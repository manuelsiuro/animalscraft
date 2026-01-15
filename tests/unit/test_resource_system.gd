## Unit tests for Resource System (Story 3-2)
## Tests ResourceData, ResourceTypes, and ResourceManager
##
## Run with: godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_resource_system.gd
extends GutTest

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Clear ResourceManager state before each test
	ResourceManager._resources.clear()
	ResourceManager._resource_data_cache.clear()
	await wait_frames(1)


func after_each() -> void:
	ResourceManager._resources.clear()
	await wait_frames(1)


# =============================================================================
# AC1: ResourceData Resource
# =============================================================================

func test_resource_data_is_valid_with_all_fields() -> void:
	var data := ResourceData.new()
	data.resource_id = "test_resource"
	data.display_name = "Test Resource"
	data.max_stack_size = 100

	assert_true(data.is_valid(), "ResourceData should be valid with all required fields")


func test_resource_data_invalid_without_id() -> void:
	var data := ResourceData.new()
	data.display_name = "Test"
	data.max_stack_size = 100

	assert_false(data.is_valid(), "ResourceData should be invalid without resource_id")


func test_resource_data_invalid_without_display_name() -> void:
	var data := ResourceData.new()
	data.resource_id = "test"
	data.max_stack_size = 100

	assert_false(data.is_valid(), "ResourceData should be invalid without display_name")


func test_resource_data_invalid_with_negative_stack() -> void:
	var data := ResourceData.new()
	data.resource_id = "test"
	data.display_name = "Test"
	data.max_stack_size = -1

	assert_false(data.is_valid(), "ResourceData should be invalid with negative max_stack_size")


func test_resource_data_valid_with_zero_stack_unlimited() -> void:
	var data := ResourceData.new()
	data.resource_id = "test"
	data.display_name = "Test"
	data.max_stack_size = 0  # 0 means unlimited

	assert_true(data.is_valid(), "ResourceData should be valid with max_stack_size=0 (unlimited)")


# =============================================================================
# AC2: ResourceCategory Enum
# =============================================================================

func test_resource_category_enum_has_expected_values() -> void:
	assert_eq(ResourceTypes.ResourceCategory.RAW, 0, "RAW should be 0")
	assert_eq(ResourceTypes.ResourceCategory.PROCESSED, 1, "PROCESSED should be 1")
	assert_eq(ResourceTypes.ResourceCategory.FINAL, 2, "FINAL should be 2")


func test_get_category_name_returns_correct_strings() -> void:
	assert_eq(ResourceTypes.get_category_name(ResourceTypes.ResourceCategory.RAW), "Raw Material")
	assert_eq(ResourceTypes.get_category_name(ResourceTypes.ResourceCategory.PROCESSED), "Processed Good")
	assert_eq(ResourceTypes.get_category_name(ResourceTypes.ResourceCategory.FINAL), "Final Product")


func test_get_category_name_unknown_returns_unknown() -> void:
	# Test with invalid category value
	var result := ResourceTypes.get_category_name(99 as ResourceTypes.ResourceCategory)
	assert_eq(result, "Unknown", "Unknown category should return 'Unknown'")


# =============================================================================
# AC4: Add Resources
# =============================================================================

func test_add_resource_creates_new_entry() -> void:
	var result := ResourceManager.add_resource("wheat", 50)

	assert_eq(result, 50, "add_resource should return new total")
	assert_eq(ResourceManager.get_resource_amount("wheat"), 50, "Resource amount should be 50")


func test_add_resource_increments_existing() -> void:
	ResourceManager.add_resource("wheat", 50)
	var result := ResourceManager.add_resource("wheat", 30)

	assert_eq(result, 80, "add_resource should return incremented total")
	assert_eq(ResourceManager.get_resource_amount("wheat"), 80)


func test_add_resource_emits_signal() -> void:
	watch_signals(EventBus)

	ResourceManager.add_resource("wood", 25)

	assert_signal_emitted_with_parameters(EventBus, "resource_changed", ["wood", 25])


func test_add_resource_rejects_zero_amount() -> void:
	ResourceManager.add_resource("wheat", 100)
	var result := ResourceManager.add_resource("wheat", 0)

	assert_eq(result, 100, "Zero amount should be rejected, return unchanged")


func test_add_resource_rejects_negative_amount() -> void:
	ResourceManager.add_resource("wheat", 100)
	var result := ResourceManager.add_resource("wheat", -50)

	assert_eq(result, 100, "Negative amount should be rejected, return unchanged")


