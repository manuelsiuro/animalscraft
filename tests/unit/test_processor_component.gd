## Unit tests for ProcessorComponent.
## Tests recipe-based resource transformation for PROCESSOR buildings.
##
## Story: 4-4-implement-production-processing
extends GutTest

# Preload the ProcessorComponent script
const ProcessorComponentScript = preload("res://scripts/entities/buildings/components/processor_component.gd")

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _processor: Node  # ProcessorComponent
var _mock_building: Node
var _mock_animal: Node
var _initial_wheat: int = 0
var _initial_flour: int = 0
var _initial_bread: int = 0

# Signal tracking
var _production_completed_count: int = 0
var _production_started_count: int = 0
var _production_halted_count: int = 0
var _last_halted_reason: String = ""
var _worker_completed_count: int = 0
var _last_output_id: String = ""


func before_each() -> void:
	# Create processor component using preloaded script
	_processor = ProcessorComponentScript.new()
	add_child_autofree(_processor)

	# Create mock building
	_mock_building = Node.new()
	_mock_building.name = "MockBuilding"
	add_child_autofree(_mock_building)

	# Create mock animal with get_animal_id method
	_mock_animal = Node.new()
	_mock_animal.name = "MockAnimal"
	_mock_animal.set_meta("animal_id", "test_animal_1")
	add_child_autofree(_mock_animal)

	# Store initial resource amounts
	_initial_wheat = ResourceManager.get_resource_amount("wheat")
	_initial_flour = ResourceManager.get_resource_amount("flour")
	_initial_bread = ResourceManager.get_resource_amount("bread")

	# Reset signal counters
	_production_completed_count = 0
	_production_started_count = 0
	_production_halted_count = 0
	_last_halted_reason = ""
	_worker_completed_count = 0
	_last_output_id = ""

	# Connect to EventBus signals
	if is_instance_valid(EventBus):
		EventBus.production_completed.connect(_on_production_completed)
		EventBus.production_started.connect(_on_production_started)
		EventBus.production_halted.connect(_on_production_halted)

	# Connect to processor signal
	_processor.worker_production_completed.connect(_on_worker_production_completed)


func after_each() -> void:
	# Restore initial resource amounts
	_restore_resources()

	# Disconnect from EventBus signals
	if is_instance_valid(EventBus):
		if EventBus.production_completed.is_connected(_on_production_completed):
			EventBus.production_completed.disconnect(_on_production_completed)
		if EventBus.production_started.is_connected(_on_production_started):
			EventBus.production_started.disconnect(_on_production_started)
		if EventBus.production_halted.is_connected(_on_production_halted):
			EventBus.production_halted.disconnect(_on_production_halted)


func _restore_resources() -> void:
	# Clear and restore to initial state
	var current_wheat := ResourceManager.get_resource_amount("wheat")
	var current_flour := ResourceManager.get_resource_amount("flour")
	var current_bread := ResourceManager.get_resource_amount("bread")

	if current_wheat > _initial_wheat:
		ResourceManager.remove_resource("wheat", current_wheat - _initial_wheat)
	elif current_wheat < _initial_wheat:
		ResourceManager.add_resource("wheat", _initial_wheat - current_wheat)

	if current_flour > _initial_flour:
		ResourceManager.remove_resource("flour", current_flour - _initial_flour)
	elif current_flour < _initial_flour:
		ResourceManager.add_resource("flour", _initial_flour - current_flour)

	if current_bread > _initial_bread:
		ResourceManager.remove_resource("bread", current_bread - _initial_bread)
	elif current_bread < _initial_bread:
		ResourceManager.add_resource("bread", _initial_bread - current_bread)


func _on_production_completed(_building: Node, output_type: String) -> void:
	_production_completed_count += 1
	_last_output_id = output_type


func _on_production_started(_building: Node) -> void:
	_production_started_count += 1


func _on_production_halted(_building: Node, reason: String) -> void:
	_production_halted_count += 1
	_last_halted_reason = reason


func _on_worker_production_completed(_animal: Node, output_id: String) -> void:
	_worker_completed_count += 1
	_last_output_id = output_id


func _get_mock_animal_id() -> String:
	return _mock_animal.get_meta("animal_id", "unknown")


# =============================================================================
# TASK 1: CREATE PROCESSORCOMPONENT SCRIPT - INITIALIZATION TESTS
# =============================================================================

func test_processor_component_exists() -> void:
	# Verify ProcessorComponent class exists
	assert_not_null(_processor, "ProcessorComponent should be instantiable")


func test_processor_component_extends_node() -> void:
	# Verify it extends Node
	assert_true(_processor is Node, "ProcessorComponent should extend Node")


func test_initialize_with_valid_recipe_loads_recipe() -> void:
	# Task 1.8, 1.9: Initialize with valid recipe
	_processor.initialize(_mock_building, "wheat_to_flour")

	assert_true(_processor.is_initialized(), "Processor should be initialized")

	var recipe: RecipeData = _processor.get_recipe()
	assert_not_null(recipe, "Recipe should be loaded")
	assert_eq(recipe.recipe_id, "wheat_to_flour", "Recipe ID should match")


