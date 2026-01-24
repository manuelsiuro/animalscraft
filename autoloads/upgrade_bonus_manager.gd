## Manages upgrade building bonuses.
## Autoload singleton - access via UpgradeBonusManager.method()
## Tracks placed upgrade buildings and provides bonus multipliers.
##
## Bonuses:
## - School: +15% worker efficiency (faster production) - does NOT stack
## - Hospital: 2x rest recovery speed - does NOT stack
## - Warehouse: +50% storage capacity per warehouse - DOES stack
##
## Architecture: autoloads/upgrade_bonus_manager.gd
## Story: 6-8-create-upgrade-buildings
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when any bonus changes (building added/removed)
signal bonuses_changed()

# =============================================================================
# CONSTANTS
# =============================================================================

## Efficiency bonus from School (15% faster production)
const EFFICIENCY_BONUS: float = 0.15

## Rest recovery multiplier from Hospital (2x faster)
const REST_MULTIPLIER: float = 2.0

## Storage capacity bonus per Warehouse (50%)
const STORAGE_BONUS_PER_WAREHOUSE: float = 0.50

## Building IDs for upgrade buildings
const SCHOOL_ID: String = "school"
const HOSPITAL_ID: String = "hospital"
const WAREHOUSE_ID: String = "warehouse"

# =============================================================================
# STATE
# =============================================================================

## Count of each upgrade building type placed
var _school_count: int = 0
var _hospital_count: int = 0
var _warehouse_count: int = 0

## Flag to prevent signal emission during load
var _loading: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Connect to building placed/removed signals
	if EventBus:
		EventBus.building_placed.connect(_on_building_placed)
		EventBus.building_removed.connect(_on_building_removed)

	GameLogger.info("UpgradeBonusManager", "Initialized")


func _exit_tree() -> void:
	# Disconnect from EventBus
	if EventBus:
		if EventBus.building_placed.is_connected(_on_building_placed):
			EventBus.building_placed.disconnect(_on_building_placed)
		if EventBus.building_removed.is_connected(_on_building_removed):
			EventBus.building_removed.disconnect(_on_building_removed)

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

## Handle building placed event
func _on_building_placed(building: Node, _hex_coord: Vector2i) -> void:
	if not is_instance_valid(building):
		return

	var building_id := _get_building_id(building)
	var changed := false

	match building_id:
		SCHOOL_ID:
			_school_count += 1
			changed = true
			GameLogger.info("UpgradeBonusManager", "School placed (count: %d)" % _school_count)
		HOSPITAL_ID:
			_hospital_count += 1
			changed = true
			GameLogger.info("UpgradeBonusManager", "Hospital placed (count: %d)" % _hospital_count)
		WAREHOUSE_ID:
			_warehouse_count += 1
			changed = true
			GameLogger.info("UpgradeBonusManager", "Warehouse placed (count: %d, storage mult: %.2f)" % [
				_warehouse_count, get_storage_multiplier()
			])

	if changed and not _loading:
		bonuses_changed.emit()


## Handle building removed event
func _on_building_removed(building: Node, _hex_coord: Vector2i) -> void:
	if not is_instance_valid(building):
		return

	var building_id := _get_building_id(building)
	var changed := false

	match building_id:
		SCHOOL_ID:
			_school_count = maxi(0, _school_count - 1)
			changed = true
			GameLogger.info("UpgradeBonusManager", "School removed (count: %d)" % _school_count)
		HOSPITAL_ID:
			_hospital_count = maxi(0, _hospital_count - 1)
			changed = true
			GameLogger.info("UpgradeBonusManager", "Hospital removed (count: %d)" % _hospital_count)
		WAREHOUSE_ID:
			_warehouse_count = maxi(0, _warehouse_count - 1)
			changed = true
			GameLogger.info("UpgradeBonusManager", "Warehouse removed (count: %d, storage mult: %.2f)" % [
				_warehouse_count, get_storage_multiplier()
			])

	if changed and not _loading:
		bonuses_changed.emit()


## Get building ID from building node
func _get_building_id(building: Node) -> String:
	if building.has_method("get_building_id"):
		return building.get_building_id()
	return ""

# =============================================================================
# PUBLIC API - BONUS MULTIPLIERS
# =============================================================================

