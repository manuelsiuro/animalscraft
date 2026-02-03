## Unit tests for BiomeManager autoload.
##
## Tests biome unlock state, milestone integration, and persistence.
##
## Architecture: tests/unit/test_biome_manager.gd
## Story: 6-11-implement-biome-unlock-preparation
extends GutTest

# =============================================================================
# TEST DATA
# =============================================================================

## Store original biome state for restoration
var _original_unlocked: Dictionary = {}

# =============================================================================
# LIFECYCLE
# =============================================================================

func before_each() -> void:
	# Store original state
	_original_unlocked = BiomeManager._unlocked.duplicate()

	# Reset for clean test
	BiomeManager.reset()
	await wait_frames(1)


func after_each() -> void:
	# Restore original state
	BiomeManager._unlocked = _original_unlocked.duplicate()


# =============================================================================
# TEST: BIOME DATA RESOURCE (AC4)
# =============================================================================

func test_biome_data_resource_loads() -> void:
	# Arrange - load plains biome
	var biome := load("res://resources/biomes/plains.tres") as BiomeData

	# Assert
	assert_not_null(biome, "Biome resource should load (AC4)")
	assert_eq(biome.id, "plains", "Biome should have correct ID")
	assert_eq(biome.display_name, "The Plains", "Biome should have display name")
	assert_true(biome.is_starting_biome, "Plains should be starting biome (AC6)")


func test_biome_data_has_required_properties() -> void:
	# Arrange - load forest biome
	var biome := load("res://resources/biomes/forest.tres") as BiomeData

	# Assert - verify all properties exist (AC4)
	assert_eq(biome.id, "forest", "Should have id property")
	assert_eq(biome.display_name, "The Forest", "Should have display_name property")
	assert_false(biome.description.is_empty(), "Should have description property")
	assert_eq(biome.unlock_milestone, "forest_border", "Should have unlock_milestone property")
	assert_true(biome.terrain_types.size() > 0, "Should have terrain_types array")
	assert_true(biome.animal_types.size() > 0, "Should have animal_types array")
	assert_false(biome.is_starting_biome, "Forest should not be starting biome")


# =============================================================================
# TEST: BIOME MANAGER INITIALIZATION (AC5)
# =============================================================================

func test_biome_manager_loads_all_biomes() -> void:
	# Assert - BiomeManager should have loaded biomes
	var biomes := BiomeManager.get_all_biomes()
	assert_eq(biomes.size(), 2, "Should have loaded 2 biomes (plains, forest)")


func test_biome_manager_has_plains_and_forest() -> void:
	# Assert
	var plains := BiomeManager.get_biome("plains")
	var forest := BiomeManager.get_biome("forest")

	assert_not_null(plains, "Plains biome should be loaded")
	assert_not_null(forest, "Forest biome should be loaded")


# =============================================================================
# TEST: STARTING BIOME - PLAINS (AC6)
# =============================================================================

func test_plains_is_unlocked_by_default() -> void:
	# Assert - Plains should be unlocked as starting biome (AC6)
	assert_true(BiomeManager.is_biome_unlocked("plains"), "Plains should be unlocked by default (AC6)")


func test_plains_is_always_unlocked_after_reset() -> void:
	# Act
	BiomeManager.reset()
	await wait_frames(1)

	# Assert - Plains should still be unlocked after reset
	assert_true(BiomeManager.is_biome_unlocked("plains"), "Plains should remain unlocked after reset (AC6)")


func test_get_unlocked_biomes_includes_plains() -> void:
	# Act
	var unlocked := BiomeManager.get_unlocked_biomes()

	# Assert
	assert_true(unlocked.has("plains"), "Unlocked biomes should include plains (AC6)")


# =============================================================================
# TEST: FOREST INITIALLY LOCKED (AC7)
# =============================================================================

func test_forest_is_locked_initially() -> void:
	# Assert - Forest should be locked until milestone achieved (AC7)
	assert_false(BiomeManager.is_biome_unlocked("forest"), "Forest should be locked initially (AC7)")


