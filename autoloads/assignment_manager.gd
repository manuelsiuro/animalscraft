## AssignmentManager - Handles animal task assignments.
## Coordinates between selection, validation, and movement systems.
## Implements the two-tap workflow: select animal → tap destination → animal moves.
##
## Architecture: autoloads/assignment_manager.gd
## Story: 2-7-implement-tap-to-assign-workflow
## NOTE: No class_name to avoid conflict with autoload singleton
extends Node

# =============================================================================
# CONSTANTS - AIComponent.AnimalState enum values (avoid magic numbers)
# =============================================================================

const AI_STATE_IDLE := 0
const AI_STATE_WORKING := 2

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when assignment attempt fails validation
signal assignment_failed(animal: Node, reason: String)

# =============================================================================
# STATE
# =============================================================================

## Track active assignments (animal_id → target_hex)
var _active_assignments: Dictionary = {}

## Destination markers (animal_id → marker_node)
var _destination_markers: Dictionary = {}

## Reference to WorldManager (found on demand)
var _world_manager: Node = null

## Reference to PathfindingManager (found via WorldManager)
var _pathfinding_manager: Node = null

## Reference to TerritoryManager (found via WorldManager)
var _territory_manager: Node = null

## Destination marker scene (preloaded)
var _marker_scene: PackedScene = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Connect to movement completion signals
	if is_instance_valid(EventBus):
		EventBus.animal_movement_completed.connect(_on_animal_movement_completed)
		EventBus.animal_movement_cancelled.connect(_on_animal_movement_cancelled)
		EventBus.animal_removed.connect(_on_animal_removed)

	# Defer manager lookups (let scene initialize first)
	call_deferred("_find_managers")

	if is_instance_valid(GameLogger):
		GameLogger.info("Assignment", "AssignmentManager initialized")


func _find_managers() -> void:
	# Find WorldManager from group
	var world_managers := get_tree().get_nodes_in_group("world_managers")
	if world_managers.size() > 0:
		_world_manager = world_managers[0]

		# Get PathfindingManager from WorldManager
		if _world_manager.has_method("get_pathfinding_manager"):
			_pathfinding_manager = _world_manager.get_pathfinding_manager()

		# Get TerritoryManager from WorldManager
		if _world_manager.has_method("get_territory_manager"):
			_territory_manager = _world_manager.get_territory_manager()

	# Try to preload marker scene
	var marker_path := "res://scenes/ui/destination_marker.tscn"
	if ResourceLoader.exists(marker_path):
		_marker_scene = load(marker_path)


func _exit_tree() -> void:
	# Clean up EventBus connections
	if is_instance_valid(EventBus):
		if EventBus.animal_movement_completed.is_connected(_on_animal_movement_completed):
			EventBus.animal_movement_completed.disconnect(_on_animal_movement_completed)
		if EventBus.animal_movement_cancelled.is_connected(_on_animal_movement_cancelled):
			EventBus.animal_movement_cancelled.disconnect(_on_animal_movement_cancelled)
		if EventBus.animal_removed.is_connected(_on_animal_removed):
			EventBus.animal_removed.disconnect(_on_animal_removed)

	# Clean up any remaining markers
	for animal_id in _destination_markers.keys():
		var marker: Node = _destination_markers[animal_id]
		if is_instance_valid(marker):
			marker.queue_free()
	_destination_markers.clear()
	_active_assignments.clear()

# =============================================================================
# PUBLIC API
# =============================================================================

## Attempt to assign an animal to a hex destination.
## Returns true if assignment succeeded, false otherwise.
## @param animal The animal to assign (must be valid Animal node)
## @param target_hex The destination hex coordinate
## @return True if assignment succeeded
func assign_to_hex(animal: Node, target_hex: HexCoord) -> bool:
	# AR18: Null safety
	if not is_instance_valid(animal):
		if is_instance_valid(GameLogger):
			GameLogger.warn("Assignment", "Invalid animal reference")
		return false

	if target_hex == null:
		if is_instance_valid(GameLogger):
			GameLogger.warn("Assignment", "Null target hex")
		return false

	# Validate target hex
	var validation := _validate_hex(animal, target_hex)
	if not validation.valid:
		if is_instance_valid(GameLogger):
			GameLogger.debug("Assignment", "Rejected: %s" % validation.reason)
		assignment_failed.emit(animal, validation.reason)
		return false

	# Cancel existing assignment if any (AC7 - re-assignment)
	_cancel_existing(animal)

	# Get movement component
	var movement := animal.get_node_or_null("MovementComponent")
	if not movement or not movement.has_method("move_to"):
		if is_instance_valid(GameLogger):
			GameLogger.error("Assignment", "Animal has no MovementComponent with move_to method")
		return false

	# Start movement
	movement.move_to(target_hex)

	# Track assignment
	var animal_id := _get_animal_id(animal)
	_active_assignments[animal_id] = target_hex

	# Show destination marker (AC2)
	_show_destination_marker(animal, target_hex)

	# Emit global signal (AC6)
	if is_instance_valid(EventBus):
		EventBus.animal_assigned.emit(animal, target_hex)

	if is_instance_valid(GameLogger):
		GameLogger.info("Assignment", "Assigned %s to hex (%d, %d)" % [
			animal_id, target_hex.q, target_hex.r
		])

	return true


