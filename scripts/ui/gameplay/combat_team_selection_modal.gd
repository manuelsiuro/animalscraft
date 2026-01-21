## CombatTeamSelectionModal - Modal UI for selecting combat team before battle.
## Displays available animals, allows selection (1-5), shows team summary and difficulty.
## Appears when player requests combat from contested territory preview.
##
## Architecture: scripts/ui/gameplay/combat_team_selection_modal.gd
## Story: 5-4-create-combat-team-selection-ui
class_name CombatTeamSelectionModal
extends Control

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when player confirms combat team and starts fight
signal combat_team_selected(team: Array, hex_coord: Vector2i, herd_id: String)

## Emitted when modal is cancelled without starting combat
signal modal_cancelled()

# =============================================================================
# CONSTANTS
# =============================================================================

## Team size constraints (AC 5, 6)
const MIN_TEAM_SIZE: int = 1
const MAX_TEAM_SIZE: int = 5

## Difficulty thresholds (reuse from ContestedPreviewPanel)
const DIFFICULTY_EASY_MAX: float = 0.6
const DIFFICULTY_MEDIUM_MAX: float = 1.0
const DIFFICULTY_HIGH_MAX: float = 1.5

## Difficulty colors
const COLOR_EASY: Color = Color("#4CAF50")  # Green
const COLOR_MEDIUM: Color = Color("#FFC107")  # Yellow
const COLOR_HIGH: Color = Color("#FF9800")  # Orange
const COLOR_DANGEROUS: Color = Color("#F44336")  # Red
const COLOR_UNKNOWN: Color = Color("#9E9E9E")  # Gray

## Animation durations (AC 17)
const FADE_DURATION: float = 0.3

## Low energy threshold for warning (AC 10)
const LOW_ENERGY_THRESHOLD: float = 0.2

## AIComponent state constants
const AI_STATE_IDLE := 0
const AI_STATE_WALKING := 1
const AI_STATE_WORKING := 2
const AI_STATE_COMBAT := 3
const AI_STATE_RESTING := 4

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _background_overlay: ColorRect = $BackgroundOverlay
@onready var _panel: PanelContainer = $Panel
@onready var _close_button: Button = $Panel/MarginContainer/VBoxContainer/Header/CloseButton
@onready var _enemy_title_label: Label = $Panel/MarginContainer/VBoxContainer/EnemyInfoSection/EnemyInfoContent/EnemyTitleRow/EnemyTitleLabel
@onready var _enemy_strength_label: Label = $Panel/MarginContainer/VBoxContainer/EnemyInfoSection/EnemyInfoContent/EnemyDetailsRow/EnemyStrengthLabel
@onready var _enemy_animal_icons: HBoxContainer = $Panel/MarginContainer/VBoxContainer/EnemyInfoSection/EnemyInfoContent/EnemyDetailsRow/EnemyAnimalIcons
@onready var _scroll_container: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer
@onready var _animal_list_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/AnimalListContainer
@onready var _no_animals_label: Label = $Panel/MarginContainer/VBoxContainer/NoAnimalsLabel
@onready var _team_count_label: Label = $Panel/MarginContainer/VBoxContainer/TeamSummarySection/TeamCountRow/TeamCountLabel
@onready var _team_strength_label: Label = $Panel/MarginContainer/VBoxContainer/TeamSummarySection/TeamCountRow/TeamStrengthLabel
@onready var _difficulty_label: Label = $Panel/MarginContainer/VBoxContainer/TeamSummarySection/DifficultyRow/DifficultyLabel
@onready var _warning_banner: Label = $Panel/MarginContainer/VBoxContainer/TeamSummarySection/WarningBanner
@onready var _cancel_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/CancelButton
@onready var _fight_button: Button = $Panel/MarginContainer/VBoxContainer/ButtonRow/FightButton

# =============================================================================
# STATE
# =============================================================================

## Currently selected animals for combat team
var _selected_animals: Array[Animal] = []

## Current contested hex coordinate
var _current_hex: Vector2i = Vector2i.ZERO

## Current wild herd ID
var _current_herd_id: String = ""

## Cached herd data
var _herd_data: WildHerdManager.WildHerd = null

## Is the modal visible/active
var _is_showing: bool = false

