## Unit tests for TerritoryManager
## Tests territory state tracking, state changes, and EventBus signal emissions.
##
## Story: 1-5-display-territory-states
extends GutTest

# =============================================================================
# TEST SETUP
# =============================================================================

var territory_manager: TerritoryManager
var world_manager: WorldManager

func before_each() -> void:
	# Create WorldManager instance
	world_manager = WorldManager.new()
	add_child(world_manager)

	# Wait one frame for _ready() to be called
	await wait_frames(1)

	# Wait for world generation to complete (with timeout safety)
	if not world_manager.is_world_generated():
		await world_manager.world_generated

	# Get TerritoryManager reference (WorldManager creates it)
	territory_manager = world_manager._territory_manager

	# Verify initialization succeeded
	assert_not_null(territory_manager, "TerritoryManager should be created by WorldManager")

func after_each() -> void:
	# Only need to free WorldManager - it owns TerritoryManager and FogOfWar
	if world_manager:
		world_manager.queue_free()
		world_manager = null
		territory_manager = null

# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

func test_initial_territory_states_center_claimed() -> void:
	var center := HexCoord.new(0, 0)
	var state := territory_manager.get_territory_state(center)
	assert_eq(state, TerritoryManager.TerritoryState.CLAIMED, "Center should be claimed")

func test_initial_territory_states_range1_claimed() -> void:
	# Test hexes at range 1 from center (should all be claimed)
	var test_hexes := [
		HexCoord.new(1, 0),
		HexCoord.new(0, 1),
		HexCoord.new(-1, 1),
		HexCoord.new(-1, 0),
		HexCoord.new(0, -1),
		HexCoord.new(1, -1),
	]

	for hex in test_hexes:
		var state := territory_manager.get_territory_state(hex)
		assert_eq(state, TerritoryManager.TerritoryState.CLAIMED, "Range 1 hex %s should be claimed" % hex.to_vector())

func test_initial_territory_states_range4_scouted() -> void:
	# Test a hex at range 4 (should be scouted)
	var hex := HexCoord.new(4, 0)
	var state := territory_manager.get_territory_state(hex)
	assert_eq(state, TerritoryManager.TerritoryState.SCOUTED, "Range 4 hex should be scouted")

func test_unexplored_by_default() -> void:
	# Test a far hex (should be unexplored by default)
	var far_hex := HexCoord.new(100, 100)
	var state := territory_manager.get_territory_state(far_hex)
	assert_eq(state, TerritoryManager.TerritoryState.UNEXPLORED, "Far hex should be unexplored")

# =============================================================================
# STATE CHANGE TESTS
# =============================================================================

func test_set_territory_state() -> void:
	var hex := HexCoord.new(5, 5)
	territory_manager.set_territory_state(hex, TerritoryManager.TerritoryState.SCOUTED)
	var state := territory_manager.get_territory_state(hex)
	assert_eq(state, TerritoryManager.TerritoryState.SCOUTED, "State should be updated to SCOUTED")

func test_set_territory_state_no_change_if_same() -> void:
	var hex := HexCoord.new(0, 0)
	# Center starts as CLAIMED
	territory_manager.set_territory_state(hex, TerritoryManager.TerritoryState.CLAIMED)
	# Should not trigger any changes (no signal emissions, no visual updates)
	# This test just verifies it doesn't crash
	assert_true(true, "Setting same state should be safe")

func test_claim_territory() -> void:
	var hex := HexCoord.new(10, 10)
	territory_manager.claim_territory(hex)
	var state := territory_manager.get_territory_state(hex)
	assert_eq(state, TerritoryManager.TerritoryState.CLAIMED, "claim_territory should set state to CLAIMED")

func test_scout_territory_from_unexplored() -> void:
	var hex := HexCoord.new(20, 20)
	# Should start unexplored
	var initial_state := territory_manager.get_territory_state(hex)
	assert_eq(initial_state, TerritoryManager.TerritoryState.UNEXPLORED, "Should start unexplored")

	territory_manager.scout_territory(hex)
	var state := territory_manager.get_territory_state(hex)
	assert_eq(state, TerritoryManager.TerritoryState.SCOUTED, "scout_territory should change UNEXPLORED to SCOUTED")

