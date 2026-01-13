## Camera pan and zoom controller for touch-based camera movement
##
## Handles touch input for panning, pinch-to-zoom, momentum, and bounds enforcement.
## Designed for 3D camera (Camera3D) with isometric view and touch controls.
## Supports single-touch pan and two-finger pinch zoom with smooth momentum.
##
## IMPORTANT: This uses Camera3D, NOT Camera2D. Key differences:
## - Pan: Adjusts global_position.x/z (not offset)
## - Zoom: Adjusts global_position.y height (not zoom property)
## - Bounds: Uses AABB with manual clamping (not limit_* properties)
## - Screen→World: Raycast to Y=0 plane (not get_canvas_transform())
##
## Architecture: scripts/camera/camera_controller.gd
## Stories: 1-0 (Camera3D Setup), 1-3 (Pan), 1-4 (Zoom)
class_name CameraController
extends Node

# Configuration
const PAN_SPEED: float = 1.0  ## Multiplier for drag sensitivity
const MOMENTUM_DECAY: float = 0.92  ## Decay per frame (0.92 = ~8% loss)
const MOMENTUM_MIN_THRESHOLD: float = 0.5  ## Stop when velocity < this
const BOUNDS_MARGIN_HEX: int = 1  ## Hex tiles beyond world edge

# Zoom Configuration (Story 1.4)
# For Camera3D, zoom is controlled via camera height (Y position)
# Lower Y = zoomed in (closer), Higher Y = zoomed out (farther)
const ZOOM_HEIGHT_MIN: float = 25.0  ## Minimum height (maximum zoom in)
const ZOOM_HEIGHT_MAX: float = 200.0  ## Maximum height (maximum zoom out)
const ZOOM_HEIGHT_DEFAULT: float = 125.0  ## Default camera height
const ZOOM_SPEED: float = 0.5  ## Height change per pixel of pinch distance
const ZOOM_MOMENTUM_DECAY: float = 0.90  ## Decay per frame
const ZOOM_MOMENTUM_MIN_THRESHOLD: float = 0.1  ## Stop when velocity < this

# Pan calculation constants
const PAN_HEIGHT_NORMALIZATION: float = 50.0  ## Height value for pan speed normalization
const PAN_FEEL_MULTIPLIER: float = 0.5  ## Multiplier for reasonable pan feel
const TARGET_FPS: float = 60.0  ## Target frame rate for frame-independent calculations

# Default bounds (used when world bounds unavailable)
const DEFAULT_BOUNDS_ORIGIN: Vector3 = Vector3(-500.0, 0.0, -1000.0)
const DEFAULT_BOUNDS_SIZE: Vector3 = Vector3(1000.0, 1.0, 2000.0)

# Pan State
var _is_dragging: bool = false
var _drag_start_pos: Vector2
var _drag_previous_pos: Vector2
var _momentum_velocity: Vector2 = Vector2.ZERO
var _camera_bounds: AABB  # 3D bounds (will be properly used in Stories 1-3 and 1-4)

# Zoom State (Story 1.4)
var _is_pinching: bool = false
var _touch_points: Dictionary = {}  ## int (index) -> Vector2 (position)
var _previous_pinch_distance: float = 0.0
var _zoom_momentum: float = 0.0
var _pinch_midpoint: Vector2 = Vector2.ZERO

# References
var _camera: Camera3D  # Changed from Camera2D in Story 1-0
var _world_manager: Node  # WorldManager reference (typed as Node for flexibility)

# Cached values for performance
var _cached_viewport_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("camera_controllers")
	_camera = get_parent() as Camera3D
	if _camera == null:
		GameLogger.error("Camera", "CameraController must be child of Camera3D")
		return

	# Cache viewport size for performance
	_cached_viewport_size = get_viewport().get_visible_rect().size

	GameLogger.info("Camera", "Camera3D controller initialized (Story 1-0)")


func initialize(world_manager: Node) -> void:
	"""Initialize with world manager reference and update bounds"""
	_world_manager = world_manager
	_update_camera_bounds()
	GameLogger.info("Camera", "Camera bounds initialized")