func test_initialize_with_invalid_recipe_logs_warning() -> void:
	# Task 1.8, 1.9: Initialize with invalid recipe
	_processor.initialize(_mock_building, "invalid_recipe_id")

	# Should still be initialized but with null recipe
	assert_false(_processor.is_initialized(), "Processor should not be initialized with invalid recipe")
	assert_null(_processor.get_recipe(), "Recipe should be null for invalid ID")


func test_initialize_twice_logs_warning() -> void:
	# Initialize once
	_processor.initialize(_mock_building, "wheat_to_flour")
	assert_true(_processor.is_initialized())

	# Initialize again - should warn but not crash
	_processor.initialize(_mock_building, "flour_to_bread")

	# Should keep first recipe
	var recipe: RecipeData = _processor.get_recipe()
	assert_eq(recipe.recipe_id, "wheat_to_flour", "Should keep first recipe")


func test_processor_has_required_properties() -> void:
	# Task 1.3-1.7: Verify required properties exist
	_processor.initialize(_mock_building, "wheat_to_flour")

	# These should not throw errors
	assert_true(_processor.is_initialized())
	assert_eq(_processor.get_active_worker_count(), 0)
	assert_not_null(_processor.get_recipe())


func test_processor_has_worker_production_completed_signal() -> void:
	# Task 1.10: Verify signal exists
	assert_true(_processor.has_signal("worker_production_completed"),
		"ProcessorComponent should have worker_production_completed signal")


func test_test_advance_timer_helper_exists() -> void:
	# Task 1.11: Test helper for fast testing
	_processor.initialize(_mock_building, "wheat_to_flour")

	# Add resources and start worker
	ResourceManager.add_resource("wheat", 10)
	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	var animal_id := _get_mock_animal_id()

	# Advance timer using test helper
	_processor._test_advance_timer(animal_id, 1.5)

	# Verify timer was advanced
	var progress: float = _processor.get_worker_progress(_mock_animal)
	assert_almost_eq(progress, 0.5, 0.1, "Progress should be ~50% after 1.5s of 3.0s")


# =============================================================================
# TASK 2: WORKER PRODUCTION LOGIC TESTS
# =============================================================================

func test_start_worker_with_sufficient_inputs_begins_production() -> void:
	# Task 2.1, 2.2: Start worker when can_craft() is true
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 10)

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	assert_eq(_processor.get_active_worker_count(), 1, "Should have 1 active worker")
	assert_false(_processor.is_worker_waiting(_mock_animal), "Worker should not be waiting")


func test_start_worker_with_insufficient_inputs_enters_waiting() -> void:
	# Task 2.2, 2.3: Start worker when can_craft() is false
	_processor.initialize(_mock_building, "wheat_to_flour")
	# No wheat added - can't craft

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	assert_true(_processor.is_worker_waiting(_mock_animal), "Worker should be waiting for inputs")


func test_stop_worker_removes_from_all_tracking() -> void:
	# Task 2.4: Stop worker with no partial production
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 10)

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	# Advance timer partially
	var animal_id := _get_mock_animal_id()
	_processor._test_advance_timer(animal_id, 1.5)
	await get_tree().process_frame

	# Stop worker mid-cycle
	_processor.stop_worker(_mock_animal)

	assert_eq(_processor.get_active_worker_count(), 0, "Should have no active workers")
	assert_eq(ResourceManager.get_resource_amount("wheat"), 10 + _initial_wheat,
		"No wheat should be consumed on partial stop")
	assert_eq(ResourceManager.get_resource_amount("flour"), _initial_flour,
		"No flour should be produced on partial stop")


func test_waiting_worker_starts_when_inputs_available() -> void:
	# Task 2.6: Check can_craft() for waiting workers
	_processor.initialize(_mock_building, "wheat_to_flour")

	# Start with no wheat - worker enters waiting
	_processor.start_worker(_mock_animal)
	await get_tree().process_frame
	assert_true(_processor.is_worker_waiting(_mock_animal))

	# Add wheat - worker should transition to producing
	ResourceManager.add_resource("wheat", 10)
	await get_tree().process_frame

	assert_false(_processor.is_worker_waiting(_mock_animal), "Worker should no longer be waiting")
	assert_eq(_processor.get_active_worker_count(), 1, "Worker should be actively producing")


# =============================================================================
# TASK 3: RESOURCE CONSUMPTION/PRODUCTION TESTS
# =============================================================================

func test_production_cycle_consumes_correct_inputs() -> void:
	# Task 3.1, 3.2: Consume inputs atomically
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 10)

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	# Fast-forward to completion
	var animal_id := _get_mock_animal_id()
	_processor._test_advance_timer(animal_id, 3.0)
	await get_tree().process_frame

	# Should consume 2 wheat (recipe requirement)
	assert_eq(ResourceManager.get_resource_amount("wheat"), 8 + _initial_wheat,
		"Should consume 2 wheat per cycle")