## Get production efficiency multiplier.
## 1.0 = normal speed, 1.15 = with School bonus (15% faster)
## Production time is DIVIDED by this value to make production faster.
## @return Efficiency multiplier (1.0 or 1.15)
func get_efficiency_multiplier() -> float:
	if _school_count > 0:
		return 1.0 + EFFICIENCY_BONUS
	return 1.0


## Get rest recovery multiplier.
## 1.0 = normal recovery, 2.0 = with Hospital bonus (2x faster)
## Recovery amount is MULTIPLIED by this value.
## @return Rest multiplier (1.0 or 2.0)
func get_rest_multiplier() -> float:
	if _hospital_count > 0:
		return REST_MULTIPLIER
	return 1.0


## Get storage capacity multiplier.
## 1.0 = normal capacity, stacks with multiple Warehouses
## Each Warehouse adds 50% capacity.
## @return Storage multiplier (1.0 + 0.5 * warehouse_count)
func get_storage_multiplier() -> float:
	return 1.0 + (_warehouse_count * STORAGE_BONUS_PER_WAREHOUSE)

# =============================================================================
# PUBLIC API - BONUS STATUS
# =============================================================================

## Check if a specific bonus is active.
## @param bonus_type "efficiency", "rest", or "storage"
## @return true if at least one building of that type is placed
func is_bonus_active(bonus_type: String) -> bool:
	match bonus_type:
		"efficiency":
			return _school_count > 0
		"rest":
			return _hospital_count > 0
		"storage":
			return _warehouse_count > 0
		_:
			return false


## Get count of a specific upgrade building type.
## @param building_id "school", "hospital", or "warehouse"
## @return Number of that building type placed
func get_building_count(building_id: String) -> int:
	match building_id:
		SCHOOL_ID:
			return _school_count
		HOSPITAL_ID:
			return _hospital_count
		WAREHOUSE_ID:
			return _warehouse_count
		_:
			return 0


## Get bonus description text for a building.
## @param building_id Building ID to get description for
## @return Formatted bonus description string
func get_bonus_description(building_id: String) -> String:
	match building_id:
		SCHOOL_ID:
			var active := is_bonus_active("efficiency")
			var status := " [ACTIVE]" if active else ""
			return "All workers +15%% efficiency%s" % status
		HOSPITAL_ID:
			var active := is_bonus_active("rest")
			var status := " [ACTIVE]" if active else ""
			return "Rest recovery 2x faster%s" % status
		WAREHOUSE_ID:
			var current_bonus := (get_storage_multiplier() - 1.0) * 100
			return "Storage +50%% per warehouse (current: +%.0f%%)" % current_bonus
		_:
			return ""

# =============================================================================
# SAVE/LOAD (AC10)
# =============================================================================

## Get data for save file.
## @return Dictionary with building counts
func get_save_data() -> Dictionary:
	return {
		"school_count": _school_count,
		"hospital_count": _hospital_count,
		"warehouse_count": _warehouse_count,
	}


## Load data from save file.
## Note: Building counts are restored from placed buildings, this is for verification.
## @param data Dictionary with saved building counts
func load_save_data(data: Dictionary) -> void:
	_loading = true

	# Reset counts - they will be rebuilt from placed buildings
	_school_count = 0
	_hospital_count = 0
	_warehouse_count = 0

	# Load counts from save data if present (for verification/fast restore)
	if data.has("school_count") and data["school_count"] is int:
		_school_count = maxi(0, data["school_count"])
	if data.has("hospital_count") and data["hospital_count"] is int:
		_hospital_count = maxi(0, data["hospital_count"])
	if data.has("warehouse_count") and data["warehouse_count"] is int:
		_warehouse_count = maxi(0, data["warehouse_count"])

	_loading = false

	GameLogger.info("UpgradeBonusManager", "Loaded: school=%d, hospital=%d, warehouse=%d" % [
		_school_count, _hospital_count, _warehouse_count
	])


## Reset to default state (no upgrade buildings).
## Used for new game. Emits bonuses_changed signal to notify dependent systems.
func reset_to_defaults() -> void:
	var had_bonuses := _school_count > 0 or _hospital_count > 0 or _warehouse_count > 0
	_school_count = 0
	_hospital_count = 0
	_warehouse_count = 0
	GameLogger.info("UpgradeBonusManager", "Reset to defaults")
	# Emit signal if we actually had bonuses to clear (Story 6-8 M2 fix)
	if had_bonuses:
		bonuses_changed.emit()
