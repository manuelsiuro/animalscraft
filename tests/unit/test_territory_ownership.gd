## Unit tests for Territory Ownership System.
## Tests ownership management, auto-claim, and adjacent territory queries.
##
## Story: 5-1-implement-territory-ownership-system
## Architecture: tests/unit/test_territory_ownership.gd
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
# OWNERSHIP ASSIGNMENT AND RETRIEVAL TESTS (AC: 1, 2)
# =============================================================================

func test_set_hex_owner_and_get_hex_owner() -> void:
	var hex := HexCoord.create(0, 0)

	# Initially unowned
	assert_eq(_territory_manager.get_hex_owner(hex), "", "Hex should initially be unowned")

	# Set player ownership
	_territory_manager.set_hex_owner(hex, "player")
	assert_eq(_territory_manager.get_hex_owner(hex), "player", "Hex should be owned by player")


func test_set_hex_owner_player() -> void:
	var hex := HexCoord.create(1, 1)
	_territory_manager.set_hex_owner(hex, "player")
	assert_eq(_territory_manager.get_hex_owner(hex), "player")


func test_set_hex_owner_wild() -> void:
	var hex := HexCoord.create(2, 2)
	_territory_manager.set_hex_owner(hex, "wild")
	assert_eq(_territory_manager.get_hex_owner(hex), "wild")


func test_set_hex_owner_camp() -> void:
	var hex := HexCoord.create(3, 3)
	_territory_manager.set_hex_owner(hex, "camp_1")
	assert_eq(_territory_manager.get_hex_owner(hex), "camp_1")


func test_set_hex_owner_empty_clears_ownership() -> void:
	var hex := HexCoord.create(4, 4)
	_territory_manager.set_hex_owner(hex, "player")
	assert_eq(_territory_manager.get_hex_owner(hex), "player")

	_territory_manager.set_hex_owner(hex, "")
	assert_eq(_territory_manager.get_hex_owner(hex), "", "Setting empty owner should clear ownership")


func test_get_hex_owner_null_hex_returns_empty() -> void:
	var result := _territory_manager.get_hex_owner(null)
	assert_eq(result, "", "Null hex should return empty owner")


func test_set_hex_owner_null_hex_does_not_crash() -> void:
	# Should not crash or throw error
	_territory_manager.set_hex_owner(null, "player")
	assert_true(true, "Setting owner on null hex should not crash")


func test_ownership_change_updates_value() -> void:
	var hex := HexCoord.create(5, 5)
	_territory_manager.set_hex_owner(hex, "player")
	assert_eq(_territory_manager.get_hex_owner(hex), "player")

	_territory_manager.set_hex_owner(hex, "wild")
	assert_eq(_territory_manager.get_hex_owner(hex), "wild", "Ownership should update when changed")

# =============================================================================
# IS_PLAYER_OWNED HELPER TESTS (AC: 2)
# =============================================================================

func test_is_player_owned_true_when_player() -> void:
	var hex := HexCoord.create(0, 1)
	_territory_manager.set_hex_owner(hex, "player")
	assert_true(_territory_manager.is_player_owned(hex), "Should return true for player-owned hex")


func test_is_player_owned_false_when_unowned() -> void:
	var hex := HexCoord.create(0, 2)
	assert_false(_territory_manager.is_player_owned(hex), "Should return false for unowned hex")


func test_is_player_owned_false_when_enemy() -> void:
	var hex := HexCoord.create(0, 3)
	_territory_manager.set_hex_owner(hex, "wild")
	assert_false(_territory_manager.is_player_owned(hex), "Should return false for enemy-owned hex")


func test_is_player_owned_null_hex_returns_false() -> void:
	assert_false(_territory_manager.is_player_owned(null), "Should return false for null hex")

# =============================================================================
# IS_CONTESTED TESTS (AC: 2)
# =============================================================================

func test_is_contested_true_when_enemy_adjacent_to_player() -> void:
	var player_hex := HexCoord.create(0, 0)
	var enemy_hex := HexCoord.create(1, 0)  # East neighbor

	_territory_manager.set_hex_owner(player_hex, "player")
	_territory_manager.set_hex_owner(enemy_hex, "wild")

	assert_true(_territory_manager.is_contested(enemy_hex), "Enemy hex adjacent to player should be contested")


func test_is_contested_false_when_enemy_not_adjacent() -> void:
	var player_hex := HexCoord.create(0, 0)
	var enemy_hex := HexCoord.create(5, 5)  # Far from player

	_territory_manager.set_hex_owner(player_hex, "player")
	_territory_manager.set_hex_owner(enemy_hex, "wild")

	assert_false(_territory_manager.is_contested(enemy_hex), "Enemy hex not adjacent to player should not be contested")


