## Unit tests for RecipeData Resource (Story 4-1)
## Tests validation, helper methods, and edge cases.
##
## Run with: godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_recipe_data.gd
extends GutTest

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

## Create a valid recipe for testing
func _create_valid_recipe() -> RecipeData:
	var recipe := RecipeData.new()
	recipe.recipe_id = "test_recipe"
	recipe.display_name = "Test Recipe"
	recipe.description = "A test recipe"
	recipe.inputs = [{"resource_id": "wheat", "amount": 2}]
	recipe.outputs = [{"resource_id": "flour", "amount": 1}]
	recipe.production_time = 3.0
	return recipe


# =============================================================================
# AC1: RecipeData Validation - Valid Recipes
# =============================================================================

func test_valid_recipe_passes_validation() -> void:
	var recipe := _create_valid_recipe()

	assert_true(recipe.is_valid(), "Recipe with all required fields should be valid")


func test_valid_recipe_with_multiple_inputs() -> void:
	var recipe := _create_valid_recipe()
	recipe.inputs = [
		{"resource_id": "wheat", "amount": 2},
		{"resource_id": "water", "amount": 1}
	]

	assert_true(recipe.is_valid(), "Recipe with multiple inputs should be valid")


func test_valid_recipe_with_multiple_outputs() -> void:
	var recipe := _create_valid_recipe()
	recipe.outputs = [
		{"resource_id": "flour", "amount": 1},
		{"resource_id": "chaff", "amount": 1}
	]

	assert_true(recipe.is_valid(), "Recipe with multiple outputs should be valid")


func test_valid_recipe_minimum_production_time() -> void:
	var recipe := _create_valid_recipe()
	recipe.production_time = 0.1  # Minimum positive value

	assert_true(recipe.is_valid(), "Recipe with minimal positive production_time should be valid")


# =============================================================================
# AC10: RecipeData Validation - Empty Inputs
# =============================================================================

func test_empty_inputs_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.inputs = []

	assert_false(recipe.is_valid(), "Recipe with empty inputs should be invalid")


# =============================================================================
# AC10: RecipeData Validation - Empty Outputs
# =============================================================================

func test_empty_outputs_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.outputs = []

	assert_false(recipe.is_valid(), "Recipe with empty outputs should be invalid")


# =============================================================================
# AC10: RecipeData Validation - Zero/Negative Production Time
# =============================================================================

func test_zero_production_time_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.production_time = 0.0

	assert_false(recipe.is_valid(), "Recipe with zero production_time should be invalid")


func test_negative_production_time_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.production_time = -1.0

	assert_false(recipe.is_valid(), "Recipe with negative production_time should be invalid")


# =============================================================================
# AC10: RecipeData Validation - Empty Recipe ID
# =============================================================================

func test_empty_recipe_id_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.recipe_id = ""

	assert_false(recipe.is_valid(), "Recipe with empty recipe_id should be invalid")


# =============================================================================
# AC10: RecipeData Validation - Invalid Input Format
# =============================================================================

func test_input_without_resource_id_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.inputs = [{"amount": 2}]  # Missing resource_id

	assert_false(recipe.is_valid(), "Recipe with input missing resource_id should be invalid")


func test_input_without_amount_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.inputs = [{"resource_id": "wheat"}]  # Missing amount

	assert_false(recipe.is_valid(), "Recipe with input missing amount should be invalid")


func test_input_with_empty_resource_id_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.inputs = [{"resource_id": "", "amount": 2}]

	assert_false(recipe.is_valid(), "Recipe with empty resource_id should be invalid")


func test_input_with_zero_amount_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.inputs = [{"resource_id": "wheat", "amount": 0}]

	assert_false(recipe.is_valid(), "Recipe with zero input amount should be invalid")


func test_input_with_negative_amount_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.inputs = [{"resource_id": "wheat", "amount": -1}]

	assert_false(recipe.is_valid(), "Recipe with negative input amount should be invalid")


# =============================================================================
# AC10: RecipeData Validation - Invalid Output Format
# =============================================================================

func test_output_without_resource_id_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.outputs = [{"amount": 1}]  # Missing resource_id

	assert_false(recipe.is_valid(), "Recipe with output missing resource_id should be invalid")


func test_output_without_amount_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.outputs = [{"resource_id": "flour"}]  # Missing amount

	assert_false(recipe.is_valid(), "Recipe with output missing amount should be invalid")


func test_output_with_empty_resource_id_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.outputs = [{"resource_id": "", "amount": 1}]

	assert_false(recipe.is_valid(), "Recipe with empty output resource_id should be invalid")


func test_output_with_zero_amount_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.outputs = [{"resource_id": "flour", "amount": 0}]

	assert_false(recipe.is_valid(), "Recipe with zero output amount should be invalid")


