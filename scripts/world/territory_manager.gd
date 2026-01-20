## TerritoryManager - Manages territory state tracking and ownership.
## Controls visual state of territories: unexplored, scouted, contested, claimed, neglected.
## Also manages ownership identity (player, wild, camp_X) separate from visual state.
##
## Architecture: scripts/world/territory_manager.gd
## Parent: Singleton/autoload or child of WorldManager
## Story: 1-5-display-territory-states, 5-1-implement-territory-ownership-system
class_name TerritoryManager
extends Node

# =============================================================================
# ENUMS
# =============================================================================

## Territory states for hex tiles
enum TerritoryState {
	UNEXPLORED,  # Dark fog, no visibility
	SCOUTED,     # Terrain visible, dim colors
	CONTESTED,   # Enemy controlled, red border
	CLAIMED,     # Player controlled, player color border
	NEGLECTED    # Losing control, fading player color
}

# =============================================================================
# CONSTANTS
# =============================================================================

## Time threshold for territory to be considered neglected (5 minutes)
const NEGLECT_THRESHOLD: float = 300.0

## Interval for checking neglect status (10 seconds)
const NEGLECT_CHECK_INTERVAL: float = 10.0

# =============================================================================
# PROPERTIES
# =============================================================================

## Dictionary of territory states keyed by Vector2i
## Vector2i -> TerritoryState
var _territory_states: Dictionary = {}

## Dictionary of neglect timers keyed by Vector2i
## Vector2i -> float (time since last activity)
var _neglect_timers: Dictionary = {}

## Reference to WorldManager for tile access
var _world_manager: WorldManager

# =============================================================================
# OWNERSHIP PROPERTIES (Story 5-1)
# =============================================================================

## Dictionary of ownership keyed by Vector2i
## Vector2i -> String (owner_id: "", "player", "wild", "camp_X")
var _ownership: Dictionary = {}

## Dictionary of claim sources keyed by Vector2i
## Vector2i -> String ("building" | "combat")
var _claim_source: Dictionary = {}

## Cached count for O(1) access (player-owned hexes only)
## Note: Contested count cannot be cached because it depends on adjacency to player territory,
## which changes when ANY player hex is claimed/unclaimed. See get_contested_count() for details.
var _player_count: int = 0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	add_to_group("territory_managers")
	# Story 5-1: Connect to building events for auto-claim
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.building_removed.connect(_on_building_removed)


## Cleanup signal connections when removed from tree.
## AR18: Safe disconnection pattern to prevent memory leaks.
func _exit_tree() -> void:
	if EventBus.building_placed.is_connected(_on_building_placed):
		EventBus.building_placed.disconnect(_on_building_placed)
	if EventBus.building_removed.is_connected(_on_building_removed):
		EventBus.building_removed.disconnect(_on_building_removed)


## Initialize the territory manager with a reference to WorldManager.
## Call this after WorldManager has generated tiles.
##
## @param world_manager The WorldManager instance
func initialize(world_manager: WorldManager) -> void:
	if world_manager == null:
		push_error("[TerritoryManager] Cannot initialize with null WorldManager")
		return

	_world_manager = world_manager
	# Story 1.6: FogOfWar now handles starting territory initialization

# =============================================================================
# TERRITORY STATE MANAGEMENT
# =============================================================================

## Set the territory state for a hex coordinate.
## Updates the state, notifies the tile visually, and emits signals.
##
## @param hex The hex coordinate to update
## @param state The new territory state
func set_territory_state(hex: HexCoord, state: TerritoryState) -> void:
	if hex == null:
		if is_instance_valid(GameLogger):
			GameLogger.warn("TerritoryManager", "Cannot set state for null hex")
		else:
			push_warning("[TerritoryManager] Cannot set state for null hex")
		return

	var hex_vec := hex.to_vector()
	var previous_state: TerritoryState = _territory_states.get(hex_vec, TerritoryState.UNEXPLORED)

	if previous_state == state:
		return  # No change

	_territory_states[hex_vec] = state

	# Update visual
	var tile := _world_manager.get_tile_at(hex) if _world_manager else null
	if tile:
		tile.set_territory_state(state)

	# Emit signals
	_emit_state_change_signals(hex_vec, previous_state, state)

	if is_instance_valid(GameLogger):
		GameLogger.debug("TerritoryManager", "Hex %s state changed: %s → %s" % [hex_vec, _state_to_string(previous_state), _state_to_string(state)])

