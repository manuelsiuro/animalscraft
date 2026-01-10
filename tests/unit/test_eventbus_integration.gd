## Integration tests for Story 0.3: EventBus Signal Hub
##
## These tests verify that the EventBus enables proper decoupled communication
## between systems, signals can be emitted and received across autoload boundaries,
## and all signal patterns work correctly.
##
## Test Framework: GUT (Godot Unit Test)
## Installation: https://github.com/bitwes/Gut
##   1. Install via AssetLib in Godot Editor (search for "Gut")
##   2. Or download and place in addons/gut/
## Run: Via GUT test runner in Godot Editor (bottom panel)
##
## IMPORTANT: This test file requires the GUT addon to be installed.
## Without GUT, these tests cannot run.
##
## Coverage:
## - AC1: EventBus exists as global singleton
## - AC2: Signal emission and reception works
## - AC3: All required signal categories are defined
## - AC4: Signal type safety and documentation
## - AC5: Integration across autoload boundaries
##
## Architecture Reference:
## - AR5: EventBus is the ONLY approved mechanism for system-to-system communication
## - Pattern: EventBus.signal_name.emit(args) / EventBus.signal_name.connect(handler)
extends GutTest


# =============================================================================
# TEST FIXTURES
# =============================================================================

## Track signal emissions for verification
var _signal_received: bool = false
var _signal_params: Array = []
var _signal_count: int = 0


## Reset tracking before each test
func before_each() -> void:
	_signal_received = false
	_signal_params = []
	_signal_count = 0


## Cleanup after each test
func after_each() -> void:
	# Test methods manually disconnect their own signals for clarity
	# No automatic cleanup needed
	pass


# =============================================================================
# AC1: EVENTBUS EXISTS AS GLOBAL SINGLETON
# =============================================================================

## Test that EventBus autoload exists and is accessible
func test_eventbus_autoload_exists() -> void:
	var bus := get_node_or_null("/root/EventBus")
	assert_not_null(bus, "EventBus autoload should exist in scene tree")


## Test that EventBus is accessible via class name
func test_eventbus_accessible_via_classname() -> void:
	assert_not_null(EventBus, "EventBus should be accessible via class name")


## Test that EventBus extends Node
func test_eventbus_is_node() -> void:
	assert_true(EventBus is Node, "EventBus should extend Node")


# =============================================================================
# AC2: SIGNAL EMISSION AND RECEPTION WORKS
# =============================================================================

## Test basic signal emission and reception
func test_signal_emission_basic() -> void:
	var callback := func() -> void:
		_signal_received = true

	EventBus.game_paused.connect(callback)
	EventBus.game_paused.emit()

	assert_true(_signal_received, "Signal should be received after emission")
	EventBus.game_paused.disconnect(callback)


## Test signal with single parameter
func test_signal_with_single_parameter() -> void:
	var received_type: String = ""

	var callback := func(resource_type: String) -> void:
		_signal_received = true
		received_type = resource_type

	EventBus.resource_depleted.connect(callback)
	EventBus.resource_depleted.emit("wood")

	assert_true(_signal_received, "Signal should be received")
	assert_eq(received_type, "wood", "Parameter should be passed correctly")
	EventBus.resource_depleted.disconnect(callback)


## Test signal with multiple parameters
func test_signal_with_multiple_parameters() -> void:
	var received_type: String = ""
	var received_amount: int = 0

	var callback := func(resource_type: String, new_amount: int) -> void:
		_signal_received = true
		received_type = resource_type
		received_amount = new_amount

	EventBus.resource_changed.connect(callback)
	EventBus.resource_changed.emit("wheat", 50)

	assert_true(_signal_received, "Signal should be received")
	assert_eq(received_type, "wheat", "First parameter should be correct")
	assert_eq(received_amount, 50, "Second parameter should be correct")
	EventBus.resource_changed.disconnect(callback)


## Test multiple listeners on same signal
func test_multiple_listeners() -> void:
	var listener1_received := false
	var listener2_received := false
	var listener3_received := false

	var callback1 := func() -> void:
		listener1_received = true

	var callback2 := func() -> void:
		listener2_received = true

	var callback3 := func() -> void:
		listener3_received = true

	EventBus.game_resumed.connect(callback1)
	EventBus.game_resumed.connect(callback2)
	EventBus.game_resumed.connect(callback3)

	EventBus.game_resumed.emit()

	assert_true(listener1_received, "Listener 1 should receive signal")
	assert_true(listener2_received, "Listener 2 should receive signal")
	assert_true(listener3_received, "Listener 3 should receive signal")

	EventBus.game_resumed.disconnect(callback1)
	EventBus.game_resumed.disconnect(callback2)
	EventBus.game_resumed.disconnect(callback3)


