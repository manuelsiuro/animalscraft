## SplatEffect - Cozy food-fight splat particle effect.
## Pie splatter visual (not violent) - fits the cozy aesthetic.
## Auto-destroys when emission completes.
##
## Architecture: scripts/effects/splat_effect.gd
## Story: 5-6-display-combat-animations
class_name SplatEffect
extends Node2D

# =============================================================================
# CONSTANTS
# =============================================================================

## Animation timing
const EFFECT_DURATION: float = 0.3
const PARTICLE_COUNT: int = 8

## Splat particle colors (cozy food-fight palette) (AC5)
const SPLAT_COLORS: Array[Color] = [
	Color("#FFB347"),  # Orange (pie)
	Color("#FFFACD"),  # Lemon chiffon (cream)
	Color("#FF6347"),  # Tomato
	Color("#FFDAB9"),  # Peach puff
]

## Particle parameters
const SPREAD_RADIUS: float = 30.0
const PARTICLE_SIZE_MIN: float = 4.0
const PARTICLE_SIZE_MAX: float = 12.0

# =============================================================================
# STATE
# =============================================================================

## Particles container
var _particles: Array[Node2D] = []

## Animation tween
var _tween: Tween = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Auto-play on ready
	play()


func _exit_tree() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

# =============================================================================
# PUBLIC API
# =============================================================================

## Play the splat effect animation (AC5).
func play() -> void:
	_create_particles()
	_animate_particles()


## Set the splat position.
func set_splat_position(pos: Vector2) -> void:
	global_position = pos

# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Create splat particles.
func _create_particles() -> void:
	# Clear existing
	for particle in _particles:
		if is_instance_valid(particle):
			particle.queue_free()
	_particles.clear()

	# Create new particles
	for i in PARTICLE_COUNT:
		var particle := _create_single_particle(i)
		add_child(particle)
		_particles.append(particle)


## Create a single particle.
func _create_single_particle(index: int) -> Node2D:
	# Use a simple ColorRect for 2D particles (food splat visual)
	var particle := Node2D.new()

	# Random color from palette
	var color: Color = SPLAT_COLORS[randi() % SPLAT_COLORS.size()]

	# Random size
	var size := randf_range(PARTICLE_SIZE_MIN, PARTICLE_SIZE_MAX)

	# Random angle for spread
	var angle := (float(index) / PARTICLE_COUNT) * TAU + randf_range(-0.3, 0.3)

	# Store particle data for animation
	particle.set_meta("angle", angle)

	# Add visual (simple colored rect for cozy food-splat aesthetic)
	var visual := ColorRect.new()
	visual.color = color
	visual.size = Vector2(size, size)
	visual.position = -Vector2(size, size) / 2
	visual.pivot_offset = Vector2(size, size) / 2
	particle.add_child(visual)

	return particle


## Animate all particles outward with fade.
func _animate_particles() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.set_parallel(true)

	for particle in _particles:
		if not is_instance_valid(particle):
			continue

		var angle: float = particle.get_meta("angle", 0.0)
		var target_pos := Vector2(cos(angle), sin(angle)) * SPREAD_RADIUS

		# Animate outward
		_tween.tween_property(particle, "position", target_pos, EFFECT_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

		# Animate scale (grow then shrink)
		_tween.tween_property(particle, "scale", Vector2(1.5, 1.5), EFFECT_DURATION * 0.3)
		_tween.tween_property(particle, "scale", Vector2(0.1, 0.1), EFFECT_DURATION * 0.7).set_delay(EFFECT_DURATION * 0.3)

		# Fade out
		_tween.tween_property(particle, "modulate:a", 0.0, EFFECT_DURATION * 0.5).set_delay(EFFECT_DURATION * 0.5)

	# Queue free when done
	_tween.set_parallel(false)
	_tween.tween_callback(queue_free)
