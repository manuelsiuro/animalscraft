## Tutorial tooltip UI component for displaying tutorial hints.
## Non-blocking tooltips with auto-dismiss, skip button, and queue system.
##
## Architecture: scripts/ui/tutorial_tooltip.gd
## Story: 6-9-implement-tutorial-flow
##
## Features:
## - Non-blocking (click-through except skip button)
## - Auto-dismiss after 5 seconds
## - Tooltip queue for sequential display
## - Animated show/hide transitions
## - Hand gesture animation for camera pan tutorial
class_name TutorialTooltip
extends Control

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the tooltip is dismissed (tap or auto-dismiss)
signal dismissed()

## Emitted when skip button is pressed
signal skip_requested()

# =============================================================================
# CONSTANTS
# =============================================================================

## Auto-dismiss time in seconds (AC11)
const AUTO_DISMISS_TIME: float = 5.0

## Animation duration for show/hide
const ANIM_DURATION: float = 0.3

## Position offset from screen edge
const EDGE_MARGIN: float = 20.0

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _panel: PanelContainer = $Panel
@onready var _message_label: Label = $Panel/MarginContainer/VBoxContainer/MessageLabel
@onready var _skip_button: Button = $Panel/MarginContainer/VBoxContainer/SkipButton
@onready var _hand_gesture: Control = $HandGesture
@onready var _anim_player: AnimationPlayer = $AnimationPlayer
@onready var _auto_dismiss_timer: Timer = $AutoDismissTimer
@onready var _skip_confirm_dialog: ConfirmationDialog = $SkipConfirmDialog

# =============================================================================
# STATE
# =============================================================================

## Current tutorial step being displayed
var _current_step: int = -1

## Queue of pending tooltips to display
var _tooltip_queue: Array[Dictionary] = []

## Whether we're currently showing a tooltip
var _is_showing: bool = false

## Whether hand gesture should be visible
var _show_hand_gesture: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Initially hidden
	visible = false
	modulate.a = 0.0

	# Setup timer
	if _auto_dismiss_timer:
		_auto_dismiss_timer.wait_time = AUTO_DISMISS_TIME
		_auto_dismiss_timer.one_shot = true
		_auto_dismiss_timer.timeout.connect(_on_auto_dismiss_timeout)

	# Connect skip button
	if _skip_button:
		_skip_button.pressed.connect(_on_skip_pressed)

	# Connect skip confirmation dialog (AC13)
	if _skip_confirm_dialog:
		_skip_confirm_dialog.confirmed.connect(_on_skip_confirmed)

	# Hide hand gesture initially
	if _hand_gesture:
		_hand_gesture.visible = false

	# Connect to TutorialManager signals
	_connect_tutorial_manager()

	GameLogger.info("TutorialTooltip", "Tutorial tooltip initialized")


func _exit_tree() -> void:
	_disconnect_tutorial_manager()


# =============================================================================
# TUTORIAL MANAGER CONNECTION
# =============================================================================

func _connect_tutorial_manager() -> void:
	if not is_instance_valid(TutorialManager):
		return

	TutorialManager.show_tooltip_requested.connect(_on_show_tooltip_requested)
	TutorialManager.hide_tooltip_requested.connect(_on_hide_tooltip_requested)


func _disconnect_tutorial_manager() -> void:
	if not is_instance_valid(TutorialManager):
		return

	if TutorialManager.show_tooltip_requested.is_connected(_on_show_tooltip_requested):
		TutorialManager.show_tooltip_requested.disconnect(_on_show_tooltip_requested)
	if TutorialManager.hide_tooltip_requested.is_connected(_on_hide_tooltip_requested):
		TutorialManager.hide_tooltip_requested.disconnect(_on_hide_tooltip_requested)


# =============================================================================
# INPUT HANDLING (AC11 - Non-blocking)
# =============================================================================

func _input(event: InputEvent) -> void:
	if not _is_showing:
		return

	# Only handle tap/click events
	if event is InputEventMouseButton and event.pressed:
		# Check if tap is on skip button - let it handle
		if _skip_button and _skip_button.get_global_rect().has_point(event.position):
			return  # Skip button handles this

		# Tap anywhere else dismisses tooltip (for dismissable steps)
		if _current_step == TutorialManager.TutorialStep.WELCOME or \
		   _current_step == TutorialManager.TutorialStep.COMBAT_INTRO:
			_dismiss()
			# Don't consume the event - let it pass through (non-blocking)


# =============================================================================
# PUBLIC API
# =============================================================================

## Show a tooltip with the given message and position hint
func show_tooltip(step: int, message: String, position_hint: String) -> void:
	# Add to queue
	_tooltip_queue.append({
		"step": step,
		"message": message,
		"position_hint": position_hint,
	})

	# If not currently showing, display next in queue
	if not _is_showing:
		_show_next_in_queue()


