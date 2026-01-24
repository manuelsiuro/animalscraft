## Save/Load system for AnimalsCraft.
## Autoload singleton - access via SaveManager.save_game/load_game
##
## Architecture: autoloads/save_manager.gd
## Order: 7 (depends on Logger, EventBus)
## Source: game-architecture.md#Save System Schema
## Story: 6-1-implement-save-system-core
##
## Handles game persistence with JSON format, auto-save, backup, and versioning.
## NOTE: No class_name to avoid conflict with autoload singleton
extends Node

# =============================================================================
# SIGNALS (local, also emitted to EventBus)
# =============================================================================

## Emitted when save starts (for UI feedback).
signal save_started()

## Emitted when save ends.
signal save_finished(success: bool)

## Emitted when load starts.
signal load_started()

## Emitted when load ends.
signal load_finished(success: bool)

# =============================================================================
# SAVE SCHEMA
# =============================================================================

## Current save schema version - uses GameConstants for single source of truth.
## Increment GameConstants.SAVE_SCHEMA_VERSION when save format changes.
var SCHEMA_VERSION: int:
	get:
		return GameConstants.SAVE_SCHEMA_VERSION

# =============================================================================
# FILE PATHS
# =============================================================================

## Primary save file path template (slot-based)
const SAVE_PATH_TEMPLATE: String = "user://saves/save_%d.json"

## Backup file path template
const BACKUP_PATH_TEMPLATE: String = "user://saves/save_%d.backup.json"

# =============================================================================
# LOAD ORDER (Story 6-1: Critical for dependency management)
# =============================================================================

## Manager restoration order for load operations.
## Each entry is the key used in save data and the manager reference.
const LOAD_ORDER: Array[String] = [
	"resources",       # ResourceManager - no dependencies
	"territory",       # TerritoryManager - needs HexGrid
	"buildings",       # Buildings - needs TerritoryManager
	"animals",         # Animals - needs Buildings (for assignments)
	"wild_herds",      # WildHerdManager - needs TerritoryManager
	"progression",     # Progression data - last
]

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Auto-save timer
var _autosave_timer: Timer = null

## Track if a save is in progress
var _save_in_progress: bool = false

## Track if a load is in progress (Story 6-1: Signal suppression)
var _load_in_progress: bool = false

## Last successful save slot
var _last_save_slot: int = -1

## Session start time for playtime tracking
var _session_start_time: float = 0.0

## Accumulated playtime from previous sessions
var _accumulated_playtime: float = 0.0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_ensure_save_directory()
	_setup_autosave_timer()

	# Track session start for playtime
	_session_start_time = Time.get_unix_time_from_system()

	# Listen for game events that should trigger save
	EventBus.game_paused.connect(_on_game_paused)

	# Defer timer start to ensure Settings has loaded its config
	call_deferred("_start_autosave_if_enabled")

	GameLogger.info("SaveManager", "Save system initialized (Schema v%d)" % SCHEMA_VERSION)


func _notification(what: int) -> void:
	# Save on app pause/close
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Settings.is_auto_save_enabled():
			_perform_autosave()


# =============================================================================
# PUBLIC API: LOADING STATE CHECK (Story 6-1: AC15)
# =============================================================================

## Check if a load operation is currently in progress.
## Systems should check this to suppress signal emission during load.
## @return True if load is in progress
func is_loading() -> bool:
	return _load_in_progress


# =============================================================================
# SAVE OPERATIONS
# =============================================================================

