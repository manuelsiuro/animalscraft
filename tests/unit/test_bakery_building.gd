## Unit tests for Bakery Building (second PROCESSOR type).
## Tests BuildingData, scene composition, factory integration,
## and verifies Bakery is NOT a gatherer but IS a producer.
##
## Architecture: tests/unit/test_bakery_building.gd
## Story: 4-3-create-bakery-building
extends GutTest

# =============================================================================
# TEST DATA
# =============================================================================

var bakery_data: BuildingData

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Load actual building data resource
	bakery_data = load("res://resources/buildings/bakery_data.tres")

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

	bakery_data = null

# =============================================================================
# AC1, AC2, AC4: BAKERY BUILD DATA VALIDATION
# =============================================================================

func test_bakery_data_loads_correctly() -> void:
	assert_not_null(bakery_data, "Bakery data should load")


func test_bakery_data_is_valid() -> void:
	assert_true(bakery_data.is_valid(), "Bakery data should be valid")


func test_bakery_building_id() -> void:
	assert_eq(bakery_data.building_id, "bakery", "Bakery building_id should be 'bakery'")


func test_bakery_display_name() -> void:
	assert_eq(bakery_data.display_name, "Bakery", "Bakery display name should be 'Bakery'")

# =============================================================================
# AC5: BUILDING TYPE IS PROCESSOR
# =============================================================================

func test_bakery_building_type_is_processor() -> void:
	assert_eq(bakery_data.building_type, BuildingTypes.BuildingType.PROCESSOR,
		"Bakery should be PROCESSOR type")


func test_bakery_building_type_not_gatherer() -> void:
	assert_ne(bakery_data.building_type, BuildingTypes.BuildingType.GATHERER,
		"Bakery should NOT be GATHERER type")


func test_bakery_type_name_is_processor() -> void:
	assert_eq(bakery_data.get_type_name(), "Processor", "Bakery type name should be 'Processor'")

# =============================================================================
# AC7: RECIPE CONNECTION
# =============================================================================

func test_bakery_has_production_recipe_id() -> void:
	assert_eq(bakery_data.production_recipe_id, "flour_to_bread",
		"Bakery should have production_recipe_id = 'flour_to_bread'")


func test_bakery_is_producer() -> void:
	assert_true(bakery_data.is_producer(), "Bakery should be a producer (has recipe)")


func test_bakery_is_not_gatherer() -> void:
	assert_false(bakery_data.is_gatherer(), "Bakery should NOT be a gatherer")


func test_bakery_output_resource_id_empty() -> void:
	assert_eq(bakery_data.output_resource_id, "",
		"Bakery output_resource_id should be empty (PROCESSOR uses recipe)")

# =============================================================================
# AC6: MAX WORKERS = 1
# =============================================================================

func test_bakery_max_workers_is_1() -> void:
	assert_eq(bakery_data.max_workers, 1, "Bakery should have max 1 worker")


func test_bakery_can_have_workers() -> void:
	assert_true(bakery_data.can_have_workers(), "Bakery should be able to have workers")

# =============================================================================
# AC4: BUILD COST - 25 WOOD, 15 STONE
# =============================================================================

func test_bakery_build_cost_has_wood() -> void:
	assert_true(bakery_data.build_cost.has("wood"), "Bakery should have wood cost")


func test_bakery_build_cost_has_stone() -> void:
	assert_true(bakery_data.build_cost.has("stone"), "Bakery should have stone cost")


func test_bakery_build_cost_wood_amount() -> void:
	assert_eq(bakery_data.build_cost["wood"], 25, "Bakery should cost 25 wood")


func test_bakery_build_cost_stone_amount() -> void:
	assert_eq(bakery_data.build_cost["stone"], 15, "Bakery should cost 15 stone")


func test_bakery_build_cost_two_resources() -> void:
	assert_eq(bakery_data.build_cost.size(), 2, "Bakery should have exactly 2 resource costs")

# =============================================================================
# AFFORDABILITY TESTS (AC2)
# =============================================================================

func test_can_afford_bakery_with_sufficient_resources() -> void:
	ResourceManager.add_resource("wood", 30)
	ResourceManager.add_resource("stone", 20)

	var can_afford := BuildingPlacementManager._can_afford(bakery_data)

	assert_true(can_afford, "Bakery should be affordable with sufficient wood and stone")


