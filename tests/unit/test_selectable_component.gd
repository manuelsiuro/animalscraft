## Unit tests for SelectableComponent.
## Tests tap detection, selection state, signal emission, and position detection.
##
## Architecture: tests/unit/test_selectable_component.gd
## Story: 2-3-implement-animal-selection
extends GutTest

# =============================================================================
# TEST DATA
# =============================================================================

var selectable: SelectableComponent
var mock_entity: Node3D

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Create mock entity (Node3D parent)
	mock_entity = Node3D.new()
	mock_entity.name = "MockAnimal"
	mock_entity.global_position = Vector3(10, 0, 10)
	add_child(mock_entity)

	# Create SelectableComponent as child
	selectable = SelectableComponent.new()
	mock_entity.add_child(selectable)
	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(mock_entity):
		mock_entity.queue_free()
	# CRITICAL: Wait for queue_free to complete before next test (GLaDOS review)
	await wait_frames(1)
	mock_entity = null
	selectable = null

# =============================================================================
# SELECTION STATE TESTS (AC7)
# =============================================================================

func test_initially_not_selected() -> void:
	assert_false(selectable.is_selected(), "Should not be selected initially")


func test_select_changes_state() -> void:
	selectable.select()

	assert_true(selectable.is_selected(), "Should be selected after select()")


func test_deselect_changes_state() -> void:
	selectable.select()
	selectable.deselect()

	assert_false(selectable.is_selected(), "Should not be selected after deselect()")


func test_double_select_no_effect() -> void:
	selectable.select()
	watch_signals(selectable)

	selectable.select()  # Second select

	assert_signal_not_emitted(selectable, "selection_changed")


func test_double_deselect_no_effect() -> void:
	watch_signals(selectable)

	selectable.deselect()  # Already deselected

	assert_signal_not_emitted(selectable, "selection_changed")


func test_select_deselect_cycle() -> void:
	selectable.select()
	assert_true(selectable.is_selected(), "Should be selected")

	selectable.deselect()
	assert_false(selectable.is_selected(), "Should be deselected")

	selectable.select()
	assert_true(selectable.is_selected(), "Should be selected again")

# =============================================================================
# SIGNAL EMISSION TESTS (AC1, AC2)
# =============================================================================

func test_select_emits_signal() -> void:
	watch_signals(selectable)

	selectable.select()

	assert_signal_emitted(selectable, "selection_changed")


func test_select_signal_has_true_parameter() -> void:
	watch_signals(selectable)

	selectable.select()

	var params: Array = get_signal_parameters(selectable, "selection_changed")
	assert_true(params[0], "Signal should emit true for selection")


func test_deselect_emits_signal() -> void:
	selectable.select()
	watch_signals(selectable)

	selectable.deselect()

	assert_signal_emitted(selectable, "selection_changed")


func test_deselect_signal_has_false_parameter() -> void:
	selectable.select()
	watch_signals(selectable)

	selectable.deselect()

	var params: Array = get_signal_parameters(selectable, "selection_changed")
	assert_false(params[0], "Signal should emit false for deselection")


func test_tapped_signal_emitted() -> void:
	watch_signals(selectable)

	selectable.handle_tap()

	assert_signal_emitted(selectable, "tapped")


func test_tapped_signal_emitted_multiple_times() -> void:
	watch_signals(selectable)

	selectable.handle_tap()
	selectable.handle_tap()
	selectable.handle_tap()

	assert_signal_emit_count(selectable, "tapped", 3)

# =============================================================================
# POSITION DETECTION TESTS (AC1)
# =============================================================================

func test_position_in_range_detects_close_tap() -> void:
	mock_entity.global_position = Vector3(10, 0, 10)
	# Very close position (within default radius)
	var close_pos := Vector3(10.2, 0, 10.2)

	assert_true(selectable.is_position_in_range(close_pos), "Should detect close tap")


func test_position_in_range_rejects_far_tap() -> void:
	mock_entity.global_position = Vector3(10, 0, 10)
	# Far position
	var far_pos := Vector3(100, 0, 100)

	assert_false(selectable.is_position_in_range(far_pos), "Should reject far tap")


func test_position_in_range_ignores_y_coordinate() -> void:
	mock_entity.global_position = Vector3(10, 0, 10)
	# Same XZ but different Y
	var elevated_pos := Vector3(10.2, 50, 10.2)

	assert_true(selectable.is_position_in_range(elevated_pos), "Should ignore Y coordinate")


func test_position_in_range_exact_boundary() -> void:
	mock_entity.global_position = Vector3(0, 0, 0)
	# Position at exact boundary (radius = 32 / 64 = 0.5 world units)
	var boundary_pos := Vector3(0.5, 0, 0)

	assert_true(selectable.is_position_in_range(boundary_pos), "Should include boundary position")


func test_position_in_range_just_outside_boundary() -> void:
	mock_entity.global_position = Vector3(0, 0, 0)
	# Position just beyond boundary
	var beyond_pos := Vector3(0.6, 0, 0)

	assert_false(selectable.is_position_in_range(beyond_pos), "Should exclude position beyond boundary")


func test_position_in_range_returns_false_without_entity() -> void:
	# Create orphan selectable (no parent entity)
	var orphan := SelectableComponent.new()
	add_child(orphan)
	await wait_frames(1)

	assert_false(orphan.is_position_in_range(Vector3.ZERO), "Should return false without entity")

	orphan.queue_free()
	await wait_frames(1)

# =============================================================================
# GET ENTITY TESTS
# =============================================================================

func test_get_entity_returns_parent() -> void:
	var entity := selectable.get_entity()

	assert_eq(entity, mock_entity, "Should return parent entity")


func test_get_entity_returns_node3d() -> void:
	var entity := selectable.get_entity()

	assert_true(entity is Node3D, "Entity should be Node3D")

# =============================================================================
# COLLISION AREA TESTS
# =============================================================================

func test_collision_area_created() -> void:
	var area := selectable.get_node_or_null("SelectionArea")

	assert_not_null(area, "SelectionArea should be created")
	assert_true(area is Area3D, "SelectionArea should be Area3D")


func test_collision_area_has_shape() -> void:
	var area := selectable.get_node_or_null("SelectionArea") as Area3D
	var children := area.get_children()

	assert_gt(children.size(), 0, "SelectionArea should have collision shape")
	assert_true(children[0] is CollisionShape3D, "Child should be CollisionShape3D")


func test_collision_area_shape_is_sphere() -> void:
	var area := selectable.get_node_or_null("SelectionArea") as Area3D
	var shape_node := area.get_child(0) as CollisionShape3D

	assert_true(shape_node.shape is SphereShape3D, "Shape should be SphereShape3D")


func test_collision_layer_set_correctly() -> void:
	var area := selectable.get_node_or_null("SelectionArea") as Area3D

	assert_eq(area.collision_layer, 0, "Collision layer should be 0")
	assert_eq(area.collision_mask, 0, "Collision mask should be 0")

# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_select_while_entity_invalid_no_crash() -> void:
	# Remove parent reference
	selectable._entity = null

	# Should not crash
	selectable.select()

	assert_true(selectable.is_selected(), "Should still change state")


func test_deselect_while_entity_invalid_no_crash() -> void:
	selectable.select()
	selectable._entity = null

	# Should not crash
	selectable.deselect()

	assert_false(selectable.is_selected(), "Should still change state")
