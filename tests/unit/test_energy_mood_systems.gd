## Unit tests for Energy and Mood Systems
## Tests Story 2-9 acceptance criteria:
## - AC1: Energy depletion during work
## - AC2: Auto-transition to resting at energy 0
## - AC3: Mood decreases when working while tired
## - AC4: Energy recovery during rest
## - AC5: Mood recovery during rest
## - AC6: Mood affects all stats
## - AC7: Stats panel shows mood effect
## - AC8: Low energy warning
##
## Story: 2-9-implement-energy-and-mood-systems
extends GutTest

var stats_component: StatsComponent
var mock_stats: AnimalStats


func before_each() -> void:
	# Create mock AnimalStats
	mock_stats = AnimalStats.new()
	mock_stats.animal_id = "test_rabbit"
	mock_stats.energy = 3
	mock_stats.speed = 4
	mock_stats.strength = 2
	mock_stats.specialty = "Speed +20% gathering"
	mock_stats.biome = "plains"

	# Create StatsComponent
	stats_component = StatsComponent.new()
	add_child(stats_component)
	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(stats_component):
		stats_component.queue_free()
	stats_component = null


# =============================================================================
# AC8: LOW ENERGY WARNING TESTS
# =============================================================================

func test_low_energy_threshold_constant_exists() -> void:
	## Verify LOW_ENERGY_THRESHOLD constant is defined
	assert_eq(StatsComponent.LOW_ENERGY_THRESHOLD, 1, "LOW_ENERGY_THRESHOLD should be 1")


func test_is_energy_low_true_at_threshold() -> void:
	## Test is_energy_low() returns true at threshold
	stats_component.initialize(mock_stats)

	# Deplete to threshold (1)
	stats_component.deplete_energy(2)

	assert_true(stats_component.is_energy_low(), "Should be low at threshold")


func test_is_energy_low_true_below_threshold() -> void:
	## Test is_energy_low() returns true below threshold (at 0)
	stats_component.initialize(mock_stats)

	stats_component.deplete_energy(3)  # Deplete to 0

	assert_true(stats_component.is_energy_low(), "Should be low at 0")


func test_is_energy_low_false_above_threshold() -> void:
	## Test is_energy_low() returns false above threshold
	stats_component.initialize(mock_stats)

	stats_component.deplete_energy(1)  # Energy is now 2

	assert_false(stats_component.is_energy_low(), "Should NOT be low above threshold")


func test_low_energy_signal_emitted_when_crossing_threshold() -> void:
	## AC8: EventBus.animal_energy_low is emitted when energy reaches threshold
	stats_component.initialize(mock_stats)
	watch_signals(EventBus)

	# Deplete to threshold (3 -> 2 -> 1)
	stats_component.deplete_energy(1)  # 3 -> 2, not low yet
	stats_component.deplete_energy(1)  # 2 -> 1, now low!

	assert_signal_emitted(EventBus, "animal_energy_low")


func test_low_energy_signal_emitted_only_once() -> void:
	## AC8: Low energy signal should only emit once per cycle
	stats_component.initialize(mock_stats)
	watch_signals(EventBus)

	# Cross threshold
	stats_component.deplete_energy(2)  # 3 -> 1, crosses threshold

	# Try to emit again (already at or below threshold)
	stats_component.deplete_energy(1)  # 1 -> 0

	assert_signal_emit_count(EventBus, "animal_energy_low", 1)


func test_low_energy_flag_resets_on_restore_above_threshold() -> void:
	## AC8: Low energy flag should reset when energy restored above threshold
	stats_component.initialize(mock_stats)
	watch_signals(EventBus)

	# Get to low energy
	stats_component.deplete_energy(3)  # 3 -> 0

	# Verify first signal emitted
	assert_signal_emitted(EventBus, "animal_energy_low")

	# Restore above threshold
	stats_component.restore_energy(3)  # 0 -> 3

	# Clear signal watcher and watch again
	clear_signal_watcher()
	watch_signals(EventBus)

	# Deplete again - should emit signal again
	stats_component.deplete_energy(2)  # 3 -> 1, crosses threshold again

	assert_signal_emitted(EventBus, "animal_energy_low")


