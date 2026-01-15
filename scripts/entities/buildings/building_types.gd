## BuildingType enum for categorizing building types.
## Used consistently across the building system.
##
## Architecture: scripts/entities/buildings/building_types.gd
## Story: 3-1-create-building-entity-structure
class_name BuildingTypes
extends RefCounted

# =============================================================================
# BUILDING TYPE ENUM
# =============================================================================

## Categories for all building types in the game.
## Used for building categorization and filtering.
enum BuildingType {
	GATHERER,   ## Resource collection buildings (Farm, Sawmill)
	PROCESSOR,  ## Transform resources (Mill, Bakery)
	STORAGE,    ## Store resources (Warehouse)
	SHELTER,    ## Animal rest locations (Shelter)
	UPGRADE,    ## Upgrade other buildings
}

# =============================================================================
# HELPER METHODS
# =============================================================================

## Get the display name for a building type.
## @param type: The BuildingType enum value
## @return String name suitable for UI display
static func get_type_name(type: BuildingType) -> String:
	match type:
		BuildingType.GATHERER:
			return "Gatherer"
		BuildingType.PROCESSOR:
			return "Processor"
		BuildingType.STORAGE:
			return "Storage"
		BuildingType.SHELTER:
			return "Shelter"
		BuildingType.UPGRADE:
			return "Upgrade"
		_:
			return "Unknown"


## Get the description for a building type.
## @param type: The BuildingType enum value
## @return String description of what this category does
static func get_type_description(type: BuildingType) -> String:
	match type:
		BuildingType.GATHERER:
			return "Collects resources from the environment"
		BuildingType.PROCESSOR:
			return "Transforms resources into products"
		BuildingType.STORAGE:
			return "Stores resources for later use"
		BuildingType.SHELTER:
			return "Provides rest for tired animals"
		BuildingType.UPGRADE:
			return "Improves other buildings"
		_:
			return "Unknown building type"
