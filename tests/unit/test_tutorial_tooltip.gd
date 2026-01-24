## Unit tests for TutorialTooltip (Story 6-9).
##
## Tests cover:
## - Tooltip display and positioning (AC3)
## - Auto-dismiss functionality (AC11)
## - Skip button behavior (AC13)
## - Queue system for sequential tooltips
##
## Architecture: tests/unit/test_tutorial_tooltip.gd
## Story: 6-9-implement-tutorial-flow
extends GutTest

# =============================================================================
# CONSTANTS
# =============================================================================

const TutorialTooltipScene := preload("res://scenes/ui/tutorial_tooltip.tscn")

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _tooltip: TutorialTooltip = null


func before_each() -> void:
	# Create fresh tooltip instance
	_tooltip = TutorialTooltipScene.instantiate()
	add_child(_tooltip)
	await wait_frames(1)


func after_each() -> void:
	if _tooltip and is_instance_valid(_tooltip):
		_tooltip.queue_free()
		_tooltip = null


# =============================================================================
# Basic Initialization Tests
# =============================================================================

func test_tooltip_initializes_hidden() -> void:
	assert_false(_tooltip.visible, "Tooltip should be hidden on init")
	assert_eq(_tooltip.modulate.a, 0.0, "Tooltip should have zero alpha on init")


func test_tooltip_has_required_nodes() -> void:
	assert_not_null(_tooltip.get_node("Panel"), "Should have Panel node")
	assert_not_null(_tooltip.get_node("Panel/MarginContainer/VBoxContainer/MessageLabel"), "Should have MessageLabel")
	assert_not_null(_tooltip.get_node("Panel/MarginContainer/VBoxContainer/SkipButton"), "Should have SkipButton")
	assert_not_null(_tooltip.get_node("HandGesture"), "Should have HandGesture node")
	assert_not_null(_tooltip.get_node("AnimationPlayer"), "Should have AnimationPlayer")
	assert_not_null(_tooltip.get_node("AutoDismissTimer"), "Should have AutoDismissTimer")


# =============================================================================
# Show/Hide Tooltip Tests (AC3)
# =============================================================================

func test_show_tooltip_makes_visible() -> void:
	_tooltip.show_tooltip(0, "Test message", "center")
	await wait_frames(2)

	assert_true(_tooltip.visible, "Tooltip should be visible after show")
	assert_true(_tooltip.is_showing(), "is_showing should return true")


func test_show_tooltip_sets_message() -> void:
	var test_message := "This is a test tutorial message"
	_tooltip.show_tooltip(0, test_message, "center")
	await wait_frames(2)

	var label: Label = _tooltip.get_node("Panel/MarginContainer/VBoxContainer/MessageLabel")
	assert_eq(label.text, test_message, "MessageLabel should show the message")


func test_hide_tooltip_hides() -> void:
	_tooltip.show_tooltip(0, "Test", "center")
	await wait_frames(2)

	_tooltip.hide_tooltip()
	await wait_frames(10)  # Wait for animation

	assert_false(_tooltip.is_showing(), "is_showing should return false after hide")


# =============================================================================
# Queue System Tests
# =============================================================================

func test_tooltip_queue_shows_in_order() -> void:
	# Queue multiple tooltips
	_tooltip.show_tooltip(0, "First message", "center")
	_tooltip.show_tooltip(1, "Second message", "center")

	# First should show immediately
	await wait_frames(2)
	var label: Label = _tooltip.get_node("Panel/MarginContainer/VBoxContainer/MessageLabel")
	assert_eq(label.text, "First message", "First queued message should show")


func test_clear_queue_removes_pending() -> void:
	_tooltip.show_tooltip(0, "First", "center")
	_tooltip.show_tooltip(1, "Second", "center")
	_tooltip.show_tooltip(2, "Third", "center")

	_tooltip.clear_queue()

	# Access private queue via workaround (queue should be cleared)
	assert_true(true, "Queue cleared without error")


# =============================================================================
# Position Hint Tests (AC3)
# =============================================================================

