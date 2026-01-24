## Unit tests for TutorialManager (Story 6-9).
##
## Tests cover:
## - Tutorial state tracking (AC1)
## - Step completion (AC1)
## - Skip all tutorials (AC13)
## - Reset tutorials (AC14)
## - Save/Load persistence (AC12)
##
## Architecture: tests/unit/test_tutorial_manager.gd
## Story: 6-9-implement-tutorial-flow
extends GutTest

# =============================================================================
# CONSTANTS
# =============================================================================

const TutorialManagerScript := preload("res://autoloads/tutorial_manager.gd")

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _manager: Node = null


func before_each() -> void:
	# Create a fresh manager instance for each test
	_manager = TutorialManagerScript.new()
	add_child(_manager)
	await wait_frames(1)


func after_each() -> void:
	if _manager and is_instance_valid(_manager):
		_manager.queue_free()
		_manager = null


# =============================================================================
# AC1: Tutorial System Exists
# =============================================================================

func test_tutorial_manager_initializes() -> void:
	assert_not_null(_manager, "TutorialManager should initialize")
	assert_true(_manager.is_tutorial_enabled(), "Tutorial should be enabled by default")


func test_tutorial_step_enum_has_all_steps() -> void:
	var step_count: int = _manager.TutorialStep.size()
	assert_eq(step_count, 8, "Should have 8 tutorial steps")


func test_tutorial_starts_with_no_completed_steps() -> void:
	assert_false(_manager.are_all_steps_complete(), "No steps should be complete initially")
	assert_eq(_manager.get_next_incomplete_step(), _manager.TutorialStep.WELCOME, "First incomplete step should be WELCOME")


# =============================================================================
# Step Completion Tests
# =============================================================================

func test_complete_step_marks_step_done() -> void:
	assert_false(_manager.is_step_complete(_manager.TutorialStep.WELCOME), "WELCOME should not be complete initially")

	_manager.complete_step(_manager.TutorialStep.WELCOME)

	assert_true(_manager.is_step_complete(_manager.TutorialStep.WELCOME), "WELCOME should be complete after completion")


func test_complete_step_emits_signal() -> void:
	watch_signals(_manager)

	_manager.complete_step(_manager.TutorialStep.WELCOME)
	await wait_frames(1)

	assert_signal_emitted(_manager, "step_completed", "step_completed signal should be emitted")


func test_complete_step_advances_to_next() -> void:
	_manager.complete_step(_manager.TutorialStep.WELCOME)

	assert_eq(_manager.get_next_incomplete_step(), _manager.TutorialStep.CAMERA_PAN, "Next step should be CAMERA_PAN")


func test_completing_all_steps_triggers_all_complete_signal() -> void:
	watch_signals(_manager)

	# Complete all steps
	for step in _manager.TutorialStep.values():
		_manager.complete_step(step)

	await wait_frames(1)

	assert_true(_manager.are_all_steps_complete(), "All steps should be complete")
	assert_signal_emitted(_manager, "all_tutorials_complete", "all_tutorials_complete signal should be emitted")


func test_cannot_complete_same_step_twice() -> void:
	_manager.complete_step(_manager.TutorialStep.WELCOME)
	var count_before: int = _manager._completed_steps.size()

	_manager.complete_step(_manager.TutorialStep.WELCOME)
	var count_after: int = _manager._completed_steps.size()

	assert_eq(count_before, count_after, "Completing same step twice should not duplicate")


# =============================================================================
# Tutorial Enable/Disable Tests
# =============================================================================

func test_disable_tutorial_mode() -> void:
	watch_signals(_manager)

	_manager.set_tutorial_enabled(false)
	await wait_frames(1)

	assert_false(_manager.is_tutorial_enabled(), "Tutorial should be disabled")
	assert_signal_emitted(_manager, "tutorial_mode_changed", "tutorial_mode_changed signal should be emitted")


func test_enable_tutorial_mode() -> void:
	_manager.set_tutorial_enabled(false)
	await wait_frames(1)

	watch_signals(_manager)
	_manager.set_tutorial_enabled(true)
	await wait_frames(1)

	assert_true(_manager.is_tutorial_enabled(), "Tutorial should be enabled")
	assert_signal_emitted(_manager, "tutorial_mode_changed", "tutorial_mode_changed signal should be emitted")