func test_production_cycle_produces_correct_outputs() -> void:
	# Task 3.3: Add outputs after consumption
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 10)

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	# Fast-forward to completion
	var animal_id := _get_mock_animal_id()
	_processor._test_advance_timer(animal_id, 3.0)
	await get_tree().process_frame

	# Should produce 1 flour
	assert_eq(ResourceManager.get_resource_amount("flour"), 1 + _initial_flour,
		"Should produce 1 flour per cycle")


func test_worker_production_completed_signal_emitted() -> void:
	# Task 3.4: Emit signal with output resource_id
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 10)

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	# Fast-forward to completion
	var animal_id := _get_mock_animal_id()
	_processor._test_advance_timer(animal_id, 3.0)
	await get_tree().process_frame

	assert_eq(_worker_completed_count, 1, "worker_production_completed should be emitted")
	assert_eq(_last_output_id, "flour", "Output ID should be 'flour'")


func test_timer_resets_for_next_cycle() -> void:
	# Task 3.5: Reset timer after production
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 20)  # Enough for multiple cycles

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	# Complete first cycle
	var animal_id := _get_mock_animal_id()
	_processor._test_advance_timer(animal_id, 3.0)
	await get_tree().process_frame

	# Progress should be near 0 for new cycle
	var progress: float = _processor.get_worker_progress(_mock_animal)
	assert_lt(progress, 0.2, "Timer should reset for next cycle")


func test_worker_enters_waiting_after_depleting_inputs() -> void:
	# Task 3.6: Check can_craft() after production
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 2)  # Only enough for 1 cycle

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	# Complete cycle - consumes all wheat
	var animal_id := _get_mock_animal_id()
	_processor._test_advance_timer(animal_id, 3.0)
	await get_tree().process_frame

	# Worker should now be waiting (no more wheat)
	assert_true(_processor.is_worker_waiting(_mock_animal),
		"Worker should enter waiting state after depleting inputs")


func test_wheat_to_flour_recipe_correct() -> void:
	# Task 9.8: Test wheat_to_flour recipe: 2 wheat → 1 flour in 3 seconds
	_processor.initialize(_mock_building, "wheat_to_flour")

	var recipe: RecipeData = _processor.get_recipe()
	assert_eq(recipe.production_time, 3.0, "Production time should be 3.0 seconds")
	assert_eq(recipe.inputs.size(), 1, "Should have 1 input")
	assert_eq(recipe.inputs[0]["resource_id"], "wheat", "Input should be wheat")
	assert_eq(recipe.inputs[0]["amount"], 2, "Should require 2 wheat")
	assert_eq(recipe.outputs.size(), 1, "Should have 1 output")
	assert_eq(recipe.outputs[0]["resource_id"], "flour", "Output should be flour")
	assert_eq(recipe.outputs[0]["amount"], 1, "Should produce 1 flour")


func test_flour_to_bread_recipe_correct() -> void:
	# Task 9.9: Test flour_to_bread recipe: 1 flour → 1 bread in 4 seconds
	_processor.initialize(_mock_building, "flour_to_bread")

	var recipe: RecipeData = _processor.get_recipe()
	assert_eq(recipe.production_time, 4.0, "Production time should be 4.0 seconds")
	assert_eq(recipe.inputs.size(), 1, "Should have 1 input")
	assert_eq(recipe.inputs[0]["resource_id"], "flour", "Input should be flour")
	assert_eq(recipe.inputs[0]["amount"], 1, "Should require 1 flour")
	assert_eq(recipe.outputs.size(), 1, "Should have 1 output")
	assert_eq(recipe.outputs[0]["resource_id"], "bread", "Output should be bread")
	assert_eq(recipe.outputs[0]["amount"], 1, "Should produce 1 bread")


func test_multiple_cycles_run_correctly() -> void:
	# Task 9.12: Multiple cycles in sequence
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 10)

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	var animal_id := _get_mock_animal_id()

	# Complete 3 cycles
	for i in range(3):
		_processor._test_advance_timer(animal_id, 3.0)
		await get_tree().process_frame

	# Should have consumed 6 wheat (2 per cycle × 3)
	assert_eq(ResourceManager.get_resource_amount("wheat"), 4 + _initial_wheat,
		"Should consume 6 wheat total")
	# Should have produced 3 flour
	assert_eq(ResourceManager.get_resource_amount("flour"), 3 + _initial_flour,
		"Should produce 3 flour total")
	assert_eq(_worker_completed_count, 3, "Should have 3 completion signals")


# =============================================================================
# TASK 6: QUERY METHODS TESTS
# =============================================================================

func test_get_worker_progress_returns_correct_value() -> void:
	# Task 6.1: Progress 0.0 to 1.0
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 10)

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	var animal_id := _get_mock_animal_id()
	_processor._test_advance_timer(animal_id, 1.5)  # 50% of 3.0s

	var progress: float = _processor.get_worker_progress(_mock_animal)
	assert_almost_eq(progress, 0.5, 0.1, "Progress should be ~50%")


