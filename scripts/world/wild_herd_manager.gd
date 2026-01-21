## WildHerdManager - Manages wild animal herds for contested territory.
## Handles herd spawning, data tracking, removal, and territory ownership integration.
## Wild herds are enemies that the player can fight to expand territory.
##
## Architecture: scripts/world/wild_herd_manager.gd
## Parent: Child of WorldManager (like TerritoryManager)
## Story: 5-2-spawn-wild-animal-herds
class_name WildHerdManager
extends Node

# =============================================================================
# INNER CLASSES
# =============================================================================

## WildHerd - Data class for wild animal herd information.
class WildHerd:
	## Unique identifier for this herd (e.g., "herd_001")
	var herd_id: String
	## Primary hex location of the herd
	var hex_coord: HexCoord
	## Animals in this herd
	var animals: Array[Animal] = []
	## Owner identifier ("wild" or "camp_X")
	var owner_id: String = "wild"
	## Biome type where herd spawned
	var biome: String = "plains"

	func _init(p_herd_id: String, p_hex: HexCoord, p_owner: String = "wild") -> void:
		herd_id = p_herd_id
		hex_coord = p_hex
		owner_id = p_owner

	## Get total strength of all animals in herd.
	## @return Combined strength of all animals
	func get_total_strength() -> int:
		var total := 0
		for animal in animals:
			if animal and animal.stats:
				total += animal.stats.strength
		return total

	## Get count of animals in herd.
	## @return Number of animals
	func get_animal_count() -> int:
		return animals.size()

	## Get array of animal types in herd.
	## @return Array of animal_id strings
	func get_animal_types() -> Array[String]:
		var types: Array[String] = []
		for animal in animals:
			if animal and animal.stats:
				types.append(animal.stats.animal_id)
		return types

# =============================================================================
# CONSTANTS
# =============================================================================

## Minimum distance from player start for herd spawning
const MIN_SPAWN_DISTANCE: int = 2

## Minimum distance between herds
const HERD_SPACING: int = 3

## Maximum active herds per biome (performance limit)
const MAX_HERDS_PER_BIOME: int = 30

## Plains biome animal types (from GDD)
const PLAINS_ANIMALS: Array[String] = ["rabbit"]  # Only rabbit available currently

## Herd size range
const MIN_HERD_SIZE: int = 2
const MAX_HERD_SIZE: int = 5

# =============================================================================
# PROPERTIES
# =============================================================================

## Dictionary of herds keyed by herd_id
var _herds: Dictionary = {}

## Dictionary for quick hex -> herd_id lookup
var _hex_to_herd: Dictionary = {}

## Counter for generating unique herd IDs
var _next_herd_id: int = 1

## Reference to WorldManager for tile and territory access
var _world_manager: WorldManager

## Track player start hex for distance calculations
var _player_start_hex: HexCoord

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	add_to_group("wild_herd_managers")
	# Connect to territory ownership changes for cleanup
	EventBus.territory_ownership_changed.connect(_on_territory_ownership_changed)
	# Connect to fog reveal for spawning herds in newly scouted territory (AC 4)
	EventBus.fog_revealed.connect(_on_fog_revealed)


## Cleanup signal connections when removed from tree.
## AR18: Safe disconnection pattern to prevent memory leaks.
func _exit_tree() -> void:
	if EventBus.territory_ownership_changed.is_connected(_on_territory_ownership_changed):
		EventBus.territory_ownership_changed.disconnect(_on_territory_ownership_changed)
	if EventBus.fog_revealed.is_connected(_on_fog_revealed):
		EventBus.fog_revealed.disconnect(_on_fog_revealed)


## Initialize the wild herd manager with WorldManager reference.
## Call this after WorldManager has generated tiles.
##
## @param world_manager The WorldManager instance
func initialize(world_manager: WorldManager) -> void:
	if world_manager == null:
		if is_instance_valid(GameLogger):
			GameLogger.error("WildHerdManager", "Cannot initialize with null WorldManager")
		else:
			push_error("[WildHerdManager] Cannot initialize with null WorldManager")
		return

	_world_manager = world_manager

	if is_instance_valid(GameLogger):
		GameLogger.info("WildHerdManager", "WildHerdManager initialized")

