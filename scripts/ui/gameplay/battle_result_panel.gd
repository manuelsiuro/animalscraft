## BattleResultPanel - Victory/defeat celebration and battle summary display.
## Shows confetti for victory, drooping for defeat, battle stats, and Continue button.
## Emits signal when player acknowledges result.
##
## Architecture: scripts/ui/gameplay/battle_result_panel.gd
## Story: 5-6-display-combat-animations
class_name BattleResultPanel
extends PanelContainer

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when player taps Continue button (AC13)
signal result_acknowledged()

# =============================================================================
# CONSTANTS
# =============================================================================

## Animation timing
const VICTORY_BOUNCE_DURATION: float = 0.3
const DEFEAT_DROOP_DURATION: float = 0.5
const CONFETTI_DURATION: float = 2.0
const FADE_IN_DURATION: float = 0.3

## Colors
const VICTORY_COLOR: Color = Color("#4CAF50")  # Green
const DEFEAT_COLOR: Color = Color("#9E9E9E")  # Gray
const GOLD_COLOR: Color = Color("#FFD700")  # Gold for victory

## Confetti settings
const CONFETTI_PARTICLE_COUNT: int = 20

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/VBoxContainer/SubtitleLabel
@onready var _stats_container: VBoxContainer = $MarginContainer/VBoxContainer/StatsContainer
@onready var _turns_label: Label = $MarginContainer/VBoxContainer/StatsContainer/TurnsLabel
@onready var _damage_label: Label = $MarginContainer/VBoxContainer/StatsContainer/DamageLabel
@onready var _captured_label: Label = $MarginContainer/VBoxContainer/StatsContainer/CapturedLabel
@onready var _continue_button: Button = $MarginContainer/VBoxContainer/ContinueButton
@onready var _confetti_container: Control = $ConfettiContainer
@onready var _celebration_icons: HBoxContainer = $MarginContainer/VBoxContainer/CelebrationIcons

# =============================================================================
# STATE
# =============================================================================

## Whether showing victory (true) or defeat (false)
var _is_victory: bool = false

## Battle stats
var _turns_taken: int = 0
var _total_damage_dealt: int = 0
var _captured_animals: Array = []

## Animation tween
var _tween: Tween = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Start hidden
	visible = false
	modulate.a = 0.0

	# Connect button
	if _continue_button:
		_continue_button.pressed.connect(_on_continue_pressed)


func _exit_tree() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

# =============================================================================
# PUBLIC API
# =============================================================================

## Show victory celebration with captured animals (AC10, AC12).
## @param captured_animals Array of animal type strings that were captured
## @param battle_log Array of BattleLogEntry for stats calculation
func show_victory(captured_animals: Array, battle_log: Array = []) -> void:
	_is_victory = true
	_captured_animals = captured_animals
	_calculate_stats(battle_log)

	# Configure display
	if _title_label:
		_title_label.text = "🎉 VICTORY! 🎉"
		_title_label.add_theme_color_override("font_color", GOLD_COLOR)

	if _subtitle_label:
		_subtitle_label.text = "You conquered the territory!"
		_subtitle_label.visible = true

	_update_stats_display()

	# Show captured animals section only if some were captured
	if _captured_label:
		if captured_animals.is_empty():
			_captured_label.visible = false
		else:
			_captured_label.visible = true
			var capture_text := "Captured: "
			for animal_type in captured_animals:
				capture_text += GameConstants.get_animal_icon(animal_type) + " "
			_captured_label.text = capture_text

	# Show with animation
	_show_with_animation()

	# Play victory celebration (AC10)
	_play_victory_celebration()


## Show defeat animation (AC11, AC12).
## @param battle_log Array of BattleLogEntry for stats calculation
func show_defeat(battle_log: Array = []) -> void:
	_is_victory = false
	_captured_animals = []
	_calculate_stats(battle_log)

	# Configure display
	if _title_label:
		_title_label.text = "😔 Defeated..."
		_title_label.add_theme_color_override("font_color", DEFEAT_COLOR)

	if _subtitle_label:
		_subtitle_label.text = "Your animals need rest."
		_subtitle_label.visible = true

	_update_stats_display()

	# Hide captured section
	if _captured_label:
		_captured_label.visible = false

	# Show with animation
	_show_with_animation()

	# Play defeat animation (AC11)
	_play_defeat_animation()


## Get the battle stats.
func get_battle_stats() -> Dictionary:
	return {
		"turns_taken": _turns_taken,
		"total_damage_dealt": _total_damage_dealt,
		"captured_count": _captured_animals.size(),
		"is_victory": _is_victory
	}

# =============================================================================
# PRIVATE METHODS - DISPLAY
# =============================================================================

## Calculate battle stats from log (AC12).
func _calculate_stats(battle_log: Array) -> void:
	_turns_taken = 0
	_total_damage_dealt = 0

	if battle_log.is_empty():
		return

	# Count turns and total damage
	for entry in battle_log:
		if "turn_number" in entry:
			_turns_taken = maxi(_turns_taken, entry.turn_number)
		if "damage" in entry:
			_total_damage_dealt += entry.damage


## Update stats display labels (AC12).
func _update_stats_display() -> void:
	if _turns_label:
		_turns_label.text = "⏱️ Turns: %d" % _turns_taken

	if _damage_label:
		_damage_label.text = "💥 Total Damage: %d" % _total_damage_dealt


## Show panel with fade animation.
func _show_with_animation() -> void:
	visible = true

	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)