func _unhandled_input(event: InputEvent) -> void:
	"""Handle touch input for camera panning and zooming (Story 1.3 + 1.4)"""
	if event is InputEventScreenTouch:
		_handle_touch_event(event)
		get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		_handle_drag_event(event)
		get_viewport().set_input_as_handled()

	# Desktop testing: Mouse wheel zoom
	elif event is InputEventMouseButton:
		if event.pressed:
			_pinch_midpoint = event.position  # Use mouse position as zoom center
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_apply_zoom(0.1)  # Zoom in
				get_viewport().set_input_as_handled()
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_apply_zoom(-0.1)  # Zoom out
				get_viewport().set_input_as_handled()


func _handle_touch_event(event: InputEventScreenTouch) -> void:
	"""Handle touch press/release events for multi-touch support (Story 1.4)"""
	if event.pressed:
		# Touch added
		_touch_points[event.index] = event.position

		if _touch_points.size() == 2:
			# Transition to pinch
			_start_pinch()
		elif _touch_points.size() == 1:
			# Single touch - start pan (Story 1.3)
			_on_touch_pressed(event.position)
	else:
		# Touch released
		_touch_points.erase(event.index)

		if _touch_points.size() == 1:
			# Transition from pinch to pan
			_end_pinch()
			# Restart pan with remaining touch
			var remaining_pos = _touch_points.values()[0]
			_on_touch_pressed(remaining_pos)
		elif _touch_points.size() == 0:
			# All touches released
			_end_pinch()
			_on_touch_released()


func _handle_drag_event(event: InputEventScreenDrag) -> void:
	"""Handle touch drag events for pan or pinch (Story 1.4)"""
	_touch_points[event.index] = event.position

	if _touch_points.size() == 2:
		# Two fingers - pinch gesture
		_update_pinch()
	elif _touch_points.size() == 1:
		# One finger - pan gesture (Story 1.3)
		_on_touch_dragged(event.position)


func _start_pinch() -> void:
	"""Start pinch gesture (Story 1.4)"""
	_is_pinching = true
	_is_dragging = false  # Cancel pan
	_momentum_velocity = Vector2.ZERO
	_zoom_momentum = 0.0

	var positions = _touch_points.values()
	_previous_pinch_distance = positions[0].distance_to(positions[1])
	_pinch_midpoint = (positions[0] + positions[1]) / 2.0


func _update_pinch() -> void:
	"""Update pinch gesture (Story 1.4)"""
	if not _is_pinching:
		return

	var positions = _touch_points.values()
	var current_distance = positions[0].distance_to(positions[1])
	var distance_delta = current_distance - _previous_pinch_distance

	# Calculate zoom change
	var zoom_delta = distance_delta * ZOOM_SPEED
	_apply_zoom(zoom_delta)

	# Update pinch midpoint (for centering)
	_pinch_midpoint = (positions[0] + positions[1]) / 2.0

	# Track zoom velocity for momentum
	_zoom_momentum = zoom_delta

	_previous_pinch_distance = current_distance


func _end_pinch() -> void:
	"""End pinch gesture (Story 1.4)"""
	if not _is_pinching:
		return

	_is_pinching = false
	# Zoom momentum already set from last update


func _apply_zoom(zoom_delta: float) -> void:
	"""Apply zoom change via camera height adjustment (Story 1.4)

	Camera3D zoom is achieved by moving the camera closer/farther (Y axis).
	Positive zoom_delta = zoom in (decrease height), Negative = zoom out (increase height).
	Zoom centers on the pinch midpoint (AC4).
	"""
	# Null safety check
	if not _camera:
		return

	# Get world position under pinch point BEFORE zoom change
	var world_before: Vector3 = _screen_to_world(_pinch_midpoint)

	# Calculate new height (inverted: positive delta = zoom in = lower height)
	var current_height: float = _camera.global_position.y
	var new_height: float = current_height - zoom_delta

	# Clamp to zoom bounds
	new_height = clampf(new_height, ZOOM_HEIGHT_MIN, ZOOM_HEIGHT_MAX)

	# Apply new height
	_camera.global_position.y = new_height

	# Get world position under pinch point AFTER zoom change
	var world_after: Vector3 = _screen_to_world(_pinch_midpoint)

	# Adjust camera X/Z to keep pinch point fixed (AC4: Zoom Centers on Pinch Point)
	var offset: Vector3 = world_before - world_after
	_camera.global_position.x += offset.x
	_camera.global_position.z += offset.z

	# Apply bounds clamping after zoom adjustment
	_apply_camera_bounds()

	# Emit zoom event for other systems (e.g., UI, LOD)
	if is_instance_valid(EventBus):
		EventBus.camera_zoomed.emit(new_height)


