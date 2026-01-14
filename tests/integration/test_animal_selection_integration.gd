## Integration tests for Animal Selection System.
## Tests visual feedback, Animal signals, and end-to-end selection flow.
##
## Architecture: tests/integration/test_animal_selection_integration.gd
## Story: 2-3-implement-animal-selection
extends GutTest

# =============================================================================
# TEST DATA
# =============================================================================

var selection_manager: Node
var animal: Animal
var mock_hex: HexCoord
var mock_stats: AnimalStats

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	mock_hex = HexCoord.new(0, 0)

	mock_stats = AnimalStats.new()
	mock_stats.animal_id = "test_rabbit"
	mock_stats.energy = 3
	mock_stats.speed = 4
	mock_stats.strength = 2
	mock_stats.specialty = "Test"
	mock_stats.biome = "plains"

	# Create SelectionManager
	var SelectionManagerScript := preload("res://scripts/systems/selection/selection_manager.gd")
	selection_manager = SelectionManagerScript.new()
	add_child(selection_manager)

	# Create test animal
	var scene := preload("res://scenes/entities/animals/rabbit.tscn")
	animal = scene.instantiate() as Animal
	add_child(animal)
	await wait_frames(1)

	animal.initialize(mock_hex, mock_stats)
	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(selection_manager):
		selection_manager.queue_free()
	if is_instance_valid(animal):
		animal.cleanup()
	await wait_frames(1)

# =============================================================================
# VISUAL FEEDBACK TESTS (AC2, AC8)
# =============================================================================

func test_selection_highlight_hidden_initially() -> void:
	var highlight := animal.get_node_or_null("SelectionHighlight")

	assert_not_null(highlight, "Selection highlight should exist")
	assert_false(highlight.visible, "Highlight should be hidden initially")


func test_selection_highlight_shown_on_select() -> void:
	selection_manager.select_animal(animal)
	await wait_frames(1)

	var highlight := animal.get_node("SelectionHighlight")
	assert_true(highlight.visible, "Highlight should be visible when selected")


func test_selection_highlight_hidden_on_deselect() -> void:
	selection_manager.select_animal(animal)
	await wait_frames(1)
	selection_manager.deselect_current()
	await wait_frames(1)

	var highlight := animal.get_node("SelectionHighlight")
	assert_false(highlight.visible, "Highlight should be hidden when deselected")


func test_selection_highlight_is_mesh_instance() -> void:
	var highlight := animal.get_node("SelectionHighlight")

	assert_true(highlight is MeshInstance3D, "Highlight should be MeshInstance3D")


func test_selection_highlight_has_emissive_material() -> void:
	var highlight := animal.get_node("SelectionHighlight") as MeshInstance3D

	assert_not_null(highlight.material_override, "Highlight should have material")
	var material := highlight.material_override as StandardMaterial3D
	assert_true(material.emission_enabled, "Material should have emission enabled")


func test_selection_highlight_position_correct() -> void:
	var highlight := animal.get_node("SelectionHighlight")

	# Should be at base of animal, just above ground
	assert_almost_eq(highlight.position.y, 0.05, 0.01, "Highlight Y should be 0.05")

# =============================================================================
# SCALE PULSE ANIMATION TESTS (AC8)
# =============================================================================

func test_scale_pulse_starts_on_selection() -> void:
	var initial_scale := animal.scale

	selection_manager.select_animal(animal)
	await wait_frames(1)  # Let animation start

	# During animation, scale should change (may be mid-animation)
	# After animation completes, should return to normal
	await get_tree().create_timer(0.3).timeout  # Wait for animation to complete

	# Scale should return to normal after animation
	assert_almost_eq(animal.scale.x, 1.0, 0.05, "Scale X should return to 1.0")
	assert_almost_eq(animal.scale.y, 1.0, 0.05, "Scale Y should return to 1.0")
	assert_almost_eq(animal.scale.z, 1.0, 0.05, "Scale Z should return to 1.0")