func test_get_unlocked_biomes_excludes_forest_initially() -> void:
	# Act
	var unlocked := BiomeManager.get_unlocked_biomes()

	# Assert
	assert_false(unlocked.has("forest"), "Unlocked biomes should not include forest initially (AC7)")


# =============================================================================
# TEST: BIOME UNLOCK MECHANISM (AC3)
# =============================================================================

func test_unlock_biome_unlocks_forest() -> void:
	# Arrange
	watch_signals(EventBus)

	# Act
	BiomeManager.unlock_biome("forest")
	await wait_frames(1)

	# Assert
	assert_true(BiomeManager.is_biome_unlocked("forest"), "Forest should be unlocked after unlock_biome (AC3)")
	assert_signal_emitted(EventBus, "biome_unlocked", "biome_unlocked signal should emit (AC3)")


func test_unlock_biome_emits_biome_unlocked_signal() -> void:
	# Arrange
	watch_signals(EventBus)

	# Act
	BiomeManager.unlock_biome("forest")
	await wait_frames(1)

	# Assert - verify signal emitted with correct parameter (AC3)
	assert_signal_emitted_with_parameters(EventBus, "biome_unlocked", ["forest"])


func test_unlock_biome_does_not_double_trigger() -> void:
	# Arrange
	watch_signals(EventBus)
	BiomeManager.unlock_biome("forest")
	await wait_frames(1)

	# Act - try to unlock again
	BiomeManager.unlock_biome("forest")
	await wait_frames(1)

	# Assert - should only emit once
	assert_signal_emit_count(EventBus, "biome_unlocked", 1, "Should not emit twice for same biome")


func test_unlock_unknown_biome_logs_warning() -> void:
	# Act - try to unlock non-existent biome
	BiomeManager.unlock_biome("nonexistent")

	# Assert - should not crash (graceful handling)
	assert_false(BiomeManager.is_biome_unlocked("nonexistent"), "Unknown biome should not be unlocked")


# =============================================================================
# TEST: MILESTONE INTEGRATION (AC1, AC2, AC3)
# =============================================================================

func test_forest_border_milestone_exists() -> void:
	# Arrange - load forest_border milestone
	var milestone := load("res://resources/milestones/forest_border.tres") as MilestoneData

	# Assert (AC1)
	assert_not_null(milestone, "forest_border milestone should exist (AC1)")
	assert_eq(milestone.id, "forest_border", "Should have correct id (AC1)")
	assert_eq(milestone.type, MilestoneData.Type.TERRITORY, "Should be TERRITORY type (AC1)")
	assert_eq(milestone.threshold, 80, "Should have 80% threshold (AC1)")
	assert_eq(milestone.trigger_value, "territory_percentage", "Should use territory_percentage trigger")


func test_forest_border_milestone_has_future_content_message() -> void:
	# Arrange - load forest_border milestone
	var milestone := load("res://resources/milestones/forest_border.tres") as MilestoneData

	# Assert (AC9)
	assert_true(milestone.description.contains("future"), "Description should mention future content (AC9)")


func test_milestone_reached_unlocks_forest() -> void:
	# Arrange
	watch_signals(EventBus)

	# Act - emit milestone_reached for forest_border
	EventBus.milestone_reached.emit("forest_border")
	await wait_frames(1)

	# Assert
	assert_true(BiomeManager.is_biome_unlocked("forest"), "Forest should be unlocked after forest_border milestone (AC2, AC3)")
	assert_signal_emitted(EventBus, "biome_unlocked", "biome_unlocked signal should emit (AC3)")


func test_unrelated_milestone_does_not_unlock_forest() -> void:
	# Arrange
	watch_signals(EventBus)

	# Act - emit milestone_reached for unrelated milestone
	EventBus.milestone_reached.emit("pop_5")
	await wait_frames(1)

	# Assert
	assert_false(BiomeManager.is_biome_unlocked("forest"), "Forest should not be unlocked by unrelated milestone")


# =============================================================================
# TEST: MILESTONE MANAGER INTEGRATION (AC2 - Full Flow)
# =============================================================================

