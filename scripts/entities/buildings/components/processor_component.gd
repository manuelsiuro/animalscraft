## ProcessorComponent - Handles recipe-based resource transformation.
## Consumes inputs and produces outputs when workers are assigned.
## Each worker has independent production timers.
##
## Architecture: scripts/entities/buildings/components/processor_component.gd
## Story: 4-4-implement-production-processing
class_name ProcessorComponent
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a worker completes a production cycle.
## @param animal The Animal node that produced (or null)
## @param output_id The resource type produced
signal worker_production_completed(animal: Node, output_id: String)

# =============================================================================
# PROPERTIES
# =============================================================================

## Loaded recipe data for this processor
var _recipe: RecipeData = null

## Reference to parent building for data access
var _building: Node = null

## Whether component has been initialized
var _initialized: bool = false

## Active production timers per worker (animal_id → accumulated_time)
var _worker_timers: Dictionary = {}

## Workers currently paused due to storage full
var _paused_workers: Dictionary = {}

## Workers waiting for input resources
var _waiting_for_inputs: Dictionary = {}

## Mapping of animal_id to Node reference for signal emission
var _worker_references: Dictionary = {}

## NOTE: Production activity signals (production_started, production_halted) are emitted by
## Building.gd, not ProcessorComponent. This avoids duplicate state tracking.

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Connect to gathering resumed signal to restart paused production
	if is_instance_valid(EventBus):
		EventBus.resource_gathering_resumed.connect(_on_gathering_resumed)


func _exit_tree() -> void:
	# Safely disconnect from EventBus
	if is_instance_valid(EventBus):
		if EventBus.resource_gathering_resumed.is_connected(_on_gathering_resumed):
			EventBus.resource_gathering_resumed.disconnect(_on_gathering_resumed)


## Initialize the processor component with configuration.
## @param building The parent Building node
## @param recipe_id The recipe this processor uses (e.g., "wheat_to_flour")
func initialize(building: Node, recipe_id: String) -> void:
	if _initialized:
		GameLogger.warn("ProcessorComponent", "Already initialized")
		return

	_building = building

	# Load recipe from RecipeManager
	if not is_instance_valid(RecipeManager):
		GameLogger.error("ProcessorComponent", "RecipeManager not available")
		return

	_recipe = RecipeManager.get_recipe(recipe_id)
	if _recipe == null:
		GameLogger.warn("ProcessorComponent", "Recipe not found: %s" % recipe_id)
		return

	_initialized = true
	GameLogger.debug("ProcessorComponent", "Initialized: recipe=%s, time=%.1fs" % [recipe_id, _recipe.production_time])


func _process(delta: float) -> void:
	if not _initialized:
		return

	# Fast path: no workers at all
	if _worker_timers.is_empty() and _waiting_for_inputs.is_empty():
		return

	# Check waiting workers - they might be able to start now
	_check_waiting_workers()

	# Update timers for active workers
	_update_worker_timers(delta)


## Check waiting workers and transition to producing if inputs available (AC4: start immediately)
func _check_waiting_workers() -> void:
	if _waiting_for_inputs.is_empty():
		return

	# Transition ALL waiting workers that can start while resources available (AC4 fix)
	# Use while loop to process multiple workers in same frame
	while not _waiting_for_inputs.is_empty() and RecipeManager.can_craft(_recipe.recipe_id):
		var waiting_ids: Array = _waiting_for_inputs.keys()
		var animal_id: String = waiting_ids[0]
		_waiting_for_inputs.erase(animal_id)
		_worker_timers[animal_id] = 0.0
		GameLogger.debug("ProcessorComponent", "Worker %s starting - inputs now available" % animal_id)

	# Note: Building.gd emits production_started when worker is added


## Update timers for all active workers
func _update_worker_timers(delta: float) -> void:
	for animal_id: String in _worker_timers.keys():
		# Skip paused workers (storage full)
		if _paused_workers.has(animal_id):
			continue

		_worker_timers[animal_id] += delta

		# Check if production cycle complete
		if _worker_timers[animal_id] >= _recipe.production_time:
			# Only decrement timer if production actually succeeded (AC6 fix)
			if _complete_production(animal_id):
				# Check key still exists (worker may have transitioned to waiting state)
				if _worker_timers.has(animal_id):
					_worker_timers[animal_id] -= _recipe.production_time  # Carry over excess

# =============================================================================
# WORKER MANAGEMENT
# =============================================================================

