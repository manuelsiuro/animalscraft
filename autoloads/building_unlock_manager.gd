## Manages building unlock state.
## Autoload singleton - access via BuildingUnlockManager.method()
## Listens to EventBus.building_unlocked and tracks which buildings are available.
##
## Buildings start locked and are unlocked through:
## - Starter buildings (available from game start)
## - Milestone rewards (population thresholds)
##
## Architecture: autoloads/building_unlock_manager.gd
## Story: 6-7-implement-building-unlocks
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a building becomes unlocked
## @param building_type The building_id that was unlocked (e.g., "mill", "bakery")
signal unlock_state_changed(building_type: String)

# =============================================================================
# CONSTANTS
# =============================================================================

## Buildings available from game start (no unlock required)
## These buildings are always available in the building menu
const STARTER_BUILDINGS: Array[String] = ["shelter", "farm", "sawmill"]

# =============================================================================
# STATE
# =============================================================================

## Set of unlocked building types (building_id -> true)
## Uses Dictionary as a Set for O(1) lookup
var _unlocked_buildings: Dictionary = {}

## Flag to prevent signals during load
var _loading: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Validate starter building IDs exist (L2: catch mismatched IDs early)
	_validate_starter_buildings()

	# Initialize with starter buildings
	for building_type in STARTER_BUILDINGS:
		_unlocked_buildings[building_type] = true

	# Connect to unlock events from MilestoneManager
	if EventBus:
		EventBus.building_unlocked.connect(_on_building_unlocked)

	GameLogger.info("BuildingUnlockManager", "Initialized with %d starter buildings: %s" % [
		STARTER_BUILDINGS.size(),
		", ".join(STARTER_BUILDINGS)
	])


func _exit_tree() -> void:
	# Disconnect from EventBus
	if EventBus and EventBus.building_unlocked.is_connected(_on_building_unlocked):
		EventBus.building_unlocked.disconnect(_on_building_unlocked)


## Validate that starter building IDs exist in building resources.
## Logs warnings for any IDs that don't match actual building data files.
func _validate_starter_buildings() -> void:
	var building_path := "res://resources/buildings/"
	var dir := DirAccess.open(building_path)
	if not dir:
		GameLogger.warn("BuildingUnlockManager", "Cannot validate starter buildings: resources folder not accessible")
		return

	# Collect valid building IDs from resource files
	var valid_ids: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with("_data.tres"):
			var data := load(building_path + file_name) as Resource
			if data and data.get("building_id"):
				valid_ids.append(data.get("building_id"))
		file_name = dir.get_next()
	dir.list_dir_end()

	# Warn about any starter buildings that don't exist
	for starter_id in STARTER_BUILDINGS:
		if starter_id not in valid_ids:
			GameLogger.warn("BuildingUnlockManager", "Starter building ID '%s' not found in building resources" % starter_id)

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

## Handle building_unlocked signal from EventBus (typically from MilestoneManager)
func _on_building_unlocked(building_type: String) -> void:
	if building_type.is_empty():
		GameLogger.warn("BuildingUnlockManager", "Received empty building_type in building_unlocked signal")
		return

	# Skip if already unlocked
	if _unlocked_buildings.has(building_type):
		GameLogger.debug("BuildingUnlockManager", "Building already unlocked: %s" % building_type)
		return

	# Unlock the building
	_unlocked_buildings[building_type] = true

	# Emit state change signal (unless loading)
	if not _loading:
		unlock_state_changed.emit(building_type)

	GameLogger.info("BuildingUnlockManager", "Building unlocked: %s (total: %d)" % [
		building_type,
		_unlocked_buildings.size()
	])

# =============================================================================
# PUBLIC API (AC1)
# =============================================================================

## Check if a building type is unlocked.
## @param building_type The building_id to check (e.g., "farm", "mill")
## @return true if the building is available to place, false otherwise
func is_building_unlocked(building_type: String) -> bool:
	if building_type.is_empty():
		return false
	return _unlocked_buildings.has(building_type)


## Get array of all unlocked building types.
## @return Array of building_ids that are currently unlocked
func get_unlocked_buildings() -> Array[String]:
	var result: Array[String] = []
	for key in _unlocked_buildings.keys():
		result.append(key)
	return result


## Get the count of unlocked buildings.
## @return Number of currently unlocked building types
func get_unlocked_count() -> int:
	return _unlocked_buildings.size()


## Check if a building type is a starter building.
## @param building_type The building_id to check
## @return true if this is a starter building (always available)
func is_starter_building(building_type: String) -> bool:
	return building_type in STARTER_BUILDINGS

# =============================================================================
# SAVE/LOAD (AC5)
# =============================================================================

## Get data for save file.
## @return Dictionary containing unlock state for persistence
func get_save_data() -> Dictionary:
	return {
		"unlocked": _unlocked_buildings.keys()
	}


## Load data from save file.
## Restores unlock state, always ensuring starter buildings remain unlocked.
## @param data Dictionary from save file containing unlock state
func load_save_data(data: Dictionary) -> void:
	_loading = true
	_unlocked_buildings.clear()

	# Always include starter buildings (safety guarantee)
	for building_type in STARTER_BUILDINGS:
		_unlocked_buildings[building_type] = true

	# Load saved unlocks
	if data.has("unlocked"):
		var unlocked_list = data["unlocked"]
		if unlocked_list is Array:
			for building_type in unlocked_list:
				if building_type is String and not building_type.is_empty():
					_unlocked_buildings[building_type] = true

	_loading = false
	GameLogger.info("BuildingUnlockManager", "Loaded %d unlocked buildings from save" % _unlocked_buildings.size())


## Reset to default state (starter buildings only).
## Used for new game or testing.
## NOTE: Does not emit unlock_state_changed signals for removed buildings.
## Callers should handle UI updates if needed (e.g., close/reopen building menu).
func reset_to_defaults() -> void:
	_unlocked_buildings.clear()
	for building_type in STARTER_BUILDINGS:
		_unlocked_buildings[building_type] = true
	GameLogger.info("BuildingUnlockManager", "Reset to default state with %d starter buildings" % STARTER_BUILDINGS.size())
