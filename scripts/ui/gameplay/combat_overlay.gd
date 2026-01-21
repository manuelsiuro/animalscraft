## CombatOverlay - Full-screen overlay for displaying combat animations.
## Shows both teams, handles attack animations, victory/defeat celebrations.
## Integrates with CombatManager via EventBus signals.
##
## Architecture: scripts/ui/gameplay/combat_overlay.gd
## Story: 5-6-display-combat-animations
##
## Usage:
##   # Automatically shown via EventBus signal
##   EventBus.combat_started.emit(hex_coord)
##
##   # Access CombatOverlay directly
##   var overlays := get_tree().get_nodes_in_group("combat_overlays")
##   if not overlays.is_empty():
##       var overlay := overlays[0] as CombatOverlay
class_name CombatOverlay
extends Control

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when SFX should be played (for audio integration in Epic 7)
signal combat_sfx_requested(sfx_id: String)

## Emitted when result is acknowledged and overlay closes
signal overlay_closed()

# =============================================================================
# CONSTANTS
# =============================================================================

## Animation timing (must fit within TURN_DELAY from CombatManager)
const ATTACK_LUNGE_DURATION: float = 0.5
const DAMAGE_POPUP_DURATION: float = 0.5
const SPLAT_DURATION: float = 0.3
const KNOCKOUT_STARS_DURATION: float = 0.5
const HEALTH_BAR_TWEEN_DURATION: float = 0.2

## Visual constants
const DAMAGE_POPUP_RISE_DISTANCE: int = 50
const DAMAGE_COLOR: Color = Color.RED
const HEALING_COLOR: Color = Color.GREEN

## Splat particle colors (cozy food-fight palette)
const SPLAT_COLORS: Array[Color] = [
	Color("#FFB347"),  # Orange (pie)
	Color("#FFFACD"),  # Lemon chiffon (cream)
	Color("#FF6347"),  # Tomato
]

## Fade animation duration
const FADE_DURATION: float = 0.3

## CanvasLayer sorting (high to render above game)
const OVERLAY_LAYER: int = 10

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _background: ColorRect = $Background
@onready var _arena_panel: PanelContainer = $ArenaPanel
@onready var _player_team_container: VBoxContainer = $ArenaPanel/MarginContainer/HBoxContainer/PlayerTeamContainer
@onready var _vs_label: Label = $ArenaPanel/MarginContainer/HBoxContainer/VSLabel
@onready var _enemy_team_container: VBoxContainer = $ArenaPanel/MarginContainer/HBoxContainer/EnemyTeamContainer
@onready var _battle_status_label: Label = $ArenaPanel/BattleStatusLabel
@onready var _animation_manager: Node = $CombatAnimationManager
@onready var _effects_container: Control = $EffectsContainer
@onready var _battle_result_panel: BattleResultPanel = $BattleResultPanel

# =============================================================================
# STATE
# =============================================================================

## Whether overlay is currently visible
var _is_showing: bool = false

## Current combat hex (for camera focus)
var _combat_hex: Vector2i = Vector2i.ZERO

## Player combatant displays (keyed by unit_id)
var _player_combatant_displays: Dictionary = {}

## Enemy combatant displays (keyed by unit_id)
var _enemy_combatant_displays: Dictionary = {}

## Reference to CombatManager for battle log access
var _combat_manager: Node = null

## Active tweens for pause/resume
var _active_tweens: Array[Tween] = []

## Fade tween
var _fade_tween: Tween = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Start hidden
	visible = false
	modulate.a = 0.0

	# Add to group for discovery
	add_to_group("combat_overlays")

	# Connect to EventBus signals (AR5)
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_ended.connect(_on_combat_ended)
	EventBus.combat_attack_occurred.connect(_on_combat_attack_occurred)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.game_resumed.connect(_on_game_resumed)

	# Connect to battle result panel if present
	if _battle_result_panel:
		_battle_result_panel.visible = false
		_battle_result_panel.result_acknowledged.connect(_on_result_acknowledged)

	GameLogger.info("UI", "CombatOverlay initialized")


## Cleanup signal connections when removed from tree (AR18).
func _exit_tree() -> void:
	# Kill any running tweens
	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()
	for tween in _active_tweens:
		if tween and tween.is_running():
			tween.kill()
	_active_tweens.clear()

	# Disconnect EventBus signals
	if EventBus.combat_started.is_connected(_on_combat_started):
		EventBus.combat_started.disconnect(_on_combat_started)
	if EventBus.combat_ended.is_connected(_on_combat_ended):
		EventBus.combat_ended.disconnect(_on_combat_ended)
	if EventBus.combat_attack_occurred.is_connected(_on_combat_attack_occurred):
		EventBus.combat_attack_occurred.disconnect(_on_combat_attack_occurred)
	if EventBus.game_paused.is_connected(_on_game_paused):
		EventBus.game_paused.disconnect(_on_game_paused)
	if EventBus.game_resumed.is_connected(_on_game_resumed):
		EventBus.game_resumed.disconnect(_on_game_resumed)

