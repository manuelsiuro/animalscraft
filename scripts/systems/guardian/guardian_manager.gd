## GuardianManager - Manages biome guardian spawning, tracking, and defeat state.
## Guardians are powerful mini-bosses that guard biome transitions.
## Defeating a guardian permanently removes it and unlocks the associated biome.
##
## Architecture: scripts/systems/guardian/guardian_manager.gd
## Story: 7-2-implement-alpha-fox-guardian
##
## Usage:
##   # Guardian spawns automatically when milestone is reached
##   # EventBus.milestone_reached triggers spawn check
##
##   # Query guardian state
##   if guardian_manager.is_guardian_defeated("alpha_fox"):
##       pass  # Forest biome should be unlocked
##
##   # Get active guardian for combat
##   var guardian = guardian_manager.get_active_guardian("alpha_fox")
class_name GuardianManager
extends Node

# =============================================================================
# CONSTANTS
# =============================================================================

## Path to guardian resource files
const GUARDIANS_PATH: String = "res://resources/guardians/"

## Path to guardian scene files
const GUARDIAN_SCENES_PATH: String = "res://scenes/entities/guardians/"

## Preloaded guardian scenes by guardian_id
const GUARDIAN_SCENES: Dictionary = {
	"alpha_fox": preload("res://scenes/entities/guardians/alpha_fox.tscn"),
}

# =============================================================================
# PROPERTIES
# =============================================================================

## All loaded guardian data (guardian_id -> GuardianData)
var _guardians: Dictionary = {}

## Set of defeated guardian IDs (guardian_id -> true)
var _defeated: Dictionary = {}

## Active guardian instances (guardian_id -> Animal node)
var _active_guardians: Dictionary = {}

## Flag to prevent signal handling during load
var _loading: bool = false

## Reference to WorldManager for hex grid access
var _world_manager: Node = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	add_to_group("guardian_managers")
	_load_guardians()
	_connect_signals()
	GameLogger.info("GuardianManager", "Initialized with %d guardian definitions" % _guardians.size())


func _exit_tree() -> void:
	_disconnect_signals()


## Initialize with WorldManager reference.
## @param world_manager The WorldManager for hex grid access
func initialize(world_manager: Node) -> void:
	if world_manager == null:
		GameLogger.error("GuardianManager", "Cannot initialize with null WorldManager")
		return

	_world_manager = world_manager
	GameLogger.info("GuardianManager", "GuardianManager initialized with WorldManager")


## Load all guardian resources from the guardians directory.
func _load_guardians() -> void:
	var dir := DirAccess.open(GUARDIANS_PATH)
	if dir == null:
		GameLogger.warn("GuardianManager", "Cannot open guardians directory: %s" % GUARDIANS_PATH)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var path := GUARDIANS_PATH + file_name
			var guardian := load(path) as GuardianData
			if guardian and guardian.guardian_id != "":
				_guardians[guardian.guardian_id] = guardian
				GameLogger.debug("GuardianManager", "Loaded guardian: %s" % guardian.guardian_id)
		file_name = dir.get_next()

	dir.list_dir_end()


## Connect to EventBus signals.
func _connect_signals() -> void:
	EventBus.milestone_reached.connect(_on_milestone_reached)
	EventBus.combat_ended.connect(_on_combat_ended)


## Disconnect from EventBus signals.
func _disconnect_signals() -> void:
	if EventBus.milestone_reached.is_connected(_on_milestone_reached):
		EventBus.milestone_reached.disconnect(_on_milestone_reached)
	if EventBus.combat_ended.is_connected(_on_combat_ended):
		EventBus.combat_ended.disconnect(_on_combat_ended)

# =============================================================================
# PUBLIC API
# =============================================================================

## Check if a guardian has been defeated.
## @param guardian_id The guardian ID to check
## @return True if defeated
func is_guardian_defeated(guardian_id: String) -> bool:
	return _defeated.has(guardian_id)


