## Unit tests for BuildingInfoPanel.
## Tests visibility, data display, real-time updates, and EventBus integration.
##
## Architecture: tests/unit/test_building_info_panel.gd
## Story: 3-9-implement-building-selection
extends GutTest

# Preload script to ensure class is available
const BuildingInfoPanelScript = preload("res://scripts/ui/building_info_panel.gd")

# =============================================================================
# TEST DATA
# =============================================================================

var info_panel: Control  # Use Control base type to avoid class_name issues
var mock_building: Building
var mock_hex: HexCoord
var mock_data: BuildingData
var mock_animal: Animal
var mock_animal_stats: AnimalStats

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Create info panel
	var panel_scene := preload("res://scenes/ui/building_info_panel.tscn")
	info_panel = panel_scene.instantiate()
	add_child(info_panel)
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


func after_each() -> void:
	if is_instance_valid(info_panel):
		info_panel.queue_free()
	if is_instance_valid(mock_building):
		mock_building.cleanup()
	if is_instance_valid(mock_animal):
		mock_animal.cleanup()
	await wait_frames(1)

	info_panel = null
	mock_building = null
	mock_hex = null
	mock_data = null
	mock_animal = null
	mock_animal_stats = null

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


func _create_mock_animal() -> Animal:
	var scene := preload("res://scenes/entities/animals/rabbit.tscn")
	var anim := scene.instantiate() as Animal
	add_child(anim)
	await wait_frames(1)

	mock_animal_stats = AnimalStats.new()
	mock_animal_stats.animal_id = "rabbit"
	mock_animal_stats.energy = 3
	mock_animal_stats.speed = 4
	mock_animal_stats.strength = 2
	mock_animal_stats.specialty = "Speed +20% gathering"
	mock_animal_stats.biome = "plains"

	var animal_hex := HexCoord.new(0, 0)
	anim.initialize(animal_hex, mock_animal_stats)
	await wait_frames(1)
	return anim


# =============================================================================
# VISIBILITY TESTS (AC1, AC2)
# =============================================================================

func test_panel_initially_hidden() -> void:
	assert_false(info_panel.visible, "Panel should be hidden initially")


func test_panel_shows_on_show_for_building() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)

	assert_true(info_panel.visible, "Panel should be visible after show_for_building")


func test_panel_hides_on_hide_panel() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)
	info_panel.hide_panel()

	assert_false(info_panel.visible, "Panel should be hidden after hide_panel")


func test_panel_shows_on_building_selected_signal() -> void:
	mock_building = await _create_test_building()
	EventBus.building_selected.emit(mock_building)
	await wait_frames(1)

	assert_true(info_panel.visible, "Panel should show after building_selected signal")


func test_panel_hides_on_building_deselected_signal() -> void:
	mock_building = await _create_test_building()
	EventBus.building_selected.emit(mock_building)
	await wait_frames(1)

	EventBus.building_deselected.emit()
	await wait_frames(1)

	assert_false(info_panel.visible, "Panel should hide after building_deselected signal")


func test_is_showing_returns_correct_state() -> void:
	assert_false(info_panel.is_showing(), "is_showing should be false initially")

	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)

	assert_true(info_panel.is_showing(), "is_showing should be true when visible with building")


# =============================================================================
# DATA DISPLAY TESTS (AC2, AC3, AC4)
# =============================================================================

func test_displays_building_name() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)

	assert_eq(info_panel.get_building_name(), "Farm", "Should display building name")


func test_displays_building_type() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)

	var type_label := info_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/Header/TypeLabel") as Label
	assert_eq(type_label.text, "Gatherer", "Should display building type")


func test_displays_worker_count() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)

	assert_eq(info_panel.get_worker_count_text(), "Workers: 0/2", "Should display worker count")


func test_displays_output_resource_for_gatherer() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)

	var output_label := info_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/ProductionSection/OutputRow/OutputLabel") as Label
	assert_eq(output_label.text, "Wheat", "Should display output resource")


func test_displays_cycle_time_for_gatherer() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)

	var cycle_label := info_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/ProductionSection/CycleRow/CycleLabel") as Label
	assert_eq(cycle_label.text, "5.0s", "Should display cycle time")


func test_displays_idle_status_with_no_workers() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)

	assert_eq(info_panel.get_production_status(), "Idle (No Workers)", "Should display idle status")


func test_production_section_visible_for_gatherer() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)

	var section := info_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/ProductionSection") as Control
	assert_true(section.visible, "Production section should be visible for gatherer")


func test_production_section_hidden_for_storage_building() -> void:
	# Create storage building data
	var storage_data := BuildingData.new()
	storage_data.building_id = "stockpile"
	storage_data.display_name = "Stockpile"
	storage_data.building_type = BuildingTypes.BuildingType.STORAGE
	storage_data.max_workers = 0
	storage_data.output_resource_id = ""  # Not a gatherer
	storage_data.storage_capacity_bonus = 50
	storage_data.footprint_hexes = [Vector2i.ZERO]

	# Use different hex to avoid conflict
	var storage_hex := HexCoord.new(5, 5)

	var scene := preload("res://scenes/entities/buildings/farm.tscn")
	var storage_building := scene.instantiate() as Building
	add_child(storage_building)
	await wait_frames(1)
	storage_building.initialize(storage_hex, storage_data)
	await wait_frames(1)

	info_panel.show_for_building(storage_building)

	var section := info_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/ProductionSection") as Control
	assert_false(section.visible, "Production section should be hidden for non-gatherer")

	storage_building.cleanup()
	await wait_frames(1)