## Cancel an animal's current assignment.
## @param animal The animal to cancel assignment for
func cancel_assignment(animal: Node) -> void:
	if not is_instance_valid(animal):
		return
	_cancel_existing(animal)


## Check if an animal has an active assignment.
## @param animal The animal to check
## @return True if animal has an active assignment
func has_assignment(animal: Node) -> bool:
	if not is_instance_valid(animal):
		return false
	return _active_assignments.has(_get_animal_id(animal))


## Get the target hex for an animal's current assignment.
## @param animal The animal to query
## @return The target HexCoord or null if no assignment
func get_assignment_target(animal: Node) -> HexCoord:
	if not is_instance_valid(animal):
		return null
	return _active_assignments.get(_get_animal_id(animal))

# =============================================================================
# VALIDATION (AC3, AC4, AC5)
# =============================================================================

## Validate if a hex is a valid assignment target.
## Checks passability, fog state, and path existence.
## Uses PathfindingManager for terrain validation (AC3, AC5).
## @param animal The animal being assigned
## @param target_hex The destination hex
## @return Dictionary with "valid" bool and "reason" string
func _validate_hex(animal: Node, target_hex: HexCoord) -> Dictionary:
	var result := {"valid": false, "reason": ""}

	# Ensure managers are available
	if not _world_manager:
		_find_managers()

	# Check if hex is passable (AC3 - water/rock rejection)
	# PathfindingManager.is_passable() handles: hex existence, terrain type
	if _pathfinding_manager and _pathfinding_manager.has_method("is_passable"):
		if not _pathfinding_manager.is_passable(target_hex):
			result.reason = "impassable_terrain"
			return result
	elif _world_manager and _world_manager.has_method("has_tile_at"):
		# Fallback: at least check hex exists if PathfindingManager unavailable
		if not _world_manager.has_tile_at(target_hex):
			result.reason = "hex_not_found"
			return result

	# Check if hex is revealed (AC4 - unexplored rejection)
	# Use TerritoryManager enum constant for clarity
	if _territory_manager and _territory_manager.has_method("get_territory_state"):
		var state: int = _territory_manager.get_territory_state(target_hex)
		# Reject UNEXPLORED hexes (fog of war)
		if state == _territory_manager.TerritoryState.UNEXPLORED:
			result.reason = "unexplored"
			return result

	# Check if path exists (AC5 - no path rejection)
	var current_hex: HexCoord = null
	if animal.has_method("get_hex_coord"):
		current_hex = animal.get_hex_coord()
	elif "hex_coord" in animal:
		current_hex = animal.hex_coord

	if current_hex and _pathfinding_manager and _pathfinding_manager.has_method("request_path"):
		var path: Array = _pathfinding_manager.request_path(current_hex, target_hex)
		if path.size() == 0:
			result.reason = "no_path"
			return result

	result.valid = true
	return result

# =============================================================================
# INTERNAL
# =============================================================================

## Get animal's unique identifier
func _get_animal_id(animal: Node) -> String:
	if animal.has_method("get_animal_id"):
		return animal.get_animal_id()
	elif "stats" in animal and animal.stats and "animal_id" in animal.stats:
		return animal.stats.animal_id
	return str(animal.get_instance_id())


## Cancel existing assignment for an animal
## Extended in Story 3-8 to remove animal from current building.
func _cancel_existing(animal: Node) -> void:
	var animal_id := _get_animal_id(animal)

	# Story 3-8: Remove from current building first (AC8 - re-assignment cleanup)
	_remove_from_current_building(animal)

	# Stop movement if currently moving
	var movement := animal.get_node_or_null("MovementComponent")
	if movement and movement.has_method("stop"):
		movement.stop()

	# Clear tracking
	_active_assignments.erase(animal_id)

	# Hide marker
	_hide_destination_marker(animal)


## Show destination marker at target hex (AC2)
func _show_destination_marker(animal: Node, target_hex: HexCoord) -> void:
	var animal_id := _get_animal_id(animal)

	# Remove existing marker
	_hide_destination_marker(animal)

	# Check if marker scene exists
	if not _marker_scene:
		# Try to load again
		var marker_path: String = "res://scenes/ui/destination_marker.tscn"
		if ResourceLoader.exists(marker_path):
			_marker_scene = load(marker_path)
		else:
			if is_instance_valid(GameLogger):
				GameLogger.debug("Assignment", "Destination marker scene not found")
			return

	# Instantiate marker
	var marker: Node3D = _marker_scene.instantiate() as Node3D

	# Position at target hex
	var world_pos: Vector3 = HexGrid.hex_to_world(target_hex)
	marker.global_position = Vector3(world_pos.x, 0.05, world_pos.z)  # Slightly above ground

	# Add to scene
	var scene_root := get_tree().current_scene
	if scene_root:
		scene_root.add_child(marker)
		_destination_markers[animal_id] = marker
	else:
		marker.queue_free()
		if is_instance_valid(GameLogger):
			GameLogger.warn("Assignment", "No current scene to add marker")


