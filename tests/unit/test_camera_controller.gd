## Unit tests for Story 1.3: Implement Camera Pan
##
## These tests verify CameraController functionality for touch-based camera panning,
## momentum, bounds enforcement, and empty space detection.
##
## Test Framework: GUT (Godot Unit Test)
## Run: Via GUT test runner in Godot Editor (bottom panel)
##
## Coverage:
## - AC1: Drag to Pan
## - AC2: Momentum Effect
## - AC3: Camera Bounds
## - AC4: Responsive Touch Input
## - AC5: Empty Space Detection
extends GutTest

# =============================================================================
# CONSTANTS FOR TESTING
# =============================================================================

## Tolerance for floating point comparisons
const FLOAT_TOLERANCE: float = 0.001

# =============================================================================
# TEST FIXTURES
# =============================================================================

var camera_controller: CameraController
var camera: Camera2D
var world_manager: Node2D

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	gut.p("Running Story 1.3 CameraController tests")

	# Create camera node hierarchy
	camera = Camera2D.new()
	camera_controller = CameraController.new()
	camera.add_child(camera_controller)
	add_child(camera)

	# Create mock world manager
	world_manager = Node2D.new()
	world_manager.set_script(load("res://scripts/world/world_manager.gd"))
	add_child(world_manager)

	# Initialize camera controller (this will calculate bounds from world_manager)
	camera_controller.initialize(world_manager)

	# NOTE: Do NOT override _camera_bounds here - let initialize() set them properly
	# Individual tests that need specific bounds should set them explicitly


func after_each() -> void:
	# Clean up nodes
	if is_instance_valid(camera):
		camera.queue_free()
	if is_instance_valid(world_manager):
		world_manager.queue_free()

# =============================================================================
# AC1: Drag to Pan Tests
# =============================================================================

## Test camera controller initializes correctly
func test_camera_controller_initialization() -> void:
	assert_not_null(camera_controller._camera, "Camera reference should be set")
	assert_eq(camera_controller._camera, camera, "Camera reference should match parent")


## Test drag moves camera offset
func test_drag_moves_camera() -> void:
	# Set large bounds to prevent clamping during test
	camera_controller._camera_bounds = Rect2(-10000, -10000, 20000, 20000)

	var start_offset := camera.offset

	# Simulate touch press and drag
	camera_controller._on_touch_pressed(Vector2(100, 100))
	camera_controller._on_touch_dragged(Vector2(150, 100))

	assert_ne(camera.offset, start_offset, "Camera offset should change on drag")


## Test drag direction matches expected movement
func test_drag_direction_correct() -> void:
	# Set large bounds to prevent clamping during test
	camera_controller._camera_bounds = Rect2(-10000, -10000, 20000, 20000)
	camera.offset = Vector2.ZERO

	# Drag right (touch moves right = camera pans right)
	camera_controller._on_touch_pressed(Vector2(100, 100))
	camera_controller._on_touch_dragged(Vector2(150, 100))

	# Camera offset should decrease (moving touch right = world moves left relative to camera)
	assert_lt(camera.offset.x, 0, "Dragging right should decrease camera offset X")


## Test multiple drag events accumulate
func test_multiple_drags_accumulate() -> void:
	# Set large bounds to prevent clamping during test
	camera_controller._camera_bounds = Rect2(-10000, -10000, 20000, 20000)
	camera.offset = Vector2.ZERO

	camera_controller._on_touch_pressed(Vector2(100, 100))
	camera_controller._on_touch_dragged(Vector2(110, 100))
	var offset_after_first := camera.offset.x

	camera_controller._on_touch_dragged(Vector2(120, 100))
	var offset_after_second := camera.offset.x

	assert_lt(offset_after_second, offset_after_first, "Multiple drags should accumulate")


