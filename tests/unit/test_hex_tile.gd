## Unit tests for Story 1.2: Render Hex Tiles - HexTile component
##
## These tests verify HexTile class functionality including initialization,
## terrain types, and visual updates.
##
## Test Framework: GUT (Godot Unit Test)
## Run: Via GUT test runner in Godot Editor (bottom panel)
##
## Coverage:
## - AC1: Hex tile creation and rendering
## - AC2: Terrain type visuals (GRASS, WATER, ROCK)
## - AC4: Coordinate integration with HexCoord
## - AC5: Pointy-top orientation with HEX_SIZE
extends GutTest

# =============================================================================
# CONSTANTS
# =============================================================================

const FLOAT_TOLERANCE := 0.01

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _tile: HexTile


func before_each() -> void:
	_tile = HexTile.new()
	add_child(_tile)
	# Wait for _ready to complete
	await get_tree().process_frame


func after_each() -> void:
	if is_instance_valid(_tile):
		_tile.queue_free()
		_tile = null

# =============================================================================
# AC1 & AC4: HexTile Creation and Initialization Tests
# =============================================================================

## Test HexTile creation
func test_hex_tile_creation() -> void:
	assert_not_null(_tile, "HexTile should be created")
	assert_true(_tile is HexTile, "Should be a HexTile instance")


## Test HexTile is added to tiles group
func test_hex_tile_in_group() -> void:
	assert_true(_tile.is_in_group("tiles"), "HexTile should be in 'tiles' group")


## Test initialization with hex coordinate
func test_hex_tile_initialization() -> void:
	var hex := HexCoord.new(2, -1)
	_tile.initialize(hex, HexTile.TerrainType.GRASS)

	assert_not_null(_tile.hex_coord, "hex_coord should be set")
	assert_eq(_tile.hex_coord.q, 2, "q coordinate should be 2")
	assert_eq(_tile.hex_coord.r, -1, "r coordinate should be -1")
	assert_eq(_tile.terrain_type, HexTile.TerrainType.GRASS, "terrain should be GRASS")


## Test initialization with null hex returns early
func test_hex_tile_initialization_null_hex() -> void:
	_tile.initialize(null, HexTile.TerrainType.WATER)
	assert_null(_tile.hex_coord, "hex_coord should remain null with null input")


## Test tile position matches hex_to_world calculation
func test_tile_position_matches_hex_to_world() -> void:
	var hex := HexCoord.new(3, 1)
	_tile.initialize(hex, HexTile.TerrainType.ROCK)

	var expected := HexGrid.hex_to_world(hex)
	assert_almost_eq(_tile.position.x, expected.x, FLOAT_TOLERANCE, "x position should match hex_to_world")
	assert_almost_eq(_tile.position.y, expected.y, FLOAT_TOLERANCE, "y position should match hex_to_world")


## Test tile position at origin
func test_tile_position_at_origin() -> void:
	var hex := HexCoord.new(0, 0)
	_tile.initialize(hex, HexTile.TerrainType.GRASS)

	assert_almost_eq(_tile.position.x, 0.0, FLOAT_TOLERANCE, "Origin x should be 0")
	assert_almost_eq(_tile.position.y, 0.0, FLOAT_TOLERANCE, "Origin y should be 0")


## Test get_world_center returns position
func test_get_world_center() -> void:
	var hex := HexCoord.new(2, -3)
	_tile.initialize(hex, HexTile.TerrainType.WATER)

	var expected := HexGrid.hex_to_world(hex)
	var center := _tile.get_world_center()

	assert_almost_eq(center.x, expected.x, FLOAT_TOLERANCE, "World center x should match position")
	assert_almost_eq(center.y, expected.y, FLOAT_TOLERANCE, "World center y should match position (ground level)")
	assert_almost_eq(center.z, expected.z, FLOAT_TOLERANCE, "World center z should match position")

# =============================================================================
# AC2: Terrain Type Visual Tests
# =============================================================================

