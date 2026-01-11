## HexCoord - Axial coordinate class for hex grid positioning.
## Uses axial (q, r) coordinate system with pointy-top orientation.
##
## Reference: Red Blob Games - https://www.redblobgames.com/grids/hexagons/
## Architecture: scripts/world/hex_coord.gd
## Story: 1-1-implement-hex-grid-data-structure
class_name HexCoord
extends RefCounted

# =============================================================================
# PROPERTIES
# =============================================================================

## Column coordinate (axial q)
var q: int

## Row coordinate (axial r)
var r: int

## Derived S coordinate for cube representation (s = -q - r)
var s: int:
	get: return -q - r

# =============================================================================
# NEIGHBOR OFFSETS
# =============================================================================

## Axial neighbor offsets for pointy-top hexes.
## Ordered clockwise from east: 0=East, 1=NE, 2=NW, 3=West, 4=SW, 5=SE
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),   # East (direction 0)
	Vector2i(1, -1),  # Northeast (direction 1)
	Vector2i(0, -1),  # Northwest (direction 2)
	Vector2i(-1, 0),  # West (direction 3)
	Vector2i(-1, 1),  # Southwest (direction 4)
	Vector2i(0, 1),   # Southeast (direction 5)
]

# =============================================================================
# CONSTRUCTOR / FACTORY
# =============================================================================

func _init(p_q: int = 0, p_r: int = 0) -> void:
	q = p_q
	r = p_r


## Create a HexCoord from q, r values (alternative factory method)
static func create(p_q: int, p_r: int) -> HexCoord:
	return HexCoord.new(p_q, p_r)


## Create a HexCoord from a Vector2i (useful for dictionary keys)
static func from_vector(vec: Vector2i) -> HexCoord:
	return HexCoord.new(vec.x, vec.y)

# =============================================================================
# COORDINATE METHODS
# =============================================================================

## Get all 6 neighbors of this hex coordinate
func get_neighbors() -> Array[HexCoord]:
	var neighbors: Array[HexCoord] = []
	for offset in NEIGHBOR_OFFSETS:
		neighbors.append(HexCoord.new(q + offset.x, r + offset.y))
	return neighbors


## Get the neighbor in a specific direction (0-5, clockwise from east)
func get_neighbor(direction: int) -> HexCoord:
	var dir_index := direction % 6
	if dir_index < 0:
		dir_index += 6
	var offset := NEIGHBOR_OFFSETS[dir_index]
	return HexCoord.new(q + offset.x, r + offset.y)


## Calculate distance to another hex coordinate
func distance_to(other: HexCoord) -> int:
	var dq := absi(q - other.q)
	var dr := absi(r - other.r)
	var ds := absi(s - other.s)
	return maxi(dq, maxi(dr, ds))


## Add another HexCoord to this one
func add(other: HexCoord) -> HexCoord:
	return HexCoord.new(q + other.q, r + other.r)


## Subtract another HexCoord from this one
func subtract(other: HexCoord) -> HexCoord:
	return HexCoord.new(q - other.q, r - other.r)


## Scale this coordinate by a factor
func scale(factor: int) -> HexCoord:
	return HexCoord.new(q * factor, r * factor)

# =============================================================================
# COMPARISON / EQUALITY
# =============================================================================

## Check equality with another HexCoord
func equals(other: HexCoord) -> bool:
	if other == null:
		return false
	return q == other.q and r == other.r


## Convert to Vector2i for use as dictionary key
func to_vector() -> Vector2i:
	return Vector2i(q, r)

# =============================================================================
# STRING REPRESENTATION
# =============================================================================

func _to_string() -> String:
	return "HexCoord(%d, %d)" % [q, r]
