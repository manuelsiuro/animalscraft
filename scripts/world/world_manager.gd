## WorldManager - Manages the game world including hex grid spawning and tile access.
## Handles creation and organization of the hex tile grid.
##
## Architecture: scripts/world/world_manager.gd
## Parent: scenes/game.tscn > World node
## Story: 1-2-render-hex-tiles (Updated for 3D in Story 1-0 rework)
class_name WorldManager
extends Node3D

# =============================================================================
# CONSTANTS
# =============================================================================

## Path to the HexTile scene
const HEX_TILE_SCENE := preload("res://scenes/world/hex_tile.tscn")

## Starting area range (range 3 = 7 diameter hex area, approximately 37 tiles)
const STARTING_RANGE := 3

# =============================================================================
# PROPERTIES
# =============================================================================

## Dictionary of tiles keyed by Vector2i (from HexCoord.to_vector())
## Provides O(1) lookup for tiles by coordinate
var _tiles: Dictionary = {}

## Track if world has been generated
var _world_generated := false

## Territory manager for tracking ownership (Story 1.5)
var _territory_manager: TerritoryManager

## Fog of war manager (Story 1.6)
var _fog_of_war: FogOfWar

## Pathfinding manager (Story 2.6 - for animal movement)
var _pathfinding: PathfindingManager

## Wild herd manager (Story 5.2 - for wild animal herds)
var _wild_herd_manager: WildHerdManager

## Combat manager (Story 5.5 - for auto-battle system)
var _combat_manager: CombatManager

## Shelter seeking system (Story 5-11 - for tired animals to find shelters)
var _shelter_seeking_system: ShelterSeekingSystem

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when world generation is complete
signal world_generated(tile_count: int)

## Emitted when a tile is added to the world
signal tile_added(tile: HexTile)

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Add to group for debug access (Story 1.6)
	add_to_group("world_managers")

	# Create and add territory manager (Story 1.5)
	_territory_manager = TerritoryManager.new()
	_territory_manager.name = "TerritoryManager"
	add_child(_territory_manager)

	# Create and add fog of war manager (Story 1.6)
	_fog_of_war = FogOfWar.new()
	_fog_of_war.name = "FogOfWar"
	add_child(_fog_of_war)

	# Generate starting area on ready
	generate_starting_area()

	# Initialize territory manager after world generation (Story 1.5)
	# Note: Skip _initialize_starting_territory() - FogOfWar will handle it
	_territory_manager.initialize(self)

	# Initialize fog of war (Story 1.6)
	# FogOfWar will set up the correct starting fog state
	_fog_of_war.initialize(self, _territory_manager)

	# Create and initialize pathfinding manager (Story 2.6)
	_pathfinding = PathfindingManager.new()
	_pathfinding.name = "PathfindingManager"
	add_child(_pathfinding)
	_pathfinding.initialize(self)

	# Create and initialize wild herd manager (Story 5.2)
	_wild_herd_manager = WildHerdManager.new()
	_wild_herd_manager.name = "WildHerdManager"
	add_child(_wild_herd_manager)
	_wild_herd_manager.initialize(self)
	# Note: spawn_initial_herds() will be called later when player start is determined

	# Create and initialize combat manager (Story 5.5)
	_combat_manager = CombatManager.new()
	_combat_manager.name = "CombatManager"
	add_child(_combat_manager)
	_combat_manager.initialize(self)

	# Create shelter seeking system (Story 5-11)
	_shelter_seeking_system = ShelterSeekingSystem.new()
	_shelter_seeking_system.name = "ShelterSeekingSystem"
	add_child(_shelter_seeking_system)
	# Note: ShelterSeekingSystem self-initializes in _ready() via EventBus connections

	# Connect to new_game_started to spawn initial animals
	if is_instance_valid(EventBus):
		EventBus.new_game_started.connect(_on_new_game_started)


## Cleanup signal connections when removed from tree.
func _exit_tree() -> void:
	if is_instance_valid(EventBus) and EventBus.new_game_started.is_connected(_on_new_game_started):
		EventBus.new_game_started.disconnect(_on_new_game_started)


# =============================================================================
# WORLD GENERATION
# =============================================================================

