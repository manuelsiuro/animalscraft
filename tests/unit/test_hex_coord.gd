## Unit tests for Story 1.1: Implement Hex Grid Data Structure
##
## These tests verify HexCoord class functionality and HexGrid utility methods
## following the Red Blob Games hexagonal grid reference.
##
## Test Framework: GUT (Godot Unit Test)
## Run: Via GUT test runner in Godot Editor (bottom panel)
##
## Coverage:
## - AC1: HexCoord class creation with q, r values
## - AC2: Hex-to-world conversion (pointy-top orientation)
## - AC3: World-to-hex conversion (inverse of hex_to_world)
## - AC4: Neighbor calculation (6 neighbors)
## - AC5: HEX_SIZE constant accessibility
## - AC6: Distance calculation between hexes
extends GutTest

# =============================================================================
# CONSTANTS FOR TESTING
# =============================================================================

## Tolerance for floating point comparisons
const FLOAT_TOLERANCE: float = 0.001

# =============================================================================
# SETUP
# =============================================================================

func before_each() -> void:
	gut.p("Running Story 1.1 HexCoord tests")

# =============================================================================
# AC1: HexCoord Class Creation Tests
# =============================================================================

## Test basic HexCoord creation with positive values
func test_hex_coord_creation_positive() -> void:
	var hex := HexCoord.new(3, -2)
	assert_eq(hex.q, 3, "q coordinate should be 3")
	assert_eq(hex.r, -2, "r coordinate should be -2")


## Test HexCoord creation with negative values
func test_hex_coord_creation_negative() -> void:
	var hex := HexCoord.new(-5, 7)
	assert_eq(hex.q, -5, "q coordinate should be -5")
	assert_eq(hex.r, 7, "r coordinate should be 7")


## Test HexCoord creation at origin
func test_hex_coord_creation_origin() -> void:
	var hex := HexCoord.new(0, 0)
	assert_eq(hex.q, 0, "q coordinate should be 0")
	assert_eq(hex.r, 0, "r coordinate should be 0")


## Test derived s coordinate (s = -q - r)
func test_hex_coord_s_coordinate() -> void:
	var hex := HexCoord.new(3, -2)
	assert_eq(hex.s, -1, "s coordinate should be -q - r = -3 - (-2) = -1")


## Test s coordinate constraint (q + r + s = 0)
func test_hex_coord_cube_constraint() -> void:
	var hex := HexCoord.new(5, -8)
	var sum := hex.q + hex.r + hex.s
	assert_eq(sum, 0, "Cube coordinate constraint: q + r + s should equal 0")


## Test default constructor creates origin
func test_hex_coord_default_constructor() -> void:
	var hex := HexCoord.new()
	assert_eq(hex.q, 0, "Default q should be 0")
	assert_eq(hex.r, 0, "Default r should be 0")


## Test static create factory method
func test_hex_coord_create_factory() -> void:
	var hex := HexCoord.create(4, -3)
	assert_eq(hex.q, 4, "Factory created q should be 4")
	assert_eq(hex.r, -3, "Factory created r should be -3")


## Test from_vector factory method
func test_hex_coord_from_vector() -> void:
	var vec := Vector2i(7, -4)
	var hex := HexCoord.from_vector(vec)
	assert_eq(hex.q, 7, "Vector-created q should be 7")
	assert_eq(hex.r, -4, "Vector-created r should be -4")


## Test to_vector conversion
func test_hex_coord_to_vector() -> void:
	var hex := HexCoord.new(9, -5)
	var vec := hex.to_vector()
	assert_eq(vec, Vector2i(9, -5), "to_vector should return Vector2i(9, -5)")

# =============================================================================
# AC2: Hex-to-World Conversion Tests (Pointy-Top)
# =============================================================================

## Test hex_to_world at origin returns Vector3.ZERO (y=0 for ground plane)
func test_hex_to_world_origin() -> void:
	var hex := HexCoord.new(0, 0)
	var world := HexGrid.hex_to_world(hex)
	assert_almost_eq(world.x, 0.0, FLOAT_TOLERANCE, "Origin x should be 0")
	assert_almost_eq(world.y, 0.0, FLOAT_TOLERANCE, "Origin y should be 0 (ground plane)")
	assert_almost_eq(world.z, 0.0, FLOAT_TOLERANCE, "Origin z should be 0")