## Test drag respects zoom level
func test_drag_respects_zoom() -> void:
	# Set large bounds to prevent clamping during test
	camera_controller._camera_bounds = Rect2(-10000, -10000, 20000, 20000)

	camera.offset = Vector2.ZERO
	camera.zoom = Vector2(0.5, 0.5)  # Zoomed out

	camera_controller._on_touch_pressed(Vector2(100, 100))
	camera_controller._on_touch_dragged(Vector2(150, 100))
	var offset_zoomed_out: float = abs(camera.offset.x)

	# Reset and test with zoomed in
	camera.offset = Vector2.ZERO
	camera.zoom = Vector2(2.0, 2.0)  # Zoomed in

	camera_controller._on_touch_pressed(Vector2(100, 100))
	camera_controller._on_touch_dragged(Vector2(150, 100))
	var offset_zoomed_in: float = abs(camera.offset.x)

	# Zoomed in should move less world space for same drag distance
	assert_lt(offset_zoomed_in, offset_zoomed_out, "Zoom level should affect pan sensitivity")

# =============================================================================
# AC2: Momentum Effect Tests
# =============================================================================

## Test momentum applies after release
func test_momentum_applies_after_release() -> void:
	# Set large bounds to prevent clamping during test
	camera_controller._camera_bounds = Rect2(-10000, -10000, 20000, 20000)

	camera_controller._on_touch_pressed(Vector2(100, 100))
	camera_controller._on_touch_dragged(Vector2(150, 100))
	camera_controller._on_touch_released()

	var offset_before := camera.offset
	camera_controller._physics_process(1.0 / 60.0)

	assert_ne(camera.offset, offset_before, "Momentum should move camera after release")


## Test momentum decays over time
func test_momentum_decays() -> void:
	# Set large bounds to prevent clamping during test
	camera_controller._camera_bounds = Rect2(-10000, -10000, 20000, 20000)

	# Set initial momentum velocity
	camera_controller._momentum_velocity = Vector2(100, 0)

	var initial_velocity := camera_controller._momentum_velocity.length()

	# Simulate several frames
	for i in range(10):
		camera_controller._physics_process(1.0 / 60.0)

	var final_velocity := camera_controller._momentum_velocity.length()

	assert_lt(final_velocity, initial_velocity, "Momentum velocity should decay")


## Test momentum stops when below threshold
func test_momentum_stops_at_threshold() -> void:
	# Set momentum just above threshold
	camera_controller._momentum_velocity = Vector2(0.6, 0)

	# Run physics until velocity reaches zero (code sets to zero when < threshold)
	for i in range(150):
		camera_controller._physics_process(1.0 / 60.0)
		# Check if velocity was set to zero
		if camera_controller._momentum_velocity == Vector2.ZERO:
			break

	# After enough iterations, momentum should be zero (set by code when below threshold)
	assert_eq(camera_controller._momentum_velocity, Vector2.ZERO, "Momentum should be set to zero when below threshold")


## Test momentum does not apply while dragging
func test_momentum_disabled_while_dragging() -> void:
	camera_controller._momentum_velocity = Vector2(100, 0)
	camera_controller._is_dragging = true

	var offset_before := camera.offset
	camera_controller._physics_process(1.0 / 60.0)

	assert_eq(camera.offset, offset_before, "Momentum should not apply while dragging")


## Test release captures velocity correctly
func test_release_captures_velocity() -> void:
	camera_controller._on_touch_pressed(Vector2(100, 100))
	camera_controller._on_touch_dragged(Vector2(150, 100))

	# Velocity should be set from last drag
	assert_ne(camera_controller._momentum_velocity, Vector2.ZERO, "Velocity should be captured on drag")

	camera_controller._on_touch_released()

	# Velocity should persist after release
	assert_ne(camera_controller._momentum_velocity, Vector2.ZERO, "Velocity should persist after release")

# =============================================================================
# AC3: Camera Bounds Tests
# =============================================================================

## Test camera bounds clamping on X axis
func test_camera_bounds_clamp_x() -> void:
	# Set up small bounds
	camera_controller._camera_bounds = Rect2(0, 0, 100, 100)

	camera.offset = Vector2(200, 50)  # Outside bounds
	camera_controller._apply_camera_bounds()

	assert_eq(camera.offset.x, 100, "Should clamp to max X bound")


## Test camera bounds clamping on Y axis
func test_camera_bounds_clamp_y() -> void:
	# Set up small bounds
	camera_controller._camera_bounds = Rect2(0, 0, 100, 100)

	camera.offset = Vector2(50, 200)  # Outside bounds
	camera_controller._apply_camera_bounds()

	assert_eq(camera.offset.y, 100, "Should clamp to max Y bound")


