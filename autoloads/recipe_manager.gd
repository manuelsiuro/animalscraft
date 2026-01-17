## RecipeManager - Central registry for all production recipes.
## Loads recipes from resources folder at startup.
## Provides validation and lookup services.
##
## Architecture: autoloads/recipe_manager.gd
## Order: 13 (depends on EventBus, GameLogger, ResourceManager)
## Story: 4-1-create-recipe-resource-system
##
## Usage:
##   var recipe = RecipeManager.get_recipe("wheat_to_flour")
##   if RecipeManager.can_craft("wheat_to_flour"):
##       print("Can craft flour!")
extends Node

## Cached recipes by recipe_id
var _recipes: Dictionary = {}

## Path to recipe resources
const RECIPES_PATH := "res://resources/recipes/"


func _ready() -> void:
	_load_all_recipes()
	GameLogger.info("RecipeManager", "Loaded %d recipes" % _recipes.size())


## Load all .tres files from recipes folder
func _load_all_recipes() -> void:
	var dir := DirAccess.open(RECIPES_PATH)
	if dir == null:
		GameLogger.warn("RecipeManager", "Recipes folder not found: %s" % RECIPES_PATH)
		return

	dir.list_dir_begin()
	var filename := dir.get_next()

	while filename != "":
		if filename.ends_with(".tres"):
			_load_recipe(RECIPES_PATH + filename)
		filename = dir.get_next()

	dir.list_dir_end()


## Load a single recipe from path
func _load_recipe(path: String) -> void:
	var recipe: RecipeData = load(path) as RecipeData
	if recipe == null:
		GameLogger.warn("RecipeManager", "Failed to load recipe: %s" % path)
		return

	if not recipe.is_valid():
		GameLogger.warn("RecipeManager", "Invalid recipe skipped: %s" % path)
		return

	_recipes[recipe.recipe_id] = recipe
	GameLogger.debug("RecipeManager", "Loaded recipe: %s" % recipe.recipe_id)


## Get recipe by ID, returns null if not found.
## @param recipe_id The unique recipe identifier
## @return RecipeData resource, or null if not found
func get_recipe(recipe_id: String) -> RecipeData:
	return _recipes.get(recipe_id, null)


## Check if recipe exists.
## @param recipe_id The unique recipe identifier
## @return True if recipe is loaded and available
func has_recipe(recipe_id: String) -> bool:
	return _recipes.has(recipe_id)


## Get all loaded recipe IDs.
## @return Array of all recipe_id strings
func get_all_recipe_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in _recipes.keys():
		ids.append(key)
	return ids


## Check if all inputs are available in ResourceManager.
## @param recipe_id The recipe to check craftability for
## @return True if ResourceManager has all required inputs
func can_craft(recipe_id: String) -> bool:
	var recipe := get_recipe(recipe_id)
	if recipe == null:
		return false

	for input in recipe.inputs:
		var resource_id: String = input.get("resource_id", "")
		var amount: int = input.get("amount", 0)
		if not ResourceManager.has_resource(resource_id, amount):
			return false

	return true


## Get inputs array (wrapper for external access).
## @param recipe_id The recipe to get inputs for
## @return Array of input dictionaries, or empty array if recipe not found
func get_inputs(recipe_id: String) -> Array[Dictionary]:
	var recipe := get_recipe(recipe_id)
	if recipe == null:
		GameLogger.warn("RecipeManager", "get_inputs: recipe not found: %s" % recipe_id)
		return []
	# Return a copy to prevent external modification
	var result: Array[Dictionary] = []
	for input in recipe.inputs:
		result.append(input.duplicate())
	return result


## Get outputs array (wrapper for external access).
## @param recipe_id The recipe to get outputs for
## @return Array of output dictionaries, or empty array if recipe not found
func get_outputs(recipe_id: String) -> Array[Dictionary]:
	var recipe := get_recipe(recipe_id)
	if recipe == null:
		GameLogger.warn("RecipeManager", "get_outputs: recipe not found: %s" % recipe_id)
		return []
	# Return a copy to prevent external modification
	var result: Array[Dictionary] = []
	for output in recipe.outputs:
		result.append(output.duplicate())
	return result


## Get list of missing inputs with amounts needed.
## @param recipe_id The recipe to check inputs for
## @return Array of dictionaries with resource_id, have, need, short
func get_missing_inputs(recipe_id: String) -> Array[Dictionary]:
	var missing: Array[Dictionary] = []
	var recipe := get_recipe(recipe_id)
	if recipe == null:
		return missing

	for input in recipe.inputs:
		var resource_id: String = input.get("resource_id", "")
		var needed: int = input.get("amount", 0)
		var current := ResourceManager.get_resource_amount(resource_id)
		if current < needed:
			missing.append({
				"resource_id": resource_id,
				"have": current,
				"need": needed,
				"short": needed - current
			})

	return missing


## Get count of loaded recipes.
## @return Number of valid recipes loaded
func get_recipe_count() -> int:
	return _recipes.size()
