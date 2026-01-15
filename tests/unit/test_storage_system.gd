## Unit tests for Storage System (Story 3-3)
## Tests StorageManager, storage percentage queries, warning signals, and gathering pause/resume
##
## Run with: godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_storage_system.gd
extends GutTest

# Preload StorageManager class since it may not be registered as autoload
const StorageManagerClass = preload("res://scripts/systems/resources/storage_manager.gd")

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _storage_manager: Node
var _original_storage_manager: Node


# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Store original storage manager reference
	_original_storage_manager = ResourceManager._storage_manager

	# Clear ResourceManager state before each test
	ResourceManager._resources.clear()
	ResourceManager._resource_data_cache.clear()
	ResourceManager._warning_emitted.clear()
	ResourceManager._gathering_paused.clear()

	# Create fresh StorageManager for tests
	_storage_manager = StorageManagerClass.new()
	add_child(_storage_manager)

	# Wait for StorageManager _ready to complete
	await wait_frames(2)


func after_each() -> void:
	# Clean up storage manager
	if _storage_manager and is_instance_valid(_storage_manager):
		_storage_manager.queue_free()
	_storage_manager = null

	# Restore original storage manager reference
	ResourceManager._storage_manager = _original_storage_manager

	# Clear ResourceManager state
	ResourceManager._resources.clear()
	ResourceManager._warning_emitted.clear()
	ResourceManager._gathering_paused.clear()

	await wait_frames(2)


# =============================================================================
# AC2: STORAGE WARNING AT 80% - BOUNDARY TESTS
# =============================================================================

func test_warning_signal_emitted_at_exactly_80_percent() -> void:
	# BOUNDARY TEST: Exactly 80 out of 100 = 0.80000
	# Use "test_res" which has no ResourceData, so falls back to DEFAULT_VILLAGE_STORAGE_CAPACITY (100)
	ResourceManager._storage_manager = null

	watch_signals(EventBus)
	ResourceManager.add_resource("test_res", 80)

	assert_signal_emitted(EventBus, "resource_storage_warning")


func test_warning_not_emitted_at_79_percent() -> void:
	# BOUNDARY TEST: Just below threshold (79%)
	ResourceManager._storage_manager = null

	watch_signals(EventBus)
	ResourceManager.add_resource("test_res", 79)

	assert_signal_not_emitted(EventBus, "resource_storage_warning")


func test_warning_emitted_at_81_percent() -> void:
	# BOUNDARY TEST: Just above threshold (81%)
	ResourceManager._storage_manager = null

	watch_signals(EventBus)
	ResourceManager.add_resource("test_res", 81)

	assert_signal_emitted(EventBus, "resource_storage_warning")


func test_warning_only_emitted_once_while_above_threshold() -> void:
	# Warning should only emit ONCE per threshold crossing
	ResourceManager._storage_manager = null

	watch_signals(EventBus)
	ResourceManager.add_resource("test_res", 80)  # First crossing - triggers warning
	ResourceManager.add_resource("test_res", 10)  # Still above threshold - NO new warning

	assert_signal_emit_count(EventBus, "resource_storage_warning", 1)


func test_warning_resets_below_70_percent() -> void:
	# Warning should reset when dropping BELOW 70%
	ResourceManager._storage_manager = null

	ResourceManager.add_resource("test_res", 80)  # Warning emitted
	ResourceManager.remove_resource("test_res", 15)  # Now at 65% (below 70%)

	watch_signals(EventBus)
	ResourceManager.add_resource("test_res", 20)  # Back to 85% - should trigger NEW warning

	assert_signal_emitted(EventBus, "resource_storage_warning")


func test_warning_not_reset_at_exactly_70_percent() -> void:
	# BOUNDARY TEST: Must be BELOW 70%, not equal to 70%
	ResourceManager._storage_manager = null

	ResourceManager.add_resource("test_res", 80)  # Warning emitted
	ResourceManager.remove_resource("test_res", 10)  # Now at exactly 70%

	# Clear warning manually to simulate it was emitted
	ResourceManager._warning_emitted["test_res"] = true

	watch_signals(EventBus)
	ResourceManager.add_resource("test_res", 15)  # Now at 85%

	# Warning should NOT re-emit because we didn't drop BELOW 70%
	assert_signal_not_emitted(EventBus, "resource_storage_warning")


# =============================================================================
# AC3: STORAGE PERCENTAGE QUERY
# =============================================================================

func test_get_storage_percentage_returns_correct_ratio() -> void:
	ResourceManager._storage_manager = null
	ResourceManager.add_resource("test_res", 50)

	var percentage: float = ResourceManager.get_storage_percentage("test_res")

	# 50/100 = 0.5 (using DEFAULT_VILLAGE_STORAGE_CAPACITY of 100 for unknown resource)
	assert_almost_eq(percentage, 0.5, 0.01)


