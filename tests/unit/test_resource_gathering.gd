## Unit tests for Resource Gathering System (Story 3-8).
## Tests GathererComponent, production cycles, worker assignment,
## storage integration, and signal emissions.
##
## Architecture: tests/unit/test_resource_gathering.gd
## Story: 3-8-implement-resource-gathering
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

	# Clear hex occupancy
	HexGrid.clear_occupancy()


func after_each() -> void:
	# Clear resources
	ResourceManager.clear_all()

	# Clear hex occupancy
	HexGrid.clear_occupancy()

	farm_data = null
	sawmill_data = null

# =============================================================================
# AC2/AC3: OUTPUT RESOURCE CONFIGURATION
# =============================================================================

func test_farm_output_resource_is_wheat() -> void:
	assert_not_null(farm_data, "Farm data should load")
	assert_eq(farm_data.output_resource_id, "wheat", "Farm should produce wheat")


func test_sawmill_output_resource_is_wood() -> void:
	assert_not_null(sawmill_data, "Sawmill data should load")
	assert_eq(sawmill_data.output_resource_id, "wood", "Sawmill should produce wood")


func test_farm_production_time_is_5_seconds() -> void:
	assert_eq(farm_data.production_time, 5.0, "Farm should have 5 second production time")


func test_sawmill_production_time_is_5_seconds() -> void:
	assert_eq(sawmill_data.production_time, 5.0, "Sawmill should have 5 second production time")


func test_farm_is_gatherer() -> void:
	assert_true(farm_data.is_gatherer(), "Farm should be recognized as gatherer")


func test_sawmill_is_gatherer() -> void:
	assert_true(sawmill_data.is_gatherer(), "Sawmill should be recognized as gatherer")

# =============================================================================
# AC9: BUILDING DATA TO_STRING INCLUDES OUTPUT
# =============================================================================

func test_building_data_to_string_includes_output() -> void:
	var str_repr := farm_data.to_string()
	assert_true("wheat" in str_repr, "Farm to_string should include output resource")


# =============================================================================
# GATHERER COMPONENT UNIT TESTS
# =============================================================================

func test_gatherer_component_initialization() -> void:
	var gatherer := GathererComponent.new()
	add_child(gatherer)
	await wait_frames(1)

	assert_false(gatherer.is_initialized(), "Should not be initialized before initialize()")

	# Initialize with test values
	gatherer.initialize(null, "wheat", 5.0)

	assert_true(gatherer.is_initialized(), "Should be initialized after initialize()")
	assert_eq(gatherer.get_output_resource_id(), "wheat", "Should have correct output resource")
	assert_eq(gatherer.get_production_time(), 5.0, "Should have correct production time")

	gatherer.queue_free()


func test_gatherer_component_minimum_production_time() -> void:
	var gatherer := GathererComponent.new()
	add_child(gatherer)
	await wait_frames(1)

	# Initialize with very small production time
	gatherer.initialize(null, "test", 0.01)

	# Should be clamped to minimum 0.1 seconds
	assert_true(gatherer.get_production_time() >= 0.1, "Production time should have minimum of 0.1s")

	gatherer.queue_free()


func test_gatherer_component_start_worker_tracks_animal() -> void:
	var gatherer := GathererComponent.new()
	add_child(gatherer)
	await wait_frames(1)
	gatherer.initialize(null, "wheat", 5.0)

	# Create mock animal
	var mock_animal := _create_mock_animal("test_animal_1")
	add_child(mock_animal)
	await wait_frames(1)

	assert_eq(gatherer.get_active_worker_count(), 0, "Should start with 0 workers")

	gatherer.start_worker(mock_animal)

	assert_eq(gatherer.get_active_worker_count(), 1, "Should have 1 worker after start")
	assert_true(gatherer.is_worker_active(mock_animal), "Worker should be active")

	gatherer.queue_free()
	mock_animal.queue_free()


func test_gatherer_component_stop_worker_removes_animal() -> void:
	var gatherer := GathererComponent.new()
	add_child(gatherer)
	await wait_frames(1)
	gatherer.initialize(null, "wheat", 5.0)

	# Create mock animal
	var mock_animal := _create_mock_animal("test_animal_2")
	add_child(mock_animal)
	await wait_frames(1)

	gatherer.start_worker(mock_animal)
	assert_eq(gatherer.get_active_worker_count(), 1, "Should have 1 worker")

	gatherer.stop_worker(mock_animal)

	assert_eq(gatherer.get_active_worker_count(), 0, "Should have 0 workers after stop")
	assert_false(gatherer.is_worker_active(mock_animal), "Worker should not be active")

	gatherer.queue_free()
	mock_animal.queue_free()