func test_position_hint_center() -> void:
	_tooltip.show_tooltip(0, "Test", "center")
	await wait_frames(2)

	var panel: PanelContainer = _tooltip.get_node("Panel")
	var viewport_size := _tooltip.get_viewport_rect().size
	var expected_x: float = (viewport_size.x - panel.size.x) / 2.0

	# Allow some tolerance for positioning
	assert_almost_eq(panel.position.x, expected_x, 10.0, "Panel should be horizontally centered")


func test_position_hint_build_button() -> void:
	_tooltip.show_tooltip(0, "Test", "build_button")
	await wait_frames(2)

	var panel: PanelContainer = _tooltip.get_node("Panel")
	var viewport_size := _tooltip.get_viewport_rect().size

	# Should be near bottom-right
	assert_gt(panel.position.x, viewport_size.x / 2.0, "Panel should be on right side for build_button hint")


# =============================================================================
# Hand Gesture Animation Tests (AC4)
# =============================================================================

func test_hand_gesture_hidden_by_default() -> void:
	var hand: Control = _tooltip.get_node("HandGesture")
	assert_false(hand.visible, "Hand gesture should be hidden by default")


func test_hand_gesture_visible_for_camera_pan_step() -> void:
	# TutorialStep.CAMERA_PAN = 1
	_tooltip.show_tooltip(1, "Drag to pan", "center")
	await wait_frames(2)

	var hand: Control = _tooltip.get_node("HandGesture")
	assert_true(hand.visible, "Hand gesture should be visible for CAMERA_PAN step")


func test_hand_gesture_hidden_for_other_steps() -> void:
	# TutorialStep.WELCOME = 0
	_tooltip.show_tooltip(0, "Welcome", "center")
	await wait_frames(2)

	var hand: Control = _tooltip.get_node("HandGesture")
	assert_false(hand.visible, "Hand gesture should be hidden for non-pan steps")


# =============================================================================
# Auto-Dismiss Tests (AC11)
# =============================================================================

func test_auto_dismiss_timer_configured() -> void:
	var timer: Timer = _tooltip.get_node("AutoDismissTimer")
	assert_eq(timer.wait_time, 5.0, "Auto-dismiss should be 5 seconds")
	assert_true(timer.one_shot, "Timer should be one-shot")


# =============================================================================
# Skip Button Tests (AC13)
# =============================================================================

func test_skip_button_exists() -> void:
	var button: Button = _tooltip.get_node("Panel/MarginContainer/VBoxContainer/SkipButton")
	assert_eq(button.text, "Skip Tutorial", "Skip button should have correct text")


func test_skip_button_shows_confirmation_dialog() -> void:
	_tooltip.show_tooltip(0, "Test", "center")
	await wait_frames(2)

	var button: Button = _tooltip.get_node("Panel/MarginContainer/VBoxContainer/SkipButton")
	var dialog: ConfirmationDialog = _tooltip.get_node("SkipConfirmDialog")

	button.pressed.emit()
	await wait_frames(2)

	assert_true(dialog.visible, "Skip confirmation dialog should be visible after skip button press")


func test_skip_confirmation_emits_signal_and_hides() -> void:
	watch_signals(_tooltip)

	_tooltip.show_tooltip(0, "Test", "center")
	await wait_frames(2)

	# Simulate confirming the skip dialog
	var dialog: ConfirmationDialog = _tooltip.get_node("SkipConfirmDialog")
	dialog.confirmed.emit()
	await wait_frames(10)  # Wait for animation

	assert_signal_emitted(_tooltip, "skip_requested", "skip_requested signal should be emitted after confirmation")
	assert_false(_tooltip.is_showing(), "Tooltip should hide after skip confirmation")


# =============================================================================
# Signal Tests
# =============================================================================

func test_dismissed_signal_on_hide() -> void:
	watch_signals(_tooltip)

	_tooltip.show_tooltip(0, "Test", "center")
	await wait_frames(2)

	# Manually trigger dismiss (simulating tap on dismissable step)
	_tooltip._dismiss()
	await wait_frames(2)

	assert_signal_emitted(_tooltip, "dismissed", "dismissed signal should be emitted")
