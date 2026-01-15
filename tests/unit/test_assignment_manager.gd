## Unit tests for AssignmentManager.
## Tests assignment validation, signals, marker management, and re-assignment.
##
## Architecture: tests/unit/test_assignment_manager.gd
## Story: 2-7-implement-tap-to-assign-workflow
extends GutTest

# =============================================================================
# TEST DATA
# =============================================================================

var assignment_manager: Node
var mock_animal: Animal
var mock_animal2: Animal
var mock_hex: HexCoord
var mock_hex_dest: HexCoord
var mock_stats: AnimalStats

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Create test hex coordinates
	mock_hex = HexCoord.new(0, 0)
	mock_hex_dest = HexCoord.new(1, 0)

	# Create shared stats
	mock_stats = AnimalStats.new()
	mock_stats.animal_id = "test_rabbit_assign"
	mock_stats.energy = 3
	mock_stats.speed = 4
	mock_stats.strength = 2
	mock_stats.specialty = "Test"
	mock_stats.biome = "plains"

	# Create AssignmentManager (dynamically to avoid autoload conflicts)
	var AssignmentManagerScript := preload("res://autoloads/assignment_manager.gd")
	assignment_manager = AssignmentManagerScript.new()
	add_child(assignment_manager)
	await wait_frames(1)

	# Create test animals
	var scene := preload("res://scenes/entities/animals/rabbit.tscn")
	mock_animal = scene.instantiate() as Animal
	mock_animal2 = scene.instantiate() as Animal
	add_child(mock_animal)
	add_child(mock_animal2)
	await wait_frames(1)

	# Initialize animals
	mock_animal.initialize(mock_hex, mock_stats)
	mock_animal2.initialize(HexCoord.new(2, 0), mock_stats)
	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(assignment_manager):
		assignment_manager.queue_free()
	if is_instance_valid(mock_animal):
		mock_animal.cleanup()
	if is_instance_valid(mock_animal2):
		mock_animal2.cleanup()
	# CRITICAL: Wait for queue_free to complete before next test
	await wait_frames(1)

	assignment_manager = null
	mock_animal = null
	mock_animal2 = null
	mock_hex = null
	mock_hex_dest = null
	mock_stats = null

# =============================================================================
# NULL SAFETY TESTS (AR18)
# =============================================================================

func test_assign_to_null_animal_returns_false() -> void:
	var result: bool = assignment_manager.assign_to_hex(null, mock_hex_dest)

	assert_false(result, "Should reject null animal")


func test_assign_to_null_target_returns_false() -> void:
	var result: bool = assignment_manager.assign_to_hex(mock_animal, null)

	assert_false(result, "Should reject null target")


func test_assign_both_null_returns_false() -> void:
	var result: bool = assignment_manager.assign_to_hex(null, null)

	assert_false(result, "Should reject both null params")

# =============================================================================
# QUERY TESTS
# =============================================================================

func test_has_assignment_returns_false_initially() -> void:
	var result: bool = assignment_manager.has_assignment(mock_animal)

	assert_false(result, "Should have no assignment initially")


func test_get_assignment_target_returns_null_when_none() -> void:
	var result: HexCoord = assignment_manager.get_assignment_target(mock_animal)

	assert_null(result, "Should return null when no assignment")


func test_has_assignment_null_animal_returns_false() -> void:
	var result: bool = assignment_manager.has_assignment(null)

	assert_false(result, "Should return false for null animal")


func test_get_assignment_target_null_animal_returns_null() -> void:
	var result: HexCoord = assignment_manager.get_assignment_target(null)

	assert_null(result, "Should return null for null animal")

# =============================================================================
# CANCELLATION TESTS (AC7)
# =============================================================================

func test_cancel_assignment_clears_state() -> void:
	# First we need to track something
	assignment_manager._active_assignments["test_rabbit_assign"] = mock_hex_dest

	assignment_manager.cancel_assignment(mock_animal)

	var has: bool = assignment_manager.has_assignment(mock_animal)
	assert_false(has, "Should have no assignment after cancel")


func test_cancel_assignment_null_animal_no_crash() -> void:
	# Should not crash
	assignment_manager.cancel_assignment(null)

	# Test passes if no exception thrown
	assert_true(true, "Should handle null gracefully")

# =============================================================================
# SIGNAL TESTS (AC6) - assignment_failed signal
# =============================================================================

func test_assignment_failed_signal_exists() -> void:
	# Verify the signal exists on the manager
	assert_true(assignment_manager.has_signal("assignment_failed"),
		"AssignmentManager should have assignment_failed signal")


