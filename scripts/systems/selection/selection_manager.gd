## SelectionManager - Manages entity selection state globally.
## Ensures single-selection mode (only one entity selected at a time).
## Handles tap detection and input coordination with camera system.
##
## CRITICAL: Uses _input() NOT _unhandled_input() to guarantee priority over camera.
## This prevents race conditions on slower Android devices.
##
## Architecture: scripts/systems/selection/selection_manager.gd (register as autoload)
## Story: 2-3-implement-animal-selection
## NOTE: No class_name to avoid conflict with autoload singleton
extends Node

# =============================================================================
# STATE
# =============================================================================

## Currently selected animal (null if none)
var _selected_animal: Animal = null

## Tap tracking
var _tap_start_time: int = 0
var _tap_start_position: Vector2 = Vector2.ZERO
var _is_potential_tap: bool = false

## Camera reference (for screen-to-world conversion)
var _camera: Camera3D

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Find camera on next frame (after scene loads)
	call_deferred("_find_camera")
	GameLogger.info("Selection", "SelectionManager initialized")


func _find_camera() -> void:
	var cameras := get_tree().get_nodes_in_group("cameras")
	if cameras.size() > 0:
		_camera = cameras[0] as Camera3D
	else:
		# Try to find by viewport
		_camera = get_viewport().get_camera_3d()

	if _camera:
		GameLogger.debug("Selection", "Camera found: %s" % _camera.name)
	else:
		GameLogger.warn("Selection", "No camera found - selection may not work correctly")


## Refresh camera reference. Call this after camera changes (e.g., cutscenes).
## Code Review fix: Addresses stale camera reference issue.
func refresh_camera() -> void:
	_find_camera()


## CRITICAL: Use _input() NOT _unhandled_input() to guarantee priority over camera.
## This ensures selection always processes taps before camera pan/zoom.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_mouse_click(event)


func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Touch started
		_tap_start_time = Time.get_ticks_msec()
		_tap_start_position = event.position
		_is_potential_tap = true
	else:
		# Touch released - check if it was a tap
		if _is_potential_tap:
			var duration := Time.get_ticks_msec() - _tap_start_time
			var distance := event.position.distance_to(_tap_start_position)

			if duration < GameConstants.TAP_MAX_DURATION_MS and distance < GameConstants.TAP_MAX_DISTANCE_PX:
				_handle_tap(event.position)
		_is_potential_tap = false


func _handle_mouse_click(event: InputEventMouseButton) -> void:
	if event.pressed:
		_tap_start_time = Time.get_ticks_msec()
		_tap_start_position = event.position
		_is_potential_tap = true
	else:
		if _is_potential_tap:
			var duration := Time.get_ticks_msec() - _tap_start_time
			var distance := event.position.distance_to(_tap_start_position)

			if duration < GameConstants.TAP_MAX_DURATION_MS and distance < GameConstants.TAP_MAX_DISTANCE_PX:
				_handle_tap(event.position)
		_is_potential_tap = false


func _handle_tap(screen_pos: Vector2) -> void:
	# Convert screen position to world
	var world_pos := _screen_to_world(screen_pos)

	# Check for animal at position
	var animal := _find_animal_at(world_pos)

	if animal:
		select_animal(animal)
		# Consume input to prevent camera from processing it
		get_viewport().set_input_as_handled()
		return

	# Story 2-7: Two-tap workflow - if animal selected, try to assign destination
	if _selected_animal and is_instance_valid(_selected_animal):
		var hex_coord := _world_to_hex(world_pos)
		if hex_coord and is_instance_valid(AssignmentManager):
			var assigned := AssignmentManager.assign_to_hex(_selected_animal, hex_coord)
			if assigned:
				# Assignment successful - consume input, keep selection
				get_viewport().set_input_as_handled()
				return
			# Assignment failed (AC3/AC4/AC5 - gentle rejection)
			# Selection remains active for retry per AR11 cozy philosophy
			# Don't consume input, don't deselect - let player try again
			return

	# Tapped empty space with no selection or no valid assignment - deselect
	deselect_current()
	# Don't consume input - let camera handle for potential pan/zoom


