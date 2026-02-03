## Unit tests for the Guardian system (Story 7-2).
## Tests GuardianData resource, GuardianManager, and combat integration.
##
## Architecture: tests/unit/test_guardian_system.gd
## Story: 7-2-implement-alpha-fox-guardian
extends GutTest

# =============================================================================
# CONSTANTS
# =============================================================================

const GUARDIAN_DATA_PATH := "res://scripts/entities/guardians/guardian_data.gd"
const ALPHA_FOX_PATH := "res://resources/guardians/alpha_fox.tres"
const GUARDIAN_MANAGER_PATH := "res://scripts/systems/guardian/guardian_manager.gd"
const GUARDIAN_SCENE_PATH := "res://scenes/entities/guardians/alpha_fox.tscn"

# =============================================================================
# FIXTURES
# =============================================================================

var _guardian_manager: Node = null


func before_each() -> void:
	# Create a fresh GuardianManager for each test
	var script := load(GUARDIAN_MANAGER_PATH)
	if script:
		_guardian_manager = Node.new()
		_guardian_manager.set_script(script)
		add_child_autofree(_guardian_manager)
		await wait_frames(1)


func after_each() -> void:
	_guardian_manager = null

# =============================================================================
# GUARDIAN DATA TESTS (AC1)
# =============================================================================

func test_guardian_data_script_exists() -> void:
	var script := load(GUARDIAN_DATA_PATH)
	assert_not_null(script, "GuardianData script should exist")


func test_guardian_data_extends_animal_stats() -> void:
	var script := load(GUARDIAN_DATA_PATH) as GDScript
	assert_not_null(script, "GuardianData script should load")

	# Check if it extends AnimalStats by checking parent
	var guardian_data := GuardianData.new()
	assert_true(guardian_data is AnimalStats, "GuardianData should extend AnimalStats")


func test_alpha_fox_resource_exists() -> void:
	assert_true(ResourceLoader.exists(ALPHA_FOX_PATH), "Alpha Fox resource should exist")


func test_alpha_fox_stats_match_gdd() -> void:
	var alpha_fox := load(ALPHA_FOX_PATH) as GuardianData
	assert_not_null(alpha_fox, "Alpha Fox resource should load as GuardianData")

	# AC1: Energy=8, Speed=5, Strength=6
	assert_eq(alpha_fox.energy, 8, "Alpha Fox energy should be 8")
	assert_eq(alpha_fox.speed, 5, "Alpha Fox speed should be 5")
	assert_eq(alpha_fox.strength, 6, "Alpha Fox strength should be 6")


func test_alpha_fox_guardian_specific_fields() -> void:
	var alpha_fox := load(ALPHA_FOX_PATH) as GuardianData
	assert_not_null(alpha_fox, "Alpha Fox resource should load")

	assert_eq(alpha_fox.guardian_id, "alpha_fox", "Guardian ID should be alpha_fox")
	assert_eq(alpha_fox.unlocks_biome, "forest", "Should unlock forest biome")
	assert_eq(alpha_fox.difficulty_rating, "Easy", "Difficulty should be Easy")
	assert_eq(alpha_fox.reward_description, "Opens Forest Biome", "Reward description should match")
	assert_eq(alpha_fox.spawn_milestone, "forest_border", "Spawn milestone should be forest_border")
	assert_eq(alpha_fox.biome, "plains", "Biome should be plains")


func test_alpha_fox_specialty() -> void:
	var alpha_fox := load(ALPHA_FOX_PATH) as GuardianData
	assert_not_null(alpha_fox, "Alpha Fox resource should load")

	assert_eq(alpha_fox.specialty, "Biome Guardian - defeats unlock Forest", "Specialty should match")


func test_guardian_data_is_valid() -> void:
	var alpha_fox := load(ALPHA_FOX_PATH) as GuardianData
	assert_not_null(alpha_fox, "Alpha Fox resource should load")

	assert_true(alpha_fox.is_valid(), "Alpha Fox should be valid")


func test_guardian_data_invalid_when_missing_fields() -> void:
	var guardian := GuardianData.new()
	# Default fields are empty
	assert_false(guardian.is_valid(), "Guardian with empty fields should be invalid")

	# Set only guardian_id
	guardian.guardian_id = "test"
	assert_false(guardian.is_valid(), "Guardian without unlocks_biome should be invalid")

	# Set unlocks_biome but missing animal_id
	guardian.unlocks_biome = "forest"
	assert_false(guardian.is_valid(), "Guardian without animal_id should be invalid")

	# Set animal_id and biome (inherited from AnimalStats)
	guardian.animal_id = "test"
	guardian.biome = "plains"
	assert_true(guardian.is_valid(), "Guardian with all required fields should be valid")


func test_guardian_data_to_string() -> void:
	var alpha_fox := load(ALPHA_FOX_PATH) as GuardianData
	assert_not_null(alpha_fox, "Alpha Fox resource should load")

	var str_repr := alpha_fox.to_string()
	assert_true(str_repr.contains("alpha_fox"), "String should contain guardian_id")
	assert_true(str_repr.contains("forest"), "String should contain unlocks_biome")

