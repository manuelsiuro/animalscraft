## Unit tests for UpgradeBonusManager (Story 6-8).
##
## Tests cover:
## - School efficiency bonus (AC2)
## - Hospital rest recovery bonus (AC4)
## - Warehouse storage multiplier (AC6)
## - Stacking behavior (AC2, AC4, AC6)
## - Save/load persistence (AC10)
##
## Architecture: tests/unit/test_upgrade_bonus_manager.gd
## Story: 6-8-create-upgrade-buildings
extends GutTest

# =============================================================================
# CONSTANTS
# =============================================================================

const UpgradeBonusManagerScript := preload("res://autoloads/upgrade_bonus_manager.gd")

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _manager: Node = null


func before_each() -> void:
	# Create a fresh manager instance for each test
	_manager = UpgradeBonusManagerScript.new()
	add_child(_manager)
	await wait_frames(1)


func after_each() -> void:
	if _manager and is_instance_valid(_manager):
		_manager.queue_free()
		_manager = null


# =============================================================================
# MOCK BUILDING CLASS
# =============================================================================

## Mock building class for testing
class MockBuilding extends Node:
	var _building_id: String = ""

	func _init(id: String) -> void:
		_building_id = id

	func get_building_id() -> String:
		return _building_id


# =============================================================================
# MOCK BUILDING HELPER
# =============================================================================

## Create a mock building node with get_building_id method
func _create_mock_building(building_id: String) -> Node:
	var mock := MockBuilding.new(building_id)
	add_child_autoqfree(mock)
	return mock


# =============================================================================
# AC2: School Provides Worker Efficiency Bonus
# =============================================================================

func test_no_efficiency_bonus_without_school() -> void:
	# Without any school, efficiency multiplier should be 1.0
	assert_eq(_manager.get_efficiency_multiplier(), 1.0, "Base efficiency should be 1.0")


func test_school_provides_efficiency_bonus() -> void:
	# Simulate school placement
	var school := _create_mock_building("school")
	EventBus.building_placed.emit(school, Vector2i.ZERO)
	await wait_frames(1)

	# Efficiency should be 1.15 (15% bonus)
	assert_almost_eq(_manager.get_efficiency_multiplier(), 1.15, 0.001, "School should provide 1.15 multiplier")


func test_multiple_schools_do_not_stack() -> void:
	# Place two schools
	var school1 := _create_mock_building("school")
	var school2 := _create_mock_building("school")
	EventBus.building_placed.emit(school1, Vector2i.ZERO)
	EventBus.building_placed.emit(school2, Vector2i(1, 0))
	await wait_frames(1)

	# Efficiency should still be 1.15 (not 1.30)
	assert_almost_eq(_manager.get_efficiency_multiplier(), 1.15, 0.001, "Multiple schools should NOT stack")


func test_school_removal_removes_efficiency_bonus() -> void:
	# Place and then remove school
	var school := _create_mock_building("school")
	EventBus.building_placed.emit(school, Vector2i.ZERO)
	await wait_frames(1)

	EventBus.building_removed.emit(school, Vector2i.ZERO)
	await wait_frames(1)

	assert_eq(_manager.get_efficiency_multiplier(), 1.0, "Efficiency should return to 1.0 after school removed")


# =============================================================================
# AC4: Hospital Provides Rest Recovery Bonus
# =============================================================================

func test_no_rest_bonus_without_hospital() -> void:
	# Without any hospital, rest multiplier should be 1.0
	assert_eq(_manager.get_rest_multiplier(), 1.0, "Base rest multiplier should be 1.0")


func test_hospital_provides_rest_bonus() -> void:
	# Simulate hospital placement
	var hospital := _create_mock_building("hospital")
	EventBus.building_placed.emit(hospital, Vector2i.ZERO)
	await wait_frames(1)

	# Rest multiplier should be 2.0
	assert_eq(_manager.get_rest_multiplier(), 2.0, "Hospital should provide 2x rest multiplier")


