## Player settings persistence for AnimalsCraft.
## Autoload singleton - access via Settings.get_*/set_*
##
## Architecture: autoloads/settings.gd
## Order: 5 (depends on EventBus)
## Source: game-architecture.md#Configuration
##
## Stores player preferences in user://settings.cfg
## Emits EventBus.setting_changed when values change
class_name Settings
extends Node

# =============================================================================
# CONFIGURATION
# =============================================================================

## Path to the settings file
const SETTINGS_PATH: String = "user://settings.cfg"

## Internal ConfigFile for persistence
var _config := ConfigFile.new()

## Track if settings have been modified since last save
var _dirty: bool = false

# =============================================================================
# SECTION NAMES
# =============================================================================

const SECTION_AUDIO: String = "audio"
const SECTION_GAMEPLAY: String = "gameplay"
const SECTION_DISPLAY: String = "display"
const SECTION_ACCESSIBILITY: String = "accessibility"

# =============================================================================
# DEFAULT VALUES
# =============================================================================

const DEFAULTS: Dictionary = {
	"audio": {
		"music_volume": 0.8,
		"sfx_volume": 1.0,
		"muted": false,
	},
	"gameplay": {
		"touch_sensitivity": 1.0,
		"tutorial_completed": false,
		"auto_save_enabled": true,
		"vibration_enabled": true,
	},
	"display": {
		"show_fps": false,
		"ui_scale": 1.0,
	},
	"accessibility": {
		"colorblind_mode": "none",  # none, deuteranopia, protanopia, tritanopia
		"reduce_motion": false,
		"large_touch_targets": false,
	},
}

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_load_settings()


func _notification(what: int) -> void:
	# Save settings when app is paused or closed
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		if _dirty:
			_save_settings()


# =============================================================================
# AUDIO SETTINGS
# =============================================================================

## Get the current music volume (0.0 to 1.0).
func get_music_volume() -> float:
	return _config.get_value(SECTION_AUDIO, "music_volume", DEFAULTS.audio.music_volume)