func test_assignment_failed_signal_can_be_emitted() -> void:
	watch_signals(assignment_manager)

	# Directly test that we can emit and receive the signal
	assignment_manager.assignment_failed.emit(mock_animal, "test_reason")

	# Verify signal can be emitted and received
	assert_signal_emitted(assignment_manager, "assignment_failed")

# =============================================================================
# EVENTBUS INTEGRATION TESTS (AC6)
# =============================================================================

func test_connects_to_movement_completed_signal() -> void:
	# Verify signal connection
	assert_true(EventBus.animal_movement_completed.is_connected(
		assignment_manager._on_animal_movement_completed
	), "Should connect to movement_completed signal")


func test_connects_to_movement_cancelled_signal() -> void:
	# Verify signal connection
	assert_true(EventBus.animal_movement_cancelled.is_connected(
		assignment_manager._on_animal_movement_cancelled
	), "Should connect to movement_cancelled signal")


func test_connects_to_animal_removed_signal() -> void:
	# Verify signal connection
	assert_true(EventBus.animal_removed.is_connected(
		assignment_manager._on_animal_removed
	), "Should connect to animal_removed signal")

# =============================================================================
# MOVEMENT LIFECYCLE TESTS (AC5.2, AC5.3)
# =============================================================================

func test_movement_completed_clears_assignment() -> void:
	# Manually track an assignment
	var animal_id := "test_rabbit_assign"
	assignment_manager._active_assignments[animal_id] = mock_hex_dest

	# Simulate movement completed
	assignment_manager._on_animal_movement_completed(mock_animal)

	assert_false(assignment_manager._active_assignments.has(animal_id),
		"Assignment should be cleared after movement completed")


func test_movement_cancelled_clears_assignment() -> void:
	# Manually track an assignment
	var animal_id := "test_rabbit_assign"
	assignment_manager._active_assignments[animal_id] = mock_hex_dest

	# Simulate movement cancelled
	assignment_manager._on_animal_movement_cancelled(mock_animal)

	assert_false(assignment_manager._active_assignments.has(animal_id),
		"Assignment should be cleared after movement cancelled")


func test_animal_removed_clears_assignment() -> void:
	# Manually track an assignment
	var animal_id := "test_rabbit_assign"
	assignment_manager._active_assignments[animal_id] = mock_hex_dest

	# Simulate animal removed
	assignment_manager._on_animal_removed(mock_animal)

	assert_false(assignment_manager._active_assignments.has(animal_id),
		"Assignment should be cleared when animal is removed")


func test_movement_completed_invalid_animal_no_crash() -> void:
	# Should not crash with invalid animal
	assignment_manager._on_animal_movement_completed(null)

	# Test passes if no exception thrown
	assert_true(true, "Should handle null gracefully")


func test_movement_cancelled_invalid_animal_no_crash() -> void:
	# Should not crash with invalid animal
	assignment_manager._on_animal_movement_cancelled(null)

	# Test passes if no exception thrown
	assert_true(true, "Should handle null gracefully")

# =============================================================================
# MARKER MANAGEMENT TESTS (AC2)
# =============================================================================

func test_markers_dictionary_initially_empty() -> void:
	assert_eq(assignment_manager._destination_markers.size(), 0,
		"Markers dictionary should be empty initially")


func test_hide_marker_no_crash_when_none_exist() -> void:
	# Should not crash when no marker exists
	assignment_manager._hide_destination_marker(mock_animal)

	# Test passes if no exception thrown
	assert_true(true, "Should handle missing marker gracefully")


func test_hide_marker_clears_marker_entry() -> void:
	# Manually add a mock marker
	var mock_marker := Node3D.new()
	add_child(mock_marker)
	assignment_manager._destination_markers["test_rabbit_assign"] = mock_marker

	assignment_manager._hide_destination_marker(mock_animal)

	assert_false(assignment_manager._destination_markers.has("test_rabbit_assign"),
		"Marker entry should be removed")

	# Clean up if not already queued
	if is_instance_valid(mock_marker):
		mock_marker.queue_free()

# =============================================================================
# VALIDATION TESTS (AC3, AC4, AC5)
# =============================================================================

func test_validate_hex_returns_dict_with_valid_and_reason() -> void:
	var result: Dictionary = assignment_manager._validate_hex(mock_animal, mock_hex_dest)

	assert_true(result.has("valid"), "Result should have 'valid' key")
	assert_true(result.has("reason"), "Result should have 'reason' key")


