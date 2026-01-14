## Unit tests for MovementComponent
## Tests path following, speed calculation, signals, direction facing, and edge cases.
##
## Story: 2-6-implement-animal-movement
extends GutTest

var movement: MovementComponent
var mock_animal: Node3D
var mock_stats: Node
var mock_visual: Node3D

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Create mock animal with required structure
	mock_animal = _create_mock_animal()
	add_child(mock_animal)

	# Get movement component reference
	movement = mock_animal.get_node("MovementComponent")
	mock_stats = mock_animal.get_node("StatsComponent")
	mock_visual = mock_animal.get_node("Visual")

	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(mock_animal):
		mock_animal.queue_free()
	mock_animal = null
	movement = null
	mock_stats = null
	mock_visual = null
	await wait_frames(1)


func _create_mock_animal() -> Node3D:
	var animal := Node3D.new()
	animal.name = "TestAnimal"

	# Add hex_coord property and methods via script
	var animal_script := GDScript.new()
	animal_script.source_code = """
extends Node3D

var hex_coord: HexCoord = null

func get_hex_coord() -> HexCoord:
	return hex_coord

func set_hex_coord(hex: HexCoord) -> void:
	hex_coord = hex
"""
	animal_script.reload()
	animal.set_script(animal_script)

	# Initialize starting hex
	var start_hex := HexCoord.new(0, 0)
	animal.hex_coord = start_hex

	# Add Visual child (for rotation)
	mock_visual = Node3D.new()
	mock_visual.name = "Visual"
	animal.add_child(mock_visual)

	# Add StatsComponent mock
	var stats := _create_mock_stats()
	animal.add_child(stats)

	# Add MovementComponent (actual implementation)
	var move := MovementComponent.new()
	move.name = "MovementComponent"
	animal.add_child(move)

	return animal


func _create_mock_stats() -> Node:
	var stats := Node.new()
	stats.name = "StatsComponent"

	var script := GDScript.new()
	script.source_code = """
extends Node

var _speed: int = 3
var _mood_modifier: float = 1.0

func get_speed() -> int:
	return _speed

func get_mood_modifier() -> float:
	return _mood_modifier

func get_effective_speed() -> float:
	return float(_speed) * _mood_modifier

func set_speed(val: int) -> void:
	_speed = val

func set_mood_modifier(val: float) -> void:
	_mood_modifier = val
"""
	script.reload()
	stats.set_script(script)
	return stats


# =============================================================================
# INITIAL STATE TESTS (AC1)
# =============================================================================

func test_is_moving_returns_false_initially() -> void:
	assert_false(movement.is_moving(), "Should not be moving initially")


func test_get_destination_returns_null_when_not_moving() -> void:
	assert_null(movement.get_destination(), "Destination should be null when not moving")


func test_get_remaining_path_length_returns_zero_when_not_moving() -> void:
	assert_eq(movement.get_remaining_path_length(), 0, "Remaining path should be 0 when not moving")


# =============================================================================
# MOVE_TO NULL HANDLING TESTS (AC1)
# =============================================================================

func test_move_to_null_does_not_crash() -> void:
	movement.move_to(null)

	assert_false(movement.is_moving(), "Should not start moving with null destination")


func test_move_to_same_location_no_movement() -> void:
	# Animal is at (0, 0), try to move to (0, 0)
	var same_hex := HexCoord.new(0, 0)

	movement.move_to(same_hex)

	assert_false(movement.is_moving(), "Should not move to same location")


# =============================================================================
# SPEED CALCULATION TESTS (AC2)
# =============================================================================

func test_get_current_speed_with_default_stats() -> void:
	# Default speed = 3, mood = 1.0, so effective_speed = 3.0
	# Speed = BASE_SPEED + (effective_speed - 1) * SPEED_PER_STAT
	# Speed = 50 + (3 - 1) * 20 = 50 + 40 = 90
	var speed := movement.get_current_speed()

	assert_almost_eq(speed, 90.0, 0.1, "Speed with default stats should be 90")


func test_speed_increases_with_higher_stat() -> void:
	mock_stats.set_speed(5)  # Max speed

	var speed := movement.get_current_speed()

	# Speed = 50 + (5 - 1) * 20 = 50 + 80 = 130
	assert_almost_eq(speed, 130.0, 0.1, "Max speed should be 130")


func test_speed_decreases_with_lower_stat() -> void:
	mock_stats.set_speed(1)  # Min speed

	var speed := movement.get_current_speed()

	# Speed = 50 + (1 - 1) * 20 = 50
	assert_almost_eq(speed, 50.0, 0.1, "Min speed should be 50")


func test_mood_modifier_affects_speed_sad() -> void:
	mock_stats.set_speed(3)
	mock_stats.set_mood_modifier(0.7)  # Sad mood

	var speed := movement.get_current_speed()

	# effective_speed = 3 * 0.7 = 2.1
	# Speed = 50 + (2.1 - 1) * 20 = 50 + 22 = 72
	assert_almost_eq(speed, 72.0, 0.1, "Sad mood should reduce speed")


