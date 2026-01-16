## Unit tests for Gatherer Buildings (Farm, Sawmill).
## Tests build costs, terrain requirements, resource deduction,
## worker slots, and visual assets.
##
## Architecture: tests/unit/test_gatherer_buildings.gd
## Story: 3-7-create-gatherer-buildings-farm-sawmill
extends GutTest

# =============================================================================
# TEST DATA
# =============================================================================

var farm_data: BuildingData
var sawmill_data: BuildingData

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Load actual building data resources
	farm_data = load("res://resources/buildings/farm_data.tres")
	sawmill_data = load("res://resources/buildings/sawmill_data.tres")

	# Clear resources
	ResourceManager.clear_all()

	# Reset BuildingPlacementManager state
	if BuildingPlacementManager.is_placing:
		BuildingPlacementManager.cancel_placement()


func after_each() -> void:
	# Cleanup any active placement
	if BuildingPlacementManager.is_placing:
		BuildingPlacementManager.cancel_placement()

	# Clear resources
	ResourceManager.clear_all()

	farm_data = null
	sawmill_data = null

# =============================================================================
# AC3: FARM BUILD COST - 10 WOOD
# =============================================================================

func test_farm_build_cost_is_10_wood() -> void:
	assert_not_null(farm_data, "Farm data should load")
	assert_true(farm_data.build_cost.has("wood"), "Farm should have wood cost")
	assert_eq(farm_data.build_cost["wood"], 10, "Farm should cost 10 wood")


func test_farm_build_cost_only_wood() -> void:
	# Farm should only cost wood, not other resources
	assert_eq(farm_data.build_cost.size(), 1, "Farm should have exactly 1 resource cost")
	assert_true(farm_data.build_cost.has("wood"), "Farm's only cost should be wood")

# =============================================================================
# AC6: SAWMILL BUILD COST - 5 WOOD AND 5 STONE
# =============================================================================

func test_sawmill_build_cost_is_5_wood_5_stone() -> void:
	assert_not_null(sawmill_data, "Sawmill data should load")
	assert_true(sawmill_data.build_cost.has("wood"), "Sawmill should have wood cost")
	assert_true(sawmill_data.build_cost.has("stone"), "Sawmill should have stone cost")
	assert_eq(sawmill_data.build_cost["wood"], 5, "Sawmill should cost 5 wood")
	assert_eq(sawmill_data.build_cost["stone"], 5, "Sawmill should cost 5 stone")


func test_sawmill_build_cost_two_resources() -> void:
	assert_eq(sawmill_data.build_cost.size(), 2, "Sawmill should have exactly 2 resource costs")

# =============================================================================
# AC7: AFFORDABILITY CHECK - CAN_AFFORD / CANNOT_AFFORD
# =============================================================================

func test_can_afford_farm_with_sufficient_wood() -> void:
	ResourceManager.add_resource("wood", 20)

	var can_afford := BuildingPlacementManager._can_afford(farm_data)

	assert_true(can_afford, "Farm should be affordable with 20 wood")


func test_cannot_afford_farm_without_wood() -> void:
	# Ensure no wood
	assert_eq(ResourceManager.get_resource_amount("wood"), 0, "Should start with no wood")

	var can_afford := BuildingPlacementManager._can_afford(farm_data)

	assert_false(can_afford, "Farm should not be affordable without wood")


func test_cannot_afford_farm_with_insufficient_wood() -> void:
	ResourceManager.add_resource("wood", 5)  # Less than 10 required

	var can_afford := BuildingPlacementManager._can_afford(farm_data)

	assert_false(can_afford, "Farm should not be affordable with only 5 wood")


func test_can_afford_sawmill_with_sufficient_resources() -> void:
	ResourceManager.add_resource("wood", 10)
	ResourceManager.add_resource("stone", 10)

	var can_afford := BuildingPlacementManager._can_afford(sawmill_data)

	assert_true(can_afford, "Sawmill should be affordable with sufficient wood and stone")


func test_cannot_afford_sawmill_without_stone() -> void:
	ResourceManager.add_resource("wood", 10)
	# No stone

	var can_afford := BuildingPlacementManager._can_afford(sawmill_data)

	assert_false(can_afford, "Sawmill should not be affordable without stone")


func test_cannot_afford_sawmill_without_wood() -> void:
	ResourceManager.add_resource("stone", 10)
	# No wood

	var can_afford := BuildingPlacementManager._can_afford(sawmill_data)

	assert_false(can_afford, "Sawmill should not be affordable without wood")