## Generate the starting hex area centered at origin.
## Creates a circular area of hexes based on STARTING_RANGE.
func generate_starting_area() -> void:
	if _world_generated:
		push_warning("[WorldManager] World already generated, skipping")
		return

	# Get all hexes in starting range
	var center := HexCoord.new(0, 0)
	var hexes := HexGrid.get_hexes_in_range(center, STARTING_RANGE)

	# Log generation start (AR11: Use Logger autoload)
	if is_instance_valid(GameLogger):
		GameLogger.info("WorldManager", "Generating starting area with %d hexes" % hexes.size())
	else:
		print("[WorldManager] Generating starting area with %d hexes" % hexes.size())

	# Spawn tiles for each hex
	for hex in hexes:
		var tile := _spawn_tile(hex)
		_tiles[hex.to_vector()] = tile
		tile_added.emit(tile)

	_world_generated = true

	# Log completion (AR11: Use Logger autoload)
	if is_instance_valid(GameLogger):
		GameLogger.info("WorldManager", "World generation complete: %d tiles spawned" % _tiles.size())
	else:
		print("[WorldManager] World generation complete: %d tiles spawned" % _tiles.size())

	world_generated.emit(_tiles.size())


## Spawn a single hex tile at the given coordinate.
##
## @param hex The hex coordinate for the tile
## @return The spawned HexTile instance
func _spawn_tile(hex: HexCoord) -> HexTile:
	var tile: HexTile = HEX_TILE_SCENE.instantiate()
	var terrain := _get_terrain_for_hex(hex)
	add_child(tile)
	tile.initialize(hex, terrain)
	return tile


## Determine the terrain type for a hex coordinate.
## Uses a simple placeholder algorithm for initial implementation.
## TODO: Replace with BiomeConfig resource (AR12: Configuration pattern)
##
## @param hex The hex coordinate to get terrain for
## @return The TerrainType for this hex
func _get_terrain_for_hex(hex: HexCoord) -> HexTile.TerrainType:
	# Simple terrain generation for placeholders:
	# - Center area (distance 0-1) = always grass
	# - Outer areas = mostly grass with some water and rock
	# NOTE: Magic numbers (0.7, 0.85) should be in BiomeConfig.tres (future story)
	var center := HexCoord.new(0, 0)
	var dist := hex.distance_to(center)

	# Center is always grass
	if dist <= 1:
		return HexTile.TerrainType.GRASS

	# Outer areas have variety
	# Use deterministic noise based on coordinates for consistency
	var noise_val := _pseudo_random(hex.q, hex.r)

	# Terrain distribution: 70% grass, 15% water, 15% rock
	if noise_val < 0.7:
		return HexTile.TerrainType.GRASS
	elif noise_val < 0.85:
		return HexTile.TerrainType.WATER
	else:
		return HexTile.TerrainType.ROCK


## Generate a pseudo-random value based on coordinates.
## Deterministic: same coordinates always produce same value.
##
## @param q The q coordinate
## @param r The r coordinate
## @return A value between 0.0 and 1.0
func _pseudo_random(q: int, r: int) -> float:
	# Simple hash-based pseudo-random
	var hash_val := (q * 12345 + r * 67890) % 1000
	return float(abs(hash_val)) / 1000.0


# =============================================================================
# TILE ACCESS
# =============================================================================

## Get a tile at the given hex coordinate.
##
## @param hex The hex coordinate to look up
## @return The HexTile at that coordinate, or null if not found
func get_tile_at(hex: HexCoord) -> HexTile:
	# AR18: Null safety with warning
	if hex == null:
		push_warning("[WorldManager] get_tile_at() called with null hex coordinate")
		return null
	return _tiles.get(hex.to_vector())


## Get a tile at the given vector coordinate.
##
## @param vec The Vector2i coordinate to look up
## @return The HexTile at that coordinate, or null if not found
func get_tile_at_vector(vec: Vector2i) -> HexTile:
	return _tiles.get(vec)


## Get all tiles in the world.
##
## @return Array of all HexTile instances
func get_all_tiles() -> Array[HexTile]:
	var result: Array[HexTile] = []
	for tile in _tiles.values():
		result.append(tile)
	return result


## Get the total number of tiles in the world.
##
## @return The tile count
func get_tile_count() -> int:
	return _tiles.size()


## Check if a hex coordinate has a tile.
##
## @param hex The hex coordinate to check
## @return True if a tile exists at that coordinate
func has_tile_at(hex: HexCoord) -> bool:
	if hex == null:
		return false
	return _tiles.has(hex.to_vector())


## Check if the world has been generated.
##
## @return True if world generation is complete
func is_world_generated() -> bool:
	return _world_generated


