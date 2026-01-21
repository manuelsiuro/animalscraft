## CombatOpportunityBadge - Shows count of available combat opportunities.
## Displays a badge with sword icon and count of contested hexes.
## Tapping pans camera to nearest contested hex and opens preview panel.
##
## Architecture: scripts/ui/hud/combat_opportunity_badge.gd
## Story: 5-3-display-contested-territory (AC: 13, 14)
class_name CombatOpportunityBadge
extends Control

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when user taps the badge
signal badge_tapped()

## Emitted when camera has finished panning to contested hex
signal pan_completed(hex_coord: Vector2i)

# =============================================================================
# STATE
# =============================================================================

## Current count of contested hexes
var _contested_count: int = 0

## Reference to TerritoryManager
var _territory_manager: TerritoryManager

## Reference to camera for panning
var _camera: Camera3D

## Reference to contested preview panel (set externally)
var _preview_panel: ContestedPreviewPanel

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _badge_button: Button = $BadgeButton
@onready var _count_label: Label = $BadgeButton/HBoxContainer/CountLabel
@onready var _icon_label: Label = $BadgeButton/HBoxContainer/IconLabel

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Start hidden until we have contests
	visible = false

	# Connect button
	if _badge_button:
		_badge_button.pressed.connect(_on_badge_pressed)

	# Connect to EventBus signals
	EventBus.wild_herd_spawned.connect(_on_herd_spawned)
	EventBus.wild_herd_removed.connect(_on_herd_removed)
	EventBus.territory_ownership_changed.connect(_on_ownership_changed)
	EventBus.contested_territory_discovered.connect(_on_contested_discovered)

	# Find TerritoryManager
	call_deferred("_find_territory_manager")

	GameLogger.info("UI", "CombatOpportunityBadge initialized")


func _exit_tree() -> void:
	# Safe signal disconnection
	if EventBus.wild_herd_spawned.is_connected(_on_herd_spawned):
		EventBus.wild_herd_spawned.disconnect(_on_herd_spawned)
	if EventBus.wild_herd_removed.is_connected(_on_herd_removed):
		EventBus.wild_herd_removed.disconnect(_on_herd_removed)
	if EventBus.territory_ownership_changed.is_connected(_on_ownership_changed):
		EventBus.territory_ownership_changed.disconnect(_on_ownership_changed)
	if EventBus.contested_territory_discovered.is_connected(_on_contested_discovered):
		EventBus.contested_territory_discovered.disconnect(_on_contested_discovered)


func _find_territory_manager() -> void:
	var territory_managers := get_tree().get_nodes_in_group("territory_managers")
	if territory_managers.size() > 0:
		_territory_manager = territory_managers[0]

	var cameras := get_tree().get_nodes_in_group("cameras")
	if cameras.size() > 0:
		_camera = cameras[0] as Camera3D
	else:
		_camera = get_viewport().get_camera_3d()

	# Code Review Fix: Auto-discover preview panel via group for AC14 reliability
	if not _preview_panel:
		var panels := get_tree().get_nodes_in_group("contested_preview_panels")
		if panels.size() > 0:
			_preview_panel = panels[0] as ContestedPreviewPanel
			GameLogger.debug("UI", "CombatOpportunityBadge auto-discovered preview panel")

# =============================================================================
# PUBLIC API
# =============================================================================

## Set the preview panel reference for auto-opening after pan (AC14).
## @param panel The ContestedPreviewPanel instance
func set_preview_panel(panel: ContestedPreviewPanel) -> void:
	_preview_panel = panel


## Get current contested count.
## @return Number of contested hexes adjacent to player territory
func get_contested_count() -> int:
	return _contested_count


## Force refresh the contested count from TerritoryManager.
func refresh_count() -> void:
	_update_contested_count()

# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Update the contested count from TerritoryManager (AC13).
func _update_contested_count() -> void:
	if not _territory_manager:
		_find_territory_manager()
		if not _territory_manager:
			return

	_contested_count = _territory_manager.get_contested_count()
	_update_display()


## Update the visual display based on count (AC13).
func _update_display() -> void:
	if _count_label:
		_count_label.text = str(_contested_count)

	# Show badge only when count > 0 (AC13)
	visible = _contested_count > 0


## Handle badge tap - pan to nearest contested hex (AC14).
func _on_badge_pressed() -> void:
	badge_tapped.emit()

	if not _territory_manager or not _camera:
		return

	# Find nearest contested hex to camera center
	var nearest_hex := _find_nearest_contested_hex()
	if not nearest_hex:
		GameLogger.warn("UI", "CombatOpportunityBadge: No contested hex found")
		return

	# Pan camera to the contested hex
	_pan_camera_to_hex(nearest_hex)


## Find the nearest contested hex to the current camera position.
## @return The nearest contested HexCoord or null
func _find_nearest_contested_hex() -> HexCoord:
	if not _territory_manager or not _camera:
		return null

	var all_contested := _territory_manager.get_all_adjacent_contested()
	if all_contested.is_empty():
		return null

	# Get camera position for distance calculation
	var camera_pos := _camera.global_position
	var camera_hex_pos := Vector3(camera_pos.x, 0, camera_pos.z)

	var nearest: HexCoord = null
	var nearest_distance: float = INF

	for contested_hex in all_contested:
		var world_pos := HexGrid.hex_to_world(contested_hex)
		var distance := camera_hex_pos.distance_to(world_pos)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = contested_hex

	return nearest


## Pan camera to a hex position (AC14).
func _pan_camera_to_hex(hex: HexCoord) -> void:
	if not _camera:
		return

	var target_world := HexGrid.hex_to_world(hex)

	# Create tween for smooth camera pan
	var pan_tween := create_tween()
	pan_tween.set_ease(Tween.EASE_OUT)
	pan_tween.set_trans(Tween.TRANS_CUBIC)

	# Pan camera X and Z while keeping Y (height)
	var target_pos := Vector3(target_world.x, _camera.global_position.y, target_world.z)
	pan_tween.tween_property(_camera, "global_position", target_pos, 0.5)

	# After pan completes, open preview panel (AC14)
	pan_tween.tween_callback(func():
		pan_completed.emit(hex.to_vector())
		_open_preview_for_hex(hex)
	)

	GameLogger.debug("UI", "CombatOpportunityBadge: Panning to contested hex %s" % hex.to_vector())


## Open preview panel for a hex after camera pan (AC14).
func _open_preview_for_hex(hex: HexCoord) -> void:
	# Code Review Fix: Retry discovery if panel not found at startup
	if not _preview_panel:
		var panels := get_tree().get_nodes_in_group("contested_preview_panels")
		if panels.size() > 0:
			_preview_panel = panels[0] as ContestedPreviewPanel

	if _preview_panel:
		_preview_panel.show_for_hex(hex)
	else:
		GameLogger.warn("UI", "CombatOpportunityBadge: Preview panel not found - AC14 unavailable")

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_herd_spawned(_herd_id: String, _hex_coord: Vector2i, _animal_count: int) -> void:
	# Delay update to allow TerritoryManager to sync
	call_deferred("_update_contested_count")


func _on_herd_removed(_herd_id: String, _hex_coord: Vector2i) -> void:
	call_deferred("_update_contested_count")


func _on_ownership_changed(_hex_coord: Vector2i, _old_owner: String, _new_owner: String) -> void:
	# Territory ownership affects contested status
	call_deferred("_update_contested_count")


func _on_contested_discovered(_hex_coord: Vector2i, _herd_id: String) -> void:
	# New contested territory discovered
	call_deferred("_update_contested_count")
