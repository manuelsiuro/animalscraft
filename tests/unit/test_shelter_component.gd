## Unit tests for ShelterComponent
## Tests capacity, recovery multiplier, signals, and edge cases.
##
## Story: 5-11-create-shelter-building-for-resting
extends GutTest

var shelter_component: ShelterComponent
var mock_building: Node3D
var mock_animals: Array[Node3D] = []

# Signal tracking
var _entered_signals: Array = []
var _left_signals: Array = []
var _capacity_reached_emitted: bool = false
var _capacity_available_emitted: bool = false

func before_each() -> void:
	# Reset signal tracking
	_entered_signals.clear()
	_left_signals.clear()
	_capacity_reached_emitted = false
	_capacity_available_emitted = false

	# Create mock building
	mock_building = Node3D.new()
	mock_building.set_meta("building_id", "shelter")
	add_child(mock_building)

	# Create ShelterComponent as child of mock building
	shelter_component = ShelterComponent.new()
	mock_building.add_child(shelter_component)
	await wait_frames(1)

	# Connect to local signals for testing
	shelter_component.animal_entered.connect(_on_animal_entered)
	shelter_component.animal_left.connect(_on_animal_left)
	shelter_component.capacity_reached.connect(_on_capacity_reached)
	shelter_component.capacity_available.connect(_on_capacity_available)

	# Create mock animals
	mock_animals.clear()
	for i in range(5):
		var animal := Node3D.new()
		animal.set_meta("animal_id", "test_animal_%d" % i)
		add_child(animal)
		mock_animals.append(animal)


func after_each() -> void:
	# Clean up mock animals
	for animal in mock_animals:
		if is_instance_valid(animal):
			animal.queue_free()
	mock_animals.clear()

	# Clean up mock building (will also clean up shelter_component)
	if is_instance_valid(mock_building):
		mock_building.queue_free()
	mock_building = null
	shelter_component = null


func _on_animal_entered(_animal: Node) -> void:
	_entered_signals.append(_animal)


func _on_animal_left(_animal: Node) -> void:
	_left_signals.append(_animal)


func _on_capacity_reached() -> void:
	_capacity_reached_emitted = true


func _on_capacity_available() -> void:
	_capacity_available_emitted = true


# =============================================================================
# INITIALIZATION TESTS
# =============================================================================

func test_shelter_component_initializes_automatically() -> void:
	await wait_frames(2)  # Allow deferred init

	assert_true(shelter_component.is_initialized(), "Should auto-initialize from parent")


func test_shelter_component_recovery_multiplier() -> void:
	assert_eq(shelter_component.get_recovery_multiplier(), 2.0, "Recovery multiplier should be 2.0")


func test_shelter_component_max_capacity() -> void:
	assert_eq(shelter_component.get_max_capacity(), 4, "Max capacity should be 4")


func test_shelter_component_initial_occupancy() -> void:
	assert_eq(shelter_component.get_occupancy(), 0, "Initial occupancy should be 0")


# =============================================================================
# CAPACITY TESTS (AC: 4)
# =============================================================================

func test_add_resting_animal_succeeds_with_capacity() -> void:
	var result := shelter_component.add_resting_animal(mock_animals[0])

	assert_true(result, "Should succeed when capacity available")
	assert_eq(shelter_component.get_occupancy(), 1)


func test_add_resting_animal_fails_when_full() -> void:
	# Fill to capacity
	for i in range(4):
		shelter_component.add_resting_animal(mock_animals[i])

	# Try to add 5th
	var result := shelter_component.add_resting_animal(mock_animals[4])

	assert_false(result, "Should fail when full")
	assert_eq(shelter_component.get_occupancy(), 4)


func test_remove_resting_animal_frees_capacity() -> void:
	shelter_component.add_resting_animal(mock_animals[0])
	assert_eq(shelter_component.get_occupancy(), 1)

	shelter_component.remove_resting_animal(mock_animals[0])

	assert_eq(shelter_component.get_occupancy(), 0)


func test_is_full_returns_true_at_capacity() -> void:
	for i in range(4):
		shelter_component.add_resting_animal(mock_animals[i])

	assert_true(shelter_component.is_full(), "Should be full at 4/4")


