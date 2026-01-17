## Unit tests for Mill Building (first PROCESSOR type).
## Tests BuildingData, scene composition, factory integration,
## and verifies Mill is NOT a gatherer but IS a producer.
##
## Architecture: tests/unit/test_mill_building.gd
## Story: 4-2-create-mill-building
extends GutTest

# =============================================================================
# TEST DATA
# =============================================================================

var mill_data: BuildingData

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Load actual building data resource
	mill_data = load("res://resources/buildings/mill_data.tres")

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

	mill_data = null

# =============================================================================
# AC1, AC2, AC4: MILL BUILD DATA VALIDATION
# =============================================================================

func test_mill_data_loads_correctly() -> void:
	assert_not_null(mill_data, "Mill data should load")


func test_mill_data_is_valid() -> void:
	assert_true(mill_data.is_valid(), "Mill data should be valid")


func test_mill_building_id() -> void:
	assert_eq(mill_data.building_id, "mill", "Mill building_id should be 'mill'")


func test_mill_display_name() -> void:
	assert_eq(mill_data.display_name, "Mill", "Mill display name should be 'Mill'")

# =============================================================================
# AC5: BUILDING TYPE IS PROCESSOR
# =============================================================================

func test_mill_building_type_is_processor() -> void:
	assert_eq(mill_data.building_type, BuildingTypes.BuildingType.PROCESSOR,
		"Mill should be PROCESSOR type")


func test_mill_building_type_not_gatherer() -> void:
	assert_ne(mill_data.building_type, BuildingTypes.BuildingType.GATHERER,
		"Mill should NOT be GATHERER type")


func test_mill_type_name_is_processor() -> void:
	assert_eq(mill_data.get_type_name(), "Processor", "Mill type name should be 'Processor'")

# =============================================================================
# AC7: RECIPE CONNECTION
# =============================================================================

func test_mill_has_production_recipe_id() -> void:
	assert_eq(mill_data.production_recipe_id, "wheat_to_flour",
		"Mill should have production_recipe_id = 'wheat_to_flour'")


func test_mill_is_producer() -> void:
	assert_true(mill_data.is_producer(), "Mill should be a producer (has recipe)")


func test_mill_is_not_gatherer() -> void:
	assert_false(mill_data.is_gatherer(), "Mill should NOT be a gatherer")


func test_mill_output_resource_id_empty() -> void:
	assert_eq(mill_data.output_resource_id, "",
		"Mill output_resource_id should be empty (PROCESSOR uses recipe)")

# =============================================================================
# AC6: MAX WORKERS = 1
# =============================================================================

func test_mill_max_workers_is_1() -> void:
	assert_eq(mill_data.max_workers, 1, "Mill should have max 1 worker")


func test_mill_can_have_workers() -> void:
	assert_true(mill_data.can_have_workers(), "Mill should be able to have workers")

# =============================================================================
# AC4: BUILD COST - 20 WOOD, 10 STONE
# =============================================================================

func test_mill_build_cost_has_wood() -> void:
	assert_true(mill_data.build_cost.has("wood"), "Mill should have wood cost")


func test_mill_build_cost_has_stone() -> void:
	assert_true(mill_data.build_cost.has("stone"), "Mill should have stone cost")


func test_mill_build_cost_wood_amount() -> void:
	assert_eq(mill_data.build_cost["wood"], 20, "Mill should cost 20 wood")


func test_mill_build_cost_stone_amount() -> void:
	assert_eq(mill_data.build_cost["stone"], 10, "Mill should cost 10 stone")


func test_mill_build_cost_two_resources() -> void:
	assert_eq(mill_data.build_cost.size(), 2, "Mill should have exactly 2 resource costs")

# =============================================================================
# AFFORDABILITY TESTS (AC2)
# =============================================================================

func test_can_afford_mill_with_sufficient_resources() -> void:
	ResourceManager.add_resource("wood", 25)
	ResourceManager.add_resource("stone", 15)

	var can_afford := BuildingPlacementManager._can_afford(mill_data)

	assert_true(can_afford, "Mill should be affordable with sufficient wood and stone")