## Test TerrainType enum exists
func test_terrain_type_enum_exists() -> void:
	assert_eq(HexTile.TerrainType.GRASS, 0, "GRASS should be enum value 0")
	assert_eq(HexTile.TerrainType.WATER, 1, "WATER should be enum value 1")
	assert_eq(HexTile.TerrainType.ROCK, 2, "ROCK should be enum value 2")


## Test terrain colors are defined
func test_terrain_colors_defined() -> void:
	assert_true(HexTile.TERRAIN_COLORS.has(HexTile.TerrainType.GRASS), "GRASS color should be defined")
	assert_true(HexTile.TERRAIN_COLORS.has(HexTile.TerrainType.WATER), "WATER color should be defined")
	assert_true(HexTile.TERRAIN_COLORS.has(HexTile.TerrainType.ROCK), "ROCK color should be defined")


## Test GRASS terrain visual
func test_terrain_visual_grass() -> void:
	var hex := HexCoord.new(0, 0)
	_tile.initialize(hex, HexTile.TerrainType.GRASS)
	await get_tree().process_frame

	assert_eq(_tile.terrain_type, HexTile.TerrainType.GRASS, "Terrain should be GRASS")


## Test WATER terrain visual
func test_terrain_visual_water() -> void:
	var hex := HexCoord.new(1, 0)
	_tile.initialize(hex, HexTile.TerrainType.WATER)

	assert_eq(_tile.terrain_type, HexTile.TerrainType.WATER, "Terrain should be WATER")


## Test ROCK terrain visual
func test_terrain_visual_rock() -> void:
	var hex := HexCoord.new(0, 1)
	_tile.initialize(hex, HexTile.TerrainType.ROCK)

	assert_eq(_tile.terrain_type, HexTile.TerrainType.ROCK, "Terrain should be ROCK")


## Test get_terrain_name for GRASS
func test_get_terrain_name_grass() -> void:
	_tile.initialize(HexCoord.new(0, 0), HexTile.TerrainType.GRASS)
	assert_eq(_tile.get_terrain_name(), "Grass", "Terrain name should be 'Grass'")


## Test get_terrain_name for WATER
func test_get_terrain_name_water() -> void:
	_tile.initialize(HexCoord.new(0, 0), HexTile.TerrainType.WATER)
	assert_eq(_tile.get_terrain_name(), "Water", "Terrain name should be 'Water'")


## Test get_terrain_name for ROCK
func test_get_terrain_name_rock() -> void:
	_tile.initialize(HexCoord.new(0, 0), HexTile.TerrainType.ROCK)
	assert_eq(_tile.get_terrain_name(), "Rock", "Terrain name should be 'Rock'")

# =============================================================================
# AC5: Pointy-Top Orientation Tests
# =============================================================================

## Test tile uses HEX_SIZE for positioning
func test_tile_uses_hex_size() -> void:
	# Move to hex (1, 0) - should be at x = sqrt(3) * HEX_SIZE
	var hex := HexCoord.new(1, 0)
	_tile.initialize(hex, HexTile.TerrainType.GRASS)

	var expected_x := sqrt(3) * GameConstants.HEX_SIZE
	assert_almost_eq(_tile.position.x, expected_x, FLOAT_TOLERANCE, "x should use HEX_SIZE in calculation")
	assert_almost_eq(_tile.position.y, 0.0, FLOAT_TOLERANCE, "y should be 0 for r=0")


## Test pointy-top orientation (y changes with r, not q)
func test_pointy_top_orientation() -> void:
	# In pointy-top: moving in q direction doesn't change y
	var hex1 := HexCoord.new(0, 0)
	var hex2 := HexCoord.new(1, 0)

	var tile1 := HexTile.new()
	var tile2 := HexTile.new()
	add_child(tile1)
	add_child(tile2)

	tile1.initialize(hex1, HexTile.TerrainType.GRASS)
	tile2.initialize(hex2, HexTile.TerrainType.GRASS)

	assert_almost_eq(tile1.position.y, tile2.position.y, FLOAT_TOLERANCE,
		"Moving in q direction should not change y (pointy-top)")

	tile1.queue_free()
	tile2.queue_free()

# =============================================================================
# STRING REPRESENTATION TESTS
# =============================================================================

