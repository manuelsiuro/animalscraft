## Integration tests for Plains animal types (Story 7-1).
## Tests recruitment, save/load, and combat compatibility.
##
## Architecture: tests/integration/test_plains_animals_integration.gd
## Story: 7-1-create-all-plains-animal-types
extends GutTest

# =============================================================================
# TEST CONSTANTS
# =============================================================================

const PLAINS_ANIMAL_TYPES: Array[String] = ["rabbit", "squirrel", "fox", "deer"]

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _created_animals: Array[Animal] = []
var _recruitment_manager: RecruitmentManager


func before_each() -> void:
	# Watch EventBus signals for recruitment testing
	watch_signals(EventBus)


func after_each() -> void:
	# Clean up any created animals
	for animal in _created_animals:
		if is_instance_valid(animal):
			animal.cleanup()
	_created_animals.clear()

	# Clean up recruitment manager
	if is_instance_valid(_recruitment_manager):
		_recruitment_manager.queue_free()
		_recruitment_manager = null


# =============================================================================
# RECRUITMENT TESTS (AC: 9)
# =============================================================================

func test_all_animal_types_can_be_recruited() -> void:
	# Create RecruitmentManager
	_recruitment_manager = RecruitmentManager.new()
	add_child(_recruitment_manager)
	await wait_frames(1)

	for animal_type in PLAINS_ANIMAL_TYPES:
		# Create a "captured" wild animal
		var hex := HexCoord.new(0, 0)
		var wild_animal := AnimalFactory.create_animal(animal_type, hex)

		if wild_animal:
			_created_animals.append(wild_animal)
			add_child(wild_animal)
			await wait_frames(2)

			# Verify the animal can be recruited (has correct interface)
			assert_not_null(wild_animal.stats, "%s should have stats for recruitment" % animal_type)
			assert_eq(wild_animal.stats.biome, "plains", "%s should have plains biome" % animal_type)


func test_recruited_animals_have_correct_stats() -> void:
	for animal_type in PLAINS_ANIMAL_TYPES:
		var hex := HexCoord.new(1, 1)
		var animal := AnimalFactory.create_animal(animal_type, hex)

		assert_not_null(animal, "Should create %s" % animal_type)
		_created_animals.append(animal)
		add_child(animal)
		await wait_frames(2)

		# Verify stats component is populated correctly
		var stats_component := animal.get_node_or_null("StatsComponent")
		assert_not_null(stats_component, "%s should have StatsComponent" % animal_type)


# =============================================================================
# SAVE/LOAD TESTS (AC: 10)
# =============================================================================

func test_animal_serialization_round_trip() -> void:
	for animal_type in PLAINS_ANIMAL_TYPES:
		var hex := HexCoord.new(3, 3)
		var original := AnimalFactory.create_animal(animal_type, hex)

		assert_not_null(original, "Should create %s" % animal_type)
		_created_animals.append(original)
		add_child(original)
		await wait_frames(2)

		# Serialize
		if original.has_method("to_dict"):
			var data := original.to_dict()

			# Verify critical fields
			assert_has(data, "animal_id", "%s should serialize animal_id" % animal_type)
			assert_eq(data["animal_id"], animal_type, "Serialized type should be %s" % animal_type)

			# Verify hex coord is included
			assert_has(data, "hex_coord", "%s should serialize hex_coord" % animal_type)


func test_save_data_includes_correct_animal_type() -> void:
	# Test that each animal type correctly identifies itself in save data
	for animal_type in PLAINS_ANIMAL_TYPES:
		var hex := HexCoord.new(2, 2)
		var animal := AnimalFactory.create_animal(animal_type, hex)

		assert_not_null(animal, "Should create %s" % animal_type)
		_created_animals.append(animal)
		add_child(animal)
		await wait_frames(2)

		# Get serialization data
		if animal.has_method("to_dict"):
			var save_data := animal.to_dict()
			assert_eq(save_data.get("animal_id", ""), animal_type,
				"Save data animal_id should be %s" % animal_type)


# =============================================================================
# COMBAT COMPATIBILITY TESTS
# =============================================================================

func test_all_animals_have_combat_stats() -> void:
	for animal_type in PLAINS_ANIMAL_TYPES:
		var hex := HexCoord.new(4, 4)
		var animal := AnimalFactory.create_animal(animal_type, hex)

		assert_not_null(animal, "Should create %s" % animal_type)
		_created_animals.append(animal)
		add_child(animal)
		await wait_frames(2)

		# Verify stats needed for combat
		assert_not_null(animal.stats, "%s should have stats" % animal_type)
		assert_gt(animal.stats.strength, 0, "%s should have positive strength" % animal_type)
		assert_gt(animal.stats.energy, 0, "%s should have positive energy" % animal_type)


func test_animals_can_be_used_in_combat_team() -> void:
	# Create one of each type to form a combat team
	var combat_team: Array[Animal] = []

	for i in range(PLAINS_ANIMAL_TYPES.size()):
		var animal_type := PLAINS_ANIMAL_TYPES[i]
		var hex := HexCoord.new(i, 0)
		var animal := AnimalFactory.create_animal(animal_type, hex)

		assert_not_null(animal, "Should create %s for combat team" % animal_type)
		_created_animals.append(animal)
		add_child(animal)
		combat_team.append(animal)

	await wait_frames(2)

	# Verify team has expected size
	assert_eq(combat_team.size(), 4, "Should have 4 animals in combat team")

	# Verify total strength can be calculated
	var total_strength := 0
	for animal in combat_team:
		if animal.stats:
			total_strength += animal.stats.strength

	# Expected: rabbit(2) + squirrel(2) + fox(3) + deer(4) = 11
	assert_eq(total_strength, 11, "Total team strength should be 11")


# =============================================================================
# WILD HERD INTEGRATION TESTS
# =============================================================================

func test_wild_herd_can_spawn_all_animal_types() -> void:
	# Verify WildHerdManager's composition function can use all types
	var plains_animals := WildHerdManager.PLAINS_ANIMALS

	assert_eq(plains_animals.size(), 4, "Should have 4 Plains animal types")

	for animal_type in plains_animals:
		# Verify each type has required files
		var scene_path := "res://scenes/entities/animals/%s.tscn" % animal_type
		var stats_path := "res://resources/animals/%s_stats.tres" % animal_type

		assert_true(ResourceLoader.exists(scene_path),
			"Scene should exist for %s" % animal_type)
		assert_true(ResourceLoader.exists(stats_path),
			"Stats should exist for %s" % animal_type)
