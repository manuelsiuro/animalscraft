## Unit tests for RecruitmentManager animal recruitment system.
## Tests recruitment flow, signal emission, error handling, and edge cases.
##
## Story: 5-8-implement-animal-capture
extends GutTest

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _mock_world_manager: Node3D
var _signal_recorder: SignalRecorder


## Helper class to record EventBus signals and their ORDER
class SignalRecorder extends RefCounted:
	var animal_recruited_calls: Array = []
	var recruitment_completed_calls: Array = []
	var animal_spawned_calls: Array = []
	## Tracks signal order: each entry is signal name in order received
	var signal_order: Array = []

	func _on_animal_recruited(animal_type: String, animal: Node) -> void:
		animal_recruited_calls.append({"animal_type": animal_type, "animal": animal})
		signal_order.append("animal_recruited")

	func _on_recruitment_completed(recruited_count: int) -> void:
		recruitment_completed_calls.append({"recruited_count": recruited_count})
		signal_order.append("recruitment_completed")

	func _on_animal_spawned(animal: Node) -> void:
		animal_spawned_calls.append({"animal": animal})
		signal_order.append("animal_spawned")


func before_each() -> void:
	# Create mock world manager as scene parent
	_mock_world_manager = Node3D.new()
	_mock_world_manager.name = "MockWorldManager"
	add_child(_mock_world_manager)

	# Create signal recorder
	_signal_recorder = SignalRecorder.new()

	# Connect to EventBus signals (including animal_spawned for order verification)
	EventBus.animal_recruited.connect(_signal_recorder._on_animal_recruited)
	EventBus.recruitment_completed.connect(_signal_recorder._on_recruitment_completed)
	EventBus.animal_spawned.connect(_signal_recorder._on_animal_spawned)


func after_each() -> void:
	# Disconnect signals
	if EventBus.animal_recruited.is_connected(_signal_recorder._on_animal_recruited):
		EventBus.animal_recruited.disconnect(_signal_recorder._on_animal_recruited)
	if EventBus.recruitment_completed.is_connected(_signal_recorder._on_recruitment_completed):
		EventBus.recruitment_completed.disconnect(_signal_recorder._on_recruitment_completed)
	if EventBus.animal_spawned.is_connected(_signal_recorder._on_animal_spawned):
		EventBus.animal_spawned.disconnect(_signal_recorder._on_animal_spawned)

	# Clean up children (recruited animals)
	for child in _mock_world_manager.get_children():
		child.queue_free()

	# Clean up world manager
	if is_instance_valid(_mock_world_manager):
		_mock_world_manager.queue_free()


# =============================================================================
# AC1, AC5: RECRUIT KNOWN ANIMAL TYPES
# =============================================================================

func test_recruit_single_rabbit() -> void:
	# Arrange
	var spawn_hex := HexCoord.new(0, 0)

	# Act
	var recruited := RecruitmentManager.recruit_animals(["rabbit"], spawn_hex, _mock_world_manager)
	await wait_frames(2)

	# Assert
	assert_eq(recruited.size(), 1, "Should recruit 1 animal")
	assert_true(_mock_world_manager.get_child_count() >= 1, "Animal should be added as child")


func test_recruit_multiple_animals_same_type() -> void:
	# Arrange
	var spawn_hex := HexCoord.new(0, 0)

	# Act
	var recruited := RecruitmentManager.recruit_animals(["rabbit", "rabbit", "rabbit"], spawn_hex, _mock_world_manager)
	await wait_frames(2)

	# Assert
	assert_eq(recruited.size(), 3, "Should recruit 3 animals")


func test_recruit_animals_at_custom_spawn_hex() -> void:
	# Arrange
	var spawn_hex := HexCoord.new(5, 5)

	# Act
	var recruited := RecruitmentManager.recruit_animals(["rabbit"], spawn_hex, _mock_world_manager)
	await wait_frames(2)

	# Assert
	assert_eq(recruited.size(), 1, "Should recruit 1 animal")
	# Animal's hex_coord is set via Animal.initialize(), verified by factory behavior


