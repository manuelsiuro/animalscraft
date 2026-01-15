## Manages all resource storage and operations.
## Autoload singleton - access via ResourceManager.method()
##
## Architecture: autoloads/resource_manager.gd
## Order: 10 (depends on EventBus, GameLogger, GameConstants)
## Source: game-architecture.md#Resource Systems
##
## Usage:
##   ResourceManager.add_resource("wheat", 50)
##   var has_enough = ResourceManager.has_resource("wheat", 30)
##   ResourceManager.remove_resource("wheat", 30)
extends Node

## Current resource amounts (resource_id -> amount)
var _resources: Dictionary = {}

## Cached ResourceData objects (resource_id -> ResourceData)
var _resource_data_cache: Dictionary = {}

## Track which resources have had warning emitted (Story 3-3)
var _warning_emitted: Dictionary = {}

## Track which resources have gathering paused due to full storage (Story 3-3)
var _gathering_paused: Dictionary = {}

## Reference to StorageManager for capacity queries (set via set_storage_manager)
var _storage_manager: Node = null

func _ready() -> void:
	_resources = {}
	_resource_data_cache = {}
	_warning_emitted = {}
	_gathering_paused = {}
	GameLogger.info("ResourceManager", "Resource system initialized")


## Add resources to storage, respecting storage limits.
## Returns the new total amount.
## Emits storage warning at 80% capacity (with hysteresis).
## Emits gathering_paused signal when storage is full.
## @param resource_id The resource type identifier
## @param amount The amount to add (must be positive)
## @return The new total amount after adding
func add_resource(resource_id: String, amount: int) -> int:
	if amount <= 0:
		GameLogger.warn("ResourceManager", "Attempted to add non-positive amount: %d" % amount)
		return get_resource_amount(resource_id)

	var current := get_resource_amount(resource_id)
	var limit := get_storage_limit(resource_id)
	var new_amount: int

	if limit > 0:
		new_amount = mini(current + amount, limit)
	else:
		new_amount = current + amount

	_resources[resource_id] = new_amount
	EventBus.resource_changed.emit(resource_id, new_amount)

	# Check for storage warning threshold (80%) - Story 3-3 AC2
	var percentage := get_storage_percentage(resource_id)
	if percentage >= GameConstants.STORAGE_WARNING_THRESHOLD:
		if not _warning_emitted.get(resource_id, false):
			_warning_emitted[resource_id] = true
			EventBus.resource_storage_warning.emit(resource_id)
			GameLogger.info("ResourceManager", "%s storage at %.0f%%" % [resource_id, percentage * 100])

	# Check for storage full - emit gathering pause - Story 3-3 AC4
	if limit > 0 and new_amount >= limit:
		EventBus.resource_full.emit(resource_id)
		# Emit gathering paused if not already paused
		if not _gathering_paused.get(resource_id, false):
			_gathering_paused[resource_id] = true
			EventBus.resource_gathering_paused.emit(resource_id, "storage_full")
			GameLogger.info("ResourceManager", "%s gathering paused - storage full" % resource_id)

	GameLogger.debug("ResourceManager", "%s: %d -> %d" % [resource_id, current, new_amount])
	return new_amount


## Remove resources from storage.
## Returns true if successful, false if insufficient stock.
## Resets warning state when dropping below 70% threshold (hysteresis).
## Resumes gathering when space becomes available.
## @param resource_id The resource type identifier
## @param amount The amount to remove (must be positive)
## @return True if removal succeeded, false if insufficient stock
func remove_resource(resource_id: String, amount: int) -> bool:
	if amount <= 0:
		GameLogger.warn("ResourceManager", "Attempted to remove non-positive amount: %d" % amount)
		return false

	var current := get_resource_amount(resource_id)
	if current < amount:
		GameLogger.debug("ResourceManager", "Insufficient %s: have %d, need %d" % [resource_id, current, amount])
		return false

	var new_amount := current - amount
	_resources[resource_id] = new_amount
	EventBus.resource_changed.emit(resource_id, new_amount)

	if new_amount == 0:
		EventBus.resource_depleted.emit(resource_id)

	# Reset warning if dropped BELOW reset threshold (70%) - Story 3-3 AC2
	# Note: Must be strictly BELOW, not equal (boundary test confirms)
	var percentage := get_storage_percentage(resource_id)
	if percentage < GameConstants.STORAGE_WARNING_RESET_THRESHOLD:
		if _warning_emitted.get(resource_id, false):
			_warning_emitted[resource_id] = false
			GameLogger.debug("ResourceManager", "%s storage warning reset" % resource_id)

	# Resume gathering if space became available - Story 3-3 AC4
	if _gathering_paused.get(resource_id, false):
		var limit := get_storage_limit(resource_id)
		if limit <= 0 or new_amount < limit:
			_gathering_paused[resource_id] = false
			EventBus.resource_gathering_resumed.emit(resource_id)
			GameLogger.info("ResourceManager", "%s gathering resumed - storage available" % resource_id)

	GameLogger.debug("ResourceManager", "%s: %d -> %d" % [resource_id, current, new_amount])
	return true


## Get current amount of a resource (0 if not initialized).
## @param resource_id The resource type identifier
## @return Current amount, or 0 if resource not tracked
func get_resource_amount(resource_id: String) -> int:
	return _resources.get(resource_id, 0)


