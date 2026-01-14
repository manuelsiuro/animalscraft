## Unit tests for AnimalStatsPanel.
## Tests visibility, stat display, real-time updates, and EventBus integration.
##
## Architecture: tests/unit/test_animal_stats_panel.gd
## Story: 2-4-display-animal-stats-panel
extends GutTest

# =============================================================================
# TEST DATA
# =============================================================================

var stats_panel: AnimalStatsPanel
var mock_animal: Animal
var mock_hex: HexCoord
var mock_stats: AnimalStats

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	# Create stats panel
	var panel_scene := preload("res://scenes/ui/animal_stats_panel.tscn")
	stats_panel = panel_scene.instantiate()
	add_child(stats_panel)
	await wait_frames(1)

	# Create mock data
	mock_hex = HexCoord.new(0, 0)
	mock_stats = AnimalStats.new()
	mock_stats.animal_id = "rabbit"
	mock_stats.energy = 3
	mock_stats.speed = 4
	mock_stats.strength = 2
	mock_stats.specialty = "Speed +20% gathering"
	mock_stats.biome = "plains"

	# Create mock animal
	var animal_scene := preload("res://scenes/entities/animals/rabbit.tscn")
	mock_animal = animal_scene.instantiate()
	add_child(mock_animal)
	await wait_frames(1)

	# Initialize animal
	mock_animal.initialize(mock_hex, mock_stats)
	await wait_frames(1)


func after_each() -> void:
	if is_instance_valid(stats_panel):
		stats_panel.queue_free()
	if is_instance_valid(mock_animal):
		mock_animal.cleanup()
	await wait_frames(1)

	stats_panel = null
	mock_animal = null
	mock_hex = null
	mock_stats = null

# =============================================================================
# VISIBILITY TESTS (AC1, AC4)
# =============================================================================

func test_panel_initially_hidden() -> void:
	assert_false(stats_panel.visible, "Panel should be hidden initially")


func test_panel_shows_on_show_for_animal() -> void:
	stats_panel.show_for_animal(mock_animal)

	assert_true(stats_panel.visible, "Panel should be visible after show_for_animal")


func test_panel_hides_on_hide_panel() -> void:
	stats_panel.show_for_animal(mock_animal)
	stats_panel.hide_panel()

	assert_false(stats_panel.visible, "Panel should be hidden after hide_panel")


func test_panel_shows_on_animal_selected_signal() -> void:
	EventBus.animal_selected.emit(mock_animal)
	await wait_frames(1)

	assert_true(stats_panel.visible, "Panel should show after animal_selected signal")


func test_panel_hides_on_animal_deselected_signal() -> void:
	EventBus.animal_selected.emit(mock_animal)
	await wait_frames(1)

	EventBus.animal_deselected.emit()
	await wait_frames(1)

	assert_false(stats_panel.visible, "Panel should hide after animal_deselected signal")


func test_is_showing_returns_correct_state() -> void:
	assert_false(stats_panel.is_showing(), "is_showing should be false initially")

	stats_panel.show_for_animal(mock_animal)

	assert_true(stats_panel.is_showing(), "is_showing should be true when visible with animal")


# =============================================================================
# STAT DISPLAY TESTS (AC2)
# =============================================================================

func test_displays_animal_type_name() -> void:
	stats_panel.show_for_animal(mock_animal)

	var type_label := stats_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/Header/AnimalTypeLabel") as Label
	assert_eq(type_label.text, "Rabbit", "Should display capitalized animal type")


func test_displays_energy_bar_value() -> void:
	stats_panel.show_for_animal(mock_animal)

	var energy_bar := stats_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/EnergyRow/EnergyBar") as TextureProgressBar
	assert_eq(int(energy_bar.value), 3, "Energy bar should show current energy")
	assert_eq(int(energy_bar.max_value), 3, "Energy bar should show max energy")


func test_displays_speed_value() -> void:
	stats_panel.show_for_animal(mock_animal)

	var speed_label := stats_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/StatsRow/SpeedContainer/SpeedValue") as Label
	assert_eq(speed_label.text, "4", "Should display speed stat")


func test_displays_strength_value() -> void:
	stats_panel.show_for_animal(mock_animal)

	var strength_label := stats_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/StatsRow/StrengthContainer/StrengthValue") as Label
	assert_eq(strength_label.text, "2", "Should display strength stat")


func test_displays_specialty_text() -> void:
	stats_panel.show_for_animal(mock_animal)

	var specialty_label := stats_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/SpecialtyLabel") as Label
	assert_eq(specialty_label.text, "Speed +20% gathering", "Should display specialty")


