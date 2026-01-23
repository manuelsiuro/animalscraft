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

## Time for wild to reclaim a neglected hex adjacent to wild territory (1 minute)
const RECLAMATION_TIME: float = 60.0

## Radius for activity detection (1 = adjacent hexes reset timer)
const ACTIVITY_DETECTION_RADIUS: int = 1

## Maximum hexes to process per frame for performance (Story 5-10 AC18)
const MAX_HEXES_PER_FRAME: int = 15

# =============================================================================
# PROPERTIES
# =============================================================================

## Dictionary of territory states keyed by Vector2i
## Vector2i -> TerritoryState
var _territory_states: Dictionary = {}

## Dictionary of neglect timers keyed by Vector2i
## Vector2i -> float (time since last activity)
var _neglect_timers: Dictionary = {}

## Dictionary of reclamation timers keyed by Vector2i
## Vector2i -> float (time towards reclamation)
var _reclamation_timers: Dictionary = {}

## Reference to WorldManager for tile access
var _world_manager: WorldManager

## Timer for staggered neglect checking (Story 5-10 performance)
var _check_timer: float = 0.0

## List of player-owned hexes for staggered processing
var _player_hex_list: Array[Vector2i] = []

## Index for staggered processing
var _next_check_index: int = 0

## Track hexes that have started reclamation (for signal emission)
var _reclamation_started: Dictionary = {}

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
	# Story 5-10: Neglect and reclamation processing
	_check_timer += delta

	# Calculate interval based on number of batches needed
	var batch_count := _get_batch_count()
	var batch_interval := NEGLECT_CHECK_INTERVAL / maxf(float(batch_count), 1.0)

	if _check_timer < batch_interval:
		return

	_check_timer = 0.0
	_process_neglect_batch(delta * float(batch_count))  # Scale delta for accumulated time


## Get number of batches needed to process all player hexes.
## @return Number of batches (minimum 1)
func _get_batch_count() -> int:
	var hex_count := _player_hex_list.size()
	if hex_count <= MAX_HEXES_PER_FRAME:
		return 1
	return ceili(float(hex_count) / float(MAX_HEXES_PER_FRAME))


## Process a batch of player hexes for neglect checking.
## @param accumulated_delta Time since last check for this batch
func _process_neglect_batch(accumulated_delta: float) -> void:
	# Rebuild hex list periodically (at start of cycle)
	if _next_check_index == 0:
		_rebuild_player_hex_list()

	var count := 0
	while count < MAX_HEXES_PER_FRAME and _next_check_index < _player_hex_list.size():
		var hex_vec := _player_hex_list[_next_check_index]
		_update_single_hex_neglect(hex_vec, accumulated_delta)
		_next_check_index += 1
		count += 1

	# Reset index when cycle completes
	if _next_check_index >= _player_hex_list.size():
		_next_check_index = 0


## Rebuild the list of player-owned hexes for processing.
func _rebuild_player_hex_list() -> void:
	_player_hex_list.clear()
	for hex_vec in _ownership.keys():
		if _ownership.get(hex_vec, "") == "player":
			_player_hex_list.append(hex_vec)


## Update neglect and reclamation state for a single hex.
## @param hex_vec The hex coordinate as Vector2i
## @param delta Time since last update
func _update_single_hex_neglect(hex_vec: Vector2i, delta: float) -> void:
	var hex := HexCoord.from_vector(hex_vec)

	# Check for activity near this hex
	if _check_activity_near_hex(hex):
		# Activity detected - reset timers
		if _neglect_timers.has(hex_vec):
			_neglect_timers.erase(hex_vec)
			_reclamation_timers.erase(hex_vec)
			_reclamation_started.erase(hex_vec)

			# If hex was NEGLECTED, revert to CLAIMED
			var current_state := get_territory_state(hex)
			if current_state == TerritoryState.NEGLECTED:
				set_territory_state(hex, TerritoryState.CLAIMED)
				if is_instance_valid(GameLogger):
					GameLogger.debug("TerritoryManager", "Hex %s reverted from NEGLECTED to CLAIMED (activity detected)" % hex_vec)

			# Emit activity detected signal (deferred for proper ordering)
			call_deferred("_emit_activity_detected", hex_vec)
		return

	# No activity - increment neglect timer
	var current_neglect: float = _neglect_timers.get(hex_vec, 0.0)
	current_neglect += delta
	_neglect_timers[hex_vec] = current_neglect

	# Check if hex should become neglected
	var current_state := get_territory_state(hex)
	if current_neglect >= NEGLECT_THRESHOLD and current_state != TerritoryState.NEGLECTED:
		set_territory_state(hex, TerritoryState.NEGLECTED)
		call_deferred("_emit_territory_neglected", hex_vec)
		if is_instance_valid(GameLogger):
			GameLogger.info("TerritoryManager", "Hex %s became NEGLECTED (no activity for %.0fs)" % [hex_vec, current_neglect])

	# Process reclamation for neglected hexes adjacent to wild
	if current_state == TerritoryState.NEGLECTED or current_neglect >= NEGLECT_THRESHOLD:
		_update_reclamation_timer(hex, hex_vec, delta)


