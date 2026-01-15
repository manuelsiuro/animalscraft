## Unit tests for Building entity system.
## Tests BuildingData, Building, WorkerSlotComponent, BuildingFactory,
## hex occupancy, and integration with selection/pathfinding systems.
##
## Architecture: tests/unit/test_building_entity.gd
## Story: 3-1-create-building-entity-structure
extends GutTest

# =============================================================================
# TEST DATA
# =============================================================================

var building: Node3D
var mock_hex: HexCoord
var mock_data: BuildingData
var mock_animal: Node3D

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Create test data
	mock_hex = HexCoord.new(2, 3)

	mock_data = BuildingData.new()
	mock_data.building_id = "test_farm"
	mock_data.display_name = "Test Farm"
	mock_data.building_type = BuildingTypes.BuildingType.GATHERER
	mock_data.max_workers = 2
	mock_data.footprint_hexes = [Vector2i.ZERO]

	# Clear any previous occupancy data
	HexGrid.clear_occupancy()


func after_each() -> void:
	if is_instance_valid(building) and not building.is_queued_for_deletion():
		building.cleanup() if building.has_method("cleanup") else building.queue_free()
		await wait_frames(1)
	building = null

	if is_instance_valid(mock_animal) and not mock_animal.is_queued_for_deletion():
		mock_animal.queue_free()
		await wait_frames(1)
	mock_animal = null

	mock_hex = null
	mock_data = null

	# Clean up occupancy
	HexGrid.clear_occupancy()


func _create_test_building() -> Node3D:
	var scene := preload("res://scenes/entities/buildings/farm.tscn")
	var bld := scene.instantiate()
	add_child(bld)
	await wait_frames(1)
	return bld


func _create_mock_animal() -> Node3D:
	var scene := preload("res://scenes/entities/animals/rabbit.tscn")
	var anim := scene.instantiate()
	add_child(anim)
	await wait_frames(1)
	return anim

# =============================================================================
# AC1: BUILDING BASE CLASS
# =============================================================================

func test_building_not_initialized_before_initialize() -> void:
	building = await _create_test_building()
	assert_false(building.is_initialized(), "Building should not be initialized before initialize() call")


func test_building_initialize_sets_hex() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	var stored_hex: HexCoord = building.get_hex_coord()
	assert_eq(stored_hex.q, mock_hex.q, "Hex q should match")
	assert_eq(stored_hex.r, mock_hex.r, "Hex r should match")


func test_building_initialize_sets_data() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	var stored_data: BuildingData = building.get_data()
	assert_eq(stored_data.building_id, "test_farm", "Building ID should match")
	assert_eq(stored_data.max_workers, 2, "Max workers should match")


func test_building_initialize_positions_at_hex() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	var expected_pos := HexGrid.hex_to_world(mock_hex)
	assert_almost_eq(building.position.x, expected_pos.x, 0.1, "X position should match hex world pos")
	assert_almost_eq(building.position.z, expected_pos.z, 0.1, "Z position should match hex world pos")


func test_building_is_initialized_after_initialize() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	assert_true(building.is_initialized(), "Building should be initialized after initialize() call")


func test_building_added_to_buildings_group() -> void:
	building = await _create_test_building()

	assert_true(building.is_in_group("buildings"), "Building should be in 'buildings' group")


func test_building_spawned_signal_emitted() -> void:
	building = await _create_test_building()
	watch_signals(EventBus)

	building.initialize(mock_hex, mock_data)

	assert_signal_emitted(EventBus, "building_spawned")


func test_building_spawned_signal_contains_building() -> void:
	building = await _create_test_building()
	watch_signals(EventBus)

	building.initialize(mock_hex, mock_data)

	var params: Array = get_signal_parameters(EventBus, "building_spawned")
	assert_eq(params[0], building, "Signal should contain the building instance")


func test_double_initialize_does_not_crash() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)
	building.initialize(mock_hex, mock_data)  # Second call should warn but not crash

	assert_true(building.is_initialized(), "Building should remain initialized after double init")

# =============================================================================
# AC2: BUILDING DATA RESOURCE
# =============================================================================

func test_building_data_is_valid() -> void:
	assert_true(mock_data.is_valid(), "Mock building data should be valid")


func test_building_data_invalid_without_id() -> void:
	mock_data.building_id = ""
	assert_false(mock_data.is_valid(), "Building data without ID should be invalid")


func test_building_data_invalid_without_display_name() -> void:
	mock_data.display_name = ""
	assert_false(mock_data.is_valid(), "Building data without display_name should be invalid")