## Hide destination marker for an animal
func _hide_destination_marker(animal: Node) -> void:
	var animal_id: String = _get_animal_id(animal)

	if _destination_markers.has(animal_id):
		var marker: Node = _destination_markers[animal_id]
		if is_instance_valid(marker):
			if marker.has_method("cleanup"):
				marker.cleanup()
			else:
				marker.queue_free()
		_destination_markers.erase(animal_id)

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

## Handle movement completion (AC5.2 - clear assignment, hide marker)
## Extended in Story 3-8 to handle building assignment.
func _on_animal_movement_completed(animal: Node) -> void:
	if not is_instance_valid(animal):
		return

	var animal_id := _get_animal_id(animal)
	_active_assignments.erase(animal_id)
	_hide_destination_marker(animal)

	# Story 3-8: Check if destination has a building
	_try_assign_to_building(animal)


## Handle movement cancellation (AC5.3 - update state, hide marker)
func _on_animal_movement_cancelled(animal: Node) -> void:
	if not is_instance_valid(animal):
		return

	var animal_id := _get_animal_id(animal)
	_active_assignments.erase(animal_id)
	_hide_destination_marker(animal)


## Handle animal removal - cleanup any associated markers
func _on_animal_removed(animal: Node) -> void:
	if not is_instance_valid(animal):
		return

	var animal_id := _get_animal_id(animal)
	_active_assignments.erase(animal_id)
	_hide_destination_marker(animal)

# =============================================================================
# BUILDING ASSIGNMENT (Story 3-8)
# =============================================================================

## Try to assign animal to a building at its current location.
## Called after movement completion to check if destination has a building.
## @param animal The animal that completed movement
func _try_assign_to_building(animal: Node) -> void:
	if not is_instance_valid(animal):
		return

	# Get animal's current hex coordinate
	var current_hex: HexCoord = null
	if animal.has_method("get_hex_coord"):
		current_hex = animal.get_hex_coord()
	elif "hex_coord" in animal:
		current_hex = animal.hex_coord

	if not current_hex:
		return

	# Check if there's a building at this hex (O(1) dictionary lookup - AC3.2)
	var hex_vec: Vector2i = current_hex.to_vector()
	var building: Node = HexGrid.get_building_at_hex(hex_vec)

	if not building:
		return  # No building at this hex

	# Only assign to gatherer buildings with worker slots
	if not building.has_method("get_worker_slots"):
		return

	var slots = building.get_worker_slots()
	if not slots:
		return

	# Check slot availability FIRST (AC3.3 - explicit check before add)
	if not slots.is_slot_available():
		# AC11: Slots full - animal stays IDLE at location
		if is_instance_valid(GameLogger):
			GameLogger.debug("Assignment", "Slots full at %s - animal remains IDLE" % building)
		return

	# Try to add worker (AC3.3)
	if not slots.add_worker(animal):
		# Add failed for some other reason
		if is_instance_valid(GameLogger):
			GameLogger.debug("Assignment", "Failed to add worker to %s" % building)
		return

	# Worker added successfully - transition to WORKING state (AC3.4)
	var ai := animal.get_node_or_null("AIComponent")
	if ai and ai.has_method("transition_to"):
		ai.transition_to(AI_STATE_WORKING)

	# Store building reference in animal (AC3.7, AC3.8)
	if animal.has_method("set_assigned_building"):
		animal.set_assigned_building(building)

	if is_instance_valid(GameLogger):
		var animal_id := _get_animal_id(animal)
		GameLogger.info("Assignment", "%s assigned to building %s" % [animal_id, building])


## Remove animal from its current building assignment.
## Called before re-assignment or when canceling assignment.
## @param animal The animal to remove from building
func _remove_from_current_building(animal: Node) -> void:
	if not is_instance_valid(animal):
		return

	# Check if animal has a building assignment
	if not animal.has_method("get_assigned_building"):
		return

	var building: Node = animal.get_assigned_building()
	if not is_instance_valid(building):
		# Clear stale reference
		if animal.has_method("clear_assigned_building"):
			animal.clear_assigned_building()
		return

	# Remove from building's worker slots (AC3.6)
	if building.has_method("get_worker_slots"):
		var slots = building.get_worker_slots()
		if slots and slots.has_method("remove_worker"):
			slots.remove_worker(animal)

	# Clear building reference (AC3.9)
	if animal.has_method("clear_assigned_building"):
		animal.clear_assigned_building()

	# Transition to IDLE state
	var ai := animal.get_node_or_null("AIComponent")
	if ai and ai.has_method("transition_to"):
		ai.transition_to(AI_STATE_IDLE)

	if is_instance_valid(GameLogger):
		var animal_id := _get_animal_id(animal)
		GameLogger.debug("Assignment", "%s removed from building" % animal_id)