## Save the game to a specific slot.
## Creates backup of previous save before writing.
## @param slot The save slot number (0 to MAX_SAVE_SLOTS-1)
## @return True if save was successful
func save_game(slot: int = 0) -> bool:
	if _save_in_progress:
		GameLogger.warn("SaveManager", "Save already in progress")
		return false

	if slot < 0 or slot >= GameConstants.MAX_SAVE_SLOTS:
		GameLogger.error("SaveManager", "Invalid save slot: %d" % slot)
		return false

	_save_in_progress = true
	save_started.emit()
	EventBus.save_started.emit()

	# Create backup of existing save (AC19)
	_create_backup(slot)

	var save_data := _gather_save_data()
	var success := _write_save_file(slot, save_data)

	_save_in_progress = false
	save_finished.emit(success)
	EventBus.save_completed.emit(success)

	if success:
		_last_save_slot = slot
		GameLogger.info("SaveManager", "Game saved to slot %d" % slot)
	else:
		GameLogger.error("SaveManager", "Failed to save game to slot %d" % slot)

	return success


## Emergency save to prevent data loss.
## Called by ErrorHandler during critical errors.
func emergency_save() -> void:
	GameLogger.warn("SaveManager", "Performing emergency save...")

	var save_data := _gather_save_data()
	save_data["emergency"] = true
	save_data["emergency_reason"] = "Critical error recovery"

	var path := GameConstants.SAVE_DIRECTORY + GameConstants.EMERGENCY_SAVE_FILE
	var success := _write_json_file(path, save_data)

	if success:
		GameLogger.info("SaveManager", "Emergency save completed: %s" % path)
	else:
		GameLogger.error("SaveManager", "Emergency save FAILED")


## Quick save to last used slot (or slot 0 if none).
func quick_save() -> bool:
	var slot := maxi(_last_save_slot, 0)
	return save_game(slot)


# =============================================================================
# LOAD OPERATIONS
# =============================================================================

## Load the game from a specific slot.
## Attempts backup if primary file is corrupted.
## @param slot The save slot number
## @return True if load was successful
func load_game(slot: int = 0) -> bool:
	if _load_in_progress:
		GameLogger.warn("SaveManager", "Load already in progress")
		return false

	if slot < 0 or slot >= GameConstants.MAX_SAVE_SLOTS:
		GameLogger.error("SaveManager", "Invalid load slot: %d" % slot)
		return false

	if not save_exists(slot):
		GameLogger.warn("SaveManager", "No save found in slot %d" % slot)
		return false

	_load_in_progress = true
	load_started.emit()
	EventBus.load_started.emit()

	var save_data := _read_save_file(slot)

	# Try backup if primary file failed (AC20)
	if save_data.is_empty():
		GameLogger.warn("SaveManager", "Primary save corrupted, trying backup...")
		save_data = _read_backup_file(slot)

	var success := false

	if save_data.is_empty():
		GameLogger.error("SaveManager", "Failed to read save data from slot %d (and backup)" % slot)
	else:
		success = _apply_save_data(save_data)

	_load_in_progress = false
	load_finished.emit(success)
	EventBus.load_completed.emit(success)

	if success:
		_last_save_slot = slot
		# Restore accumulated playtime
		_accumulated_playtime = save_data.get("playtime_seconds", 0.0)
		_session_start_time = Time.get_unix_time_from_system()
		GameLogger.info("SaveManager", "Game loaded from slot %d" % slot)
	else:
		GameLogger.error("SaveManager", "Failed to load game from slot %d" % slot)

	return success


## Load from emergency save if it exists.
## @return True if load was successful
func load_emergency_save() -> bool:
	var path := GameConstants.SAVE_DIRECTORY + GameConstants.EMERGENCY_SAVE_FILE

	if not FileAccess.file_exists(path):
		GameLogger.info("SaveManager", "No emergency save found")
		return false

	_load_in_progress = true
	load_started.emit()
	EventBus.load_started.emit()

	var save_data := _read_json_file(path)
	var success := false

	if not save_data.is_empty():
		success = _apply_save_data(save_data)

	_load_in_progress = false
	load_finished.emit(success)
	EventBus.load_completed.emit(success)

	if success:
		GameLogger.info("SaveManager", "Emergency save loaded successfully")
		# Delete emergency save after successful load
		DirAccess.remove_absolute(path)
	else:
		GameLogger.error("SaveManager", "Failed to load emergency save")

	return success


