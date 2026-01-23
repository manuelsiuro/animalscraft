## Loading overlay that appears during load operations.
## Blocks input and shows visual feedback during loading.
##
## Architecture: scripts/ui/menus/loading_overlay.gd
## Story: 6-3-implement-load-game-ui
extends CanvasLayer

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _background: ColorRect = $Background
@onready var _loading_label: Label = $CenterContainer/VBoxContainer/LoadingLabel
@onready var _spinner: Control = $CenterContainer/VBoxContainer/Spinner

# =============================================================================
# STATE
# =============================================================================

## Animation tween for spinner rotation
var _spin_tween: Tween

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Start hidden
	visible = false

	# Connect to EventBus for load events (AC4, AC6)
	EventBus.load_started.connect(_on_load_started)
	EventBus.load_completed.connect(_on_load_completed)

	# Also listen for save events (optional visual feedback)
	EventBus.save_started.connect(_on_save_started)
	EventBus.save_completed.connect(_on_save_completed)

	GameLogger.debug("LoadingOverlay", "Loading overlay initialized")


func _exit_tree() -> void:
	# Kill any running tween
	if _spin_tween and _spin_tween.is_running():
		_spin_tween.kill()

	# Disconnect EventBus signals
	if EventBus.load_started.is_connected(_on_load_started):
		EventBus.load_started.disconnect(_on_load_started)
	if EventBus.load_completed.is_connected(_on_load_completed):
		EventBus.load_completed.disconnect(_on_load_completed)
	if EventBus.save_started.is_connected(_on_save_started):
		EventBus.save_started.disconnect(_on_save_started)
	if EventBus.save_completed.is_connected(_on_save_completed):
		EventBus.save_completed.disconnect(_on_save_completed)

# =============================================================================
# INPUT HANDLING (AC4 - Block input during load)
# =============================================================================

func _input(event: InputEvent) -> void:
	if visible:
		# Consume all input when loading overlay is visible
		get_viewport().set_input_as_handled()

# =============================================================================
# SHOW/HIDE
# =============================================================================

## Show the loading overlay with optional custom message
func show_loading(message: String = "Loading...") -> void:
	if _loading_label:
		_loading_label.text = message

	visible = true
	_start_spinner_animation()
	GameLogger.debug("LoadingOverlay", "Showing overlay: %s" % message)


## Hide the loading overlay
func hide_loading() -> void:
	visible = false
	_stop_spinner_animation()
	GameLogger.debug("LoadingOverlay", "Hiding overlay")

# =============================================================================
# SPINNER ANIMATION
# =============================================================================

## Start the spinner rotation animation
func _start_spinner_animation() -> void:
	if not _spinner:
		return

	# Kill existing tween
	if _spin_tween and _spin_tween.is_running():
		_spin_tween.kill()

	# Create continuous rotation tween
	_spin_tween = create_tween()
	_spin_tween.set_loops()  # Infinite loop
	_spin_tween.tween_property(_spinner, "rotation_degrees", 360.0, 1.0).from(0.0)


## Stop the spinner rotation animation
func _stop_spinner_animation() -> void:
	if _spin_tween and _spin_tween.is_running():
		_spin_tween.kill()

	if _spinner:
		_spinner.rotation_degrees = 0.0

# =============================================================================
# EVENT HANDLERS
# =============================================================================

## Handle load started event (AC4)
func _on_load_started() -> void:
	show_loading("Loading...")


## Handle load completed event (AC4)
func _on_load_completed(_success: bool) -> void:
	hide_loading()


## Handle save started event (optional)
func _on_save_started() -> void:
	# Don't show overlay for saves - they're quick and non-blocking
	pass


## Handle save completed event (optional)
func _on_save_completed(_success: bool) -> void:
	pass

# =============================================================================
# PUBLIC API
# =============================================================================

## Check if the loading overlay is currently showing
func is_showing() -> bool:
	return visible
