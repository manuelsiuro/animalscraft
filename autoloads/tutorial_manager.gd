## Tutorial system manager for AnimalsCraft.
## Autoload singleton - access via TutorialManager
##
## Architecture: autoloads/tutorial_manager.gd
## Order: 9 (depends on EventBus, SaveManager)
## Story: 6-9-implement-tutorial-flow
##
## Tracks tutorial state, handles step progression, and persists progress.
## Tutorial philosophy: Non-blocking hints that guide but never force.
## NOTE: No class_name to avoid conflict with autoload singleton
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a tutorial step is completed
signal step_completed(step: TutorialStep)

## Emitted when tutorial mode is enabled/disabled
signal tutorial_mode_changed(enabled: bool)

## Emitted when all tutorials are complete
signal all_tutorials_complete()

## Emitted when a tutorial tooltip should be shown
signal show_tooltip_requested(step: TutorialStep, message: String, position_hint: String)

## Emitted when current tooltip should be hidden
signal hide_tooltip_requested()

# =============================================================================
# TUTORIAL STEPS
# =============================================================================

## Tutorial step enum - ordered sequence of tutorial phases
enum TutorialStep {
	WELCOME,          ## Initial welcome message
	CAMERA_PAN,       ## Teach camera panning
	SELECT_ANIMAL,    ## Teach animal selection
	ASSIGN_ANIMAL,    ## Teach movement assignment
	OPEN_MENU,        ## Teach opening building menu
	PLACE_BUILDING,   ## Teach building placement
	ASSIGN_WORKER,    ## Teach worker assignment
	COMBAT_INTRO,     ## Introduce combat mechanics
}

## Tutorial step display messages
const STEP_MESSAGES := {
	TutorialStep.WELCOME: "Welcome to AnimalsCraft!\nBuild a village with your animal friends.",
	TutorialStep.CAMERA_PAN: "Drag to explore your world",
	TutorialStep.SELECT_ANIMAL: "Tap an animal to select it",
	TutorialStep.ASSIGN_ANIMAL: "Tap a tile to send your animal there",
	TutorialStep.OPEN_MENU: "Tap to build structures",
	TutorialStep.PLACE_BUILDING: "Drag a building to place it",
	TutorialStep.ASSIGN_WORKER: "Tap an animal, then tap a building to assign",
	TutorialStep.COMBAT_INTRO: "Red borders mean wild animals!\nTap to start a food fight and claim territory",
}

## Tutorial step position hints (where to show tooltip)
const STEP_POSITION_HINTS := {
	TutorialStep.WELCOME: "center",
	TutorialStep.CAMERA_PAN: "center",
	TutorialStep.SELECT_ANIMAL: "animal",
	TutorialStep.ASSIGN_ANIMAL: "center",
	TutorialStep.OPEN_MENU: "build_button",
	TutorialStep.PLACE_BUILDING: "menu",
	TutorialStep.ASSIGN_WORKER: "center",
	TutorialStep.COMBAT_INTRO: "contested",
}

# =============================================================================
# STATE
# =============================================================================

## Whether tutorial mode is currently enabled
var _tutorial_enabled: bool = true

## Set of completed tutorial steps (stored as int values)
var _completed_steps: Array[int] = []

## Currently active tutorial step (or -1 if none)
var _current_step: int = -1

## Whether we're waiting for user action to complete current step
var _waiting_for_action: bool = false

## Flag to track if first pan has been detected
var _first_pan_detected: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Connect to EventBus signals for tutorial progression
	_connect_event_signals()

	GameLogger.info("TutorialManager", "Tutorial manager initialized")


func _exit_tree() -> void:
	_disconnect_event_signals()


# =============================================================================
# EVENT SIGNAL CONNECTIONS
# =============================================================================

func _connect_event_signals() -> void:
	if not is_instance_valid(EventBus):
		return

	# Camera pan detection (AC4)
	EventBus.camera_panned.connect(_on_camera_panned)

	# Animal selection detection (AC5)
	EventBus.animal_selected.connect(_on_animal_selected)

	# Animal assignment detection (AC6)
	EventBus.animal_assigned.connect(_on_animal_assigned)

	# Building menu opened detection (AC7)
	EventBus.menu_opened.connect(_on_menu_opened)

	# Building placed detection (AC8)
	EventBus.building_placed.connect(_on_building_placed)

	# Worker assigned detection (AC9)
	EventBus.worker_assigned.connect(_on_worker_assigned)

	# Combat started detection (AC10)
	EventBus.combat_started.connect(_on_combat_started)

	# Scene loaded - trigger tutorial start
	EventBus.scene_loaded.connect(_on_scene_loaded)