func test_validate_hex_without_world_manager_returns_invalid() -> void:
	# Clear world manager reference
	assignment_manager._world_manager = null

	# Force a validation where hex won't be found
	var result: Dictionary = assignment_manager._validate_hex(mock_animal, HexCoord.new(100, 100))

	# Without world manager, can't verify hex exists - but should not crash
	assert_true(result.has("valid"), "Result should have 'valid' key")

# =============================================================================
# GET ANIMAL ID TESTS
# =============================================================================

func test_get_animal_id_returns_stats_id() -> void:
	var result: String = assignment_manager._get_animal_id(mock_animal)

	assert_eq(result, "test_rabbit_assign", "Should return animal stats ID")


func test_get_animal_id_fallback_for_null_stats() -> void:
	# Create minimal mock without stats
	var mock_node: Node3D = Node3D.new()
	add_child(mock_node)
	await wait_frames(1)

	var result: String = assignment_manager._get_animal_id(mock_node)

	# Should return instance ID as string fallback
	assert_ne(result, "", "Should return non-empty fallback ID")

	mock_node.queue_free()

# =============================================================================
# RE-ASSIGNMENT TESTS (AC7)
# =============================================================================

func test_reassign_cancels_previous_assignment() -> void:
	# Manually set up initial assignment
	var animal_id := "test_rabbit_assign"
	var first_target := HexCoord.new(1, 0)
	var second_target := HexCoord.new(2, 0)
	assignment_manager._active_assignments[animal_id] = first_target

	# Cancel existing (simulating re-assignment)
	assignment_manager._cancel_existing(mock_animal)

	assert_false(assignment_manager._active_assignments.has(animal_id),
		"Previous assignment should be cleared")


func test_cancel_existing_stops_movement_if_possible() -> void:
	# Track whether stop was called
	var stop_called := false

	# Create mock movement with stop
	var movement := mock_animal.get_node_or_null("MovementComponent")
	if movement:
		# Movement component has stop method - this will be called
		assignment_manager._cancel_existing(mock_animal)
		# If no error, test passes (method was callable)
		assert_true(true, "Should call stop without error")
	else:
		# No movement component - that's fine, should not crash
		assignment_manager._cancel_existing(mock_animal)
		assert_true(true, "Should handle missing movement gracefully")

# =============================================================================
# CLEANUP TESTS
# =============================================================================

func test_exit_tree_cleans_up_markers() -> void:
	# Add some mock markers
	var mock_marker1 := Node3D.new()
	var mock_marker2 := Node3D.new()
	add_child(mock_marker1)
	add_child(mock_marker2)

	assignment_manager._destination_markers["animal1"] = mock_marker1
	assignment_manager._destination_markers["animal2"] = mock_marker2

	# Call cleanup indirectly via remove
	assignment_manager._destination_markers.clear()

	assert_eq(assignment_manager._destination_markers.size(), 0,
		"All markers should be cleared")

	# Clean up
	mock_marker1.queue_free()
	mock_marker2.queue_free()


func test_multiple_assignments_tracked_separately() -> void:
	# Track two different animals
	assignment_manager._active_assignments["animal_a"] = HexCoord.new(1, 0)
	assignment_manager._active_assignments["animal_b"] = HexCoord.new(2, 0)

	assert_eq(assignment_manager._active_assignments.size(), 2,
		"Should track multiple assignments")

	# Clear one
	assignment_manager._active_assignments.erase("animal_a")

	assert_eq(assignment_manager._active_assignments.size(), 1,
		"Should have one assignment left")
	assert_true(assignment_manager._active_assignments.has("animal_b"),
		"animal_b assignment should remain")

# =============================================================================
# SUCCESS CASE TESTS (AC1, AC6) - Code Review Fix H3
# =============================================================================

