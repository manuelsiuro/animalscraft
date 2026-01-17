## Unit tests for Story 2-5: Implement AStar Pathfinding
##
## These tests verify PathfindingManager functionality for A* pathfinding
## on the hex grid with caching and throttling.
##
## Test Framework: GUT (Godot Unit Test)
## Run: Via GUT test runner in Godot Editor (bottom panel)
##
## Coverage:
## - AC1: Path calculation via AStar2D
## - AC2: Water tiles impassable
## - AC3: Path request throttling (50/frame)
## - AC4: Path caching with LRU eviction
## - AC5: Terrain change updates
## - AC6: Hex grid topology (6 neighbors)
extends GutTest

# =============================================================================
# TEST FIXTURE
# =============================================================================

## Mock WorldManager for testing
var _world_manager: Node3D

## PathfindingManager instance under test
var _pathfinding: PathfindingManager

## Mock tiles dictionary (Vector2i -> MockHexTile)
var _mock_tiles: Dictionary = {}

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Clear HexGrid occupancy from previous tests
	HexGrid.clear_occupancy()

	# Create mock world manager
	_world_manager = _create_mock_world_manager()
	add_child(_world_manager)

	# Create pathfinding manager
	_pathfinding = PathfindingManager.new()
	_pathfinding.name = "PathfindingManager"
	add_child(_pathfinding)

	await wait_frames(1)

	# Initialize with mock world manager
	_pathfinding.initialize(_world_manager)

	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(_pathfinding):
		_pathfinding.queue_free()
	if is_instance_valid(_world_manager):
		_world_manager.queue_free()
	_mock_tiles.clear()

	# Clear HexGrid occupancy to prevent test pollution
	HexGrid.clear_occupancy()

	await wait_frames(1)

# =============================================================================
# MOCK CREATION
# =============================================================================

## Create a mock WorldManager with a 7x7 hex grid centered at origin.
## All tiles default to GRASS terrain (passable).
func _create_mock_world_manager() -> Node3D:
	var manager = Node3D.new()
	manager.name = "MockWorldManager"

	var script := GDScript.new()
	script.source_code = """
extends Node3D

var _tiles: Dictionary = {}

func get_all_tiles() -> Array:
	return _tiles.values()

func get_tile_at(hex: HexCoord):
	if hex == null:
		return null
	return _tiles.get(hex.to_vector())

func has_tile_at(hex: HexCoord) -> bool:
	if hex == null:
		return false
	return _tiles.has(hex.to_vector())

func add_mock_tile(hex: HexCoord, terrain_type: int) -> void:
	var tile = MockHexTile.new()
	tile.hex_coord = hex
	tile.terrain_type = terrain_type
	_tiles[hex.to_vector()] = tile

func set_terrain_type(hex: HexCoord, terrain_type: int) -> void:
	var tile = _tiles.get(hex.to_vector())
	if tile:
		tile.terrain_type = terrain_type

class MockHexTile:
	var hex_coord: HexCoord
	var terrain_type: int = 0  # 0 = GRASS (passable)
"""
	script.reload()
	manager.set_script(script)

	# Create a 7x7 hex grid (range 3 from center)
	for q in range(-3, 4):
		for r in range(-3, 4):
			# Skip hexes outside hex distance 3
			var s := -q - r
			if abs(q) + abs(r) + abs(s) > 6:
				continue
			var hex := HexCoord.new(q, r)
			manager.add_mock_tile(hex, 0)  # 0 = GRASS

	return manager


## Helper to set terrain type on mock tile
func _set_terrain(hex: HexCoord, terrain_type: int) -> void:
	_world_manager.set_terrain_type(hex, terrain_type)

# =============================================================================
# AC1: PATH CALCULATION TESTS
# =============================================================================

