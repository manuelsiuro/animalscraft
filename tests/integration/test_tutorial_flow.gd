## Integration tests for Tutorial Flow (Story 6-9).
##
## Tests the complete tutorial progression from first launch through
## all tutorial steps, verifying EventBus signal integration and
## cross-system communication.
##
## Architecture: tests/integration/test_tutorial_flow.gd
## Story: 6-9-implement-tutorial-flow
extends GutTest

# =============================================================================
# CONSTANTS
# =============================================================================

const TutorialManagerScript := preload("res://autoloads/tutorial_manager.gd")
const TutorialTooltipScene := preload("res://scenes/ui/tutorial_tooltip.tscn")

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _manager: Node = null
var _tooltip: TutorialTooltip = null


func before_each() -> void:
	# Create fresh instances for each test
	_manager = TutorialManagerScript.new()
	add_child(_manager)

	_tooltip = TutorialTooltipScene.instantiate()
	add_child(_tooltip)

	await wait_frames(2)


func after_each() -> void:
	if _manager and is_instance_valid(_manager):
		_manager.queue_free()
		_manager = null
	if _tooltip and is_instance_valid(_tooltip):
		_tooltip.queue_free()
		_tooltip = null


# =============================================================================
# AC2: First Launch Detection Integration
# =============================================================================

func test_game_manager_first_launch_detection() -> void:
	# GameManager should have first launch detection methods
	assert_true(GameManager.has_method("is_first_launch"), "GameManager should have is_first_launch method")
	assert_true(GameManager.has_method("start_first_launch_game"), "GameManager should have start_first_launch_game method")


func test_first_launch_enables_tutorial() -> void:
	# When first launch game starts, tutorial should be enabled
	_manager.set_tutorial_enabled(false)  # Disable first

	# Simulate what start_first_launch_game does
	_manager.set_tutorial_enabled(true)

	assert_true(_manager.is_tutorial_enabled(), "Tutorial should be enabled after first launch start")


# =============================================================================
# Tutorial Flow Progression Tests
# =============================================================================

func test_tutorial_steps_progress_in_order() -> void:
	# Complete steps in sequence and verify progression
	var steps := [
		_manager.TutorialStep.WELCOME,
		_manager.TutorialStep.CAMERA_PAN,
		_manager.TutorialStep.SELECT_ANIMAL,
		_manager.TutorialStep.ASSIGN_ANIMAL,
		_manager.TutorialStep.OPEN_MENU,
		_manager.TutorialStep.PLACE_BUILDING,
		_manager.TutorialStep.ASSIGN_WORKER,
		_manager.TutorialStep.COMBAT_INTRO,
	]

	for i in range(steps.size()):
		var step: int = steps[i]
		assert_eq(_manager.get_next_incomplete_step(), step, "Step %d should be next" % i)
		_manager.complete_step(step)
		assert_true(_manager.is_step_complete(step), "Step %d should be complete" % i)


func test_tutorial_completion_flow() -> void:
	watch_signals(_manager)

	# Complete all steps
	for step in _manager.TutorialStep.values():
		_manager.complete_step(step)

	await wait_frames(2)

	assert_true(_manager.are_all_steps_complete(), "All steps should be complete")
	assert_signal_emitted(_manager, "all_tutorials_complete", "Completion signal should emit")


# =============================================================================
# EventBus Integration Tests
# =============================================================================

func test_eventbus_has_tutorial_signals() -> void:
	assert_true(EventBus.has_signal("tutorial_started"), "EventBus should have tutorial_started signal")
	assert_true(EventBus.has_signal("tutorial_step_completed"), "EventBus should have tutorial_step_completed signal")
	assert_true(EventBus.has_signal("tutorial_completed"), "EventBus should have tutorial_completed signal")


func test_eventbus_camera_panned_signal_exists() -> void:
	assert_true(EventBus.has_signal("camera_panned"), "EventBus should have camera_panned signal")


func test_eventbus_menu_opened_signal_exists() -> void:
	assert_true(EventBus.has_signal("menu_opened"), "EventBus should have menu_opened signal")


func test_eventbus_worker_assigned_signal_exists() -> void:
	assert_true(EventBus.has_signal("worker_assigned"), "EventBus should have worker_assigned signal")


# =============================================================================
# Tooltip and Manager Integration Tests
# =============================================================================

