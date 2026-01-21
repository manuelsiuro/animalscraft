## CombatManager - Auto-battle system for territory combat.
## Handles turn-based combat resolution, victory/defeat processing, and territory claiming.
## Combat is "cozy" - animals get knocked out, never die.
##
## Architecture: scripts/systems/combat/combat_manager.gd
## Story: 5-5-implement-auto-battle-system
##
## Usage:
##   # Automatically started via EventBus signal
##   EventBus.combat_team_selected.emit(player_team, hex_coord, herd_id)
##
##   # Query combat state
##   if CombatManager.is_combat_active():
##       pass  # Combat in progress
##
##   # Get battle log after combat
##   var log = CombatManager.get_battle_log()
class_name CombatManager
extends Node

# =============================================================================
# INNER CLASSES
# =============================================================================

## CombatUnit - Wrapper for Animal during battle with HP tracking.
## HP is battle-only (strength * 3), not tied to energy.
class CombatUnit extends RefCounted:
	## The wrapped Animal node
	var animal: Node
	## Maximum HP for this battle (strength * 3)
	var max_hp: int
	## Current HP
	var current_hp: int
	## Whether knocked out (HP <= 0)
	var is_knocked_out: bool = false
	## Whether this unit is on player's team
	var is_player_team: bool
	## Unique ID for logging/identification
	var unit_id: String

	func _init(p_animal: Node, p_is_player: bool) -> void:
		animal = p_animal
		is_player_team = p_is_player

		# Calculate HP from strength (AC8)
		var strength := get_strength()
		max_hp = strength * HP_MULTIPLIER
		current_hp = max_hp

		# Generate unit ID
		if p_animal and p_animal.has_method("get_animal_id"):
			unit_id = p_animal.get_animal_id()
		else:
			unit_id = "unit_%d" % randi()

	## Get animal's strength stat.
	func get_strength() -> int:
		if animal and animal.stats:
			return animal.stats.strength
		return 1  # Fallback

	## Take damage, mark knocked out if HP <= 0 (AC9).
	func take_damage(amount: int) -> void:
		current_hp = maxi(0, current_hp - amount)
		if current_hp <= 0:
			is_knocked_out = true

	## Check if unit is still alive (not knocked out) (AC10).
	func is_alive() -> bool:
		return current_hp > 0 and not is_knocked_out


## BattleLogEntry - Record of a single combat action.
class BattleLogEntry extends RefCounted:
	## Turn number when this action occurred
	var turn_number: int
	## ID of the attacking unit
	var attacker_id: String
	## ID of the defending unit
	var defender_id: String
	## Damage dealt
	var damage: int
	## Defender's HP after this attack
	var defender_hp_after: int
	## Whether defender was knocked out by this attack
	var defender_knocked_out: bool

	func _init(p_turn: int, p_attacker: String, p_defender: String, p_damage: int, p_hp: int, p_ko: bool) -> void:
		turn_number = p_turn
		attacker_id = p_attacker
		defender_id = p_defender
		damage = p_damage
		defender_hp_after = p_hp
		defender_knocked_out = p_ko

# =============================================================================
# CONSTANTS
# =============================================================================

## HP multiplier (HP = strength * HP_MULTIPLIER)
const HP_MULTIPLIER: int = 3

## Attack variance (0-20% random bonus)
const ATTACK_VARIANCE: float = 0.2

## Defense multiplier (70% of strength)
const DEFENSE_MULTIPLIER: float = 0.7

## Minimum damage per attack
const MIN_DAMAGE: int = 1

## Turn delay range (seconds between attacks)
const TURN_DELAY_MIN: float = 0.8
const TURN_DELAY_MAX: float = 1.2

# =============================================================================
# PROPERTIES
# =============================================================================

## Whether combat is currently active (AC21, AC22)
var _is_combat_active: bool = false

## Current combat hex location
var _current_hex: Vector2i

## Current herd ID being fought
var _current_herd_id: String

## Player team (CombatUnit wrappers)
var _player_team: Array[CombatUnit] = []

## Enemy team (CombatUnit wrappers)
var _enemy_team: Array[CombatUnit] = []

## Turn queue for round-robin combat
var _turn_queue: Array[CombatUnit] = []

## Current turn index in queue
var _current_turn_index: int = 0

## Turn counter for logging
var _turn_number: int = 0

## Battle log for UI replay (AC24, AC25)
var _battle_log: Array[BattleLogEntry] = []

## Reference to WorldManager
var _world_manager: Node = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	add_to_group("combat_managers")
	# Connect to combat team selection signal (AC1)
	EventBus.combat_team_selected.connect(_on_combat_team_selected)