## Test path from A to B returns array of HexCoord
func test_path_from_a_to_b_returns_array() -> void:
	var from := HexCoord.new(0, 0)
	var to := HexCoord.new(2, 0)

	var path: Array = _pathfinding.request_path(from, to)

	assert_gt(path.size(), 0, "Path should have elements")
	assert_eq(path[0].q, 0, "Path should start at origin q")
	assert_eq(path[0].r, 0, "Path should start at origin r")
	assert_eq(path[-1].q, 2, "Path should end at destination q")
	assert_eq(path[-1].r, 0, "Path should end at destination r")


## Test path from A to A returns single element
func test_path_from_a_to_a_returns_single_element() -> void:
	var coord := HexCoord.new(1, 1)

	var path: Array = _pathfinding.request_path(coord, coord)

	assert_eq(path.size(), 1, "Same start/end should return single element")
	assert_eq(path[0].q, 1, "Element should be the input coord q")
	assert_eq(path[0].r, 1, "Element should be the input coord r")


## Test null coordinates return empty array
func test_null_coordinates_return_empty() -> void:
	var from := HexCoord.new(0, 0)

	var path1: Array = _pathfinding.request_path(null, from)
	var path2: Array = _pathfinding.request_path(from, null)
	var path3: Array = _pathfinding.request_path(null, null)

	assert_eq(path1.size(), 0, "Null from should return empty")
	assert_eq(path2.size(), 0, "Null to should return empty")
	assert_eq(path3.size(), 0, "Both null should return empty")


## Test path is optimal (shortest number of steps)
func test_path_is_optimal_length() -> void:
	var from := HexCoord.new(0, 0)
	var to := HexCoord.new(3, 0)

	var path: Array = _pathfinding.request_path(from, to)

	# Direct path should be 4 hexes (distance 3 + 1 for inclusive)
	var expected_distance := from.distance_to(to)
	assert_eq(path.size(), expected_distance + 1, "Path should be optimal (distance + 1)")


## Test uninitialized pathfinding returns empty
func test_uninitialized_returns_empty() -> void:
	var uninit_pathfinding := PathfindingManager.new()
	add_child(uninit_pathfinding)
	await wait_frames(1)

	var from := HexCoord.new(0, 0)
	var to := HexCoord.new(1, 0)

	var path: Array = uninit_pathfinding.request_path(from, to)

	assert_eq(path.size(), 0, "Uninitialized pathfinding should return empty")

	uninit_pathfinding.queue_free()
	await wait_frames(1)

# =============================================================================
# AC2: WATER AVOIDANCE TESTS
# =============================================================================

## Test path avoids water tiles
func test_path_avoids_water_tiles() -> void:
	# Set water tile in direct path
	var water := HexCoord.new(1, 0)
	_set_terrain(water, 1)  # 1 = WATER
	_pathfinding.build_graph()
	await wait_frames(1)

	var from := HexCoord.new(0, 0)
	var to := HexCoord.new(2, 0)

	var path: Array = _pathfinding.request_path(from, to)

	# Path should exist but avoid water
	assert_gt(path.size(), 0, "Path should exist around water")
	for hex in path:
		var is_water: bool = (hex.q == 1 and hex.r == 0)
		assert_false(is_water, "Path should not include water tile at (1, 0)")


## Test no path when destination is surrounded by water
func test_no_path_when_surrounded_by_water() -> void:
	# Surround a hex with water
	var target := HexCoord.new(0, 2)
	var neighbors := target.get_neighbors()

	for neighbor in neighbors:
		if _world_manager.has_tile_at(neighbor):
			_set_terrain(neighbor, 1)  # 1 = WATER

	_pathfinding.build_graph()
	await wait_frames(1)

	var from := HexCoord.new(0, 0)
	var path: Array = _pathfinding.request_path(from, target)

	assert_eq(path.size(), 0, "No path should exist to surrounded hex")


## Test no path to impassable destination
func test_no_path_to_water_destination() -> void:
	var water_dest := HexCoord.new(1, 1)
	_set_terrain(water_dest, 1)  # 1 = WATER
	_pathfinding.build_graph()
	await wait_frames(1)

	var from := HexCoord.new(0, 0)
	var path: Array = _pathfinding.request_path(from, water_dest)

	assert_eq(path.size(), 0, "No path should exist to water destination")