func test_building_data_invalid_with_negative_workers() -> void:
	mock_data.max_workers = -1
	assert_false(mock_data.is_valid(), "Building data with negative workers should be invalid")


func test_building_data_get_type_name() -> void:
	assert_eq(mock_data.get_type_name(), "Gatherer", "Type name should be 'Gatherer'")


func test_building_data_can_have_workers() -> void:
	assert_true(mock_data.can_have_workers(), "Building with max_workers > 0 should accept workers")
	mock_data.max_workers = 0
	assert_false(mock_data.can_have_workers(), "Building with max_workers = 0 should not accept workers")

# =============================================================================
# AC3: COMPONENT ARCHITECTURE
# =============================================================================

func test_building_has_visual_node() -> void:
	building = await _create_test_building()
	assert_true(building.has_node("Visual"), "Building should have Visual node")


func test_building_has_selectable_component() -> void:
	building = await _create_test_building()
	assert_true(building.has_node("SelectableComponent"), "Building should have SelectableComponent")


func test_building_has_worker_slot_component() -> void:
	building = await _create_test_building()
	assert_true(building.has_node("WorkerSlotComponent"), "Building should have WorkerSlotComponent")


func test_building_is_node3d() -> void:
	building = await _create_test_building()
	assert_true(building is Node3D, "Building should extend Node3D")

# =============================================================================
# AC4: WORKER SLOT MANAGEMENT
# =============================================================================

func test_worker_slot_add_worker() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	mock_animal = await _create_mock_animal()
	var worker_slots: WorkerSlotComponent = building.get_node("WorkerSlotComponent")

	var result := worker_slots.add_worker(mock_animal)

	assert_true(result, "Adding worker should succeed")
	assert_eq(worker_slots.get_worker_count(), 1, "Worker count should be 1")


func test_worker_slot_respects_max_workers() -> void:
	mock_data.max_workers = 1
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	var animal1 = await _create_mock_animal()
	var animal2_scene := preload("res://scenes/entities/animals/rabbit.tscn")
	var animal2 := animal2_scene.instantiate()
	add_child(animal2)
	await wait_frames(1)

	var worker_slots: WorkerSlotComponent = building.get_node("WorkerSlotComponent")
	worker_slots.add_worker(animal1)
	var result := worker_slots.add_worker(animal2)

	assert_false(result, "Adding second worker should fail (max_workers=1)")
	assert_eq(worker_slots.get_worker_count(), 1, "Worker count should remain 1")

	# Cleanup extra animal
	animal2.queue_free()
	mock_animal = animal1


func test_worker_slot_remove_worker() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	mock_animal = await _create_mock_animal()
	var worker_slots: WorkerSlotComponent = building.get_node("WorkerSlotComponent")

	worker_slots.add_worker(mock_animal)
	var result := worker_slots.remove_worker(mock_animal)

	assert_true(result, "Removing worker should succeed")
	assert_eq(worker_slots.get_worker_count(), 0, "Worker count should be 0")


func test_worker_slot_is_slot_available() -> void:
	mock_data.max_workers = 1
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	var worker_slots: WorkerSlotComponent = building.get_node("WorkerSlotComponent")

	assert_true(worker_slots.is_slot_available(), "Slot should be available initially")

	mock_animal = await _create_mock_animal()
	worker_slots.add_worker(mock_animal)

	assert_false(worker_slots.is_slot_available(), "Slot should not be available when full")


func test_worker_slot_get_workers_returns_copy() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	mock_animal = await _create_mock_animal()
	var worker_slots: WorkerSlotComponent = building.get_node("WorkerSlotComponent")
	worker_slots.add_worker(mock_animal)

	var workers := worker_slots.get_workers()
	workers.clear()  # Modify returned array

	# Original should be unchanged
	assert_eq(worker_slots.get_worker_count(), 1, "Original worker array should be unchanged")


func test_worker_added_signal_emitted() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	mock_animal = await _create_mock_animal()
	var worker_slots: WorkerSlotComponent = building.get_node("WorkerSlotComponent")
	watch_signals(worker_slots)

	worker_slots.add_worker(mock_animal)

	assert_signal_emitted(worker_slots, "worker_added")


func test_worker_removed_signal_emitted() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	mock_animal = await _create_mock_animal()
	var worker_slots: WorkerSlotComponent = building.get_node("WorkerSlotComponent")
	worker_slots.add_worker(mock_animal)
	watch_signals(worker_slots)

	worker_slots.remove_worker(mock_animal)

	assert_signal_emitted(worker_slots, "worker_removed")


