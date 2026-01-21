## Unit tests for CombatManager auto-battle system.
## Tests combat initiation, turn order, formulas, victory/defeat, and battle log.
##
## Story: 5-5-implement-auto-battle-system
extends GutTest

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _combat_manager: CombatManager
var _mock_world_manager: Node3D
var _mock_territory_manager: Node
var _mock_wild_herd_manager: Node
var _mock_animals: Array[Node]
var _mock_enemy_animals: Array[Node]

func before_each() -> void:
	# Create mock world manager with script so properties work
	_mock_world_manager = Node3D.new()
	_mock_world_manager.name = "MockWorldManager"
	var world_script := GDScript.new()
	world_script.source_code = """
extends Node3D
var _territory_manager: Node
var _wild_herd_manager: Node
"""
	world_script.reload()
	_mock_world_manager.set_script(world_script)
	add_child(_mock_world_manager)

	# Create mock territory manager
	_mock_territory_manager = _create_mock_territory_manager()
	_mock_world_manager.add_child(_mock_territory_manager)
	_mock_world_manager._territory_manager = _mock_territory_manager

	# Create mock wild herd manager
	_mock_wild_herd_manager = _create_mock_wild_herd_manager()
	_mock_wild_herd_manager.add_to_group("wild_herd_managers")
	_mock_world_manager.add_child(_mock_wild_herd_manager)
	_mock_world_manager._wild_herd_manager = _mock_wild_herd_manager

	# Create combat manager
	_combat_manager = CombatManager.new()
	add_child(_combat_manager)
	await wait_frames(1)

	# Initialize combat manager with mock world manager
	_combat_manager.initialize(_mock_world_manager)

	# Create mock animals
	_mock_animals = []
	_mock_enemy_animals = []


func after_each() -> void:
	# Clean up mock animals
	for animal in _mock_animals:
		if is_instance_valid(animal):
			animal.queue_free()
	_mock_animals.clear()

	for animal in _mock_enemy_animals:
		if is_instance_valid(animal):
			animal.queue_free()
	_mock_enemy_animals.clear()

	# Clean up
	if is_instance_valid(_combat_manager):
		_combat_manager.queue_free()
	if is_instance_valid(_mock_world_manager):
		_mock_world_manager.queue_free()


# =============================================================================
# MOCK CREATION HELPERS
# =============================================================================

func _create_mock_animal(strength: int = 5, animal_id: String = "test_animal") -> Node:
	var animal := Node.new()
	animal.name = "MockAnimal_" + animal_id

	# Create mock stats
	var mock_stats = RefCounted.new()
	mock_stats.set_meta("strength", strength)
	mock_stats.set_meta("animal_id", animal_id)

	# Add stats wrapper class dynamically
	var stats_script := GDScript.new()
	stats_script.source_code = """
extends RefCounted
var strength: int = %d
var animal_id: String = \"%s\"
""" % [strength, animal_id]
	stats_script.reload()
	var stats_obj = stats_script.new()

	animal.set("stats", stats_obj)

	# Add get_animal_id method
	var animal_script := GDScript.new()
	animal_script.source_code = """
extends Node
var stats: RefCounted
var _ai: Node

func get_animal_id() -> String:
	if stats:
		return stats.animal_id
	return \"unknown\"

func _get_ai_component() -> Node:
	return _ai
"""
	animal_script.reload()
	animal.set_script(animal_script)
	animal.stats = stats_obj

	# Create mock AIComponent
	var ai_component := Node.new()
	ai_component.name = "AIComponent"
	var ai_script := GDScript.new()
	ai_script.source_code = """
extends Node
var last_state: int = -1

func transition_to(state: int) -> void:
	last_state = state
"""
	ai_script.reload()
	ai_component.set_script(ai_script)
	animal.add_child(ai_component)
	animal._ai = ai_component

	add_child(animal)
	return animal


func _create_mock_territory_manager() -> Node:
	var manager := Node.new()
	manager.name = "MockTerritoryManager"

	var script := GDScript.new()
	script.source_code = """
extends Node
var claimed_hexes: Array = []
var last_claim_source: String = \"\"

func set_hex_owner(hex: RefCounted, owner_id: String, source: String) -> void:
	claimed_hexes.append({\"hex\": hex, \"owner\": owner_id, \"source\": source})
	last_claim_source = source
"""
	script.reload()
	manager.set_script(script)

	return manager