## Animation tween
var _fade_tween: Tween

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Start hidden
	visible = false
	modulate.a = 0.0

	# Add to group for discovery
	add_to_group("combat_team_selection_modals")

	# Connect buttons
	if _close_button:
		_close_button.pressed.connect(_on_cancel_pressed)
	if _cancel_button:
		_cancel_button.pressed.connect(_on_cancel_pressed)
	if _fight_button:
		_fight_button.pressed.connect(_on_fight_pressed)

	# Connect background overlay for tap-outside-to-dismiss
	if _background_overlay:
		_background_overlay.gui_input.connect(_on_background_input)

	# Connect to EventBus for combat requests (AR5)
	if EventBus:
		EventBus.combat_requested.connect(_on_combat_requested)

	GameLogger.info("UI", "CombatTeamSelectionModal initialized")


## Cleanup signal connections when removed from tree (AR18).
func _exit_tree() -> void:
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()

	if EventBus:
		if EventBus.combat_requested.is_connected(_on_combat_requested):
			EventBus.combat_requested.disconnect(_on_combat_requested)

# =============================================================================
# PUBLIC API
# =============================================================================

## Show the modal for a combat request (AC 1).
## @param hex_coord The contested hex coordinate
## @param herd_id The wild herd ID to fight
func show_for_combat(hex_coord: Vector2i, herd_id: String) -> void:
	if herd_id.is_empty():
		GameLogger.warn("UI", "CombatTeamSelectionModal: Cannot show with empty herd_id")
		return

	_current_hex = hex_coord
	_current_herd_id = herd_id

	# Query herd data from WildHerdManager
	_herd_data = _get_herd_data(herd_id)
	if not _herd_data:
		GameLogger.warn("UI", "CombatTeamSelectionModal: No herd found for ID: %s" % herd_id)
		return

	# Clear previous selection
	_selected_animals.clear()

	# Populate enemy info (AC 18)
	_populate_enemy_info(_herd_data)

	# Populate animal list (AC 2, 20)
	_populate_animal_list()

	# Update team summary (AC 4, 14)
	_update_team_summary()

	# Update fight button state (AC 6)
	_update_fight_button_state()

	# Show with animation
	_show_with_animation()

	GameLogger.info("UI", "CombatTeamSelectionModal shown for hex %s, herd %s" % [hex_coord, herd_id])


## Dismiss the modal with fade-out animation (AC 15, 17).
func dismiss() -> void:
	if not _is_showing:
		return

	_is_showing = false

	# Fade out animation
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	_fade_tween.tween_callback(func():
		visible = false
		_clear_animal_list()
	)

	GameLogger.debug("UI", "CombatTeamSelectionModal dismissed")


## Check if the modal is currently showing.
func is_showing() -> bool:
	return _is_showing


## Get the currently selected animals.
func get_selected_animals() -> Array[Animal]:
	return _selected_animals.duplicate()


## Get the current hex coordinate.
func get_current_hex() -> Vector2i:
	return _current_hex


## Get the current herd ID.
func get_current_herd_id() -> String:
	return _current_herd_id

# =============================================================================
# ENEMY INFO (AC 18)
# =============================================================================

## Populate enemy herd information display.
func _populate_enemy_info(herd: WildHerdManager.WildHerd) -> void:
	if not herd:
		return

	# Title with animal count (AC 18)
	if _enemy_title_label:
		_enemy_title_label.text = "Enemy: Wild Herd (%d animals)" % herd.get_animal_count()

	# Strength display
	if _enemy_strength_label:
		_enemy_strength_label.text = "💪 Strength: %d" % herd.get_total_strength()

	# Animal type icons
	if _enemy_animal_icons:
		# Clear existing icons
		for child in _enemy_animal_icons.get_children():
			child.queue_free()

		# Add icons for each animal type
		var animal_types := herd.get_animal_types()
		for animal_type in animal_types:
			var icon_label := Label.new()
			icon_label.text = _get_animal_icon(animal_type)
			icon_label.add_theme_font_size_override("font_size", 18)
			_enemy_animal_icons.add_child(icon_label)


## Get animal icon for display (delegates to shared utility).
func _get_animal_icon(animal_type: String) -> String:
	return GameConstants.get_animal_icon(animal_type)

# =============================================================================
# ANIMAL LIST POPULATION (AC 2, 8, 9, 10, 11, 20)
# =============================================================================

