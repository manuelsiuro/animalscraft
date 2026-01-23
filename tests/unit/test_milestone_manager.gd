## Unit tests for MilestoneManager autoload.
##
## Tests milestone tracking, achievement detection, and persistence.
##
## Architecture: tests/unit/test_milestone_manager.gd
## Story: 6-5-implement-milestone-system
extends GutTest

# =============================================================================
# TEST DATA
# =============================================================================

## Store original milestone state for restoration
var _original_achieved: Dictionary = {}
var _original_counts: Dictionary = {}
var _original_first_buildings: Dictionary = {}
var _original_first_productions: Dictionary = {}

# =============================================================================
# LIFECYCLE
# =============================================================================

func before_each() -> void:
	# Store original state
	_original_achieved = MilestoneManager._achieved.duplicate()
	_original_counts = MilestoneManager._counts.duplicate()
	_original_first_buildings = MilestoneManager._first_buildings.duplicate()
	_original_first_productions = MilestoneManager._first_productions.duplicate()

	# Reset for clean test
	MilestoneManager.reset()
	await wait_frames(1)


func after_each() -> void:
	# Restore original state
	MilestoneManager._achieved = _original_achieved.duplicate()
	MilestoneManager._counts = _original_counts.duplicate()
	MilestoneManager._first_buildings = _original_first_buildings.duplicate()
	MilestoneManager._first_productions = _original_first_productions.duplicate()

# =============================================================================
# TEST: MILESTONE DATA RESOURCE (AC1)
# =============================================================================

func test_milestone_data_resource_loads() -> void:
	# Arrange - load a known milestone
	var milestone := load("res://resources/milestones/pop_5.tres") as MilestoneData

	# Assert
	assert_not_null(milestone, "Milestone resource should load (AC1)")
	assert_eq(milestone.id, "pop_5", "Milestone should have correct ID")
	assert_eq(milestone.display_name, "Growing Community", "Milestone should have display name")
	assert_eq(milestone.threshold, 5, "Population milestone should have threshold 5")
	assert_eq(milestone.type, MilestoneData.Type.POPULATION, "Should be POPULATION type")


func test_all_milestone_types_exist() -> void:
	# Arrange - check all types are loadable
	var population := load("res://resources/milestones/pop_10.tres") as MilestoneData
	var building := load("res://resources/milestones/first_farm.tres") as MilestoneData
	var territory := load("res://resources/milestones/territory_10.tres") as MilestoneData
	var combat := load("res://resources/milestones/first_win.tres") as MilestoneData
	var production := load("res://resources/milestones/first_bread.tres") as MilestoneData

	# Assert
	assert_eq(population.type, MilestoneData.Type.POPULATION, "Should have POPULATION type (AC1)")
	assert_eq(building.type, MilestoneData.Type.BUILDING, "Should have BUILDING type (AC1)")
	assert_eq(territory.type, MilestoneData.Type.TERRITORY, "Should have TERRITORY type (AC1)")
	assert_eq(combat.type, MilestoneData.Type.COMBAT, "Should have COMBAT type (AC1)")
	assert_eq(production.type, MilestoneData.Type.PRODUCTION, "Should have PRODUCTION type (AC1)")


func test_milestone_manager_loads_all_milestones() -> void:
	# Assert - MilestoneManager should have loaded milestones
	var milestones := MilestoneManager.get_all_milestones()
	assert_gte(milestones.size(), 17, "Should have at least 17 milestones loaded (AC1)")

# =============================================================================
# TEST: POPULATION MILESTONES (AC2)
# =============================================================================

func test_population_milestone_triggers_at_threshold() -> void:
	# Arrange
	watch_signals(EventBus)
	watch_signals(MilestoneManager)

	# Create mock animal
	var mock_animal := _create_mock_animal(false)
	add_child(mock_animal)
	await wait_frames(1)

	# Act - emit animal_spawned 5 times
	for i in range(5):
		EventBus.animal_spawned.emit(mock_animal)
	await wait_frames(1)

	# Assert
	assert_signal_emitted(EventBus, "milestone_reached", "milestone_reached should emit at pop 5 (AC2)")
	assert_true(MilestoneManager.is_milestone_achieved("pop_5"), "pop_5 should be achieved (AC2)")

	# Cleanup
	mock_animal.queue_free()


