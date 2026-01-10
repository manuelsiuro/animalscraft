## Save/Load system for AnimalsCraft.
## Autoload singleton - access via SaveManager.save_game/load_game
##
## Architecture: autoloads/save_manager.gd
## Order: 7 (depends on Logger, EventBus)
## Source: game-architecture.md#Save System Schema
##
## Handles game persistence with JSON format, auto-save, and versioning.
class_name SaveManager
extends Node

# =============================================================================
# SIGNALS
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

## Current save schema version.
## Increment when save format changes.
const SCHEMA_VERSION: int = 1

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Auto-save timer
var _autosave_timer: Timer = null

## Track if a save is in progress
var _save_in_progress: bool = false

## Track if a load is in progress
var _load_in_progress: bool = false

## Last successful save slot
var _last_save_slot: int = -1

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_ensure_save_directory()
	_setup_autosave_timer()

	# Listen for game events that should trigger save
	EventBus.game_paused.connect(_on_game_paused)

	# Defer timer start to ensure Settings has loaded its config
	# (Settings loads in _ready too, so we can't guarantee order)
	call_deferred("_start_autosave_if_enabled")

	Logger.info("SaveManager", "Save system initialized")


func _notification(what: int) -> void:
	# Save on app pause/close
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if Settings.is_auto_save_enabled():
			_perform_autosave()


# =============================================================================
# SAVE OPERATIONS
# =============================================================================

## Save the game to a specific slot.
## @param slot The save slot number (0 to MAX_SAVE_SLOTS-1)
## @return True if save was successful
func save_game(slot: int = 0) -> bool:
	if _save_in_progress:
		Logger.warn("SaveManager", "Save already in progress")
		return false

	if slot < 0 or slot >= GameConstants.MAX_SAVE_SLOTS:
		Logger.error("SaveManager", "Invalid save slot: %d" % slot)
		return false

	_save_in_progress = true
	save_started.emit()

	var save_data := _gather_save_data()
	var success := _write_save_file(slot, save_data)

	_save_in_progress = false
	save_finished.emit(success)
	EventBus.save_completed.emit(success)

	if success:
		_last_save_slot = slot
		Logger.info("SaveManager", "Game saved to slot %d" % slot)
	else:
		Logger.error("SaveManager", "Failed to save game to slot %d" % slot)

	return success


## Emergency save to prevent data loss.
## Called by ErrorHandler during critical errors.
func emergency_save() -> void:
	Logger.warn("SaveManager", "Performing emergency save...")

	var save_data := _gather_save_data()
	save_data["emergency"] = true
	save_data["emergency_reason"] = "Critical error recovery"

	var path := GameConstants.SAVE_DIRECTORY + GameConstants.EMERGENCY_SAVE_FILE
	var success := _write_json_file(path, save_data)

	if success:
		Logger.info("SaveManager", "Emergency save completed: %s" % path)
	else:
		Logger.error("SaveManager", "Emergency save FAILED")


## Quick save to last used slot (or slot 0 if none).
func quick_save() -> bool:
	var slot := maxi(_last_save_slot, 0)
	return save_game(slot)


# =============================================================================
# LOAD OPERATIONS
# =============================================================================

## Load the game from a specific slot.
## @param slot The save slot number
## @return True if load was successful
func load_game(slot: int = 0) -> bool:
	if _load_in_progress:
		Logger.warn("SaveManager", "Load already in progress")
		return false

	if slot < 0 or slot >= GameConstants.MAX_SAVE_SLOTS:
		Logger.error("SaveManager", "Invalid load slot: %d" % slot)
		return false

	if not save_exists(slot):
		Logger.warn("SaveManager", "No save found in slot %d" % slot)
		return false

	_load_in_progress = true
	load_started.emit()

	var save_data := _read_save_file(slot)
	var success := false

	if save_data.is_empty():
		Logger.error("SaveManager", "Failed to read save data from slot %d" % slot)
	else:
		success = _apply_save_data(save_data)

	_load_in_progress = false
	load_finished.emit(success)
	EventBus.load_completed.emit(success)

	if success:
		_last_save_slot = slot
		Logger.info("SaveManager", "Game loaded from slot %d" % slot)
	else:
		Logger.error("SaveManager", "Failed to load game from slot %d" % slot)

	return success


## Load from emergency save if it exists.
## @return True if load was successful
func load_emergency_save() -> bool:
	var path := GameConstants.SAVE_DIRECTORY + GameConstants.EMERGENCY_SAVE_FILE

	if not FileAccess.file_exists(path):
		Logger.info("SaveManager", "No emergency save found")
		return false

	_load_in_progress = true
	load_started.emit()

	var save_data := _read_json_file(path)
	var success := false

	if not save_data.is_empty():
		success = _apply_save_data(save_data)

	_load_in_progress = false
	load_finished.emit(success)
	EventBus.load_completed.emit(success)

	if success:
		Logger.info("SaveManager", "Emergency save loaded successfully")
		# Delete emergency save after successful load
		DirAccess.remove_absolute(path)
	else:
		Logger.error("SaveManager", "Failed to load emergency save")

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
		Logger.info("SaveManager", "Deleted save slot %d" % slot)
		return true
	else:
		Logger.error("SaveManager", "Failed to delete save slot %d: %s" % [slot, error_string(err)])
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
# INTERNAL: SAVE DATA GATHERING
# =============================================================================

