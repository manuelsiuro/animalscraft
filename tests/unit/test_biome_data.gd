## Unit tests for BiomeData resource class.
##
## Tests biome resource properties and structure.
##
## Architecture: tests/unit/test_biome_data.gd
## Story: 6-11-implement-biome-unlock-preparation
extends GutTest

# =============================================================================
# TEST: BIOME DATA PROPERTIES (AC4)
# =============================================================================

func test_biome_data_has_id_property() -> void:
	# Arrange
	var biome := BiomeData.new()

	# Act
	biome.id = "test_biome"

	# Assert (AC4)
	assert_eq(biome.id, "test_biome", "BiomeData should have id property (AC4)")


func test_biome_data_has_display_name_property() -> void:
	# Arrange
	var biome := BiomeData.new()

	# Act
	biome.display_name = "Test Biome"

	# Assert (AC4)
	assert_eq(biome.display_name, "Test Biome", "BiomeData should have display_name property (AC4)")


func test_biome_data_has_description_property() -> void:
	# Arrange
	var biome := BiomeData.new()

	# Act
	biome.description = "A test biome description"

	# Assert (AC4)
	assert_eq(biome.description, "A test biome description", "BiomeData should have description property (AC4)")


func test_biome_data_has_unlock_milestone_property() -> void:
	# Arrange
	var biome := BiomeData.new()

	# Act
	biome.unlock_milestone = "test_milestone"

	# Assert (AC4)
	assert_eq(biome.unlock_milestone, "test_milestone", "BiomeData should have unlock_milestone property (AC4)")


func test_biome_data_has_terrain_types_property() -> void:
	# Arrange
	var biome := BiomeData.new()

	# Act
	biome.terrain_types = ["grass", "water"]

	# Assert (AC4)
	assert_eq(biome.terrain_types.size(), 2, "BiomeData should have terrain_types array property (AC4)")
	assert_true(biome.terrain_types.has("grass"), "terrain_types should contain grass")


func test_biome_data_has_animal_types_property() -> void:
	# Arrange
	var biome := BiomeData.new()

	# Act
	biome.animal_types = ["rabbit", "fox"]

	# Assert (AC4)
	assert_eq(biome.animal_types.size(), 2, "BiomeData should have animal_types array property (AC4)")
	assert_true(biome.animal_types.has("rabbit"), "animal_types should contain rabbit")


func test_biome_data_has_is_starting_biome_property() -> void:
	# Arrange
	var biome := BiomeData.new()

	# Act
	biome.is_starting_biome = true

	# Assert (AC4)
	assert_true(biome.is_starting_biome, "BiomeData should have is_starting_biome property (AC4)")


func test_biome_data_defaults() -> void:
	# Arrange
	var biome := BiomeData.new()

	# Assert - check default values
	assert_eq(biome.id, "", "id should default to empty string")
	assert_eq(biome.display_name, "", "display_name should default to empty string")
	assert_eq(biome.description, "", "description should default to empty string")
	assert_eq(biome.unlock_milestone, "", "unlock_milestone should default to empty string")
	assert_eq(biome.terrain_types.size(), 0, "terrain_types should default to empty array")
	assert_eq(biome.animal_types.size(), 0, "animal_types should default to empty array")
	assert_false(biome.is_starting_biome, "is_starting_biome should default to false")


# =============================================================================
# TEST: BIOME DATA IS RESOURCE (AC4)
# =============================================================================

func test_biome_data_extends_resource() -> void:
	# Arrange
	var biome := BiomeData.new()

	# Assert (AC4)
	assert_true(biome is Resource, "BiomeData should extend Resource (AC4)")


func test_biome_data_has_class_name() -> void:
	# Arrange
	var biome := BiomeData.new()

	# Assert
	assert_eq(biome.get_class(), "Resource", "BiomeData extends Resource")


# =============================================================================
# TEST: PLAINS BIOME RESOURCE (AC6)
# =============================================================================

func test_plains_biome_resource_exists() -> void:
	# Arrange
	var plains := load("res://resources/biomes/plains.tres") as BiomeData

	# Assert (AC6)
	assert_not_null(plains, "plains.tres should exist (AC6)")


func test_plains_biome_has_correct_id() -> void:
	# Arrange
	var plains := load("res://resources/biomes/plains.tres") as BiomeData

	# Assert (AC6)
	assert_eq(plains.id, "plains", "Plains should have id 'plains' (AC6)")


func test_plains_biome_has_correct_display_name() -> void:
	# Arrange
	var plains := load("res://resources/biomes/plains.tres") as BiomeData

	# Assert (AC6)
	assert_eq(plains.display_name, "The Plains", "Plains should have display_name 'The Plains' (AC6)")


func test_plains_biome_is_starting_biome() -> void:
	# Arrange
	var plains := load("res://resources/biomes/plains.tres") as BiomeData

	# Assert (AC6)
	assert_true(plains.is_starting_biome, "Plains should be starting biome (AC6)")


func test_plains_biome_has_no_unlock_milestone() -> void:
	# Arrange
	var plains := load("res://resources/biomes/plains.tres") as BiomeData

	# Assert (AC6)
	assert_eq(plains.unlock_milestone, "", "Plains should have empty unlock_milestone (starts unlocked) (AC6)")


# =============================================================================
# TEST: FOREST BIOME RESOURCE (AC7)
# =============================================================================

func test_forest_biome_resource_exists() -> void:
	# Arrange
	var forest := load("res://resources/biomes/forest.tres") as BiomeData

	# Assert (AC7)
	assert_not_null(forest, "forest.tres should exist (AC7)")


func test_forest_biome_has_correct_id() -> void:
	# Arrange
	var forest := load("res://resources/biomes/forest.tres") as BiomeData

	# Assert (AC7)
	assert_eq(forest.id, "forest", "Forest should have id 'forest' (AC7)")


func test_forest_biome_has_correct_display_name() -> void:
	# Arrange
	var forest := load("res://resources/biomes/forest.tres") as BiomeData

	# Assert (AC7)
	assert_eq(forest.display_name, "The Forest", "Forest should have display_name 'The Forest' (AC7)")


func test_forest_biome_is_not_starting_biome() -> void:
	# Arrange
	var forest := load("res://resources/biomes/forest.tres") as BiomeData

	# Assert (AC7)
	assert_false(forest.is_starting_biome, "Forest should not be starting biome (AC7)")


func test_forest_biome_has_forest_border_unlock_milestone() -> void:
	# Arrange
	var forest := load("res://resources/biomes/forest.tres") as BiomeData

	# Assert (AC7)
	assert_eq(forest.unlock_milestone, "forest_border", "Forest should have unlock_milestone 'forest_border' (AC7)")


func test_forest_biome_has_description_with_future_message() -> void:
	# Arrange
	var forest := load("res://resources/biomes/forest.tres") as BiomeData

	# Assert (AC9)
	assert_true(forest.description.contains("future"), "Forest description should mention future update (AC9)")