func test_displays_mood_indicator_happy() -> void:
	stats_panel.show_for_animal(mock_animal)

	var mood_label := stats_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/Header/MoodIndicator") as Label
	assert_eq(mood_label.text, "😊", "Should display happy mood emoji")


# =============================================================================
# REAL-TIME UPDATE TESTS (AC3)
# =============================================================================

func test_energy_bar_updates_on_energy_changed() -> void:
	stats_panel.show_for_animal(mock_animal)

	# Deplete energy
	var stats_component := mock_animal.get_node("StatsComponent") as StatsComponent
	stats_component.deplete_energy(1)
	await wait_frames(30)  # Wait for tween animation (0.3s at 60fps)

	var energy_bar := stats_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/EnergyRow/EnergyBar") as TextureProgressBar
	assert_eq(int(energy_bar.value), 2, "Energy bar should update to new value")


func test_mood_indicator_updates_on_mood_changed() -> void:
	stats_panel.show_for_animal(mock_animal)

	# Change mood
	var stats_component := mock_animal.get_node("StatsComponent") as StatsComponent
	stats_component.decrease_mood()  # Happy → Neutral
	await wait_frames(1)

	var mood_label := stats_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/Header/MoodIndicator") as Label
	assert_eq(mood_label.text, "😐", "Should display neutral mood emoji")


func test_mood_indicator_updates_to_sad() -> void:
	stats_panel.show_for_animal(mock_animal)

	# Change mood twice
	var stats_component := mock_animal.get_node("StatsComponent") as StatsComponent
	stats_component.decrease_mood()  # Happy → Neutral
	stats_component.decrease_mood()  # Neutral → Sad
	await wait_frames(1)

	var mood_label := stats_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/Header/MoodIndicator") as Label
	assert_eq(mood_label.text, "😢", "Should display sad mood emoji")


func test_energy_depletes_to_zero() -> void:
	stats_panel.show_for_animal(mock_animal)

	# Deplete all energy
	var stats_component := mock_animal.get_node("StatsComponent") as StatsComponent
	stats_component.deplete_energy(3)
	await wait_frames(30)  # Wait longer for tween animation (0.3s at 60fps = 18 frames minimum)

	var energy_bar := stats_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/EnergyRow/EnergyBar") as TextureProgressBar
	assert_eq(int(energy_bar.value), 0, "Energy bar should show 0")


func test_energy_restores_updates_bar() -> void:
	stats_panel.show_for_animal(mock_animal)

	# Deplete then restore
	var stats_component := mock_animal.get_node("StatsComponent") as StatsComponent
	stats_component.deplete_energy(2)
	await wait_frames(30)  # Wait for first tween
	stats_component.restore_energy(1)
	await wait_frames(30)  # Wait for second tween

	var energy_bar := stats_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/EnergyRow/EnergyBar") as TextureProgressBar
	assert_eq(int(energy_bar.value), 2, "Energy bar should show restored value")


# =============================================================================
# SELECTION CHANGE TESTS (AC6)
# =============================================================================

func test_panel_updates_when_selecting_different_animal() -> void:
	# First animal
	stats_panel.show_for_animal(mock_animal)

	# Create second animal with different stats
	var animal2_scene := preload("res://scenes/entities/animals/rabbit.tscn")
	var mock_animal2 := animal2_scene.instantiate()
	add_child(mock_animal2)
	await wait_frames(1)

	var hex2 := HexCoord.new(5, 5)
	var stats2 := AnimalStats.new()
	stats2.animal_id = "fox"
	stats2.energy = 5
	stats2.speed = 6
	stats2.strength = 5
	stats2.specialty = "Hunter"
	stats2.biome = "plains"

	mock_animal2.initialize(hex2, stats2)
	await wait_frames(1)

	# Deplete second animal's energy to differentiate
	var stats_component2 := mock_animal2.get_node("StatsComponent") as StatsComponent
	stats_component2.deplete_energy(2)
	await wait_frames(1)

	# Select second animal via EventBus
	EventBus.animal_selected.emit(mock_animal2)
	await wait_frames(1)

	var energy_bar := stats_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/EnergyRow/EnergyBar") as TextureProgressBar
	assert_eq(int(energy_bar.value), 3, "Energy bar should show second animal's energy")
	assert_eq(int(energy_bar.max_value), 5, "Energy bar max should show second animal's max energy")

	var type_label := stats_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/Header/AnimalTypeLabel") as Label
	assert_eq(type_label.text, "Fox", "Should display second animal's type")

	# Cleanup
	mock_animal2.cleanup()
	await wait_frames(1)


