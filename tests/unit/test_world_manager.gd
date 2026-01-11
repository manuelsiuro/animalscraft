## Unit tests for Story 1.2: Render Hex Tiles - WorldManager component
##
## These tests verify WorldManager class functionality including world generation,
## tile spawning, and tile access methods.
##
## Test Framework: GUT (Godot Unit Test)
## Run: Via GUT test runner in Godot Editor (bottom panel)
##
## Coverage:
## - AC1: Hex grid rendering with 7x7 visible area
## - AC3: Performance with 200+ hexes
## - AC4: Coordinate integration with HexGrid
extends GutTest

# =============================================================================
# CONSTANTS
# =============================================================================

const FLOAT_TOLERANCE := 0.01

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _manager: WorldManager


func before_each() -> void:
	_manager = WorldManager.new()
	# Don't add to tree yet - some tests need to control when _ready fires


func after_each() -> void:
	if is_instance_valid(_manager):
		_manager.queue_free()
		_manager = null

# =============================================================================
# HELPER METHODS
# =============================================================================

## Add manager to tree and wait for world generation
func _setup_manager_with_generation() -> void:
	add_child(_manager)
	await get_tree().process_frame

# =============================================================================
# AC1: World Generation Tests
# =============================================================================

## Test WorldManager creation
func test_world_manager_creation() -> void:
	assert_not_null(_manager, "WorldManager should be created")
	assert_true(_manager is WorldManager, "Should be a WorldManager instance")


## Test world generates on ready
func test_world_generates_on_ready() -> void:
	add_child(_manager)
	await get_tree().process_frame

	assert_true(_manager.is_world_generated(), "World should be generated after _ready")


## Test starting area generation creates correct tile count
func test_starting_area_tile_count() -> void:
	await _setup_manager_with_generation()

	var tile_count := _manager.get_tile_count()
	# Range 3 = 3*3*(3+1) + 1 = 37 hexes (formula: 3*n*(n+1) + 1)
	assert_eq(tile_count, 37, "Starting area (range 3) should have 37 tiles")


## Test starting area is at least 7x7 (diameter = 2*range + 1 = 7)
func test_starting_area_minimum_size() -> void:
	await _setup_manager_with_generation()

	var tile_count := _manager.get_tile_count()
	# 7x7 area = at least 37 tiles for circular hex area
	assert_true(tile_count >= 37, "Starting area should have at least 37 tiles (7x7)")


## Test tiles are added to tree
func test_tiles_added_to_tree() -> void:
	await _setup_manager_with_generation()

	var tiles := get_tree().get_nodes_in_group("tiles")
	assert_eq(tiles.size(), 37, "All tiles should be in 'tiles' group")


## Test world_generated signal is emitted
func test_world_generated_signal() -> void:
	# Use GUT's signal watching - must watch BEFORE the signal is emitted
	watch_signals(_manager)

	# Adding to tree triggers _ready() which generates world and emits signal
	add_child(_manager)
	await get_tree().process_frame

	# Verify signal was emitted with correct parameters
	assert_signal_emitted(_manager, "world_generated", "world_generated signal should be emitted")
	assert_signal_emitted_with_parameters(_manager, "world_generated", [37])

# =============================================================================
# AC4: Tile Access and Coordinate Tests
# =============================================================================

## Test center tile exists at origin
func test_center_tile_exists() -> void:
	await _setup_manager_with_generation()

	var center := HexCoord.new(0, 0)
	var tile := _manager.get_tile_at(center)

	assert_not_null(tile, "Center tile at (0,0) should exist")


## Test get_tile_at with valid coordinates
func test_get_tile_at_valid() -> void:
	await _setup_manager_with_generation()

	# Test a tile within starting range
	var hex := HexCoord.new(2, -1)
	var tile := _manager.get_tile_at(hex)

	assert_not_null(tile, "Tile at (2,-1) should exist within range 3")
	assert_eq(tile.hex_coord.q, 2, "Tile q should match")
	assert_eq(tile.hex_coord.r, -1, "Tile r should match")