func test_is_contested_false_when_unowned() -> void:
	var hex := HexCoord.create(0, 0)
	assert_false(_territory_manager.is_contested(hex), "Unowned hex should not be contested")


func test_is_contested_false_when_player_owned() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")
	assert_false(_territory_manager.is_contested(hex), "Player-owned hex should not be contested")


func test_is_contested_null_hex_returns_false() -> void:
	assert_false(_territory_manager.is_contested(null), "Null hex should return false for contested check")

# =============================================================================
# COUNT METHODS TESTS (AC: 3)
# =============================================================================

func test_get_claimed_count_initial_zero() -> void:
	assert_eq(_territory_manager.get_claimed_count(), 0, "Initial claimed count should be 0")


func test_get_claimed_count_increments() -> void:
	_territory_manager.set_hex_owner(HexCoord.create(0, 0), "player")
	assert_eq(_territory_manager.get_claimed_count(), 1)

	_territory_manager.set_hex_owner(HexCoord.create(1, 0), "player")
	assert_eq(_territory_manager.get_claimed_count(), 2)


func test_get_claimed_count_decrements_on_unclaim() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")
	assert_eq(_territory_manager.get_claimed_count(), 1)

	_territory_manager.set_hex_owner(hex, "")
	assert_eq(_territory_manager.get_claimed_count(), 0)


func test_get_contested_count_with_contested_hexes() -> void:
	# Create a contested scenario
	_territory_manager.set_hex_owner(HexCoord.create(0, 0), "player")
	_territory_manager.set_hex_owner(HexCoord.create(1, 0), "wild")  # Adjacent to player

	var contested_count := _territory_manager.get_contested_count()
	assert_eq(contested_count, 1, "Should have 1 contested hex")


func test_get_contested_count_no_contested() -> void:
	_territory_manager.set_hex_owner(HexCoord.create(0, 0), "player")
	_territory_manager.set_hex_owner(HexCoord.create(5, 5), "wild")  # Not adjacent

	var contested_count := _territory_manager.get_contested_count()
	assert_eq(contested_count, 0, "Should have 0 contested hexes when not adjacent")


func test_get_unowned_count_without_world_manager() -> void:
	# Without WorldManager, get_unowned_count returns cached value (starts at 0)
	var unowned := _territory_manager.get_unowned_count()
	assert_eq(unowned, 0, "Without WorldManager, unowned count should be 0")

# =============================================================================
# EVENTBUS SIGNAL TESTS (AC: 12)
# =============================================================================

func test_ownership_change_emits_signal() -> void:
	watch_signals(EventBus)
	var hex := HexCoord.create(0, 0)

	_territory_manager.set_hex_owner(hex, "player")

	assert_signal_emitted(EventBus, "territory_ownership_changed")


func test_ownership_change_signal_parameters() -> void:
	watch_signals(EventBus)
	var hex := HexCoord.create(2, 3)

	_territory_manager.set_hex_owner(hex, "player")

	assert_signal_emitted_with_parameters(
		EventBus,
		"territory_ownership_changed",
		[Vector2i(2, 3), "", "player"]
	)


func test_ownership_change_signal_on_owner_change() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")

	watch_signals(EventBus)
	_territory_manager.set_hex_owner(hex, "wild")

	assert_signal_emitted_with_parameters(
		EventBus,
		"territory_ownership_changed",
		[Vector2i(0, 0), "player", "wild"]
	)


func test_no_signal_when_ownership_unchanged() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")

	watch_signals(EventBus)
	_territory_manager.set_hex_owner(hex, "player")  # Same owner

	assert_signal_not_emitted(EventBus, "territory_ownership_changed")

# =============================================================================
# COMBAT-CLAIMED TRACKING TESTS (AC: 9, 10)
# =============================================================================

func test_is_combat_claimed_true_when_source_combat() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player", "combat")

	assert_true(_territory_manager.is_combat_claimed(hex), "Should return true for combat-claimed hex")


func test_is_combat_claimed_false_when_source_building() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player", "building")

	assert_false(_territory_manager.is_combat_claimed(hex), "Should return false for building-claimed hex")


func test_is_combat_claimed_false_when_unowned() -> void:
	var hex := HexCoord.create(0, 0)
	assert_false(_territory_manager.is_combat_claimed(hex), "Should return false for unowned hex")


