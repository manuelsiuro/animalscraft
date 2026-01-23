## Unit tests for Settings Screen functionality.
## Tests controls, Settings integration, and navigation.
##
## Architecture: tests/unit/test_settings_screen.gd
## Story: 6-4-create-settings-screen
extends GutTest

# =============================================================================
# TEST CONSTANTS
# =============================================================================

const SETTINGS_SCREEN_SCENE := "res://scenes/ui/menus/settings_screen.tscn"

# =============================================================================
# REFERENCES
# =============================================================================

var _settings_screen_scene: PackedScene
var _settings_screen: Control

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_all() -> void:
	_settings_screen_scene = load(SETTINGS_SCREEN_SCENE)


func before_each() -> void:
	# Store original settings values
	_store_original_settings()


func after_each() -> void:
	# Cleanup instance
	if _settings_screen and is_instance_valid(_settings_screen):
		_settings_screen.queue_free()
		_settings_screen = null
	await wait_frames(1)

	# Restore original settings
	_restore_original_settings()


# =============================================================================
# ORIGINAL SETTINGS STORAGE
# =============================================================================

var _original_music_volume: float
var _original_sfx_volume: float
var _original_muted: bool
var _original_auto_save: bool
var _original_vibration: bool
var _original_touch_sensitivity: float
var _original_colorblind_mode: String
var _original_reduce_motion: bool
var _original_large_touch: bool


func _store_original_settings() -> void:
	_original_music_volume = Settings.get_music_volume()
	_original_sfx_volume = Settings.get_sfx_volume()
	_original_muted = Settings.is_muted()
	_original_auto_save = Settings.is_auto_save_enabled()
	_original_vibration = Settings.is_vibration_enabled()
	_original_touch_sensitivity = Settings.get_touch_sensitivity()
	_original_colorblind_mode = Settings.get_colorblind_mode()
	_original_reduce_motion = Settings.is_reduce_motion_enabled()
	_original_large_touch = Settings.is_large_touch_targets_enabled()


func _restore_original_settings() -> void:
	Settings.set_music_volume(_original_music_volume)
	Settings.set_sfx_volume(_original_sfx_volume)
	Settings.set_muted(_original_muted)
	Settings.set_auto_save_enabled(_original_auto_save)
	Settings.set_vibration_enabled(_original_vibration)
	Settings.set_touch_sensitivity(_original_touch_sensitivity)
	Settings.set_colorblind_mode(_original_colorblind_mode)
	Settings.set_reduce_motion_enabled(_original_reduce_motion)
	Settings.set_large_touch_targets_enabled(_original_large_touch)


# =============================================================================
# HELPER METHODS
# =============================================================================

func _create_settings_screen() -> Control:
	_settings_screen = _settings_screen_scene.instantiate()
	add_child(_settings_screen)
	await wait_frames(1)
	return _settings_screen


# =============================================================================
# AC1: Scene Loading Tests
# =============================================================================

func test_settings_screen_scene_loads() -> void:
	# Assert
	assert_not_null(_settings_screen_scene, "Settings screen scene should load")


func test_settings_screen_instantiates() -> void:
	# Act
	await _create_settings_screen()

	# Assert
	assert_not_null(_settings_screen, "Settings screen should instantiate")
	assert_true(_settings_screen is Control, "Settings screen should be a Control")


func test_settings_screen_starts_hidden() -> void:
	# Act
	await _create_settings_screen()

	# Assert - scene is visible=false by default in tscn
	assert_false(_settings_screen.visible, "Settings screen should start hidden")


# =============================================================================
# AC2: Audio Settings Tests
# =============================================================================

func test_music_volume_slider_updates_settings() -> void:
	# Arrange
	await _create_settings_screen()
	var music_slider: HSlider = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MusicVolume/HSlider")
	assert_not_null(music_slider, "Music slider should exist")

	# Act - set slider to 50%
	music_slider.value = 50.0
	await wait_frames(1)

	# Assert
	assert_almost_eq(Settings.get_music_volume(), 0.5, 0.01, "Music volume should be 0.5 (AC2)")


func test_sfx_volume_slider_updates_settings() -> void:
	# Arrange
	await _create_settings_screen()
	var sfx_slider: HSlider = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/SfxVolume/HSlider")
	assert_not_null(sfx_slider, "SFX slider should exist")

	# Act - set slider to 75%
	sfx_slider.value = 75.0
	await wait_frames(1)

	# Assert
	assert_almost_eq(Settings.get_sfx_volume(), 0.75, 0.01, "SFX volume should be 0.75 (AC2)")


