## HexGrid - Utility class for hex grid operations and coordinate conversions.
## Provides static methods for hex-to-world and world-to-hex conversions.
## Uses pointy-top hex orientation for portrait mode display.
##
## Reference: Red Blob Games - https://www.redblobgames.com/grids/hexagons/
## Architecture: scripts/world/hex_grid.gd
## Story: 1-1-implement-hex-grid-data-structure
class_name HexGrid
extends RefCounted

# =============================================================================
# CONSTANTS
# =============================================================================

## Square root of 3, precalculated for performance
const SQRT3: float = 1.7320508075688772

# =============================================================================
# COORDINATE CONVERSIONS
# =============================================================================

## Convert hex coordinate to world position (Vector2).
## Uses pointy-top orientation formula for portrait mode.
##
## Formula (pointy-top):
##   x = size * (sqrt(3) * q + sqrt(3)/2 * r)
##   y = size * (3/2 * r)
static func hex_to_world(hex: HexCoord) -> Vector2:
	var size: float = GameConstants.HEX_SIZE
	var x: float = size * (SQRT3 * hex.q + SQRT3 / 2.0 * hex.r)
	var y: float = size * (3.0 / 2.0 * hex.r)
	return Vector2(x, y)


## Convert world position to hex coordinate.
## Uses pointy-top orientation formula with axial rounding.
##
## Formula (pointy-top):
##   q = (sqrt(3)/3 * x - 1/3 * y) / size
##   r = (2/3 * y) / size
static func world_to_hex(world_pos: Vector2) -> HexCoord:
	var size: float = GameConstants.HEX_SIZE
	var q: float = (SQRT3 / 3.0 * world_pos.x - 1.0 / 3.0 * world_pos.y) / size
	var r: float = (2.0 / 3.0 * world_pos.y) / size
	return _axial_round(q, r)


## Round floating point axial coordinates to nearest hex.
## Uses cube coordinate rounding then converts back to axial.
static func _axial_round(fq: float, fr: float) -> HexCoord:
	var fs: float = -fq - fr

	var rq: int = roundi(fq)
	var rr: int = roundi(fr)
	var rs: int = roundi(fs)

	var q_diff: float = absf(float(rq) - fq)
	var r_diff: float = absf(float(rr) - fr)
	var s_diff: float = absf(float(rs) - fs)

	# Reset the component with largest rounding error
	if q_diff > r_diff and q_diff > s_diff:
		rq = -rr - rs
	elif r_diff > s_diff:
		rr = -rq - rs
	# Note: No need to recalculate rs since we only need q, r

	return HexCoord.new(rq, rr)

# =============================================================================
# UTILITY METHODS
# =============================================================================

## Calculate distance between two hex coordinates.
static func hex_distance(a: HexCoord, b: HexCoord) -> int:
	return a.distance_to(b)


## Get all hexes within a given range of a center hex.
static func get_hexes_in_range(center: HexCoord, range_val: int) -> Array[HexCoord]:
	var results: Array[HexCoord] = []

	for dq in range(-range_val, range_val + 1):
		var r1: int = maxi(-range_val, -dq - range_val)
		var r2: int = mini(range_val, -dq + range_val)
		for dr in range(r1, r2 + 1):
			results.append(HexCoord.new(center.q + dq, center.r + dr))

	return results


## Get a ring of hexes at exactly the given distance from center.
static func get_hex_ring(center: HexCoord, radius: int) -> Array[HexCoord]:
	if radius == 0:
		return [center]

	var results: Array[HexCoord] = []

	# Start at a known position and walk around
	var hex := HexCoord.new(center.q - radius, center.r + radius)

	for direction in range(6):
		for _step in range(radius):
			results.append(hex)
			hex = hex.get_neighbor(direction)

	return results


## Linear interpolation between two hex coordinates.
## Returns the hex at position t (0.0 to 1.0) along the line.
static func hex_lerp(a: HexCoord, b: HexCoord, t: float) -> HexCoord:
	var fq: float = lerpf(float(a.q), float(b.q), t)
	var fr: float = lerpf(float(a.r), float(b.r), t)
	return _axial_round(fq, fr)


## Get all hexes along a line between two coordinates (inclusive).
static func get_hex_line(start: HexCoord, end: HexCoord) -> Array[HexCoord]:
	var distance := start.distance_to(end)
	if distance == 0:
		return [start]

	var results: Array[HexCoord] = []
	for i in range(distance + 1):
		var t: float = float(i) / float(distance)
		results.append(hex_lerp(start, end, t))

	return results


## Check if a hex coordinate is within rectangular bounds.
static func is_in_bounds(hex: HexCoord, min_q: int, max_q: int, min_r: int, max_r: int) -> bool:
	return hex.q >= min_q and hex.q <= max_q and hex.r >= min_r and hex.r <= max_r


## Get the world-space bounding box for a hex (returns Rect2).
static func get_hex_bounds(hex: HexCoord) -> Rect2:
	var center := hex_to_world(hex)
	var size: float = GameConstants.HEX_SIZE

	# For pointy-top hexes:
	# Width = sqrt(3) * size
	# Height = 2 * size
	var width: float = SQRT3 * size
	var height: float = 2.0 * size

	return Rect2(center.x - width / 2.0, center.y - height / 2.0, width, height)
