## Settings screen for AnimalsCraft.
## Provides UI controls for audio, gameplay, and accessibility settings.
##
## Architecture: scripts/ui/menus/settings_screen.gd
## Story: 6-4-create-settings-screen
extends Control

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the back button is pressed
signal back_pressed

# =============================================================================
# CONSTANTS
# =============================================================================

## Colorblind mode string mappings
const COLORBLIND_MODES := ["none", "deuteranopia", "protanopia", "tritanopia"]

## Colorblind mode display names
const COLORBLIND_LABELS := ["None", "Deuteranopia", "Protanopia", "Tritanopia"]

# =============================================================================
# NODE REFERENCES
# =============================================================================

# Header
@onready var _back_button: Button = $VBoxContainer/Header/BackButton

# Audio Section
@onready var _music_slider: HSlider = $VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MusicVolume/HSlider
@onready var _music_value_label: Label = $VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MusicVolume/ValueLabel
@onready var _sfx_slider: HSlider = $VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/SfxVolume/HSlider
@onready var _sfx_value_label: Label = $VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/SfxVolume/ValueLabel
@onready var _mute_toggle: CheckButton = $VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MuteToggle

# Gameplay Section
@onready var _auto_save_toggle: CheckButton = $VBoxContainer/ScrollContainer/SettingsContainer/GameplaySection/AutoSaveToggle
@onready var _vibration_toggle: CheckButton = $VBoxContainer/ScrollContainer/SettingsContainer/GameplaySection/VibrationToggle
@onready var _touch_sensitivity_slider: HSlider = $VBoxContainer/ScrollContainer/SettingsContainer/GameplaySection/TouchSensitivity/HSlider
@onready var _touch_sensitivity_label: Label = $VBoxContainer/ScrollContainer/SettingsContainer/GameplaySection/TouchSensitivity/ValueLabel
@onready var _reset_tutorial_button: Button = $VBoxContainer/ScrollContainer/SettingsContainer/GameplaySection/ResetTutorialButton

# Accessibility Section
@onready var _colorblind_dropdown: OptionButton = $VBoxContainer/ScrollContainer/SettingsContainer/AccessibilitySection/ColorblindMode/OptionButton
@onready var _reduce_motion_toggle: CheckButton = $VBoxContainer/ScrollContainer/SettingsContainer/AccessibilitySection/ReduceMotionToggle
@onready var _large_touch_toggle: CheckButton = $VBoxContainer/ScrollContainer/SettingsContainer/AccessibilitySection/LargeTouchToggle

# Footer
@onready var _reset_button: Button = $VBoxContainer/Footer/ResetButton
@onready var _reset_dialog: ConfirmationDialog = $ResetConfirmDialog
@onready var _tutorial_reset_dialog: ConfirmationDialog = $TutorialResetDialog

# =============================================================================
# STATE
# =============================================================================

## Flag to prevent recursive signal handling during initialization
var _initializing: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_initializing = true

	# Setup colorblind dropdown options
	_setup_colorblind_dropdown()

	# Connect all control signals
	_connect_signals()

	# Initialize all controls from Settings
	_refresh_all_controls()

	_initializing = false

	GameLogger.info("SettingsScreen", "Settings screen initialized")


func _exit_tree() -> void:
	# Disconnect signals if connected
	_disconnect_signals()

# =============================================================================
# INPUT HANDLING (AC6 - Android back button)
# =============================================================================

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

# =============================================================================
# SIGNAL CONNECTIONS
# =============================================================================

func _connect_signals() -> void:
	# Header
	if _back_button:
		_back_button.pressed.connect(_on_back_pressed)

	# Audio
	if _music_slider:
		_music_slider.value_changed.connect(_on_music_volume_changed)
	if _sfx_slider:
		_sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	if _mute_toggle:
		_mute_toggle.toggled.connect(_on_mute_toggled)

	# Gameplay
	if _auto_save_toggle:
		_auto_save_toggle.toggled.connect(_on_auto_save_toggled)
	if _vibration_toggle:
		_vibration_toggle.toggled.connect(_on_vibration_toggled)
	if _touch_sensitivity_slider:
		_touch_sensitivity_slider.value_changed.connect(_on_touch_sensitivity_changed)

	# Accessibility
	if _colorblind_dropdown:
		_colorblind_dropdown.item_selected.connect(_on_colorblind_mode_selected)
	if _reduce_motion_toggle:
		_reduce_motion_toggle.toggled.connect(_on_reduce_motion_toggled)
	if _large_touch_toggle:
		_large_touch_toggle.toggled.connect(_on_large_touch_toggled)

	# Footer
	if _reset_button:
		_reset_button.pressed.connect(_on_reset_pressed)
	if _reset_dialog:
		_reset_dialog.confirmed.connect(_on_reset_confirmed)

	# Tutorial Reset (Story 6-9)
	if _reset_tutorial_button:
		_reset_tutorial_button.pressed.connect(_on_reset_tutorial_pressed)
	if _tutorial_reset_dialog:
		_tutorial_reset_dialog.confirmed.connect(_on_tutorial_reset_confirmed)