# =============================================================================
# AC5: Remove Resources
# =============================================================================

func test_remove_resource_succeeds_with_sufficient_stock() -> void:
	ResourceManager.add_resource("wheat", 100)

	var result := ResourceManager.remove_resource("wheat", 30)

	assert_true(result, "remove_resource should succeed with sufficient stock")
	assert_eq(ResourceManager.get_resource_amount("wheat"), 70)


func test_remove_resource_fails_with_insufficient_stock() -> void:
	ResourceManager.add_resource("wheat", 20)

	var result := ResourceManager.remove_resource("wheat", 50)

	assert_false(result, "remove_resource should fail with insufficient stock")
	assert_eq(ResourceManager.get_resource_amount("wheat"), 20, "Amount should be unchanged")


func test_remove_resource_emits_changed_signal() -> void:
	ResourceManager.add_resource("wheat", 100)
	watch_signals(EventBus)

	ResourceManager.remove_resource("wheat", 30)

	assert_signal_emitted_with_parameters(EventBus, "resource_changed", ["wheat", 70])


func test_remove_resource_emits_depleted_at_zero() -> void:
	ResourceManager.add_resource("wheat", 50)
	watch_signals(EventBus)

	ResourceManager.remove_resource("wheat", 50)

	assert_signal_emitted_with_parameters(EventBus, "resource_depleted", ["wheat"])


func test_remove_resource_rejects_zero_amount() -> void:
	ResourceManager.add_resource("wheat", 100)

	var result := ResourceManager.remove_resource("wheat", 0)

	assert_false(result, "Zero amount should be rejected")
	assert_eq(ResourceManager.get_resource_amount("wheat"), 100)


func test_remove_resource_rejects_negative_amount() -> void:
	ResourceManager.add_resource("wheat", 100)

	var result := ResourceManager.remove_resource("wheat", -50)

	assert_false(result, "Negative amount should be rejected")
	assert_eq(ResourceManager.get_resource_amount("wheat"), 100)


func test_remove_more_than_available_does_not_go_negative() -> void:
	ResourceManager.add_resource("wheat", 10)

	var result := ResourceManager.remove_resource("wheat", 100)

	assert_false(result, "Should fail when removing more than available")
	assert_eq(ResourceManager.get_resource_amount("wheat"), 10, "Amount should not go negative")


# =============================================================================
# AC6: Query Resources
# =============================================================================

func test_get_resource_amount_returns_zero_for_unknown() -> void:
	var amount := ResourceManager.get_resource_amount("nonexistent")

	assert_eq(amount, 0, "Unknown resource should return 0")


func test_has_resource_returns_true_when_sufficient() -> void:
	ResourceManager.add_resource("wood", 100)

	assert_true(ResourceManager.has_resource("wood", 50), "Should have 50 when we have 100")
	assert_true(ResourceManager.has_resource("wood", 100), "Should have 100 when we have 100")


func test_has_resource_returns_false_when_insufficient() -> void:
	ResourceManager.add_resource("wood", 30)

	assert_false(ResourceManager.has_resource("wood", 50), "Should not have 50 when we have 30")


func test_has_resource_returns_false_for_unknown() -> void:
	assert_false(ResourceManager.has_resource("unknown", 1), "Unknown resource should return false")


func test_get_all_resources_returns_copy() -> void:
	ResourceManager.add_resource("wheat", 100)
	ResourceManager.add_resource("wood", 50)

	var all_resources := ResourceManager.get_all_resources()
	all_resources["wheat"] = 999  # Modify copy

	assert_eq(ResourceManager.get_resource_amount("wheat"), 100, "Original should be unchanged")


func test_get_all_resources_contains_all_resources() -> void:
	ResourceManager.add_resource("wheat", 100)
	ResourceManager.add_resource("wood", 50)
	ResourceManager.add_resource("stone", 25)

	var all_resources := ResourceManager.get_all_resources()

	assert_eq(all_resources.size(), 3, "Should have 3 resources")
	assert_eq(all_resources["wheat"], 100)
	assert_eq(all_resources["wood"], 50)
	assert_eq(all_resources["stone"], 25)


# =============================================================================
# AC7: Storage Limits
# =============================================================================

func test_add_resource_respects_storage_limit() -> void:
	# Assuming wheat_data.tres has max_stack_size = 500
	ResourceManager.add_resource("wheat", 400)
	var result := ResourceManager.add_resource("wheat", 200)

	assert_eq(result, 500, "Should be capped at storage limit")
	assert_eq(ResourceManager.get_resource_amount("wheat"), 500)