## Emit territory_activity_detected signal (called deferred).
## @param hex_vec The hex coordinate
func _emit_activity_detected(hex_vec: Vector2i) -> void:
	EventBus.territory_activity_detected.emit(hex_vec)


## Emit territory_neglected signal (called deferred).
## @param hex_vec The hex coordinate
func _emit_territory_neglected(hex_vec: Vector2i) -> void:
	EventBus.territory_neglected.emit(hex_vec)


## Reset neglect timers for a hex and its neighbors (AC4).
## Called immediately when buildings are placed/removed.
##
## @param hex The central hex around which to reset timers
func _reset_neglect_timers_around(hex: HexCoord) -> void:
	if hex == null:
		return

	# Reset timer for this hex
	var hex_vec := hex.to_vector()
	_reset_single_hex_neglect(hex_vec)

	# Reset timers for all neighbors within ACTIVITY_DETECTION_RADIUS
	var neighbors := hex.get_neighbors()
	for neighbor in neighbors:
		_reset_single_hex_neglect(neighbor.to_vector())


## Reset neglect state for a single hex.
## Clears timers and reverts NEGLECTED state to CLAIMED if player-owned.
##
## @param hex_vec The hex coordinate as Vector2i
func _reset_single_hex_neglect(hex_vec: Vector2i) -> void:
	# Only process if hex has a neglect timer
	if not _neglect_timers.has(hex_vec):
		return

	# Clear timers
	_neglect_timers.erase(hex_vec)
	_reclamation_timers.erase(hex_vec)
	_reclamation_started.erase(hex_vec)

	# Revert NEGLECTED state to CLAIMED if still player-owned
	var hex := HexCoord.from_vector(hex_vec)
	if get_hex_owner(hex) == "player":
		var current_state := get_territory_state(hex)
		if current_state == TerritoryManager.TerritoryState.NEGLECTED:
			set_territory_state(hex, TerritoryManager.TerritoryState.CLAIMED)
			if is_instance_valid(GameLogger):
				GameLogger.debug("TerritoryManager", "Hex %s reverted from NEGLECTED to CLAIMED (building activity)" % hex_vec)

	# Emit activity detected signal
	call_deferred("_emit_activity_detected", hex_vec)

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

	# Story 5-3: Update expansion glow on adjacent tiles
	_update_expansion_glow_for_hex(hex)


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

## Handle building placement - auto-claim unowned territory and reset neglect timers (AC4).
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

	# AC4: Reset neglect timers for this hex and adjacent hexes immediately
	_reset_neglect_timers_around(hex)


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


# =============================================================================
# STORY 5-3: EXPANSION GLOW MANAGEMENT
# =============================================================================

## Update expansion glow for a hex and its neighbors when ownership changes (AC9).
## Player-owned hexes adjacent to contested hexes get a subtle glow.
##
## @param hex The hex that changed
func _update_expansion_glow_for_hex(hex: HexCoord) -> void:
	if not _world_manager:
		return

	# Update this hex and all its neighbors
	var hexes_to_update: Array[HexCoord] = [hex]
	hexes_to_update.append_array(hex.get_neighbors())

	for update_hex in hexes_to_update:
		var tile := _world_manager.get_tile_at(update_hex) as HexTile
		if not tile:
			continue

		# Check if tile should have expansion glow (AC9)
		var should_glow := _should_have_expansion_glow(update_hex)
		tile.set_expansion_glow(should_glow)


