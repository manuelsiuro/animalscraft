## HexTile - Visual representation of a hex tile on the game world.
## Uses Node3D with MeshInstance3D for 3D rendering with isometric view.
##
## Architecture: scripts/world/hex_tile.gd
## Scene: scenes/world/hex_tile.tscn
## Story: 1-2-render-hex-tiles (Updated for 3D in Story 1-0 rework)
class_name HexTile
extends Node3D

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

## Territory visual constants (Story 1.5)
const STATE_TRANSITION_DURATION: float = 0.4
const FOG_OPACITY: float = 0.85
const SCOUTED_SATURATION: float = 0.5
const BORDER_WIDTH: float = 3.0

## Territory colors
const COLOR_CONTESTED: Color = Color("#E74C3C")  # Red
const COLOR_CLAIMED: Color = Color("#3498DB")    # Blue (player color)
const COLOR_NEGLECTED: Color = Color("#95A5A6")  # Gray

# =============================================================================
# PROPERTIES
# =============================================================================

## The hex coordinate for this tile
var hex_coord: HexCoord

## The terrain type for this tile
var terrain_type: TerrainType = TerrainType.GRASS

## The territory state for this tile (Story 1.5)
## Starts at -1 (uninitialized) until TerritoryManager assigns a state
var territory_state: int = -1

## Reference to the mesh instance for terrain visuals
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

## Reference to border mesh (Story 1.5)
@onready var border_mesh: MeshInstance3D = $BorderMesh

## Reference to fog overlay mesh (Story 1.5)
@onready var fog_mesh: MeshInstance3D = $FogMesh

## Tween for state transitions
var _tween: Tween

## Tween for fog animation loop (AC1: subtle fog animation)
var _fog_animation_tween: Tween

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# AR18: Internal setup only - no external dependencies
	add_to_group("tiles")
	_setup_hex_mesh()
	_setup_territory_visuals()


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

## Setup hex mesh with correct pointy-top vertices using HEX_SIZE.
## AC5: Dynamically generates 3D mesh based on GameConstants.HEX_SIZE
func _setup_hex_mesh() -> void:
	if not mesh_instance:
		return

	# Create hexagonal mesh for terrain
	var hex_mesh := _create_hexagonal_mesh(GameConstants.HEX_SIZE)
	mesh_instance.mesh = hex_mesh

	# Create material for terrain
	var material := StandardMaterial3D.new()
	material.albedo_color = TERRAIN_COLORS[TerrainType.GRASS]  # Default color
	mesh_instance.set_surface_override_material(0, material)

	# Setup border mesh (slightly larger, positioned above to avoid z-fighting)
	if border_mesh:
		var border_size := GameConstants.HEX_SIZE + 3.0  # BORDER_WIDTH pixels larger
		border_mesh.mesh = _create_hexagonal_mesh(border_size)
		border_mesh.position.y = 0.01  # Slightly above terrain
		var border_material := StandardMaterial3D.new()
		border_material.albedo_color = Color.TRANSPARENT
		border_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		border_mesh.set_surface_override_material(0, border_material)

	# Setup fog mesh (same size as terrain, positioned above border)
	if fog_mesh:
		fog_mesh.mesh = _create_hexagonal_mesh(GameConstants.HEX_SIZE)
		fog_mesh.position.y = 0.02  # Above border
		fog_mesh.visible = false
		var fog_material := StandardMaterial3D.new()
		fog_material.albedo_color = Color(0, 0, 0, FOG_OPACITY)
		fog_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fog_mesh.set_surface_override_material(0, fog_material)


