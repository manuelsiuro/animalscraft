## BattleResultPanel - Victory/defeat celebration and battle summary display.
## Shows confetti for victory, drooping for defeat, battle stats, and Continue button.
## Emits signal when player acknowledges result.
##
## Story 5-7: Enhanced to show captured animals with icons, names, and
## "Available for recruitment" label.
##
## Story 5-8: Enhanced with recruitment selection UI. Players can now select
## which captured animals to recruit to their village.
##
## Architecture: scripts/ui/gameplay/battle_result_panel.gd
## Story: 5-6-display-combat-animations, 5-7-implement-victory-outcomes, 5-8-implement-animal-capture
class_name BattleResultPanel
extends PanelContainer

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when player taps Continue button (AC13)
signal result_acknowledged()

## Story 5-8: Emitted when recruitment is confirmed with selected animal types
## @param selected_animals Array of animal type strings to recruit
signal recruitment_confirmed(selected_animals: Array)

# =============================================================================
# CONSTANTS
# =============================================================================

## Animation timing
const VICTORY_BOUNCE_DURATION: float = 0.3
const DEFEAT_DROOP_DURATION: float = 0.5
const CONFETTI_DURATION: float = 2.0
const FADE_IN_DURATION: float = 0.3
const RECRUITING_DURATION: float = 1.5

## Colors
const VICTORY_COLOR: Color = Color("#4CAF50")  # Green
const DEFEAT_COLOR: Color = Color("#9E9E9E")  # Gray
const GOLD_COLOR: Color = Color("#FFD700")  # Gold for victory
const CHECKBOX_SELECTED_COLOR: Color = Color("#4CAF50")  # Green check
const CHECKBOX_DESELECTED_COLOR: Color = Color("#AAAAAA")  # Gray

## Confetti settings
const CONFETTI_PARTICLE_COUNT: int = 20

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var _subtitle_label: Label = $MarginContainer/VBoxContainer/SubtitleLabel
@onready var _stats_container: VBoxContainer = $MarginContainer/VBoxContainer/StatsContainer
@onready var _turns_label: Label = $MarginContainer/VBoxContainer/StatsContainer/TurnsLabel
@onready var _damage_label: Label = $MarginContainer/VBoxContainer/StatsContainer/DamageLabel
@onready var _captured_label: Label = $MarginContainer/VBoxContainer/StatsContainer/CapturedLabel
@onready var _continue_button: Button = $MarginContainer/VBoxContainer/ContinueButton
@onready var _confetti_container: Control = $ConfettiContainer
@onready var _celebration_icons: HBoxContainer = $MarginContainer/VBoxContainer/CelebrationIcons

## Story 5-7: Container for dynamically created captured animal displays
## Created programmatically if not present in scene
var _captured_animals_container: VBoxContainer = null

## Story 5-8: Recruitment UI components (created programmatically)
var _recruitment_section: VBoxContainer = null
var _recruitment_items: Array = []  # Array of HBoxContainer with CheckBox
var _select_all_button: Button = null
var _deselect_all_button: Button = null
var _selection_counter_label: Label = null
var _recruiting_label: Label = null

# =============================================================================
# STATE
# =============================================================================

## Whether showing victory (true) or defeat (false)
var _is_victory: bool = false

## Battle stats
var _turns_taken: int = 0
var _total_damage_dealt: int = 0
var _captured_animals: Array = []

## Story 5-8: Recruitment state
var _is_recruiting: bool = false
var _has_capturable_animals: bool = false

## Animation tween
var _tween: Tween = null

# =============================================================================
# LIFECYCLE
# =============================================================================

## Ensure we have a valid continue button reference.
## Needed because @onready may fail if UI structure is added after _ready().
func _ensure_continue_button() -> void:
	if _continue_button and is_instance_valid(_continue_button):
		return
	_continue_button = get_node_or_null("MarginContainer/VBoxContainer/ContinueButton")
	if _continue_button and not _continue_button.pressed.is_connected(_on_continue_pressed):
		_continue_button.pressed.connect(_on_continue_pressed)


func _ready() -> void:
	# Start hidden
	visible = false
	modulate.a = 0.0

	# Connect button
	if _continue_button:
		_continue_button.pressed.connect(_on_continue_pressed)


