## FogOfWar - Manages fog of war mechanics and territory reveal.
## Handles fog reveal on territory claim and scouting of adjacent hexes.
##
## Architecture: scripts/world/fog_of_war.gd
## Parent: Child of WorldManager
## Story: 1-6-implement-fog-of-war
class_name FogOfWar
extends Node

# =============================================================================
# CONSTANTS
# =============================================================================

## Starting reveal radius (center + ring 1 = 7 hexes total)
const STARTING_REVEAL_RADIUS: int = 1

## Scout ring radius (rings 2-4 from center)
const STARTING_SCOUT_MIN: int = 2
const STARTING_SCOUT_MAX: int = 4

# =============================================================================
# PROPERTIES
# =============================================================================

## Reference to WorldManager
var _world_manager: WorldManager

## Reference to TerritoryManager (from Story 1.5)
var _territory_manager: TerritoryManager

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	add_to_group("fog_of_war")

## Initialize the fog system with world and territory managers.
## Called by WorldManager after all systems are ready.
##
## @param world_manager Reference to WorldManager
## @param territory_manager Reference to TerritoryManager (from Story 1.5)
func initialize(world_manager: WorldManager, territory_manager: TerritoryManager) -> void:
	# AR18: Null safety guard
	if world_manager == null or territory_manager == null:
		push_error("[FogOfWar] Cannot initialize with null references")
		return

	_world_manager = world_manager
	_territory_manager = territory_manager

	# Connect to EventBus signals for future integration
	# (Animals, buildings in later epics will use these)
	EventBus.territory_claimed.connect(_on_territory_claimed)

	# Initialize starting fog state
	_initialize_starting_fog()

	# AR11: Debug logging
	if is_instance_valid(GameLogger):
		GameLogger.info("FogOfWar", "Fog system initialized - starting area revealed")

## Initialize starting fog state for new game.
## AC1-AC3: Starting area revealed, adjacent scouted, distant fogged
func _initialize_starting_fog() -> void:
	var center := HexCoord.new(0, 0)

	# AC1: Reveal starting area (center + ring 1 = 7 hexes)
	# These hexes become CLAIMED
	var starting_hexes := HexGrid.get_hexes_in_range(center, STARTING_REVEAL_RADIUS)
	for hex in starting_hexes:
		_territory_manager.set_territory_state(hex, TerritoryManager.TerritoryState.CLAIMED)

	# AC2: Scout adjacent hexes (rings 2-4)
	# These hexes become SCOUTED (dim, terrain visible)
	for radius in range(STARTING_SCOUT_MIN, STARTING_SCOUT_MAX + 1):
		var scouted_ring := HexGrid.get_hex_ring(center, radius)
		for hex in scouted_ring:
			_territory_manager.set_territory_state(hex, TerritoryManager.TerritoryState.SCOUTED)

	# AC3: All other hexes remain UNEXPLORED (default)
	# No action needed - TerritoryManager defaults to UNEXPLORED

# =============================================================================
# FOG REVEAL METHODS
# =============================================================================

## Reveal a hex and scout its neighbors.
## AC4: Fog reveals on territory claim
##
## @param hex The hex coordinate to reveal
func reveal_hex(hex: HexCoord) -> void:
	# AR18: Null safety
	if hex == null:
		push_warning("[FogOfWar] Cannot reveal null hex")
		return

	# Claim the hex (triggers visual update via TerritoryManager)
	_territory_manager.claim_territory(hex)

	# Scout all neighbors (if they are UNEXPLORED)
	var neighbors := hex.get_neighbors()
	for neighbor in neighbors:
		scout_hex(neighbor)

	# AR11: Debug logging
	if is_instance_valid(GameLogger):
		GameLogger.debug("FogOfWar", "Revealed hex %s and scouted %d neighbors" % [hex.to_vector(), neighbors.size()])

## Scout a hex (only if currently UNEXPLORED).
## Changes UNEXPLORED → SCOUTED, leaves other states unchanged.
##
## @param hex The hex coordinate to scout
func scout_hex(hex: HexCoord) -> void:
	# AR18: Null safety
	if hex == null:
		return

	# Only scout if currently unexplored
	var current_state := _territory_manager.get_territory_state(hex)
	if current_state == TerritoryManager.TerritoryState.UNEXPLORED:
		_territory_manager.scout_territory(hex)

## Get the number of revealed hexes (for debug/stats).
##
## @return Count of CLAIMED hexes
func get_revealed_count() -> int:
	if _territory_manager == null:
		return 0
	return _territory_manager.get_state_count(TerritoryManager.TerritoryState.CLAIMED)

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

## Handle territory claimed signal from EventBus.
## Future stories (combat, buildings) will trigger this.
##
## @param hex_coord The hex that was claimed
func _on_territory_claimed(hex_coord: Vector2i) -> void:
	# Future: Auto-reveal neighbors when claiming via combat/buildings
	# For Story 1.6, reveal_hex() handles this explicitly
	pass

# =============================================================================
# CLEANUP
# =============================================================================

## Cleanup resources before node destruction.
## AR19: Resource cleanup pattern
func cleanup() -> void:
	# Disconnect signals
	if EventBus.territory_claimed.is_connected(_on_territory_claimed):
		EventBus.territory_claimed.disconnect(_on_territory_claimed)

	# Clear references
	_world_manager = null
	_territory_manager = null

	# Remove from groups
	if is_in_group("fog_of_war"):
		remove_from_group("fog_of_war")

	# Queue self for deletion
	queue_free()
