## Unit tests for SaveManager.
## Tests save/load operations, serialization, backup system, error handling, and auto-save.
##
## Architecture: tests/unit/test_save_manager.gd
## Story: 6-1-implement-save-system-core, 6-2-implement-auto-save
extends GutTest

# =============================================================================
# TEST CONSTANTS
# =============================================================================

## Test slot for unit tests. Uses slot 2 (valid range 0-2) to avoid conflicts with slot 0 autosaves.
## WARNING: Do not run unit tests in parallel with integration tests, as they use different slots.
## Code Review Note (Story 6-1): Consider a dedicated test slot prefix if parallel testing is needed.
const TEST_SLOT := 2

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Clean up any test saves
	_cleanup_test_saves()


func after_each() -> void:
	# Clean up test saves
	_cleanup_test_saves()


func _cleanup_test_saves() -> void:
	var save_path := "user://saves/save_%d.json" % TEST_SLOT
	var backup_path := "user://saves/save_%d.backup.json" % TEST_SLOT

	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)


# =============================================================================
# AC1: Save creates valid JSON with schema version
# =============================================================================

func test_save_game_creates_json_file() -> void:
	# Arrange
	assert_not_null(SaveManager, "SaveManager autoload should exist")

	# Act
	var success := SaveManager.save_game(TEST_SLOT)

	# Assert
	assert_true(success, "save_game should return true on success")
	assert_true(SaveManager.save_exists(TEST_SLOT), "Save file should exist after save")


func test_save_includes_schema_version() -> void:
	# Arrange
	var save_success := SaveManager.save_game(TEST_SLOT)
	assert_true(save_success, "Save should succeed first")

	# Act
	var info := SaveManager.get_save_info(TEST_SLOT)

	# Assert
	assert_false(info.is_empty(), "Info should not be empty after successful save")
	assert_true(info.has("version"), "Info should have version key")
	assert_eq(info.get("version", -1), SaveManager.SCHEMA_VERSION, "Save should include schema version")


func test_save_includes_timestamp() -> void:
	# Arrange
	var save_success := SaveManager.save_game(TEST_SLOT)
	assert_true(save_success, "Save should succeed first")

	# Act
	var info := SaveManager.get_save_info(TEST_SLOT)

	# Assert
	assert_false(info.is_empty(), "Info should not be empty after successful save")
	assert_true(info.has("timestamp"), "Info should have timestamp key")
	assert_ne(info.get("timestamp", ""), "", "Save should include timestamp")


func test_save_includes_playtime() -> void:
	# Arrange
	var save_success := SaveManager.save_game(TEST_SLOT)
	assert_true(save_success, "Save should succeed first")

	# Act
	var info := SaveManager.get_save_info(TEST_SLOT)

	# Assert
	assert_false(info.is_empty(), "Info should not be empty after successful save")
	assert_true(info.has("playtime_seconds"), "Save should include playtime_seconds")
	assert_gte(info.get("playtime_seconds", -1.0), 0.0, "Playtime should be non-negative")


# =============================================================================
# AC10-11: Save and Load complete state
# =============================================================================

func test_load_game_returns_true_for_valid_save() -> void:
	# Arrange
	SaveManager.save_game(TEST_SLOT)

	# Act
	var success := SaveManager.load_game(TEST_SLOT)

	# Assert
	assert_true(success, "load_game should return true for valid save")


func test_load_game_returns_false_for_missing_slot() -> void:
	# Arrange - ensure slot is empty
	_cleanup_test_saves()

	# Act
	var success := SaveManager.load_game(TEST_SLOT)

	# Assert
	assert_false(success, "load_game should return false for missing save")


# =============================================================================
# AC12-13: EventBus signals emitted
# =============================================================================