## Check if a hex should have expansion glow (AC9).
## A CLAIMED hex gets glow if it has any adjacent CONTESTED hexes.
##
## @param hex The hex to check
## @return True if hex should have expansion glow
func _should_have_expansion_glow(hex: HexCoord) -> bool:
	# Only player-owned (CLAIMED) hexes can have expansion glow
	if get_hex_owner(hex) != "player":
		return false

	# Check for adjacent contested hexes
	var neighbors := hex.get_neighbors()
	for neighbor in neighbors:
		if is_contested(neighbor):
			return true

	return false


## Get all contested hexes adjacent to player territory.
## Used by combat opportunity badge to count available battles (AC13).
##
## @return Array of contested HexCoord adjacent to player territory
func get_all_adjacent_contested() -> Array[HexCoord]:
	var result: Array[HexCoord] = []
	var added: Dictionary = {}  # Track already-added hexes to avoid duplicates

	# For each player-owned hex, check for contested neighbors
	for hex_vec in _ownership.keys():
		if _ownership[hex_vec] != "player":
			continue

		var hex := HexCoord.from_vector(hex_vec)
		var contested := get_adjacent_contested(hex)

		for contested_hex in contested:
			var contested_vec := contested_hex.to_vector()
			if not added.has(contested_vec):
				added[contested_vec] = true
				result.append(contested_hex)

	return result


# =============================================================================
# STORY 5-10: NEGLECT AND RECLAMATION SYSTEM
# =============================================================================

## Check for player activity near a hex (buildings or animals).
## Activity within ACTIVITY_DETECTION_RADIUS resets neglect timer.
##
## @param hex The hex to check around
## @return True if player activity detected nearby
func _check_activity_near_hex(hex: HexCoord) -> bool:
	if hex == null:
		return false

	# Check for buildings at this hex and neighbors
	if _has_buildings_at(hex):
		return true

	var neighbors := hex.get_neighbors()
	for neighbor in neighbors:
		if _has_buildings_at(neighbor):
			return true

	# Check for player animals nearby
	var world_pos := HexGrid.hex_to_world(hex)
	var detection_radius := GameConstants.HEX_SIZE * float(ACTIVITY_DETECTION_RADIUS + 1)
	var animals := get_tree().get_nodes_in_group("animals")

	for animal in animals:
		if not is_instance_valid(animal):
			continue

		# Skip wild animals (check for wild indicator)
		if animal.has_method("is_wild") and animal.is_wild():
			continue

		# Cast to Node3D for position access
		var animal_node := animal as Node3D
		if not animal_node:
			continue

		var distance: float = animal_node.global_position.distance_to(world_pos)
		if distance <= detection_radius:
			return true

	return false


## Check if a hex is adjacent to wild territory.
## Only neglected hexes adjacent to wild can be reclaimed.
##
## @param hex The hex to check
## @return True if adjacent to wild/camp territory
func _is_adjacent_to_wild(hex: HexCoord) -> bool:
	if hex == null:
		return false

	var neighbors := hex.get_neighbors()
	for neighbor in neighbors:
		var owner := get_hex_owner(neighbor)
		if owner == "wild" or owner.begins_with("camp_"):
			return true

	return false


## Update reclamation timer for a neglected hex.
## Only processes hexes adjacent to wild territory.
##
## @param hex The hex to update
## @param hex_vec The hex as Vector2i
## @param delta Time since last update
func _update_reclamation_timer(hex: HexCoord, hex_vec: Vector2i, delta: float) -> void:
	# Only reclaim if adjacent to wild territory
	if not _is_adjacent_to_wild(hex):
		# Not adjacent to wild - clear reclamation timer if exists
		_reclamation_timers.erase(hex_vec)
		_reclamation_started.erase(hex_vec)
		return

	# Increment reclamation timer
	var current_reclamation: float = _reclamation_timers.get(hex_vec, 0.0)

	# Emit reclamation started signal on first increment
	if current_reclamation == 0.0 and not _reclamation_started.has(hex_vec):
		_reclamation_started[hex_vec] = true
		call_deferred("_emit_reclamation_started", hex_vec, RECLAMATION_TIME)
		if is_instance_valid(GameLogger):
			GameLogger.info("TerritoryManager", "Reclamation started at hex %s (adjacent to wild)" % hex_vec)

	current_reclamation += delta
	_reclamation_timers[hex_vec] = current_reclamation

	# Check if reclamation complete
	if current_reclamation >= RECLAMATION_TIME:
		_reclaim_hex_for_wild(hex, hex_vec)