func test_mute_toggle_updates_settings() -> void:
	# Arrange
	await _create_settings_screen()
	var mute_toggle: CheckButton = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MuteToggle")
	assert_not_null(mute_toggle, "Mute toggle should exist")

	# Ensure mute is off first
	Settings.set_muted(false)
	await wait_frames(1)

	# Act - enable mute
	mute_toggle.button_pressed = true
	await wait_frames(1)

	# Assert
	assert_true(Settings.is_muted(), "Mute should be enabled (AC2)")


# =============================================================================
# AC3: Gameplay Settings Tests
# =============================================================================

func test_auto_save_toggle_updates_settings() -> void:
	# Arrange
	await _create_settings_screen()
	var auto_save_toggle: CheckButton = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/GameplaySection/AutoSaveToggle")
	assert_not_null(auto_save_toggle, "Auto-save toggle should exist")

	# Start with auto-save enabled
	Settings.set_auto_save_enabled(true)
	_settings_screen.show_settings()
	await wait_frames(1)

	# Act - disable auto-save
	auto_save_toggle.button_pressed = false
	await wait_frames(1)

	# Assert
	assert_false(Settings.is_auto_save_enabled(), "Auto-save should be disabled (AC3)")


func test_vibration_toggle_updates_settings() -> void:
	# Arrange
	await _create_settings_screen()
	var vibration_toggle: CheckButton = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/GameplaySection/VibrationToggle")
	assert_not_null(vibration_toggle, "Vibration toggle should exist")

	# Start with vibration enabled
	Settings.set_vibration_enabled(true)
	_settings_screen.show_settings()
	await wait_frames(1)

	# Act - disable vibration
	vibration_toggle.button_pressed = false
	await wait_frames(1)

	# Assert
	assert_false(Settings.is_vibration_enabled(), "Vibration should be disabled (AC3)")


func test_touch_sensitivity_slider_updates_settings() -> void:
	# Arrange
	await _create_settings_screen()
	var sensitivity_slider: HSlider = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/GameplaySection/TouchSensitivity/HSlider")
	assert_not_null(sensitivity_slider, "Touch sensitivity slider should exist")

	# Act - set to 150%
	sensitivity_slider.value = 150.0
	await wait_frames(1)

	# Assert
	assert_almost_eq(Settings.get_touch_sensitivity(), 1.5, 0.01, "Touch sensitivity should be 1.5 (AC3)")


# =============================================================================
# AC4: Accessibility Settings Tests
# =============================================================================

func test_colorblind_mode_dropdown_updates_settings() -> void:
	# Arrange
	await _create_settings_screen()
	var colorblind_dropdown: OptionButton = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AccessibilitySection/ColorblindMode/OptionButton")
	assert_not_null(colorblind_dropdown, "Colorblind dropdown should exist")

	# Act - select deuteranopia (index 1)
	colorblind_dropdown.select(1)
	colorblind_dropdown.item_selected.emit(1)
	await wait_frames(1)

	# Assert
	assert_eq(Settings.get_colorblind_mode(), "deuteranopia", "Colorblind mode should be deuteranopia (AC4)")


func test_reduced_motion_toggle_updates_settings() -> void:
	# Arrange
	await _create_settings_screen()
	var reduce_motion_toggle: CheckButton = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AccessibilitySection/ReduceMotionToggle")
	assert_not_null(reduce_motion_toggle, "Reduce motion toggle should exist")

	# Start with reduce motion disabled
	Settings.set_reduce_motion_enabled(false)
	_settings_screen.show_settings()
	await wait_frames(1)

	# Act - enable reduce motion
	reduce_motion_toggle.button_pressed = true
	await wait_frames(1)

	# Assert
	assert_true(Settings.is_reduce_motion_enabled(), "Reduce motion should be enabled (AC4)")


func test_large_touch_targets_toggle_updates_settings() -> void:
	# Arrange
	await _create_settings_screen()
	var large_touch_toggle: CheckButton = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AccessibilitySection/LargeTouchToggle")
	assert_not_null(large_touch_toggle, "Large touch toggle should exist")

	# Start with large touch disabled
	Settings.set_large_touch_targets_enabled(false)
	_settings_screen.show_settings()
	await wait_frames(1)

	# Act - enable large touch targets
	large_touch_toggle.button_pressed = true
	await wait_frames(1)

	# Assert
	assert_true(Settings.is_large_touch_targets_enabled(), "Large touch targets should be enabled (AC4)")


# =============================================================================
# AC5: Settings Persistence Tests
# =============================================================================