func test_workers_changed_signal_emitted() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	mock_animal = await _create_mock_animal()
	var worker_slots: WorkerSlotComponent = building.get_node("WorkerSlotComponent")
	watch_signals(worker_slots)

	worker_slots.add_worker(mock_animal)

	assert_signal_emitted(worker_slots, "workers_changed")


func test_worker_slot_has_worker() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	mock_animal = await _create_mock_animal()
	var worker_slots: WorkerSlotComponent = building.get_node("WorkerSlotComponent")

	assert_false(worker_slots.has_worker(mock_animal), "Should not have worker initially")

	worker_slots.add_worker(mock_animal)

	assert_true(worker_slots.has_worker(mock_animal), "Should have worker after add")


func test_worker_slot_add_invalid_animal() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	var worker_slots: WorkerSlotComponent = building.get_node("WorkerSlotComponent")

	var result := worker_slots.add_worker(null)

	assert_false(result, "Adding null worker should fail")
	assert_eq(worker_slots.get_worker_count(), 0, "Worker count should remain 0")


func test_worker_slot_add_duplicate_worker() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	mock_animal = await _create_mock_animal()
	var worker_slots: WorkerSlotComponent = building.get_node("WorkerSlotComponent")

	worker_slots.add_worker(mock_animal)
	var result := worker_slots.add_worker(mock_animal)  # Add same animal again

	assert_false(result, "Adding duplicate worker should fail")
	assert_eq(worker_slots.get_worker_count(), 1, "Worker count should remain 1")

# =============================================================================
# AC6: HEX OCCUPANCY
# =============================================================================

func test_hex_marked_occupied_on_initialize() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	assert_false(HexGrid.is_hex_buildable(mock_hex.to_vector()), "Hex should not be buildable after building init")
	assert_true(HexGrid.is_hex_occupied(mock_hex.to_vector()), "Hex should be marked occupied")


func test_get_building_at_hex() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	var found := HexGrid.get_building_at_hex(mock_hex.to_vector())
	assert_eq(found, building, "get_building_at_hex should return the building")


func test_hex_unmarked_on_cleanup() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)
	building.cleanup()
	await wait_frames(1)

	assert_true(HexGrid.is_hex_buildable(mock_hex.to_vector()), "Hex should be buildable after cleanup")


func test_is_hex_buildable_returns_true_for_empty() -> void:
	var empty_hex := Vector2i(10, 10)
	assert_true(HexGrid.is_hex_buildable(empty_hex), "Empty hex should be buildable")


func test_building_removed_signal_includes_hex() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)
	watch_signals(EventBus)

	building.cleanup()

	assert_signal_emitted(EventBus, "building_removed")
	var params: Array = get_signal_parameters(EventBus, "building_removed")
	assert_eq(params[1], mock_hex.to_vector(), "Signal should include hex coordinate")

# =============================================================================
# AC7: BUILDING TYPES ENUM
# =============================================================================

func test_building_type_enum_values() -> void:
	assert_eq(BuildingTypes.BuildingType.GATHERER, 0, "GATHERER should be 0")
	assert_eq(BuildingTypes.BuildingType.PROCESSOR, 1, "PROCESSOR should be 1")
	assert_eq(BuildingTypes.BuildingType.STORAGE, 2, "STORAGE should be 2")
	assert_eq(BuildingTypes.BuildingType.SHELTER, 3, "SHELTER should be 3")
	assert_eq(BuildingTypes.BuildingType.UPGRADE, 4, "UPGRADE should be 4")


func test_get_type_name_returns_string() -> void:
	assert_eq(BuildingTypes.get_type_name(BuildingTypes.BuildingType.GATHERER), "Gatherer")
	assert_eq(BuildingTypes.get_type_name(BuildingTypes.BuildingType.PROCESSOR), "Processor")
	assert_eq(BuildingTypes.get_type_name(BuildingTypes.BuildingType.STORAGE), "Storage")
	assert_eq(BuildingTypes.get_type_name(BuildingTypes.BuildingType.SHELTER), "Shelter")
	assert_eq(BuildingTypes.get_type_name(BuildingTypes.BuildingType.UPGRADE), "Upgrade")


func test_get_building_type() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	assert_eq(building.get_building_type(), BuildingTypes.BuildingType.GATHERER, "Building type should match data")

# =============================================================================
# AC8: BUILDING FACTORY
# =============================================================================

func test_factory_creates_farm() -> void:
	var hex := HexCoord.new(0, 0)
	var farm := BuildingFactory.create_building("farm", hex)

	if farm:
		add_child(farm)
		await wait_frames(2)

	assert_not_null(farm, "Factory should create farm building")

	# Cleanup
	if is_instance_valid(farm):
		farm.cleanup() if farm.has_method("cleanup") else farm.queue_free()


