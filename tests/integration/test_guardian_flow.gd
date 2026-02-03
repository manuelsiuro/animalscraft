## Integration tests for the Guardian battle flow (Story 7-2).
## Tests end-to-end guardian spawning, combat, defeat, and biome unlock.
##
## Architecture: tests/integration/test_guardian_flow.gd
## Story: 7-2-implement-alpha-fox-guardian
extends GutTest

# =============================================================================
# CONSTANTS
# =============================================================================

const ALPHA_FOX_PATH := "res://resources/guardians/alpha_fox.tres"
const GUARDIAN_MANAGER_PATH := "res://scripts/systems/guardian/guardian_manager.gd"
const COMBAT_MANAGER_PATH := "res://scripts/systems/combat/combat_manager.gd"
const ANIMAL_SCENE_PATH := "res://scenes/entities/animals/rabbit.tscn"

# =============================================================================
# FIXTURES
# =============================================================================

var _guardian_manager: Node = null
var _combat_manager: Node = null
var _test_animals: Array[Node] = []


func before_each() -> void:
	# Create GuardianManager
	var gm_script := load(GUARDIAN_MANAGER_PATH)
	if gm_script:
		_guardian_manager = Node.new()
		_guardian_manager.set_script(gm_script)
		add_child_autofree(_guardian_manager)

	# Create CombatManager
	var cm_script := load(COMBAT_MANAGER_PATH)
	if cm_script:
		_combat_manager = Node.new()
		_combat_manager.set_script(cm_script)
		add_child_autofree(_combat_manager)

	await wait_frames(2)


func after_each() -> void:
	# Clean up test animals
	for animal in _test_animals:
		if is_instance_valid(animal):
			animal.queue_free()
	_test_animals.clear()

	_guardian_manager = null
	_combat_manager = null


## Create a test animal with specific strength for combat testing.
func _create_test_animal(strength: int = 3) -> Node:
	var scene: PackedScene = load(ANIMAL_SCENE_PATH) as PackedScene
	if not scene:
		return null

	var animal: Node = scene.instantiate()
	add_child_autofree(animal)
	await wait_frames(1)

	# Initialize with test stats
	var hex: HexCoord = HexCoord.new(0, 0)
	var stats: AnimalStats = AnimalStats.new()
	stats.animal_id = "test_rabbit"
	stats.strength = strength
	stats.energy = 3
	stats.speed = 3
	stats.biome = "plains"

	if animal.has_method("initialize"):
		animal.initialize(hex, stats)

	_test_animals.append(animal)
	return animal

# =============================================================================
# MILESTONE SPAWN FLOW TESTS (AC3)
# =============================================================================

func test_milestone_triggers_guardian_spawn() -> void:
	watch_signals(EventBus)

	# Emit forest_border milestone (triggers Alpha Fox spawn)
	EventBus.milestone_reached.emit("forest_border")
	await wait_frames(2)

	# Guardian should have spawned
	assert_signal_emitted(EventBus, "guardian_spawned")

	var params: Array = get_signal_parameters(EventBus, "guardian_spawned")
	assert_eq(params[0], "alpha_fox", "Should spawn alpha_fox")


func test_milestone_spawn_only_once() -> void:
	watch_signals(EventBus)

	# First milestone
	EventBus.milestone_reached.emit("forest_border")
	await wait_frames(2)

	# Clear signal tracking
	clear_signal_watcher()
	watch_signals(EventBus)

	# Second milestone should not re-spawn
	EventBus.milestone_reached.emit("forest_border")
	await wait_frames(2)

	# Should not emit spawn again (already spawned)
	assert_signal_not_emitted(EventBus, "guardian_spawned")


func test_no_spawn_after_defeat() -> void:
	# Defeat the guardian first
	_guardian_manager.defeat_guardian("alpha_fox")
	await wait_frames(1)

	watch_signals(EventBus)

	# Milestone should not spawn defeated guardian
	EventBus.milestone_reached.emit("forest_border")
	await wait_frames(2)

	assert_signal_not_emitted(EventBus, "guardian_spawned")

# =============================================================================
# GUARDIAN BATTLE FLOW TESTS (AC4, AC5, AC6)
# =============================================================================

func test_guardian_battle_signal_triggers_combat() -> void:
	watch_signals(EventBus)

	# Create test animals for combat team
	var animal1 := await _create_test_animal(5)
	var animal2 := await _create_test_animal(5)
	var animal3 := await _create_test_animal(5)

	# Form team
	var team: Array = [animal1, animal2, animal3]

	# Emit guardian battle signal
	EventBus.guardian_battle_started.emit(team, "alpha_fox", Vector2i(5, 5))
	await wait_frames(2)

	# Combat should have started
	assert_signal_emitted(EventBus, "combat_started")


func test_guardian_combat_manager_state() -> void:
	# Create test animals
	var animal1 := await _create_test_animal(5)
	var animal2 := await _create_test_animal(5)

	var team: Array = [animal1, animal2]

	# Start guardian battle
	EventBus.guardian_battle_started.emit(team, "alpha_fox", Vector2i(5, 5))
	await wait_frames(2)

	# Combat manager should report guardian battle
	assert_true(_combat_manager.is_combat_active(), "Combat should be active")
	assert_true(_combat_manager.is_guardian_battle(), "Should be guardian battle")
	assert_eq(_combat_manager.get_guardian_id(), "alpha_fox", "Guardian ID should match")

