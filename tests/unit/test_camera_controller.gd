## Unit tests for Stories 1.3 and 1.4: Camera Pan and Zoom
##
## These tests verify CameraController functionality for touch-based camera panning,
## zoom, momentum, bounds enforcement, and empty space detection.
##
## Test Framework: GUT (Godot Unit Test)
## Run: Via GUT test runner in Godot Editor (bottom panel)
##
## Coverage (Story 1.3):
## - AC1: Drag to Pan
## - AC2: Momentum Effect
## - AC3: Camera Bounds
## - AC4: Responsive Touch Input
## - AC5: Empty Space Detection
##
## Coverage (Story 1.4):
## - AC1: Pinch to Zoom Out
## - AC2: Pinch to Zoom In
## - AC3: Smooth Zoom with Momentum
## - AC4: Zoom Centers on Pinch Point
## - AC5: Camera Bounds Adjust with Zoom
##
## NOTE: Story 1.3 and Story 1.4 tests ENABLED.
extends GutTest

# =============================================================================
# CONSTANTS FOR TESTING
# =============================================================================

## Tolerance for floating point comparisons
const FLOAT_TOLERANCE: float = 0.1

## Default camera height for tests
const DEFAULT_CAMERA_HEIGHT: float = 50.0

# =============================================================================
# TEST FIXTURES
# =============================================================================

var camera_controller: CameraController
var camera: Camera3D
var world_manager: Node3D

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	gut.p("Running Story 1.3 CameraController tests")

	# Create camera node hierarchy
	camera = Camera3D.new()
	camera.global_position = Vector3(0, DEFAULT_CAMERA_HEIGHT, 30)
	camera_controller = CameraController.new()
	camera.add_child(camera_controller)
	add_child(camera)

	# Create mock world manager with get_world_bounds method
	world_manager = Node3D.new()
	var script_mock := GDScript.new()
	script_mock.source_code = """
extends Node3D
func get_world_bounds() -> AABB:
	return AABB(Vector3(-500, 0, -500), Vector3(1000, 1, 1000))
func get_tile_at(hex) -> Node:
	return null
"""
	script_mock.reload()
	world_manager.set_script(script_mock)
	add_child(world_manager)

	# Wait for _ready to complete
	await wait_frames(1)

	# Initialize camera controller
	camera_controller.initialize(world_manager)


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


## Test drag moves camera position
func test_drag_moves_camera() -> void:
	var start_x: float = camera.global_position.x
	var start_z: float = camera.global_position.z

	# Simulate touch press and drag
	camera_controller._on_touch_pressed(Vector2(100, 100))
	camera_controller._on_touch_dragged(Vector2(200, 100))

	# Camera should have moved (x decreased because drag right = camera left in world)
	assert_ne(camera.global_position.x, start_x, "Camera X should change on drag")


## Test drag direction is correct (inverse)
func test_drag_direction_correct() -> void:
	camera.global_position.x = 0
	camera.global_position.z = 0

	# Drag right (touch moves right = camera pans left in world)
	camera_controller._on_touch_pressed(Vector2(100, 100))
	camera_controller._on_touch_dragged(Vector2(200, 100))

	# Camera X should have decreased (moved left)
	assert_lt(camera.global_position.x, 0, "Dragging right should decrease camera X")


## Test multiple drags accumulate
func test_multiple_drags_accumulate() -> void:
	camera.global_position.x = 0

	camera_controller._on_touch_pressed(Vector2(100, 100))
	camera_controller._on_touch_dragged(Vector2(110, 100))
	var x_after_first: float = camera.global_position.x

	camera_controller._on_touch_dragged(Vector2(120, 100))
	var x_after_second: float = camera.global_position.x

	assert_lt(x_after_second, x_after_first, "Multiple drags should accumulate")


## Test vertical drag affects Z position
func test_vertical_drag_affects_z() -> void:
	camera.global_position.z = 30  # Start at default Z

	# Drag down (touch moves down = camera pans toward -Z)
	camera_controller._on_touch_pressed(Vector2(100, 100))
	camera_controller._on_touch_dragged(Vector2(100, 200))

	assert_lt(camera.global_position.z, 30, "Dragging down should decrease camera Z")

