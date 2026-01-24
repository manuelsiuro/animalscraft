## GathererComponent - Handles periodic resource production for gatherer buildings.
## Produces output resource at fixed intervals when workers are assigned.
## Each worker has independent production timers.
##
## Architecture: scripts/entities/buildings/components/gatherer_component.gd
## Story: 3-8-implement-resource-gathering
class_name GathererComponent
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a worker completes a production cycle.
## @param animal The Animal node that produced (or null)
## @param resource_id The resource type produced
signal worker_production_completed(animal: Node, resource_id: String)

# =============================================================================
# PROPERTIES
# =============================================================================

## Output resource type produced by this building
var _output_resource_id: String = ""

## Time in seconds for one production cycle
var _production_time: float = 5.0

## Active production timers per worker (animal_id → accumulated_time)
var _worker_timers: Dictionary = {}

## Workers currently paused due to storage full
var _paused_workers: Dictionary = {}

## Mapping of animal_id to Node reference for signal emission
var _worker_references: Dictionary = {}

## Reference to parent building for data access
var _building: Node = null

## Whether component has been initialized
var _initialized: bool = false

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


## Initialize the gatherer component with configuration.
## @param building The parent Building node
## @param output_resource_id The resource type this building produces (e.g., "wheat", "wood")
## @param production_time The time in seconds for one production cycle
func initialize(building: Node, output_resource_id: String, production_time: float) -> void:
	if _initialized:
		GameLogger.warn("GathererComponent", "Already initialized")
		return

	_building = building
	_output_resource_id = output_resource_id
	_production_time = maxf(0.1, production_time)  # Minimum 0.1 seconds to avoid infinite loops
	_initialized = true

	GameLogger.debug("GathererComponent", "Initialized: output=%s, time=%.1fs" % [output_resource_id, production_time])


func _process(delta: float) -> void:
	if not _initialized:
		return

	if _worker_timers.is_empty():
		return

	# Get effective production time (with School efficiency bonus - Story 6-8)
	var effective_time := _get_effective_production_time()

	# Update timers for all active workers
	for animal_id: String in _worker_timers.keys():
		# Skip paused workers (storage full)
		if _paused_workers.has(animal_id):
			continue

		_worker_timers[animal_id] += delta

		# Check if production cycle complete (using effective time)
		if _worker_timers[animal_id] >= effective_time:
			_worker_timers[animal_id] -= effective_time  # Carry over excess to prevent drift
			_produce_resource(animal_id)

# =============================================================================
# WORKER MANAGEMENT
# =============================================================================

## Start production timer for a worker.
## Called when an animal is assigned to this building.
## @param animal The Animal node that started working
func start_worker(animal: Node) -> void:
	if not is_instance_valid(animal):
		GameLogger.warn("GathererComponent", "start_worker called with invalid animal")
		return

	if not _initialized:
		GameLogger.warn("GathererComponent", "Cannot start worker: not initialized")
		return

	var animal_id := _get_animal_id(animal)

	# Initialize timer at 0 (fresh start)
	_worker_timers[animal_id] = 0.0
	_worker_references[animal_id] = animal

	# Clear any previous paused state
	_paused_workers.erase(animal_id)

	GameLogger.debug("GathererComponent", "Worker %s started production for %s" % [animal_id, _output_resource_id])


## Stop production timer for a worker.
## Called when an animal is removed from this building.
## Note: No resource is produced for partial cycles (AC13).
## @param animal The Animal node that stopped working
func stop_worker(animal: Node) -> void:
	if not is_instance_valid(animal):
		return

	var animal_id := _get_animal_id(animal)

	# Remove timer - no partial production (AC13)
	_worker_timers.erase(animal_id)
	_paused_workers.erase(animal_id)
	_worker_references.erase(animal_id)

	GameLogger.debug("GathererComponent", "Worker %s stopped production (no partial resource)" % animal_id)


## Get current number of active workers.
## @return Number of workers with active timers
func get_active_worker_count() -> int:
	return _worker_timers.size()


## Check if a specific animal is working at this component.
## @param animal The Animal to check
## @return true if animal has an active production timer
func is_worker_active(animal: Node) -> bool:
	if not is_instance_valid(animal):
		return false
	return _worker_timers.has(_get_animal_id(animal))

# =============================================================================
# PRODUCTION
# =============================================================================

