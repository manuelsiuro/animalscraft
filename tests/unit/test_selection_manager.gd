## Unit tests for SelectionManager.
## Tests single-selection, deselection, EventBus integration, and edge cases.
##
## Architecture: tests/unit/test_selection_manager.gd
## Story: 2-3-implement-animal-selection
extends GutTest

# =============================================================================
# TEST DATA
# =============================================================================

var selection_manager: Node
var animal1: Animal
var animal2: Animal
var mock_hex1: HexCoord
var mock_hex2: HexCoord
var mock_stats: AnimalStats

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Create test hex coordinates (far apart for clear tap detection)
	mock_hex1 = HexCoord.new(0, 0)
	mock_hex2 = HexCoord.new(10, 10)

	# Create shared stats
	mock_stats = AnimalStats.new()
	mock_stats.animal_id = "test_rabbit"
	mock_stats.energy = 3
	mock_stats.speed = 4
	mock_stats.strength = 2
	mock_stats.specialty = "Test"
	mock_stats.biome = "plains"

	# Create SelectionManager (dynamically to avoid autoload conflicts)
	var SelectionManagerScript := preload("res://scripts/systems/selection/selection_manager.gd")
	selection_manager = SelectionManagerScript.new()
	add_child(selection_manager)

	# Create test animals
	var scene := preload("res://scenes/entities/animals/rabbit.tscn")
	animal1 = scene.instantiate() as Animal
	animal2 = scene.instantiate() as Animal
	add_child(animal1)
	add_child(animal2)
	await wait_frames(1)

	# Initialize animals
	animal1.initialize(mock_hex1, mock_stats)
	animal2.initialize(mock_hex2, mock_stats)
	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(selection_manager):
		selection_manager.queue_free()
	if is_instance_valid(animal1):
		animal1.cleanup()
	if is_instance_valid(animal2):
		animal2.cleanup()
	# CRITICAL: Wait for queue_free to complete before next test (GLaDOS review)
	await wait_frames(1)

	selection_manager = null
	animal1 = null
	animal2 = null
	mock_hex1 = null
	mock_hex2 = null
	mock_stats = null

# =============================================================================
# SINGLE SELECTION TESTS (AC3)
# =============================================================================

func test_initially_no_selection() -> void:
	assert_null(selection_manager.get_selected_animal(), "Should have no selection initially")
	assert_false(selection_manager.has_selection(), "has_selection should be false initially")


func test_select_animal_sets_selected() -> void:
	selection_manager.select_animal(animal1)

	assert_eq(selection_manager.get_selected_animal(), animal1, "Should have animal1 selected")


func test_selecting_different_animal_deselects_previous() -> void:
	selection_manager.select_animal(animal1)
	selection_manager.select_animal(animal2)

	var selectable1 := animal1.get_node("SelectableComponent") as SelectableComponent
	var selectable2 := animal2.get_node("SelectableComponent") as SelectableComponent

	assert_false(selectable1.is_selected(), "Animal1 should be deselected")
	assert_true(selectable2.is_selected(), "Animal2 should be selected")
	assert_eq(selection_manager.get_selected_animal(), animal2, "Should have animal2 selected")


func test_only_one_animal_selected_at_time() -> void:
	selection_manager.select_animal(animal1)
	selection_manager.select_animal(animal2)

	assert_true(selection_manager.has_selection(), "Should have selection")
	assert_eq(selection_manager.get_selected_animal(), animal2, "Only animal2 should be selected")


func test_selecting_same_animal_again_no_change() -> void:
	selection_manager.select_animal(animal1)
	watch_signals(EventBus)

	selection_manager.select_animal(animal1)  # Select same again

	# Should not emit deselect/select signals since no change
	assert_signal_not_emitted(EventBus, "animal_deselected")

# =============================================================================
# DESELECTION TESTS (AC4)
# =============================================================================

func test_deselect_current_clears_selection() -> void:
	selection_manager.select_animal(animal1)
	selection_manager.deselect_current()

	assert_null(selection_manager.get_selected_animal(), "Selection should be cleared")
	assert_false(selection_manager.has_selection(), "has_selection should be false")


func test_deselect_when_none_selected_no_error() -> void:
	# Should not crash
	selection_manager.deselect_current()

	assert_false(selection_manager.has_selection(), "Should have no selection")


func test_deselect_updates_selectable_component() -> void:
	selection_manager.select_animal(animal1)
	selection_manager.deselect_current()

	var selectable := animal1.get_node("SelectableComponent") as SelectableComponent
	assert_false(selectable.is_selected(), "Selectable should be deselected")


func test_double_deselect_no_error() -> void:
	selection_manager.select_animal(animal1)
	selection_manager.deselect_current()
	selection_manager.deselect_current()  # Second deselect

	assert_false(selection_manager.has_selection(), "Should have no selection")