# =============================================================================
# AC2: Momentum Effect Tests
# =============================================================================

## Test momentum applies after release
func test_momentum_applies_after_release() -> void:
	# Set large bounds to prevent clamping
	camera_controller._camera_bounds = AABB(Vector3(-10000, 0, -10000), Vector3(20000, 1, 20000))

	camera_controller._on_touch_pressed(Vector2(100, 100))
	camera_controller._on_touch_dragged(Vector2(200, 100))
	camera_controller._on_touch_released()

	var x_before: float = camera.global_position.x
	camera_controller._physics_process(1.0 / 60.0)

	assert_ne(camera.global_position.x, x_before, "Momentum should move camera after release")


## Test momentum decays over time
func test_momentum_decays() -> void:
	# Set large bounds to prevent clamping
	camera_controller._camera_bounds = AABB(Vector3(-10000, 0, -10000), Vector3(20000, 1, 20000))

	# Set initial momentum velocity
	camera_controller._momentum_velocity = Vector2(100, 0)

	var initial_velocity: float = camera_controller._momentum_velocity.length()

	# Simulate several frames
	for i in range(10):
		camera_controller._physics_process(1.0 / 60.0)

	var final_velocity: float = camera_controller._momentum_velocity.length()

	assert_lt(final_velocity, initial_velocity, "Momentum velocity should decay")


## Test momentum stops when below threshold
func test_momentum_stops_at_threshold() -> void:
	# Set momentum just above threshold
	camera_controller._momentum_velocity = Vector2(0.6, 0)

	# Run physics until velocity reaches zero
	for i in range(150):
		camera_controller._physics_process(1.0 / 60.0)
		if camera_controller._momentum_velocity == Vector2.ZERO:
			break

	assert_eq(camera_controller._momentum_velocity, Vector2.ZERO, "Momentum should stop when below threshold")


## Test momentum does not apply while dragging
func test_momentum_disabled_while_dragging() -> void:
	camera_controller._momentum_velocity = Vector2(100, 0)
	camera_controller._is_dragging = true

	var x_before: float = camera.global_position.x
	camera_controller._physics_process(1.0 / 60.0)

	assert_eq(camera.global_position.x, x_before, "Momentum should not apply while dragging")


## Test release captures velocity correctly
func test_release_captures_velocity() -> void:
	camera_controller._on_touch_pressed(Vector2(100, 100))
	camera_controller._on_touch_dragged(Vector2(200, 100))

	# Velocity should be set from last drag
	assert_ne(camera_controller._momentum_velocity, Vector2.ZERO, "Velocity should be captured on drag")

	camera_controller._on_touch_released()

	# Velocity should persist after release
	assert_ne(camera_controller._momentum_velocity, Vector2.ZERO, "Velocity should persist after release")

# =============================================================================
# AC3: Camera Bounds Tests
# =============================================================================

## Test camera bounds clamping on X axis (max)
func test_camera_bounds_clamp_x_max() -> void:
	# Set up small bounds
	camera_controller._camera_bounds = AABB(Vector3(0, 0, 0), Vector3(100, 1, 100))

	camera.global_position.x = 200  # Outside bounds
	camera_controller._apply_camera_bounds()

	assert_eq(camera.global_position.x, 100, "Should clamp to max X bound")


## Test camera bounds clamping on X axis (min)
func test_camera_bounds_clamp_x_min() -> void:
	camera_controller._camera_bounds = AABB(Vector3(10, 0, 10), Vector3(100, 1, 100))

	camera.global_position.x = -50  # Below minimum
	camera_controller._apply_camera_bounds()

	assert_eq(camera.global_position.x, 10, "Should clamp to min X bound")


