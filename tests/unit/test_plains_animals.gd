## Unit tests for Plains animal types (Story 7-1).
## Tests all 4 Plains animal type definitions and factory creation.
##
## Architecture: tests/unit/test_plains_animals.gd
## Story: 7-1-create-all-plains-animal-types
extends GutTest

# =============================================================================
# TEST CONSTANTS - GDD Specifications (Source: gdd.md:424-433)
# =============================================================================

## Expected stats for each Plains animal type
const GDD_ANIMAL_SPECS: Dictionary = {
	"rabbit": {
		"energy": 3,
		"speed": 4,
		"strength": 2,
		"specialty": "Speed +20% gathering",
		"biome": "plains"
	},
	"squirrel": {
		"energy": 4,
		"speed": 3,
		"strength": 2,
		"specialty": "Tree resources +25%",
		"biome": "plains"
	},
	"fox": {
		"energy": 3,
		"speed": 4,
		"strength": 3,
		"specialty": "Quick attacks",
		"biome": "plains"
	},
	"deer": {
		"energy": 5,
		"speed": 3,
		"strength": 4,
		"specialty": "Double carry capacity",
		"biome": "plains"
	}
}

const PLAINS_ANIMAL_TYPES: Array[String] = ["rabbit", "squirrel", "fox", "deer"]

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _created_animals: Array[Animal] = []


func after_each() -> void:
	# Clean up any created animals
	for animal in _created_animals:
		if is_instance_valid(animal):
			animal.cleanup()
	_created_animals.clear()


# =============================================================================
# STATS RESOURCE TESTS (AC: 1, 2, 3, 4)
# =============================================================================

func test_rabbit_stats_file_exists() -> void:
	var path := "res://resources/animals/rabbit_stats.tres"
	assert_true(ResourceLoader.exists(path), "rabbit_stats.tres should exist")


func test_squirrel_stats_file_exists() -> void:
	var path := "res://resources/animals/squirrel_stats.tres"
	assert_true(ResourceLoader.exists(path), "squirrel_stats.tres should exist")


func test_fox_stats_file_exists() -> void:
	var path := "res://resources/animals/fox_stats.tres"
	assert_true(ResourceLoader.exists(path), "fox_stats.tres should exist")


func test_deer_stats_file_exists() -> void:
	var path := "res://resources/animals/deer_stats.tres"
	assert_true(ResourceLoader.exists(path), "deer_stats.tres should exist")


func test_rabbit_stats_match_gdd() -> void:
	var stats: AnimalStats = load("res://resources/animals/rabbit_stats.tres")
	assert_not_null(stats, "Should load rabbit stats")
	_verify_animal_stats(stats, "rabbit")


func test_squirrel_stats_match_gdd() -> void:
	var stats: AnimalStats = load("res://resources/animals/squirrel_stats.tres")
	assert_not_null(stats, "Should load squirrel stats")
	_verify_animal_stats(stats, "squirrel")


func test_fox_stats_match_gdd() -> void:
	var stats: AnimalStats = load("res://resources/animals/fox_stats.tres")
	assert_not_null(stats, "Should load fox stats")
	_verify_animal_stats(stats, "fox")


func test_deer_stats_match_gdd() -> void:
	var stats: AnimalStats = load("res://resources/animals/deer_stats.tres")
	assert_not_null(stats, "Should load deer stats")
	_verify_animal_stats(stats, "deer")


func test_all_stats_have_plains_biome() -> void:
	for animal_type in PLAINS_ANIMAL_TYPES:
		var path := "res://resources/animals/%s_stats.tres" % animal_type
		var stats: AnimalStats = load(path)
		assert_not_null(stats, "%s stats should load" % animal_type)
		assert_eq(stats.biome, "plains", "%s should have biome 'plains'" % animal_type)


func test_all_stats_are_valid() -> void:
	for animal_type in PLAINS_ANIMAL_TYPES:
		var path := "res://resources/animals/%s_stats.tres" % animal_type
		var stats: AnimalStats = load(path)
		assert_not_null(stats, "%s stats should load" % animal_type)
		assert_true(stats.is_valid(), "%s stats should be valid" % animal_type)


