## SelectableComponent - Handles tap/click detection for animal selection.
## Uses Area3D for collision detection and raycast for touch-to-world conversion.
##
## Architecture: scripts/entities/animals/components/selectable_component.gd
## Story: 2-3-implement-animal-selection
class_name SelectableComponent
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when this entity is tapped/clicked
signal tapped()

## Emitted when selection state changes
signal selection_changed(is_selected: bool)

# =============================================================================
# CONFIGURATION
# =============================================================================

## Collision detection radius for tap (in pixels, converted to world units)
@export var tap_radius: float = GameConstants.SELECTION_TAP_RADIUS

# =============================================================================
# PROPERTIES
# =============================================================================

## Whether this entity is currently selected
var _is_selected: bool = false

## Parent entity reference
var _entity: Node3D

## Area3D for collision detection (created dynamically)
var _collision_area: Area3D

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_entity = get_parent() as Node3D
	_setup_collision_area()


func _setup_collision_area() -> void:
	# Create Area3D for tap detection
	_collision_area = Area3D.new()
	_collision_area.name = "SelectionArea"
	add_child(_collision_area)

	# Create collision shape (sphere around entity)
	var collision_shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	# Convert pixel radius to world units using HEX_SIZE as reference
	sphere_shape.radius = tap_radius / GameConstants.HEX_SIZE
	collision_shape.shape = sphere_shape
	_collision_area.add_child(collision_shape)

	# Set collision layer for selection detection
	# Layer 0: Physics objects (not used)
	# Selection uses raycast, not physics collision
	_collision_area.collision_layer = 0
	_collision_area.collision_mask = 0

# =============================================================================
# PUBLIC API
# =============================================================================

## Check if entity is currently selected
func is_selected() -> bool:
	return _is_selected


## Select this entity
func select() -> void:
	if _is_selected:
		return
	_is_selected = true
	selection_changed.emit(true)
	if _entity:
		GameLogger.debug("Selection", "Selected: %s" % _entity.name)


## Deselect this entity
func deselect() -> void:
	if not _is_selected:
		return
	_is_selected = false
	selection_changed.emit(false)
	if _entity:
		GameLogger.debug("Selection", "Deselected: %s" % _entity.name)


## Get the parent entity
func get_entity() -> Node3D:
	return _entity


## Check if a world position is within tap range of this entity.
## Uses XZ distance (ignores Y) since animals are on ground plane.
## @param world_pos The world position to check (Vector3)
## @return True if position is within tap radius
func is_position_in_range(world_pos: Vector3) -> bool:
	if not _entity:
		return false
	var entity_pos := _entity.global_position
	# Check XZ distance (ignore Y)
	var distance := Vector2(world_pos.x - entity_pos.x, world_pos.z - entity_pos.z).length()
	var world_radius := tap_radius / GameConstants.HEX_SIZE
	return distance <= world_radius

# =============================================================================
# TAP HANDLING (called by SelectionManager)
# =============================================================================

## Handle a tap at this entity
func handle_tap() -> void:
	tapped.emit()
