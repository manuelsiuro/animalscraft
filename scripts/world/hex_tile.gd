## HexTile - Visual representation of a hex tile on the game world.
## Uses Node2D with Sprite2D for 2D rendering in portrait mode.
##
## Architecture: scripts/world/hex_tile.gd
## Scene: scenes/world/hex_tile.tscn
## Story: 1-2-render-hex-tiles
class_name HexTile
extends Node2D

# =============================================================================
# ENUMS
# =============================================================================

## Terrain types for hex tiles
enum TerrainType { GRASS, WATER, ROCK }

# =============================================================================
# CONSTANTS
# =============================================================================

## Terrain colors for placeholder visuals
const TERRAIN_COLORS: Dictionary = {
	TerrainType.GRASS: Color("#7CBA5F"),  # Warm grass green
	TerrainType.WATER: Color("#4A90C2"),  # Calm water blue
	TerrainType.ROCK: Color("#8B8B83"),   # Stone gray
}

# =============================================================================
# PROPERTIES
# =============================================================================

## The hex coordinate for this tile
var hex_coord: HexCoord

## The terrain type for this tile
var terrain_type: TerrainType = TerrainType.GRASS

## Reference to the polygon for visuals
@onready var polygon: Polygon2D = $Polygon2D

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# AR18: Internal setup only - no external dependencies
	add_to_group("tiles")
	_setup_hex_polygon()


## Initialize the hex tile with coordinate and terrain data.
## Call this after instantiating the scene.
## AR18: External data injection - called by factory/spawner after _ready()
##
## @param hex The hex coordinate for this tile
## @param terrain The terrain type to display
func initialize(hex: HexCoord, terrain: TerrainType) -> void:
	# AR18: Null safety guard
	if hex == null:
		push_error("[HexTile] Cannot initialize with null hex coordinate")
		return

	hex_coord = hex
	terrain_type = terrain

	# Position tile in world space using HexGrid conversion
	var world_pos := HexGrid.hex_to_world(hex)
	position = world_pos

	# Update visual with terrain color
	_update_visual()

# =============================================================================
# VISUAL METHODS
# =============================================================================

## Setup hex polygon with correct pointy-top vertices using HEX_SIZE.
## AC5: Dynamically generates polygon based on GameConstants.HEX_SIZE
func _setup_hex_polygon() -> void:
	if not polygon:
		return

	# Pointy-top hex vertices using HEX_SIZE
	# AC5: HEX_SIZE constant (64.0) used for sizing
	var size: float = GameConstants.HEX_SIZE
	var width_half: float = sqrt(3.0) / 2.0 * size  # ≈ 55.43 for size=64

	# Pointy-top hex: 6 vertices starting from top, clockwise
	var vertices := PackedVector2Array([
		Vector2(0, -size),                    # Top
		Vector2(width_half, -size / 2.0),     # Top-right
		Vector2(width_half, size / 2.0),      # Bottom-right
		Vector2(0, size),                     # Bottom
		Vector2(-width_half, size / 2.0),     # Bottom-left
		Vector2(-width_half, -size / 2.0),    # Top-left
	])

	polygon.polygon = vertices


## Update the visual appearance based on terrain type
func _update_visual() -> void:
	if not polygon:
		return

	var color: Color = TERRAIN_COLORS.get(terrain_type, TERRAIN_COLORS[TerrainType.GRASS])
	polygon.color = color


## Get the world position center of this tile
func get_world_center() -> Vector2:
	return position


## Get the terrain type as a string for debugging
func get_terrain_name() -> String:
	match terrain_type:
		TerrainType.GRASS:
			return "Grass"
		TerrainType.WATER:
			return "Water"
		TerrainType.ROCK:
			return "Rock"
		_:
			return "Unknown"

# =============================================================================
# STRING REPRESENTATION
# =============================================================================

func _to_string() -> String:
	if hex_coord:
		return "HexTile(%d, %d, %s)" % [hex_coord.q, hex_coord.r, get_terrain_name()]
	return "HexTile(uninitialized)"

# =============================================================================
# CLEANUP
# =============================================================================

## Cleanup resources before tile destruction.
## AR18: Resource cleanup pattern - reverse order of creation
func cleanup() -> void:
	# 1. Stop all processes (none currently)
	set_process(false)

	# 2. Disconnect all signals (none currently)
	# Future: Disconnect any connected signals here

	# 3. Clear internal references
	hex_coord = null
	polygon = null

	# 4. Remove from groups
	if is_in_group("tiles"):
		remove_from_group("tiles")

	# 5. Queue self for deletion
	queue_free()