# =============================================================================
# HERD DATA RETRIEVAL (AC: 1, 2, 3)
# =============================================================================

## Get a herd by its unique identifier.
##
## @param herd_id The unique herd identifier
## @return WildHerd or null if not found
func get_herd(herd_id: String) -> WildHerd:
	return _herds.get(herd_id)


## Get a herd at a specific hex coordinate.
##
## @param hex The hex coordinate to query
## @return WildHerd or null if no herd at that hex
func get_herd_at(hex: HexCoord) -> WildHerd:
	if hex == null:
		return null
	var herd_id: String = _hex_to_herd.get(hex.to_vector(), "")
	if herd_id == "":
		return null
	return _herds.get(herd_id)


## Get total count of active wild herds.
##
## @return Number of herds
func get_herd_count() -> int:
	return _herds.size()


## Get total count of wild animals across all herds.
##
## @return Total animal count
func get_total_wild_animals() -> int:
	var total := 0
	for herd in _herds.values():
		total += herd.get_animal_count()
	return total


## Get all herds within a range of a center hex.
##
## @param center The center hex coordinate
## @param radius The search radius
## @return Array of WildHerd objects in range
func get_herds_in_range(center: HexCoord, radius: int) -> Array[WildHerd]:
	var result: Array[WildHerd] = []
	if center == null or radius < 0:
		return result

	for herd in _herds.values():
		if herd.hex_coord and center.distance_to(herd.hex_coord) <= radius:
			result.append(herd)

	return result


## Get all herd IDs.
##
## @return Array of herd ID strings
func get_all_herd_ids() -> Array[String]:
	var ids: Array[String] = []
	for herd_id in _herds.keys():
		ids.append(herd_id)
	return ids

# =============================================================================
# HERD SPAWNING (AC: 4, 5, 6, 7)
# =============================================================================

## Spawn a new wild herd at a hex location.
## Enforces MAX_HERDS_PER_BIOME limit for performance (AC 19).
##
## @param hex The hex coordinate to spawn at
## @param herd_size Number of animals (clamped to MIN/MAX)
## @param owner_id The owner ("wild" or "camp_X")
## @return The spawned WildHerd or null on failure
func spawn_herd(hex: HexCoord, herd_size: int, owner_id: String = "wild") -> WildHerd:
	if hex == null:
		if is_instance_valid(GameLogger):
			GameLogger.warn("WildHerdManager", "Cannot spawn herd at null hex")
		return null

	# Enforce MAX_HERDS_PER_BIOME limit (AC 19 - performance)
	if _herds.size() >= MAX_HERDS_PER_BIOME:
		if is_instance_valid(GameLogger):
			GameLogger.warn("WildHerdManager", "Cannot spawn herd: max herds reached (%d)" % MAX_HERDS_PER_BIOME)
		return null

	# Check if hex already has a herd
	if _hex_to_herd.has(hex.to_vector()):
		if is_instance_valid(GameLogger):
			GameLogger.warn("WildHerdManager", "Hex %s already has a herd" % hex.to_vector())
		return null

	# Clamp herd size
	herd_size = clampi(herd_size, MIN_HERD_SIZE, MAX_HERD_SIZE)

	# Generate unique herd ID
	var herd_id := "herd_%03d" % _next_herd_id
	_next_herd_id += 1

	# Create herd data
	var herd := WildHerd.new(herd_id, hex, owner_id)

	# Determine herd composition and create animals
	var composition := _calculate_herd_composition("plains", herd_size)
	var offsets := _calculate_visual_offsets(herd_size)

	for i in herd_size:
		var animal_type := composition[i] if i < composition.size() else "rabbit"
		var animal := _create_wild_animal(animal_type, hex, offsets[i] if i < offsets.size() else Vector3.ZERO)
		if animal:
			herd.animals.append(animal)

	# Store herd
	_herds[herd_id] = herd
	_hex_to_herd[hex.to_vector()] = herd_id

	# Set territory ownership
	if _world_manager and _world_manager._territory_manager:
		_world_manager._territory_manager.set_hex_owner(hex, owner_id)

	# Emit spawn signal
	EventBus.wild_herd_spawned.emit(herd_id, hex.to_vector(), herd.get_animal_count())

	if is_instance_valid(GameLogger):
		GameLogger.info("WildHerdManager", "Spawned herd %s at %s with %d animals" % [herd_id, hex.to_vector(), herd.get_animal_count()])

	return herd


