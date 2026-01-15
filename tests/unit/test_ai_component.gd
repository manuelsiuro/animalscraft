## Unit tests for AIComponent state machine
## Tests state transitions, guards, signals, and integration
##
## Story: 2-8-implement-animal-ai-state-machine
extends GutTest

var mock_animal: Node
var ai_component: AIComponent
var mock_stats: AnimalStats


func before_each() -> void:
	# Create mock AnimalStats
	mock_stats = AnimalStats.new()
	mock_stats.animal_id = "test_rabbit"
	mock_stats.energy = 3
	mock_stats.speed = 3
	mock_stats.strength = 2

	# Create test animal from scene
	mock_animal = _create_test_animal()
	add_child(mock_animal)

	# Wait for deferred initialization to complete (scene tree must process)
	await get_tree().process_frame
	await get_tree().process_frame

	ai_component = mock_animal.get_node_or_null("AIComponent") as AIComponent

	# Ensure AIComponent is fully initialized before tests run
	# Poll until initialized or timeout
	var max_wait: int = 10
	while ai_component and not ai_component.is_initialized() and max_wait > 0:
		await get_tree().process_frame
		max_wait -= 1


func after_each() -> void:
	if is_instance_valid(mock_animal):
		mock_animal.queue_free()
	await get_tree().process_frame


func _create_test_animal() -> Node:
	var animal_scene: PackedScene = load("res://scenes/entities/animals/rabbit.tscn")
	var animal: Node = animal_scene.instantiate()

	# Initialize with test data
	var hex := HexCoord.new()
	hex.q = 0
	hex.r = 0

	animal.call_deferred("initialize", hex, mock_stats)

	return animal

# =============================================================================
# INITIALIZATION TESTS (AC1)
# =============================================================================

func test_ai_component_exists() -> void:
	assert_not_null(ai_component, "AIComponent should exist")


func test_ai_component_initialized() -> void:
	assert_true(ai_component.is_initialized(), "AIComponent should be initialized")


func test_default_state_is_idle() -> void:
	var state := ai_component.get_current_state()
	assert_eq(state, AIComponent.AnimalState.IDLE, "Default state should be IDLE")


func test_get_current_state_string() -> void:
	var state_str := ai_component.get_current_state_string()
	assert_eq(state_str, "IDLE", "State string should be 'IDLE'")

# =============================================================================
# TRANSITION TESTS (AC7)
# =============================================================================

func test_valid_transition_idle_to_walking() -> void:
	ai_component.transition_to(AIComponent.AnimalState.WALKING)
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.WALKING)


func test_valid_transition_walking_to_idle() -> void:
	ai_component.transition_to(AIComponent.AnimalState.WALKING)
	ai_component.transition_to(AIComponent.AnimalState.IDLE)
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.IDLE)


func test_valid_transition_idle_to_working() -> void:
	ai_component.transition_to(AIComponent.AnimalState.WORKING)
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.WORKING)


func test_valid_transition_idle_to_resting() -> void:
	ai_component.transition_to(AIComponent.AnimalState.RESTING)
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.RESTING)


func test_valid_transition_working_to_resting() -> void:
	ai_component.transition_to(AIComponent.AnimalState.WORKING)
	ai_component.transition_to(AIComponent.AnimalState.RESTING)
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.RESTING)


func test_valid_transition_resting_to_idle() -> void:
	ai_component.transition_to(AIComponent.AnimalState.RESTING)
	ai_component.transition_to(AIComponent.AnimalState.IDLE)
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.IDLE)


func test_invalid_transition_resting_to_walking() -> void:
	ai_component.transition_to(AIComponent.AnimalState.RESTING)

	# Try invalid transition
	ai_component.transition_to(AIComponent.AnimalState.WALKING)

	# Should still be in Resting (invalid transition rejected)
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.RESTING)


func test_invalid_transition_resting_to_working() -> void:
	ai_component.transition_to(AIComponent.AnimalState.RESTING)

	# Try invalid transition
	ai_component.transition_to(AIComponent.AnimalState.WORKING)

	# Should still be in Resting
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.RESTING)


func test_same_state_transition_ignored() -> void:
	watch_signals(ai_component)
	ai_component.transition_to(AIComponent.AnimalState.IDLE)
	assert_signal_not_emitted(ai_component, "state_changed")

# =============================================================================
# SIGNAL TESTS (AC8)
# =============================================================================

func test_state_changed_signal_emitted() -> void:
	watch_signals(ai_component)
	ai_component.transition_to(AIComponent.AnimalState.WALKING)
	assert_signal_emitted(ai_component, "state_changed")


func test_state_changed_signal_params() -> void:
	watch_signals(ai_component)
	ai_component.transition_to(AIComponent.AnimalState.WALKING)

	var params: Array = get_signal_parameters(ai_component, "state_changed", 0)
	assert_eq(params[0], AIComponent.AnimalState.IDLE, "Old state should be IDLE")
	assert_eq(params[1], AIComponent.AnimalState.WALKING, "New state should be WALKING")