func test_multiple_hospitals_do_not_stack() -> void:
	# Place two hospitals
	var hospital1 := _create_mock_building("hospital")
	var hospital2 := _create_mock_building("hospital")
	EventBus.building_placed.emit(hospital1, Vector2i.ZERO)
	EventBus.building_placed.emit(hospital2, Vector2i(1, 0))
	await wait_frames(1)

	# Rest multiplier should still be 2.0 (not 4.0)
	assert_eq(_manager.get_rest_multiplier(), 2.0, "Multiple hospitals should NOT stack")


func test_hospital_removal_removes_rest_bonus() -> void:
	# Place and then remove hospital
	var hospital := _create_mock_building("hospital")
	EventBus.building_placed.emit(hospital, Vector2i.ZERO)
	await wait_frames(1)

	EventBus.building_removed.emit(hospital, Vector2i.ZERO)
	await wait_frames(1)

	assert_eq(_manager.get_rest_multiplier(), 1.0, "Rest multiplier should return to 1.0 after hospital removed")


# =============================================================================
# AC6: Warehouse Provides Storage Capacity Bonus
# =============================================================================

func test_no_storage_bonus_without_warehouse() -> void:
	# Without any warehouse, storage multiplier should be 1.0
	assert_eq(_manager.get_storage_multiplier(), 1.0, "Base storage multiplier should be 1.0")


func test_warehouse_provides_storage_bonus() -> void:
	# Simulate warehouse placement
	var warehouse := _create_mock_building("warehouse")
	EventBus.building_placed.emit(warehouse, Vector2i.ZERO)
	await wait_frames(1)

	# Storage multiplier should be 1.50 (50% bonus)
	assert_almost_eq(_manager.get_storage_multiplier(), 1.5, 0.001, "Warehouse should provide 1.5 multiplier")


func test_multiple_warehouses_stack() -> void:
	# Place three warehouses
	var warehouse1 := _create_mock_building("warehouse")
	var warehouse2 := _create_mock_building("warehouse")
	var warehouse3 := _create_mock_building("warehouse")
	EventBus.building_placed.emit(warehouse1, Vector2i.ZERO)
	EventBus.building_placed.emit(warehouse2, Vector2i(1, 0))
	EventBus.building_placed.emit(warehouse3, Vector2i(2, 0))
	await wait_frames(1)

	# Storage multiplier should be 2.5 (1.0 + 3 * 0.5)
	assert_almost_eq(_manager.get_storage_multiplier(), 2.5, 0.001, "Multiple warehouses SHOULD stack")


func test_warehouse_removal_reduces_storage_bonus() -> void:
	# Place two warehouses then remove one
	var warehouse1 := _create_mock_building("warehouse")
	var warehouse2 := _create_mock_building("warehouse")
	EventBus.building_placed.emit(warehouse1, Vector2i.ZERO)
	EventBus.building_placed.emit(warehouse2, Vector2i(1, 0))
	await wait_frames(1)

	assert_almost_eq(_manager.get_storage_multiplier(), 2.0, 0.001, "Two warehouses should give 2.0 multiplier")

	EventBus.building_removed.emit(warehouse1, Vector2i.ZERO)
	await wait_frames(1)

	assert_almost_eq(_manager.get_storage_multiplier(), 1.5, 0.001, "One warehouse should give 1.5 multiplier")


# =============================================================================
# is_bonus_active Tests
# =============================================================================

func test_is_bonus_active_efficiency() -> void:
	assert_false(_manager.is_bonus_active("efficiency"), "Efficiency should be inactive initially")

	var school := _create_mock_building("school")
	EventBus.building_placed.emit(school, Vector2i.ZERO)
	await wait_frames(1)

	assert_true(_manager.is_bonus_active("efficiency"), "Efficiency should be active with school")


func test_is_bonus_active_rest() -> void:
	assert_false(_manager.is_bonus_active("rest"), "Rest should be inactive initially")

	var hospital := _create_mock_building("hospital")
	EventBus.building_placed.emit(hospital, Vector2i.ZERO)
	await wait_frames(1)

	assert_true(_manager.is_bonus_active("rest"), "Rest should be active with hospital")


