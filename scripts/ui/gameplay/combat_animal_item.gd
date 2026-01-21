## CombatAnimalItem - Individual animal item in combat team selection list.
## Shows animal info (name, strength, energy, status) and handles selection toggle.
## Displays badges for working/tired animals and energy warnings.
##
## Architecture: scripts/ui/gameplay/combat_animal_item.gd
## Story: 5-4-create-combat-team-selection-ui
class_name CombatAnimalItem
extends PanelContainer

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when selection state changes
signal selection_toggled(animal: Animal, selected: bool)

# =============================================================================
# CONSTANTS
# =============================================================================

## Low energy threshold for warning display (AC 10)
const LOW_ENERGY_THRESHOLD: float = 0.2

## Status badge colors
const COLOR_IDLE: Color = Color("#4CAF50")  # Green
const COLOR_WORKING: Color = Color("#FFC107")  # Yellow/Orange
const COLOR_TIRED: Color = Color("#F44336")  # Red
const COLOR_WALKING: Color = Color("#2196F3")  # Blue

## Selection indicator glyphs
const CHECKBOX_UNCHECKED: String = "☐"
const CHECKBOX_CHECKED: String = "☑"

## Selection highlight colors
const COLOR_SELECTED_BORDER: Color = Color("#4CAF50")  # Green highlight
const COLOR_NORMAL_BORDER: Color = Color(0.4, 0.35, 0.3, 0.6)

## Energy bar colors
const COLOR_ENERGY_HIGH: Color = Color("#4CAF50")  # Green
const COLOR_ENERGY_MEDIUM: Color = Color("#FFC107")  # Yellow
const COLOR_ENERGY_LOW: Color = Color("#F44336")  # Red

## AIComponent state constants
const AI_STATE_IDLE := 0
const AI_STATE_WALKING := 1
const AI_STATE_WORKING := 2
const AI_STATE_COMBAT := 3
const AI_STATE_RESTING := 4

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _selection_indicator: Label = $HBoxContainer/SelectionIndicator
@onready var _animal_icon: Label = $HBoxContainer/AnimalIcon
@onready var _name_label: Label = $HBoxContainer/InfoContainer/NameRow/NameLabel
@onready var _status_badge: Label = $HBoxContainer/InfoContainer/NameRow/StatusBadge
@onready var _strength_label: Label = $HBoxContainer/InfoContainer/StatsRow/StrengthLabel
@onready var _energy_bar: ProgressBar = $HBoxContainer/InfoContainer/StatsRow/EnergyContainer/EnergyBar
@onready var _energy_label: Label = $HBoxContainer/InfoContainer/StatsRow/EnergyContainer/EnergyLabel
@onready var _disabled_overlay: ColorRect = $DisabledOverlay
@onready var _disabled_label: Label = $DisabledOverlay/DisabledLabel

# =============================================================================
# STATE
# =============================================================================

## Reference to the animal this item represents
var _animal: Animal = null

## Whether this item is currently selected
var _is_selected: bool = false

## Whether this item is available for selection
var _is_available: bool = true

## Cached panel style
var _normal_style: StyleBoxFlat
var _selected_style: StyleBoxFlat

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Cache and create styles
	_normal_style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	_selected_style = _normal_style.duplicate() as StyleBoxFlat
	if _selected_style:
		_selected_style.border_color = COLOR_SELECTED_BORDER
		_selected_style.border_width_left = 2
		_selected_style.border_width_top = 2
		_selected_style.border_width_right = 2
		_selected_style.border_width_bottom = 2


## Handle input for selection toggle (AC 3).
func _gui_input(event: InputEvent) -> void:
	if not _is_available:
		return

	# Handle tap/click to toggle selection
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_toggle_selection()
		accept_event()
	elif event is InputEventScreenTouch and event.pressed:
		_toggle_selection()
		accept_event()

# =============================================================================
# PUBLIC API
# =============================================================================

## Setup the item with animal data (AC 2).
func setup(animal: Animal) -> void:
	if animal == null:
		GameLogger.warn("UI", "CombatAnimalItem: Cannot setup with null animal")
		return

	_animal = animal

	# Animal icon
	if _animal_icon:
		var animal_type := animal.stats.animal_id if animal.stats else "unknown"
		_animal_icon.text = _get_animal_icon(animal_type)

	# Name/type (AC 2)
	if _name_label:
		var animal_id := animal.get_animal_id() if animal.has_method("get_animal_id") else "Animal"
		_name_label.text = animal_id

	# Strength stat (AC 2)
	if _strength_label:
		var strength := animal.stats.strength if animal.stats else 0
		_strength_label.text = "💪 %d" % strength

	# Energy level (AC 2)
	_update_energy_display()

	# Status badge (AC 2, 8)
	_update_status_badge()

	# Initial selection state
	_update_selection_visual()