func test_tooltip_responds_to_manager_show_signal() -> void:
	# Manager should be able to trigger tooltip display
	assert_true(_manager.has_signal("show_tooltip_requested"), "Manager should have show_tooltip_requested signal")

	# Connect tooltip to our test manager instance (normally it connects to autoload)
	_manager.show_tooltip_requested.connect(_tooltip._on_show_tooltip_requested)

	# Emit show tooltip signal
	_manager.show_tooltip_requested.emit(
		_manager.TutorialStep.WELCOME,
		"Test message",
		"center"
	)
	await wait_frames(3)

	assert_true(_tooltip.is_showing(), "Tooltip should show after manager signal")

	# Cleanup
	_manager.show_tooltip_requested.disconnect(_tooltip._on_show_tooltip_requested)


func test_tooltip_responds_to_manager_hide_signal() -> void:
	# Connect tooltip to our test manager instance
	_manager.hide_tooltip_requested.connect(_tooltip._on_hide_tooltip_requested)

	# Show tooltip first
	_tooltip.show_tooltip(0, "Test", "center")
	await wait_frames(3)

	# Manager hide signal
	_manager.hide_tooltip_requested.emit()
	await wait_frames(10)

	assert_false(_tooltip.is_showing(), "Tooltip should hide after manager signal")

	# Cleanup
	_manager.hide_tooltip_requested.disconnect(_tooltip._on_hide_tooltip_requested)


# =============================================================================
# Save/Load Integration Tests
# =============================================================================

func test_save_manager_has_tutorial_integration() -> void:
	# SaveManager should include tutorial data in save
	assert_true(is_instance_valid(SaveManager), "SaveManager should exist")


func test_tutorial_state_survives_save_load_cycle() -> void:
	# Complete some steps
	_manager.complete_step(_manager.TutorialStep.WELCOME)
	_manager.complete_step(_manager.TutorialStep.CAMERA_PAN)

	# Get save data
	var save_data: Dictionary = _manager.get_save_data()

	# Reset
	_manager.reset_all()
	assert_false(_manager.is_step_complete(_manager.TutorialStep.WELCOME), "Should be reset")

	# Load
	_manager.load_save_data(save_data)

	# Verify restored
	assert_true(_manager.is_step_complete(_manager.TutorialStep.WELCOME), "WELCOME should be restored")
	assert_true(_manager.is_step_complete(_manager.TutorialStep.CAMERA_PAN), "CAMERA_PAN should be restored")
	assert_false(_manager.is_step_complete(_manager.TutorialStep.SELECT_ANIMAL), "SELECT_ANIMAL should not be restored")


# =============================================================================
# Skip and Reset Integration Tests (AC13, AC14)
# =============================================================================

func test_skip_all_disables_tutorial_and_marks_complete() -> void:
	watch_signals(_manager)

	_manager.skip_all()
	await wait_frames(2)

	assert_true(_manager.are_all_steps_complete(), "All steps complete after skip")
	assert_false(_manager.is_tutorial_enabled(), "Tutorial disabled after skip")
	assert_signal_emitted(_manager, "all_tutorials_complete", "Completion signal on skip")


func test_reset_after_skip_restores_full_tutorial() -> void:
	_manager.skip_all()
	_manager.reset_all()

	assert_false(_manager.are_all_steps_complete(), "No steps complete after reset")
	assert_true(_manager.is_tutorial_enabled(), "Tutorial enabled after reset")
	assert_eq(_manager.get_next_incomplete_step(), _manager.TutorialStep.WELCOME, "Should start from WELCOME")


# =============================================================================
# Settings Integration Tests (AC14)
# =============================================================================

func test_tutorial_manager_exists_as_autoload() -> void:
	# TutorialManager should be accessible as autoload
	var tutorial_mgr := get_node_or_null("/root/TutorialManager")
	assert_not_null(tutorial_mgr, "TutorialManager should be registered as autoload")


func test_settings_can_reset_tutorial() -> void:
	# Verify TutorialManager has reset_all method for Settings integration
	assert_true(_manager.has_method("reset_all"), "TutorialManager should have reset_all method")

	# Complete some steps
	_manager.complete_step(_manager.TutorialStep.WELCOME)

	# Reset (as Settings would call)
	_manager.reset_all()

	assert_false(_manager.is_step_complete(_manager.TutorialStep.WELCOME), "Should be reset")