func _disconnect_event_signals() -> void:
	if not is_instance_valid(EventBus):
		return

	if EventBus.camera_panned.is_connected(_on_camera_panned):
		EventBus.camera_panned.disconnect(_on_camera_panned)
	if EventBus.animal_selected.is_connected(_on_animal_selected):
		EventBus.animal_selected.disconnect(_on_animal_selected)
	if EventBus.animal_assigned.is_connected(_on_animal_assigned):
		EventBus.animal_assigned.disconnect(_on_animal_assigned)
	if EventBus.menu_opened.is_connected(_on_menu_opened):
		EventBus.menu_opened.disconnect(_on_menu_opened)
	if EventBus.building_placed.is_connected(_on_building_placed):
		EventBus.building_placed.disconnect(_on_building_placed)
	if EventBus.worker_assigned.is_connected(_on_worker_assigned):
		EventBus.worker_assigned.disconnect(_on_worker_assigned)
	if EventBus.combat_started.is_connected(_on_combat_started):
		EventBus.combat_started.disconnect(_on_combat_started)
	if EventBus.scene_loaded.is_connected(_on_scene_loaded):
		EventBus.scene_loaded.disconnect(_on_scene_loaded)


# =============================================================================
# PUBLIC API - State Queries
# =============================================================================

## Check if tutorial mode is enabled
func is_tutorial_enabled() -> bool:
	return _tutorial_enabled


## Check if a specific tutorial step is complete
func is_step_complete(step: TutorialStep) -> bool:
	return step in _completed_steps


## Check if all tutorial steps are complete
func are_all_steps_complete() -> bool:
	return _completed_steps.size() >= TutorialStep.size()


## Get the current active tutorial step (or -1 if none)
func get_current_step() -> int:
	return _current_step


## Get the next incomplete tutorial step (or -1 if all complete)
func get_next_incomplete_step() -> int:
	for step_value in TutorialStep.values():
		if step_value not in _completed_steps:
			return step_value
	return -1


## Get message for a tutorial step
func get_step_message(step: TutorialStep) -> String:
	return STEP_MESSAGES.get(step, "")


## Get position hint for a tutorial step
func get_step_position_hint(step: TutorialStep) -> String:
	return STEP_POSITION_HINTS.get(step, "center")


# =============================================================================
# PUBLIC API - State Modification
# =============================================================================

## Complete a tutorial step (AC1, AC12)
func complete_step(step: TutorialStep) -> void:
	if step in _completed_steps:
		return  # Already complete

	_completed_steps.append(step)
	_waiting_for_action = false

	GameLogger.info("TutorialManager", "Tutorial step completed: %s" % TutorialStep.keys()[step])
	step_completed.emit(step)

	# Emit EventBus signal
	if is_instance_valid(EventBus):
		EventBus.tutorial_step_completed.emit(step)

	# Hide current tooltip
	hide_tooltip_requested.emit()

	# Check if all complete
	if are_all_steps_complete():
		GameLogger.info("TutorialManager", "All tutorial steps complete!")
		all_tutorials_complete.emit()
		_current_step = -1

		# Emit EventBus signal
		if is_instance_valid(EventBus):
			EventBus.tutorial_completed.emit()
	else:
		# Trigger next step after a short delay
		_schedule_next_step()


## Enable or disable tutorial mode
func set_tutorial_enabled(enabled: bool) -> void:
	if _tutorial_enabled == enabled:
		return

	_tutorial_enabled = enabled
	GameLogger.info("TutorialManager", "Tutorial mode: %s" % ("enabled" if enabled else "disabled"))
	tutorial_mode_changed.emit(enabled)

	if enabled and not are_all_steps_complete():
		# Start/resume tutorial
		_schedule_next_step()
	else:
		# Hide any active tooltip
		hide_tooltip_requested.emit()
		_current_step = -1


## Skip all remaining tutorials (AC13)
func skip_all() -> void:
	# Mark all steps complete
	for step_value in TutorialStep.values():
		if step_value not in _completed_steps:
			_completed_steps.append(step_value)

	_tutorial_enabled = false
	_current_step = -1
	_waiting_for_action = false

	# Hide any active tooltip
	hide_tooltip_requested.emit()

	GameLogger.info("TutorialManager", "All tutorials skipped")
	tutorial_mode_changed.emit(false)
	all_tutorials_complete.emit()


## Reset all tutorial progress (AC14)
func reset_all() -> void:
	_completed_steps.clear()
	_tutorial_enabled = true
	_current_step = -1
	_waiting_for_action = false
	_first_pan_detected = false

	GameLogger.info("TutorialManager", "Tutorial progress reset")
	tutorial_mode_changed.emit(true)


# =============================================================================
# SAVE/LOAD (AC1, AC12)
# =============================================================================