# =============================================================================
# AC6: MOOD AFFECTS ALL STATS TESTS (Extended)
# =============================================================================

func test_effective_speed_with_all_moods() -> void:
	## AC6: Verify mood modifiers for speed
	stats_component.initialize(mock_stats)

	# Happy: 1.0x
	assert_almost_eq(stats_component.get_effective_speed(), 4.0, 0.01)

	# Neutral: 0.85x
	stats_component.set_mood(StatsComponent.Mood.NEUTRAL)
	assert_almost_eq(stats_component.get_effective_speed(), 3.4, 0.01)  # 4 * 0.85

	# Sad: 0.7x
	stats_component.set_mood(StatsComponent.Mood.SAD)
	assert_almost_eq(stats_component.get_effective_speed(), 2.8, 0.01)  # 4 * 0.7


func test_effective_strength_with_all_moods() -> void:
	## AC6: Verify mood modifiers for strength
	stats_component.initialize(mock_stats)

	# Happy: 1.0x
	assert_almost_eq(stats_component.get_effective_strength(), 2.0, 0.01)

	# Neutral: 0.85x
	stats_component.set_mood(StatsComponent.Mood.NEUTRAL)
	assert_almost_eq(stats_component.get_effective_strength(), 1.7, 0.01)  # 2 * 0.85

	# Sad: 0.7x
	stats_component.set_mood(StatsComponent.Mood.SAD)
	assert_almost_eq(stats_component.get_effective_strength(), 1.4, 0.01)  # 2 * 0.7


func test_mood_modifiers_correct_values() -> void:
	## AC6: Verify mood modifier constants
	assert_almost_eq(StatsComponent.MOOD_MODIFIERS[StatsComponent.Mood.HAPPY], 1.0, 0.01)
	assert_almost_eq(StatsComponent.MOOD_MODIFIERS[StatsComponent.Mood.NEUTRAL], 0.85, 0.01)
	assert_almost_eq(StatsComponent.MOOD_MODIFIERS[StatsComponent.Mood.SAD], 0.7, 0.01)


# =============================================================================
# SIGNAL ORDER TESTS
# =============================================================================

func test_low_energy_signal_emits_after_local_signal() -> void:
	## Low energy signal should emit after local energy_changed signal
	stats_component.initialize(mock_stats)

	var emission_order: Array[String] = []

	# Connect to local signal
	stats_component.energy_changed.connect(func(_curr: int, _max: int) -> void: emission_order.append("local"))

	# Connect to EventBus low energy signal
	EventBus.animal_energy_low.connect(func(_animal: Node) -> void: emission_order.append("eventbus_low"))

	# Trigger crossing threshold
	stats_component.deplete_energy(2)  # 3 -> 1

	# Verify order
	assert_true(emission_order.size() >= 2, "Both signals should emit")
	var local_idx := emission_order.find("local")
	var eventbus_idx := emission_order.find("eventbus_low")
	assert_true(local_idx < eventbus_idx, "Local signal should emit BEFORE EventBus signal")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_restore_does_not_reset_flag_at_threshold() -> void:
	## Restoring to exactly threshold should NOT reset the flag
	stats_component.initialize(mock_stats)
	watch_signals(EventBus)

	# Get to 0 energy
	stats_component.deplete_energy(3)

	# Restore to exactly threshold (1)
	stats_component.restore_energy(1)  # 0 -> 1

	# Flag should NOT reset because we're still at threshold
	clear_signal_watcher()
	watch_signals(EventBus)

	# Deplete again - should NOT emit since flag wasn't reset
	stats_component.deplete_energy(1)  # 1 -> 0

	# Signal should not emit again since we never went above threshold
	assert_signal_not_emitted(EventBus, "animal_energy_low")