func _create_mock_wild_herd_manager() -> Node:
	var manager := Node.new()
	manager.name = "MockWildHerdManager"

	var script := GDScript.new()
	script.source_code = """
extends Node

class WildHerd:
	var herd_id: String
	var animals: Array = []
	var hex_coord = null

	func _init(p_id: String, p_animals: Array):
		herd_id = p_id
		animals = p_animals

var _herds: Dictionary = {}
var removed_herds: Array = []

func get_herd(herd_id: String):
	return _herds.get(herd_id)

func add_test_herd(herd_id: String, animals: Array) -> void:
	var herd = WildHerd.new(herd_id, animals)
	_herds[herd_id] = herd

func remove_herd(herd_id: String) -> void:
	removed_herds.append(herd_id)
	_herds.erase(herd_id)
"""
	script.reload()
	manager.set_script(script)

	return manager


func _setup_basic_combat(player_strength: int = 10, enemy_strength: int = 5) -> Array:
	# Create player team (3 animals)
	var player_team: Array = []
	for i in 3:
		var animal := _create_mock_animal(player_strength, "player_%d" % i)
		player_team.append(animal)
		_mock_animals.append(animal)

	# Create enemy team (2 animals)
	var enemy_team: Array = []
	for i in 2:
		var animal := _create_mock_animal(enemy_strength, "enemy_%d" % i)
		enemy_team.append(animal)
		_mock_enemy_animals.append(animal)

	# Register enemy herd
	_mock_wild_herd_manager.add_test_herd("test_herd", enemy_team)

	return player_team


# =============================================================================
# COMBAT INITIATION TESTS (AC1, AC2, AC21, AC22, AC23)
# =============================================================================

func test_combat_starts_when_combat_team_selected_emitted() -> void:
	# AC1: Combat starts when combat_team_selected signal emitted
	var player_team := _setup_basic_combat()

	watch_signals(EventBus)

	# Emit the signal
	EventBus.combat_team_selected.emit(player_team, Vector2i(1, 1), "test_herd")

	# Wait for combat to start
	await wait_frames(2)

	# Verify combat started
	assert_signal_emitted(EventBus, "combat_started")


func test_combat_started_signal_emitted_at_battle_start() -> void:
	# AC2: combat_started signal emitted at battle start
	var player_team := _setup_basic_combat()

	watch_signals(EventBus)

	_combat_manager.start_combat(player_team, Vector2i(2, 2), "test_herd")

	await wait_frames(2)

	assert_signal_emitted_with_parameters(EventBus, "combat_started", [Vector2i(2, 2)])


func test_is_combat_active_returns_true_during_combat() -> void:
	# AC21: is_combat_active returns true during combat
	var player_team := _setup_basic_combat()

	assert_false(_combat_manager.is_combat_active())

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	await wait_frames(2)

	assert_true(_combat_manager.is_combat_active())


func test_is_combat_active_returns_false_when_not_in_combat() -> void:
	# AC22: is_combat_active returns false when not in combat
	assert_false(_combat_manager.is_combat_active())


func test_second_combat_rejected_while_one_is_active() -> void:
	# AC23: Second combat rejected while one is active
	var player_team := _setup_basic_combat()

	# Create second enemy herd
	var enemy_team2: Array = []
	for i in 2:
		var animal := _create_mock_animal(5, "enemy2_%d" % i)
		enemy_team2.append(animal)
		_mock_enemy_animals.append(animal)
	_mock_wild_herd_manager.add_test_herd("test_herd_2", enemy_team2)

	# Start first combat
	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")
	await wait_frames(2)

	var is_active_before := _combat_manager.is_combat_active()

	# Try to start second combat
	_combat_manager.start_combat(player_team, Vector2i(2, 2), "test_herd_2")
	await wait_frames(2)

	# Should still be on first combat
	assert_true(is_active_before)
	assert_eq(_combat_manager.get_current_hex(), Vector2i(1, 1))


# =============================================================================
# TURN ORDER TESTS (AC3, AC4, AC10)
# =============================================================================