func test_gatherer_component_worker_progress() -> void:
	var gatherer := GathererComponent.new()
	add_child(gatherer)
	await wait_frames(1)
	gatherer.initialize(null, "wheat", 1.0)  # 1 second for faster test

	# Create mock animal
	var mock_animal := _create_mock_animal("test_animal_3")
	add_child(mock_animal)
	await wait_frames(1)

	gatherer.start_worker(mock_animal)

	# Initially at 0 progress
	var initial_progress := gatherer.get_worker_progress(mock_animal)
	assert_almost_eq(initial_progress, 0.0, 0.01, "Should start at 0 progress")

	# Wait for partial progress
	await wait_frames(30)  # ~0.5 seconds at 60fps

	var mid_progress := gatherer.get_worker_progress(mock_animal)
	assert_gt(mid_progress, 0.0, "Progress should advance over time")
	assert_lt(mid_progress, 1.0, "Progress should not complete yet")

	gatherer.queue_free()
	mock_animal.queue_free()


func test_gatherer_component_cleanup() -> void:
	var gatherer := GathererComponent.new()
	add_child(gatherer)
	await wait_frames(1)
	gatherer.initialize(null, "wheat", 5.0)

	# Create mock animal
	var mock_animal := _create_mock_animal("test_animal_4")
	add_child(mock_animal)
	await wait_frames(1)

	gatherer.start_worker(mock_animal)

	gatherer.cleanup()

	assert_eq(gatherer.get_active_worker_count(), 0, "Cleanup should clear all workers")
	assert_false(gatherer.is_initialized(), "Cleanup should reset initialized state")

	gatherer.queue_free()
	mock_animal.queue_free()

# =============================================================================
# AC4: PRODUCTION_STARTED SIGNAL
# =============================================================================

func test_production_started_signal_emitted_on_first_worker() -> void:
	var farm_scene := load("res://scenes/entities/buildings/farm.tscn") as PackedScene
	if not farm_scene:
		pending("Farm scene not available for test")
		return

	# Load actual animal scene (WorkerSlotComponent requires Animal type)
	var animal_scene := load("res://scenes/entities/animals/rabbit.tscn") as PackedScene
	if not animal_scene:
		pending("Animal scene not available for test")
		return

	var farm := farm_scene.instantiate()
	add_child(farm)
	await wait_frames(1)

	var hex := HexCoord.new(0, 0)
	farm.initialize(hex, farm_data)

	# Watch EventBus signal
	watch_signals(EventBus)

	# Create real animal (WorkerSlotComponent.add_worker expects Animal type)
	var animal := animal_scene.instantiate()
	add_child(animal)
	await wait_frames(1)

	var slots: WorkerSlotComponent = farm.get_worker_slots()
	assert_not_null(slots, "Farm should have worker slots")

	# Add worker - this should trigger production_started
	slots.add_worker(animal)

	# Building's _on_worker_added should emit production_started on first worker
	assert_signal_emitted(EventBus, "production_started", "production_started should be emitted when first worker added")

	farm.queue_free()
	animal.queue_free()

# =============================================================================
# AC5: PRODUCTION_COMPLETED SIGNAL
# =============================================================================

func test_production_completed_signal_emitted() -> void:
	var gatherer := GathererComponent.new()
	add_child(gatherer)
	await wait_frames(1)
	gatherer.initialize(null, "wheat", 0.2)  # Short time for test

	# Create mock animal
	var mock_animal := _create_mock_animal("test_animal_5")
	add_child(mock_animal)
	await wait_frames(1)

	# Watch the signal
	watch_signals(gatherer)

	gatherer.start_worker(mock_animal)

	# Wait for production to complete
	await wait_for_signal(gatherer.worker_production_completed, 1.0)

	assert_signal_emitted(gatherer, "worker_production_completed", "Signal should be emitted on production")

	gatherer.queue_free()
	mock_animal.queue_free()