## Create a procedural hexagonal mesh for a pointy-top hex.
## Returns an ArrayMesh with a flat hexagon on the Y=0 plane.
##
## @param size The hex size (distance from center to vertex)
## @return The generated hexagonal mesh
func _create_hexagonal_mesh(size: float) -> ArrayMesh:
	var surface_array := []
	surface_array.resize(Mesh.ARRAY_MAX)

	# Pointy-top hex vertices on Y=0 plane
	var width_half: float = sqrt(3.0) / 2.0 * size

	var vertices := PackedVector3Array([
		Vector3(0, 0, -size),                    # Top
		Vector3(width_half, 0, -size / 2.0),     # Top-right
		Vector3(width_half, 0, size / 2.0),      # Bottom-right
		Vector3(0, 0, size),                     # Bottom
		Vector3(-width_half, 0, size / 2.0),     # Bottom-left
		Vector3(-width_half, 0, -size / 2.0),    # Top-left
	])

	# Triangulate the hexagon (6 triangles from center)
	var center := Vector3.ZERO
	var indices := PackedInt32Array()
	for i in range(6):
		var next := (i + 1) % 6
		# Triangle: center -> vertex[i] -> vertex[next]
		indices.append(0)  # Center (we'll add it as first vertex)
		indices.append(i + 1)
		indices.append(next + 1)

	# Add center as first vertex
	var final_vertices := PackedVector3Array([center])
	final_vertices.append_array(vertices)

	# Generate normals (all pointing up for a flat hex)
	var normals := PackedVector3Array()
	for _i in range(final_vertices.size()):
		normals.append(Vector3.UP)

	# Generate UVs (simple planar mapping)
	var uvs := PackedVector2Array()
	for vertex in final_vertices:
		var uv := Vector2(
			(vertex.x / (width_half * 2.0)) + 0.5,
			(vertex.z / (size * 2.0)) + 0.5
		)
		uvs.append(uv)

	surface_array[Mesh.ARRAY_VERTEX] = final_vertices
	surface_array[Mesh.ARRAY_NORMAL] = normals
	surface_array[Mesh.ARRAY_TEX_UV] = uvs
	surface_array[Mesh.ARRAY_INDEX] = indices

	var array_mesh := ArrayMesh.new()
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_array)

	return array_mesh


## Update the visual appearance based on terrain type
func _update_visual() -> void:
	if not mesh_instance:
		return

	var color: Color = TERRAIN_COLORS.get(terrain_type, TERRAIN_COLORS[TerrainType.GRASS])
	var material := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	if material:
		material.albedo_color = color


## Get the world position center of this tile
func get_world_center() -> Vector3:
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

	# 3. Kill any active tweens (Story 1.5)
	if _tween and _tween.is_running():
		_tween.kill()
	_stop_fog_animation()

	# 4. Clear internal references
	hex_coord = null
	mesh_instance = null
	border_mesh = null
	fog_mesh = null

	# 5. Remove from groups
	if is_in_group("tiles"):
		remove_from_group("tiles")

	# 6. Queue self for deletion
	queue_free()

# =============================================================================
# TERRITORY STATE METHODS (Story 1.5)
# =============================================================================

## Setup territory visual components.
## Called in _ready() to ensure border and fog meshes are properly configured.
func _setup_territory_visuals() -> void:
	# Verify border mesh exists
	if not border_mesh:
		push_warning("[HexTile] BorderMesh not found in scene")
		return

	# Verify fog mesh exists
	if not fog_mesh:
		push_warning("[HexTile] FogMesh not found in scene")
		return

	# Border is initially transparent (no state)
	var border_material := border_mesh.get_surface_override_material(0) as StandardMaterial3D
	if border_material:
		border_material.albedo_color = Color.TRANSPARENT

	# Fog is initially hidden (neutral state until TerritoryManager assigns state)
	fog_mesh.visible = false

	# Note: Don't apply initial visual state here
	# TerritoryManager will explicitly call set_territory_state() to apply visuals
	# This prevents tiles from showing fog before territory states are assigned

## Set the territory state and animate the visual transition.
## Called by TerritoryManager when state changes.
##
## @param state The new TerritoryState value (from TerritoryManager enum)
func set_territory_state(state: int) -> void:
	if territory_state == state:
		return  # No change

	var old_state := territory_state
	territory_state = state

	# AR11: Debug logging for state transitions
	if is_instance_valid(GameLogger):
		GameLogger.debug("HexTile", "Territory state transition at %s: %s → %s" % [
			hex_coord.to_vector() if hex_coord else Vector2i.ZERO,
			_state_to_string(old_state),
			_state_to_string(state)
		])

	_animate_state_transition()