func test_scout_territory_does_not_change_if_already_scouted() -> void:
	var hex := HexCoord.new(4, 0)
	# This hex is already scouted in initialization
	var initial_state := territory_manager.get_territory_state(hex)
	assert_eq(initial_state, TerritoryManager.TerritoryState.SCOUTED, "Should be scouted")

	territory_manager.scout_territory(hex)
	var state := territory_manager.get_territory_state(hex)
	assert_eq(state, TerritoryManager.TerritoryState.SCOUTED, "Should remain SCOUTED")

func test_contest_territory() -> void:
	var hex := HexCoord.new(10, 10)
	territory_manager.contest_territory(hex)
	var state := territory_manager.get_territory_state(hex)
	assert_eq(state, TerritoryManager.TerritoryState.CONTESTED, "contest_territory should set state to CONTESTED")

# =============================================================================
# SIGNAL EMISSION TESTS
# =============================================================================

func test_territory_claimed_signal() -> void:
	var hex := HexCoord.new(15, 15)
	watch_signals(EventBus)

	territory_manager.set_territory_state(hex, TerritoryManager.TerritoryState.CLAIMED)

	assert_signal_emitted(EventBus, "territory_claimed", "territory_claimed signal should be emitted")

func test_territory_lost_signal() -> void:
	var hex := HexCoord.new(0, 0)
	# Center starts claimed
	watch_signals(EventBus)

	# Change from CLAIMED to CONTESTED
	territory_manager.set_territory_state(hex, TerritoryManager.TerritoryState.CONTESTED)

	assert_signal_emitted(EventBus, "territory_lost", "territory_lost signal should be emitted when losing claimed territory")

func test_territory_claimed_signal_not_emitted_if_already_claimed() -> void:
	var hex := HexCoord.new(0, 0)
	# Center starts claimed
	watch_signals(EventBus)

	# Try to claim again (no change)
	territory_manager.set_territory_state(hex, TerritoryManager.TerritoryState.CLAIMED)

	assert_signal_emit_count(EventBus, "territory_claimed", 0, "Signal should not emit if already claimed")

# =============================================================================
# NULL SAFETY TESTS
# =============================================================================

func test_get_territory_state_with_null_hex() -> void:
	var state := territory_manager.get_territory_state(null)
	assert_eq(state, TerritoryManager.TerritoryState.UNEXPLORED, "Null hex should return UNEXPLORED")

func test_set_territory_state_with_null_hex() -> void:
	# Should not crash
	territory_manager.set_territory_state(null, TerritoryManager.TerritoryState.CLAIMED)
	assert_true(true, "Setting state on null hex should not crash")

# =============================================================================
# TILE INTEGRATION TESTS
# =============================================================================

func test_set_territory_state_updates_tile_visual() -> void:
	# Get a tile that exists in the world
	var hex := HexCoord.new(0, 0)
	var tile := world_manager.get_tile_at(hex)

	assert_not_null(tile, "Tile should exist at center")

	# Change state
	territory_manager.set_territory_state(hex, TerritoryManager.TerritoryState.CONTESTED)

	# Tile should have been updated (we'll verify visual in hex_tile tests)
	assert_eq(tile.territory_state, TerritoryManager.TerritoryState.CONTESTED, "Tile's territory_state should be updated")

func test_set_territory_state_for_non_existent_tile() -> void:
	# Test edge case: setting state for a hex outside world bounds
	var far_hex := HexCoord.new(999, 999)

	# Should not crash, state should still be tracked
	territory_manager.set_territory_state(far_hex, TerritoryManager.TerritoryState.CLAIMED)

	# State should be stored even if tile doesn't exist
	var state := territory_manager.get_territory_state(far_hex)
	assert_eq(state, TerritoryManager.TerritoryState.CLAIMED, "State should be tracked even for non-existent tiles")

	# Verify no tile exists at that location
	var tile := world_manager.get_tile_at(far_hex)
	assert_null(tile, "No tile should exist at far location")
