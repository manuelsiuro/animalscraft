## Unit tests for WildHerdManager.
## Tests herd spawning, data retrieval, territory integration, and cleanup.
##
## Story: 5-2-spawn-wild-animal-herds
## Architecture: tests/unit/test_wild_herd_manager.gd
extends GutTest

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _wild_herd_manager: WildHerdManager
var _world_manager: WorldManager

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Create WorldManager which will create WildHerdManager
	_world_manager = WorldManager.new()
	add_child(_world_manager)
	await wait_frames(1)

	# Wait for world generation
	if not _world_manager.is_world_generated():
		await _world_manager.world_generated

	# Get WildHerdManager reference
	_wild_herd_manager = _world_manager._wild_herd_manager
	assert_not_null(_wild_herd_manager, "WildHerdManager should be created by WorldManager")


func after_each() -> void:
	if _world_manager:
		_world_manager.queue_free()
		_world_manager = null
		_wild_herd_manager = null

# =============================================================================
# INITIALIZATION TESTS (AC: 1)
# =============================================================================

func test_wild_herd_manager_created_by_world_manager() -> void:
	assert_not_null(_wild_herd_manager, "WildHerdManager should exist")
	assert_true(_wild_herd_manager.is_in_group("wild_herd_managers"))


func test_initial_herd_count_is_zero() -> void:
	assert_eq(_wild_herd_manager.get_herd_count(), 0, "Initial herd count should be 0")


func test_initial_total_wild_animals_is_zero() -> void:
	assert_eq(_wild_herd_manager.get_total_wild_animals(), 0, "Initial wild animal count should be 0")

# =============================================================================
# HERD SPAWNING TESTS (AC: 4, 5, 6)
# =============================================================================

func test_spawn_herd_creates_herd_with_animals() -> void:
	var hex := HexCoord.create(5, 5)
	var herd := _wild_herd_manager.spawn_herd(hex, 3)

	assert_not_null(herd, "Herd should be created")
	assert_eq(herd.get_animal_count(), 3, "Herd should have 3 animals")
	assert_eq(herd.owner_id, "wild", "Default owner should be 'wild'")


func test_spawn_herd_with_custom_owner() -> void:
	var hex := HexCoord.create(6, 6)
	var herd := _wild_herd_manager.spawn_herd(hex, 2, "camp_1")

	assert_not_null(herd)
	assert_eq(herd.owner_id, "camp_1")


func test_spawn_herd_clamps_size_to_minimum() -> void:
	var hex := HexCoord.create(7, 7)
	var herd := _wild_herd_manager.spawn_herd(hex, 1)

	assert_not_null(herd)
	assert_eq(herd.get_animal_count(), 2, "Herd size should be clamped to minimum 2")


func test_spawn_herd_clamps_size_to_maximum() -> void:
	var hex := HexCoord.create(8, 8)
	var herd := _wild_herd_manager.spawn_herd(hex, 10)

	assert_not_null(herd)
	assert_eq(herd.get_animal_count(), 5, "Herd size should be clamped to maximum 5")


func test_spawn_herd_null_hex_returns_null() -> void:
	var herd := _wild_herd_manager.spawn_herd(null, 3)
	assert_null(herd, "Should return null for null hex")


func test_spawn_herd_duplicate_hex_returns_null() -> void:
	var hex := HexCoord.create(9, 9)
	var herd1 := _wild_herd_manager.spawn_herd(hex, 3)
	var herd2 := _wild_herd_manager.spawn_herd(hex, 3)

	assert_not_null(herd1)
	assert_null(herd2, "Should not allow duplicate herds at same hex")


func test_spawn_herd_generates_unique_id() -> void:
	var herd1 := _wild_herd_manager.spawn_herd(HexCoord.create(10, 10), 2)
	var herd2 := _wild_herd_manager.spawn_herd(HexCoord.create(11, 11), 2)

	assert_ne(herd1.herd_id, herd2.herd_id, "Herds should have unique IDs")


func test_spawn_herd_increments_herd_count() -> void:
	assert_eq(_wild_herd_manager.get_herd_count(), 0)

	_wild_herd_manager.spawn_herd(HexCoord.create(12, 12), 2)
	assert_eq(_wild_herd_manager.get_herd_count(), 1)

	_wild_herd_manager.spawn_herd(HexCoord.create(13, 13), 2)
	assert_eq(_wild_herd_manager.get_herd_count(), 2)

