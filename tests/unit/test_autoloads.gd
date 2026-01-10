## Unit tests for Story 0.2: Core Autoloads
##
## These tests verify that all core autoloads are properly configured,
## registered, and functioning according to the Architecture specification.
##
## Test Framework: GUT (Godot Unit Test)
## Installation: https://github.com/bitwes/Gut
##   1. Install via AssetLib in Godot Editor (search for "Gut")
##   2. Or download and place in addons/gut/
## Run: Via GUT test runner in Godot Editor (bottom panel)
##
## IMPORTANT: This test file requires the GUT addon to be installed.
## Without GUT, these tests cannot run. The story should have specified
## the test framework requirement in Task 9.1.
##
## Coverage:
## - AC1: GameConstants accessibility and values
## - AC2: Logger output formatting
## - AC3: ErrorHandler error handling
## - AC4: EventBus signal emission
## - AC5: Settings persistence
## - AC6: AudioManager audio control
## - AC7: SaveManager save/load operations
## - AC8: GameManager state control
## - AC9: Autoload registration order
extends GutTest


## Setup runs before each test
func before_each() -> void:
	gut.p("Running Story 0.2 autoloads tests")


# =============================================================================
# AC1: GameConstants Tests
# =============================================================================

## Test that GameConstants autoload exists and is accessible
func test_game_constants_autoload_exists() -> void:
	var constants := get_node_or_null("/root/GameConstants")
	assert_not_null(constants, "GameConstants autoload should exist")


## Test that core constants are defined with correct values
func test_game_constants_core_values() -> void:
	assert_eq(GameConstants.HEX_SIZE, 64.0, "HEX_SIZE should be 64.0")
	assert_eq(GameConstants.MAX_ANIMALS, 200, "MAX_ANIMALS should be 200")
	assert_eq(GameConstants.AUTOSAVE_INTERVAL, 60.0, "AUTOSAVE_INTERVAL should be 60.0")
	assert_eq(GameConstants.MAX_PATH_REQUESTS_PER_FRAME, 50, "MAX_PATH_REQUESTS_PER_FRAME should be 50")


## Test that GameConstants has all expected constant categories
func test_game_constants_categories_exist() -> void:
	# Hex grid constants
	assert_true(GameConstants.HEX_SIZE > 0, "HEX_SIZE should be positive")
	assert_true(GameConstants.DEFAULT_MAP_WIDTH > 0, "DEFAULT_MAP_WIDTH should be positive")

	# Camera constants
	assert_true(GameConstants.CAMERA_ZOOM_MIN > 0, "CAMERA_ZOOM_MIN should be positive")
	assert_true(GameConstants.CAMERA_ZOOM_MAX > GameConstants.CAMERA_ZOOM_MIN, "CAMERA_ZOOM_MAX should be greater than MIN")

	# Save constants
	assert_eq(GameConstants.SAVE_SCHEMA_VERSION, 1, "Initial schema version should be 1")
	assert_true(GameConstants.MAX_SAVE_SLOTS >= 1, "Should have at least 1 save slot")


# =============================================================================
# AC2: Logger Tests
# =============================================================================

## Test that Logger autoload exists
func test_logger_autoload_exists() -> void:
	var logger := get_node_or_null("/root/Logger")
	assert_not_null(logger, "Logger autoload should exist")


## Test that Logger Level enum exists with correct values
func test_logger_level_enum() -> void:
	assert_eq(Logger.Level.DEBUG, 0, "DEBUG should be 0")
	assert_eq(Logger.Level.INFO, 1, "INFO should be 1")
	assert_eq(Logger.Level.WARN, 2, "WARN should be 2")
	assert_eq(Logger.Level.ERROR, 3, "ERROR should be 3")


## Test that Logger convenience methods exist
func test_logger_convenience_methods_exist() -> void:
	assert_true(Logger.has_method("log"), "Logger should have log() method")
	assert_true(Logger.has_method("debug"), "Logger should have debug() method")
	assert_true(Logger.has_method("info"), "Logger should have info() method")
	assert_true(Logger.has_method("warn"), "Logger should have warn() method")
	assert_true(Logger.has_method("error"), "Logger should have error() method")


# =============================================================================
# AC3: ErrorHandler Tests
# =============================================================================

## Test that ErrorHandler autoload exists
func test_error_handler_autoload_exists() -> void:
	var handler := get_node_or_null("/root/ErrorHandler")
	assert_not_null(handler, "ErrorHandler autoload should exist")


## Test that ErrorHandler has required signals
func test_error_handler_signals_exist() -> void:
	assert_true(ErrorHandler.has_signal("critical_error"), "ErrorHandler should have critical_error signal")
	assert_true(ErrorHandler.has_signal("error_recovered"), "ErrorHandler should have error_recovered signal")