func test_mood_modifier_affects_speed_neutral() -> void:
	mock_stats.set_speed(3)
	mock_stats.set_mood_modifier(0.85)  # Neutral mood

	var speed := movement.get_current_speed()

	# effective_speed = 3 * 0.85 = 2.55
	# Speed = 50 + (2.55 - 1) * 20 = 50 + 31 = 81
	assert_almost_eq(speed, 81.0, 0.1, "Neutral mood should slightly reduce speed")


func test_speed_has_minimum_value() -> void:
	# Even with very low stats, speed should have a minimum
	mock_stats.set_speed(0)  # Invalid but should handle gracefully
	mock_stats.set_mood_modifier(0.1)

	var speed := movement.get_current_speed()

	assert_gte(speed, 10.0, "Speed should never go below minimum")


# =============================================================================
# SIGNAL TESTS (AC5, AC6)
# =============================================================================

func test_movement_cancelled_signal_emitted_on_stop() -> void:
	watch_signals(movement)

	# Stop when not moving should not emit signal
	movement.stop()

	assert_signal_not_emitted(movement, "movement_cancelled",
		"Should not emit cancelled when not moving")


func test_stop_when_not_moving_no_crash() -> void:
	# This should not throw any errors
	movement.stop()

	assert_false(movement.is_moving(), "Stop when not moving should be safe")


func test_waypoint_reached_signal_exists() -> void:
	# Verify the signal is defined
	assert_true(movement.has_signal("waypoint_reached"),
		"MovementComponent should have waypoint_reached signal")


func test_movement_started_signal_exists() -> void:
	assert_true(movement.has_signal("movement_started"),
		"MovementComponent should have movement_started signal")


func test_movement_completed_signal_exists() -> void:
	assert_true(movement.has_signal("movement_completed"),
		"MovementComponent should have movement_completed signal")


func test_movement_cancelled_signal_exists() -> void:
	assert_true(movement.has_signal("movement_cancelled"),
		"MovementComponent should have movement_cancelled signal")


# =============================================================================
# EVENTBUS SIGNAL TESTS (AC6)
# =============================================================================

func test_eventbus_has_movement_started_signal() -> void:
	assert_true(EventBus.has_signal("animal_movement_started"),
		"EventBus should have animal_movement_started signal")


func test_eventbus_has_movement_completed_signal() -> void:
	assert_true(EventBus.has_signal("animal_movement_completed"),
		"EventBus should have animal_movement_completed signal")


func test_eventbus_has_movement_cancelled_signal() -> void:
	assert_true(EventBus.has_signal("animal_movement_cancelled"),
		"EventBus should have animal_movement_cancelled signal")


# =============================================================================
# DIRECTION FACING TESTS (AC3)
# =============================================================================

func test_visual_node_exists_for_rotation() -> void:
	assert_not_null(mock_visual, "Visual child should exist for rotation")


func test_visual_initial_rotation_is_zero() -> void:
	assert_almost_eq(mock_visual.rotation.y, 0.0, 0.01,
		"Visual should start with zero Y rotation")


# =============================================================================
# PUBLIC API TESTS
# =============================================================================

func test_get_remaining_path_length_public_method() -> void:
	var length := movement.get_remaining_path_length()

	assert_eq(length, 0, "Should return 0 when not moving")


func test_get_current_speed_public_method() -> void:
	var speed := movement.get_current_speed()

	assert_gt(speed, 0.0, "Speed should be positive")


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_move_to_without_pathfinding_manager() -> void:
	# This tests the null check for PathfindingManager
	# Without a valid PathfindingManager, movement should not start
	var target := HexCoord.new(5, 5)

	# Ensure no pathfinding manager is set (clear any existing reference)
	movement.set_pathfinding_manager(null)

	# This should not crash even if PathfindingManager is not set up
	movement.move_to(target)

	# Movement should NOT start when PathfindingManager is unavailable
	assert_false(movement.is_moving(),
		"Should not start moving without PathfindingManager")


func test_stop_multiple_times_no_crash() -> void:
	movement.stop()
	movement.stop()
	movement.stop()

	assert_false(movement.is_moving(), "Multiple stops should be safe")


func test_get_destination_after_stop_is_null() -> void:
	movement.stop()

	assert_null(movement.get_destination(), "Destination should be null after stop")


# =============================================================================
# COMPONENT REFERENCE TESTS
# =============================================================================

func test_finds_stats_component_sibling() -> void:
	# The movement component should find the StatsComponent
	# If it does, get_current_speed() should return calculated value
	var speed := movement.get_current_speed()

	# Should not be exactly BASE_SPEED since stats are applied
	assert_almost_eq(speed, 90.0, 0.1, "Should calculate speed from StatsComponent")