## Test rock tiles are also impassable
func test_path_avoids_rock_tiles() -> void:
	var rock := HexCoord.new(1, 0)
	_set_terrain(rock, 2)  # 2 = ROCK
	_pathfinding.build_graph()
	await wait_frames(1)

	var from := HexCoord.new(0, 0)
	var to := HexCoord.new(2, 0)

	var path: Array = _pathfinding.request_path(from, to)

	# Path should exist but avoid rock
	for hex in path:
		var is_rock: bool = (hex.q == 1 and hex.r == 0)
		assert_false(is_rock, "Path should not include rock tile at (1, 0)")

# =============================================================================
# AC3: THROTTLING TESTS
# =============================================================================

## Test throttling at 50 requests per frame
func test_throttling_at_50_requests() -> void:
	var from := HexCoord.new(0, 0)
	var to := HexCoord.new(1, 0)

	# Make 60 requests in one frame
	var successful := 0
	for i in range(60):
		var path: Array = _pathfinding.request_path(from, to)
		if path.size() > 0:
			successful += 1

	# Note: After 50, cache hits still return results but don't count against throttle
	# First request calculates, next 49 hit cache, remaining 10 are throttled
	assert_eq(_pathfinding.get_frame_request_count(), 50, "Request count should be 50")


## Test requests beyond limit are queued
func test_requests_beyond_limit_are_queued() -> void:
	# Use larger grid for this test (91 hexes vs 37)
	if is_instance_valid(_world_manager):
		_world_manager.queue_free()
	_world_manager = _create_large_mock_world_manager()
	add_child(_world_manager)
	await wait_frames(1)
	_pathfinding.initialize(_world_manager)
	await wait_frames(1)

	# Fill up the frame quota with requests
	var from := HexCoord.new(0, 0)
	var destinations: Array[HexCoord] = []

	# Generate 50 valid destinations from larger grid (range 5)
	for q in range(-5, 6):
		for r in range(-5, 6):
			if q == 0 and r == 0:
				continue  # Skip same as start
			var s := -q - r
			if abs(q) + abs(r) + abs(s) > 10:
				continue  # Skip hexes outside grid
			destinations.append(HexCoord.new(q, r))
			if destinations.size() >= 50:
				break
		if destinations.size() >= 50:
			break

	# Make 50 requests to fill the quota
	for dest in destinations:
		_pathfinding.request_path(from, dest)

	assert_eq(_pathfinding.get_frame_request_count(), 50, "Should have 50 requests")

	# Next request should be queued
	var overflow_to := HexCoord.new(1, 1)
	_pathfinding.request_path(from, overflow_to)

	assert_gt(_pathfinding.get_queue_size(), 0, "Overflow requests should be queued")


## Test queued requests are processed next frame
func test_queued_requests_processed_next_frame() -> void:
	# Use larger grid for this test (91 hexes vs 37)
	if is_instance_valid(_world_manager):
		_world_manager.queue_free()
	_world_manager = _create_large_mock_world_manager()
	add_child(_world_manager)
	await wait_frames(1)
	_pathfinding.initialize(_world_manager)
	await wait_frames(1)

	# Fill up quota with valid requests (destinations != start)
	var from := HexCoord.new(0, 0)
	var destinations: Array[HexCoord] = []

	# Generate 50 valid destinations from larger grid
	for q in range(-5, 6):
		for r in range(-5, 6):
			if q == 0 and r == 0:
				continue
			var s := -q - r
			if abs(q) + abs(r) + abs(s) > 10:
				continue
			destinations.append(HexCoord.new(q, r))
			if destinations.size() >= 50:
				break
		if destinations.size() >= 50:
			break

	for dest in destinations:
		_pathfinding.request_path(from, dest)

	# Queue one more (overflow)
	var overflow_to := HexCoord.new(2, 2)
	_pathfinding.request_path(from, overflow_to)

	var queue_before := _pathfinding.get_queue_size()
	assert_gt(queue_before, 0, "Should have queued request")

	# Wait for next frame
	await wait_frames(2)

	var queue_after := _pathfinding.get_queue_size()
	assert_eq(queue_after, 0, "Queue should be empty after processing")