func test_get_recipe_returns_loaded_recipe() -> void:
	# Task 6.2: get_recipe()
	_processor.initialize(_mock_building, "wheat_to_flour")

	var recipe: RecipeData = _processor.get_recipe()
	assert_not_null(recipe)
	assert_eq(recipe.recipe_id, "wheat_to_flour")


func test_get_input_requirements_returns_array() -> void:
	# Task 6.3: get_input_requirements()
	_processor.initialize(_mock_building, "wheat_to_flour")

	var inputs: Array[Dictionary] = _processor.get_input_requirements()
	assert_eq(inputs.size(), 1)
	assert_eq(inputs[0]["resource_id"], "wheat")
	assert_eq(inputs[0]["amount"], 2)


func test_get_output_types_returns_array() -> void:
	# Task 6.4: get_output_types()
	_processor.initialize(_mock_building, "wheat_to_flour")

	var outputs: Array[Dictionary] = _processor.get_output_types()
	assert_eq(outputs.size(), 1)
	assert_eq(outputs[0]["resource_id"], "flour")
	assert_eq(outputs[0]["amount"], 1)


func test_get_active_worker_count_correct() -> void:
	# Task 6.5: get_active_worker_count()
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 10)

	assert_eq(_processor.get_active_worker_count(), 0, "Should start with 0 workers")

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	assert_eq(_processor.get_active_worker_count(), 1, "Should have 1 active worker")

	_processor.stop_worker(_mock_animal)
	assert_eq(_processor.get_active_worker_count(), 0, "Should have 0 workers after stop")


func test_is_worker_waiting_correct() -> void:
	# Task 6.6: is_worker_waiting()
	_processor.initialize(_mock_building, "wheat_to_flour")

	# Start with no resources - should be waiting
	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	assert_true(_processor.is_worker_waiting(_mock_animal))

	# Add resources - should no longer be waiting
	ResourceManager.add_resource("wheat", 10)
	await get_tree().process_frame

	assert_false(_processor.is_worker_waiting(_mock_animal))


func test_is_initialized_correct() -> void:
	# Task 6.8: is_initialized()
	assert_false(_processor.is_initialized(), "Should not be initialized initially")

	_processor.initialize(_mock_building, "wheat_to_flour")

	assert_true(_processor.is_initialized(), "Should be initialized after init")


func test_get_production_time_correct() -> void:
	# Task 6.9: get_production_time()
	_processor.initialize(_mock_building, "wheat_to_flour")

	assert_eq(_processor.get_production_time(), 3.0, "Production time should be 3.0s")

	# Test with different recipe
	var processor2 := ProcessorComponent.new()
	add_child_autofree(processor2)
	processor2.initialize(_mock_building, "flour_to_bread")

	assert_eq(processor2.get_production_time(), 4.0, "Production time should be 4.0s")


# =============================================================================
# CLEANUP TESTS
# =============================================================================

func test_cleanup_clears_all_state() -> void:
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 10)

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	# Cleanup
	_processor.cleanup()

	assert_false(_processor.is_initialized(), "Should not be initialized after cleanup")
	assert_eq(_processor.get_active_worker_count(), 0, "Should have no workers after cleanup")


# =============================================================================
# TASK 4: STORAGE-FULL PAUSE BEHAVIOR TESTS
# =============================================================================

func test_production_pauses_when_storage_full() -> void:
	# Task 4.1: Check is_gathering_paused() before adding output
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 10)

	# Fill flour storage to max
	var max_flour := ResourceManager.get_storage_limit("flour")
	ResourceManager.add_resource("flour", max_flour)

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	# Complete a cycle - should pause
	var animal_id := _get_mock_animal_id()
	_processor._test_advance_timer(animal_id, 3.0)
	await get_tree().process_frame

	# Worker should be paused
	assert_true(_processor.is_worker_paused(_mock_animal), "Worker should be paused when storage full")
	assert_gt(_processor.get_paused_worker_count(), 0, "Should have paused workers")


func test_production_halted_signal_on_storage_full() -> void:
	# Task 4.2: Emit production_halted with "storage_full" reason
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 10)

	# Fill flour storage
	var max_flour := ResourceManager.get_storage_limit("flour")
	ResourceManager.add_resource("flour", max_flour)

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	# Complete a cycle
	var animal_id := _get_mock_animal_id()
	_processor._test_advance_timer(animal_id, 3.0)
	await get_tree().process_frame

	assert_eq(_last_halted_reason, "storage_full", "Halted reason should be 'storage_full'")


func test_paused_worker_resumes_when_storage_freed() -> void:
	# Task 4.3: Listen for resource_gathering_resumed signal
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 10)

	# Fill flour storage
	var max_flour := ResourceManager.get_storage_limit("flour")
	ResourceManager.add_resource("flour", max_flour)

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	# Complete a cycle - pauses
	var animal_id := _get_mock_animal_id()
	_processor._test_advance_timer(animal_id, 3.0)
	await get_tree().process_frame
	assert_true(_processor.is_worker_paused(_mock_animal))

	# Free up storage
	ResourceManager.remove_resource("flour", 5)
	await get_tree().process_frame

	# Worker should resume
	assert_false(_processor.is_worker_paused(_mock_animal), "Worker should resume when storage freed")