func test_is_bonus_active_storage() -> void:
	assert_false(_manager.is_bonus_active("storage"), "Storage should be inactive initially")

	var warehouse := _create_mock_building("warehouse")
	EventBus.building_placed.emit(warehouse, Vector2i.ZERO)
	await wait_frames(1)

	assert_true(_manager.is_bonus_active("storage"), "Storage should be active with warehouse")


func test_is_bonus_active_unknown() -> void:
	assert_false(_manager.is_bonus_active("unknown"), "Unknown bonus type should return false")


# =============================================================================
# get_building_count Tests
# =============================================================================

func test_get_building_count_school() -> void:
	assert_eq(_manager.get_building_count("school"), 0, "Should start with 0 schools")

	var school := _create_mock_building("school")
	EventBus.building_placed.emit(school, Vector2i.ZERO)
	await wait_frames(1)

	assert_eq(_manager.get_building_count("school"), 1, "Should have 1 school after placement")


func test_get_building_count_warehouse_stacks() -> void:
	var warehouse1 := _create_mock_building("warehouse")
	var warehouse2 := _create_mock_building("warehouse")
	EventBus.building_placed.emit(warehouse1, Vector2i.ZERO)
	EventBus.building_placed.emit(warehouse2, Vector2i(1, 0))
	await wait_frames(1)

	assert_eq(_manager.get_building_count("warehouse"), 2, "Should have 2 warehouses")


# =============================================================================
# bonuses_changed Signal Tests
# =============================================================================

func test_bonuses_changed_signal_emits_on_school_placed() -> void:
	watch_signals(_manager)

	var school := _create_mock_building("school")
	EventBus.building_placed.emit(school, Vector2i.ZERO)
	await wait_frames(1)

	assert_signal_emitted(_manager, "bonuses_changed", "Signal should emit on school placement")


func test_bonuses_changed_signal_emits_on_warehouse_removed() -> void:
	var warehouse := _create_mock_building("warehouse")
	EventBus.building_placed.emit(warehouse, Vector2i.ZERO)
	await wait_frames(1)

	watch_signals(_manager)

	EventBus.building_removed.emit(warehouse, Vector2i.ZERO)
	await wait_frames(1)

	assert_signal_emitted(_manager, "bonuses_changed", "Signal should emit on warehouse removal")


func test_non_upgrade_building_does_not_emit_signal() -> void:
	watch_signals(_manager)

	var farm := _create_mock_building("farm")
	EventBus.building_placed.emit(farm, Vector2i.ZERO)
	await wait_frames(1)

	assert_signal_not_emitted(_manager, "bonuses_changed", "Signal should NOT emit for non-upgrade buildings")


# =============================================================================
# AC10: Save/Load Persistence
# =============================================================================

func test_save_data_format() -> void:
	# Place one of each
	var school := _create_mock_building("school")
	var hospital := _create_mock_building("hospital")
	var warehouse := _create_mock_building("warehouse")
	EventBus.building_placed.emit(school, Vector2i.ZERO)
	EventBus.building_placed.emit(hospital, Vector2i(1, 0))
	EventBus.building_placed.emit(warehouse, Vector2i(2, 0))
	await wait_frames(1)

	var save_data: Dictionary = _manager.get_save_data()

	assert_true(save_data.has("school_count"), "Save data should have school_count")
	assert_true(save_data.has("hospital_count"), "Save data should have hospital_count")
	assert_true(save_data.has("warehouse_count"), "Save data should have warehouse_count")
	assert_eq(save_data["school_count"], 1, "School count should be 1")
	assert_eq(save_data["hospital_count"], 1, "Hospital count should be 1")
	assert_eq(save_data["warehouse_count"], 1, "Warehouse count should be 1")


func test_load_save_data_restores_state() -> void:
	var save_data := {
		"school_count": 1,
		"hospital_count": 1,
		"warehouse_count": 2,
	}

	_manager.load_save_data(save_data)

	assert_eq(_manager.get_building_count("school"), 1, "School count should be restored")
	assert_eq(_manager.get_building_count("hospital"), 1, "Hospital count should be restored")
	assert_eq(_manager.get_building_count("warehouse"), 2, "Warehouse count should be restored")

	# Verify bonuses are active
	assert_almost_eq(_manager.get_efficiency_multiplier(), 1.15, 0.001, "Efficiency bonus should be active")
	assert_eq(_manager.get_rest_multiplier(), 2.0, "Rest bonus should be active")
	assert_almost_eq(_manager.get_storage_multiplier(), 2.0, 0.001, "Storage bonus should be active (2 warehouses)")


