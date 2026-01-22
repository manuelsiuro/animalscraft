## Unit tests for BattleResultPanel recruitment UI.
## Tests recruitment selection, checkbox behavior, signals, and edge cases.
##
## Story: 5-8-implement-animal-capture
extends GutTest

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _panel: BattleResultPanel
var _recruitment_confirmed_received: Array = []


func before_each() -> void:
	# Create panel
	_panel = BattleResultPanel.new()
	add_child(_panel)
	await wait_frames(1)

	# Track recruitment_confirmed signal
	_recruitment_confirmed_received.clear()
	_panel.recruitment_confirmed.connect(_on_recruitment_confirmed)


func after_each() -> void:
	_recruitment_confirmed_received.clear()

	if is_instance_valid(_panel):
		if _panel.recruitment_confirmed.is_connected(_on_recruitment_confirmed):
			_panel.recruitment_confirmed.disconnect(_on_recruitment_confirmed)
		_panel.queue_free()


func _on_recruitment_confirmed(selected_animals: Array) -> void:
	_recruitment_confirmed_received.append(selected_animals)


# =============================================================================
# MOCK HELPERS
# =============================================================================

func _create_mock_stats_container() -> VBoxContainer:
	var stats_container := VBoxContainer.new()
	stats_container.name = "StatsContainer"

	var turns_label := Label.new()
	turns_label.name = "TurnsLabel"
	stats_container.add_child(turns_label)

	var damage_label := Label.new()
	damage_label.name = "DamageLabel"
	stats_container.add_child(damage_label)

	var captured_label := Label.new()
	captured_label.name = "CapturedLabel"
	stats_container.add_child(captured_label)

	return stats_container


func _setup_panel_with_ui() -> void:
	# Create minimal UI structure needed for tests
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	margin.add_child(vbox)

	var title := Label.new()
	title.name = "TitleLabel"
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	vbox.add_child(subtitle)

	var stats := _create_mock_stats_container()
	vbox.add_child(stats)

	var celebration := HBoxContainer.new()
	celebration.name = "CelebrationIcons"
	vbox.add_child(celebration)

	var button := Button.new()
	button.name = "ContinueButton"
	button.text = "Continue"
	vbox.add_child(button)

	var confetti := Control.new()
	confetti.name = "ConfettiContainer"
	_panel.add_child(confetti)

	await wait_frames(1)


# =============================================================================
# AC1: VICTORY SHOWS CAPTURED ANIMALS WITH CHECKBOXES
# =============================================================================

func test_show_victory_with_captured_animals_shows_recruitment_ui() -> void:
	# Arrange
	await _setup_panel_with_ui()
	var captured := ["rabbit", "rabbit", "rabbit"]

	# Act
	_panel.show_victory(captured, [])
	await wait_frames(2)

	# Assert
	assert_true(_panel.visible, "Panel should be visible after show_victory")
	# Recruitment items should be created (verified via get_selected_animals)
	var selected := _panel.get_selected_animals()
	assert_eq(selected.size(), 3, "All 3 animals should be selected by default")


func test_show_victory_empty_captured_no_recruitment_ui() -> void:
	# Arrange
	await _setup_panel_with_ui()

	# Act
	_panel.show_victory([], [])
	await wait_frames(2)

	# Assert
	var selected := _panel.get_selected_animals()
	assert_eq(selected.size(), 0, "No animals to select when empty")


# =============================================================================
# AC2: CHECKBOX DEFAULT STATE
# =============================================================================

func test_checkboxes_selected_by_default() -> void:
	# Arrange
	await _setup_panel_with_ui()
	var captured := ["rabbit", "rabbit"]

	# Act
	_panel.show_victory(captured, [])
	await wait_frames(2)

	# Assert
	var selected := _panel.get_selected_animals()
	assert_eq(selected.size(), 2, "All animals should be selected by default")


# =============================================================================
# AC3: GET SELECTED ANIMALS
# =============================================================================