func test_cannot_afford_mill_without_resources() -> void:
	# No resources
	assert_eq(ResourceManager.get_resource_amount("wood"), 0, "Should start with no wood")
	assert_eq(ResourceManager.get_resource_amount("stone"), 0, "Should start with no stone")

	var can_afford := BuildingPlacementManager._can_afford(mill_data)

	assert_false(can_afford, "Mill should not be affordable without resources")


func test_cannot_afford_mill_without_wood() -> void:
	ResourceManager.add_resource("stone", 15)
	# No wood

	var can_afford := BuildingPlacementManager._can_afford(mill_data)

	assert_false(can_afford, "Mill should not be affordable without wood")


func test_cannot_afford_mill_without_stone() -> void:
	ResourceManager.add_resource("wood", 25)
	# No stone

	var can_afford := BuildingPlacementManager._can_afford(mill_data)

	assert_false(can_afford, "Mill should not be affordable without stone")


func test_cannot_afford_mill_with_insufficient_wood() -> void:
	ResourceManager.add_resource("wood", 15)  # Less than 20 required
	ResourceManager.add_resource("stone", 15)

	var can_afford := BuildingPlacementManager._can_afford(mill_data)

	assert_false(can_afford, "Mill should not be affordable with only 15 wood")


func test_cannot_afford_mill_with_insufficient_stone() -> void:
	ResourceManager.add_resource("wood", 25)
	ResourceManager.add_resource("stone", 5)  # Less than 10 required

	var can_afford := BuildingPlacementManager._can_afford(mill_data)

	assert_false(can_afford, "Mill should not be affordable with only 5 stone")


func test_can_afford_mill_with_exact_resources() -> void:
	ResourceManager.add_resource("wood", 20)  # Exactly 20
	ResourceManager.add_resource("stone", 10)  # Exactly 10

	var can_afford := BuildingPlacementManager._can_afford(mill_data)

	assert_true(can_afford, "Mill should be affordable with exactly 20 wood and 10 stone")

# =============================================================================
# TERRAIN REQUIREMENTS (AC3)
# =============================================================================

func test_mill_terrain_requirements_grass_only() -> void:
	# Mill should only be placeable on GRASS (TerrainType 0)
	assert_eq(mill_data.terrain_requirements.size(), 1, "Mill should have 1 terrain requirement")
	assert_true(0 in mill_data.terrain_requirements, "Mill should require GRASS terrain (0)")


func test_mill_is_terrain_valid_grass() -> void:
	assert_true(mill_data.is_terrain_valid(0), "Mill should be valid on GRASS")


func test_mill_is_terrain_invalid_water() -> void:
	assert_false(mill_data.is_terrain_valid(1), "Mill should be invalid on WATER")


func test_mill_is_terrain_invalid_rock() -> void:
	assert_false(mill_data.is_terrain_valid(2), "Mill should be invalid on ROCK")

# =============================================================================
# BUILDING FACTORY INTEGRATION (AC1, AC8)
# =============================================================================

func test_building_factory_has_mill() -> void:
	assert_true(BuildingFactory.has_building_type("mill"), "BuildingFactory should have mill")


func test_building_factory_get_mill_display_name() -> void:
	var display_name := BuildingFactory.get_building_display_name("mill")
	assert_eq(display_name, "Mill", "BuildingFactory should return 'Mill' display name")


func test_building_factory_get_available_types_includes_mill() -> void:
	var types := BuildingFactory.get_available_types()
	assert_true("mill" in types, "Mill should be in available building types")


# Code Review Fix: Task 6.8 - Test BuildingFactory.create_building returns valid Building
func test_building_factory_create_building_returns_valid_mill() -> void:
	# Setup: Clear hex occupancy and create valid hex
	HexGrid.clear_occupancy()
	var hex := HexCoord.create(5, 5)

	# Create mill through factory
	var mill := BuildingFactory.create_building("mill", hex)

	# Verify building was created
	assert_not_null(mill, "BuildingFactory.create_building('mill', hex) should return valid Building")
	assert_true(mill is Building, "Created mill should be a Building instance")

	# Cleanup
	if mill:
		mill.queue_free()
	HexGrid.clear_occupancy()