func test_restore_resets_flag_above_threshold() -> void:
	## Restoring ABOVE threshold should reset the flag
	stats_component.initialize(mock_stats)
	watch_signals(EventBus)

	# Get to 0 energy
	stats_component.deplete_energy(3)

	# Restore above threshold
	stats_component.restore_energy(2)  # 0 -> 2

	# Clear and watch again
	clear_signal_watcher()
	watch_signals(EventBus)

	# Deplete to threshold - should emit again
	stats_component.deplete_energy(1)  # 2 -> 1

	assert_signal_emitted(EventBus, "animal_energy_low")


# =============================================================================
# AC1: ENERGY DEPLETION DURING WORK (WorkingState Tests)
# =============================================================================

func test_working_state_energy_drain_rate_constant() -> void:
	## AC1: Verify ENERGY_DRAIN_RATE constant is configurable
	assert_almost_eq(WorkingState.ENERGY_DRAIN_RATE, 0.5, 0.01, "ENERGY_DRAIN_RATE should be 0.5")


func test_working_state_depletes_energy_over_time() -> void:
	## AC1: Energy depletes during WorkingState update()
	var test_stats := StatsComponent.new()
	test_stats.name = "StatsComponent"
	test_stats.initialize(mock_stats)

	var mock_animal := Node3D.new()
	mock_animal.add_child(test_stats)
	add_child(mock_animal)
	await wait_frames(2)

	var working_state := WorkingState.new(null, mock_animal)
	var initial_energy := test_stats.get_energy()

	# Simulate 2.5 seconds of work (at 0.5 drain/sec = 1 energy per 2 sec)
	working_state.enter()
	for i in range(25):
		working_state.update(0.1)

	assert_lt(test_stats.get_energy(), initial_energy, "Energy should deplete during work")

	mock_animal.queue_free()
	await wait_frames(1)


# =============================================================================
# AC2: AUTO-TRANSITION TO RESTING (Signal-based)
# =============================================================================

func test_energy_depleted_signal_emitted_at_zero() -> void:
	## AC2: EventBus.animal_energy_depleted emitted when energy reaches 0
	stats_component.initialize(mock_stats)
	watch_signals(EventBus)

	# Deplete all energy
	stats_component.deplete_energy(3)  # 3 -> 0

	assert_signal_emitted(EventBus, "animal_energy_depleted")


# =============================================================================
# AC3: MOOD DECREASES WHEN WORKING WHILE TIRED
# =============================================================================

func test_working_state_mood_penalty_interval_constant() -> void:
	## AC3: Verify MOOD_PENALTY_INTERVAL constant is configurable
	assert_almost_eq(WorkingState.MOOD_PENALTY_INTERVAL, 5.0, 0.01, "MOOD_PENALTY_INTERVAL should be 5.0")


func test_working_state_mood_penalty_when_low_energy() -> void:
	## AC3: Mood decreases when working at low energy for MOOD_PENALTY_INTERVAL
	var test_stats := StatsComponent.new()
	test_stats.name = "StatsComponent"
	test_stats.initialize(mock_stats)

	var mock_animal := Node3D.new()
	mock_animal.add_child(test_stats)
	add_child(mock_animal)
	await wait_frames(2)

	# Set to low energy
	test_stats.deplete_energy(2)  # 3 -> 1
	assert_true(test_stats.is_energy_low())
	assert_eq(test_stats.get_mood(), StatsComponent.Mood.HAPPY)

	var working_state := WorkingState.new(null, mock_animal)
	working_state.enter()

	# Simulate 5.5 seconds of work at low energy
	for i in range(55):
		working_state.update(0.1)

	assert_ne(test_stats.get_mood(), StatsComponent.Mood.HAPPY, "Mood should decrease from exhaustion")

	mock_animal.queue_free()
	await wait_frames(1)


