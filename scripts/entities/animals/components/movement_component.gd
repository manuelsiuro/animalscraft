## MovementComponent - Handles smooth path-following movement for animals.
##
## Integrates with PathfindingManager for A* paths and StatsComponent for speed.
## Emits signals for movement lifecycle events.
##
## Architecture: scripts/entities/animals/components/movement_component.gd
## Story: 2-6-implement-animal-movement
class_name MovementComponent
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when movement begins
signal movement_started()

## Emitted when destination reached
signal movement_completed()

## Emitted when movement is interrupted
signal movement_cancelled()

## Emitted when animal reaches a waypoint (intermediate hex)
signal waypoint_reached(hex: HexCoord)

# =============================================================================
# CONSTANTS
# =============================================================================

## Base movement speed in world units per second (at Speed stat = 1)
const BASE_SPEED: float = 50.0

## Speed multiplier per Speed stat point
const SPEED_PER_STAT: float = 20.0

## Rotation smoothing factor (higher = faster rotation)
const ROTATION_SPEED: float = 10.0

# =============================================================================
# STATE
# =============================================================================

## Current path being followed (Array of HexCoord)
var _path: Array = []

## Current index in the path
var _path_index: int = 0

## Is currently moving
var _is_moving: bool = false

## Target destination hex
var _destination: HexCoord = null

## Reference to parent Animal
var _animal: Node3D = null

## Reference to StatsComponent for speed
var _stats: Node = null

## Current world position target
var _current_target_pos: Vector3 = Vector3.ZERO

## Starting position for current segment
var _segment_start_pos: Vector3 = Vector3.ZERO

## Target rotation angle (Y axis)
var _target_rotation: float = 0.0

## Reference to Visual child for rotation
var _visual: Node3D = null

## Reference to AnimationPlayer (if exists)
var _animation_player: AnimationPlayer = null

## Reference to PathfindingManager (found via WorldManager)
var _pathfinding: Node = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Get parent animal reference
	_animal = get_parent()

	if not _animal:
		if is_instance_valid(GameLogger):
			GameLogger.warn("Movement", "MovementComponent: No parent node found")
		return

	# Find StatsComponent sibling
	_stats = _animal.get_node_or_null("StatsComponent")

	if not _stats:
		if is_instance_valid(GameLogger):
			GameLogger.warn("Movement", "MovementComponent: No StatsComponent found")

	# Find Visual child for rotation (apply rotation to Visual, not Animal)
	_visual = _animal.get_node_or_null("Visual")

	# Find AnimationPlayer if exists (for walk animation)
	_animation_player = _find_animation_player()

	# Find PathfindingManager (typically via WorldManager in tree)
	_pathfinding = _find_pathfinding_manager()


func _process(delta: float) -> void:
	if not _is_moving:
		return

	_update_movement(delta)
	_update_rotation(delta)


func _find_animation_player() -> AnimationPlayer:
	# Try common locations for AnimationPlayer
	if _animal:
		# Check direct child
		var player := _animal.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if player:
			return player

		# Check in Visual child
		if _visual:
			player = _visual.get_node_or_null("AnimationPlayer") as AnimationPlayer
			if player:
				return player

	return null


func _find_pathfinding_manager() -> Node:
	# Look for PathfindingManager in the scene tree
	# It should be a child of WorldManager or similar

	# First try: Look in "world_managers" group
	var world_managers := get_tree().get_nodes_in_group("world_managers")
	for wm in world_managers:
		var pm := wm.get_node_or_null("PathfindingManager")
		if pm:
			return pm

	# Second try: Search common paths
	var root := get_tree().current_scene
	if root:
		# Try /root/Game/World/PathfindingManager
		var pm := root.get_node_or_null("World/PathfindingManager")
		if pm:
			return pm

	# PathfindingManager not found - will fail gracefully in move_to
	return null

# =============================================================================
# PUBLIC API
# =============================================================================