func test_load_handles_missing_keys() -> void:
	var incomplete_data := {}  # Missing all keys

	_manager.load_save_data(incomplete_data)

	assert_eq(_manager.get_building_count("school"), 0, "Should default to 0 schools")
	assert_eq(_manager.get_building_count("hospital"), 0, "Should default to 0 hospitals")
	assert_eq(_manager.get_building_count("warehouse"), 0, "Should default to 0 warehouses")


func test_load_handles_invalid_values() -> void:
	var invalid_data := {
		"school_count": "invalid",
		"hospital_count": -5,
		"warehouse_count": null,
	}

	_manager.load_save_data(invalid_data)

	# Should handle gracefully - negative values clamped to 0
	assert_eq(_manager.get_building_count("school"), 0, "Invalid school count should be 0")
	assert_eq(_manager.get_building_count("hospital"), 0, "Negative hospital count should be 0")
	assert_eq(_manager.get_building_count("warehouse"), 0, "Null warehouse count should be 0")


# =============================================================================
# reset_to_defaults Tests
# =============================================================================

func test_reset_to_defaults_clears_all() -> void:
	# Place buildings
	var school := _create_mock_building("school")
	var warehouse := _create_mock_building("warehouse")
	EventBus.building_placed.emit(school, Vector2i.ZERO)
	EventBus.building_placed.emit(warehouse, Vector2i(1, 0))
	await wait_frames(1)

	assert_eq(_manager.get_building_count("school"), 1, "Should have school before reset")
	assert_eq(_manager.get_building_count("warehouse"), 1, "Should have warehouse before reset")

	_manager.reset_to_defaults()

	assert_eq(_manager.get_building_count("school"), 0, "Should have 0 schools after reset")
	assert_eq(_manager.get_building_count("warehouse"), 0, "Should have 0 warehouses after reset")
	assert_eq(_manager.get_efficiency_multiplier(), 1.0, "Efficiency should be 1.0 after reset")
	assert_eq(_manager.get_storage_multiplier(), 1.0, "Storage should be 1.0 after reset")


# =============================================================================
# get_bonus_description Tests
# =============================================================================

func test_get_bonus_description_school() -> void:
	var desc: String = _manager.get_bonus_description("school")
	assert_true("15%" in desc, "School description should mention 15%")
	assert_true("efficiency" in desc.to_lower(), "School description should mention efficiency")


func test_get_bonus_description_hospital() -> void:
	var desc: String = _manager.get_bonus_description("hospital")
	assert_true("2x" in desc.to_lower(), "Hospital description should mention 2x")
	assert_true("rest" in desc.to_lower() or "recovery" in desc.to_lower(), "Hospital description should mention rest/recovery")


func test_get_bonus_description_warehouse() -> void:
	var desc: String = _manager.get_bonus_description("warehouse")
	assert_true("50%" in desc, "Warehouse description should mention 50%")
	assert_true("storage" in desc.to_lower(), "Warehouse description should mention storage")


func test_get_bonus_description_unknown() -> void:
	var desc: String = _manager.get_bonus_description("unknown")
	assert_eq(desc, "", "Unknown building should return empty description")


# =============================================================================
# INTEGRATION TESTS - Bonus Application (L2 fix)
# =============================================================================

