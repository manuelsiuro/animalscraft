## Unit tests for Territory Neglect and Reclamation System.
## Tests neglect tracking, activity detection, reclamation timers, and signals.
##
## Story: 5-10-implement-wild-rival-camps
## Architecture: tests/unit/test_territory_neglect.gd
extends GutTest

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _territory_manager: TerritoryManager

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	_territory_manager = TerritoryManager.new()
	add_child_autofree(_territory_manager)
	await wait_frames(1)


func after_each() -> void:
	_territory_manager = null

# =============================================================================
# CONSTANTS TESTS (AC: 16, 17)
# =============================================================================

func test_neglect_threshold_constant_defined() -> void:
	assert_eq(TerritoryManager.NEGLECT_THRESHOLD, 300.0,
		"NEGLECT_THRESHOLD should be 300 seconds (5 minutes)")


func test_neglect_check_interval_constant_defined() -> void:
	assert_eq(TerritoryManager.NEGLECT_CHECK_INTERVAL, 10.0,
		"NEGLECT_CHECK_INTERVAL should be 10 seconds")


func test_reclamation_time_constant_defined() -> void:
	assert_eq(TerritoryManager.RECLAMATION_TIME, 60.0,
		"RECLAMATION_TIME should be 60 seconds")


func test_activity_detection_radius_constant_defined() -> void:
	assert_eq(TerritoryManager.ACTIVITY_DETECTION_RADIUS, 1,
		"ACTIVITY_DETECTION_RADIUS should be 1 (adjacent hexes)")


func test_max_hexes_per_frame_constant_defined() -> void:
	assert_eq(TerritoryManager.MAX_HEXES_PER_FRAME, 15,
		"MAX_HEXES_PER_FRAME should be 15 for performance")

# =============================================================================
# NEGLECT TIMER TRACKING TESTS (AC: 1, 2)
# =============================================================================

func test_hex_without_activity_accumulates_neglect_time() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")

	# Simulate time passing via _update_single_hex_neglect
	# Since there's no WorldManager/buildings/animals, activity check returns false
	_territory_manager._update_single_hex_neglect(hex.to_vector(), 100.0)

	# Neglect timer should have accumulated
	var neglect_time: float = _territory_manager._neglect_timers.get(hex.to_vector(), 0.0)
	assert_eq(neglect_time, 100.0, "Neglect timer should accumulate time")


func test_hex_becomes_neglected_after_threshold() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")

	# Simulate time beyond threshold
	_territory_manager._update_single_hex_neglect(hex.to_vector(), TerritoryManager.NEGLECT_THRESHOLD + 1.0)

	# Territory state should be NEGLECTED
	var state := _territory_manager.get_territory_state(hex)
	assert_eq(state, TerritoryManager.TerritoryState.NEGLECTED,
		"Hex should become NEGLECTED after threshold")


func test_neglect_timer_resets_with_activity() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")

	# First accumulate some neglect time
	_territory_manager._neglect_timers[hex.to_vector()] = 200.0
	_territory_manager._reclamation_timers[hex.to_vector()] = 30.0
	_territory_manager._reclamation_started[hex.to_vector()] = true

	# Use _reset_neglect_timers_around to simulate building placement activity (AC4)
	_territory_manager._reset_neglect_timers_around(hex)

	# Verify timer was reset
	assert_false(_territory_manager._neglect_timers.has(hex.to_vector()),
		"Neglect timer should be cleared after activity")
	assert_false(_territory_manager._reclamation_timers.has(hex.to_vector()),
		"Reclamation timer should be cleared after activity")
	assert_false(_territory_manager._reclamation_started.has(hex.to_vector()),
		"Reclamation started flag should be cleared after activity")

# =============================================================================
# ACTIVITY DETECTION TESTS (AC: 2, 4)
# =============================================================================

func test_check_activity_near_hex_null_returns_false() -> void:
	var result := _territory_manager._check_activity_near_hex(null)
	assert_false(result, "Null hex should return false for activity check")


func test_check_activity_near_hex_no_activity_returns_false() -> void:
	# Without WorldManager and no animals/buildings, should return false
	var hex := HexCoord.create(0, 0)
	var result := _territory_manager._check_activity_near_hex(hex)
	assert_false(result, "Hex without activity should return false")