func test_working_state_mood_penalty_timer_resets_on_exit() -> void:
	## Task 8.9: Mood penalty timer resets when exiting WorkingState
	var test_stats := StatsComponent.new()
	test_stats.name = "StatsComponent"
	test_stats.initialize(mock_stats)

	var mock_animal := Node3D.new()
	mock_animal.add_child(test_stats)
	add_child(mock_animal)
	await wait_frames(2)

	# Set to low energy
	test_stats.deplete_energy(2)

	var working_state := WorkingState.new(null, mock_animal)
	working_state.enter()

	# Accumulate some timer (but not enough for penalty)
	for i in range(30):  # 3 seconds
		working_state.update(0.1)

	# Exit and re-enter - timer should reset
	working_state.exit()
	working_state.enter()

	# Need another full 5 seconds for mood penalty (not just 2 more seconds)
	for i in range(45):  # 4.5 seconds - not enough
		working_state.update(0.1)

	assert_eq(test_stats.get_mood(), StatsComponent.Mood.HAPPY, "Timer should have reset on exit/enter")

	mock_animal.queue_free()
	await wait_frames(1)


func test_working_state_mood_penalty_timer_resets_when_energy_restored() -> void:
	## MEDIUM-3 fix: Timer resets if energy restored above threshold mid-work
	var test_stats := StatsComponent.new()
	test_stats.name = "StatsComponent"
	test_stats.initialize(mock_stats)

	var mock_animal := Node3D.new()
	mock_animal.add_child(test_stats)
	add_child(mock_animal)
	await wait_frames(2)

	# Set to low energy
	test_stats.deplete_energy(2)

	var working_state := WorkingState.new(null, mock_animal)
	working_state.enter()

	# Accumulate 3 seconds of low energy timer
	for i in range(30):
		working_state.update(0.1)

	# Restore energy above threshold
	test_stats.restore_energy(2)  # 1 -> 3
	assert_false(test_stats.is_energy_low())

	# Update once to reset timer
	working_state.update(0.1)

	# Now go back to low energy
	test_stats.deplete_energy(2)  # 3 -> 1

	# Need another full 5 seconds (timer was reset when energy restored)
	for i in range(45):  # 4.5 seconds
		working_state.update(0.1)

	assert_eq(test_stats.get_mood(), StatsComponent.Mood.HAPPY, "Timer should have reset when energy restored")

	mock_animal.queue_free()
	await wait_frames(1)


# =============================================================================
# AC4: ENERGY RECOVERY DURING REST
# =============================================================================

func test_resting_state_energy_recovery_rate_constant() -> void:
	## AC4: Verify ENERGY_RECOVERY_RATE constant (~3s per point)
	assert_almost_eq(RestingState.ENERGY_RECOVERY_RATE, 0.33, 0.01, "ENERGY_RECOVERY_RATE should be ~0.33")


func test_resting_state_restores_energy_over_time() -> void:
	## AC4: Energy restores during RestingState update()
	var test_stats := StatsComponent.new()
	test_stats.name = "StatsComponent"
	test_stats.initialize(mock_stats)
	test_stats.deplete_energy(3)  # 3 -> 0
	assert_eq(test_stats.get_energy(), 0)

	var mock_animal := Node3D.new()
	mock_animal.add_child(test_stats)
	add_child(mock_animal)
	await wait_frames(2)

	var resting_state := RestingState.new(null, mock_animal)
	resting_state.enter()

	# Simulate ~4 seconds of rest (should restore at least 1 energy)
	for i in range(40):
		resting_state.update(0.1)

	assert_gt(test_stats.get_energy(), 0, "Energy should restore during rest")

	mock_animal.queue_free()
	await wait_frames(1)


# =============================================================================
# AC5: MOOD RECOVERY DURING REST
# =============================================================================