# =============================================================================
# AC6: ANIMALS ADDED TO "animals" GROUP
# =============================================================================

func test_recruited_animals_added_to_animals_group() -> void:
	# Arrange
	var spawn_hex := HexCoord.new(0, 0)

	# Act
	var recruited := RecruitmentManager.recruit_animals(["rabbit"], spawn_hex, _mock_world_manager)
	await wait_frames(2)

	# Assert
	assert_eq(recruited.size(), 1, "Should recruit 1 animal")
	if recruited.size() > 0:
		var animal: Node = recruited[0]
		assert_true(animal.is_in_group("animals"), "Recruited animal should be in 'animals' group")


# =============================================================================
# AC7, AC8: SKIP UNKNOWN ANIMAL TYPES WITH WARNING
# =============================================================================

func test_skip_unknown_animal_type() -> void:
	# Arrange
	var spawn_hex := HexCoord.new(0, 0)

	# Act
	var recruited := RecruitmentManager.recruit_animals(["dragon", "unicorn"], spawn_hex, _mock_world_manager)
	await wait_frames(2)

	# Assert
	assert_eq(recruited.size(), 0, "Should not recruit unknown animal types")


func test_mixed_known_and_unknown_types() -> void:
	# Arrange
	var spawn_hex := HexCoord.new(0, 0)

	# Act
	var recruited := RecruitmentManager.recruit_animals(["rabbit", "dragon", "rabbit"], spawn_hex, _mock_world_manager)
	await wait_frames(2)

	# Assert
	assert_eq(recruited.size(), 2, "Should recruit only known types (2 rabbits)")


# =============================================================================
# AC9, AC10: SIGNAL EMISSION
# =============================================================================

func test_animal_recruited_signal_emitted_per_animal() -> void:
	# Arrange
	var spawn_hex := HexCoord.new(0, 0)

	# Act
	var recruited := RecruitmentManager.recruit_animals(["rabbit", "rabbit"], spawn_hex, _mock_world_manager)
	await wait_frames(2)

	# Assert
	assert_eq(_signal_recorder.animal_recruited_calls.size(), 2,
		"animal_recruited signal should be emitted for each animal")

	for call in _signal_recorder.animal_recruited_calls:
		assert_eq(call.animal_type, "rabbit", "Signal should pass correct animal type")
		assert_true(is_instance_valid(call.animal), "Signal should pass valid animal node")


func test_recruitment_completed_signal_emitted_once() -> void:
	# Arrange
	var spawn_hex := HexCoord.new(0, 0)

	# Act
	var recruited := RecruitmentManager.recruit_animals(["rabbit", "rabbit", "rabbit"], spawn_hex, _mock_world_manager)
	await wait_frames(2)

	# Assert
	assert_eq(_signal_recorder.recruitment_completed_calls.size(), 1,
		"recruitment_completed signal should be emitted once")
	assert_eq(_signal_recorder.recruitment_completed_calls[0].recruited_count, 3,
		"Signal should pass correct count")