## Spawn initial herds at game start.
## Places herds at strategic locations avoiding player start area.
##
## @param player_start_hex The player's starting hex
func spawn_initial_herds(player_start_hex: HexCoord) -> void:
	if player_start_hex == null:
		if is_instance_valid(GameLogger):
			GameLogger.warn("WildHerdManager", "Cannot spawn initial herds without player start hex")
		return

	_player_start_hex = player_start_hex

	# Calculate spawn locations
	var spawn_count := 10  # Start with 10 initial herds
	var locations := _calculate_spawn_locations(player_start_hex, spawn_count)

	for location in locations:
		var herd_size := _calculate_herd_size_for_distance(location, player_start_hex)
		spawn_herd(location, herd_size)

	if is_instance_valid(GameLogger):
		GameLogger.info("WildHerdManager", "Spawned %d initial wild herds" % locations.size())


## Calculate herd composition based on biome and size.
##
## @param biome The biome type (e.g., "plains")
## @param size Number of animals
## @return Array of animal type strings
func _calculate_herd_composition(biome: String, size: int) -> Array[String]:
	var composition: Array[String] = []

	# Get available animals for biome
	var available: Array[String] = PLAINS_ANIMALS.duplicate()
	if biome != "plains":
		# Future: add other biome animals
		available = PLAINS_ANIMALS.duplicate()

	# Mix of workers (~60%) and fighters (~40%) per GDD
	# With only rabbit available, all will be rabbits
	for i in size:
		# Randomly select from available types
		var type := available[randi() % available.size()]
		composition.append(type)

	return composition


## Calculate visual offsets for animals in a herd.
## Animals cluster around hex center with slight randomization.
##
## @param count Number of animals
## @return Array of Vector3 offsets
func _calculate_visual_offsets(count: int) -> Array[Vector3]:
	var offsets: Array[Vector3] = []
	var radius := 0.3  # Units from center

	for i in count:
		var angle := (TAU / count) * i + randf() * 0.2  # Slight randomization
		var offset := Vector3(
			cos(angle) * radius * randf_range(0.7, 1.0),
			0,  # Ground plane
			sin(angle) * radius * randf_range(0.7, 1.0)
		)
		offsets.append(offset)

	return offsets


## Calculate spawn locations avoiding player start area.
##
## @param player_hex The player's starting hex
## @param count Number of spawn locations needed
## @return Array of valid HexCoord spawn locations
func _calculate_spawn_locations(player_hex: HexCoord, count: int) -> Array[HexCoord]:
	var locations: Array[HexCoord] = []

	if not _world_manager:
		return locations

	# Get all tiles from WorldManager
	var all_tiles := _world_manager.get_all_tiles()
	var candidates: Array[HexCoord] = []

	# Find candidate hexes that meet distance requirements
	for tile in all_tiles:
		if not tile or not tile.hex_coord:
			continue

		var hex := tile.hex_coord
		var distance := hex.distance_to(player_hex)

		# Must be at least MIN_SPAWN_DISTANCE from player
		if distance >= MIN_SPAWN_DISTANCE:
			# Check terrain is walkable (not water or rock)
			if tile.terrain_type == HexTile.TerrainType.GRASS:
				candidates.append(hex)

	# Shuffle for randomness
	candidates.shuffle()

	# Select locations with spacing
	for candidate in candidates:
		if locations.size() >= count:
			break

		# Check spacing from other selected locations
		var valid := true
		for existing in locations:
			if candidate.distance_to(existing) < HERD_SPACING:
				valid = false
				break

		if valid:
			locations.append(candidate)

	return locations