func test_production_adds_resource_to_storage() -> void:
	var gatherer := GathererComponent.new()
	add_child(gatherer)
	await wait_frames(1)
	gatherer.initialize(null, "wheat", 0.2)  # Short time for test

	# Create mock animal
	var mock_animal := _create_mock_animal("test_animal_6")
	add_child(mock_animal)
	await wait_frames(1)

	var initial_wheat := ResourceManager.get_resource_amount("wheat")

	gatherer.start_worker(mock_animal)

	# Wait for production
	await wait_for_signal(gatherer.worker_production_completed, 1.0)

	var final_wheat := ResourceManager.get_resource_amount("wheat")
	assert_gt(final_wheat, initial_wheat, "Production should add wheat to storage")

	gatherer.queue_free()
	mock_animal.queue_free()

# =============================================================================
# AC6: STORAGE FULL PAUSES PRODUCTION
# =============================================================================

func test_production_pauses_when_storage_full() -> void:
	var gatherer := GathererComponent.new()
	add_child(gatherer)
	await wait_frames(1)
	gatherer.initialize(null, "wheat", 0.2)  # Short time for test

	# Create mock animal
	var mock_animal := _create_mock_animal("test_animal_7")
	add_child(mock_animal)
	await wait_frames(1)

	# Fill storage to capacity (wheat max_stack_size is 500 per ResourceData)
	var storage_limit := ResourceManager.get_storage_limit("wheat")
	ResourceManager.add_resource("wheat", storage_limit)

	# Verify storage is full and gathering is paused
	assert_true(ResourceManager.is_gathering_paused("wheat"), "Gathering should be paused when storage full")

	gatherer.start_worker(mock_animal)

	# Wait for production cycle to complete and attempt production
	await wait_frames(20)  # ~0.33s at 60fps, enough for 0.2s production time

	# Worker should be paused due to storage full (AC6)
	assert_true(gatherer.is_worker_paused(mock_animal), "Worker should be paused when storage full")
	assert_eq(gatherer.get_paused_worker_count(), 1, "Should have 1 paused worker")

	gatherer.queue_free()
	mock_animal.queue_free()

# =============================================================================
# AC10: MULTIPLE WORKERS PRODUCE INDEPENDENTLY
# =============================================================================

func test_multiple_workers_have_independent_timers() -> void:
	var gatherer := GathererComponent.new()
	add_child(gatherer)
	await wait_frames(1)
	gatherer.initialize(null, "wheat", 1.0)

	# Create two mock animals
	var mock_animal1 := _create_mock_animal("worker_1")
	var mock_animal2 := _create_mock_animal("worker_2")
	add_child(mock_animal1)
	add_child(mock_animal2)
	await wait_frames(1)

	gatherer.start_worker(mock_animal1)
	assert_eq(gatherer.get_active_worker_count(), 1, "Should have 1 worker")  # Only first worker added

	# Wait a bit
	await wait_frames(15)

	# Add second worker later
	gatherer.start_worker(mock_animal2)
	assert_eq(gatherer.get_active_worker_count(), 2, "Should have 2 workers")

	# Check progress - second worker should be behind first
	var progress1 := gatherer.get_worker_progress(mock_animal1)
	var progress2 := gatherer.get_worker_progress(mock_animal2)

	assert_gt(progress1, progress2, "First worker should have more progress")

	gatherer.queue_free()
	mock_animal1.queue_free()
	mock_animal2.queue_free()

# =============================================================================
# AC13: NO PARTIAL PRODUCTION ON REMOVAL
# =============================================================================

func test_stopping_worker_produces_no_partial_resource() -> void:
	var gatherer := GathererComponent.new()
	add_child(gatherer)
	await wait_frames(1)
	gatherer.initialize(null, "wheat", 2.0)  # 2 second production

	# Create mock animal
	var mock_animal := _create_mock_animal("test_animal_8")
	add_child(mock_animal)
	await wait_frames(1)

	var initial_wheat := ResourceManager.get_resource_amount("wheat")

	gatherer.start_worker(mock_animal)

	# Wait for partial progress (not complete)
	await wait_frames(30)  # ~0.5 seconds

	# Stop worker before completion
	gatherer.stop_worker(mock_animal)

	var final_wheat := ResourceManager.get_resource_amount("wheat")
	assert_eq(final_wheat, initial_wheat, "No partial resource should be produced")

	gatherer.queue_free()
	mock_animal.queue_free()

