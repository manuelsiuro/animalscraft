## Animal - Base class for all animal entities in AnimalsCraft.
## Follows composition pattern with child component nodes.
## Animals are Node3D positioned on the Y=0 ground plane.
##
## Architecture: scripts/entities/animals/animal.gd
## Story: 2-1-create-animal-entity-structure
class_name Animal
extends Node3D

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when animal is selected by player
signal selected()

## Emitted when animal is deselected
signal deselected()

# =============================================================================
# PROPERTIES
# =============================================================================

## Current hex coordinate of this animal
var hex_coord: HexCoord

## Stats resource for this animal type
var stats: AnimalStats

## Whether animal has been properly initialized
var _initialized: bool = false

# =============================================================================
# COMPONENTS (child nodes, assigned in _ready)
# =============================================================================

@onready var _visual: Node3D = $Visual
@onready var _selectable: Node = $SelectableComponent
@onready var _movement: Node = $MovementComponent
@onready var _stats_component: Node = $StatsComponent

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	add_to_group("animals")
	_setup_components()


## Initialize animal with hex position and stats.
## Must be called after scene instantiation.
## @param hex: The hex coordinate to place the animal
## @param animal_stats: The stats resource for this animal type
func initialize(hex: HexCoord, animal_stats: AnimalStats) -> void:
	if _initialized:
		GameLogger.warn("Animal", "Animal already initialized: %s" % (animal_stats.animal_id if animal_stats else "unknown"))
		return

	hex_coord = hex
	stats = animal_stats

	# Position at hex world location
	if hex:
		position = HexGrid.hex_to_world(hex)
	else:
		GameLogger.warn("Animal", "Initialized with null hex coordinate")

	# Initialize stats component if it exists and has initialize method
	if _stats_component and _stats_component.has_method("initialize"):
		_stats_component.initialize(animal_stats)

	_initialized = true

	if animal_stats:
		GameLogger.info("Animal", "Spawned %s at %s" % [animal_stats.animal_id, hex])
	else:
		GameLogger.info("Animal", "Spawned animal at %s" % hex)

	# Notify other systems
	EventBus.animal_spawned.emit(self)


func _setup_components() -> void:
	# Wire up component references
	# Components are stubs in this story, fully implemented in later stories
	pass

# =============================================================================
# PUBLIC API
# =============================================================================

## Check if animal is properly initialized
func is_initialized() -> bool:
	return _initialized


## Get current hex coordinate
func get_hex_coord() -> HexCoord:
	return hex_coord


## Get animal stats
func get_stats() -> AnimalStats:
	return stats


## Get the animal's unique identifier (from stats)
func get_animal_id() -> String:
	if stats:
		return stats.animal_id
	return ""

# =============================================================================
# CLEANUP
# =============================================================================

## Clean up animal resources before removal.
## Call this before queue_free() for proper cleanup.
func cleanup() -> void:
	# 1. Stop processes
	set_process(false)
	set_physics_process(false)

	# 2. Emit removal signal before cleanup (only if initialized)
	if _initialized:
		EventBus.animal_removed.emit(self)

	# 3. Disconnect any signals (future stories will add signal connections)
	# Currently no signals to disconnect

	# 4. Clear references
	hex_coord = null
	stats = null

	# 5. Remove from groups
	remove_from_group("animals")

	# 6. Queue for deletion
	queue_free()

# =============================================================================
# STRING REPRESENTATION
# =============================================================================

func _to_string() -> String:
	if stats:
		return "Animal<%s at %s>" % [stats.animal_id, hex_coord]
	return "Animal<uninitialized>"