## Test hex_to_world uses HEX_SIZE constant
func test_hex_to_world_uses_hex_size() -> void:
	# For pointy-top hex at (1, 0):
	# x = HEX_SIZE * sqrt(3) * 1 = 64 * 1.732... ≈ 110.85
	# y = HEX_SIZE * 0 = 0
	var hex := HexCoord.new(1, 0)
	var world := HexGrid.hex_to_world(hex)

	var expected_x := GameConstants.HEX_SIZE * sqrt(3)
	assert_almost_eq(world.x, expected_x, FLOAT_TOLERANCE, "x should use HEX_SIZE in formula")
	assert_almost_eq(world.y, 0.0, FLOAT_TOLERANCE, "y should be 0 for r=0")


## Test hex_to_world for positive r coordinate
func test_hex_to_world_positive_r() -> void:
	# For pointy-top hex at (0, 1):
	# x = HEX_SIZE * (sqrt(3)/2 * 1) ≈ 64 * 0.866 ≈ 55.42
	# z = HEX_SIZE * (3/2 * 1) = 64 * 1.5 = 96 (in 3D, Z is depth, Y is up)
	var hex := HexCoord.new(0, 1)
	var world := HexGrid.hex_to_world(hex)

	var expected_x := GameConstants.HEX_SIZE * (sqrt(3) / 2.0)
	var expected_z := GameConstants.HEX_SIZE * 1.5
	assert_almost_eq(world.x, expected_x, FLOAT_TOLERANCE, "x should follow pointy-top formula")
	assert_almost_eq(world.z, expected_z, FLOAT_TOLERANCE, "z should follow pointy-top formula (3D depth)")


## Test hex_to_world uses pointy-top orientation (not flat-top)
func test_hex_to_world_pointy_top_orientation() -> void:
	# In pointy-top: y depends on r, not q
	# Moving in pure q direction should not change y
	var hex_q1 := HexCoord.new(1, 0)
	var hex_q2 := HexCoord.new(2, 0)

	var world1 := HexGrid.hex_to_world(hex_q1)
	var world2 := HexGrid.hex_to_world(hex_q2)

	assert_almost_eq(world1.y, world2.y, FLOAT_TOLERANCE,
		"Moving in q direction should not change y (pointy-top orientation)")

# =============================================================================
# AC3: World-to-Hex Conversion Tests
# =============================================================================

## Test world_to_hex at origin
func test_world_to_hex_origin() -> void:
	var world := Vector3.ZERO
	var hex := HexGrid.world_to_hex(world)
	assert_eq(hex.q, 0, "Origin world position should map to q=0")
	assert_eq(hex.r, 0, "Origin world position should map to r=0")


## Test roundtrip conversion hex -> world -> hex
func test_world_to_hex_roundtrip() -> void:
	var original := HexCoord.new(5, -3)
	var world := HexGrid.hex_to_world(original)
	var result := HexGrid.world_to_hex(world)

	assert_eq(result.q, original.q, "Roundtrip should preserve q coordinate")
	assert_eq(result.r, original.r, "Roundtrip should preserve r coordinate")


## Test roundtrip for negative coordinates
func test_world_to_hex_roundtrip_negative() -> void:
	var original := HexCoord.new(-7, 4)
	var world := HexGrid.hex_to_world(original)
	var result := HexGrid.world_to_hex(world)

	assert_eq(result.q, original.q, "Roundtrip should preserve negative q")
	assert_eq(result.r, original.r, "Roundtrip should preserve r")


## Test roundtrip for large coordinates
func test_world_to_hex_roundtrip_large() -> void:
	var original := HexCoord.new(100, -50)
	var world := HexGrid.hex_to_world(original)
	var result := HexGrid.world_to_hex(world)

	assert_eq(result.q, original.q, "Roundtrip should work for large q")
	assert_eq(result.r, original.r, "Roundtrip should work for large r")


