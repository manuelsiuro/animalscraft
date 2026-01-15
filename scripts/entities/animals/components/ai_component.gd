## AIComponent - Finite State Machine for animal AI behavior.
## Manages state transitions between Idle, Walking, Working, Resting.
##
## Architecture: scripts/entities/animals/components/ai_component.gd
## Story: 2-8-implement-animal-ai-state-machine
class_name AIComponent
extends Node

# =============================================================================
# ENUMS
# =============================================================================

## Animal behavior states
enum AnimalState { IDLE, WALKING, WORKING, RESTING }
# Note: COMBAT state deferred to Epic 5

# =============================================================================
# CONSTANTS - [PARTY: Cloud - Data-driven transition matrix]
# =============================================================================

## Valid state transitions - extensible for future states (Combat in Epic 5)
const VALID_TRANSITIONS := {
	AnimalState.IDLE: [AnimalState.WALKING, AnimalState.WORKING, AnimalState.RESTING],
	AnimalState.WALKING: [AnimalState.IDLE, AnimalState.WORKING, AnimalState.RESTING],
	AnimalState.WORKING: [AnimalState.IDLE, AnimalState.RESTING],
	AnimalState.RESTING: [AnimalState.IDLE],
}

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when state changes
signal state_changed(old_state: AnimalState, new_state: AnimalState)

# =============================================================================
# PROPERTIES
# =============================================================================

## Current state
var _current_state: AnimalState = AnimalState.IDLE

## [PARTY: Link] Cached current state object - avoids dictionary lookup per frame
var _current_state_obj: BaseState = null

## State objects dictionary
var _states: Dictionary = {}

## Reference to parent Animal
var _animal: Node3D = null

## Reference to MovementComponent
var _movement: Node = null

## Reference to StatsComponent
var _stats: Node = null

## Whether component is initialized
var _initialized: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Defer initialization to allow parent to be fully ready
	call_deferred("_initialize")


func _initialize() -> void:
	_animal = get_parent() as Node3D
	if not _animal:
		GameLogger.error("AIComponent", "No parent Animal found")
		return

	# Find sibling components
	_movement = _animal.get_node_or_null("MovementComponent")
	_stats = _animal.get_node_or_null("StatsComponent")

	# Create state objects
	_states = {
		AnimalState.IDLE: IdleState.new(self, _animal),
		AnimalState.WALKING: WalkingState.new(self, _animal),
		AnimalState.WORKING: WorkingState.new(self, _animal),
		AnimalState.RESTING: RestingState.new(self, _animal),
	}

	# Connect to component signals
	_connect_signals()

	# Enter initial state and cache reference [PARTY: Link]
	_current_state_obj = _states[_current_state]
	_current_state_obj.enter()
	_initialized = true

	var animal_id: String = ""
	if _animal.has_method("get_animal_id"):
		animal_id = _animal.get_animal_id()

	GameLogger.info("AIComponent", "Initialized for %s in state %s" % [
		animal_id, AnimalState.keys()[_current_state]
	])


func _connect_signals() -> void:
	# Movement signals - MovementComponent always defines these signals
	if _movement:
		_movement.movement_started.connect(_on_movement_started)
		_movement.movement_completed.connect(_on_movement_completed)
		_movement.movement_cancelled.connect(_on_movement_cancelled)

	# Stats signals - StatsComponent always defines these signals
	if _stats:
		_stats.energy_changed.connect(_on_energy_changed)


func _process(delta: float) -> void:
	if not _initialized:
		return

	# [PARTY: Link] Skip update for IDLE state - it's passive, saves ~12K lookups/sec
	# Most animals idle most of the time, this is free performance
	if _current_state == AnimalState.IDLE:
		return

	# Update current state using cached reference (no dictionary lookup)
	if _current_state_obj:
		_current_state_obj.update(delta)


func _exit_tree() -> void:
	# Disconnect signals to prevent orphan connections
	_disconnect_signals()