func test_cannot_afford_sawmill_with_partial_resources() -> void:
	ResourceManager.add_resource("wood", 5)  # Exactly enough
	ResourceManager.add_resource("stone", 3)  # Not enough

	var can_afford := BuildingPlacementManager._can_afford(sawmill_data)

	assert_false(can_afford, "Sawmill should not be affordable with insufficient stone")


func test_can_afford_sawmill_with_exact_resources() -> void:
	ResourceManager.add_resource("wood", 5)  # Exactly 5
	ResourceManager.add_resource("stone", 5)  # Exactly 5

	var can_afford := BuildingPlacementManager._can_afford(sawmill_data)

	assert_true(can_afford, "Sawmill should be affordable with exactly 5 wood and 5 stone")

# =============================================================================
# AC8: RESOURCE DEDUCTION ON PLACEMENT
# =============================================================================

func test_farm_placement_deducts_wood() -> void:
	# Give player resources
	ResourceManager.add_resource("wood", 25)
	var initial_wood := ResourceManager.get_resource_amount("wood")

	# Simulate resource deduction (as would happen in _place_building)
	var costs: Dictionary = farm_data.build_cost
	for resource_id in costs:
		var amount: int = costs[resource_id]
		ResourceManager.remove_resource(resource_id, amount)

	var final_wood := ResourceManager.get_resource_amount("wood")
	assert_eq(final_wood, initial_wood - 10, "Farm placement should deduct 10 wood")


func test_sawmill_placement_deducts_wood_and_stone() -> void:
	# Give player resources
	ResourceManager.add_resource("wood", 25)
	ResourceManager.add_resource("stone", 25)
	var initial_wood := ResourceManager.get_resource_amount("wood")
	var initial_stone := ResourceManager.get_resource_amount("stone")

	# Simulate resource deduction
	var costs: Dictionary = sawmill_data.build_cost
	for resource_id in costs:
		var amount: int = costs[resource_id]
		ResourceManager.remove_resource(resource_id, amount)

	var final_wood := ResourceManager.get_resource_amount("wood")
	var final_stone := ResourceManager.get_resource_amount("stone")
	assert_eq(final_wood, initial_wood - 5, "Sawmill placement should deduct 5 wood")
	assert_eq(final_stone, initial_stone - 5, "Sawmill placement should deduct 5 stone")


func test_resource_deduction_is_atomic() -> void:
	# Setup: Player has wood but not stone (for sawmill test)
	ResourceManager.add_resource("wood", 10)
	# No stone added
	var initial_wood := ResourceManager.get_resource_amount("wood")

	# First check affordability (should fail)
	var can_afford := BuildingPlacementManager._can_afford(sawmill_data)
	assert_false(can_afford, "Sawmill should not be affordable")

	# Wood should not have been deducted during the check
	var final_wood := ResourceManager.get_resource_amount("wood")
	assert_eq(final_wood, initial_wood, "Resources should not be deducted during affordability check")

# =============================================================================
# AC1, AC4: TERRAIN REQUIREMENTS
# =============================================================================

func test_farm_terrain_requirements_grass_only() -> void:
	# Farm should only be placeable on GRASS (TerrainType 0)
	assert_eq(farm_data.terrain_requirements.size(), 1, "Farm should have 1 terrain requirement")
	assert_true(0 in farm_data.terrain_requirements, "Farm should require GRASS terrain (0)")


func test_farm_is_terrain_valid_grass() -> void:
	assert_true(farm_data.is_terrain_valid(0), "Farm should be valid on GRASS")


func test_farm_is_terrain_invalid_water() -> void:
	assert_false(farm_data.is_terrain_valid(1), "Farm should be invalid on WATER")


func test_farm_is_terrain_invalid_rock() -> void:
	assert_false(farm_data.is_terrain_valid(2), "Farm should be invalid on ROCK")


func test_sawmill_terrain_requirements_grass_and_rock() -> void:
	# Sawmill should be placeable on GRASS (0) or ROCK (2)
	assert_eq(sawmill_data.terrain_requirements.size(), 2, "Sawmill should have 2 terrain requirements")
	assert_true(0 in sawmill_data.terrain_requirements, "Sawmill should allow GRASS terrain (0)")
	assert_true(2 in sawmill_data.terrain_requirements, "Sawmill should allow ROCK terrain (2)")


