## Unit tests for Story 0.5: Scene Management
##
## These tests verify that scene management functionality works correctly:
## - Main scene loads and verifies autoloads
## - Game scene subsystems are accessible
## - Scene transitions via GameManager work properly
## - EventBus scene lifecycle signals emit correctly
##
## Test Framework: GUT (Godot Unit Test)
## Installation: https://github.com/bitwes/Gut
##   1. Install via AssetLib in Godot Editor (search for "Gut")
##   2. Or download and place in addons/gut/
## Run: Via GUT test runner in Godot Editor (bottom panel)
##
## IMPORTANT: This test file requires the GUT addon to be installed.
##
## Coverage:
## - AC1: Main scene loads without errors
## - AC2: Scene transition to Game works
## - AC3: Game scene structure matches Architecture
## - AC4: Android compatibility (display settings)
## - AC5: Integration verification (autoloads, EventBus)
extends GutTest


## Setup runs before each test
func before_each() -> void:
	gut.p("Running Story 0.5 scene management tests")


# =============================================================================
# AC1: Main Scene Loads Tests
# =============================================================================

## Test that Main scene constants are defined
func test_main_scene_constants_defined() -> void:
	# Main script should define critical and non-critical autoload lists
	var main_script := load("res://scripts/main.gd")
	assert_not_null(main_script, "Main script should exist")

	# Check that constants are accessible (loaded as class)
	var main_instance := Main.new()
	assert_not_null(main_instance.CRITICAL_AUTOLOADS, "CRITICAL_AUTOLOADS should be defined")
	assert_not_null(main_instance.NON_CRITICAL_AUTOLOADS, "NON_CRITICAL_AUTOLOADS should be defined")

	# Verify expected autoload counts
	assert_eq(main_instance.CRITICAL_AUTOLOADS.size(), 4, "Should have 4 critical autoloads")
	assert_eq(main_instance.NON_CRITICAL_AUTOLOADS.size(), 4, "Should have 4 non-critical autoloads")

	main_instance.free()


## Test that critical autoloads list contains correct items
func test_main_scene_critical_autoloads_list() -> void:
	var main_instance := Main.new()

	assert_has(main_instance.CRITICAL_AUTOLOADS, "GameConstants", "CRITICAL_AUTOLOADS should include GameConstants")
	assert_has(main_instance.CRITICAL_AUTOLOADS, "Logger", "CRITICAL_AUTOLOADS should include Logger")
	assert_has(main_instance.CRITICAL_AUTOLOADS, "ErrorHandler", "CRITICAL_AUTOLOADS should include ErrorHandler")
	assert_has(main_instance.CRITICAL_AUTOLOADS, "EventBus", "CRITICAL_AUTOLOADS should include EventBus")

	main_instance.free()


## Test that non-critical autoloads list contains correct items
func test_main_scene_non_critical_autoloads_list() -> void:
	var main_instance := Main.new()

	assert_has(main_instance.NON_CRITICAL_AUTOLOADS, "Settings", "NON_CRITICAL_AUTOLOADS should include Settings")
	assert_has(main_instance.NON_CRITICAL_AUTOLOADS, "AudioManager", "NON_CRITICAL_AUTOLOADS should include AudioManager")
	assert_has(main_instance.NON_CRITICAL_AUTOLOADS, "SaveManager", "NON_CRITICAL_AUTOLOADS should include SaveManager")
	assert_has(main_instance.NON_CRITICAL_AUTOLOADS, "GameManager", "NON_CRITICAL_AUTOLOADS should include GameManager")

	main_instance.free()


## Test that Main has autoload verification methods
func test_main_scene_has_verification_methods() -> void:
	var main_instance := Main.new()

	assert_true(main_instance.has_method("_verify_autoloads"), "Main should have _verify_autoloads() method")
	assert_true(main_instance.has_method("_is_autoload_ready"), "Main should have _is_autoload_ready() method")
	assert_true(main_instance.has_method("are_autoloads_ready"), "Main should have are_autoloads_ready() method")
	assert_true(main_instance.has_method("go_to_game"), "Main should have go_to_game() method")

	main_instance.free()


# =============================================================================
# AC2: Scene Transition Tests
# =============================================================================

## Test that GameManager has scene path constants
func test_game_manager_scene_paths() -> void:
	assert_eq(GameManager.MAIN_SCENE_PATH, "res://scenes/main.tscn", "MAIN_SCENE_PATH should be correct")
	assert_eq(GameManager.GAME_SCENE_PATH, "res://scenes/game.tscn", "GAME_SCENE_PATH should be correct")


## Test that GameManager has scene transition methods
func test_game_manager_scene_transition_methods() -> void:
	assert_true(GameManager.has_method("change_to_game_scene"), "GameManager should have change_to_game_scene() method")
	assert_true(GameManager.has_method("change_to_main_scene"), "GameManager should have change_to_main_scene() method")
	assert_true(GameManager.has_method("_change_scene"), "GameManager should have _change_scene() method")
	assert_true(GameManager.has_method("_do_scene_change"), "GameManager should have _do_scene_change() method")