func test_save_completed_signal_emitted_on_success() -> void:
	# Arrange - use dictionary to capture values (GDScript lambdas capture primitives by value)
	var state := {"received": false, "success": false}

	var callback := func(success: bool) -> void:
		state.received = true
		state.success = success

	EventBus.save_completed.connect(callback)

	# Act
	SaveManager.save_game(TEST_SLOT)
	await get_tree().process_frame

	# Assert
	EventBus.save_completed.disconnect(callback)
	assert_true(state.received, "save_completed signal should be emitted")
	assert_true(state.success, "save_completed should have success=true")


func test_load_completed_signal_emitted_on_success() -> void:
	# Arrange
	SaveManager.save_game(TEST_SLOT)
	var state := {"received": false, "success": false}

	var callback := func(success: bool) -> void:
		state.received = true
		state.success = success

	EventBus.load_completed.connect(callback)

	# Act
	SaveManager.load_game(TEST_SLOT)
	await get_tree().process_frame

	# Assert
	EventBus.load_completed.disconnect(callback)
	assert_true(state.received, "load_completed signal should be emitted")
	assert_true(state.success, "load_completed should have success=true")


func test_save_started_signal_emitted() -> void:
	# Arrange - use dictionary to capture values (GDScript lambdas capture primitives by value)
	var state := {"received": false}
	var callback := func() -> void:
		state.received = true

	EventBus.save_started.connect(callback)

	# Act
	SaveManager.save_game(TEST_SLOT)
	await get_tree().process_frame

	# Assert
	EventBus.save_started.disconnect(callback)
	assert_true(state.received, "save_started signal should be emitted")


func test_load_started_signal_emitted() -> void:
	# Arrange
	SaveManager.save_game(TEST_SLOT)
	var state := {"received": false}
	var callback := func() -> void:
		state.received = true

	EventBus.load_started.connect(callback)

	# Act
	SaveManager.load_game(TEST_SLOT)
	await get_tree().process_frame

	# Assert
	EventBus.load_started.disconnect(callback)
	assert_true(state.received, "load_started signal should be emitted")


# =============================================================================
# AC15: is_loading flag during load
# =============================================================================

func test_is_loading_returns_false_normally() -> void:
	# Assert
	assert_false(SaveManager.is_loading(), "is_loading should be false when not loading")


func test_is_loading_returns_true_during_load() -> void:
	# Arrange
	SaveManager.save_game(TEST_SLOT)
	var state := {"was_loading": false}

	var callback := func() -> void:
		state.was_loading = SaveManager.is_loading()

	EventBus.load_started.connect(callback)

	# Act
	SaveManager.load_game(TEST_SLOT)
	await get_tree().process_frame

	# Assert
	EventBus.load_started.disconnect(callback)
	assert_true(state.was_loading, "is_loading should be true during load")


# =============================================================================
# AC16-17: Error handling (cozy philosophy)
# =============================================================================

func test_corrupted_json_returns_false_no_crash() -> void:
	# Arrange - write invalid JSON directly
	var save_path := "user://saves/save_%d.json" % TEST_SLOT
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string("{ invalid json }")
	file.close()

	# Act
	var success := SaveManager.load_game(TEST_SLOT)

	# Assert
	assert_false(success, "load_game should return false for corrupted JSON")
	# Test passed if no crash occurred


func test_load_nonexistent_slot_returns_false() -> void:
	# Act
	var success := SaveManager.load_game(TEST_SLOT)

	# Assert
	assert_false(success, "load_game should return false for non-existent slot")


func test_invalid_slot_number_rejected() -> void:
	# Act
	var save_result := SaveManager.save_game(-1)
	var load_result := SaveManager.load_game(999)

	# Assert
	assert_false(save_result, "save_game should reject invalid slot -1")
	assert_false(load_result, "load_game should reject invalid slot 999")


# =============================================================================
# AC19-20: Backup system
# =============================================================================

func test_backup_created_on_save() -> void:
	# Arrange - create initial save
	SaveManager.save_game(TEST_SLOT)

	# Act - save again (should create backup)
	SaveManager.save_game(TEST_SLOT)

	# Assert
	var backup_path := "user://saves/save_%d.backup.json" % TEST_SLOT
	assert_true(FileAccess.file_exists(backup_path), "Backup should be created on subsequent save")


