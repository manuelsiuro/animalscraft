## StorageManager - Manages total storage capacity from buildings.
## Works with ResourceManager to enforce capacity limits.
## Not an autoload - instantiated in game scene.
##
## Architecture: scripts/systems/resources/storage_manager.gd
## Story: 3-3-implement-resource-storage-and-limits
## Source: game-architecture.md#Resource Systems
##
## Performance: Uses caching for capacity and storage info to avoid O(n*m)
## recalculation on every frame. Cache invalidated on building/resource changes.
class_name StorageManager
extends Node

# =============================================================================
# PROPERTIES
# =============================================================================

## Registered storage buildings (Array of Building nodes with storage_capacity_bonus > 0)
var _storage_buildings: Array[Node] = []

## Base storage capacity without buildings
var _base_capacity: int = GameConstants.DEFAULT_VILLAGE_STORAGE_CAPACITY

## Cached total capacity (invalidated on building change)
## -1 means cache is invalid and needs recalculation
var _cached_capacity: int = -1

## Cached storage info for UI polling (invalidated on resource/capacity change)
var _cached_storage_info: Dictionary = {}
var _storage_info_dirty: bool = true

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_storage_buildings = []
	_cached_capacity = -1
	_cached_storage_info = {}
	_storage_info_dirty = true

	# Connect to EventBus signals for building lifecycle
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.building_removed.connect(_on_building_removed)
	EventBus.resource_changed.connect(_on_resource_changed)

	# Connect to UpgradeBonusManager for Warehouse storage multiplier (Story 6-8)
	if is_instance_valid(UpgradeBonusManager):
		UpgradeBonusManager.bonuses_changed.connect(_on_bonuses_changed)

	# Register with ResourceManager
	if ResourceManager and ResourceManager.has_method("set_storage_manager"):
		ResourceManager.set_storage_manager(self)

	GameLogger.info("StorageManager", "Storage system initialized")


# =============================================================================
# CAPACITY QUERIES (Story 3-3 AC1)
# =============================================================================

## Get total storage capacity for a resource type.
## Uses caching to avoid redundant iteration.
## Applies Warehouse storage multiplier from UpgradeBonusManager (Story 6-8).
## @param resource_id The resource type identifier
## @return Total storage capacity including base + building bonuses + multiplier
func get_total_capacity(_resource_id: String) -> int:
	# Check cache first
	if _cached_capacity >= 0:
		return _cached_capacity

	# Calculate total: base capacity + all storage building bonuses
	var total := _base_capacity

	for building in _storage_buildings:
		if building and is_instance_valid(building):
			var building_data: BuildingData = _get_building_data(building)
			if building_data and building_data.storage_capacity_bonus > 0:
				total += building_data.storage_capacity_bonus

	# Apply Warehouse storage multiplier (Story 6-8)
	# Note: Warehouses themselves don't add flat storage - they multiply total capacity
	# The storage_capacity_bonus in warehouse_data.tres is for legacy/fallback only
	var multiplier := 1.0
	if is_instance_valid(UpgradeBonusManager):
		multiplier = UpgradeBonusManager.get_storage_multiplier()
	total = int(float(total) * multiplier)

	_cached_capacity = total
	return total


## Get storage info for a specific resource (Story 3-3 AC7).
## Returns dictionary with resource_id, current, capacity, percentage, is_warning, is_full.
## @param resource_id The resource type identifier
## @return Dictionary with storage information
func get_storage_info_for(resource_id: String) -> Dictionary:
	var current := ResourceManager.get_resource_amount(resource_id)
	var capacity := get_total_capacity(resource_id)
	var percentage: float = float(current) / float(capacity) if capacity > 0 else 0.0

	return {
		"resource_id": resource_id,
		"current": current,
		"capacity": capacity,
		"percentage": percentage,
		"is_warning": percentage >= GameConstants.STORAGE_WARNING_THRESHOLD,
		"is_full": current >= capacity
	}


## Get complete storage info for all resources (Story 3-3 AC7).
## Uses caching for efficient UI polling.
## @return Dictionary mapping resource_id to storage info dictionaries
func get_all_storage_info() -> Dictionary:
	# Return cached result if still valid
	if not _storage_info_dirty and not _cached_storage_info.is_empty():
		return _cached_storage_info

	var result := {}
	var all_resources := ResourceManager.get_all_resources()

	for resource_id in all_resources.keys():
		result[resource_id] = get_storage_info_for(resource_id)

	_cached_storage_info = result
	_storage_info_dirty = false
	return result