# =============================================================================
# HERD DATA RETRIEVAL TESTS (AC: 2, 3)
# =============================================================================

func test_get_herd_by_id() -> void:
	var hex := HexCoord.create(14, 14)
	var created_herd := _wild_herd_manager.spawn_herd(hex, 3)

	var retrieved_herd := _wild_herd_manager.get_herd(created_herd.herd_id)
	assert_not_null(retrieved_herd)
	assert_eq(retrieved_herd.herd_id, created_herd.herd_id)


func test_get_herd_invalid_id_returns_null() -> void:
	var herd := _wild_herd_manager.get_herd("nonexistent_id")
	assert_null(herd)


func test_get_herd_at_hex() -> void:
	var hex := HexCoord.create(15, 15)
	var created_herd := _wild_herd_manager.spawn_herd(hex, 3)

	var retrieved_herd := _wild_herd_manager.get_herd_at(hex)
	assert_not_null(retrieved_herd)
	assert_eq(retrieved_herd.herd_id, created_herd.herd_id)


func test_get_herd_at_empty_hex_returns_null() -> void:
	var hex := HexCoord.create(100, 100)
	var herd := _wild_herd_manager.get_herd_at(hex)
	assert_null(herd)


func test_get_herd_at_null_returns_null() -> void:
	var herd := _wild_herd_manager.get_herd_at(null)
	assert_null(herd)


func test_get_total_wild_animals_accurate() -> void:
	_wild_herd_manager.spawn_herd(HexCoord.create(16, 16), 3)
	_wild_herd_manager.spawn_herd(HexCoord.create(17, 17), 2)

	assert_eq(_wild_herd_manager.get_total_wild_animals(), 5)


func test_get_herds_in_range() -> void:
	var center := HexCoord.create(20, 20)
	var nearby := HexCoord.create(21, 20)  # Distance 1
	var far := HexCoord.create(30, 30)  # Distance 10

	_wild_herd_manager.spawn_herd(nearby, 2)
	_wild_herd_manager.spawn_herd(far, 2)

	var herds_in_range := _wild_herd_manager.get_herds_in_range(center, 2)
	assert_eq(herds_in_range.size(), 1, "Should find 1 herd within range 2")


func test_get_herds_in_range_empty_when_none() -> void:
	var center := HexCoord.create(25, 25)
	var far := HexCoord.create(50, 50)

	_wild_herd_manager.spawn_herd(far, 2)

	var herds_in_range := _wild_herd_manager.get_herds_in_range(center, 5)
	assert_eq(herds_in_range.size(), 0)


func test_get_herds_in_range_null_center() -> void:
	_wild_herd_manager.spawn_herd(HexCoord.create(26, 26), 2)

	var herds := _wild_herd_manager.get_herds_in_range(null, 5)
	assert_eq(herds.size(), 0)


func test_get_herds_in_range_negative_radius() -> void:
	_wild_herd_manager.spawn_herd(HexCoord.create(27, 27), 2)

	var herds := _wild_herd_manager.get_herds_in_range(HexCoord.create(27, 27), -1)
	assert_eq(herds.size(), 0)

# =============================================================================
# WILD HERD CLASS TESTS (AC: 2)
# =============================================================================

func test_wild_herd_get_total_strength() -> void:
	var hex := HexCoord.create(28, 28)
	var herd := _wild_herd_manager.spawn_herd(hex, 3)

	# Wait for animal initialization
	await wait_frames(2)

	# Each rabbit has strength (from stats)
	var strength := herd.get_total_strength()
	assert_gt(strength, 0, "Herd should have positive total strength")


func test_wild_herd_get_animal_types() -> void:
	var hex := HexCoord.create(29, 29)
	var herd := _wild_herd_manager.spawn_herd(hex, 3)

	# Wait for animal initialization
	await wait_frames(2)

	var types := herd.get_animal_types()
	assert_eq(types.size(), 3, "Should have 3 animal types listed")
	# All should be rabbits currently
	for animal_type in types:
		assert_eq(animal_type, "rabbit")

# =============================================================================
# HERD REMOVAL TESTS (AC: 10)
# =============================================================================