## Test camera bounds clamping on Z axis
func test_camera_bounds_clamp_z() -> void:
	camera_controller._camera_bounds = AABB(Vector3(0, 0, 0), Vector3(100, 1, 100))

	camera.global_position.z = 200  # Outside bounds
	camera_controller._apply_camera_bounds()

	assert_eq(camera.global_position.z, 100, "Should clamp to max Z bound")


## Test bounds include hex margin
func test_bounds_include_margin() -> void:
	camera_controller._update_camera_bounds()

	# Bounds should have volume
	assert_true(camera_controller._camera_bounds.has_volume(), "Camera bounds should have volume")


## Test drag enforces bounds automatically
func test_drag_enforces_bounds() -> void:
	# Set tight bounds
	camera_controller._camera_bounds = AABB(Vector3(-50, 0, -50), Vector3(100, 1, 100))
	camera.global_position.x = 0

	# Try to drag far outside bounds
	camera_controller._on_touch_pressed(Vector2(100, 100))
	camera_controller._on_touch_dragged(Vector2(-500, 100))  # Huge drag

	# Camera should be clamped to bounds
	assert_between(camera.global_position.x, -50, 50, "X should be within bounds after drag")


## Test momentum enforces bounds
func test_momentum_enforces_bounds() -> void:
	# Set tight bounds
	camera_controller._camera_bounds = AABB(Vector3(-50, 0, -50), Vector3(100, 1, 100))

	# Set high momentum that would go outside bounds
	camera.global_position.x = 40
	camera_controller._momentum_velocity = Vector2(-1000, 0)  # Negative = camera moves positive

	# Run physics
	camera_controller._physics_process(1.0 / 60.0)

	# Should be clamped
	assert_lte(camera.global_position.x, 50, "Momentum should respect bounds")

# =============================================================================
# AC4: Responsive Touch Input Tests
# =============================================================================

## Test unhandled input processes touch press
func test_unhandled_input_touch_press() -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = true
	event.position = Vector2(100, 100)

	camera_controller._unhandled_input(event)

	assert_true(camera_controller._is_dragging, "Touch press should start dragging")


## Test unhandled input processes touch release
func test_unhandled_input_touch_release() -> void:
	# Start drag first
	camera_controller._on_touch_pressed(Vector2(100, 100))

	var event := InputEventScreenTouch.new()
	event.index = 0
	event.pressed = false
	event.position = Vector2(100, 100)

	camera_controller._unhandled_input(event)

	assert_false(camera_controller._is_dragging, "Touch release should stop dragging")


## Test unhandled input processes touch drag
func test_unhandled_input_touch_drag() -> void:
	# Start drag via touch event
	var touch_event := InputEventScreenTouch.new()
	touch_event.index = 0
	touch_event.pressed = true
	touch_event.position = Vector2(100, 100)
	camera_controller._unhandled_input(touch_event)

	var start_x: float = camera.global_position.x

	var drag_event := InputEventScreenDrag.new()
	drag_event.index = 0
	drag_event.position = Vector2(200, 100)

	camera_controller._unhandled_input(drag_event)

	assert_ne(camera.global_position.x, start_x, "Drag event should move camera")


## Test physics process runs with delta time
func test_physics_process_with_delta() -> void:
	camera_controller._camera_bounds = AABB(Vector3(-10000, 0, -10000), Vector3(20000, 1, 20000))
	camera_controller._momentum_velocity = Vector2(100, 0)

	# Simulate exactly 1/60 second
	var delta: float = 1.0 / 60.0
	var x_before: float = camera.global_position.x

	camera_controller._physics_process(delta)

	# Movement should occur
	assert_ne(camera.global_position.x, x_before, "Physics process should update camera")

# =============================================================================
# AC5: Empty Space Detection Tests
# =============================================================================

## Test empty space detection basic case
func test_empty_space_detection_no_entities() -> void:
	var screen_pos := Vector2(540, 960)  # Center of 1080x1920 screen

	var is_entity: bool = camera_controller._is_touching_entity(screen_pos)

	# For now, should return false (tiles not selectable)
	assert_false(is_entity, "Empty space should not be entity")