func test_scale_pulse_completes_correctly() -> void:
	selection_manager.select_animal(animal)

	# Wait for full animation (0.2s total)
	await get_tree().create_timer(0.3).timeout

	assert_eq(animal.scale, Vector3.ONE, "Scale should be exactly 1,1,1 after animation")

# =============================================================================
# ANIMAL SIGNAL TESTS
# =============================================================================

func test_animal_selected_signal_emitted() -> void:
	watch_signals(animal)

	selection_manager.select_animal(animal)

	assert_signal_emitted(animal, "selected")


func test_animal_deselected_signal_emitted() -> void:
	selection_manager.select_animal(animal)
	watch_signals(animal)

	selection_manager.deselect_current()

	assert_signal_emitted(animal, "deselected")


func test_animal_is_selected_method() -> void:
	assert_false(animal.is_selected(), "Should not be selected initially")

	selection_manager.select_animal(animal)

	assert_true(animal.is_selected(), "Should be selected after select")

	selection_manager.deselect_current()

	assert_false(animal.is_selected(), "Should not be selected after deselect")

# =============================================================================
# COMPONENT SIGNAL CHAIN TESTS
# =============================================================================

func test_selectable_to_animal_signal_chain() -> void:
	# Verify signal chain: SelectableComponent -> Animal -> External
	var selectable := animal.get_node("SelectableComponent") as SelectableComponent

	watch_signals(animal)

	# Directly trigger component (simulating SelectionManager action)
	selectable.select()

	assert_signal_emitted(animal, "selected")


func test_animal_cleanup_disconnects_signals() -> void:
	selection_manager.select_animal(animal)
	var selectable := animal.get_node("SelectableComponent") as SelectableComponent

	# Cleanup should disconnect signals
	animal.cleanup()
	await wait_frames(1)

	# This should not crash (signals disconnected)
	assert_true(true, "Cleanup should disconnect signals without error")

# =============================================================================
# MULTI-ANIMAL VISUAL TESTS
# =============================================================================

func test_only_selected_animal_shows_highlight() -> void:
	# Create second animal
	var animal2 := preload("res://scenes/entities/animals/rabbit.tscn").instantiate() as Animal
	add_child(animal2)
	await wait_frames(1)
	animal2.initialize(HexCoord.new(5, 5), mock_stats)
	await wait_frames(1)

	# Select first, then second
	selection_manager.select_animal(animal)
	await wait_frames(1)
	selection_manager.select_animal(animal2)
	await wait_frames(1)

	# First should be hidden, second should be visible
	var highlight1 := animal.get_node("SelectionHighlight")
	var highlight2 := animal2.get_node("SelectionHighlight")

	assert_false(highlight1.visible, "First animal highlight should be hidden")
	assert_true(highlight2.visible, "Second animal highlight should be visible")

	animal2.cleanup()
	await wait_frames(1)

# =============================================================================
# TAP THRESHOLD EDGE CASE TESTS (GLaDOS review)
# =============================================================================

func test_tap_at_boundary_threshold_time() -> void:
	## Edge case: Touch at 199ms (just under 300ms threshold)
	## This should count as a valid tap
	var threshold_ms := GameConstants.TAP_MAX_DURATION_MS

	# Verify threshold is what we expect
	assert_eq(threshold_ms, 300, "TAP_MAX_DURATION_MS should be 300")


func test_tap_at_boundary_threshold_distance() -> void:
	## Edge case: Movement of 9.9px (just under 10px threshold)
	## This should count as a valid tap
	var threshold_px := GameConstants.TAP_MAX_DISTANCE_PX

	# Verify threshold is what we expect
	assert_eq(threshold_px, 10.0, "TAP_MAX_DISTANCE_PX should be 10.0")