func test_controls_initialize_from_settings() -> void:
	# Arrange - set specific values before creating screen
	Settings.set_music_volume(0.3)
	Settings.set_sfx_volume(0.6)
	Settings.set_muted(true)
	Settings.set_auto_save_enabled(false)
	await wait_frames(1)

	# Act - create settings screen (which should load from Settings)
	await _create_settings_screen()

	# Assert - controls should reflect Settings values
	var music_slider: HSlider = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MusicVolume/HSlider")
	var sfx_slider: HSlider = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/SfxVolume/HSlider")
	var mute_toggle: CheckButton = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MuteToggle")
	var auto_save_toggle: CheckButton = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/GameplaySection/AutoSaveToggle")

	assert_almost_eq(music_slider.value, 30.0, 1.0, "Music slider should initialize to 30% (AC5)")
	assert_almost_eq(sfx_slider.value, 60.0, 1.0, "SFX slider should initialize to 60% (AC5)")
	assert_true(mute_toggle.button_pressed, "Mute toggle should be enabled (AC5)")
	assert_false(auto_save_toggle.button_pressed, "Auto-save toggle should be disabled (AC5)")


# =============================================================================
# AC6: Navigation Tests
# =============================================================================

func test_back_button_emits_signal() -> void:
	# Arrange
	await _create_settings_screen()
	_settings_screen.show()
	watch_signals(_settings_screen)

	var back_button: Button = _settings_screen.get_node("VBoxContainer/Header/BackButton")
	assert_not_null(back_button, "Back button should exist")

	# Act
	back_button.pressed.emit()
	await wait_frames(1)

	# Assert
	assert_signal_emitted(_settings_screen, "back_pressed", "back_pressed signal should emit (AC6)")


func test_back_button_hides_settings() -> void:
	# Arrange
	await _create_settings_screen()
	_settings_screen.show()
	assert_true(_settings_screen.visible, "Settings should be visible before test")

	var back_button: Button = _settings_screen.get_node("VBoxContainer/Header/BackButton")

	# Act
	back_button.pressed.emit()
	await wait_frames(1)

	# Assert
	assert_false(_settings_screen.visible, "Settings screen should be hidden after back (AC6)")


func test_ui_cancel_action_triggers_back() -> void:
	# Arrange - Issue #3: Test Android back button / ui_cancel action
	await _create_settings_screen()
	_settings_screen.show()
	watch_signals(_settings_screen)
	assert_true(_settings_screen.visible, "Settings should be visible before test")

	# Act - simulate ui_cancel action (Android back button)
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	_settings_screen._input(event)
	await wait_frames(1)

	# Assert
	assert_signal_emitted(_settings_screen, "back_pressed", "back_pressed signal should emit on ui_cancel (AC6)")
	assert_false(_settings_screen.visible, "Settings screen should be hidden after ui_cancel (AC6)")


# =============================================================================
# AC7: Reset to Defaults Tests
# =============================================================================

func test_reset_to_defaults_restores_all_values() -> void:
	# Arrange - set non-default values
	Settings.set_music_volume(0.2)
	Settings.set_sfx_volume(0.3)
	Settings.set_muted(true)
	Settings.set_auto_save_enabled(false)
	Settings.set_vibration_enabled(false)
	Settings.set_touch_sensitivity(2.0)
	Settings.set_colorblind_mode("protanopia")
	Settings.set_reduce_motion_enabled(true)
	Settings.set_large_touch_targets_enabled(true)

	await _create_settings_screen()
	_settings_screen.show_settings()
	await wait_frames(1)

	# Get reset dialog and trigger via confirmation workflow (Issue #1, #4)
	var reset_dialog: ConfirmationDialog = _settings_screen.get_node("ResetConfirmDialog")
	assert_not_null(reset_dialog, "Reset dialog should exist")

	# Act - trigger reset via dialog confirmation (simulates user clicking OK)
	reset_dialog.confirmed.emit()
	await wait_frames(1)

	# Assert - verify Settings values are reset (from Settings autoload DEFAULTS)
	assert_almost_eq(Settings.get_music_volume(), 0.8, 0.01, "Music volume should reset to 0.8 (AC7)")
	assert_almost_eq(Settings.get_sfx_volume(), 1.0, 0.01, "SFX volume should reset to 1.0 (AC7)")
	assert_false(Settings.is_muted(), "Mute should reset to false (AC7)")
	assert_true(Settings.is_auto_save_enabled(), "Auto-save should reset to true (AC7)")
	assert_true(Settings.is_vibration_enabled(), "Vibration should reset to true (AC7)")
	assert_almost_eq(Settings.get_touch_sensitivity(), 1.0, 0.01, "Touch sensitivity should reset to 1.0 (AC7)")
	assert_eq(Settings.get_colorblind_mode(), "none", "Colorblind mode should reset to none (AC7)")
	assert_false(Settings.is_reduce_motion_enabled(), "Reduce motion should reset to false (AC7)")
	assert_false(Settings.is_large_touch_targets_enabled(), "Large touch should reset to false (AC7)")

	# Assert - verify UI controls are also updated (Issue #4)
	var music_slider: HSlider = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MusicVolume/HSlider")
	var sfx_slider: HSlider = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/SfxVolume/HSlider")
	var mute_toggle: CheckButton = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MuteToggle")
	var auto_save_toggle: CheckButton = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/GameplaySection/AutoSaveToggle")

	assert_almost_eq(music_slider.value, 80.0, 1.0, "Music slider should show 80% after reset (AC7)")
	assert_almost_eq(sfx_slider.value, 100.0, 1.0, "SFX slider should show 100% after reset (AC7)")
	assert_false(mute_toggle.button_pressed, "Mute toggle should be off after reset (AC7)")
	assert_true(auto_save_toggle.button_pressed, "Auto-save toggle should be on after reset (AC7)")


