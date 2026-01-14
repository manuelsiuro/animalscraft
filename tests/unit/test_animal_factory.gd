## Unit tests for AnimalFactory.
## Tests animal creation, stats loading, and error handling.
##
## Architecture: tests/unit/test_animal_factory.gd
## Story: 2-1-create-animal-entity-structure
extends GutTest

# =============================================================================
# FACTORY METHOD TESTS (AC5)
# =============================================================================

func test_create_rabbit_returns_animal() -> void:
	var hex := HexCoord.new(0, 0)

	var animal := AnimalFactory.create_animal("rabbit", hex)

	assert_not_null(animal, "Factory should return an animal")
	if animal:
		add_child(animal)
		await wait_frames(2)  # Wait for deferred initialize
		assert_true(animal.is_initialized(), "Animal should be initialized")
		animal.queue_free()


func test_create_unknown_type_returns_null() -> void:
	var hex := HexCoord.new(0, 0)

	var animal := AnimalFactory.create_animal("unknown_animal_type", hex)

	assert_null(animal, "Factory should return null for unknown type")


func test_created_animal_has_correct_stats() -> void:
	var hex := HexCoord.new(0, 0)

	var animal := AnimalFactory.create_animal("rabbit", hex)
	if animal:
		add_child(animal)
		await wait_frames(2)

		var stats: AnimalStats = animal.get_stats()
		assert_eq(stats.animal_id, "rabbit", "Animal ID should be 'rabbit'")
		assert_eq(stats.biome, "plains", "Biome should be 'plains'")
		animal.queue_free()
	else:
		fail_test("Failed to create rabbit")


func test_created_animal_is_in_animals_group() -> void:
	var hex := HexCoord.new(0, 0)

	var animal := AnimalFactory.create_animal("rabbit", hex)
	if animal:
		add_child(animal)
		await wait_frames(1)

		assert_true(animal.is_in_group("animals"), "Created animal should be in 'animals' group")
		animal.queue_free()
	else:
		fail_test("Failed to create rabbit")


func test_created_animal_is_node3d() -> void:
	var hex := HexCoord.new(0, 0)

	var animal := AnimalFactory.create_animal("rabbit", hex)
	if animal:
		# Must add to tree before queue_free to avoid orphans
		add_child(animal)
		await wait_frames(1)
		assert_true(animal is Node3D, "Created animal should be Node3D")
		animal.queue_free()
	else:
		fail_test("Failed to create rabbit")


func test_created_animal_positioned_at_hex() -> void:
	var hex := HexCoord.new(5, 3)

	var animal := AnimalFactory.create_animal("rabbit", hex)
	if animal:
		add_child(animal)
		await wait_frames(2)

		var expected_pos := HexGrid.hex_to_world(hex)
		assert_almost_eq(animal.position.x, expected_pos.x, 0.1, "X position should match")
		assert_almost_eq(animal.position.z, expected_pos.z, 0.1, "Z position should match")
		animal.queue_free()
	else:
		fail_test("Failed to create rabbit")


func test_create_with_null_hex() -> void:
	# Should handle null hex gracefully
	var animal := AnimalFactory.create_animal("rabbit", null)

	if animal:
		add_child(animal)
		await wait_frames(2)
		assert_true(animal.is_initialized(), "Should initialize even with null hex")
		animal.queue_free()
	else:
		fail_test("Factory should still return animal with null hex")

# =============================================================================
# UTILITY METHOD TESTS
# =============================================================================

func test_get_available_types_includes_rabbit() -> void:
	var types := AnimalFactory.get_available_types()

	assert_has(types, "rabbit", "Available types should include rabbit")


func test_get_available_types_returns_array() -> void:
	var types := AnimalFactory.get_available_types()

	assert_true(types is Array, "Should return an Array")
	assert_gt(types.size(), 0, "Should have at least one type")


func test_has_animal_type_true_for_rabbit() -> void:
	assert_true(AnimalFactory.has_animal_type("rabbit"), "Should have rabbit type")


func test_has_animal_type_false_for_unknown() -> void:
	assert_false(AnimalFactory.has_animal_type("dragon"), "Should not have dragon type")

# =============================================================================
# EVENT BUS INTEGRATION TESTS
# =============================================================================

func test_created_animal_emits_spawned_signal() -> void:
	var hex := HexCoord.new(0, 0)
	watch_signals(EventBus)

	var animal := AnimalFactory.create_animal("rabbit", hex)
	if animal:
		add_child(animal)
		await wait_frames(2)

		assert_signal_emitted(EventBus, "animal_spawned")
		animal.queue_free()
	else:
		fail_test("Failed to create rabbit")


func test_created_animal_signal_contains_correct_instance() -> void:
	var hex := HexCoord.new(0, 0)
	watch_signals(EventBus)

	var animal := AnimalFactory.create_animal("rabbit", hex)
	if animal:
		add_child(animal)
		await wait_frames(2)

		var params: Array = get_signal_parameters(EventBus, "animal_spawned")
		assert_eq(params[0], animal, "Signal should contain the created animal")
		animal.queue_free()
	else:
		fail_test("Failed to create rabbit")

# =============================================================================
# MULTIPLE ANIMAL TESTS
# =============================================================================

func test_create_multiple_animals() -> void:
	var animals: Array[Node3D] = []

	for i in range(3):
		var hex := HexCoord.new(i, 0)
		var animal := AnimalFactory.create_animal("rabbit", hex)
		if animal:
			animals.append(animal)
			add_child(animal)

	await wait_frames(2)

	assert_eq(animals.size(), 3, "Should create 3 animals")

	# Verify each is initialized
	for animal in animals:
		assert_true(animal.is_initialized(), "Each animal should be initialized")

	# Cleanup
	for animal in animals:
		animal.queue_free()


func test_multiple_animals_have_independent_positions() -> void:
	var hex1 := HexCoord.new(0, 0)
	var hex2 := HexCoord.new(5, 5)

	var animal1 := AnimalFactory.create_animal("rabbit", hex1)
	var animal2 := AnimalFactory.create_animal("rabbit", hex2)

	if animal1 and animal2:
		add_child(animal1)
		add_child(animal2)
		await wait_frames(2)

		var pos1 := animal1.position
		var pos2 := animal2.position

		assert_ne(pos1, pos2, "Animals should have different positions")

		animal1.queue_free()
		animal2.queue_free()
	else:
		fail_test("Failed to create animals")

# =============================================================================
# SCENE STRUCTURE VERIFICATION
# =============================================================================

func test_created_animal_has_expected_components() -> void:
	var hex := HexCoord.new(0, 0)

	var animal := AnimalFactory.create_animal("rabbit", hex)
	if animal:
		add_child(animal)
		await wait_frames(1)

		assert_true(animal.has_node("Visual"), "Should have Visual node")
		assert_true(animal.has_node("SelectableComponent"), "Should have SelectableComponent")
		assert_true(animal.has_node("MovementComponent"), "Should have MovementComponent")
		assert_true(animal.has_node("StatsComponent"), "Should have StatsComponent")

		animal.queue_free()
	else:
		fail_test("Failed to create rabbit")
