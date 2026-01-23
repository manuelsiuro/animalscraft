## Manages milestone tracking and achievement detection.
## Autoload singleton - access via MilestoneManager.method()
##
## Milestones track player progress across population, buildings, territory,
## combat, and production. Achievements persist via SaveManager integration.
##
## Architecture: autoloads/milestone_manager.gd
## Order: 8 (depends on EventBus, SaveManager)
## Story: 6-5-implement-milestone-system
##
## NOTE: No class_name to avoid conflict with autoload singleton
extends Node

# =============================================================================
# CONSTANTS
# =============================================================================

## Path to milestone resource files
const MILESTONES_PATH: String = "res://resources/milestones/"

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted internally before EventBus.milestone_reached (for testing)
signal _milestone_triggered(milestone_id: String)

# =============================================================================
# STATE
# =============================================================================

## All loaded milestone definitions (id -> MilestoneData)
var _milestones: Dictionary = {}

## Set of achieved milestone IDs (id -> true)
var _achieved: Dictionary = {}

## Current counts for threshold tracking
var _counts: Dictionary = {
	"population": 0,
	"territory": 0,
	"combat_wins": 0,
}

## First-time tracking for unique milestones (building_type -> true)
var _first_buildings: Dictionary = {}

## First-time tracking for production milestones (output_type -> true)
var _first_productions: Dictionary = {}

## Flag to prevent signal handling during load
var _loading: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_load_milestones()
	_connect_signals()
	GameLogger.info("MilestoneManager", "Initialized with %d milestones" % _milestones.size())


func _exit_tree() -> void:
	_disconnect_signals()


## Load all milestone resources from the milestones directory.
func _load_milestones() -> void:
	var dir := DirAccess.open(MILESTONES_PATH)
	if dir == null:
		GameLogger.warn("MilestoneManager", "Cannot open milestones directory: %s" % MILESTONES_PATH)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if file_name.ends_with(".tres"):
			var path := MILESTONES_PATH + file_name
			var milestone := load(path) as MilestoneData
			if milestone and milestone.id != "":
				_milestones[milestone.id] = milestone
				GameLogger.debug("MilestoneManager", "Loaded milestone: %s" % milestone.id)
		file_name = dir.get_next()

	dir.list_dir_end()


## Connect to EventBus signals for milestone tracking.
func _connect_signals() -> void:
	EventBus.animal_spawned.connect(_on_animal_spawned)
	EventBus.animal_removed.connect(_on_animal_removed)
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.territory_claimed.connect(_on_territory_claimed)
	EventBus.combat_ended.connect(_on_combat_ended)
	EventBus.production_completed.connect(_on_production_completed)


## Disconnect from EventBus signals.
func _disconnect_signals() -> void:
	if EventBus.animal_spawned.is_connected(_on_animal_spawned):
		EventBus.animal_spawned.disconnect(_on_animal_spawned)
	if EventBus.animal_removed.is_connected(_on_animal_removed):
		EventBus.animal_removed.disconnect(_on_animal_removed)
	if EventBus.building_placed.is_connected(_on_building_placed):
		EventBus.building_placed.disconnect(_on_building_placed)
	if EventBus.territory_claimed.is_connected(_on_territory_claimed):
		EventBus.territory_claimed.disconnect(_on_territory_claimed)
	if EventBus.combat_ended.is_connected(_on_combat_ended):
		EventBus.combat_ended.disconnect(_on_combat_ended)
	if EventBus.production_completed.is_connected(_on_production_completed):
		EventBus.production_completed.disconnect(_on_production_completed)

# =============================================================================
# PUBLIC API (AC8)
# =============================================================================

## Get list of all achieved milestone IDs.
## @return Array of milestone ID strings
func get_achieved_milestones() -> Array[String]:
	var result: Array[String] = []
	for id in _achieved.keys():
		result.append(id)
	return result


## Check if a specific milestone has been achieved.
## @param id The milestone ID to check
## @return True if achieved
func is_milestone_achieved(id: String) -> bool:
	return _achieved.has(id)