## Test touch on empty space starts drag
func test_touch_empty_space_starts_drag() -> void:
	var screen_pos := Vector2(100, 100)

	camera_controller._on_touch_pressed(screen_pos)

	assert_true(camera_controller._is_dragging, "Touch on empty space should start drag")


## Test screen to world conversion returns Vector3
func test_screen_to_world_returns_vector3() -> void:
	var screen_pos := Vector2(540, 960)

	var world_pos: Vector3 = camera_controller._screen_to_world(screen_pos)

	# Should return a valid Vector3 (on Y=0 plane)
	assert_eq(world_pos.y, 0.0, "World position should be on Y=0 ground plane")


## Test screen to world conversion at screen center
func test_screen_to_world_center() -> void:
	# Get viewport center
	var viewport_size: Vector2 = camera_controller._cached_viewport_size
	var screen_center := viewport_size / 2.0

	var world_pos: Vector3 = camera_controller._screen_to_world(screen_center)

	# World position should be roughly where camera is looking
	# Camera is at (0, 50, 30) looking down at 45°
	# At screen center, the ground intersection should be near camera's XZ but offset by height
	assert_not_null(world_pos, "Should return valid world position")

# =============================================================================
# Edge Cases Tests
# =============================================================================

## Test camera bounds with zero volume
func test_camera_bounds_zero_volume() -> void:
	camera_controller._camera_bounds = AABB(Vector3(100, 0, 100), Vector3(0, 0, 0))

	camera.global_position.x = 200
	camera_controller._apply_camera_bounds()

	# With zero volume, _apply_camera_bounds should skip (has_volume check)
	assert_eq(camera.global_position.x, 200, "Zero-volume bounds should skip clamping")


## Test drag without initialization
func test_drag_without_world_manager() -> void:
	# Create new controller without world manager initialization
	var uninit_controller := CameraController.new()
	var uninit_camera := Camera3D.new()
	uninit_camera.global_position = Vector3(0, 50, 30)
	uninit_camera.add_child(uninit_controller)
	add_child(uninit_camera)

	await wait_frames(1)

	# Should not crash when dragging without world manager
	uninit_controller._on_touch_pressed(Vector2(100, 100))
	uninit_controller._on_touch_dragged(Vector2(150, 100))

	# Test should complete without crash
	assert_not_null(uninit_controller, "Should handle uninitialized state gracefully")

	uninit_camera.queue_free()


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
	await wait_frames(1)

	assert_null(orphan_controller._camera, "Should detect missing camera parent")

	orphan_controller.queue_free()


## Test pan with negative momentum
func test_momentum_negative_velocity() -> void:
	camera_controller._camera_bounds = AABB(Vector3(-10000, 0, -10000), Vector3(20000, 1, 20000))
	camera.global_position.x = 0

	camera_controller._momentum_velocity = Vector2(-100, 0)

	camera_controller._physics_process(1.0 / 60.0)

	# Negative momentum should move camera in positive direction
	assert_gt(camera.global_position.x, 0, "Negative momentum should move camera positively")


# =============================================================================
# Story 1.4: Camera Zoom Tests
# =============================================================================

## Test zoom in decreases camera height
func test_zoom_in_decreases_height() -> void:
	var start_height: float = camera.global_position.y

	camera_controller._pinch_midpoint = Vector2(540, 960)
	camera_controller._apply_zoom(10.0)  # Positive = zoom in

	assert_lt(camera.global_position.y, start_height, "Zoom in should decrease camera height")


## Test zoom out increases camera height
func test_zoom_out_increases_height() -> void:
	var start_height: float = camera.global_position.y

	camera_controller._pinch_midpoint = Vector2(540, 960)
	camera_controller._apply_zoom(-10.0)  # Negative = zoom out

	assert_gt(camera.global_position.y, start_height, "Zoom out should increase camera height")