func _exit_tree() -> void:
	if _tween and _tween.is_running():
		_tween.kill()

# =============================================================================
# PUBLIC API
# =============================================================================

## Show victory celebration with captured animals (Story 5-7: AC10, AC11, AC12, AC18).
## Story 5-8: Now includes recruitment selection UI for captured animals.
## @param captured_animals Array of animal type strings that were captured
## @param battle_log Array of BattleLogEntry for stats calculation
func show_victory(captured_animals: Array, battle_log: Array = []) -> void:
	_is_victory = true
	_captured_animals = captured_animals if captured_animals else []
	_is_recruiting = false
	_has_capturable_animals = not _captured_animals.is_empty()
	_calculate_stats(battle_log)

	# Configure display
	if _title_label:
		_title_label.text = "🎉 VICTORY! 🎉"
		_title_label.add_theme_color_override("font_color", GOLD_COLOR)

	if _subtitle_label:
		_subtitle_label.text = "You conquered the territory!"
		_subtitle_label.visible = true

	_update_stats_display()

	# Ensure button reference is valid (may have been added after _ready)
	_ensure_continue_button()

	# Story 5-8: Show recruitment UI if there are captured animals (AC1, AC12)
	if _has_capturable_animals:
		_display_recruitment_ui(_captured_animals)
		# Change button text (AC13)
		if _continue_button:
			_continue_button.text = "Confirm & Continue"
	else:
		# Story 5-7: Show simple captured display for empty case (AC16)
		_display_captured_animals(_captured_animals)
		if _continue_button:
			_continue_button.text = "Continue"

	# Show with animation
	_show_with_animation()

	# Play victory celebration (AC10)
	_play_victory_celebration()


## Show defeat animation (AC11, AC12).
## Story 5-9: Enhanced with friendly retreat messaging and "Return to Village" button.
## @param battle_log Array of BattleLogEntry for stats calculation
func show_defeat(battle_log: Array = []) -> void:
	_is_victory = false
	_captured_animals = []
	_has_capturable_animals = false
	_is_recruiting = false
	_calculate_stats(battle_log)

	# Configure display (Story 5-9 AC7)
	if _title_label:
		_title_label.text = "😔 Defeated..."
		_title_label.add_theme_color_override("font_color", DEFEAT_COLOR)

	# Story 5-9 AC8, AC14: Friendly, cozy messaging - no harsh "failure" language
	if _subtitle_label:
		_subtitle_label.text = "Your animals retreated to rest. Try again when they've recovered!"
		_subtitle_label.visible = true

	_update_stats_display()

	# Hide captured section
	if _captured_label:
		_captured_label.visible = false

	# Hide recruitment UI
	_hide_recruitment_ui()

	# Ensure button reference is valid
	_ensure_continue_button()

	# Story 5-9 AC9: Change button text to "Return to Village" for defeat
	if _continue_button:
		_continue_button.text = "Return to Village"

	# Show with animation
	_show_with_animation()

	# Play defeat animation (AC11)
	_play_defeat_animation()


## Get the battle stats.
func get_battle_stats() -> Dictionary:
	return {
		"turns_taken": _turns_taken,
		"total_damage_dealt": _total_damage_dealt,
		"captured_count": _captured_animals.size(),
		"is_victory": _is_victory
	}


## Story 5-8: Get selected animals for recruitment.
## @return Array of animal type strings that are selected
func get_selected_animals() -> Array:
	var selected: Array = []

	for i in _recruitment_items.size():
		var item: HBoxContainer = _recruitment_items[i]
		var checkbox: CheckBox = item.get_node_or_null("CheckBox")
		if checkbox and checkbox.button_pressed:
			# Get animal type from stored metadata
			if i < _captured_animals.size():
				selected.append(_captured_animals[i])

	return selected

# =============================================================================
# PRIVATE METHODS - DISPLAY
# =============================================================================

## Calculate battle stats from log (AC12).
func _calculate_stats(battle_log: Array) -> void:
	_turns_taken = 0
	_total_damage_dealt = 0

	if battle_log.is_empty():
		return

	# Count turns and total damage
	for entry in battle_log:
		if "turn_number" in entry:
			_turns_taken = maxi(_turns_taken, entry.turn_number)
		if "damage" in entry:
			_total_damage_dealt += entry.damage