# =============================================================================
# PUBLIC API
# =============================================================================

## Check if overlay is currently showing.
func is_showing() -> bool:
	return _is_showing


## Get combatant display by unit_id.
## @param unit_id The CombatUnit's unit_id
## @param is_player_team Whether to search player or enemy displays
## @return The CombatantDisplay node or null
func get_combatant_display(unit_id: String, is_player_team: bool) -> Control:
	if is_player_team:
		return _player_combatant_displays.get(unit_id)
	else:
		return _enemy_combatant_displays.get(unit_id)


## Get the effects container for spawning particles/popups.
func get_effects_container() -> Control:
	return _effects_container


## Register a tween for pause/resume management.
func register_tween(tween: Tween) -> void:
	if tween:
		_active_tweens.append(tween)
		# Clean up when tween finishes
		tween.finished.connect(func(): _active_tweens.erase(tween))

# =============================================================================
# COMBAT LIFECYCLE (AC1, AC2, AC3, AC14)
# =============================================================================

## Handle combat_started signal (AC1, AC14).
func _on_combat_started(hex_coord: Vector2i) -> void:
	_combat_hex = hex_coord

	# Find CombatManager
	_combat_manager = _find_combat_manager()
	if not _combat_manager:
		GameLogger.warn("UI", "CombatOverlay: Cannot find CombatManager")

	# Build teams from CombatManager
	_build_team_displays()

	# Show overlay
	_show_overlay()

	# Disable camera controls (AC14)
	_set_camera_controls_enabled(false)

	GameLogger.info("UI", "CombatOverlay shown for combat at %s" % hex_coord)


## Handle combat_ended signal (AC10, AC11, AC12, AC13).
func _on_combat_ended(won: bool, captured_animals: Array) -> void:
	GameLogger.info("UI", "CombatOverlay: Combat ended, won=%s, captured=%d" % [won, captured_animals.size()])

	# Update status label
	if _battle_status_label:
		_battle_status_label.text = "🏁 Battle Complete!"

	# Get battle log for stats (AC19)
	var battle_log: Array = []
	if _combat_manager and _combat_manager.has_method("get_battle_log"):
		battle_log = _combat_manager.get_battle_log()

	# Show victory or defeat panel (AC10, AC11, AC12)
	if _battle_result_panel:
		if won:
			_battle_result_panel.show_victory(captured_animals, battle_log)
		else:
			_battle_result_panel.show_defeat(battle_log)
	else:
		# No result panel - just close after a delay
		get_tree().create_timer(1.0).timeout.connect(close_overlay)


## Handle combat_attack_occurred signal (AC4, AC5, AC6, AC7).
func _on_combat_attack_occurred(attacker: RefCounted, defender: RefCounted, damage: int, defender_hp: int) -> void:
	if not _is_showing:
		return

	# Get combatant displays
	var attacker_display := _get_display_for_unit(attacker)
	var defender_display := _get_display_for_unit(defender)

	if not attacker_display or not defender_display:
		GameLogger.warn("UI", "CombatOverlay: Cannot find displays for attack animation")
		return

	# Let animation manager handle the attack sequence
	if _animation_manager and _animation_manager.has_method("play_attack_sequence"):
		_animation_manager.play_attack_sequence(attacker_display, defender_display, damage, defender_hp)


## Handle game_paused signal (AC18).
func _on_game_paused() -> void:
	if not _is_showing:
		return

	# Pause all active tweens
	for tween in _active_tweens:
		if tween and tween.is_running():
			tween.pause()

	GameLogger.debug("UI", "CombatOverlay: Animations paused")


## Handle game_resumed signal (AC18).
func _on_game_resumed() -> void:
	if not _is_showing:
		return

	# Resume all paused tweens
	for tween in _active_tweens:
		if tween and is_instance_valid(tween):
			tween.play()

	GameLogger.debug("UI", "CombatOverlay: Animations resumed")

# =============================================================================
# OVERLAY VISIBILITY
# =============================================================================

## Show the overlay with fade animation.
func _show_overlay() -> void:
	_is_showing = true
	visible = true

	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, FADE_DURATION)

	# Update status label
	if _battle_status_label:
		_battle_status_label.text = "⚔️ Battle in Progress!"


## Hide the overlay with fade animation (AC15).
func close_overlay() -> void:
	if not _is_showing:
		return

	_is_showing = false

	# Re-enable camera controls (AC15)
	_set_camera_controls_enabled(true)

	if _fade_tween and _fade_tween.is_running():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	_fade_tween.tween_callback(func():
		visible = false
		_cleanup_displays()
		overlay_closed.emit()
	)

	GameLogger.info("UI", "CombatOverlay closed")

