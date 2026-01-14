## Unit tests for Animal base class.
## Tests initialization, hex positioning, group membership, and lifecycle.
##
## Architecture: tests/unit/test_animal.gd
## Story: 2-1-create-animal-entity-structure
extends GutTest

# =============================================================================
# TEST DATA
# =============================================================================

var animal: Node3D
var mock_hex: HexCoord
var mock_stats: AnimalStats

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Create test data
	mock_hex = HexCoord.new(2, 3)

	mock_stats = AnimalStats.new()
	mock_stats.animal_id = "test_rabbit"
	mock_stats.energy = 3
	mock_stats.speed = 4
	mock_stats.strength = 2
	mock_stats.specialty = "Test specialty"
	mock_stats.biome = "plains"

	# Load animal scene
	var scene := preload("res://scenes/entities/animals/rabbit.tscn")
	animal = scene.instantiate()
	add_child(animal)
	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(animal) and not animal.is_queued_for_deletion():
		animal.queue_free()
		await wait_frames(1)  # Ensure node is freed before next test
	animal = null
	mock_hex = null
	mock_stats = null

# =============================================================================
# INITIALIZATION TESTS (AC1, AC3)
# =============================================================================

func test_animal_not_initialized_before_initialize() -> void:
	assert_false(animal.is_initialized(), "Animal should not be initialized before initialize() call")


func test_animal_initialize_sets_hex() -> void:
	animal.initialize(mock_hex, mock_stats)

	var stored_hex: HexCoord = animal.get_hex_coord()
	assert_eq(stored_hex.q, mock_hex.q, "Hex q should match")
	assert_eq(stored_hex.r, mock_hex.r, "Hex r should match")


func test_animal_initialize_sets_stats() -> void:
	animal.initialize(mock_hex, mock_stats)

	var stored_stats: AnimalStats = animal.get_stats()
	assert_eq(stored_stats.animal_id, "test_rabbit", "Animal ID should match")
	assert_eq(stored_stats.energy, 3, "Energy should match")


func test_animal_initialize_positions_at_hex() -> void:
	animal.initialize(mock_hex, mock_stats)

	var expected_pos := HexGrid.hex_to_world(mock_hex)
	assert_almost_eq(animal.position.x, expected_pos.x, 0.1, "X position should match hex world pos")
	assert_almost_eq(animal.position.z, expected_pos.z, 0.1, "Z position should match hex world pos")


func test_animal_is_initialized_after_initialize() -> void:
	animal.initialize(mock_hex, mock_stats)

	assert_true(animal.is_initialized(), "Animal should be initialized after initialize() call")


func test_double_initialize_does_not_crash() -> void:
	animal.initialize(mock_hex, mock_stats)
	animal.initialize(mock_hex, mock_stats)  # Second call should warn but not crash

	# Animal should still be initialized
	assert_true(animal.is_initialized(), "Animal should remain initialized after double init")


func test_animal_position_y_is_zero() -> void:
	animal.initialize(mock_hex, mock_stats)

	assert_almost_eq(animal.position.y, 0.0, 0.01, "Y position should be 0 (ground plane)")


func test_initialize_with_null_hex_does_not_crash() -> void:
	# Should handle null gracefully
	animal.initialize(null, mock_stats)

	assert_true(animal.is_initialized(), "Should initialize even with null hex")


func test_initialize_with_null_stats_does_not_crash() -> void:
	# Should handle null gracefully
	animal.initialize(mock_hex, null)

	assert_true(animal.is_initialized(), "Should initialize even with null stats")

# =============================================================================
# GROUP MEMBERSHIP TESTS (AC6)
# =============================================================================

func test_animal_in_animals_group() -> void:
	assert_true(animal.is_in_group("animals"), "Animal should be in 'animals' group")


func test_animal_queryable_via_group() -> void:
	animal.initialize(mock_hex, mock_stats)

	var animals := get_tree().get_nodes_in_group("animals")
	assert_has(animals, animal, "Animal should be queryable via group")

# =============================================================================
# EVENT BUS TESTS (AC7)
# =============================================================================

func test_animal_spawned_signal_emitted() -> void:
	watch_signals(EventBus)

	animal.initialize(mock_hex, mock_stats)

	assert_signal_emitted(EventBus, "animal_spawned")