func _screen_to_world(screen_pos: Vector2) -> Vector3:
	"""Convert screen position to world position via raycast to Y=0 plane (Story 1.3)"""
	# Null safety check
	if not _camera:
		return Vector3.ZERO

	# Get ray from camera through screen position
	var ray_origin: Vector3 = _camera.project_ray_origin(screen_pos)
	var ray_direction: Vector3 = _camera.project_ray_normal(screen_pos)

	# Intersect ray with Y=0 ground plane
	# Plane equation: y = 0
	# Ray equation: P = origin + t * direction
	# Solve for t: origin.y + t * direction.y = 0
	# t = -origin.y / direction.y

	# Avoid division by zero (ray parallel to ground)
	if abs(ray_direction.y) < 0.0001:
		return Vector3(ray_origin.x, 0, ray_origin.z)

	var t: float = -ray_origin.y / ray_direction.y

	# Calculate intersection point
	var world_pos: Vector3 = ray_origin + ray_direction * t
	world_pos.y = 0  # Ensure exactly on ground plane

	return world_pos


func _on_touch_pressed(position: Vector2) -> void:
	"""Handle touch press - start dragging if touching empty space"""
	# Check if touching empty space (not an entity)
	if _is_touching_entity(position):
		return

	_is_dragging = true
	_drag_start_pos = position
	_drag_previous_pos = position
	_momentum_velocity = Vector2.ZERO


func _on_touch_dragged(position: Vector2) -> void:
	"""Handle touch drag - pan camera via position.x/z adjustment (Story 1.3)"""
	if not _is_dragging:
		return

	# Null safety check
	if not _camera:
		return

	# Calculate drag delta in screen space
	var drag_delta: Vector2 = position - _drag_previous_pos

	# Convert screen drag to world movement
	# Pan speed scales with camera height (higher = faster pan to cover more ground)
	var height_factor: float = _camera.global_position.y / PAN_HEIGHT_NORMALIZATION
	var pan_scale: float = PAN_SPEED * height_factor * PAN_FEEL_MULTIPLIER

	# Apply pan to camera position (inverse: drag right = camera moves left in world)
	# For isometric: screen X -> world X, screen Y -> world Z
	_camera.global_position.x -= drag_delta.x * pan_scale
	_camera.global_position.z -= drag_delta.y * pan_scale

	# Apply bounds clamping
	_apply_camera_bounds()

	# Emit pan event for other systems (e.g., minimap)
	if is_instance_valid(EventBus):
		EventBus.camera_panned.emit(_camera.global_position)

	# Track velocity for momentum (in screen space, will convert on release)
	_momentum_velocity = drag_delta * pan_scale

	_drag_previous_pos = position


func _on_touch_released() -> void:
	"""Handle touch release - end dragging, momentum continues"""
	if not _is_dragging:
		return

	_is_dragging = false
	# Momentum velocity already set from last drag