func _screen_to_world(screen_pos: Vector2) -> Vector3:
	# Auto-refresh camera if it became invalid (Code Review fix)
	if not _camera or not is_instance_valid(_camera):
		_find_camera()
		if not _camera:
			return Vector3.ZERO

	# Raycast from camera to Y=0 plane
	var ray_origin := _camera.project_ray_origin(screen_pos)
	var ray_direction := _camera.project_ray_normal(screen_pos)

	# Avoid division by zero (ray parallel to ground)
	if abs(ray_direction.y) < 0.0001:
		return Vector3(ray_origin.x, 0, ray_origin.z)

	# Calculate intersection with Y=0 plane
	var t := -ray_origin.y / ray_direction.y
	var world_pos := ray_origin + ray_direction * t
	world_pos.y = 0

	return world_pos


## Convert world position to hex coordinate (Story 2-7).
## Uses HexGrid utility for coordinate conversion.
## @param world_pos The world position to convert
## @return The HexCoord at that position, or null if conversion fails
func _world_to_hex(world_pos: Vector3) -> HexCoord:
	return HexGrid.world_to_hex(world_pos)


func _find_animal_at(world_pos: Vector3) -> Animal:
	var animals := get_tree().get_nodes_in_group("animals")

	for animal_node in animals:
		var animal := animal_node as Animal
		# Null safety: skip invalid or uninitialized animals (GLaDOS review)
		if not is_instance_valid(animal) or not animal.is_initialized():
			continue

		# Check if tap is within animal's selection range
		var selectable := animal.get_node_or_null("SelectableComponent") as SelectableComponent
		if selectable and selectable.is_position_in_range(world_pos):
			return animal

	return null

# =============================================================================
# PUBLIC API
# =============================================================================

## Select an animal (deselects previous if any)
func select_animal(animal: Animal) -> void:
	# Null safety: animal could be queue_free'd between tap and selection (GLaDOS review)
	if not is_instance_valid(animal):
		GameLogger.warn("Selection", "Attempted to select invalid animal")
		return

	if animal == _selected_animal:
		return  # Already selected

	# Deselect previous (with null safety for freed animals)
	if _selected_animal and is_instance_valid(_selected_animal):
		var prev_selectable := _selected_animal.get_node_or_null("SelectableComponent") as SelectableComponent
		if prev_selectable:
			prev_selectable.deselect()
		EventBus.animal_deselected.emit()
	elif _selected_animal:
		# Previous animal was freed - just clear reference and emit signal
		EventBus.animal_deselected.emit()

	# Select new
	_selected_animal = animal
	var selectable := animal.get_node_or_null("SelectableComponent") as SelectableComponent
	if selectable:
		selectable.select()
		selectable.handle_tap()

	EventBus.animal_selected.emit(animal)
	GameLogger.info("Selection", "Selected animal: %s" % animal.get_animal_id())


## Deselect current animal
func deselect_current() -> void:
	if not _selected_animal:
		return

	# Null safety: animal may have been freed while selected (GLaDOS review)
	if is_instance_valid(_selected_animal):
		var selectable := _selected_animal.get_node_or_null("SelectableComponent") as SelectableComponent
		if selectable:
			selectable.deselect()

	_selected_animal = null
	EventBus.animal_deselected.emit()
	GameLogger.debug("Selection", "Deselected all")


## Get currently selected animal (or null)
func get_selected_animal() -> Animal:
	return _selected_animal


## Check if any animal is selected
func has_selection() -> bool:
	return _selected_animal != null


## Cancel any in-progress tap detection (called when drag starts)
func cancel_tap() -> void:
	_is_potential_tap = false