## Test that ErrorHandler handle_error method exists
func test_error_handler_methods_exist() -> void:
	assert_true(ErrorHandler.has_method("handle_error"), "ErrorHandler should have handle_error() method")
	assert_true(ErrorHandler.has_method("report_recovered"), "ErrorHandler should have report_recovered() method")
	assert_true(ErrorHandler.has_method("is_system_in_error"), "ErrorHandler should have is_system_in_error() method")


## Test error tracking functionality
func test_error_handler_error_tracking() -> void:
	# Initially no errors
	assert_false(ErrorHandler.is_system_in_error("TestSystem"), "TestSystem should not be in error initially")

	# We can't fully test critical errors without triggering recovery
	# Just verify the methods can be called
	ErrorHandler.handle_error("TestSystem", "Test message", false)
	# Non-critical errors don't track state
	assert_false(ErrorHandler.is_system_in_error("TestSystem"), "Non-critical error should not set error state")


# =============================================================================
# AC4: EventBus Tests
# =============================================================================

## Test that EventBus autoload exists
func test_event_bus_autoload_exists() -> void:
	var bus := get_node_or_null("/root/EventBus")
	assert_not_null(bus, "EventBus autoload should exist")


## Test that EventBus has selection signals
func test_event_bus_selection_signals() -> void:
	assert_true(EventBus.has_signal("animal_selected"), "EventBus should have animal_selected signal")
	assert_true(EventBus.has_signal("animal_deselected"), "EventBus should have animal_deselected signal")
	assert_true(EventBus.has_signal("building_selected"), "EventBus should have building_selected signal")


## Test that EventBus has resource signals
func test_event_bus_resource_signals() -> void:
	assert_true(EventBus.has_signal("resource_changed"), "EventBus should have resource_changed signal")
	assert_true(EventBus.has_signal("resource_depleted"), "EventBus should have resource_depleted signal")


## Test that EventBus has game state signals
func test_event_bus_game_state_signals() -> void:
	assert_true(EventBus.has_signal("game_paused"), "EventBus should have game_paused signal")
	assert_true(EventBus.has_signal("game_resumed"), "EventBus should have game_resumed signal")
	assert_true(EventBus.has_signal("save_completed"), "EventBus should have save_completed signal")


## Test that EventBus has progression signals
func test_event_bus_progression_signals() -> void:
	assert_true(EventBus.has_signal("milestone_reached"), "EventBus should have milestone_reached signal")
	assert_true(EventBus.has_signal("building_unlocked"), "EventBus should have building_unlocked signal")
	assert_true(EventBus.has_signal("biome_unlocked"), "EventBus should have biome_unlocked signal")


## Test signal emission and reception
func test_event_bus_signal_emission() -> void:
	var signal_received := false
	var received_value: Variant = null

	var callback := func(value: Variant) -> void:
		signal_received = true
		received_value = value

	EventBus.setting_changed.connect(callback)
	EventBus.setting_changed.emit("test_setting", "test_value")

	assert_true(signal_received, "Signal should be received")
	assert_eq(received_value, "test_value", "Signal should carry correct value")

	EventBus.setting_changed.disconnect(callback)


# =============================================================================
# AC5: Settings Tests
# =============================================================================

## Test that Settings autoload exists
func test_settings_autoload_exists() -> void:
	var settings := get_node_or_null("/root/Settings")
	assert_not_null(settings, "Settings autoload should exist")


## Test default audio settings
func test_settings_default_audio_values() -> void:
	# Reset to ensure defaults
	Settings.reset_to_defaults()

	assert_almost_eq(Settings.get_music_volume(), 0.8, 0.01, "Default music volume should be 0.8")
	assert_almost_eq(Settings.get_sfx_volume(), 1.0, 0.01, "Default SFX volume should be 1.0")
	assert_false(Settings.is_muted(), "Audio should not be muted by default")


## Test settings getter and setter
func test_settings_getters_setters() -> void:
	var original_volume := Settings.get_music_volume()

	Settings.set_music_volume(0.5)
	assert_almost_eq(Settings.get_music_volume(), 0.5, 0.01, "Music volume should be updated to 0.5")

	# Restore original
	Settings.set_music_volume(original_volume)


## Test settings persistence methods exist
func test_settings_persistence_methods() -> void:
	assert_true(Settings.has_method("save"), "Settings should have save() method")
	assert_true(Settings.has_method("reset_to_defaults"), "Settings should have reset_to_defaults() method")
	assert_true(Settings.has_method("get_value"), "Settings should have generic get_value() method")
	assert_true(Settings.has_method("set_value"), "Settings should have generic set_value() method")