## Test that scene paths point to existing resources
func test_scene_paths_exist() -> void:
	assert_true(ResourceLoader.exists(GameManager.MAIN_SCENE_PATH), "Main scene should exist at path")
	assert_true(ResourceLoader.exists(GameManager.GAME_SCENE_PATH), "Game scene should exist at path")


## Test that scenes can be loaded as PackedScene
func test_scenes_loadable() -> void:
	var main_scene := load(GameManager.MAIN_SCENE_PATH) as PackedScene
	assert_not_null(main_scene, "Main scene should load as PackedScene")

	var game_scene := load(GameManager.GAME_SCENE_PATH) as PackedScene
	assert_not_null(game_scene, "Game scene should load as PackedScene")


# =============================================================================
# AC3: Game Scene Structure Tests
# =============================================================================

## Test that Game scene has required child nodes
func test_game_scene_structure() -> void:
	var game_scene := load("res://scenes/game.tscn") as PackedScene
	var game_instance := game_scene.instantiate()

	# Check child nodes exist
	assert_not_null(game_instance.get_node_or_null("World"), "Game should have World node")
	assert_not_null(game_instance.get_node_or_null("UI"), "Game should have UI node")
	assert_not_null(game_instance.get_node_or_null("Camera"), "Game should have Camera node")

	game_instance.free()


## Test that Game child nodes have correct types
func test_game_scene_node_types() -> void:
	var game_scene := load("res://scenes/game.tscn") as PackedScene
	var game_instance := game_scene.instantiate()

	# World should be Node2D
	var world := game_instance.get_node_or_null("World")
	assert_true(world is Node2D, "World should be Node2D")

	# UI should be CanvasLayer
	var ui := game_instance.get_node_or_null("UI")
	assert_true(ui is CanvasLayer, "UI should be CanvasLayer")

	# Camera should be Camera2D
	var camera := game_instance.get_node_or_null("Camera")
	assert_true(camera is Camera2D, "Camera should be Camera2D")

	game_instance.free()


## Test that Game script has subsystem accessor methods
func test_game_script_accessors() -> void:
	var game_instance := Game.new()

	assert_true(game_instance.has_method("get_world"), "Game should have get_world() method")
	assert_true(game_instance.has_method("get_ui"), "Game should have get_ui() method")
	assert_true(game_instance.has_method("get_camera"), "Game should have get_camera() method")
	assert_true(game_instance.has_method("is_initialized"), "Game should have is_initialized() method")

	game_instance.free()


## Test that Game script has EventBus methods
func test_game_script_eventbus_methods() -> void:
	var game_instance := Game.new()

	assert_true(game_instance.has_method("_connect_eventbus_signals"), "Game should have _connect_eventbus_signals() method")
	assert_true(game_instance.has_method("_disconnect_eventbus_signals"), "Game should have _disconnect_eventbus_signals() method")

	game_instance.free()


## Test that Game script has lifecycle handlers
func test_game_script_lifecycle_handlers() -> void:
	var game_instance := Game.new()

	assert_true(game_instance.has_method("_on_game_paused"), "Game should have _on_game_paused() handler")
	assert_true(game_instance.has_method("_on_game_resumed"), "Game should have _on_game_resumed() handler")

	game_instance.free()


# =============================================================================
# AC4: Android Configuration Tests
# =============================================================================

## Test display configuration matches Architecture requirements
func test_display_configuration() -> void:
	var viewport_width := ProjectSettings.get_setting("display/window/size/viewport_width")
	var viewport_height := ProjectSettings.get_setting("display/window/size/viewport_height")

	assert_eq(viewport_width, 1080, "Viewport width should be 1080")
	assert_eq(viewport_height, 1920, "Viewport height should be 1920")


## Test portrait orientation is set
func test_portrait_orientation() -> void:
	var orientation := ProjectSettings.get_setting("display/window/handheld/orientation")
	# orientation=1 is portrait in Godot
	assert_eq(orientation, 1, "Orientation should be portrait (1)")


## Test mobile renderer is configured
func test_mobile_renderer() -> void:
	var renderer := ProjectSettings.get_setting("rendering/renderer/rendering_method")
	assert_eq(renderer, "mobile", "Renderer should be mobile")


## Test touch emulation is enabled
func test_touch_emulation() -> void:
	var touch_emulation := ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse")
	assert_true(touch_emulation, "Touch emulation should be enabled")


# =============================================================================
# AC5: EventBus Scene Lifecycle Signals Tests
# =============================================================================

## Test that EventBus has scene lifecycle signals
func test_eventbus_scene_signals_exist() -> void:
	assert_true(EventBus.has_signal("scene_loading"), "EventBus should have scene_loading signal")
	assert_true(EventBus.has_signal("scene_loaded"), "EventBus should have scene_loaded signal")
	assert_true(EventBus.has_signal("scene_unloading"), "EventBus should have scene_unloading signal")