func test_get_paused_worker_count_correct() -> void:
	# Task 4.5: get_paused_worker_count() query method
	_processor.initialize(_mock_building, "wheat_to_flour")
	assert_eq(_processor.get_paused_worker_count(), 0, "Should start with 0 paused workers")


func test_get_waiting_worker_count_correct() -> void:
	# Task 4.6: get_waiting_worker_count() query method
	_processor.initialize(_mock_building, "wheat_to_flour")

	assert_eq(_processor.get_waiting_worker_count(), 0, "Should start with 0 waiting workers")

	# Start worker with no inputs - enters waiting
	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	assert_eq(_processor.get_waiting_worker_count(), 1, "Should have 1 waiting worker")


# =============================================================================
# TASK 5: EVENTBUS SIGNAL INTEGRATION TESTS
# =============================================================================

func test_production_started_signal_on_first_worker() -> void:
	# Task 5.1: production_started is emitted by BUILDING when first worker begins
	# ProcessorComponent tracks state internally, Building owns signal emission
	var mill_scene := preload("res://scenes/entities/buildings/mill.tscn")
	var mill_data := preload("res://resources/buildings/mill_data.tres") as BuildingData
	var rabbit_scene := preload("res://scenes/entities/animals/rabbit.tscn")

	var mill := mill_scene.instantiate()
	add_child_autofree(mill)
	mill.initialize(HexCoord.create(10, 10), mill_data)
	await get_tree().process_frame

	# Create real Animal for WorkerSlotComponent
	var rabbit_stats := preload("res://resources/animals/rabbit_stats.tres") as AnimalStats
	var rabbit: Animal = rabbit_scene.instantiate()
	add_child_autofree(rabbit)
	rabbit.initialize(HexCoord.create(10, 11), rabbit_stats)
	await get_tree().process_frame

	ResourceManager.add_resource("wheat", 10)

	# Assign worker via WorkerSlotComponent (triggers Building._on_worker_added)
	var worker_slots: WorkerSlotComponent = mill.get_worker_slots()
	worker_slots.add_worker(rabbit)
	await get_tree().process_frame

	assert_eq(_production_started_count, 1, "production_started should be emitted by Building on first worker")


func test_production_halted_on_no_inputs() -> void:
	# Task 5.2: Emit production_halted with "no_inputs" reason
	_processor.initialize(_mock_building, "wheat_to_flour")
	# No wheat - can't craft

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	assert_eq(_production_halted_count, 1, "production_halted should be emitted")
	assert_eq(_last_halted_reason, "no_inputs", "Reason should be 'no_inputs'")


func test_production_halted_on_last_worker_removed() -> void:
	# Task 5.3: production_halted("no_workers") is emitted by BUILDING when last worker removed
	# ProcessorComponent tracks state internally, Building owns signal emission
	var mill_scene := preload("res://scenes/entities/buildings/mill.tscn")
	var mill_data := preload("res://resources/buildings/mill_data.tres") as BuildingData
	var rabbit_scene := preload("res://scenes/entities/animals/rabbit.tscn")

	var mill := mill_scene.instantiate()
	add_child_autofree(mill)
	mill.initialize(HexCoord.create(11, 11), mill_data)
	await get_tree().process_frame

	# Create real Animal for WorkerSlotComponent
	var rabbit_stats := preload("res://resources/animals/rabbit_stats.tres") as AnimalStats
	var rabbit: Animal = rabbit_scene.instantiate()
	add_child_autofree(rabbit)
	rabbit.initialize(HexCoord.create(11, 12), rabbit_stats)
	await get_tree().process_frame

	ResourceManager.add_resource("wheat", 10)

	# Assign and remove worker via WorkerSlotComponent
	var worker_slots: WorkerSlotComponent = mill.get_worker_slots()
	worker_slots.add_worker(rabbit)
	await get_tree().process_frame

	worker_slots.remove_worker(rabbit)
	await get_tree().process_frame

	# Last halted signal should be "no_workers" from Building
	assert_eq(_last_halted_reason, "no_workers", "Last halted reason should be 'no_workers' from Building")


func test_production_completed_signal_emitted() -> void:
	# Task 5.4: Emit production_completed via EventBus
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 10)

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	var animal_id := _get_mock_animal_id()
	_processor._test_advance_timer(animal_id, 3.0)
	await get_tree().process_frame

	assert_eq(_production_completed_count, 1, "production_completed should be emitted")
	assert_eq(_last_output_id, "flour", "Output ID should be 'flour'")


# =============================================================================
# TASK 14: INTEGRATION TESTS - Building → ProcessorComponent Wiring
# =============================================================================

func test_building_detects_processor_type() -> void:
	# Verify Building.is_producer() works with PROCESSOR buildings
	var mill_data := preload("res://resources/buildings/mill_data.tres") as BuildingData
	assert_not_null(mill_data, "Mill data should exist")
	assert_true(mill_data.is_producer(), "Mill should be a producer (PROCESSOR type)")


