## MovementComponent - Handles pathfinding and movement for animals.
## Stub implementation - full functionality in Stories 2-5, 2-6.
##
## Architecture: scripts/entities/animals/components/movement_component.gd
## Story: 2-1-create-animal-entity-structure (stub)
## Full Implementation: 2-5-implement-astar-pathfinding, 2-6-implement-animal-movement
class_name MovementComponent
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when movement starts
signal movement_started()

## Emitted when destination is reached
signal movement_completed()

## Emitted when movement is blocked or cancelled
signal movement_cancelled()

# =============================================================================
# PROPERTIES
# =============================================================================

## Current destination hex (null if not moving)
var _destination: HexCoord = null

## Whether currently moving
var _is_moving: bool = false

# =============================================================================
# PUBLIC API (STUB)
# =============================================================================

## Check if currently moving
func is_moving() -> bool:
	return _is_moving


## Get current destination (null if not moving)
func get_destination() -> HexCoord:
	return _destination


## Start moving to target hex (stub - full implementation in Story 2-6)
func move_to(target_hex: HexCoord) -> void:
	# Stub: Just store destination, actual movement in later stories
	_destination = target_hex
	_is_moving = true
	movement_started.emit()


## Stop current movement (stub - full implementation in Story 2-6)
func stop() -> void:
	_destination = null
	_is_moving = false
	movement_cancelled.emit()