func test_remove_herd_removes_from_lookup() -> void:
	var hex := HexCoord.create(30, 30)
	var herd := _wild_herd_manager.spawn_herd(hex, 3)
	var herd_id := herd.herd_id

	assert_eq(_wild_herd_manager.get_herd_count(), 1)

	_wild_herd_manager.remove_herd(herd_id)

	assert_eq(_wild_herd_manager.get_herd_count(), 0)
	assert_null(_wild_herd_manager.get_herd(herd_id))


func test_remove_herd_clears_hex_lookup() -> void:
	var hex := HexCoord.create(31, 31)
	var herd := _wild_herd_manager.spawn_herd(hex, 3)

	_wild_herd_manager.remove_herd(herd.herd_id)

	assert_null(_wild_herd_manager.get_herd_at(hex))


func test_remove_nonexistent_herd_does_not_crash() -> void:
	_wild_herd_manager.remove_herd("nonexistent_herd")
	assert_true(true, "Removing nonexistent herd should not crash")


func test_remove_herd_decrements_animal_count() -> void:
	_wild_herd_manager.spawn_herd(HexCoord.create(32, 32), 3)
	_wild_herd_manager.spawn_herd(HexCoord.create(33, 33), 2)

	assert_eq(_wild_herd_manager.get_total_wild_animals(), 5)

	var herd := _wild_herd_manager.get_herd_at(HexCoord.create(32, 32))
	_wild_herd_manager.remove_herd(herd.herd_id)

	assert_eq(_wild_herd_manager.get_total_wild_animals(), 2)

# =============================================================================
# TERRITORY INTEGRATION TESTS (AC: 8, 9)
# =============================================================================

func test_spawn_herd_sets_territory_ownership() -> void:
	var hex := HexCoord.create(34, 34)
	_wild_herd_manager.spawn_herd(hex, 3)

	var territory_manager := _world_manager._territory_manager
	assert_eq(territory_manager.get_hex_owner(hex), "wild")


func test_spawn_herd_with_camp_owner_sets_correct_ownership() -> void:
	var hex := HexCoord.create(35, 35)
	_wild_herd_manager.spawn_herd(hex, 3, "camp_2")

	var territory_manager := _world_manager._territory_manager
	assert_eq(territory_manager.get_hex_owner(hex), "camp_2")


func test_territory_ownership_change_removes_herd() -> void:
	var hex := HexCoord.create(36, 36)
	var herd := _wild_herd_manager.spawn_herd(hex, 3)
	var herd_id := herd.herd_id

	assert_eq(_wild_herd_manager.get_herd_count(), 1)

	# Simulate player claiming the territory
	var territory_manager := _world_manager._territory_manager
	territory_manager.set_hex_owner(hex, "player", "combat")

	# Herd should be removed
	assert_eq(_wild_herd_manager.get_herd_count(), 0)
	assert_null(_wild_herd_manager.get_herd(herd_id))


func test_contested_hex_with_wild_herd() -> void:
	var player_hex := HexCoord.create(0, 0)
	var wild_hex := HexCoord.create(1, 0)  # Adjacent to player

	var territory_manager := _world_manager._territory_manager

	# Explicitly set player ownership (in case not already set by fog of war)
	territory_manager.set_hex_owner(player_hex, "player")

	# Spawn wild herd at adjacent hex
	_wild_herd_manager.spawn_herd(wild_hex, 3)

	# Verify wild ownership was set
	assert_eq(territory_manager.get_hex_owner(wild_hex), "wild", "Wild herd should set hex ownership to wild")
	assert_true(territory_manager.is_contested(wild_hex), "Wild herd hex adjacent to player should be contested")

# =============================================================================
# EVENTBUS SIGNAL TESTS (AC: 16, 17)
# =============================================================================

func test_spawn_herd_emits_signal() -> void:
	watch_signals(EventBus)
	var hex := HexCoord.create(37, 37)

	_wild_herd_manager.spawn_herd(hex, 3)

	assert_signal_emitted(EventBus, "wild_herd_spawned")


func test_spawn_herd_signal_parameters() -> void:
	watch_signals(EventBus)
	var hex := HexCoord.create(38, 38)

	var herd := _wild_herd_manager.spawn_herd(hex, 3)

	assert_signal_emitted_with_parameters(
		EventBus,
		"wild_herd_spawned",
		[herd.herd_id, Vector2i(38, 38), 3]
	)


func test_remove_herd_emits_signal() -> void:
	var hex := HexCoord.create(39, 39)
	var herd := _wild_herd_manager.spawn_herd(hex, 3)

	watch_signals(EventBus)
	_wild_herd_manager.remove_herd(herd.herd_id)

	assert_signal_emitted(EventBus, "wild_herd_removed")