func _disconnect_signals() -> void:
	if _back_button and _back_button.pressed.is_connected(_on_back_pressed):
		_back_button.pressed.disconnect(_on_back_pressed)
	if _music_slider and _music_slider.value_changed.is_connected(_on_music_volume_changed):
		_music_slider.value_changed.disconnect(_on_music_volume_changed)
	if _sfx_slider and _sfx_slider.value_changed.is_connected(_on_sfx_volume_changed):
		_sfx_slider.value_changed.disconnect(_on_sfx_volume_changed)
	if _mute_toggle and _mute_toggle.toggled.is_connected(_on_mute_toggled):
		_mute_toggle.toggled.disconnect(_on_mute_toggled)
	if _auto_save_toggle and _auto_save_toggle.toggled.is_connected(_on_auto_save_toggled):
		_auto_save_toggle.toggled.disconnect(_on_auto_save_toggled)
	if _vibration_toggle and _vibration_toggle.toggled.is_connected(_on_vibration_toggled):
		_vibration_toggle.toggled.disconnect(_on_vibration_toggled)
	if _touch_sensitivity_slider and _touch_sensitivity_slider.value_changed.is_connected(_on_touch_sensitivity_changed):
		_touch_sensitivity_slider.value_changed.disconnect(_on_touch_sensitivity_changed)
	if _colorblind_dropdown and _colorblind_dropdown.item_selected.is_connected(_on_colorblind_mode_selected):
		_colorblind_dropdown.item_selected.disconnect(_on_colorblind_mode_selected)
	if _reduce_motion_toggle and _reduce_motion_toggle.toggled.is_connected(_on_reduce_motion_toggled):
		_reduce_motion_toggle.toggled.disconnect(_on_reduce_motion_toggled)
	if _large_touch_toggle and _large_touch_toggle.toggled.is_connected(_on_large_touch_toggled):
		_large_touch_toggle.toggled.disconnect(_on_large_touch_toggled)
	if _reset_button and _reset_button.pressed.is_connected(_on_reset_pressed):
		_reset_button.pressed.disconnect(_on_reset_pressed)
	if _reset_dialog and _reset_dialog.confirmed.is_connected(_on_reset_confirmed):
		_reset_dialog.confirmed.disconnect(_on_reset_confirmed)
	if _reset_tutorial_button and _reset_tutorial_button.pressed.is_connected(_on_reset_tutorial_pressed):
		_reset_tutorial_button.pressed.disconnect(_on_reset_tutorial_pressed)
	if _tutorial_reset_dialog and _tutorial_reset_dialog.confirmed.is_connected(_on_tutorial_reset_confirmed):
		_tutorial_reset_dialog.confirmed.disconnect(_on_tutorial_reset_confirmed)

# =============================================================================
# SETUP
# =============================================================================

func _setup_colorblind_dropdown() -> void:
	if not _colorblind_dropdown:
		return

	_colorblind_dropdown.clear()
	for i in range(COLORBLIND_LABELS.size()):
		_colorblind_dropdown.add_item(COLORBLIND_LABELS[i], i)

# =============================================================================
# CONTROL REFRESH (AC5 - Initialize from Settings)
# =============================================================================

## Refresh all controls to match current Settings values
func _refresh_all_controls() -> void:
	_initializing = true

	# Audio
	if _music_slider:
		_music_slider.value = Settings.get_music_volume() * 100.0
		_update_music_label()
	if _sfx_slider:
		_sfx_slider.value = Settings.get_sfx_volume() * 100.0
		_update_sfx_label()
	if _mute_toggle:
		_mute_toggle.button_pressed = Settings.is_muted()

	# Gameplay
	if _auto_save_toggle:
		_auto_save_toggle.button_pressed = Settings.is_auto_save_enabled()
	if _vibration_toggle:
		_vibration_toggle.button_pressed = Settings.is_vibration_enabled()
	if _touch_sensitivity_slider:
		_touch_sensitivity_slider.value = Settings.get_touch_sensitivity() * 100.0
		_update_touch_sensitivity_label()

	# Accessibility
	if _colorblind_dropdown:
		var current_mode := Settings.get_colorblind_mode()
		var mode_index := COLORBLIND_MODES.find(current_mode)
		if mode_index >= 0:
			_colorblind_dropdown.select(mode_index)
		else:
			_colorblind_dropdown.select(0)  # Default to "None"
	if _reduce_motion_toggle:
		_reduce_motion_toggle.button_pressed = Settings.is_reduce_motion_enabled()
	if _large_touch_toggle:
		_large_touch_toggle.button_pressed = Settings.is_large_touch_targets_enabled()

	_initializing = false
	GameLogger.debug("SettingsScreen", "All controls refreshed from Settings")

