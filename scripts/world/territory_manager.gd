## TerritoryManager - Manages territory state tracking and ownership.
## Controls visual state of territories: unexplored, scouted, contested, claimed, neglected.
##
## Architecture: scripts/world/territory_manager.gd
## Parent: Singleton/autoload or child of WorldManager
## Story: 1-5-display-territory-states
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
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	add_to_group("territory_managers")

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
