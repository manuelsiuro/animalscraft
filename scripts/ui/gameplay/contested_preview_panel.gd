## ContestedPreviewPanel - Shows herd information for contested territory.
## Displays herd size, strength estimate, difficulty label, and battle button.
## Appears when player taps a contested hex.
##
## Architecture: scripts/ui/gameplay/contested_preview_panel.gd
## Story: 5-3-display-contested-territory
class_name ContestedPreviewPanel
extends Control

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the battle button is pressed
signal battle_pressed(hex_coord: Vector2i, herd_id: String)

## Emitted when the panel is dismissed
signal panel_dismissed()

# =============================================================================
# CONSTANTS
# =============================================================================

## Difficulty thresholds (ratio of herd strength to player strength)
const DIFFICULTY_EASY_MAX: float = 0.6  # Below 60% = Easy
const DIFFICULTY_MEDIUM_MAX: float = 1.0  # 60-100% = Medium
const DIFFICULTY_HIGH_MAX: float = 1.5  # 100-150% = High/Challenging
# Above 150% = Dangerous

## Difficulty colors
const COLOR_EASY: Color = Color("#4CAF50")  # Green
const COLOR_MEDIUM: Color = Color("#FFC107")  # Yellow
const COLOR_HIGH: Color = Color("#FF9800")  # Orange
const COLOR_DANGEROUS: Color = Color("#F44336")  # Red
const COLOR_UNKNOWN: Color = Color("#9E9E9E")  # Gray

## Animation durations
const FADE_DURATION: float = 0.2  # AC8: fade-out animation

# =============================================================================
# STATE
# =============================================================================

## Current hex coordinate being displayed
var _current_hex: Vector2i = Vector2i.ZERO

## Current herd ID being displayed
var _current_herd_id: String = ""

## Is the panel visible/active
var _is_showing: bool = false

## Animation tween
var _fade_tween: Tween

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _panel_container: PanelContainer = $PanelContainer
@onready var _title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/TitleLabel
@onready var _animal_icons_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/AnimalsRow/AnimalIconsContainer
@onready var _strength_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StrengthRow/StrengthLabel
@onready var _difficulty_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DifficultyRow/DifficultyLabel
@onready var _difficulty_row: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/DifficultyRow
@onready var _battle_button: Button = $PanelContainer/MarginContainer/VBoxContainer/BattleButton

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Start hidden
	visible = false
	modulate.a = 0.0

	# Add to group for discovery by SelectionManager
	add_to_group("contested_preview_panels")

	# Connect button
	if _battle_button:
		_battle_button.pressed.connect(_on_battle_pressed)

	# Code Review Fix: Auto-register with SelectionManager for reliable initialization
	call_deferred("_register_with_selection_manager")

	GameLogger.info("UI", "ContestedPreviewPanel initialized")


func _exit_tree() -> void:
	# Clean up any running tweens
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()


## Code Review Fix: Auto-register with SelectionManager for reliable panel reference.
func _register_with_selection_manager() -> void:
	# SelectionManager is an autoload, access directly if available
	if has_node("/root/SelectionManager"):
		var selection_manager := get_node("/root/SelectionManager")
		if selection_manager.has_method("set_contested_preview_panel"):
			selection_manager.set_contested_preview_panel(self)
			GameLogger.debug("UI", "ContestedPreviewPanel registered with SelectionManager")


