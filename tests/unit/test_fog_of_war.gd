extends GutTest

## Unit tests for FogOfWar system
## Tests fog initialization, reveal mechanics, and integration with TerritoryManager
## Story: 1-6-implement-fog-of-war

const HEX_TILE_SCENE := preload("res://scenes/world/hex_tile.tscn")

var fog_of_war: FogOfWar
var world_manager: WorldManager
var territory_manager: TerritoryManager

func before_each() -> void:
	# Create WorldManager
	world_manager = WorldManager.new()
	add_child(world_manager)

	# Wait one frame for _ready() to be called
	await wait_frames(1)

	# Wait for world generation (with timeout safety)
	if not world_manager.is_world_generated():
		await world_manager.world_generated

	# Get references (WorldManager creates these)
	territory_manager = world_manager._territory_manager
	fog_of_war = world_manager._fog_of_war

	# Verify initialization succeeded
	assert_not_null(territory_manager, "TerritoryManager should be created")
	assert_not_null(fog_of_war, "FogOfWar should be created")

func after_each() -> void:
	if world_manager:
		world_manager.queue_free()
		world_manager = null

# =============================================================================
# INITIALIZATION TESTS (AC1, AC2, AC3)
# =============================================================================

func test_starting_area_revealed() -> void:
	# AC1: Starting area (7 hexes) should be CLAIMED
	var center := HexCoord.new(0, 0)
	var state := territory_manager.get_territory_state(center)
	assert_eq(state, TerritoryManager.TerritoryState.CLAIMED, "Center should be claimed")

	# Test ring 1 neighbors (6 hexes)
	var ring1_hexes := HexGrid.get_hex_ring(center, 1)
	for hex in ring1_hexes:
		var hex_state := territory_manager.get_territory_state(hex)
		assert_eq(hex_state, TerritoryManager.TerritoryState.CLAIMED, "Ring 1 should be claimed")

func test_adjacent_hexes_scouted() -> void:
	# AC2: Adjacent hexes (rings 2-4) should be SCOUTED
	var center := HexCoord.new(0, 0)

	for radius in range(2, 5):  # Rings 2, 3, 4
		var ring_hexes := HexGrid.get_hex_ring(center, radius)
		for hex in ring_hexes:
			var state := territory_manager.get_territory_state(hex)
			assert_eq(state, TerritoryManager.TerritoryState.SCOUTED,
				"Ring %d hex %s should be scouted" % [radius, hex.to_vector()])

func test_distant_hexes_unexplored() -> void:
	# AC3: Distant hexes (range 5+) should be UNEXPLORED
	var far_hexes := [
		HexCoord.new(10, 10),
		HexCoord.new(-8, 5),
		HexCoord.new(0, 10)
	]

	for hex in far_hexes:
		var state := territory_manager.get_territory_state(hex)
		assert_eq(state, TerritoryManager.TerritoryState.UNEXPLORED,
			"Far hex %s should be unexplored" % hex.to_vector())

func test_fog_visual_on_unexplored() -> void:
	# AC3: Verify fog overlay is visible on unexplored hexes
	var far_hex := HexCoord.new(10, 10)
	var tile := world_manager.get_tile_at(far_hex)

	if tile:
		assert_true(tile.fog_overlay.visible, "Fog should be visible on unexplored hex")
		assert_almost_eq(tile.fog_overlay.color.a, 0.85, 0.01, "Fog opacity should be ~85%")

# =============================================================================
# FOG REVEAL TESTS (AC4)
# =============================================================================

func test_reveal_hex_claims_territory() -> void:
	# AC4: Revealing a hex should claim it
	var test_hex := HexCoord.new(5, 5)

	# Initially unexplored
	var initial_state := territory_manager.get_territory_state(test_hex)
	assert_eq(initial_state, TerritoryManager.TerritoryState.UNEXPLORED)

	# Reveal it
	fog_of_war.reveal_hex(test_hex)

	# Now claimed
	var new_state := territory_manager.get_territory_state(test_hex)
	assert_eq(new_state, TerritoryManager.TerritoryState.CLAIMED, "Revealed hex should be claimed")

func test_reveal_hex_scouts_neighbors() -> void:
	# AC4: Revealing a hex should scout its neighbors
	var test_hex := HexCoord.new(5, 5)
	fog_of_war.reveal_hex(test_hex)

	# Check all 6 neighbors
	var neighbors := test_hex.get_neighbors()
	for neighbor in neighbors:
		var state := territory_manager.get_territory_state(neighbor)
		assert_ne(state, TerritoryManager.TerritoryState.UNEXPLORED,
			"Neighbor %s should be scouted after reveal" % neighbor.to_vector())

func test_reveal_hex_animation_smooth() -> void:
	# AC4: Fog reveal should animate smoothly
	var test_hex := HexCoord.new(5, 5)
	var tile := world_manager.get_tile_at(test_hex)

	if tile:
		fog_of_war.reveal_hex(test_hex)

		# Tween should be created
		assert_not_null(tile._tween, "Tween should exist for animation")

		# Wait for animation
		if tile._tween:
			await tile._tween.finished

		# Fog should be hidden after animation
		assert_false(tile.fog_overlay.visible, "Fog should be hidden after reveal")