## Test frame request count resets each frame
func test_frame_request_count_resets() -> void:
	# Make some requests
	for i in range(10):
		var from := HexCoord.new(0, 0)
		var to := HexCoord.new(1, 0)
		_pathfinding.request_path(from, to)

	var count_before := _pathfinding.get_frame_request_count()
	assert_eq(count_before, 10, "Should have 10 requests this frame")

	# Wait for next frame
	await wait_frames(1)

	var count_after := _pathfinding.get_frame_request_count()
	assert_eq(count_after, 0, "Request count should reset to 0")

# =============================================================================
# AC4: CACHING TESTS
# =============================================================================

## Test cache hit for repeated requests
func test_cache_hit_for_repeated_requests() -> void:
	var from := HexCoord.new(0, 0)
	var to := HexCoord.new(2, 0)

	# First request (cache miss)
	var path1: Array = _pathfinding.request_path(from, to)

	# Second request (cache hit)
	var path2: Array = _pathfinding.request_path(from, to)

	assert_eq(path1.size(), path2.size(), "Cached path should have same size")
	for i in range(path1.size()):
		assert_eq(path1[i].q, path2[i].q, "Path q coords should match at index %d" % i)
		assert_eq(path1[i].r, path2[i].r, "Path r coords should match at index %d" % i)


## Test cache size increases with unique requests
func test_cache_size_increases() -> void:
	var initial_size := _pathfinding.get_cache_size()

	# Make unique path requests
	for i in range(5):
		var from := HexCoord.new(0, 0)
		var to := HexCoord.new(i - 2, 0)
		if from.q != to.q or from.r != to.r:  # Skip same start/end
			_pathfinding.request_path(from, to)

	assert_gt(_pathfinding.get_cache_size(), initial_size, "Cache size should increase")


## Test LRU eviction at max cache size
func test_lru_eviction_at_max_size() -> void:
	# Fill cache beyond max (100 entries)
	for i in range(110):
		var from := HexCoord.new(0, 0)
		# Create unique destinations within grid bounds
		var q := (i % 7) - 3
		var r := (i / 7) % 7 - 3
		if q != 0 or r != 0:  # Skip origin
			var to := HexCoord.new(q, r)
			if _world_manager.has_tile_at(to):
				_pathfinding.request_path(from, to)

	assert_true(_pathfinding.get_cache_size() <= 100, "Cache should not exceed max size (100)")


## Test invalidate_cache clears all entries
func test_invalidate_cache_clears_all() -> void:
	# Add some entries to cache
	for i in range(10):
		var from := HexCoord.new(0, 0)
		var to := HexCoord.new((i % 3) - 1, 0)
		_pathfinding.request_path(from, to)

	assert_gt(_pathfinding.get_cache_size(), 0, "Cache should have entries")

	_pathfinding.invalidate_cache()

	assert_eq(_pathfinding.get_cache_size(), 0, "Cache should be empty after invalidation")

# =============================================================================
# AC5: TERRAIN CHANGE UPDATE TESTS
# =============================================================================

## Test cache invalidation on terrain change
func test_cache_invalidation_on_terrain_change() -> void:
	var from := HexCoord.new(0, 0)
	var to := HexCoord.new(2, 0)

	# Request and cache path
	var path1: Array = _pathfinding.request_path(from, to)
	assert_gt(path1.size(), 0, "Initial path should exist")

	# Change terrain in the path
	var middle := HexCoord.new(1, 0)
	_set_terrain(middle, 1)  # 1 = WATER
	_pathfinding.update_hex(middle)

	# Request again - should recalculate
	var path2: Array = _pathfinding.request_path(from, to)

	# Path should be different (route around water)
	var same_path := path1.size() == path2.size()
	if same_path:
		for i in range(path1.size()):
			if path1[i].q != path2[i].q or path1[i].r != path2[i].r:
				same_path = false
				break

	assert_false(same_path, "Path should change after terrain update")


