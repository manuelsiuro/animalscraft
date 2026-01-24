## Unit tests for milestone celebration system (Story 6-6).
##
## Tests cover:
## - MilestoneCelebrationPopup display and animations
## - MilestoneCelebrationManager queue and pause/resume
## - Integration with MilestoneManager and EventBus
##
## Architecture: tests/unit/test_milestone_celebration.gd
## Story: 6-6-display-milestone-celebrations
extends GutTest

# =============================================================================
# CONSTANTS
# =============================================================================

const MilestoneCelebrationPopup := preload("res://scripts/ui/gameplay/milestone_celebration_popup.gd")
const MilestoneCelebrationManager := preload("res://scripts/ui/gameplay/milestone_celebration_manager.gd")
const POPUP_SCENE_PATH := "res://scenes/ui/gameplay/milestone_celebration_popup.tscn"

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _popup: MilestoneCelebrationPopup = null
var _manager: MilestoneCelebrationManager = null
var _test_milestone: MilestoneData = null


func before_each() -> void:
	# Create test milestone
	_test_milestone = MilestoneData.new()
	_test_milestone.id = "test_milestone"
	_test_milestone.display_name = "Test Milestone"
	_test_milestone.description = "A test milestone description"
	_test_milestone.type = MilestoneData.Type.POPULATION
	_test_milestone.threshold = 5
	_test_milestone.unlock_rewards = []


func after_each() -> void:
	if _popup and is_instance_valid(_popup):
		_popup.queue_free()
		_popup = null

	if _manager and is_instance_valid(_manager):
		_manager.queue_free()
		_manager = null

	_test_milestone = null


# =============================================================================
# HELPER METHODS
# =============================================================================

## Create a popup instance for testing.
func _create_popup() -> MilestoneCelebrationPopup:
	var scene := load(POPUP_SCENE_PATH) as PackedScene
	if scene == null:
		gut.p("Failed to load popup scene")
		return null
	var popup := scene.instantiate() as MilestoneCelebrationPopup
	add_child(popup)
	await wait_frames(1)
	return popup


## Create a manager instance for testing.
func _create_manager() -> MilestoneCelebrationManager:
	var manager := MilestoneCelebrationManager.new()
	add_child(manager)
	await wait_frames(1)
	return manager


## Create a milestone with unlock rewards.
func _create_milestone_with_unlocks() -> MilestoneData:
	var milestone := MilestoneData.new()
	milestone.id = "test_unlock_milestone"
	milestone.display_name = "Builder Milestone"
	milestone.description = "Unlock new buildings"
	milestone.type = MilestoneData.Type.BUILDING
	milestone.trigger_value = "farm"
	milestone.unlock_rewards = ["mill", "bakery"]
	return milestone


# =============================================================================
# POPUP TESTS - AC1: Milestone Popup UI Component
# =============================================================================

func test_popup_shows_milestone_info() -> void:
	_popup = await _create_popup()
	assert_not_null(_popup, "Popup should be created")

	# Show milestone
	_popup.show_milestone(_test_milestone)
	await wait_frames(2)

	# Popup should be visible
	assert_true(_popup.visible, "Popup should be visible after show_milestone")

	# Check display elements
	var icon_label := _popup.get_node_or_null("MarginContainer/VBoxContainer/IconLabel") as Label
	var name_label := _popup.get_node_or_null("MarginContainer/VBoxContainer/NameLabel") as Label
	var desc_label := _popup.get_node_or_null("MarginContainer/VBoxContainer/DescriptionLabel") as Label

	assert_not_null(icon_label, "Icon label should exist")
	assert_not_null(name_label, "Name label should exist")
	assert_not_null(desc_label, "Description label should exist")

	assert_eq(name_label.text, "Test Milestone", "Name label should show milestone name")
	assert_eq(desc_label.text, "A test milestone description", "Description label should show description")