func test_is_combat_claimed_null_hex_returns_false() -> void:
	assert_false(_territory_manager.is_combat_claimed(null), "Should return false for null hex")

# =============================================================================
# ADJACENT TERRITORY API TESTS (AC: 13, 14)
# =============================================================================

func test_get_adjacent_contested_returns_contested_neighbors() -> void:
	var player_hex := HexCoord.create(0, 0)
	var enemy_hex := HexCoord.create(1, 0)  # East neighbor

	_territory_manager.set_hex_owner(player_hex, "player")
	_territory_manager.set_hex_owner(enemy_hex, "wild")

	var contested := _territory_manager.get_adjacent_contested(player_hex)
	assert_eq(contested.size(), 1, "Should have 1 adjacent contested hex")
	assert_eq(contested[0].to_vector(), enemy_hex.to_vector())


func test_get_adjacent_contested_empty_when_no_contested() -> void:
	var player_hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(player_hex, "player")

	var contested := _territory_manager.get_adjacent_contested(player_hex)
	assert_eq(contested.size(), 0, "Should have 0 contested neighbors when none exist")


func test_get_adjacent_contested_null_hex_returns_empty() -> void:
	var contested := _territory_manager.get_adjacent_contested(null)
	assert_eq(contested.size(), 0)


func test_get_claimable_neighbors_returns_unowned() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")

	var claimable := _territory_manager.get_claimable_neighbors(hex)
	# Without WorldManager, all 6 neighbors are assumed valid and claimable
	assert_eq(claimable.size(), 6, "Should have 6 claimable neighbors for isolated hex (no WorldManager)")


func test_get_claimable_neighbors_excludes_owned() -> void:
	var hex := HexCoord.create(0, 0)
	var neighbor := HexCoord.create(1, 0)  # East neighbor

	_territory_manager.set_hex_owner(hex, "player")
	_territory_manager.set_hex_owner(neighbor, "player")

	var claimable := _territory_manager.get_claimable_neighbors(hex)
	# Should have 5 claimable neighbors (one is owned)
	assert_eq(claimable.size(), 5, "Should have 5 claimable neighbors when one is owned")


func test_get_claimable_neighbors_null_hex_returns_empty() -> void:
	var claimable := _territory_manager.get_claimable_neighbors(null)
	assert_eq(claimable.size(), 0)


func test_get_all_border_hexes_returns_expansion_frontier() -> void:
	var center := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(center, "player")

	var border := _territory_manager.get_all_border_hexes()
	# Should return all 6 neighbors as border hexes
	assert_eq(border.size(), 6, "Should have 6 border hexes for single owned hex")


func test_get_all_border_hexes_no_duplicates() -> void:
	# Create a 2-hex cluster
	_territory_manager.set_hex_owner(HexCoord.create(0, 0), "player")
	_territory_manager.set_hex_owner(HexCoord.create(1, 0), "player")  # East neighbor

	var border := _territory_manager.get_all_border_hexes()

	# Check for duplicates
	var seen: Dictionary = {}
	var has_duplicates := false
	for hex in border:
		var vec := hex.to_vector()
		if seen.has(vec):
			has_duplicates = true
			break
		seen[vec] = true

	assert_false(has_duplicates, "Border hexes should not contain duplicates")


func test_get_all_border_hexes_empty_when_no_player_territory() -> void:
	var border := _territory_manager.get_all_border_hexes()
	assert_eq(border.size(), 0, "Should have 0 border hexes when no player territory")

# =============================================================================
# TERRITORY STATE SYNC TESTS (AC: 4, 5, 6, 7)
# =============================================================================

func test_set_hex_owner_player_syncs_claimed_state() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")

	var state := _territory_manager.get_territory_state(hex)
	assert_eq(state, TerritoryManager.TerritoryState.CLAIMED, "Player ownership should sync to CLAIMED state")


func test_set_hex_owner_enemy_syncs_contested_state() -> void:
	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "wild")

	var state := _territory_manager.get_territory_state(hex)
	assert_eq(state, TerritoryManager.TerritoryState.CONTESTED, "Enemy ownership should sync to CONTESTED state")


func test_set_hex_owner_empty_syncs_scouted_state_from_claimed() -> void:
	var hex := HexCoord.create(0, 0)

	# First claim it
	_territory_manager.set_hex_owner(hex, "player")
	assert_eq(_territory_manager.get_territory_state(hex), TerritoryManager.TerritoryState.CLAIMED)

	# Then unclaim it
	_territory_manager.set_hex_owner(hex, "")
	assert_eq(_territory_manager.get_territory_state(hex), TerritoryManager.TerritoryState.SCOUTED, "Unclaiming should revert to SCOUTED")

