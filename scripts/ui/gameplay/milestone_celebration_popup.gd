## Displays celebratory popup when a milestone is achieved.
## Shows icon, name, description, and any unlock rewards.
## Supports confetti animation and accessibility settings.
##
## Architecture: scripts/ui/gameplay/milestone_celebration_popup.gd
## Story: 6-6-display-milestone-celebrations
class_name MilestoneCelebrationPopup
extends PanelContainer

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the celebration is dismissed (by button or auto-timeout)
signal celebration_dismissed()

# =============================================================================
# CONSTANTS
# =============================================================================

## Auto-dismiss timer duration (AC5)
const AUTO_DISMISS_TIME: float = 5.0

## Animation durations
const FADE_DURATION: float = 0.3
const SCALE_DURATION: float = 0.25
const ICON_BOUNCE_DURATION: float = 0.4

## Confetti settings (AC2)
const CONFETTI_PARTICLE_COUNT: int = 15
const CONFETTI_DURATION: float = 2.0

## Milestone type icons (AC3)
const TYPE_ICONS: Dictionary = {
	MilestoneData.Type.POPULATION: "\ud83d\udc65",
	MilestoneData.Type.BUILDING: "\ud83c\udfe0",
	MilestoneData.Type.TERRITORY: "\ud83d\uddfa\ufe0f",
	MilestoneData.Type.COMBAT: "\u2694\ufe0f",
	MilestoneData.Type.PRODUCTION: "\ud83c\udf5e",
}

## Type colors for subtle theming
const TYPE_COLORS: Dictionary = {
	MilestoneData.Type.POPULATION: Color("#5B9BD5"),   # Blue
	MilestoneData.Type.BUILDING: Color("#8B6914"),     # Brown
	MilestoneData.Type.TERRITORY: Color("#70AD47"),    # Green
	MilestoneData.Type.COMBAT: Color("#C55A5A"),       # Red
	MilestoneData.Type.PRODUCTION: Color("#FFC000"),   # Gold
}

## Warm, cozy popup colors (AC8)
const PANEL_COLOR: Color = Color("#F5E6D3")           # Warm cream
const TITLE_COLOR: Color = Color("#4A3728")           # Warm brown
const DESC_COLOR: Color = Color("#6B5344")            # Muted brown
const UNLOCK_COLOR: Color = Color("#2E7D32")          # Pleasant green

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _icon_label: Label = $MarginContainer/VBoxContainer/IconLabel
@onready var _name_label: Label = $MarginContainer/VBoxContainer/NameLabel
@onready var _description_label: Label = $MarginContainer/VBoxContainer/DescriptionLabel
@onready var _unlocks_container: VBoxContainer = $MarginContainer/VBoxContainer/UnlocksContainer
@onready var _unlocks_label: Label = $MarginContainer/VBoxContainer/UnlocksContainer/UnlocksLabel
@onready var _unlocks_list: Label = $MarginContainer/VBoxContainer/UnlocksContainer/UnlocksList
@onready var _continue_button: Button = $MarginContainer/VBoxContainer/ContinueButton
@onready var _confetti_container: Control = $ConfettiContainer

# =============================================================================
# STATE
# =============================================================================

## Current milestone being displayed
var _current_milestone: MilestoneData = null

## Animation tween
var _tween: Tween = null

## Auto-dismiss timer
var _dismiss_timer: Timer = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Start hidden
	visible = false
	modulate.a = 0.0
	scale = Vector2(0.8, 0.8)

	# Connect button
	if _continue_button:
		_continue_button.pressed.connect(_on_continue_pressed)

	# Create auto-dismiss timer
	_dismiss_timer = Timer.new()
	_dismiss_timer.one_shot = true
	_dismiss_timer.timeout.connect(_on_auto_dismiss_timeout)
	add_child(_dismiss_timer)


func _exit_tree() -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	if _dismiss_timer:
		_dismiss_timer.stop()

# =============================================================================
# PUBLIC API (AC1)
# =============================================================================