func test_turn_queue_alternates_player_and_enemy() -> void:
	# AC3: Turn queue alternates player and enemy
	var player_units: Array[CombatManager.CombatUnit] = []
	var enemy_units: Array[CombatManager.CombatUnit] = []

	# Create player units
	for i in 3:
		var animal := _create_mock_animal(5, "p%d" % i)
		_mock_animals.append(animal)
		var unit = CombatManager.CombatUnit.new(animal, true)
		player_units.append(unit)

	# Create enemy units
	for i in 2:
		var animal := _create_mock_animal(5, "e%d" % i)
		_mock_enemy_animals.append(animal)
		var unit = CombatManager.CombatUnit.new(animal, false)
		enemy_units.append(unit)

	# Build turn queue
	_combat_manager._build_turn_queue(player_units, enemy_units)

	# Expected order: p0, e0, p1, e1, p2
	assert_eq(_combat_manager._turn_queue.size(), 5)

	# Check alternating pattern
	assert_true(_combat_manager._turn_queue[0].is_player_team)  # p0
	assert_false(_combat_manager._turn_queue[1].is_player_team) # e0
	assert_true(_combat_manager._turn_queue[2].is_player_team)  # p1
	assert_false(_combat_manager._turn_queue[3].is_player_team) # e1
	assert_true(_combat_manager._turn_queue[4].is_player_team)  # p2


func test_knocked_out_animals_skipped_in_turn_order() -> void:
	# AC10: Knocked out animals are skipped in turn order
	var player_units: Array[CombatManager.CombatUnit] = []
	var enemy_units: Array[CombatManager.CombatUnit] = []

	# Create player units
	for i in 2:
		var animal := _create_mock_animal(5, "p%d" % i)
		_mock_animals.append(animal)
		var unit = CombatManager.CombatUnit.new(animal, true)
		player_units.append(unit)

	# Create one enemy unit
	var enemy_animal := _create_mock_animal(5, "e0")
	_mock_enemy_animals.append(enemy_animal)
	var enemy_unit = CombatManager.CombatUnit.new(enemy_animal, false)
	enemy_units.append(enemy_unit)

	# Build turn queue
	_combat_manager._build_turn_queue(player_units, enemy_units)

	# Knock out first player unit
	player_units[0].take_damage(player_units[0].max_hp)
	assert_true(player_units[0].is_knocked_out)

	# Get next attacker should skip knocked out unit
	var next := _combat_manager._get_next_attacker()
	assert_not_null(next)
	assert_true(next.is_alive())
	# Should not be the knocked out unit
	assert_ne(next.unit_id, "p0")


func test_get_random_living_target_returns_valid_target() -> void:
	# AC4: Target selection returns random living enemy
	# Create attacker (player)
	var attacker_animal := _create_mock_animal(5, "attacker")
	_mock_animals.append(attacker_animal)
	var attacker = CombatManager.CombatUnit.new(attacker_animal, true)

	# Create enemy units
	_combat_manager._enemy_team.clear()
	for i in 3:
		var animal := _create_mock_animal(5, "target_%d" % i)
		_mock_enemy_animals.append(animal)
		var unit = CombatManager.CombatUnit.new(animal, false)
		_combat_manager._enemy_team.append(unit)

	# Get target
	var target := _combat_manager._get_random_living_target(attacker)

	assert_not_null(target)
	assert_false(target.is_player_team)
	assert_true(target.is_alive())


# =============================================================================
# COMBAT FORMULA TESTS (AC5, AC6, AC7, AC8)
# =============================================================================

func test_attack_formula_produces_expected_damage_range() -> void:
	# AC5: Attack formula: strength + random(0, strength * 0.2)
	var animal := _create_mock_animal(10, "attacker")
	_mock_animals.append(animal)
	var unit = CombatManager.CombatUnit.new(animal, true)

	# Run multiple times to test range
	var min_attack := INF
	var max_attack := 0.0

	for i in 100:
		var attack := _combat_manager._calculate_attack_power(unit)
		min_attack = minf(min_attack, attack)
		max_attack = maxf(max_attack, attack)

	# Strength is 10, variance is 0-20%
	# Expected range: 10.0 to 12.0
	assert_gte(min_attack, 10.0)
	assert_lte(max_attack, 12.0)


func test_defense_formula_reduces_damage_correctly() -> void:
	# AC6: Defense formula: strength * 0.7
	var animal := _create_mock_animal(10, "defender")
	_mock_animals.append(animal)
	var unit = CombatManager.CombatUnit.new(animal, true)

	var defense := _combat_manager._calculate_defense_power(unit)

	# 10 * 0.7 = 7.0
	assert_almost_eq(defense, 7.0, 0.01)