## Start production timer for a worker.
## Called when an animal is assigned to this building.
## If inputs unavailable, worker enters waiting state.
## @param animal The Animal node that started working
func start_worker(animal: Node) -> void:
	if not is_instance_valid(animal):
		GameLogger.warn("ProcessorComponent", "start_worker called with invalid animal")
		return

	if not _initialized:
		GameLogger.warn("ProcessorComponent", "Cannot start worker: not initialized")
		return

	var animal_id := _get_animal_id(animal)

	# Store reference
	_worker_references[animal_id] = animal

	# Clear any previous paused/waiting state
	_paused_workers.erase(animal_id)
	_waiting_for_inputs.erase(animal_id)

	# Check if we can start production (have inputs)
	if RecipeManager.can_craft(_recipe.recipe_id):
		# Start production timer
		_worker_timers[animal_id] = 0.0
		GameLogger.debug("ProcessorComponent", "Worker %s started production for %s" % [animal_id, _recipe.recipe_id])
		# Note: Building.gd emits production_started signal
	else:
		# Enter waiting state
		_waiting_for_inputs[animal_id] = true
		GameLogger.debug("ProcessorComponent", "Worker %s waiting for inputs" % animal_id)

		# Emit production_halted with "no_inputs" reason
		if is_instance_valid(EventBus) and is_instance_valid(_building):
			EventBus.production_halted.emit(_building, "no_inputs")


## Stop production timer for a worker.
## Called when an animal is removed from this building.
## Note: No resource is consumed or produced for partial cycles (AC7).
## @param animal The Animal node that stopped working
func stop_worker(animal: Node) -> void:
	if not is_instance_valid(animal):
		return

	var animal_id := _get_animal_id(animal)

	# Remove from all tracking - no partial production (AC7)
	_worker_timers.erase(animal_id)
	_paused_workers.erase(animal_id)
	_waiting_for_inputs.erase(animal_id)
	_worker_references.erase(animal_id)

	GameLogger.debug("ProcessorComponent", "Worker %s stopped production (no partial resource)" % animal_id)

	# Note: Building.gd emits production_halted("no_workers") when last worker is removed

# =============================================================================
# PRODUCTION
# =============================================================================

## Complete a production cycle for a worker.
## Consumes inputs atomically and produces outputs.
## @param animal_id The ID of the animal that completed production
## @return true if production succeeded, false if blocked (storage full, race condition)
func _complete_production(animal_id: String) -> bool:
	# Check if output storage is full (any output resource)
	for output in _recipe.outputs:
		var resource_id: String = output.get("resource_id", "")
		if ResourceManager.is_gathering_paused(resource_id):
			_paused_workers[animal_id] = true
			GameLogger.debug("ProcessorComponent", "Production paused for %s - %s storage full" % [animal_id, resource_id])
			if is_instance_valid(EventBus) and is_instance_valid(_building):
				EventBus.production_halted.emit(_building, "storage_full")
			return false  # Production blocked - don't decrement timer (AC6)

	# Consume ALL inputs atomically (all-or-nothing)
	for input in _recipe.inputs:
		var resource_id: String = input.get("resource_id", "")
		var amount: int = input.get("amount", 0)
		var success := ResourceManager.remove_resource(resource_id, amount)
		if not success:
			# Race condition: another processor consumed first
			_waiting_for_inputs[animal_id] = true
			_worker_timers.erase(animal_id)
			GameLogger.debug("ProcessorComponent", "Input consumed by another - entering wait state")
			if is_instance_valid(EventBus) and is_instance_valid(_building):
				EventBus.production_halted.emit(_building, "no_inputs")
			return false  # Production blocked

	# Produce ALL outputs
	for output in _recipe.outputs:
		var resource_id: String = output.get("resource_id", "")
		var amount: int = output.get("amount", 0)
		ResourceManager.add_resource(resource_id, amount)

		# Emit EventBus signal
		if is_instance_valid(EventBus) and is_instance_valid(_building):
			EventBus.production_completed.emit(_building, resource_id)

		# Emit local signal with animal reference
		var animal: Node = _worker_references.get(animal_id)
		worker_production_completed.emit(animal, resource_id)

		GameLogger.debug("ProcessorComponent", "Worker %s produced %d %s" % [animal_id, amount, resource_id])

	# Check if can continue for next cycle
	if not RecipeManager.can_craft(_recipe.recipe_id):
		# Enter waiting state
		_waiting_for_inputs[animal_id] = true
		_worker_timers.erase(animal_id)
		GameLogger.debug("ProcessorComponent", "Worker %s waiting for inputs after production" % animal_id)
		# Emit production_halted for input depletion (AC10 fix)
		if is_instance_valid(EventBus) and is_instance_valid(_building):
			EventBus.production_halted.emit(_building, "no_inputs")

	return true  # Production succeeded