## Gather all game data into a saveable dictionary.
func _gather_save_data() -> Dictionary:
	var save_data := {
		"version": SCHEMA_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"playtime_seconds": _get_playtime_seconds(),
		"world": _gather_world_data(),
		"animals": _gather_animals_data(),
		"resources": _gather_resources_data(),
		"progression": _gather_progression_data(),
	}

	# Warn if we're saving placeholder/empty data (systems not yet implemented)
	if save_data["animals"].is_empty():
		Logger.warn("SaveManager", "Saving with empty animals data (system not yet implemented)")
	if save_data["world"]["buildings"].is_empty():
		Logger.warn("SaveManager", "Saving with empty buildings data (system not yet implemented)")

	return save_data


## Gather world/territory data.
func _gather_world_data() -> Dictionary:
	# TODO: Implement when world systems exist (Epic 1)
	# Currently returns placeholder empty data
	return {
		"claimed_hexes": [],
		"fog_revealed": [],
		"buildings": [],
	}


## Gather animal data.
func _gather_animals_data() -> Array:
	# TODO: Implement when animal systems exist (Epic 2)
	# Currently returns placeholder empty data
	return []


## Gather resource data.
func _gather_resources_data() -> Dictionary:
	# TODO: Implement when resource systems exist (Epic 3)
	# Currently returns placeholder zero values
	return {
		"wood": 0,
		"wheat": 0,
		"flour": 0,
		"bread": 0,
	}


## Gather progression data.
func _gather_progression_data() -> Dictionary:
	# TODO: Implement when progression systems exist (Epic 6)
	# Currently returns placeholder default values
	return {
		"milestones": [],
		"unlocks": [],
		"current_biome": "plains",
	}


## Get total playtime in seconds.
func _get_playtime_seconds() -> int:
	# TODO: Get actual playtime from GameManager
	# For now, return 0 (GameManager.get_playtime_seconds() will be implemented)
	if is_instance_valid(GameManager):
		return int(GameManager.get_playtime_seconds())
	return 0


# =============================================================================
# INTERNAL: SAVE DATA APPLICATION
# =============================================================================

## Apply loaded save data to game systems.
func _apply_save_data(save_data: Dictionary) -> bool:
	# Validate version
	var version := save_data.get("version", 0) as int
	if version > SCHEMA_VERSION:
		Logger.error("SaveManager", "Save version %d is newer than supported %d" % [version, SCHEMA_VERSION])
		return false

	# Migrate if needed
	if version < SCHEMA_VERSION:
		save_data = _migrate_save_data(save_data, version)

	# Apply data to systems (will be implemented as systems are built)
	# For now, just validate the structure
	if not save_data.has("world"):
		return false
	if not save_data.has("animals"):
		return false
	if not save_data.has("resources"):
		return false
	if not save_data.has("progression"):
		return false

	return true


## Migrate save data from older versions.
func _migrate_save_data(save_data: Dictionary, from_version: int) -> Dictionary:
	Logger.info("SaveManager", "Migrating save from v%d to v%d" % [from_version, SCHEMA_VERSION])

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
		Logger.error("SaveManager", "Cannot access user directory")
		return

	if not dir.dir_exists("saves"):
		var err := dir.make_dir("saves")
		if err != OK:
			Logger.error("SaveManager", "Failed to create saves directory: %s" % error_string(err))


## Get the file path for a save slot.
func _get_save_path(slot: int) -> String:
	return "%ssave_%d.json" % [GameConstants.SAVE_DIRECTORY, slot]


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
		Logger.error("SaveManager", "Cannot open file for writing: %s" % path)
		return false

	file.store_string(json_string)
	file.close()
	return true


## Read a JSON file into a dictionary.
func _read_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		Logger.error("SaveManager", "Cannot open file for reading: %s" % path)
		return {}

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_string)
	if err != OK:
		Logger.error("SaveManager", "JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return {}

	var data = json.get_data()
	if data is Dictionary:
		return data
	else:
		Logger.error("SaveManager", "Save file is not a valid dictionary")
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
		Logger.debug("SaveManager", "Autosave timer started (interval: %.0fs)" % GameConstants.AUTOSAVE_INTERVAL)


## Perform an autosave.
func _perform_autosave() -> void:
	if not Settings.is_auto_save_enabled():
		return

	Logger.debug("SaveManager", "Autosave triggered")
	quick_save()


## Handle game pause event for autosave.
func _on_game_paused() -> void:
	if Settings.is_auto_save_enabled():
		_perform_autosave()