func test_get_selected_animals_returns_correct_types() -> void:
	# Arrange
	await _setup_panel_with_ui()
	var captured := ["rabbit", "rabbit", "rabbit"]

	# Act
	_panel.show_victory(captured, [])
	await wait_frames(2)

	# Assert
	var selected := _panel.get_selected_animals()
	assert_eq(selected.size(), 3)
	for animal_type in selected:
		assert_eq(animal_type, "rabbit", "Selected animals should be rabbits")


# =============================================================================
# AC4: RECRUITMENT CONFIRMED SIGNAL
# =============================================================================

func test_recruitment_confirmed_signal_has_correct_signature() -> void:
	# Verify signal exists with correct parameter
	var signals := _panel.get_signal_list()
	var found := false
	for sig in signals:
		if sig.name == "recruitment_confirmed":
			found = true
			# Check parameter exists
			assert_gt(sig.args.size(), 0, "Should have at least one parameter")
			break

	assert_true(found, "recruitment_confirmed signal should exist")


# =============================================================================
# AC5: DEFEAT SHOWS NO RECRUITMENT
# =============================================================================

func test_show_defeat_no_recruitment_ui() -> void:
	# Arrange
	await _setup_panel_with_ui()

	# Act
	_panel.show_defeat([])
	await wait_frames(2)

	# Assert
	var selected := _panel.get_selected_animals()
	assert_eq(selected.size(), 0, "Defeat should have no selectable animals")


# =============================================================================
# AC6: BUTTON TEXT CHANGES
# =============================================================================

func test_continue_button_shows_confirm_when_animals_captured() -> void:
	# Arrange
	await _setup_panel_with_ui()
	var button := _panel.get_node("MarginContainer/VBoxContainer/ContinueButton") as Button
	assert_not_null(button, "Button should exist")

	# Act
	_panel.show_victory(["rabbit"], [])
	await wait_frames(2)

	# Assert
	assert_eq(button.text, "Confirm & Continue", "Button text should be 'Confirm & Continue'")


func test_continue_button_shows_continue_when_no_animals() -> void:
	# Arrange
	await _setup_panel_with_ui()
	var button := _panel.get_node("MarginContainer/VBoxContainer/ContinueButton") as Button

	# Act
	_panel.show_victory([], [])
	await wait_frames(2)

	# Assert
	assert_eq(button.text, "Continue", "Button text should be 'Continue' for no captures")


# =============================================================================
# AC7: BATTLE STATS
# =============================================================================

func test_get_battle_stats_returns_victory_info() -> void:
	# Arrange
	await _setup_panel_with_ui()
	var captured := ["rabbit", "rabbit"]

	# Act
	_panel.show_victory(captured, [])
	await wait_frames(2)

	# Assert
	var stats := _panel.get_battle_stats()
	assert_true(stats.is_victory, "Should be marked as victory")
	assert_eq(stats.captured_count, 2, "Should have 2 captured")


func test_get_battle_stats_returns_defeat_info() -> void:
	# Arrange
	await _setup_panel_with_ui()

	# Act
	_panel.show_defeat([])
	await wait_frames(2)

	# Assert
	var stats := _panel.get_battle_stats()
	assert_false(stats.is_victory, "Should be marked as defeat")
	assert_eq(stats.captured_count, 0, "Should have 0 captured")


# =============================================================================
# AC8: NULL/EDGE CASES
# =============================================================================

func test_show_victory_empty_captured_animals() -> void:
	# Arrange
	await _setup_panel_with_ui()

	# Act - Pass empty array (edge case)
	_panel.show_victory([], [])
	await wait_frames(2)

	# Assert
	var selected := _panel.get_selected_animals()
	assert_eq(selected.size(), 0, "Should handle empty captured array gracefully")


func test_show_victory_large_captured_count() -> void:
	# Arrange
	await _setup_panel_with_ui()
	var captured: Array = []
	for i in 10:
		captured.append("rabbit")

	# Act
	_panel.show_victory(captured, [])
	await wait_frames(2)

	# Assert
	var selected := _panel.get_selected_animals()
	assert_eq(selected.size(), 10, "Should handle many animals")
