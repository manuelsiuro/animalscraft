## DamagePopup - Floating damage number that rises and fades.
## Shows damage dealt or healing received during combat.
## Auto-destroys when animation completes.
##
## Architecture: scripts/ui/effects/damage_popup.gd
## Story: 5-6-display-combat-animations
class_name DamagePopup
extends Control

# =============================================================================
# CONSTANTS
# =============================================================================

## Animation parameters (AC6)
const RISE_DISTANCE: int = 50
const ANIMATION_DURATION: float = 0.5

## Colors
const DAMAGE_COLOR: Color = Color.RED
const HEALING_COLOR: Color = Color.GREEN
const CRITICAL_COLOR: Color = Color("#FF4500")  # Orange-red for critical hits

## Font sizes
const NORMAL_FONT_SIZE: int = 24
const CRITICAL_FONT_SIZE: int = 32

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _label: Label = $Label

# =============================================================================
# STATE
# =============================================================================

## Animation tween
var _tween: Tween = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Ensure we're above other UI
	z_index = 100

	# Start hidden until show_damage is called
	modulate.a = 1.0


func _exit_tree() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

# =============================================================================
# PUBLIC API
# =============================================================================

## Show damage number at position with animation (AC6).
## @param amount The damage amount (negative for healing)
## @param start_position The starting position for the popup
## @param is_critical Whether this is a critical hit (larger font)
func show_damage(amount: int, start_position: Vector2, is_critical: bool = false) -> void:
	# Set position
	position = start_position - size / 2

	# Configure label
	if _label:
		# Text format: "-3" for damage, "+5" for healing
		if amount >= 0:
			_label.text = "-%d" % amount
			_label.add_theme_color_override("font_color", DAMAGE_COLOR)
		else:
			_label.text = "+%d" % abs(amount)
			_label.add_theme_color_override("font_color", HEALING_COLOR)

		# Font size based on critical
		var font_size := CRITICAL_FONT_SIZE if is_critical else NORMAL_FONT_SIZE
		_label.add_theme_font_size_override("font_size", font_size)

		# Use critical color for critical hits
		if is_critical and amount >= 0:
			_label.add_theme_color_override("font_color", CRITICAL_COLOR)

	# Play animation
	_play_animation()


## Show healing number at position.
## @param amount The healing amount
## @param start_position The starting position
func show_healing(amount: int, start_position: Vector2) -> void:
	# Healing is shown as negative damage (green, with +)
	show_damage(-abs(amount), start_position, false)

# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Play the rise and fade animation (AC6).
func _play_animation() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()

	# Parallel: rise up and fade out
	_tween.set_parallel(true)
	_tween.tween_property(self, "position:y", position.y - RISE_DISTANCE, ANIMATION_DURATION)
	_tween.tween_property(self, "modulate:a", 0.0, ANIMATION_DURATION)

	# Queue free when done
	_tween.set_parallel(false)
	_tween.tween_callback(queue_free)