## Test gameplay settings
func test_settings_gameplay_values() -> void:
	Settings.reset_to_defaults()

	assert_almost_eq(Settings.get_touch_sensitivity(), 1.0, 0.01, "Default touch sensitivity should be 1.0")
	assert_false(Settings.is_tutorial_completed(), "Tutorial should not be completed by default")
	assert_true(Settings.is_auto_save_enabled(), "Auto-save should be enabled by default")


# =============================================================================
# AC6: AudioManager Tests
# =============================================================================

## Test that AudioManager autoload exists
func test_audio_manager_autoload_exists() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	assert_not_null(audio, "AudioManager autoload should exist")


## Test that AudioManager has music methods
func test_audio_manager_music_methods() -> void:
	assert_true(AudioManager.has_method("play_music"), "AudioManager should have play_music() method")
	assert_true(AudioManager.has_method("stop_music"), "AudioManager should have stop_music() method")
	assert_true(AudioManager.has_method("pause_music"), "AudioManager should have pause_music() method")
	assert_true(AudioManager.has_method("resume_music"), "AudioManager should have resume_music() method")
	assert_true(AudioManager.has_method("is_music_playing"), "AudioManager should have is_music_playing() method")


## Test that AudioManager has SFX methods
func test_audio_manager_sfx_methods() -> void:
	assert_true(AudioManager.has_method("play_sfx"), "AudioManager should have play_sfx() method")
	assert_true(AudioManager.has_method("play_sfx_from_path"), "AudioManager should have play_sfx_from_path() method")
	assert_true(AudioManager.has_method("play_ui_sfx"), "AudioManager should have play_ui_sfx() method")


## Test that AudioManager has volume control
func test_audio_manager_volume_control() -> void:
	assert_true(AudioManager.has_method("set_music_volume"), "AudioManager should have set_music_volume() method")
	assert_true(AudioManager.has_method("set_sfx_volume"), "AudioManager should have set_sfx_volume() method")
	assert_true(AudioManager.has_method("toggle_mute"), "AudioManager should have toggle_mute() method")
	assert_true(AudioManager.has_method("set_muted"), "AudioManager should have set_muted() method")


# =============================================================================
# AC7: SaveManager Tests
# =============================================================================

## Test that SaveManager autoload exists
func test_save_manager_autoload_exists() -> void:
	var save := get_node_or_null("/root/SaveManager")
	assert_not_null(save, "SaveManager autoload should exist")


## Test that SaveManager has save/load methods
func test_save_manager_save_load_methods() -> void:
	assert_true(SaveManager.has_method("save_game"), "SaveManager should have save_game() method")
	assert_true(SaveManager.has_method("load_game"), "SaveManager should have load_game() method")
	assert_true(SaveManager.has_method("emergency_save"), "SaveManager should have emergency_save() method")
	assert_true(SaveManager.has_method("quick_save"), "SaveManager should have quick_save() method")


## Test that SaveManager has slot management
func test_save_manager_slot_management() -> void:
	assert_true(SaveManager.has_method("save_exists"), "SaveManager should have save_exists() method")
	assert_true(SaveManager.has_method("get_save_info"), "SaveManager should have get_save_info() method")
	assert_true(SaveManager.has_method("get_all_save_info"), "SaveManager should have get_all_save_info() method")
	assert_true(SaveManager.has_method("delete_save"), "SaveManager should have delete_save() method")


## Test that SaveManager has signals
func test_save_manager_signals() -> void:
	assert_true(SaveManager.has_signal("save_started"), "SaveManager should have save_started signal")
	assert_true(SaveManager.has_signal("save_finished"), "SaveManager should have save_finished signal")
	assert_true(SaveManager.has_signal("load_started"), "SaveManager should have load_started signal")
	assert_true(SaveManager.has_signal("load_finished"), "SaveManager should have load_finished signal")


## Test save exists for non-existent slot
func test_save_manager_no_save_exists() -> void:
	# Slot 99 should never exist
	assert_false(SaveManager.save_exists(99), "Non-existent save slot should return false")


# =============================================================================
# AC8: GameManager Tests
# =============================================================================

## Test that GameManager autoload exists
func test_game_manager_autoload_exists() -> void:
	var game := get_node_or_null("/root/GameManager")
	assert_not_null(game, "GameManager autoload should exist")


## Test that GameManager has state methods
func test_game_manager_state_methods() -> void:
	assert_true(GameManager.has_method("get_state"), "GameManager should have get_state() method")
	assert_true(GameManager.has_method("is_playing"), "GameManager should have is_playing() method")
	assert_true(GameManager.has_method("is_paused"), "GameManager should have is_paused() method")
	assert_true(GameManager.has_method("is_in_menu"), "GameManager should have is_in_menu() method")