## Get save data for persistence
func get_save_data() -> Dictionary:
	return {
		"tutorial_enabled": _tutorial_enabled,
		"completed_steps": _completed_steps.duplicate(),
	}


## Load save data to restore state
func load_save_data(data: Dictionary) -> void:
	_tutorial_enabled = data.get("tutorial_enabled", true)

	# Load completed steps (handle both int and enum values)
	var loaded_steps = data.get("completed_steps", [])
	_completed_steps.clear()
	for step in loaded_steps:
		if step is int and step >= 0 and step < TutorialStep.size():
			_completed_steps.append(step)

	# Reset current step state
	_current_step = -1
	_waiting_for_action = false

	GameLogger.info("TutorialManager", "Tutorial state loaded: enabled=%s, completed=%d steps" % [
		_tutorial_enabled, _completed_steps.size()
	])


# =============================================================================
# TUTORIAL FLOW CONTROL
# =============================================================================

## Start the tutorial sequence
func start_tutorial() -> void:
	if not _tutorial_enabled:
		return

	if are_all_steps_complete():
		return

	GameLogger.info("TutorialManager", "Starting tutorial sequence")

	# Emit EventBus signal for tutorial start
	if is_instance_valid(EventBus):
		EventBus.tutorial_started.emit()

	_schedule_next_step()


## Show tooltip for the current step
func _show_current_step_tooltip() -> void:
	if _current_step < 0 or _current_step >= TutorialStep.size():
		return

	var step := _current_step as TutorialStep
	var message := get_step_message(step)
	var position_hint := get_step_position_hint(step)

	GameLogger.debug("TutorialManager", "Showing tooltip for step: %s" % TutorialStep.keys()[step])
	show_tooltip_requested.emit(step, message, position_hint)
	_waiting_for_action = true


## Schedule the next tutorial step
func _schedule_next_step() -> void:
	if not _tutorial_enabled:
		return

	var next_step := get_next_incomplete_step()
	if next_step < 0:
		return

	_current_step = next_step

	# Small delay before showing next tooltip
	await get_tree().create_timer(0.5).timeout

	if _tutorial_enabled and _current_step == next_step:
		_show_current_step_tooltip()


# =============================================================================
# EVENT HANDLERS - Tutorial Step Completion
# =============================================================================

func _on_scene_loaded(scene_name: String) -> void:
	# Start tutorial when game scene loads
	if scene_name == "game" and _tutorial_enabled and not are_all_steps_complete():
		# Delay to let scene fully initialize
		await get_tree().create_timer(1.0).timeout
		start_tutorial()


func _on_camera_panned(_position: Vector3) -> void:
	# Only trigger once
	if _first_pan_detected:
		return

	if _current_step == TutorialStep.CAMERA_PAN and _waiting_for_action:
		_first_pan_detected = true
		complete_step(TutorialStep.CAMERA_PAN)


func _on_animal_selected(_animal: Node) -> void:
	if _current_step == TutorialStep.SELECT_ANIMAL and _waiting_for_action:
		complete_step(TutorialStep.SELECT_ANIMAL)


func _on_animal_assigned(_animal: Node, _target: Variant) -> void:
	if _current_step == TutorialStep.ASSIGN_ANIMAL and _waiting_for_action:
		complete_step(TutorialStep.ASSIGN_ANIMAL)


func _on_menu_opened(menu_name: String) -> void:
	if menu_name == "building_menu" and _current_step == TutorialStep.OPEN_MENU and _waiting_for_action:
		complete_step(TutorialStep.OPEN_MENU)


func _on_building_placed(_building: Node, _hex_coord: Vector2i) -> void:
	if _current_step == TutorialStep.PLACE_BUILDING and _waiting_for_action:
		complete_step(TutorialStep.PLACE_BUILDING)


func _on_worker_assigned(_animal: Node, _building: Node) -> void:
	if _current_step == TutorialStep.ASSIGN_WORKER and _waiting_for_action:
		complete_step(TutorialStep.ASSIGN_WORKER)


func _on_combat_started(_hex_coord: Vector2i) -> void:
	if _current_step == TutorialStep.COMBAT_INTRO and _waiting_for_action:
		complete_step(TutorialStep.COMBAT_INTRO)


# =============================================================================
# MANUAL STEP COMPLETION (for dismissal without action)
# =============================================================================

## Manually complete the current step (e.g., user dismisses tooltip)
func dismiss_current_step() -> void:
	if _current_step < 0:
		return

	# Welcome step can be dismissed by tap
	if _current_step == TutorialStep.WELCOME:
		complete_step(TutorialStep.WELCOME)
	# Combat intro can be dismissed without entering combat
	elif _current_step == TutorialStep.COMBAT_INTRO:
		complete_step(TutorialStep.COMBAT_INTRO)
