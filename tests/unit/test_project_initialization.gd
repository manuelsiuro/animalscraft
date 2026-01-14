## Unit tests for Story 0.1: Initialize Godot Project
##
## These tests verify that the project is correctly configured according to
## the Architecture specification and acceptance criteria.
##
## Test Framework: GUT (Godot Unit Test) - to be installed in Story 0.2+
## Run: Via GUT test runner in Godot Editor
##
## Coverage:
## - AC1: Project configuration validity
## - AC3: Mobile renderer enabled
## - AC4: Display settings (1080x1920 portrait)
## - AC2: Folder structure existence (sampled)
extends GutTest


## Setup runs before each test
func before_each() -> void:
	gut.p("Running Story 0.1 project initialization tests")


## Test AC1: Verify project loads and has correct configuration
func test_project_configuration_is_valid() -> void:
	# Verify project name
	var project_name: String = ProjectSettings.get_setting("application/config/name")
	assert_eq(project_name, "AnimalsCraft", "Project name should be AnimalsCraft")

	# Verify version
	var version: String = ProjectSettings.get_setting("application/config/version")
	assert_eq(version, "0.1.0", "Initial version should be 0.1.0")

	# Verify main scene is set
	var main_scene: String = ProjectSettings.get_setting("application/run/main_scene")
	assert_eq(main_scene, "res://scenes/main.tscn", "Main scene should be res://scenes/main.tscn")


## Test AC3: Verify Mobile renderer is configured
func test_mobile_renderer_is_enabled() -> void:
	# Verify rendering method
	var rendering_method: String = ProjectSettings.get_setting("rendering/renderer/rendering_method")
	assert_eq(rendering_method, "mobile", "Renderer should be Mobile, not Forward+")

	# Verify VRAM compression for mobile
	var vram_compression: bool = ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc")
	assert_true(vram_compression, "ETC2/ASTC compression should be enabled for mobile")


## Test AC4: Verify display settings for portrait orientation
func test_display_settings_are_portrait_1080x1920() -> void:
	# Verify viewport dimensions
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	assert_eq(width, 1080, "Viewport width should be 1080")

	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert_eq(height, 1920, "Viewport height should be 1920")

	# Verify portrait orientation
	var orientation: int = ProjectSettings.get_setting("display/window/handheld/orientation")
	assert_eq(orientation, 1, "Orientation should be 1 (portrait)")

	# Verify stretch settings
	var stretch_mode: String = ProjectSettings.get_setting("display/window/stretch/mode")
	assert_eq(stretch_mode, "canvas_items", "Stretch mode should be canvas_items")

	var stretch_aspect: String = ProjectSettings.get_setting("display/window/stretch/aspect")
	assert_eq(stretch_aspect, "keep_width", "Stretch aspect should be keep_width for portrait")


## Test AC2: Verify critical folder structure exists (sampled)
func test_folder_structure_exists() -> void:
	# Test root folders
	assert_true(DirAccess.dir_exists_absolute("res://autoloads"), "autoloads/ folder should exist")
	assert_true(DirAccess.dir_exists_absolute("res://scripts"), "scripts/ folder should exist")
	assert_true(DirAccess.dir_exists_absolute("res://scenes"), "scenes/ folder should exist")
	assert_true(DirAccess.dir_exists_absolute("res://resources"), "resources/ folder should exist")
	assert_true(DirAccess.dir_exists_absolute("res://assets"), "assets/ folder should exist")
	assert_true(DirAccess.dir_exists_absolute("res://tests"), "tests/ folder should exist")

	# Test sample subdirectories (not all 37 - just verify structure pattern)
	assert_true(DirAccess.dir_exists_absolute("res://scripts/entities"), "scripts/entities/ should exist")
	assert_true(DirAccess.dir_exists_absolute("res://scenes/world"), "scenes/world/ should exist")
	assert_true(DirAccess.dir_exists_absolute("res://assets/audio/music"), "assets/audio/music/ should exist")


## Test that Main scene loads successfully
func test_main_scene_loads() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	assert_not_null(main_scene, "Main scene should load without errors")

	# Instantiate and verify it's the Main class
	var main_instance: Node = main_scene.instantiate()
	assert_not_null(main_instance, "Main scene should instantiate")
	assert_true(main_instance is Main, "Scene root should be Main class")

	# Cleanup
	main_instance.free()


## Test that Game scene loads successfully
func test_game_scene_loads() -> void:
	var game_scene: PackedScene = load("res://scenes/game.tscn")
	assert_not_null(game_scene, "Game scene should load without errors")

	# Instantiate and verify it's the Game class
	var game_instance: Node = game_scene.instantiate()
	assert_not_null(game_instance, "Game scene should instantiate")
	assert_true(game_instance is Game, "Scene root should be Game class")

	# Cleanup
	game_instance.free()


## Test that Game scene has required child nodes
func test_game_scene_has_subsystems() -> void:
	var game_scene: PackedScene = load("res://scenes/game.tscn")
	var game_instance: Node = game_scene.instantiate()

	# Verify World, UI, Camera nodes exist
	var world: Node = game_instance.get_node_or_null("World")
	assert_not_null(world, "Game scene should have World node")
	assert_true(world is Node3D, "World should be Node3D")

	var ui: Node = game_instance.get_node_or_null("UI")
	assert_not_null(ui, "Game scene should have UI node")
	assert_true(ui is CanvasLayer, "UI should be CanvasLayer")

	var camera: Node = game_instance.get_node_or_null("Camera")
	assert_not_null(camera, "Game scene should have Camera node")
	assert_true(camera is Camera3D, "Camera should be Camera3D")

	# Cleanup
	game_instance.free()