## Test that GameManager has game control methods
func test_game_manager_control_methods() -> void:
	assert_true(GameManager.has_method("start_new_game"), "GameManager should have start_new_game() method")
	assert_true(GameManager.has_method("load_saved_game"), "GameManager should have load_saved_game() method")
	assert_true(GameManager.has_method("pause_game"), "GameManager should have pause_game() method")
	assert_true(GameManager.has_method("resume_game"), "GameManager should have resume_game() method")
	assert_true(GameManager.has_method("toggle_pause"), "GameManager should have toggle_pause() method")
	assert_true(GameManager.has_method("return_to_menu"), "GameManager should have return_to_menu() method")


## Test that GameManager has time control
func test_game_manager_time_control() -> void:
	assert_true(GameManager.has_method("get_time_scale"), "GameManager should have get_time_scale() method")
	assert_true(GameManager.has_method("set_time_scale"), "GameManager should have set_time_scale() method")
	assert_true(GameManager.has_method("get_playtime_seconds"), "GameManager should have get_playtime_seconds() method")
	assert_true(GameManager.has_method("get_playtime_formatted"), "GameManager should have get_playtime_formatted() method")


## Test GameState enum
func test_game_manager_state_enum() -> void:
	assert_eq(GameManager.GameState.INITIALIZING, 0, "INITIALIZING should be 0")
	assert_eq(GameManager.GameState.MENU, 1, "MENU should be 1")
	assert_eq(GameManager.GameState.LOADING, 2, "LOADING should be 2")
	assert_eq(GameManager.GameState.PLAYING, 3, "PLAYING should be 3")
	assert_eq(GameManager.GameState.PAUSED, 4, "PAUSED should be 4")


## Test initial state
func test_game_manager_initial_state() -> void:
	# After initialization, GameManager should be in MENU state
	assert_true(GameManager.is_in_menu(), "GameManager should start in MENU state")


# =============================================================================
# AC9: Autoload Registration Order Tests
# =============================================================================

## Test that all autoloads are registered
func test_all_autoloads_registered() -> void:
	assert_not_null(get_node_or_null("/root/GameConstants"), "GameConstants should be registered")
	assert_not_null(get_node_or_null("/root/Logger"), "Logger should be registered")
	assert_not_null(get_node_or_null("/root/ErrorHandler"), "ErrorHandler should be registered")
	assert_not_null(get_node_or_null("/root/EventBus"), "EventBus should be registered")
	assert_not_null(get_node_or_null("/root/Settings"), "Settings should be registered")
	assert_not_null(get_node_or_null("/root/AudioManager"), "AudioManager should be registered")
	assert_not_null(get_node_or_null("/root/SaveManager"), "SaveManager should be registered")
	assert_not_null(get_node_or_null("/root/GameManager"), "GameManager should be registered")


## Test autoload order in scene tree
func test_autoload_order() -> void:
	# Get all autoload indices
	var root := get_tree().root
	var game_constants_idx := root.get_child(root.get_node("GameConstants").get_index()).get_index()
	var logger_idx := root.get_child(root.get_node("Logger").get_index()).get_index()
	var error_handler_idx := root.get_child(root.get_node("ErrorHandler").get_index()).get_index()
	var event_bus_idx := root.get_child(root.get_node("EventBus").get_index()).get_index()
	var settings_idx := root.get_child(root.get_node("Settings").get_index()).get_index()
	var audio_manager_idx := root.get_child(root.get_node("AudioManager").get_index()).get_index()
	var save_manager_idx := root.get_child(root.get_node("SaveManager").get_index()).get_index()
	var game_manager_idx := root.get_child(root.get_node("GameManager").get_index()).get_index()

	# Verify order: GameConstants < Logger < ErrorHandler < EventBus < Settings < AudioManager < SaveManager < GameManager
	assert_true(game_constants_idx < logger_idx, "GameConstants should load before Logger")
	assert_true(logger_idx < error_handler_idx, "Logger should load before ErrorHandler")
	assert_true(error_handler_idx < event_bus_idx, "ErrorHandler should load before EventBus")
	assert_true(event_bus_idx < settings_idx, "EventBus should load before Settings")
	assert_true(settings_idx < audio_manager_idx, "Settings should load before AudioManager")
	assert_true(audio_manager_idx < save_manager_idx, "AudioManager should load before SaveManager")
	assert_true(save_manager_idx < game_manager_idx, "SaveManager should load before GameManager")