## Get an active guardian instance by ID.
## @param guardian_id The guardian ID
## @return Animal node or null if not spawned/defeated
func get_active_guardian(guardian_id: String) -> Node:
	return _active_guardians.get(guardian_id, null)


## Get guardian data by ID.
## @param guardian_id The guardian ID
## @return GuardianData or null if not found
func get_guardian_data(guardian_id: String) -> GuardianData:
	return _guardians.get(guardian_id, null)


## Get all guardian data (for UI display).
## @return Array of GuardianData resources
func get_all_guardians() -> Array[GuardianData]:
	var result: Array[GuardianData] = []
	for id in _guardians:
		result.append(_guardians[id])
	return result


## Get hex coordinate where a guardian is located.
## @param guardian_id The guardian ID
## @return Vector2i hex coordinate or Vector2i.ZERO if not active
func get_guardian_hex(guardian_id: String) -> Vector2i:
	var guardian_data := get_guardian_data(guardian_id)
	if guardian_data:
		return guardian_data.spawn_hex
	return Vector2i.ZERO


## Check if a hex contains an active guardian.
## @param hex_coord The hex coordinate to check
## @return String guardian_id if present, empty string if not
func get_guardian_at_hex(hex_coord: Vector2i) -> String:
	for guardian_id in _active_guardians:
		var guardian_data := get_guardian_data(guardian_id)
		if guardian_data and guardian_data.spawn_hex == hex_coord:
			return guardian_id
	return ""

# =============================================================================
# SPAWNING
# =============================================================================

## Spawn a guardian at its designated location.
## @param guardian_id The guardian to spawn
## @return True if spawned successfully
func spawn_guardian(guardian_id: String) -> bool:
	# Guard: check if already spawned
	if _active_guardians.has(guardian_id):
		GameLogger.warn("GuardianManager", "Guardian %s already spawned" % guardian_id)
		return false

	# Guard: check if defeated
	if _defeated.has(guardian_id):
		GameLogger.debug("GuardianManager", "Guardian %s already defeated, not spawning" % guardian_id)
		return false

	# Get guardian data
	var guardian_data := get_guardian_data(guardian_id)
	if not guardian_data:
		GameLogger.error("GuardianManager", "Unknown guardian: %s" % guardian_id)
		return false

	# Get guardian scene
	if not GUARDIAN_SCENES.has(guardian_id):
		GameLogger.error("GuardianManager", "No scene for guardian: %s" % guardian_id)
		return false

	var scene: PackedScene = GUARDIAN_SCENES[guardian_id]
	var guardian := scene.instantiate()

	if not guardian:
		GameLogger.error("GuardianManager", "Failed to instantiate guardian: %s" % guardian_id)
		return false

	# Initialize guardian with data
	var hex := HexCoord.from_vector(guardian_data.spawn_hex)
	if guardian.has_method("initialize"):
		guardian.call_deferred("initialize", hex, guardian_data)

	# Mark as wild (guardians are like wild animals but stronger)
	if "is_wild" in guardian:
		guardian.is_wild = true

	# Add to scene tree
	if _world_manager:
		_world_manager.add_child(guardian)
	else:
		# Fallback: add to root
		var root := get_tree().root
		if root:
			root.add_child(guardian)

	# Track active guardian
	_active_guardians[guardian_id] = guardian

	# Emit spawn signal
	EventBus.guardian_spawned.emit(guardian_id, guardian_data.spawn_hex)

	GameLogger.info("GuardianManager", "Spawned guardian %s at %s" % [guardian_id, guardian_data.spawn_hex])
	return true


## Remove a guardian from the world (after defeat).
## @param guardian_id The guardian to remove
func _remove_guardian(guardian_id: String) -> void:
	if not _active_guardians.has(guardian_id):
		return

	var guardian: Node = _active_guardians[guardian_id]
	if is_instance_valid(guardian):
		guardian.queue_free()

	_active_guardians.erase(guardian_id)
	GameLogger.debug("GuardianManager", "Removed guardian: %s" % guardian_id)

# =============================================================================
# DEFEAT PROCESSING
# =============================================================================