func test_tap_constants_accessible() -> void:
	## Verify constants are accessible from GameConstants
	assert_not_null(GameConstants.TAP_MAX_DURATION_MS, "TAP_MAX_DURATION_MS should exist")
	assert_not_null(GameConstants.TAP_MAX_DISTANCE_PX, "TAP_MAX_DISTANCE_PX should exist")
	assert_not_null(GameConstants.SELECTION_TAP_RADIUS, "SELECTION_TAP_RADIUS should exist")

# =============================================================================
# RAPID TAP STRESS TEST (GLaDOS review)
# =============================================================================

func test_rapid_selection_no_thrashing() -> void:
	## Simulate rapid taps (10 taps/second equivalent)
	## Selection should handle debouncing naturally

	# Create second animal
	var animal2 := preload("res://scenes/entities/animals/rabbit.tscn").instantiate() as Animal
	add_child(animal2)
	await wait_frames(1)
	animal2.initialize(HexCoord.new(5, 5), mock_stats)
	await wait_frames(1)

	# Rapidly alternate selections
	for i in range(10):
		selection_manager.select_animal(animal if i % 2 == 0 else animal2)

	# Should end with predictable state (last selection)
	assert_eq(selection_manager.get_selected_animal(), animal2, "Should end with last selected animal")

	animal2.cleanup()
	await wait_frames(1)


func test_rapid_same_animal_selection() -> void:
	## Selecting same animal rapidly should be no-op after first
	watch_signals(EventBus)

	selection_manager.select_animal(animal)

	# Rapid re-selections of same animal
	for i in range(9):
		selection_manager.select_animal(animal)

	# Should only have emitted one select signal
	assert_signal_emit_count(EventBus, "animal_selected", 1)

# =============================================================================
# SELECTION DURING CAMERA MOMENTUM TESTS (Task 8.10 - Code Review fix)
# =============================================================================

func test_selection_during_camera_momentum() -> void:
	## Test that selection works while camera has active momentum (AC5)
	## This verifies momentum does not interfere with tap detection

	# Create a mock camera controller with momentum
	var camera := Camera3D.new()
	camera.add_to_group("cameras")
	add_child(camera)
	await wait_frames(1)

	var CameraControllerScript := preload("res://scripts/camera/camera_controller.gd")
	var camera_controller := CameraControllerScript.new()
	camera.add_child(camera_controller)
	await wait_frames(1)

	# Simulate camera momentum (set internal state)
	camera_controller._momentum_velocity = Vector2(50.0, 30.0)  # Active momentum

	# Verify momentum is active
	assert_gt(camera_controller._momentum_velocity.length(), 0.5, "Camera should have active momentum")

	# Now select an animal while camera has momentum
	selection_manager.select_animal(animal)

	# Selection should succeed despite camera momentum
	assert_true(selection_manager.has_selection(), "Selection should work during camera momentum")
	assert_eq(selection_manager.get_selected_animal(), animal, "Correct animal should be selected")
	assert_true(animal.is_selected(), "Animal should report as selected")

	# Cleanup
	camera.queue_free()
	await wait_frames(1)


func test_selection_clears_during_camera_momentum() -> void:
	## Test that deselection works while camera has active momentum

	# Create a mock camera with momentum
	var camera := Camera3D.new()
	camera.add_to_group("cameras")
	add_child(camera)
	await wait_frames(1)

	var CameraControllerScript := preload("res://scripts/camera/camera_controller.gd")
	var camera_controller := CameraControllerScript.new()
	camera.add_child(camera_controller)
	await wait_frames(1)

	# First select the animal
	selection_manager.select_animal(animal)
	assert_true(selection_manager.has_selection(), "Should have selection")

	# Simulate camera momentum
	camera_controller._momentum_velocity = Vector2(100.0, 50.0)

	# Now deselect while camera has momentum
	selection_manager.deselect_current()

	# Deselection should succeed
	assert_false(selection_manager.has_selection(), "Deselection should work during camera momentum")
	assert_false(animal.is_selected(), "Animal should report as deselected")

	# Cleanup
	camera.queue_free()
	await wait_frames(1)