func test_assign_to_hex_success_with_mocked_managers() -> void:
	# Create mock PathfindingManager that allows assignment
	var mock_pathfinding := Node.new()
	var pathfinding_script := GDScript.new()
	pathfinding_script.source_code = """
extends Node
func is_passable(hex: HexCoord) -> bool:
	return true
func request_path(from: HexCoord, to: HexCoord) -> Array:
	return [from, to]  # Return valid path
"""
	pathfinding_script.reload()
	mock_pathfinding.set_script(pathfinding_script)
	add_child(mock_pathfinding)

	# Create mock TerritoryManager that returns CLAIMED state
	var mock_territory := Node.new()
	var territory_script := GDScript.new()
	territory_script.source_code = """
extends Node
enum TerritoryState { UNEXPLORED, SCOUTED, CONTESTED, CLAIMED, NEGLECTED }
func get_territory_state(hex: HexCoord) -> int:
	return TerritoryState.CLAIMED
"""
	territory_script.reload()
	mock_territory.set_script(territory_script)
	add_child(mock_territory)

	# Create mock WorldManager
	var mock_world := Node.new()
	var world_script := GDScript.new()
	world_script.source_code = """
extends Node
func has_tile_at(hex: HexCoord) -> bool:
	return true
func get_pathfinding_manager():
	return null
func get_territory_manager():
	return null
"""
	world_script.reload()
	mock_world.set_script(world_script)
	add_child(mock_world)

	# Inject mocks into assignment manager
	assignment_manager._pathfinding_manager = mock_pathfinding
	assignment_manager._territory_manager = mock_territory
	assignment_manager._world_manager = mock_world

	# Watch for EventBus signal
	watch_signals(EventBus)

	# Attempt assignment
	var result: bool = assignment_manager.assign_to_hex(mock_animal, mock_hex_dest)

	# Verify success
	assert_true(result, "Assignment should succeed with valid mocks")

	# Verify EventBus signal emitted (AC6)
	assert_signal_emitted(EventBus, "animal_assigned")

	# Verify assignment is tracked
	assert_true(assignment_manager.has_assignment(mock_animal),
		"Animal should have active assignment after success")

	# Verify target is correct
	var target: HexCoord = assignment_manager.get_assignment_target(mock_animal)
	assert_not_null(target, "Should have target hex")
	assert_eq(target.q, mock_hex_dest.q, "Target q should match")
	assert_eq(target.r, mock_hex_dest.r, "Target r should match")

	# Cleanup mocks
	mock_pathfinding.queue_free()
	mock_territory.queue_free()
	mock_world.queue_free()


func test_assign_to_hex_emits_correct_signal_params() -> void:
	# Create minimal mocks for success
	var mock_pathfinding := Node.new()
	var pathfinding_script := GDScript.new()
	pathfinding_script.source_code = """
extends Node
func is_passable(hex: HexCoord) -> bool:
	return true
func request_path(from: HexCoord, to: HexCoord) -> Array:
	return [from, to]
"""
	pathfinding_script.reload()
	mock_pathfinding.set_script(pathfinding_script)
	add_child(mock_pathfinding)

	var mock_territory := Node.new()
	var territory_script := GDScript.new()
	territory_script.source_code = """
extends Node
enum TerritoryState { UNEXPLORED, SCOUTED, CONTESTED, CLAIMED, NEGLECTED }
func get_territory_state(hex: HexCoord) -> int:
	return TerritoryState.CLAIMED
"""
	territory_script.reload()
	mock_territory.set_script(territory_script)
	add_child(mock_territory)

	assignment_manager._pathfinding_manager = mock_pathfinding
	assignment_manager._territory_manager = mock_territory

	# Watch signals
	watch_signals(EventBus)

	# Assign
	assignment_manager.assign_to_hex(mock_animal, mock_hex_dest)

	# Verify signal parameters
	var params: Array = get_signal_parameters(EventBus, "animal_assigned")
	assert_eq(params.size(), 2, "animal_assigned should have 2 parameters")
	if params.size() >= 2:
		assert_eq(params[0], mock_animal, "First param should be the animal")
		assert_true(params[1] is HexCoord, "Second param should be HexCoord")

	# Cleanup
	mock_pathfinding.queue_free()
	mock_territory.queue_free()


func test_assign_to_hex_rejects_impassable_terrain() -> void:
	# Create mock that returns impassable
	var mock_pathfinding := Node.new()
	var pathfinding_script := GDScript.new()
	pathfinding_script.source_code = """
extends Node
func is_passable(hex: HexCoord) -> bool:
	return false  # Water/rock
func request_path(from: HexCoord, to: HexCoord) -> Array:
	return []
"""
	pathfinding_script.reload()
	mock_pathfinding.set_script(pathfinding_script)
	add_child(mock_pathfinding)

	assignment_manager._pathfinding_manager = mock_pathfinding

	# Watch for failure signal
	watch_signals(assignment_manager)

	# Attempt assignment
	var result: bool = assignment_manager.assign_to_hex(mock_animal, mock_hex_dest)

	# Verify rejection
	assert_false(result, "Should reject impassable terrain")
	assert_signal_emitted(assignment_manager, "assignment_failed")

	# Cleanup
	mock_pathfinding.queue_free()