func test_population_milestone_not_triggered_below_threshold() -> void:
	# Arrange
	watch_signals(EventBus)
	var mock_animal := _create_mock_animal(false)
	add_child(mock_animal)
	await wait_frames(1)

	# Act - emit only 4 times
	for i in range(4):
		EventBus.animal_spawned.emit(mock_animal)
	await wait_frames(1)

	# Assert
	assert_false(MilestoneManager.is_milestone_achieved("pop_5"), "pop_5 should NOT be achieved at 4 animals (AC2)")

	# Cleanup
	mock_animal.queue_free()


func test_multiple_population_milestones_can_trigger() -> void:
	# Arrange
	var mock_animal := _create_mock_animal(false)
	add_child(mock_animal)
	await wait_frames(1)

	# Act - emit 10 times to trigger both pop_5 and pop_10
	for i in range(10):
		EventBus.animal_spawned.emit(mock_animal)
	await wait_frames(1)

	# Assert
	assert_true(MilestoneManager.is_milestone_achieved("pop_5"), "pop_5 should be achieved (AC2)")
	assert_true(MilestoneManager.is_milestone_achieved("pop_10"), "pop_10 should be achieved (AC2)")

	# Cleanup
	mock_animal.queue_free()


func test_wild_animals_not_counted_for_population() -> void:
	# Arrange
	var wild_animal := _create_mock_animal(true)  # is_wild = true
	add_child(wild_animal)
	await wait_frames(1)

	# Act - emit for wild animal
	for i in range(5):
		EventBus.animal_spawned.emit(wild_animal)
	await wait_frames(1)

	# Assert
	assert_false(MilestoneManager.is_milestone_achieved("pop_5"), "Wild animals should not count for population (AC2)")

	# Cleanup
	wild_animal.queue_free()


func test_animal_removal_decrements_population_count() -> void:
	# Arrange - spawn 6 animals to trigger pop_5
	var mock_animal := _create_mock_animal(false)
	add_child(mock_animal)
	await wait_frames(1)

	for i in range(6):
		EventBus.animal_spawned.emit(mock_animal)
	await wait_frames(1)

	# Verify initial count
	var progress_before := MilestoneManager.get_progress("population")
	assert_eq(progress_before["current"], 6, "Should have 6 animals before removal")

	# Act - remove 2 animals
	EventBus.animal_removed.emit(mock_animal)
	EventBus.animal_removed.emit(mock_animal)
	await wait_frames(1)

	# Assert
	var progress_after := MilestoneManager.get_progress("population")
	assert_eq(progress_after["current"], 4, "Should have 4 animals after removal (AC2)")

	# Verify milestone stays achieved (once achieved, stays achieved)
	assert_true(MilestoneManager.is_milestone_achieved("pop_5"), "pop_5 should stay achieved after removal (AC2)")

	# Cleanup
	mock_animal.queue_free()


func test_animal_removal_does_not_go_negative() -> void:
	# Arrange
	var mock_animal := _create_mock_animal(false)
	add_child(mock_animal)
	await wait_frames(1)

	# Act - try to remove when count is 0
	EventBus.animal_removed.emit(mock_animal)
	await wait_frames(1)

	# Assert
	var progress := MilestoneManager.get_progress("population")
	assert_eq(progress["current"], 0, "Population should not go negative (AC2)")

	# Cleanup
	mock_animal.queue_free()

# =============================================================================
# TEST: BUILDING MILESTONES (AC3)
# =============================================================================

func test_building_milestone_triggers_on_first_placement() -> void:
	# Arrange
	watch_signals(EventBus)
	var mock_building := _create_mock_building("farm")
	add_child(mock_building)
	await wait_frames(1)

	# Act
	EventBus.building_placed.emit(mock_building, Vector2i(0, 0))
	await wait_frames(1)

	# Assert
	assert_signal_emitted(EventBus, "milestone_reached", "milestone_reached should emit for first farm (AC3)")
	assert_true(MilestoneManager.is_milestone_achieved("first_farm"), "first_farm should be achieved (AC3)")

	# Cleanup
	mock_building.queue_free()


