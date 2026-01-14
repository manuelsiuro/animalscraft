## Unit tests for StatsComponent
## Tests initialization, energy, mood, and effective stats.
##
## Story: 2-2-implement-animal-stats
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
# INITIALIZATION TESTS (AC1, AC2)
# =============================================================================

func test_initialize_sets_energy_from_resource() -> void:
	stats_component.initialize(mock_stats)

	assert_eq(stats_component.get_energy(), 3, "Energy should match resource")
	assert_eq(stats_component.get_max_energy(), 3, "Max energy should match resource")


func test_initialize_sets_mood_to_happy() -> void:
	stats_component.initialize(mock_stats)

	assert_eq(stats_component.get_mood(), StatsComponent.Mood.HAPPY)
	assert_eq(stats_component.get_mood_string(), "happy")


func test_initialize_stores_base_stats_reference() -> void:
	stats_component.initialize(mock_stats)

	assert_eq(stats_component.get_base_stats(), mock_stats)


func test_is_initialized_returns_false_before_init() -> void:
	assert_false(stats_component.is_initialized())


func test_is_initialized_returns_true_after_init() -> void:
	stats_component.initialize(mock_stats)

	assert_true(stats_component.is_initialized())


func test_double_initialize_is_ignored() -> void:
	var other_stats := AnimalStats.new()
	other_stats.energy = 5

	stats_component.initialize(mock_stats)
	stats_component.initialize(other_stats)  # Should be ignored

	assert_eq(stats_component.get_max_energy(), 3, "Should keep original stats")


func test_initialize_without_resource_uses_defaults() -> void:
	stats_component.initialize(null)

	assert_eq(stats_component.get_energy(), 3, "Should use default energy")
	assert_eq(stats_component.get_max_energy(), 3, "Should use default max energy")


# =============================================================================
# ENERGY TESTS (AC5)
# =============================================================================

func test_deplete_energy_reduces_current() -> void:
	stats_component.initialize(mock_stats)

	stats_component.deplete_energy(1)

	assert_eq(stats_component.get_energy(), 2)


func test_deplete_energy_clamps_to_zero() -> void:
	stats_component.initialize(mock_stats)

	stats_component.deplete_energy(10)  # More than max

	assert_eq(stats_component.get_energy(), 0)


func test_deplete_energy_emits_signal() -> void:
	stats_component.initialize(mock_stats)
	watch_signals(stats_component)

	stats_component.deplete_energy(1)

	assert_signal_emitted(stats_component, "energy_changed")


func test_deplete_energy_signal_has_correct_values() -> void:
	stats_component.initialize(mock_stats)
	watch_signals(stats_component)

	stats_component.deplete_energy(1)

	var signal_params = get_signal_parameters(stats_component, "energy_changed", 0)
	assert_eq(signal_params[0], 2, "Current energy should be 2")
	assert_eq(signal_params[1], 3, "Max energy should be 3")


func test_restore_energy_increases_current() -> void:
	stats_component.initialize(mock_stats)
	stats_component.deplete_energy(2)

	stats_component.restore_energy(1)

	assert_eq(stats_component.get_energy(), 2)


func test_restore_energy_clamps_to_max() -> void:
	stats_component.initialize(mock_stats)
	stats_component.deplete_energy(1)

	stats_component.restore_energy(10)  # More than needed

	assert_eq(stats_component.get_energy(), 3)


func test_restore_energy_emits_signal() -> void:
	stats_component.initialize(mock_stats)
	stats_component.deplete_energy(1)
	watch_signals(stats_component)

	stats_component.restore_energy(1)

	assert_signal_emitted(stats_component, "energy_changed")


func test_is_energy_depleted_when_zero() -> void:
	stats_component.initialize(mock_stats)
	stats_component.deplete_energy(3)

	assert_true(stats_component.is_energy_depleted())


func test_is_energy_depleted_when_not_zero() -> void:
	stats_component.initialize(mock_stats)

	assert_false(stats_component.is_energy_depleted())


func test_is_energy_full_when_at_max() -> void:
	stats_component.initialize(mock_stats)

	assert_true(stats_component.is_energy_full())


func test_is_energy_full_when_not_at_max() -> void:
	stats_component.initialize(mock_stats)
	stats_component.deplete_energy(1)

	assert_false(stats_component.is_energy_full())