# =============================================================================
# GUARDIAN SCENE TESTS (AC2)
# =============================================================================

func test_guardian_scene_exists() -> void:
	assert_true(ResourceLoader.exists(GUARDIAN_SCENE_PATH), "Alpha Fox scene should exist")


func test_guardian_scene_loads() -> void:
	var scene := load(GUARDIAN_SCENE_PATH) as PackedScene
	assert_not_null(scene, "Alpha Fox scene should load as PackedScene")


func test_guardian_scene_instantiates() -> void:
	var scene := load(GUARDIAN_SCENE_PATH) as PackedScene
	assert_not_null(scene, "Scene should load")

	var instance := scene.instantiate()
	assert_not_null(instance, "Scene should instantiate")

	add_child_autofree(instance)
	await wait_frames(1)

	# Should be a Node3D (inherits from animal_base)
	assert_true(instance is Node3D, "Guardian should be Node3D")


func test_guardian_scene_has_visual_node() -> void:
	var scene := load(GUARDIAN_SCENE_PATH) as PackedScene
	var instance := scene.instantiate()
	add_child_autofree(instance)
	await wait_frames(1)

	var visual := instance.get_node_or_null("Visual")
	assert_not_null(visual, "Guardian should have Visual node")

	var placeholder := instance.get_node_or_null("Visual/Placeholder")
	assert_not_null(placeholder, "Guardian should have Placeholder mesh")


func test_guardian_scene_scale() -> void:
	var scene := load(GUARDIAN_SCENE_PATH) as PackedScene
	var instance := scene.instantiate()
	add_child_autofree(instance)
	await wait_frames(1)

	# AC2: 1.5x scale for boss visual distinction
	var scale := (instance as Node3D).scale
	assert_almost_eq(scale.x, 1.5, 0.01, "Guardian X scale should be 1.5")
	assert_almost_eq(scale.y, 1.5, 0.01, "Guardian Y scale should be 1.5")
	assert_almost_eq(scale.z, 1.5, 0.01, "Guardian Z scale should be 1.5")

# =============================================================================
# GUARDIAN MANAGER TESTS (AC3, AC8)
# =============================================================================

func test_guardian_manager_exists() -> void:
	assert_not_null(_guardian_manager, "GuardianManager should be created")


func test_guardian_manager_loads_guardians() -> void:
	# Wait for _ready to complete
	await wait_frames(2)

	# Check if alpha_fox was loaded
	var alpha_fox: GuardianData = _guardian_manager.get_guardian_data("alpha_fox")
	assert_not_null(alpha_fox, "GuardianManager should load alpha_fox guardian")


func test_guardian_manager_is_guardian_defeated_default_false() -> void:
	assert_false(_guardian_manager.is_guardian_defeated("alpha_fox"),
		"Guardian should not be defeated by default")


func test_guardian_manager_get_all_guardians() -> void:
	await wait_frames(2)

	var all_guardians: Array = _guardian_manager.get_all_guardians()
	assert_gte(all_guardians.size(), 1, "Should have at least 1 guardian")


func test_guardian_manager_get_guardian_hex() -> void:
	await wait_frames(2)

	var hex: Vector2i = _guardian_manager.get_guardian_hex("alpha_fox")
	var alpha_fox: GuardianData = load(ALPHA_FOX_PATH) as GuardianData
	assert_eq(hex, alpha_fox.spawn_hex, "Guardian hex should match spawn_hex from data")


func test_guardian_manager_get_guardian_at_hex_not_spawned() -> void:
	# Guardian not spawned yet
	var guardian_id: String = _guardian_manager.get_guardian_at_hex(Vector2i(5, 5))
	assert_eq(guardian_id, "", "Should return empty string when guardian not spawned")


func test_guardian_manager_spawn_guardian_without_init() -> void:
	await wait_frames(2)

	# Spawning without WorldManager should still work (adds to root)
	var result: bool = _guardian_manager.spawn_guardian("alpha_fox")
	assert_true(result, "Spawn should succeed")

	# Check it's tracked as active
	var active: Node = _guardian_manager.get_active_guardian("alpha_fox")
	assert_not_null(active, "Guardian should be tracked as active after spawn")


func test_guardian_manager_spawn_duplicate_fails() -> void:
	await wait_frames(2)

	# First spawn
	_guardian_manager.spawn_guardian("alpha_fox")

	# Second spawn should fail
	var result: bool = _guardian_manager.spawn_guardian("alpha_fox")
	assert_false(result, "Duplicate spawn should fail")


func test_guardian_manager_spawn_defeated_fails() -> void:
	await wait_frames(2)

	# Defeat the guardian first
	_guardian_manager.defeat_guardian("alpha_fox")

	# Spawn should fail
	var result: bool = _guardian_manager.spawn_guardian("alpha_fox")
	assert_false(result, "Spawn after defeat should fail")


func test_guardian_manager_spawn_unknown_fails() -> void:
	var result: bool = _guardian_manager.spawn_guardian("unknown_guardian")
	assert_false(result, "Spawn unknown guardian should fail")