# =============================================================================
# AC13: Skip Tutorial Option
# =============================================================================

func test_skip_all_completes_all_steps() -> void:
	_manager.skip_all()

	assert_true(_manager.are_all_steps_complete(), "All steps should be complete after skip")
	assert_false(_manager.is_tutorial_enabled(), "Tutorial should be disabled after skip")


func test_skip_all_emits_signals() -> void:
	watch_signals(_manager)

	_manager.skip_all()
	await wait_frames(1)

	assert_signal_emitted(_manager, "tutorial_mode_changed", "tutorial_mode_changed should be emitted on skip")
	assert_signal_emitted(_manager, "all_tutorials_complete", "all_tutorials_complete should be emitted on skip")


# =============================================================================
# AC14: Reset Tutorial
# =============================================================================

func test_reset_all_clears_progress() -> void:
	# Complete some steps first
	_manager.complete_step(_manager.TutorialStep.WELCOME)
	_manager.complete_step(_manager.TutorialStep.CAMERA_PAN)

	_manager.reset_all()

	assert_false(_manager.is_step_complete(_manager.TutorialStep.WELCOME), "WELCOME should not be complete after reset")
	assert_false(_manager.is_step_complete(_manager.TutorialStep.CAMERA_PAN), "CAMERA_PAN should not be complete after reset")
	assert_true(_manager.is_tutorial_enabled(), "Tutorial should be enabled after reset")


func test_reset_after_skip_restores_tutorial() -> void:
	_manager.skip_all()

	_manager.reset_all()

	assert_false(_manager.are_all_steps_complete(), "No steps should be complete after reset")
	assert_true(_manager.is_tutorial_enabled(), "Tutorial should be enabled after reset")


func test_reset_all_emits_signal() -> void:
	_manager.complete_step(_manager.TutorialStep.WELCOME)

	watch_signals(_manager)
	_manager.reset_all()
	await wait_frames(1)

	assert_signal_emitted(_manager, "tutorial_mode_changed", "tutorial_mode_changed should be emitted on reset")


# =============================================================================
# AC12: Save/Load Persistence
# =============================================================================

func test_save_data_format() -> void:
	# Complete some steps
	_manager.complete_step(_manager.TutorialStep.WELCOME)
	_manager.complete_step(_manager.TutorialStep.CAMERA_PAN)

	var save_data: Dictionary = _manager.get_save_data()

	assert_true(save_data.has("tutorial_enabled"), "Save data should have tutorial_enabled")
	assert_true(save_data.has("completed_steps"), "Save data should have completed_steps")
	assert_eq(save_data["tutorial_enabled"], true, "tutorial_enabled should be true")
	assert_eq(save_data["completed_steps"].size(), 2, "Should have 2 completed steps")


func test_save_data_after_skip() -> void:
	_manager.skip_all()

	var save_data: Dictionary = _manager.get_save_data()

	assert_eq(save_data["tutorial_enabled"], false, "tutorial_enabled should be false after skip")
	assert_eq(save_data["completed_steps"].size(), 8, "All 8 steps should be in completed_steps")


func test_load_save_data_restores_state() -> void:
	var save_data := {
		"tutorial_enabled": false,
		"completed_steps": [0, 1, 2],  # WELCOME, CAMERA_PAN, SELECT_ANIMAL
	}

	_manager.load_save_data(save_data)

	assert_false(_manager.is_tutorial_enabled(), "Tutorial should be disabled")
	assert_true(_manager.is_step_complete(_manager.TutorialStep.WELCOME), "WELCOME should be complete")
	assert_true(_manager.is_step_complete(_manager.TutorialStep.CAMERA_PAN), "CAMERA_PAN should be complete")
	assert_true(_manager.is_step_complete(_manager.TutorialStep.SELECT_ANIMAL), "SELECT_ANIMAL should be complete")
	assert_false(_manager.is_step_complete(_manager.TutorialStep.ASSIGN_ANIMAL), "ASSIGN_ANIMAL should not be complete")


func test_load_handles_missing_keys() -> void:
	var incomplete_data := {}  # Missing all keys

	_manager.load_save_data(incomplete_data)

	assert_true(_manager.is_tutorial_enabled(), "Should default to enabled")
	assert_eq(_manager._completed_steps.size(), 0, "Should have no completed steps")