func test_energy_depleted_emits_eventbus_signal() -> void:
	stats_component.initialize(mock_stats)
	watch_signals(EventBus)

	stats_component.deplete_energy(3)  # Deplete to 0

	assert_signal_emitted(EventBus, "animal_energy_depleted")


# =============================================================================
# MOOD TESTS (AC6)
# =============================================================================

func test_decrease_mood_happy_to_neutral() -> void:
	stats_component.initialize(mock_stats)

	stats_component.decrease_mood()

	assert_eq(stats_component.get_mood(), StatsComponent.Mood.NEUTRAL)


func test_decrease_mood_neutral_to_sad() -> void:
	stats_component.initialize(mock_stats)
	stats_component.set_mood(StatsComponent.Mood.NEUTRAL)

	stats_component.decrease_mood()

	assert_eq(stats_component.get_mood(), StatsComponent.Mood.SAD)


func test_decrease_mood_sad_stays_sad() -> void:
	stats_component.initialize(mock_stats)
	stats_component.set_mood(StatsComponent.Mood.SAD)

	stats_component.decrease_mood()

	assert_eq(stats_component.get_mood(), StatsComponent.Mood.SAD)


func test_increase_mood_sad_to_neutral() -> void:
	stats_component.initialize(mock_stats)
	stats_component.set_mood(StatsComponent.Mood.SAD)

	stats_component.increase_mood()

	assert_eq(stats_component.get_mood(), StatsComponent.Mood.NEUTRAL)


func test_increase_mood_neutral_to_happy() -> void:
	stats_component.initialize(mock_stats)
	stats_component.set_mood(StatsComponent.Mood.NEUTRAL)

	stats_component.increase_mood()

	assert_eq(stats_component.get_mood(), StatsComponent.Mood.HAPPY)


func test_increase_mood_happy_stays_happy() -> void:
	stats_component.initialize(mock_stats)

	stats_component.increase_mood()

	assert_eq(stats_component.get_mood(), StatsComponent.Mood.HAPPY)


func test_mood_changed_emits_signal() -> void:
	stats_component.initialize(mock_stats)
	watch_signals(stats_component)

	stats_component.set_mood(StatsComponent.Mood.NEUTRAL)

	assert_signal_emitted(stats_component, "mood_changed")


func test_mood_changed_signal_has_correct_value() -> void:
	stats_component.initialize(mock_stats)
	watch_signals(stats_component)

	stats_component.set_mood(StatsComponent.Mood.SAD)

	var signal_params = get_signal_parameters(stats_component, "mood_changed", 0)
	assert_eq(signal_params[0], "sad")


func test_mood_changed_emits_eventbus_signal() -> void:
	stats_component.initialize(mock_stats)
	watch_signals(EventBus)

	stats_component.set_mood(StatsComponent.Mood.NEUTRAL)

	assert_signal_emitted(EventBus, "animal_mood_changed")


func test_get_mood_string_returns_correct_values() -> void:
	stats_component.initialize(mock_stats)

	assert_eq(stats_component.get_mood_string(), "happy")

	stats_component.set_mood(StatsComponent.Mood.NEUTRAL)
	assert_eq(stats_component.get_mood_string(), "neutral")

	stats_component.set_mood(StatsComponent.Mood.SAD)
	assert_eq(stats_component.get_mood_string(), "sad")


# =============================================================================
# EFFECTIVE STATS TESTS (AC7)
# =============================================================================

func test_effective_speed_happy_full() -> void:
	stats_component.initialize(mock_stats)

	assert_almost_eq(stats_component.get_effective_speed(), 4.0, 0.01)


func test_effective_speed_neutral_reduced() -> void:
	stats_component.initialize(mock_stats)
	stats_component.set_mood(StatsComponent.Mood.NEUTRAL)

	assert_almost_eq(stats_component.get_effective_speed(), 3.4, 0.01)  # 4 * 0.85


func test_effective_speed_sad_reduced() -> void:
	stats_component.initialize(mock_stats)
	stats_component.set_mood(StatsComponent.Mood.SAD)

	assert_almost_eq(stats_component.get_effective_speed(), 2.8, 0.01)  # 4 * 0.7


func test_effective_strength_happy() -> void:
	stats_component.initialize(mock_stats)

	assert_almost_eq(stats_component.get_effective_strength(), 2.0, 0.01)


