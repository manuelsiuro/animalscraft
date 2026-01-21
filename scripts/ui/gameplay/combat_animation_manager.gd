## CombatAnimationManager - Orchestrates combat animation sequences.
## Handles attack lunges, damage popups, splat effects, and knockout animations.
## Emits SFX signals for future audio integration (Epic 7).
##
## Architecture: scripts/ui/gameplay/combat_animation_manager.gd
## Story: 5-6-display-combat-animations
class_name CombatAnimationManager
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when SFX should be played (AC16, AC17)
signal combat_sfx_requested(sfx_id: String)

## Emitted when an animation sequence completes
signal animation_completed()

# =============================================================================
# CONSTANTS
# =============================================================================

## Animation timing
const ATTACK_LUNGE_DURATION: float = 0.5
const DAMAGE_POPUP_DELAY: float = 0.25  # When to show damage (mid-lunge)
const SPLAT_DELAY: float = 0.3  # When to show splat (near impact)

# =============================================================================
# PRELOADS
# =============================================================================

var _damage_popup_scene: PackedScene = null
var _splat_effect_scene: PackedScene = null

# =============================================================================
# STATE
# =============================================================================

## Parent CombatOverlay reference
var _overlay: CombatOverlay = null

## Currently running animation
var _is_animating: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Get parent overlay
	var parent := get_parent()
	if parent is CombatOverlay:
		_overlay = parent

	# Preload effect scenes
	_preload_effect_scenes()


func _exit_tree() -> void:
	pass  # No EventBus signals to disconnect - we listen via parent overlay

# =============================================================================
# PUBLIC API
# =============================================================================

## Play complete attack animation sequence (AC4, AC5, AC6, AC7).
## @param attacker_display The CombatantDisplay of the attacker
## @param defender_display The CombatantDisplay of the defender
## @param damage The damage amount
## @param defender_hp The defender's HP after this attack
func play_attack_sequence(attacker_display: Control, defender_display: Control, damage: int, defender_hp: int) -> void:
	if _is_animating:
		# Queue animation? For now, log warning
		GameLogger.debug("UI", "CombatAnimationManager: Animation already in progress, new attack may overlap")

	_is_animating = true

	# Get positions
	var attacker_pos := _get_display_center(attacker_display)
	var defender_pos := _get_display_center(defender_display)

	# Get max HP for health update
	var max_hp := _get_max_hp(defender_display)

	# 1. Play attack lunge animation (AC4)
	if attacker_display.has_method("play_attack_lunge"):
		attacker_display.play_attack_lunge(defender_pos)

	# 2. Schedule splat effect (AC5)
	_schedule_splat_effect(defender_pos, SPLAT_DELAY)

	# 3. Schedule damage popup (AC6)
	_schedule_damage_popup(defender_pos, damage, DAMAGE_POPUP_DELAY)

	# 4. Update health bar (AC7)
	if defender_display.has_method("update_hp"):
		# Small delay so health updates after visual hit
		get_tree().create_timer(DAMAGE_POPUP_DELAY).timeout.connect(func():
			if is_instance_valid(defender_display):
				defender_display.update_hp(defender_hp, max_hp, true)
		)

	# 5. Play hit reaction on defender
	if defender_display.has_method("play_hit_reaction"):
		get_tree().create_timer(DAMAGE_POPUP_DELAY).timeout.connect(func():
			if is_instance_valid(defender_display):
				defender_display.play_hit_reaction()
		)

	# 6. Check for knockout (AC8, AC9)
	if defender_hp <= 0:
		get_tree().create_timer(ATTACK_LUNGE_DURATION).timeout.connect(func():
			if is_instance_valid(defender_display) and defender_display.has_method("play_knocked_out"):
				defender_display.play_knocked_out()
		)

	# Mark animation complete after full sequence
	get_tree().create_timer(ATTACK_LUNGE_DURATION).timeout.connect(func():
		_is_animating = false
		animation_completed.emit()
	)


## Play damage popup at position (AC6).
## @param position The world position for the popup
## @param damage The damage amount to display
func play_damage_popup(position: Vector2, damage: int) -> void:
	var effects_container := _get_effects_container()
	if not effects_container:
		return

	if _damage_popup_scene:
		var popup: Control = _damage_popup_scene.instantiate()
		effects_container.add_child(popup)
		if popup.has_method("show_damage"):
			popup.show_damage(damage, position)
	else:
		# Fallback: create simple popup
		_create_fallback_damage_popup(effects_container, position, damage)


## Play splat effect at position (AC5).
## @param position The world position for the effect
func play_splat_effect(position: Vector2) -> void:
	# Emit SFX signal (AC17)
	combat_sfx_requested.emit("splat")
	if _overlay:
		_overlay.combat_sfx_requested.emit("splat")

	var effects_container := _get_effects_container()
	if not effects_container:
		return

	if _splat_effect_scene:
		var splat: Node2D = _splat_effect_scene.instantiate()
		effects_container.add_child(splat)
		splat.global_position = position
		if splat.has_method("play"):
			splat.play()
	else:
		# Fallback: create simple splat animation
		_create_fallback_splat_effect(effects_container, position)

# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Preload effect scenes for faster instantiation.
func _preload_effect_scenes() -> void:
	var damage_popup_path := "res://scenes/ui/effects/damage_popup.tscn"
	var splat_effect_path := "res://scenes/effects/splat_effect.tscn"

	if ResourceLoader.exists(damage_popup_path):
		_damage_popup_scene = load(damage_popup_path)

	if ResourceLoader.exists(splat_effect_path):
		_splat_effect_scene = load(splat_effect_path)


## Get the effects container from overlay.
func _get_effects_container() -> Control:
	if _overlay and _overlay.has_method("get_effects_container"):
		return _overlay.get_effects_container()
	return _overlay


## Get center position of a display.
func _get_display_center(display: Control) -> Vector2:
	if display.has_method("get_sprite_center"):
		return display.get_sprite_center()
	return display.global_position + display.size / 2


## Get max HP from display.
func _get_max_hp(display: Control) -> int:
	if display.has_meta("max_hp"):
		return display.get_meta("max_hp")
	if display is CombatantDisplay and "_max_hp" in display:
		return display._max_hp
	return 100  # Fallback


## Schedule splat effect after delay.
func _schedule_splat_effect(position: Vector2, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(func():
		play_splat_effect(position)
	)


## Schedule damage popup after delay.
func _schedule_damage_popup(position: Vector2, damage: int, delay: float) -> void:
	get_tree().create_timer(delay).timeout.connect(func():
		play_damage_popup(position, damage)
	)


## Create fallback damage popup without scene file.
func _create_fallback_damage_popup(container: Control, position: Vector2, damage: int) -> void:
	var label := Label.new()
	label.text = "-%d" % damage
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.RED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = container.get_local_position(position) if container.has_method("get_local_position") else position - container.global_position

	container.add_child(label)

	# Animate rise and fade
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50, 0.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)


## Create fallback splat effect without scene file.
func _create_fallback_splat_effect(container: Control, position: Vector2) -> void:
	# Create simple "SPLAT" text animation
	var label := Label.new()
	label.text = "💥"
	label.add_theme_font_size_override("font_size", 32)
	label.position = container.get_local_position(position) if container.has_method("get_local_position") else position - container.global_position

	container.add_child(label)

	# Animate scale and fade
	var tween := label.create_tween()
	label.scale = Vector2(0.5, 0.5)
	label.pivot_offset = label.size / 2
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector2(1.5, 1.5), 0.2)
	tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.1)
	tween.set_parallel(false)
	tween.tween_callback(label.queue_free)