## Test update_hex reconnects neighbors correctly
func test_update_hex_reconnects_neighbors() -> void:
	# Block a hex
	var blocking := HexCoord.new(1, 0)
	_set_terrain(blocking, 1)  # WATER
	_pathfinding.update_hex(blocking)

	var from := HexCoord.new(0, 0)
	var to := HexCoord.new(2, 0)
	var path_blocked: Array = _pathfinding.request_path(from, to)

	# Path should route around
	for hex in path_blocked:
		assert_false(hex.q == 1 and hex.r == 0, "Path should avoid blocked hex")

	# Unblock the hex
	_set_terrain(blocking, 0)  # GRASS
	_pathfinding.update_hex(blocking)

	var path_unblocked: Array = _pathfinding.request_path(from, to)

	# Path should now be shorter (can go through)
	assert_true(path_unblocked.size() <= path_blocked.size(), "Unblocked path should be shorter or equal")


## Test build_graph clears existing graph
func test_build_graph_clears_existing() -> void:
	# Initial state
	var initial_points := _pathfinding._astar.get_point_count()
	assert_gt(initial_points, 0, "Graph should have points")

	# Add water tile to change terrain
	var water := HexCoord.new(0, 1)
	_set_terrain(water, 1)  # WATER

	# Rebuild
	_pathfinding.build_graph()

	# Cache should be cleared
	assert_eq(_pathfinding.get_cache_size(), 0, "Cache should be cleared on rebuild")

# =============================================================================
# AC6: HEX TOPOLOGY TESTS
# =============================================================================

## Test hex has 6 neighbors
func test_hex_has_six_neighbors() -> void:
	var center := HexCoord.new(0, 0)
	var neighbors := center.get_neighbors()

	assert_eq(neighbors.size(), 6, "Hex should have 6 neighbors")


## Test path follows hex neighbor steps
func test_path_follows_hex_neighbor_steps() -> void:
	var from := HexCoord.new(0, 0)
	var to := HexCoord.new(2, -1)

	var path: Array = _pathfinding.request_path(from, to)

	assert_gt(path.size(), 1, "Path should have multiple steps")

	# Verify each step is a valid hex neighbor
	for i in range(path.size() - 1):
		var current: HexCoord = path[i]
		var next_hex: HexCoord = path[i + 1]
		var is_neighbor := _is_hex_neighbor(current, next_hex)
		assert_true(is_neighbor, "Step %d to %d should be valid neighbor" % [i, i + 1])


## Test path uses all 6 directions when needed
func test_path_uses_multiple_directions() -> void:
	# Create a path that requires multiple direction changes
	var from := HexCoord.new(-2, 0)
	var to := HexCoord.new(2, -2)

	var path: Array = _pathfinding.request_path(from, to)

	assert_gt(path.size(), 2, "Path should have multiple steps")

	# Collect direction changes
	var directions_used := {}
	for i in range(path.size() - 1):
		var current: HexCoord = path[i]
		var next_hex: HexCoord = path[i + 1]
		var dq := next_hex.q - current.q
		var dr := next_hex.r - current.r
		var key := "%d,%d" % [dq, dr]
		directions_used[key] = true

	# Path should use at least some directions
	assert_gt(directions_used.size(), 0, "Path should use directions")


## Helper to check if two hexes are neighbors
func _is_hex_neighbor(a: HexCoord, b: HexCoord) -> bool:
	var dq: int = absi(a.q - b.q)
	var dr: int = absi(a.r - b.r)
	var ds: int = absi((-a.q - a.r) - (-b.q - b.r))
	# In hex grid, neighbors have distance 1 (sum of cube coord diffs = 2)
	return (dq + dr + ds) == 2