func test_get_storage_limit_returns_data_value() -> void:
	# wheat_data.tres has max_stack_size = 500
	var limit := ResourceManager.get_storage_limit("wheat")

	assert_eq(limit, 500, "Wheat should have limit of 500")


func test_get_storage_limit_returns_default_for_unknown() -> void:
	var limit := ResourceManager.get_storage_limit("unknown_resource")

	# Story 3-3: Unknown resources use DEFAULT_VILLAGE_STORAGE_CAPACITY (100)
	# when no StorageManager is available
	assert_eq(limit, GameConstants.DEFAULT_VILLAGE_STORAGE_CAPACITY, "Unknown resource should return default village capacity")


func test_is_storage_full_returns_true_at_capacity() -> void:
	# Fill to capacity
	ResourceManager._resources["wheat"] = 500

	assert_true(ResourceManager.is_storage_full("wheat"), "Should be full at 500")


func test_is_storage_full_returns_false_below_capacity() -> void:
	ResourceManager._resources["wheat"] = 400

	assert_false(ResourceManager.is_storage_full("wheat"), "Should not be full at 400")


func test_is_storage_full_returns_false_for_unknown() -> void:
	# Unknown resources with default large limit should not be considered full
	assert_false(ResourceManager.is_storage_full("unknown"), "Unknown resource should not be full at 0")


func test_add_resource_emits_full_signal_at_capacity() -> void:
	ResourceManager._resources["wheat"] = 450
	watch_signals(EventBus)

	ResourceManager.add_resource("wheat", 100)  # Would exceed 500

	assert_signal_emitted_with_parameters(EventBus, "resource_full", ["wheat"])


func test_add_resource_emits_full_signal_when_reaching_limit_exactly() -> void:
	ResourceManager._resources["wheat"] = 400
	watch_signals(EventBus)

	ResourceManager.add_resource("wheat", 100)  # Exactly 500

	assert_signal_emitted_with_parameters(EventBus, "resource_full", ["wheat"])


# =============================================================================
# AC9: Save/Load
# =============================================================================

func test_get_save_data_returns_serializable_dict() -> void:
	ResourceManager.add_resource("wheat", 100)
	ResourceManager.add_resource("wood", 50)

	var save_data := ResourceManager.get_save_data()

	assert_has(save_data, "resources", "Save data should have 'resources' key")
	assert_eq(save_data["resources"]["wheat"], 100)
	assert_eq(save_data["resources"]["wood"], 50)


func test_get_save_data_returns_copy() -> void:
	ResourceManager.add_resource("wheat", 100)

	var save_data := ResourceManager.get_save_data()
	save_data["resources"]["wheat"] = 999

	assert_eq(ResourceManager.get_resource_amount("wheat"), 100, "Original should be unchanged")


func test_load_save_data_restores_state() -> void:
	var save_data := {
		"resources": {
			"wheat": 200,
			"stone": 75
		}
	}

	ResourceManager.load_save_data(save_data)

	assert_eq(ResourceManager.get_resource_amount("wheat"), 200)
	assert_eq(ResourceManager.get_resource_amount("stone"), 75)


func test_load_save_data_clears_existing_resources() -> void:
	ResourceManager.add_resource("wood", 1000)

	var save_data := {
		"resources": {
			"wheat": 100
		}
	}

	ResourceManager.load_save_data(save_data)

	assert_eq(ResourceManager.get_resource_amount("wood"), 0, "Existing resources should be cleared")
	assert_eq(ResourceManager.get_resource_amount("wheat"), 100)


func test_load_save_data_emits_signals() -> void:
	var save_data := {
		"resources": {
			"wheat": 100
		}
	}
	watch_signals(EventBus)

	ResourceManager.load_save_data(save_data)

	assert_signal_emitted(EventBus, "resource_changed")


func test_load_save_data_handles_empty_dict() -> void:
	ResourceManager.add_resource("wheat", 100)

	ResourceManager.load_save_data({})

	assert_eq(ResourceManager.get_resource_amount("wheat"), 0, "Resources should be cleared")


func test_load_save_data_handles_missing_resources_key() -> void:
	ResourceManager.add_resource("wheat", 100)

	ResourceManager.load_save_data({"other_data": 123})

	assert_eq(ResourceManager.get_resource_amount("wheat"), 0, "Resources should be cleared")