## Handle gathering resumed signal from ResourceManager.
## Clears pause state but does NOT reset timers.
## @param resource_id The resource type that can be gathered again
func _on_gathering_resumed(resource_id: String) -> void:
	if not _initialized or _recipe == null:
		return

	# Check if this resource is one of our outputs
	var is_our_output := false
	for output in _recipe.outputs:
		if output.get("resource_id", "") == resource_id:
			is_our_output = true
			break

	if not is_our_output:
		return

	# Clear pause flags for workers that were paused for this resource
	var resumed_count := _paused_workers.size()
	_paused_workers.clear()

	if resumed_count > 0:
		GameLogger.debug("ProcessorComponent", "Production resumed for %d workers producing %s" % [resumed_count, resource_id])

# =============================================================================
# QUERY METHODS
# =============================================================================

## Get current number of active workers (producing or waiting).
## @return Number of workers in production or waiting state
func get_active_worker_count() -> int:
	return _worker_timers.size() + _waiting_for_inputs.size()


## Check if component is initialized.
## @return true if initialize() has been called successfully
func is_initialized() -> bool:
	return _initialized


## Get the loaded recipe.
## @return RecipeData or null if not initialized
func get_recipe() -> RecipeData:
	return _recipe


## Get production time per cycle from recipe.
## @return Time in seconds for one production cycle
func get_production_time() -> float:
	if _recipe:
		return _recipe.production_time
	return 0.0


## Get production progress for a specific worker (0.0 to 1.0).
## @param animal The Animal to check
## @return Progress ratio, or -1.0 if worker not found
func get_worker_progress(animal: Node) -> float:
	if not is_instance_valid(animal):
		return -1.0

	var animal_id := _get_animal_id(animal)
	if not _worker_timers.has(animal_id):
		return -1.0

	if _recipe == null or _recipe.production_time <= 0:
		return 0.0

	return clampf(_worker_timers[animal_id] / _recipe.production_time, 0.0, 1.0)


## Check if a specific worker is waiting for inputs.
## @param animal The Animal to check
## @return true if worker is waiting for inputs
func is_worker_waiting(animal: Node) -> bool:
	if not is_instance_valid(animal):
		return false
	return _waiting_for_inputs.has(_get_animal_id(animal))


## Check if a specific worker is paused (storage full).
## @param animal The Animal to check
## @return true if worker is paused due to storage full
func is_worker_paused(animal: Node) -> bool:
	if not is_instance_valid(animal):
		return false
	return _paused_workers.has(_get_animal_id(animal))


## Get input requirements from recipe.
## @return Array of input dictionaries with resource_id and amount
func get_input_requirements() -> Array[Dictionary]:
	if _recipe == null:
		return []
	var result: Array[Dictionary] = []
	for input in _recipe.inputs:
		result.append(input.duplicate())
	return result


## Get output types from recipe.
## @return Array of output dictionaries with resource_id and amount
func get_output_types() -> Array[Dictionary]:
	if _recipe == null:
		return []
	var result: Array[Dictionary] = []
	for output in _recipe.outputs:
		result.append(output.duplicate())
	return result


## Get number of paused workers (storage full).
## @return Number of workers currently paused
func get_paused_worker_count() -> int:
	return _paused_workers.size()


## Get number of waiting workers (no inputs).
## @return Number of workers waiting for inputs
func get_waiting_worker_count() -> int:
	return _waiting_for_inputs.size()

# =============================================================================
# UTILITY
# =============================================================================

## Get unique identifier for an animal.
## @param animal The Animal node (or any Node with get_animal_id method)
## @return String identifier
func _get_animal_id(animal: Node) -> String:
	if animal.has_method("get_animal_id"):
		return animal.get_animal_id()
	# Fallback: check for meta
	if animal.has_meta("animal_id"):
		return animal.get_meta("animal_id")
	return str(animal.get_instance_id())


## TEST ONLY: Advance worker timer for fast testing. Not for production use.
## @param animal_id The animal ID to advance timer for
## @param time The time in seconds to advance
func _test_advance_timer(animal_id: String, time: float) -> void:
	if _worker_timers.has(animal_id):
		_worker_timers[animal_id] += time

# =============================================================================
# CLEANUP
# =============================================================================

## Clean up component state.
## Called during building cleanup.
func cleanup() -> void:
	_worker_timers.clear()
	_paused_workers.clear()
	_waiting_for_inputs.clear()
	_worker_references.clear()
	_building = null
	_recipe = null
	_initialized = false