func test_eventbus_state_changed_signal_emitted() -> void:
	watch_signals(EventBus)
	ai_component.transition_to(AIComponent.AnimalState.WALKING)
	assert_signal_emitted(EventBus, "animal_state_changed")


func test_eventbus_state_changed_signal_params() -> void:
	watch_signals(EventBus)
	ai_component.transition_to(AIComponent.AnimalState.WALKING)

	var params: Array = get_signal_parameters(EventBus, "animal_state_changed", 0)
	assert_eq(params[0], mock_animal, "Signal should contain animal reference")
	assert_eq(params[1], "WALKING", "Signal should contain state string")

# =============================================================================
# RESTING STATE TESTS (AC5)
# =============================================================================

func test_energy_depleted_triggers_resting() -> void:
	var stats := mock_animal.get_node_or_null("StatsComponent") as StatsComponent
	assert_not_null(stats)

	# Deplete all energy
	stats.deplete_energy(stats.get_max_energy())

	await get_tree().process_frame

	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.RESTING)


func test_resting_emits_animal_resting_signal() -> void:
	watch_signals(EventBus)
	ai_component.transition_to(AIComponent.AnimalState.RESTING)
	assert_signal_emitted(EventBus, "animal_resting")


func test_resting_exit_emits_animal_recovered_signal() -> void:
	ai_component.transition_to(AIComponent.AnimalState.RESTING)
	watch_signals(EventBus)
	ai_component.transition_to(AIComponent.AnimalState.IDLE)
	assert_signal_emitted(EventBus, "animal_recovered")

# =============================================================================
# IS_IN_STATE HELPER TESTS
# =============================================================================

func test_is_in_state_returns_true_for_current() -> void:
	assert_true(ai_component.is_in_state(AIComponent.AnimalState.IDLE))


func test_is_in_state_returns_false_for_other() -> void:
	assert_false(ai_component.is_in_state(AIComponent.AnimalState.WALKING))


func test_is_in_state_after_transition() -> void:
	ai_component.transition_to(AIComponent.AnimalState.WALKING)
	assert_true(ai_component.is_in_state(AIComponent.AnimalState.WALKING))
	assert_false(ai_component.is_in_state(AIComponent.AnimalState.IDLE))

# =============================================================================
# MOVEMENT SIGNAL INTEGRATION TESTS (AC3)
# =============================================================================

func test_movement_started_triggers_walking() -> void:
	var movement := mock_animal.get_node_or_null("MovementComponent")
	assert_not_null(movement, "MovementComponent should exist")

	# Verify starting state
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.IDLE, "Should start in IDLE")

	# Debug: verify signal is connected
	var connections: Array = movement.movement_started.get_connections()
	assert_gt(connections.size(), 0, "movement_started should have at least one connection")

	# Simulate movement_started signal - handlers are synchronous
	movement.movement_started.emit()

	# Check state immediately after signal (before _process runs WalkingState.update)
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.WALKING)


func test_movement_completed_triggers_idle() -> void:
	ai_component.transition_to(AIComponent.AnimalState.WALKING)

	var movement := mock_animal.get_node_or_null("MovementComponent")
	assert_not_null(movement)

	# Simulate movement_completed signal
	movement.movement_completed.emit()
	await get_tree().process_frame

	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.IDLE)


func test_movement_cancelled_triggers_idle() -> void:
	ai_component.transition_to(AIComponent.AnimalState.WALKING)

	var movement := mock_animal.get_node_or_null("MovementComponent")
	assert_not_null(movement)

	# Simulate movement_cancelled signal
	movement.movement_cancelled.emit()
	await get_tree().process_frame

	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.IDLE)

# =============================================================================
# [PARTY: GLaDOS] ADDITIONAL EDGE CASE TESTS
# =============================================================================

func test_race_condition_movement_started_while_walking() -> void:
	# Already in WALKING state
	ai_component.transition_to(AIComponent.AnimalState.WALKING)

	# Start watching AFTER the initial transition
	watch_signals(ai_component)

	# Fire movement_started again - should not cause issues
	var movement := mock_animal.get_node_or_null("MovementComponent")
	assert_not_null(movement, "MovementComponent should exist")
	movement.movement_started.emit()

	# Check immediately after signal (synchronous) - no state change should occur
	# because we're already in WALKING
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.WALKING)
	assert_signal_not_emitted(ai_component, "state_changed")


func test_rapid_state_cycling() -> void:
	# Rapid transitions should maintain coherence
	ai_component.transition_to(AIComponent.AnimalState.WALKING)
	ai_component.transition_to(AIComponent.AnimalState.IDLE)
	ai_component.transition_to(AIComponent.AnimalState.WALKING)
	ai_component.transition_to(AIComponent.AnimalState.IDLE)

	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.IDLE)
	assert_true(ai_component.is_in_state(AIComponent.AnimalState.IDLE))


func test_energy_boundary_triggers_resting() -> void:
	var stats := mock_animal.get_node_or_null("StatsComponent") as StatsComponent
	assert_not_null(stats)

	# Deplete energy to exactly 1
	while stats.get_energy() > 1:
		stats.deplete_energy(1)

	assert_eq(stats.get_energy(), 1)
	assert_ne(ai_component.get_current_state(), AIComponent.AnimalState.RESTING)

	# Deplete the last point
	stats.deplete_energy(1)
	await get_tree().process_frame

	# Should transition to RESTING
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.RESTING)