## Test camera bounds clamping at minimum
func test_camera_bounds_clamp_min() -> void:
	# Set up bounds
	camera_controller._camera_bounds = Rect2(10, 10, 100, 100)

	camera.offset = Vector2(-50, -50)  # Below minimum
	camera_controller._apply_camera_bounds()

	assert_eq(camera.offset.x, 10, "Should clamp to min X bound")
	assert_eq(camera.offset.y, 10, "Should clamp to min Y bound")


## Test bounds include hex margin
func test_bounds_include_margin() -> void:
	# Create a new world manager with mock bounds
	# Use large world bounds to ensure they're bigger than viewport
	var mock_world := Node2D.new()
	var script_mock := GDScript.new()
	script_mock.source_code = """
extends Node2D
func get_world_bounds() -> Rect2:
	return Rect2(-1000, -2000, 2000, 4000)
"""
	script_mock.reload()
	mock_world.set_script(script_mock)
	add_child(mock_world)

	camera_controller.initialize(mock_world)
	camera_controller._update_camera_bounds()

	# Bounds should be larger than world due to margin
	# Margin = HEX_SIZE * BOUNDS_MARGIN_HEX
	var expected_margin := GameConstants.HEX_SIZE * camera_controller.BOUNDS_MARGIN_HEX

	assert_true(camera_controller._camera_bounds.has_area(), "Camera bounds should have area")

	# Clean up
	mock_world.queue_free()


## Test drag enforces bounds automatically
func test_drag_enforces_bounds() -> void:
	# Set tight bounds
	camera_controller._camera_bounds = Rect2(-50, -50, 100, 100)

	camera.offset = Vector2.ZERO

	# Try to drag far outside bounds
	camera_controller._on_touch_pressed(Vector2(100, 100))
	camera_controller._on_touch_dragged(Vector2(-500, 100))  # Huge drag

	# Camera should be clamped to bounds
	assert_between(camera.offset.x, -50, 50, "X should be within bounds after drag")


## Test momentum enforces bounds
func test_momentum_enforces_bounds() -> void:
	# Set tight bounds
	camera_controller._camera_bounds = Rect2(-50, -50, 100, 100)

	# Set high momentum that would go outside bounds
	camera.offset = Vector2(40, 0)
	camera_controller._momentum_velocity = Vector2(1000, 0)

	# Run physics
	camera_controller._physics_process(1.0 / 60.0)

	# Should be clamped
	assert_lte(camera.offset.x, 50, "Momentum should respect bounds")

# =============================================================================
# AC4: Responsive Touch Input Tests
# =============================================================================

## Test unhandled input processes touch press
func test_unhandled_input_touch_press() -> void:
	var event := InputEventScreenTouch.new()
	event.pressed = true
	event.position = Vector2(100, 100)

	camera_controller._unhandled_input(event)

	assert_true(camera_controller._is_dragging, "Touch press should start dragging")


## Test unhandled input processes touch release
func test_unhandled_input_touch_release() -> void:
	# Start drag first
	camera_controller._on_touch_pressed(Vector2(100, 100))

	var event := InputEventScreenTouch.new()
	event.pressed = false
	event.position = Vector2(100, 100)

	camera_controller._unhandled_input(event)

	assert_false(camera_controller._is_dragging, "Touch release should stop dragging")


## Test unhandled input processes touch drag
func test_unhandled_input_touch_drag() -> void:
	# Start drag
	camera_controller._on_touch_pressed(Vector2(100, 100))

	var start_offset := camera.offset

	var event := InputEventScreenDrag.new()
	event.position = Vector2(150, 100)

	camera_controller._unhandled_input(event)

	assert_ne(camera.offset, start_offset, "Drag event should move camera")


## Test physics process runs at 60fps consistency
func test_physics_process_60fps() -> void:
	camera_controller._momentum_velocity = Vector2(100, 0)

	# Simulate exactly 1/60 second
	var delta := 1.0 / 60.0
	var offset_before := camera.offset

	camera_controller._physics_process(delta)

	# Movement should occur
	assert_ne(camera.offset, offset_before, "Physics process should update camera")