# =============================================================================
# LABEL UPDATES
# =============================================================================

func _update_music_label() -> void:
	if _music_value_label and _music_slider:
		_music_value_label.text = "%d%%" % int(_music_slider.value)


func _update_sfx_label() -> void:
	if _sfx_value_label and _sfx_slider:
		_sfx_value_label.text = "%d%%" % int(_sfx_slider.value)


func _update_touch_sensitivity_label() -> void:
	if _touch_sensitivity_label and _touch_sensitivity_slider:
		_touch_sensitivity_label.text = "%d%%" % int(_touch_sensitivity_slider.value)

# =============================================================================
# AUDIO HANDLERS (AC2)
# =============================================================================

func _on_music_volume_changed(value: float) -> void:
	_update_music_label()
	if _initializing:
		return
	Settings.set_music_volume(value / 100.0)
	GameLogger.debug("SettingsScreen", "Music volume set to %.0f%%" % value)


func _on_sfx_volume_changed(value: float) -> void:
	_update_sfx_label()
	if _initializing:
		return
	Settings.set_sfx_volume(value / 100.0)
	GameLogger.debug("SettingsScreen", "SFX volume set to %.0f%%" % value)


func _on_mute_toggled(pressed: bool) -> void:
	if _initializing:
		return
	Settings.set_muted(pressed)
	GameLogger.debug("SettingsScreen", "Mute set to %s" % pressed)

# =============================================================================
# GAMEPLAY HANDLERS (AC3)
# =============================================================================

func _on_auto_save_toggled(pressed: bool) -> void:
	if _initializing:
		return
	Settings.set_auto_save_enabled(pressed)
	GameLogger.debug("SettingsScreen", "Auto-save set to %s" % pressed)


func _on_vibration_toggled(pressed: bool) -> void:
	if _initializing:
		return
	Settings.set_vibration_enabled(pressed)
	GameLogger.debug("SettingsScreen", "Vibration set to %s" % pressed)


func _on_touch_sensitivity_changed(value: float) -> void:
	_update_touch_sensitivity_label()
	if _initializing:
		return
	Settings.set_touch_sensitivity(value / 100.0)
	GameLogger.debug("SettingsScreen", "Touch sensitivity set to %.0f%%" % value)

# =============================================================================
# ACCESSIBILITY HANDLERS (AC4)
# =============================================================================

func _on_colorblind_mode_selected(index: int) -> void:
	if _initializing:
		return
	if index >= 0 and index < COLORBLIND_MODES.size():
		Settings.set_colorblind_mode(COLORBLIND_MODES[index])
		GameLogger.debug("SettingsScreen", "Colorblind mode set to %s" % COLORBLIND_MODES[index])


func _on_reduce_motion_toggled(pressed: bool) -> void:
	if _initializing:
		return
	Settings.set_reduce_motion_enabled(pressed)
	GameLogger.debug("SettingsScreen", "Reduce motion set to %s" % pressed)


func _on_large_touch_toggled(pressed: bool) -> void:
	if _initializing:
		return
	Settings.set_large_touch_targets_enabled(pressed)
	GameLogger.debug("SettingsScreen", "Large touch targets set to %s" % pressed)

# =============================================================================
# NAVIGATION HANDLERS (AC6)
# =============================================================================

func _on_back_pressed() -> void:
	GameLogger.info("SettingsScreen", "Back pressed")
	back_pressed.emit()
	hide()

# =============================================================================
# RESET HANDLERS (AC7)
# =============================================================================

func _on_reset_pressed() -> void:
	if not _reset_dialog:
		return
	_reset_dialog.popup_centered()
	GameLogger.debug("SettingsScreen", "Reset confirmation shown")


func _on_reset_confirmed() -> void:
	Settings.reset_to_defaults()
	_refresh_all_controls()
	GameLogger.info("SettingsScreen", "Settings reset to defaults")

# =============================================================================
# TUTORIAL RESET HANDLERS (Story 6-9, AC14)
# =============================================================================

func _on_reset_tutorial_pressed() -> void:
	if not _tutorial_reset_dialog:
		return
	_tutorial_reset_dialog.popup_centered()
	GameLogger.debug("SettingsScreen", "Tutorial reset confirmation shown")


func _on_tutorial_reset_confirmed() -> void:
	if is_instance_valid(TutorialManager):
		TutorialManager.reset_all()
		GameLogger.info("SettingsScreen", "Tutorial progress reset")
	else:
		GameLogger.warn("SettingsScreen", "TutorialManager not available for reset")

# =============================================================================
# PUBLIC API
# =============================================================================

## Show the settings screen and refresh controls
func show_settings() -> void:
	_refresh_all_controls()
	show()
	GameLogger.debug("SettingsScreen", "Settings screen shown")