func test_resting_state_mood_improve_interval_constant() -> void:
	## AC5: Verify MOOD_IMPROVE_INTERVAL constant (5 seconds)
	assert_almost_eq(RestingState.MOOD_IMPROVE_INTERVAL, 5.0, 0.01, "MOOD_IMPROVE_INTERVAL should be 5.0")


func test_resting_state_improves_mood_over_time() -> void:
	## AC5: Mood improves during RestingState
	var test_stats := StatsComponent.new()
	test_stats.name = "StatsComponent"
	test_stats.initialize(mock_stats)
	test_stats.set_mood(StatsComponent.Mood.SAD)
	assert_eq(test_stats.get_mood(), StatsComponent.Mood.SAD)

	var mock_animal := Node3D.new()
	mock_animal.add_child(test_stats)
	add_child(mock_animal)
	await wait_frames(2)

	var resting_state := RestingState.new(null, mock_animal)
	resting_state.enter()

	# Simulate 5.5 seconds of rest (should improve mood once)
	for i in range(55):
		resting_state.update(0.1)

	assert_ne(test_stats.get_mood(), StatsComponent.Mood.SAD, "Mood should improve during rest")

	mock_animal.queue_free()
	await wait_frames(1)


# =============================================================================
# AC4 FIX TEST: RESTING STATE ONLY EMITS RECOVERED WHEN FULL
# =============================================================================

func test_resting_state_recovered_signal_only_when_full() -> void:
	## MEDIUM-2 fix: animal_recovered only emits when energy is actually full
	var test_stats := StatsComponent.new()
	test_stats.name = "StatsComponent"
	test_stats.initialize(mock_stats)
	test_stats.deplete_energy(2)  # 3 -> 1 (not depleted, just low)

	var mock_animal := Node3D.new()
	mock_animal.add_child(test_stats)
	add_child(mock_animal)
	await wait_frames(2)

	watch_signals(EventBus)

	var resting_state := RestingState.new(null, mock_animal)
	resting_state.enter()

	# Exit immediately (simulating interrupted rest)
	resting_state.exit()

	# Should NOT emit animal_recovered since energy is not full
	assert_signal_not_emitted(EventBus, "animal_recovered")

	mock_animal.queue_free()
	await wait_frames(1)


func test_resting_state_recovered_signal_when_full() -> void:
	## Verify animal_recovered DOES emit when energy is full
	var test_stats := StatsComponent.new()
	test_stats.name = "StatsComponent"
	test_stats.initialize(mock_stats)
	# Energy starts at max (3)
	assert_true(test_stats.is_energy_full())

	var mock_animal := Node3D.new()
	mock_animal.add_child(test_stats)
	add_child(mock_animal)
	await wait_frames(2)

	watch_signals(EventBus)

	var resting_state := RestingState.new(null, mock_animal)
	resting_state.enter()
	resting_state.exit()

	# SHOULD emit animal_recovered since energy is full
	assert_signal_emitted(EventBus, "animal_recovered")

	mock_animal.queue_free()
	await wait_frames(1)


# =============================================================================
# AC6/TASK 7: MOVEMENT SPEED WITH MOOD MODIFIER
# =============================================================================

func test_movement_component_uses_effective_speed() -> void:
	## Task 7.1: MovementComponent uses get_effective_speed()
	# Create fresh stats component for this test (avoid reparenting issues)
	var test_stats := StatsComponent.new()
	test_stats.name = "StatsComponent"
	test_stats.initialize(mock_stats)

	var mock_animal := Node3D.new()
	mock_animal.add_child(test_stats)
	add_child(mock_animal)
	await wait_frames(2)

	var movement := MovementComponent.new()
	mock_animal.add_child(movement)
	await wait_frames(2)

	# Get speed at Happy mood
	var happy_speed := movement.get_current_speed()

	# Change to Sad mood
	test_stats.set_mood(StatsComponent.Mood.SAD)

	# Get speed at Sad mood
	var sad_speed := movement.get_current_speed()

	assert_lt(sad_speed, happy_speed, "Sad mood should result in slower movement speed")

	mock_animal.queue_free()
	await wait_frames(1)