func test_effective_strength_sad_reduced() -> void:
	stats_component.initialize(mock_stats)
	stats_component.set_mood(StatsComponent.Mood.SAD)

	assert_almost_eq(stats_component.get_effective_strength(), 1.4, 0.01)  # 2 * 0.7


func test_mood_modifier_values() -> void:
	stats_component.initialize(mock_stats)

	assert_almost_eq(stats_component.get_mood_modifier(), 1.0, 0.01)

	stats_component.set_mood(StatsComponent.Mood.NEUTRAL)
	assert_almost_eq(stats_component.get_mood_modifier(), 0.85, 0.01)

	stats_component.set_mood(StatsComponent.Mood.SAD)
	assert_almost_eq(stats_component.get_mood_modifier(), 0.7, 0.01)


func test_get_effective_stat_speed() -> void:
	stats_component.initialize(mock_stats)

	assert_almost_eq(stats_component.get_effective_stat("speed"), 4.0, 0.01)


func test_get_effective_stat_strength() -> void:
	stats_component.initialize(mock_stats)

	assert_almost_eq(stats_component.get_effective_stat("strength"), 2.0, 0.01)


func test_get_effective_stat_energy() -> void:
	stats_component.initialize(mock_stats)

	assert_almost_eq(stats_component.get_effective_stat("energy"), 3.0, 0.01)


func test_get_effective_stat_unknown_returns_zero() -> void:
	stats_component.initialize(mock_stats)

	assert_almost_eq(stats_component.get_effective_stat("invalid"), 0.0, 0.01)


# =============================================================================
# ACCESSORS TESTS (AC7)
# =============================================================================

func test_get_speed_returns_base() -> void:
	stats_component.initialize(mock_stats)

	assert_eq(stats_component.get_speed(), 4)


func test_get_strength_returns_base() -> void:
	stats_component.initialize(mock_stats)

	assert_eq(stats_component.get_strength(), 2)


func test_get_specialty_returns_string() -> void:
	stats_component.initialize(mock_stats)

	assert_eq(stats_component.get_specialty(), "Speed +20% gathering")


func test_get_biome_returns_string() -> void:
	stats_component.initialize(mock_stats)

	assert_eq(stats_component.get_biome(), "plains")


func test_get_animal_id_returns_string() -> void:
	stats_component.initialize(mock_stats)

	assert_eq(stats_component.get_animal_id(), "test_rabbit")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_deplete_zero_no_change() -> void:
	stats_component.initialize(mock_stats)
	watch_signals(stats_component)

	stats_component.deplete_energy(0)

	assert_eq(stats_component.get_energy(), 3)
	assert_signal_not_emitted(stats_component, "energy_changed")


func test_deplete_negative_no_change() -> void:
	stats_component.initialize(mock_stats)
	watch_signals(stats_component)

	stats_component.deplete_energy(-1)

	assert_eq(stats_component.get_energy(), 3)
	assert_signal_not_emitted(stats_component, "energy_changed")


func test_restore_zero_no_change() -> void:
	stats_component.initialize(mock_stats)
	stats_component.deplete_energy(1)
	watch_signals(stats_component)

	stats_component.restore_energy(0)

	assert_eq(stats_component.get_energy(), 2)
	assert_signal_not_emitted(stats_component, "energy_changed")


func test_restore_negative_no_change() -> void:
	stats_component.initialize(mock_stats)
	stats_component.deplete_energy(1)
	watch_signals(stats_component)

	stats_component.restore_energy(-1)

	assert_eq(stats_component.get_energy(), 2)
	assert_signal_not_emitted(stats_component, "energy_changed")


func test_set_same_mood_no_signal() -> void:
	stats_component.initialize(mock_stats)
	watch_signals(stats_component)

	stats_component.set_mood(StatsComponent.Mood.HAPPY)  # Already happy

	assert_signal_not_emitted(stats_component, "mood_changed")


func test_string_to_mood_conversion() -> void:
	assert_eq(StatsComponent.string_to_mood("happy"), StatsComponent.Mood.HAPPY)
	assert_eq(StatsComponent.string_to_mood("NEUTRAL"), StatsComponent.Mood.NEUTRAL)
	assert_eq(StatsComponent.string_to_mood("Sad"), StatsComponent.Mood.SAD)
	assert_eq(StatsComponent.string_to_mood("invalid"), StatsComponent.Mood.HAPPY)