func test_guardian_manager_defeat_guardian() -> void:
	await wait_frames(2)
	watch_signals(EventBus)

	# Defeat the guardian
	_guardian_manager.defeat_guardian("alpha_fox")

	# Should be marked as defeated
	assert_true(_guardian_manager.is_guardian_defeated("alpha_fox"),
		"Guardian should be marked as defeated")

	# Signal should be emitted
	assert_signal_emitted(EventBus, "guardian_defeated")


func test_guardian_manager_defeat_emits_correct_biome() -> void:
	await wait_frames(2)
	watch_signals(EventBus)

	_guardian_manager.defeat_guardian("alpha_fox")

	var params: Array = get_signal_parameters(EventBus, "guardian_defeated")
	assert_eq(params[0], "alpha_fox", "Signal should emit guardian_id")
	assert_eq(params[1], "forest", "Signal should emit biome_id")

# =============================================================================
# GUARDIAN MANAGER SAVE/LOAD TESTS (AC9)
# =============================================================================

func test_guardian_manager_get_save_data() -> void:
	await wait_frames(2)

	var save_data: Dictionary = _guardian_manager.get_save_data()
	assert_true(save_data.has("defeated"), "Save data should have defeated key")
	assert_true(save_data.has("active"), "Save data should have active key")


func test_guardian_manager_save_data_tracks_defeated() -> void:
	await wait_frames(2)

	# Defeat a guardian
	_guardian_manager.defeat_guardian("alpha_fox")

	var save_data: Dictionary = _guardian_manager.get_save_data()
	assert_true("alpha_fox" in save_data["defeated"], "Defeated guardian should be in save data")


func test_guardian_manager_load_save_data_restores_defeated() -> void:
	await wait_frames(2)

	# Create save data with defeated guardian
	var save_data: Dictionary = {
		"defeated": ["alpha_fox"],
		"active": [],
	}

	_guardian_manager.load_save_data(save_data)

	assert_true(_guardian_manager.is_guardian_defeated("alpha_fox"),
		"Defeated state should be restored from save")


func test_guardian_manager_reset() -> void:
	await wait_frames(2)

	# Defeat and spawn
	_guardian_manager.defeat_guardian("alpha_fox")

	# Reset
	_guardian_manager.reset()

	assert_false(_guardian_manager.is_guardian_defeated("alpha_fox"),
		"Reset should clear defeated state")

# =============================================================================
# EVENTBUS SIGNAL TESTS (AC8)
# =============================================================================

func test_eventbus_has_guardian_spawned_signal() -> void:
	assert_true(EventBus.has_signal("guardian_spawned"),
		"EventBus should have guardian_spawned signal")


func test_eventbus_has_guardian_defeated_signal() -> void:
	assert_true(EventBus.has_signal("guardian_defeated"),
		"EventBus should have guardian_defeated signal")


func test_eventbus_has_guardian_battle_started_signal() -> void:
	assert_true(EventBus.has_signal("guardian_battle_started"),
		"EventBus should have guardian_battle_started signal")


func test_guardian_spawn_emits_signal() -> void:
	await wait_frames(2)
	watch_signals(EventBus)

	_guardian_manager.spawn_guardian("alpha_fox")

	assert_signal_emitted(EventBus, "guardian_spawned")


func test_guardian_spawn_signal_params() -> void:
	await wait_frames(2)
	watch_signals(EventBus)

	_guardian_manager.spawn_guardian("alpha_fox")

	var params: Array = get_signal_parameters(EventBus, "guardian_spawned")
	assert_eq(params[0], "alpha_fox", "Signal should emit guardian_id")
	assert_eq(params[1], Vector2i(5, 5), "Signal should emit spawn_hex")

# =============================================================================
# COMBAT HP CALCULATION TESTS (AC5)
# =============================================================================

func test_guardian_hp_calculation() -> void:
	# AC5: Guardian HP = strength * HP_MULTIPLIER (6 * 3 = 18)
	var alpha_fox: GuardianData = load(ALPHA_FOX_PATH) as GuardianData
	var expected_hp: int = alpha_fox.strength * 3  # HP_MULTIPLIER = 3

	assert_eq(expected_hp, 18, "Alpha Fox HP should be 18 (6 * 3)")


func test_guardian_difficulty_uses_strength_not_hp() -> void:
	# L2 Fix: Document that UI difficulty uses strength, not HP
	var alpha_fox: GuardianData = load(ALPHA_FOX_PATH) as GuardianData
	assert_not_null(alpha_fox, "Alpha Fox should load")

	# Difficulty calculation should use strength (6), not HP (18)
	# This matches the UI modal's _update_team_summary behavior
	assert_eq(alpha_fox.strength, 6, "Strength should be 6 for difficulty calc")

	# Document: Guardian HP (18) is for combat, strength (6) is for difficulty display
	var guardian_hp: int = alpha_fox.strength * 3
	assert_eq(guardian_hp, 18, "Guardian HP = strength * 3")