func test_reset_neglect_timers_around_clears_adjacent_timers() -> void:
	# AC4: Building placement should reset timers for adjacent hexes
	var center := HexCoord.create(0, 0)
	var neighbor := HexCoord.create(1, 0)  # East neighbor

	# Set up neglect timers for both hexes
	_territory_manager.set_hex_owner(center, "player")
	_territory_manager.set_hex_owner(neighbor, "player")
	_territory_manager._neglect_timers[center.to_vector()] = 200.0
	_territory_manager._neglect_timers[neighbor.to_vector()] = 150.0

	# Reset timers around center (simulating building placed at center)
	_territory_manager._reset_neglect_timers_around(center)

	# Both timers should be cleared (within ACTIVITY_DETECTION_RADIUS)
	assert_false(_territory_manager._neglect_timers.has(center.to_vector()),
		"Center hex timer should be cleared")
	assert_false(_territory_manager._neglect_timers.has(neighbor.to_vector()),
		"Adjacent hex timer should be cleared")

# =============================================================================
# RECLAMATION TESTS (AC: 5, 6, 7, 8)
# =============================================================================

func test_is_adjacent_to_wild_true_when_neighbor_is_wild() -> void:
	var player_hex := HexCoord.create(0, 0)
	var wild_hex := HexCoord.create(1, 0)  # East neighbor

	_territory_manager.set_hex_owner(player_hex, "player")
	_territory_manager.set_hex_owner(wild_hex, "wild")

	var result := _territory_manager._is_adjacent_to_wild(player_hex)
	assert_true(result, "Hex adjacent to wild territory should return true")


func test_is_adjacent_to_wild_true_when_neighbor_is_camp() -> void:
	var player_hex := HexCoord.create(0, 0)
	var camp_hex := HexCoord.create(1, 0)  # East neighbor

	_territory_manager.set_hex_owner(player_hex, "player")
	_territory_manager.set_hex_owner(camp_hex, "camp_1")

	var result := _territory_manager._is_adjacent_to_wild(player_hex)
	assert_true(result, "Hex adjacent to camp territory should return true")


func test_is_adjacent_to_wild_false_when_no_wild_neighbors() -> void:
	var player_hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(player_hex, "player")

	var result := _territory_manager._is_adjacent_to_wild(player_hex)
	assert_false(result, "Hex with no wild neighbors should return false")


func test_is_adjacent_to_wild_null_returns_false() -> void:
	var result := _territory_manager._is_adjacent_to_wild(null)
	assert_false(result, "Null hex should return false for adjacent to wild check")


func test_reclamation_timer_starts_only_when_adjacent_to_wild() -> void:
	var hex := HexCoord.create(0, 0)
	var wild_hex := HexCoord.create(1, 0)  # East neighbor

	_territory_manager.set_hex_owner(hex, "player")
	_territory_manager.set_territory_state(hex, TerritoryManager.TerritoryState.NEGLECTED)
	_territory_manager.set_hex_owner(wild_hex, "wild")

	# Process reclamation
	_territory_manager._update_reclamation_timer(hex, hex.to_vector(), 10.0)

	# Reclamation timer should have started
	var reclamation_time: float = _territory_manager._reclamation_timers.get(hex.to_vector(), 0.0)
	assert_eq(reclamation_time, 10.0, "Reclamation timer should start when adjacent to wild")


func test_reclamation_timer_not_started_when_not_adjacent_to_wild() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")
	_territory_manager.set_territory_state(hex, TerritoryManager.TerritoryState.NEGLECTED)
	# No wild neighbors

	# Process reclamation
	_territory_manager._update_reclamation_timer(hex, hex.to_vector(), 10.0)

	# Reclamation timer should not have started
	var reclamation_time: float = _territory_manager._reclamation_timers.get(hex.to_vector(), 0.0)
	assert_eq(reclamation_time, 0.0, "Reclamation timer should not start without wild neighbor")


func test_reclaim_hex_delayed_without_herd_manager() -> void:
	# Without WildHerdManager, reclamation should be delayed (AC14 guarantee)
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")

	# Directly call reclaim - should NOT change ownership without herd spawn
	_territory_manager._reclaim_hex_for_wild(hex, hex.to_vector())

	# Ownership should STILL be player (herd couldn't spawn)
	assert_eq(_territory_manager.get_hex_owner(hex), "player",
		"Reclamation should be delayed if herd cannot spawn (AC14)")


func test_spawn_reclamation_herd_returns_false_without_manager() -> void:
	# Verify _spawn_reclamation_herd returns false without WildHerdManager
	var hex := HexCoord.create(0, 0)

	var result := _territory_manager._spawn_reclamation_herd(hex)
	assert_false(result, "Should return false without WildHerdManager")