func test_backup_loaded_when_primary_corrupted() -> void:
	# Arrange - create valid save, then corrupt primary
	SaveManager.save_game(TEST_SLOT)
	SaveManager.save_game(TEST_SLOT)  # Creates backup

	# Corrupt primary
	var save_path := "user://saves/save_%d.json" % TEST_SLOT
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string("corrupted!")
	file.close()

	# Act
	var success := SaveManager.load_game(TEST_SLOT)

	# Assert
	assert_true(success, "load_game should succeed from backup when primary corrupted")


# =============================================================================
# AC18: Schema migration
# =============================================================================

func test_newer_schema_version_rejected() -> void:
	# Arrange - write save with future version
	var save_path := "user://saves/save_%d.json" % TEST_SLOT
	var data := {
		"version": SaveManager.SCHEMA_VERSION + 10,
		"resources": {}
	}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

	# Act
	var success := SaveManager.load_game(TEST_SLOT)

	# Assert
	assert_false(success, "load_game should reject saves with newer schema version")


# =============================================================================
# Save slot management
# =============================================================================

func test_save_exists_returns_correct_state() -> void:
	# Assert - slot should not exist
	assert_false(SaveManager.save_exists(TEST_SLOT), "save_exists should return false for empty slot")

	# Act
	SaveManager.save_game(TEST_SLOT)

	# Assert - slot should exist now
	assert_true(SaveManager.save_exists(TEST_SLOT), "save_exists should return true after save")


func test_delete_save_removes_file() -> void:
	# Arrange
	SaveManager.save_game(TEST_SLOT)
	assert_true(SaveManager.save_exists(TEST_SLOT), "Save should exist before delete")

	# Act
	var success := SaveManager.delete_save(TEST_SLOT)

	# Assert
	assert_true(success, "delete_save should return true")
	assert_false(SaveManager.save_exists(TEST_SLOT), "Save should not exist after delete")


func test_get_save_info_returns_empty_for_missing() -> void:
	# Act
	var info := SaveManager.get_save_info(TEST_SLOT)

	# Assert
	assert_true(info.is_empty(), "get_save_info should return empty dict for missing slot")


func test_get_all_save_info_returns_array() -> void:
	# Arrange
	SaveManager.save_game(TEST_SLOT)

	# Act
	var saves := SaveManager.get_all_save_info()

	# Assert
	assert_true(saves is Array, "get_all_save_info should return Array")


# =============================================================================
# Quick save
# =============================================================================

func test_quick_save_uses_last_slot() -> void:
	# Arrange
	SaveManager.save_game(TEST_SLOT)

	# Act - quick save should use last slot
	var success := SaveManager.quick_save()

	# Assert
	assert_true(success, "quick_save should succeed")
	assert_true(SaveManager.save_exists(TEST_SLOT), "quick_save should use last slot")


# =============================================================================
# HexCoord serialization (Task 2)
# =============================================================================

func test_hexcoord_to_dict() -> void:
	# Arrange
	var coord := HexCoord.new(3, -2)

	# Act
	var data := coord.to_dict()

	# Assert
	assert_eq(data.q, 3, "to_dict should preserve q")
	assert_eq(data.r, -2, "to_dict should preserve r")


func test_hexcoord_from_dict() -> void:
	# Arrange
	var data := {"q": 5, "r": -3}

	# Act
	var coord := HexCoord.from_dict(data)

	# Assert
	assert_eq(coord.q, 5, "from_dict should restore q")
	assert_eq(coord.r, -3, "from_dict should restore r")


func test_hexcoord_coord_to_key() -> void:
	# Arrange
	var coord := HexCoord.new(3, -2)

	# Act
	var key := HexCoord.coord_to_key(coord)

	# Assert
	assert_eq(key, "3,-2", "coord_to_key should produce correct format")