## Produce a resource for a worker that completed a cycle.
## @param animal_id The ID of the animal that completed production
func _produce_resource(animal_id: String) -> void:
	# Check if gathering is paused for this resource (storage full - AC6)
	if ResourceManager.is_gathering_paused(_output_resource_id):
		_paused_workers[animal_id] = true
		GameLogger.debug("GathererComponent", "Production paused for %s - %s storage full" % [animal_id, _output_resource_id])
		return

	# Add resource to storage
	ResourceManager.add_resource(_output_resource_id, 1)

	# Emit EventBus signal (AC5) - verify building still valid
	if is_instance_valid(EventBus) and is_instance_valid(_building):
		EventBus.production_completed.emit(_building, _output_resource_id)

	# Emit local signal with animal reference
	var animal: Node = _worker_references.get(animal_id)
	worker_production_completed.emit(animal, _output_resource_id)

	GameLogger.debug("GathererComponent", "Worker %s produced 1 %s" % [animal_id, _output_resource_id])


## Handle gathering resumed signal from ResourceManager.
## Clears pause state but does NOT reset timers (timer continues from paused time).
## @param resource_id The resource type that can be gathered again
func _on_gathering_resumed(resource_id: String) -> void:
	if resource_id != _output_resource_id:
		return

	# Only clear pause flags - do NOT touch _worker_timers (timer continues from where it was)
	var resumed_count := _paused_workers.size()
	_paused_workers.clear()

	if resumed_count > 0:
		GameLogger.debug("GathererComponent", "Production resumed for %d workers producing %s" % [resumed_count, resource_id])

# =============================================================================
# QUERIES
# =============================================================================

## Get the output resource ID.
## @return The resource type this component produces
func get_output_resource_id() -> String:
	return _output_resource_id


## Get the production time per cycle (base time without bonuses).
## @return Time in seconds for one production cycle
func get_production_time() -> float:
	return _production_time


## Get effective production time with School efficiency bonus (Story 6-8).
## Production time is divided by efficiency multiplier (higher = faster).
## @return Effective time in seconds for one production cycle
func _get_effective_production_time() -> float:
	var multiplier := 1.0
	if is_instance_valid(UpgradeBonusManager):
		multiplier = UpgradeBonusManager.get_efficiency_multiplier()
	return _production_time / multiplier


## Get effective production time (public API for UI display).
## @return Effective time in seconds with bonuses applied
func get_effective_production_time() -> float:
	return _get_effective_production_time()


## Check if component is initialized.
## @return true if initialize() has been called
func is_initialized() -> bool:
	return _initialized


## Get the number of paused workers (storage full).
## @return Number of workers currently paused
func get_paused_worker_count() -> int:
	return _paused_workers.size()


## Check if a specific worker is paused.
## @param animal The Animal to check
## @return true if worker is paused due to storage full
func is_worker_paused(animal: Node) -> bool:
	if not is_instance_valid(animal):
		return false
	return _paused_workers.has(_get_animal_id(animal))


## Get production progress for a specific worker (0.0 to 1.0).
## @param animal The Animal to check
## @return Progress ratio, or -1.0 if worker not found
func get_worker_progress(animal: Node) -> float:
	if not is_instance_valid(animal):
		return -1.0

	var animal_id := _get_animal_id(animal)
	if not _worker_timers.has(animal_id):
		return -1.0

	# Use effective time for accurate progress display (Story 6-8)
	var effective_time := _get_effective_production_time()
	return clampf(_worker_timers[animal_id] / effective_time, 0.0, 1.0)

# =============================================================================
# UTILITY
# =============================================================================

## Get unique identifier for an animal.
## @param animal The Animal node (or any Node with get_animal_id method)
## @return String identifier
func _get_animal_id(animal: Node) -> String:
	if animal.has_method("get_animal_id"):
		return animal.get_animal_id()
	return str(animal.get_instance_id())

# =============================================================================
# SERIALIZATION (Story 6-1)
# =============================================================================

## Serialize gatherer state for save system.
## Captures production timers and pause state for all workers.
## @return Dictionary with serialized state
func to_dict() -> Dictionary:
	return {
		"output_resource_id": _output_resource_id,
		"production_time": _production_time,
		"worker_timers": _worker_timers.duplicate(),
		"paused_workers": _paused_workers.keys(),
	}


## Restore gatherer state from saved data.
## NOTE: Worker references must be reconnected by Building after animals are restored.
## @param data Dictionary with saved state
func from_dict(data: Dictionary) -> void:
	if data.has("worker_timers") and data["worker_timers"] is Dictionary:
		_worker_timers = data["worker_timers"].duplicate()
	if data.has("paused_workers") and data["paused_workers"] is Array:
		_paused_workers.clear()
		for animal_id in data["paused_workers"]:
			_paused_workers[animal_id] = true
	# Note: _worker_references must be restored separately when animals are loaded


# =============================================================================
# CLEANUP
# =============================================================================

## Clean up component state.
## Called during building cleanup.
func cleanup() -> void:
	_worker_timers.clear()
	_paused_workers.clear()
	_worker_references.clear()
	_building = null
	_initialized = false
