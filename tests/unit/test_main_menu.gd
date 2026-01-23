## Unit tests for Main Menu functionality.
## Tests Continue button visibility, load flow, and error handling.
##
## Architecture: tests/unit/test_main_menu.gd
## Story: 6-3-implement-load-game-ui
extends GutTest

# =============================================================================
# TEST CONSTANTS
# =============================================================================

## Test slot for menu tests (slot 2 to avoid conflicts with autosave)
const TEST_SLOT := 2

## Scene paths
const MAIN_MENU_SCENE := "res://scenes/ui/menus/main_menu.tscn"
const LOADING_OVERLAY_SCENE := "res://scenes/ui/menus/loading_overlay.tscn"

# =============================================================================
# REFERENCES
# =============================================================================

var _main_menu_script: GDScript
var _loading_overlay_script: GDScript
var _main_menu_scene: PackedScene
var _loading_overlay_scene: PackedScene

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_all() -> void:
	# Preload scripts for testing
	_main_menu_script = load("res://scripts/ui/menus/main_menu.gd")
	_loading_overlay_script = load("res://scripts/ui/menus/loading_overlay.gd")
	# Preload scenes for UI testing
	_main_menu_scene = load(MAIN_MENU_SCENE)
	_loading_overlay_scene = load(LOADING_OVERLAY_SCENE)


func before_each() -> void:
	# Clean up any test saves
	_cleanup_test_saves()


func after_each() -> void:
	_cleanup_test_saves()


func _cleanup_test_saves() -> void:
	var save_path := "user://saves/save_%d.json" % TEST_SLOT
	var backup_path := "user://saves/save_%d.backup.json" % TEST_SLOT
	var slot_0_path := "user://saves/save_0.json"
	var slot_0_backup := "user://saves/save_0.backup.json"

	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(slot_0_path):
		DirAccess.remove_absolute(slot_0_path)
	if FileAccess.file_exists(slot_0_backup):
		DirAccess.remove_absolute(slot_0_backup)

# =============================================================================
# AC1: Continue Button Visibility Tests
# =============================================================================

func test_continue_button_visible_when_save_exists() -> void:
	# Arrange - create a save in slot 0 (default continue slot)
	SaveManager.save_game(0)
	assert_true(SaveManager.save_exists(0), "Save should exist for test")

	# Act - check visibility logic
	var save_exists := SaveManager.save_exists(0)

	# Assert
	assert_true(save_exists, "Continue button should be visible when save exists (AC1)")


func test_continue_button_hidden_when_no_save() -> void:
	# Arrange - ensure no save exists
	_cleanup_test_saves()

	# Act
	var save_exists := SaveManager.save_exists(0)

	# Assert
	assert_false(save_exists, "Continue button should be hidden when no save exists (AC1)")


func test_save_exists_api_works_correctly() -> void:
	# Arrange
	_cleanup_test_saves()
	assert_false(SaveManager.save_exists(0), "Save should not exist before test")

	# Act
	SaveManager.save_game(0)

	# Assert
	assert_true(SaveManager.save_exists(0), "save_exists should return true after save")

# =============================================================================
# AC2: Continue Loads Game Tests
# =============================================================================

func test_load_game_returns_true_for_valid_save() -> void:
	# Arrange
	SaveManager.save_game(0)

	# Act
	var success := SaveManager.load_game(0)

	# Assert
	assert_true(success, "load_game should succeed with valid save (AC2)")


func test_load_game_returns_false_for_missing_save() -> void:
	# Arrange
	_cleanup_test_saves()

	# Act
	var success := SaveManager.load_game(0)

	# Assert
	assert_false(success, "load_game should fail when no save exists (AC2)")

# =============================================================================
# AC4: Loading Indicator Tests
# =============================================================================

func test_load_started_signal_emitted() -> void:
	# Arrange
	SaveManager.save_game(0)
	watch_signals(EventBus)

	# Act
	SaveManager.load_game(0)
	await wait_frames(1)

	# Assert
	assert_signal_emitted(EventBus, "load_started", "load_started signal should be emitted (AC4, AC6)")