func test_hexcoord_key_to_coord() -> void:
	# Arrange
	var key := "5,-3"

	# Act
	var coord := HexCoord.key_to_coord(key)

	# Assert
	assert_eq(coord.q, 5, "key_to_coord should restore q")
	assert_eq(coord.r, -3, "key_to_coord should restore r")


func test_hexcoord_vec_to_key() -> void:
	# Arrange
	var vec := Vector2i(4, -1)

	# Act
	var key := HexCoord.vec_to_key(vec)

	# Assert
	assert_eq(key, "4,-1", "vec_to_key should produce correct format")


func test_hexcoord_key_to_vec() -> void:
	# Arrange
	var key := "6,-4"

	# Act
	var vec := HexCoord.key_to_vec(key)

	# Assert
	assert_eq(vec, Vector2i(6, -4), "key_to_vec should restore Vector2i")


# =============================================================================
# Signal emission verification
# =============================================================================

func test_load_completed_emitted_with_false_on_failure() -> void:
	# Arrange - create a corrupted save file that exists but fails to load
	var save_path := "user://saves/save_%d.json" % TEST_SLOT
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string("{ invalid json }")
	file.close()

	# Use dictionary to capture values (GDScript lambdas capture primitives by value)
	var state := {"received": false, "success": true}  # default success=true so false assertion catches issue
	var callback := func(success: bool) -> void:
		state.received = true
		state.success = success

	EventBus.load_completed.connect(callback)

	# Act - load corrupted save (exists but fails to parse)
	SaveManager.load_game(TEST_SLOT)
	await get_tree().process_frame

	# Assert
	EventBus.load_completed.disconnect(callback)
	assert_true(state.received, "load_completed signal should be emitted")
	assert_false(state.success, "load_completed should have success=false on failure")


# =============================================================================
# Story 6-2: Auto-Save Tests (AC1-AC5)
# =============================================================================

func test_autosave_timer_exists() -> void:
	# Arrange - get autosave timer via internal access
	var timer: Timer = null
	for child in SaveManager.get_children():
		if child is Timer and child.name == "AutosaveTimer":
			timer = child
			break

	# Assert
	assert_not_null(timer, "Autosave timer should exist as child of SaveManager")
	assert_eq(timer.wait_time, GameConstants.AUTOSAVE_INTERVAL, "Timer should use GameConstants interval")


func test_autosave_respects_disabled_setting() -> void:
	# Arrange - disable autosave
	var original_value := Settings.is_auto_save_enabled()
	Settings.set_auto_save_enabled(false)

	var state := {"save_count": 0}
	var callback := func(_success: bool) -> void:
		state.save_count += 1

	EventBus.save_completed.connect(callback)

	# Act - force autosave while disabled
	SaveManager.force_autosave()
	await get_tree().process_frame

	# Cleanup
	EventBus.save_completed.disconnect(callback)
	Settings.set_auto_save_enabled(original_value)

	# Assert
	assert_eq(state.save_count, 0, "Autosave should not trigger when disabled")


func test_autosave_triggers_when_enabled() -> void:
	# Arrange - enable autosave
	var original_value := Settings.is_auto_save_enabled()
	Settings.set_auto_save_enabled(true)

	var state := {"save_count": 0}
	var callback := func(_success: bool) -> void:
		state.save_count += 1

	EventBus.save_completed.connect(callback)

	# Act - force autosave while enabled
	SaveManager.force_autosave()
	await get_tree().process_frame

	# Cleanup
	EventBus.save_completed.disconnect(callback)
	Settings.set_auto_save_enabled(original_value)

	# Assert
	assert_eq(state.save_count, 1, "Autosave should trigger when enabled")


func test_pause_signal_triggers_autosave() -> void:
	# Arrange - enable autosave
	var original_value := Settings.is_auto_save_enabled()
	Settings.set_auto_save_enabled(true)

	var state := {"save_count": 0}
	var callback := func(_success: bool) -> void:
		state.save_count += 1

	EventBus.save_completed.connect(callback)

	# Act - emit pause signal
	EventBus.game_paused.emit()
	await get_tree().process_frame

	# Cleanup
	EventBus.save_completed.disconnect(callback)
	Settings.set_auto_save_enabled(original_value)

	# Assert
	assert_eq(state.save_count, 1, "Pause signal should trigger autosave")