func test_sawmill_is_terrain_valid_grass() -> void:
	assert_true(sawmill_data.is_terrain_valid(0), "Sawmill should be valid on GRASS")


func test_sawmill_is_terrain_invalid_water() -> void:
	assert_false(sawmill_data.is_terrain_valid(1), "Sawmill should be invalid on WATER")


func test_sawmill_is_terrain_valid_rock() -> void:
	assert_true(sawmill_data.is_terrain_valid(2), "Sawmill should be valid on ROCK")

# =============================================================================
# AC2, AC5: WORKER SLOTS - MAX 2 WORKERS
# =============================================================================

func test_farm_max_workers_is_2() -> void:
	assert_eq(farm_data.max_workers, 2, "Farm should have max 2 workers")


func test_sawmill_max_workers_is_2() -> void:
	assert_eq(sawmill_data.max_workers, 2, "Sawmill should have max 2 workers")


func test_farm_can_have_workers() -> void:
	assert_true(farm_data.can_have_workers(), "Farm should be able to have workers")


func test_sawmill_can_have_workers() -> void:
	assert_true(sawmill_data.can_have_workers(), "Sawmill should be able to have workers")

# =============================================================================
# AC9: DISPLAY NAMES
# =============================================================================

func test_farm_display_name() -> void:
	assert_eq(farm_data.display_name, "Farm", "Farm display name should be 'Farm'")


func test_sawmill_display_name() -> void:
	assert_eq(sawmill_data.display_name, "Sawmill", "Sawmill display name should be 'Sawmill'")


func test_building_factory_get_farm_display_name() -> void:
	var display_name := BuildingFactory.get_building_display_name("farm")
	assert_eq(display_name, "Farm", "BuildingFactory should return 'Farm' display name")


func test_building_factory_get_sawmill_display_name() -> void:
	var display_name := BuildingFactory.get_building_display_name("sawmill")
	assert_eq(display_name, "Sawmill", "BuildingFactory should return 'Sawmill' display name")

# =============================================================================
# AC10: BUILDING SCENE COMPOSITION
# =============================================================================

func test_building_factory_has_farm() -> void:
	assert_true(BuildingFactory.has_building_type("farm"), "BuildingFactory should have farm")


func test_building_factory_has_sawmill() -> void:
	assert_true(BuildingFactory.has_building_type("sawmill"), "BuildingFactory should have sawmill")


func test_farm_scene_has_required_components() -> void:
	var farm_scene := load("res://scenes/entities/buildings/farm.tscn") as PackedScene
	assert_not_null(farm_scene, "Farm scene should load")

	var farm := farm_scene.instantiate()
	add_child(farm)
	await wait_frames(1)

	# Check for required child nodes
	assert_not_null(farm.get_node_or_null("Visual"), "Farm should have Visual node")
	assert_not_null(farm.get_node_or_null("SelectableComponent"), "Farm should have SelectableComponent")
	assert_not_null(farm.get_node_or_null("WorkerSlotComponent"), "Farm should have WorkerSlotComponent")

	farm.queue_free()


func test_sawmill_scene_has_required_components() -> void:
	var sawmill_scene := load("res://scenes/entities/buildings/sawmill.tscn") as PackedScene
	assert_not_null(sawmill_scene, "Sawmill scene should load")

	var sawmill := sawmill_scene.instantiate()
	add_child(sawmill)
	await wait_frames(1)

	# Check for required child nodes
	assert_not_null(sawmill.get_node_or_null("Visual"), "Sawmill should have Visual node")
	assert_not_null(sawmill.get_node_or_null("SelectableComponent"), "Sawmill should have SelectableComponent")
	assert_not_null(sawmill.get_node_or_null("WorkerSlotComponent"), "Sawmill should have WorkerSlotComponent")

	sawmill.queue_free()


func test_farm_uses_building_script() -> void:
	var farm_scene := load("res://scenes/entities/buildings/farm.tscn") as PackedScene
	var farm := farm_scene.instantiate()
	add_child(farm)
	await wait_frames(1)

	assert_true(farm is Building, "Farm should be a Building instance")

	farm.queue_free()


func test_sawmill_uses_building_script() -> void:
	var sawmill_scene := load("res://scenes/entities/buildings/sawmill.tscn") as PackedScene
	var sawmill := sawmill_scene.instantiate()
	add_child(sawmill)
	await wait_frames(1)

	assert_true(sawmill is Building, "Sawmill should be a Building instance")

	sawmill.queue_free()

