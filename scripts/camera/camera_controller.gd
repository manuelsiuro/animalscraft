class_name CameraController
extends Node

## Camera pan controller for touch-based camera movement
##
## Handles touch input for panning, momentum, and bounds enforcement.
## Designed for 2D camera (Camera2D) with touch controls.

# Configuration
const PAN_SPEED: float = 1.0  ## Multiplier for drag sensitivity
const MOMENTUM_DECAY: float = 0.92  ## Decay per frame (0.92 = ~8% loss)
const MOMENTUM_MIN_THRESHOLD: float = 0.5  ## Stop when velocity < this
const BOUNDS_MARGIN_HEX: int = 1  ## Hex tiles beyond world edge

# State
var _is_dragging: bool = false
var _drag_start_pos: Vector2
var _drag_previous_pos: Vector2
var _momentum_velocity: Vector2 = Vector2.ZERO
var _camera_bounds: Rect2

# References
var _camera: Camera2D
var _world_manager: Node  # WorldManager reference (typed as Node for flexibility)

# Cached values for performance
var _cached_viewport_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("camera_controllers")
	_camera = get_parent() as Camera2D
	if _camera == null:
		GameLogger.error("Camera", "CameraController must be child of Camera2D")
		return

	# Cache viewport size for performance
	_cached_viewport_size = get_viewport().get_visible_rect().size

	GameLogger.info("Camera", "CameraController initialized")


func initialize(world_manager: Node) -> void:
	"""Initialize with world manager reference and update bounds"""
	_world_manager = world_manager
	_update_camera_bounds()
	GameLogger.info("Camera", "Camera bounds initialized")


func _unhandled_input(event: InputEvent) -> void:
	"""Handle touch input for camera panning (mouse converted to touch via emulation)"""
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_touch_pressed(event.position)
		else:
			_on_touch_released()
		get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		_on_touch_dragged(event.position)
		get_viewport().set_input_as_handled()


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
	"""Handle touch drag - pan camera and track velocity"""
	if not _is_dragging:
		return

	# Null safety check
	if not _camera:
		return

	# Calculate drag delta
	var drag_delta := position - _drag_previous_pos

	# Division by zero protection
	if _camera.zoom.x == 0 or _camera.zoom.y == 0:
		GameLogger.warn("Camera", "Camera zoom is zero, cannot pan")
		return

	# Pan camera by inverse drag (moving touch right = world moves left = camera right)
	_camera.offset -= drag_delta / _camera.zoom * PAN_SPEED

	# Apply bounds
	_apply_camera_bounds()

	# Track velocity for momentum (world space)
	_momentum_velocity = drag_delta / _camera.zoom

	_drag_previous_pos = position


func _on_touch_released() -> void:
	"""Handle touch release - end dragging, momentum continues"""
	if not _is_dragging:
		return

	_is_dragging = false
	# Momentum velocity already set from last drag


func _physics_process(delta: float) -> void:
	"""Apply momentum decay and movement"""
	if _is_dragging:
		return  # No momentum while dragging

	# Null safety check
	if not _camera:
		return

	# Apply momentum
	if _momentum_velocity.length() > MOMENTUM_MIN_THRESHOLD:
		# Frame-independent momentum: scale velocity by delta
		# Velocity is in pixels per frame at 60fps, so we normalize
		_camera.offset -= _momentum_velocity * delta * 60.0
		_apply_camera_bounds()

		# Frame-independent decay: use pow for consistent decay rate regardless of frame rate
		# MOMENTUM_DECAY is per-frame at 60fps, so we adjust for actual delta
		var decay_factor := pow(MOMENTUM_DECAY, delta * 60.0)
		_momentum_velocity *= decay_factor
	else:
		_momentum_velocity = Vector2.ZERO


func _is_touching_entity(screen_pos: Vector2) -> bool:
	"""Check if screen position is touching an interactive entity"""
	# Null safety check
	if not _camera:
		return false

	# Convert screen to world position using cached viewport size
	var world_pos := _camera.get_screen_center_position() + (screen_pos - _cached_viewport_size / 2) / _camera.zoom

	# Check for tiles at position
	var hex := HexGrid.world_to_hex(world_pos)
	if _world_manager and _world_manager.has_method("get_tile_at"):
		var tile = _world_manager.get_tile_at(hex)
		if tile:
			# Future: Check if tile is selectable/interactive
			# For now, tiles are not selectable, so this is false
			return false

	# Future: Check for animals and buildings
	# var animals := get_tree().get_nodes_in_group("animals")
	# for animal in animals:
	#     if animal.is_at_position(world_pos):
	#         return true

	return false


func _apply_camera_bounds() -> void:
	"""Clamp camera position to world bounds"""
	# Null safety check
	if not _camera:
		return

	_camera.offset.x = clamp(_camera.offset.x, _camera_bounds.position.x, _camera_bounds.end.x)
	_camera.offset.y = clamp(_camera.offset.y, _camera_bounds.position.y, _camera_bounds.end.y)


func _update_camera_bounds() -> void:
	"""Calculate camera bounds based on world size and viewport"""
	if not _world_manager:
		GameLogger.warn("Camera", "No world manager for bounds calculation")
		return

	# Null safety check
	if not _camera:
		GameLogger.warn("Camera", "No camera for bounds calculation")
		return

	var world_bounds := Rect2()
	if _world_manager.has_method("get_world_bounds"):
		world_bounds = _world_manager.get_world_bounds()
	else:
		GameLogger.warn("Camera", "World manager has no get_world_bounds method")

	if not world_bounds.has_area():
		GameLogger.warn("Camera", "World bounds empty, using default")
		world_bounds = Rect2(-500, -1000, 1000, 2000)  # Portrait default

	# Add margin
	var margin := GameConstants.HEX_SIZE * BOUNDS_MARGIN_HEX
	world_bounds = world_bounds.grow(margin)

	# Update cached viewport size (in case of window resize)
	_cached_viewport_size = get_viewport().get_visible_rect().size

	# Adjust for viewport size / zoom
	var viewport_world_size := _cached_viewport_size / _camera.zoom

	# Check if world is smaller than viewport
	if world_bounds.size.x < viewport_world_size.x or world_bounds.size.y < viewport_world_size.y:
		# World smaller than viewport - use world bounds directly
		# This allows panning within the small world
		_camera_bounds = world_bounds
	else:
		# World larger than viewport - calculate proper camera bounds
		var half_viewport := viewport_world_size / 2.0
		_camera_bounds = Rect2(
			world_bounds.position + half_viewport,
			world_bounds.size - viewport_world_size
		)