## Update stats display labels (AC12).
func _update_stats_display() -> void:
	if _turns_label:
		_turns_label.text = "⏱️ Turns: %d" % _turns_taken

	if _damage_label:
		_damage_label.text = "💥 Total Damage: %d" % _total_damage_dealt


# =============================================================================
# RECRUITMENT UI (Story 5-8: AC1-4, AC12, AC13, AC16, AC17)
# =============================================================================

## Display recruitment selection UI for captured animals.
## Replaces the simple captured animals display with interactive checkboxes.
## @param captured_animals Array of animal type strings
func _display_recruitment_ui(captured_animals: Array) -> void:
	# Update header label (AC1)
	if _captured_label:
		_captured_label.visible = true
		_captured_label.text = "🎁 Recruit Animals"

	# Create or get the recruitment section container
	_ensure_recruitment_section()

	# Clear any existing items
	_recruitment_items.clear()
	if _recruitment_section and is_instance_valid(_recruitment_section):
		for child in _recruitment_section.get_children():
			child.queue_free()

	# Wait a frame for cleanup
	await get_tree().process_frame

	# Create recruitment item for each captured animal (AC2)
	for i in captured_animals.size():
		var animal_type: String = captured_animals[i]
		var item := _create_recruitment_item(animal_type, i)
		_recruitment_section.add_child(item)
		_recruitment_items.append(item)

	# Add selection controls (AC3, AC4)
	_create_selection_controls()

	# Update counter
	_update_selection_counter()


## Ensure the recruitment section container exists.
func _ensure_recruitment_section() -> void:
	if _recruitment_section and is_instance_valid(_recruitment_section):
		return

	# Look for existing container in stats container
	if _stats_container:
		_recruitment_section = _stats_container.get_node_or_null("RecruitmentSection")

	# Create if not found
	if not _recruitment_section:
		_recruitment_section = VBoxContainer.new()
		_recruitment_section.name = "RecruitmentSection"
		_recruitment_section.add_theme_constant_override("separation", 6)

		# Insert after _captured_label if it exists
		if _stats_container and _captured_label:
			var label_index := _captured_label.get_index()
			_stats_container.add_child(_recruitment_section)
			_stats_container.move_child(_recruitment_section, label_index + 1)
		elif _stats_container:
			_stats_container.add_child(_recruitment_section)


## Create a recruitment item with checkbox for a single animal (AC2).
## @param animal_type The animal type string
## @param index The index in the captured animals array
## @return HBoxContainer with checkbox, icon, and name
func _create_recruitment_item(animal_type: String, index: int) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.name = "RecruitmentItem_%d" % index
	container.add_theme_constant_override("separation", 8)
	container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Checkbox - default to selected (AC3)
	var checkbox := CheckBox.new()
	checkbox.name = "CheckBox"
	checkbox.button_pressed = true  # All selected by default
	checkbox.toggled.connect(_on_recruitment_checkbox_toggled)
	container.add_child(checkbox)

	# Animal icon
	var icon_label := Label.new()
	icon_label.name = "Icon"
	icon_label.text = GameConstants.get_animal_icon(animal_type)
	icon_label.add_theme_font_size_override("font_size", 24)
	container.add_child(icon_label)

	# Animal name
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.text = GameConstants.get_animal_display_name(animal_type)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", GOLD_COLOR)
	container.add_child(name_label)

	return container


## Create Select All / Deselect All buttons and counter (AC3, AC4).
func _create_selection_controls() -> void:
	if not _recruitment_section:
		return

	# Container for buttons
	var controls_container := HBoxContainer.new()
	controls_container.name = "SelectionControls"
	controls_container.add_theme_constant_override("separation", 10)
	controls_container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Select All button
	_select_all_button = Button.new()
	_select_all_button.name = "SelectAllButton"
	_select_all_button.text = "Select All"
	_select_all_button.pressed.connect(_on_select_all_pressed)
	controls_container.add_child(_select_all_button)

	# Deselect All button
	_deselect_all_button = Button.new()
	_deselect_all_button.name = "DeselectAllButton"
	_deselect_all_button.text = "Deselect All"
	_deselect_all_button.pressed.connect(_on_deselect_all_pressed)
	controls_container.add_child(_deselect_all_button)

	_recruitment_section.add_child(controls_container)

	# Selection counter (AC3.6)
	_selection_counter_label = Label.new()
	_selection_counter_label.name = "SelectionCounter"
	_selection_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selection_counter_label.add_theme_font_size_override("font_size", 12)
	_recruitment_section.add_child(_selection_counter_label)