# =============================================================================
# BUILDING SCENE COMPONENT TESTS
# =============================================================================

func test_farm_scene_has_gatherer_component() -> void:
	var farm_scene := load("res://scenes/entities/buildings/farm.tscn") as PackedScene
	assert_not_null(farm_scene, "Farm scene should load")

	var farm := farm_scene.instantiate()
	add_child(farm)
	await wait_frames(1)

	var gatherer := farm.get_node_or_null("GathererComponent")
	assert_not_null(gatherer, "Farm should have GathererComponent")

	farm.queue_free()


func test_sawmill_scene_has_gatherer_component() -> void:
	var sawmill_scene := load("res://scenes/entities/buildings/sawmill.tscn") as PackedScene
	assert_not_null(sawmill_scene, "Sawmill scene should load")

	var sawmill := sawmill_scene.instantiate()
	add_child(sawmill)
	await wait_frames(1)

	var gatherer := sawmill.get_node_or_null("GathererComponent")
	assert_not_null(gatherer, "Sawmill should have GathererComponent")

	sawmill.queue_free()

# =============================================================================
# BUILDING INTEGRATION TESTS
# =============================================================================

func test_building_is_gatherer_method() -> void:
	var farm_scene := load("res://scenes/entities/buildings/farm.tscn") as PackedScene
	var farm := farm_scene.instantiate()
	add_child(farm)
	await wait_frames(1)

	# Initialize building
	var hex := HexCoord.new(0, 0)
	farm.initialize(hex, farm_data)

	assert_true(farm.is_gatherer(), "Initialized farm should be a gatherer")

	farm.queue_free()


func test_building_get_gatherer_returns_component() -> void:
	var farm_scene := load("res://scenes/entities/buildings/farm.tscn") as PackedScene
	var farm := farm_scene.instantiate()
	add_child(farm)
	await wait_frames(1)

	# Initialize building
	var hex := HexCoord.new(0, 0)
	farm.initialize(hex, farm_data)

	var gatherer: Node = farm.get_gatherer()
	assert_not_null(gatherer, "Should return GathererComponent")
	assert_true(gatherer.has_method("start_worker"), "Should have GathererComponent methods")

	farm.queue_free()


func test_building_production_active_tracking() -> void:
	var farm_scene := load("res://scenes/entities/buildings/farm.tscn") as PackedScene
	var farm := farm_scene.instantiate()
	add_child(farm)
	await wait_frames(1)

	var hex := HexCoord.new(0, 0)
	farm.initialize(hex, farm_data)

	assert_false(farm.is_production_active(), "Production should not be active initially")

	farm.queue_free()

# =============================================================================
# ANIMAL BUILDING ASSIGNMENT TESTS
# =============================================================================

func test_animal_set_assigned_building() -> void:
	# Load actual animal scene
	var animal_scene := load("res://scenes/entities/animals/rabbit.tscn") as PackedScene
	if not animal_scene:
		pending("Animal scene not available for test")
		return

	var animal := animal_scene.instantiate()
	add_child(animal)
	await wait_frames(1)

	var mock_building := Node.new()
	add_child(mock_building)

	assert_false(animal.has_assigned_building(), "Should not have building initially")

	animal.set_assigned_building(mock_building)

	assert_true(animal.has_assigned_building(), "Should have building after assignment")
	assert_eq(animal.get_assigned_building(), mock_building, "Should return assigned building")

	animal.clear_assigned_building()

	assert_false(animal.has_assigned_building(), "Should not have building after clear")

	animal.queue_free()
	mock_building.queue_free()

# =============================================================================
# WORKING STATE TESTS
# =============================================================================

func test_working_state_exists() -> void:
	var state := WorkingState.new(null, null)
	assert_not_null(state, "WorkingState should be instantiable")
	assert_eq(state.get_state_name(), "WorkingState", "Should return correct state name")

# =============================================================================
# HELPER METHODS
# =============================================================================

## Create a minimal mock animal for testing.
func _create_mock_animal(animal_id: String) -> Node3D:
	var mock := Node3D.new()
	mock.set_meta("animal_id", animal_id)

	# Add get_animal_id method via script
	var script := GDScript.new()
	script.source_code = """
extends Node3D

func get_animal_id() -> String:
	return get_meta("animal_id", "unknown")
"""
	script.reload()
	mock.set_script(script)

	return mock