func test_bakery_is_processor_type() -> void:
	# Verify Bakery is also a PROCESSOR type
	var bakery_data := preload("res://resources/buildings/bakery_data.tres") as BuildingData
	assert_not_null(bakery_data, "Bakery data should exist")
	assert_true(bakery_data.is_producer(), "Bakery should be a producer (PROCESSOR type)")


func test_mill_has_processor_component_in_scene() -> void:
	# Verify Mill scene has ProcessorComponent node
	var mill_scene := preload("res://scenes/entities/buildings/mill.tscn")
	var mill_instance := mill_scene.instantiate()
	add_child_autofree(mill_instance)

	var processor := mill_instance.get_node_or_null("ProcessorComponent")
	assert_not_null(processor, "Mill should have ProcessorComponent child node")


func test_bakery_has_processor_component_in_scene() -> void:
	# Verify Bakery scene has ProcessorComponent node
	var bakery_scene := preload("res://scenes/entities/buildings/bakery.tscn")
	var bakery_instance := bakery_scene.instantiate()
	add_child_autofree(bakery_instance)

	var processor := bakery_instance.get_node_or_null("ProcessorComponent")
	assert_not_null(processor, "Bakery should have ProcessorComponent child node")


func test_mill_get_processor_returns_valid_component() -> void:
	# Verify Building.get_processor() works after initialization
	var mill_scene := preload("res://scenes/entities/buildings/mill.tscn")
	var mill_data := preload("res://resources/buildings/mill_data.tres") as BuildingData
	var mill := mill_scene.instantiate()
	add_child_autofree(mill)

	# Initialize the building
	mill.initialize(HexCoord.create(0, 0), mill_data)
	await get_tree().process_frame

	# get_processor() should return valid ProcessorComponent
	var processor: Node = mill.get_processor()
	assert_not_null(processor, "Mill.get_processor() should return ProcessorComponent")
	assert_true(processor.is_initialized(), "ProcessorComponent should be initialized")


func test_mill_is_processor_returns_true() -> void:
	# Verify Building.is_processor() returns true for Mill
	var mill_scene := preload("res://scenes/entities/buildings/mill.tscn")
	var mill_data := preload("res://resources/buildings/mill_data.tres") as BuildingData
	var mill := mill_scene.instantiate()
	add_child_autofree(mill)

	# Before initialization
	assert_false(mill.is_processor(), "is_processor() should be false before init")

	# Initialize the building
	mill.initialize(HexCoord.create(0, 0), mill_data)
	await get_tree().process_frame

	# After initialization
	assert_true(mill.is_processor(), "is_processor() should be true after init")


func test_bakery_get_processor_returns_valid_component() -> void:
	# Verify Building.get_processor() works for Bakery
	var bakery_scene := preload("res://scenes/entities/buildings/bakery.tscn")
	var bakery_data := preload("res://resources/buildings/bakery_data.tres") as BuildingData
	var bakery := bakery_scene.instantiate()
	add_child_autofree(bakery)

	# Initialize the building
	bakery.initialize(HexCoord.create(1, 1), bakery_data)
	await get_tree().process_frame

	# get_processor() should return valid ProcessorComponent
	var processor: Node = bakery.get_processor()
	assert_not_null(processor, "Bakery.get_processor() should return ProcessorComponent")
	assert_true(processor.is_initialized(), "ProcessorComponent should be initialized")

	# Verify recipe is correct
	var recipe: RecipeData = processor.get_recipe()
	assert_eq(recipe.recipe_id, "flour_to_bread", "Bakery should use flour_to_bread recipe")


func test_processor_get_recipe_via_building() -> void:
	# Full integration: Building → ProcessorComponent → RecipeData
	var mill_scene := preload("res://scenes/entities/buildings/mill.tscn")
	var mill_data := preload("res://resources/buildings/mill_data.tres") as BuildingData
	var mill := mill_scene.instantiate()
	add_child_autofree(mill)

	mill.initialize(HexCoord.create(2, 2), mill_data)
	await get_tree().process_frame

	var processor: Node = mill.get_processor()
	var recipe: RecipeData = processor.get_recipe()

	assert_eq(recipe.recipe_id, "wheat_to_flour", "Mill should use wheat_to_flour recipe")
	assert_eq(recipe.production_time, 3.0, "Production time should be 3.0s")


# =============================================================================
# BUILDINGFACTORY INTEGRATION TESTS
# =============================================================================

func test_building_factory_creates_mill_with_processor() -> void:
	# Test Mill creation via BuildingFactory
	var hex := HexCoord.create(5, 5)

	# Mark hex as unoccupied for test
	HexGrid.mark_hex_unoccupied(hex.to_vector())

	var mill := BuildingFactory.create_building("mill", hex)
	assert_not_null(mill, "BuildingFactory should create Mill")
	add_child_autofree(mill)
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for deferred initialize

	# Verify processor component is initialized
	assert_true(mill.is_processor(), "Factory-created Mill should be a processor")
	var processor: Node = mill.get_processor()
	assert_not_null(processor, "Mill should have ProcessorComponent")
	assert_true(processor.is_initialized(), "ProcessorComponent should be initialized")


