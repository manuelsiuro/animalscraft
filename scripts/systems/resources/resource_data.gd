## Data resource defining a resource type's properties.
## Used by ResourceManager to validate and configure resources.
##
## Architecture: scripts/systems/resources/resource_data.gd
## Source: game-architecture.md#Resource Systems
##
## Usage:
##   # Load resource data
##   var wheat_data = load("res://resources/resources/wheat_data.tres") as ResourceData
##   if wheat_data.is_valid():
##       print("Resource: %s (max: %d)" % [wheat_data.display_name, wheat_data.max_stack_size])
class_name ResourceData
extends Resource

## Unique identifier for this resource type (e.g., "wheat", "wood", "flour")
@export var resource_id: String = ""

## Display name shown in UI (e.g., "Wheat", "Wood Planks")
@export var display_name: String = ""

## Path to icon texture for UI display (empty for placeholder)
@export var icon_path: String = ""

## Resource category for production chain classification
@export var category: ResourceTypes.ResourceCategory = ResourceTypes.ResourceCategory.RAW

## Maximum amount that can be stored (0 = unlimited, default 999)
@export_range(0, 99999) var max_stack_size: int = 999

## Description for tooltips and information panels
@export_multiline var description: String = ""

## Validate that this resource data has all required fields.
## @return True if resource data is valid and usable
func is_valid() -> bool:
	if resource_id.is_empty():
		return false
	if display_name.is_empty():
		return false
	if max_stack_size < 0:
		return false
	return true
