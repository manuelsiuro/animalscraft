## Integration tests for Shelter System
## Tests full flow of shelter building, seeking, and recovery.
##
## Story: 5-11-create-shelter-building-for-resting
extends GutTest

# Test tracking
var _shelter_entered_count: int = 0
var _shelter_left_count: int = 0

func before_each() -> void:
	_shelter_entered_count = 0
	_shelter_left_count = 0

	# Connect to EventBus signals for tracking
	if EventBus:
		EventBus.animal_entered_shelter.connect(_on_shelter_entered)
		EventBus.animal_left_shelter.connect(_on_shelter_left)


func after_each() -> void:
	# Disconnect EventBus signals
	if EventBus:
		if EventBus.animal_entered_shelter.is_connected(_on_shelter_entered):
			EventBus.animal_entered_shelter.disconnect(_on_shelter_entered)
		if EventBus.animal_left_shelter.is_connected(_on_shelter_left):
			EventBus.animal_left_shelter.disconnect(_on_shelter_left)


func _on_shelter_entered(_animal: Node, _shelter: Node) -> void:
	_shelter_entered_count += 1


func _on_shelter_left(_animal: Node, _shelter: Node) -> void:
	_shelter_left_count += 1


# =============================================================================
# SHELTER DATA TESTS (AC: 2, 3, 4)
# =============================================================================

func test_shelter_data_resource_loads_correctly() -> void:
	var path := "res://resources/buildings/shelter_data.tres"
	assert_true(ResourceLoader.exists(path), "shelter_data.tres should exist")

	var data := load(path) as BuildingData
	assert_not_null(data, "Should load as BuildingData")
	assert_eq(data.building_id, "shelter", "ID should be 'shelter'")
	assert_eq(data.display_name, "Shelter", "Display name should be 'Shelter'")
	assert_eq(data.building_type, BuildingTypes.BuildingType.SHELTER, "Type should be SHELTER")
	assert_eq(data.max_workers, 4, "Max workers/capacity should be 4")
	assert_eq(data.build_cost.get("wood", 0), 15, "Build cost should be 15 wood")


func test_shelter_terrain_requirements() -> void:
	var data := load("res://resources/buildings/shelter_data.tres") as BuildingData
	assert_not_null(data)

	# Should only be placeable on GRASS (0)
	assert_true(data.terrain_requirements.has(0), "Should allow GRASS terrain")
	assert_eq(data.terrain_requirements.size(), 1, "Should only allow one terrain type")


# =============================================================================
# BUILDING FACTORY TESTS (AC: 1)
# =============================================================================

func test_building_factory_has_shelter_type() -> void:
	assert_true(BuildingFactory.has_building_type("shelter"), "BuildingFactory should have 'shelter' type")


func test_building_factory_shelter_in_available_types() -> void:
	var types := BuildingFactory.get_available_types()
	assert_true("shelter" in types, "Shelter should be in available types")


# =============================================================================
# SHELTER BUILDING CREATION TESTS (AC: 3)
# =============================================================================

func test_shelter_scene_exists() -> void:
	var path := "res://scenes/entities/buildings/shelter.tscn"
	assert_true(ResourceLoader.exists(path), "shelter.tscn should exist")


func test_shelter_scene_has_required_components() -> void:
	var scene := load("res://scenes/entities/buildings/shelter.tscn") as PackedScene
	assert_not_null(scene, "Shelter scene should load")

	var instance := scene.instantiate()
	add_child(instance)
	await wait_frames(1)

	# Check for required components
	assert_not_null(instance.get_node_or_null("SelectableComponent"), "Should have SelectableComponent")
	assert_not_null(instance.get_node_or_null("WorkerSlotComponent"), "Should have WorkerSlotComponent")
	assert_not_null(instance.get_node_or_null("ShelterComponent"), "Should have ShelterComponent")
	assert_not_null(instance.get_node_or_null("Visual"), "Should have Visual node")

	instance.queue_free()


# =============================================================================
# SHELTER COMPONENT INTEGRATION TESTS (AC: 5, 6, 7)
# =============================================================================