# =============================================================================
# SAVE SLOT MANAGEMENT
# =============================================================================

## Check if a save exists in the given slot.
func save_exists(slot: int) -> bool:
	var path := _get_save_path(slot)
	return FileAccess.file_exists(path)


## Get save info for a slot without loading the full save.
## @return Dictionary with timestamp, playtime, version, or empty if no save
func get_save_info(slot: int) -> Dictionary:
	if not save_exists(slot):
		return {}

	var save_data := _read_save_file(slot)
	if save_data.is_empty():
		return {}

	return {
		"slot": slot,
		"version": save_data.get("version", 0),
		"timestamp": save_data.get("timestamp", ""),
		"playtime_seconds": save_data.get("playtime_seconds", 0),
	}


## Get info for all save slots.
## @return Array of save info dictionaries
func get_all_save_info() -> Array:
	var saves := []
	for slot in GameConstants.MAX_SAVE_SLOTS:
		var info := get_save_info(slot)
		if not info.is_empty():
			saves.append(info)
	return saves


## Delete a save slot.
func delete_save(slot: int) -> bool:
	var path := _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return false

	var err := DirAccess.remove_absolute(path)
	if err == OK:
		# Also delete backup if exists
		var backup_path := _get_backup_path(slot)
		if FileAccess.file_exists(backup_path):
			DirAccess.remove_absolute(backup_path)
		GameLogger.info("SaveManager", "Deleted save slot %d" % slot)
		return true
	else:
		GameLogger.error("SaveManager", "Failed to delete save slot %d: %s" % [slot, error_string(err)])
		return false


# =============================================================================
# AUTOSAVE
# =============================================================================

## Enable or disable autosave.
func set_autosave_enabled(enabled: bool) -> void:
	Settings.set_auto_save_enabled(enabled)
	if enabled:
		_autosave_timer.start()
	else:
		_autosave_timer.stop()


## Force an immediate autosave.
func force_autosave() -> void:
	_perform_autosave()


# =============================================================================
# INTERNAL: SAVE DATA GATHERING (AC1-9)
# =============================================================================

## Gather all game data into a saveable dictionary.
func _gather_save_data() -> Dictionary:
	var save_data := {
		"version": SCHEMA_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"playtime_seconds": _get_playtime_seconds(),
		"world": _gather_world_data(),
		"buildings": _gather_buildings_data(),
		"animals": _gather_animals_data(),
		"resources": _gather_resources_data(),
		"territory": _gather_territory_data(),
		"wild_herds": _gather_wild_herds_data(),
		"progression": _gather_progression_data(),
	}

	return save_data


## Gather world/territory data.
## NOTE: Detailed territory state is in _gather_territory_data() via TerritoryManager.to_dict()
## This captures high-level world info and fog state.
func _gather_world_data() -> Dictionary:
	var world_data := {
		"fog_revealed": [],
	}

	# TODO: Get fog revealed data from FogOfWar when implemented

	return world_data


## Gather territory data via TerritoryManager.to_dict().
func _gather_territory_data() -> Dictionary:
	var territory_managers := get_tree().get_nodes_in_group("territory_managers")
	if territory_managers.size() > 0:
		var tm: TerritoryManager = territory_managers[0]
		if tm.has_method("to_dict"):
			return tm.to_dict()
	return {}


## Gather wild herd data via WildHerdManager.to_dict().
func _gather_wild_herds_data() -> Dictionary:
	var wild_herd_managers := get_tree().get_nodes_in_group("wild_herd_managers")
	if wild_herd_managers.size() > 0:
		var whm = wild_herd_managers[0]
		if whm.has_method("to_dict"):
			return whm.to_dict()
	return {}


## Gather building data (AC: buildings with workers, production state).
func _gather_buildings_data() -> Array:
	var buildings_data: Array = []

	var buildings := get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if building is Building and building.can_serialize():
			buildings_data.append(building.to_dict())

	return buildings_data