func test_remove_herd_signal_parameters() -> void:
	var hex := HexCoord.create(40, 40)
	var herd := _wild_herd_manager.spawn_herd(hex, 3)
	var herd_id := herd.herd_id

	watch_signals(EventBus)
	_wild_herd_manager.remove_herd(herd_id)

	assert_signal_emitted_with_parameters(
		EventBus,
		"wild_herd_removed",
		[herd_id, Vector2i(40, 40)]
	)

# =============================================================================
# HERD COMPOSITION TESTS (AC: 5)
# =============================================================================

func test_herd_composition_uses_biome_animals() -> void:
	var hex := HexCoord.create(41, 41)
	var herd := _wild_herd_manager.spawn_herd(hex, 3)

	# Wait for animal initialization
	await wait_frames(2)

	# All animals should be from PLAINS_ANIMALS
	for animal in herd.animals:
		assert_not_null(animal)
		# Currently only rabbit is available
		assert_eq(animal.get_animal_id(), "rabbit")


func test_herd_composition_size_matches_request() -> void:
	for size in [2, 3, 4, 5]:
		var hex := HexCoord.create(42 + size, 42 + size)
		var herd := _wild_herd_manager.spawn_herd(hex, size)
		assert_eq(herd.get_animal_count(), size)

# =============================================================================
# VISUAL OFFSET TESTS (AC: 6)
# =============================================================================

func test_visual_offsets_count_matches_herd_size() -> void:
	var offsets := _wild_herd_manager._calculate_visual_offsets(4)
	assert_eq(offsets.size(), 4)


func test_visual_offsets_are_on_ground_plane() -> void:
	var offsets := _wild_herd_manager._calculate_visual_offsets(3)
	for offset in offsets:
		assert_eq(offset.y, 0.0, "Offsets should be on ground plane (Y=0)")

# =============================================================================
# DIFFICULTY SCALING TESTS (AC: 7)
# =============================================================================

func test_difficulty_scaling_near_player() -> void:
	var player_hex := HexCoord.create(0, 0)
	var nearby_hex := HexCoord.create(4, 0)  # Distance 4

	var size := _wild_herd_manager._calculate_herd_size_for_distance(nearby_hex, player_hex)
	assert_gte(size, 2)
	assert_lte(size, 3, "Nearby herds should be small (2-3)")


func test_difficulty_scaling_far_from_player() -> void:
	var player_hex := HexCoord.create(0, 0)
	var far_hex := HexCoord.create(15, 0)  # Distance 15

	var size := _wild_herd_manager._calculate_herd_size_for_distance(far_hex, player_hex)
	assert_eq(size, 5, "Distant herds should be maximum size")


func test_herd_strength_scales_with_distance() -> void:
	var player_hex := HexCoord.create(0, 0)
	var near_strength := _wild_herd_manager._calculate_herd_strength(HexCoord.create(3, 0), player_hex)
	var far_strength := _wild_herd_manager._calculate_herd_strength(HexCoord.create(12, 0), player_hex)

	# Far herds should generally be stronger (though there's randomness)
	# We check the ranges overlap correctly
	assert_gte(near_strength, 4)
	assert_lte(near_strength, 8)
	assert_gte(far_strength, 18)

# =============================================================================
# INITIAL HERDS SPAWNING TESTS (AC: 4)
# =============================================================================

func test_spawn_initial_herds_creates_herds() -> void:
	var player_hex := HexCoord.create(0, 0)

	# Clear any existing herds
	for herd_id in _wild_herd_manager.get_all_herd_ids():
		_wild_herd_manager.remove_herd(herd_id)

	# Wait for cleanup
	await wait_frames(1)

	_wild_herd_manager.spawn_initial_herds(player_hex)

	# Wait for herds to spawn
	await wait_frames(2)

	# With starting range 3 and min spawn distance 2, should find some valid hexes
	var herd_count := _wild_herd_manager.get_herd_count()
	assert_gt(herd_count, 0, "Should spawn some initial herds (found %d)" % herd_count)