func test_shelter_component_constants_match_spec() -> void:
	assert_eq(ShelterComponent.RECOVERY_MULTIPLIER, 2.0, "Recovery multiplier should be 2.0")
	assert_eq(ShelterComponent.MAX_CAPACITY, 4, "Max capacity should be 4")


# =============================================================================
# RESTING STATE RECOVERY TESTS (AC: 5, 6)
# =============================================================================

func test_resting_state_has_base_energy_recovery_rate() -> void:
	# Check constant exists
	assert_eq(RestingState.BASE_ENERGY_RECOVERY_RATE, 0.33, "Base recovery rate should be 0.33")


# =============================================================================
# EVENT BUS SIGNAL TESTS (AC: 14, 15, 16, 17)
# =============================================================================

func test_event_bus_has_shelter_signals() -> void:
	assert_true(EventBus.has_signal("animal_entered_shelter"), "Should have animal_entered_shelter signal")
	assert_true(EventBus.has_signal("animal_left_shelter"), "Should have animal_left_shelter signal")
	assert_true(EventBus.has_signal("shelter_capacity_reached"), "Should have shelter_capacity_reached signal")
	assert_true(EventBus.has_signal("shelter_capacity_available"), "Should have shelter_capacity_available signal")


# =============================================================================
# BUILDING CLASS INTEGRATION TESTS (AC: 10, 11)
# =============================================================================

func test_building_has_shelter_methods() -> void:
	# Create a building instance to check methods exist
	var building := Building.new()
	add_child(building)
	await wait_frames(1)

	assert_true(building.has_method("get_shelter"), "Building should have get_shelter method")
	assert_true(building.has_method("is_shelter"), "Building should have is_shelter method")

	building.queue_free()


func test_shelter_building_added_to_shelters_group() -> void:
	# This requires a full shelter building instantiation
	var shelter_data := load("res://resources/buildings/shelter_data.tres") as BuildingData
	if shelter_data == null:
		pending("shelter_data.tres not found")
		return

	var shelter := load("res://scenes/entities/buildings/shelter.tscn").instantiate() as Building
	add_child(shelter)

	# Initialize with shelter data and hex
	var hex := HexCoord.new(0, 0)
	shelter.initialize(hex, shelter_data)
	await wait_frames(2)

	assert_true(shelter.is_in_group(GameConstants.GROUP_SHELTERS), "Shelter should be in 'shelters' group")

	shelter.cleanup()


# =============================================================================
# SHELTER SEEKING SYSTEM INTEGRATION TESTS (AC: 8, 9)
# =============================================================================

func test_shelter_seeking_system_exists_and_has_constants() -> void:
	assert_eq(ShelterSeekingSystem.SHELTER_SEEK_RADIUS, 5, "Seek radius should be 5 hexes")
	assert_eq(ShelterSeekingSystem.RESERVATION_TIMEOUT, 30.0, "Reservation timeout should be 30 seconds")


# =============================================================================
# ANIMAL TARGET BUILDING TESTS
# =============================================================================

func test_animal_has_target_building_methods() -> void:
	var animal := Animal.new()
	add_child(animal)
	await wait_frames(1)

	assert_true(animal.has_method("set_target_building"), "Animal should have set_target_building")
	assert_true(animal.has_method("get_target_building"), "Animal should have get_target_building")
	assert_true(animal.has_method("has_target_building"), "Animal should have has_target_building")

	animal.queue_free()


# =============================================================================
# BUILDING INFO PANEL INTEGRATION TESTS (AC: 18, 19)
# =============================================================================

func test_building_info_panel_has_shelter_status_constants() -> void:
	assert_true("STATUS_SHELTER_EMPTY" in BuildingInfoPanel, "Should have STATUS_SHELTER_EMPTY constant")
	assert_true("STATUS_SHELTER_PARTIAL" in BuildingInfoPanel, "Should have STATUS_SHELTER_PARTIAL constant")
	assert_true("STATUS_SHELTER_FULL" in BuildingInfoPanel, "Should have STATUS_SHELTER_FULL constant")
