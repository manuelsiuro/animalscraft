## BuildingData - Resource defining configuration for a building type.
## Loaded from resources/buildings/<type>_data.tres files.
## Data is read-only and shared across all buildings of the same type.
##
## Architecture: scripts/entities/buildings/building_data.gd
## Story: 3-1-create-building-entity-structure, 3-6-display-placement-validity-indicators
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

## Output resource ID for gatherer buildings (Story 3-8).
## The resource type this building produces (e.g., "wheat", "wood").
## Empty for non-gatherer buildings.
@export var output_resource_id: String = ""

## Production time in seconds for gatherer buildings (Story 3-8).
## Time for one production cycle. Default 5.0 seconds.
@export var production_time: float = 5.0

## Storage capacity bonus provided by this building (Story 3-3).
## 0 means this is not a storage building.
## Stockpile provides +50 capacity per resource type.
@export var storage_capacity_bonus: int = 0

## Valid terrain types for placement (e.g., ["grass"]).
## Empty array means placement anywhere is valid.
## @deprecated Use terrain_requirements instead
@export var valid_terrain: Array[String] = []

## Terrain types this building can be placed on (Story 3-6).
## Empty array OR null means any non-water terrain is valid.
## VALIDATED at resource load time via _validate_on_load()
## Uses HexTile.TerrainType values: GRASS=0, WATER=1, ROCK=2
@export var terrain_requirements: Array[int] = []

## Build cost as resource_id -> amount dictionary.
## Example: {"wood": 15}
@export var build_cost: Dictionary = {}

# =============================================================================
# VALIDATION
# =============================================================================

## Validate terrain_requirements at resource load time (Story 3-6).
## Ensures array is valid and not corrupt. Called on resource load.
func _validate_on_load() -> void:
	# Ensure terrain_requirements is valid array (not corrupt)
	if terrain_requirements == null:
		terrain_requirements = []

	# Filter out invalid terrain types (WATER = 1 should not be in requirements)
	var valid_reqs: Array[int] = []
	for req in terrain_requirements:
		# WATER (1) is never a valid terrain requirement
		if req != 1:  # HexTile.TerrainType.WATER
			valid_reqs.append(req)
	terrain_requirements = valid_reqs


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


## Check if a terrain type is valid for this building (Story 3-6).
## @param terrain_type The HexTile.TerrainType value to check
## @return true if building can be placed on this terrain
func is_terrain_valid(terrain_type: int) -> bool:
	# Empty array means any non-water terrain is valid
	if terrain_requirements.is_empty():
		return terrain_type != 1  # Not WATER

	# Check if terrain is in requirements list
	return terrain_type in terrain_requirements

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


## Check if this building is a gatherer (produces output resource) (Story 3-8).
## @return true if output_resource_id is not empty
func is_gatherer() -> bool:
	return not output_resource_id.is_empty()


## Check if this building provides storage capacity bonus (Story 3-3).
## @return true if storage_capacity_bonus > 0
func is_storage_building() -> bool:
	return storage_capacity_bonus > 0


## Get all hex offsets in the building footprint.
## @return Array of Vector2i offsets from placement hex
func get_footprint() -> Array[Vector2i]:
	return footprint_hexes.duplicate()

# =============================================================================
# STRING REPRESENTATION
# =============================================================================

func _to_string() -> String:
	var output_info := ""
	if not output_resource_id.is_empty():
		output_info = ", output=%s" % output_resource_id
	return "BuildingData<%s: %s, workers=%d%s>" % [building_id, get_type_name(), max_workers, output_info]