## Check if sufficient stock exists.
## @param resource_id The resource type identifier
## @param amount The amount to check for
## @return True if current stock >= amount
func has_resource(resource_id: String, amount: int) -> bool:
	return get_resource_amount(resource_id) >= amount


## Get copy of all resource amounts.
## @return Dictionary copy of all resource amounts (resource_id -> int)
func get_all_resources() -> Dictionary:
	return _resources.duplicate()


## Get storage limit for a resource - Story 3-3 AC1.
## Uses StorageManager for global capacity if available, otherwise falls back
## to ResourceData max_stack_size or default village capacity.
## @param resource_id The resource type identifier
## @return Maximum storage capacity
func get_storage_limit(resource_id: String) -> int:
	# Use StorageManager for capacity if available - Story 3-3 AC1
	if _storage_manager and _storage_manager.has_method("get_total_capacity"):
		return _storage_manager.get_total_capacity(resource_id)
	# Fallback to ResourceData max_stack_size
	var data := _get_resource_data(resource_id)
	if data:
		return data.max_stack_size
	# Final fallback to default village storage capacity
	return GameConstants.DEFAULT_VILLAGE_STORAGE_CAPACITY


## Check if storage is at capacity.
## @param resource_id The resource type identifier
## @return True if current amount >= storage limit
func is_storage_full(resource_id: String) -> bool:
	var limit := get_storage_limit(resource_id)
	if limit <= 0:
		return false
	return get_resource_amount(resource_id) >= limit


## Get storage fill percentage (0.0 to 1.0) - Story 3-3 AC3.
## Returns 0.0 for unknown resources or if capacity is 0.
## @param resource_id The resource type identifier
## @return Float between 0.0 and 1.0 representing fill ratio
func get_storage_percentage(resource_id: String) -> float:
	var current := get_resource_amount(resource_id)
	var capacity := get_storage_limit(resource_id)
	if capacity <= 0:
		return 0.0
	return clampf(float(current) / float(capacity), 0.0, 1.0)


## Get complete storage info for a resource - Story 3-3 AC3.
## Returns dictionary with current, capacity, percentage, is_warning, is_full.
## Works for both known and unknown resources.
## @param resource_id The resource type identifier
## @return Dictionary with storage information
func get_storage_info(resource_id: String) -> Dictionary:
	var current := get_resource_amount(resource_id)
	var capacity := get_storage_limit(resource_id)
	var percentage := get_storage_percentage(resource_id)
	return {
		"current": current,
		"capacity": capacity,
		"percentage": percentage,
		"is_warning": percentage >= GameConstants.STORAGE_WARNING_THRESHOLD,
		"is_full": current >= capacity if capacity > 0 else false
	}


## Check if gathering is paused for a resource - Story 3-3 AC4.
## @param resource_id The resource type identifier
## @return True if gathering is currently paused for this resource
func is_gathering_paused(resource_id: String) -> bool:
	return _gathering_paused.get(resource_id, false)


## Set the StorageManager reference for capacity calculations - Story 3-3.
## Called by StorageManager during initialization.
## @param manager The StorageManager node instance
func set_storage_manager(manager: Node) -> void:
	_storage_manager = manager
	GameLogger.debug("ResourceManager", "StorageManager reference set")


## Get ResourceData for a resource, with caching.
## @param resource_id The resource type identifier
## @return ResourceData resource, or null if not found
func _get_resource_data(resource_id: String) -> ResourceData:
	if _resource_data_cache.has(resource_id):
		return _resource_data_cache[resource_id]

	var path = "res://resources/resources/%s_data.tres" % resource_id
	if not ResourceLoader.exists(path):
		GameLogger.debug("ResourceManager", "No ResourceData for: " + resource_id)
		return null

	var data = load(path) as ResourceData
	if data:
		_resource_data_cache[resource_id] = data
	return data


## Get save data for persistence - Story 3-3 AC8.
## Includes resource amounts and warning states.
## @return Serializable dictionary containing resource state
func get_save_data() -> Dictionary:
	return {
		"resources": _resources.duplicate(),
		"warning_emitted": _warning_emitted.duplicate()
	}


## Load save data and restore state - Story 3-3 AC8.
## Clears existing resources and emits signals for each loaded resource.
## Restores warning states from saved data.
## @param data Dictionary containing saved resource state
func load_save_data(data: Dictionary) -> void:
	_resources.clear()
	_warning_emitted.clear()
	_gathering_paused.clear()

	if data.has("resources") and data["resources"] is Dictionary:
		var saved_resources: Dictionary = data["resources"]
		for resource_id in saved_resources:
			var amount: int = saved_resources[resource_id]
			_resources[resource_id] = amount
			EventBus.resource_changed.emit(resource_id, amount)

	# Restore warning states - Story 3-3 AC8
	if data.has("warning_emitted") and data["warning_emitted"] is Dictionary:
		_warning_emitted = data["warning_emitted"].duplicate()

	GameLogger.info("ResourceManager", "Loaded %d resource types" % _resources.size())


## Clear all resources (for new game).
## Emits resource_changed and resource_depleted signals for each cleared resource.
## Also clears warning and gathering states.
func clear_all() -> void:
	for resource_id in _resources.keys():
		EventBus.resource_changed.emit(resource_id, 0)
		EventBus.resource_depleted.emit(resource_id)
	_resources.clear()
	_warning_emitted.clear()
	_gathering_paused.clear()
	GameLogger.info("ResourceManager", "All resources cleared")