func test_load_completed_signal_emitted_on_success() -> void:
	# Arrange
	SaveManager.save_game(0)
	watch_signals(EventBus)

	# Act
	SaveManager.load_game(0)
	await wait_frames(1)

	# Assert
	assert_signal_emitted(EventBus, "load_completed", "load_completed signal should be emitted (AC4, AC6)")


func test_is_loading_flag_during_load() -> void:
	# Arrange
	SaveManager.save_game(0)
	var state := {"was_loading": false}

	var callback := func() -> void:
		state.was_loading = SaveManager.is_loading()

	EventBus.load_started.connect(callback)

	# Act
	SaveManager.load_game(0)
	await wait_frames(1)

	# Cleanup
	EventBus.load_started.disconnect(callback)

	# Assert
	assert_true(state.was_loading, "is_loading should be true during load (AC4)")

# =============================================================================
# AC5: Error Handling Tests
# =============================================================================

func test_load_corrupted_save_returns_false() -> void:
	# Arrange - write corrupted save
	var save_path := "user://saves/save_0.json"
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string("{ invalid json }")
	file.close()

	# Act
	var success := SaveManager.load_game(0)

	# Assert
	assert_false(success, "load_game should return false for corrupted save (AC5)")


func test_load_completed_emits_false_on_failure() -> void:
	# Arrange - corrupted save
	var save_path := "user://saves/save_0.json"
	var dir := DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")

	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string("{ invalid }")
	file.close()

	var state := {"received": false, "success": true}
	var callback := func(success: bool) -> void:
		state.received = true
		state.success = success

	EventBus.load_completed.connect(callback)

	# Act
	SaveManager.load_game(0)
	await wait_frames(1)

	# Cleanup
	EventBus.load_completed.disconnect(callback)

	# Assert
	assert_true(state.received, "load_completed should be emitted")
	assert_false(state.success, "load_completed should emit false on failure (AC5)")

# =============================================================================
# AC6: EventBus Signal Tests
# =============================================================================

func test_load_signals_sequence() -> void:
	# Arrange
	SaveManager.save_game(0)
	var events: Array[String] = []

	var on_load_started := func() -> void:
		events.append("load_started")
	var on_load_completed := func(_s: bool) -> void:
		events.append("load_completed")

	EventBus.load_started.connect(on_load_started)
	EventBus.load_completed.connect(on_load_completed)

	# Act
	SaveManager.load_game(0)
	await wait_frames(1)

	# Cleanup
	EventBus.load_started.disconnect(on_load_started)
	EventBus.load_completed.disconnect(on_load_completed)

	# Assert
	assert_eq(events.size(), 2, "Should have 2 events")
	assert_eq(events[0], "load_started", "First event should be load_started (AC6)")
	assert_eq(events[1], "load_completed", "Second event should be load_completed (AC6)")

# =============================================================================
# Loading Overlay Tests
# =============================================================================

func test_loading_overlay_script_exists() -> void:
	# Assert
	assert_not_null(_loading_overlay_script, "Loading overlay script should exist")


func test_main_menu_script_exists() -> void:
	# Assert
	assert_not_null(_main_menu_script, "Main menu script should exist")

# =============================================================================
# Integration-Style Tests (Without Full Scene)
# =============================================================================

func test_save_and_load_roundtrip_for_menu() -> void:
	# Arrange
	_cleanup_test_saves()

	# Act - save
	var save_success := SaveManager.save_game(0)
	var exists_after_save := SaveManager.save_exists(0)

	# Act - load
	var load_success := SaveManager.load_game(0)

	# Assert
	assert_true(save_success, "Save should succeed")
	assert_true(exists_after_save, "Save should exist after save")
	assert_true(load_success, "Load should succeed")

# =============================================================================
# UI Scene Tests (AC1, AC2, AC4)
# =============================================================================

func test_main_menu_scene_loads() -> void:
	# Assert
	assert_not_null(_main_menu_scene, "Main menu scene should load")