## Update selection counter display.
func _update_selection_counter() -> void:
	if not _selection_counter_label:
		return

	var selected := get_selected_animals()
	var total := _captured_animals.size()
	var releasing := total - selected.size()

	_selection_counter_label.text = "Recruiting: %d | Releasing: %d" % [selected.size(), releasing]


## Hide recruitment UI.
func _hide_recruitment_ui() -> void:
	if _recruitment_section and is_instance_valid(_recruitment_section):
		_recruitment_section.visible = false


## Show "Recruiting..." loading state (AC14).
func _show_recruiting_state() -> void:
	_is_recruiting = true

	# Hide selection UI
	if _recruitment_section:
		for child in _recruitment_section.get_children():
			if child.name != "RecruitingLabel":
				child.visible = false

	# Show recruiting message
	if not _recruiting_label:
		_recruiting_label = Label.new()
		_recruiting_label.name = "RecruitingLabel"
		_recruiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_recruiting_label.add_theme_font_size_override("font_size", 16)
		if _recruitment_section:
			_recruitment_section.add_child(_recruiting_label)

	if _recruiting_label:
		_recruiting_label.text = "🐾 Recruiting..."
		_recruiting_label.visible = true

	# Disable continue button during recruitment
	if _continue_button:
		_continue_button.disabled = true

	# Spawn more confetti for celebration
	if _confetti_container:
		_spawn_confetti()


## Show recruitment success messages (AC4.5).
## @param recruited_animals Array of animal type strings that were recruited
func _show_recruitment_success(recruited_animals: Array) -> void:
	if recruited_animals.is_empty():
		# AC17: All deselected case
		if _recruiting_label:
			_recruiting_label.text = "🌿 Animals released back to the wild"
			_recruiting_label.visible = true
	else:
		# Show success for each animal
		var messages: Array = []
		for animal_type in recruited_animals:
			var display_name := GameConstants.get_animal_display_name(animal_type)
			var icon := GameConstants.get_animal_icon(animal_type)
			messages.append("%s %s joined your village!" % [icon, display_name])

		if _recruiting_label:
			_recruiting_label.text = "\n".join(messages)
			_recruiting_label.visible = true


# =============================================================================
# CAPTURED ANIMALS DISPLAY (Story 5-7: AC10, AC11, AC12, AC18)
# Kept for defeat screen and empty captures case
# =============================================================================

## Display captured animals section with icons, names, and recruitment label.
## Handles empty array gracefully with "No animals captured" message (AC18).
## @param captured_animals Array of animal type strings
func _display_captured_animals(captured_animals: Array) -> void:
	# Use existing _captured_label for the section header
	if _captured_label:
		_captured_label.visible = true

		if captured_animals.is_empty():
			# AC18/AC16: Handle empty captured_animals array gracefully
			_captured_label.text = "🐾 No animals captured"
		else:
			# AC11: Label as "available for recruitment"
			_captured_label.text = "🎁 Captured Animals - Available for recruitment!"

	# Create or get the captured animals display container
	_ensure_captured_animals_container()

	# Clear any existing displays (with null safety - AR18)
	if _captured_animals_container and is_instance_valid(_captured_animals_container):
		for child in _captured_animals_container.get_children():
			child.queue_free()

		# AC10, AC11: Show each captured animal type with icon and name
		if not captured_animals.is_empty():
			for animal_type in captured_animals:
				var animal_display := _create_captured_animal_display(animal_type)
				_captured_animals_container.add_child(animal_display)