func test_reset_single_hex_neglect_clears_timers() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")
	_territory_manager._neglect_timers[hex.to_vector()] = 300.0
	_territory_manager._reclamation_timers[hex.to_vector()] = 60.0
	_territory_manager._reclamation_started[hex.to_vector()] = true

	# Reset via activity detection
	_territory_manager._reset_single_hex_neglect(hex.to_vector())

	# Timers should be cleared
	assert_false(_territory_manager._neglect_timers.has(hex.to_vector()),
		"Neglect timer should be cleared after activity")
	assert_false(_territory_manager._reclamation_timers.has(hex.to_vector()),
		"Reclamation timer should be cleared after activity")
	assert_false(_territory_manager._reclamation_started.has(hex.to_vector()),
		"Reclamation started flag should be cleared after activity")

# =============================================================================
# SIGNAL TESTS (AC: 9, 10, 11, 12)
# =============================================================================

func test_territory_neglected_signal_emitted() -> void:
	watch_signals(EventBus)
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")

	# Simulate neglect past threshold
	_territory_manager._update_single_hex_neglect(hex.to_vector(), TerritoryManager.NEGLECT_THRESHOLD + 1.0)

	# Allow deferred signal to emit
	await wait_frames(1)

	assert_signal_emitted(EventBus, "territory_neglected")


func test_territory_reclamation_started_signal_emitted() -> void:
	watch_signals(EventBus)
	var hex := HexCoord.create(0, 0)
	var wild_hex := HexCoord.create(1, 0)

	_territory_manager.set_hex_owner(hex, "player")
	_territory_manager.set_territory_state(hex, TerritoryManager.TerritoryState.NEGLECTED)
	_territory_manager.set_hex_owner(wild_hex, "wild")

	# Start reclamation
	_territory_manager._update_reclamation_timer(hex, hex.to_vector(), 1.0)

	# Allow deferred signal to emit
	await wait_frames(1)

	assert_signal_emitted(EventBus, "territory_reclamation_started")


func test_territory_reclaimed_by_wild_signal_not_emitted_without_herd() -> void:
	# AC14: Signal should NOT be emitted if herd can't spawn (no WildHerdManager)
	watch_signals(EventBus)
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")

	# Attempt reclaim - should fail without WildHerdManager
	_territory_manager._reclaim_hex_for_wild(hex, hex.to_vector())

	# Allow deferred signal to emit (if any)
	await wait_frames(1)

	# Signal should NOT be emitted (reclamation delayed due to no herd)
	assert_signal_not_emitted(EventBus, "territory_reclaimed_by_wild")
	# Ownership should remain player
	assert_eq(_territory_manager.get_hex_owner(hex), "player",
		"Ownership should not change without herd spawn")


func test_emit_territory_reclaimed_signal_directly() -> void:
	# Test that the signal emission function works correctly
	watch_signals(EventBus)

	_territory_manager._emit_territory_reclaimed(Vector2i(5, 5))

	assert_signal_emitted(EventBus, "territory_reclaimed_by_wild")


func test_territory_activity_detected_signal_emitted_on_reset() -> void:
	# This test would require activity detection to actually detect something
	# Without WorldManager, we can test the signal emission function directly
	watch_signals(EventBus)

	_territory_manager._emit_activity_detected(Vector2i(0, 0))

	assert_signal_emitted(EventBus, "territory_activity_detected")

# =============================================================================
# PERFORMANCE TESTS (AC: 18, 19)
# =============================================================================

func test_batch_count_calculation() -> void:
	# Test with empty hex list
	_territory_manager._player_hex_list.clear()
	assert_eq(_territory_manager._get_batch_count(), 1, "Batch count should be at least 1")

	# Test with hex list smaller than MAX_HEXES_PER_FRAME
	for i in 10:
		_territory_manager._player_hex_list.append(Vector2i(i, 0))
	assert_eq(_territory_manager._get_batch_count(), 1,
		"Batch count should be 1 for small hex lists")

	# Test with larger hex list
	_territory_manager._player_hex_list.clear()
	for i in 50:
		_territory_manager._player_hex_list.append(Vector2i(i, 0))
	var expected_batches := ceili(50.0 / float(TerritoryManager.MAX_HEXES_PER_FRAME))
	assert_eq(_territory_manager._get_batch_count(), expected_batches,
		"Batch count should scale with hex list size")


func test_rebuild_player_hex_list() -> void:
	# Set up some player-owned hexes
	_territory_manager.set_hex_owner(HexCoord.create(0, 0), "player")
	_territory_manager.set_hex_owner(HexCoord.create(1, 0), "player")
	_territory_manager.set_hex_owner(HexCoord.create(2, 0), "wild")  # Not player

	# Rebuild list
	_territory_manager._rebuild_player_hex_list()

	# Should contain only player-owned hexes
	assert_eq(_territory_manager._player_hex_list.size(), 2,
		"Player hex list should contain only player-owned hexes")
	assert_true(_territory_manager._player_hex_list.has(Vector2i(0, 0)))
	assert_true(_territory_manager._player_hex_list.has(Vector2i(1, 0)))
	assert_false(_territory_manager._player_hex_list.has(Vector2i(2, 0)))