## Get the territory manager (Story 1.5).
##
## @return The TerritoryManager instance
func get_territory_manager() -> TerritoryManager:
	return _territory_manager


## Get the pathfinding manager (Story 2.6).
##
## @return The PathfindingManager instance
func get_pathfinding_manager() -> PathfindingManager:
	return _pathfinding


## Get the wild herd manager (Story 5.2).
##
## @return The WildHerdManager instance
func get_wild_herd_manager() -> WildHerdManager:
	return _wild_herd_manager


## Get the combat manager (Story 5.5).
##
## @return The CombatManager instance
func get_combat_manager() -> CombatManager:
	return _combat_manager


## Get the shelter seeking system (Story 5-11).
##
## @return The ShelterSeekingSystem instance
func get_shelter_seeking_system() -> ShelterSeekingSystem:
	return _shelter_seeking_system


## Handle new game started signal - spawn initial animals and buildings.
## Creates STARTING_ANIMALS (2) animals at the center hex.
func _on_new_game_started() -> void:
	if is_instance_valid(GameLogger):
		GameLogger.info("WorldManager", "New game started - spawning initial entities")

	# Spawn initial stockpile building FIRST (so animals can check for occupied hexes)
	_spawn_initial_stockpile()

	# Spawn initial player animals (will avoid occupied hexes)
	_spawn_initial_animals()


## Spawn the initial player animals at the start of a new game.
## Uses STARTING_ANIMALS constant from GameConstants (default: 2).
## Spreads animals across adjacent hexes to avoid overlapping and buildings.
func _spawn_initial_animals() -> void:
	var center_hex := get_player_spawn_hex()
	var animal_count: int = GameConstants.STARTING_ANIMALS if is_instance_valid(GameConstants) else 2

	# Get available animal types and pick random ones for variety
	var available_types := AnimalFactory.get_available_types()
	if available_types.is_empty():
		push_error("[WorldManager] No animal types available in AnimalFactory")
		return

	# Get valid spawn hexes (grass tiles, not occupied by buildings)
	var spawn_hexes: Array[HexCoord] = []

	# Check center hex first
	if not HexGrid.is_hex_occupied(center_hex.to_vector()):
		spawn_hexes.append(center_hex)

	# Then check neighbors
	var neighbors := center_hex.get_neighbors()
	for neighbor in neighbors:
		var tile := get_tile_at(neighbor)
		# Only use grass tiles that are not occupied by buildings
		if tile and tile.terrain_type == HexTile.TerrainType.GRASS:
			if not HexGrid.is_hex_occupied(neighbor.to_vector()):
				spawn_hexes.append(neighbor)
				if spawn_hexes.size() >= animal_count:
					break

	for i in range(animal_count):
		# Pick a random animal type for variety (rabbits and squirrels are common starters)
		var animal_type: String
		if i == 0:
			animal_type = "rabbit" if "rabbit" in available_types else available_types[0]
		else:
			animal_type = "squirrel" if "squirrel" in available_types else available_types[randi() % available_types.size()]

		# Use different hex for each animal - MUST NOT be occupied by a building
		var spawn_hex: HexCoord = null
		if i < spawn_hexes.size():
			spawn_hex = spawn_hexes[i]
		else:
			# Fallback: find any valid unoccupied grass hex
			for hex in spawn_hexes:
				if not HexGrid.is_hex_occupied(hex.to_vector()):
					spawn_hex = hex
					break
			if not spawn_hex:
				spawn_hex = center_hex

		# Final safety check - NEVER spawn on occupied hex
		if HexGrid.is_hex_occupied(spawn_hex.to_vector()):
			GameLogger.warn("WorldManager", "Spawn hex %s is occupied, finding alternative" % spawn_hex)
			# Find alternative from neighbors
			for neighbor in spawn_hex.get_neighbors():
				var tile := get_tile_at(neighbor)
				if tile and tile.terrain_type == HexTile.TerrainType.GRASS:
					if not HexGrid.is_hex_occupied(neighbor.to_vector()):
						spawn_hex = neighbor
						break

		var animal := AnimalFactory.create_animal(animal_type, spawn_hex)
		if animal:
			# Add animal to the world
			add_child(animal)
			if is_instance_valid(GameLogger):
				GameLogger.info("WorldManager", "Spawned starting animal: %s at %s" % [animal_type, spawn_hex])
		else:
			push_warning("[WorldManager] Failed to create starting animal: %s" % animal_type)