func test_building_factory_creates_bakery_with_processor() -> void:
	# Test Bakery creation via BuildingFactory
	var hex := HexCoord.create(6, 6)

	# Mark hex as unoccupied for test
	HexGrid.mark_hex_unoccupied(hex.to_vector())

	var bakery := BuildingFactory.create_building("bakery", hex)
	assert_not_null(bakery, "BuildingFactory should create Bakery")
	add_child_autofree(bakery)
	await get_tree().process_frame
	await get_tree().process_frame  # Extra frame for deferred initialize

	# Verify processor component is initialized
	assert_true(bakery.is_processor(), "Factory-created Bakery should be a processor")
	var processor: Node = bakery.get_processor()
	assert_not_null(processor, "Bakery should have ProcessorComponent")

	# Verify recipe
	var recipe: RecipeData = processor.get_recipe()
	assert_eq(recipe.recipe_id, "flour_to_bread", "Bakery should use flour_to_bread recipe")


func test_factory_mill_produces_flour() -> void:
	# Full production test via BuildingFactory
	var hex := HexCoord.create(7, 7)
	HexGrid.mark_hex_unoccupied(hex.to_vector())

	var mill := BuildingFactory.create_building("mill", hex)
	add_child_autofree(mill)
	await get_tree().process_frame
	await get_tree().process_frame

	# Add resources
	ResourceManager.add_resource("wheat", 10)

	# Get processor and start production
	var processor: Node = mill.get_processor()
	processor.start_worker(_mock_animal)
	await get_tree().process_frame

	# Advance to completion
	var animal_id := _get_mock_animal_id()
	processor._test_advance_timer(animal_id, 3.0)
	await get_tree().process_frame

	# Verify production
	assert_eq(ResourceManager.get_resource_amount("flour") - _initial_flour, 1,
		"Factory Mill should produce 1 flour")
	assert_eq(ResourceManager.get_resource_amount("wheat") - _initial_wheat, 8,
		"Factory Mill should consume 2 wheat (10 - 2 = 8)")


# =============================================================================
# TASK 15: EDGE CASE TESTS
# =============================================================================

func test_simultaneous_consumption_race_condition() -> void:
	# Edge case: Two processors trying to consume from same limited pool
	var processor2 := ProcessorComponentScript.new()
	add_child_autofree(processor2)

	_processor.initialize(_mock_building, "wheat_to_flour")
	processor2.initialize(_mock_building, "wheat_to_flour")

	# Clear all wheat first to ensure clean state
	var current_wheat := ResourceManager.get_resource_amount("wheat")
	if current_wheat > 0:
		ResourceManager.remove_resource("wheat", current_wheat)

	# Only enough wheat for ONE production cycle (exactly 2)
	ResourceManager.add_resource("wheat", 2)

	var animal2 := Node.new()
	animal2.set_meta("animal_id", "test_animal_2")
	add_child_autofree(animal2)

	# First processor starts - has enough resources
	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	# Second processor starts - also sees enough resources (not consumed yet)
	processor2.start_worker(animal2)
	await get_tree().process_frame

	# Both try to complete simultaneously
	_processor._test_advance_timer(_get_mock_animal_id(), 3.0)
	processor2._test_advance_timer("test_animal_2", 3.0)
	await get_tree().process_frame

	# Only ONE should produce (race condition handling - atomic consumption)
	var flour_produced := ResourceManager.get_resource_amount("flour") - _initial_flour
	assert_eq(flour_produced, 1, "Only one processor should produce when resources are limited")

	# BOTH workers should be waiting now:
	# - Winner: produced flour, then can_craft fails (no wheat) → waiting
	# - Loser: couldn't consume wheat (already consumed by winner) → waiting
	var waiting_count := 0
	if _processor.is_worker_waiting(_mock_animal):
		waiting_count += 1
	if processor2.is_worker_waiting(animal2):
		waiting_count += 1
	assert_eq(waiting_count, 2, "Both workers should be waiting after race (no wheat left)")


func test_worker_reassignment_mid_cycle() -> void:
	# Edge case: Worker removed and re-added mid-cycle
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 10)

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	# Advance timer to 50%
	var animal_id := _get_mock_animal_id()
	_processor._test_advance_timer(animal_id, 1.5)
	await get_tree().process_frame

	# Remove worker mid-cycle
	_processor.stop_worker(_mock_animal)

	# Re-add immediately
	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	# Timer should reset to 0 (no partial progress)
	var progress: float = _processor.get_worker_progress(_mock_animal)
	assert_lt(progress, 0.1, "Progress should reset when worker is reassigned")