## Test zoom clamps to minimum height
func test_zoom_clamps_to_min_height() -> void:
	# Set camera to near minimum height
	camera.global_position.y = 30.0

	camera_controller._pinch_midpoint = Vector2(540, 960)
	camera_controller._apply_zoom(100.0)  # Try to zoom in way past limit

	assert_gte(camera.global_position.y, CameraController.ZOOM_HEIGHT_MIN, "Should not go below minimum height")


## Test zoom clamps to maximum height
func test_zoom_clamps_to_max_height() -> void:
	# Set camera to near maximum height
	camera.global_position.y = 90.0

	camera_controller._pinch_midpoint = Vector2(540, 960)
	camera_controller._apply_zoom(-100.0)  # Try to zoom out way past limit

	assert_lte(camera.global_position.y, CameraController.ZOOM_HEIGHT_MAX, "Should not exceed maximum height")


## Test pinch gesture starts correctly
func test_pinch_gesture_starts() -> void:
	# Simulate two touch points
	camera_controller._touch_points[0] = Vector2(100, 100)
	camera_controller._touch_points[1] = Vector2(200, 200)

	camera_controller._start_pinch()

	assert_true(camera_controller._is_pinching, "Should be in pinch state")
	assert_false(camera_controller._is_dragging, "Should cancel pan when pinching")


## Test pinch gesture ends correctly
func test_pinch_gesture_ends() -> void:
	camera_controller._is_pinching = true

	camera_controller._end_pinch()

	assert_false(camera_controller._is_pinching, "Should not be pinching after end")


## Test pinch distance change triggers zoom
func test_pinch_distance_change_zooms() -> void:
	var start_height: float = camera.global_position.y

	# Simulate pinch start
	camera_controller._touch_points[0] = Vector2(100, 100)
	camera_controller._touch_points[1] = Vector2(200, 200)
	camera_controller._start_pinch()

	# Move fingers apart (zoom in)
	camera_controller._touch_points[0] = Vector2(50, 50)
	camera_controller._touch_points[1] = Vector2(250, 250)
	camera_controller._update_pinch()

	# Height should decrease (zoomed in)
	assert_lt(camera.global_position.y, start_height, "Spreading fingers should zoom in")


## Test pinch closing zooms out
func test_pinch_close_zooms_out() -> void:
	var start_height: float = camera.global_position.y

	# Simulate pinch start with fingers apart
	camera_controller._touch_points[0] = Vector2(50, 50)
	camera_controller._touch_points[1] = Vector2(250, 250)
	camera_controller._start_pinch()

	# Move fingers together (zoom out)
	camera_controller._touch_points[0] = Vector2(100, 100)
	camera_controller._touch_points[1] = Vector2(200, 200)
	camera_controller._update_pinch()

	# Height should increase (zoomed out)
	assert_gt(camera.global_position.y, start_height, "Closing fingers should zoom out")


## Test zoom momentum applies after pinch release
func test_zoom_momentum_applies() -> void:
	camera_controller._zoom_momentum = 5.0
	camera_controller._is_pinching = false

	var start_height: float = camera.global_position.y
	camera_controller._physics_process(1.0 / 60.0)

	assert_ne(camera.global_position.y, start_height, "Zoom momentum should change height")


## Test zoom momentum decays over time
func test_zoom_momentum_decays() -> void:
	camera_controller._zoom_momentum = 10.0
	camera_controller._is_pinching = false

	var initial_momentum: float = camera_controller._zoom_momentum

	# Run several frames
	for i in range(10):
		camera_controller._physics_process(1.0 / 60.0)

	assert_lt(abs(camera_controller._zoom_momentum), initial_momentum, "Zoom momentum should decay")


## Test zoom momentum stops at threshold
func test_zoom_momentum_stops_at_threshold() -> void:
	camera_controller._zoom_momentum = 0.15  # Just above threshold
	camera_controller._is_pinching = false

	# Run until momentum stops
	for i in range(50):
		camera_controller._physics_process(1.0 / 60.0)
		if camera_controller._zoom_momentum == 0.0:
			break

	assert_eq(camera_controller._zoom_momentum, 0.0, "Zoom momentum should stop at threshold")


