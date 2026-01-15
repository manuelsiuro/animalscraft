## Resource category definitions and helpers.
## Provides enum for categorizing resources in production chains.
##
## Architecture: scripts/systems/resources/resource_types.gd
## Source: game-architecture.md#Resource Systems
##
## Usage:
##   var category = ResourceTypes.ResourceCategory.RAW
##   var name = ResourceTypes.get_category_name(category)
class_name ResourceTypes
extends RefCounted

## Categories for classifying resources in production chains.
## RAW: Gathered directly from environment (wheat, wood, stone)
## PROCESSED: Intermediate products from processing (flour, planks, metal)
## FINAL: End products ready for consumption or use (bread, tools)
enum ResourceCategory {
	RAW,       ## Gathered from environment (wheat, wood, stone)
	PROCESSED, ## Intermediate products (flour, planks, metal)
	FINAL      ## End products (bread, tools, food ammo)
}

## Get human-readable name for a resource category.
## @param category The ResourceCategory enum value
## @return Human-readable category name for UI display
static func get_category_name(category: ResourceCategory) -> String:
	match category:
		ResourceCategory.RAW:
			return "Raw Material"
		ResourceCategory.PROCESSED:
			return "Processed Good"
		ResourceCategory.FINAL:
			return "Final Product"
		_:
			return "Unknown"