func _physics_process(delta: float) -> void:
	"""Apply momentum decay and movement (Story 1.3 + 1.4)"""
	# Null safety check
	if not _camera:
		return

	# Pan momentum (Story 1.3)
	if not _is_dragging and _momentum_velocity.length() > MOMENTUM_MIN_THRESHOLD:
		# Apply momentum to camera position
		# Momentum velocity is in world units per frame at TARGET_FPS
		_camera.global_position.x -= _momentum_velocity.x * delta * TARGET_FPS
		_camera.global_position.z -= _momentum_velocity.y * delta * TARGET_FPS

		# Apply bounds clamping
		_apply_camera_bounds()

		# Emit pan event for momentum movement
		if is_instance_valid(EventBus):
			EventBus.camera_panned.emit(_camera.global_position)

		# Frame-independent decay: use pow for consistent decay rate regardless of frame rate
		var decay_factor: float = pow(MOMENTUM_DECAY, delta * TARGET_FPS)
		_momentum_velocity *= decay_factor
	elif not _is_dragging:
		_momentum_velocity = Vector2.ZERO

	# Zoom momentum (Story 1.4)
	if not _is_pinching and abs(_zoom_momentum) > ZOOM_MOMENTUM_MIN_THRESHOLD:
		_apply_zoom(_zoom_momentum * delta * TARGET_FPS)
		var zoom_decay_factor: float = pow(ZOOM_MOMENTUM_DECAY, delta * TARGET_FPS)
		_zoom_momentum *= zoom_decay_factor
	elif not _is_pinching:
		_zoom_momentum = 0.0


func _is_touching_entity(screen_pos: Vector2) -> bool:
	"""Check if screen position is touching an interactive entity (Story 1.3 AC5)

	Returns true if touch should be consumed by an entity instead of panning.
	Currently returns false for all positions since no entities are selectable yet.

	TODO (Future Stories): Implement entity selection for:
	- Animals (group: 'animals') - check is_at_position()
	- Buildings (group: 'buildings') - check collision bounds
	- Selectable tiles - check tile.is_selectable if property exists
	"""
	# Null safety check
	if not _camera:
		return false

	# Convert screen to world position via raycast
	var world_pos: Vector3 = _screen_to_world(screen_pos)

	# Check for tiles at position (placeholder for future selectability)
	var hex := HexGrid.world_to_hex(world_pos)
	if _world_manager and _world_manager.has_method("get_tile_at"):
		var tile = _world_manager.get_tile_at(hex)
		if tile:
			# Tiles are not selectable in current implementation (Story 1.3)
			# Future: return tile.is_selectable if tile.has_method("is_selectable")
			pass

	# No interactive entities implemented yet - always allow pan
	return false


func _apply_camera_bounds() -> void:
	"""Clamp camera position to world bounds (Story 1.3)"""
	# Null safety check
	if not _camera:
		return

	# Skip if bounds not set or invalid
	if not _camera_bounds.has_volume():
		return

	# Clamp camera X position to bounds
	_camera.global_position.x = clampf(
		_camera.global_position.x,
		_camera_bounds.position.x,
		_camera_bounds.end.x
	)

	# Clamp camera Z position to bounds
	_camera.global_position.z = clampf(
		_camera.global_position.z,
		_camera_bounds.position.z,
		_camera_bounds.end.z
	)

	# Note: Y (height) is not clamped here - that's handled by zoom (Story 1.4)


func _update_camera_bounds() -> void:
	"""Calculate camera bounds based on world size, viewport, and zoom level (Story 1.3 + 1.4)"""
	if not _world_manager:
		GameLogger.warn("Camera", "No world manager for bounds calculation")
		return

	# Null safety check
	if not _camera:
		GameLogger.warn("Camera", "No camera for bounds calculation")
		return

	var world_bounds := AABB()
	if _world_manager.has_method("get_world_bounds"):
		world_bounds = _world_manager.get_world_bounds()
	else:
		GameLogger.warn("Camera", "World manager has no get_world_bounds method")

	if not world_bounds.has_volume():
		GameLogger.warn("Camera", "World bounds empty, using default")
		world_bounds = AABB(DEFAULT_BOUNDS_ORIGIN, DEFAULT_BOUNDS_SIZE)

	# Add margin (grow in XZ plane, keep Y unchanged)
	var margin := GameConstants.HEX_SIZE * BOUNDS_MARGIN_HEX
	world_bounds = world_bounds.grow(margin)

	# Update cached viewport size (in case of window resize)
	_cached_viewport_size = get_viewport().get_visible_rect().size

	# TODO (Story 1-3/1-4): Implement proper 3D camera bounds calculation
	# For now, just store the world bounds directly
	_camera_bounds = world_bounds