# =============================================================================
# EVENTBUS TESTS (AC6)
# =============================================================================

func test_animal_selected_signal_emitted() -> void:
	watch_signals(EventBus)

	selection_manager.select_animal(animal1)

	assert_signal_emitted(EventBus, "animal_selected")


func test_animal_selected_signal_contains_animal() -> void:
	watch_signals(EventBus)

	selection_manager.select_animal(animal1)

	var params: Array = get_signal_parameters(EventBus, "animal_selected")
	assert_eq(params[0], animal1, "Signal should contain selected animal")


func test_animal_deselected_signal_emitted() -> void:
	selection_manager.select_animal(animal1)
	watch_signals(EventBus)

	selection_manager.deselect_current()

	assert_signal_emitted(EventBus, "animal_deselected")


func test_switching_animals_emits_both_signals() -> void:
	selection_manager.select_animal(animal1)
	watch_signals(EventBus)

	selection_manager.select_animal(animal2)

	assert_signal_emitted(EventBus, "animal_deselected")
	assert_signal_emitted(EventBus, "animal_selected")


func test_switching_animals_signal_order() -> void:
	# Deselect should come before select when switching
	selection_manager.select_animal(animal1)

	var signal_order: Array = []
	EventBus.animal_deselected.connect(func(): signal_order.append("deselect"))
	EventBus.animal_selected.connect(func(_a): signal_order.append("select"))

	selection_manager.select_animal(animal2)

	assert_eq(signal_order, ["deselect", "select"], "Deselect should emit before select")

# =============================================================================
# QUERY TESTS (AC7)
# =============================================================================

func test_has_selection_true_when_selected() -> void:
	selection_manager.select_animal(animal1)

	assert_true(selection_manager.has_selection(), "has_selection should be true")


func test_has_selection_false_when_none() -> void:
	assert_false(selection_manager.has_selection(), "has_selection should be false")


func test_get_selected_animal_returns_correct_animal() -> void:
	selection_manager.select_animal(animal1)

	assert_eq(selection_manager.get_selected_animal(), animal1, "Should return correct animal")


func test_get_selected_animal_returns_null_when_none() -> void:
	assert_null(selection_manager.get_selected_animal(), "Should return null when none selected")

# =============================================================================
# NULL SAFETY TESTS (GLaDOS Edge Cases)
# =============================================================================

func test_select_animal_then_free_and_deselect_no_crash() -> void:
	# Select an animal, then free it, then try operations
	var temp_animal := preload("res://scenes/entities/animals/rabbit.tscn").instantiate() as Animal
	add_child(temp_animal)
	await wait_frames(1)
	temp_animal.initialize(HexCoord.new(5, 5), mock_stats)
	await wait_frames(1)

	# Select it first
	selection_manager.select_animal(temp_animal)
	assert_true(selection_manager.has_selection(), "Should have selection")

	# Free the selected animal
	temp_animal.cleanup()
	await wait_frames(1)

	# Try to deselect - should not crash even though animal is freed
	selection_manager.deselect_current()

	# Selection should be cleared
	assert_false(selection_manager.has_selection(), "Should have no selection after cleanup")


func test_deselect_after_animal_freed_no_crash() -> void:
	selection_manager.select_animal(animal1)

	# Free the selected animal
	animal1.cleanup()
	await wait_frames(1)

	# Try to deselect - should not crash even though animal is freed
	selection_manager.deselect_current()

	# Should have no selection after deselect
	assert_false(selection_manager.has_selection(), "Should have no selection after deselect")

# =============================================================================
# CANCEL TAP TESTS
# =============================================================================

func test_cancel_tap_clears_potential_tap() -> void:
	# Start a potential tap
	selection_manager._tap_start_time = Time.get_ticks_msec()
	selection_manager._tap_start_position = Vector2(100, 100)
	selection_manager._is_potential_tap = true

	selection_manager.cancel_tap()

	assert_false(selection_manager._is_potential_tap, "Potential tap should be cancelled")

# =============================================================================
# COMPONENT SIGNAL TESTS
# =============================================================================

func test_selectable_tapped_signal_called_on_select() -> void:
	var selectable := animal1.get_node("SelectableComponent") as SelectableComponent
	watch_signals(selectable)

	selection_manager.select_animal(animal1)

	assert_signal_emitted(selectable, "tapped")


func test_selectable_selection_changed_signal_on_select() -> void:
	var selectable := animal1.get_node("SelectableComponent") as SelectableComponent
	watch_signals(selectable)

	selection_manager.select_animal(animal1)

	assert_signal_emitted(selectable, "selection_changed")


func test_selectable_selection_changed_signal_on_deselect() -> void:
	selection_manager.select_animal(animal1)

	var selectable := animal1.get_node("SelectableComponent") as SelectableComponent
	watch_signals(selectable)

	selection_manager.deselect_current()

	assert_signal_emitted(selectable, "selection_changed")