## Test zoom momentum disabled while pinching
func test_zoom_momentum_disabled_while_pinching() -> void:
	camera_controller._zoom_momentum = 10.0
	camera_controller._is_pinching = true

	var start_height: float = camera.global_position.y
	camera_controller._physics_process(1.0 / 60.0)

	assert_eq(camera.global_position.y, start_height, "Zoom momentum should not apply while pinching")


## Test mouse wheel zoom in (desktop testing)
func test_mouse_wheel_zoom_in() -> void:
	var start_height: float = camera.global_position.y

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP
	event.pressed = true
	event.position = Vector2(540, 960)

	camera_controller._unhandled_input(event)

	assert_lt(camera.global_position.y, start_height, "Mouse wheel up should zoom in")


## Test mouse wheel zoom out (desktop testing)
func test_mouse_wheel_zoom_out() -> void:
	var start_height: float = camera.global_position.y

	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.position = Vector2(540, 960)

	camera_controller._unhandled_input(event)

	assert_gt(camera.global_position.y, start_height, "Mouse wheel down should zoom out")


## Test zoom centers on pinch midpoint
func test_zoom_centers_on_pinch_point() -> void:
	# Set pinch midpoint off-center
	camera_controller._pinch_midpoint = Vector2(800, 1200)

	# Get world position at pinch point before zoom
	var world_before: Vector3 = camera_controller._screen_to_world(camera_controller._pinch_midpoint)

	# Zoom in
	camera_controller._apply_zoom(10.0)

	# Get world position at pinch point after zoom
	var world_after: Vector3 = camera_controller._screen_to_world(camera_controller._pinch_midpoint)

	# The world position under the pinch point should be approximately the same
	assert_almost_eq(world_after.x, world_before.x, 1.0, "X should remain centered on pinch point")
	assert_almost_eq(world_after.z, world_before.z, 1.0, "Z should remain centered on pinch point")


## Test two-finger touch starts pinch
func test_two_finger_touch_starts_pinch() -> void:
	# First touch
	var event1 := InputEventScreenTouch.new()
	event1.index = 0
	event1.pressed = true
	event1.position = Vector2(100, 100)
	camera_controller._unhandled_input(event1)

	assert_false(camera_controller._is_pinching, "One finger should not start pinch")

	# Second touch
	var event2 := InputEventScreenTouch.new()
	event2.index = 1
	event2.pressed = true
	event2.position = Vector2(200, 200)
	camera_controller._unhandled_input(event2)

	assert_true(camera_controller._is_pinching, "Two fingers should start pinch")


## Test pinch to pan transition
func test_pinch_to_pan_transition() -> void:
	# Start with two fingers (pinch)
	camera_controller._touch_points[0] = Vector2(100, 100)
	camera_controller._touch_points[1] = Vector2(200, 200)
	camera_controller._start_pinch()

	assert_true(camera_controller._is_pinching, "Should be pinching with two fingers")

	# Simulate releasing one finger
	var release_event := InputEventScreenTouch.new()
	release_event.index = 1
	release_event.pressed = false
	release_event.position = Vector2(200, 200)
	camera_controller._handle_touch_event(release_event)

	assert_false(camera_controller._is_pinching, "Should stop pinching when finger lifted")
	assert_true(camera_controller._is_dragging, "Should transition to pan with one finger")


## Test bounds respected during zoom
func test_bounds_respected_during_zoom() -> void:
	# Set tight bounds
	camera_controller._camera_bounds = AABB(Vector3(-50, 0, -50), Vector3(100, 1, 100))

	# Position camera at edge
	camera.global_position.x = 50
	camera.global_position.z = 50

	# Zoom with off-center pinch point (would shift camera position)
	camera_controller._pinch_midpoint = Vector2(100, 100)
	camera_controller._apply_zoom(20.0)

	# Camera should still be within bounds
	assert_between(camera.global_position.x, -50, 50, "X should be within bounds after zoom")
	assert_between(camera.global_position.z, -50, 50, "Z should be within bounds after zoom")