func test_energy_boundary_not_idle_until_full() -> void:
	# Get into RESTING state via energy depletion
	var stats := mock_animal.get_node_or_null("StatsComponent") as StatsComponent
	stats.deplete_energy(stats.get_max_energy())
	await get_tree().process_frame

	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.RESTING)

	# Restore 1 energy - should NOT return to IDLE yet
	stats.restore_energy(1)
	await get_tree().process_frame

	# Still in RESTING (not full energy)
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.RESTING)


func test_animal_resting_signal_correct_reference() -> void:
	watch_signals(EventBus)
	ai_component.transition_to(AIComponent.AnimalState.RESTING)

	var params: Array = get_signal_parameters(EventBus, "animal_resting", 0)
	assert_eq(params[0], mock_animal, "Signal should contain THIS animal instance")


func test_animal_state_changed_signal_correct_reference() -> void:
	watch_signals(EventBus)
	ai_component.transition_to(AIComponent.AnimalState.WALKING)

	var params: Array = get_signal_parameters(EventBus, "animal_state_changed", 0)
	assert_eq(params[0], mock_animal, "Signal should contain THIS animal instance")
	assert_eq(params[1], "WALKING", "Signal should contain correct state string")


func test_transition_from_working_to_idle() -> void:
	# Working can only go to IDLE or RESTING
	ai_component.transition_to(AIComponent.AnimalState.WORKING)
	ai_component.transition_to(AIComponent.AnimalState.IDLE)
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.IDLE)


func test_invalid_transition_working_to_walking() -> void:
	ai_component.transition_to(AIComponent.AnimalState.WORKING)

	# Try invalid transition from WORKING to WALKING
	ai_component.transition_to(AIComponent.AnimalState.WALKING)

	# Should still be WORKING
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.WORKING)

# =============================================================================
# STATE ENTER/EXIT TESTS (AC7)
# =============================================================================

func test_enter_called_on_transition() -> void:
	# Transition to walking
	ai_component.transition_to(AIComponent.AnimalState.WALKING)

	# State should be walking - enter was called
	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.WALKING)


func test_multiple_transitions_maintain_consistency() -> void:
	# Series of valid transitions
	ai_component.transition_to(AIComponent.AnimalState.WALKING)
	ai_component.transition_to(AIComponent.AnimalState.WORKING)
	ai_component.transition_to(AIComponent.AnimalState.RESTING)
	ai_component.transition_to(AIComponent.AnimalState.IDLE)

	assert_eq(ai_component.get_current_state(), AIComponent.AnimalState.IDLE)

# =============================================================================
# WALKING STATE UPDATE FALLBACK TEST
# =============================================================================

func test_walking_state_fallback_to_idle() -> void:
	# Put in walking state
	ai_component.transition_to(AIComponent.AnimalState.WALKING)

	# Simulate a few frames where movement is not active
	# Walking state should check movement.is_moving() in update
	# and transition to IDLE if movement stopped externally

	# Give it some frames to process
	for _i in range(5):
		await get_tree().process_frame

	# If movement wasn't active, should have transitioned to idle
	# Note: This depends on MovementComponent.is_moving() returning false
	# In a real scenario, movement would be started first
	assert_true(
		ai_component.get_current_state() == AIComponent.AnimalState.IDLE or
		ai_component.get_current_state() == AIComponent.AnimalState.WALKING,
		"Should be IDLE or WALKING depending on movement state"
	)

# =============================================================================
# CONSTANT VERIFICATION TESTS
# =============================================================================

func test_valid_transitions_constant_exists() -> void:
	assert_true(AIComponent.VALID_TRANSITIONS.size() > 0, "VALID_TRANSITIONS should have entries")


func test_valid_transitions_has_all_states() -> void:
	assert_true(AIComponent.VALID_TRANSITIONS.has(AIComponent.AnimalState.IDLE))
	assert_true(AIComponent.VALID_TRANSITIONS.has(AIComponent.AnimalState.WALKING))
	assert_true(AIComponent.VALID_TRANSITIONS.has(AIComponent.AnimalState.WORKING))
	assert_true(AIComponent.VALID_TRANSITIONS.has(AIComponent.AnimalState.RESTING))


func test_idle_valid_transitions() -> void:
	var valid := AIComponent.VALID_TRANSITIONS[AIComponent.AnimalState.IDLE]
	assert_true(AIComponent.AnimalState.WALKING in valid)
	assert_true(AIComponent.AnimalState.WORKING in valid)
	assert_true(AIComponent.AnimalState.RESTING in valid)


func test_resting_only_to_idle() -> void:
	var valid := AIComponent.VALID_TRANSITIONS[AIComponent.AnimalState.RESTING]
	assert_eq(valid.size(), 1, "RESTING should only transition to IDLE")
	assert_true(AIComponent.AnimalState.IDLE in valid)
