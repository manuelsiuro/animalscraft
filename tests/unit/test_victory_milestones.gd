## Unit tests for Victory Milestones (Story 6-10)
##
## Tests victory condition detection, celebration enhancements,
## and endless mode behavior.
##
## Architecture: tests/unit/test_victory_milestones.gd
## Story: 6-10-implement-victory-conditions-endless
extends GutTest

# =============================================================================
# CONSTANTS
# =============================================================================

const MilestoneManagerScript := preload("res://autoloads/milestone_manager.gd")
const MilestoneDataScript := preload("res://scripts/systems/progression/milestone_data.gd")
const MilestoneCelebrationPopupScript := preload("res://scripts/ui/gameplay/milestone_celebration_popup.gd")

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _manager: Node = null


func before_each() -> void:
	_manager = MilestoneManagerScript.new()
	add_child(_manager)
	await wait_frames(2)


func after_each() -> void:
	if _manager and is_instance_valid(_manager):
		_manager.queue_free()
		_manager = null


# =============================================================================
# AC1: Victory Type Exists in Enum
# =============================================================================

func test_milestone_data_has_victory_type() -> void:
	# Verify VICTORY type exists in enum
	assert_true(MilestoneData.Type.has("VICTORY"), "MilestoneData.Type should have VICTORY")


func test_victory_type_enum_value() -> void:
	# VICTORY should be the 6th type (index 5)
	assert_eq(MilestoneData.Type.VICTORY, 5, "VICTORY should be enum value 5")


# =============================================================================
# AC2: Thriving Village Victory (50 animals)
# =============================================================================

func test_victory_thriving_village_resource_exists() -> void:
	var milestone := load("res://resources/milestones/victory_thriving_village.tres") as MilestoneData
	assert_not_null(milestone, "victory_thriving_village.tres should exist")
	assert_eq(milestone.id, "victory_thriving_village")
	assert_eq(milestone.type, MilestoneData.Type.VICTORY)
	assert_eq(milestone.threshold, 50)


func test_victory_thriving_village_triggers_at_50_animals() -> void:
	# Load the milestone
	var milestone := load("res://resources/milestones/victory_thriving_village.tres") as MilestoneData
	assert_not_null(milestone)

	# Manually add to manager
	_manager._milestones["victory_thriving_village"] = milestone

	# Set population to 50
	_manager._counts["population"] = 50

	# Check victory milestones
	_manager._check_victory_milestones()

	assert_true(_manager.is_milestone_achieved("victory_thriving_village"),
		"Victory should trigger at 50 animals")


func test_victory_thriving_village_does_not_trigger_below_50() -> void:
	var milestone := load("res://resources/milestones/victory_thriving_village.tres") as MilestoneData
	_manager._milestones["victory_thriving_village"] = milestone

	_manager._counts["population"] = 49
	_manager._check_victory_milestones()

	assert_false(_manager.is_milestone_achieved("victory_thriving_village"),
		"Victory should not trigger below 50 animals")


# =============================================================================
# AC3: Plains Conqueror Victory (80% territory)
# =============================================================================

func test_victory_plains_conqueror_resource_exists() -> void:
	var milestone := load("res://resources/milestones/victory_plains_conqueror.tres") as MilestoneData
	assert_not_null(milestone, "victory_plains_conqueror.tres should exist")
	assert_eq(milestone.id, "victory_plains_conqueror")
	assert_eq(milestone.type, MilestoneData.Type.VICTORY)
	assert_eq(milestone.threshold, 80)
	assert_eq(milestone.trigger_value, "territory_percentage")


func test_victory_plains_conqueror_triggers_at_80_percent() -> void:
	var milestone := load("res://resources/milestones/victory_plains_conqueror.tres") as MilestoneData
	_manager._milestones["victory_plains_conqueror"] = milestone

	# Set territory percentage to 80%
	_manager._territory_percentage = 80.0
	_manager._check_victory_milestones()

	assert_true(_manager.is_milestone_achieved("victory_plains_conqueror"),
		"Victory should trigger at 80% territory")


func test_victory_plains_conqueror_does_not_trigger_below_80_percent() -> void:
	var milestone := load("res://resources/milestones/victory_plains_conqueror.tres") as MilestoneData
	_manager._milestones["victory_plains_conqueror"] = milestone

	_manager._territory_percentage = 79.9
	_manager._check_victory_milestones()

	assert_false(_manager.is_milestone_achieved("victory_plains_conqueror"),
		"Victory should not trigger below 80% territory")


# =============================================================================
# AC4: Master Crafter Victory (first bread)
# =============================================================================

func test_victory_master_crafter_resource_exists() -> void:
	var milestone := load("res://resources/milestones/victory_master_crafter.tres") as MilestoneData
	assert_not_null(milestone, "victory_master_crafter.tres should exist")
	assert_eq(milestone.id, "victory_master_crafter")
	assert_eq(milestone.type, MilestoneData.Type.VICTORY)
	assert_eq(milestone.trigger_value, "bread")