## Test get_tile_at with invalid coordinates returns null
func test_get_tile_at_invalid() -> void:
	await _setup_manager_with_generation()

	# Test a tile outside starting range
	var hex := HexCoord.new(10, 10)
	var tile := _manager.get_tile_at(hex)

	assert_null(tile, "Tile outside range should return null")


## Test get_tile_at with null returns null
func test_get_tile_at_null() -> void:
	await _setup_manager_with_generation()

	var tile := _manager.get_tile_at(null)
	assert_null(tile, "get_tile_at(null) should return null")


## Test get_tile_at_vector
func test_get_tile_at_vector() -> void:
	await _setup_manager_with_generation()

	var vec := Vector2i(1, -1)
	var tile := _manager.get_tile_at_vector(vec)

	assert_not_null(tile, "Tile at vector should exist")
	assert_eq(tile.hex_coord.q, 1, "Tile q should match vector")
	assert_eq(tile.hex_coord.r, -1, "Tile r should match vector")


## Test has_tile_at
func test_has_tile_at() -> void:
	await _setup_manager_with_generation()

	var inside := HexCoord.new(1, 1)
	var outside := HexCoord.new(10, 10)

	assert_true(_manager.has_tile_at(inside), "Should have tile inside range")
	assert_false(_manager.has_tile_at(outside), "Should not have tile outside range")


## Test has_tile_at with null
func test_has_tile_at_null() -> void:
	await _setup_manager_with_generation()

	assert_false(_manager.has_tile_at(null), "has_tile_at(null) should return false")


## Test get_all_tiles
func test_get_all_tiles() -> void:
	await _setup_manager_with_generation()

	var all_tiles := _manager.get_all_tiles()
	assert_eq(all_tiles.size(), 37, "get_all_tiles should return all tiles")


## Test tile positions match hex_to_world
func test_tile_positions_match_hex_to_world() -> void:
	await _setup_manager_with_generation()

	# Test several tiles
	var test_coords := [
		HexCoord.new(0, 0),
		HexCoord.new(1, 0),
		HexCoord.new(0, 1),
		HexCoord.new(-1, 1),
		HexCoord.new(2, -2),
	]

	for hex in test_coords:
		var tile := _manager.get_tile_at(hex)
		if tile:
			var expected := HexGrid.hex_to_world(hex)
			assert_almost_eq(tile.position.x, expected.x, FLOAT_TOLERANCE,
				"Tile at (%d,%d) x should match hex_to_world" % [hex.q, hex.r])
			assert_almost_eq(tile.position.y, expected.y, FLOAT_TOLERANCE,
				"Tile at (%d,%d) y should match hex_to_world" % [hex.q, hex.r])


## Test get_tile_at_world_pos
func test_get_tile_at_world_pos() -> void:
	await _setup_manager_with_generation()

	# Get a known tile and its world position
	var hex := HexCoord.new(1, -1)
	var world_pos := HexGrid.hex_to_world(hex)

	var tile := _manager.get_tile_at_world_pos(world_pos)
	assert_not_null(tile, "Should find tile at world position")
	assert_eq(tile.hex_coord.q, hex.q, "Found tile q should match")
	assert_eq(tile.hex_coord.r, hex.r, "Found tile r should match")

# =============================================================================
# AC3: Performance Tests
# =============================================================================

## Test can generate larger area without errors
func test_large_area_generation() -> void:
	add_child(_manager)
	await get_tree().process_frame

	# Generate 200+ tiles (range 8 = 217 tiles)
	_manager.generate_test_area(8)
	await get_tree().process_frame

	var tile_count := _manager.get_tile_count()
	# Range 8 = 3*8*9 + 1 = 217 tiles
	assert_eq(tile_count, 217, "Range 8 should generate 217 tiles (200+)")