func test_building_milestone_not_retriggered_on_second_placement() -> void:
	# Arrange
	var mock_building := _create_mock_building("farm")
	add_child(mock_building)
	await wait_frames(1)

	# First placement
	EventBus.building_placed.emit(mock_building, Vector2i(0, 0))
	await wait_frames(1)

	# Clear signal tracking
	watch_signals(MilestoneManager)

	# Act - second placement
	EventBus.building_placed.emit(mock_building, Vector2i(1, 0))
	await wait_frames(1)

	# Assert
	assert_signal_not_emitted(MilestoneManager, "_milestone_triggered", "Should not retrigger on second farm (AC3)")

	# Cleanup
	mock_building.queue_free()


func test_different_building_types_trigger_separately() -> void:
	# Arrange
	var farm := _create_mock_building("farm")
	var mill := _create_mock_building("mill")
	add_child(farm)
	add_child(mill)
	await wait_frames(1)

	# Act
	EventBus.building_placed.emit(farm, Vector2i(0, 0))
	EventBus.building_placed.emit(mill, Vector2i(1, 0))
	await wait_frames(1)

	# Assert
	assert_true(MilestoneManager.is_milestone_achieved("first_farm"), "first_farm should be achieved (AC3)")
	assert_true(MilestoneManager.is_milestone_achieved("first_mill"), "first_mill should be achieved (AC3)")

	# Cleanup
	farm.queue_free()
	mill.queue_free()

# =============================================================================
# TEST: TERRITORY MILESTONES (AC4)
# =============================================================================

func test_territory_milestone_triggers_at_threshold() -> void:
	# Arrange
	watch_signals(EventBus)

	# Act - claim 10 territories
	for i in range(10):
		EventBus.territory_claimed.emit(Vector2i(i, 0))
	await wait_frames(1)

	# Assert
	assert_signal_emitted(EventBus, "milestone_reached", "milestone_reached should emit at 10 territories (AC4)")
	assert_true(MilestoneManager.is_milestone_achieved("territory_10"), "territory_10 should be achieved (AC4)")


func test_territory_progress_tracking() -> void:
	# Arrange - claim 5 territories
	for i in range(5):
		EventBus.territory_claimed.emit(Vector2i(i, 0))
	await wait_frames(1)

	# Act
	var progress := MilestoneManager.get_progress("territory")

	# Assert
	assert_eq(progress["current"], 5, "Territory count should be 5 (AC9)")
	assert_eq(progress["target"], 10, "Next territory target should be 10 (AC9)")

# =============================================================================
# TEST: COMBAT MILESTONES (AC5)
# =============================================================================

func test_combat_milestone_triggers_at_threshold() -> void:
	# Arrange
	watch_signals(EventBus)

	# Act - win first combat
	EventBus.combat_ended.emit(true, [])
	await wait_frames(1)

	# Assert
	assert_signal_emitted(EventBus, "milestone_reached", "milestone_reached should emit on first win (AC5)")
	assert_true(MilestoneManager.is_milestone_achieved("first_win"), "first_win should be achieved (AC5)")


func test_combat_loss_not_counted() -> void:
	# Arrange
	watch_signals(EventBus)

	# Act - lose 5 combats
	for i in range(5):
		EventBus.combat_ended.emit(false, [])
	await wait_frames(1)

	# Assert
	assert_false(MilestoneManager.is_milestone_achieved("first_win"), "Losses should not trigger first_win (AC5)")


func test_combat_wins_accumulate() -> void:
	# Act - win 5 combats
	for i in range(5):
		EventBus.combat_ended.emit(true, [])
	await wait_frames(1)

	# Assert
	assert_true(MilestoneManager.is_milestone_achieved("first_win"), "first_win should be achieved (AC5)")
	assert_true(MilestoneManager.is_milestone_achieved("wins_5"), "wins_5 should be achieved (AC5)")