func test_cannot_afford_bakery_without_resources() -> void:
	# No resources
	assert_eq(ResourceManager.get_resource_amount("wood"), 0, "Should start with no wood")
	assert_eq(ResourceManager.get_resource_amount("stone"), 0, "Should start with no stone")

	var can_afford := BuildingPlacementManager._can_afford(bakery_data)

	assert_false(can_afford, "Bakery should not be affordable without resources")


func test_cannot_afford_bakery_without_wood() -> void:
	ResourceManager.add_resource("stone", 20)
	# No wood

	var can_afford := BuildingPlacementManager._can_afford(bakery_data)

	assert_false(can_afford, "Bakery should not be affordable without wood")


func test_cannot_afford_bakery_without_stone() -> void:
	ResourceManager.add_resource("wood", 30)
	# No stone

	var can_afford := BuildingPlacementManager._can_afford(bakery_data)

	assert_false(can_afford, "Bakery should not be affordable without stone")


func test_cannot_afford_bakery_with_insufficient_wood() -> void:
	ResourceManager.add_resource("wood", 20)  # Less than 25 required
	ResourceManager.add_resource("stone", 20)

	var can_afford := BuildingPlacementManager._can_afford(bakery_data)

	assert_false(can_afford, "Bakery should not be affordable with only 20 wood")


func test_cannot_afford_bakery_with_insufficient_stone() -> void:
	ResourceManager.add_resource("wood", 30)
	ResourceManager.add_resource("stone", 10)  # Less than 15 required

	var can_afford := BuildingPlacementManager._can_afford(bakery_data)

	assert_false(can_afford, "Bakery should not be affordable with only 10 stone")


func test_can_afford_bakery_with_exact_resources() -> void:
	ResourceManager.add_resource("wood", 25)  # Exactly 25
	ResourceManager.add_resource("stone", 15)  # Exactly 15

	var can_afford := BuildingPlacementManager._can_afford(bakery_data)

	assert_true(can_afford, "Bakery should be affordable with exactly 25 wood and 15 stone")

# =============================================================================
# TERRAIN REQUIREMENTS (AC3)
# =============================================================================

func test_bakery_terrain_requirements_grass_only() -> void:
	# Bakery should only be placeable on GRASS (TerrainType 0)
	assert_eq(bakery_data.terrain_requirements.size(), 1, "Bakery should have 1 terrain requirement")
	assert_true(0 in bakery_data.terrain_requirements, "Bakery should require GRASS terrain (0)")


func test_bakery_is_terrain_valid_grass() -> void:
	assert_true(bakery_data.is_terrain_valid(0), "Bakery should be valid on GRASS")


func test_bakery_is_terrain_invalid_water() -> void:
	assert_false(bakery_data.is_terrain_valid(1), "Bakery should be invalid on WATER")


func test_bakery_is_terrain_invalid_rock() -> void:
	assert_false(bakery_data.is_terrain_valid(2), "Bakery should be invalid on ROCK")

# =============================================================================
# BUILDING FACTORY INTEGRATION (AC1, AC8)
# =============================================================================

func test_building_factory_has_bakery() -> void:
	assert_true(BuildingFactory.has_building_type("bakery"), "BuildingFactory should have bakery")


func test_building_factory_get_bakery_display_name() -> void:
	var display_name := BuildingFactory.get_building_display_name("bakery")
	assert_eq(display_name, "Bakery", "BuildingFactory should return 'Bakery' display name")


func test_building_factory_get_available_types_includes_bakery() -> void:
	var types := BuildingFactory.get_available_types()
	assert_true("bakery" in types, "Bakery should be in available building types")


func test_building_factory_create_building_returns_valid_bakery() -> void:
	# Setup: Clear hex occupancy and create valid hex
	HexGrid.clear_occupancy()
	var hex := HexCoord.create(5, 5)

	# Create bakery through factory
	var bakery := BuildingFactory.create_building("bakery", hex)

	# Verify building was created
	assert_not_null(bakery, "BuildingFactory.create_building('bakery', hex) should return valid Building")
	assert_true(bakery is Building, "Created bakery should be a Building instance")

	# Cleanup
	if bakery:
		bakery.queue_free()
	HexGrid.clear_occupancy()

# =============================================================================
# SCENE COMPOSITION (AC3, AC8, AC9)
# =============================================================================

func test_bakery_scene_loads() -> void:
	var bakery_scene := load("res://scenes/entities/buildings/bakery.tscn") as PackedScene
	assert_not_null(bakery_scene, "Bakery scene should load")