## Populate the animal list with available player animals.
## @note AC 21 Performance: For 50+ animals, consider implementing virtual list
## or lazy loading. Current VBoxContainer is adequate for typical counts (<30).
## TODO: If animal counts grow significantly, implement ItemList with virtual scrolling.
func _populate_animal_list() -> void:
	_clear_animal_list()

	var available_animals := _get_available_animals()

	# Sort animals (AC 20): idle first, then energy desc, then strength desc
	_sort_animals(available_animals)

	# Check if no animals available
	if available_animals.is_empty():
		if _no_animals_label:
			_no_animals_label.visible = true
			_no_animals_label.text = "No animals available for combat"
		if _scroll_container:
			_scroll_container.visible = false
		return

	if _no_animals_label:
		_no_animals_label.visible = false
	if _scroll_container:
		_scroll_container.visible = true

	# Create item for each animal
	for animal in available_animals:
		var item := _create_animal_item(animal)
		if _animal_list_container:
			_animal_list_container.add_child(item)


## Clear the animal list.
func _clear_animal_list() -> void:
	if not _animal_list_container:
		return

	for child in _animal_list_container.get_children():
		child.queue_free()


## Get all available player animals for combat.
func _get_available_animals() -> Array[Animal]:
	var result: Array[Animal] = []

	var all_animals := get_tree().get_nodes_in_group("animals")

	for node in all_animals:
		var animal := node as Animal
		if not is_instance_valid(animal):
			continue
		if not animal.is_initialized():
			continue

		# Skip wild animals
		if animal.is_wild:
			continue

		# Include all player animals (availability checked in item setup)
		result.append(animal)

	return result


## Sort animals by availability: idle first, then energy desc, then strength desc (AC 20).
func _sort_animals(animals: Array[Animal]) -> void:
	animals.sort_custom(func(a: Animal, b: Animal) -> bool:
		var a_state := _get_animal_ai_state(a)
		var b_state := _get_animal_ai_state(b)

		# Idle animals first
		var a_idle := (a_state == AI_STATE_IDLE or a_state == AI_STATE_WALKING)
		var b_idle := (b_state == AI_STATE_IDLE or b_state == AI_STATE_WALKING)
		if a_idle != b_idle:
			return a_idle  # true comes first

		# Resting animals last (not available)
		var a_resting := (a_state == AI_STATE_RESTING)
		var b_resting := (b_state == AI_STATE_RESTING)
		if a_resting != b_resting:
			return b_resting  # false (not resting) comes first

		# Then by energy descending
		var a_energy := _get_animal_energy_percent(a)
		var b_energy := _get_animal_energy_percent(b)
		if abs(a_energy - b_energy) > 0.01:
			return a_energy > b_energy

		# Then by strength descending
		var a_strength := a.stats.strength if a.stats else 0
		var b_strength := b.stats.strength if b.stats else 0
		return a_strength > b_strength
	)


## Create an animal item for the list.
func _create_animal_item(animal: Animal) -> Control:
	# Load item scene
	var item_scene_path := "res://scenes/ui/gameplay/combat_animal_item.tscn"
	if ResourceLoader.exists(item_scene_path):
		var item_scene := load(item_scene_path) as PackedScene
		if item_scene:
			var item: Control = item_scene.instantiate()
			if item:
				if item.has_method("setup"):
					item.setup(animal)
				if item.has_signal("selection_toggled"):
					item.selection_toggled.connect(_on_animal_selection_changed)

				# Check availability
				var ai_state := _get_animal_ai_state(animal)
				if item.has_method("set_available"):
					if ai_state == AI_STATE_RESTING:
						item.set_available(false, "Needs rest")
					elif ai_state == AI_STATE_COMBAT:
						item.set_available(false, "In combat")
					else:
						item.set_available(true, "")

				return item

	# Fallback: create simple item
	return _create_fallback_animal_item(animal)


## Create fallback item when scene is not available.
## Stores animal reference in metadata for _set_animal_item_selected compatibility.
func _create_fallback_animal_item(animal: Animal) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var animal_id := animal.get_animal_id() if animal.has_method("get_animal_id") else "Animal"
	var energy_percent := int(_get_animal_energy_percent(animal) * 100)
	var strength := animal.stats.strength if animal.stats else 0

	button.text = "%s 💪%d ⚡%d%%" % [animal_id, strength, energy_percent]
	button.add_theme_font_size_override("font_size", 14)
	button.toggle_mode = true

	# Store animal reference for _set_animal_item_selected
	button.set_meta("_animal", animal)

	# Check availability
	var ai_state := _get_animal_ai_state(animal)
	if ai_state == AI_STATE_RESTING or ai_state == AI_STATE_COMBAT:
		button.disabled = true
		button.text += " (unavailable)"
	else:
		button.toggled.connect(func(toggled: bool):
			_on_animal_selection_changed(animal, toggled)
		)

	return button