func test_spawn_initial_herds_not_adjacent_to_player() -> void:
	var player_hex := HexCoord.create(0, 0)

	# Clear any existing herds
	for herd_id in _wild_herd_manager.get_all_herd_ids():
		_wild_herd_manager.remove_herd(herd_id)

	# Wait for cleanup
	await wait_frames(1)

	_wild_herd_manager.spawn_initial_herds(player_hex)

	# Wait for herds to spawn
	await wait_frames(2)

	# Check no herds are within MIN_SPAWN_DISTANCE - 1 of player start
	# MIN_SPAWN_DISTANCE is 2, so we check range 1 (immediate neighbors)
	var close_herds := _wild_herd_manager.get_herds_in_range(player_hex, 1)
	assert_eq(close_herds.size(), 0, "No herds should spawn within 1 hex of player")


func test_spawn_initial_herds_with_null_does_not_crash() -> void:
	_wild_herd_manager.spawn_initial_herds(null)
	assert_true(true, "Should not crash with null player hex")

# =============================================================================
# SIGNAL CLEANUP TESTS (AR18)
# =============================================================================

func test_exit_tree_disconnects_signals() -> void:
	# Create a standalone manager for this test
	var manager := WildHerdManager.new()
	add_child(manager)
	await wait_frames(1)

	# Verify signal is connected
	assert_true(EventBus.territory_ownership_changed.is_connected(manager._on_territory_ownership_changed))

	# Simulate exit tree
	manager._exit_tree()

	# Verify signal is disconnected
	assert_false(EventBus.territory_ownership_changed.is_connected(manager._on_territory_ownership_changed))

	manager.queue_free()

# =============================================================================
# PERFORMANCE TESTS (AC: 18, 19)
# =============================================================================

func test_herd_lookup_performance() -> void:
	# Spawn 30 herds (max per biome)
	for i in range(30):
		var hex := HexCoord.create(50 + i, 50 + i)
		_wild_herd_manager.spawn_herd(hex, 3)

	assert_eq(_wild_herd_manager.get_herd_count(), 30)

	# Measure lookup performance
	var start_time := Time.get_ticks_usec()

	for _i in range(1000):
		var _herd := _wild_herd_manager.get_herd_at(HexCoord.create(60, 60))

	var elapsed_usec := Time.get_ticks_usec() - start_time
	var avg_usec := elapsed_usec / 1000.0

	# Should be O(1) lookup, well under 1ms
	assert_lt(avg_usec, 100.0, "Herd lookup should be fast (was %f usec)" % avg_usec)


func test_herd_count_methods_performance() -> void:
	# Spawn herds
	for i in range(20):
		var hex := HexCoord.create(80 + i, 80 + i)
		_wild_herd_manager.spawn_herd(hex, 3)

	var start_time := Time.get_ticks_usec()

	for _i in range(100):
		var _count := _wild_herd_manager.get_herd_count()
		var _total := _wild_herd_manager.get_total_wild_animals()

	var elapsed_usec := Time.get_ticks_usec() - start_time
	var avg_usec := elapsed_usec / 100.0

	assert_lt(avg_usec, 1000.0, "Count methods should complete under 1ms (was %f usec)" % avg_usec)


func test_max_herds_per_biome_enforced() -> void:
	# Spawn exactly MAX_HERDS_PER_BIOME herds
	for i in range(WildHerdManager.MAX_HERDS_PER_BIOME):
		var hex := HexCoord.create(100 + i, 100 + i)
		var herd := _wild_herd_manager.spawn_herd(hex, 2)
		assert_not_null(herd, "Herd %d should spawn" % i)

	assert_eq(_wild_herd_manager.get_herd_count(), WildHerdManager.MAX_HERDS_PER_BIOME)

	# Try to spawn one more - should fail
	var extra_hex := HexCoord.create(200, 200)
	var extra_herd := _wild_herd_manager.spawn_herd(extra_hex, 2)

	assert_null(extra_herd, "Should not allow spawning beyond MAX_HERDS_PER_BIOME")
	assert_eq(_wild_herd_manager.get_herd_count(), WildHerdManager.MAX_HERDS_PER_BIOME)

# =============================================================================
# ALL HERD IDS HELPER TEST
# =============================================================================

func test_get_all_herd_ids() -> void:
	_wild_herd_manager.spawn_herd(HexCoord.create(90, 90), 2)
	_wild_herd_manager.spawn_herd(HexCoord.create(91, 91), 2)

	var ids := _wild_herd_manager.get_all_herd_ids()
	assert_eq(ids.size(), 2)