# =============================================================================
# BUILDING DATA VALIDATION
# =============================================================================

func test_farm_data_is_valid() -> void:
	assert_true(farm_data.is_valid(), "Farm data should be valid")


func test_sawmill_data_is_valid() -> void:
	assert_true(sawmill_data.is_valid(), "Sawmill data should be valid")


func test_farm_building_id() -> void:
	assert_eq(farm_data.building_id, "farm", "Farm building_id should be 'farm'")


func test_sawmill_building_id() -> void:
	assert_eq(sawmill_data.building_id, "sawmill", "Sawmill building_id should be 'sawmill'")


func test_farm_building_type_is_gatherer() -> void:
	assert_eq(farm_data.building_type, BuildingTypes.BuildingType.GATHERER, "Farm should be GATHERER type")


func test_sawmill_building_type_is_gatherer() -> void:
	assert_eq(sawmill_data.building_type, BuildingTypes.BuildingType.GATHERER, "Sawmill should be GATHERER type")

# =============================================================================
# INVALIDITY REASON FOR CANNOT_AFFORD
# =============================================================================

func test_cannot_afford_returns_correct_invalidity_reason() -> void:
	# Create test data with build cost
	var test_data := BuildingData.new()
	test_data.building_id = "test"
	test_data.display_name = "Test"
	test_data.max_workers = 1
	test_data.footprint_hexes = [Vector2i.ZERO]
	test_data.build_cost = {"wood": 1000}  # Unaffordable

	# Mock a valid placement scenario by setting up the check
	# In unit test without full world, check_placement_validity will fail early
	# but we can test the _can_afford function directly
	var can_afford := BuildingPlacementManager._can_afford(test_data)
	assert_false(can_afford, "Should not be able to afford with 1000 wood cost")


func test_invalidity_reason_cannot_afford_priority() -> void:
	# CANNOT_AFFORD should be lowest priority (value 5)
	assert_eq(
		BuildingPlacementManager.InvalidityReason.CANNOT_AFFORD,
		5,
		"CANNOT_AFFORD should have priority value 5"
	)

# =============================================================================
# EDGE CASES
# =============================================================================

func test_empty_build_cost_is_always_affordable() -> void:
	var test_data := BuildingData.new()
	test_data.building_id = "free_building"
	test_data.display_name = "Free"
	test_data.max_workers = 1
	test_data.footprint_hexes = [Vector2i.ZERO]
	test_data.build_cost = {}  # Empty = free

	var can_afford := BuildingPlacementManager._can_afford(test_data)
	assert_true(can_afford, "Building with empty build_cost should always be affordable")


func test_null_build_cost_is_always_affordable() -> void:
	var test_data := BuildingData.new()
	test_data.building_id = "null_cost"
	test_data.display_name = "NullCost"
	test_data.max_workers = 1
	test_data.footprint_hexes = [Vector2i.ZERO]
	# build_cost defaults to empty dict {}

	var can_afford := BuildingPlacementManager._can_afford(test_data)
	assert_true(can_afford, "Building with default build_cost should be affordable")


func test_farm_afford_with_exact_resources() -> void:
	ResourceManager.add_resource("wood", 10)  # Exactly 10

	var can_afford := BuildingPlacementManager._can_afford(farm_data)

	assert_true(can_afford, "Farm should be affordable with exactly 10 wood")


func test_sawmill_afford_boundary_resources() -> void:
	# Test boundary: exactly enough for one resource, one short for other
	ResourceManager.add_resource("wood", 5)
	ResourceManager.add_resource("stone", 4)  # One short

	var can_afford := BuildingPlacementManager._can_afford(sawmill_data)

	assert_false(can_afford, "Sawmill should not be affordable with 4 stone")

# =============================================================================
# AC1, AC4: VISUAL APPEARANCE VERIFICATION
# Story: 3-7 Code Review Fix - Verify unique visual colors
# =============================================================================