# =============================================================================
# PRIVATE METHODS - VICTORY CELEBRATION (AC10)
# =============================================================================

## Play victory celebration with confetti and bouncing.
func _play_victory_celebration() -> void:
	# Spawn confetti particles
	if _confetti_container:
		_spawn_confetti()

	# Bounce celebration icons
	if _celebration_icons:
		_animate_celebration_bounce()


## Spawn confetti particles.
func _spawn_confetti() -> void:
	if not _confetti_container:
		return

	# Clear existing confetti
	for child in _confetti_container.get_children():
		child.queue_free()

	# Create confetti particles
	for i in CONFETTI_PARTICLE_COUNT:
		var confetti := _create_confetti_particle()
		_confetti_container.add_child(confetti)
		_animate_confetti_particle(confetti, i)


## Create a single confetti particle.
func _create_confetti_particle() -> Control:
	var particle := Label.new()

	# Random confetti emoji
	var confetti_chars := ["🎊", "🎉", "✨", "⭐", "🌟"]
	particle.text = confetti_chars[randi() % confetti_chars.size()]
	particle.add_theme_font_size_override("font_size", randi_range(12, 20))

	# Random starting position (spread across top)
	particle.position = Vector2(
		randf_range(0, _confetti_container.size.x if _confetti_container.size.x > 0 else 300),
		-20
	)

	return particle


## Animate a confetti particle falling.
func _animate_confetti_particle(particle: Control, index: int) -> void:
	var delay := randf_range(0, 0.5)
	var duration := randf_range(1.0, CONFETTI_DURATION)

	var tween := particle.create_tween()
	tween.set_parallel(true)

	# Fall down with some horizontal drift
	var target_y: float = _confetti_container.size.y if _confetti_container.size.y > 0 else 200.0
	var drift := randf_range(-50, 50)

	tween.tween_property(particle, "position:y", target_y, duration).set_delay(delay)
	tween.tween_property(particle, "position:x", particle.position.x + drift, duration).set_delay(delay)
	tween.tween_property(particle, "modulate:a", 0.0, duration * 0.3).set_delay(delay + duration * 0.7)

	# Rotation for visual interest
	tween.tween_property(particle, "rotation_degrees", randf_range(-180, 180), duration).set_delay(delay)

	tween.set_parallel(false)
	tween.tween_callback(particle.queue_free)


## Animate celebration icons bouncing.
func _animate_celebration_bounce() -> void:
	if not _celebration_icons:
		return

	# Clear any existing icons first (prevent mixing victory/defeat icons)
	for child in _celebration_icons.get_children():
		child.queue_free()

	# Wait a frame for cleanup, then create bouncing animal icons
	await get_tree().process_frame

	# Create bouncing animal icons
	var icons := ["🐰", "🦊", "🐻", "🐼"]
	for icon_text in icons:
		var icon := Label.new()
		icon.text = icon_text
		icon.add_theme_font_size_override("font_size", 28)
		_celebration_icons.add_child(icon)

	# Animate each icon with staggered bounce
	var i := 0
	for child in _celebration_icons.get_children():
		_animate_single_bounce(child, i * 0.1)
		i += 1


## Animate a single icon bouncing.
func _animate_single_bounce(icon: Control, delay: float) -> void:
	var original_y := icon.position.y
	var tween := icon.create_tween()
	tween.set_loops(3)  # Bounce 3 times

	tween.tween_property(icon, "position:y", original_y - 15, VICTORY_BOUNCE_DURATION / 2).set_delay(delay)
	tween.tween_property(icon, "position:y", original_y, VICTORY_BOUNCE_DURATION / 2)

# =============================================================================
# PRIVATE METHODS - DEFEAT ANIMATION (AC11)
# =============================================================================

## Play gentle defeat animation.
func _play_defeat_animation() -> void:
	# Droop the celebration icons (sad animals)
	if _celebration_icons:
		_animate_defeat_droop()

	# Apply grayish tint
	var tween := create_tween()
	tween.tween_property(self, "self_modulate", Color(0.8, 0.8, 0.9, 1.0), DEFEAT_DROOP_DURATION)


## Animate icons drooping for defeat.
func _animate_defeat_droop() -> void:
	if not _celebration_icons:
		return

	# Clear any existing icons first (prevent mixing victory/defeat icons)
	for child in _celebration_icons.get_children():
		child.queue_free()

	# Wait a frame for cleanup, then create drooping animal icons (AC11)
	await get_tree().process_frame

	# Create drooping animal icons (same animals as victory, but sad)
	var icons := ["🐰", "🦊", "🐻", "🐼"]
	for icon_text in icons:
		var icon := Label.new()
		icon.text = icon_text
		icon.add_theme_font_size_override("font_size", 28)
		_celebration_icons.add_child(icon)

	# Animate each animal icon drooping (tilted, grayed out)
	for child in _celebration_icons.get_children():
		var tween := child.create_tween()
		tween.set_parallel(true)
		tween.tween_property(child, "rotation_degrees", randf_range(-20, -10), DEFEAT_DROOP_DURATION)
		tween.tween_property(child, "modulate", Color(0.6, 0.6, 0.6, 1.0), DEFEAT_DROOP_DURATION)
		tween.tween_property(child, "position:y", child.position.y + 5, DEFEAT_DROOP_DURATION)  # Slight droop down

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

## Handle Continue button press (AC13).
func _on_continue_pressed() -> void:
	result_acknowledged.emit()

	# Hide panel
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_IN_DURATION)
	_tween.tween_callback(func():
		visible = false
	)