func test_load_handles_invalid_step_values() -> void:
	var invalid_data := {
		"tutorial_enabled": true,
		"completed_steps": [-1, 99, "invalid", 0, 1],  # Mix of invalid and valid
	}

	_manager.load_save_data(invalid_data)

	# Should only load valid steps (0, 1)
	assert_true(_manager.is_step_complete(_manager.TutorialStep.WELCOME), "WELCOME (0) should be loaded")
	assert_true(_manager.is_step_complete(_manager.TutorialStep.CAMERA_PAN), "CAMERA_PAN (1) should be loaded")
	assert_eq(_manager._completed_steps.size(), 2, "Should only have 2 valid completed steps")


func test_save_and_load_round_trip() -> void:
	# Setup state
	_manager.complete_step(_manager.TutorialStep.WELCOME)
	_manager.complete_step(_manager.TutorialStep.CAMERA_PAN)
	_manager.complete_step(_manager.TutorialStep.SELECT_ANIMAL)

	# Save
	var save_data: Dictionary = _manager.get_save_data()

	# Reset
	_manager.reset_all()

	# Load
	_manager.load_save_data(save_data)

	# Verify state restored
	assert_true(_manager.is_step_complete(_manager.TutorialStep.WELCOME), "WELCOME should be restored")
	assert_true(_manager.is_step_complete(_manager.TutorialStep.CAMERA_PAN), "CAMERA_PAN should be restored")
	assert_true(_manager.is_step_complete(_manager.TutorialStep.SELECT_ANIMAL), "SELECT_ANIMAL should be restored")
	assert_false(_manager.is_step_complete(_manager.TutorialStep.ASSIGN_ANIMAL), "ASSIGN_ANIMAL should not be restored")


# =============================================================================
# Step Message and Position Hint Tests
# =============================================================================

func test_get_step_message_returns_correct_text() -> void:
	var welcome_msg: String = _manager.get_step_message(_manager.TutorialStep.WELCOME)
	assert_true("Welcome" in welcome_msg, "Welcome message should contain 'Welcome'")

	var pan_msg: String = _manager.get_step_message(_manager.TutorialStep.CAMERA_PAN)
	assert_true("Drag" in pan_msg, "Camera pan message should contain 'Drag'")


func test_get_step_position_hint_returns_hint() -> void:
	var welcome_hint: String = _manager.get_step_position_hint(_manager.TutorialStep.WELCOME)
	assert_eq(welcome_hint, "center", "Welcome position hint should be 'center'")

	var menu_hint: String = _manager.get_step_position_hint(_manager.TutorialStep.OPEN_MENU)
	assert_eq(menu_hint, "build_button", "Open menu position hint should be 'build_button'")


# =============================================================================
# Dismiss Current Step Tests
# =============================================================================

func test_dismiss_welcome_step_completes_it() -> void:
	# Set current step to WELCOME
	_manager._current_step = _manager.TutorialStep.WELCOME

	_manager.dismiss_current_step()

	assert_true(_manager.is_step_complete(_manager.TutorialStep.WELCOME), "WELCOME should be complete after dismiss")


func test_dismiss_combat_intro_completes_it() -> void:
	# Set current step to COMBAT_INTRO
	_manager._current_step = _manager.TutorialStep.COMBAT_INTRO

	_manager.dismiss_current_step()

	assert_true(_manager.is_step_complete(_manager.TutorialStep.COMBAT_INTRO), "COMBAT_INTRO should be complete after dismiss")


func test_dismiss_other_steps_does_nothing() -> void:
	# Set current step to CAMERA_PAN (requires action, not dismissable)
	_manager._current_step = _manager.TutorialStep.CAMERA_PAN

	_manager.dismiss_current_step()

	assert_false(_manager.is_step_complete(_manager.TutorialStep.CAMERA_PAN), "CAMERA_PAN should not be complete from dismiss")


# =============================================================================
# Current Step State Tests
# =============================================================================

func test_get_current_step_returns_negative_when_inactive() -> void:
	assert_eq(_manager.get_current_step(), -1, "Current step should be -1 when inactive")


func test_get_next_incomplete_after_all_complete_returns_negative() -> void:
	_manager.skip_all()

	assert_eq(_manager.get_next_incomplete_step(), -1, "Next incomplete should be -1 when all complete")