## Cleanup signal connections when removed from tree (AR18).
func _exit_tree() -> void:
	if EventBus.combat_team_selected.is_connected(_on_combat_team_selected):
		EventBus.combat_team_selected.disconnect(_on_combat_team_selected)


## Initialize with WorldManager reference.
## @param world_manager The WorldManager for territory/herd access
func initialize(world_manager: Node) -> void:
	if world_manager == null:
		GameLogger.error("CombatManager", "Cannot initialize with null WorldManager")
		return

	_world_manager = world_manager
	GameLogger.info("CombatManager", "CombatManager initialized")

# =============================================================================
# PUBLIC API
# =============================================================================

## Check if combat is currently active (AC21, AC22).
## @return True if combat is in progress
func is_combat_active() -> bool:
	return _is_combat_active


## Get the battle log for UI display (AC25).
## @return Array of BattleLogEntry objects
func get_battle_log() -> Array[BattleLogEntry]:
	return _battle_log


## Get the current combat hex (for UI/camera focus).
## @return Vector2i hex coordinate or Vector2i.ZERO if no combat
func get_current_hex() -> Vector2i:
	if _is_combat_active:
		return _current_hex
	return Vector2i.ZERO

# =============================================================================
# COMBAT INITIATION (AC1, AC2, AC23)
# =============================================================================

## Signal handler for combat_team_selected.
func _on_combat_team_selected(team: Array, hex_coord: Vector2i, herd_id: String) -> void:
	# Guard: reject if combat already active (AC23)
	if _is_combat_active:
		GameLogger.warn("CombatManager", "Combat request rejected: combat already active")
		return

	# Guard: validate inputs
	if team.is_empty():
		GameLogger.error("CombatManager", "Combat request rejected: empty team")
		return

	if herd_id.is_empty():
		GameLogger.error("CombatManager", "Combat request rejected: empty herd_id")
		return

	start_combat(team, hex_coord, herd_id)


## Start combat with the given team at the specified location.
## @param team Array of Animal nodes (player's combat team)
## @param hex_coord The contested hex coordinate
## @param herd_id The wild herd to fight
func start_combat(team: Array, hex_coord: Vector2i, herd_id: String) -> void:
	# Guard: reject if already active (AC23)
	if _is_combat_active:
		GameLogger.warn("CombatManager", "start_combat rejected: combat already active")
		return

	_is_combat_active = true
	_current_hex = hex_coord
	_current_herd_id = herd_id

	# Clear previous battle state
	_player_team.clear()
	_enemy_team.clear()
	_turn_queue.clear()
	_battle_log.clear()
	_turn_number = 0

	GameLogger.info("CombatManager", "Starting combat at %s against herd %s" % [hex_coord, herd_id])

	# Create player CombatUnits
	for animal in team:
		if animal:
			var unit := CombatUnit.new(animal, true)
			_player_team.append(unit)
			GameLogger.debug("CombatManager", "Player unit: %s (HP: %d, STR: %d)" % [
				unit.unit_id, unit.max_hp, unit.get_strength()
			])

	# Get enemy herd from WildHerdManager
	var wild_herd_manager := _get_wild_herd_manager()
	if not wild_herd_manager:
		GameLogger.error("CombatManager", "Cannot find WildHerdManager, aborting combat")
		_reset_combat_state()
		return

	var herd = wild_herd_manager.get_herd(herd_id)
	if not herd:
		GameLogger.error("CombatManager", "Herd %s not found, aborting combat" % herd_id)
		_reset_combat_state()
		return

	# Create enemy CombatUnits
	for animal in herd.animals:
		if animal:
			var unit := CombatUnit.new(animal, false)
			_enemy_team.append(unit)
			GameLogger.debug("CombatManager", "Enemy unit: %s (HP: %d, STR: %d)" % [
				unit.unit_id, unit.max_hp, unit.get_strength()
			])

	if _enemy_team.is_empty():
		GameLogger.error("CombatManager", "Enemy team is empty, aborting combat")
		_reset_combat_state()
		return

	# Build turn queue (AC3)
	_build_turn_queue(_player_team, _enemy_team)

	# Emit combat started signal (AC2)
	EventBus.combat_started.emit(hex_coord)

	# Start the battle loop
	_execute_battle_loop()

# =============================================================================
# TURN ORDER SYSTEM (AC3, AC4, AC10)
# =============================================================================