## Show celebration for a milestone.
## @param milestone The MilestoneData to celebrate
func show_milestone(milestone: MilestoneData) -> void:
	if milestone == null:
		GameLogger.warn("MilestoneCelebrationPopup", "Cannot show null milestone")
		return

	_current_milestone = milestone

	_configure_display(milestone)
	_start_animations()
	_play_celebration_sound()
	_start_auto_dismiss_timer()


## Hide the popup with animation.
func hide_popup() -> void:
	_dismiss()

# =============================================================================
# PRIVATE METHODS - DISPLAY (AC1, AC3, AC4)
# =============================================================================

## Configure the display with milestone data.
func _configure_display(milestone: MilestoneData) -> void:
	# Icon (AC3)
	if _icon_label:
		if TYPE_ICONS.has(milestone.type):
			_icon_label.text = TYPE_ICONS[milestone.type]
		else:
			_icon_label.text = "\u2b50"  # Fallback star icon
			GameLogger.warn("MilestoneCelebrationPopup", "Unknown milestone type %d, using fallback icon" % milestone.type)

	# Name (AC1)
	if _name_label:
		_name_label.text = milestone.display_name
		_name_label.add_theme_color_override("font_color", TYPE_COLORS.get(milestone.type, TITLE_COLOR))

	# Description (AC1)
	if _description_label:
		_description_label.text = milestone.description

	# Unlock rewards (AC4)
	_configure_unlock_rewards(milestone.unlock_rewards)


## Configure the unlock rewards section.
func _configure_unlock_rewards(rewards: Array[String]) -> void:
	if _unlocks_container == null:
		return

	if rewards.is_empty():
		_unlocks_container.visible = false
		return

	_unlocks_container.visible = true

	if _unlocks_label:
		_unlocks_label.text = "Unlocked:"

	if _unlocks_list:
		var reward_texts: Array[String] = []
		for reward in rewards:
			var display_name := GameConstants.get_building_display_name(reward)
			var icon := GameConstants.get_building_icon(reward)
			reward_texts.append("%s %s" % [icon, display_name])
		_unlocks_list.text = "\n".join(reward_texts)

# =============================================================================
# PRIVATE METHODS - ANIMATION (AC2, AC10)
# =============================================================================