## Get the territory state for a hex coordinate.
##
## @param hex The hex coordinate to query
## @return The TerritoryState for that hex (UNEXPLORED if not found)
func get_territory_state(hex: HexCoord) -> TerritoryState:
	if hex == null:
		return TerritoryState.UNEXPLORED

	return _territory_states.get(hex.to_vector(), TerritoryState.UNEXPLORED)

## Claim a territory hex for the player.
##
## @param hex The hex coordinate to claim
func claim_territory(hex: HexCoord) -> void:
	set_territory_state(hex, TerritoryState.CLAIMED)

## Scout a territory hex (reveal from unexplored).
##
## @param hex The hex coordinate to scout
func scout_territory(hex: HexCoord) -> void:
	var current_state := get_territory_state(hex)
	if current_state == TerritoryState.UNEXPLORED:
		set_territory_state(hex, TerritoryState.SCOUTED)

## Mark a territory hex as contested (enemy controlled).
##
## @param hex The hex coordinate to contest
func contest_territory(hex: HexCoord) -> void:
	set_territory_state(hex, TerritoryState.CONTESTED)

## Get count of hexes in a specific territory state.
##
## @param state The state to count
## @return Number of hexes in that state
func get_state_count(state: TerritoryState) -> int:
	var count := 0
	for hex_state in _territory_states.values():
		if hex_state == state:
			count += 1
	return count

# =============================================================================
# SIGNAL MANAGEMENT
# =============================================================================

## Emit EventBus signals based on state changes.
##
## @param hex_vec The Vector2i coordinate of the changed hex
## @param old_state The previous territory state
## @param new_state The new territory state
func _emit_state_change_signals(hex_vec: Vector2i, old_state: TerritoryState, new_state: TerritoryState) -> void:
	# EventBus integration
	if new_state == TerritoryState.CLAIMED and old_state != TerritoryState.CLAIMED:
		EventBus.territory_claimed.emit(hex_vec)
	elif old_state == TerritoryState.CLAIMED and new_state != TerritoryState.CLAIMED:
		EventBus.territory_lost.emit(hex_vec)

# =============================================================================
# NEGLECT TRACKING
# =============================================================================

func _physics_process(delta: float) -> void:
	# Periodic neglect check (Story 5.10 will use this for reclamation)
	# For now, placeholder for future feature
	pass

# =============================================================================
# UTILITIES
# =============================================================================

## Convert TerritoryState enum to string for logging.
##
## @param state The TerritoryState to convert
## @return String representation of the state
func _state_to_string(state: TerritoryState) -> String:
	match state:
		TerritoryState.UNEXPLORED:
			return "UNEXPLORED"
		TerritoryState.SCOUTED:
			return "SCOUTED"
		TerritoryState.CONTESTED:
			return "CONTESTED"
		TerritoryState.CLAIMED:
			return "CLAIMED"
		TerritoryState.NEGLECTED:
			return "NEGLECTED"
		_:
			return "UNKNOWN"

# =============================================================================
# OWNERSHIP MANAGEMENT (Story 5-1)
# =============================================================================

## Set the owner of a hex coordinate.
## Updates ownership, syncs territory state, updates cached counts, and emits signal.
##
## @param hex The hex coordinate to update
## @param owner_id The owner ID ("" for unowned, "player", "wild", "camp_X")
## @param source Optional claim source ("building" or "combat")
func set_hex_owner(hex: HexCoord, owner_id: String, source: String = "building") -> void:
	if hex == null:
		if is_instance_valid(GameLogger):
			GameLogger.warn("TerritoryManager", "Cannot set owner for null hex")
		else:
			push_warning("[TerritoryManager] Cannot set owner for null hex")
		return

	var hex_vec := hex.to_vector()
	var old_owner := get_hex_owner(hex)

	# No change - skip processing
	if old_owner == owner_id:
		return

	# Update cached counts
	_decrement_count(old_owner)
	_increment_count(owner_id)

	# Store ownership
	if owner_id == "":
		_ownership.erase(hex_vec)
		_claim_source.erase(hex_vec)
	else:
		_ownership[hex_vec] = owner_id
		_claim_source[hex_vec] = source

	# Sync territory state with ownership
	_sync_territory_state_with_ownership(hex, owner_id)

	# Emit ownership change signal
	EventBus.territory_ownership_changed.emit(hex_vec, old_owner, owner_id)

	if is_instance_valid(GameLogger):
		GameLogger.debug("TerritoryManager", "Ownership changed at %s: '%s' → '%s' (source: %s)" % [hex_vec, old_owner, owner_id, source])