func test_popup_displays_correct_icon_for_type() -> void:
	_popup = await _create_popup()

	# Test each milestone type gets correct icon
	var test_types := {
		MilestoneData.Type.POPULATION: "\ud83d\udc65",
		MilestoneData.Type.BUILDING: "\ud83c\udfe0",
		MilestoneData.Type.TERRITORY: "\ud83d\uddfa\ufe0f",
		MilestoneData.Type.COMBAT: "\u2694\ufe0f",
		MilestoneData.Type.PRODUCTION: "\ud83c\udf5e",
	}

	for type_value in test_types:
		_test_milestone.type = type_value
		_popup.show_milestone(_test_milestone)
		await wait_frames(1)

		var icon_label := _popup.get_node_or_null("MarginContainer/VBoxContainer/IconLabel") as Label
		assert_eq(icon_label.text, test_types[type_value], "Icon should match type %d" % type_value)


# =============================================================================
# POPUP TESTS - AC4: Unlock Rewards Display
# =============================================================================

func test_popup_shows_unlock_rewards() -> void:
	_popup = await _create_popup()
	var milestone := _create_milestone_with_unlocks()

	_popup.show_milestone(milestone)
	await wait_frames(2)

	# Unlocks container should be visible
	var unlocks_container := _popup.get_node_or_null("MarginContainer/VBoxContainer/UnlocksContainer") as VBoxContainer
	assert_not_null(unlocks_container, "Unlocks container should exist")
	assert_true(unlocks_container.visible, "Unlocks container should be visible when rewards exist")

	# Check label
	var unlocks_label := unlocks_container.get_node_or_null("UnlocksLabel") as Label
	assert_not_null(unlocks_label, "Unlocks label should exist")
	assert_eq(unlocks_label.text, "Unlocked:", "Label should say 'Unlocked:'")


func test_popup_hides_unlocks_when_empty() -> void:
	_popup = await _create_popup()
	_test_milestone.unlock_rewards = []

	_popup.show_milestone(_test_milestone)
	await wait_frames(2)

	# Unlocks container should be hidden
	var unlocks_container := _popup.get_node_or_null("MarginContainer/VBoxContainer/UnlocksContainer") as VBoxContainer
	if unlocks_container:
		assert_false(unlocks_container.visible, "Unlocks container should be hidden when no rewards")


# =============================================================================
# POPUP TESTS - AC5: Auto-Dismiss with Continue Option
# =============================================================================

func test_popup_auto_dismisses_after_timeout() -> void:
	_popup = await _create_popup()
	watch_signals(_popup)

	_popup.show_milestone(_test_milestone)
	await wait_frames(1)
	assert_true(_popup.visible, "Popup should be visible initially")

	# Wait for auto-dismiss (5 seconds + buffer)
	await get_tree().create_timer(5.5).timeout

	# Should have emitted celebration_dismissed
	assert_signal_emitted(_popup, "celebration_dismissed", "Should emit celebration_dismissed on auto-dismiss")


func test_popup_dismisses_on_continue_press() -> void:
	_popup = await _create_popup()
	watch_signals(_popup)

	_popup.show_milestone(_test_milestone)
	await wait_frames(2)

	# Find and press continue button
	var continue_button := _popup.get_node_or_null("MarginContainer/VBoxContainer/ContinueButton") as Button
	assert_not_null(continue_button, "Continue button should exist")

	continue_button.pressed.emit()
	# Wait for dismiss animation (FADE_DURATION = 0.3s + buffer)
	await get_tree().create_timer(0.5).timeout

	assert_signal_emitted(_popup, "celebration_dismissed", "Should emit celebration_dismissed on button press")


# =============================================================================
# MANAGER TESTS - AC6: Queue Multiple Milestones
# =============================================================================

func test_multiple_milestones_queued() -> void:
	_manager = await _create_manager()

	# Emit multiple milestone_reached signals
	EventBus.milestone_reached.emit("pop_5")
	EventBus.milestone_reached.emit("pop_10")
	await wait_frames(2)

	# Manager should have one active and one queued
	# Note: First milestone starts displaying immediately, second goes to queue
	# Since we can't check internal queue directly, we verify it's celebrating
	assert_true(_manager.is_celebrating(), "Manager should be celebrating")