## Get progress for a milestone type.
## @param type_name One of: "population", "territory", "combat_wins"
## @return Dictionary with "current" and "target" keys, or empty if invalid type
func get_progress(type_name: String) -> Dictionary:
	if not _counts.has(type_name):
		return {}

	var current: int = _counts[type_name]
	var target: int = _get_next_threshold(type_name)

	return {
		"current": current,
		"target": target,
	}


## Get all milestone data (for UI display).
## @return Array of MilestoneData resources
func get_all_milestones() -> Array[MilestoneData]:
	var result: Array[MilestoneData] = []
	for id in _milestones:
		result.append(_milestones[id])
	return result


## Get a specific milestone by ID.
## @param id The milestone ID
## @return MilestoneData or null if not found
func get_milestone(id: String) -> MilestoneData:
	return _milestones.get(id, null)

# =============================================================================
# SAVE/LOAD INTEGRATION (AC7)
# =============================================================================

## Get save data for persistence.
## @return Dictionary with milestone state
func get_save_data() -> Dictionary:
	return {
		"achieved": get_achieved_milestones(),
		"counts": _counts.duplicate(),
		"first_buildings": _first_buildings.keys(),
		"first_productions": _first_productions.keys(),
	}


## Load save data to restore milestone state.
## @param data Dictionary from get_save_data()
func load_save_data(data: Dictionary) -> void:
	_loading = true

	# Restore achieved milestones
	_achieved.clear()
	var achieved_list: Array = data.get("achieved", [])
	for id in achieved_list:
		_achieved[id] = true

	# Restore counts
	var saved_counts: Dictionary = data.get("counts", {})
	for key in _counts.keys():
		if saved_counts.has(key):
			_counts[key] = saved_counts[key]

	# Restore first-time trackers
	_first_buildings.clear()
	var buildings_list: Array = data.get("first_buildings", [])
	for building_type in buildings_list:
		_first_buildings[building_type] = true

	_first_productions.clear()
	var productions_list: Array = data.get("first_productions", [])
	for output_type in productions_list:
		_first_productions[output_type] = true

	_loading = false
	GameLogger.info("MilestoneManager", "Loaded %d achieved milestones" % _achieved.size())


## Reset all milestone progress (for new game).
func reset() -> void:
	_achieved.clear()
	_counts = {
		"population": 0,
		"territory": 0,
		"combat_wins": 0,
	}
	_first_buildings.clear()
	_first_productions.clear()
	GameLogger.info("MilestoneManager", "Milestone progress reset")

# =============================================================================
# EVENT HANDLERS - POPULATION (AC2)
# =============================================================================

## Handle animal spawned event.
func _on_animal_spawned(animal: Node) -> void:
	if _loading:
		return

	# Only count player animals (not wild)
	if animal is Animal and not animal.is_wild:
		_counts["population"] += 1
		_check_population_milestones()


## Handle animal removed event.
func _on_animal_removed(animal: Node) -> void:
	if _loading:
		return

	# Only count player animals
	if animal is Animal and not animal.is_wild:
		_counts["population"] = maxi(0, _counts["population"] - 1)
		# No milestone un-achievement - once achieved, stays achieved

# =============================================================================
# EVENT HANDLERS - BUILDINGS (AC3)
# =============================================================================

## Handle building placed event.
func _on_building_placed(building: Node, _hex_coord: Vector2i) -> void:
	if _loading:
		return

	if building is Building and building.data:
		var building_id: String = building.data.building_id
		if building_id != "" and not _first_buildings.has(building_id):
			_first_buildings[building_id] = true
			_check_building_milestones(building_id)

# =============================================================================
# EVENT HANDLERS - TERRITORY (AC4)
# =============================================================================

## Handle territory claimed event.
func _on_territory_claimed(_hex_coord: Vector2i) -> void:
	if _loading:
		return

	_counts["territory"] += 1
	_check_territory_milestones()

# =============================================================================
# EVENT HANDLERS - COMBAT (AC5)
# =============================================================================

## Handle combat ended event.
func _on_combat_ended(won: bool, _captured_animals: Array) -> void:
	if _loading:
		return

	if won:
		_counts["combat_wins"] += 1
		_check_combat_milestones()

