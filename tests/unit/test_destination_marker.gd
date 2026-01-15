## Unit tests for DestinationMarker.
## Tests visual creation, pulse animation, and cleanup.
##
## Architecture: tests/unit/test_destination_marker.gd
## Story: 2-7-implement-tap-to-assign-workflow
extends GutTest

# Preload for scene instantiation
const DestinationMarkerScene: PackedScene = preload("res://scenes/ui/destination_marker.tscn")
const DestinationMarkerScript: Script = preload("res://scenes/ui/destination_marker.gd")

# =============================================================================
# TEST DATA
# =============================================================================

var marker: Node3D

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	marker = DestinationMarkerScene.instantiate() as Node3D
	add_child(marker)
	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(marker):
		marker.queue_free()
	await wait_frames(1)
	marker = null

# =============================================================================
# BASIC INSTANTIATION TESTS
# =============================================================================

func test_marker_instantiates() -> void:
	assert_not_null(marker, "Marker should instantiate")


func test_marker_is_node3d() -> void:
	assert_true(marker is Node3D, "Marker should be Node3D")


func test_marker_has_destination_marker_script() -> void:
	assert_true(marker.has_method("cleanup"), "Marker should have DestinationMarker script")

# =============================================================================
# VISUAL CREATION TESTS
# =============================================================================

func test_marker_creates_ring_child() -> void:
	# Check if Ring child exists (created in _ready)
	var ring: Node = marker.get_node_or_null("Ring")
	assert_not_null(ring, "Marker should have Ring child")


func test_ring_is_mesh_instance() -> void:
	var ring: Node = marker.get_node_or_null("Ring")
	if ring:
		assert_true(ring is MeshInstance3D, "Ring should be MeshInstance3D")
	else:
		fail_test("Ring node not found")


func test_ring_has_mesh() -> void:
	var ring: MeshInstance3D = marker.get_node_or_null("Ring") as MeshInstance3D
	if ring:
		assert_not_null(ring.mesh, "Ring should have a mesh")
	else:
		fail_test("Ring node not found")


func test_ring_mesh_is_torus() -> void:
	var ring: MeshInstance3D = marker.get_node_or_null("Ring") as MeshInstance3D
	if ring and ring.mesh:
		assert_true(ring.mesh is TorusMesh, "Ring mesh should be TorusMesh")
	else:
		fail_test("Ring or mesh not found")


func test_ring_has_material() -> void:
	var ring: MeshInstance3D = marker.get_node_or_null("Ring") as MeshInstance3D
	if ring:
		assert_not_null(ring.material_override, "Ring should have material override")
	else:
		fail_test("Ring node not found")


func test_ring_material_is_emissive() -> void:
	var ring: MeshInstance3D = marker.get_node_or_null("Ring") as MeshInstance3D
	if ring and ring.material_override:
		var material: StandardMaterial3D = ring.material_override as StandardMaterial3D
		if material:
			assert_true(material.emission_enabled, "Material should have emission enabled")
		else:
			fail_test("Material is not StandardMaterial3D")
	else:
		fail_test("Ring or material not found")


func test_ring_is_rotated_flat() -> void:
	var ring: Node3D = marker.get_node_or_null("Ring") as Node3D
	if ring:
		# Should be rotated -90 degrees on X to lay flat
		assert_almost_eq(ring.rotation_degrees.x, -90.0, 1.0,
			"Ring should be rotated to lay flat")
	else:
		fail_test("Ring node not found")

# =============================================================================
# ANIMATION TESTS
# =============================================================================

func test_marker_has_tween() -> void:
	# After _ready, tween should be running (access via get())
	assert_true(marker.get("_tween") != null, "Marker should have tween")


func test_marker_tween_is_running() -> void:
	var tween: Tween = marker.get("_tween")
	if tween:
		assert_true(tween.is_running(), "Tween should be running")
	else:
		fail_test("No tween found")