func test_minimum_1_damage_per_attack() -> void:
	# AC7: Minimum 1 damage per attack
	var damage := _combat_manager._calculate_damage(1.0, 100.0)  # Attack much lower than defense
	assert_eq(damage, 1)

	damage = _combat_manager._calculate_damage(5.0, 5.0)  # Equal attack and defense
	assert_eq(damage, 1)


func test_hp_initialization_is_strength_times_3() -> void:
	# AC8: HP = strength * 3
	var animal := _create_mock_animal(7, "test")
	_mock_animals.append(animal)
	var unit = CombatManager.CombatUnit.new(animal, true)

	# 7 * 3 = 21
	assert_eq(unit.max_hp, 21)
	assert_eq(unit.current_hp, 21)


# =============================================================================
# COMBAT UNIT TESTS (AC8, AC9, AC10)
# =============================================================================

func test_combat_unit_take_damage_reduces_hp() -> void:
	var animal := _create_mock_animal(5, "test")
	_mock_animals.append(animal)
	var unit = CombatManager.CombatUnit.new(animal, true)

	var initial_hp: int = unit.current_hp
	unit.take_damage(5)

	assert_eq(unit.current_hp, initial_hp - 5)


func test_combat_unit_knocked_out_when_hp_zero() -> void:
	# AC9: Knocked out when HP reaches 0
	var animal := _create_mock_animal(5, "test")
	_mock_animals.append(animal)
	var unit = CombatManager.CombatUnit.new(animal, true)

	assert_false(unit.is_knocked_out)
	assert_true(unit.is_alive())

	# Deal lethal damage
	unit.take_damage(unit.max_hp)

	assert_true(unit.is_knocked_out)
	assert_false(unit.is_alive())


func test_combat_unit_is_alive_check() -> void:
	var animal := _create_mock_animal(5, "test")
	_mock_animals.append(animal)
	var unit = CombatManager.CombatUnit.new(animal, true)

	assert_true(unit.is_alive())

	unit.take_damage(unit.max_hp - 1)
	assert_true(unit.is_alive())

	unit.take_damage(1)
	assert_false(unit.is_alive())


# =============================================================================
# VICTORY/DEFEAT TESTS (AC13, AC14, AC15, AC17, AC18)
# =============================================================================

func test_victory_detected_when_all_enemies_knocked_out() -> void:
	# AC13: Victory when all enemies at 0 HP
	# AC15: combat_ended(true, captured_types) emitted
	var player_team := _setup_basic_combat(100, 1)  # Strong player, weak enemies

	watch_signals(EventBus)

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	# Wait for battle to complete (weak enemies should fall fast)
	await wait_for_signal(EventBus.combat_ended, 15.0)

	assert_signal_emitted(EventBus, "combat_ended")

	# Check victory - get_signal_parameters returns array of params from last emission
	var emitted: Array = get_signal_parameters(EventBus, "combat_ended")
	if emitted.size() > 0:
		# First element is the 'won' bool parameter
		assert_true(emitted[0], "Should be victory (first param is true)")


func test_defeat_detected_when_all_player_animals_knocked_out() -> void:
	# AC14: Defeat when all player animals at 0 HP
	# AC16: combat_ended(false, []) emitted
	var player_team := _setup_basic_combat(1, 100)  # Weak player, strong enemies

	watch_signals(EventBus)

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	assert_signal_emitted(EventBus, "combat_ended")

	# Check defeat - get_signal_parameters returns array of params from last emission
	var emitted: Array = get_signal_parameters(EventBus, "combat_ended")
	if emitted.size() > 0:
		# First element is the 'won' bool parameter
		assert_false(emitted[0], "Should be defeat (first param is false)")