# =============================================================================
# SCENE FILE TESTS (AC: 5)
# =============================================================================

func test_rabbit_scene_file_exists() -> void:
	var path := "res://scenes/entities/animals/rabbit.tscn"
	assert_true(ResourceLoader.exists(path), "rabbit.tscn should exist")


func test_squirrel_scene_file_exists() -> void:
	var path := "res://scenes/entities/animals/squirrel.tscn"
	assert_true(ResourceLoader.exists(path), "squirrel.tscn should exist")


func test_fox_scene_file_exists() -> void:
	var path := "res://scenes/entities/animals/fox.tscn"
	assert_true(ResourceLoader.exists(path), "fox.tscn should exist")


func test_deer_scene_file_exists() -> void:
	var path := "res://scenes/entities/animals/deer.tscn"
	assert_true(ResourceLoader.exists(path), "deer.tscn should exist")


func test_all_scenes_inherit_from_animal_base() -> void:
	for animal_type in PLAINS_ANIMAL_TYPES:
		var scene_path := "res://scenes/entities/animals/%s.tscn" % animal_type
		var scene: PackedScene = load(scene_path)
		assert_not_null(scene, "%s scene should load" % animal_type)

		var instance := scene.instantiate()
		add_child(instance)
		await wait_frames(1)

		# Verify it has Animal script attached
		assert_true(instance is Animal, "%s should be an Animal" % animal_type)

		# Verify expected child nodes exist (from animal_base)
		assert_not_null(instance.get_node_or_null("Visual"), "%s should have Visual node" % animal_type)
		assert_not_null(instance.get_node_or_null("SelectableComponent"), "%s should have SelectableComponent" % animal_type)
		assert_not_null(instance.get_node_or_null("MovementComponent"), "%s should have MovementComponent" % animal_type)
		assert_not_null(instance.get_node_or_null("StatsComponent"), "%s should have StatsComponent" % animal_type)
		assert_not_null(instance.get_node_or_null("AIComponent"), "%s should have AIComponent" % animal_type)

		instance.queue_free()


# =============================================================================
# ANIMAL FACTORY TESTS (AC: 6)
# =============================================================================

func test_animal_factory_has_rabbit() -> void:
	assert_true(AnimalFactory.has_animal_type("rabbit"), "Factory should have rabbit")


func test_animal_factory_has_squirrel() -> void:
	assert_true(AnimalFactory.has_animal_type("squirrel"), "Factory should have squirrel")


func test_animal_factory_has_fox() -> void:
	assert_true(AnimalFactory.has_animal_type("fox"), "Factory should have fox")


func test_animal_factory_has_deer() -> void:
	assert_true(AnimalFactory.has_animal_type("deer"), "Factory should have deer")


func test_animal_factory_get_available_types_includes_all_plains() -> void:
	var available := AnimalFactory.get_available_types()
	for animal_type in PLAINS_ANIMAL_TYPES:
		assert_has(available, animal_type, "Available types should include %s" % animal_type)


func test_animal_factory_available_types_count() -> void:
	var available := AnimalFactory.get_available_types()
	assert_gte(available.size(), 4, "Should have at least 4 animal types")


# =============================================================================
# ANIMAL CREATION TESTS (AC: 7)
# =============================================================================

func test_create_rabbit_via_factory() -> void:
	var hex := HexCoord.new(0, 0)
	var animal := AnimalFactory.create_animal("rabbit", hex)

	assert_not_null(animal, "Should create rabbit")
	_created_animals.append(animal)
	add_child(animal)
	await wait_frames(2)  # Allow deferred initialization

	assert_not_null(animal.stats, "Rabbit should have stats")
	assert_eq(animal.stats.animal_id, "rabbit", "Should be rabbit type")


func test_create_squirrel_via_factory() -> void:
	var hex := HexCoord.new(1, 0)
	var animal := AnimalFactory.create_animal("squirrel", hex)

	assert_not_null(animal, "Should create squirrel")
	_created_animals.append(animal)
	add_child(animal)
	await wait_frames(2)

	assert_not_null(animal.stats, "Squirrel should have stats")
	assert_eq(animal.stats.animal_id, "squirrel", "Should be squirrel type")


