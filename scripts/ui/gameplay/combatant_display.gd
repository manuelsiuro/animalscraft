## CombatantDisplay - Visual representation of a single combatant in battle.
## Shows animal sprite, health bar, and handles animation states (normal, hit, knockout).
## Used within CombatOverlay for both player and enemy animals.
##
## Architecture: scripts/ui/gameplay/combatant_display.gd
## Story: 5-6-display-combat-animations
class_name CombatantDisplay
extends Control

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when knockout animation completes
signal knockout_animation_completed()

## Emitted when any animation on this display completes
signal animation_completed()

# =============================================================================
# CONSTANTS
# =============================================================================

## Animation timing
const HEALTH_BAR_TWEEN_DURATION: float = 0.2
const KNOCKOUT_STARS_DURATION: float = 0.5
const LUNGE_FORWARD_DURATION: float = 0.25
const LUNGE_RETURN_DURATION: float = 0.2
const HIT_FLASH_DURATION: float = 0.1

## Visual constants
const LUNGE_DISTANCE: float = 40.0
const KNOCKOUT_GRAY_ALPHA: float = 0.5

## Health bar colors
const COLOR_HP_HIGH: Color = Color("#4CAF50")  # Green
const COLOR_HP_MEDIUM: Color = Color("#FFC107")  # Yellow
const COLOR_HP_LOW: Color = Color("#F44336")  # Red

## Hit flash color
const HIT_FLASH_COLOR: Color = Color(1.0, 0.3, 0.3, 1.0)

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _sprite_container: Control = $SpriteContainer
@onready var _animal_icon: Label = $SpriteContainer/AnimalIcon
@onready var _health_bar: ProgressBar = $SpriteContainer/HealthBar
@onready var _hp_label: Label = $SpriteContainer/HPLabel
@onready var _knockout_overlay: ColorRect = $SpriteContainer/KnockoutOverlay
@onready var _stars_container: Control = $SpriteContainer/StarsContainer
@onready var _name_label: Label = $NameLabel

# =============================================================================
# STATE
# =============================================================================

## The CombatUnit this display represents
var _unit: RefCounted = null

## Whether this is a player team member
var _is_player_team: bool = true

## Current HP tracking
var _current_hp: int = 0
var _max_hp: int = 0

## Whether currently knocked out
var _is_knocked_out: bool = false

## Original position for lunge animation
var _original_position: Vector2

## Active tweens for cleanup
var _active_tweens: Array[Tween] = []

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Start with overlay hidden
	if _knockout_overlay:
		_knockout_overlay.visible = false
	if _stars_container:
		_stars_container.visible = false

	# Store original position
	_original_position = position


func _exit_tree() -> void:
	# Cleanup tweens
	for tween in _active_tweens:
		if tween and tween.is_running():
			tween.kill()
	_active_tweens.clear()

# =============================================================================
# PUBLIC API
# =============================================================================

## Setup the display with a CombatUnit.
## @param unit The CombatUnit RefCounted object
## @param is_player Whether this is a player team member
func setup(unit: RefCounted, is_player: bool) -> void:
	_unit = unit
	_is_player_team = is_player

	if not unit:
		GameLogger.warn("UI", "CombatantDisplay: Cannot setup with null unit")
		return

	# Store HP values
	_max_hp = unit.max_hp
	_current_hp = unit.current_hp

	# Get animal info
	var animal_type := "unknown"
	var animal_id := "Animal"
	if unit.animal and unit.animal.stats:
		animal_type = unit.animal.stats.animal_id
		animal_id = unit.animal.get_animal_id() if unit.animal.has_method("get_animal_id") else animal_type

	# Set animal icon
	if _animal_icon:
		_animal_icon.text = GameConstants.get_animal_icon(animal_type)
		# Flip for enemies (face left)
		if not is_player:
			_animal_icon.scale.x = -1

	# Set name label
	if _name_label:
		_name_label.text = animal_id

	# Set initial HP display (AC3)
	_update_health_display(_current_hp, _max_hp, false)


## Get the unit_id.
func get_unit_id() -> String:
	if _unit and "unit_id" in _unit:
		return _unit.unit_id
	return ""


## Check if this is a player team display.
func is_player_team() -> bool:
	return _is_player_team


## Get sprite container position for animation targeting.
func get_sprite_center() -> Vector2:
	if _sprite_container:
		return _sprite_container.global_position + _sprite_container.size / 2
	return global_position + size / 2


## Update HP with optional animation (AC3, AC7).
## @param new_hp The new HP value
## @param max_hp The maximum HP
## @param animate Whether to animate the change
func update_hp(new_hp: int, max_hp: int, animate: bool = true) -> void:
	_current_hp = new_hp
	_max_hp = max_hp
	_update_health_display(new_hp, max_hp, animate)

	# Check for knockout
	if new_hp <= 0 and not _is_knocked_out:
		play_knocked_out()