func test_to_string_format() -> void:
	stats_component.initialize(mock_stats)

	var result := str(stats_component)

	assert_true(result.contains("StatsComponent"), "Should include class name")
	assert_true(result.contains("E3/3"), "Should include energy")
	assert_true(result.contains("happy"), "Should include mood")


# =============================================================================
# RUNTIME VS BASE STATS TESTS (AC4)
# =============================================================================

func test_runtime_energy_independent_from_base() -> void:
	stats_component.initialize(mock_stats)

	stats_component.deplete_energy(1)

	# Runtime changed, but base should not
	assert_eq(stats_component.get_energy(), 2)
	assert_eq(stats_component.get_max_energy(), 3)
	assert_eq(mock_stats.energy, 3, "Base stats should not change")


func test_base_stats_resource_unchanged_after_operations() -> void:
	stats_component.initialize(mock_stats)

	# Perform various operations
	stats_component.deplete_energy(2)
	stats_component.restore_energy(1)
	stats_component.set_mood(StatsComponent.Mood.SAD)

	# Verify base stats are unchanged
	assert_eq(mock_stats.energy, 3)
	assert_eq(mock_stats.speed, 4)
	assert_eq(mock_stats.strength, 2)


# =============================================================================
# GLADOS INVARIANT TESTS (AC6, AC8)
# =============================================================================

func test_energy_not_affected_by_mood() -> void:
	## GLaDOS: "Energy is NOT affected by mood - assert this invariant
	## to prevent future developers from 'fixing' it incorrectly."
	stats_component.initialize(mock_stats)
	var initial_energy := stats_component.get_energy()
	var initial_max := stats_component.get_max_energy()

	# Change mood through all states
	stats_component.set_mood(StatsComponent.Mood.NEUTRAL)
	assert_eq(stats_component.get_energy(), initial_energy, "Energy should NOT change with NEUTRAL mood")
	assert_eq(stats_component.get_max_energy(), initial_max, "Max energy should NOT change with mood")

	stats_component.set_mood(StatsComponent.Mood.SAD)
	assert_eq(stats_component.get_energy(), initial_energy, "Energy should NOT change with SAD mood")
	assert_eq(stats_component.get_max_energy(), initial_max, "Max energy should NOT change with mood")

	stats_component.set_mood(StatsComponent.Mood.HAPPY)
	assert_eq(stats_component.get_energy(), initial_energy, "Energy should NOT change back with HAPPY mood")


func test_signal_emission_order_local_before_eventbus() -> void:
	## GLaDOS: "AC8 requires EventBus signals emit AFTER local signals.
	## Trust, but verify with tests."
	stats_component.initialize(mock_stats)

	var emission_order: Array[String] = []

	# Connect to local signal
	stats_component.mood_changed.connect(func(_mood: String) -> void: emission_order.append("local"))

	# Connect to EventBus signal
	EventBus.animal_mood_changed.connect(func(_animal: Node, _mood: String) -> void: emission_order.append("eventbus"))

	# Trigger mood change
	stats_component.set_mood(StatsComponent.Mood.NEUTRAL)

	# Verify order: local signal should emit before EventBus
	assert_eq(emission_order.size(), 2, "Both signals should emit")
	assert_eq(emission_order[0], "local", "Local signal should emit FIRST")
	assert_eq(emission_order[1], "eventbus", "EventBus signal should emit SECOND")

	# Note: Anonymous lambdas cannot be disconnected by reference.
	# GUT's after_each cleanup handles node removal which breaks connections.


func test_energy_signal_order_local_before_eventbus() -> void:
	## Test signal order for energy depletion
	stats_component.initialize(mock_stats)

	var emission_order: Array[String] = []

	# Connect to local signal
	stats_component.energy_changed.connect(func(_curr: int, _max: int) -> void: emission_order.append("local"))

	# Connect to EventBus signal (only fires when depleted)
	EventBus.animal_energy_depleted.connect(func(_animal: Node) -> void: emission_order.append("eventbus"))

	# Trigger energy depletion to 0
	stats_component.deplete_energy(3)

	# Verify order
	assert_eq(emission_order.size(), 2, "Both signals should emit")
	assert_eq(emission_order[0], "local", "Local signal should emit FIRST")
	assert_eq(emission_order[1], "eventbus", "EventBus signal should emit SECOND")

	# Note: Anonymous lambdas cannot be disconnected by reference.
	# GUT's after_each cleanup handles node removal which breaks connections.