## Apply the initial visual state without animation.
## Called during setup to ensure visual matches initial territory_state.
func _apply_initial_visual_state() -> void:
	match territory_state:
		0:  # UNEXPLORED
			fog_mesh.visible = true
			var fog_mat := fog_mesh.get_surface_override_material(0) as StandardMaterial3D
			if fog_mat:
				fog_mat.albedo_color.a = FOG_OPACITY
			var border_mat := border_mesh.get_surface_override_material(0) as StandardMaterial3D
			if border_mat:
				border_mat.albedo_color.a = 0.0
		1:  # SCOUTED
			fog_mesh.visible = false
			var desaturated_color := _desaturate_color(_get_terrain_color(terrain_type), SCOUTED_SATURATION)
			var mesh_mat := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
			if mesh_mat:
				mesh_mat.albedo_color = desaturated_color
			var border_mat := border_mesh.get_surface_override_material(0) as StandardMaterial3D
			if border_mat:
				border_mat.albedo_color.a = 0.0
		2:  # CONTESTED
			fog_mesh.visible = false
			var mesh_mat := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
			if mesh_mat:
				mesh_mat.albedo_color = _get_terrain_color(terrain_type)
			var border_mat := border_mesh.get_surface_override_material(0) as StandardMaterial3D
			if border_mat:
				border_mat.albedo_color = COLOR_CONTESTED
		3:  # CLAIMED
			fog_mesh.visible = false
			var mesh_mat := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
			if mesh_mat:
				mesh_mat.albedo_color = _get_terrain_color(terrain_type)
			var border_mat := border_mesh.get_surface_override_material(0) as StandardMaterial3D
			if border_mat:
				border_mat.albedo_color = COLOR_CLAIMED
		4:  # NEGLECTED
			fog_mesh.visible = false
			var mesh_mat := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
			if mesh_mat:
				mesh_mat.albedo_color = _get_terrain_color(terrain_type)
			var border_mat := border_mesh.get_surface_override_material(0) as StandardMaterial3D
			if border_mat:
				border_mat.albedo_color = COLOR_NEGLECTED

## Animate the visual transition to the current territory state.
## Uses Tween for smooth color/opacity changes.
func _animate_state_transition() -> void:
	# Cancel any existing tween
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)  # Multiple properties animate simultaneously

	match territory_state:
		0:  # UNEXPLORED
			_apply_unexplored_state(_tween)
		1:  # SCOUTED
			_apply_scouted_state(_tween)
		2:  # CONTESTED
			_apply_contested_state(_tween)
		3:  # CLAIMED
			_apply_claimed_state(_tween)
		4:  # NEGLECTED
			_apply_neglected_state(_tween)

## Apply UNEXPLORED visual state: dark fog overlay, no border.
func _apply_unexplored_state(tween: Tween) -> void:
	# Dark fog overlay
	fog_mesh.visible = true
	var fog_mat := fog_mesh.get_surface_override_material(0) as StandardMaterial3D
	if fog_mat:
		tween.tween_property(fog_mat, "albedo_color:a", FOG_OPACITY, STATE_TRANSITION_DURATION)

	# No border
	var border_mat := border_mesh.get_surface_override_material(0) as StandardMaterial3D
	if border_mat:
		tween.tween_property(border_mat, "albedo_color:a", 0.0, STATE_TRANSITION_DURATION)

	# AC1: Start subtle fog animation (pulsing opacity)
	tween.tween_callback(_start_fog_animation).set_delay(STATE_TRANSITION_DURATION)

## Apply SCOUTED visual state: fade out fog, desaturate terrain, no border.
func _apply_scouted_state(tween: Tween) -> void:
	# Stop fog animation if running
	_stop_fog_animation()

	# Fade out fog
	var fog_mat := fog_mesh.get_surface_override_material(0) as StandardMaterial3D
	if fog_mat:
		tween.tween_property(fog_mat, "albedo_color:a", 0.0, STATE_TRANSITION_DURATION)
	tween.tween_callback(func(): fog_mesh.visible = false).set_delay(STATE_TRANSITION_DURATION)

	# Desaturate terrain
	var desaturated_color := _desaturate_color(_get_terrain_color(terrain_type), SCOUTED_SATURATION)
	var mesh_mat := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	if mesh_mat:
		tween.tween_property(mesh_mat, "albedo_color", desaturated_color, STATE_TRANSITION_DURATION)

	# No border
	var border_mat := border_mesh.get_surface_override_material(0) as StandardMaterial3D
	if border_mat:
		tween.tween_property(border_mat, "albedo_color:a", 0.0, STATE_TRANSITION_DURATION)

