## Unit tests for defeat outcomes system.
## Tests animal tired state, energy depletion, retreat, signals, and territory preservation.
##
## Story: 5-9-implement-defeat-outcomes
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

## Create mock animal with AIComponent and StatsComponent.
## Story 5-9: Enhanced with energy tracking for tired state tests.
func _create_mock_animal_with_stats(strength: int = 5, energy: int = 5, animal_id: String = "test_animal") -> Node3D:
	var animal := Node3D.new()
	animal.name = "MockAnimal_" + animal_id

	# Create mock stats object
	var stats_script := GDScript.new()
	stats_script.source_code = """
extends RefCounted
var strength: int = %d
var animal_id: String = \"%s\"
""" % [strength, animal_id]
	stats_script.reload()
	var stats_obj = stats_script.new()

	# Add animal script with proper methods
	var animal_script := GDScript.new()
	animal_script.source_code = """
extends Node3D
var stats: RefCounted

func get_animal_id() -> String:
	if stats:
		return stats.animal_id
	return \"unknown\"
"""
	animal_script.reload()
	animal.set_script(animal_script)
	animal.stats = stats_obj

	# Create mock StatsComponent with energy tracking
	var stats_component := Node.new()
	stats_component.name = "StatsComponent"
	var stats_comp_script := GDScript.new()
	stats_comp_script.source_code = """
extends Node
var _current_energy: int = %d
var _energy_depleted_amount: int = 0

func get_energy() -> int:
	return _current_energy

func deplete_energy(amount: int) -> void:
	_energy_depleted_amount = amount
	_current_energy = maxi(0, _current_energy - amount)
""" % energy
	stats_comp_script.reload()
	stats_component.set_script(stats_comp_script)
	animal.add_child(stats_component)

	# Create mock AIComponent with state tracking
	var ai_component := Node.new()
	ai_component.name = "AIComponent"
	var ai_script := GDScript.new()
	ai_script.source_code = """
extends Node
var last_state: int = -1
var transition_count: int = 0

func transition_to(state: int) -> void:
	last_state = state
	transition_count += 1
"""
	ai_script.reload()
	ai_component.set_script(ai_script)
	animal.add_child(ai_component)

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


## Setup combat scenario where player will LOSE (weak player vs strong enemies).
func _setup_defeat_scenario(player_strength: int = 1, enemy_strength: int = 100) -> Array:
	# Create player team (3 weak animals)
	var player_team: Array = []
	for i in 3:
		var animal := _create_mock_animal_with_stats(player_strength, 5, "player_%d" % i)
		player_team.append(animal)
		_mock_animals.append(animal)

	# Create enemy team (2 strong animals)
	var enemy_team: Array = []
	for i in 2:
		var animal := _create_mock_animal_with_stats(enemy_strength, 5, "enemy_%d" % i)
		enemy_team.append(animal)
		_mock_enemy_animals.append(animal)

	# Register enemy herd
	_mock_wild_herd_manager.add_test_herd("test_herd", enemy_team)

	return player_team


# =============================================================================
# DEFEAT STATE PROCESSING TESTS (AC1, AC2, AC3)
# =============================================================================

func test_defeat_marks_all_player_animals_as_tired() -> void:
	# Story 5-9 AC1: All player animals marked as "tired" (RESTING state)
	var player_team := _setup_defeat_scenario()

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	# Wait for battle to complete (weak player should lose quickly)
	await wait_for_signal(EventBus.combat_ended, 15.0)

	# Check all animals transitioned to RESTING state (3)
	for animal in player_team:
		var ai_component: Node = animal.get_node_or_null("AIComponent")
		assert_true(ai_component != null, "Animal should have AIComponent")
		if ai_component:
			assert_eq(ai_component.last_state, 3, "Animal should be in RESTING state (3)")


func test_defeat_sets_animal_energy_to_zero() -> void:
	# Story 5-9 AC1: Animals have energy = 0 after defeat
	var player_team := _setup_defeat_scenario()

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	# Check all animals have energy depleted to 0
	for animal in player_team:
		var stats_component: Node = animal.get_node_or_null("StatsComponent")
		assert_true(stats_component != null, "Animal should have StatsComponent")
		if stats_component:
			assert_eq(stats_component.get_energy(), 0, "Animal energy should be 0 after defeat")