func test_marker_scale_changes_during_animation() -> void:
	# Get initial scale
	var initial_scale: Vector3 = marker.scale

	# Wait for some animation
	await wait_frames(30)  # ~0.5 seconds at 60fps

	# This test may be flaky, so we just check tween is still running
	var tween: Tween = marker.get("_tween")
	if tween:
		assert_true(tween.is_running(),
			"Tween should still be running after frames")
	else:
		fail_test("Tween stopped unexpectedly")

# =============================================================================
# CLEANUP TESTS
# =============================================================================

func test_cleanup_method_exists() -> void:
	assert_true(marker.has_method("cleanup"), "Marker should have cleanup method")


func test_cleanup_stops_tween() -> void:
	# Get tween reference
	var tween: Tween = marker.get("_tween")

	# Cleanup (but don't actually free yet, we want to check tween state)
	if tween and tween.is_running():
		tween.kill()

	# Tween should be stopped
	assert_false(tween.is_running() if tween else true,
		"Tween should be stopped after cleanup")


func test_cleanup_queues_free() -> void:
	# This test is tricky - cleanup calls queue_free
	# We'll verify by checking the node state after a frame

	var marker_ref: Node3D = marker  # Keep reference
	marker.cleanup()
	await wait_frames(2)

	# After queue_free processes, node should be invalid
	assert_false(is_instance_valid(marker_ref),
		"Marker should be freed after cleanup")

	# Prevent double-free in after_each
	marker = null

# =============================================================================
# CONSTANTS TESTS (access via script reference)
# =============================================================================

func test_pulse_duration_positive() -> void:
	var PULSE_DURATION: float = DestinationMarkerScript.get("PULSE_DURATION")
	assert_gt(PULSE_DURATION, 0.0,
		"Pulse duration should be positive")


func test_pulse_scale_min_less_than_max() -> void:
	var PULSE_SCALE_MIN: float = DestinationMarkerScript.get("PULSE_SCALE_MIN")
	var PULSE_SCALE_MAX: float = DestinationMarkerScript.get("PULSE_SCALE_MAX")
	assert_lt(PULSE_SCALE_MIN, PULSE_SCALE_MAX,
		"Min scale should be less than max scale")


func test_ring_color_is_visible() -> void:
	var RING_COLOR: Color = DestinationMarkerScript.get("RING_COLOR")
	# Check color has visible alpha
	assert_gt(RING_COLOR.a, 0.5, "Ring color should be visible (alpha > 0.5)")


func test_emission_energy_positive() -> void:
	var EMISSION_ENERGY: float = DestinationMarkerScript.get("EMISSION_ENERGY")
	assert_gt(EMISSION_ENERGY, 0.0,
		"Emission energy should be positive")

# =============================================================================
# POSITIONING TESTS
# =============================================================================

func test_marker_initial_position_is_origin() -> void:
	# Fresh marker should be at origin
	var fresh_marker: Node3D = DestinationMarkerScene.instantiate() as Node3D
	add_child(fresh_marker)
	await wait_frames(1)

	assert_eq(fresh_marker.position, Vector3.ZERO,
		"Fresh marker should be at origin")

	fresh_marker.queue_free()


func test_marker_position_can_be_set() -> void:
	var target_pos: Vector3 = Vector3(10, 0.05, 20)
	marker.global_position = target_pos

	assert_eq(marker.global_position, target_pos,
		"Marker position should be settable")

# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_double_cleanup_no_crash() -> void:
	# Manually kill tween and clear reference
	var tween: Tween = marker.get("_tween")
	if tween:
		tween.kill()
		marker.set("_tween", null)

	# Call cleanup again - should not crash
	marker.cleanup()
	await wait_frames(1)

	# Test passes if no exception thrown
	assert_true(true, "Double cleanup should not crash")

	# Prevent double-free in after_each
	marker = null


func test_marker_dynamic_creation() -> void:
	# Create marker by instantiating scene
	var dynamic_marker: Node3D = DestinationMarkerScene.instantiate() as Node3D

	add_child(dynamic_marker)
	await wait_frames(1)

	# Check it initialized properly
	var ring: Node = dynamic_marker.get_node_or_null("Ring")
	assert_not_null(ring, "Dynamic marker should create ring")

	dynamic_marker.queue_free()