func test_bakery_scene_has_visual_node() -> void:
	var bakery_scene := load("res://scenes/entities/buildings/bakery.tscn") as PackedScene
	var bakery := bakery_scene.instantiate()
	add_child(bakery)
	await wait_frames(1)

	assert_not_null(bakery.get_node_or_null("Visual"), "Bakery should have Visual node")

	bakery.queue_free()


func test_bakery_scene_has_selectable_component() -> void:
	var bakery_scene := load("res://scenes/entities/buildings/bakery.tscn") as PackedScene
	var bakery := bakery_scene.instantiate()
	add_child(bakery)
	await wait_frames(1)

	assert_not_null(bakery.get_node_or_null("SelectableComponent"), "Bakery should have SelectableComponent")

	bakery.queue_free()


func test_bakery_scene_has_worker_slot_component() -> void:
	var bakery_scene := load("res://scenes/entities/buildings/bakery.tscn") as PackedScene
	var bakery := bakery_scene.instantiate()
	add_child(bakery)
	await wait_frames(1)

	assert_not_null(bakery.get_node_or_null("WorkerSlotComponent"), "Bakery should have WorkerSlotComponent")

	bakery.queue_free()


func test_bakery_worker_slot_component_max_workers() -> void:
	var bakery_scene := load("res://scenes/entities/buildings/bakery.tscn") as PackedScene
	var bakery := bakery_scene.instantiate() as Building
	add_child(bakery)
	await wait_frames(1)

	# Initialize with bakery_data to set up worker slots
	var hex := HexCoord.create(0, 0)
	bakery.call_deferred("initialize", hex, bakery_data)
	await wait_frames(2)

	# Get worker slot component and verify max workers
	var worker_slot := bakery.get_node_or_null("WorkerSlotComponent")
	assert_not_null(worker_slot, "Bakery should have WorkerSlotComponent")

	# Check that the building data's max_workers is respected
	if worker_slot and worker_slot.has_method("get_max_workers"):
		var max_workers = worker_slot.get_max_workers()
		assert_eq(max_workers, 1, "Bakery WorkerSlotComponent should have max 1 worker")
	elif bakery.has_method("get_max_workers"):
		var max_workers = bakery.get_max_workers()
		assert_eq(max_workers, 1, "Bakery should have max 1 worker")
	else:
		# Fallback: verify via building data
		assert_eq(bakery_data.max_workers, 1, "Bakery data should have max 1 worker")

	bakery.queue_free()


func test_bakery_scene_has_no_gatherer_component() -> void:
	# CRITICAL: PROCESSOR buildings should NOT have GathererComponent (AC8)
	var bakery_scene := load("res://scenes/entities/buildings/bakery.tscn") as PackedScene
	var bakery := bakery_scene.instantiate()
	add_child(bakery)
	await wait_frames(1)

	assert_null(bakery.get_node_or_null("GathererComponent"),
		"Bakery should NOT have GathererComponent (PROCESSOR type)")

	bakery.queue_free()


func test_bakery_uses_building_script() -> void:
	var bakery_scene := load("res://scenes/entities/buildings/bakery.tscn") as PackedScene
	var bakery := bakery_scene.instantiate()
	add_child(bakery)
	await wait_frames(1)

	assert_true(bakery is Building, "Bakery should be a Building instance")

	bakery.queue_free()

# =============================================================================
# AC10: VISUAL APPEARANCE - ORANGE FOR PROCESSOR
# =============================================================================

func test_bakery_visual_color_is_orange() -> void:
	var bakery_scene := load("res://scenes/entities/buildings/bakery.tscn") as PackedScene
	var bakery := bakery_scene.instantiate()
	add_child(bakery)
	await wait_frames(1)

	# Find the Visual/Placeholder MeshInstance3D
	var visual := bakery.get_node_or_null("Visual/Placeholder") as MeshInstance3D
	assert_not_null(visual, "Bakery should have Visual/Placeholder node")

	# Check material color
	var material := visual.get_surface_override_material(0) as StandardMaterial3D
	assert_not_null(material, "Bakery placeholder should have material")

	# Bakery color should be ORANGE (0.85, 0.5, 0.25) matching BuildingMenuItem.TYPE_COLORS[PROCESSOR]
	var expected_color := Color(0.85, 0.5, 0.25, 1.0)
	assert_almost_eq(material.albedo_color.r, expected_color.r, 0.01, "Bakery red channel")
	assert_almost_eq(material.albedo_color.g, expected_color.g, 0.01, "Bakery green channel")
	assert_almost_eq(material.albedo_color.b, expected_color.b, 0.01, "Bakery blue channel")

	bakery.queue_free()


