## RecipeData - Defines input/output transformation for production buildings.
## Each recipe specifies what resources are consumed and produced.
##
## Architecture: scripts/systems/production/recipe_data.gd
## Story: 4-1-create-recipe-resource-system
##
## Usage:
##   var recipe = load("res://resources/recipes/wheat_to_flour.tres") as RecipeData
##   if recipe.is_valid():
##       print("Recipe: %s takes %d seconds" % [recipe.display_name, recipe.production_time])
class_name RecipeData
extends Resource

## Unique identifier for this recipe (e.g., "wheat_to_flour")
@export var recipe_id: String = ""

## Human-readable name for UI (e.g., "Grind Wheat")
@export var display_name: String = ""

## Description explaining the production process
@export_multiline var description: String = ""

## Input resources required: [{resource_id: String, amount: int}, ...]
## All inputs must be present and consumed for one production cycle
@export var inputs: Array[Dictionary] = []

## Output resources produced: [{resource_id: String, amount: int}, ...]
## All outputs are generated when production completes
@export var outputs: Array[Dictionary] = []

## Time in seconds for one production cycle
@export_range(0.1, 300.0, 0.1) var production_time: float = 5.0


## Validates that this recipe has all required fields.
## Checks: recipe_id present, inputs not empty, outputs not empty,
## production_time positive, all inputs/outputs have valid resource_id and amount,
## no duplicate resource_ids in inputs or outputs.
## @return True if recipe data is valid and usable
func is_valid() -> bool:
	if recipe_id.is_empty():
		return false
	if inputs.is_empty():
		return false
	if outputs.is_empty():
		return false
	if production_time <= 0.0:
		return false

	# Validate each input and check for duplicates
	var seen_input_ids: Array[String] = []
	for input in inputs:
		if not input.has("resource_id") or not input.has("amount"):
			return false
		if not input["resource_id"] is String or input["resource_id"].is_empty():
			return false
		if not input["amount"] is int or input["amount"] <= 0:
			return false
		# Check for duplicate resource_id
		if input["resource_id"] in seen_input_ids:
			return false
		seen_input_ids.append(input["resource_id"])

	# Validate each output and check for duplicates
	var seen_output_ids: Array[String] = []
	for output in outputs:
		if not output.has("resource_id") or not output.has("amount"):
			return false
		if not output["resource_id"] is String or output["resource_id"].is_empty():
			return false
		if not output["amount"] is int or output["amount"] <= 0:
			return false
		# Check for duplicate resource_id
		if output["resource_id"] in seen_output_ids:
			return false
		seen_output_ids.append(output["resource_id"])

	return true


## Returns the required amount of a specific input resource.
## @param resource_id The resource type identifier to look up
## @return Amount required, or 0 if resource not in inputs
func get_input_amount(resource_id: String) -> int:
	for input in inputs:
		if input.has("resource_id") and input["resource_id"] == resource_id:
			if input.has("amount") and input["amount"] is int:
				return input["amount"]
	return 0


## Returns the produced amount of a specific output resource.
## @param resource_id The resource type identifier to look up
## @return Amount produced, or 0 if resource not in outputs
func get_output_amount(resource_id: String) -> int:
	for output in outputs:
		if output.has("resource_id") and output["resource_id"] == resource_id:
			if output.has("amount") and output["amount"] is int:
				return output["amount"]
	return 0