## Test world_to_hex correctly rounds to nearest hex
func test_world_to_hex_rounding() -> void:
	# Position slightly off-center should round to correct hex
	var hex_center := HexGrid.hex_to_world(HexCoord.new(3, -2))
	var offset := Vector3(5.0, 0, 5.0)  # Small offset within hex bounds (y=0 for ground plane)
	var result := HexGrid.world_to_hex(hex_center + offset)

	assert_eq(result.q, 3, "Should round to nearest hex q")
	assert_eq(result.r, -2, "Should round to nearest hex r")


## Test inverse relationship
func test_world_to_hex_is_inverse() -> void:
	# Test multiple coordinates to verify inverse relationship
	var test_coords := [
		HexCoord.new(0, 0),
		HexCoord.new(1, 0),
		HexCoord.new(0, 1),
		HexCoord.new(-1, 1),
		HexCoord.new(3, -5),
		HexCoord.new(-4, 2),
	]

	for original in test_coords:
		var world := HexGrid.hex_to_world(original)
		var back := HexGrid.world_to_hex(world)
		assert_eq(back.q, original.q, "Inverse should preserve q for (%d, %d)" % [original.q, original.r])
		assert_eq(back.r, original.r, "Inverse should preserve r for (%d, %d)" % [original.q, original.r])

# =============================================================================
# AC4: Neighbor Calculation Tests
# =============================================================================

## Test get_neighbors returns exactly 6 neighbors
func test_get_neighbors_count() -> void:
	var hex := HexCoord.new(0, 0)
	var neighbors := hex.get_neighbors()
	assert_eq(neighbors.size(), 6, "Should return exactly 6 neighbors")


## Test neighbors are all at distance 1
func test_get_neighbors_distance() -> void:
	var center := HexCoord.new(5, -3)
	var neighbors := center.get_neighbors()

	for neighbor in neighbors:
		var dist := center.distance_to(neighbor)
		assert_eq(dist, 1, "Each neighbor should be at distance 1")


## Test neighbor offsets match expected axial directions
func test_get_neighbors_correct_offsets() -> void:
	var center := HexCoord.new(0, 0)
	var neighbors := center.get_neighbors()

	# Expected neighbors from origin (clockwise from east)
	var expected := [
		Vector2i(1, 0),   # East
		Vector2i(1, -1),  # Northeast
		Vector2i(0, -1),  # Northwest
		Vector2i(-1, 0),  # West
		Vector2i(-1, 1),  # Southwest
		Vector2i(0, 1),   # Southeast
	]

	for i in range(6):
		assert_eq(neighbors[i].q, expected[i].x, "Neighbor %d q should match" % i)
		assert_eq(neighbors[i].r, expected[i].y, "Neighbor %d r should match" % i)


## Test get_neighbor for specific direction
func test_get_neighbor_single_direction() -> void:
	var center := HexCoord.new(3, -2)

	# Direction 0 = East = (+1, 0)
	var east := center.get_neighbor(0)
	assert_eq(east.q, 4, "East neighbor q should be center.q + 1")
	assert_eq(east.r, -2, "East neighbor r should be center.r")

	# Direction 3 = West = (-1, 0)
	var west := center.get_neighbor(3)
	assert_eq(west.q, 2, "West neighbor q should be center.q - 1")
	assert_eq(west.r, -2, "West neighbor r should be center.r")


## Test neighbors are unique
func test_get_neighbors_unique() -> void:
	var hex := HexCoord.new(7, -4)
	var neighbors := hex.get_neighbors()

	var seen := {}
	for neighbor in neighbors:
		var key := "%d,%d" % [neighbor.q, neighbor.r]
		assert_false(seen.has(key), "Neighbors should be unique")
		seen[key] = true

# =============================================================================
# AC5: HEX_SIZE Constant Tests
# =============================================================================

## Test HEX_SIZE is defined in GameConstants
func test_hex_size_exists() -> void:
	var size := GameConstants.HEX_SIZE
	assert_not_null(size, "HEX_SIZE should be defined")


## Test HEX_SIZE equals 64.0
func test_hex_size_value() -> void:
	assert_eq(GameConstants.HEX_SIZE, 64.0, "HEX_SIZE should be 64.0")