func test_bakery_visually_distinct_from_farm() -> void:
	# Verify Bakery has different color than Farm (PROCESSOR vs GATHERER)
	var bakery_scene := load("res://scenes/entities/buildings/bakery.tscn") as PackedScene
	var farm_scene := load("res://scenes/entities/buildings/farm.tscn") as PackedScene

	var bakery := bakery_scene.instantiate()
	var farm := farm_scene.instantiate()
	add_child(bakery)
	add_child(farm)
	await wait_frames(1)

	var bakery_visual := bakery.get_node_or_null("Visual/Placeholder") as MeshInstance3D
	var farm_visual := farm.get_node_or_null("Visual/Placeholder") as MeshInstance3D

	var bakery_material := bakery_visual.get_surface_override_material(0) as StandardMaterial3D
	var farm_material := farm_visual.get_surface_override_material(0) as StandardMaterial3D

	# Colors should be different
	assert_ne(bakery_material.albedo_color, farm_material.albedo_color,
		"Bakery and Farm should have different visual colors")

	bakery.queue_free()
	farm.queue_free()


func test_bakery_same_color_as_mill() -> void:
	# Verify Bakery has same PROCESSOR color as Mill
	var bakery_scene := load("res://scenes/entities/buildings/bakery.tscn") as PackedScene
	var mill_scene := load("res://scenes/entities/buildings/mill.tscn") as PackedScene

	var bakery := bakery_scene.instantiate()
	var mill := mill_scene.instantiate()
	add_child(bakery)
	add_child(mill)
	await wait_frames(1)

	var bakery_visual := bakery.get_node_or_null("Visual/Placeholder") as MeshInstance3D
	var mill_visual := mill.get_node_or_null("Visual/Placeholder") as MeshInstance3D

	var bakery_material := bakery_visual.get_surface_override_material(0) as StandardMaterial3D
	var mill_material := mill_visual.get_surface_override_material(0) as StandardMaterial3D

	# Colors should be the same (both PROCESSOR type)
	assert_almost_eq(bakery_material.albedo_color.r, mill_material.albedo_color.r, 0.01,
		"Bakery and Mill should have same red channel")
	assert_almost_eq(bakery_material.albedo_color.g, mill_material.albedo_color.g, 0.01,
		"Bakery and Mill should have same green channel")
	assert_almost_eq(bakery_material.albedo_color.b, mill_material.albedo_color.b, 0.01,
		"Bakery and Mill should have same blue channel")

	bakery.queue_free()
	mill.queue_free()

# =============================================================================
# FOOTPRINT AND PRODUCTION TIME
# =============================================================================

func test_bakery_footprint_single_hex() -> void:
	assert_eq(bakery_data.footprint_hexes.size(), 1, "Bakery should occupy 1 hex")
	assert_eq(bakery_data.footprint_hexes[0], Vector2i(0, 0), "Bakery footprint should be origin hex")


func test_bakery_production_time() -> void:
	# Production time should match flour_to_bread recipe (4.0 seconds)
	assert_eq(bakery_data.production_time, 4.0, "Bakery production time should be 4.0 seconds")

# =============================================================================
# RECIPE MANAGER INTEGRATION
# =============================================================================

func test_bakery_recipe_exists_in_recipe_manager() -> void:
	# Verify the recipe referenced by Bakery exists
	var recipe := RecipeManager.get_recipe("flour_to_bread")
	assert_not_null(recipe, "flour_to_bread recipe should exist in RecipeManager")


func test_bakery_recipe_is_valid() -> void:
	var recipe := RecipeManager.get_recipe("flour_to_bread")
	assert_not_null(recipe, "Recipe should exist")
	assert_true(recipe.is_valid(), "flour_to_bread recipe should be valid")

# =============================================================================
# BUILDING.GD PROCESSOR HANDLING
# =============================================================================

func test_bakery_building_get_gatherer_returns_null() -> void:
	# When Building.initialize() runs on Bakery, _gatherer should be null
	# because is_gatherer() returns false for PROCESSOR type
	var bakery_scene := load("res://scenes/entities/buildings/bakery.tscn") as PackedScene
	var bakery := bakery_scene.instantiate() as Building
	add_child(bakery)
	await wait_frames(1)

	# Initialize with mock data (deferred call)
	var hex := HexCoord.create(0, 0)
	bakery.call_deferred("initialize", hex, bakery_data)
	await wait_frames(2)

	# Check that get_gatherer returns null
	if bakery.has_method("get_gatherer"):
		var gatherer = bakery.get_gatherer()
		assert_null(gatherer, "Bakery.get_gatherer() should return null (PROCESSOR type)")

	bakery.queue_free()