# =============================================================================
# REAL-TIME UPDATE TESTS (AC9)
# =============================================================================

func test_worker_count_updates_when_worker_added() -> void:
	mock_building = await _create_test_building()
	mock_animal = await _create_mock_animal()
	info_panel.show_for_building(mock_building)

	# Add worker
	var slots := mock_building.get_worker_slots()
	slots.add_worker(mock_animal)
	await wait_frames(1)

	assert_eq(info_panel.get_worker_count_text(), "Workers: 1/2", "Should update worker count")


func test_worker_count_updates_when_worker_removed() -> void:
	mock_building = await _create_test_building()
	mock_animal = await _create_mock_animal()
	info_panel.show_for_building(mock_building)

	# Add then remove worker
	var slots := mock_building.get_worker_slots()
	slots.add_worker(mock_animal)
	await wait_frames(1)
	slots.remove_worker(mock_animal)
	await wait_frames(1)

	assert_eq(info_panel.get_worker_count_text(), "Workers: 0/2", "Should update worker count after removal")


func test_production_status_updates_on_production_started() -> void:
	mock_building = await _create_test_building()
	mock_animal = await _create_mock_animal()
	info_panel.show_for_building(mock_building)

	# Add worker to start production
	var slots := mock_building.get_worker_slots()
	slots.add_worker(mock_animal)
	await wait_frames(2)

	# Status should change to Active
	assert_eq(info_panel.get_production_status(), "Active", "Should show Active status after worker added")


func test_production_status_updates_on_production_halted() -> void:
	mock_building = await _create_test_building()
	mock_animal = await _create_mock_animal()
	info_panel.show_for_building(mock_building)

	# Add worker then remove
	var slots := mock_building.get_worker_slots()
	slots.add_worker(mock_animal)
	await wait_frames(2)
	slots.remove_worker(mock_animal)
	await wait_frames(2)

	assert_eq(info_panel.get_production_status(), "Idle (No Workers)", "Should show Idle status")


# =============================================================================
# SELECTION CHANGE TESTS (AC5)
# =============================================================================

func test_panel_updates_when_selecting_different_building() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)
	assert_eq(info_panel.get_building_name(), "Farm")

	# Create sawmill
	var sawmill_data := BuildingData.new()
	sawmill_data.building_id = "sawmill"
	sawmill_data.display_name = "Sawmill"
	sawmill_data.building_type = BuildingTypes.BuildingType.GATHERER
	sawmill_data.max_workers = 3
	sawmill_data.output_resource_id = "wood"
	sawmill_data.production_time = 4.0
	sawmill_data.footprint_hexes = [Vector2i.ZERO]

	var sawmill_hex := HexCoord.new(10, 10)
	var scene := preload("res://scenes/entities/buildings/farm.tscn")
	var sawmill := scene.instantiate() as Building
	add_child(sawmill)
	await wait_frames(1)
	sawmill.initialize(sawmill_hex, sawmill_data)
	await wait_frames(1)

	# Select sawmill
	EventBus.building_selected.emit(sawmill)
	await wait_frames(1)

	assert_eq(info_panel.get_building_name(), "Sawmill", "Should display new building name")
	assert_eq(info_panel.get_worker_count_text(), "Workers: 0/3", "Should display new worker count")

	sawmill.cleanup()
	await wait_frames(1)


func test_panel_disconnects_from_previous_building_on_switch() -> void:
	mock_building = await _create_test_building()
	mock_animal = await _create_mock_animal()
	info_panel.show_for_building(mock_building)

	# Create second building
	var hex2 := HexCoord.new(8, 8)
	var scene := preload("res://scenes/entities/buildings/farm.tscn")
	var building2 := scene.instantiate() as Building
	add_child(building2)
	await wait_frames(1)
	building2.initialize(hex2, mock_data)
	await wait_frames(1)

	# Switch to second building
	info_panel.show_for_building(building2)

	# Add worker to first building - panel should NOT update
	var slots := mock_building.get_worker_slots()
	slots.add_worker(mock_animal)
	await wait_frames(2)

	# Worker count should still show 0 for second building
	assert_eq(info_panel.get_worker_count_text(), "Workers: 0/2", "Should NOT update from disconnected building")

	building2.cleanup()
	await wait_frames(1)


# =============================================================================
# BUILDING REMOVAL TESTS (AC10)
# =============================================================================

func test_panel_hides_on_building_removed_signal() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)
	assert_true(info_panel.visible)

	# Emit removal signal
	var hex_vec := mock_building.get_hex_coord().to_vector()
	EventBus.building_removed.emit(mock_building, hex_vec)
	await wait_frames(1)

	assert_false(info_panel.visible, "Panel should hide when building is removed")