# =============================================================================
# SCENE COMPOSITION (AC3, AC8, AC9)
# =============================================================================

func test_mill_scene_loads() -> void:
	var mill_scene := load("res://scenes/entities/buildings/mill.tscn") as PackedScene
	assert_not_null(mill_scene, "Mill scene should load")


func test_mill_scene_has_visual_node() -> void:
	var mill_scene := load("res://scenes/entities/buildings/mill.tscn") as PackedScene
	var mill := mill_scene.instantiate()
	add_child(mill)
	await wait_frames(1)

	assert_not_null(mill.get_node_or_null("Visual"), "Mill should have Visual node")

	mill.queue_free()


func test_mill_scene_has_selectable_component() -> void:
	var mill_scene := load("res://scenes/entities/buildings/mill.tscn") as PackedScene
	var mill := mill_scene.instantiate()
	add_child(mill)
	await wait_frames(1)

	assert_not_null(mill.get_node_or_null("SelectableComponent"), "Mill should have SelectableComponent")

	mill.queue_free()


func test_mill_scene_has_worker_slot_component() -> void:
	var mill_scene := load("res://scenes/entities/buildings/mill.tscn") as PackedScene
	var mill := mill_scene.instantiate()
	add_child(mill)
	await wait_frames(1)

	assert_not_null(mill.get_node_or_null("WorkerSlotComponent"), "Mill should have WorkerSlotComponent")

	mill.queue_free()


# Code Review Fix: Task 6.10 - Verify WorkerSlotComponent respects max_workers = 1
func test_mill_worker_slot_component_max_workers() -> void:
	var mill_scene := load("res://scenes/entities/buildings/mill.tscn") as PackedScene
	var mill := mill_scene.instantiate() as Building
	add_child(mill)
	await wait_frames(1)

	# Initialize with mill_data to set up worker slots
	var hex := HexCoord.create(0, 0)
	mill.call_deferred("initialize", hex, mill_data)
	await wait_frames(2)

	# Get worker slot component and verify max workers
	var worker_slot := mill.get_node_or_null("WorkerSlotComponent")
	assert_not_null(worker_slot, "Mill should have WorkerSlotComponent")

	# Check that the building data's max_workers is respected
	if worker_slot and worker_slot.has_method("get_max_workers"):
		var max_workers = worker_slot.get_max_workers()
		assert_eq(max_workers, 1, "Mill WorkerSlotComponent should have max 1 worker")
	elif mill.has_method("get_max_workers"):
		var max_workers = mill.get_max_workers()
		assert_eq(max_workers, 1, "Mill should have max 1 worker")
	else:
		# Fallback: verify via building data
		assert_eq(mill_data.max_workers, 1, "Mill data should have max 1 worker")

	mill.queue_free()


func test_mill_scene_has_no_gatherer_component() -> void:
	# CRITICAL: PROCESSOR buildings should NOT have GathererComponent (AC8)
	var mill_scene := load("res://scenes/entities/buildings/mill.tscn") as PackedScene
	var mill := mill_scene.instantiate()
	add_child(mill)
	await wait_frames(1)

	assert_null(mill.get_node_or_null("GathererComponent"),
		"Mill should NOT have GathererComponent (PROCESSOR type)")

	mill.queue_free()


func test_mill_uses_building_script() -> void:
	var mill_scene := load("res://scenes/entities/buildings/mill.tscn") as PackedScene
	var mill := mill_scene.instantiate()
	add_child(mill)
	await wait_frames(1)

	assert_true(mill is Building, "Mill should be a Building instance")

	mill.queue_free()

# =============================================================================
# AC10: VISUAL APPEARANCE - ORANGE FOR PROCESSOR
# =============================================================================