## Start moving to target hex coordinate
func move_to(target_hex: HexCoord) -> void:
	if target_hex == null:
		if is_instance_valid(GameLogger):
			GameLogger.warn("Movement", "move_to called with null target")
		return

	if not _animal:
		if is_instance_valid(GameLogger):
			GameLogger.error("Movement", "Cannot move: no parent animal")
		return

	# Get current hex
	var current_hex: HexCoord = null
	if _animal.has_method("get_hex_coord"):
		current_hex = _animal.get_hex_coord()
	elif "hex_coord" in _animal:
		current_hex = _animal.hex_coord

	if current_hex == null:
		if is_instance_valid(GameLogger):
			GameLogger.error("Movement", "Cannot move: animal has no hex_coord")
		return

	# Same location check
	if current_hex.q == target_hex.q and current_hex.r == target_hex.r:
		if is_instance_valid(GameLogger):
			GameLogger.debug("Movement", "Already at destination")
		return

	# Request path from PathfindingManager
	if not _pathfinding:
		# Try to find it again (might have been created after us)
		_pathfinding = _find_pathfinding_manager()

	if not is_instance_valid(_pathfinding):
		if is_instance_valid(GameLogger):
			GameLogger.error("Movement", "PathfindingManager not available")
		return

	if not _pathfinding.has_method("request_path"):
		if is_instance_valid(GameLogger):
			GameLogger.error("Movement", "PathfindingManager missing request_path method")
		return

	var path: Array = _pathfinding.request_path(current_hex, target_hex)

	if path.size() == 0:
		if is_instance_valid(GameLogger):
			GameLogger.warn("Movement", "No path found to destination")
		return

	# Clear any existing movement
	if _is_moving:
		_cancel_movement_internal(false)  # Don't emit signal since we're starting new movement

	# Start following path
	_path = path
	_path_index = 0
	_destination = target_hex
	_is_moving = true
	_segment_start_pos = _animal.global_position

	# Set first waypoint
	_advance_to_next_waypoint()

	# Start walk animation (AC4)
	_play_walk_animation()

	# Emit signals
	movement_started.emit()
	if is_instance_valid(EventBus):
		EventBus.animal_movement_started.emit(_animal)

	if is_instance_valid(GameLogger):
		GameLogger.debug("Movement", "Started path with %d waypoints" % path.size())


## Stop current movement
func stop() -> void:
	if not _is_moving:
		return

	_cancel_movement_internal(true)


## Check if currently moving
func is_moving() -> bool:
	return _is_moving


## Get current destination (null if not moving)
func get_destination() -> HexCoord:
	return _destination


## Get remaining path length (hexes to destination)
func get_remaining_path_length() -> int:
	if not _is_moving:
		return 0
	return _path.size() - _path_index


## Get current movement speed (considering stats and mood)
func get_current_speed() -> float:
	return _calculate_speed()


## Inject PathfindingManager reference (useful for testing and initialization)
## @param pathfinding The PathfindingManager instance
func set_pathfinding_manager(pathfinding: Node) -> void:
	_pathfinding = pathfinding

# =============================================================================
# PRIVATE - MOVEMENT
# =============================================================================

## Update movement each frame
func _update_movement(delta: float) -> void:
	if _path_index >= _path.size():
		_complete_movement()
		return

	# Calculate movement speed
	var speed: float = _calculate_speed()

	# Calculate distance to target
	var current_pos: Vector3 = _animal.global_position
	var distance_to_target: float = current_pos.distance_to(_current_target_pos)

	# Calculate movement this frame
	var move_distance: float = speed * delta

	if distance_to_target <= move_distance:
		# Reached waypoint - snap to exact position
		_animal.global_position = _current_target_pos
		_on_waypoint_reached()
	else:
		# Continue moving toward waypoint with linear interpolation
		var direction: Vector3 = current_pos.direction_to(_current_target_pos)
		_animal.global_position += direction * move_distance

		# Update target rotation based on direction
		_update_target_rotation(direction)


## Calculate movement speed based on stats and mood (AC2)
## Formula: BASE_SPEED + (effective_speed - BASE_STAT_VALUE) * SPEED_PER_STAT
## Where effective_speed already includes mood modifier from StatsComponent.
## Example: Speed stat 4, Sad mood (0.7x) → effective_speed = 2.8
##          Result: 50 + (2.8 - 1.0) * 20 = 86 units/sec
func _calculate_speed() -> float:
	# Base stat value of 1 is the baseline - stats above 1 add speed, below 1 subtract
	const BASE_STAT_VALUE: float = 1.0
	var speed: float = BASE_SPEED

	if _stats:
		if _stats.has_method("get_effective_speed"):
			var effective_speed: float = _stats.get_effective_speed()
			# effective_speed already includes mood modifier from StatsComponent
			speed = BASE_SPEED + (effective_speed - BASE_STAT_VALUE) * SPEED_PER_STAT
		elif _stats.has_method("get_speed"):
			# Fallback: manually apply mood modifier
			var speed_stat: int = _stats.get_speed()
			var mood_modifier: float = 1.0
			if _stats.has_method("get_mood_modifier"):
				mood_modifier = _stats.get_mood_modifier()
			speed = (BASE_SPEED + (speed_stat - BASE_STAT_VALUE) * SPEED_PER_STAT) * mood_modifier

	return maxf(speed, 10.0)  # Minimum speed to prevent stuck animals