## Handle input for tap-outside-to-dismiss (AC8).
func _input(event: InputEvent) -> void:
	if not _is_showing:
		return

	# Check for tap/click outside panel
	if event is InputEventScreenTouch and not event.pressed:
		_check_dismiss(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_check_dismiss(event.position)


func _check_dismiss(screen_pos: Vector2) -> void:
	# Check if tap was outside the panel
	if not _panel_container:
		return

	var panel_rect := _panel_container.get_global_rect()
	if not panel_rect.has_point(screen_pos):
		dismiss()
		get_viewport().set_input_as_handled()

# =============================================================================
# PUBLIC API
# =============================================================================

## Show the panel for a contested hex with herd information (AC5).
## @param hex_coord The contested hex coordinate
func show_for_hex(hex_coord: HexCoord) -> void:
	if hex_coord == null:
		GameLogger.warn("UI", "ContestedPreviewPanel: Cannot show for null hex")
		return

	_current_hex = hex_coord.to_vector()

	# Query herd data from WildHerdManager
	var herd: WildHerdManager.WildHerd = null
	var wild_herd_managers := get_tree().get_nodes_in_group("wild_herd_managers")
	if wild_herd_managers.size() > 0:
		var manager: WildHerdManager = wild_herd_managers[0]
		herd = manager.get_herd_at(hex_coord)

	if not herd:
		GameLogger.warn("UI", "ContestedPreviewPanel: No herd at hex %s" % _current_hex)
		return

	_current_herd_id = herd.herd_id

	# Populate panel data (AC5)
	_populate_panel_data(herd)

	# Update difficulty (AC7)
	_update_difficulty_display(herd)

	# Update battle button state (AC10)
	_update_battle_button_state()

	# Position panel (AC5: above tapped hex)
	_position_panel(hex_coord)

	# Show with fade-in
	_show_with_animation()


## Dismiss the panel with fade-out animation (AC8).
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
		panel_dismissed.emit()
	)

	GameLogger.debug("UI", "ContestedPreviewPanel dismissed")


## Check if the panel is currently showing.
## @return True if panel is visible
func is_showing() -> bool:
	return _is_showing


## Get the current hex coordinate being displayed.
## @return The hex coordinate or Vector2i.ZERO if not showing
func get_current_hex() -> Vector2i:
	return _current_hex


## Get the current herd ID being displayed.
## @return The herd ID or empty string if not showing
func get_current_herd_id() -> String:
	return _current_herd_id

# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Populate panel with herd data (AC5).
func _populate_panel_data(herd: WildHerdManager.WildHerd) -> void:
	# Title with animal count
	if _title_label:
		_title_label.text = "Wild Herd (%d animals)" % herd.get_animal_count()

	# Animal type icons
	if _animal_icons_container:
		# Clear existing icons
		for child in _animal_icons_container.get_children():
			child.queue_free()

		# Add icons for each animal type
		var animal_types := herd.get_animal_types()
		for animal_type in animal_types:
			var icon_label := Label.new()
			icon_label.text = _get_animal_icon(animal_type)
			icon_label.add_theme_font_size_override("font_size", 24)
			_animal_icons_container.add_child(icon_label)

	# Strength estimate (AC5)
	if _strength_label:
		var strength := herd.get_total_strength()
		var strength_category := _categorize_strength(strength)
		_strength_label.text = "%s (%d)" % [strength_category, strength]


## Update difficulty display based on herd vs player strength (AC7).
func _update_difficulty_display(herd: WildHerdManager.WildHerd) -> void:
	var player_strength := _get_recommended_team_strength()
	var herd_strength := herd.get_total_strength()
	var difficulty := _calculate_difficulty_label(herd_strength, player_strength)

	if _difficulty_label:
		_difficulty_label.text = difficulty["label"]
		_difficulty_label.add_theme_color_override("font_color", difficulty["color"])

	# Show/hide difficulty row based on whether we can compare
	if _difficulty_row:
		_difficulty_row.visible = player_strength > 0

	# Show warning for challenging/dangerous (AC7)
	if difficulty["label"] in ["Challenging", "Dangerous"]:
		if _difficulty_label:
			_difficulty_label.text = "⚠️ " + difficulty["label"]


## Update battle button enabled state (AC10).
func _update_battle_button_state() -> void:
	if not _battle_button:
		return

	var has_available_animals := _has_available_combat_animals()
	_battle_button.disabled = not has_available_animals

	if not has_available_animals:
		_battle_button.tooltip_text = "Assign animals first"
	else:
		_battle_button.tooltip_text = ""