# =============================================================================
# RESOURCE DEDUCTION ON PLACEMENT
# =============================================================================

func test_bakery_placement_deducts_wood_and_stone() -> void:
	# Give player resources
	ResourceManager.add_resource("wood", 50)
	ResourceManager.add_resource("stone", 30)
	var initial_wood := ResourceManager.get_resource_amount("wood")
	var initial_stone := ResourceManager.get_resource_amount("stone")

	# Simulate resource deduction (as would happen in _place_building)
	var costs: Dictionary = bakery_data.build_cost
	for resource_id in costs:
		var amount: int = costs[resource_id]
		ResourceManager.remove_resource(resource_id, amount)

	var final_wood := ResourceManager.get_resource_amount("wood")
	var final_stone := ResourceManager.get_resource_amount("stone")
	assert_eq(final_wood, initial_wood - 25, "Bakery placement should deduct 25 wood")
	assert_eq(final_stone, initial_stone - 15, "Bakery placement should deduct 15 stone")

# =============================================================================
# EDGE CASES
# =============================================================================

func test_bakery_boundary_affordability() -> void:
	# Test boundary: exactly enough for one resource, one short for other
	ResourceManager.add_resource("wood", 25)
	ResourceManager.add_resource("stone", 14)  # One short

	var can_afford := BuildingPlacementManager._can_afford(bakery_data)

	assert_false(can_afford, "Bakery should not be affordable with 14 stone")


func test_bakery_data_not_storage_building() -> void:
	assert_false(bakery_data.is_storage_building(),
		"Bakery should not be a storage building")


func test_bakery_storage_capacity_bonus_is_zero() -> void:
	assert_eq(bakery_data.storage_capacity_bonus, 0,
		"Bakery storage_capacity_bonus should be 0")

# =============================================================================
# BUILDING MENU DISCOVERY
# =============================================================================

func test_bakery_discovered_by_building_menu_panel() -> void:
	# The BuildingMenuPanel loads all *_data.tres from res://resources/buildings/
	# Verify bakery_data.tres exists and can be discovered
	var dir := DirAccess.open("res://resources/buildings/")
	assert_not_null(dir, "Buildings resource directory should be accessible")

	var found_bakery := false
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name == "bakery_data.tres":
				found_bakery = true
				break
			file_name = dir.get_next()
		dir.list_dir_end()

	assert_true(found_bakery, "bakery_data.tres should exist in resources/buildings/ for menu discovery")

	# Also verify the data loads correctly (as BuildingMenuPanel would)
	var path := "res://resources/buildings/bakery_data.tres"
	var data := load(path) as BuildingData
	assert_not_null(data, "Bakery data should load as BuildingData")
	assert_true(data.is_valid(), "Bakery data should be valid for menu display")

# =============================================================================
# BAKERY VS MILL COMPARISON (PROCESSOR CONSISTENCY)
# =============================================================================

func test_bakery_and_mill_both_processors() -> void:
	var mill_data := load("res://resources/buildings/mill_data.tres") as BuildingData

	assert_eq(bakery_data.building_type, mill_data.building_type,
		"Bakery and Mill should both be PROCESSOR type")
	assert_eq(bakery_data.building_type, BuildingTypes.BuildingType.PROCESSOR,
		"Both should be PROCESSOR enum value")


func test_bakery_more_expensive_than_mill() -> void:
	var mill_data := load("res://resources/buildings/mill_data.tres") as BuildingData

	# Bakery: 25 wood, 15 stone
	# Mill: 20 wood, 10 stone
	assert_gt(bakery_data.build_cost["wood"], mill_data.build_cost["wood"],
		"Bakery should cost more wood than Mill")
	assert_gt(bakery_data.build_cost["stone"], mill_data.build_cost["stone"],
		"Bakery should cost more stone than Mill")


func test_bakery_production_time_longer_than_mill() -> void:
	var mill_data := load("res://resources/buildings/mill_data.tres") as BuildingData

	# Bakery: 4.0 seconds (flour_to_bread)
	# Mill: 3.0 seconds (wheat_to_flour)
	assert_gt(bakery_data.production_time, mill_data.production_time,
		"Bakery production time should be longer than Mill")