## Start show animations.
func _start_animations() -> void:
	visible = true

	# Check accessibility setting (AC10)
	var reduce_motion := Settings.is_reduce_motion_enabled()

	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	if reduce_motion:
		# Simple fade only for reduced motion
		modulate.a = 0.0
		scale = Vector2.ONE
		_tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)
	else:
		# Full animation (AC2)
		modulate.a = 0.0
		scale = Vector2(0.8, 0.8)
		_tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)
		_tween.tween_property(self, "scale", Vector2.ONE, SCALE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		# Icon bounce (AC3)
		_animate_icon_bounce()

		# Confetti (AC2) - spawn after layout frame to ensure sizes are computed
		_spawn_confetti_deferred()


## Animate the icon bouncing (AC3).
func _animate_icon_bounce() -> void:
	if _icon_label == null or Settings.is_reduce_motion_enabled():
		return

	var icon_tween := _icon_label.create_tween()
	icon_tween.set_loops(2)

	# Store original position
	var original_y := _icon_label.position.y

	icon_tween.tween_property(_icon_label, "position:y", original_y - 10, ICON_BOUNCE_DURATION / 2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	icon_tween.tween_property(_icon_label, "position:y", original_y, ICON_BOUNCE_DURATION / 2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## Spawn confetti particles after ensuring layout is computed (AC2, AC10).
## Uses deferred call to wait for layout frame.
func _spawn_confetti_deferred() -> void:
	if _confetti_container == null:
		return

	# Skip confetti if reduced motion enabled (AC10)
	if Settings.is_reduce_motion_enabled():
		return

	# Wait for layout to be computed so container size is valid
	await get_tree().process_frame

	# Double-check we're still valid after await
	if not is_instance_valid(self) or not is_instance_valid(_confetti_container):
		return

	_spawn_confetti()


## Spawn confetti particles immediately (AC2, AC10).
func _spawn_confetti() -> void:
	if _confetti_container == null:
		return

	# Skip confetti if reduced motion enabled (AC10)
	if Settings.is_reduce_motion_enabled():
		return

	# Clear existing confetti
	for child in _confetti_container.get_children():
		child.queue_free()

	# Create confetti particles
	for i in CONFETTI_PARTICLE_COUNT:
		var confetti := _create_confetti_particle()
		_confetti_container.add_child(confetti)
		_animate_confetti_particle(confetti)


## Create a single confetti particle.
func _create_confetti_particle() -> Control:
	var particle := Label.new()

	# Random confetti emoji
	var confetti_chars := ["\ud83c\udf89", "\ud83c\udf8a", "\u2728", "\u2b50", "\ud83c\udf1f", "\ud83c\udf88", "\ud83e\udde1"]
	particle.text = confetti_chars[randi() % confetti_chars.size()]
	particle.add_theme_font_size_override("font_size", randi_range(12, 20))

	# Random starting position across top
	var container_width: float = _confetti_container.size.x if _confetti_container.size.x > 0 else 300.0
	particle.position = Vector2(randf_range(0, container_width), -20)

	return particle


## Animate a confetti particle falling.
func _animate_confetti_particle(particle: Control) -> void:
	var delay := randf_range(0, 0.5)
	var duration := randf_range(1.0, CONFETTI_DURATION)

	var tween := particle.create_tween()
	tween.set_parallel(true)

	# Fall down with horizontal drift
	var container_height: float = _confetti_container.size.y if _confetti_container.size.y > 0 else 200.0
	var drift := randf_range(-50, 50)

	tween.tween_property(particle, "position:y", container_height, duration).set_delay(delay)
	tween.tween_property(particle, "position:x", particle.position.x + drift, duration).set_delay(delay)
	tween.tween_property(particle, "modulate:a", 0.0, duration * 0.3).set_delay(delay + duration * 0.7)

	# Rotation for visual interest
	tween.tween_property(particle, "rotation_degrees", randf_range(-180, 180), duration).set_delay(delay)

	tween.set_parallel(false)
	tween.tween_callback(particle.queue_free)

# =============================================================================
# PRIVATE METHODS - SOUND (AC2)
# =============================================================================

## Play celebration sound effect.
## Uses AudioManager.play_ui_sfx which looks for sfx_ui_{name}.ogg
func _play_celebration_sound() -> void:
	# Play via AudioManager (respects audio settings)
	# AudioManager.play_ui_sfx looks for "res://assets/audio/sfx/sfx_ui_milestone.ogg"
	# Check if file exists to avoid error spam during testing
	var sfx_path := "res://assets/audio/sfx/sfx_ui_milestone.ogg"
	if FileAccess.file_exists(sfx_path):
		AudioManager.play_ui_sfx("milestone")

# =============================================================================
# PRIVATE METHODS - AUTO-DISMISS (AC5)
# =============================================================================

## Start the auto-dismiss timer.
func _start_auto_dismiss_timer() -> void:
	if _dismiss_timer:
		_dismiss_timer.start(AUTO_DISMISS_TIME)


## Stop the auto-dismiss timer.
func _stop_auto_dismiss_timer() -> void:
	if _dismiss_timer:
		_dismiss_timer.stop()


## Handle auto-dismiss timeout.
func _on_auto_dismiss_timeout() -> void:
	_dismiss()


## Dismiss the popup with animation.
func _dismiss() -> void:
	_stop_auto_dismiss_timer()

	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	var reduce_motion := Settings.is_reduce_motion_enabled()

	if reduce_motion:
		_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	else:
		_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
		_tween.tween_property(self, "scale", Vector2(0.9, 0.9), FADE_DURATION)

	_tween.set_parallel(false)
	_tween.tween_callback(_on_dismiss_complete)


## Called when dismiss animation completes.
func _on_dismiss_complete() -> void:
	visible = false
	_current_milestone = null
	celebration_dismissed.emit()

# =============================================================================
# SIGNAL HANDLERS (AC5)
# =============================================================================

## Handle Continue button press.
func _on_continue_pressed() -> void:
	_dismiss()
