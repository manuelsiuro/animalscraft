## Unit tests for WorkerSelectionOverlay.
## Tests visibility, animal list population, assignment workflow, and dismissal.
##
## Architecture: tests/unit/test_worker_selection_overlay.gd
## Story: 3-10-assign-animals-to-buildings
extends GutTest

# Preload script for type safety
const WorkerSelectionOverlayScript = preload("res://scripts/ui/worker_selection_overlay.gd")

# =============================================================================
# TEST DATA
# =============================================================================

var overlay: Control  # Use Control base type to avoid class_name resolution issues
var mock_building: Building
var mock_hex: HexCoord
var mock_data: BuildingData
var mock_animal: Animal
var mock_animal_stats: AnimalStats
var created_animals: Array[Animal] = []

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Create overlay
	var overlay_scene := preload("res://scenes/ui/worker_selection_overlay.tscn")
	overlay = overlay_scene.instantiate()
	add_child(overlay)
	await wait_frames(1)

	# Create mock building data
	mock_hex = HexCoord.new(2, 3)
	mock_data = BuildingData.new()
	mock_data.building_id = "farm"
	mock_data.display_name = "Farm"
	mock_data.building_type = BuildingTypes.BuildingType.GATHERER
	mock_data.max_workers = 2
	mock_data.output_resource_id = "wheat"
	mock_data.production_time = 5.0
	mock_data.footprint_hexes = [Vector2i.ZERO]

	# Clear occupancy
	HexGrid.clear_occupancy()
	created_animals.clear()


func after_each() -> void:
	if is_instance_valid(overlay):
		overlay.queue_free()
	if is_instance_valid(mock_building):
		mock_building.cleanup()
	if is_instance_valid(mock_animal):
		mock_animal.cleanup()
	for animal in created_animals:
		if is_instance_valid(animal):
			animal.cleanup()
	await wait_frames(1)

	overlay = null
	mock_building = null
	mock_hex = null
	mock_data = null
	mock_animal = null
	mock_animal_stats = null
	created_animals.clear()

	# Clean up occupancy
	HexGrid.clear_occupancy()


func _create_test_building() -> Building:
	var scene := preload("res://scenes/entities/buildings/farm.tscn")
	var bld := scene.instantiate() as Building
	add_child(bld)
	await wait_frames(1)
	bld.initialize(mock_hex, mock_data)
	await wait_frames(1)
	return bld


func _create_mock_animal(hex_offset: int = 0) -> Animal:
	var scene := preload("res://scenes/entities/animals/rabbit.tscn")
	var anim := scene.instantiate() as Animal
	add_child(anim)
	await wait_frames(1)

	var stats := AnimalStats.new()
	stats.animal_id = "rabbit_%d" % hex_offset
	stats.energy = 3
	stats.speed = 4
	stats.strength = 2
	stats.specialty = "Speed +20% gathering"
	stats.biome = "plains"

	var animal_hex := HexCoord.new(hex_offset, hex_offset)
	anim.initialize(animal_hex, stats)
	await wait_frames(2)  # Wait for AIComponent to initialize
	created_animals.append(anim)
	return anim


# =============================================================================
# VISIBILITY TESTS (AC3, AC6)
# =============================================================================

func test_overlay_initially_hidden() -> void:
	assert_false(overlay.visible, "Overlay should be hidden initially")


func test_overlay_shows_on_show_for_building() -> void:
	mock_building = await _create_test_building()
	overlay.show_for_building(mock_building)

	assert_true(overlay.visible, "Overlay should be visible after show_for_building")


func test_overlay_hides_on_hide_overlay() -> void:
	mock_building = await _create_test_building()
	overlay.show_for_building(mock_building)
	overlay.hide_overlay()

	assert_false(overlay.visible, "Overlay should be hidden after hide_overlay")


func test_is_showing_returns_correct_state() -> void:
	assert_false(overlay.is_showing(), "is_showing should be false initially")

	mock_building = await _create_test_building()
	overlay.show_for_building(mock_building)

	assert_true(overlay.is_showing(), "is_showing should be true when visible")


# =============================================================================
# ANIMAL LIST TESTS (AC3, AC9)
# =============================================================================

func test_populates_list_with_idle_animals() -> void:
	mock_building = await _create_test_building()
	mock_animal = await _create_mock_animal(0)

	# Ensure animal is IDLE
	var ai := mock_animal.get_node_or_null("AIComponent")
	if ai and ai.has_method("transition_to"):
		ai.transition_to(AIComponent.AnimalState.IDLE)
	await wait_frames(1)

	overlay.show_for_building(mock_building)
	await wait_frames(1)

	assert_gt(overlay.get_animal_item_count(), 0, "Should show at least one idle animal")


func test_shows_no_animals_message_when_none_available() -> void:
	mock_building = await _create_test_building()
	# No animals created - no idle animals available

	overlay.show_for_building(mock_building)
	await wait_frames(1)

	assert_true(overlay.is_no_animals_message_visible(), "Should show 'no animals' message")


func test_excludes_animals_assigned_to_buildings() -> void:
	mock_building = await _create_test_building()
	mock_animal = await _create_mock_animal(0)

	# Assign animal to building
	mock_animal.set_assigned_building(mock_building)
	await wait_frames(1)

	overlay.show_for_building(mock_building)
	await wait_frames(1)

	assert_eq(overlay.get_animal_item_count(), 0, "Should not show assigned animals")