## Hide the current tooltip
func hide_tooltip() -> void:
	if _is_showing:
		_hide_animated()


## Check if tooltip is currently visible
func is_showing() -> bool:
	return _is_showing


## Clear the tooltip queue
func clear_queue() -> void:
	_tooltip_queue.clear()


# =============================================================================
# PRIVATE - QUEUE MANAGEMENT
# =============================================================================

func _show_next_in_queue() -> void:
	if _tooltip_queue.is_empty():
		return

	var tooltip_data: Dictionary = _tooltip_queue.pop_front()
	_display_tooltip(tooltip_data)


func _display_tooltip(data: Dictionary) -> void:
	_current_step = data.get("step", -1)
	var message: String = data.get("message", "")
	var position_hint: String = data.get("position_hint", "center")

	# Set message
	if _message_label:
		_message_label.text = message

	# Position tooltip based on hint
	_position_tooltip(position_hint)

	# Show/hide hand gesture for camera pan
	_show_hand_gesture = (_current_step == TutorialManager.TutorialStep.CAMERA_PAN)
	if _hand_gesture:
		_hand_gesture.visible = _show_hand_gesture
		if _show_hand_gesture and _anim_player and _anim_player.has_animation("hand_drag"):
			_anim_player.play("hand_drag")

	# Animate in
	_show_animated()

	# Start auto-dismiss timer
	if _auto_dismiss_timer:
		_auto_dismiss_timer.start()


func _position_tooltip(hint: String) -> void:
	if not _panel:
		return

	var viewport_size := get_viewport_rect().size
	var panel_size := _panel.size

	match hint:
		"center":
			_panel.position = (viewport_size - panel_size) / 2.0
		"build_button":
			# Position near bottom-right where build button typically is
			_panel.position = Vector2(
				viewport_size.x - panel_size.x - EDGE_MARGIN,
				viewport_size.y - panel_size.y - 150.0  # Above button area
			)
		"menu":
			# Position near center-left where menu appears
			_panel.position = Vector2(
				EDGE_MARGIN,
				(viewport_size.y - panel_size.y) / 2.0
			)
		"animal":
			# Position in upper area where animals typically are
			_panel.position = Vector2(
				(viewport_size.x - panel_size.x) / 2.0,
				viewport_size.y * 0.3
			)
		"contested":
			# Position near edges where contested territory typically is
			_panel.position = Vector2(
				(viewport_size.x - panel_size.x) / 2.0,
				viewport_size.y * 0.2
			)
		_:
			# Default to center
			_panel.position = (viewport_size - panel_size) / 2.0


# =============================================================================
# PRIVATE - ANIMATIONS
# =============================================================================

func _show_animated() -> void:
	visible = true
	_is_showing = true

	# Tween fade in
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, ANIM_DURATION)


func _hide_animated() -> void:
	# Mark as not showing immediately (before animation completes)
	_is_showing = false

	# Stop auto-dismiss timer
	if _auto_dismiss_timer:
		_auto_dismiss_timer.stop()

	# Tween fade out
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, ANIM_DURATION)
	tween.tween_callback(_on_hide_complete)


func _on_hide_complete() -> void:
	visible = false
	_current_step = -1

	# Hide hand gesture
	if _hand_gesture:
		_hand_gesture.visible = false
	if _anim_player and _anim_player.is_playing():
		_anim_player.stop()

	# Show next in queue if any
	if not _tooltip_queue.is_empty():
		# Small delay between tooltips
		await get_tree().create_timer(0.3).timeout
		_show_next_in_queue()


func _dismiss() -> void:
	_hide_animated()
	dismissed.emit()

	# Notify TutorialManager to complete the step if dismissable
	if is_instance_valid(TutorialManager):
		TutorialManager.dismiss_current_step()


# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_auto_dismiss_timeout() -> void:
	if _is_showing:
		_dismiss()


func _on_skip_pressed() -> void:
	GameLogger.debug("TutorialTooltip", "Skip button pressed - showing confirmation")
	# Show confirmation dialog (AC13)
	if _skip_confirm_dialog:
		_skip_confirm_dialog.popup_centered()


func _on_skip_confirmed() -> void:
	GameLogger.info("TutorialTooltip", "Skip tutorial confirmed")
	skip_requested.emit()

	# Hide immediately
	_hide_animated()

	# Clear queue
	clear_queue()

	# Notify TutorialManager to skip all
	if is_instance_valid(TutorialManager):
		TutorialManager.skip_all()


func _on_show_tooltip_requested(step: int, message: String, position_hint: String) -> void:
	show_tooltip(step, message, position_hint)


func _on_hide_tooltip_requested() -> void:
	hide_tooltip()