# =============================================================================
# TEST: PRODUCTION MILESTONES (AC6)
# =============================================================================

func test_production_milestone_triggers_on_first_bread() -> void:
	# Arrange
	watch_signals(EventBus)
	var mock_building := _create_mock_building("bakery")
	add_child(mock_building)
	await wait_frames(1)

	# Act
	EventBus.production_completed.emit(mock_building, "bread")
	await wait_frames(1)

	# Assert
	assert_signal_emitted(EventBus, "milestone_reached", "milestone_reached should emit on first bread (AC6)")
	assert_true(MilestoneManager.is_milestone_achieved("first_bread"), "first_bread should be achieved (AC6)")

	# Cleanup
	mock_building.queue_free()


func test_production_milestone_not_retriggered() -> void:
	# Arrange
	var mock_building := _create_mock_building("bakery")
	add_child(mock_building)
	await wait_frames(1)

	# First bread
	EventBus.production_completed.emit(mock_building, "bread")
	await wait_frames(1)

	watch_signals(MilestoneManager)

	# Act - second bread
	EventBus.production_completed.emit(mock_building, "bread")
	await wait_frames(1)

	# Assert
	assert_signal_not_emitted(MilestoneManager, "_milestone_triggered", "Should not retrigger on second bread (AC6)")

	# Cleanup
	mock_building.queue_free()


func test_milestone_unlock_rewards_emits_building_unlocked() -> void:
	# Arrange - modify a milestone to have unlock rewards for testing
	var milestone := MilestoneManager.get_milestone("pop_5")
	var original_rewards := milestone.unlock_rewards.duplicate()
	milestone.unlock_rewards = ["advanced_farm", "windmill"]

	watch_signals(EventBus)

	var mock_animal := _create_mock_animal(false)
	add_child(mock_animal)
	await wait_frames(1)

	# Act - trigger pop_5 milestone
	for i in range(5):
		EventBus.animal_spawned.emit(mock_animal)
	await wait_frames(1)

	# Assert - building_unlocked should be emitted for each unlock reward
	assert_signal_emitted(EventBus, "building_unlocked", "building_unlocked should emit for unlock rewards")

	# Restore original rewards
	milestone.unlock_rewards = original_rewards

	# Cleanup
	mock_animal.queue_free()

# =============================================================================
# TEST: MILESTONE PERSISTENCE (AC7)
# =============================================================================

func test_milestone_persistence_save_load() -> void:
	# Arrange - achieve some milestones
	var mock_animal := _create_mock_animal(false)
	add_child(mock_animal)
	await wait_frames(1)

	for i in range(5):
		EventBus.animal_spawned.emit(mock_animal)
	EventBus.territory_claimed.emit(Vector2i(0, 0))
	await wait_frames(1)

	# Verify initial state
	assert_true(MilestoneManager.is_milestone_achieved("pop_5"), "pop_5 should be achieved before save")

	# Act - save data
	var save_data := MilestoneManager.get_save_data()

	# Reset
	MilestoneManager.reset()
	assert_false(MilestoneManager.is_milestone_achieved("pop_5"), "pop_5 should NOT be achieved after reset")

	# Load data
	MilestoneManager.load_save_data(save_data)

	# Assert
	assert_true(MilestoneManager.is_milestone_achieved("pop_5"), "pop_5 should be restored after load (AC7)")
	assert_eq(MilestoneManager._counts["territory"], 1, "Territory count should be restored (AC7)")

	# Cleanup
	mock_animal.queue_free()


func test_milestone_not_retriggered_after_load() -> void:
	# Arrange - achieve milestone and save
	var mock_animal := _create_mock_animal(false)
	add_child(mock_animal)
	await wait_frames(1)

	for i in range(5):
		EventBus.animal_spawned.emit(mock_animal)
	await wait_frames(1)

	var save_data := MilestoneManager.get_save_data()
	MilestoneManager.reset()
	MilestoneManager.load_save_data(save_data)

	# Start watching signals after load
	watch_signals(EventBus)
	watch_signals(MilestoneManager)

	# Act - spawn more animals (should not re-trigger pop_5)
	EventBus.animal_spawned.emit(mock_animal)
	await wait_frames(1)

	# Assert - pop_5 should NOT retrigger
	assert_signal_not_emitted(MilestoneManager, "_milestone_triggered", "Achieved milestone should not retrigger after load (AC7)")

	# Cleanup
	mock_animal.queue_free()

