## Integration tests for Neglect and Reclamation Flow.
## Tests full neglect -> reclamation -> combat flow integration.
##
## Story: 5-10-implement-wild-rival-camps
## Architecture: tests/integration/test_neglect_reclamation_flow.gd
extends GutTest

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _territory_manager: TerritoryManager
var _mock_world_manager: Node3D

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Create mock WorldManager with minimal functionality
	_mock_world_manager = Node3D.new()
	var script := GDScript.new()
	script.source_code = """
extends Node3D
class_name MockWorldManager

var _territory_manager: TerritoryManager
var _wild_herd_manager: Node

func get_tile_at(hex: HexCoord):
	return null

func get_all_tiles() -> Array:
	return []

func get_tile_count() -> int:
	return 100
"""
	script.reload()
	_mock_world_manager.set_script(script)
	add_child_autofree(_mock_world_manager)

	# Create TerritoryManager
	_territory_manager = TerritoryManager.new()
	add_child_autofree(_territory_manager)
	await wait_frames(1)


func after_each() -> void:
	_territory_manager = null
	_mock_world_manager = null

# =============================================================================
# FULL FLOW TESTS (AC: Full integration)
# =============================================================================

func test_full_neglect_to_reclamation_flow() -> void:
	# Setup: Player hex adjacent to wild
	var player_hex := HexCoord.create(0, 0)
	var wild_hex := HexCoord.create(1, 0)

	_territory_manager.set_hex_owner(player_hex, "player")
	_territory_manager.set_hex_owner(wild_hex, "wild")

	# Verify initial state
	assert_eq(_territory_manager.get_territory_state(player_hex),
		TerritoryManager.TerritoryState.CLAIMED)
	assert_eq(_territory_manager.get_hex_owner(player_hex), "player")

	# Phase 1: Accumulate neglect
	watch_signals(EventBus)
	_territory_manager._update_single_hex_neglect(
		player_hex.to_vector(),
		TerritoryManager.NEGLECT_THRESHOLD + 1.0
	)
	await wait_frames(1)

	# Verify neglect state
	assert_eq(_territory_manager.get_territory_state(player_hex),
		TerritoryManager.TerritoryState.NEGLECTED,
		"Hex should be NEGLECTED after threshold")
	assert_signal_emitted(EventBus, "territory_neglected")

	# Phase 2: Start reclamation (adjacent to wild)
	_territory_manager._update_reclamation_timer(player_hex, player_hex.to_vector(), 1.0)
	await wait_frames(1)

	assert_signal_emitted(EventBus, "territory_reclamation_started")

	# Phase 3: Complete reclamation
	_territory_manager._update_reclamation_timer(
		player_hex,
		player_hex.to_vector(),
		TerritoryManager.RECLAMATION_TIME
	)
	await wait_frames(1)

	# Verify ownership changed
	assert_eq(_territory_manager.get_hex_owner(player_hex), "wild",
		"Hex should be owned by wild after reclamation")
	assert_signal_emitted(EventBus, "territory_reclaimed_by_wild")


func test_multiple_hexes_neglected_simultaneously() -> void:
	# Setup: Multiple player hexes
	var hexes: Array[HexCoord] = [
		HexCoord.create(0, 0),
		HexCoord.create(2, 2),
		HexCoord.create(4, 4)
	]

	for hex in hexes:
		_territory_manager.set_hex_owner(hex, "player")

	# All hexes accumulate neglect simultaneously
	for hex in hexes:
		_territory_manager._update_single_hex_neglect(
			hex.to_vector(),
			TerritoryManager.NEGLECT_THRESHOLD + 1.0
		)

	# Verify all hexes are NEGLECTED
	for hex in hexes:
		assert_eq(_territory_manager.get_territory_state(hex),
			TerritoryManager.TerritoryState.NEGLECTED,
			"All hexes should be NEGLECTED: %s" % hex.to_vector())