## Test tile lookup performance with large area
func test_tile_lookup_performance() -> void:
	add_child(_manager)
	await get_tree().process_frame
	_manager.generate_test_area(8)
	await get_tree().process_frame

	# Perform many lookups (should be O(1) with Dictionary)
	var start := Time.get_ticks_msec()
	for i in range(1000):
		var _tile: HexTile = _manager.get_tile_at(HexCoord.new(0, 0))
	var elapsed := Time.get_ticks_msec() - start

	# 1000 lookups should complete in less than 100ms
	assert_true(elapsed < 100, "1000 tile lookups should complete in < 100ms (took %dms)" % elapsed)

# =============================================================================
# TERRAIN GENERATION TESTS
# =============================================================================

## Test terrain variety exists
func test_terrain_variety() -> void:
	await _setup_manager_with_generation()

	var terrain_counts := {
		HexTile.TerrainType.GRASS: 0,
		HexTile.TerrainType.WATER: 0,
		HexTile.TerrainType.ROCK: 0,
	}

	for tile in _manager.get_all_tiles():
		terrain_counts[tile.terrain_type] += 1

	# Grass should be most common
	assert_true(terrain_counts[HexTile.TerrainType.GRASS] > 0, "Should have GRASS terrain")
	# Note: WATER and ROCK may or may not appear due to pseudo-random generation


## Test center terrain is grass
func test_center_terrain_is_grass() -> void:
	await _setup_manager_with_generation()

	var center_tile := _manager.get_tile_at(HexCoord.new(0, 0))
	assert_eq(center_tile.terrain_type, HexTile.TerrainType.GRASS,
		"Center tile should be GRASS terrain")


## Test pseudo-random is deterministic
func test_terrain_generation_deterministic() -> void:
	# Generate twice and compare terrain
	await _setup_manager_with_generation()

	var first_terrains := {}
	for tile in _manager.get_all_tiles():
		first_terrains[tile.hex_coord.to_vector()] = tile.terrain_type

	# Regenerate
	_manager.generate_test_area(WorldManager.STARTING_RANGE)
	await get_tree().process_frame

	var all_match := true
	for tile in _manager.get_all_tiles():
		var vec := tile.hex_coord.to_vector()
		if first_terrains.has(vec) and first_terrains[vec] != tile.terrain_type:
			all_match = false
			break

	assert_true(all_match, "Terrain generation should be deterministic (same coords = same terrain)")

# =============================================================================
# WORLD BOUNDS TESTS
# =============================================================================

## Test get_world_bounds returns valid rect
func test_get_world_bounds() -> void:
	await _setup_manager_with_generation()

	var bounds := _manager.get_world_bounds()

	assert_true(bounds.size.x > 0, "Bounds width should be > 0")
	assert_true(bounds.size.y > 0, "Bounds height should be > 0")


## Test world bounds contains all tiles
func test_world_bounds_contains_all_tiles() -> void:
	await _setup_manager_with_generation()

	var bounds := _manager.get_world_bounds()

	for tile in _manager.get_all_tiles():
		var pos := tile.position
		assert_true(bounds.has_point(pos),
			"Bounds should contain tile at (%f, %f)" % [pos.x, pos.y])

# =============================================================================
# EDGE CASE TESTS
# =============================================================================

## Test double generation is prevented
func test_double_generation_prevented() -> void:
	await _setup_manager_with_generation()

	var initial_count := _manager.get_tile_count()

	# Try to generate again
	_manager.generate_starting_area()
	await get_tree().process_frame

	assert_eq(_manager.get_tile_count(), initial_count,
		"Double generation should be prevented")


## Test empty world before generation
func test_empty_world_before_generation() -> void:
	# Don't add to tree (no _ready)
	assert_false(_manager.is_world_generated(), "World should not be generated initially")
	assert_eq(_manager.get_tile_count(), 0, "Should have 0 tiles initially")