func test_loading_overlay_scene_loads() -> void:
	# Assert
	assert_not_null(_loading_overlay_scene, "Loading overlay scene should load")


func test_main_menu_continue_button_hidden_by_default_in_scene() -> void:
	# Arrange - ensure no save exists
	_cleanup_test_saves()

	# Act - instantiate scene
	var menu := _main_menu_scene.instantiate()
	add_child(menu)
	await wait_frames(1)

	# Assert - Continue button should be hidden when no save exists
	var continue_btn: Button = menu.get_node("VBoxContainer/ContinueButton")
	assert_not_null(continue_btn, "Continue button should exist")
	assert_false(continue_btn.visible, "Continue button should be hidden when no save exists (AC1)")

	# Cleanup
	menu.queue_free()
	await wait_frames(1)


func test_main_menu_continue_button_visible_when_save_exists_ui() -> void:
	# Arrange - create a save
	SaveManager.save_game(0)
	assert_true(SaveManager.save_exists(0), "Save should exist for test")

	# Act - instantiate scene
	var menu := _main_menu_scene.instantiate()
	add_child(menu)
	await wait_frames(1)

	# Assert - Continue button should be visible when save exists
	var continue_btn: Button = menu.get_node("VBoxContainer/ContinueButton")
	assert_not_null(continue_btn, "Continue button should exist")
	assert_true(continue_btn.visible, "Continue button should be visible when save exists (AC1)")

	# Cleanup
	menu.queue_free()
	await wait_frames(1)


func test_loading_overlay_starts_hidden() -> void:
	# Act - instantiate scene
	var overlay := _loading_overlay_scene.instantiate()
	add_child(overlay)
	await wait_frames(1)

	# Assert
	assert_false(overlay.visible, "Loading overlay should start hidden (AC4)")

	# Cleanup
	overlay.queue_free()
	await wait_frames(1)


func test_loading_overlay_shows_on_load_started() -> void:
	# Arrange - instantiate overlay
	var overlay := _loading_overlay_scene.instantiate()
	add_child(overlay)
	await wait_frames(1)

	# Act - emit load_started
	EventBus.load_started.emit()
	await wait_frames(1)

	# Assert
	assert_true(overlay.visible, "Loading overlay should be visible after load_started (AC4)")

	# Cleanup - emit load_completed to reset
	EventBus.load_completed.emit(true)
	overlay.queue_free()
	await wait_frames(1)


func test_loading_overlay_hides_on_load_completed() -> void:
	# Arrange - instantiate and show overlay
	var overlay := _loading_overlay_scene.instantiate()
	add_child(overlay)
	await wait_frames(1)
	EventBus.load_started.emit()
	await wait_frames(1)
	assert_true(overlay.visible, "Overlay should be visible before test")

	# Act - emit load_completed
	EventBus.load_completed.emit(true)
	await wait_frames(1)

	# Assert
	assert_false(overlay.visible, "Loading overlay should be hidden after load_completed (AC4)")

	# Cleanup
	overlay.queue_free()
	await wait_frames(1)


func test_loading_overlay_is_showing_api() -> void:
	# Arrange
	var overlay := _loading_overlay_scene.instantiate()
	add_child(overlay)
	await wait_frames(1)

	# Assert - initially not showing
	assert_false(overlay.is_showing(), "is_showing() should return false when hidden")

	# Act - show overlay
	EventBus.load_started.emit()
	await wait_frames(1)

	# Assert - now showing
	assert_true(overlay.is_showing(), "is_showing() should return true when visible")

	# Cleanup
	EventBus.load_completed.emit(true)
	overlay.queue_free()
	await wait_frames(1)


func test_main_menu_error_dialog_exists() -> void:
	# Act - instantiate scene
	var menu := _main_menu_scene.instantiate()
	add_child(menu)
	await wait_frames(1)

	# Assert
	var error_dialog: AcceptDialog = menu.get_node("ErrorDialog")
	assert_not_null(error_dialog, "Error dialog should exist for error handling (AC5)")

	# Cleanup
	menu.queue_free()
	await wait_frames(1)