func test_sad_animal_moves_slower() -> void:
	## Task 7.3: Test sad animal moving slower
	# Create fresh stats component for this test (avoid reparenting issues)
	var test_stats := StatsComponent.new()
	test_stats.name = "StatsComponent"
	test_stats.initialize(mock_stats)

	var mock_animal := Node3D.new()
	mock_animal.add_child(test_stats)
	add_child(mock_animal)
	await wait_frames(2)

	var movement := MovementComponent.new()
	mock_animal.add_child(movement)
	await wait_frames(2)

	# Calculate expected speeds
	# BASE_SPEED = 50, SPEED_PER_STAT = 20, base_stat = 4
	# Happy: effective_speed = 4.0, speed = 50 + (4.0 - 1.0) * 20 = 110
	# Sad: effective_speed = 4 * 0.7 = 2.8, speed = 50 + (2.8 - 1.0) * 20 = 86

	test_stats.set_mood(StatsComponent.Mood.HAPPY)
	var happy_speed := movement.get_current_speed()

	test_stats.set_mood(StatsComponent.Mood.SAD)
	var sad_speed := movement.get_current_speed()

	# Sad should be ~78% of happy (0.7 modifier on effective speed)
	var ratio := sad_speed / happy_speed
	assert_lt(ratio, 0.9, "Sad speed should be significantly slower than happy")
	assert_gt(ratio, 0.6, "Sad speed should not be less than 60% of happy")

	mock_animal.queue_free()
	await wait_frames(1)


# =============================================================================
# DECREASE/INCREASE MOOD TESTS
# =============================================================================

func test_decrease_mood_happy_to_neutral() -> void:
	## Test mood decrease from Happy to Neutral
	stats_component.initialize(mock_stats)
	assert_eq(stats_component.get_mood(), StatsComponent.Mood.HAPPY)

	stats_component.decrease_mood()

	assert_eq(stats_component.get_mood(), StatsComponent.Mood.NEUTRAL)


func test_decrease_mood_neutral_to_sad() -> void:
	## Test mood decrease from Neutral to Sad
	stats_component.initialize(mock_stats)
	stats_component.set_mood(StatsComponent.Mood.NEUTRAL)

	stats_component.decrease_mood()

	assert_eq(stats_component.get_mood(), StatsComponent.Mood.SAD)


func test_decrease_mood_sad_stays_sad() -> void:
	## Test mood decrease from Sad stays Sad (floor)
	stats_component.initialize(mock_stats)
	stats_component.set_mood(StatsComponent.Mood.SAD)

	stats_component.decrease_mood()

	assert_eq(stats_component.get_mood(), StatsComponent.Mood.SAD)


func test_increase_mood_sad_to_neutral() -> void:
	## Test mood increase from Sad to Neutral
	stats_component.initialize(mock_stats)
	stats_component.set_mood(StatsComponent.Mood.SAD)

	stats_component.increase_mood()

	assert_eq(stats_component.get_mood(), StatsComponent.Mood.NEUTRAL)


func test_increase_mood_neutral_to_happy() -> void:
	## Test mood increase from Neutral to Happy
	stats_component.initialize(mock_stats)
	stats_component.set_mood(StatsComponent.Mood.NEUTRAL)

	stats_component.increase_mood()

	assert_eq(stats_component.get_mood(), StatsComponent.Mood.HAPPY)


func test_increase_mood_happy_stays_happy() -> void:
	## Test mood increase from Happy stays Happy (ceiling)
	stats_component.initialize(mock_stats)
	assert_eq(stats_component.get_mood(), StatsComponent.Mood.HAPPY)

	stats_component.increase_mood()

	assert_eq(stats_component.get_mood(), StatsComponent.Mood.HAPPY)