## Test that EventBus has autoload verification signals
func test_eventbus_autoload_signals_exist() -> void:
	assert_true(EventBus.has_signal("autoloads_ready"), "EventBus should have autoloads_ready signal")
	assert_true(EventBus.has_signal("autoloads_failed"), "EventBus should have autoloads_failed signal")


## Test scene_loading signal emission
func test_scene_loading_signal_emission() -> void:
	var signal_received := false
	var received_path := ""

	var callback := func(path: String) -> void:
		signal_received = true
		received_path = path

	EventBus.scene_loading.connect(callback)
	EventBus.scene_loading.emit("res://scenes/test.tscn")

	assert_true(signal_received, "scene_loading signal should be received")
	assert_eq(received_path, "res://scenes/test.tscn", "Signal should carry correct path")

	EventBus.scene_loading.disconnect(callback)


## Test scene_loaded signal emission
func test_scene_loaded_signal_emission() -> void:
	var signal_received := false
	var received_name := ""

	var callback := func(name: String) -> void:
		signal_received = true
		received_name = name

	EventBus.scene_loaded.connect(callback)
	EventBus.scene_loaded.emit("game")

	assert_true(signal_received, "scene_loaded signal should be received")
	assert_eq(received_name, "game", "Signal should carry correct name")

	EventBus.scene_loaded.disconnect(callback)


## Test scene_unloading signal emission
func test_scene_unloading_signal_emission() -> void:
	var signal_received := false
	var received_name := ""

	var callback := func(name: String) -> void:
		signal_received = true
		received_name = name

	EventBus.scene_unloading.connect(callback)
	EventBus.scene_unloading.emit("main")

	assert_true(signal_received, "scene_unloading signal should be received")
	assert_eq(received_name, "main", "Signal should carry correct name")

	EventBus.scene_unloading.disconnect(callback)


## Test autoloads_ready signal emission
func test_autoloads_ready_signal_emission() -> void:
	var signal_received := false

	var callback := func() -> void:
		signal_received = true

	EventBus.autoloads_ready.connect(callback)
	EventBus.autoloads_ready.emit()

	assert_true(signal_received, "autoloads_ready signal should be received")

	EventBus.autoloads_ready.disconnect(callback)


## Test autoloads_failed signal emission
func test_autoloads_failed_signal_emission() -> void:
	var signal_received := false
	var received_missing: Array = []

	var callback := func(missing: Array) -> void:
		signal_received = true
		received_missing = missing

	EventBus.autoloads_failed.connect(callback)
	EventBus.autoloads_failed.emit(["TestAutoload"])

	assert_true(signal_received, "autoloads_failed signal should be received")
	assert_eq(received_missing.size(), 1, "Signal should carry missing autoloads array")
	assert_eq(received_missing[0], "TestAutoload", "Array should contain correct autoload name")

	EventBus.autoloads_failed.disconnect(callback)


# =============================================================================
# Integration Tests
# =============================================================================

## Test Main scene can verify all autoloads are present
func test_main_scene_autoload_verification() -> void:
	# All autoloads should be accessible
	assert_not_null(get_node_or_null("/root/GameConstants"), "GameConstants should be accessible")
	assert_not_null(get_node_or_null("/root/Logger"), "Logger should be accessible")
	assert_not_null(get_node_or_null("/root/ErrorHandler"), "ErrorHandler should be accessible")
	assert_not_null(get_node_or_null("/root/EventBus"), "EventBus should be accessible")
	assert_not_null(get_node_or_null("/root/Settings"), "Settings should be accessible")
	assert_not_null(get_node_or_null("/root/AudioManager"), "AudioManager should be accessible")
	assert_not_null(get_node_or_null("/root/SaveManager"), "SaveManager should be accessible")
	assert_not_null(get_node_or_null("/root/GameManager"), "GameManager should be accessible")


## Test that GameManager notification handler exists for Android focus
func test_game_manager_focus_handling() -> void:
	# GameManager should have _notification method for handling focus changes
	assert_true(GameManager.has_method("_notification"), "GameManager should handle notifications")

	# Process mode should be ALWAYS to handle notifications when paused
	assert_eq(GameManager.process_mode, Node.PROCESS_MODE_ALWAYS, "GameManager should process when paused")


## Test Main scene tscn structure is valid
func test_main_scene_structure() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	assert_not_null(main_scene, "Main scene should load")

	var main_instance := main_scene.instantiate()
	assert_not_null(main_instance, "Main scene should instantiate")

	# Main should have script attached
	assert_not_null(main_instance.get_script(), "Main should have script attached")

	main_instance.free()


## Test that Main script is attached correctly
func test_main_script_class() -> void:
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var main_instance := main_scene.instantiate()

	assert_true(main_instance is Main, "Main scene root should be Main class")

	main_instance.free()


## Test that Game script is attached correctly
func test_game_script_class() -> void:
	var game_scene := load("res://scenes/game.tscn") as PackedScene
	var game_instance := game_scene.instantiate()

	assert_true(game_instance is Game, "Game scene root should be Game class")

	game_instance.free()
