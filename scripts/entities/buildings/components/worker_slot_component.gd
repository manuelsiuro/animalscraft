## WorkerSlotComponent - Manages worker assignment for buildings.
## Tracks assigned animals up to a maximum limit.
## Emits signals for worker changes.
##
## Architecture: scripts/entities/buildings/components/worker_slot_component.gd
## Story: 3-1-create-building-entity-structure
class_name WorkerSlotComponent
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a worker is added to this building.
## @param animal The Animal node that was added
signal worker_added(animal: Animal)

## Emitted when a worker is removed from this building.
## @param animal The Animal node that was removed
signal worker_removed(animal: Animal)

## Emitted when the worker count changes.
## @param count The new total number of workers
signal workers_changed(count: int)

# =============================================================================
# PROPERTIES
# =============================================================================

## Maximum number of workers allowed
var _max_workers: int = 1

## Currently assigned workers
var _assigned_workers: Array[Animal] = []

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Connect to EventBus to handle animal removal (PARTY MODE feature)
	EventBus.animal_removed.connect(_on_animal_removed)


func _exit_tree() -> void:
	# Safe disconnect from EventBus
	if EventBus.animal_removed.is_connected(_on_animal_removed):
		EventBus.animal_removed.disconnect(_on_animal_removed)


## Initialize worker slots with max capacity.
## @param max_workers Maximum number of workers allowed
func initialize(max_workers: int) -> void:
	_max_workers = maxi(0, max_workers)  # Ensure non-negative
	GameLogger.debug("WorkerSlotComponent", "Initialized with max_workers=%d" % _max_workers)

# =============================================================================
# WORKER MANAGEMENT
# =============================================================================

## Add a worker to this building.
## @param animal The Animal to assign as worker
## @return true if worker was added, false if slot full or invalid
func add_worker(animal: Animal) -> bool:
	# Guard: validate animal reference
	if not is_instance_valid(animal):
		GameLogger.warn("WorkerSlotComponent", "Attempted to add invalid animal reference")
		return false

	# Guard: check if slots available
	if not is_slot_available():
		GameLogger.debug("WorkerSlotComponent", "No available worker slots (max=%d)" % _max_workers)
		return false

	# Guard: prevent duplicate assignment
	if animal in _assigned_workers:
		GameLogger.debug("WorkerSlotComponent", "Animal already assigned to this building")
		return false

	# Add worker
	_assigned_workers.append(animal)

	# Emit signals
	worker_added.emit(animal)
	workers_changed.emit(_assigned_workers.size())

	GameLogger.debug("WorkerSlotComponent", "Worker added: %s (total: %d/%d)" % [
		animal.get_animal_id() if animal.has_method("get_animal_id") else "unknown",
		_assigned_workers.size(),
		_max_workers
	])

	return true


## Remove a worker from this building.
## @param animal The Animal to remove
## @return true if worker was removed, false if not found
func remove_worker(animal: Animal) -> bool:
	# Guard: check if animal is assigned
	if not animal in _assigned_workers:
		return false

	# Remove worker
	_assigned_workers.erase(animal)

	# Emit signals
	worker_removed.emit(animal)
	workers_changed.emit(_assigned_workers.size())

	GameLogger.debug("WorkerSlotComponent", "Worker removed (total: %d/%d)" % [
		_assigned_workers.size(),
		_max_workers
	])

	return true

# =============================================================================
# QUERIES
# =============================================================================

## Check if there are available worker slots.
## @return true if current workers < max workers
func is_slot_available() -> bool:
	return _assigned_workers.size() < _max_workers


## Get current number of assigned workers.
## @return Number of workers currently assigned
func get_worker_count() -> int:
	return _assigned_workers.size()


## Get copy of assigned workers array.
## Returns a copy to prevent external modification.
## @return Array of assigned Animal nodes
func get_workers() -> Array[Animal]:
	return _assigned_workers.duplicate()


## Get maximum number of workers allowed.
## @return Maximum worker capacity
func get_max_workers() -> int:
	return _max_workers


## Check if a specific animal is assigned to this building.
## @param animal The Animal to check
## @return true if animal is assigned here
func has_worker(animal: Animal) -> bool:
	if not is_instance_valid(animal):
		return false
	return animal in _assigned_workers

# =============================================================================
# EVENT HANDLERS (PARTY MODE)
# =============================================================================

## Handle animal removal - auto-remove freed workers from slots.
## Prevents orphan references when animals are destroyed.
## @param animal The Animal node that was removed
func _on_animal_removed(animal: Node) -> void:
	# Only process if this is an Animal type
	if not animal is Animal:
		return

	var typed_animal := animal as Animal

	# Check if this animal was assigned to us
	if typed_animal in _assigned_workers:
		GameLogger.debug("WorkerSlotComponent", "Auto-removing freed worker from building")
		# Use internal array operation to avoid double-emit
		_assigned_workers.erase(typed_animal)
		worker_removed.emit(typed_animal)
		workers_changed.emit(_assigned_workers.size())

# =============================================================================
# CLEANUP
# =============================================================================

## Clear all worker references.
## Called during building cleanup.
func cleanup() -> void:
	# Emit removal for each worker before clearing
	for worker in _assigned_workers:
		if is_instance_valid(worker):
			worker_removed.emit(worker)

	_assigned_workers.clear()
	workers_changed.emit(0)