func test_defeated_animals_teleported_to_home_hex() -> void:
	# Story 5-9 AC2: Animals teleported to home hex (0,0) after defeat
	var player_team := _setup_defeat_scenario()

	# Set initial positions away from home
	for animal in player_team:
		animal.global_position = Vector3(100, 0, 100)

	_combat_manager.start_combat(player_team, Vector2i(5, 5), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	# Check all animals are near home hex (0,0)
	# Home hex world position should be near (0, 0, 0) with small random offset
	for animal in player_team:
		var pos: Vector3 = animal.global_position
		# Allow for small random offset (±0.5 units) added in teleport
		assert_almost_eq(pos.x, 0.0, 1.0, "Animal X should be near home hex")
		assert_almost_eq(pos.z, 0.0, 1.0, "Animal Z should be near home hex")


# =============================================================================
# EVENTBUS INTEGRATION TESTS (AC4, AC5, AC6)
# =============================================================================

func test_combat_ended_false_emitted_on_defeat() -> void:
	# Story 5-9 AC4: combat_ended(false, []) emitted on defeat
	var player_team := _setup_defeat_scenario()

	watch_signals(EventBus)

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	assert_signal_emitted(EventBus, "combat_ended")

	var params: Array = get_signal_parameters(EventBus, "combat_ended")
	if params.size() >= 2:
		assert_false(params[0], "First param (won) should be false")
		assert_eq(params[1].size(), 0, "Second param (captured) should be empty array")


func test_animal_tired_signal_emitted_for_each_animal() -> void:
	# Story 5-9 AC5: animal_tired signal emitted for each affected animal
	var player_team := _setup_defeat_scenario()

	watch_signals(EventBus)

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	# Wait for deferred signals to complete
	await wait_frames(2)

	# Check animal_tired was emitted for each player animal
	var tired_count: int = get_signal_emit_count(EventBus, "animal_tired")
	assert_eq(tired_count, player_team.size(), "animal_tired should be emitted for each player animal")


func test_combat_retreat_started_signal_emitted_on_defeat() -> void:
	# Story 5-9 AC6: combat_retreat_started signal emitted with hex and count
	var player_team := _setup_defeat_scenario()

	watch_signals(EventBus)

	_combat_manager.start_combat(player_team, Vector2i(3, 4), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	assert_signal_emitted(EventBus, "combat_retreat_started")

	var params: Array = get_signal_parameters(EventBus, "combat_retreat_started")
	if params.size() >= 2:
		assert_eq(params[0], Vector2i(3, 4), "First param should be combat hex")
		assert_eq(params[1], player_team.size(), "Second param should be animal count")


# =============================================================================
# TERRITORY AND HERD UNCHANGED TESTS (AC11, AC12, AC13)
# =============================================================================

func test_defeat_does_not_change_territory_state() -> void:
	# Story 5-9 AC11: Contested hex remains wild-controlled (no territory change)
	var player_team := _setup_defeat_scenario()

	_combat_manager.start_combat(player_team, Vector2i(5, 5), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	# Check territory was NOT claimed
	var claims: Array = _mock_territory_manager.claimed_hexes
	assert_eq(claims.size(), 0, "Territory should NOT be claimed after defeat")


func test_defeat_preserves_wild_herd() -> void:
	# Story 5-9 AC12: Wild herd remains intact on the hex after defeat
	var player_team := _setup_defeat_scenario()

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	# Check herd was NOT removed
	var removed: Array = _mock_wild_herd_manager.removed_herds
	assert_false(removed.has("test_herd"), "Herd should NOT be removed after defeat")

	# Herd should still be accessible
	var herd = _mock_wild_herd_manager.get_herd("test_herd")
	assert_true(herd != null, "Herd should still exist in manager")


func test_player_can_retry_combat_after_recovery() -> void:
	# Story 5-9 AC13: Player can attempt to fight the same herd again
	var player_team := _setup_defeat_scenario()

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	# Combat should have ended
	assert_false(_combat_manager.is_combat_active(), "Combat should have ended")

	# Herd should still exist for retry
	var herd = _mock_wild_herd_manager.get_herd("test_herd")
	assert_true(herd != null, "Herd should be available for retry")


# =============================================================================
# SIGNAL ORDERING TESTS
# =============================================================================

func test_retreat_signal_emitted_before_combat_ended() -> void:
	# Verify combat_retreat_started is emitted BEFORE combat_ended
	var player_team := _setup_defeat_scenario()

	var signal_order: Array = []

	EventBus.combat_retreat_started.connect(func(_hex, _count): signal_order.append("retreat"))
	EventBus.combat_ended.connect(func(_won, _captured): signal_order.append("ended"))

	_combat_manager.start_combat(player_team, Vector2i(1, 1), "test_herd")

	# Wait for battle to complete
	await wait_for_signal(EventBus.combat_ended, 15.0)

	# Verify order: retreat should come before ended
	assert_gte(signal_order.size(), 2, "Both signals should be emitted")
	if signal_order.size() >= 2:
		var retreat_index: int = signal_order.find("retreat")
		var ended_index: int = signal_order.find("ended")
		assert_lt(retreat_index, ended_index, "retreat signal should come before ended signal")

	# Cleanup connections
	for connection in EventBus.combat_retreat_started.get_connections():
		EventBus.combat_retreat_started.disconnect(connection.callable)
	for connection in EventBus.combat_ended.get_connections():
		if connection.callable.get_method() != "_on_combat_ended":  # Don't disconnect internal handlers
			EventBus.combat_ended.disconnect(connection.callable)