func test_activity_detection_across_entity_types() -> void:
	# This test validates that the activity detection structure supports
	# both buildings and animals. Without full game context, we verify
	# the function signature and behavior with no entities.

	var hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(hex, "player")

	# With no WorldManager initialized, activity check should return false
	# (no buildings or animals detectable)
	var has_activity := _territory_manager._check_activity_near_hex(hex)
	assert_false(has_activity, "No activity should be detected without entities")

	# Accumulate neglect
	_territory_manager._update_single_hex_neglect(hex.to_vector(), 100.0)

	# Timer should have accumulated
	var neglect_time: float = _territory_manager._neglect_timers.get(hex.to_vector(), 0.0)
	assert_gt(neglect_time, 0.0, "Neglect timer should accumulate without activity")


func test_staggered_processing_does_not_skip_hexes() -> void:
	# Create more hexes than MAX_HEXES_PER_FRAME to test batching
	var hex_count := TerritoryManager.MAX_HEXES_PER_FRAME * 3  # 45 hexes

	for i in hex_count:
		_territory_manager.set_hex_owner(HexCoord.create(i, 0), "player")

	# Rebuild hex list
	_territory_manager._rebuild_player_hex_list()
	assert_eq(_territory_manager._player_hex_list.size(), hex_count,
		"All player hexes should be in the list")

	# Process multiple batches
	var processed := 0
	_territory_manager._next_check_index = 0

	while _territory_manager._next_check_index < _territory_manager._player_hex_list.size():
		var start_index := _territory_manager._next_check_index
		_territory_manager._process_neglect_batch(1.0)
		processed += _territory_manager._next_check_index - start_index
		if _territory_manager._next_check_index == 0:
			# Cycle completed
			break

	# Verify all hexes were processed
	assert_eq(processed, hex_count, "All hexes should be processed across batches")


func test_reclamation_only_affects_border_hexes() -> void:
	# Create player territory surrounded by more player hexes
	# Center hex should NOT be reclaimable (not adjacent to wild)

	# Create a cluster of player hexes
	var center := HexCoord.create(0, 0)
	var neighbors := center.get_neighbors()

	_territory_manager.set_hex_owner(center, "player")
	for neighbor in neighbors:
		_territory_manager.set_hex_owner(neighbor, "player")

	# Make center hex NEGLECTED
	_territory_manager.set_territory_state(center, TerritoryManager.TerritoryState.NEGLECTED)

	# Check if center is adjacent to wild (should be false)
	assert_false(_territory_manager._is_adjacent_to_wild(center),
		"Center hex surrounded by player territory should not be adjacent to wild")

	# Try to start reclamation
	_territory_manager._update_reclamation_timer(center, center.to_vector(), 10.0)

	# Reclamation timer should NOT have started (no wild adjacent)
	var reclamation_time: float = _territory_manager._reclamation_timers.get(center.to_vector(), 0.0)
	assert_eq(reclamation_time, 0.0,
		"Reclamation should not start for hex not adjacent to wild")


func test_reclamation_can_happen_on_edge_hexes() -> void:
	# Create player territory with one edge adjacent to wild
	var edge_hex := HexCoord.create(0, 0)
	var interior_hex := HexCoord.create(1, 0)
	var wild_hex := HexCoord.create(-1, 0)

	_territory_manager.set_hex_owner(edge_hex, "player")
	_territory_manager.set_hex_owner(interior_hex, "player")
	_territory_manager.set_hex_owner(wild_hex, "wild")

	# Make edge hex NEGLECTED
	_territory_manager.set_territory_state(edge_hex, TerritoryManager.TerritoryState.NEGLECTED)

	# Edge hex IS adjacent to wild
	assert_true(_territory_manager._is_adjacent_to_wild(edge_hex),
		"Edge hex should be adjacent to wild")

	# Reclamation should be able to start
	_territory_manager._update_reclamation_timer(edge_hex, edge_hex.to_vector(), 10.0)

	var reclamation_time: float = _territory_manager._reclamation_timers.get(edge_hex.to_vector(), 0.0)
	assert_gt(reclamation_time, 0.0,
		"Reclamation should start for hex adjacent to wild")