## Position panel above the tapped hex (AC5).
func _position_panel(hex_coord: HexCoord) -> void:
	# Get camera for world-to-screen conversion
	var camera := get_viewport().get_camera_3d()
	if not camera:
		# Fallback: center on screen
		anchor_left = 0.5
		anchor_right = 0.5
		anchor_top = 0.3
		anchor_bottom = 0.3
		return

	# Get hex world position
	var world_pos := HexGrid.hex_to_world(hex_coord)
	world_pos.y = 0.5  # Slightly above ground for better projection

	# Convert to screen position
	var screen_pos := camera.unproject_position(world_pos)

	# Get viewport size for clamping
	var viewport_size := get_viewport_rect().size
	var panel_size := _panel_container.size if _panel_container else Vector2(300, 200)

	# Position panel above the hex with some offset
	var target_pos := screen_pos - Vector2(panel_size.x / 2, panel_size.y + 50)

	# Clamp to viewport bounds
	target_pos.x = clampf(target_pos.x, 10, viewport_size.x - panel_size.x - 10)
	target_pos.y = clampf(target_pos.y, 10, viewport_size.y - panel_size.y - 10)

	position = target_pos


## Show with fade-in animation.
func _show_with_animation() -> void:
	_is_showing = true
	visible = true

	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)

	GameLogger.debug("UI", "ContestedPreviewPanel shown for hex %s, herd %s" % [_current_hex, _current_herd_id])


## Get animal icon for display.
func _get_animal_icon(animal_type: String) -> String:
	match animal_type:
		"rabbit":
			return "🐰"
		"fox":
			return "🦊"
		"deer":
			return "🦌"
		"bear":
			return "🐻"
		"wolf":
			return "🐺"
		_:
			return "🐾"


## Categorize strength into Low/Medium/High text.
func _categorize_strength(strength: int) -> String:
	if strength <= 10:
		return "Low"
	elif strength <= 20:
		return "Medium"
	else:
		return "High"


## Calculate difficulty label and color based on strength comparison (AC7).
## @param herd_strength The total herd strength
## @param player_strength The player's recommended team strength
## @return Dictionary with "label" and "color" keys
func _calculate_difficulty_label(herd_strength: int, player_strength: int) -> Dictionary:
	if player_strength == 0:
		return {"label": "Unknown", "color": COLOR_UNKNOWN}

	var ratio: float = float(herd_strength) / player_strength

	if ratio < DIFFICULTY_EASY_MAX:
		return {"label": "Easy", "color": COLOR_EASY}
	elif ratio < DIFFICULTY_MEDIUM_MAX:
		return {"label": "Medium", "color": COLOR_MEDIUM}
	elif ratio < DIFFICULTY_HIGH_MAX:
		return {"label": "Challenging", "color": COLOR_HIGH}
	else:
		return {"label": "Dangerous", "color": COLOR_DANGEROUS}


## Get recommended team strength from player's available animals (AC7).
## @return Total strength of player's available combat animals
func _get_recommended_team_strength() -> int:
	var total_strength := 0
	var animals := get_tree().get_nodes_in_group("animals")

	for animal_node in animals:
		var animal := animal_node as Animal
		if not is_instance_valid(animal) or not animal.is_initialized():
			continue

		# Only count non-wild, available animals
		if animal.is_wild:
			continue

		# Check if animal is available (not working)
		# For now, count all player animals
		if animal.stats:
			total_strength += animal.stats.strength

	return total_strength


## Check if player has animals available for combat (AC10).
## @return True if at least one animal is available
func _has_available_combat_animals() -> bool:
	var animals := get_tree().get_nodes_in_group("animals")

	for animal_node in animals:
		var animal := animal_node as Animal
		if not is_instance_valid(animal) or not animal.is_initialized():
			continue

		# Check if not wild
		if animal.is_wild:
			continue

		# Found at least one player animal
		return true

	return false


## Handle battle button press (AC6).
func _on_battle_pressed() -> void:
	if _current_herd_id.is_empty():
		GameLogger.warn("UI", "ContestedPreviewPanel: Battle pressed with no herd")
		return

	# Emit signal for combat system (AC6 - combat itself handled in Story 5-5)
	battle_pressed.emit(_current_hex, _current_herd_id)

	# Also emit EventBus signal for cross-system communication
	EventBus.combat_requested.emit(_current_hex, _current_herd_id)

	GameLogger.info("UI", "Combat requested for hex %s, herd %s" % [_current_hex, _current_herd_id])

	# Dismiss panel after requesting combat
	dismiss()
