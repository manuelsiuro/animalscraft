## Core game state manager for AnimalsCraft.
## Autoload singleton - access via GameManager
##
## Architecture: autoloads/game_manager.gd
## Order: 8 (depends on all other autoloads)
## Source: game-architecture.md#State Management
##
## Controls game state, pause, time scale, and coordinates other systems.
## Story 0.5: Added scene transition methods (change_to_game_scene, change_to_main_scene)
## Story 1.7: Added auto-pause on app switch with Android support (PAUSED/RESUMED notifications)
## Story 6-9: Added first launch detection for tutorial flow
## NOTE: No class_name to avoid conflict with autoload singleton
extends Node

# =============================================================================
# SCENE PATHS
# =============================================================================

## Path to the main menu/title scene
const MAIN_SCENE_PATH := "res://scenes/main.tscn"

## Path to the gameplay scene
const GAME_SCENE_PATH := "res://scenes/game.tscn"

# =============================================================================
# GAME STATE
# =============================================================================

## Game state machine states
enum GameState {
	INITIALIZING,  ## Game is starting up
	MENU,          ## In main menu
	LOADING,       ## Loading a save or new game
	PLAYING,       ## Normal gameplay
	PAUSED,        ## Game is paused
	CUTSCENE,      ## Playing a cutscene
}

## Current game state
var _state: GameState = GameState.INITIALIZING

## Previous state (for returning from pause)
var _previous_state: GameState = GameState.INITIALIZING

# =============================================================================
# TIME TRACKING
# =============================================================================

## Total playtime in seconds (current session)
var _session_playtime: float = 0.0

## Playtime loaded from save
var _loaded_playtime: float = 0.0

## Game time scale (1.0 = normal)
var _time_scale: float = 1.0

## Paused time scale (stored during pause)
var _pre_pause_time_scale: float = 1.0

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Set process mode to always run (even when paused)
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Connect to error handler for recovery
	if is_instance_valid(ErrorHandler):
		ErrorHandler.critical_error.connect(_on_critical_error)

	# Transition to menu state
	_transition_to_state(GameState.MENU)

	GameLogger.info("GameManager", "Game manager initialized")


func _process(delta: float) -> void:
	# Only track time while playing
	if _state == GameState.PLAYING:
		_session_playtime += delta


## Handle application notifications for pause/resume (Story 1.7).
## Called by Godot engine for app lifecycle events.
## Supports both desktop (FOCUS_*) and Android (APPLICATION_*) notifications.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			# Desktop: Window loses focus
			# Mobile: App goes to background
			_handle_app_pause()

		NOTIFICATION_APPLICATION_FOCUS_IN:
			# Desktop: Window gains focus
			# Mobile: App returns to foreground
			_handle_app_resume()

		NOTIFICATION_APPLICATION_PAUSED:
			# Android only: App paused (more reliable on Android)
			_handle_app_pause()

		NOTIFICATION_APPLICATION_RESUMED:
			# Android only: App resumed (more reliable on Android)
			_handle_app_resume()

		NOTIFICATION_WM_CLOSE_REQUEST:
			# Cleanup before quitting
			EventBus.game_quitting.emit()


# =============================================================================
# STATE ACCESSORS
# =============================================================================

## Get the current game state.
func get_state() -> GameState:
	return _state


## Check if game is currently playing.
func is_playing() -> bool:
	return _state == GameState.PLAYING


## Check if game is paused.
func is_paused() -> bool:
	return _state == GameState.PAUSED


## Check if game is in menu.
func is_in_menu() -> bool:
	return _state == GameState.MENU


## Check if game is loading.
func is_loading() -> bool:
	return _state == GameState.LOADING


# =============================================================================
# FIRST LAUNCH DETECTION (Story 6-9)
# =============================================================================

## Check if this is the first launch (no save file exists).
## Used to determine if tutorial should be shown and to skip main menu.
func is_first_launch() -> bool:
	if not is_instance_valid(SaveManager):
		return true
	var saves := SaveManager.get_all_save_info()
	return saves.is_empty()


## Start the game directly (skip main menu) for first-time players.
## Enables tutorial and starts a new game immediately.
func start_first_launch_game() -> void:
	GameLogger.info("GameManager", "First launch detected - starting tutorial game")

	# Ensure tutorial is enabled
	if is_instance_valid(TutorialManager):
		TutorialManager.set_tutorial_enabled(true)

	# Emit tutorial started signal
	if is_instance_valid(EventBus):
		EventBus.tutorial_started.emit()

	# Start new game directly
	start_new_game()