## Ensure the captured animals container exists.
## Creates it programmatically if not in the scene tree.
func _ensure_captured_animals_container() -> void:
	if _captured_animals_container and is_instance_valid(_captured_animals_container):
		return

	# Look for existing container in stats container
	if _stats_container:
		_captured_animals_container = _stats_container.get_node_or_null("CapturedAnimalsContainer")

	# Create if not found
	if not _captured_animals_container:
		_captured_animals_container = VBoxContainer.new()
		_captured_animals_container.name = "CapturedAnimalsContainer"
		_captured_animals_container.add_theme_constant_override("separation", 4)

		# Insert after _captured_label if it exists
		if _stats_container and _captured_label:
			var label_index := _captured_label.get_index()
			_stats_container.add_child(_captured_animals_container)
			_stats_container.move_child(_captured_animals_container, label_index + 1)
		elif _stats_container:
			_stats_container.add_child(_captured_animals_container)


## Create a display for a single captured animal type.
## Shows icon, name, and maintains cozy aesthetic.
## @param animal_type The animal type string (e.g., "rabbit")
## @return HBoxContainer with the animal display
func _create_captured_animal_display(animal_type: String) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 8)
	container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Animal icon (AC11)
	var icon_label := Label.new()
	icon_label.text = GameConstants.get_animal_icon(animal_type)
	icon_label.add_theme_font_size_override("font_size", 24)
	container.add_child(icon_label)

	# Animal name (AC11)
	var name_label := Label.new()
	name_label.text = GameConstants.get_animal_display_name(animal_type)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", GOLD_COLOR)
	container.add_child(name_label)

	return container


## Show panel with fade animation.
func _show_with_animation() -> void:
	visible = true

	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)

# =============================================================================
# PRIVATE METHODS - VICTORY CELEBRATION (AC10)
# =============================================================================

## Play victory celebration with confetti and bouncing.
func _play_victory_celebration() -> void:
	# Spawn confetti particles
	if _confetti_container:
		_spawn_confetti()

	# Bounce celebration icons
	if _celebration_icons:
		_animate_celebration_bounce()


## Spawn confetti particles.
func _spawn_confetti() -> void:
	if not _confetti_container:
		return

	# Clear existing confetti
	for child in _confetti_container.get_children():
		child.queue_free()

	# Create confetti particles
	for i in CONFETTI_PARTICLE_COUNT:
		var confetti := _create_confetti_particle()
		_confetti_container.add_child(confetti)
		_animate_confetti_particle(confetti, i)


## Create a single confetti particle.
func _create_confetti_particle() -> Control:
	var particle := Label.new()

	# Random confetti emoji
	var confetti_chars := ["🎊", "🎉", "✨", "⭐", "🌟"]
	particle.text = confetti_chars[randi() % confetti_chars.size()]
	particle.add_theme_font_size_override("font_size", randi_range(12, 20))

	# Random starting position (spread across top)
	particle.position = Vector2(
		randf_range(0, _confetti_container.size.x if _confetti_container.size.x > 0 else 300),
		-20
	)

	return particle


## Animate a confetti particle falling.
func _animate_confetti_particle(particle: Control, index: int) -> void:
	var delay := randf_range(0, 0.5)
	var duration := randf_range(1.0, CONFETTI_DURATION)

	var tween := particle.create_tween()
	tween.set_parallel(true)

	# Fall down with some horizontal drift
	var target_y: float = _confetti_container.size.y if _confetti_container.size.y > 0 else 200.0
	var drift := randf_range(-50, 50)

	tween.tween_property(particle, "position:y", target_y, duration).set_delay(delay)
	tween.tween_property(particle, "position:x", particle.position.x + drift, duration).set_delay(delay)
	tween.tween_property(particle, "modulate:a", 0.0, duration * 0.3).set_delay(delay + duration * 0.7)

	# Rotation for visual interest
	tween.tween_property(particle, "rotation_degrees", randf_range(-180, 180), duration).set_delay(delay)

	tween.set_parallel(false)
	tween.tween_callback(particle.queue_free)


## Animate celebration icons bouncing.
func _animate_celebration_bounce() -> void:
	if not _celebration_icons:
		return

	# Clear any existing icons first (prevent mixing victory/defeat icons)
	for child in _celebration_icons.get_children():
		child.queue_free()

	# Wait a frame for cleanup, then create bouncing animal icons
	await get_tree().process_frame

	# Create bouncing animal icons
	var icons := ["🐰", "🦊", "🐻", "🐼"]
	for icon_text in icons:
		var icon := Label.new()
		icon.text = icon_text
		icon.add_theme_font_size_override("font_size", 28)
		_celebration_icons.add_child(icon)

	# Animate each icon with staggered bounce
	var i := 0
	for child in _celebration_icons.get_children():
		_animate_single_bounce(child, i * 0.1)
		i += 1


