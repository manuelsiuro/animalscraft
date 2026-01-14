## Unit tests for AnimalStats resource class.
## Tests resource creation, validation, and loading.
##
## Architecture: tests/unit/test_animal_stats.gd
## Story: 2-1-create-animal-entity-structure
extends GutTest

# =============================================================================
# TEST SETUP
# =============================================================================

var stats: AnimalStats

func before_each() -> void:
	stats = AnimalStats.new()


func after_each() -> void:
	stats = null

# =============================================================================
# PROPERTY TESTS (AC4)
# =============================================================================

func test_default_animal_id_is_empty() -> void:
	assert_eq(stats.animal_id, "", "Default animal_id should be empty string")


func test_default_energy_is_3() -> void:
	assert_eq(stats.energy, 3, "Default energy should be 3")


func test_default_speed_is_3() -> void:
	assert_eq(stats.speed, 3, "Default speed should be 3")


func test_default_strength_is_3() -> void:
	assert_eq(stats.strength, 3, "Default strength should be 3")


func test_default_specialty_is_empty() -> void:
	assert_eq(stats.specialty, "", "Default specialty should be empty string")


func test_default_biome_is_plains() -> void:
	assert_eq(stats.biome, "plains", "Default biome should be 'plains'")


func test_can_set_animal_id() -> void:
	stats.animal_id = "test_animal"
	assert_eq(stats.animal_id, "test_animal", "Should be able to set animal_id")


func test_can_set_energy() -> void:
	stats.energy = 5
	assert_eq(stats.energy, 5, "Should be able to set energy")


func test_can_set_speed() -> void:
	stats.speed = 1
	assert_eq(stats.speed, 1, "Should be able to set speed")


func test_can_set_strength() -> void:
	stats.strength = 4
	assert_eq(stats.strength, 4, "Should be able to set strength")


func test_can_set_specialty() -> void:
	stats.specialty = "Wood gatherer +50%"
	assert_eq(stats.specialty, "Wood gatherer +50%", "Should be able to set specialty")


func test_can_set_biome() -> void:
	stats.biome = "forest"
	assert_eq(stats.biome, "forest", "Should be able to set biome")

# =============================================================================
# VALIDATION TESTS
# =============================================================================

func test_is_valid_returns_false_when_animal_id_empty() -> void:
	stats.animal_id = ""
	stats.biome = "plains"
	assert_false(stats.is_valid(), "Should be invalid with empty animal_id")


func test_is_valid_returns_false_when_biome_empty() -> void:
	stats.animal_id = "rabbit"
	stats.biome = ""
	assert_false(stats.is_valid(), "Should be invalid with empty biome")


func test_is_valid_returns_true_with_required_fields() -> void:
	stats.animal_id = "rabbit"
	stats.biome = "plains"
	assert_true(stats.is_valid(), "Should be valid with required fields")

# =============================================================================
# RESOURCE LOADING TESTS (AC4)
# =============================================================================

func test_can_load_rabbit_stats_resource() -> void:
	var path := "res://resources/animals/rabbit_stats.tres"
	var loaded_stats := load(path) as AnimalStats

	assert_not_null(loaded_stats, "Should be able to load rabbit_stats.tres")


func test_rabbit_stats_has_correct_id() -> void:
	var path := "res://resources/animals/rabbit_stats.tres"
	var loaded_stats := load(path) as AnimalStats

	if loaded_stats:
		assert_eq(loaded_stats.animal_id, "rabbit", "Rabbit stats should have 'rabbit' id")
	else:
		fail_test("Failed to load rabbit_stats.tres")


func test_rabbit_stats_has_correct_biome() -> void:
	var path := "res://resources/animals/rabbit_stats.tres"
	var loaded_stats := load(path) as AnimalStats

	if loaded_stats:
		assert_eq(loaded_stats.biome, "plains", "Rabbit should belong to plains biome")
	else:
		fail_test("Failed to load rabbit_stats.tres")


func test_rabbit_stats_is_valid() -> void:
	var path := "res://resources/animals/rabbit_stats.tres"
	var loaded_stats := load(path) as AnimalStats

	if loaded_stats:
		assert_true(loaded_stats.is_valid(), "Loaded rabbit stats should be valid")
	else:
		fail_test("Failed to load rabbit_stats.tres")


func test_rabbit_stats_has_expected_values() -> void:
	var path := "res://resources/animals/rabbit_stats.tres"
	var loaded_stats := load(path) as AnimalStats

	if loaded_stats:
		assert_eq(loaded_stats.energy, 3, "Rabbit energy should be 3")
		assert_eq(loaded_stats.speed, 4, "Rabbit speed should be 4")
		assert_eq(loaded_stats.strength, 2, "Rabbit strength should be 2")
		assert_eq(loaded_stats.specialty, "Fast gatherer", "Rabbit should be fast gatherer")
	else:
		fail_test("Failed to load rabbit_stats.tres")

# =============================================================================
# STRING REPRESENTATION TESTS
# =============================================================================

func test_to_string_includes_animal_id() -> void:
	stats.animal_id = "test_bunny"
	stats.energy = 4
	stats.speed = 3
	stats.strength = 2

	var str_repr := str(stats)
	assert_true(str_repr.contains("test_bunny"), "String should contain animal_id")


func test_to_string_includes_stats() -> void:
	stats.animal_id = "test_bunny"
	stats.energy = 4
	stats.speed = 3
	stats.strength = 2

	var str_repr := str(stats)
	assert_true(str_repr.contains("E4"), "String should contain energy stat")
	assert_true(str_repr.contains("S3"), "String should contain speed stat")
	assert_true(str_repr.contains("St2"), "String should contain strength stat")