func test_building_placed_resets_adjacent_neglect_timers() -> void:
	# AC4: Building placement should immediately reset neglect timers
	var hex := HexCoord.create(0, 0)
	var neighbor := HexCoord.create(1, 0)  # Adjacent hex

	# Set up player territory with neglect timers
	_territory_manager.set_hex_owner(hex, "player")
	_territory_manager.set_hex_owner(neighbor, "player")
	_territory_manager._neglect_timers[hex.to_vector()] = 250.0
	_territory_manager._neglect_timers[neighbor.to_vector()] = 180.0
	_territory_manager.set_territory_state(neighbor, TerritoryManager.TerritoryState.NEGLECTED)

	# Emit building_placed signal (simulate building placement)
	watch_signals(EventBus)
	EventBus.building_placed.emit(Node.new(), hex.to_vector())
	await wait_frames(1)

	# Both timers should be reset
	assert_false(_territory_manager._neglect_timers.has(hex.to_vector()),
		"Timer at building hex should be reset")
	assert_false(_territory_manager._neglect_timers.has(neighbor.to_vector()),
		"Timer at adjacent hex should be reset")

	# Neighbor should revert from NEGLECTED to CLAIMED
	assert_eq(_territory_manager.get_territory_state(neighbor),
		TerritoryManager.TerritoryState.CLAIMED,
		"Adjacent neglected hex should revert to CLAIMED on building activity")

	# Activity detected signal should be emitted
	assert_signal_emitted(EventBus, "territory_activity_detected")


func test_signal_order_in_reclamation_flow() -> void:
	# Verify signals are emitted in correct order:
	# 1. territory_neglected (when hex becomes neglected)
	# 2. territory_reclamation_started (when reclamation begins)
	# 3. territory_reclaimed_by_wild (when reclamation completes)

	var hex := HexCoord.create(0, 0)
	var wild_hex := HexCoord.create(1, 0)

	_territory_manager.set_hex_owner(hex, "player")
	_territory_manager.set_hex_owner(wild_hex, "wild")

	var signal_order: Array[String] = []

	# Connect to track signal order
	EventBus.territory_neglected.connect(func(_coord): signal_order.append("neglected"))
	EventBus.territory_reclamation_started.connect(func(_coord, _time): signal_order.append("reclamation_started"))
	EventBus.territory_reclaimed_by_wild.connect(func(_coord): signal_order.append("reclaimed"))

	# Step 1: Become neglected
	_territory_manager._update_single_hex_neglect(
		hex.to_vector(),
		TerritoryManager.NEGLECT_THRESHOLD + 1.0
	)
	await wait_frames(1)

	# Step 2: Start reclamation
	_territory_manager._update_reclamation_timer(hex, hex.to_vector(), 1.0)
	await wait_frames(1)

	# Step 3: Complete reclamation
	_territory_manager._reclamation_timers[hex.to_vector()] = TerritoryManager.RECLAMATION_TIME - 1.0
	_territory_manager._update_reclamation_timer(hex, hex.to_vector(), 2.0)
	await wait_frames(1)

	# Verify signal order
	assert_eq(signal_order.size(), 3, "Should have 3 signals emitted")
	if signal_order.size() >= 3:
		assert_eq(signal_order[0], "neglected", "First signal should be territory_neglected")
		assert_eq(signal_order[1], "reclamation_started", "Second signal should be territory_reclamation_started")
		assert_eq(signal_order[2], "reclaimed", "Third signal should be territory_reclaimed_by_wild")

	# Cleanup connections
	for connection in EventBus.territory_neglected.get_connections():
		EventBus.territory_neglected.disconnect(connection.callable)
	for connection in EventBus.territory_reclamation_started.get_connections():
		EventBus.territory_reclamation_started.disconnect(connection.callable)
	for connection in EventBus.territory_reclaimed_by_wild.get_connections():
		EventBus.territory_reclaimed_by_wild.disconnect(connection.callable)
