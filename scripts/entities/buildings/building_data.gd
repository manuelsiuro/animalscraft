## BuildingData - Resource defining configuration for a building type.
## Loaded from resources/buildings/<type>_data.tres files.
## Data is read-only and shared across all buildings of the same type.
##
## Architecture: scripts/entities/buildings/building_data.gd
## Story: 3-1-create-building-entity-structure
class_name BuildingData
extends Resource

# =============================================================================
# PROPERTIES
# =============================================================================

## Unique identifier for this building type (e.g., "farm", "sawmill")
@export var building_id: String = ""

## Display name for UI (e.g., "Farm", "Sawmill")
@export var display_name: String = ""

## Building category for filtering and behavior
@export var building_type: BuildingTypes.BuildingType = BuildingTypes.BuildingType.GATHERER

## Maximum number of workers that can be assigned
@export_range(0, 10) var max_workers: int = 1

## Hex footprint relative to placement hex (default single hex).
## Array of Vector2i offsets from the placement hex.
## [Vector2i.ZERO] means single hex occupancy.
@export var footprint_hexes: Array[Vector2i] = [Vector2i.ZERO]

## Recipe ID for production (empty for non-producers).
## Links to recipe system for PROCESSOR buildings.
@export var production_recipe_id: String = ""

# =============================================================================
# VALIDATION
# =============================================================================

## Check if this building data is valid (has required fields).
## @return true if building data has valid configuration
func is_valid() -> bool:
	if building_id.is_empty():
		return false
	if display_name.is_empty():
		return false
	if max_workers < 0:
		return false
	if footprint_hexes.is_empty():
		return false
	return true

# =============================================================================
# HELPER METHODS
# =============================================================================

## Get the building type as a display string.
## @return String name of the building type
func get_type_name() -> String:
	return BuildingTypes.get_type_name(building_type)


## Check if this building can have workers assigned.
## @return true if max_workers > 0
func can_have_workers() -> bool:
	return max_workers > 0


## Check if this building is a producer (has recipe).
## @return true if production_recipe_id is not empty
func is_producer() -> bool:
	return not production_recipe_id.is_empty()


## Get all hex offsets in the building footprint.
## @return Array of Vector2i offsets from placement hex
func get_footprint() -> Array[Vector2i]:
	return footprint_hexes.duplicate()

# =============================================================================
# STRING REPRESENTATION
# =============================================================================

func _to_string() -> String:
	return "BuildingData<%s: %s, workers=%d>" % [building_id, get_type_name(), max_workers]