func test_gatherer_component_uses_efficiency_bonus() -> void:
	# Reset global UpgradeBonusManager to clean state (accumulated from prior tests)
	if is_instance_valid(UpgradeBonusManager):
		UpgradeBonusManager.reset_to_defaults()
	await wait_frames(1)

	# Create and initialize GathererComponent
	var gatherer := GathererComponent.new()
	add_child_autoqfree(gatherer)
	await wait_frames(1)

	# Mock building for initialization
	var mock_building := Node.new()
	add_child_autoqfree(mock_building)

	# Initialize with 10 second base production time
	gatherer.initialize(mock_building, "wheat", 10.0)

	# Verify base effective time without school (global UpgradeBonusManager has no school)
	var base_time := gatherer.get_effective_production_time()
	assert_almost_eq(base_time, 10.0, 0.001, "Base effective time should be 10.0s")

	# Place a school via EventBus (will be picked up by global UpgradeBonusManager)
	var school := _create_mock_building("school")
	EventBus.building_placed.emit(school, Vector2i.ZERO)
	await wait_frames(1)

	# Verify effective time is reduced (10.0 / 1.15 ≈ 8.7s)
	var boosted_time := gatherer.get_effective_production_time()
	var expected_time := 10.0 / 1.15
	assert_almost_eq(boosted_time, expected_time, 0.01, "Effective time should be reduced by 15%% efficiency")
	assert_true(boosted_time < base_time, "Boosted time should be less than base time")

	# Cleanup: reset global state for subsequent tests
	UpgradeBonusManager.reset_to_defaults()


func test_processor_component_uses_efficiency_bonus() -> void:
	# Skip if RecipeManager not available (unit test environment)
	if not is_instance_valid(RecipeManager):
		pending("RecipeManager not available in unit test environment")
		return

	# Reset global UpgradeBonusManager to clean state
	if is_instance_valid(UpgradeBonusManager):
		UpgradeBonusManager.reset_to_defaults()
	await wait_frames(1)

	# Create and initialize ProcessorComponent
	var processor := ProcessorComponent.new()
	add_child_autoqfree(processor)
	await wait_frames(1)

	# Mock building for initialization
	var mock_building := Node.new()
	add_child_autoqfree(mock_building)

	# Initialize with wheat_to_flour recipe (if available)
	processor.initialize(mock_building, "wheat_to_flour")

	# Only proceed if initialization succeeded
	if not processor.is_initialized():
		pending("Recipe wheat_to_flour not available")
		return

	var base_time := processor.get_production_time()
	if base_time <= 0:
		pending("Recipe has no production time")
		return

	# Verify base effective time without school (global UpgradeBonusManager reset)
	var effective_base := processor.get_effective_production_time()
	assert_almost_eq(effective_base, base_time, 0.001, "Base effective time should match recipe time")

	# Place a school via EventBus
	var school := _create_mock_building("school")
	EventBus.building_placed.emit(school, Vector2i.ZERO)
	await wait_frames(1)

	# Verify effective time is reduced
	var boosted_time := processor.get_effective_production_time()
	var expected_time := base_time / 1.15
	assert_almost_eq(boosted_time, expected_time, 0.01, "Effective time should be reduced by 15%% efficiency")

	# Cleanup: reset global state for subsequent tests
	UpgradeBonusManager.reset_to_defaults()


func test_reset_to_defaults_emits_signal() -> void:
	# Place buildings first
	var school := _create_mock_building("school")
	var warehouse := _create_mock_building("warehouse")
	EventBus.building_placed.emit(school, Vector2i.ZERO)
	EventBus.building_placed.emit(warehouse, Vector2i(1, 0))
	await wait_frames(1)

	# Verify bonuses are active
	assert_true(_manager.is_bonus_active("efficiency"), "Efficiency should be active")
	assert_true(_manager.is_bonus_active("storage"), "Storage should be active")

	# Watch for signal
	watch_signals(_manager)

	# Reset to defaults
	_manager.reset_to_defaults()

	# Verify signal was emitted (M2 fix)
	assert_signal_emitted(_manager, "bonuses_changed", "Signal should emit on reset")

	# Verify bonuses are cleared
	assert_false(_manager.is_bonus_active("efficiency"), "Efficiency should be inactive after reset")
	assert_false(_manager.is_bonus_active("storage"), "Storage should be inactive after reset")


func test_reset_to_defaults_no_signal_when_empty() -> void:
	# Don't place any buildings - start fresh

	# Watch for signal
	watch_signals(_manager)

	# Reset to defaults (should NOT emit signal since nothing changed)
	_manager.reset_to_defaults()

	# Verify NO signal was emitted (no bonuses to clear)
	assert_signal_not_emitted(_manager, "bonuses_changed", "Signal should NOT emit when no bonuses to clear")