func test_output_with_negative_amount_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.outputs = [{"resource_id": "flour", "amount": -1}]

	assert_false(recipe.is_valid(), "Recipe with negative output amount should be invalid")


# =============================================================================
# HELPER METHODS: get_input_amount
# =============================================================================

func test_get_input_amount_returns_correct_value() -> void:
	var recipe := _create_valid_recipe()
	recipe.inputs = [{"resource_id": "wheat", "amount": 5}]

	var amount := recipe.get_input_amount("wheat")

	assert_eq(amount, 5, "Should return correct input amount")


func test_get_input_amount_returns_zero_for_missing_resource() -> void:
	var recipe := _create_valid_recipe()

	var amount := recipe.get_input_amount("nonexistent")

	assert_eq(amount, 0, "Should return 0 for resource not in inputs")


func test_get_input_amount_with_multiple_inputs() -> void:
	var recipe := _create_valid_recipe()
	recipe.inputs = [
		{"resource_id": "wheat", "amount": 2},
		{"resource_id": "water", "amount": 3}
	]

	assert_eq(recipe.get_input_amount("wheat"), 2)
	assert_eq(recipe.get_input_amount("water"), 3)


# =============================================================================
# HELPER METHODS: get_output_amount
# =============================================================================

func test_get_output_amount_returns_correct_value() -> void:
	var recipe := _create_valid_recipe()
	recipe.outputs = [{"resource_id": "flour", "amount": 3}]

	var amount := recipe.get_output_amount("flour")

	assert_eq(amount, 3, "Should return correct output amount")


func test_get_output_amount_returns_zero_for_missing_resource() -> void:
	var recipe := _create_valid_recipe()

	var amount := recipe.get_output_amount("nonexistent")

	assert_eq(amount, 0, "Should return 0 for resource not in outputs")


func test_get_output_amount_with_multiple_outputs() -> void:
	var recipe := _create_valid_recipe()
	recipe.outputs = [
		{"resource_id": "flour", "amount": 1},
		{"resource_id": "chaff", "amount": 2}
	]

	assert_eq(recipe.get_output_amount("flour"), 1)
	assert_eq(recipe.get_output_amount("chaff"), 2)


# =============================================================================
# EDGE CASES
# =============================================================================

func test_default_recipe_is_invalid() -> void:
	var recipe := RecipeData.new()

	assert_false(recipe.is_valid(), "Default RecipeData should be invalid")


func test_recipe_with_only_recipe_id_is_invalid() -> void:
	var recipe := RecipeData.new()
	recipe.recipe_id = "test"

	assert_false(recipe.is_valid(), "Recipe with only recipe_id should be invalid")


func test_input_with_wrong_type_for_amount_fails() -> void:
	var recipe := _create_valid_recipe()
	recipe.inputs = [{"resource_id": "wheat", "amount": "two"}]  # String instead of int

	assert_false(recipe.is_valid(), "Recipe with non-int amount should be invalid")


func test_input_with_wrong_type_for_resource_id_fails() -> void:
	var recipe := _create_valid_recipe()
	recipe.inputs = [{"resource_id": 123, "amount": 2}]  # Int instead of String

	assert_false(recipe.is_valid(), "Recipe with non-string resource_id should be invalid")


# =============================================================================
# DUPLICATE DETECTION (Code Review Fix)
# =============================================================================

func test_duplicate_input_resource_ids_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.inputs = [
		{"resource_id": "wheat", "amount": 2},
		{"resource_id": "wheat", "amount": 3}  # Duplicate resource_id
	]

	assert_false(recipe.is_valid(), "Recipe with duplicate input resource_ids should be invalid")


func test_duplicate_output_resource_ids_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.outputs = [
		{"resource_id": "flour", "amount": 1},
		{"resource_id": "flour", "amount": 2}  # Duplicate resource_id
	]

	assert_false(recipe.is_valid(), "Recipe with duplicate output resource_ids should be invalid")


func test_same_resource_in_input_and_output_is_valid() -> void:
	var recipe := _create_valid_recipe()
	recipe.inputs = [{"resource_id": "wheat", "amount": 2}]
	recipe.outputs = [{"resource_id": "wheat", "amount": 1}]  # Same as input is OK

	assert_true(recipe.is_valid(), "Same resource in input and output should be valid")


# =============================================================================
# FLOAT COERCION (Code Review Fix)
# =============================================================================

func test_input_with_float_amount_fails_validation() -> void:
	var recipe := _create_valid_recipe()
	recipe.inputs = [{"resource_id": "wheat", "amount": 2.0}]  # Float instead of int

	assert_false(recipe.is_valid(), "Recipe with float amount should be invalid")
