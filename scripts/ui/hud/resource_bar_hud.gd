## ResourceBarHUD - Displays resource amounts and storage status.
## Persists at top of screen, updates via EventBus signals.
##
## Architecture: scripts/ui/hud/resource_bar_hud.gd
## Story: 3-11-display-resource-bar-hud
class_name ResourceBarHUD
extends Control

# =============================================================================
# CONSTANTS
# =============================================================================

## Resource emoji/icon mapping
const RESOURCE_ICONS := {
	"wheat": "🌾",
	"wood": "🪵",
	"flour": "🥛",
	"bread": "🍞",
	"stone": "🪨",
	"ore": "⛏️"
}

## Default icon for unknown resources
const DEFAULT_ICON := "📦"

# =============================================================================
# STATE
# =============================================================================

## Resource display items by resource_id
var _resource_items: Dictionary = {}

# =============================================================================
# NODE REFERENCES
# =============================================================================

## Container for resource displays
@onready var _container: HBoxContainer = $PanelContainer/MarginContainer/HBoxContainer

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Connect to EventBus signals
	if EventBus:
		EventBus.resource_changed.connect(_on_resource_changed)
		EventBus.storage_capacity_changed.connect(_on_capacity_changed)
		EventBus.resource_storage_warning.connect(_on_storage_warning)
		EventBus.resource_full.connect(_on_resource_full)

	# Initialize with existing resources
	_populate_initial_resources()

	GameLogger.info("UI", "ResourceBarHUD initialized")


func _exit_tree() -> void:
	# Safely disconnect all EventBus signals
	if EventBus:
		if EventBus.resource_changed.is_connected(_on_resource_changed):
			EventBus.resource_changed.disconnect(_on_resource_changed)
		if EventBus.storage_capacity_changed.is_connected(_on_capacity_changed):
			EventBus.storage_capacity_changed.disconnect(_on_capacity_changed)
		if EventBus.resource_storage_warning.is_connected(_on_storage_warning):
			EventBus.resource_storage_warning.disconnect(_on_storage_warning)
		if EventBus.resource_full.is_connected(_on_resource_full):
			EventBus.resource_full.disconnect(_on_resource_full)

# =============================================================================
# PUBLIC API
# =============================================================================

## Get a resource item by ID (for testing).
## @param resource_id The resource identifier
## @return The ResourceDisplayItem or null
func get_resource_item(resource_id: String):
	return _resource_items.get(resource_id, null)


## Get count of displayed resources (for testing).
## @return Number of resource items currently displayed
func get_resource_count() -> int:
	return _resource_items.size()


## Get icon for a resource type.
## @param resource_id The resource identifier
## @return The emoji/icon for this resource
func get_icon_for_resource(resource_id: String) -> String:
	return RESOURCE_ICONS.get(resource_id, DEFAULT_ICON)

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

## Handle resource amount changes.
func _on_resource_changed(resource_id: String, new_amount: int) -> void:
	_update_or_create_item(resource_id, new_amount)


## Handle storage capacity changes.
func _on_capacity_changed(resource_id: String, new_capacity: int) -> void:
	if _resource_items.has(resource_id):
		var item = _resource_items[resource_id]
		item.update_capacity(new_capacity)


## Handle storage warning threshold.
func _on_storage_warning(resource_id: String) -> void:
	if _resource_items.has(resource_id):
		var item = _resource_items[resource_id]
		item.show_warning_state()


## Handle storage full state.
func _on_resource_full(resource_id: String) -> void:
	if _resource_items.has(resource_id):
		var item = _resource_items[resource_id]
		item.show_full_state()

# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Populate HUD with all existing resources on initialization.
func _populate_initial_resources() -> void:
	if not ResourceManager:
		GameLogger.warn("UI", "ResourceManager not available for initial population")
		return

	var all_resources: Dictionary = ResourceManager.get_all_resources()
	for resource_id: String in all_resources:
		_update_or_create_item(resource_id, all_resources[resource_id])


## Update existing item or create new one.
func _update_or_create_item(resource_id: String, amount: int) -> void:
	if _resource_items.has(resource_id):
		var item = _resource_items[resource_id]
		item.update_amount(amount)
	else:
		_create_resource_item(resource_id, amount)


## Create a new resource display item.
func _create_resource_item(resource_id: String, amount: int) -> void:
	var item_scene := preload("res://scenes/ui/hud/resource_display_item.tscn")
	var item = item_scene.instantiate()

	if not item:
		GameLogger.error("UI", "Failed to instantiate ResourceDisplayItem")
		return

	var icon: String = RESOURCE_ICONS.get(resource_id, DEFAULT_ICON)
	var capacity: int = _get_resource_capacity(resource_id)

	_container.add_child(item)
	item.setup(resource_id, icon, amount, capacity)
	_resource_items[resource_id] = item

	GameLogger.debug("UI", "Created resource display for: %s" % resource_id)


## Get storage capacity for a resource.
func _get_resource_capacity(resource_id: String) -> int:
	if ResourceManager and ResourceManager.has_method("get_storage_limit"):
		return ResourceManager.get_storage_limit(resource_id)
	return GameConstants.DEFAULT_VILLAGE_STORAGE_CAPACITY