func test_panel_disconnects_from_previous_animal_on_switch() -> void:
	# Show panel for first animal
	stats_panel.show_for_animal(mock_animal)

	# Create and show panel for second animal
	var animal2_scene := preload("res://scenes/entities/animals/rabbit.tscn")
	var mock_animal2 := animal2_scene.instantiate()
	add_child(mock_animal2)
	await wait_frames(1)

	var hex2 := HexCoord.new(5, 5)
	mock_animal2.initialize(hex2, mock_stats)
	await wait_frames(1)

	# Switch to second animal
	stats_panel.show_for_animal(mock_animal2)

	# Now change first animal's energy - panel should NOT update
	var stats_component := mock_animal.get_node("StatsComponent") as StatsComponent
	stats_component.deplete_energy(2)
	await wait_frames(5)

	# Energy bar should still show second animal's full energy (3)
	var energy_bar := stats_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/EnergyRow/EnergyBar") as TextureProgressBar
	assert_eq(int(energy_bar.value), 3, "Energy bar should NOT update from disconnected animal")

	# Cleanup
	mock_animal2.cleanup()
	await wait_frames(1)


# =============================================================================
# NULL SAFETY TESTS
# =============================================================================

func test_show_for_null_animal_no_crash() -> void:
	stats_panel.show_for_animal(null)

	assert_false(stats_panel.visible, "Panel should remain hidden for null animal")


func test_panel_handles_animal_freed_gracefully() -> void:
	stats_panel.show_for_animal(mock_animal)
	assert_true(stats_panel.visible)

	# Free the animal
	mock_animal.queue_free()
	await wait_frames(1)

	# Emit deselected (simulating what SelectionManager would do)
	EventBus.animal_deselected.emit()
	await wait_frames(1)

	assert_false(stats_panel.visible, "Panel should hide gracefully")


func test_current_animal_reference_cleared_on_hide() -> void:
	stats_panel.show_for_animal(mock_animal)
	assert_not_null(stats_panel.get_current_animal(), "Should have animal reference")

	stats_panel.hide_panel()

	assert_null(stats_panel.get_current_animal(), "Animal reference should be cleared")


func test_current_animal_reference_cleared_on_deselected() -> void:
	EventBus.animal_selected.emit(mock_animal)
	await wait_frames(1)
	assert_not_null(stats_panel.get_current_animal(), "Should have animal reference")

	EventBus.animal_deselected.emit()
	await wait_frames(1)

	assert_null(stats_panel.get_current_animal(), "Animal reference should be cleared")


# =============================================================================
# SIGNAL CONNECTION TESTS
# =============================================================================

func test_eventbus_signals_connected_on_ready() -> void:
	# Verify connections exist
	assert_true(EventBus.animal_selected.is_connected(stats_panel._on_animal_selected),
		"Should be connected to animal_selected")
	assert_true(EventBus.animal_deselected.is_connected(stats_panel._on_animal_deselected),
		"Should be connected to animal_deselected")


func test_stats_component_signals_connected_on_show() -> void:
	stats_panel.show_for_animal(mock_animal)

	var stats_component := mock_animal.get_node("StatsComponent") as StatsComponent
	assert_true(stats_component.energy_changed.is_connected(stats_panel._on_energy_changed),
		"Should be connected to energy_changed")
	assert_true(stats_component.mood_changed.is_connected(stats_panel._on_mood_changed),
		"Should be connected to mood_changed")


func test_stats_component_signals_disconnected_on_hide() -> void:
	stats_panel.show_for_animal(mock_animal)
	var stats_component := mock_animal.get_node("StatsComponent") as StatsComponent

	stats_panel.hide_panel()

	assert_false(stats_component.energy_changed.is_connected(stats_panel._on_energy_changed),
		"Should be disconnected from energy_changed")
	assert_false(stats_component.mood_changed.is_connected(stats_panel._on_mood_changed),
		"Should be disconnected from mood_changed")


# =============================================================================
# MOOD EMOJI MAPPING TESTS
# =============================================================================

func test_mood_emoji_happy() -> void:
	assert_eq(AnimalStatsPanel.MOOD_EMOJIS.get("happy"), "😊", "Happy should map to 😊")


func test_mood_emoji_neutral() -> void:
	assert_eq(AnimalStatsPanel.MOOD_EMOJIS.get("neutral"), "😐", "Neutral should map to 😐")


func test_mood_emoji_sad() -> void:
	assert_eq(AnimalStatsPanel.MOOD_EMOJIS.get("sad"), "😢", "Sad should map to 😢")


func test_mood_emoji_unknown_defaults_neutral() -> void:
	stats_panel.show_for_animal(mock_animal)

	# Manually call update with unknown mood
	stats_panel._update_mood_indicator("unknown_mood")

	var mood_label := stats_panel.get_node("PanelContainer/MarginContainer/VBoxContainer/Header/MoodIndicator") as Label
	assert_eq(mood_label.text, "😐", "Unknown mood should default to neutral emoji")
