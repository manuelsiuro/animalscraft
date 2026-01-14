## AnimalFactory - Factory for creating animal instances.
## Handles scene loading, stats initialization, and spawning.
## Use static methods to create animals by type.
##
## Architecture: scripts/entities/animals/animal_factory.gd
## Story: 2-1-create-animal-entity-structure
class_name AnimalFactory
extends RefCounted

# =============================================================================
# CONSTANTS
# =============================================================================

## Preloaded animal scenes by type
const ANIMAL_SCENES: Dictionary = {
	"rabbit": preload("res://scenes/entities/animals/rabbit.tscn"),
	# Future animals added here as scenes are created:
	# "beaver": preload("res://scenes/entities/animals/beaver.tscn"),
	# "squirrel": preload("res://scenes/entities/animals/squirrel.tscn"),
	# "fox": preload("res://scenes/entities/animals/fox.tscn"),
}

## Template path for loading stats resources
const STATS_PATH_TEMPLATE: String = "res://resources/animals/%s_stats.tres"

# =============================================================================
# PUBLIC API
# =============================================================================

## Create an animal of specified type at given hex position.
## The caller is responsible for adding the animal to the scene tree.
## @param type: Animal type identifier (e.g., "rabbit")
## @param at_hex: HexCoord to place the animal
## @return: Animal instance or null if creation failed
static func create_animal(type: String, at_hex: HexCoord) -> Animal:
	# Validate type
	if not ANIMAL_SCENES.has(type):
		GameLogger.error("AnimalFactory", "Unknown animal type: %s" % type)
		return null

	# Load stats
	var stats := _load_stats(type)
	if not stats:
		GameLogger.error("AnimalFactory", "Failed to load stats for: %s" % type)
		return null

	# Instantiate scene
	var scene: PackedScene = ANIMAL_SCENES[type]
	var animal := scene.instantiate()

	if not animal:
		GameLogger.error("AnimalFactory", "Failed to instantiate scene for: %s" % type)
		return null

	# Initialize with deferred call (ensures node is in tree before initialization)
	if animal.has_method("initialize"):
		animal.call_deferred("initialize", at_hex, stats)

	GameLogger.debug("AnimalFactory", "Created %s at %s" % [type, at_hex])
	return animal


## Get list of available animal types
static func get_available_types() -> Array[String]:
	var types: Array[String] = []
	for key in ANIMAL_SCENES.keys():
		types.append(key)
	return types


## Check if an animal type is available
static func has_animal_type(type: String) -> bool:
	return ANIMAL_SCENES.has(type)

# =============================================================================
# INTERNAL METHODS
# =============================================================================

## Load stats resource for an animal type
static func _load_stats(type: String) -> AnimalStats:
	var path := STATS_PATH_TEMPLATE % type

	if not ResourceLoader.exists(path):
		GameLogger.warn("AnimalFactory", "Stats file not found: %s" % path)
		return null

	var stats := load(path) as AnimalStats
	if not stats:
		GameLogger.warn("AnimalFactory", "Failed to load stats as AnimalStats: %s" % path)
		return null

	return stats
