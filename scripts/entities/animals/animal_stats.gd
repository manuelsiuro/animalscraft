## AnimalStats - Resource defining stats for a single animal type.
## Loaded from resources/animals/<type>_stats.tres files.
## Stats are read-only and shared across all animals of the same type.
##
## Architecture: scripts/entities/animals/animal_stats.gd
## Story: 2-1-create-animal-entity-structure
class_name AnimalStats
extends Resource

# =============================================================================
# PROPERTIES
# =============================================================================

## Unique identifier for this animal type (e.g., "rabbit", "beaver")
@export var animal_id: String = ""

## Energy stat (1-5) - Work duration before rest needed
## Higher energy = more work tasks before needing shelter
@export_range(1, 5) var energy: int = 3

## Speed stat (1-5) - Movement and task completion rate
## Higher speed = faster movement and work completion
@export_range(1, 5) var speed: int = 3

## Strength stat (1-5) - Combat power, carry capacity
## Higher strength = better in combat, can carry more
@export_range(1, 5) var strength: int = 3

## Special ability description (e.g., "Fast gatherer", "Wood +50%")
## Displayed in UI, affects gameplay through specific mechanics
@export var specialty: String = ""

## Biome this animal belongs to (e.g., "plains", "forest", "mountain")
## Determines where the animal can be found/recruited
@export var biome: String = "plains"

# =============================================================================
# VALIDATION
# =============================================================================

## Check if this stats resource is valid (has required fields).
func is_valid() -> bool:
	return animal_id != "" and biome != ""

# =============================================================================
# STRING REPRESENTATION
# =============================================================================

func _to_string() -> String:
	return "AnimalStats<%s: E%d S%d St%d>" % [animal_id, energy, speed, strength]