func test_forest_border_uses_territory_percentage_trigger() -> void:
	# Verify forest_border milestone is configured for percentage-based triggering
	var milestone := load("res://resources/milestones/forest_border.tres") as MilestoneData

	# Assert - must use territory_percentage trigger (not raw count)
	assert_eq(milestone.trigger_value, "territory_percentage", "forest_border must use percentage trigger (AC2)")
	assert_eq(milestone.type, MilestoneData.Type.TERRITORY, "forest_border should be TERRITORY type")
	assert_eq(milestone.threshold, 80, "forest_border should trigger at 80%")


# =============================================================================
# TEST: SAVE/LOAD INTEGRATION (AC8)
# =============================================================================

func test_get_save_data_includes_unlocked_biomes() -> void:
	# Arrange
	BiomeManager.unlock_biome("forest")

	# Act
	var save_data := BiomeManager.get_save_data()

	# Assert (AC8)
	assert_true(save_data.has("unlocked"), "Save data should have unlocked key (AC8)")
	assert_true(save_data["unlocked"].has("plains"), "Save data should include plains (AC8)")
	assert_true(save_data["unlocked"].has("forest"), "Save data should include forest (AC8)")


func test_load_save_data_restores_unlocked_biomes() -> void:
	# Arrange
	var save_data := {
		"unlocked": ["plains", "forest"],
	}

	# Act
	BiomeManager.load_save_data(save_data)
	await wait_frames(1)

	# Assert (AC8)
	assert_true(BiomeManager.is_biome_unlocked("plains"), "Plains should be restored (AC8)")
	assert_true(BiomeManager.is_biome_unlocked("forest"), "Forest should be restored (AC8)")


func test_load_save_data_always_includes_starting_biomes() -> void:
	# Arrange - save data without plains (corrupted/old format)
	var save_data := {
		"unlocked": ["forest"],
	}

	# Act
	BiomeManager.load_save_data(save_data)
	await wait_frames(1)

	# Assert - Plains should still be unlocked as starting biome
	assert_true(BiomeManager.is_biome_unlocked("plains"), "Plains should be unlocked even if not in save (AC8)")
	assert_true(BiomeManager.is_biome_unlocked("forest"), "Forest should be restored from save (AC8)")


func test_load_ignores_unknown_biome_ids() -> void:
	# Arrange - save data with unknown biome
	var save_data := {
		"unlocked": ["plains", "unknown_biome"],
	}

	# Act
	BiomeManager.load_save_data(save_data)
	await wait_frames(1)

	# Assert - should not crash
	assert_true(BiomeManager.is_biome_unlocked("plains"), "Plains should be unlocked")
	assert_false(BiomeManager.is_biome_unlocked("unknown_biome"), "Unknown biome should not be added")


func test_reset_clears_unlocked_except_starting() -> void:
	# Arrange
	BiomeManager.unlock_biome("forest")
	assert_true(BiomeManager.is_biome_unlocked("forest"), "Forest should be unlocked initially")

	# Act
	BiomeManager.reset()
	await wait_frames(1)

	# Assert
	assert_true(BiomeManager.is_biome_unlocked("plains"), "Plains should remain unlocked after reset")
	assert_false(BiomeManager.is_biome_unlocked("forest"), "Forest should be locked after reset")


# =============================================================================
# TEST: BIOME QUERIES
# =============================================================================

func test_get_biome_returns_correct_data() -> void:
	# Act
	var plains := BiomeManager.get_biome("plains")

	# Assert
	assert_eq(plains.id, "plains", "Should return correct biome")
	assert_eq(plains.display_name, "The Plains", "Should have correct display name")


func test_get_biome_returns_null_for_unknown() -> void:
	# Act
	var unknown := BiomeManager.get_biome("nonexistent")

	# Assert
	assert_null(unknown, "Should return null for unknown biome")


func test_get_all_biomes_returns_array() -> void:
	# Act
	var biomes := BiomeManager.get_all_biomes()

	# Assert
	assert_true(biomes is Array, "Should return array")
	assert_eq(biomes.size(), 2, "Should have 2 biomes")
