## Manages biome unlock state and provides biome queries.
## Autoload singleton - access via BiomeManager.method()
##
## Biomes are unlockable game regions. Plains starts unlocked as the
## starting biome. Forest is unlocked when the forest_border milestone
## is achieved (80% territory claimed).
##
## Architecture: autoloads/biome_manager.gd
## Order: 9 (depends on EventBus, MilestoneManager)
## Story: 6-11-implement-biome-unlock-preparation
##
## NOTE: No class_name to avoid conflict with autoload singleton
extends Node

# =============================================================================
# CONSTANTS
# =============================================================================

## Path to biome resource files
const BIOMES_PATH: String = "res://resources/biomes/"

# =============================================================================
# STATE
# =============================================================================

## All loaded biome definitions (id -> BiomeData)
var _biomes: Dictionary = {}

## Set of unlocked biome IDs (id -> true)
var _unlocked: Dictionary = {}

## Flag to prevent signal handling during load
var _loading: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_load_biomes()
	_initialize_starting_biomes()
	_connect_signals()
	GameLogger.info("BiomeManager", "Initialized with %d biomes (%d unlocked)" % [_biomes.size(), _unlocked.size()])


func _exit_tree() -> void:
	_disconnect_signals()


## Load all biome resources from the biomes directory.
func _load_biomes() -> void:
	var dir := DirAccess.open(BIOMES_PATH)
	if dir == null:
		GameLogger.warn("BiomeManager", "Cannot open biomes directory: %s" % BIOMES_PATH)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var path := BIOMES_PATH + file_name
			var biome := load(path) as BiomeData
			if biome and biome.id != "":
				_biomes[biome.id] = biome
				GameLogger.debug("BiomeManager", "Loaded biome: %s" % biome.id)
		file_name = dir.get_next()

	dir.list_dir_end()


## Initialize starting biomes as unlocked.
func _initialize_starting_biomes() -> void:
	for id in _biomes:
		var biome: BiomeData = _biomes[id]
		if biome.is_starting_biome:
			_unlocked[id] = true
			GameLogger.debug("BiomeManager", "Starting biome unlocked: %s" % id)


## Connect to EventBus signals for milestone tracking.
func _connect_signals() -> void:
	EventBus.milestone_reached.connect(_on_milestone_reached)


## Disconnect from EventBus signals.
func _disconnect_signals() -> void:
	if EventBus.milestone_reached.is_connected(_on_milestone_reached):
		EventBus.milestone_reached.disconnect(_on_milestone_reached)


# =============================================================================
# PUBLIC API
# =============================================================================

## Check if a specific biome is unlocked.
## @param biome_id The biome ID to check
## @return True if unlocked
func is_biome_unlocked(biome_id: String) -> bool:
	return _unlocked.has(biome_id)


## Get list of all unlocked biome IDs.
## @return Array of biome ID strings
func get_unlocked_biomes() -> Array[String]:
	var result: Array[String] = []
	for id in _unlocked.keys():
		result.append(id)
	return result


## Unlock a biome by ID.
## Emits biome_unlocked signal if not already unlocked.
## @param biome_id The biome ID to unlock
func unlock_biome(biome_id: String) -> void:
	if _unlocked.has(biome_id):
		return  # Already unlocked - don't re-trigger

	if not _biomes.has(biome_id):
		GameLogger.warn("BiomeManager", "Cannot unlock unknown biome: %s" % biome_id)
		return

	_unlocked[biome_id] = true
	GameLogger.info("BiomeManager", "Biome unlocked: %s" % biome_id)

	# Emit to EventBus for game-wide notification
	EventBus.biome_unlocked.emit(biome_id)


## Get a specific biome by ID.
## @param biome_id The biome ID
## @return BiomeData or null if not found
func get_biome(biome_id: String) -> BiomeData:
	return _biomes.get(biome_id, null)


## Get all biome data (for UI display).
## @return Array of BiomeData resources
func get_all_biomes() -> Array[BiomeData]:
	var result: Array[BiomeData] = []
	for id in _biomes:
		result.append(_biomes[id])
	return result


# =============================================================================
# SAVE/LOAD INTEGRATION
# =============================================================================

## Get save data for persistence.
## @return Dictionary with biome state
func get_save_data() -> Dictionary:
	return {
		"unlocked": get_unlocked_biomes(),
	}


## Load save data to restore biome state.
## @param data Dictionary from get_save_data()
func load_save_data(data: Dictionary) -> void:
	_loading = true

	# Restore unlocked biomes
	_unlocked.clear()

	# Always restore starting biomes first
	_initialize_starting_biomes()

	# Then restore saved unlocks
	var unlocked_list: Array = data.get("unlocked", [])
	for id in unlocked_list:
		if _biomes.has(id):
			_unlocked[id] = true

	_loading = false
	GameLogger.info("BiomeManager", "Loaded %d unlocked biomes" % _unlocked.size())


## Reset all biome progress (for new game).
func reset() -> void:
	_unlocked.clear()
	_initialize_starting_biomes()
	GameLogger.info("BiomeManager", "Biome progress reset")


# =============================================================================
# EVENT HANDLERS
# =============================================================================

## Handle milestone reached event.
## Checks if milestone unlocks any biome.
func _on_milestone_reached(milestone_id: String) -> void:
	if _loading:
		return

	# Check if any biome is unlocked by this milestone
	for id in _biomes:
		var biome: BiomeData = _biomes[id]
		if biome.unlock_milestone == milestone_id:
			unlock_biome(id)