## Build alternating turn queue (player first, then enemy, etc.) (AC3).
func _build_turn_queue(player_units: Array[CombatUnit], enemy_units: Array[CombatUnit]) -> void:
	_turn_queue.clear()

	var max_size := maxi(player_units.size(), enemy_units.size())

	# Interleave player and enemy units
	for i in max_size:
		if i < player_units.size():
			_turn_queue.append(player_units[i])
		if i < enemy_units.size():
			_turn_queue.append(enemy_units[i])

	_current_turn_index = 0

	GameLogger.debug("CombatManager", "Turn queue built with %d units" % _turn_queue.size())


## Get next attacker, skipping knocked out units (AC10).
## @return Next CombatUnit to attack, or null if no living units
func _get_next_attacker() -> CombatUnit:
	if _turn_queue.is_empty():
		return null

	var attempts := 0
	var queue_size := _turn_queue.size()

	while attempts < queue_size:
		var unit := _turn_queue[_current_turn_index]
		_current_turn_index = (_current_turn_index + 1) % queue_size
		attempts += 1

		# Skip knocked out units (AC10)
		if unit.is_alive():
			return unit

	return null  # All units knocked out (shouldn't happen in normal flow)


## Get random living target from opposing team (AC4).
## @param attacker The attacking unit
## @return Random living enemy unit, or null if none
func _get_random_living_target(attacker: CombatUnit) -> CombatUnit:
	var targets: Array[CombatUnit] = []

	# Get opposing team
	var enemy_team: Array[CombatUnit]
	if attacker.is_player_team:
		enemy_team = _enemy_team
	else:
		enemy_team = _player_team

	# Filter to living targets
	for unit in enemy_team:
		if unit.is_alive():
			targets.append(unit)

	if targets.is_empty():
		return null

	# Return random target (AC4)
	return targets[randi() % targets.size()]

# =============================================================================
# COMBAT FORMULAS (AC5, AC6, AC7)
# =============================================================================

## Calculate attack power (AC5).
## Formula: strength + random(0, strength * 0.2)
## @param attacker The attacking unit
## @return Attack power value
func _calculate_attack_power(attacker: CombatUnit) -> float:
	var strength := float(attacker.get_strength())
	var variance := randf() * strength * ATTACK_VARIANCE
	return strength + variance


## Calculate defense power (AC6).
## Formula: strength * 0.7
## @param defender The defending unit
## @return Defense power value
func _calculate_defense_power(defender: CombatUnit) -> float:
	var strength := float(defender.get_strength())
	return strength * DEFENSE_MULTIPLIER


## Calculate final damage (AC7).
## Formula: max(1, attack_power - defense_power)
## @param attack_power Attacker's attack value
## @param defense_power Defender's defense value
## @return Damage to deal (minimum 1)
func _calculate_damage(attack_power: float, defense_power: float) -> int:
	var raw_damage := attack_power - defense_power
	return maxi(MIN_DAMAGE, int(raw_damage))

# =============================================================================
# BATTLE EXECUTION (AC11, AC12, AC13, AC14)
# =============================================================================

## Execute the battle loop as async coroutine.
## Continues until one side is defeated.
func _execute_battle_loop() -> void:
	# Use call_deferred to start async loop
	_run_battle.call_deferred()


## Async battle execution.
func _run_battle() -> void:
	GameLogger.info("CombatManager", "Battle loop starting")

	while _is_combat_active:
		# Check victory/defeat conditions (AC13, AC14)
		if _check_all_knocked_out(_enemy_team):
			_process_victory()
			return

		if _check_all_knocked_out(_player_team):
			_process_defeat()
			return

		# Get next attacker
		var attacker := _get_next_attacker()
		if not attacker:
			GameLogger.error("CombatManager", "No valid attacker found, ending battle")
			_process_defeat()
			return

		# Get target
		var target := _get_random_living_target(attacker)
		if not target:
			# No targets = victory for attacker's team
			if attacker.is_player_team:
				_process_victory()
			else:
				_process_defeat()
			return

		# Execute attack
		_execute_attack(attacker, target)

		# Wait between turns (AC11)
		var delay := randf_range(TURN_DELAY_MIN, TURN_DELAY_MAX)
		await get_tree().create_timer(delay).timeout

	GameLogger.info("CombatManager", "Battle loop ended")


## Execute a single attack (AC12).
func _execute_attack(attacker: CombatUnit, defender: CombatUnit) -> void:
	_turn_number += 1

	# Calculate damage
	var attack_power := _calculate_attack_power(attacker)
	var defense_power := _calculate_defense_power(defender)
	var damage := _calculate_damage(attack_power, defense_power)

	# Apply damage
	defender.take_damage(damage)

	# Log action (AC24)
	_log_action(attacker, defender, damage)

	# Emit attack signal for UI (AC12)
	EventBus.combat_attack_occurred.emit(attacker, defender, damage, defender.current_hp)

	GameLogger.debug("CombatManager", "Turn %d: %s attacks %s for %d damage (HP: %d/%d)%s" % [
		_turn_number,
		attacker.unit_id,
		defender.unit_id,
		damage,
		defender.current_hp,
		defender.max_hp,
		" [KO!]" if defender.is_knocked_out else ""
	])