## Get animal's AI state.
func _get_animal_ai_state(animal: Animal) -> int:
	var ai := animal.get_node_or_null("AIComponent") as AIComponent
	if ai and ai.has_method("get_current_state"):
		return ai.get_current_state()
	return AI_STATE_IDLE


## Get animal's energy as percentage (0.0 - 1.0).
func _get_animal_energy_percent(animal: Animal) -> float:
	var stats_comp := animal.get_node_or_null("StatsComponent")
	if stats_comp:
		var energy: int = stats_comp.get_energy() if stats_comp.has_method("get_energy") else 100
		var max_energy: int = stats_comp.get_max_energy() if stats_comp.has_method("get_max_energy") else 100
		if max_energy > 0:
			return float(energy) / float(max_energy)
	return 1.0

# =============================================================================
# TEAM SELECTION LOGIC (AC 3, 4, 5, 6, 7, 14)
# =============================================================================

## Handle animal selection change.
func _on_animal_selection_changed(animal: Animal, selected: bool) -> void:
	# Null safety (AR18)
	if not is_instance_valid(animal):
		GameLogger.warn("UI", "CombatTeamSelectionModal: Cannot change selection for invalid animal")
		return

	if selected:
		# Check max team size (AC 5)
		if _selected_animals.size() >= MAX_TEAM_SIZE:
			GameLogger.info("UI", "Team is full! Deselect an animal first")
			# Reject selection - find and unselect the item
			_set_animal_item_selected(animal, false)
			return

		# Add to team
		if animal not in _selected_animals:
			_selected_animals.append(animal)
			# AC 8: Warn about production impact if animal is working
			var ai_state := _get_animal_ai_state(animal)
			if ai_state == AI_STATE_WORKING:
				_show_working_animal_warning(animal)
	else:
		# Remove from team
		_selected_animals.erase(animal)

	# Update summary and button
	_update_team_summary()
	_update_fight_button_state()


## Set an animal item's selected state.
func _set_animal_item_selected(animal: Animal, selected: bool) -> void:
	if not _animal_list_container:
		return

	for child in _animal_list_container.get_children():
		# Check CombatAnimalItem (has get_animal/set_selected methods)
		if child.has_method("get_animal") and child.has_method("set_selected"):
			if child.get_animal() == animal:
				child.set_selected(selected)
				return
		# Check fallback Button (uses metadata for animal reference)
		elif child is Button and child.has_meta("_animal"):
			if child.get_meta("_animal") == animal:
				child.button_pressed = selected
				return

# =============================================================================
# TEAM SUMMARY DISPLAY (AC 4, 12, 14)
# =============================================================================

## Update the team summary display.
func _update_team_summary() -> void:
	var team_size := _selected_animals.size()
	var team_strength := _calculate_team_strength()

	# Team count (AC 4)
	if _team_count_label:
		_team_count_label.text = "Team: %d/%d selected" % [team_size, MAX_TEAM_SIZE]

	# Team strength
	if _team_strength_label:
		_team_strength_label.text = "💪 %d" % team_strength

	# No animals selected message (AC 14)
	if team_size == 0:
		if _no_animals_label:
			_no_animals_label.visible = true
			_no_animals_label.text = "Select animals to form your combat team"
		if _difficulty_label:
			_difficulty_label.text = "Difficulty: --"
			_difficulty_label.add_theme_color_override("font_color", COLOR_UNKNOWN)
		if _warning_banner:
			_warning_banner.visible = false
		return
	else:
		if _no_animals_label:
			_no_animals_label.visible = false

	# Calculate difficulty (AC 4, 12)
	var herd_strength := _herd_data.get_total_strength() if _herd_data else 0
	var difficulty := _calculate_difficulty(team_strength, herd_strength)

	if _difficulty_label:
		_difficulty_label.text = "Difficulty: %s" % difficulty["label"]
		_difficulty_label.add_theme_color_override("font_color", difficulty["color"])

	# Warning banner for dangerous difficulty (AC 12)
	if _warning_banner:
		_warning_banner.visible = (difficulty["label"] == "Dangerous")


## Calculate total team strength.
func _calculate_team_strength() -> int:
	var total := 0
	for animal in _selected_animals:
		if animal and animal.stats:
			total += animal.stats.strength
	return total