func test_excludes_animals_not_in_idle_state() -> void:
	mock_building = await _create_test_building()
	mock_animal = await _create_mock_animal(0)

	# Transition to WORKING state
	var ai := mock_animal.get_node_or_null("AIComponent")
	if ai and ai.has_method("transition_to"):
		# First go to WALKING (can't go directly to WORKING from IDLE)
		ai.transition_to(AIComponent.AnimalState.WALKING)
		await wait_frames(1)
		ai.transition_to(AIComponent.AnimalState.WORKING)
		await wait_frames(1)

	overlay.show_for_building(mock_building)
	await wait_frames(1)

	assert_eq(overlay.get_animal_item_count(), 0, "Should not show non-IDLE animals")


func test_shows_multiple_idle_animals() -> void:
	mock_building = await _create_test_building()

	# Create multiple idle animals
	var animal1 := await _create_mock_animal(5)
	var animal2 := await _create_mock_animal(6)
	var animal3 := await _create_mock_animal(7)
	await wait_frames(2)

	overlay.show_for_building(mock_building)
	await wait_frames(1)

	assert_eq(overlay.get_animal_item_count(), 3, "Should show all idle animals")


# =============================================================================
# DISMISSAL TESTS (AC6, AC12)
# =============================================================================

func test_closed_signal_emitted_on_hide() -> void:
	watch_signals(overlay)

	mock_building = await _create_test_building()
	overlay.show_for_building(mock_building)
	overlay.hide_overlay()
	await wait_frames(1)

	assert_signal_emitted(overlay, "closed", "closed signal should be emitted")


func test_overlay_closes_on_building_removed() -> void:
	mock_building = await _create_test_building()
	overlay.show_for_building(mock_building)
	assert_true(overlay.visible)

	# Emit building removed signal
	var hex_vec := mock_building.get_hex_coord().to_vector()
	EventBus.building_removed.emit(mock_building, hex_vec)
	await wait_frames(1)

	assert_false(overlay.visible, "Overlay should close when target building is removed")


func test_overlay_ignores_removal_of_different_building() -> void:
	mock_building = await _create_test_building()
	overlay.show_for_building(mock_building)
	assert_true(overlay.visible)

	# Create and remove different building
	var other_hex := HexCoord.new(15, 15)
	var scene := preload("res://scenes/entities/buildings/farm.tscn")
	var other_building := scene.instantiate() as Building
	add_child(other_building)
	await wait_frames(1)
	other_building.initialize(other_hex, mock_data)
	await wait_frames(1)

	var hex_vec := other_building.get_hex_coord().to_vector()
	EventBus.building_removed.emit(other_building, hex_vec)
	await wait_frames(1)

	assert_true(overlay.visible, "Overlay should remain for target building")

	other_building.cleanup()
	await wait_frames(1)


# =============================================================================
# TITLE DISPLAY TESTS
# =============================================================================

func test_title_shows_building_name() -> void:
	mock_building = await _create_test_building()
	overlay.show_for_building(mock_building)

	var title := overlay.get_node("Panel/MarginContainer/VBoxContainer/Header/TitleLabel") as Label
	assert_true(title.text.contains("Farm"), "Title should contain building name")


# =============================================================================
# TARGET BUILDING TESTS
# =============================================================================

func test_get_target_building_returns_current_building() -> void:
	mock_building = await _create_test_building()
	overlay.show_for_building(mock_building)

	assert_eq(overlay.get_target_building(), mock_building, "Should return target building")


func test_target_building_cleared_on_hide() -> void:
	mock_building = await _create_test_building()
	overlay.show_for_building(mock_building)
	overlay.hide_overlay()

	assert_null(overlay.get_target_building(), "Target building should be cleared on hide")


# =============================================================================
# NULL SAFETY TESTS
# =============================================================================

func test_show_for_null_building_no_crash() -> void:
	overlay.show_for_building(null)
	assert_false(overlay.visible, "Overlay should remain hidden for null building")


func test_hide_overlay_when_not_visible_no_crash() -> void:
	overlay.hide_overlay()
	assert_false(overlay.visible, "Should handle hide when already hidden")


# =============================================================================
# SIGNAL TESTS
# =============================================================================

func test_worker_assigned_signal_emitted_on_assignment() -> void:
	watch_signals(overlay)

	mock_building = await _create_test_building()
	mock_animal = await _create_mock_animal(0)
	await wait_frames(2)

	overlay.show_for_building(mock_building)
	await wait_frames(2)

	# Simulate selecting the animal item
	overlay._on_animal_item_pressed(mock_animal)
	await wait_frames(1)

	assert_signal_emitted(overlay, "worker_assigned", "worker_assigned signal should be emitted")

	# Verify signal parameters
	var params: Array = get_signal_parameters(overlay, "worker_assigned", 0)
	if params.size() >= 2:
		assert_eq(params[0], mock_animal, "Should pass correct animal")
		assert_eq(params[1], mock_building, "Should pass correct building")


func test_overlay_closes_after_assignment() -> void:
	mock_building = await _create_test_building()
	mock_animal = await _create_mock_animal(0)
	await wait_frames(1)

	overlay.show_for_building(mock_building)
	await wait_frames(1)

	overlay._on_animal_item_pressed(mock_animal)
	await wait_frames(1)

	assert_false(overlay.visible, "Overlay should close after assignment")


# =============================================================================
# EVENTBUS CONNECTION TESTS
# =============================================================================

func test_building_removed_signal_connected() -> void:
	assert_true(EventBus.building_removed.is_connected(overlay._on_building_removed),
		"Should be connected to building_removed signal")