## Apply CONTESTED visual state: full saturation, red border.
func _apply_contested_state(tween: Tween) -> void:
	# Stop fog animation if running
	_stop_fog_animation()

	# Remove fog
	fog_mesh.visible = false

	# Full saturation terrain
	var full_color := _get_terrain_color(terrain_type)
	var mesh_mat := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	if mesh_mat:
		tween.tween_property(mesh_mat, "albedo_color", full_color, STATE_TRANSITION_DURATION)

	# Red border
	var border_mat := border_mesh.get_surface_override_material(0) as StandardMaterial3D
	if border_mat:
		tween.tween_property(border_mat, "albedo_color", COLOR_CONTESTED, STATE_TRANSITION_DURATION)

## Apply CLAIMED visual state: full saturation, player color border.
func _apply_claimed_state(tween: Tween) -> void:
	# Stop fog animation if running
	_stop_fog_animation()

	# Remove fog
	fog_mesh.visible = false

	# Full saturation terrain
	var full_color := _get_terrain_color(terrain_type)
	var mesh_mat := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	if mesh_mat:
		tween.tween_property(mesh_mat, "albedo_color", full_color, STATE_TRANSITION_DURATION)

	# Player color border
	var border_mat := border_mesh.get_surface_override_material(0) as StandardMaterial3D
	if border_mat:
		tween.tween_property(border_mat, "albedo_color", COLOR_CLAIMED, STATE_TRANSITION_DURATION)

## Apply NEGLECTED visual state: full saturation, gray border.
func _apply_neglected_state(tween: Tween) -> void:
	# Stop fog animation if running
	_stop_fog_animation()

	# Terrain stays full saturation
	var full_color := _get_terrain_color(terrain_type)
	var mesh_mat := mesh_instance.get_surface_override_material(0) as StandardMaterial3D
	if mesh_mat:
		tween.tween_property(mesh_mat, "albedo_color", full_color, STATE_TRANSITION_DURATION)

	# Border fades to gray
	var border_mat := border_mesh.get_surface_override_material(0) as StandardMaterial3D
	if border_mat:
		tween.tween_property(border_mat, "albedo_color", COLOR_NEGLECTED, STATE_TRANSITION_DURATION)

## Desaturate a color by reducing saturation in HSV space.
##
## @param color The color to desaturate
## @param saturation The target saturation factor (0.0-1.0)
## @return The desaturated color
func _desaturate_color(color: Color, saturation: float) -> Color:
	# Godot 4 Color has h, s, v properties directly
	var h := color.h
	var s := color.s * saturation
	var v := color.v
	return Color.from_hsv(h, s, v, color.a)

## Get the full-saturation color for a terrain type.
##
## @param terrain The terrain type
## @return The terrain color
func _get_terrain_color(terrain: TerrainType) -> Color:
	return TERRAIN_COLORS.get(terrain, TERRAIN_COLORS[TerrainType.GRASS])

## Start subtle fog animation loop (AC1: fog has subtle animation or opacity variation).
## Pulses fog opacity between 0.80 and 0.90 over 3 seconds.
func _start_fog_animation() -> void:
	if not fog_mesh or not fog_mesh.visible:
		return

	# Stop any existing fog animation
	_stop_fog_animation()

	var fog_mat := fog_mesh.get_surface_override_material(0) as StandardMaterial3D
	if not fog_mat:
		return

	# Create looping tween for subtle pulsing
	_fog_animation_tween = create_tween()
	_fog_animation_tween.set_loops()  # Loop indefinitely

	# Pulse from 0.85 → 0.80 → 0.90 → 0.85
	_fog_animation_tween.tween_property(fog_mat, "albedo_color:a", 0.80, 1.5)
	_fog_animation_tween.tween_property(fog_mat, "albedo_color:a", 0.90, 1.5)

## Stop fog animation loop.
func _stop_fog_animation() -> void:
	if _fog_animation_tween and _fog_animation_tween.is_running():
		_fog_animation_tween.kill()
		_fog_animation_tween = null

## Convert territory state int to string for logging.
##
## @param state The territory state value
## @return String representation of the state
func _state_to_string(state: int) -> String:
	match state:
		0:  # TerritoryManager.TerritoryState.UNEXPLORED
			return "UNEXPLORED"
		1:  # TerritoryManager.TerritoryState.SCOUTED
			return "SCOUTED"
		2:  # TerritoryManager.TerritoryState.CONTESTED
			return "CONTESTED"
		3:  # TerritoryManager.TerritoryState.CLAIMED
			return "CLAIMED"
		4:  # TerritoryManager.TerritoryState.NEGLECTED
			return "NEGLECTED"
		_:
			return "UNKNOWN(%d)" % state