func test_victory_claims_territory() -> void:
	# AC17: Victory claims territory
	var player_team := _setup_basic_combat(100, 1)

	_combat_manager.start_combat(player_team, Vector2i(3, 3), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	# Check territory was claimed
	var claims: Array = _mock_territory_manager.claimed_hexes
	assert_gt(claims.size(), 0, "Territory should be claimed")
	if claims.size() > 0:
		assert_eq(claims[0].owner, "player")
		assert_eq(claims[0].source, "combat")


func test_victory_removes_wild_herd() -> void:
	# AC18: Victory removes wild herd
	var player_team := _setup_basic_combat(100, 1)

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	# Check herd was removed
	var removed: Array = _mock_wild_herd_manager.removed_herds
	assert_true(removed.has("test_herd"), "Herd should be removed after victory")


# =============================================================================
# DEFEAT HANDLING TESTS (AC16, AC19, AC20)
# =============================================================================

func test_defeat_marks_player_animals_as_tired() -> void:
	# AC19: Defeat marks player animals as tired (RESTING state)
	var player_team := _setup_basic_combat(1, 100)  # Weak player

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	# Check AI components were transitioned to RESTING (state 3)
	for animal in player_team:
		if animal._ai:
			assert_eq(animal._ai.last_state, 3, "Animal should be in RESTING state")


func test_defeat_leaves_herd_and_hex_unchanged() -> void:
	# AC20: Defeat leaves herd and hex unchanged
	var player_team := _setup_basic_combat(1, 100)  # Weak player

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	# Check herd was NOT removed
	var removed: Array = _mock_wild_herd_manager.removed_herds
	assert_false(removed.has("test_herd"), "Herd should NOT be removed after defeat")

	# Check territory was NOT claimed
	var claims: Array = _mock_territory_manager.claimed_hexes
	assert_eq(claims.size(), 0, "Territory should NOT be claimed after defeat")


# =============================================================================
# BATTLE LOG TESTS (AC24, AC25)
# =============================================================================

func test_battle_log_records_all_actions() -> void:
	# AC24: Battle log records all actions
	var player_team := _setup_basic_combat(10, 5)

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	var log := _combat_manager.get_battle_log()

	assert_gt(log.size(), 0, "Battle log should have entries")

	# Check log entry structure
	if log.size() > 0:
		var entry = log[0]
		assert_true("turn_number" in entry, "Entry should have turn_number")
		assert_true("attacker_id" in entry, "Entry should have attacker_id")
		assert_true("defender_id" in entry, "Entry should have defender_id")
		assert_true("damage" in entry, "Entry should have damage")
		assert_true("defender_hp_after" in entry, "Entry should have defender_hp_after")


func test_battle_log_accessible_after_combat() -> void:
	# AC25: Battle log accessible for UI display
	var player_team := _setup_basic_combat(100, 1)

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	# Combat ended, but log should still be accessible
	assert_false(_combat_manager.is_combat_active())

	var log := _combat_manager.get_battle_log()
	assert_gt(log.size(), 0, "Battle log should be accessible after combat")


# =============================================================================
# COMBAT STATE TESTS (AC21, AC22, AC23)
# =============================================================================

func test_combat_state_resets_after_battle() -> void:
	var player_team := _setup_basic_combat(100, 1)

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	assert_true(_combat_manager.is_combat_active())

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	assert_false(_combat_manager.is_combat_active())


func test_combat_rejected_with_empty_team() -> void:
	_mock_wild_herd_manager.add_test_herd("test_herd", [])

	_combat_manager.start_combat([], Vector2i(1, 1), "test_herd")

	await wait_frames(2)

	assert_false(_combat_manager.is_combat_active(), "Combat should not start with empty team")


func test_combat_rejected_with_invalid_herd() -> void:
	var player_team := _setup_basic_combat()

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "nonexistent_herd")

	await wait_frames(2)

	assert_false(_combat_manager.is_combat_active(), "Combat should not start with invalid herd")


# =============================================================================
# SIGNAL TESTS (AC12)
# =============================================================================

func test_combat_attack_occurred_signal_emitted() -> void:
	# AC12: combat_attack_occurred signal emitted during attacks
	var player_team := _setup_basic_combat(10, 5)

	watch_signals(EventBus)

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	# Wait a bit for some attacks to occur
	await get_tree().create_timer(3.0).timeout

	# Should have emitted attack signals
	var attack_count: int = get_signal_emit_count(EventBus, "combat_attack_occurred")
	assert_gt(attack_count, 0, "combat_attack_occurred should be emitted during combat")


func test_combat_ended_signal_contains_correct_data() -> void:
	var player_team := _setup_basic_combat(100, 1)

	watch_signals(EventBus)

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	await wait_for_signal(EventBus.combat_ended, 15.0)

	assert_signal_emitted(EventBus, "combat_ended")

	# get_signal_parameters returns array of params from last emission: [won, captured]
	var params: Array = get_signal_parameters(EventBus, "combat_ended")
	if params.size() >= 2:
		var won: bool = params[0]
		var captured: Array = params[1]

		assert_true(won, "First param should be victory boolean")
		assert_typeof(captured, TYPE_ARRAY, "Second param should be captured animals array")