## Test HEX_SIZE is accessible from conversion functions
func test_hex_size_used_in_conversions() -> void:
	# Verify HEX_SIZE affects conversion output
	var hex := HexCoord.new(1, 0)
	var world := HexGrid.hex_to_world(hex)

	# Expected: x = 64 * sqrt(3) ≈ 110.85
	var expected := 64.0 * sqrt(3)
	assert_almost_eq(world.x, expected, FLOAT_TOLERANCE,
		"HEX_SIZE should be used in hex_to_world conversion")

# =============================================================================
# AC6: Distance Calculation Tests
# =============================================================================

## Test distance to self is zero
func test_distance_to_self() -> void:
	var hex := HexCoord.new(5, -3)
	var dist := hex.distance_to(hex)
	assert_eq(dist, 0, "Distance to self should be 0")


## Test distance to adjacent hex is 1
func test_distance_to_neighbor() -> void:
	var a := HexCoord.new(0, 0)
	var b := HexCoord.new(1, 0)  # East neighbor
	var dist := a.distance_to(b)
	assert_eq(dist, 1, "Distance to neighbor should be 1")


## Test distance calculation formula
func test_distance_calculation() -> void:
	var a := HexCoord.new(0, 0)
	var b := HexCoord.new(3, -2)

	# Distance = max(|dq|, |dr|, |ds|)
	# dq = 3, dr = -2, ds = -1
	# max(3, 2, 1) = 3
	var dist := a.distance_to(b)
	assert_eq(dist, 3, "Distance should be max(|dq|, |dr|, |ds|)")


## Test distance is symmetric
func test_distance_symmetric() -> void:
	var a := HexCoord.new(2, -5)
	var b := HexCoord.new(-3, 4)

	var dist_ab := a.distance_to(b)
	var dist_ba := b.distance_to(a)

	assert_eq(dist_ab, dist_ba, "Distance should be symmetric: d(a,b) = d(b,a)")


## Test static hex_distance method
func test_hex_distance_static() -> void:
	var a := HexCoord.new(1, 2)
	var b := HexCoord.new(4, -1)

	var instance_dist := a.distance_to(b)
	var static_dist := HexGrid.hex_distance(a, b)

	assert_eq(instance_dist, static_dist, "Static and instance distance methods should match")


## Test distance for negative coordinates
func test_distance_negative_coords() -> void:
	var a := HexCoord.new(-5, 3)
	var b := HexCoord.new(2, -4)

	# dq = 7, dr = -7, ds = 0
	# max(7, 7, 0) = 7
	var dist := a.distance_to(b)
	assert_eq(dist, 7, "Distance should work correctly with negative coordinates")

# =============================================================================
# ADDITIONAL UTILITY TESTS
# =============================================================================

## Test equality comparison
func test_hex_coord_equality() -> void:
	var a := HexCoord.new(3, -2)
	var b := HexCoord.new(3, -2)
	var c := HexCoord.new(3, -3)

	assert_true(a.equals(b), "Equal coordinates should return true")
	assert_false(a.equals(c), "Different coordinates should return false")


## Test equality with null
func test_hex_coord_equality_null() -> void:
	var hex := HexCoord.new(1, 1)
	assert_false(hex.equals(null), "Equality with null should return false")


## Test to_string format
func test_hex_coord_to_string() -> void:
	var hex := HexCoord.new(5, -3)
	var str := hex.to_string()
	assert_eq(str, "HexCoord(5, -3)", "to_string should format as 'HexCoord(q, r)'")


## Test add operation
func test_hex_coord_add() -> void:
	var a := HexCoord.new(3, -2)
	var b := HexCoord.new(1, 4)
	var result := a.add(b)

	assert_eq(result.q, 4, "Add should sum q coordinates")
	assert_eq(result.r, 2, "Add should sum r coordinates")


## Test subtract operation
func test_hex_coord_subtract() -> void:
	var a := HexCoord.new(5, -1)
	var b := HexCoord.new(2, 3)
	var result := a.subtract(b)

	assert_eq(result.q, 3, "Subtract should difference q coordinates")
	assert_eq(result.r, -4, "Subtract should difference r coordinates")