## Play attack lunge animation (AC4).
## @param target_position The position to lunge toward
## @return Tween for chaining/tracking
func play_attack_lunge(target_position: Vector2) -> Tween:
	if not _sprite_container:
		return null

	_original_position = _sprite_container.position
	var direction := (target_position - global_position).normalized()
	var lunge_offset := direction * LUNGE_DISTANCE

	var tween := create_tween()
	_register_tween(tween)

	# Forward lunge
	tween.tween_property(_sprite_container, "position",
		_original_position + lunge_offset, LUNGE_FORWARD_DURATION)
	# Return
	tween.tween_property(_sprite_container, "position",
		_original_position, LUNGE_RETURN_DURATION)

	tween.finished.connect(func(): animation_completed.emit())

	return tween


## Play hit reaction animation.
## Visual flash when taking damage.
func play_hit_reaction() -> Tween:
	if not _sprite_container:
		return null

	var tween := create_tween()
	_register_tween(tween)

	var original_modulate := _sprite_container.modulate
	tween.tween_property(_sprite_container, "modulate", HIT_FLASH_COLOR, HIT_FLASH_DURATION)
	tween.tween_property(_sprite_container, "modulate", original_modulate, HIT_FLASH_DURATION)

	return tween


## Play knockout animation (AC8, AC9).
## Shows dizzy stars, then transitions to knocked out visual state.
func play_knocked_out() -> void:
	if _is_knocked_out:
		return

	_is_knocked_out = true

	# Show stars animation (AC8)
	if _stars_container:
		_stars_container.visible = true
		_animate_stars()

	# After stars, show knockout overlay (AC9)
	var tween := create_tween()
	_register_tween(tween)

	tween.tween_interval(KNOCKOUT_STARS_DURATION)
	tween.tween_callback(func():
		if _stars_container:
			_stars_container.visible = false
		if _knockout_overlay:
			_knockout_overlay.visible = true
		# Gray out the display
		if _sprite_container:
			_sprite_container.modulate = Color(0.5, 0.5, 0.5, KNOCKOUT_GRAY_ALPHA)
		knockout_animation_completed.emit()
	)


## Reset the display for reuse.
func reset() -> void:
	_is_knocked_out = false
	_current_hp = _max_hp

	# Reset visuals
	if _sprite_container:
		_sprite_container.position = _original_position
		_sprite_container.modulate = Color.WHITE

	if _knockout_overlay:
		_knockout_overlay.visible = false

	if _stars_container:
		_stars_container.visible = false

	_update_health_display(_max_hp, _max_hp, false)

	# Cancel active tweens
	for tween in _active_tweens:
		if tween and tween.is_running():
			tween.kill()
	_active_tweens.clear()

# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Update health bar and label display.
func _update_health_display(hp: int, max_hp: int, animate: bool) -> void:
	var hp_percent := float(hp) / float(max_hp) if max_hp > 0 else 0.0

	# Update health bar
	if _health_bar:
		var target_value := hp_percent * 100.0

		if animate:
			var tween := create_tween()
			_register_tween(tween)
			tween.tween_property(_health_bar, "value", target_value, HEALTH_BAR_TWEEN_DURATION)
		else:
			_health_bar.value = target_value

		# Update color based on HP level
		_update_health_bar_color(hp_percent)

	# Update HP label
	if _hp_label:
		_hp_label.text = "%d/%d" % [hp, max_hp]


## Update health bar color based on HP percentage.
func _update_health_bar_color(hp_percent: float) -> void:
	if not _health_bar:
		return

	var bar_style := _health_bar.get_theme_stylebox("fill")
	if bar_style and bar_style is StyleBoxFlat:
		bar_style = bar_style.duplicate()
		if hp_percent <= 0.25:
			bar_style.bg_color = COLOR_HP_LOW
		elif hp_percent <= 0.5:
			bar_style.bg_color = COLOR_HP_MEDIUM
		else:
			bar_style.bg_color = COLOR_HP_HIGH
		_health_bar.add_theme_stylebox_override("fill", bar_style)


## Animate the dizzy stars.
func _animate_stars() -> void:
	if not _stars_container:
		return

	# Create spinning star labels if not present
	if _stars_container.get_child_count() == 0:
		for i in 3:
			var star := Label.new()
			star.text = "⭐"
			star.add_theme_font_size_override("font_size", 14)
			star.position = Vector2(cos(i * TAU / 3) * 15, sin(i * TAU / 3) * 15 - 10)
			_stars_container.add_child(star)

	# Spin the stars
	var tween := create_tween()
	_register_tween(tween)
	tween.set_loops(int(KNOCKOUT_STARS_DURATION / 0.5))
	tween.tween_property(_stars_container, "rotation_degrees", 360.0, 0.5).from(0.0)


## Register a tween for cleanup and pause/resume support.
func _register_tween(tween: Tween) -> void:
	_active_tweens.append(tween)
	tween.finished.connect(func(): _active_tweens.erase(tween))

	# Register with parent overlay for pause/resume
	var overlay := get_parent()
	while overlay and not overlay is CombatOverlay:
		overlay = overlay.get_parent()
	if overlay and overlay.has_method("register_tween"):
		overlay.register_tween(tween)