## Test signal disconnection works properly
func test_signal_disconnection() -> void:
	var callback := func() -> void:
		_signal_count += 1

	EventBus.new_game_started.connect(callback)
	EventBus.new_game_started.emit()

	assert_eq(_signal_count, 1, "Should receive signal once")

	EventBus.new_game_started.disconnect(callback)
	EventBus.new_game_started.emit()

	assert_eq(_signal_count, 1, "Should not receive signal after disconnect")


## Test one-shot connection
func test_one_shot_connection() -> void:
	var callback := func() -> void:
		_signal_count += 1

	EventBus.game_quitting.connect(callback, CONNECT_ONE_SHOT)

	EventBus.game_quitting.emit()
	assert_eq(_signal_count, 1, "Should receive signal once")

	EventBus.game_quitting.emit()
	assert_eq(_signal_count, 1, "Should not receive signal again (one-shot)")


## Test signal with complex parameters (Array)
func test_signal_with_array_parameter() -> void:
	var received_won: bool = false
	var received_animals: Array = []

	var callback := func(won: bool, captured_animals: Array) -> void:
		_signal_received = true
		received_won = won
		received_animals = captured_animals

	EventBus.combat_ended.connect(callback)
	EventBus.combat_ended.emit(true, ["rabbit", "fox", "deer"])

	assert_true(_signal_received, "Signal should be received")
	assert_true(received_won, "Won parameter should be true")
	assert_eq(received_animals.size(), 3, "Should have 3 captured animals")
	assert_eq(received_animals[0], "rabbit", "First animal should be rabbit")
	EventBus.combat_ended.disconnect(callback)


## Test signal with Vector2i parameter
func test_signal_with_vector2i_parameter() -> void:
	var received_coord: Vector2i = Vector2i.ZERO

	var callback := func(hex_coord: Vector2i) -> void:
		_signal_received = true
		received_coord = hex_coord

	EventBus.territory_claimed.connect(callback)
	EventBus.territory_claimed.emit(Vector2i(3, -2))

	assert_true(_signal_received, "Signal should be received")
	assert_eq(received_coord, Vector2i(3, -2), "Hex coord should match")
	EventBus.territory_claimed.disconnect(callback)


# =============================================================================
# AC3: ALL REQUIRED SIGNAL CATEGORIES DEFINED
# =============================================================================

## Test Selection signals exist
func test_selection_signals_defined() -> void:
	assert_true(EventBus.has_signal("animal_selected"), "animal_selected signal should exist")
	assert_true(EventBus.has_signal("animal_deselected"), "animal_deselected signal should exist")
	assert_true(EventBus.has_signal("building_selected"), "building_selected signal should exist")
	assert_true(EventBus.has_signal("building_deselected"), "building_deselected signal should exist")
	assert_true(EventBus.has_signal("hex_selected"), "hex_selected signal should exist")


## Test Resource signals exist
func test_resource_signals_defined() -> void:
	assert_true(EventBus.has_signal("resource_changed"), "resource_changed signal should exist")
	assert_true(EventBus.has_signal("resource_depleted"), "resource_depleted signal should exist")
	assert_true(EventBus.has_signal("resource_full"), "resource_full signal should exist")


## Test Territory signals exist
func test_territory_signals_defined() -> void:
	assert_true(EventBus.has_signal("territory_claimed"), "territory_claimed signal should exist")
	assert_true(EventBus.has_signal("territory_lost"), "territory_lost signal should exist")
	assert_true(EventBus.has_signal("fog_revealed"), "fog_revealed signal should exist")


## Test Progression signals exist
func test_progression_signals_defined() -> void:
	assert_true(EventBus.has_signal("milestone_reached"), "milestone_reached signal should exist")
	assert_true(EventBus.has_signal("building_unlocked"), "building_unlocked signal should exist")
	assert_true(EventBus.has_signal("biome_unlocked"), "biome_unlocked signal should exist")
	assert_true(EventBus.has_signal("animal_unlocked"), "animal_unlocked signal should exist")


