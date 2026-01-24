## Unit tests for BuildingUnlockManager (Story 6-7).
##
## Tests cover:
## - Starter buildings unlocked by default (AC1)
## - Building unlock signal handling (AC6)
## - Save/load persistence (AC5)
## - Public API correctness
## - Integration with MilestoneManager unlock_rewards
##
## Architecture: tests/unit/test_building_unlock_manager.gd
## Story: 6-7-implement-building-unlocks
extends GutTest

# =============================================================================
# CONSTANTS
# =============================================================================

const BuildingUnlockManagerScript := preload("res://autoloads/building_unlock_manager.gd")

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _manager: Node = null


func before_each() -> void:
	# Create a fresh manager instance for each test
	_manager = BuildingUnlockManagerScript.new()
	add_child(_manager)
	await wait_frames(1)


func after_each() -> void:
	if _manager and is_instance_valid(_manager):
		_manager.queue_free()
		_manager = null


# =============================================================================
# AC1: Starter Buildings Unlocked by Default
# =============================================================================

func test_starter_buildings_unlocked_by_default() -> void:
	# All starter buildings should be unlocked on initialization
	assert_true(_manager.is_building_unlocked("shelter"), "Shelter should be unlocked by default")
	assert_true(_manager.is_building_unlocked("farm"), "Farm should be unlocked by default")
	assert_true(_manager.is_building_unlocked("sawmill"), "Sawmill should be unlocked by default")


func test_non_starter_buildings_locked_by_default() -> void:
	# Mill and Bakery should NOT be unlocked by default
	assert_false(_manager.is_building_unlocked("mill"), "Mill should be locked by default")
	assert_false(_manager.is_building_unlocked("bakery"), "Bakery should be locked by default")


func test_starter_buildings_constant_contents() -> void:
	# Verify STARTER_BUILDINGS constant contains expected values
	var starter: Array[String] = _manager.STARTER_BUILDINGS
	assert_eq(starter.size(), 3, "Should have 3 starter buildings")
	assert_true("shelter" in starter, "Shelter should be in starter buildings")
	assert_true("farm" in starter, "Farm should be in starter buildings")
	assert_true("sawmill" in starter, "Sawmill should be in starter buildings")


# =============================================================================
# AC1: Public API - is_building_unlocked
# =============================================================================

func test_is_building_unlocked_returns_correct_state() -> void:
	# Starter building = true
	assert_true(_manager.is_building_unlocked("farm"), "Farm should return true")
	# Non-starter = false
	assert_false(_manager.is_building_unlocked("mill"), "Mill should return false")
	# Empty string = false
	assert_false(_manager.is_building_unlocked(""), "Empty string should return false")
	# Unknown building = false
	assert_false(_manager.is_building_unlocked("nonexistent"), "Unknown building should return false")


# =============================================================================
# AC1: Public API - get_unlocked_buildings
# =============================================================================

func test_get_unlocked_buildings_returns_array() -> void:
	var unlocked: Array[String] = _manager.get_unlocked_buildings()
	assert_true(unlocked is Array, "Should return an Array")
	assert_eq(unlocked.size(), 3, "Should have 3 starter buildings initially")
	assert_true("shelter" in unlocked, "Array should contain shelter")
	assert_true("farm" in unlocked, "Array should contain farm")
	assert_true("sawmill" in unlocked, "Array should contain sawmill")


func test_get_unlocked_count_returns_correct_count() -> void:
	assert_eq(_manager.get_unlocked_count(), 3, "Should have 3 unlocked buildings initially")


# =============================================================================
# AC6: Building Unlock Signal Handling
# =============================================================================

func test_building_unlocked_signal_adds_to_unlocked_set() -> void:
	# Mill should be locked initially
	assert_false(_manager.is_building_unlocked("mill"), "Mill should be locked initially")

	# Emit building_unlocked signal
	EventBus.building_unlocked.emit("mill")
	await wait_frames(1)

	# Mill should now be unlocked
	assert_true(_manager.is_building_unlocked("mill"), "Mill should be unlocked after signal")