## Gather animal data (AC9: id, type, hex, stats, state, assigned_building).
func _gather_animals_data() -> Array:
	var animals_data: Array = []

	var animals := get_tree().get_nodes_in_group("animals")
	for animal in animals:
		if animal is Animal and animal.can_serialize():
			# Skip wild animals - they're restored via WildHerdManager
			if animal.is_wild:
				continue
			animals_data.append(animal.to_dict())

	return animals_data


## Gather resource data from ResourceManager.
func _gather_resources_data() -> Dictionary:
	if is_instance_valid(ResourceManager):
		return ResourceManager.get_save_data()
	# Fallback if ResourceManager not yet initialized
	return {"resources": {}}


## Gather progression data including milestones and building unlocks.
func _gather_progression_data() -> Dictionary:
	var progression_data := {
		"current_biome": "plains",
	}

	# Get milestone data from MilestoneManager (Story 6-5)
	if is_instance_valid(MilestoneManager):
		progression_data["milestones"] = MilestoneManager.get_save_data()
	else:
		progression_data["milestones"] = {}

	# Get building unlock data from BuildingUnlockManager (Story 6-7)
	if is_instance_valid(BuildingUnlockManager):
		progression_data["building_unlocks"] = BuildingUnlockManager.get_save_data()
	else:
		progression_data["building_unlocks"] = {}

	# Get upgrade bonus data from UpgradeBonusManager (Story 6-8)
	if is_instance_valid(UpgradeBonusManager):
		progression_data["upgrade_bonuses"] = UpgradeBonusManager.get_save_data()
	else:
		progression_data["upgrade_bonuses"] = {}

	return progression_data


## Get total playtime in seconds.
func _get_playtime_seconds() -> float:
	var current_session := Time.get_unix_time_from_system() - _session_start_time
	return _accumulated_playtime + current_session


# =============================================================================
# INTERNAL: SAVE DATA APPLICATION (AC14, AC15)
# =============================================================================

## Apply loaded save data to game systems.
## Follows strict load order for dependency management.
func _apply_save_data(save_data: Dictionary) -> bool:
	# Validate version
	var version := save_data.get("version", 0) as int
	if version > SCHEMA_VERSION:
		GameLogger.error("SaveManager", "Save version %d is newer than supported %d" % [version, SCHEMA_VERSION])
		return false

	# Migrate if needed (AC18)
	if version < SCHEMA_VERSION:
		save_data = _migrate_save_data(save_data, version)

	# Validate required sections
	if not _validate_save_structure(save_data):
		return false

	# Apply data in dependency order (AC14)
	GameLogger.info("SaveManager", "Applying save data (v%d) in load order..." % version)

	# 1. Resources first (no dependencies)
	if save_data.has("resources"):
		_apply_resources_data(save_data["resources"])

	# 2. Territory (needs HexGrid which is always available)
	if save_data.has("territory"):
		_apply_territory_data(save_data["territory"])

	# 3. Buildings (needs territory for ownership context)
	if save_data.has("buildings"):
		_apply_buildings_data(save_data["buildings"])

	# 4. Animals (needs buildings for assignments)
	if save_data.has("animals"):
		_apply_animals_data(save_data["animals"])

	# 5. Wild herds (needs territory)
	if save_data.has("wild_herds"):
		_apply_wild_herds_data(save_data["wild_herds"])

	# 6. Progression (last, depends on other systems)
	if save_data.has("progression"):
		_apply_progression_data(save_data["progression"])

	GameLogger.info("SaveManager", "Save data applied successfully")
	return true


## Validate save data has required structure.
func _validate_save_structure(save_data: Dictionary) -> bool:
	var required_keys := ["version", "resources"]
	for key in required_keys:
		if not save_data.has(key):
			GameLogger.error("SaveManager", "Save data missing required key: %s" % key)
			return false
	return true