func test_reset_dialog_exists() -> void:
	# Act
	await _create_settings_screen()

	# Assert
	var reset_dialog: ConfirmationDialog = _settings_screen.get_node("ResetConfirmDialog")
	assert_not_null(reset_dialog, "Reset confirmation dialog should exist (AC7)")


func test_reset_button_shows_dialog() -> void:
	# Arrange
	await _create_settings_screen()
	_settings_screen.show()

	var reset_button: Button = _settings_screen.get_node("VBoxContainer/Footer/ResetButton")
	var reset_dialog: ConfirmationDialog = _settings_screen.get_node("ResetConfirmDialog")
	assert_not_null(reset_button, "Reset button should exist")
	assert_not_null(reset_dialog, "Reset dialog should exist")

	# Act
	reset_button.pressed.emit()
	await wait_frames(1)

	# Assert
	assert_true(reset_dialog.visible, "Reset dialog should be visible after pressing reset (AC7)")


# =============================================================================
# AC8: EventBus Integration Tests
# =============================================================================

func test_setting_changed_signal_emitted_on_music_change() -> void:
	# Arrange
	await _create_settings_screen()
	watch_signals(EventBus)

	var music_slider: HSlider = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MusicVolume/HSlider")

	# Act
	music_slider.value = 40.0
	await wait_frames(1)

	# Assert
	assert_signal_emitted(EventBus, "setting_changed", "setting_changed should emit on music change (AC8)")


func test_setting_changed_signal_emitted_on_toggle_change() -> void:
	# Arrange
	await _create_settings_screen()

	# Ensure mute starts as false
	Settings.set_muted(false)
	_settings_screen.show_settings()
	await wait_frames(1)

	watch_signals(EventBus)

	var mute_toggle: CheckButton = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MuteToggle")

	# Act
	mute_toggle.button_pressed = true
	await wait_frames(1)

	# Assert
	assert_signal_emitted(EventBus, "setting_changed", "setting_changed should emit on mute toggle (AC8)")


# =============================================================================
# UI Structure Tests
# =============================================================================

func test_audio_section_exists() -> void:
	# Act
	await _create_settings_screen()

	# Assert
	var audio_section = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AudioSection")
	assert_not_null(audio_section, "Audio section should exist")


func test_gameplay_section_exists() -> void:
	# Act
	await _create_settings_screen()

	# Assert
	var gameplay_section = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/GameplaySection")
	assert_not_null(gameplay_section, "Gameplay section should exist")


func test_accessibility_section_exists() -> void:
	# Act
	await _create_settings_screen()

	# Assert
	var accessibility_section = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AccessibilitySection")
	assert_not_null(accessibility_section, "Accessibility section should exist")


func test_show_settings_makes_visible_and_refreshes() -> void:
	# Arrange
	Settings.set_music_volume(0.5)
	await _create_settings_screen()
	assert_false(_settings_screen.visible, "Should start hidden")

	# Act
	_settings_screen.show_settings()
	await wait_frames(1)

	# Assert
	assert_true(_settings_screen.visible, "show_settings() should make screen visible")

	var music_slider: HSlider = _settings_screen.get_node("VBoxContainer/ScrollContainer/SettingsContainer/AudioSection/MusicVolume/HSlider")
	assert_almost_eq(music_slider.value, 50.0, 1.0, "Controls should be refreshed after show_settings()")