func test_load_save_data_handles_non_dictionary_resources_value() -> void:
	ResourceManager.add_resource("wheat", 100)

	# Pass malformed data where "resources" is not a Dictionary
	ResourceManager.load_save_data({"resources": "invalid_string"})

	assert_eq(ResourceManager.get_resource_amount("wheat"), 0, "Resources should be cleared even with malformed data")


# =============================================================================
# AC8: Initial Resource Types - Data File Loading
# =============================================================================

func test_wheat_data_loads_correctly() -> void:
	var wheat_data := load("res://resources/resources/wheat_data.tres") as ResourceData

	assert_not_null(wheat_data, "Wheat data should load")
	assert_eq(wheat_data.resource_id, "wheat")
	assert_eq(wheat_data.display_name, "Wheat")
	assert_eq(wheat_data.category, ResourceTypes.ResourceCategory.RAW)
	assert_eq(wheat_data.max_stack_size, 500)
	assert_true(wheat_data.is_valid())


func test_wood_data_loads_correctly() -> void:
	var wood_data := load("res://resources/resources/wood_data.tres") as ResourceData

	assert_not_null(wood_data, "Wood data should load")
	assert_eq(wood_data.resource_id, "wood")
	assert_eq(wood_data.display_name, "Wood")
	assert_eq(wood_data.category, ResourceTypes.ResourceCategory.RAW)
	assert_eq(wood_data.max_stack_size, 500)
	assert_true(wood_data.is_valid())


func test_stone_data_loads_correctly() -> void:
	var stone_data := load("res://resources/resources/stone_data.tres") as ResourceData

	assert_not_null(stone_data, "Stone data should load")
	assert_eq(stone_data.resource_id, "stone")
	assert_eq(stone_data.display_name, "Stone")
	assert_eq(stone_data.category, ResourceTypes.ResourceCategory.RAW)
	assert_eq(stone_data.max_stack_size, 500)
	assert_true(stone_data.is_valid())


# =============================================================================
# CLEAR ALL RESOURCES
# =============================================================================

func test_clear_all_clears_resources() -> void:
	ResourceManager.add_resource("wheat", 100)
	ResourceManager.add_resource("wood", 50)

	ResourceManager.clear_all()

	assert_eq(ResourceManager.get_resource_amount("wheat"), 0)
	assert_eq(ResourceManager.get_resource_amount("wood"), 0)
	assert_eq(ResourceManager.get_all_resources().size(), 0)


func test_clear_all_emits_signals() -> void:
	ResourceManager.add_resource("wheat", 100)
	watch_signals(EventBus)

	ResourceManager.clear_all()

	assert_signal_emitted(EventBus, "resource_changed")
	assert_signal_emitted(EventBus, "resource_depleted")


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

func test_integration_resource_manager_autoload_accessible() -> void:
	# Verify ResourceManager is accessible as autoload singleton
	assert_not_null(ResourceManager, "ResourceManager autoload should be accessible")


func test_integration_eventbus_signals_connected() -> void:
	# Verify EventBus has the required resource signals
	assert_true(EventBus.has_signal("resource_changed"), "EventBus should have resource_changed signal")
	assert_true(EventBus.has_signal("resource_depleted"), "EventBus should have resource_depleted signal")
	assert_true(EventBus.has_signal("resource_full"), "EventBus should have resource_full signal")


func test_integration_game_constants_resource_values() -> void:
	# Verify GameConstants has resource-related constants
	assert_eq(GameConstants.DEFAULT_RESOURCE_STACK_SIZE, 999, "DEFAULT_RESOURCE_STACK_SIZE should be 999")
	assert_eq(GameConstants.RESOURCE_LOW_THRESHOLD, 10, "RESOURCE_LOW_THRESHOLD should be 10")


func test_integration_save_load_roundtrip() -> void:
	# Full save/load roundtrip test
	ResourceManager.add_resource("wheat", 100)
	ResourceManager.add_resource("wood", 50)
	ResourceManager.add_resource("stone", 25)

	# Save
	var save_data := ResourceManager.get_save_data()

	# Clear and verify cleared
	ResourceManager.clear_all()
	assert_eq(ResourceManager.get_resource_amount("wheat"), 0)

	# Load and verify restored
	ResourceManager.load_save_data(save_data)
	assert_eq(ResourceManager.get_resource_amount("wheat"), 100)
	assert_eq(ResourceManager.get_resource_amount("wood"), 50)
	assert_eq(ResourceManager.get_resource_amount("stone"), 25)
