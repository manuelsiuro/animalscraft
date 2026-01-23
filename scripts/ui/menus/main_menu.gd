## Main menu screen for AnimalsCraft.
## Handles Continue, New Game, Settings, and Exit buttons.
##
## Architecture: scripts/ui/menus/main_menu.gd
## Story: 6-3-implement-load-game-ui
extends Control

# =============================================================================
# CONSTANTS
# =============================================================================

## Default save slot for Continue functionality (slot 0)
const DEFAULT_SAVE_SLOT := 0

## Path to the game scene
const GAME_SCENE_PATH := "res://scenes/game.tscn"

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _continue_button: Button = $VBoxContainer/ContinueButton
@onready var _new_game_button: Button = $VBoxContainer/NewGameButton
@onready var _settings_button: Button = $VBoxContainer/SettingsButton
@onready var _exit_button: Button = $VBoxContainer/ExitButton
@onready var _error_dialog: AcceptDialog = $ErrorDialog
@onready var _settings_screen: Control = $SettingsScreen

# =============================================================================
# STATE
# =============================================================================

## Whether a load operation is in progress
var _loading: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Connect button signals
	if _continue_button:
		_continue_button.pressed.connect(_on_continue_pressed)
	if _new_game_button:
		_new_game_button.pressed.connect(_on_new_game_pressed)
	if _settings_button:
		_settings_button.pressed.connect(_on_settings_pressed)
	if _exit_button:
		_exit_button.pressed.connect(_on_exit_pressed)

	# Connect error dialog confirmation to start new game (AC5)
	if _error_dialog:
		_error_dialog.confirmed.connect(_on_new_game_pressed)

	# Connect to EventBus for load events
	EventBus.load_started.connect(_on_load_started)
	EventBus.load_completed.connect(_on_load_completed)

	# Connect settings screen back signal
	if _settings_screen:
		_settings_screen.back_pressed.connect(_on_settings_back_pressed)

	# Validate game scene exists
	if not ResourceLoader.exists(GAME_SCENE_PATH):
		GameLogger.error("MainMenu", "Game scene not found: %s" % GAME_SCENE_PATH)

	# Update Continue button visibility based on save existence
	_update_continue_button_visibility()

	GameLogger.info("MainMenu", "Main menu initialized")


func _exit_tree() -> void:
	# Disconnect EventBus signals
	if EventBus.load_started.is_connected(_on_load_started):
		EventBus.load_started.disconnect(_on_load_started)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)

# =============================================================================
# UI STATE MANAGEMENT
# =============================================================================

## Update Continue button visibility based on save existence (AC1)
func _update_continue_button_visibility() -> void:
	if not _continue_button:
		return

	var save_exists := SaveManager.save_exists(DEFAULT_SAVE_SLOT)
	_continue_button.visible = save_exists

	if save_exists:
		GameLogger.debug("MainMenu", "Save found - Continue button visible")
	else:
		GameLogger.debug("MainMenu", "No save found - Continue button hidden")


## Set all buttons enabled/disabled state
func _set_buttons_enabled(enabled: bool) -> void:
	if _continue_button:
		_continue_button.disabled = not enabled
	if _new_game_button:
		_new_game_button.disabled = not enabled
	if _settings_button:
		_settings_button.disabled = not enabled
	if _exit_button:
		_exit_button.disabled = not enabled

# =============================================================================
# BUTTON HANDLERS
# =============================================================================

## Handle Continue button press (AC2)
func _on_continue_pressed() -> void:
	if _loading:
		return

	GameLogger.info("MainMenu", "Continue pressed - loading save slot %d" % DEFAULT_SAVE_SLOT)

	# SaveManager emits load_started/load_completed via EventBus
	# _on_load_started handles button disable, _on_load_completed handles transition
	SaveManager.load_game(DEFAULT_SAVE_SLOT)


## Handle New Game button press
func _on_new_game_pressed() -> void:
	if _loading:
		return

	GameLogger.info("MainMenu", "New Game pressed")

	# Emit new game signal
	EventBus.new_game_started.emit()

	# Transition to game scene
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


## Handle Settings button press
func _on_settings_pressed() -> void:
	if _loading:
		return

	GameLogger.info("MainMenu", "Settings pressed")
	EventBus.menu_opened.emit("settings")

	# Show settings screen
	if _settings_screen:
		_settings_screen.show_settings()


## Handle Exit button press
func _on_exit_pressed() -> void:
	if _loading:
		return

	GameLogger.info("MainMenu", "Exit pressed - quitting game")
	EventBus.game_quitting.emit()
	get_tree().quit()

# =============================================================================
# EVENT HANDLERS
# =============================================================================

## Handle load started event (AC4)
func _on_load_started() -> void:
	_loading = true
	_set_buttons_enabled(false)
	GameLogger.debug("MainMenu", "Load started")


## Handle load completed event (AC2, AC5)
func _on_load_completed(success: bool) -> void:
	_loading = false

	if success:
		GameLogger.info("MainMenu", "Load successful - transitioning to game")
		get_tree().change_scene_to_file(GAME_SCENE_PATH)
	else:
		GameLogger.warn("MainMenu", "Load failed - showing error dialog")
		_set_buttons_enabled(true)
		_show_error_dialog()


## Show friendly error dialog for failed loads (AC5 - cozy philosophy)
func _show_error_dialog() -> void:
	if not _error_dialog:
		GameLogger.warn("MainMenu", "Error dialog not found - cannot show error")
		return

	_error_dialog.dialog_text = "Couldn't load your save.\nWould you like to start a new adventure?"
	_error_dialog.popup_centered()

# =============================================================================
# PUBLIC API
# =============================================================================

## Check if a load is in progress
func is_loading() -> bool:
	return _loading


## Refresh the Continue button visibility (call after save operations)
func refresh_continue_button() -> void:
	_update_continue_button_visibility()


## Handle settings screen back button (AC6)
func _on_settings_back_pressed() -> void:
	GameLogger.debug("MainMenu", "Settings closed")
	# Settings screen handles its own hiding