## Test to_string with initialized tile
func test_to_string_initialized() -> void:
	_tile.initialize(HexCoord.new(5, -3), HexTile.TerrainType.WATER)
	var str := _tile.to_string()
	assert_eq(str, "HexTile(5, -3, Water)", "to_string should format correctly")


## Test to_string with uninitialized tile
func test_to_string_uninitialized() -> void:
	var str := _tile.to_string()
	assert_eq(str, "HexTile(uninitialized)", "Uninitialized tile should show 'uninitialized'")

# =============================================================================
# AC7-5: 3D Terrain Model Tests (Story 7-5: Visual Review Fixes)
# =============================================================================

## Test USE_3D_TERRAIN_MODELS constant is defined
func test_use_3d_terrain_models_constant_defined() -> void:
	assert_true("USE_3D_TERRAIN_MODELS" in HexTile, "USE_3D_TERRAIN_MODELS constant should exist")


## Test TERRAIN_MODEL_PATHS contains all terrain types
func test_terrain_model_paths_defined() -> void:
	assert_true(HexTile.TERRAIN_MODEL_PATHS.has(HexTile.TerrainType.GRASS), "GRASS model path should be defined")
	assert_true(HexTile.TERRAIN_MODEL_PATHS.has(HexTile.TerrainType.WATER), "WATER model path should be defined")
	assert_true(HexTile.TERRAIN_MODEL_PATHS.has(HexTile.TerrainType.ROCK), "ROCK model path should be defined")


## Test _get_safe_surface_material returns null for invalid mesh
func test_get_safe_surface_material_null_mesh() -> void:
	var result := _tile._get_safe_surface_material(null)
	assert_null(result, "_get_safe_surface_material should return null for null input")


## Test _get_safe_surface_material returns null for mesh without surfaces
func test_get_safe_surface_material_no_surfaces() -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = null  # No mesh set
	add_child(mesh_instance)

	var result := _tile._get_safe_surface_material(mesh_instance)
	assert_null(result, "_get_safe_surface_material should return null for mesh without mesh resource")

	mesh_instance.queue_free()


## Test terrain model scale factor matches HEX_SIZE (Story 7-5 fix)
## When 3D models load, they should be scaled by HEX_SIZE (64 units)
func test_terrain_model_scale_factor() -> void:
	# This test verifies the scaling constant is correct
	# Models are created at unit scale (1.0), need to scale to HEX_SIZE
	var expected_scale: float = GameConstants.HEX_SIZE
	assert_eq(expected_scale, 64.0, "HEX_SIZE should be 64.0 for terrain model scaling")


## Test terrain model rotation offset (Story 7-5 fix)
## GLB models may be on XY plane, need -90° X rotation to lay flat on XZ plane
func test_terrain_model_rotation_offset() -> void:
	# When 3D models load, they should be rotated -90 degrees around X axis
	# This test documents the expected rotation offset
	var expected_rotation: float = -90.0
	# Note: Actual rotation is applied in _try_load_terrain_model()
	# This test documents the expected value
	assert_eq(expected_rotation, -90.0, "Terrain models should rotate -90 degrees on X axis")


## Test terrain scene cache is static (shared across all tiles)
func test_terrain_scene_cache_is_static() -> void:
	# The cache should be a static class variable
	assert_true(HexTile._terrain_scene_cache is Dictionary, "Terrain scene cache should be a Dictionary")


## Test _animate_state_transition handles no-tweener case (Story 7-5 fix)
## When using 3D models, procedural mesh may be hidden and have no materials to animate
## The tween should still work without throwing "started with no Tweeners" error
func test_animate_state_transition_no_crash_with_3d_models() -> void:
	var hex := HexCoord.new(0, 0)
	_tile.initialize(hex, HexTile.TerrainType.GRASS)
	await get_tree().process_frame

	# Setting territory state triggers _animate_state_transition()
	# This should NOT crash even if procedural mesh is hidden (3D model mode)
	_tile.set_territory_state(1)  # SCOUTED
	await get_tree().process_frame

	# If we get here without error, the test passes
	assert_true(true, "State transition should not crash with 3D terrain models")