## Called when a waypoint is reached (AC5)
func _on_waypoint_reached() -> void:
	if _path_index >= _path.size():
		return

	var current_hex: HexCoord = _path[_path_index]

	# Update animal's hex coordinate
	if _animal.has_method("set_hex_coord"):
		_animal.set_hex_coord(current_hex)
	elif "hex_coord" in _animal:
		_animal.hex_coord = current_hex

	waypoint_reached.emit(current_hex)

	_path_index += 1

	if _path_index >= _path.size():
		_complete_movement()
	else:
		_segment_start_pos = _animal.global_position
		_advance_to_next_waypoint()


## Advance to the next waypoint in path
func _advance_to_next_waypoint() -> void:
	if _path_index >= _path.size():
		return

	var next_hex: HexCoord = _path[_path_index]

	# Get world position for next hex
	_current_target_pos = HexGrid.hex_to_world(next_hex)

	# Calculate initial direction to target
	var direction := _animal.global_position.direction_to(_current_target_pos)
	_update_target_rotation(direction)


## Complete movement and emit signals (AC5)
func _complete_movement() -> void:
	_is_moving = false
	_path.clear()
	_path_index = 0

	var dest := _destination
	_destination = null

	# Stop walk animation, resume idle (AC4)
	_stop_walk_animation()

	# Emit signals (AC6)
	movement_completed.emit()
	if is_instance_valid(EventBus):
		EventBus.animal_movement_completed.emit(_animal)

	if is_instance_valid(GameLogger):
		GameLogger.debug("Movement", "Movement completed at destination")


## Internal cancellation (can suppress signal for chained movements)
func _cancel_movement_internal(emit_signal: bool) -> void:
	_is_moving = false
	_path.clear()
	_path_index = 0
	_destination = null

	# Stop walk animation (AC4)
	_stop_walk_animation()

	if emit_signal:
		movement_cancelled.emit()
		if is_instance_valid(EventBus):
			EventBus.animal_movement_cancelled.emit(_animal)

		if is_instance_valid(GameLogger):
			GameLogger.debug("Movement", "Movement cancelled")

# =============================================================================
# PRIVATE - ROTATION (AC3)
# =============================================================================

## Update target rotation based on movement direction
func _update_target_rotation(direction: Vector3) -> void:
	if direction.length_squared() < 0.001:
		return

	# Calculate Y rotation to face direction (X-Z plane movement)
	# atan2(x, z) gives angle from +Z axis toward +X axis
	_target_rotation = atan2(direction.x, direction.z)


## Smoothly update facing direction
func _update_rotation(delta: float) -> void:
	# Find the node to rotate (Visual child preferred, or animal itself)
	var target: Node3D = _visual if _visual else _animal
	if not target:
		return

	# Smooth rotation interpolation
	var current_rotation: float = target.rotation.y
	var rotation_diff: float = _target_rotation - current_rotation

	# Normalize rotation difference to shortest path (-PI to PI)
	while rotation_diff > PI:
		rotation_diff -= TAU
	while rotation_diff < -PI:
		rotation_diff += TAU

	# Apply smooth rotation (can be instant for immediate response, smooth for polished feel)
	if abs(rotation_diff) > 0.01:
		target.rotation.y = current_rotation + rotation_diff * minf(ROTATION_SPEED * delta, 1.0)
	else:
		target.rotation.y = _target_rotation

# =============================================================================
# PRIVATE - ANIMATION (AC4)
# =============================================================================

## Play walk animation if AnimationPlayer exists
func _play_walk_animation() -> void:
	if not _animation_player:
		return

	# Check if walk animation exists
	if _animation_player.has_animation("walk"):
		_animation_player.play("walk")
	elif _animation_player.has_animation("Walk"):
		_animation_player.play("Walk")
	elif _animation_player.has_animation("walking"):
		_animation_player.play("walking")
	# If no walk animation exists, that's fine - placeholder acceptable per AC4


## Stop walk animation and resume idle
func _stop_walk_animation() -> void:
	if not _animation_player:
		return

	# Check if idle animation exists
	if _animation_player.has_animation("idle"):
		_animation_player.play("idle")
	elif _animation_player.has_animation("Idle"):
		_animation_player.play("Idle")
	elif _animation_player.has_animation("RESET"):
		_animation_player.play("RESET")
	else:
		# Just stop the current animation
		_animation_player.stop()