## Mark a guardian as defeated and trigger biome unlock.
## @param guardian_id The guardian that was defeated
func defeat_guardian(guardian_id: String) -> void:
	if _defeated.has(guardian_id):
		return  # Already defeated

	var guardian_data := get_guardian_data(guardian_id)
	if not guardian_data:
		GameLogger.error("GuardianManager", "Cannot defeat unknown guardian: %s" % guardian_id)
		return

	# Mark as permanently defeated
	_defeated[guardian_id] = true

	# Remove from world
	_remove_guardian(guardian_id)

	# Emit guardian defeated signal
	EventBus.guardian_defeated.emit(guardian_id, guardian_data.unlocks_biome)

	# Unlock the biome via BiomeManager
	if BiomeManager:
		BiomeManager.unlock_biome(guardian_data.unlocks_biome)

	GameLogger.info("GuardianManager", "Guardian %s defeated! Unlocking biome: %s" % [guardian_id, guardian_data.unlocks_biome])

# =============================================================================
# SAVE/LOAD INTEGRATION (AC9)
# =============================================================================

## Get save data for persistence.
## @return Dictionary with guardian state
func get_save_data() -> Dictionary:
	var active_list: Array[String] = []
	for id in _active_guardians.keys():
		active_list.append(id)

	var defeated_list: Array[String] = []
	for id in _defeated.keys():
		defeated_list.append(id)

	return {
		"defeated": defeated_list,
		"active": active_list,
	}


## Load save data to restore guardian state.
## @param data Dictionary from get_save_data()
func load_save_data(data: Dictionary) -> void:
	_loading = true

	# Clear current state
	for guardian_id in _active_guardians.keys():
		_remove_guardian(guardian_id)
	_active_guardians.clear()
	_defeated.clear()

	# Restore defeated guardians
	var defeated_list: Array = data.get("defeated", [])
	for id in defeated_list:
		_defeated[id] = true

	# Restore active guardians (spawn them)
	var active_list: Array = data.get("active", [])
	for id in active_list:
		if not _defeated.has(id):
			spawn_guardian(id)

	_loading = false
	GameLogger.info("GuardianManager", "Loaded guardian state: %d defeated, %d active" % [_defeated.size(), _active_guardians.size()])


## Reset all guardian progress (for new game).
func reset() -> void:
	# Remove all active guardians
	for guardian_id in _active_guardians.keys():
		_remove_guardian(guardian_id)
	_active_guardians.clear()
	_defeated.clear()
	GameLogger.info("GuardianManager", "Guardian progress reset")

# =============================================================================
# EVENT HANDLERS
# =============================================================================

## Handle milestone reached event to check for guardian spawning.
func _on_milestone_reached(milestone_id: String) -> void:
	if _loading:
		return

	# Check if any guardian should spawn from this milestone
	for id in _guardians:
		var guardian_data: GuardianData = _guardians[id]
		if guardian_data.spawn_milestone == milestone_id:
			spawn_guardian(id)


## Handle combat ended event to check for guardian defeat.
## This checks if the combat was against a guardian.
func _on_combat_ended(won: bool, _captured_animals: Array) -> void:
	if _loading:
		return

	if not won:
		return  # Only process victories

	# Check if combat was at a guardian hex
	# We need to get the combat hex from CombatManager
	var combat_managers := get_tree().get_nodes_in_group("combat_managers")
	if combat_managers.is_empty():
		return

	var combat_manager = combat_managers[0]
	# Note: We need to check the hex before combat state is reset
	# The combat_ended signal is emitted before state reset, so we can check
	# However, CombatManager resets state in _process_victory before emitting
	# So we need an alternative approach - check active guardians location

	# Alternative: Check if any active guardian is no longer in our tracking
	# This happens because combat with guardian removes the herd but not the guardian
	# We need a more direct approach - store the combat hex

	# For now, we'll rely on the guardian battle UI to call defeat_guardian directly
	# This will be implemented in Task 6 (Combat Integration)
	pass