func test_unlock_state_changed_signal_emits() -> void:
	watch_signals(_manager)

	# Emit building_unlocked signal
	EventBus.building_unlocked.emit("mill")
	await wait_frames(1)

	# unlock_state_changed should have been emitted
	assert_signal_emitted(_manager, "unlock_state_changed", "unlock_state_changed should emit on unlock")


func test_unlock_state_changed_signal_includes_building_type() -> void:
	watch_signals(_manager)

	EventBus.building_unlocked.emit("bakery")
	await wait_frames(1)

	# Verify signal was emitted with correct parameter
	assert_signal_emitted_with_parameters(_manager, "unlock_state_changed", ["bakery"])


func test_duplicate_unlock_does_not_emit_signal() -> void:
	watch_signals(_manager)

	# Unlock mill
	EventBus.building_unlocked.emit("mill")
	await wait_frames(1)

	# Try to unlock mill again
	EventBus.building_unlocked.emit("mill")
	await wait_frames(1)

	# Signal should only have been emitted once
	assert_signal_emit_count(_manager, "unlock_state_changed", 1,
		"Signal should only emit once for duplicate unlock")


func test_empty_building_type_ignored() -> void:
	watch_signals(_manager)

	EventBus.building_unlocked.emit("")
	await wait_frames(1)

	# Signal should not emit for empty string
	assert_signal_not_emitted(_manager, "unlock_state_changed",
		"Signal should not emit for empty building type")


# =============================================================================
# AC5: Save/Load Persistence
# =============================================================================

func test_save_load_preserves_unlock_state() -> void:
	# Unlock some buildings
	EventBus.building_unlocked.emit("mill")
	EventBus.building_unlocked.emit("bakery")
	await wait_frames(1)

	# Get save data
	var save_data: Dictionary = _manager.get_save_data()

	# Create a new manager and load the data
	var new_manager := BuildingUnlockManagerScript.new()
	add_child(new_manager)
	await wait_frames(1)

	new_manager.load_save_data(save_data)

	# Verify unlocks were preserved
	assert_true(new_manager.is_building_unlocked("mill"), "Mill should be unlocked after load")
	assert_true(new_manager.is_building_unlocked("bakery"), "Bakery should be unlocked after load")

	# Cleanup
	new_manager.queue_free()


func test_save_data_format() -> void:
	# Unlock a building
	EventBus.building_unlocked.emit("mill")
	await wait_frames(1)

	var save_data: Dictionary = _manager.get_save_data()

	# Verify format
	assert_true(save_data.has("unlocked"), "Save data should have 'unlocked' key")
	assert_true(save_data["unlocked"] is Array, "Unlocked should be an array")
	assert_true("mill" in save_data["unlocked"], "Mill should be in saved unlocks")


func test_starter_buildings_always_included_after_load() -> void:
	# Create save data without starter buildings (corrupted/old save)
	var corrupted_data := {
		"unlocked": ["mill", "bakery"]  # Missing starter buildings
	}

	_manager.load_save_data(corrupted_data)

	# Starter buildings should still be unlocked
	assert_true(_manager.is_building_unlocked("shelter"), "Shelter should be unlocked after load")
	assert_true(_manager.is_building_unlocked("farm"), "Farm should be unlocked after load")
	assert_true(_manager.is_building_unlocked("sawmill"), "Sawmill should be unlocked after load")
	# Additional unlocks should also be present
	assert_true(_manager.is_building_unlocked("mill"), "Mill should be unlocked from save")
	assert_true(_manager.is_building_unlocked("bakery"), "Bakery should be unlocked from save")


func test_load_handles_missing_unlocked_key() -> void:
	var incomplete_data := {}  # Missing 'unlocked' key

	_manager.load_save_data(incomplete_data)

	# Starter buildings should still be unlocked
	assert_eq(_manager.get_unlocked_count(), 3, "Should have starter buildings after loading incomplete data")