## Calculate difficulty based on team vs herd strength.
func _calculate_difficulty(team_strength: int, herd_strength: int) -> Dictionary:
	if team_strength == 0:
		return {"label": "Unknown", "color": COLOR_UNKNOWN}

	var ratio: float = float(herd_strength) / team_strength

	if ratio < DIFFICULTY_EASY_MAX:
		return {"label": "Easy", "color": COLOR_EASY}
	elif ratio < DIFFICULTY_MEDIUM_MAX:
		return {"label": "Medium", "color": COLOR_MEDIUM}
	elif ratio < DIFFICULTY_HIGH_MAX:
		return {"label": "Challenging", "color": COLOR_HIGH}
	else:
		return {"label": "Dangerous", "color": COLOR_DANGEROUS}

# =============================================================================
# FIGHT BUTTON STATE (AC 6, 7)
# =============================================================================

## Update fight button enabled state.
func _update_fight_button_state() -> void:
	if not _fight_button:
		return

	var team_size := _selected_animals.size()

	# Disable if below minimum (AC 6)
	if team_size < MIN_TEAM_SIZE:
		_fight_button.disabled = true
		_fight_button.tooltip_text = "Select at least 1 animal"
	else:
		# Enable when valid (AC 7)
		_fight_button.disabled = false
		_fight_button.tooltip_text = ""

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

## Handle combat request from EventBus.
func _on_combat_requested(hex_coord: Vector2i, herd_id: String) -> void:
	show_for_combat(hex_coord, herd_id)


## Handle cancel button pressed (AC 15).
func _on_cancel_pressed() -> void:
	modal_cancelled.emit()
	dismiss()
	GameLogger.debug("UI", "CombatTeamSelectionModal cancelled")


## Handle fight button pressed (AC 16).
func _on_fight_pressed() -> void:
	if _selected_animals.size() < MIN_TEAM_SIZE:
		return

	# Convert to untyped array for signal
	var team_array: Array = []
	for animal in _selected_animals:
		team_array.append(animal)

	# Emit local signal
	combat_team_selected.emit(team_array, _current_hex, _current_herd_id)

	# Emit EventBus signal for cross-system communication (AR5)
	if EventBus:
		EventBus.combat_team_selected.emit(team_array, _current_hex, _current_herd_id)

	GameLogger.info("UI", "Combat team selected: %d animals for hex %s, herd %s" % [
		team_array.size(), _current_hex, _current_herd_id
	])

	dismiss()


## Handle background tap (AC 15).
func _on_background_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_cancel_pressed()
	elif event is InputEventScreenTouch and event.pressed:
		_on_cancel_pressed()

# =============================================================================
# ANIMATION
# =============================================================================

## Show modal with fade-in animation.
func _show_with_animation() -> void:
	_is_showing = true
	visible = true

	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)

# =============================================================================
# HELPERS
# =============================================================================

## Get herd data from WildHerdManager.
func _get_herd_data(herd_id: String) -> WildHerdManager.WildHerd:
	var wild_herd_managers := get_tree().get_nodes_in_group("wild_herd_managers")
	if wild_herd_managers.size() > 0:
		var manager: WildHerdManager = wild_herd_managers[0]
		return manager.get_herd(herd_id)
	return null


## Show warning when selecting a working animal (AC 8).
## Warns that removing from work will impact production.
func _show_working_animal_warning(animal: Animal) -> void:
	var animal_id := animal.get_animal_id() if animal.has_method("get_animal_id") else "Animal"
	GameLogger.info("UI", "Warning: %s is currently working. Selecting for combat will impact production." % animal_id)

	# Show visual warning via warning banner temporarily
	if _warning_banner:
		var original_text := _warning_banner.text
		var was_visible := _warning_banner.visible
		_warning_banner.text = "⚠️ %s is working - combat will stop production!" % animal_id
		_warning_banner.visible = true

		# Reset after 2 seconds
		var timer := get_tree().create_timer(2.0)
		timer.timeout.connect(func():
			if is_instance_valid(_warning_banner):
				_warning_banner.text = original_text
				_warning_banner.visible = was_visible or _is_dangerous_difficulty()
		)


## Check if current difficulty is dangerous (for warning banner visibility).
func _is_dangerous_difficulty() -> bool:
	if _selected_animals.is_empty() or not _herd_data:
		return false
	var team_strength := _calculate_team_strength()
	var herd_strength := _herd_data.get_total_strength()
	if team_strength == 0:
		return false
	var ratio: float = float(herd_strength) / team_strength
	return ratio >= DIFFICULTY_HIGH_MAX


## Get the animal item count (for testing).
func get_animal_item_count() -> int:
	if not _animal_list_container:
		return 0
	return _animal_list_container.get_child_count()