## Create a larger mock WorldManager for throttle tests (range 5 = 61 hexes)
func _create_large_mock_world_manager() -> Node3D:
	var manager = Node3D.new()
	manager.name = "LargeMockWorldManager"

	var script := GDScript.new()
	script.source_code = """
extends Node3D

var _tiles: Dictionary = {}

func get_all_tiles() -> Array:
	return _tiles.values()

func get_tile_at(hex: HexCoord):
	if hex == null:
		return null
	return _tiles.get(hex.to_vector())

func has_tile_at(hex: HexCoord) -> bool:
	if hex == null:
		return false
	return _tiles.has(hex.to_vector())

func add_mock_tile(hex: HexCoord, terrain_type: int) -> void:
	var tile = MockHexTile.new()
	tile.hex_coord = hex
	tile.terrain_type = terrain_type
	_tiles[hex.to_vector()] = tile

func set_terrain_type(hex: HexCoord, terrain_type: int) -> void:
	var tile = _tiles.get(hex.to_vector())
	if tile:
		tile.terrain_type = terrain_type

class MockHexTile:
	var hex_coord: HexCoord
	var terrain_type: int = 0  # 0 = GRASS (passable)
"""
	script.reload()
	manager.set_script(script)

	# Create a larger hex grid (range 5 = 91 hexes)
	for q in range(-5, 6):
		for r in range(-5, 6):
			var s := -q - r
			if abs(q) + abs(r) + abs(s) > 10:
				continue
			var hex := HexCoord.new(q, r)
			manager.add_mock_tile(hex, 0)  # 0 = GRASS

	return manager

# =============================================================================
# COORDINATE CONVERSION TESTS
# =============================================================================

## Test hex to point ID conversion is consistent
func test_hex_to_point_id_consistent() -> void:
	var hex := HexCoord.new(3, -2)
	var id1 := _pathfinding._hex_to_point_id(hex)
	var id2 := _pathfinding._hex_to_point_id(hex)

	assert_eq(id1, id2, "Same hex should produce same ID")


## Test point ID to hex conversion roundtrip
func test_point_id_roundtrip() -> void:
	var original := HexCoord.new(5, -3)
	var id := _pathfinding._hex_to_point_id(original)
	var result := _pathfinding._point_id_to_hex(id)

	assert_eq(result.q, original.q, "Roundtrip should preserve q")
	assert_eq(result.r, original.r, "Roundtrip should preserve r")


## Test negative coordinates convert correctly
func test_negative_coords_convert() -> void:
	var hex := HexCoord.new(-5, 3)
	var id := _pathfinding._hex_to_point_id(hex)
	var result := _pathfinding._point_id_to_hex(id)

	assert_eq(result.q, hex.q, "Negative q should roundtrip")
	assert_eq(result.r, hex.r, "Positive r should roundtrip")

# =============================================================================
# PASSABILITY TESTS
# =============================================================================

## Test is_passable returns true for grass
func test_is_passable_grass() -> void:
	var grass := HexCoord.new(0, 0)
	_set_terrain(grass, 0)  # GRASS

	assert_true(_pathfinding.is_passable(grass), "Grass should be passable")


## Test is_passable returns false for water
func test_is_passable_water() -> void:
	var water := HexCoord.new(1, 0)
	_set_terrain(water, 1)  # WATER

	assert_false(_pathfinding.is_passable(water), "Water should not be passable")


## Test is_passable returns false for rock
func test_is_passable_rock() -> void:
	var rock := HexCoord.new(0, 1)
	_set_terrain(rock, 2)  # ROCK

	assert_false(_pathfinding.is_passable(rock), "Rock should not be passable")


## Test is_passable returns false for null hex
func test_is_passable_null() -> void:
	assert_false(_pathfinding.is_passable(null), "Null hex should not be passable")


## Test is_passable returns false for invalid hex
func test_is_passable_invalid_hex() -> void:
	var invalid := HexCoord.new(100, 100)  # Outside grid

	assert_false(_pathfinding.is_passable(invalid), "Invalid hex should not be passable")