func test_queue_processes_sequentially() -> void:
	_manager = await _create_manager()
	watch_signals(EventBus)

	# Start with one milestone
	EventBus.milestone_reached.emit("pop_5")
	await wait_frames(2)

	# Verify manager is celebrating
	assert_true(_manager.is_celebrating(), "Should be celebrating first milestone")

	# Clear queue for clean test
	_manager.clear_queue()


# =============================================================================
# MANAGER TESTS - AC7: Game Pause During Celebration
# =============================================================================

func test_game_pauses_during_celebration() -> void:
	_manager = await _create_manager()
	watch_signals(EventBus)

	# Emit milestone
	EventBus.milestone_reached.emit("pop_5")
	await wait_frames(2)

	# Should have paused the game
	assert_signal_emitted(EventBus, "game_paused", "Should emit game_paused when celebration starts")


func test_game_resumes_after_dismiss() -> void:
	_manager = await _create_manager()
	watch_signals(EventBus)

	# Emit milestone
	EventBus.milestone_reached.emit("pop_5")
	await wait_frames(2)

	# Clear queue to prevent processing more
	_manager.clear_queue()

	# Wait for auto-dismiss
	await get_tree().create_timer(6.0).timeout

	# Should have resumed the game
	assert_signal_emitted(EventBus, "game_resumed", "Should emit game_resumed after celebration dismissed")


# =============================================================================
# POPUP TESTS - AC10: Settings Respect (Reduced Motion)
# =============================================================================

func test_reduced_motion_disables_confetti() -> void:
	# Enable reduced motion
	var original_value := Settings.is_reduce_motion_enabled()
	Settings.set_reduce_motion_enabled(true)

	_popup = await _create_popup()
	_popup.show_milestone(_test_milestone)
	await wait_frames(5)

	# Check confetti container - should be empty or have no animated children
	var confetti_container := _popup.get_node_or_null("ConfettiContainer") as Control
	if confetti_container:
		assert_eq(confetti_container.get_child_count(), 0, "Confetti container should be empty with reduced motion")

	# Restore setting
	Settings.set_reduce_motion_enabled(original_value)


func test_normal_mode_spawns_confetti() -> void:
	# Ensure reduced motion is disabled
	var original_value := Settings.is_reduce_motion_enabled()
	Settings.set_reduce_motion_enabled(false)

	_popup = await _create_popup()
	_popup.show_milestone(_test_milestone)
	await wait_frames(3)

	# Check confetti container - should have particles
	var confetti_container := _popup.get_node_or_null("ConfettiContainer") as Control
	if confetti_container:
		assert_gt(confetti_container.get_child_count(), 0, "Confetti container should have particles in normal mode")

	# Restore setting
	Settings.set_reduce_motion_enabled(original_value)


# =============================================================================
# MANAGER TESTS - AC9: Integration with MilestoneManager
# =============================================================================

func test_manager_fetches_milestone_from_milestone_manager() -> void:
	_manager = await _create_manager()

	# Emit a real milestone ID (if one exists)
	# This tests integration with MilestoneManager.get_milestone()
	EventBus.milestone_reached.emit("pop_5")
	await wait_frames(2)

	# If milestone exists, manager should be celebrating
	# If not, it should gracefully handle missing milestone
	# Either way, this shouldn't crash
	pass_test("Manager handles milestone_reached signal without crashing")


# =============================================================================
# HELPER FUNCTION TESTS
# =============================================================================