func test_panel_ignores_removal_of_different_building() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)
	assert_true(info_panel.visible)

	# Create another building
	var hex2 := HexCoord.new(15, 15)
	var scene := preload("res://scenes/entities/buildings/farm.tscn")
	var building2 := scene.instantiate() as Building
	add_child(building2)
	await wait_frames(1)
	building2.initialize(hex2, mock_data)
	await wait_frames(1)

	# Remove the OTHER building
	var hex_vec := building2.get_hex_coord().to_vector()
	EventBus.building_removed.emit(building2, hex_vec)
	await wait_frames(1)

	assert_true(info_panel.visible, "Panel should remain visible for selected building")

	building2.cleanup()
	await wait_frames(1)


# =============================================================================
# NULL SAFETY TESTS
# =============================================================================

func test_show_for_null_building_no_crash() -> void:
	info_panel.show_for_building(null)
	assert_false(info_panel.visible, "Panel should remain hidden for null building")


func test_panel_handles_building_freed_gracefully() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)
	assert_true(info_panel.visible)

	# Directly free the building (without cleanup signal)
	mock_building.queue_free()
	await wait_frames(2)

	# Emit deselected (simulating what SelectionManager would do)
	EventBus.building_deselected.emit()
	await wait_frames(1)

	assert_false(info_panel.visible, "Panel should hide gracefully")
	mock_building = null  # Prevent after_each cleanup error


func test_current_building_reference_cleared_on_hide() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)
	assert_not_null(info_panel.get_current_building(), "Should have building reference")

	info_panel.hide_panel()

	assert_null(info_panel.get_current_building(), "Building reference should be cleared")


func test_current_building_reference_cleared_on_deselected() -> void:
	mock_building = await _create_test_building()
	EventBus.building_selected.emit(mock_building)
	await wait_frames(1)
	assert_not_null(info_panel.get_current_building(), "Should have building reference")

	EventBus.building_deselected.emit()
	await wait_frames(1)

	assert_null(info_panel.get_current_building(), "Building reference should be cleared")


# =============================================================================
# SIGNAL CONNECTION TESTS
# =============================================================================

func test_eventbus_signals_connected_on_ready() -> void:
	assert_true(EventBus.building_selected.is_connected(info_panel._on_building_selected),
		"Should be connected to building_selected")
	assert_true(EventBus.building_deselected.is_connected(info_panel._on_building_deselected),
		"Should be connected to building_deselected")
	assert_true(EventBus.building_removed.is_connected(info_panel._on_building_removed),
		"Should be connected to building_removed")


func test_worker_slots_signal_connected_on_show() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)

	var slots := mock_building.get_worker_slots()
	assert_true(slots.workers_changed.is_connected(info_panel._on_workers_changed),
		"Should be connected to workers_changed")


func test_worker_slots_signal_disconnected_on_hide() -> void:
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)
	var slots := mock_building.get_worker_slots()

	info_panel.hide_panel()

	assert_false(slots.workers_changed.is_connected(info_panel._on_workers_changed),
		"Should be disconnected from workers_changed")


func test_production_signals_connected_in_ready() -> void:
	# Production signals are connected once in _ready(), not per-building selection
	# This ensures no connection leaks when switching buildings
	assert_true(EventBus.production_started.is_connected(info_panel._on_production_started),
		"Should be connected to production_started from _ready()")
	assert_true(EventBus.production_halted.is_connected(info_panel._on_production_halted),
		"Should be connected to production_halted from _ready()")
	assert_true(EventBus.resource_gathering_paused.is_connected(info_panel._on_gathering_paused),
		"Should be connected to resource_gathering_paused from _ready()")
	assert_true(EventBus.resource_gathering_resumed.is_connected(info_panel._on_gathering_resumed),
		"Should be connected to resource_gathering_resumed from _ready()")


func test_production_signals_remain_connected_after_hide() -> void:
	# Production signals stay connected (filter by building in handlers)
	mock_building = await _create_test_building()
	info_panel.show_for_building(mock_building)
	info_panel.hide_panel()

	# Signals remain connected - disconnected only in _exit_tree()
	assert_true(EventBus.production_started.is_connected(info_panel._on_production_started),
		"Should remain connected to production_started after hide")
	assert_true(EventBus.production_halted.is_connected(info_panel._on_production_halted),
		"Should remain connected to production_halted after hide")


# =============================================================================
# STATUS CONSTANTS TESTS
# =============================================================================

func test_status_idle_constant() -> void:
	assert_eq(BuildingInfoPanelScript.STATUS_IDLE, "Idle (No Workers)", "Idle status constant")


func test_status_active_constant() -> void:
	assert_eq(BuildingInfoPanelScript.STATUS_ACTIVE, "Active", "Active status constant")


func test_status_paused_constant() -> void:
	assert_eq(BuildingInfoPanelScript.STATUS_PAUSED, "Paused (Storage Full)", "Paused status constant")
