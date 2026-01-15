## BuildingFactory - Factory for creating building instances.
## Handles scene loading, data initialization, and spawning.
## Use static methods to create buildings by type.
##
## NOTE: This factory is NOT an autoload. It should be instantiated by
## WorldManager (matches AnimalFactory pattern for consistency - PARTY MODE decision).
##
## Architecture: scripts/entities/buildings/building_factory.gd
## Story: 3-1-create-building-entity-structure
class_name BuildingFactory
extends RefCounted

# =============================================================================
# CONSTANTS
# =============================================================================

## Preloaded building scenes by type
const BUILDING_SCENES: Dictionary = {
	"farm": preload("res://scenes/entities/buildings/farm.tscn"),
	"sawmill": preload("res://scenes/entities/buildings/sawmill.tscn"),
	# Future buildings added here as scenes are created:
	# "mill": preload("res://scenes/entities/buildings/mill.tscn"),
	# "bakery": preload("res://scenes/entities/buildings/bakery.tscn"),
	# "warehouse": preload("res://scenes/entities/buildings/warehouse.tscn"),
}

## Template path for loading building data resources
const DATA_PATH_TEMPLATE: String = "res://resources/buildings/%s_data.tres"

# =============================================================================
# PUBLIC API
# =============================================================================

## Create a building of specified type at given hex position.
## The caller is responsible for adding the building to the scene tree.
## @param type: Building type identifier (e.g., "farm", "sawmill")
## @param at_hex: HexCoord to place the building
## @return: Building instance or null if creation failed
static func create_building(type: String, at_hex: HexCoord) -> Building:
	# Guard: validate hex coordinate
	if not at_hex:
		GameLogger.error("BuildingFactory", "Null hex coordinate provided for building type: %s" % type)
		return null

	# Validate type
	if not BUILDING_SCENES.has(type):
		GameLogger.error("BuildingFactory", "Unknown building type: %s" % type)
		return null

	# Check if hex is buildable
	var hex_vec: Vector2i = at_hex.to_vector()
	if not HexGrid.is_hex_buildable(hex_vec):
		GameLogger.error("BuildingFactory", "Cannot place %s at %s - hex already occupied" % [type, at_hex])
		return null

	# Load building data
	var building_data := _load_data(type)
	if not building_data:
		GameLogger.error("BuildingFactory", "Failed to load data for: %s" % type)
		return null

	# Instantiate scene
	var scene: PackedScene = BUILDING_SCENES[type]
	var building := scene.instantiate()

	if not building:
		GameLogger.error("BuildingFactory", "Failed to instantiate scene for: %s" % type)
		return null

	# Initialize with deferred call (ensures node is in tree before initialization)
	if building.has_method("initialize"):
		building.call_deferred("initialize", at_hex, building_data)

	GameLogger.debug("BuildingFactory", "Created %s at %s" % [type, at_hex])
	return building


## Get list of available building types
static func get_available_types() -> Array[String]:
	var types: Array[String] = []
	for key in BUILDING_SCENES.keys():
		types.append(key)
	return types


## Check if a building type is available
static func has_building_type(type: String) -> bool:
	return BUILDING_SCENES.has(type)


## Get display name for a building type
static func get_building_display_name(type: String) -> String:
	var data := _load_data(type)
	if data:
		return data.display_name
	return type.capitalize()

# =============================================================================
# INTERNAL METHODS
# =============================================================================

## Load data resource for a building type
static func _load_data(type: String) -> BuildingData:
	var path := DATA_PATH_TEMPLATE % type

	if not ResourceLoader.exists(path):
		GameLogger.warn("BuildingFactory", "Data file not found: %s" % path)
		return null

	var data := load(path) as BuildingData
	if not data:
		GameLogger.warn("BuildingFactory", "Failed to load data as BuildingData: %s" % path)
		return null

	# Validate loaded data
	if not data.is_valid():
		GameLogger.warn("BuildingFactory", "Invalid building data for: %s" % type)
		return null

	return data