## Calculate herd size based on distance from player (difficulty scaling).
##
## @param herd_hex The herd's location
## @param player_hex The player's location
## @return Appropriate herd size
func _calculate_herd_size_for_distance(herd_hex: HexCoord, player_hex: HexCoord) -> int:
	var distance := herd_hex.distance_to(player_hex)

	# Difficulty scaling by distance
	if distance <= 4:
		return randi_range(2, 3)  # Easy: small herds
	elif distance <= 6:
		return randi_range(3, 4)  # Medium
	elif distance <= 10:
		return randi_range(4, 5)  # Hard
	else:
		return 5  # Very Hard: full herds


## Calculate herd strength based on distance from player.
## NOTE: Currently unused in production - AC 7 (difficulty scaling) is satisfied
## through `_calculate_herd_size_for_distance()` since all animals have identical stats.
## This function is reserved for future use when multiple animal types with different
## stats are available, allowing more granular strength-based difficulty tuning.
##
## @param herd_hex The herd's location
## @param player_hex The player's location
## @return Target strength value
func _calculate_herd_strength(herd_hex: HexCoord, player_hex: HexCoord) -> int:
	var distance := herd_hex.distance_to(player_hex)

	if distance <= 3:
		return randi_range(4, 8)    # Easy
	elif distance <= 6:
		return randi_range(8, 14)   # Medium
	elif distance <= 10:
		return randi_range(14, 20)  # Hard
	else:
		return randi_range(18, 25)  # Very Hard

# =============================================================================
# HERD REMOVAL (AC: 10)
# =============================================================================

## Remove a herd and clean up its animals and territory.
##
## @param herd_id The unique herd identifier
func remove_herd(herd_id: String) -> void:
	var herd: WildHerd = _herds.get(herd_id)
	if not herd:
		if is_instance_valid(GameLogger):
			GameLogger.warn("WildHerdManager", "Cannot remove non-existent herd: %s" % herd_id)
		return

	var hex_vec := herd.hex_coord.to_vector() if herd.hex_coord else Vector2i.ZERO

	# Clean up animals
	for animal in herd.animals:
		if is_instance_valid(animal):
			animal.cleanup()
	herd.animals.clear()

	# Remove from lookups
	_herds.erase(herd_id)
	if herd.hex_coord:
		_hex_to_herd.erase(herd.hex_coord.to_vector())

	# Emit removal signal
	EventBus.wild_herd_removed.emit(herd_id, hex_vec)

	if is_instance_valid(GameLogger):
		GameLogger.info("WildHerdManager", "Removed herd %s at %s" % [herd_id, hex_vec])

# =============================================================================
# TERRITORY INTEGRATION (AC: 8, 9, 10)
# =============================================================================

## Handle territory ownership changes (e.g., player claiming wild hex).
##
## @param hex_coord The changed hex coordinate
## @param old_owner Previous owner
## @param new_owner New owner
func _on_territory_ownership_changed(hex_coord: Vector2i, old_owner: String, new_owner: String) -> void:
	# If player claims a wild hex, check if there's a herd to remove
	if new_owner == "player" and (old_owner == "wild" or old_owner.begins_with("camp_")):
		var herd_id: String = _hex_to_herd.get(hex_coord, "")
		if herd_id != "":
			# Herd defeated - remove it
			remove_herd(herd_id)
			if is_instance_valid(GameLogger):
				GameLogger.info("WildHerdManager", "Herd %s removed - territory claimed by player" % herd_id)