## Test scale operation
func test_hex_coord_scale() -> void:
	var hex := HexCoord.new(2, -3)
	var result := hex.scale(3)

	assert_eq(result.q, 6, "Scale should multiply q")
	assert_eq(result.r, -9, "Scale should multiply r")

# =============================================================================
# HexGrid UTILITY TESTS
# =============================================================================

## Test get_hexes_in_range at origin
func test_get_hexes_in_range() -> void:
	var center := HexCoord.new(0, 0)
	var hexes := HexGrid.get_hexes_in_range(center, 1)

	# Range 1 should include center + 6 neighbors = 7 hexes
	assert_eq(hexes.size(), 7, "Range 1 should include 7 hexes")


## Test get_hexes_in_range count formula
func test_get_hexes_in_range_count() -> void:
	# Formula: 3*n*(n+1) + 1 hexes in range n
	var center := HexCoord.new(5, -3)

	var range_2 := HexGrid.get_hexes_in_range(center, 2)
	var expected_2 := 3 * 2 * 3 + 1  # = 19
	assert_eq(range_2.size(), expected_2, "Range 2 should have 19 hexes")


## Test get_hex_ring returns correct count
func test_get_hex_ring_count() -> void:
	var center := HexCoord.new(0, 0)

	# Ring 0 = just center = 1 hex
	var ring_0 := HexGrid.get_hex_ring(center, 0)
	assert_eq(ring_0.size(), 1, "Ring 0 should have 1 hex")

	# Ring 1 = 6 hexes
	var ring_1 := HexGrid.get_hex_ring(center, 1)
	assert_eq(ring_1.size(), 6, "Ring 1 should have 6 hexes")

	# Ring n = 6*n hexes
	var ring_3 := HexGrid.get_hex_ring(center, 3)
	assert_eq(ring_3.size(), 18, "Ring 3 should have 18 hexes")


## Test get_hex_line between adjacent hexes
func test_get_hex_line_adjacent() -> void:
	var start := HexCoord.new(0, 0)
	var end := HexCoord.new(1, 0)
	var line := HexGrid.get_hex_line(start, end)

	assert_eq(line.size(), 2, "Line between adjacent hexes should have 2 hexes")


## Test get_hex_line between distant hexes
func test_get_hex_line_distant() -> void:
	var start := HexCoord.new(0, 0)
	var end := HexCoord.new(5, 0)
	var line := HexGrid.get_hex_line(start, end)

	# Distance is 5, so line should have 6 hexes (inclusive)
	assert_eq(line.size(), 6, "Line of distance 5 should have 6 hexes")


## Test is_in_bounds
func test_is_in_bounds() -> void:
	var hex := HexCoord.new(3, -2)

	assert_true(HexGrid.is_in_bounds(hex, 0, 5, -5, 5), "Hex should be in bounds")
	assert_false(HexGrid.is_in_bounds(hex, 0, 2, -5, 5), "Hex should be out of q bounds")
	assert_false(HexGrid.is_in_bounds(hex, 0, 5, 0, 5), "Hex should be out of r bounds")


## Test is_in_bounds with exact boundaries
func test_is_in_bounds_exact_boundaries() -> void:
	var hex_min := HexCoord.new(0, 0)
	var hex_max := HexCoord.new(5, 5)

	assert_true(HexGrid.is_in_bounds(hex_min, 0, 5, 0, 5), "Min boundary should be in bounds")
	assert_true(HexGrid.is_in_bounds(hex_max, 0, 5, 0, 5), "Max boundary should be in bounds")


## Test hex_lerp interpolation
func test_hex_lerp_midpoint() -> void:
	var start := HexCoord.new(0, 0)
	var end := HexCoord.new(4, 0)
	var mid := HexGrid.hex_lerp(start, end, 0.5)

	assert_eq(mid.q, 2, "Midpoint q should be halfway")
	assert_eq(mid.r, 0, "Midpoint r should remain 0")


## Test hex_lerp at start and end
func test_hex_lerp_endpoints() -> void:
	var start := HexCoord.new(1, 2)
	var end := HexCoord.new(5, -3)

	var at_start := HexGrid.hex_lerp(start, end, 0.0)
	assert_eq(at_start.q, start.q, "t=0.0 should return start q")
	assert_eq(at_start.r, start.r, "t=0.0 should return start r")

	var at_end := HexGrid.hex_lerp(start, end, 1.0)
	assert_eq(at_end.q, end.q, "t=1.0 should return end q")
	assert_eq(at_end.r, end.r, "t=1.0 should return end r")