func test_create_fox_via_factory() -> void:
	var hex := HexCoord.new(2, 0)
	var animal := AnimalFactory.create_animal("fox", hex)

	assert_not_null(animal, "Should create fox")
	_created_animals.append(animal)
	add_child(animal)
	await wait_frames(2)

	assert_not_null(animal.stats, "Fox should have stats")
	assert_eq(animal.stats.animal_id, "fox", "Should be fox type")


func test_create_deer_via_factory() -> void:
	var hex := HexCoord.new(3, 0)
	var animal := AnimalFactory.create_animal("deer", hex)

	assert_not_null(animal, "Should create deer")
	_created_animals.append(animal)
	add_child(animal)
	await wait_frames(2)

	assert_not_null(animal.stats, "Deer should have stats")
	assert_eq(animal.stats.animal_id, "deer", "Should be deer type")


func test_created_animals_have_correct_stats() -> void:
	for animal_type in PLAINS_ANIMAL_TYPES:
		var hex := HexCoord.new(0, 0)
		var animal := AnimalFactory.create_animal(animal_type, hex)

		assert_not_null(animal, "Should create %s" % animal_type)
		_created_animals.append(animal)
		add_child(animal)
		await wait_frames(2)

		assert_not_null(animal.stats, "%s should have stats" % animal_type)
		_verify_animal_stats(animal.stats, animal_type)


# =============================================================================
# WILD HERD MANAGER TESTS (AC: 8)
# =============================================================================

func test_wild_herd_manager_plains_animals_constant() -> void:
	# Verify the constant exists and has all types
	var expected_types: Array[String] = ["rabbit", "squirrel", "fox", "deer"]

	assert_eq(WildHerdManager.PLAINS_ANIMALS.size(), 4, "Should have 4 Plains animal types")

	for animal_type in expected_types:
		assert_has(WildHerdManager.PLAINS_ANIMALS, animal_type,
			"PLAINS_ANIMALS should include %s" % animal_type)


# =============================================================================
# ANIMAL SERIALIZATION TESTS (AC: 10)
# =============================================================================

func test_rabbit_can_serialize() -> void:
	_test_animal_serialization("rabbit")


func test_squirrel_can_serialize() -> void:
	_test_animal_serialization("squirrel")


func test_fox_can_serialize() -> void:
	_test_animal_serialization("fox")


func test_deer_can_serialize() -> void:
	_test_animal_serialization("deer")


func _test_animal_serialization(animal_type: String) -> void:
	var hex := HexCoord.new(5, 5)
	var animal := AnimalFactory.create_animal(animal_type, hex)

	assert_not_null(animal, "Should create %s" % animal_type)
	_created_animals.append(animal)
	add_child(animal)
	await wait_frames(2)

	# Check can_serialize
	if animal.has_method("can_serialize"):
		assert_true(animal.can_serialize(), "%s should be serializable" % animal_type)

	# Check to_dict includes animal_id
	if animal.has_method("to_dict"):
		var data := animal.to_dict()
		assert_has(data, "animal_id", "%s serialization should include animal_id" % animal_type)
		assert_eq(data["animal_id"], animal_type, "Serialized animal_id should be %s" % animal_type)


# =============================================================================
# HELPER METHODS
# =============================================================================

func _verify_animal_stats(stats: AnimalStats, animal_type: String) -> void:
	var expected: Dictionary = GDD_ANIMAL_SPECS[animal_type]

	assert_eq(stats.animal_id, animal_type, "%s animal_id should match" % animal_type)
	assert_eq(stats.energy, expected["energy"], "%s energy should be %d" % [animal_type, expected["energy"]])
	assert_eq(stats.speed, expected["speed"], "%s speed should be %d" % [animal_type, expected["speed"]])
	assert_eq(stats.strength, expected["strength"], "%s strength should be %d" % [animal_type, expected["strength"]])
	assert_eq(stats.specialty, expected["specialty"], "%s specialty should match" % animal_type)
	assert_eq(stats.biome, expected["biome"], "%s biome should be %s" % [animal_type, expected["biome"]])