func test_chain_starvation() -> void:
	# Edge case: Chain starvation - upstream stops, downstream starves
	var upstream := _processor  # wheat_to_flour
	upstream.initialize(_mock_building, "wheat_to_flour")

	var downstream := ProcessorComponentScript.new()
	add_child_autofree(downstream)
	downstream.initialize(_mock_building, "flour_to_bread")

	var downstream_animal := Node.new()
	downstream_animal.set_meta("animal_id", "downstream_worker")
	add_child_autofree(downstream_animal)

	# Clear resources first for clean state
	var current_wheat := ResourceManager.get_resource_amount("wheat")
	var current_flour := ResourceManager.get_resource_amount("flour")
	if current_wheat > 0:
		ResourceManager.remove_resource("wheat", current_wheat)
	if current_flour > 0:
		ResourceManager.remove_resource("flour", current_flour)

	# Only a little wheat - upstream will deplete quickly (exactly 2)
	ResourceManager.add_resource("wheat", 2)

	# Start upstream first (has wheat, can produce)
	upstream.start_worker(_mock_animal)
	await get_tree().process_frame
	assert_false(upstream.is_worker_waiting(_mock_animal), "Upstream should start producing")

	# Start downstream (no flour yet, will wait)
	downstream.start_worker(downstream_animal)
	await get_tree().process_frame
	assert_true(downstream.is_worker_waiting(downstream_animal), "Downstream should wait for flour")

	# Upstream produces once
	upstream._test_advance_timer(_get_mock_animal_id(), 3.0)
	await get_tree().process_frame

	# Now upstream waiting (no more wheat), should have 1 flour
	assert_true(upstream.is_worker_waiting(_mock_animal), "Upstream should be waiting (no wheat)")
	assert_eq(ResourceManager.get_resource_amount("flour"), 1, "Should have 1 flour")

	# Downstream should now transition from waiting to producing
	await get_tree().process_frame
	assert_false(downstream.is_worker_waiting(downstream_animal), "Downstream should start producing")

	# Downstream completes - consumes the flour
	downstream._test_advance_timer("downstream_worker", 4.0)
	await get_tree().process_frame

	# Now downstream is starved too (no more flour)
	assert_true(downstream.is_worker_waiting(downstream_animal), "Downstream should be waiting (no flour)")
	assert_eq(ResourceManager.get_resource_amount("bread"), 1, "Should have 1 bread")


func test_multiple_workers_independent_timers() -> void:
	# Edge case: Two workers have independent progress
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 20)

	var animal2 := Node.new()
	animal2.set_meta("animal_id", "worker_2")
	add_child_autofree(animal2)

	_processor.start_worker(_mock_animal)
	_processor.start_worker(animal2)
	await get_tree().process_frame

	# Advance first worker only
	_processor._test_advance_timer(_get_mock_animal_id(), 1.5)
	await get_tree().process_frame

	var progress1: float = _processor.get_worker_progress(_mock_animal)
	var progress2: float = _processor.get_worker_progress(animal2)

	assert_almost_eq(progress1, 0.5, 0.1, "Worker 1 should be at 50%")
	assert_lt(progress2, 0.1, "Worker 2 should be near 0%")


func test_invalid_animal_handling() -> void:
	# Edge case: Invalid/null animal passed to methods
	_processor.initialize(_mock_building, "wheat_to_flour")

	# These should not crash
	_processor.start_worker(null)
	_processor.stop_worker(null)

	assert_eq(_processor.get_worker_progress(null), -1.0, "Invalid animal progress should be -1.0")
	assert_false(_processor.is_worker_waiting(null), "Invalid animal should not be waiting")
	assert_false(_processor.is_worker_paused(null), "Invalid animal should not be paused")


func test_uninitialized_processor_handling() -> void:
	# Edge case: Methods called before initialization
	# These should not crash
	var new_processor := ProcessorComponentScript.new()
	add_child_autofree(new_processor)

	new_processor.start_worker(_mock_animal)
	new_processor.stop_worker(_mock_animal)

	assert_eq(new_processor.get_active_worker_count(), 0)
	assert_null(new_processor.get_recipe())
	assert_eq(new_processor.get_production_time(), 0.0)


func test_production_time_carry_over() -> void:
	# Edge case: Timer carry-over to prevent drift
	_processor.initialize(_mock_building, "wheat_to_flour")
	ResourceManager.add_resource("wheat", 20)

	_processor.start_worker(_mock_animal)
	await get_tree().process_frame

	var animal_id := _get_mock_animal_id()

	# Advance by more than production_time
	_processor._test_advance_timer(animal_id, 3.5)  # 0.5s extra
	await get_tree().process_frame

	# Progress should carry over the excess
	var progress: float = _processor.get_worker_progress(_mock_animal)
	assert_almost_eq(progress, 0.167, 0.05, "Excess time should carry over (~0.5/3.0)")


func test_get_input_output_returns_copies() -> void:
	# Ensure returned arrays are copies (not references)
	_processor.initialize(_mock_building, "wheat_to_flour")

	var inputs1: Array[Dictionary] = _processor.get_input_requirements()
	var inputs2: Array[Dictionary] = _processor.get_input_requirements()

	# Modify first array
	inputs1[0]["amount"] = 999

	# Second should be unchanged
	assert_eq(inputs2[0]["amount"], 2, "Returned arrays should be independent copies")