## Test get_hex_bounds returns correct rect size
func test_get_hex_bounds_size() -> void:
	var hex := HexCoord.new(0, 0)
	var bounds := HexGrid.get_hex_bounds(hex)

	var expected_width := sqrt(3) * GameConstants.HEX_SIZE
	var expected_depth := 2.0 * GameConstants.HEX_SIZE

	assert_almost_eq(bounds.size.x, expected_width, FLOAT_TOLERANCE, "Bounds width (X) should match hex width")
	assert_almost_eq(bounds.size.z, expected_depth, FLOAT_TOLERANCE, "Bounds depth (Z) should match hex depth")


## Test get_hex_bounds centered on hex position
func test_get_hex_bounds_centered() -> void:
	var hex := HexCoord.new(3, -2)
	var world_pos := HexGrid.hex_to_world(hex)
	var bounds := HexGrid.get_hex_bounds(hex)

	# AABB.get_center() returns the center of the bounding box
	var bounds_center := bounds.get_center()

	assert_almost_eq(bounds_center.x, world_pos.x, FLOAT_TOLERANCE, "Bounds should be centered on hex x")
	assert_almost_eq(bounds_center.z, world_pos.z, FLOAT_TOLERANCE, "Bounds should be centered on hex z")
	# Note: AABB has height=1 (y: 0 to 1), so center.y = 0.5, not 0
	# We check that bounds.position.y matches ground plane instead
	assert_almost_eq(bounds.position.y, world_pos.y, FLOAT_TOLERANCE, "Bounds base y should match ground plane")


## Test get_hexes_in_range includes center
func test_get_hexes_in_range_includes_center() -> void:
	var center := HexCoord.new(5, -3)
	var hexes := HexGrid.get_hexes_in_range(center, 2)

	var found_center := false
	for hex in hexes:
		if hex.q == center.q and hex.r == center.r:
			found_center = true
			break

	assert_true(found_center, "Range should include center hex")


## Test get_hexes_in_range all within distance
func test_get_hexes_in_range_all_within_distance() -> void:
	var center := HexCoord.new(0, 0)
	var range_val := 3
	var hexes := HexGrid.get_hexes_in_range(center, range_val)

	for hex in hexes:
		var dist := center.distance_to(hex)
		assert_true(dist <= range_val, "All hexes should be within range %d, got %d at (%d, %d)" % [range_val, dist, hex.q, hex.r])


## Test get_hex_ring at distance
func test_get_hex_ring_all_at_distance() -> void:
	var center := HexCoord.new(2, -1)
	var radius := 2
	var ring := HexGrid.get_hex_ring(center, radius)

	for hex in ring:
		var dist := center.distance_to(hex)
		assert_eq(dist, radius, "All ring hexes should be exactly at distance %d, got %d at (%d, %d)" % [radius, dist, hex.q, hex.r])


## Test get_hex_line includes endpoints
func test_get_hex_line_includes_endpoints() -> void:
	var start := HexCoord.new(0, 0)
	var end := HexCoord.new(3, 2)
	var line := HexGrid.get_hex_line(start, end)

	var first := line[0]
	var last := line[line.size() - 1]

	assert_eq(first.q, start.q, "Line should start at start hex q")
	assert_eq(first.r, start.r, "Line should start at start hex r")
	assert_eq(last.q, end.q, "Line should end at end hex q")
	assert_eq(last.r, end.r, "Line should end at end hex r")


## Test get_hex_line forms continuous path
func test_get_hex_line_continuous() -> void:
	var start := HexCoord.new(0, 0)
	var end := HexCoord.new(5, -2)
	var line := HexGrid.get_hex_line(start, end)

	# Each hex in line should be distance 1 from previous
	for i in range(1, line.size()):
		var dist := line[i - 1].distance_to(line[i])
		assert_true(dist <= 1, "Line should be continuous (adjacent hexes), got distance %d between step %d and %d" % [dist, i - 1, i])