## Handle fog reveal - potentially spawn wild herds in newly scouted territory (AC 4).
## Spawns herds with a probability based on distance from player territory.
##
## @param hex_coord The revealed hex coordinate
func _on_fog_revealed(hex_coord: Vector2i) -> void:
	# Skip if already at max herds
	if _herds.size() >= MAX_HERDS_PER_BIOME:
		return

	# Skip if hex already has a herd or is player-owned
	if _hex_to_herd.has(hex_coord):
		return

	var hex := HexCoord.from_vector(hex_coord)

	# Check if hex is unowned (not player territory)
	if _world_manager and _world_manager._territory_manager:
		var owner := _world_manager._territory_manager.get_hex_owner(hex)
		if owner == "player":
			return

	# Check terrain is valid for spawning (GRASS only)
	if _world_manager:
		var tile := _world_manager.get_tile_at(hex)
		if not tile or tile.terrain_type != HexTile.TerrainType.GRASS:
			return

	# Calculate spawn probability based on distance from player start
	# Closer = less likely to spawn (give player space), farther = more likely
	var spawn_chance := 0.0
	if _player_start_hex:
		var distance := hex.distance_to(_player_start_hex)
		if distance < MIN_SPAWN_DISTANCE:
			return  # Too close to player start
		# 10% base chance + 5% per hex distance (max ~50% at distance 10+)
		spawn_chance = minf(0.1 + (distance - MIN_SPAWN_DISTANCE) * 0.05, 0.5)
	else:
		spawn_chance = 0.2  # Default 20% if no player start known

	# Random spawn check
	if randf() > spawn_chance:
		return

	# Spawn a herd at this location
	var herd_size := 2 if not _player_start_hex else _calculate_herd_size_for_distance(hex, _player_start_hex)
	var herd := spawn_herd(hex, herd_size)

	if herd:
		# Story 5-3: Emit contested territory discovered signal (AC12)
		EventBus.contested_territory_discovered.emit(hex_coord, herd.herd_id)

		if is_instance_valid(GameLogger):
			GameLogger.info("WildHerdManager", "Spawned wild herd at newly revealed hex %s, emitting contested_territory_discovered" % hex_coord)

# =============================================================================
# ANIMAL CREATION HELPERS
# =============================================================================

## Create a wild animal and add to scene.
## Note: Unlike player animals, wild animals are initialized immediately (not deferred)
## to ensure they're fully ready when added to herd data structures.
##
## @param animal_type The type of animal to create
## @param hex The hex location
## @param offset Visual offset from hex center
## @return Created Animal node or null
func _create_wild_animal(animal_type: String, hex: HexCoord, offset: Vector3) -> Animal:
	if not AnimalFactory.has_animal_type(animal_type):
		if is_instance_valid(GameLogger):
			GameLogger.warn("WildHerdManager", "Unknown animal type: %s, using rabbit" % animal_type)
		animal_type = "rabbit"

	# Load scene and stats directly (bypass AnimalFactory's deferred initialization)
	var scene_path := "res://scenes/entities/animals/%s.tscn" % animal_type
	var stats_path := "res://resources/animals/%s_stats.tres" % animal_type

	if not ResourceLoader.exists(scene_path):
		if is_instance_valid(GameLogger):
			GameLogger.error("WildHerdManager", "Animal scene not found: %s" % scene_path)
		return null

	var scene: PackedScene = load(scene_path)
	var animal: Animal = scene.instantiate()
	if not animal:
		if is_instance_valid(GameLogger):
			GameLogger.error("WildHerdManager", "Failed to instantiate animal: %s" % animal_type)
		return null

	# Add to scene tree first (required for initialization)
	if _world_manager:
		_world_manager.add_child(animal)
	else:
		add_child(animal)

	# Load and apply stats
	var stats: AnimalStats = null
	if ResourceLoader.exists(stats_path):
		stats = load(stats_path)

	# Initialize immediately (not deferred) so herd data is accurate
	if animal.has_method("initialize"):
		animal.initialize(hex, stats)

	# Mark as wild after initialization
	if animal.has_method("set_wild_indicator"):
		animal.set_wild_indicator(true)

	# Apply visual offset
	animal.position += offset

	return animal