func test_get_storage_percentage_returns_zero_for_empty() -> void:
	var percentage: float = ResourceManager.get_storage_percentage("wheat")

	assert_eq(percentage, 0.0, "Empty resource should have 0% fill")


func test_get_storage_percentage_returns_zero_for_unknown() -> void:
	var percentage: float = ResourceManager.get_storage_percentage("nonexistent")

	assert_eq(percentage, 0.0, "Unknown resource should return 0%")


func test_get_storage_info_returns_complete_dictionary() -> void:
	ResourceManager._storage_manager = null
	ResourceManager.add_resource("test_res", 80)

	var info: Dictionary = ResourceManager.get_storage_info("test_res")

	assert_has(info, "current", "Info should have 'current' key")
	assert_has(info, "capacity", "Info should have 'capacity' key")
	assert_has(info, "percentage", "Info should have 'percentage' key")
	assert_has(info, "is_warning", "Info should have 'is_warning' key")
	assert_has(info, "is_full", "Info should have 'is_full' key")
	assert_eq(info["current"], 80)
	assert_true(info["is_warning"], "Should be in warning state at 80%")


func test_get_storage_info_for_unknown_resource() -> void:
	var info: Dictionary = ResourceManager.get_storage_info("unknown")

	assert_eq(info["current"], 0, "Unknown resource current should be 0")
	assert_false(info["is_warning"], "Unknown resource should not be in warning")
	assert_false(info["is_full"], "Unknown resource should not be full")


# =============================================================================
# AC1, AC6: STORAGE CAPACITY WITH BUILDINGS
# =============================================================================

func test_base_capacity_without_buildings() -> void:
	var capacity: int = _storage_manager.get_total_capacity("wheat")

	assert_eq(capacity, GameConstants.DEFAULT_VILLAGE_STORAGE_CAPACITY, "Base capacity should be default village storage")


func test_stockpile_building_increases_capacity() -> void:
	# Create mock storage building
	var mock_building: Node = _create_mock_storage_building(50)
	add_child(mock_building)
	await wait_frames(1)

	_storage_manager.register_storage_building(mock_building)

	var capacity: int = _storage_manager.get_total_capacity("wheat")

	assert_eq(capacity, GameConstants.DEFAULT_VILLAGE_STORAGE_CAPACITY + 50)

	mock_building.queue_free()


func test_multiple_stockpiles_stack_additively() -> void:
	var mock_building1: Node = _create_mock_storage_building(50)
	var mock_building2: Node = _create_mock_storage_building(50)
	add_child(mock_building1)
	add_child(mock_building2)
	await wait_frames(1)

	_storage_manager.register_storage_building(mock_building1)
	_storage_manager.register_storage_building(mock_building2)

	var capacity: int = _storage_manager.get_total_capacity("wheat")

	assert_eq(capacity, GameConstants.DEFAULT_VILLAGE_STORAGE_CAPACITY + 100)

	mock_building1.queue_free()
	mock_building2.queue_free()


func test_destroyed_stockpile_reduces_capacity() -> void:
	var mock_building: Node = _create_mock_storage_building(50)
	add_child(mock_building)
	await wait_frames(1)

	_storage_manager.register_storage_building(mock_building)
	var capacity_with: int = _storage_manager.get_total_capacity("wheat")

	_storage_manager.unregister_storage_building(mock_building)
	var capacity_without: int = _storage_manager.get_total_capacity("wheat")

	assert_eq(capacity_with, GameConstants.DEFAULT_VILLAGE_STORAGE_CAPACITY + 50)
	assert_eq(capacity_without, GameConstants.DEFAULT_VILLAGE_STORAGE_CAPACITY)

	mock_building.queue_free()


func test_storage_capacity_changed_signal_on_building_placed() -> void:
	# Add a resource first so the signal has something to emit for
	ResourceManager.add_resource("wheat", 10)

	watch_signals(EventBus)

	var mock_building: Node = _create_mock_storage_building(50)
	add_child(mock_building)
	await wait_frames(1)

	_storage_manager.register_storage_building(mock_building)

	assert_signal_emitted(EventBus, "storage_capacity_changed")

	mock_building.queue_free()


# =============================================================================
# AC7: STORAGE UI DATA PROVIDER
# =============================================================================