func test_is_full_returns_false_with_space() -> void:
	shelter_component.add_resting_animal(mock_animals[0])

	assert_false(shelter_component.is_full(), "Should not be full at 1/4")


func test_has_capacity_returns_true_with_space() -> void:
	shelter_component.add_resting_animal(mock_animals[0])

	assert_true(shelter_component.has_capacity(), "Should have capacity at 1/4")


func test_has_capacity_returns_false_when_full() -> void:
	for i in range(4):
		shelter_component.add_resting_animal(mock_animals[i])

	assert_false(shelter_component.has_capacity(), "Should not have capacity at 4/4")


# =============================================================================
# SIGNAL TESTS (AC: 14, 15, 16, 17)
# =============================================================================

func test_animal_entered_signal_emitted_on_add() -> void:
	shelter_component.add_resting_animal(mock_animals[0])

	assert_eq(_entered_signals.size(), 1, "Should emit animal_entered signal")
	assert_eq(_entered_signals[0], mock_animals[0])


func test_animal_left_signal_emitted_on_remove() -> void:
	shelter_component.add_resting_animal(mock_animals[0])
	shelter_component.remove_resting_animal(mock_animals[0])

	assert_eq(_left_signals.size(), 1, "Should emit animal_left signal")
	assert_eq(_left_signals[0], mock_animals[0])


func test_capacity_reached_signal_emitted_at_exactly_4() -> void:
	# Add 3 animals - should not emit capacity_reached yet
	for i in range(3):
		shelter_component.add_resting_animal(mock_animals[i])
	assert_false(_capacity_reached_emitted, "Should not emit at 3/4")

	# Add 4th animal - should emit capacity_reached
	shelter_component.add_resting_animal(mock_animals[3])

	assert_true(_capacity_reached_emitted, "Should emit capacity_reached at exactly 4/4")


func test_capacity_available_signal_emitted_when_going_from_full_to_space() -> void:
	# Fill to capacity
	for i in range(4):
		shelter_component.add_resting_animal(mock_animals[i])
	assert_false(_capacity_available_emitted, "Should not emit until going from full")

	# Remove one
	shelter_component.remove_resting_animal(mock_animals[0])

	assert_true(_capacity_available_emitted, "Should emit capacity_available when 4->3")


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_add_same_animal_twice_fails() -> void:
	shelter_component.add_resting_animal(mock_animals[0])
	var result := shelter_component.add_resting_animal(mock_animals[0])

	assert_false(result, "Should fail to add duplicate")
	assert_eq(shelter_component.get_occupancy(), 1)


func test_remove_animal_not_in_shelter_does_nothing() -> void:
	shelter_component.add_resting_animal(mock_animals[0])

	shelter_component.remove_resting_animal(mock_animals[1])  # Not in shelter

	assert_eq(shelter_component.get_occupancy(), 1, "Should not change occupancy")
	assert_eq(_left_signals.size(), 0, "Should not emit signal")


func test_add_null_animal_fails() -> void:
	var result := shelter_component.add_resting_animal(null)

	assert_false(result, "Should fail for null animal")
	assert_eq(shelter_component.get_occupancy(), 0)


func test_remove_all_animals_clears_occupancy() -> void:
	for i in range(3):
		shelter_component.add_resting_animal(mock_animals[i])
	assert_eq(shelter_component.get_occupancy(), 3)

	shelter_component.remove_all_animals()

	assert_eq(shelter_component.get_occupancy(), 0)
	assert_eq(_left_signals.size(), 3, "Should emit left signal for each animal")


func test_get_resting_animals_returns_copy() -> void:
	shelter_component.add_resting_animal(mock_animals[0])
	shelter_component.add_resting_animal(mock_animals[1])

	var animals := shelter_component.get_resting_animals()

	assert_eq(animals.size(), 2)
	# Modify returned array should not affect internal state
	animals.clear()
	assert_eq(shelter_component.get_occupancy(), 2, "Internal state should not be affected")


# =============================================================================
# CLEANUP TESTS (AC: 23)
# =============================================================================

func test_cleanup_removes_all_animals() -> void:
	for i in range(3):
		shelter_component.add_resting_animal(mock_animals[i])

	shelter_component.cleanup()

	# After cleanup, shelter should be empty
	assert_eq(_left_signals.size(), 3, "Should emit left signal for each animal on cleanup")