func test_victory_master_crafter_triggers_on_first_bread() -> void:
	var milestone := load("res://resources/milestones/victory_master_crafter.tres") as MilestoneData
	_manager._milestones["victory_master_crafter"] = milestone

	# Simulate first bread production
	_manager._first_productions["bread"] = true
	_manager._check_victory_milestones()

	assert_true(_manager.is_milestone_achieved("victory_master_crafter"),
		"Victory should trigger on first bread production")


func test_victory_master_crafter_does_not_trigger_without_bread() -> void:
	var milestone := load("res://resources/milestones/victory_master_crafter.tres") as MilestoneData
	_manager._milestones["victory_master_crafter"] = milestone

	# No bread produced
	_manager._check_victory_milestones()

	assert_false(_manager.is_milestone_achieved("victory_master_crafter"),
		"Victory should not trigger without bread production")


# =============================================================================
# AC6: Multiple Victories Don't Re-trigger
# =============================================================================

func test_victory_milestones_do_not_retrigger() -> void:
	var milestone := load("res://resources/milestones/victory_thriving_village.tres") as MilestoneData
	_manager._milestones["victory_thriving_village"] = milestone

	watch_signals(EventBus)

	# First trigger
	_manager._counts["population"] = 50
	_manager._check_victory_milestones()
	assert_signal_emit_count(EventBus, "milestone_reached", 1)

	# Should not trigger again
	_manager._counts["population"] = 60
	_manager._check_victory_milestones()
	assert_signal_emit_count(EventBus, "milestone_reached", 1,
		"Milestone should not re-trigger once achieved")


# =============================================================================
# AC7: Victory Persistence
# =============================================================================

func test_victory_milestone_persists_in_save_data() -> void:
	var milestone := load("res://resources/milestones/victory_thriving_village.tres") as MilestoneData
	_manager._milestones["victory_thriving_village"] = milestone

	_manager._counts["population"] = 50
	_manager._territory_percentage = 85.0
	_manager._check_victory_milestones()

	var save_data: Dictionary = _manager.get_save_data()

	assert_true("victory_thriving_village" in save_data["achieved"],
		"Victory should be in save data")
	assert_eq(save_data["territory_percentage"], 85.0,
		"Territory percentage should be saved")


func test_victory_milestone_loads_from_save_data() -> void:
	var milestone := load("res://resources/milestones/victory_thriving_village.tres") as MilestoneData
	_manager._milestones["victory_thriving_village"] = milestone

	var save_data := {
		"achieved": ["victory_thriving_village"],
		"counts": {"population": 55, "territory": 100, "combat_wins": 5},
		"first_buildings": [],
		"first_productions": ["bread"],
		"territory_percentage": 90.0,
	}

	_manager.load_save_data(save_data)

	assert_true(_manager.is_milestone_achieved("victory_thriving_village"),
		"Victory should be restored from save")
	assert_eq(_manager._territory_percentage, 90.0,
		"Territory percentage should be restored")


# =============================================================================
# AC8: Victory Progress Tracking
# =============================================================================

func test_get_victory_progress_population() -> void:
	_manager._counts["population"] = 25

	var progress: Dictionary = _manager.get_victory_progress("population")

	assert_eq(progress["current"], 25)
	assert_eq(progress["target"], 50)
	assert_false(progress["achieved"])


func test_get_victory_progress_territory() -> void:
	_manager._territory_percentage = 65.0

	var progress: Dictionary = _manager.get_victory_progress("territory")

	assert_eq(progress["current"], 65)
	assert_eq(progress["target"], 80)
	assert_false(progress["achieved"])


func test_get_victory_progress_production() -> void:
	_manager._first_productions["bread"] = true

	var progress: Dictionary = _manager.get_victory_progress("production")

	assert_true(progress["current"])
	assert_true(progress["target"])
	assert_false(progress["achieved"], "Victory not achieved until milestone triggers")


func test_get_victory_progress_invalid_type() -> void:
	var progress: Dictionary = _manager.get_victory_progress("invalid")

	assert_true(progress.is_empty(), "Invalid type should return empty dictionary")


# =============================================================================
# AC9: Victory Celebration Style
# =============================================================================

func test_type_icons_includes_victory() -> void:
	# Check that VICTORY icon is defined
	var icons: Dictionary = MilestoneCelebrationPopupScript.TYPE_ICONS
	assert_true(icons.has(MilestoneData.Type.VICTORY),
		"TYPE_ICONS should include VICTORY type")
	assert_eq(icons[MilestoneData.Type.VICTORY], "🏆",
		"VICTORY icon should be trophy emoji")


func test_type_colors_includes_victory() -> void:
	var colors: Dictionary = MilestoneCelebrationPopupScript.TYPE_COLORS
	assert_true(colors.has(MilestoneData.Type.VICTORY),
		"TYPE_COLORS should include VICTORY type")