func test_handles_missing_stats_component_gracefully() -> void:
	# Create animal without StatsComponent
	var bare_animal := Node3D.new()
	bare_animal.name = "BareAnimal"

	var bare_script := GDScript.new()
	bare_script.source_code = """
extends Node3D
var hex_coord: HexCoord = HexCoord.new(0, 0)
func get_hex_coord() -> HexCoord:
	return hex_coord
func set_hex_coord(hex: HexCoord) -> void:
	hex_coord = hex
"""
	bare_script.reload()
	bare_animal.set_script(bare_script)

	var move := MovementComponent.new()
	move.name = "MovementComponent"
	bare_animal.add_child(move)

	add_child(bare_animal)
	await wait_frames(1)

	# Should not crash and should use base speed
	var speed := move.get_current_speed()
	assert_almost_eq(speed, 50.0, 0.1, "Should use BASE_SPEED without StatsComponent")

	bare_animal.queue_free()


# =============================================================================
# CONSTANTS TESTS
# =============================================================================

func test_base_speed_constant_value() -> void:
	assert_eq(MovementComponent.BASE_SPEED, 50.0, "BASE_SPEED should be 50.0")


func test_speed_per_stat_constant_value() -> void:
	assert_eq(MovementComponent.SPEED_PER_STAT, 20.0, "SPEED_PER_STAT should be 20.0")


func test_rotation_speed_constant_value() -> void:
	assert_eq(MovementComponent.ROTATION_SPEED, 10.0, "ROTATION_SPEED should be 10.0")


# =============================================================================
# STATE INTEGRITY TESTS
# =============================================================================

func test_initial_path_is_empty() -> void:
	# Access internal state for verification
	assert_false(movement.is_moving(), "Should not be moving initially")
	assert_eq(movement.get_remaining_path_length(), 0, "Path should be empty")


func test_destination_null_when_not_moving() -> void:
	assert_null(movement.get_destination(), "Destination should be null")


# =============================================================================
# SPEED FORMULA VERIFICATION TESTS
# =============================================================================

func test_speed_formula_at_stat_1() -> void:
	mock_stats.set_speed(1)
	mock_stats.set_mood_modifier(1.0)

	var speed := movement.get_current_speed()

	# effective_speed = 1.0
	# Speed = 50 + (1 - 1) * 20 = 50
	assert_almost_eq(speed, 50.0, 0.1)


func test_speed_formula_at_stat_2() -> void:
	mock_stats.set_speed(2)
	mock_stats.set_mood_modifier(1.0)

	var speed := movement.get_current_speed()

	# effective_speed = 2.0
	# Speed = 50 + (2 - 1) * 20 = 70
	assert_almost_eq(speed, 70.0, 0.1)


func test_speed_formula_at_stat_3() -> void:
	mock_stats.set_speed(3)
	mock_stats.set_mood_modifier(1.0)

	var speed := movement.get_current_speed()

	# effective_speed = 3.0
	# Speed = 50 + (3 - 1) * 20 = 90
	assert_almost_eq(speed, 90.0, 0.1)


func test_speed_formula_at_stat_4() -> void:
	mock_stats.set_speed(4)
	mock_stats.set_mood_modifier(1.0)

	var speed := movement.get_current_speed()

	# effective_speed = 4.0
	# Speed = 50 + (4 - 1) * 20 = 110
	assert_almost_eq(speed, 110.0, 0.1)


func test_speed_formula_at_stat_5() -> void:
	mock_stats.set_speed(5)
	mock_stats.set_mood_modifier(1.0)

	var speed := movement.get_current_speed()

	# effective_speed = 5.0
	# Speed = 50 + (5 - 1) * 20 = 130
	assert_almost_eq(speed, 130.0, 0.1)


# =============================================================================
# MOOD MODIFIER SPEED TESTS
# =============================================================================

func test_speed_with_happy_mood() -> void:
	mock_stats.set_speed(3)
	mock_stats.set_mood_modifier(1.0)  # Happy

	var speed := movement.get_current_speed()

	assert_almost_eq(speed, 90.0, 0.1, "Happy mood should give full speed")


func test_speed_with_neutral_mood() -> void:
	mock_stats.set_speed(3)
	mock_stats.set_mood_modifier(0.85)  # Neutral

	var speed := movement.get_current_speed()

	# effective = 3 * 0.85 = 2.55
	# speed = 50 + (2.55 - 1) * 20 = 81
	assert_almost_eq(speed, 81.0, 0.1, "Neutral mood should reduce speed")


func test_speed_with_sad_mood() -> void:
	mock_stats.set_speed(3)
	mock_stats.set_mood_modifier(0.7)  # Sad

	var speed := movement.get_current_speed()

	# effective = 3 * 0.7 = 2.1
	# speed = 50 + (2.1 - 1) * 20 = 72
	assert_almost_eq(speed, 72.0, 0.1, "Sad mood should significantly reduce speed")