# =============================================================================
# BUILDING REGISTRATION (Story 3-3 AC6)
# =============================================================================

## Register a storage building (called via building_placed signal).
## Only buildings with storage_capacity_bonus > 0 are tracked.
## @param building The Building node that was placed
func register_storage_building(building: Node) -> void:
	if not building or not is_instance_valid(building):
		return

	var building_data: BuildingData = _get_building_data(building)
	if not building_data:
		return

	# Only track buildings with storage capacity bonus
	if building_data.storage_capacity_bonus <= 0:
		return

	# Avoid duplicates
	if building in _storage_buildings:
		return

	_storage_buildings.append(building)
	_invalidate_capacity_cache()

	# Emit capacity changed for all tracked resources
	_emit_capacity_changed_for_all()

	GameLogger.debug("StorageManager", "Storage building registered: %s (+%d capacity)" % [building_data.building_id, building_data.storage_capacity_bonus])


## Unregister a storage building (called via building_removed signal).
## @param building The Building node that was removed
func unregister_storage_building(building: Node) -> void:
	if not building:
		return

	var index := _storage_buildings.find(building)
	if index < 0:
		return

	_storage_buildings.remove_at(index)
	_invalidate_capacity_cache()

	# Emit capacity changed for all tracked resources
	_emit_capacity_changed_for_all()

	GameLogger.debug("StorageManager", "Storage building unregistered")


# =============================================================================
# CACHE MANAGEMENT
# =============================================================================

## Invalidate capacity cache (call when buildings change).
func _invalidate_capacity_cache() -> void:
	_cached_capacity = -1
	_storage_info_dirty = true


## Emit storage_capacity_changed signal for all tracked resources.
func _emit_capacity_changed_for_all() -> void:
	var all_resources := ResourceManager.get_all_resources()
	var new_capacity := get_total_capacity("")  # Recalculate once

	for resource_id in all_resources.keys():
		EventBus.storage_capacity_changed.emit(resource_id, new_capacity)


# =============================================================================
# EVENT HANDLERS
# =============================================================================

func _on_building_placed(building: Node, _hex_coord: Vector2i) -> void:
	register_storage_building(building)


func _on_building_removed(building: Node, _hex_coord: Vector2i) -> void:
	unregister_storage_building(building)


func _on_resource_changed(_resource_id: String, _amount: int) -> void:
	# Mark cached storage info as stale (capacity stays valid)
	_storage_info_dirty = true


## Handle upgrade bonus changes (Story 6-8).
## Invalidates cache when Warehouse multiplier changes.
func _on_bonuses_changed() -> void:
	_invalidate_capacity_cache()
	_emit_capacity_changed_for_all()
	GameLogger.debug("StorageManager", "Capacity recalculated due to bonus change")


# =============================================================================
# HELPER METHODS
# =============================================================================

## Safely get BuildingData from a Building node.
## @param building The Building node
## @return BuildingData or null
func _get_building_data(building: Node) -> BuildingData:
	if building.has_method("get_data"):
		return building.get_data()
	elif "data" in building:
		return building.data
	return null


## Get count of registered storage buildings.
## @return Number of storage buildings tracked
func get_storage_building_count() -> int:
	return _storage_buildings.size()


# =============================================================================
# CLEANUP
# =============================================================================

func _exit_tree() -> void:
	# Disconnect signals
	if EventBus.building_placed.is_connected(_on_building_placed):
		EventBus.building_placed.disconnect(_on_building_placed)
	if EventBus.building_removed.is_connected(_on_building_removed):
		EventBus.building_removed.disconnect(_on_building_removed)
	if EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)

	# Disconnect from UpgradeBonusManager (Story 6-8)
	if is_instance_valid(UpgradeBonusManager) and UpgradeBonusManager.bonuses_changed.is_connected(_on_bonuses_changed):
		UpgradeBonusManager.bonuses_changed.disconnect(_on_bonuses_changed)

	# Clear reference in ResourceManager
	if ResourceManager and ResourceManager._storage_manager == self:
		ResourceManager._storage_manager = null

	_storage_buildings.clear()
	_cached_storage_info.clear()
	GameLogger.debug("StorageManager", "Storage system cleaned up")