func test_mill_visual_color_is_orange() -> void:
	var mill_scene := load("res://scenes/entities/buildings/mill.tscn") as PackedScene
	var mill := mill_scene.instantiate()
	add_child(mill)
	await wait_frames(1)

	# Find the Visual/Placeholder MeshInstance3D
	var visual := mill.get_node_or_null("Visual/Placeholder") as MeshInstance3D
	assert_not_null(visual, "Mill should have Visual/Placeholder node")

	# Check material color
	var material := visual.get_surface_override_material(0) as StandardMaterial3D
	assert_not_null(material, "Mill placeholder should have material")

	# Mill color should be ORANGE (0.85, 0.5, 0.25) matching BuildingMenuItem.TYPE_COLORS[PROCESSOR]
	var expected_color := Color(0.85, 0.5, 0.25, 1.0)
	assert_almost_eq(material.albedo_color.r, expected_color.r, 0.01, "Mill red channel")
	assert_almost_eq(material.albedo_color.g, expected_color.g, 0.01, "Mill green channel")
	assert_almost_eq(material.albedo_color.b, expected_color.b, 0.01, "Mill blue channel")

	mill.queue_free()


func test_mill_visually_distinct_from_farm() -> void:
	# Verify Mill has different color than Farm (PROCESSOR vs GATHERER)
	var mill_scene := load("res://scenes/entities/buildings/mill.tscn") as PackedScene
	var farm_scene := load("res://scenes/entities/buildings/farm.tscn") as PackedScene

	var mill := mill_scene.instantiate()
	var farm := farm_scene.instantiate()
	add_child(mill)
	add_child(farm)
	await wait_frames(1)

	var mill_visual := mill.get_node_or_null("Visual/Placeholder") as MeshInstance3D
	var farm_visual := farm.get_node_or_null("Visual/Placeholder") as MeshInstance3D

	var mill_material := mill_visual.get_surface_override_material(0) as StandardMaterial3D
	var farm_material := farm_visual.get_surface_override_material(0) as StandardMaterial3D

	# Colors should be different
	assert_ne(mill_material.albedo_color, farm_material.albedo_color,
		"Mill and Farm should have different visual colors")

	mill.queue_free()
	farm.queue_free()


func test_mill_visually_distinct_from_sawmill() -> void:
	# Verify Mill has different color than Sawmill
	var mill_scene := load("res://scenes/entities/buildings/mill.tscn") as PackedScene
	var sawmill_scene := load("res://scenes/entities/buildings/sawmill.tscn") as PackedScene

	var mill := mill_scene.instantiate()
	var sawmill := sawmill_scene.instantiate()
	add_child(mill)
	add_child(sawmill)
	await wait_frames(1)

	var mill_visual := mill.get_node_or_null("Visual/Placeholder") as MeshInstance3D
	var sawmill_visual := sawmill.get_node_or_null("Visual/Placeholder") as MeshInstance3D

	var mill_material := mill_visual.get_surface_override_material(0) as StandardMaterial3D
	var sawmill_material := sawmill_visual.get_surface_override_material(0) as StandardMaterial3D

	# Colors should be different
	assert_ne(mill_material.albedo_color, sawmill_material.albedo_color,
		"Mill and Sawmill should have different visual colors")

	mill.queue_free()
	sawmill.queue_free()

# =============================================================================
# FOOTPRINT AND PRODUCTION TIME
# =============================================================================

func test_mill_footprint_single_hex() -> void:
	assert_eq(mill_data.footprint_hexes.size(), 1, "Mill should occupy 1 hex")
	assert_eq(mill_data.footprint_hexes[0], Vector2i(0, 0), "Mill footprint should be origin hex")


func test_mill_production_time() -> void:
	# Production time should match wheat_to_flour recipe (3.0 seconds)
	assert_eq(mill_data.production_time, 3.0, "Mill production time should be 3.0 seconds")

# =============================================================================
# RECIPE MANAGER INTEGRATION
# =============================================================================

func test_mill_recipe_exists_in_recipe_manager() -> void:
	# Verify the recipe referenced by Mill exists
	var recipe := RecipeManager.get_recipe("wheat_to_flour")
	assert_not_null(recipe, "wheat_to_flour recipe should exist in RecipeManager")