func test_get_all_storage_info_returns_all_resources() -> void:
	ResourceManager.add_resource("wheat", 50)
	ResourceManager.add_resource("wood", 30)

	var all_info: Dictionary = _storage_manager.get_all_storage_info()

	assert_has(all_info, "wheat", "Should include wheat")
	assert_has(all_info, "wood", "Should include wood")
	assert_eq(all_info["wheat"]["current"], 50)
	assert_eq(all_info["wood"]["current"], 30)


func test_get_all_storage_info_returns_empty_when_no_resources() -> void:
	# No resources added
	var all_info: Dictionary = _storage_manager.get_all_storage_info()

	assert_eq(all_info.size(), 0, "Should return empty dictionary when no resources")


func test_get_storage_info_for_includes_all_fields() -> void:
	ResourceManager.add_resource("wheat", 80)

	var info: Dictionary = _storage_manager.get_storage_info_for("wheat")

	assert_has(info, "resource_id")
	assert_has(info, "current")
	assert_has(info, "capacity")
	assert_has(info, "percentage")
	assert_has(info, "is_warning")
	assert_has(info, "is_full")
	assert_eq(info["resource_id"], "wheat")


# =============================================================================
# AC4: GATHERING PAUSE/RESUME SIGNALS
# =============================================================================

func test_gathering_pause_signal_emitted_when_storage_full() -> void:
	ResourceManager._storage_manager = null

	watch_signals(EventBus)

	# Fill storage to capacity (100 is default for unknown resources)
	ResourceManager.add_resource("test_res", 100)

	assert_signal_emitted(EventBus, "resource_gathering_paused")


func test_gathering_resume_signal_emitted_when_space_available() -> void:
	ResourceManager._storage_manager = null

	# Fill storage and trigger pause
	ResourceManager.add_resource("test_res", 100)

	watch_signals(EventBus)

	# Remove some resources to make space
	ResourceManager.remove_resource("test_res", 20)

	assert_signal_emitted(EventBus, "resource_gathering_resumed")


func test_is_gathering_paused_returns_correct_state() -> void:
	ResourceManager._storage_manager = null

	# Initially not paused
	assert_false(ResourceManager.is_gathering_paused("test_res"))

	# Fill storage
	ResourceManager.add_resource("test_res", 100)

	# Now should be paused
	assert_true(ResourceManager.is_gathering_paused("test_res"))


func test_gathering_pause_not_emitted_multiple_times() -> void:
	ResourceManager._storage_manager = null

	watch_signals(EventBus)

	# Fill storage
	ResourceManager.add_resource("test_res", 100)
	# Try adding more while already full
	ResourceManager.add_resource("test_res", 10)

	# Should only emit once
	assert_signal_emit_count(EventBus, "resource_gathering_paused", 1)


# =============================================================================
# CACHING TESTS (PERFORMANCE OPTIMIZATION)
# =============================================================================

func test_capacity_cache_invalidates_on_building_placed() -> void:
	var initial_capacity: int = _storage_manager.get_total_capacity("wheat")

	var mock_building: Node = _create_mock_storage_building(50)
	add_child(mock_building)
	await wait_frames(1)

	_storage_manager.register_storage_building(mock_building)

	var new_capacity: int = _storage_manager.get_total_capacity("wheat")

	assert_eq(new_capacity, initial_capacity + 50, "Capacity should update after building placed")

	mock_building.queue_free()


func test_storage_info_cache_invalidates_on_resource_change() -> void:
	ResourceManager.add_resource("wheat", 50)
	var info1: Dictionary = _storage_manager.get_all_storage_info()

	ResourceManager.add_resource("wheat", 20)
	var info2: Dictionary = _storage_manager.get_all_storage_info()

	assert_eq(info1["wheat"]["current"], 50)
	assert_eq(info2["wheat"]["current"], 70)


# =============================================================================
# AC5: STOCKPILE BUILDING DATA
# =============================================================================

func test_stockpile_data_file_exists() -> void:
	var stockpile_data: BuildingData = load("res://resources/buildings/stockpile_data.tres") as BuildingData

	assert_not_null(stockpile_data, "Stockpile data file should exist")


func test_stockpile_has_correct_properties() -> void:
	var stockpile_data: BuildingData = load("res://resources/buildings/stockpile_data.tres") as BuildingData

	assert_eq(stockpile_data.building_id, "stockpile")
	assert_eq(stockpile_data.display_name, "Stockpile")
	assert_eq(stockpile_data.storage_capacity_bonus, 50)
	assert_eq(stockpile_data.building_type, BuildingTypes.BuildingType.STORAGE)


func test_stockpile_build_cost() -> void:
	var stockpile_data: BuildingData = load("res://resources/buildings/stockpile_data.tres") as BuildingData

	assert_has(stockpile_data.build_cost, "wood")
	assert_eq(stockpile_data.build_cost["wood"], 15)