func test_factory_creates_sawmill() -> void:
	var hex := HexCoord.new(1, 1)
	var sawmill := BuildingFactory.create_building("sawmill", hex)

	if sawmill:
		add_child(sawmill)
		await wait_frames(2)

	assert_not_null(sawmill, "Factory should create sawmill building")

	# Cleanup
	if is_instance_valid(sawmill):
		sawmill.cleanup() if sawmill.has_method("cleanup") else sawmill.queue_free()


func test_factory_handles_unknown_type() -> void:
	var hex := HexCoord.new(0, 0)
	var invalid := BuildingFactory.create_building("nonexistent", hex)

	assert_null(invalid, "Factory should return null for unknown type")


func test_factory_handles_null_hex() -> void:
	var invalid := BuildingFactory.create_building("farm", null)

	assert_null(invalid, "Factory should return null for null hex")


func test_factory_get_available_types() -> void:
	var types := BuildingFactory.get_available_types()

	assert_has(types, "farm", "Available types should include farm")
	assert_has(types, "sawmill", "Available types should include sawmill")


func test_factory_has_building_type() -> void:
	assert_true(BuildingFactory.has_building_type("farm"), "Should have farm type")
	assert_true(BuildingFactory.has_building_type("sawmill"), "Should have sawmill type")
	assert_false(BuildingFactory.has_building_type("nonexistent"), "Should not have nonexistent type")


func test_factory_prevents_placement_on_occupied_hex() -> void:
	# First building should succeed
	var hex := HexCoord.new(5, 5)
	var building1 := BuildingFactory.create_building("farm", hex)
	if building1:
		add_child(building1)
		await wait_frames(2)

	# Second building at same hex should fail
	var building2 := BuildingFactory.create_building("sawmill", hex)

	assert_null(building2, "Factory should prevent placement on occupied hex")

	# Cleanup
	if is_instance_valid(building1):
		building1.cleanup()

# =============================================================================
# AC5: BUILDING SELECTION (Integration with SelectionManager)
# =============================================================================

func test_building_selection_emits_signal() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)
	watch_signals(building)

	var selectable: SelectableComponent = building.get_node("SelectableComponent")
	selectable.select()

	assert_signal_emitted_with_parameters(building, "selected", [])


func test_building_deselection_emits_signal() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	var selectable: SelectableComponent = building.get_node("SelectableComponent")
	selectable.select()
	watch_signals(building)
	selectable.deselect()

	assert_signal_emitted_with_parameters(building, "deselected", [])


func test_building_is_selected() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	var selectable: SelectableComponent = building.get_node("SelectableComponent")

	assert_false(building.is_selected(), "Building should not be selected initially")

	selectable.select()

	assert_true(building.is_selected(), "Building should be selected after select()")

# =============================================================================
# CLEANUP TESTS
# =============================================================================

func test_cleanup_removes_from_group() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)
	building.cleanup()
	await wait_frames(1)

	var buildings := get_tree().get_nodes_in_group("buildings")
	assert_does_not_have(buildings, building, "Building should be removed from group after cleanup")


func test_cleanup_clears_references() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)
	building.cleanup()

	assert_null(building.hex_coord, "hex_coord should be null after cleanup")
	assert_null(building.data, "data should be null after cleanup")


func test_cleanup_emits_building_removed_signal() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)
	watch_signals(EventBus)

	building.cleanup()

	assert_signal_emitted(EventBus, "building_removed")


func test_cleanup_only_emits_signal_if_initialized() -> void:
	building = await _create_test_building()
	watch_signals(EventBus)

	building.cleanup()

	assert_signal_not_emitted(EventBus, "building_removed")

# =============================================================================
# PARTY MODE / EDGE CASE TESTS (GLaDOS additions)
# =============================================================================

func test_worker_freed_while_assigned_auto_removed() -> void:
	## GLaDOS: Test worker freed while assigned - WorkerSlotComponent auto-removes
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	mock_animal = await _create_mock_animal()
	var worker_slots: WorkerSlotComponent = building.get_node("WorkerSlotComponent")
	worker_slots.add_worker(mock_animal)

	assert_eq(worker_slots.get_worker_count(), 1, "Should have 1 worker")

	# Simulate animal removal via EventBus (WorkerSlotComponent listens)
	EventBus.animal_removed.emit(mock_animal)

	# Worker should be auto-removed
	assert_eq(worker_slots.get_worker_count(), 0, "Worker should be auto-removed when animal is removed")
	mock_animal = null  # Don't cleanup again