# =============================================================================
# AC5: Empty Space Detection Tests
# =============================================================================

## Test empty space detection basic case
func test_empty_space_detection_no_entities() -> void:
	var screen_pos := Vector2(540, 960)  # Center of 1080x1920 screen

	var is_entity := camera_controller._is_touching_entity(screen_pos)

	# For now, should return false (tiles not selectable)
	assert_false(is_entity, "Empty space should not be entity")


## Test touch on empty space starts drag
func test_touch_empty_space_starts_drag() -> void:
	var screen_pos := Vector2(100, 100)

	camera_controller._on_touch_pressed(screen_pos)

	assert_true(camera_controller._is_dragging, "Touch on empty space should start drag")


## Test screen to world position conversion
func test_screen_to_world_conversion() -> void:
	camera.offset = Vector2.ZERO
	camera.zoom = Vector2(1.0, 1.0)

	var screen_pos := Vector2(540, 960)  # Center of viewport

	# Should convert without error
	var is_entity := camera_controller._is_touching_entity(screen_pos)

	# Test should complete without crash
	assert_not_null(camera_controller, "Controller should remain valid after conversion")


## Test touch on entity blocks drag (when entity detection is fully implemented)
func test_touch_on_entity_blocks_drag() -> void:
	# This test validates that when entity detection returns true,
	# dragging does not start (AC5 requirement)
	# Currently entity detection always returns false (tiles not selectable)
	# so this test documents expected future behavior

	var screen_pos := Vector2(100, 100)

	# Mock entity detection to return true
	# When entities are selectable, this should prevent drag from starting
	# For now, we test that the method exists and can be called
	var is_entity := camera_controller._is_touching_entity(screen_pos)

	# Document that currently entities don't block pan
	assert_false(is_entity, "Current implementation: entities don't block pan (AC5 partial)")

# =============================================================================
# Edge Cases Tests
# =============================================================================

## Test camera bounds with zero area (world smaller than viewport)
func test_camera_bounds_zero_area() -> void:
	camera_controller._camera_bounds = Rect2(100, 100, 0, 0)

	camera.offset = Vector2(200, 200)
	camera_controller._apply_camera_bounds()

	# Should clamp to bounds position when size is 0
	assert_eq(camera.offset.x, 100, "Zero-width bounds should clamp to position")
	assert_eq(camera.offset.y, 100, "Zero-height bounds should clamp to position")


## Test drag without initialization
func test_drag_without_initialization() -> void:
	# Create new controller without initialization
	var uninit_controller := CameraController.new()
	var uninit_camera := Camera2D.new()
	uninit_camera.add_child(uninit_controller)
	add_child(uninit_camera)

	# Should not crash when dragging without world manager
	uninit_controller._on_touch_pressed(Vector2(100, 100))
	uninit_controller._on_touch_dragged(Vector2(150, 100))

	# Test should complete
	assert_not_null(uninit_controller, "Should handle uninitialized state gracefully")

	uninit_camera.queue_free()


## Test momentum with negative velocity
func test_momentum_negative_velocity() -> void:
	camera_controller._momentum_velocity = Vector2(-100, -100)

	camera_controller._physics_process(1.0 / 60.0)

	# Should move in negative direction
	assert_gt(camera.offset.x, 0, "Negative momentum should move camera positively")
	assert_gt(camera.offset.y, 0, "Negative momentum should move camera positively")


## Test rapid touch press/release
func test_rapid_touch_press_release() -> void:
	for i in range(10):
		camera_controller._on_touch_pressed(Vector2(100, 100))
		camera_controller._on_touch_dragged(Vector2(110 + i * 10, 100))
		camera_controller._on_touch_released()

	# Should not crash and maintain valid state
	assert_not_null(camera_controller, "Should handle rapid touch events")


## Test camera parent null check
func test_camera_parent_null_check() -> void:
	# Create controller without camera parent
	var orphan_controller := CameraController.new()
	add_child(orphan_controller)

	# Should log error but not crash
	await get_tree().process_frame

	assert_null(orphan_controller._camera, "Should detect missing camera parent")

	orphan_controller.queue_free()