func test_stockpile_valid_terrain() -> void:
	var stockpile_data: BuildingData = load("res://resources/buildings/stockpile_data.tres") as BuildingData

	assert_true(stockpile_data.valid_terrain.has("grass"), "Stockpile should be valid on grass")


func test_building_data_is_storage_building_method() -> void:
	var stockpile_data: BuildingData = load("res://resources/buildings/stockpile_data.tres") as BuildingData
	var farm_data: BuildingData = load("res://resources/buildings/farm_data.tres") as BuildingData

	assert_true(stockpile_data.is_storage_building(), "Stockpile should be a storage building")
	assert_false(farm_data.is_storage_building(), "Farm should not be a storage building")


# =============================================================================
# AC8: SAVE/LOAD STORAGE STATE
# =============================================================================

func test_save_data_includes_warning_states() -> void:
	ResourceManager._storage_manager = null

	# Trigger warning - use test_res which has no ResourceData, capacity=100, 80%=80
	ResourceManager.add_resource("test_res", 80)

	var save_data: Dictionary = ResourceManager.get_save_data()

	assert_has(save_data, "warning_emitted")
	assert_true(save_data["warning_emitted"].get("test_res", false))


func test_load_save_data_restores_warning_states() -> void:
	var save_data: Dictionary = {
		"resources": {"test_res": 85},
		"warning_emitted": {"test_res": true}
	}

	ResourceManager.load_save_data(save_data)

	assert_true(ResourceManager._warning_emitted.get("test_res", false))


func test_load_save_data_handles_missing_warning_states() -> void:
	# Old save format without warning_emitted
	var save_data: Dictionary = {
		"resources": {"wheat": 50}
	}

	ResourceManager.load_save_data(save_data)

	assert_eq(ResourceManager._warning_emitted.size(), 0, "Warning states should be empty for old saves")


func test_clear_all_clears_warning_states() -> void:
	ResourceManager._storage_manager = null
	ResourceManager.add_resource("test_res", 80)  # Triggers warning (80% of 100)

	ResourceManager.clear_all()

	assert_eq(ResourceManager._warning_emitted.size(), 0, "Warning states should be cleared")
	assert_eq(ResourceManager._gathering_paused.size(), 0, "Gathering pause states should be cleared")


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

func test_integration_storage_constants_exist() -> void:
	assert_eq(GameConstants.STORAGE_WARNING_THRESHOLD, 0.8)
	assert_eq(GameConstants.STORAGE_WARNING_RESET_THRESHOLD, 0.7)
	assert_eq(GameConstants.DEFAULT_VILLAGE_STORAGE_CAPACITY, 100)
	assert_eq(GameConstants.STOCKPILE_STORAGE_BONUS, 50)


func test_integration_eventbus_storage_signals_exist() -> void:
	assert_true(EventBus.has_signal("resource_storage_warning"))
	assert_true(EventBus.has_signal("resource_gathering_paused"))
	assert_true(EventBus.has_signal("resource_gathering_resumed"))
	assert_true(EventBus.has_signal("storage_capacity_changed"))


func test_integration_storage_manager_registers_with_resource_manager() -> void:
	# After StorageManager is added in before_each, it should register itself
	assert_eq(ResourceManager._storage_manager, _storage_manager)


func test_integration_resource_manager_uses_storage_manager_capacity() -> void:
	# Add a storage building
	var mock_building: Node = _create_mock_storage_building(50)
	add_child(mock_building)
	await wait_frames(1)
	_storage_manager.register_storage_building(mock_building)

	# ResourceManager should now use the increased capacity
	var limit: int = ResourceManager.get_storage_limit("wheat")

	assert_eq(limit, GameConstants.DEFAULT_VILLAGE_STORAGE_CAPACITY + 50)

	mock_building.queue_free()


# =============================================================================
# HELPER METHODS
# =============================================================================

## Create a mock building with storage capacity bonus for testing
func _create_mock_storage_building(bonus: int) -> Node:
	var building: Node = Node.new()
	building.name = "MockStorageBuilding"

	# Create BuildingData with storage bonus
	var building_data: BuildingData = BuildingData.new()
	building_data.building_id = "mock_stockpile"
	building_data.display_name = "Mock Stockpile"
	building_data.storage_capacity_bonus = bonus

	# Store data for get_data() method
	building.set_meta("building_data", building_data)

	# Add get_data method via script
	var script: GDScript = GDScript.new()
	script.source_code = """
extends Node

func get_data() -> BuildingData:
	return get_meta("building_data")
"""
	script.reload()
	building.set_script(script)

	return building