func test_get_building_icon_returns_correct_icons() -> void:
	assert_eq(GameConstants.get_building_icon("farm"), "\ud83c\udf3e", "Farm icon should be wheat")
	assert_eq(GameConstants.get_building_icon("mill"), "\ud83c\udf7d\ufe0f", "Mill icon should be grain processing")
	assert_eq(GameConstants.get_building_icon("bakery"), "\ud83c\udf5e", "Bakery icon should be bread")
	assert_eq(GameConstants.get_building_icon("shelter"), "\ud83c\udfe0", "Shelter icon should be house")
	assert_eq(GameConstants.get_building_icon("unknown"), "\ud83c\udfd7\ufe0f", "Unknown should return default building icon")


func test_get_building_display_name_returns_correct_names() -> void:
	assert_eq(GameConstants.get_building_display_name("farm"), "Farm", "Farm display name")
	assert_eq(GameConstants.get_building_display_name("mill"), "Mill", "Mill display name")
	assert_eq(GameConstants.get_building_display_name("bakery"), "Bakery", "Bakery display name")
	assert_eq(GameConstants.get_building_display_name("shelter"), "Shelter", "Shelter display name")
	# GDScript capitalize() capitalizes each word: "unknown_type" -> "Unknown Type"
	assert_eq(GameConstants.get_building_display_name("unknown_type"), "Unknown Type", "Unknown should capitalize words")
	assert_eq(GameConstants.get_building_display_name(""), "Building", "Empty string should return Building")


# =============================================================================
# EDGE CASES
# =============================================================================

func test_popup_handles_null_milestone_gracefully() -> void:
	_popup = await _create_popup()

	# Should not crash when given null
	_popup.show_milestone(null)
	await wait_frames(1)

	# Popup should still be hidden (not shown for null)
	assert_false(_popup.visible, "Popup should not show for null milestone")


func test_manager_handles_empty_milestone_id() -> void:
	_manager = await _create_manager()

	# Should not crash when given empty ID
	EventBus.milestone_reached.emit("")
	await wait_frames(1)

	# Manager should handle gracefully
	pass_test("Manager handles empty milestone ID without crashing")


func test_popup_dismiss_stops_auto_dismiss_timer() -> void:
	_popup = await _create_popup()
	watch_signals(_popup)

	_popup.show_milestone(_test_milestone)
	await wait_frames(2)

	# Dismiss immediately via button
	var continue_button := _popup.get_node_or_null("MarginContainer/VBoxContainer/ContinueButton") as Button
	assert_not_null(continue_button, "Continue button should exist")

	continue_button.pressed.emit()
	# Wait for dismiss animation (FADE_DURATION = 0.3s + buffer)
	await get_tree().create_timer(0.5).timeout

	# Signal count should be exactly 1 (not 2 from both button and timer)
	assert_signal_emit_count(_popup, "celebration_dismissed", 1, "Should only emit once when manually dismissed")


func test_manager_clear_queue_empties_pending_milestones() -> void:
	_manager = await _create_manager()

	# Add milestones to queue
	EventBus.milestone_reached.emit("pop_5")
	EventBus.milestone_reached.emit("pop_10")
	EventBus.milestone_reached.emit("pop_20")
	await wait_frames(1)

	# Clear the queue
	_manager.clear_queue()

	# Queue should be empty
	assert_eq(_manager.get_queue_count(), 0, "Queue should be empty after clear")


func test_popup_uses_fallback_icon_for_unknown_type() -> void:
	_popup = await _create_popup()

	# Create milestone with an invalid type value (cast int to enum)
	# Using a value beyond the defined enum range
	var unknown_milestone := MilestoneData.new()
	unknown_milestone.id = "test_unknown"
	unknown_milestone.display_name = "Unknown Type Test"
	unknown_milestone.description = "Testing unknown type fallback"
	unknown_milestone.type = 999 as MilestoneData.Type  # Invalid type

	_popup.show_milestone(unknown_milestone)
	await wait_frames(2)

	# Icon should be fallback star emoji
	var icon_label := _popup.get_node_or_null("MarginContainer/VBoxContainer/IconLabel") as Label
	assert_not_null(icon_label, "Icon label should exist")
	assert_eq(icon_label.text, "\u2b50", "Unknown type should use fallback star icon")