## Set the music volume.
## @param value Volume between 0.0 and 1.0
func set_music_volume(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	_set_value(SECTION_AUDIO, "music_volume", value)


## Get the current SFX volume (0.0 to 1.0).
func get_sfx_volume() -> float:
	return _config.get_value(SECTION_AUDIO, "sfx_volume", DEFAULTS.audio.sfx_volume)


## Set the SFX volume.
## @param value Volume between 0.0 and 1.0
func set_sfx_volume(value: float) -> void:
	value = clampf(value, 0.0, 1.0)
	_set_value(SECTION_AUDIO, "sfx_volume", value)


## Check if audio is muted.
func is_muted() -> bool:
	return _config.get_value(SECTION_AUDIO, "muted", DEFAULTS.audio.muted)


## Set muted state.
## @param value True to mute all audio
func set_muted(value: bool) -> void:
	_set_value(SECTION_AUDIO, "muted", value)


# =============================================================================
# GAMEPLAY SETTINGS
# =============================================================================

## Get touch sensitivity multiplier.
func get_touch_sensitivity() -> float:
	return _config.get_value(SECTION_GAMEPLAY, "touch_sensitivity", DEFAULTS.gameplay.touch_sensitivity)


## Set touch sensitivity.
## @param value Sensitivity multiplier (0.5 to 2.0 recommended)
func set_touch_sensitivity(value: float) -> void:
	value = clampf(value, 0.25, 4.0)
	_set_value(SECTION_GAMEPLAY, "touch_sensitivity", value)


## Check if tutorial has been completed.
func is_tutorial_completed() -> bool:
	return _config.get_value(SECTION_GAMEPLAY, "tutorial_completed", DEFAULTS.gameplay.tutorial_completed)


## Set tutorial completion state.
## @param value True if tutorial is completed
func set_tutorial_completed(value: bool) -> void:
	_set_value(SECTION_GAMEPLAY, "tutorial_completed", value)


## Check if auto-save is enabled.
func is_auto_save_enabled() -> bool:
	return _config.get_value(SECTION_GAMEPLAY, "auto_save_enabled", DEFAULTS.gameplay.auto_save_enabled)


## Set auto-save state.
## @param value True to enable auto-save
func set_auto_save_enabled(value: bool) -> void:
	_set_value(SECTION_GAMEPLAY, "auto_save_enabled", value)


## Check if vibration is enabled.
func is_vibration_enabled() -> bool:
	return _config.get_value(SECTION_GAMEPLAY, "vibration_enabled", DEFAULTS.gameplay.vibration_enabled)


## Set vibration state.
## @param value True to enable vibration feedback
func set_vibration_enabled(value: bool) -> void:
	_set_value(SECTION_GAMEPLAY, "vibration_enabled", value)


# =============================================================================
# DISPLAY SETTINGS
# =============================================================================

## Check if FPS counter should be shown.
func is_fps_visible() -> bool:
	return _config.get_value(SECTION_DISPLAY, "show_fps", DEFAULTS.display.show_fps)


## Set FPS counter visibility.
## @param value True to show FPS counter
func set_fps_visible(value: bool) -> void:
	_set_value(SECTION_DISPLAY, "show_fps", value)


## Get UI scale multiplier.
func get_ui_scale() -> float:
	return _config.get_value(SECTION_DISPLAY, "ui_scale", DEFAULTS.display.ui_scale)


## Set UI scale.
## @param value Scale multiplier (0.75 to 1.5 recommended)
func set_ui_scale(value: float) -> void:
	value = clampf(value, 0.5, 2.0)
	_set_value(SECTION_DISPLAY, "ui_scale", value)


# =============================================================================
# ACCESSIBILITY SETTINGS
# =============================================================================

## Get colorblind mode.
## @return One of: "none", "deuteranopia", "protanopia", "tritanopia"
func get_colorblind_mode() -> String:
	return _config.get_value(SECTION_ACCESSIBILITY, "colorblind_mode", DEFAULTS.accessibility.colorblind_mode)


## Set colorblind mode.
## @param mode One of: "none", "deuteranopia", "protanopia", "tritanopia"
func set_colorblind_mode(mode: String) -> void:
	var valid_modes := ["none", "deuteranopia", "protanopia", "tritanopia"]
	if mode not in valid_modes:
		mode = "none"
	_set_value(SECTION_ACCESSIBILITY, "colorblind_mode", mode)


## Check if reduced motion is enabled.
func is_reduce_motion_enabled() -> bool:
	return _config.get_value(SECTION_ACCESSIBILITY, "reduce_motion", DEFAULTS.accessibility.reduce_motion)


## Set reduced motion state.
## @param value True to reduce motion/animations
func set_reduce_motion_enabled(value: bool) -> void:
	_set_value(SECTION_ACCESSIBILITY, "reduce_motion", value)


## Check if large touch targets are enabled.
func is_large_touch_targets_enabled() -> bool:
	return _config.get_value(SECTION_ACCESSIBILITY, "large_touch_targets", DEFAULTS.accessibility.large_touch_targets)


## Set large touch targets state.
## @param value True to enable larger touch targets
func set_large_touch_targets_enabled(value: bool) -> void:
	_set_value(SECTION_ACCESSIBILITY, "large_touch_targets", value)


# =============================================================================
# GENERIC ACCESS
# =============================================================================

## Get any setting value by section and key.
## @param section The section name
## @param key The setting key
## @param default Default value if not found
func get_value(section: String, key: String, default: Variant = null) -> Variant:
	return _config.get_value(section, key, default)


## Set any setting value by section and key.
## @param section The section name
## @param key The setting key
## @param value The value to set
func set_value(section: String, key: String, value: Variant) -> void:
	_set_value(section, key, value)


## Reset all settings to defaults.
func reset_to_defaults() -> void:
	_config = ConfigFile.new()

	# Apply all defaults
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			_config.set_value(section, key, DEFAULTS[section][key])

	_save_settings()
	Logger.info("Settings", "Reset all settings to defaults")


## Force save settings to disk.
func save() -> void:
	_save_settings()


# =============================================================================
# INTERNAL METHODS
# =============================================================================

## Set a value and mark as dirty.
func _set_value(section: String, key: String, value: Variant) -> void:
	var old_value = _config.get_value(section, key, null)
	if old_value != value:
		_config.set_value(section, key, value)
		_dirty = true

		# Emit change event (with null safety check for EventBus dependency)
		if is_instance_valid(EventBus):
			var setting_name := "%s.%s" % [section, key]
			EventBus.setting_changed.emit(setting_name, value)

		# Auto-save after changes
		_save_settings()


## Load settings from disk.
func _load_settings() -> void:
	var err := _config.load(SETTINGS_PATH)

	if err != OK:
		if err == ERR_FILE_NOT_FOUND:
			Logger.info("Settings", "No settings file found, using defaults")
			_apply_defaults()
			_save_settings()
		else:
			Logger.warn("Settings", "Failed to load settings: %s" % error_string(err))
			_apply_defaults()
	else:
		Logger.info("Settings", "Settings loaded successfully")
		# Ensure all default keys exist (for version upgrades)
		_ensure_all_keys_exist()


## Apply default values to config.
func _apply_defaults() -> void:
	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			_config.set_value(section, key, DEFAULTS[section][key])


## Ensure all default keys exist (handles version upgrades).
func _ensure_all_keys_exist() -> void:
	var added_keys := false

	for section in DEFAULTS:
		for key in DEFAULTS[section]:
			if not _config.has_section_key(section, key):
				_config.set_value(section, key, DEFAULTS[section][key])
				added_keys = true
				Logger.info("Settings", "Added new setting: %s.%s" % [section, key])

	if added_keys:
		_save_settings()


## Save settings to disk.
func _save_settings() -> void:
	var err := _config.save(SETTINGS_PATH)

	if err != OK:
		Logger.error("Settings", "Failed to save settings: %s" % error_string(err))
	else:
		_dirty = false