## Apply resources data.
func _apply_resources_data(data: Dictionary) -> void:
	if is_instance_valid(ResourceManager):
		ResourceManager.load_save_data(data)
		GameLogger.debug("SaveManager", "Resources restored")


## Apply territory data.
func _apply_territory_data(data: Dictionary) -> void:
	var territory_managers := get_tree().get_nodes_in_group("territory_managers")
	if territory_managers.size() > 0:
		var tm: TerritoryManager = territory_managers[0]
		if tm.has_method("from_dict"):
			tm.from_dict(data)
			GameLogger.debug("SaveManager", "Territory restored")


## Apply wild herds data.
func _apply_wild_herds_data(data: Dictionary) -> void:
	var wild_herd_managers := get_tree().get_nodes_in_group("wild_herd_managers")
	if wild_herd_managers.size() > 0:
		var whm = wild_herd_managers[0]
		if whm.has_method("from_dict"):
			whm.from_dict(data)
			GameLogger.debug("SaveManager", "Wild herds restored")


## Apply buildings data.
## NOTE: Building recreation requires BuildingFactory (to be implemented in detail).
func _apply_buildings_data(data: Array) -> void:
	# TODO: Implement building recreation from save data
	# This requires:
	# 1. Clear existing buildings
	# 2. Recreate each building from saved type and position
	# 3. Restore worker assignments after animals are restored
	GameLogger.debug("SaveManager", "Buildings restoration: %d buildings (stub)" % data.size())


## Apply animals data.
## NOTE: Animal recreation requires AnimalFactory.
func _apply_animals_data(data: Array) -> void:
	# TODO: Implement animal recreation from save data
	# This requires:
	# 1. Clear existing player animals
	# 2. Recreate each animal from saved type and position
	# 3. Restore stats and AI state
	# 4. Restore building assignments (buildings must be restored first)
	GameLogger.debug("SaveManager", "Animals restoration: %d animals (stub)" % data.size())


## Apply progression data including milestones and building unlocks.
func _apply_progression_data(data: Dictionary) -> void:
	# Load milestone data (Story 6-5)
	if is_instance_valid(MilestoneManager) and data.has("milestones"):
		MilestoneManager.load_save_data(data["milestones"])
		GameLogger.debug("SaveManager", "Milestones restored")
	else:
		GameLogger.debug("SaveManager", "No milestone data to restore")

	# Load building unlock data (Story 6-7)
	if is_instance_valid(BuildingUnlockManager) and data.has("building_unlocks"):
		BuildingUnlockManager.load_save_data(data["building_unlocks"])
		GameLogger.debug("SaveManager", "Building unlocks restored")
	else:
		GameLogger.debug("SaveManager", "No building unlock data to restore")

	# Load upgrade bonus data (Story 6-8)
	if is_instance_valid(UpgradeBonusManager) and data.has("upgrade_bonuses"):
		UpgradeBonusManager.load_save_data(data["upgrade_bonuses"])
		GameLogger.debug("SaveManager", "Upgrade bonuses restored")
	else:
		GameLogger.debug("SaveManager", "No upgrade bonus data to restore")


## Migrate save data from older versions.
func _migrate_save_data(save_data: Dictionary, from_version: int) -> Dictionary:
	GameLogger.info("SaveManager", "Migrating save from v%d to v%d" % [from_version, SCHEMA_VERSION])

	# Add migration steps as schema evolves
	# Example:
	# if from_version < 2:
	#     save_data["new_field"] = default_value

	save_data["version"] = SCHEMA_VERSION
	return save_data


# =============================================================================
# INTERNAL: FILE OPERATIONS
# =============================================================================

## Ensure save directory exists.
func _ensure_save_directory() -> void:
	var dir := DirAccess.open("user://")
	if dir == null:
		GameLogger.error("SaveManager", "Cannot access user directory")
		return

	if not dir.dir_exists("saves"):
		var err := dir.make_dir("saves")
		if err != OK:
			GameLogger.error("SaveManager", "Failed to create saves directory: %s" % error_string(err))