## Get the owner of a hex coordinate.
##
## @param hex The hex coordinate to query
## @return The owner_id ("" if unowned)
func get_hex_owner(hex: HexCoord) -> String:
	if hex == null:
		return ""
	return _ownership.get(hex.to_vector(), "")


## Check if a hex is owned by the player.
##
## @param hex The hex coordinate to check
## @return True if player owns the hex
func is_player_owned(hex: HexCoord) -> bool:
	return get_hex_owner(hex) == "player"


## Check if a hex is contested (enemy-owned with conflict potential).
## A hex is contested if it's owned by an enemy (wild, camp_X) and
## is adjacent to at least one player-owned hex.
##
## @param hex The hex coordinate to check
## @return True if the hex is contested
func is_contested(hex: HexCoord) -> bool:
	if hex == null:
		return false

	var owner := get_hex_owner(hex)
	# Not contested if unowned or player-owned
	if owner == "" or owner == "player":
		return false

	# Check if adjacent to any player-owned hex
	var neighbors := hex.get_neighbors()
	for neighbor in neighbors:
		if is_player_owned(neighbor):
			return true

	return false


## Get count of hexes claimed by the player.
##
## @return Number of player-owned hexes
func get_claimed_count() -> int:
	return _player_count


## Get count of contested hexes (enemy-owned adjacent to player territory).
## NOTE: This recalculates dynamically because contested status depends on adjacency
## to player territory, not just ownership. When player claims/unclaims a hex, the
## contested status of all neighboring enemy hexes changes. Caching would require
## complex invalidation logic. With typical map sizes (<500 enemy hexes), this
## O(n) iteration completes well under 1ms on modern devices.
##
## @return Number of contested hexes
func get_contested_count() -> int:
	var count := 0
	for hex_vec in _ownership.keys():
		var hex := HexCoord.from_vector(hex_vec)
		if is_contested(hex):
			count += 1
	return count


## Get count of unowned hexes (requires WorldManager for total count).
##
## @return Number of unowned hexes (0 if WorldManager not available)
func get_unowned_count() -> int:
	if not _world_manager:
		return 0
	# Total hexes minus owned hexes
	var total := _get_total_hex_count()
	return total - _ownership.size()


## Sync territory state with ownership for visual consistency.
##
## @param hex The hex to sync
## @param owner_id The current owner
func _sync_territory_state_with_ownership(hex: HexCoord, owner_id: String) -> void:
	if owner_id == "player":
		# Player ownership = CLAIMED visual state
		set_territory_state(hex, TerritoryState.CLAIMED)
	elif owner_id != "":
		# Enemy ownership = CONTESTED visual state
		set_territory_state(hex, TerritoryState.CONTESTED)
	else:
		# No owner - revert to SCOUTED (or leave as-is if UNEXPLORED)
		var current_state := get_territory_state(hex)
		if current_state == TerritoryState.CLAIMED or current_state == TerritoryState.CONTESTED:
			set_territory_state(hex, TerritoryState.SCOUTED)


## Decrement the player count if owner was player.
##
## @param owner_id The owner to check
func _decrement_count(owner_id: String) -> void:
	if owner_id == "player":
		_player_count = maxi(0, _player_count - 1)


## Increment the player count if new owner is player.
##
## @param owner_id The owner to check
func _increment_count(owner_id: String) -> void:
	if owner_id == "player":
		_player_count += 1


## Get total hex count from WorldManager.
##
## @return Total number of hexes in the world
func _get_total_hex_count() -> int:
	if not _world_manager:
		return 0
	# Use WorldManager's tile count or calculate from grid
	if _world_manager.has_method("get_tile_count"):
		return _world_manager.get_tile_count()
	# Fallback: estimate from default dimensions
	return GameConstants.DEFAULT_MAP_WIDTH * GameConstants.DEFAULT_MAP_HEIGHT


## Check if a hex was claimed through combat (vs building placement).
##
## @param hex The hex to check
## @return True if claimed via combat
func is_combat_claimed(hex: HexCoord) -> bool:
	if hex == null:
		return false
	return _claim_source.get(hex.to_vector(), "") == "combat"


# =============================================================================
# BUILDING INTEGRATION (Story 5-1)
# =============================================================================

