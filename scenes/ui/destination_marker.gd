## DestinationMarker - Visual indicator for animal destination.
## Shows a pulsing ring at the target hex location.
## Automatically pulses to draw attention to the destination.
##
## Architecture: scenes/ui/destination_marker.gd
## Story: 2-7-implement-tap-to-assign-workflow
class_name DestinationMarker
extends Node3D

# =============================================================================
# CONSTANTS
# =============================================================================

## Pulse animation duration (seconds per cycle)
const PULSE_DURATION: float = 0.8

## Minimum scale during pulse
const PULSE_SCALE_MIN: float = 0.9

## Maximum scale during pulse
const PULSE_SCALE_MAX: float = 1.15

## Ring color (golden yellow to match selection highlight)
const RING_COLOR: Color = Color(1.0, 0.8, 0.2, 0.9)

## Ring emission energy
const EMISSION_ENERGY: float = 1.5

# =============================================================================
# STATE
# =============================================================================

## Active tween for pulse animation
var _tween: Tween = null

## The ring mesh instance
var _ring: MeshInstance3D = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	_create_visual()
	_start_pulse_animation()


func _create_visual() -> void:
	# Create ring mesh instance
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"

	# Create torus mesh (ring shape)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.75
	torus.rings = 16
	torus.ring_segments = 24
	_ring.mesh = torus

	# Create emissive material for visibility
	var material := StandardMaterial3D.new()
	material.albedo_color = RING_COLOR
	material.emission_enabled = true
	material.emission = RING_COLOR
	material.emission_energy_multiplier = EMISSION_ENERGY
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring.material_override = material

	# Rotate to lay flat on ground plane
	_ring.rotation_degrees.x = -90

	add_child(_ring)


func _start_pulse_animation() -> void:
	# Kill existing tween if running
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.set_loops()  # Infinite loop
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)

	# Scale up
	_tween.tween_property(
		self,
		"scale",
		Vector3(PULSE_SCALE_MAX, 1.0, PULSE_SCALE_MAX),
		PULSE_DURATION / 2.0
	)

	# Scale down
	_tween.tween_property(
		self,
		"scale",
		Vector3(PULSE_SCALE_MIN, 1.0, PULSE_SCALE_MIN),
		PULSE_DURATION / 2.0
	)

# =============================================================================
# PUBLIC API
# =============================================================================

## Clean up resources before removal.
## Stops animation and queues for deletion.
func cleanup() -> void:
	# Stop tween
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = null

	queue_free()