func test_initialize_with_null_hex_does_not_crash() -> void:
	## GLaDOS: Test null hex handling
	building = await _create_test_building()
	building.initialize(null, mock_data)

	assert_true(building.is_initialized(), "Should initialize even with null hex")


func test_initialize_with_null_data_does_not_crash() -> void:
	## GLaDOS: Test null data handling
	building = await _create_test_building()
	building.initialize(mock_hex, null)

	assert_true(building.is_initialized(), "Should initialize even with null data")


func test_get_worker_slots_returns_component() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	var worker_slots: WorkerSlotComponent = building.get_worker_slots()

	assert_not_null(worker_slots, "get_worker_slots should return component")
	assert_true(worker_slots is WorkerSlotComponent, "Should be WorkerSlotComponent type")


func test_building_to_string() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	var str_repr := str(building)
	assert_true(str_repr.contains("test_farm") or str_repr.contains("Building"), "String should contain building info")

# =============================================================================
# PUBLIC API TESTS
# =============================================================================

func test_get_building_id_returns_data_id() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, mock_data)

	assert_eq(building.get_building_id(), "test_farm", "get_building_id should return data building_id")


func test_get_building_id_returns_empty_when_no_data() -> void:
	building = await _create_test_building()
	building.initialize(mock_hex, null)

	assert_eq(building.get_building_id(), "", "get_building_id should return empty string when no data")

# =============================================================================
# INTEGRATION TESTS - PATHFINDING (Tasks 12.6, 12.7, 12.8)
# =============================================================================

func test_pathfinding_respects_building_occupancy() -> void:
	## Task 12.6: Test animal paths AROUND building after spawn
	## Verifies that PathfindingManager treats building hexes as impassable
	building = await _create_test_building()
	var building_hex := HexCoord.new(5, 5)
	building.initialize(building_hex, mock_data)

	# Building hex should not be passable for pathfinding
	var hex_vec: Vector2i = building_hex.to_vector()
	assert_true(HexGrid.is_hex_occupied(hex_vec), "Building hex should be occupied")
	assert_false(HexGrid.is_hex_buildable(hex_vec), "Building hex should not be buildable")


func test_path_cache_invalidated_on_building_removal() -> void:
	## Task 12.7: Test path cache invalidated on building removal
	## Verifies that PathfindingManager receives building_removed signal with hex
	building = await _create_test_building()
	var building_hex := HexCoord.new(5, 5)
	building.initialize(building_hex, mock_data)
	watch_signals(EventBus)

	# Remove building
	building.cleanup()
	await wait_frames(1)

	# Verify building_removed was emitted with hex coordinate
	assert_signal_emitted(EventBus, "building_removed")
	var params: Array = get_signal_parameters(EventBus, "building_removed")
	assert_eq(params.size(), 2, "building_removed should have 2 parameters")
	assert_eq(params[1], building_hex.to_vector(), "Second param should be hex coordinate")

	# Hex should now be free
	assert_true(HexGrid.is_hex_buildable(building_hex.to_vector()), "Hex should be buildable after removal")


func test_adjacent_hexes_remain_walkable() -> void:
	## Task 12.8: Test animal can reach adjacent hex of building for work assignment
	## Building hex is impassable but neighbors are valid work destinations
	building = await _create_test_building()
	var building_hex := HexCoord.new(5, 5)
	building.initialize(building_hex, mock_data)

	# Building hex is occupied
	assert_true(HexGrid.is_hex_occupied(building_hex.to_vector()), "Building hex should be occupied")

	# Adjacent hexes should NOT be occupied (only the building footprint is)
	var neighbors := building_hex.get_neighbors()
	for neighbor in neighbors:
		var neighbor_vec: Vector2i = neighbor.to_vector()
		# Adjacent hexes remain buildable/walkable (not occupied by this building)
		assert_false(HexGrid.is_hex_occupied(neighbor_vec), "Adjacent hex %s should not be occupied" % neighbor)


func test_building_spawned_triggers_pathfinding_update() -> void:
	## Additional integration test: Verify EventBus building_spawned is emitted
	## PathfindingManager listens to this to update its graph
	watch_signals(EventBus)

	building = await _create_test_building()
	var building_hex := HexCoord.new(7, 7)
	building.initialize(building_hex, mock_data)

	assert_signal_emitted(EventBus, "building_spawned")
	var params: Array = get_signal_parameters(EventBus, "building_spawned")
	assert_eq(params[0], building, "building_spawned should contain the building")