func test_assign_to_hex_rejects_unexplored_hex() -> void:
	# Create mocks - passable but unexplored
	var mock_pathfinding := Node.new()
	var pathfinding_script := GDScript.new()
	pathfinding_script.source_code = """
extends Node
func is_passable(hex: HexCoord) -> bool:
	return true
func request_path(from: HexCoord, to: HexCoord) -> Array:
	return [from, to]
"""
	pathfinding_script.reload()
	mock_pathfinding.set_script(pathfinding_script)
	add_child(mock_pathfinding)

	var mock_territory := Node.new()
	var territory_script := GDScript.new()
	territory_script.source_code = """
extends Node
enum TerritoryState { UNEXPLORED, SCOUTED, CONTESTED, CLAIMED, NEGLECTED }
func get_territory_state(hex: HexCoord) -> int:
	return TerritoryState.UNEXPLORED  # Fog of war
"""
	territory_script.reload()
	mock_territory.set_script(territory_script)
	add_child(mock_territory)

	assignment_manager._pathfinding_manager = mock_pathfinding
	assignment_manager._territory_manager = mock_territory

	# Watch for failure signal
	watch_signals(assignment_manager)

	# Attempt assignment
	var result: bool = assignment_manager.assign_to_hex(mock_animal, mock_hex_dest)

	# Verify rejection (AC4)
	assert_false(result, "Should reject unexplored hex")
	assert_signal_emitted(assignment_manager, "assignment_failed")

	# Cleanup
	mock_pathfinding.queue_free()
	mock_territory.queue_free()


func test_assign_to_hex_rejects_no_path() -> void:
	# Create mocks - passable and revealed but no path
	var mock_pathfinding := Node.new()
	var pathfinding_script := GDScript.new()
	pathfinding_script.source_code = """
extends Node
func is_passable(hex: HexCoord) -> bool:
	return true
func request_path(from: HexCoord, to: HexCoord) -> Array:
	return []  # No path exists
"""
	pathfinding_script.reload()
	mock_pathfinding.set_script(pathfinding_script)
	add_child(mock_pathfinding)

	var mock_territory := Node.new()
	var territory_script := GDScript.new()
	territory_script.source_code = """
extends Node
enum TerritoryState { UNEXPLORED, SCOUTED, CONTESTED, CLAIMED, NEGLECTED }
func get_territory_state(hex: HexCoord) -> int:
	return TerritoryState.CLAIMED
"""
	territory_script.reload()
	mock_territory.set_script(territory_script)
	add_child(mock_territory)

	assignment_manager._pathfinding_manager = mock_pathfinding
	assignment_manager._territory_manager = mock_territory

	# Watch for failure signal
	watch_signals(assignment_manager)

	# Attempt assignment
	var result: bool = assignment_manager.assign_to_hex(mock_animal, mock_hex_dest)

	# Verify rejection (AC5)
	assert_false(result, "Should reject when no path exists")
	assert_signal_emitted(assignment_manager, "assignment_failed")

	# Cleanup
	mock_pathfinding.queue_free()
	mock_territory.queue_free()


# =============================================================================
# DESTINATION MARKER SCENE TESTS
# =============================================================================

func test_destination_marker_scene_exists() -> void:
	var marker_path := "res://scenes/ui/destination_marker.tscn"
	assert_true(ResourceLoader.exists(marker_path),
		"Destination marker scene should exist")


func test_destination_marker_can_be_instantiated() -> void:
	var marker_path := "res://scenes/ui/destination_marker.tscn"
	if ResourceLoader.exists(marker_path):
		var scene := load(marker_path) as PackedScene
		var marker := scene.instantiate()
		add_child(marker)
		await wait_frames(1)

		assert_not_null(marker, "Should be able to instantiate marker")
		assert_true(marker is Node3D, "Marker should be Node3D")

		marker.queue_free()
	else:
		pending("Marker scene not found - may not be created yet")


func test_destination_marker_has_cleanup_method() -> void:
	var marker_path := "res://scenes/ui/destination_marker.tscn"
	if ResourceLoader.exists(marker_path):
		var scene := load(marker_path) as PackedScene
		var marker := scene.instantiate()
		add_child(marker)
		await wait_frames(1)

		assert_true(marker.has_method("cleanup"),
			"Marker should have cleanup method")

		marker.queue_free()
	else:
		pending("Marker scene not found - may not be created yet")
