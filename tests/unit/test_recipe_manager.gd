## Unit tests for RecipeManager Autoload (Story 4-1)
## Tests recipe loading, lookup, and crafting validation.
##
## Run with: godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_recipe_manager.gd
extends GutTest

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Clear ResourceManager state before each test
	ResourceManager._resources.clear()
	ResourceManager._resource_data_cache.clear()
	ResourceManager._warning_emitted.clear()
	ResourceManager._gathering_paused.clear()
	await wait_frames(1)


func after_each() -> void:
	ResourceManager._resources.clear()
	await wait_frames(1)


# =============================================================================
# AC7: RecipeManager Loads Recipes from Resources Folder
# =============================================================================

func test_recipe_manager_is_accessible() -> void:
	assert_not_null(RecipeManager, "RecipeManager autoload should be accessible")


func test_recipe_manager_loads_recipes_on_ready() -> void:
	var recipe_count := RecipeManager.get_recipe_count()

	assert_gt(recipe_count, 0, "RecipeManager should have loaded at least one recipe")


func test_wheat_to_flour_recipe_loads_correctly() -> void:
	var recipe := RecipeManager.get_recipe("wheat_to_flour")

	assert_not_null(recipe, "wheat_to_flour recipe should be loaded")
	assert_eq(recipe.recipe_id, "wheat_to_flour")
	assert_eq(recipe.display_name, "Grind Wheat")
	assert_eq(recipe.production_time, 3.0)
	assert_true(recipe.is_valid())


func test_flour_to_bread_recipe_loads_correctly() -> void:
	var recipe := RecipeManager.get_recipe("flour_to_bread")

	assert_not_null(recipe, "flour_to_bread recipe should be loaded")
	assert_eq(recipe.recipe_id, "flour_to_bread")
	assert_eq(recipe.display_name, "Bake Bread")
	assert_eq(recipe.production_time, 4.0)
	assert_true(recipe.is_valid())


# =============================================================================
# AC8: Get Recipe by ID
# =============================================================================

func test_get_recipe_returns_correct_data() -> void:
	var recipe := RecipeManager.get_recipe("wheat_to_flour")

	assert_not_null(recipe)
	assert_eq(recipe.recipe_id, "wheat_to_flour")


func test_get_recipe_returns_null_for_invalid_id() -> void:
	var recipe := RecipeManager.get_recipe("nonexistent_recipe")

	assert_null(recipe, "get_recipe should return null for invalid ID")


func test_has_recipe_returns_true_for_existing() -> void:
	var has := RecipeManager.has_recipe("wheat_to_flour")

	assert_true(has, "has_recipe should return true for existing recipe")


func test_has_recipe_returns_false_for_nonexistent() -> void:
	var has := RecipeManager.has_recipe("nonexistent_recipe")

	assert_false(has, "has_recipe should return false for nonexistent recipe")


func test_get_all_recipe_ids_returns_loaded_recipes() -> void:
	var ids := RecipeManager.get_all_recipe_ids()

	assert_has(ids, "wheat_to_flour", "Should include wheat_to_flour")
	assert_has(ids, "flour_to_bread", "Should include flour_to_bread")


# =============================================================================
# AC4: can_craft Returns True with Sufficient Resources
# =============================================================================

func test_can_craft_returns_true_with_sufficient_resources() -> void:
	# wheat_to_flour needs 2 wheat
	ResourceManager.add_resource("wheat", 10)

	var can := RecipeManager.can_craft("wheat_to_flour")

	assert_true(can, "can_craft should return true when resources available")


func test_can_craft_returns_true_with_exact_resources() -> void:
	# wheat_to_flour needs exactly 2 wheat
	ResourceManager.add_resource("wheat", 2)

	var can := RecipeManager.can_craft("wheat_to_flour")

	assert_true(can, "can_craft should return true with exact amount needed")


# =============================================================================
# AC4: can_craft Returns False with Insufficient Resources
# =============================================================================

func test_can_craft_returns_false_with_insufficient_resources() -> void:
	# wheat_to_flour needs 2 wheat, only have 1
	ResourceManager.add_resource("wheat", 1)

	var can := RecipeManager.can_craft("wheat_to_flour")

	assert_false(can, "can_craft should return false with insufficient resources")


func test_can_craft_returns_false_with_no_resources() -> void:
	# No resources at all
	var can := RecipeManager.can_craft("wheat_to_flour")

	assert_false(can, "can_craft should return false with no resources")


func test_can_craft_returns_false_for_invalid_recipe() -> void:
	var can := RecipeManager.can_craft("nonexistent_recipe")

	assert_false(can, "can_craft should return false for invalid recipe ID")


# =============================================================================
# AC5: get_inputs Returns Correct Array
# =============================================================================

func test_get_inputs_returns_correct_array() -> void:
	var inputs := RecipeManager.get_inputs("wheat_to_flour")

	assert_eq(inputs.size(), 1, "wheat_to_flour should have 1 input")
	assert_eq(inputs[0]["resource_id"], "wheat")
	assert_eq(inputs[0]["amount"], 2)


func test_get_inputs_returns_empty_for_invalid_recipe() -> void:
	var inputs := RecipeManager.get_inputs("nonexistent_recipe")

	assert_eq(inputs.size(), 0, "get_inputs should return empty array for invalid recipe")


func test_get_inputs_returns_copy() -> void:
	var inputs := RecipeManager.get_inputs("wheat_to_flour")
	inputs[0]["amount"] = 999  # Modify the copy

	var inputs_again := RecipeManager.get_inputs("wheat_to_flour")

	assert_eq(inputs_again[0]["amount"], 2, "Original inputs should be unchanged")