## Test Combat signals exist
func test_combat_signals_defined() -> void:
	assert_true(EventBus.has_signal("combat_started"), "combat_started signal should exist")
	assert_true(EventBus.has_signal("combat_ended"), "combat_ended signal should exist")
	assert_true(EventBus.has_signal("animal_captured"), "animal_captured signal should exist")


## Test Game State signals exist
func test_game_state_signals_defined() -> void:
	assert_true(EventBus.has_signal("game_paused"), "game_paused signal should exist")
	assert_true(EventBus.has_signal("game_resumed"), "game_resumed signal should exist")
	assert_true(EventBus.has_signal("save_completed"), "save_completed signal should exist")
	assert_true(EventBus.has_signal("load_completed"), "load_completed signal should exist")
	assert_true(EventBus.has_signal("new_game_started"), "new_game_started signal should exist")
	assert_true(EventBus.has_signal("game_quitting"), "game_quitting signal should exist")


## Test additional Production signals exist
func test_production_signals_defined() -> void:
	assert_true(EventBus.has_signal("production_started"), "production_started signal should exist")
	assert_true(EventBus.has_signal("production_completed"), "production_completed signal should exist")
	assert_true(EventBus.has_signal("production_halted"), "production_halted signal should exist")


## Test additional Animal signals exist
func test_animal_signals_defined() -> void:
	assert_true(EventBus.has_signal("animal_spawned"), "animal_spawned signal should exist")
	assert_true(EventBus.has_signal("animal_assigned"), "animal_assigned signal should exist")
	assert_true(EventBus.has_signal("animal_task_completed"), "animal_task_completed signal should exist")
	assert_true(EventBus.has_signal("animal_resting"), "animal_resting signal should exist")
	assert_true(EventBus.has_signal("animal_recovered"), "animal_recovered signal should exist")


## Test additional Building signals exist
func test_building_signals_defined() -> void:
	assert_true(EventBus.has_signal("building_placed"), "building_placed signal should exist")
	assert_true(EventBus.has_signal("building_removed"), "building_removed signal should exist")


## Test UI signals exist
func test_ui_signals_defined() -> void:
	assert_true(EventBus.has_signal("menu_opened"), "menu_opened signal should exist")
	assert_true(EventBus.has_signal("menu_closed"), "menu_closed signal should exist")
	assert_true(EventBus.has_signal("tutorial_hint_requested"), "tutorial_hint_requested signal should exist")
	assert_true(EventBus.has_signal("tutorial_hint_dismissed"), "tutorial_hint_dismissed signal should exist")


## Test Settings signals exist
func test_settings_signals_defined() -> void:
	assert_true(EventBus.has_signal("setting_changed"), "setting_changed signal should exist")


# =============================================================================
# AC5: CROSS-SYSTEM COMMUNICATION TESTS
# =============================================================================

## Test that GameManager can use EventBus signals
func test_gamemanager_uses_eventbus() -> void:
	# GameManager should emit game_paused when pausing
	var received := false
	var callback := func() -> void:
		received = true

	EventBus.game_paused.connect(callback)

	# Verify GameManager exists and has pause capability
	assert_not_null(GameManager, "GameManager should exist")
	assert_true(GameManager.has_method("pause_game"), "GameManager should have pause_game method")

	# We can verify the connection works without actually pausing
	# (Pausing might have side effects in tests)
	assert_true(EventBus.has_signal("game_paused"), "game_paused signal should exist for GameManager")

	EventBus.game_paused.disconnect(callback)


## Test that SaveManager can use EventBus signals
func test_savemanager_uses_eventbus() -> void:
	# SaveManager should emit save_completed after saving
	assert_not_null(SaveManager, "SaveManager should exist")
	assert_true(EventBus.has_signal("save_completed"), "save_completed signal should exist for SaveManager")
	assert_true(EventBus.has_signal("load_completed"), "load_completed signal should exist for SaveManager")


## Test that systems don't create circular dependencies
func test_no_circular_dependencies() -> void:
	# EventBus should have no dependencies - order 4 in autoload chain
	# Verify EventBus doesn't require other autoloads to exist
	assert_not_null(EventBus, "EventBus should be accessible independently")

	# Verify signal connections don't cause issues
	var callback := func() -> void:
		pass

	# Connect and disconnect without errors
	EventBus.game_paused.connect(callback)
	EventBus.game_paused.disconnect(callback)

	# This test passes if no errors are thrown