## Spawn the initial stockpile building at game start.
## Places a stockpile at (1, 0) adjacent to the home hex.
func _spawn_initial_stockpile() -> void:
	var stockpile_hex := HexCoord.new(1, 0)

	# Check if BuildingFactory exists and has stockpile
	if not BuildingFactory.has_building_type("stockpile"):
		if is_instance_valid(GameLogger):
			GameLogger.warn("WorldManager", "Stockpile building type not available")
		return

	# Create building first (BuildingFactory checks if hex is free)
	var building := BuildingFactory.create_building("stockpile", stockpile_hex)
	if building:
		add_child(building)
		# Manually mark hex as occupied NOW (don't wait for deferred initialize)
		# This ensures animals spawned after won't use this hex
		HexGrid.mark_hex_occupied(stockpile_hex.to_vector(), building)
		if is_instance_valid(GameLogger):
			GameLogger.info("WorldManager", "Spawned starting stockpile at %s" % stockpile_hex)
	else:
		push_warning("[WorldManager] Failed to create starting stockpile")


## Get the player's spawn hex for recruited animals (Story 5-8).
## Returns home hex (0,0) or fallback (1,0) if home hex is blocked.
## Simplified implementation - no search algorithm needed per story requirements.
##
## @return HexCoord for spawning player animals
func get_player_spawn_hex() -> HexCoord:
	# Home hex (0,0) is the player's starting location
	var home_hex := HexCoord.new(0, 0)
	var home_tile := get_tile_at(home_hex)

	# Check if home hex exists and is valid for spawning
	if home_tile and home_tile.terrain_type == HexTile.TerrainType.GRASS:
		return home_hex

	# Fallback to (1,0) if home is blocked
	if is_instance_valid(GameLogger):
		GameLogger.warn("WorldManager", "Home hex (0,0) blocked, using fallback (1,0)")
	return HexCoord.new(1, 0)


# =============================================================================
# COORDINATE UTILITIES
# =============================================================================

## Convert a world position to the nearest tile.
##
## @param world_pos The world position to convert (Vector3 in 3D space)
## @return The HexTile at that position, or null if no tile exists
func get_tile_at_world_pos(world_pos: Vector3) -> HexTile:
	var hex := HexGrid.world_to_hex(world_pos)
	return get_tile_at(hex)


## Generate a large test area for performance testing.
## Use this to verify 60 FPS with 200+ hexes.
##
## @param range_val The range to generate (range 7 = ~127 tiles, range 8 = ~169 tiles)
func generate_test_area(range_val: int) -> void:
	# Clear existing tiles
	for tile in _tiles.values():
		tile.queue_free()
	_tiles.clear()
	_world_generated = false

	# Generate new area
	var center := HexCoord.new(0, 0)
	var hexes := HexGrid.get_hexes_in_range(center, range_val)

	if is_instance_valid(GameLogger):
		GameLogger.info("WorldManager", "Performance test: generating %d hexes (range %d)" % [hexes.size(), range_val])

	for hex in hexes:
		var tile := _spawn_tile(hex)
		_tiles[hex.to_vector()] = tile

	_world_generated = true

	if is_instance_valid(GameLogger):
		GameLogger.info("WorldManager", "Performance test complete: %d tiles spawned" % _tiles.size())


## Get the world bounds of the current tile area.
## Useful for setting camera limits.
##
## @return AABB containing all tiles, or reasonable default if no tiles exist
func get_world_bounds() -> AABB:
	# AR18: Handle empty tiles gracefully
	if _tiles.is_empty():
		push_warning("[WorldManager] No tiles exist, returning default bounds")
		# Return reasonable default bounds (1000x2000 on XZ plane, Y=0 ground level)
		return AABB(Vector3(-500, 0, -1000), Vector3(1000, 1, 2000))

	var min_pos := Vector3.INF
	var max_pos := -Vector3.INF

	for vec in _tiles.keys():
		var hex := HexCoord.from_vector(vec)
		var bounds := HexGrid.get_hex_bounds(hex)

		min_pos.x = minf(min_pos.x, bounds.position.x)
		min_pos.y = minf(min_pos.y, bounds.position.y)
		min_pos.z = minf(min_pos.z, bounds.position.z)
		max_pos.x = maxf(max_pos.x, bounds.end.x)
		max_pos.y = maxf(max_pos.y, bounds.end.y)
		max_pos.z = maxf(max_pos.z, bounds.end.z)

	return AABB(min_pos, max_pos - min_pos)