# =============================================================================
# EVENT HANDLERS - PRODUCTION (AC6)
# =============================================================================

## Handle production completed event.
func _on_production_completed(_building: Node, output_type: String) -> void:
	if _loading:
		return

	if output_type != "" and not _first_productions.has(output_type):
		_first_productions[output_type] = true
		_check_production_milestones(output_type)

# =============================================================================
# MILESTONE CHECKING
# =============================================================================

## Check population milestones against current count.
func _check_population_milestones() -> void:
	var current: int = _counts["population"]

	for id in _milestones:
		var milestone: MilestoneData = _milestones[id]
		if milestone.type == MilestoneData.Type.POPULATION:
			if current >= milestone.threshold:
				_try_achieve_milestone(id)


## Check building milestones for the given building type.
func _check_building_milestones(building_type: String) -> void:
	for id in _milestones:
		var milestone: MilestoneData = _milestones[id]
		if milestone.type == MilestoneData.Type.BUILDING:
			if milestone.trigger_value == building_type:
				_try_achieve_milestone(id)


## Check territory milestones against current count.
func _check_territory_milestones() -> void:
	var current: int = _counts["territory"]

	for id in _milestones:
		var milestone: MilestoneData = _milestones[id]
		if milestone.type == MilestoneData.Type.TERRITORY:
			if current >= milestone.threshold:
				_try_achieve_milestone(id)


## Check combat milestones against current win count.
func _check_combat_milestones() -> void:
	var current: int = _counts["combat_wins"]

	for id in _milestones:
		var milestone: MilestoneData = _milestones[id]
		if milestone.type == MilestoneData.Type.COMBAT:
			if current >= milestone.threshold:
				_try_achieve_milestone(id)


## Check production milestones for the given output type.
func _check_production_milestones(output_type: String) -> void:
	for id in _milestones:
		var milestone: MilestoneData = _milestones[id]
		if milestone.type == MilestoneData.Type.PRODUCTION:
			if milestone.trigger_value == output_type:
				_try_achieve_milestone(id)


## Try to achieve a milestone (only if not already achieved).
func _try_achieve_milestone(id: String) -> void:
	if _achieved.has(id):
		return  # Already achieved - don't re-trigger

	_achieved[id] = true

	# Emit internal signal for testing
	_milestone_triggered.emit(id)

	# Emit to EventBus for game-wide notification
	EventBus.milestone_reached.emit(id)

	var milestone: MilestoneData = _milestones.get(id, null)
	if milestone:
		GameLogger.info("MilestoneManager", "Milestone achieved: %s (%s)" % [milestone.display_name, id])

		# Process unlock rewards
		for unlock in milestone.unlock_rewards:
			EventBus.building_unlocked.emit(unlock)

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

## Get the next threshold for a milestone type.
## Returns the lowest unachieved threshold above current count.
## If all milestones of this type are achieved, returns the highest threshold
## (allowing UI to show "100/100" style completion indicators).
## Returns 0 only if no milestones exist for this type.
func _get_next_threshold(type_name: String) -> int:
	var current: int = _counts.get(type_name, 0)
	var next_threshold: int = 0

	var milestone_type: MilestoneData.Type
	match type_name:
		"population":
			milestone_type = MilestoneData.Type.POPULATION
		"territory":
			milestone_type = MilestoneData.Type.TERRITORY
		"combat_wins":
			milestone_type = MilestoneData.Type.COMBAT
		_:
			return 0

	# Find the lowest threshold above current that isn't achieved
	for id in _milestones:
		var milestone: MilestoneData = _milestones[id]
		if milestone.type == milestone_type:
			if milestone.threshold > current and not _achieved.has(id):
				if next_threshold == 0 or milestone.threshold < next_threshold:
					next_threshold = milestone.threshold

	# If all achieved at this type, return the highest threshold
	if next_threshold == 0:
		for id in _milestones:
			var milestone: MilestoneData = _milestones[id]
			if milestone.type == milestone_type:
				if milestone.threshold > next_threshold:
					next_threshold = milestone.threshold

	return next_threshold