func test_neglect_timer_uses_simple_dictionary() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager._neglect_timers[hex.to_vector()] = 100.0

	# Verify it's a simple dictionary lookup
	var value: float = _territory_manager._neglect_timers.get(Vector2i(0, 0), 0.0)
	assert_eq(value, 100.0, "Neglect timers should use simple Dictionary storage")


func test_reclamation_timer_uses_simple_dictionary() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager._reclamation_timers[hex.to_vector()] = 30.0

	# Verify it's a simple dictionary lookup
	var value: float = _territory_manager._reclamation_timers.get(Vector2i(0, 0), 0.0)
	assert_eq(value, 30.0, "Reclamation timers should use simple Dictionary storage")

# =============================================================================
# STATE TRANSITION TESTS (AC: 3)
# =============================================================================

func test_neglected_hex_reverts_to_claimed_on_activity() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")
	_territory_manager.set_territory_state(hex, TerritoryManager.TerritoryState.NEGLECTED)
	_territory_manager._neglect_timers[hex.to_vector()] = 400.0

	# Use the actual code path: _reset_neglect_timers_around simulates building activity (AC4)
	# This is what happens when a building is placed on or near a neglected hex
	_territory_manager._reset_neglect_timers_around(hex)

	# Verify state reverted via actual code path
	var state := _territory_manager.get_territory_state(hex)
	assert_eq(state, TerritoryManager.TerritoryState.CLAIMED,
		"Neglected hex should revert to CLAIMED when activity detected")

# =============================================================================
# EDGE CASES
# =============================================================================

func test_reclamation_does_not_happen_for_interior_hex() -> void:
	# Create a player territory island with no wild neighbors
	_territory_manager.set_hex_owner(HexCoord.create(0, 0), "player")
	_territory_manager.set_hex_owner(HexCoord.create(1, 0), "player")
	_territory_manager.set_hex_owner(HexCoord.create(0, 1), "player")
	_territory_manager.set_hex_owner(HexCoord.create(-1, 0), "player")
	_territory_manager.set_hex_owner(HexCoord.create(0, -1), "player")
	_territory_manager.set_hex_owner(HexCoord.create(-1, 1), "player")
	_territory_manager.set_hex_owner(HexCoord.create(1, -1), "player")

	var center_hex := HexCoord.create(0, 0)
	_territory_manager.set_territory_state(center_hex, TerritoryManager.TerritoryState.NEGLECTED)

	# Center hex is surrounded by player hexes, so not adjacent to wild
	assert_false(_territory_manager._is_adjacent_to_wild(center_hex),
		"Interior hex should not be adjacent to wild")


func test_multiple_hexes_can_be_neglected_simultaneously() -> void:
	var hex1 := HexCoord.create(0, 0)
	var hex2 := HexCoord.create(5, 5)

	_territory_manager.set_hex_owner(hex1, "player")
	_territory_manager.set_hex_owner(hex2, "player")

	# Both hexes accumulate neglect
	_territory_manager._update_single_hex_neglect(hex1.to_vector(), TerritoryManager.NEGLECT_THRESHOLD + 1.0)
	_territory_manager._update_single_hex_neglect(hex2.to_vector(), TerritoryManager.NEGLECT_THRESHOLD + 1.0)

	# Both should be NEGLECTED
	assert_eq(_territory_manager.get_territory_state(hex1), TerritoryManager.TerritoryState.NEGLECTED)
	assert_eq(_territory_manager.get_territory_state(hex2), TerritoryManager.TerritoryState.NEGLECTED)


func test_timer_cleanup_on_activity_reset() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")
	_territory_manager._neglect_timers[hex.to_vector()] = 200.0
	_territory_manager._reclamation_timers[hex.to_vector()] = 30.0
	_territory_manager._reclamation_started[hex.to_vector()] = true

	# Simulate activity via _reset_neglect_timers_around (building placement)
	_territory_manager._reset_neglect_timers_around(hex)

	# Timers should be cleaned up
	assert_false(_territory_manager._neglect_timers.has(hex.to_vector()),
		"Neglect timer should be cleaned up on activity")
	assert_false(_territory_manager._reclamation_timers.has(hex.to_vector()),
		"Reclamation timer should be cleaned up on activity")
	assert_false(_territory_manager._reclamation_started.has(hex.to_vector()),
		"Reclamation started flag should be cleaned up on activity")