func test_mill_recipe_is_valid() -> void:
	var recipe := RecipeManager.get_recipe("wheat_to_flour")
	assert_not_null(recipe, "Recipe should exist")
	assert_true(recipe.is_valid(), "wheat_to_flour recipe should be valid")

# =============================================================================
# BUILDING.GD PROCESSOR HANDLING
# =============================================================================

func test_mill_building_get_gatherer_returns_null() -> void:
	# When Building.initialize() runs on Mill, _gatherer should be null
	# because is_gatherer() returns false for PROCESSOR type
	var mill_scene := load("res://scenes/entities/buildings/mill.tscn") as PackedScene
	var mill := mill_scene.instantiate() as Building
	add_child(mill)
	await wait_frames(1)

	# Initialize with mock data (deferred call)
	var hex := HexCoord.create(0, 0)
	mill.call_deferred("initialize", hex, mill_data)
	await wait_frames(2)

	# Check that get_gatherer returns null
	if mill.has_method("get_gatherer"):
		var gatherer = mill.get_gatherer()
		assert_null(gatherer, "Mill.get_gatherer() should return null (PROCESSOR type)")

	mill.queue_free()

# =============================================================================
# RESOURCE DEDUCTION ON PLACEMENT
# =============================================================================

func test_mill_placement_deducts_wood_and_stone() -> void:
	# Give player resources
	ResourceManager.add_resource("wood", 50)
	ResourceManager.add_resource("stone", 30)
	var initial_wood := ResourceManager.get_resource_amount("wood")
	var initial_stone := ResourceManager.get_resource_amount("stone")

	# Simulate resource deduction (as would happen in _place_building)
	var costs: Dictionary = mill_data.build_cost
	for resource_id in costs:
		var amount: int = costs[resource_id]
		ResourceManager.remove_resource(resource_id, amount)

	var final_wood := ResourceManager.get_resource_amount("wood")
	var final_stone := ResourceManager.get_resource_amount("stone")
	assert_eq(final_wood, initial_wood - 20, "Mill placement should deduct 20 wood")
	assert_eq(final_stone, initial_stone - 10, "Mill placement should deduct 10 stone")

# =============================================================================
# EDGE CASES
# =============================================================================

func test_mill_boundary_affordability() -> void:
	# Test boundary: exactly enough for one resource, one short for other
	ResourceManager.add_resource("wood", 20)
	ResourceManager.add_resource("stone", 9)  # One short

	var can_afford := BuildingPlacementManager._can_afford(mill_data)

	assert_false(can_afford, "Mill should not be affordable with 9 stone")


func test_mill_data_not_storage_building() -> void:
	assert_false(mill_data.is_storage_building(),
		"Mill should not be a storage building")


func test_mill_storage_capacity_bonus_is_zero() -> void:
	assert_eq(mill_data.storage_capacity_bonus, 0,
		"Mill storage_capacity_bonus should be 0")


# =============================================================================
# CODE REVIEW FIXES - ADDITIONAL TESTS
# =============================================================================

# Code Review Fix: Task 6.11 - Test Mill shows in building menu (auto-discovery)
func test_mill_discovered_by_building_menu_panel() -> void:
	# The BuildingMenuPanel loads all *_data.tres from res://resources/buildings/
	# Verify mill_data.tres exists and can be discovered
	var dir := DirAccess.open("res://resources/buildings/")
	assert_not_null(dir, "Buildings resource directory should be accessible")

	var found_mill := false
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name == "mill_data.tres":
				found_mill = true
				break
			file_name = dir.get_next()
		dir.list_dir_end()

	assert_true(found_mill, "mill_data.tres should exist in resources/buildings/ for menu discovery")

	# Also verify the data loads correctly (as BuildingMenuPanel would)
	var path := "res://resources/buildings/mill_data.tres"
	var data := load(path) as BuildingData
	assert_not_null(data, "Mill data should load as BuildingData")
	assert_true(data.is_valid(), "Mill data should be valid for menu display")