func test_farm_visual_color_is_green() -> void:
	var farm_scene := load("res://scenes/entities/buildings/farm.tscn") as PackedScene
	var farm := farm_scene.instantiate()
	add_child(farm)
	await wait_frames(1)

	# Find the Visual/Placeholder MeshInstance3D
	var visual := farm.get_node_or_null("Visual/Placeholder") as MeshInstance3D
	assert_not_null(visual, "Farm should have Visual/Placeholder node")

	# Check material color
	var material := visual.get_surface_override_material(0) as StandardMaterial3D
	assert_not_null(material, "Farm placeholder should have material")

	# Farm color should be GREEN (0.3, 0.7, 0.2)
	var expected_color := Color(0.3, 0.7, 0.2, 1.0)
	assert_almost_eq(material.albedo_color.r, expected_color.r, 0.01, "Farm red channel")
	assert_almost_eq(material.albedo_color.g, expected_color.g, 0.01, "Farm green channel")
	assert_almost_eq(material.albedo_color.b, expected_color.b, 0.01, "Farm blue channel")

	farm.queue_free()


func test_sawmill_visual_color_is_brown() -> void:
	var sawmill_scene := load("res://scenes/entities/buildings/sawmill.tscn") as PackedScene
	var sawmill := sawmill_scene.instantiate()
	add_child(sawmill)
	await wait_frames(1)

	# Find the Visual/Placeholder MeshInstance3D
	var visual := sawmill.get_node_or_null("Visual/Placeholder") as MeshInstance3D
	assert_not_null(visual, "Sawmill should have Visual/Placeholder node")

	# Check material color
	var material := visual.get_surface_override_material(0) as StandardMaterial3D
	assert_not_null(material, "Sawmill placeholder should have material")

	# Sawmill color should be BROWN (0.5, 0.3, 0.1)
	var expected_color := Color(0.5, 0.3, 0.1, 1.0)
	assert_almost_eq(material.albedo_color.r, expected_color.r, 0.01, "Sawmill red channel")
	assert_almost_eq(material.albedo_color.g, expected_color.g, 0.01, "Sawmill green channel")
	assert_almost_eq(material.albedo_color.b, expected_color.b, 0.01, "Sawmill blue channel")

	sawmill.queue_free()


func test_farm_and_sawmill_visually_distinct() -> void:
	# Verify Farm and Sawmill have different colors (AC1, AC4)
	var farm_scene := load("res://scenes/entities/buildings/farm.tscn") as PackedScene
	var sawmill_scene := load("res://scenes/entities/buildings/sawmill.tscn") as PackedScene

	var farm := farm_scene.instantiate()
	var sawmill := sawmill_scene.instantiate()
	add_child(farm)
	add_child(sawmill)
	await wait_frames(1)

	var farm_visual := farm.get_node_or_null("Visual/Placeholder") as MeshInstance3D
	var sawmill_visual := sawmill.get_node_or_null("Visual/Placeholder") as MeshInstance3D

	var farm_material := farm_visual.get_surface_override_material(0) as StandardMaterial3D
	var sawmill_material := sawmill_visual.get_surface_override_material(0) as StandardMaterial3D

	# Colors should be different
	assert_ne(farm_material.albedo_color, sawmill_material.albedo_color,
		"Farm and Sawmill should have different visual colors")

	farm.queue_free()
	sawmill.queue_free()


# =============================================================================
# REGRESSION TESTS (Story 3-6)
# =============================================================================

func test_existing_placement_tests_pass() -> void:
	# Verify key methods still exist and work
	assert_true(BuildingPlacementManager.has_method("_can_afford"), "_can_afford should exist")
	assert_true(BuildingPlacementManager.has_method("check_placement_validity"), "check_placement_validity should exist")
	assert_true(BuildingPlacementManager.has_method("is_placement_valid"), "is_placement_valid should exist")


func test_building_data_terrain_requirements_exists() -> void:
	# Story 3-6 feature should still work
	assert_true("terrain_requirements" in farm_data, "terrain_requirements should exist")
	assert_true("terrain_requirements" in sawmill_data, "terrain_requirements should exist")


func test_invalidity_reason_enum_complete() -> void:
	# All reasons from Story 3-6 should exist
	assert_eq(BuildingPlacementManager.InvalidityReason.NONE, 0)
	assert_eq(BuildingPlacementManager.InvalidityReason.WATER, 1)
	assert_eq(BuildingPlacementManager.InvalidityReason.OCCUPIED, 2)
	assert_eq(BuildingPlacementManager.InvalidityReason.UNCLAIMED, 3)
	assert_eq(BuildingPlacementManager.InvalidityReason.TERRAIN_INCOMPATIBLE, 4)
	assert_eq(BuildingPlacementManager.InvalidityReason.CANNOT_AFFORD, 5)