func test_victory_confetti_multiplier_exists() -> void:
	assert_eq(MilestoneCelebrationPopupScript.VICTORY_CONFETTI_MULTIPLIER, 2,
		"Victory confetti multiplier should be 2")


func test_victory_auto_dismiss_time_longer() -> void:
	assert_gt(MilestoneCelebrationPopupScript.VICTORY_AUTO_DISMISS_TIME,
		MilestoneCelebrationPopupScript.AUTO_DISMISS_TIME,
		"Victory auto-dismiss time should be longer than regular")


# =============================================================================
# AC5: No Game Over State (Endless Mode)
# =============================================================================

func test_victory_milestones_have_no_game_over_reward() -> void:
	# Load all victory milestones and verify they don't trigger game over
	var thriving := load("res://resources/milestones/victory_thriving_village.tres") as MilestoneData
	var conqueror := load("res://resources/milestones/victory_plains_conqueror.tres") as MilestoneData
	var crafter := load("res://resources/milestones/victory_master_crafter.tres") as MilestoneData

	# Verify none have special game-ending rewards
	assert_true(thriving.unlock_rewards.is_empty(),
		"Thriving Village should have no unlock rewards")
	assert_true(conqueror.unlock_rewards.is_empty(),
		"Plains Conqueror should have no unlock rewards")
	assert_true(crafter.unlock_rewards.is_empty(),
		"Master Crafter should have no unlock rewards")


func test_manager_continues_after_all_victories() -> void:
	# Load all victory milestones
	var thriving := load("res://resources/milestones/victory_thriving_village.tres") as MilestoneData
	var conqueror := load("res://resources/milestones/victory_plains_conqueror.tres") as MilestoneData
	var crafter := load("res://resources/milestones/victory_master_crafter.tres") as MilestoneData

	_manager._milestones["victory_thriving_village"] = thriving
	_manager._milestones["victory_plains_conqueror"] = conqueror
	_manager._milestones["victory_master_crafter"] = crafter

	# Achieve all victories
	_manager._counts["population"] = 50
	_manager._territory_percentage = 80.0
	_manager._first_productions["bread"] = true
	_manager._check_victory_milestones()

	# Manager should still be valid and operational
	assert_true(is_instance_valid(_manager), "Manager should still be valid")
	assert_true(_manager.is_milestone_achieved("victory_thriving_village"))
	assert_true(_manager.is_milestone_achieved("victory_plains_conqueror"))
	assert_true(_manager.is_milestone_achieved("victory_master_crafter"))

	# Should still be able to track further progress
	_manager._counts["population"] = 100
	var progress: Dictionary = _manager.get_victory_progress("population")
	assert_eq(progress["current"], 100, "Progress tracking should continue after victory")


# =============================================================================
# INTEGRATION: Multiple Simultaneous Victories
# =============================================================================

func test_multiple_victories_trigger_independently() -> void:
	var thriving := load("res://resources/milestones/victory_thriving_village.tres") as MilestoneData
	var crafter := load("res://resources/milestones/victory_master_crafter.tres") as MilestoneData

	_manager._milestones["victory_thriving_village"] = thriving
	_manager._milestones["victory_master_crafter"] = crafter

	watch_signals(EventBus)

	# Trigger both conditions
	_manager._counts["population"] = 50
	_manager._first_productions["bread"] = true
	_manager._check_victory_milestones()

	assert_signal_emit_count(EventBus, "milestone_reached", 2,
		"Both victories should trigger")
	assert_true(_manager.is_milestone_achieved("victory_thriving_village"))
	assert_true(_manager.is_milestone_achieved("victory_master_crafter"))


# =============================================================================
# EDGE CASES
# =============================================================================

func test_victory_at_exact_threshold() -> void:
	var milestone := load("res://resources/milestones/victory_plains_conqueror.tres") as MilestoneData
	_manager._milestones["victory_plains_conqueror"] = milestone

	# Exactly 80%
	_manager._territory_percentage = 80.0
	_manager._check_victory_milestones()

	assert_true(_manager.is_milestone_achieved("victory_plains_conqueror"),
		"Victory should trigger at exactly 80%")


func test_victory_progress_after_achievement() -> void:
	var milestone := load("res://resources/milestones/victory_thriving_village.tres") as MilestoneData
	_manager._milestones["victory_thriving_village"] = milestone
	_manager._achieved["victory_thriving_village"] = true

	var progress: Dictionary = _manager.get_victory_progress("population")

	assert_true(progress["achieved"], "Progress should show achieved status")


func test_reset_clears_territory_percentage() -> void:
	_manager._territory_percentage = 75.0
	_manager.reset()

	assert_eq(_manager._territory_percentage, 0.0,
		"Territory percentage should reset to 0")