## Handle building placement - auto-claim unowned territory.
##
## @param building The placed building node
## @param hex_coord The hex coordinate where building was placed
func _on_building_placed(building: Node, hex_coord: Vector2i) -> void:
	var hex := HexCoord.from_vector(hex_coord)
	var current_owner := get_hex_owner(hex)

	# Only claim if unowned
	if current_owner == "":
		set_hex_owner(hex, "player", "building")
		if is_instance_valid(GameLogger):
			GameLogger.info("TerritoryManager", "Auto-claimed hex %s for player (building placed)" % hex_coord)


## Handle building removal - revert to unowned if no other buildings and not combat-claimed.
##
## @param building The removed building node
## @param hex_coord The hex coordinate where building was removed
func _on_building_removed(building: Node, hex_coord: Vector2i) -> void:
	var hex := HexCoord.from_vector(hex_coord)

	# Don't revert combat-claimed hexes
	if is_combat_claimed(hex):
		if is_instance_valid(GameLogger):
			GameLogger.debug("TerritoryManager", "Hex %s is combat-claimed, keeping ownership" % hex_coord)
		return

	# Check if hex still has buildings
	if _has_buildings_at(hex):
		return

	# Revert to unowned
	var current_owner := get_hex_owner(hex)
	if current_owner == "player":
		set_hex_owner(hex, "", "")
		if is_instance_valid(GameLogger):
			GameLogger.info("TerritoryManager", "Reverted hex %s to unowned (last building removed)" % hex_coord)


## Check if a hex has any buildings on it.
##
## @param hex The hex to check
## @return True if hex has at least one building
func _has_buildings_at(hex: HexCoord) -> bool:
	if hex == null or not _world_manager:
		return false

	# Get tile at hex and check for buildings
	var tile := _world_manager.get_tile_at(hex)
	if not tile:
		return false

	# Check if tile has buildings using groups or direct check
	var buildings := get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if building.has_method("get_hex_coord"):
			var building_hex: HexCoord = building.get_hex_coord()
			if building_hex and building_hex.equals(hex):
				return true
		elif building.has_meta("hex_coord"):
			var building_hex_vec: Vector2i = building.get_meta("hex_coord")
			if building_hex_vec == hex.to_vector():
				return true

	return false


# =============================================================================
# ADJACENT TERRITORY API (Story 5-1)
# =============================================================================

## Get all contested hexes adjacent to a specific player-claimed hex.
##
## @param hex The player-claimed hex to check from
## @return Array of contested HexCoords adjacent to the given hex
func get_adjacent_contested(hex: HexCoord) -> Array[HexCoord]:
	var result: Array[HexCoord] = []
	if hex == null:
		return result

	var neighbors := hex.get_neighbors()
	for neighbor in neighbors:
		if is_contested(neighbor):
			result.append(neighbor)

	return result


## Get all unowned hexes adjacent to a specific hex (claimable neighbors).
##
## @param hex The hex to check from
## @return Array of unowned HexCoords adjacent to the given hex
func get_claimable_neighbors(hex: HexCoord) -> Array[HexCoord]:
	var result: Array[HexCoord] = []
	if hex == null:
		return result

	var neighbors := hex.get_neighbors()
	for neighbor in neighbors:
		if get_hex_owner(neighbor) == "":
			# Only include if neighbor is valid in world bounds
			if _is_valid_hex(neighbor):
				result.append(neighbor)

	return result


## Get all hexes on the border of player territory (expansion frontier).
## These are unowned hexes that are adjacent to at least one player-claimed hex.
##
## @return Array of unowned HexCoords on the player's territory border
func get_all_border_hexes() -> Array[HexCoord]:
	var result: Array[HexCoord] = []
	var added: Dictionary = {}  # Track already-added hexes to avoid duplicates

	# For each player-owned hex, get its claimable neighbors
	for hex_vec in _ownership.keys():
		if _ownership[hex_vec] == "player":
			var hex := HexCoord.from_vector(hex_vec)
			var claimable := get_claimable_neighbors(hex)
			for neighbor in claimable:
				var neighbor_vec := neighbor.to_vector()
				if not added.has(neighbor_vec):
					added[neighbor_vec] = true
					result.append(neighbor)

	return result


## Check if a hex is valid (within world bounds).
##
## @param hex The hex to check
## @return True if hex is within valid world bounds
func _is_valid_hex(hex: HexCoord) -> bool:
	if not _world_manager:
		# Without WorldManager, assume all hexes are valid
		return true

	# Check if tile exists at this coordinate
	var tile := _world_manager.get_tile_at(hex)
	return tile != null