func test_animal_spawned_signal_contains_animal() -> void:
	watch_signals(EventBus)

	animal.initialize(mock_hex, mock_stats)

	var params: Array = get_signal_parameters(EventBus, "animal_spawned")
	assert_eq(params[0], animal, "Signal should contain the animal instance")


func test_animal_removed_signal_emitted_on_cleanup() -> void:
	animal.initialize(mock_hex, mock_stats)
	watch_signals(EventBus)

	animal.cleanup()

	assert_signal_emitted(EventBus, "animal_removed")


func test_animal_removed_signal_not_emitted_if_not_initialized() -> void:
	watch_signals(EventBus)

	# Don't initialize, just cleanup
	animal.cleanup()

	assert_signal_not_emitted(EventBus, "animal_removed")

# =============================================================================
# PUBLIC API TESTS
# =============================================================================

func test_get_animal_id_returns_stats_id() -> void:
	animal.initialize(mock_hex, mock_stats)

	assert_eq(animal.get_animal_id(), "test_rabbit", "get_animal_id should return stats animal_id")


func test_get_animal_id_returns_empty_when_no_stats() -> void:
	animal.initialize(mock_hex, null)

	assert_eq(animal.get_animal_id(), "", "get_animal_id should return empty string when no stats")


func test_to_string_includes_animal_id() -> void:
	animal.initialize(mock_hex, mock_stats)

	var str_repr := str(animal)
	assert_true(str_repr.contains("test_rabbit"), "String should contain animal_id")


func test_to_string_shows_uninitialized() -> void:
	var str_repr := str(animal)
	assert_true(str_repr.contains("uninitialized"), "String should indicate uninitialized state")

# =============================================================================
# CLEANUP TESTS
# =============================================================================

func test_cleanup_removes_from_group() -> void:
	animal.initialize(mock_hex, mock_stats)
	animal.cleanup()
	await wait_frames(1)

	var animals := get_tree().get_nodes_in_group("animals")
	assert_does_not_have(animals, animal, "Animal should be removed from group after cleanup")


func test_cleanup_clears_references() -> void:
	animal.initialize(mock_hex, mock_stats)
	animal.cleanup()

	# After cleanup, references should be null
	assert_null(animal.hex_coord, "hex_coord should be null after cleanup")
	assert_null(animal.stats, "stats should be null after cleanup")

# =============================================================================
# SCENE STRUCTURE TESTS (AC2)
# =============================================================================

func test_animal_has_visual_node() -> void:
	assert_true(animal.has_node("Visual"), "Animal should have Visual node")


func test_animal_has_selectable_component() -> void:
	assert_true(animal.has_node("SelectableComponent"), "Animal should have SelectableComponent")


func test_animal_has_movement_component() -> void:
	assert_true(animal.has_node("MovementComponent"), "Animal should have MovementComponent")


func test_animal_has_stats_component() -> void:
	assert_true(animal.has_node("StatsComponent"), "Animal should have StatsComponent")


func test_animal_is_node3d() -> void:
	assert_true(animal is Node3D, "Animal should extend Node3D")

# =============================================================================
# COMPONENT INTEGRATION TESTS
# =============================================================================

func test_selectable_component_has_script() -> void:
	var selectable := animal.get_node("SelectableComponent")
	assert_not_null(selectable.get_script(), "SelectableComponent should have script attached")


func test_movement_component_has_script() -> void:
	var movement := animal.get_node("MovementComponent")
	assert_not_null(movement.get_script(), "MovementComponent should have script attached")


func test_stats_component_has_script() -> void:
	var stats_comp := animal.get_node("StatsComponent")
	assert_not_null(stats_comp.get_script(), "StatsComponent should have script attached")


func test_stats_component_initialized_with_animal_stats() -> void:
	animal.initialize(mock_hex, mock_stats)
	await wait_frames(1)

	var stats_comp: Node = animal.get_node("StatsComponent")
	if stats_comp.has_method("get_base_stats"):
		var base_stats: AnimalStats = stats_comp.get_base_stats()
		assert_eq(base_stats, mock_stats, "StatsComponent should have animal's stats")