# =============================================================================
# PERFORMANCE TESTS (AC: 15)
# =============================================================================

func test_ownership_lookup_performance() -> void:
	# Create 200+ hexes with ownership
	for q in range(-10, 10):
		for r in range(-10, 10):
			_territory_manager.set_hex_owner(HexCoord.create(q, r), "player" if (q + r) % 2 == 0 else "wild")

	# Measure lookup time
	var start_time := Time.get_ticks_usec()

	for _i in range(1000):
		var _owner := _territory_manager.get_hex_owner(HexCoord.create(0, 0))

	var elapsed_usec := Time.get_ticks_usec() - start_time
	var avg_usec := elapsed_usec / 1000.0

	# Should average under 1ms (1000 microseconds) per lookup
	assert_lt(avg_usec, 1000.0, "Ownership lookup should average under 1ms (was %f usec)" % avg_usec)


func test_count_methods_performance() -> void:
	# Create hexes
	for q in range(-10, 10):
		for r in range(-10, 10):
			_territory_manager.set_hex_owner(HexCoord.create(q, r), "player")

	var start_time := Time.get_ticks_usec()

	for _i in range(100):
		var _claimed := _territory_manager.get_claimed_count()

	var elapsed_usec := Time.get_ticks_usec() - start_time
	var avg_usec := elapsed_usec / 100.0

	# Claimed count uses cached value, should be very fast
	assert_lt(avg_usec, 100.0, "Claimed count should use cached value (was %f usec)" % avg_usec)


func test_contested_count_performance() -> void:
	# Create a realistic scenario with player territory surrounded by enemies
	# Player owns center hexes, enemies own outer ring
	for q in range(-5, 6):
		for r in range(-5, 6):
			if abs(q) <= 2 and abs(r) <= 2:
				_territory_manager.set_hex_owner(HexCoord.create(q, r), "player")
			else:
				_territory_manager.set_hex_owner(HexCoord.create(q, r), "wild")

	var start_time := Time.get_ticks_usec()

	for _i in range(100):
		var _contested := _territory_manager.get_contested_count()

	var elapsed_usec := Time.get_ticks_usec() - start_time
	var avg_usec := elapsed_usec / 100.0

	# AC15: Operations should complete in under 1ms (1000 usec)
	# Contested count iterates through enemy hexes and checks adjacency
	assert_lt(avg_usec, 1000.0, "Contested count should complete under 1ms (was %f usec)" % avg_usec)


# =============================================================================
# EDGE CASES
# =============================================================================

func test_multiple_camps_tracked_separately() -> void:
	_territory_manager.set_hex_owner(HexCoord.create(0, 0), "camp_1")
	_territory_manager.set_hex_owner(HexCoord.create(1, 0), "camp_2")
	_territory_manager.set_hex_owner(HexCoord.create(2, 0), "camp_3")

	assert_eq(_territory_manager.get_hex_owner(HexCoord.create(0, 0)), "camp_1")
	assert_eq(_territory_manager.get_hex_owner(HexCoord.create(1, 0)), "camp_2")
	assert_eq(_territory_manager.get_hex_owner(HexCoord.create(2, 0)), "camp_3")


func test_same_hex_ownership_change_no_duplicate_count() -> void:
	var hex := HexCoord.create(0, 0)

	_territory_manager.set_hex_owner(hex, "player")
	assert_eq(_territory_manager.get_claimed_count(), 1)

	# Change to same owner - should not increment
	_territory_manager.set_hex_owner(hex, "player")
	assert_eq(_territory_manager.get_claimed_count(), 1, "Count should not change when setting same owner")


# =============================================================================
# SIGNAL CLEANUP TESTS (AR18)
# =============================================================================

func test_exit_tree_disconnects_signals() -> void:
	# Verify signals are connected
	assert_true(EventBus.building_placed.is_connected(_territory_manager._on_building_placed),
		"building_placed should be connected after _ready")
	assert_true(EventBus.building_removed.is_connected(_territory_manager._on_building_removed),
		"building_removed should be connected after _ready")

	# Simulate exit tree
	_territory_manager._exit_tree()

	# Verify signals are disconnected
	assert_false(EventBus.building_placed.is_connected(_territory_manager._on_building_placed),
		"building_placed should be disconnected after _exit_tree")
	assert_false(EventBus.building_removed.is_connected(_territory_manager._on_building_removed),
		"building_removed should be disconnected after _exit_tree")