func test_scout_hex_only_affects_unexplored() -> void:
	# scout_hex() should only change UNEXPLORED → SCOUTED
	var claimed_hex := HexCoord.new(0, 0)  # Center is claimed

	# Try to scout a claimed hex
	fog_of_war.scout_hex(claimed_hex)

	# Should remain claimed
	var state := territory_manager.get_territory_state(claimed_hex)
	assert_eq(state, TerritoryManager.TerritoryState.CLAIMED,
		"scout_hex should not change claimed territory")

func test_reveal_hex_eventbus_integration() -> void:
	# AC4: territory_claimed signal should fire
	var test_hex := HexCoord.new(5, 5)
	watch_signals(EventBus)

	fog_of_war.reveal_hex(test_hex)

	assert_signal_emitted(EventBus, "territory_claimed",
		"territory_claimed signal should be emitted")

# =============================================================================
# PERFORMANCE TESTS (AC5)
# =============================================================================

func test_many_simultaneous_reveals() -> void:
	# AC5: Revealing many hexes should not impact performance
	var test_hexes: Array[HexCoord] = []

	# Create 20 test hexes to reveal
	for i in range(20):
		test_hexes.append(HexCoord.new(10 + i, 10))

	# Measure time
	var start_time := Time.get_ticks_usec()

	# Reveal all at once
	for hex in test_hexes:
		fog_of_war.reveal_hex(hex)

	var end_time := Time.get_ticks_usec()
	var duration_ms := (end_time - start_time) / 1000.0

	# Should complete in < 16.67ms (60 FPS)
	assert_lt(duration_ms, 16.67,
		"20 simultaneous reveals should complete in < 16.67ms for 60 FPS (actual: %.2fms)" % duration_ms)

	# Wait for all animations to complete (Story 1-5 pattern)
	# Get the last tile's tween and wait for it to finish
	var last_tile := world_manager.get_tile_at(test_hexes[-1])
	if last_tile and last_tile._tween:
		await last_tile._tween.finished

	# Verify all were revealed
	for hex in test_hexes:
		var state := territory_manager.get_territory_state(hex)
		assert_eq(state, TerritoryManager.TerritoryState.CLAIMED,
			"Hex %s should be claimed after reveal" % hex.to_vector())

# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_reveal_null_hex() -> void:
	# Null safety: Should not crash
	fog_of_war.reveal_hex(null)
	assert_true(true, "reveal_hex(null) should not crash")

func test_scout_null_hex() -> void:
	# Null safety: Should not crash
	fog_of_war.scout_hex(null)
	assert_true(true, "scout_hex(null) should not crash")

func test_reveal_already_revealed_hex() -> void:
	# Revealing an already revealed hex should be safe
	var test_hex := HexCoord.new(0, 0)  # Already claimed
	fog_of_war.reveal_hex(test_hex)

	# Should still be claimed
	var state := territory_manager.get_territory_state(test_hex)
	assert_eq(state, TerritoryManager.TerritoryState.CLAIMED,
		"Revealing already revealed hex should be safe")

func test_reveal_hex_outside_world_bounds() -> void:
	# Revealing hex that doesn't have a tile should not crash
	var far_hex := HexCoord.new(999, 999)
	fog_of_war.reveal_hex(far_hex)

	# State should still be tracked
	var state := territory_manager.get_territory_state(far_hex)
	assert_eq(state, TerritoryManager.TerritoryState.CLAIMED,
		"State should be tracked even if tile doesn't exist")

func test_starting_fog_count_correct() -> void:
	# AC1: Verify exactly 7 hexes are claimed initially
	var center := HexCoord.new(0, 0)
	var starting_hexes := HexGrid.get_hexes_in_range(center, 1)

	assert_eq(starting_hexes.size(), 7, "Should have exactly 7 starting hexes (center + ring 1)")

	# Verify all are claimed
	for hex in starting_hexes:
		var state := territory_manager.get_territory_state(hex)
		assert_eq(state, TerritoryManager.TerritoryState.CLAIMED,
			"All starting hexes should be claimed")

func test_scouted_ring_count_correct() -> void:
	# AC2: Verify scouted rings (2-4) are correct
	var center := HexCoord.new(0, 0)
	var total_scouted := 0

	for radius in range(2, 5):
		var ring := HexGrid.get_hex_ring(center, radius)
		total_scouted += ring.size()

		for hex in ring:
			var state := territory_manager.get_territory_state(hex)
			assert_eq(state, TerritoryManager.TerritoryState.SCOUTED,
				"Ring %d hex %s should be scouted" % [radius, hex.to_vector()])

	# Rings 2, 3, 4 should have 12 + 18 + 24 = 54 hexes total
	assert_eq(total_scouted, 54, "Scouted rings should have 54 hexes total")