## Check if all units in a team are knocked out.
func _check_all_knocked_out(team: Array[CombatUnit]) -> bool:
	for unit in team:
		if unit.is_alive():
			return false
	return true

# =============================================================================
# VICTORY PROCESSING (AC15, AC17, AC18)
# =============================================================================

## Process player victory (AC15, AC17, AC18).
func _process_victory() -> void:
	GameLogger.info("CombatManager", "VICTORY! Player wins at %s" % _current_hex)

	# Collect captured animal types (AC15)
	var captured_types: Array = []
	for unit in _enemy_team:
		if unit.animal and unit.animal.stats:
			captured_types.append(unit.animal.stats.animal_id)

	# Claim territory (AC17)
	var territory_manager := _get_territory_manager()
	if territory_manager:
		var hex := HexCoord.from_vector(_current_hex)
		territory_manager.set_hex_owner(hex, "player", "combat")
		GameLogger.info("CombatManager", "Territory claimed at %s via combat" % _current_hex)

	# Remove wild herd (AC18)
	var wild_herd_manager := _get_wild_herd_manager()
	if wild_herd_manager:
		wild_herd_manager.remove_herd(_current_herd_id)
		GameLogger.info("CombatManager", "Wild herd %s removed" % _current_herd_id)

	# Emit combat ended signal (AC15)
	EventBus.combat_ended.emit(true, captured_types)

	# Reset state
	_reset_combat_state()

# =============================================================================
# DEFEAT PROCESSING (AC16, AC19, AC20)
# =============================================================================

## Process player defeat (AC16, AC19, AC20).
func _process_defeat() -> void:
	GameLogger.info("CombatManager", "DEFEAT! Player loses at %s" % _current_hex)

	# Mark player animals as tired (AC19)
	for unit in _player_team:
		if unit.animal and is_instance_valid(unit.animal):
			_mark_animal_tired(unit.animal)

	# Hex and herd remain unchanged (AC20)
	# No territory claim, no herd removal

	# Emit combat ended signal (AC16)
	EventBus.combat_ended.emit(false, [])

	# Reset state
	_reset_combat_state()


## Mark an animal as tired, transitioning to RESTING state (AC19).
func _mark_animal_tired(animal: Node) -> void:
	# Find AIComponent and transition to RESTING
	var ai_component := animal.get_node_or_null("AIComponent")
	if ai_component and ai_component.has_method("transition_to"):
		# AIComponent.AnimalState.RESTING = 3
		ai_component.transition_to(3)  # RESTING state
		GameLogger.debug("CombatManager", "Marked %s as tired (RESTING)" % (
			animal.get_animal_id() if animal.has_method("get_animal_id") else "unknown"
		))

# =============================================================================
# BATTLE LOG (AC24, AC25)
# =============================================================================

## Log a combat action (AC24).
func _log_action(attacker: CombatUnit, defender: CombatUnit, damage: int) -> void:
	var entry := BattleLogEntry.new(
		_turn_number,
		attacker.unit_id,
		defender.unit_id,
		damage,
		defender.current_hp,
		defender.is_knocked_out
	)
	_battle_log.append(entry)

# =============================================================================
# HELPERS
# =============================================================================

## Get TerritoryManager from WorldManager.
func _get_territory_manager() -> Node:
	if _world_manager and _world_manager.has_method("get_territory_manager"):
		return _world_manager.get_territory_manager()
	if _world_manager and "_territory_manager" in _world_manager:
		return _world_manager._territory_manager
	return null


## Get WildHerdManager from WorldManager.
func _get_wild_herd_manager() -> Node:
	if _world_manager and _world_manager.has_method("get_wild_herd_manager"):
		return _world_manager.get_wild_herd_manager()
	if _world_manager and "_wild_herd_manager" in _world_manager:
		return _world_manager._wild_herd_manager
	# Fallback: search in scene tree
	var managers := get_tree().get_nodes_in_group("wild_herd_managers")
	if not managers.is_empty():
		return managers[0]
	return null


## Reset combat state after battle ends.
func _reset_combat_state() -> void:
	_is_combat_active = false
	_current_hex = Vector2i.ZERO
	_current_herd_id = ""
	_player_team.clear()
	_enemy_team.clear()
	_turn_queue.clear()
	_current_turn_index = 0
	_turn_number = 0
	# Note: Keep _battle_log for UI access (AC25)