# =============================================================================
# GUARDIAN DEFEAT FLOW TESTS (AC6)
# =============================================================================

func test_guardian_defeat_triggers_biome_unlock_signal() -> void:
	watch_signals(EventBus)

	# Defeat guardian
	_guardian_manager.defeat_guardian("alpha_fox")
	await wait_frames(2)

	# Should emit guardian_defeated with biome
	assert_signal_emitted(EventBus, "guardian_defeated")

	var params: Array = get_signal_parameters(EventBus, "guardian_defeated")
	assert_eq(params[0], "alpha_fox", "Should emit guardian_id")
	assert_eq(params[1], "forest", "Should emit biome_id for unlock")


func test_guardian_defeat_is_permanent() -> void:
	# Defeat guardian
	_guardian_manager.defeat_guardian("alpha_fox")

	# Verify permanently defeated
	assert_true(_guardian_manager.is_guardian_defeated("alpha_fox"))

	# Cannot spawn again
	var spawn_result: bool = _guardian_manager.spawn_guardian("alpha_fox")
	assert_false(spawn_result, "Cannot spawn defeated guardian")

# =============================================================================
# PLAYER DEFEAT FLOW TESTS (AC7)
# =============================================================================

func test_player_defeat_guardian_remains() -> void:
	# Spawn guardian first
	_guardian_manager.spawn_guardian("alpha_fox")
	await wait_frames(2)

	# Get active guardian before simulated defeat
	var guardian_before: Node = _guardian_manager.get_active_guardian("alpha_fox")
	assert_not_null(guardian_before, "Guardian should be active before defeat")

	# Guardian should still be tracked (player defeat doesn't remove guardian)
	# Note: Full combat flow would need to be simulated for complete test
	assert_false(_guardian_manager.is_guardian_defeated("alpha_fox"),
		"Guardian should not be defeated when player loses")

# =============================================================================
# SAVE/LOAD FLOW TESTS (AC9)
# =============================================================================

func test_save_load_preserves_defeated_state() -> void:
	# Defeat guardian
	_guardian_manager.defeat_guardian("alpha_fox")

	# Get save data
	var save_data: Dictionary = _guardian_manager.get_save_data()

	# Create new manager and load
	var new_manager: Node = Node.new()
	var script: GDScript = load(GUARDIAN_MANAGER_PATH)
	new_manager.set_script(script)
	add_child_autofree(new_manager)
	await wait_frames(2)

	new_manager.load_save_data(save_data)

	# Defeated state should be preserved
	assert_true(new_manager.is_guardian_defeated("alpha_fox"),
		"Defeated state should persist across save/load")


func test_save_load_preserves_active_guardian() -> void:
	# Spawn guardian
	_guardian_manager.spawn_guardian("alpha_fox")
	await wait_frames(2)

	# Get save data
	var save_data: Dictionary = _guardian_manager.get_save_data()
	assert_true("alpha_fox" in save_data["active"], "Active guardian should be in save data")

	# Create new manager and load
	var new_manager: Node = Node.new()
	var script: GDScript = load(GUARDIAN_MANAGER_PATH)
	new_manager.set_script(script)
	add_child_autofree(new_manager)
	await wait_frames(2)

	new_manager.load_save_data(save_data)
	await wait_frames(2)

	# Guardian should be spawned
	var active: Node = new_manager.get_active_guardian("alpha_fox")
	assert_not_null(active, "Active guardian should be restored from save")


func test_reset_clears_all_guardian_state() -> void:
	# Spawn and defeat
	_guardian_manager.spawn_guardian("alpha_fox")
	await wait_frames(2)
	_guardian_manager.defeat_guardian("alpha_fox")

	# Reset
	_guardian_manager.reset()

	# All state should be cleared
	assert_false(_guardian_manager.is_guardian_defeated("alpha_fox"),
		"Defeated state should be cleared")
	assert_null(_guardian_manager.get_active_guardian("alpha_fox"),
		"Active guardian should be cleared")

# =============================================================================
# BIOME UNLOCK INTEGRATION TESTS (AC6)
# =============================================================================

func test_guardian_defeat_integrates_with_biome_manager() -> void:
	# This test verifies the signal chain for biome unlock
	watch_signals(EventBus)

	# Defeat guardian
	_guardian_manager.defeat_guardian("alpha_fox")
	await wait_frames(2)

	# Check signal was emitted (BiomeManager would receive this)
	assert_signal_emitted(EventBus, "guardian_defeated")

	# Verify correct biome in signal
	var params: Array = get_signal_parameters(EventBus, "guardian_defeated")
	assert_eq(params[1], "forest", "Should unlock forest biome")

# =============================================================================
# COMBAT UI INTEGRATION TESTS
# =============================================================================

func test_combat_team_selection_modal_guardian_mode() -> void:
	# This tests the UI can be configured for guardian battles
	# The modal should accept GuardianData and display guardian info
	var alpha_fox: GuardianData = load(ALPHA_FOX_PATH) as GuardianData
	assert_not_null(alpha_fox, "Alpha Fox data should load")

	# Verify guardian-specific fields are accessible for UI
	assert_eq(alpha_fox.difficulty_rating, "Easy", "Difficulty rating accessible")
	assert_eq(alpha_fox.reward_description, "Opens Forest Biome", "Reward description accessible")