func _disconnect_signals() -> void:
	# Movement signals
	if is_instance_valid(_movement):
		if _movement.movement_started.is_connected(_on_movement_started):
			_movement.movement_started.disconnect(_on_movement_started)
		if _movement.movement_completed.is_connected(_on_movement_completed):
			_movement.movement_completed.disconnect(_on_movement_completed)
		if _movement.movement_cancelled.is_connected(_on_movement_cancelled):
			_movement.movement_cancelled.disconnect(_on_movement_cancelled)

	# Stats signals
	if is_instance_valid(_stats):
		if _stats.energy_changed.is_connected(_on_energy_changed):
			_stats.energy_changed.disconnect(_on_energy_changed)

# =============================================================================
# PUBLIC API
# =============================================================================

## Transition to a new state with validation
func transition_to(new_state: AnimalState) -> void:
	if not _initialized:
		GameLogger.warn("AIComponent", "Cannot transition: not initialized")
		return

	if _current_state == new_state:
		return

	# Validate transition is allowed
	if not _is_transition_valid(_current_state, new_state):
		GameLogger.warn("AIComponent", "Invalid transition: %s -> %s" % [
			AnimalState.keys()[_current_state], AnimalState.keys()[new_state]
		])
		return

	# Execute transition
	var old_state := _current_state

	# Exit old state
	if _current_state_obj:
		_current_state_obj.exit()

	# Change state and cache new state object [PARTY: Link]
	_current_state = new_state
	_current_state_obj = _states.get(_current_state)

	# Enter new state
	if _current_state_obj:
		_current_state_obj.enter()

	# Log and notify
	_log_transition(old_state, new_state)
	state_changed.emit(old_state, new_state)

	# Emit global EventBus signal
	if is_instance_valid(EventBus):
		EventBus.animal_state_changed.emit(_animal, AnimalState.keys()[new_state])


## Get current state
func get_current_state() -> AnimalState:
	return _current_state


## Get current state as string
func get_current_state_string() -> String:
	return AnimalState.keys()[_current_state]


## Check if in specific state
func is_in_state(state: AnimalState) -> bool:
	return _current_state == state


## Check if initialized
func is_initialized() -> bool:
	return _initialized

# =============================================================================
# TRANSITION VALIDATION
# =============================================================================

## Validate if transition is allowed
## [PARTY: Cloud] Data-driven validation - easy to extend for Combat state in Epic 5
func _is_transition_valid(from: AnimalState, to: AnimalState) -> bool:
	var valid_targets: Array = VALID_TRANSITIONS.get(from, [])
	return to in valid_targets

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_movement_started() -> void:
	if _current_state != AnimalState.WALKING:
		transition_to(AnimalState.WALKING)


func _on_movement_completed() -> void:
	# Check if destination is a building (future: transition to Working)
	# For now, return to Idle
	if _current_state == AnimalState.WALKING:
		transition_to(AnimalState.IDLE)


func _on_movement_cancelled() -> void:
	if _current_state == AnimalState.WALKING:
		transition_to(AnimalState.IDLE)


func _on_energy_changed(current: int, _max_energy: int) -> void:
	# Check for energy depleted
	if current <= 0 and _current_state != AnimalState.RESTING:
		transition_to(AnimalState.RESTING)

# =============================================================================
# LOGGING
# =============================================================================

func _log_transition(from: AnimalState, to: AnimalState) -> void:
	var animal_id: String = "unknown"
	if is_instance_valid(_animal) and _animal.has_method("get_animal_id"):
		animal_id = _animal.get_animal_id()

	var from_str: String = AnimalState.keys()[from]
	var to_str: String = AnimalState.keys()[to]

	# Use INFO for significant transitions (entering Resting)
	if to == AnimalState.RESTING:
		GameLogger.info("AIComponent", "%s: %s -> %s" % [animal_id, from_str, to_str])
	else:
		GameLogger.debug("AIComponent", "%s: %s -> %s" % [animal_id, from_str, to_str])