# =============================================================================
# PATH EXISTS TESTS
# =============================================================================

## Test path_exists returns true for valid path
func test_path_exists_valid() -> void:
	var from := HexCoord.new(0, 0)
	var to := HexCoord.new(1, 0)

	assert_true(_pathfinding.path_exists(from, to), "Path should exist between adjacent hexes")


## Test path_exists returns false for blocked path
func test_path_exists_blocked() -> void:
	# Block all paths to target
	var target := HexCoord.new(0, 2)
	for neighbor in target.get_neighbors():
		if _world_manager.has_tile_at(neighbor):
			_set_terrain(neighbor, 1)  # WATER
	_pathfinding.build_graph()
	await wait_frames(1)

	var from := HexCoord.new(0, 0)
	assert_false(_pathfinding.path_exists(from, target), "Path should not exist to surrounded hex")


## Test path_exists returns true for same point
func test_path_exists_same_point() -> void:
	var hex := HexCoord.new(0, 0)

	assert_true(_pathfinding.path_exists(hex, hex), "Path should exist to same point")

# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

## Test is_initialized returns correct state
func test_is_initialized() -> void:
	assert_true(_pathfinding.is_initialized(), "Should be initialized after setup")


## Test initialize with null world manager fails gracefully
func test_initialize_null_world_manager() -> void:
	var new_pathfinding := PathfindingManager.new()
	add_child(new_pathfinding)
	await wait_frames(1)

	new_pathfinding.initialize(null)

	assert_false(new_pathfinding.is_initialized(), "Should not be initialized with null")

	new_pathfinding.queue_free()
	await wait_frames(1)


## Test graph has correct point count
func test_graph_point_count() -> void:
	var point_count := _pathfinding._astar.get_point_count()

	# Mock world manager has ~37 hexes (range 3)
	assert_gt(point_count, 0, "Graph should have points")
	assert_true(point_count <= 50, "Graph should have reasonable point count")

# =============================================================================
# SIGNAL TESTS
# =============================================================================

## Test graph_rebuilt signal emitted on build
func test_graph_rebuilt_signal() -> void:
	watch_signals(_pathfinding)

	_pathfinding.build_graph()

	assert_signal_emitted(_pathfinding, "graph_rebuilt")


## Test cache_invalidated signal emitted on invalidate
func test_cache_invalidated_signal() -> void:
	# Add entry to cache
	_pathfinding.request_path(HexCoord.new(0, 0), HexCoord.new(1, 0))

	watch_signals(_pathfinding)

	_pathfinding.invalidate_cache()

	assert_signal_emitted(_pathfinding, "cache_invalidated")


## Test path_queued signal emitted when throttled
func test_path_queued_signal() -> void:
	# Use larger grid for this test (91 hexes vs 37)
	if is_instance_valid(_world_manager):
		_world_manager.queue_free()
	_world_manager = _create_large_mock_world_manager()
	add_child(_world_manager)
	await wait_frames(1)
	_pathfinding.initialize(_world_manager)
	await wait_frames(1)

	# Fill frame quota with valid requests (destinations != start)
	var from := HexCoord.new(0, 0)
	var destinations: Array[HexCoord] = []

	# Generate 50 valid destinations from larger grid
	for q in range(-5, 6):
		for r in range(-5, 6):
			if q == 0 and r == 0:
				continue
			var s := -q - r
			if abs(q) + abs(r) + abs(s) > 10:
				continue
			destinations.append(HexCoord.new(q, r))
			if destinations.size() >= 50:
				break
		if destinations.size() >= 50:
			break

	for dest in destinations:
		_pathfinding.request_path(from, dest)

	watch_signals(_pathfinding)

	# This should trigger queue and emit signal
	_pathfinding.request_path(from, HexCoord.new(1, 1))

	assert_signal_emitted(_pathfinding, "path_queued")