## Get the file path for a save slot.
func _get_save_path(slot: int) -> String:
	return SAVE_PATH_TEMPLATE % slot


## Get the backup path for a save slot.
func _get_backup_path(slot: int) -> String:
	return BACKUP_PATH_TEMPLATE % slot


## Create backup of existing save (AC19).
func _create_backup(slot: int) -> void:
	var primary_path := _get_save_path(slot)
	var backup_path := _get_backup_path(slot)

	if not FileAccess.file_exists(primary_path):
		return

	# Read existing save
	var file := FileAccess.open(primary_path, FileAccess.READ)
	if file == null:
		GameLogger.warn("SaveManager", "Cannot open primary save for backup")
		return

	var content := file.get_as_text()
	file.close()

	# Write to backup
	var backup_file := FileAccess.open(backup_path, FileAccess.WRITE)
	if backup_file == null:
		GameLogger.warn("SaveManager", "Cannot create backup file")
		return

	backup_file.store_string(content)
	backup_file.close()

	GameLogger.debug("SaveManager", "Backup created for slot %d" % slot)


## Read backup file.
func _read_backup_file(slot: int) -> Dictionary:
	var backup_path := _get_backup_path(slot)
	return _read_json_file(backup_path)


## Write save data to a slot.
func _write_save_file(slot: int, save_data: Dictionary) -> bool:
	var path := _get_save_path(slot)
	return _write_json_file(path, save_data)


## Read save data from a slot.
func _read_save_file(slot: int) -> Dictionary:
	var path := _get_save_path(slot)
	return _read_json_file(path)


## Write a dictionary to a JSON file.
func _write_json_file(path: String, data: Dictionary) -> bool:
	var json_string := JSON.stringify(data, "  ")

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		GameLogger.error("SaveManager", "Cannot open file for writing: %s" % path)
		return false

	file.store_string(json_string)
	file.close()
	return true


## Read a JSON file into a dictionary.
## Returns empty dictionary on failure (AC16: graceful error handling).
func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		GameLogger.error("SaveManager", "Cannot open file for reading: %s" % path)
		return {}

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		GameLogger.error("SaveManager", "JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return {}

	var data = json.get_data()
	if data is Dictionary:
		return data
	else:
		GameLogger.error("SaveManager", "Save file is not a valid dictionary")
		return {}


# =============================================================================
# INTERNAL: AUTOSAVE
# =============================================================================

## Setup autosave timer.
func _setup_autosave_timer() -> void:
	_autosave_timer = Timer.new()
	_autosave_timer.name = "AutosaveTimer"
	_autosave_timer.wait_time = GameConstants.AUTOSAVE_INTERVAL
	_autosave_timer.one_shot = false
	_autosave_timer.timeout.connect(_perform_autosave)
	add_child(_autosave_timer)
	# Timer will be started in _start_autosave_if_enabled() after Settings loads


## Start autosave timer if enabled in Settings.
## Called deferred from _ready() to ensure Settings has loaded.
func _start_autosave_if_enabled() -> void:
	if is_instance_valid(Settings) and Settings.is_auto_save_enabled():
		_autosave_timer.start()
		GameLogger.debug("SaveManager", "Autosave timer started (interval: %.0fs)" % GameConstants.AUTOSAVE_INTERVAL)


## Perform an autosave.
## Skips if auto-save disabled, load in progress, or save already in progress.
func _perform_autosave() -> void:
	if not Settings.is_auto_save_enabled():
		return

	# Don't auto-save during load to prevent data corruption (Story 6-2: AC3)
	if _load_in_progress:
		GameLogger.debug("SaveManager", "Autosave skipped: load in progress")
		return

	GameLogger.debug("SaveManager", "Autosave triggered")
	quick_save()


## Handle game pause event for autosave.
func _on_game_paused() -> void:
	if Settings.is_auto_save_enabled():
		_perform_autosave()