# =============================================================================
# STATE TRANSITIONS
# =============================================================================

## Start a new game.
func start_new_game() -> void:
	GameLogger.info("GameManager", "Starting new game")

	_transition_to_state(GameState.LOADING)

	# Reset playtime
	_session_playtime = 0.0
	_loaded_playtime = 0.0

	# Initialize game world (to be implemented with world systems)
	# For now, just transition to playing
	await get_tree().create_timer(0.5).timeout  # Simulate loading

	_transition_to_state(GameState.PLAYING)
	EventBus.new_game_started.emit()


## Load a saved game.
## @param slot The save slot to load
func load_saved_game(slot: int = 0) -> void:
	GameLogger.info("GameManager", "Loading saved game from slot %d" % slot)

	_transition_to_state(GameState.LOADING)

	var success := SaveManager.load_game(slot)

	if success:
		_transition_to_state(GameState.PLAYING)
	else:
		# Return to menu on failed load
		GameLogger.error("GameManager", "Failed to load game, returning to menu")
		_transition_to_state(GameState.MENU)


## Continue the most recent save.
func continue_game() -> void:
	var saves := SaveManager.get_all_save_info()
	if saves.is_empty():
		GameLogger.warn("GameManager", "No saves found to continue")
		return

	# Find most recent save
	var most_recent: Dictionary = saves[0]
	for save_info in saves:
		if save_info.get("timestamp", "") > most_recent.get("timestamp", ""):
			most_recent = save_info

	load_saved_game(most_recent.get("slot", 0))


## Pause the game.
func pause_game() -> void:
	if _state != GameState.PLAYING:
		return

	GameLogger.info("GameManager", "Game paused")

	_previous_state = _state
	_pre_pause_time_scale = _time_scale

	_transition_to_state(GameState.PAUSED)

	# Pause the scene tree
	get_tree().paused = true

	EventBus.game_paused.emit()


## Resume the game from pause.
func resume_game() -> void:
	if _state != GameState.PAUSED:
		return

	GameLogger.info("GameManager", "Game resumed")

	# Restore time scale
	_time_scale = _pre_pause_time_scale

	# Unpause the scene tree
	get_tree().paused = false

	_transition_to_state(GameState.PLAYING)

	EventBus.game_resumed.emit()


## Toggle pause state.
func toggle_pause() -> void:
	if _state == GameState.PLAYING:
		pause_game()
	elif _state == GameState.PAUSED:
		resume_game()


## Return to main menu.
func return_to_menu() -> void:
	GameLogger.info("GameManager", "Returning to main menu")

	# Unpause if paused
	if _state == GameState.PAUSED:
		get_tree().paused = false

	# Save before returning (if playing or paused)
	if _state == GameState.PLAYING or _state == GameState.PAUSED:
		SaveManager.quick_save()

	# Change to main scene using scene transition system (Story 0.5)
	change_to_main_scene()


## Quit the game.
func quit_game() -> void:
	GameLogger.info("GameManager", "Quitting game")

	EventBus.game_quitting.emit()

	# Save before quitting
	SaveManager.quick_save()

	get_tree().quit()


# =============================================================================
# TIME CONTROL
# =============================================================================

## Get the current time scale.
func get_time_scale() -> float:
	return _time_scale


## Set the game time scale.
## @param scale Time scale (1.0 = normal, 2.0 = double speed, etc.)
func set_time_scale(scale: float) -> void:
	_time_scale = clampf(scale, 0.0, 4.0)
	Engine.time_scale = _time_scale
	GameLogger.debug("GameManager", "Time scale set to %.2f" % _time_scale)


## Get total playtime in seconds.
func get_playtime_seconds() -> float:
	return _loaded_playtime + _session_playtime


## Get formatted playtime string (HH:MM:SS).
func get_playtime_formatted() -> String:
	var total := int(get_playtime_seconds())
	var hours := total / 3600
	var minutes := (total % 3600) / 60
	var seconds := total % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]


# =============================================================================
# ERROR RECOVERY
# =============================================================================