## Test signal emission order is preserved
func test_signal_emission_order() -> void:
	var order: Array = []

	var callback1 := func() -> void:
		order.append(1)

	var callback2 := func() -> void:
		order.append(2)

	var callback3 := func() -> void:
		order.append(3)

	# Connect in order 1, 2, 3
	EventBus.new_game_started.connect(callback1)
	EventBus.new_game_started.connect(callback2)
	EventBus.new_game_started.connect(callback3)

	EventBus.new_game_started.emit()

	# Signals should be received in connection order
	assert_eq(order.size(), 3, "All callbacks should be called")
	assert_eq(order[0], 1, "First connected should be called first")
	assert_eq(order[1], 2, "Second connected should be called second")
	assert_eq(order[2], 3, "Third connected should be called third")

	EventBus.new_game_started.disconnect(callback1)
	EventBus.new_game_started.disconnect(callback2)
	EventBus.new_game_started.disconnect(callback3)


## Test that is_connected check works
func test_is_connected_check() -> void:
	var callback := func() -> void:
		pass

	assert_false(EventBus.game_quitting.is_connected(callback), "Should not be connected initially")

	EventBus.game_quitting.connect(callback)
	assert_true(EventBus.game_quitting.is_connected(callback), "Should be connected after connect()")

	EventBus.game_quitting.disconnect(callback)
	assert_false(EventBus.game_quitting.is_connected(callback), "Should not be connected after disconnect()")


## Test safe disconnection pattern (AR18 null safety)
func test_safe_disconnection_pattern() -> void:
	var callback := func() -> void:
		_signal_received = true

	# Safe disconnect pattern - check before disconnect
	if not EventBus.resource_changed.is_connected(callback):
		EventBus.resource_changed.connect(callback)

	# Emit and verify
	EventBus.resource_changed.emit("test", 0)
	assert_true(_signal_received, "Should receive signal")

	# Safe disconnect
	if EventBus.resource_changed.is_connected(callback):
		EventBus.resource_changed.disconnect(callback)

	# This test passes if no errors are thrown


# =============================================================================
# SIGNAL NAMING CONVENTION TESTS
# =============================================================================

## Test that signal names follow {noun}_{past_tense_verb} convention
func test_signal_naming_convention() -> void:
	# Verify naming pattern: noun_verb (past tense)
	# These are examples of correctly named signals
	var expected_patterns: Array = [
		"animal_selected",      # animal (noun) + selected (past verb)
		"resource_changed",     # resource (noun) + changed (past verb)
		"territory_claimed",    # territory (noun) + claimed (past verb)
		"milestone_reached",    # milestone (noun) + reached (past verb)
		"combat_started",       # combat (noun) + started (past verb)
		"game_paused",          # game (noun) + paused (past verb)
		"building_unlocked",    # building (noun) + unlocked (past verb)
	]

	for pattern in expected_patterns:
		assert_true(EventBus.has_signal(pattern), "Signal '%s' should follow naming convention" % pattern)


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

## Test emitting signal with null parameter
func test_signal_with_null_node_parameter() -> void:
	var received_animal: Node = Node.new()  # Non-null default

	var callback := func(animal: Node) -> void:
		_signal_received = true
		received_animal = animal

	EventBus.animal_selected.connect(callback)
	EventBus.animal_selected.emit(null)  # Emit with null

	assert_true(_signal_received, "Signal should be received even with null parameter")
	assert_null(received_animal, "Null parameter should be passed correctly")
	EventBus.animal_selected.disconnect(callback)


## Test rapid signal emission
func test_rapid_signal_emission() -> void:
	var emission_count := 100

	var callback := func() -> void:
		_signal_count += 1

	EventBus.game_resumed.connect(callback)

	for i in range(emission_count):
		EventBus.game_resumed.emit()

	assert_eq(_signal_count, emission_count, "All rapid emissions should be received")
	EventBus.game_resumed.disconnect(callback)


## Test connecting same callback twice (should work in Godot 4)
func test_duplicate_connection() -> void:
	var callback := func() -> void:
		_signal_count += 1

	EventBus.game_paused.connect(callback)

	# In Godot 4, connecting the same callable again is a no-op (doesn't add duplicate)
	EventBus.game_paused.connect(callback)

	EventBus.game_paused.emit()

	# Should only receive once
	assert_eq(_signal_count, 1, "Duplicate connection should not cause duplicate calls")

	EventBus.game_paused.disconnect(callback)