## Set the selected state (AC 3).
func set_selected(selected: bool) -> void:
	if _is_selected == selected:
		return  # Idempotent

	_is_selected = selected
	_update_selection_visual()


## Get the selected state.
func is_selected() -> bool:
	return _is_selected


## Set the availability state (AC 9).
func set_available(available: bool, reason: String = "") -> void:
	_is_available = available

	if _disabled_overlay:
		_disabled_overlay.visible = not available

	if _disabled_label and not available:
		_disabled_label.text = reason if not reason.is_empty() else "Unavailable"


## Check if available for selection.
func is_available() -> bool:
	return _is_available


## Get the animal reference.
func get_animal() -> Animal:
	return _animal

# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Toggle selection state.
func _toggle_selection() -> void:
	_is_selected = not _is_selected
	_update_selection_visual()
	selection_toggled.emit(_animal, _is_selected)


## Update selection visual feedback (AC 3).
func _update_selection_visual() -> void:
	# Selection indicator checkbox
	if _selection_indicator:
		_selection_indicator.text = CHECKBOX_CHECKED if _is_selected else CHECKBOX_UNCHECKED
		_selection_indicator.add_theme_color_override("font_color",
			COLOR_SELECTED_BORDER if _is_selected else Color(0.8, 0.75, 0.7, 1))

	# Panel border highlight
	if _is_selected and _selected_style:
		add_theme_stylebox_override("panel", _selected_style)
	elif _normal_style:
		add_theme_stylebox_override("panel", _normal_style)


## Update energy display with warning for low energy (AC 2, 10).
func _update_energy_display() -> void:
	if not _animal:
		return

	var stats_comp := _animal.get_node_or_null("StatsComponent")
	var energy := 100
	var max_energy := 100

	if stats_comp:
		energy = stats_comp.get_energy() if stats_comp.has_method("get_energy") else 100
		max_energy = stats_comp.get_max_energy() if stats_comp.has_method("get_max_energy") else 100

	var energy_percent := float(energy) / float(max_energy) if max_energy > 0 else 1.0

	# Energy bar
	if _energy_bar:
		_energy_bar.value = energy_percent * 100

		# Color based on level
		var bar_style := _energy_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
		if bar_style:
			if energy_percent <= LOW_ENERGY_THRESHOLD:
				bar_style.bg_color = COLOR_ENERGY_LOW
			elif energy_percent <= 0.5:
				bar_style.bg_color = COLOR_ENERGY_MEDIUM
			else:
				bar_style.bg_color = COLOR_ENERGY_HIGH
			_energy_bar.add_theme_stylebox_override("fill", bar_style)

	# Energy label
	if _energy_label:
		_energy_label.text = "%d%%" % int(energy_percent * 100)

		# Low energy warning color (AC 10)
		if energy_percent <= LOW_ENERGY_THRESHOLD:
			_energy_label.add_theme_color_override("font_color", COLOR_ENERGY_LOW)
		else:
			_energy_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7, 1))


## Update status badge based on AI state (AC 2, 8, 9).
func _update_status_badge() -> void:
	if not _status_badge or not _animal:
		return

	var ai := _animal.get_node_or_null("AIComponent") as AIComponent
	var state := AI_STATE_IDLE
	if ai and ai.has_method("get_current_state"):
		state = ai.get_current_state()

	match state:
		AI_STATE_IDLE:
			_status_badge.text = "Idle"
			_status_badge.add_theme_color_override("font_color", COLOR_IDLE)
		AI_STATE_WALKING:
			_status_badge.text = "Moving"
			_status_badge.add_theme_color_override("font_color", COLOR_WALKING)
		AI_STATE_WORKING:
			# AC 8: Show "Working" badge
			_status_badge.text = "Working"
			_status_badge.add_theme_color_override("font_color", COLOR_WORKING)
		AI_STATE_RESTING:
			# AC 9: Show "Tired" badge
			_status_badge.text = "Tired"
			_status_badge.add_theme_color_override("font_color", COLOR_TIRED)
		AI_STATE_COMBAT:
			_status_badge.text = "Combat"
			_status_badge.add_theme_color_override("font_color", COLOR_TIRED)
		_:
			_status_badge.text = "Idle"
			_status_badge.add_theme_color_override("font_color", COLOR_IDLE)


## Get animal icon for display (delegates to shared utility).
func _get_animal_icon(animal_type: String) -> String:
	return GameConstants.get_animal_icon(animal_type)