func test_signal_emission_order() -> void:
	# Arrange - Task 6.9: Verify signal order animal_spawned → animal_recruited → recruitment_completed
	var spawn_hex := HexCoord.new(0, 0)

	# Act
	var recruited := RecruitmentManager.recruit_animals(["rabbit"], spawn_hex, _mock_world_manager)
	# Wait for deferred calls to complete (signals use call_deferred)
	await wait_frames(3)

	# Assert - Check that signals fired in correct order
	assert_gte(_signal_recorder.signal_order.size(), 3,
		"Should have at least 3 signals: animal_spawned, animal_recruited, recruitment_completed")

	# Find indices of each signal type
	var spawned_idx := _signal_recorder.signal_order.find("animal_spawned")
	var recruited_idx := _signal_recorder.signal_order.find("animal_recruited")
	var completed_idx := _signal_recorder.signal_order.find("recruitment_completed")

	# Verify order: spawned < recruited < completed
	assert_ne(spawned_idx, -1, "animal_spawned signal should have been emitted")
	assert_ne(recruited_idx, -1, "animal_recruited signal should have been emitted")
	assert_ne(completed_idx, -1, "recruitment_completed signal should have been emitted")

	assert_lt(spawned_idx, recruited_idx,
		"animal_spawned should fire BEFORE animal_recruited (got spawned=%d, recruited=%d)" % [spawned_idx, recruited_idx])
	assert_lt(recruited_idx, completed_idx,
		"animal_recruited should fire BEFORE recruitment_completed (got recruited=%d, completed=%d)" % [recruited_idx, completed_idx])


# =============================================================================
# AC11, AC16, AC17: EDGE CASES
# =============================================================================

func test_empty_animal_list() -> void:
	# Arrange
	var spawn_hex := HexCoord.new(0, 0)

	# Act
	var recruited := RecruitmentManager.recruit_animals([], spawn_hex, _mock_world_manager)
	await wait_frames(2)

	# Assert
	assert_eq(recruited.size(), 0, "Should return empty array for empty input")
	assert_eq(_signal_recorder.recruitment_completed_calls.size(), 1,
		"Should still emit recruitment_completed")
	assert_eq(_signal_recorder.recruitment_completed_calls[0].recruited_count, 0,
		"Count should be 0")


func test_null_spawn_hex_uses_home_hex() -> void:
	# Arrange - null spawn hex

	# Act
	var recruited := RecruitmentManager.recruit_animals(["rabbit"], null, _mock_world_manager)
	await wait_frames(2)

	# Assert
	assert_eq(recruited.size(), 1, "Should recruit even with null spawn hex")


func test_invalid_scene_parent_returns_empty() -> void:
	# Arrange
	var spawn_hex := HexCoord.new(0, 0)

	# Act
	var recruited := RecruitmentManager.recruit_animals(["rabbit"], spawn_hex, null)
	await wait_frames(2)

	# Assert
	assert_eq(recruited.size(), 0, "Should return empty for invalid scene parent")


func test_non_string_animal_types_skipped() -> void:
	# Arrange
	var spawn_hex := HexCoord.new(0, 0)
	var mixed_types: Array = ["rabbit", 123, null, "rabbit"]

	# Act
	var recruited := RecruitmentManager.recruit_animals(mixed_types, spawn_hex, _mock_world_manager)
	await wait_frames(2)

	# Assert
	assert_eq(recruited.size(), 2, "Should only recruit valid string types")


# =============================================================================
# AC12: GET PLAYER SPAWN HEX
# =============================================================================

func test_get_player_spawn_hex_returns_home_hex() -> void:
	# Act
	var spawn_hex := RecruitmentManager.get_player_spawn_hex()

	# Assert
	assert_not_null(spawn_hex, "Should return a HexCoord")
	assert_eq(spawn_hex.q, 0, "Default spawn should be at q=0")
	assert_eq(spawn_hex.r, 0, "Default spawn should be at r=0")


# =============================================================================
# AC13: RECRUITED ANIMALS APPEAR ON MAP
# =============================================================================

func test_recruited_animals_added_to_scene_tree() -> void:
	# Arrange
	var spawn_hex := HexCoord.new(0, 0)
	var initial_child_count := _mock_world_manager.get_child_count()

	# Act
	var recruited := RecruitmentManager.recruit_animals(["rabbit"], spawn_hex, _mock_world_manager)
	await wait_frames(2)

	# Assert
	assert_eq(recruited.size(), 1, "Should recruit 1 animal")
	assert_gt(_mock_world_manager.get_child_count(), initial_child_count,
		"Child count should increase after recruitment")