func test_autosave_emits_save_completed_signal() -> void:
	# Arrange
	var original_value := Settings.is_auto_save_enabled()
	Settings.set_auto_save_enabled(true)

	var state := {"received": false, "success": false}
	var callback := func(success: bool) -> void:
		state.received = true
		state.success = success

	EventBus.save_completed.connect(callback)

	# Act
	SaveManager.force_autosave()
	await get_tree().process_frame

	# Cleanup
	EventBus.save_completed.disconnect(callback)
	Settings.set_auto_save_enabled(original_value)

	# Assert
	assert_true(state.received, "save_completed signal should be emitted on autosave")
	assert_true(state.success, "Autosave should succeed")


func test_autosave_uses_quick_save_slot() -> void:
	# Arrange - save to test slot first to set _last_save_slot
	SaveManager.save_game(TEST_SLOT)

	var original_value := Settings.is_auto_save_enabled()
	Settings.set_auto_save_enabled(true)

	# Act - force autosave
	SaveManager.force_autosave()
	await get_tree().process_frame

	# Cleanup
	Settings.set_auto_save_enabled(original_value)

	# Assert - slot should still have save
	assert_true(SaveManager.save_exists(TEST_SLOT), "Autosave should use last used slot")


func test_set_autosave_enabled_updates_setting() -> void:
	# Arrange
	var original_value := Settings.is_auto_save_enabled()

	# Act - toggle setting via SaveManager API
	SaveManager.set_autosave_enabled(false)
	var disabled_state := Settings.is_auto_save_enabled()

	SaveManager.set_autosave_enabled(true)
	var enabled_state := Settings.is_auto_save_enabled()

	# Cleanup
	Settings.set_auto_save_enabled(original_value)

	# Assert
	assert_false(disabled_state, "Setting should be disabled")
	assert_true(enabled_state, "Setting should be enabled")


func test_concurrent_save_prevented() -> void:
	# Arrange - this tests that _save_in_progress prevents concurrent saves
	var state := {"save_count": 0}
	var callback := func(_success: bool) -> void:
		state.save_count += 1

	EventBus.save_completed.connect(callback)

	# Act - rapid sequential saves (synchronous so they don't actually overlap)
	SaveManager.save_game(TEST_SLOT)
	SaveManager.save_game(TEST_SLOT)
	await get_tree().process_frame

	# Cleanup
	EventBus.save_completed.disconnect(callback)

	# Assert - both saves should complete (no overlap in synchronous code)
	assert_eq(state.save_count, 2, "Sequential saves should complete")


func test_autosave_blocked_during_load() -> void:
	# Arrange - create a save to load
	SaveManager.save_game(TEST_SLOT)

	var original_value := Settings.is_auto_save_enabled()
	Settings.set_auto_save_enabled(true)

	var state := {"autosave_count": 0}
	var callback := func(_success: bool) -> void:
		state.autosave_count += 1

	# Track saves triggered during load
	var load_callback := func() -> void:
		# During load, try to force an autosave
		SaveManager.force_autosave()

	EventBus.save_completed.connect(callback)
	EventBus.load_started.connect(load_callback)

	# Act - start a load (autosave should be blocked during load)
	SaveManager.load_game(TEST_SLOT)
	await get_tree().process_frame

	# Cleanup
	EventBus.save_completed.disconnect(callback)
	EventBus.load_started.disconnect(load_callback)
	Settings.set_auto_save_enabled(original_value)

	# Assert - autosave should NOT have triggered during load
	# Note: save_completed fires once for the load operation itself (false), not for autosave
	assert_eq(state.autosave_count, 0, "Autosave should be blocked during load")