## Emit territory_reclamation_started signal (called deferred).
## @param hex_vec The hex coordinate
## @param estimated_time Time until reclamation completes
func _emit_reclamation_started(hex_vec: Vector2i, estimated_time: float) -> void:
	EventBus.territory_reclamation_started.emit(hex_vec, estimated_time)


## Reclaim a hex for wild territory.
## Changes ownership, spawns a herd, and emits signals.
## NOTE: Reclamation only completes if a herd can spawn (AC14 guarantee).
##
## @param hex The hex to reclaim
## @param hex_vec The hex as Vector2i
func _reclaim_hex_for_wild(hex: HexCoord, hex_vec: Vector2i) -> void:
	if is_instance_valid(GameLogger):
		GameLogger.info("TerritoryManager", "Wild attempting to reclaim hex %s" % hex_vec)

	# Try to spawn a herd FIRST - only complete reclamation if successful (AC14)
	var herd_spawned := _spawn_reclamation_herd(hex)

	if not herd_spawned:
		# Cannot complete reclamation without a herd to fight
		# Keep hex as NEGLECTED and hold reclamation timer at threshold
		# Will retry on next cycle when herd slot becomes available
		if is_instance_valid(GameLogger):
			GameLogger.warn("TerritoryManager", "Reclamation delayed at %s - waiting for herd slot" % hex_vec)
		return

	# Herd spawned successfully - now complete ownership change
	set_hex_owner(hex, "wild", "reclamation")

	# Emit reclaimed signal
	call_deferred("_emit_territory_reclaimed", hex_vec)

	# Clean up timers
	_neglect_timers.erase(hex_vec)
	_reclamation_timers.erase(hex_vec)
	_reclamation_started.erase(hex_vec)


## Emit territory_reclaimed_by_wild signal (called deferred).
## @param hex_vec The hex coordinate
func _emit_territory_reclaimed(hex_vec: Vector2i) -> void:
	EventBus.territory_reclaimed_by_wild.emit(hex_vec)


## Spawn a small wild herd at a reclaimed hex.
## Uses WildHerdManager if available.
##
## @param hex The hex to spawn at
## @return True if herd was spawned successfully, false otherwise
func _spawn_reclamation_herd(hex: HexCoord) -> bool:
	if not _world_manager:
		if is_instance_valid(GameLogger):
			GameLogger.warn("TerritoryManager", "Cannot spawn reclamation herd: no WorldManager")
		return false

	# Access WildHerdManager through WorldManager
	if not _world_manager.has_method("get_wild_herd_manager"):
		# Try direct property access
		if _world_manager.get("_wild_herd_manager") == null:
			if is_instance_valid(GameLogger):
				GameLogger.warn("TerritoryManager", "Cannot spawn reclamation herd: no WildHerdManager")
			return false

	var wild_herd_manager = _world_manager.get("_wild_herd_manager")
	if not wild_herd_manager:
		if is_instance_valid(GameLogger):
			GameLogger.warn("TerritoryManager", "Cannot spawn reclamation herd: WildHerdManager is null")
		return false

	# Small reclamation herd (2-3 animals)
	var herd_size := randi_range(2, 3)
	var herd = wild_herd_manager.spawn_herd(hex, herd_size, "wild")

	if herd:
		if is_instance_valid(GameLogger):
			GameLogger.info("TerritoryManager", "Reclamation herd spawned at %s with %d animals" % [hex.to_vector(), herd_size])
		return true
	else:
		# Max herds reached or other failure
		if is_instance_valid(GameLogger):
			GameLogger.debug("TerritoryManager", "Could not spawn reclamation herd at %s (may be at max herds)" % hex.to_vector())
		return false