# =============================================================================
# TEAM DISPLAY BUILDING (AC2, AC3)
# =============================================================================

## Build combatant displays for both teams.
func _build_team_displays() -> void:
	# Clear existing displays
	_cleanup_displays()

	if not _combat_manager:
		return

	# Get player and enemy teams from CombatManager
	var player_team: Array = []
	var enemy_team: Array = []

	if "_player_team" in _combat_manager:
		player_team = _combat_manager._player_team
	if "_enemy_team" in _combat_manager:
		enemy_team = _combat_manager._enemy_team

	# Create player displays (left side) (AC2)
	for unit in player_team:
		var display := _create_combatant_display(unit, true)
		if display and _player_team_container:
			_player_team_container.add_child(display)
			_player_combatant_displays[unit.unit_id] = display

	# Create enemy displays (right side) (AC2)
	for unit in enemy_team:
		var display := _create_combatant_display(unit, false)
		if display and _enemy_team_container:
			_enemy_team_container.add_child(display)
			_enemy_combatant_displays[unit.unit_id] = display

	GameLogger.debug("UI", "Built displays: %d player, %d enemy" % [
		_player_combatant_displays.size(),
		_enemy_combatant_displays.size()
	])


## Create a single combatant display.
func _create_combatant_display(unit: RefCounted, is_player: bool) -> Control:
	var display_scene_path := "res://scenes/ui/gameplay/combatant_display.tscn"
	if ResourceLoader.exists(display_scene_path):
		var display_scene := load(display_scene_path) as PackedScene
		if display_scene:
			var display: Control = display_scene.instantiate()
			if display and display.has_method("setup"):
				display.setup(unit, is_player)
			return display

	# Fallback: create simple display
	return _create_fallback_display(unit, is_player)


## Create fallback display when scene is not available.
func _create_fallback_display(unit: RefCounted, is_player: bool) -> Control:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(80, 100)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Animal icon
	var icon := Label.new()
	var animal_type := "unknown"
	if unit.animal and unit.animal.stats:
		animal_type = unit.animal.stats.animal_id
	icon.text = GameConstants.get_animal_icon(animal_type)
	icon.add_theme_font_size_override("font_size", 32)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(icon)

	# Health bar (AC3)
	var health_bar := ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(70, 12)
	health_bar.value = 100.0
	health_bar.show_percentage = false
	container.add_child(health_bar)

	# Store unit reference
	container.set_meta("unit_id", unit.unit_id)
	container.set_meta("unit", unit)
	container.set_meta("health_bar", health_bar)
	container.set_meta("max_hp", unit.max_hp)
	container.set_meta("current_hp", unit.current_hp)

	return container


## Cleanup all combatant displays.
func _cleanup_displays() -> void:
	# Clear player displays
	for display in _player_combatant_displays.values():
		if is_instance_valid(display):
			display.queue_free()
	_player_combatant_displays.clear()

	# Clear enemy displays
	for display in _enemy_combatant_displays.values():
		if is_instance_valid(display):
			display.queue_free()
	_enemy_combatant_displays.clear()

# =============================================================================
# HELPERS
# =============================================================================

## Find CombatManager in scene.
func _find_combat_manager() -> Node:
	var managers := get_tree().get_nodes_in_group("combat_managers")
	if not managers.is_empty():
		return managers[0]
	return null


## Get combatant display for a CombatUnit.
func _get_display_for_unit(unit: RefCounted) -> Control:
	if not unit or not "unit_id" in unit:
		return null

	var unit_id: String = unit.unit_id
	var is_player: bool = unit.is_player_team if "is_player_team" in unit else false

	if is_player:
		return _player_combatant_displays.get(unit_id)
	else:
		return _enemy_combatant_displays.get(unit_id)


## Enable/disable camera controls (AC14, AC15).
func _set_camera_controls_enabled(enabled: bool) -> void:
	var cameras := get_tree().get_nodes_in_group("camera_controllers")
	if not cameras.is_empty():
		var controller := cameras[0]
		# CameraController uses set_enabled() method (Story 3-5)
		if controller.has_method("set_enabled"):
			controller.set_enabled(enabled)
		elif "enabled" in controller:
			controller.enabled = enabled

	# Also try direct camera node
	var camera := get_viewport().get_camera_3d()
	if camera:
		var cam_controller := camera.get_node_or_null("CameraController")
		if cam_controller:
			if cam_controller.has_method("set_enabled"):
				cam_controller.set_enabled(enabled)
			elif "enabled" in cam_controller:
				cam_controller.enabled = enabled


## Handle result panel Continue button (AC13).
func _on_result_acknowledged() -> void:
	GameLogger.debug("UI", "CombatOverlay: Result acknowledged, closing overlay")
	close_overlay()
