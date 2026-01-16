## BuildingMenuPanel - Displays available buildings for construction.
## Shows building icons, names, resource costs, and handles affordability states.
## Opens via build button, closes on outside tap or building selection.
##
## Architecture: scripts/ui/building_menu_panel.gd
## Story: 3-4-create-building-menu-ui
class_name BuildingMenuPanel
extends Control

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a building is selected for placement
signal building_selected(building_data: BuildingData)

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _panel: PanelContainer = $PanelContainer
@onready var _grid: GridContainer = $PanelContainer/MarginContainer/VBoxContainer/ScrollContainer/GridContainer

# =============================================================================
# CONSTANTS
# =============================================================================

## Path to building data resources
const BUILDING_RESOURCES_PATH := "res://resources/buildings/"

## Building menu item scene path
const BUILDING_MENU_ITEM_SCENE := "res://scenes/ui/building_menu_item.tscn"

# =============================================================================
# STATE
# =============================================================================

## Cached building menu item scene
var _building_menu_item_scene: PackedScene = null

## List of active menu items for cleanup
var _menu_items: Array[BuildingMenuItem] = []

## Panel rect for outside click detection
var _panel_rect: Rect2 = Rect2()

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Initially hidden
	visible = false

	# Load building menu item scene
	_building_menu_item_scene = load(BUILDING_MENU_ITEM_SCENE)

	# Connect to EventBus resource changes
	if EventBus:
		EventBus.resource_changed.connect(_on_resource_changed)

	GameLogger.info("UI", "BuildingMenuPanel initialized")


func _exit_tree() -> void:
	# Cleanup signal connections
	if EventBus and EventBus.resource_changed.is_connected(_on_resource_changed):
		EventBus.resource_changed.disconnect(_on_resource_changed)

	# Clear menu items
	_clear_menu_items()


func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Handle outside tap to close menu (AC5)
	if event is InputEventMouseButton and event.pressed:
		# Update panel rect before checking
		_update_panel_rect()
		if not _panel_rect.has_point(event.position):
			hide_menu()
			get_viewport().set_input_as_handled()

# =============================================================================
# PUBLIC API
# =============================================================================

## Show the building menu and populate with available buildings
func show_menu() -> void:
	# Populate menu with buildings
	_populate_buildings()

	# Show panel
	visible = true

	# Emit menu opened signal
	if EventBus:
		EventBus.menu_opened.emit("building_menu")

	GameLogger.debug("UI", "Building menu opened")


## Hide the building menu
func hide_menu() -> void:
	visible = false

	# Emit menu closed signal
	if EventBus:
		EventBus.menu_closed.emit("building_menu")

	GameLogger.debug("UI", "Building menu closed")


## Check if menu is currently visible
func is_showing() -> bool:
	return visible


## Get the list of menu items (for testing)
func get_menu_items() -> Array[BuildingMenuItem]:
	return _menu_items

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_resource_changed(_resource_type: String, _new_amount: int) -> void:
	# Update affordability states for all menu items
	_update_affordability_states()


func _on_building_item_selected(building_data: BuildingData) -> void:
	# Emit selection signal
	building_selected.emit(building_data)

	# Emit placement started signal for Story 3-5
	if EventBus:
		EventBus.building_placement_started.emit(building_data)

	# Close menu after selection
	hide_menu()

	GameLogger.debug("UI", "Building selected: %s" % building_data.display_name)

# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Clear all existing menu items
func _clear_menu_items() -> void:
	for item in _menu_items:
		if is_instance_valid(item):
			item.queue_free()
	_menu_items.clear()


## Populate menu with available building data
func _populate_buildings() -> void:
	# Clear existing items
	_clear_menu_items()

	# Load all building data resources
	var building_data_list := _load_building_data_resources()

	# Create menu item for each building
	for building_data in building_data_list:
		var menu_item := _create_menu_item(building_data)
		if menu_item:
			_grid.add_child(menu_item)
			_menu_items.append(menu_item)

	GameLogger.debug("UI", "Populated %d buildings in menu" % _menu_items.size())


## Load all building data resources from the resources folder
func _load_building_data_resources() -> Array[BuildingData]:
	var result: Array[BuildingData] = []

	var dir := DirAccess.open(BUILDING_RESOURCES_PATH)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with("_data.tres"):
				var path := BUILDING_RESOURCES_PATH + file_name
				var data := load(path) as BuildingData
				if data and data.is_valid():
					result.append(data)
			file_name = dir.get_next()
		dir.list_dir_end()
	else:
		GameLogger.warn("UI", "Cannot open building resources folder")

	return result


## Create a menu item for a building
func _create_menu_item(building_data: BuildingData) -> BuildingMenuItem:
	if not _building_menu_item_scene:
		GameLogger.error("UI", "Building menu item scene not loaded")
		return null

	var menu_item := _building_menu_item_scene.instantiate() as BuildingMenuItem
	if not menu_item:
		GameLogger.error("UI", "Failed to instantiate BuildingMenuItem")
		return null

	# Setup the menu item with building data
	menu_item.setup(building_data)

	# Connect selection signal
	menu_item.selected.connect(_on_building_item_selected)

	return menu_item


## Update affordability states for all menu items
func _update_affordability_states() -> void:
	for item in _menu_items:
		if is_instance_valid(item):
			item.update_affordability()


## Update panel rect for outside click detection
func _update_panel_rect() -> void:
	if _panel:
		_panel_rect = _panel.get_global_rect()