# =============================================================================
# TEST: PUBLIC API (AC8)
# =============================================================================

func test_get_achieved_milestones_returns_array() -> void:
	# Arrange - achieve a milestone
	var mock_animal := _create_mock_animal(false)
	add_child(mock_animal)
	await wait_frames(1)

	for i in range(5):
		EventBus.animal_spawned.emit(mock_animal)
	await wait_frames(1)

	# Act
	var achieved := MilestoneManager.get_achieved_milestones()

	# Assert
	assert_true(achieved is Array, "get_achieved_milestones should return Array (AC8)")
	assert_true(achieved.has("pop_5"), "Should contain pop_5 (AC8)")

	# Cleanup
	mock_animal.queue_free()


func test_is_milestone_achieved_returns_correct_state() -> void:
	# Assert initial state
	assert_false(MilestoneManager.is_milestone_achieved("pop_5"), "pop_5 should not be achieved initially (AC8)")
	assert_false(MilestoneManager.is_milestone_achieved("nonexistent"), "Nonexistent milestone should return false (AC8)")


func test_get_milestone_returns_data() -> void:
	# Act
	var milestone := MilestoneManager.get_milestone("pop_5")

	# Assert
	assert_not_null(milestone, "get_milestone should return MilestoneData (AC8)")
	assert_eq(milestone.id, "pop_5", "Should return correct milestone (AC8)")


func test_get_milestone_returns_null_for_nonexistent() -> void:
	# Act
	var milestone := MilestoneManager.get_milestone("nonexistent")

	# Assert
	assert_null(milestone, "get_milestone should return null for nonexistent ID (AC8)")

# =============================================================================
# TEST: PROGRESS TRACKING (AC9)
# =============================================================================

func test_get_progress_returns_current_and_target() -> void:
	# Arrange - spawn 3 animals
	var mock_animal := _create_mock_animal(false)
	add_child(mock_animal)
	await wait_frames(1)

	for i in range(3):
		EventBus.animal_spawned.emit(mock_animal)
	await wait_frames(1)

	# Act
	var progress := MilestoneManager.get_progress("population")

	# Assert
	assert_true(progress.has("current"), "Progress should have 'current' key (AC9)")
	assert_true(progress.has("target"), "Progress should have 'target' key (AC9)")
	assert_eq(progress["current"], 3, "Current should be 3 (AC9)")
	assert_eq(progress["target"], 5, "Target should be 5 (next milestone threshold) (AC9)")

	# Cleanup
	mock_animal.queue_free()


func test_get_progress_invalid_type() -> void:
	# Act
	var progress := MilestoneManager.get_progress("invalid_type")

	# Assert
	assert_true(progress.is_empty(), "Invalid type should return empty Dictionary (AC9)")

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

## Create a mock Animal node for testing.
## Uses actual Animal class to ensure proper type checking.
## NOTE: Creates minimal Animal for signal testing only - does not set up
## full node tree, stats, or AI state that a real Animal would have.
func _create_mock_animal(is_wild_flag: bool) -> Animal:
	var animal := Animal.new()
	animal.name = "MockAnimal"
	animal.is_wild = is_wild_flag
	return animal


## Create a mock Building node for testing.
## Uses actual Building class with BuildingData.
## NOTE: Creates minimal Building for signal testing only - does not call
## _setup_visuals(), add to groups, or initialize production state.
## This is sufficient for MilestoneManager which only checks building.data.building_id.
func _create_mock_building(building_id: String) -> Building:
	var building := Building.new()
	building.name = "MockBuilding"

	# Create BuildingData with the specified ID
	var building_data := BuildingData.new()
	building_data.building_id = building_id
	building.data = building_data

	return building