func test_load_handles_non_array_unlocked() -> void:
	var invalid_data := {
		"unlocked": "not_an_array"  # Wrong type
	}

	_manager.load_save_data(invalid_data)

	# Starter buildings should still be unlocked
	assert_eq(_manager.get_unlocked_count(), 3, "Should have starter buildings after loading invalid data")


func test_load_filters_invalid_entries() -> void:
	var data_with_invalid := {
		"unlocked": ["mill", "", 123, null, "bakery"]  # Mixed valid/invalid
	}

	_manager.load_save_data(data_with_invalid)

	# Should have starter buildings + valid unlocks
	assert_true(_manager.is_building_unlocked("mill"), "Mill should be unlocked")
	assert_true(_manager.is_building_unlocked("bakery"), "Bakery should be unlocked")
	# Count should be 5: shelter, farm, sawmill, mill, bakery
	assert_eq(_manager.get_unlocked_count(), 5, "Should have 5 unlocked buildings")


# =============================================================================
# AC1: is_starter_building Helper
# =============================================================================

func test_is_starter_building_returns_correct_value() -> void:
	assert_true(_manager.is_starter_building("shelter"), "Shelter is a starter building")
	assert_true(_manager.is_starter_building("farm"), "Farm is a starter building")
	assert_true(_manager.is_starter_building("sawmill"), "Sawmill is a starter building")
	assert_false(_manager.is_starter_building("mill"), "Mill is not a starter building")
	assert_false(_manager.is_starter_building("bakery"), "Bakery is not a starter building")


# =============================================================================
# Reset to Defaults
# =============================================================================

func test_reset_to_defaults_clears_unlocks() -> void:
	# Unlock some buildings
	EventBus.building_unlocked.emit("mill")
	EventBus.building_unlocked.emit("bakery")
	await wait_frames(1)

	assert_eq(_manager.get_unlocked_count(), 5, "Should have 5 unlocked before reset")

	# Reset
	_manager.reset_to_defaults()

	# Should only have starter buildings
	assert_eq(_manager.get_unlocked_count(), 3, "Should have 3 unlocked after reset")
	assert_false(_manager.is_building_unlocked("mill"), "Mill should be locked after reset")
	assert_false(_manager.is_building_unlocked("bakery"), "Bakery should be locked after reset")


# =============================================================================
# AC2: Integration with MilestoneManager unlock_rewards
# =============================================================================

func test_milestone_unlock_rewards_trigger_unlock() -> void:
	# This test verifies the integration path:
	# MilestoneManager.milestone_reached -> EventBus.building_unlocked -> BuildingUnlockManager

	# Mill should be locked initially
	assert_false(_manager.is_building_unlocked("mill"), "Mill should be locked initially")

	# Simulate what MilestoneManager does when a milestone with unlock_rewards triggers
	# (MilestoneManager emits EventBus.building_unlocked for each reward)
	EventBus.building_unlocked.emit("mill")
	await wait_frames(1)

	# Mill should now be unlocked
	assert_true(_manager.is_building_unlocked("mill"), "Mill should be unlocked after milestone")


# =============================================================================
# Signal Not Emitted During Load (Loading Flag)
# =============================================================================

func test_signal_not_emitted_during_load() -> void:
	# Unlock mill first
	EventBus.building_unlocked.emit("mill")
	await wait_frames(1)

	# Save data
	var save_data: Dictionary = _manager.get_save_data()

	# Create new manager and watch signals
	var new_manager := BuildingUnlockManagerScript.new()
	add_child(new_manager)
	await wait_frames(1)
	watch_signals(new_manager)

	# Load should not emit unlock_state_changed
	new_manager.load_save_data(save_data)

	# Signal should not have been emitted (loading flag prevents it)
	assert_signal_not_emitted(new_manager, "unlock_state_changed",
		"Signal should not emit during load")

	new_manager.queue_free()