## Reset game to a safe state after critical error.
## Called by ErrorHandler during recovery.
func reset_to_safe_state() -> void:
	GameLogger.warn("GameManager", "Resetting to safe state")

	# Unpause if paused
	if _state == GameState.PAUSED:
		get_tree().paused = false

	# Reset time scale
	_time_scale = 1.0
	Engine.time_scale = 1.0

	# Return to menu as safest option
	_transition_to_state(GameState.MENU)


# =============================================================================
# INTERNAL
# =============================================================================

## Transition to a new game state.
func _transition_to_state(new_state: GameState) -> void:
	if _state == new_state:
		return

	var old_state := _state
	_state = new_state

	GameLogger.info("GameManager", "State: %s -> %s" % [
		GameState.keys()[old_state],
		GameState.keys()[new_state]
	])


## Handle critical error from ErrorHandler.
func _on_critical_error(system: String, message: String) -> void:
	GameLogger.error("GameManager", "Critical error in %s: %s" % [system, message])

	# Pause game during error handling
	if _state == GameState.PLAYING:
		pause_game()


# =============================================================================
# SCENE TRANSITIONS (Story 0.5)
# =============================================================================

## Change to the game scene.
## Emits EventBus.scene_loading before transition and EventBus.scene_loaded after.
## Uses deferred scene change for safety.
func change_to_game_scene() -> void:
	GameLogger.info("GameManager", "Transitioning to game scene")
	_change_scene(GAME_SCENE_PATH)


## Change to the main/menu scene.
## Emits EventBus.scene_loading before transition and EventBus.scene_loaded after.
## Uses deferred scene change for safety.
func change_to_main_scene() -> void:
	GameLogger.info("GameManager", "Transitioning to main scene")
	_change_scene(MAIN_SCENE_PATH)


## Internal scene change with error handling and EventBus integration.
## @param scene_path The path to the scene file to load
func _change_scene(scene_path: String) -> void:
	# Transition to loading state
	_transition_to_state(GameState.LOADING)

	# Use call_deferred for safer scene transition
	# Signals are emitted inside deferred call to ensure proper timing
	call_deferred("_do_scene_change", scene_path)


## Deferred scene change execution.
## Called via call_deferred to ensure safe timing.
## Emits signals at proper lifecycle points.
## @param scene_path The path to load
func _do_scene_change(scene_path: String) -> void:
	# Emit scene loading signal at start of transition
	EventBus.scene_loading.emit(scene_path)

	# Notify current scene it's being unloaded
	var current_scene := get_tree().current_scene
	if current_scene != null:
		EventBus.scene_unloading.emit(current_scene.name)

	# Perform actual scene change
	var err := get_tree().change_scene_to_file(scene_path)

	if err != OK:
		GameLogger.error("GameManager", "Failed to change scene to %s: error code %d" % [scene_path, err])
		ErrorHandler.handle_error("Scene", "Failed to load scene: " + scene_path, false)

		# Attempt recovery - stay in current scene
		_transition_to_state(GameState.MENU)
		return

	# Extract scene name from path for logging
	var scene_name := scene_path.get_file().get_basename()

	# Emit scene loaded signal (scene is now ready)
	EventBus.scene_loaded.emit(scene_name)

	# Transition state based on which scene loaded
	if scene_path == GAME_SCENE_PATH:
		_transition_to_state(GameState.PLAYING)
	else:
		_transition_to_state(GameState.MENU)

	GameLogger.info("GameManager", "Scene loaded: %s" % scene_name)


# =============================================================================
# APP LIFECYCLE (Story 1.7)
# =============================================================================

## Handle app going to background/losing focus (Story 1.7).
## Called by _notification() on FOCUS_OUT or APPLICATION_PAUSED.
## Only pauses if currently playing - safe to call multiple times.
func _handle_app_pause() -> void:
	# Only pause if we're actually playing
	if _state == GameState.PLAYING:
		GameLogger.debug("GameManager", "App focus lost - pausing game")
		pause_game()


## Handle app returning to foreground/gaining focus (Story 1.7).
## Called by _notification() on FOCUS_IN or APPLICATION_RESUMED.
## Auto-resumes if currently paused - safe to call multiple times.
func _handle_app_resume() -> void:
	# Only resume if we're paused
	if _state == GameState.PAUSED:
		GameLogger.debug("GameManager", "App focus regained - resuming game")
		resume_game()