## Animate a single icon bouncing.
func _animate_single_bounce(icon: Control, delay: float) -> void:
	var original_y := icon.position.y
	var tween := icon.create_tween()
	tween.set_loops(3)  # Bounce 3 times

	tween.tween_property(icon, "position:y", original_y - 15, VICTORY_BOUNCE_DURATION / 2).set_delay(delay)
	tween.tween_property(icon, "position:y", original_y, VICTORY_BOUNCE_DURATION / 2)

# =============================================================================
# PRIVATE METHODS - DEFEAT ANIMATION (AC11)
# =============================================================================

## Play gentle defeat animation.
func _play_defeat_animation() -> void:
	# Droop the celebration icons (sad animals)
	if _celebration_icons:
		_animate_defeat_droop()

	# Apply grayish tint
	var tween := create_tween()
	tween.tween_property(self, "self_modulate", Color(0.8, 0.8, 0.9, 1.0), DEFEAT_DROOP_DURATION)


## Animate icons drooping for defeat.
func _animate_defeat_droop() -> void:
	if not _celebration_icons:
		return

	# Clear any existing icons first (prevent mixing victory/defeat icons)
	for child in _celebration_icons.get_children():
		child.queue_free()

	# Wait a frame for cleanup, then create drooping animal icons (AC11)
	await get_tree().process_frame

	# Create drooping animal icons (same animals as victory, but sad)
	var icons := ["🐰", "🦊", "🐻", "🐼"]
	for icon_text in icons:
		var icon := Label.new()
		icon.text = icon_text
		icon.add_theme_font_size_override("font_size", 28)
		_celebration_icons.add_child(icon)

	# Animate each animal icon drooping (tilted, grayed out)
	for child in _celebration_icons.get_children():
		var tween := child.create_tween()
		tween.set_parallel(true)
		tween.tween_property(child, "rotation_degrees", randf_range(-20, -10), DEFEAT_DROOP_DURATION)
		tween.tween_property(child, "modulate", Color(0.6, 0.6, 0.6, 1.0), DEFEAT_DROOP_DURATION)
		tween.tween_property(child, "position:y", child.position.y + 5, DEFEAT_DROOP_DURATION)  # Slight droop down

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

## Handle Continue button press (AC13, Story 5-8: AC4).
func _on_continue_pressed() -> void:
	# Story 5-8: If we have capturable animals, process recruitment first
	if _has_capturable_animals and not _is_recruiting:
		var selected := get_selected_animals()

		# Show recruiting state
		_show_recruiting_state()

		# Emit recruitment confirmed signal
		recruitment_confirmed.emit(selected)

		# Show success message after a brief delay
		await get_tree().create_timer(RECRUITING_DURATION).timeout

		# Show success message
		_show_recruitment_success(selected)

		# Wait for player to read message
		await get_tree().create_timer(1.0).timeout

		# Re-enable continue and proceed to close
		if _continue_button:
			_continue_button.disabled = false

	# Emit result acknowledged and close panel
	result_acknowledged.emit()

	# Hide panel
	if _tween and _tween.is_running():
		_tween.kill()

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, FADE_IN_DURATION)
	_tween.tween_callback(func():
		visible = false
		# Reset state for next use
		_is_recruiting = false
		_has_capturable_animals = false
	)


## Handle recruitment checkbox toggle (AC3).
func _on_recruitment_checkbox_toggled(_pressed: bool) -> void:
	_update_selection_counter()


## Handle Select All button press (AC3.4).
func _on_select_all_pressed() -> void:
	for item in _recruitment_items:
		var checkbox: CheckBox = item.get_node_or_null("CheckBox")
		if checkbox:
			checkbox.button_pressed = true
	_update_selection_counter()


## Handle Deselect All button press (AC3.4).
func _on_deselect_all_pressed() -> void:
	for item in _recruitment_items:
		var checkbox: CheckBox = item.get_node_or_null("CheckBox")
		if checkbox:
			checkbox.button_pressed = false
	_update_selection_counter()
