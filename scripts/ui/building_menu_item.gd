## BuildingMenuItem - Individual building entry in the building menu.
## Displays building icon, name, resource cost, and handles affordability states.
##
## Architecture: scripts/ui/building_menu_item.gd
## Story: 3-4-create-building-menu-ui
class_name BuildingMenuItem
extends Control

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when this building item is selected
signal selected(building_data: BuildingData)

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _button: Button = $Button
@onready var _icon_rect: ColorRect = $Button/VBoxContainer/IconRect
@onready var _name_label: Label = $Button/VBoxContainer/NameLabel
@onready var _cost_container: HBoxContainer = $Button/VBoxContainer/CostContainer

# =============================================================================
# CONSTANTS
# =============================================================================

## Building type colors for placeholder icons
const TYPE_COLORS := {
	BuildingTypes.BuildingType.GATHERER: Color(0.4, 0.7, 0.3, 1),    # Green
	BuildingTypes.BuildingType.STORAGE: Color(0.6, 0.45, 0.3, 1),   # Brown
	BuildingTypes.BuildingType.PROCESSOR: Color(0.85, 0.5, 0.25, 1) # Orange
}

## Default icon color
const DEFAULT_ICON_COLOR := Color(0.5, 0.5, 0.5, 1)

## Normal button modulate
const NORMAL_MODULATE := Color(1, 1, 1, 1)

## Disabled button modulate (grayed out)
const DISABLED_MODULATE := Color(0.5, 0.5, 0.5, 0.7)

# =============================================================================
# STATE
# =============================================================================

## The building data this item represents
var _building_data: BuildingData = null

## Whether this building is currently affordable
var _is_affordable: bool = true

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Connect button signal
	if _button:
		_button.pressed.connect(_on_button_pressed)


func _exit_tree() -> void:
	if _button and _button.pressed.is_connected(_on_button_pressed):
		_button.pressed.disconnect(_on_button_pressed)

# =============================================================================
# PUBLIC API
# =============================================================================

## Setup the menu item with building data
func setup(building_data: BuildingData) -> void:
	if not building_data:
		GameLogger.warn("UI", "BuildingMenuItem setup called with null data")
		return

	_building_data = building_data

	# Defer setup if node isn't ready yet
	if not is_node_ready():
		ready.connect(_complete_setup, CONNECT_ONE_SHOT)
		return

	_complete_setup()


## Complete the setup after nodes are ready
func _complete_setup() -> void:
	if not _building_data:
		return

	# Set icon color based on building type
	if _icon_rect:
		_icon_rect.color = TYPE_COLORS.get(_building_data.building_type, DEFAULT_ICON_COLOR)

	# Set building name
	if _name_label:
		_name_label.text = _building_data.display_name

	# Populate cost display
	_populate_cost_display()

	# Update affordability state
	update_affordability()


## Update the affordability visual state
func update_affordability() -> void:
	if not _building_data:
		return

	# Check if player can afford this building
	_is_affordable = _check_affordability()

	# Update visual state
	_update_visual_state()


## Get the building data for this item
func get_building_data() -> BuildingData:
	return _building_data


## Check if this building is currently affordable
func is_affordable() -> bool:
	return _is_affordable

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_button_pressed() -> void:
	if not _building_data:
		return

	# Only allow selection if affordable
	if _is_affordable:
		selected.emit(_building_data)
	else:
		GameLogger.debug("UI", "Cannot select %s - insufficient resources" % _building_data.display_name)

# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Check if player can afford this building
func _check_affordability() -> bool:
	if not _building_data:
		return false

	var costs: Dictionary = _building_data.build_cost
	if costs.is_empty():
		return true

	# Check each resource cost
	for resource_id in costs:
		var required: int = costs[resource_id]
		if not ResourceManager.has_resource(resource_id, required):
			return false

	return true


## Populate the cost display with resource icons and amounts
func _populate_cost_display() -> void:
	if not _cost_container or not _building_data:
		return

	# Clear existing cost items
	for child in _cost_container.get_children():
		child.queue_free()

	var costs: Dictionary = _building_data.build_cost
	if costs.is_empty():
		# Show "Free" if no cost
		var free_label := Label.new()
		free_label.text = "Free"
		free_label.add_theme_font_size_override("font_size", 14)
		free_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1))
		_cost_container.add_child(free_label)
		return

	# Add cost entry for each resource
	for resource_id in costs:
		var amount: int = costs[resource_id]
		var cost_item := _create_cost_item(resource_id, amount)
		_cost_container.add_child(cost_item)


## Create a cost item (icon + amount label)
func _create_cost_item(resource_id: String, amount: int) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 4)

	# Resource icon (colored rect placeholder)
	var icon := ColorRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.color = _get_resource_color(resource_id)
	container.add_child(icon)

	# Amount label
	var label := Label.new()
	label.text = str(amount)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8, 1))
	container.add_child(label)

	return container


## Get color for resource type (placeholder until icons ready)
func _get_resource_color(resource_id: String) -> Color:
	match resource_id:
		"wood":
			return Color(0.55, 0.35, 0.15, 1)  # Brown
		"stone":
			return Color(0.5, 0.5, 0.55, 1)    # Gray
		"wheat":
			return Color(0.9, 0.8, 0.3, 1)    # Yellow
		"flour":
			return Color(0.95, 0.95, 0.9, 1)  # White
		_:
			return Color(0.6, 0.6, 0.6, 1)    # Default gray


## Update visual state based on affordability
func _update_visual_state() -> void:
	if _button:
		if _is_affordable:
			_button.modulate = NORMAL_MODULATE
			_button.disabled = false
		else:
			_button.modulate = DISABLED_MODULATE
			_button.disabled = true