# =============================================================================
# AC6: get_outputs Returns Correct Array
# =============================================================================

func test_get_outputs_returns_correct_array() -> void:
	var outputs := RecipeManager.get_outputs("wheat_to_flour")

	assert_eq(outputs.size(), 1, "wheat_to_flour should have 1 output")
	assert_eq(outputs[0]["resource_id"], "flour")
	assert_eq(outputs[0]["amount"], 1)


func test_get_outputs_returns_empty_for_invalid_recipe() -> void:
	var outputs := RecipeManager.get_outputs("nonexistent_recipe")

	assert_eq(outputs.size(), 0, "get_outputs should return empty array for invalid recipe")


func test_get_outputs_returns_copy() -> void:
	var outputs := RecipeManager.get_outputs("wheat_to_flour")
	outputs[0]["amount"] = 999  # Modify the copy

	var outputs_again := RecipeManager.get_outputs("wheat_to_flour")

	assert_eq(outputs_again[0]["amount"], 1, "Original outputs should be unchanged")


# =============================================================================
# get_missing_inputs Helper Method
# =============================================================================

func test_get_missing_inputs_shows_shortage() -> void:
	# wheat_to_flour needs 2 wheat, only have 1
	ResourceManager.add_resource("wheat", 1)

	var missing := RecipeManager.get_missing_inputs("wheat_to_flour")

	assert_eq(missing.size(), 1, "Should have 1 missing input")
	assert_eq(missing[0]["resource_id"], "wheat")
	assert_eq(missing[0]["have"], 1)
	assert_eq(missing[0]["need"], 2)
	assert_eq(missing[0]["short"], 1)


func test_get_missing_inputs_empty_when_sufficient() -> void:
	ResourceManager.add_resource("wheat", 10)

	var missing := RecipeManager.get_missing_inputs("wheat_to_flour")

	assert_eq(missing.size(), 0, "Should have no missing inputs when resources sufficient")


func test_get_missing_inputs_returns_empty_for_invalid_recipe() -> void:
	var missing := RecipeManager.get_missing_inputs("nonexistent_recipe")

	assert_eq(missing.size(), 0, "get_missing_inputs should return empty for invalid recipe")


func test_get_missing_inputs_with_no_resources() -> void:
	var missing := RecipeManager.get_missing_inputs("wheat_to_flour")

	assert_eq(missing.size(), 1)
	assert_eq(missing[0]["have"], 0)
	assert_eq(missing[0]["need"], 2)
	assert_eq(missing[0]["short"], 2)


# =============================================================================
# INTEGRATION: Full Bread Chain Validation
# =============================================================================

func test_integration_bread_chain_can_craft_flour() -> void:
	# Add enough wheat for flour
	ResourceManager.add_resource("wheat", 10)

	# Can make flour
	assert_true(RecipeManager.can_craft("wheat_to_flour"))

	# Get recipe details
	var recipe := RecipeManager.get_recipe("wheat_to_flour")
	assert_not_null(recipe)
	assert_eq(recipe.get_input_amount("wheat"), 2)
	assert_eq(recipe.get_output_amount("flour"), 1)


func test_integration_bread_chain_can_craft_bread() -> void:
	# Add flour for bread
	ResourceManager.add_resource("flour", 5)

	# Can make bread
	assert_true(RecipeManager.can_craft("flour_to_bread"))

	# Get recipe details
	var recipe := RecipeManager.get_recipe("flour_to_bread")
	assert_not_null(recipe)
	assert_eq(recipe.get_input_amount("flour"), 1)
	assert_eq(recipe.get_output_amount("bread"), 1)


func test_integration_bread_chain_cannot_bake_without_flour() -> void:
	# Only have wheat, no flour
	ResourceManager.add_resource("wheat", 100)

	# Cannot make bread without flour
	assert_false(RecipeManager.can_craft("flour_to_bread"))


func test_integration_full_chain_simulation() -> void:
	# Start with wheat
	ResourceManager.add_resource("wheat", 4)

	# Step 1: Can craft flour
	assert_true(RecipeManager.can_craft("wheat_to_flour"))

	# Simulate crafting flour (2 wheat -> 1 flour)
	ResourceManager.remove_resource("wheat", 2)
	ResourceManager.add_resource("flour", 1)

	# Step 2: Can now craft bread
	assert_true(RecipeManager.can_craft("flour_to_bread"))

	# Simulate crafting bread (1 flour -> 1 bread)
	ResourceManager.remove_resource("flour", 1)
	ResourceManager.add_resource("bread", 1)

	# Verify final state
	assert_eq(ResourceManager.get_resource_amount("wheat"), 2)
	assert_eq(ResourceManager.get_resource_amount("flour"), 0)
	assert_eq(ResourceManager.get_resource_amount("bread"), 1)


# =============================================================================
# RESOURCE DATA FILES
# =============================================================================

func test_flour_data_loads_correctly() -> void:
	var flour_data := load("res://resources/resources/flour_data.tres") as ResourceData

	assert_not_null(flour_data, "Flour data should load")
	assert_eq(flour_data.resource_id, "flour")
	assert_eq(flour_data.display_name, "Flour")
	assert_eq(flour_data.category, ResourceTypes.ResourceCategory.PROCESSED)
	assert_true(flour_data.is_valid())


func test_bread_data_loads_correctly() -> void:
	var bread_data := load("res://resources/resources/bread_data.tres") as ResourceData

	assert_not_null(bread_data, "Bread data should load")
	assert_eq(bread_data.resource_id, "bread")
	assert_eq(bread_data.display_name, "Bread")
	assert_eq(bread_data.category, ResourceTypes.ResourceCategory.FINAL)
	assert_true(bread_data.is_valid())
