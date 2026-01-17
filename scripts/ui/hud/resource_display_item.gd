## ResourceDisplayItem - Displays a single resource with amount and capacity.
## Shows visual states for warning (80%+) and full (100%).
##
## Architecture: scripts/ui/hud/resource_display_item.gd
## Story: 3-11-display-resource-bar-hud
class_name ResourceDisplayItem
extends Control

# =============================================================================
# CONSTANTS
# =============================================================================

## Normal state color (white)
const NORMAL_COLOR := Color(1.0, 1.0, 1.0, 1.0)

## Warning state color (amber) - 80%+ capacity
const WARNING_COLOR := Color(1.0, 0.7, 0.2, 1.0)

## Full state color (red) - 100% capacity
const FULL_COLOR := Color(1.0, 0.3, 0.3, 1.0)

## Animation duration for smooth amount updates
const TWEEN_DURATION: float = 0.25

# =============================================================================
# STATE
# =============================================================================

## Resource identifier
var _resource_id: String = ""

## Current actual amount
var _current_amount: int = 0

## Storage capacity
var _capacity: int = 0

## Currently displayed amount (for animation)
var _displayed_amount: float = 0.0

## Active tween for amount animation
var _amount_tween: Tween = null

# =============================================================================
# NODE REFERENCES
# Note: Scene structure has PanelContainer and HBoxContainer as siblings at root
# level. This allows independent styling while keeping node paths simple.
# =============================================================================

## Icon/emoji label
@onready var _icon_label: Label = $HBoxContainer/IconLabel

## Amount display label
@onready var _amount_label: Label = $HBoxContainer/AmountLabel

# =============================================================================
# LIFECYCLE
# =============================================================================

func _exit_tree() -> void:
	# Clean up any running tween to prevent orphaned references
	if _amount_tween and _amount_tween.is_valid():
		_amount_tween.kill()

# =============================================================================
# PUBLIC API
# =============================================================================

## Initialize the resource display item.
## @param resource_id The resource identifier
## @param icon The emoji/icon to display
## @param amount Current amount
## @param capacity Storage capacity (0 for unlimited)
func setup(resource_id: String, icon: String, amount: int, capacity: int) -> void:
	_resource_id = resource_id
	_current_amount = amount
	_capacity = capacity
	_displayed_amount = float(amount)

	# Wait for nodes to be ready if not already
	if not is_node_ready():
		await ready

	_icon_label.text = icon
	_update_label()
	_update_color_state()


## Update the displayed amount with animation.
## @param new_amount The new amount to display
func update_amount(new_amount: int) -> void:
	if _current_amount == new_amount:
		return

	var old_amount := _current_amount
	_current_amount = new_amount

	# Animate the change
	_animate_amount(old_amount, new_amount)
	_update_color_state()


## Update the capacity value.
## @param new_capacity The new storage capacity
func update_capacity(new_capacity: int) -> void:
	_capacity = new_capacity
	_update_label()
	_update_color_state()


## Force warning state (from explicit signal).
func show_warning_state() -> void:
	if is_node_ready() and _amount_label:
		_amount_label.modulate = WARNING_COLOR


## Force full state (from explicit signal).
func show_full_state() -> void:
	if is_node_ready() and _amount_label:
		_amount_label.modulate = FULL_COLOR


## Get the resource identifier.
## @return The resource ID
func get_resource_id() -> String:
	return _resource_id


## Get the current amount.
## @return Current resource amount
func get_current_amount() -> int:
	return _current_amount


## Get the storage capacity.
## @return Storage capacity (0 if unlimited)
func get_capacity() -> int:
	return _capacity


## Get the formatted amount text (for testing).
## @return The amount text as displayed
func get_amount_text() -> String:
	if _capacity > 0:
		return "%d/%d" % [int(round(_displayed_amount)), _capacity]
	return str(int(round(_displayed_amount)))


## Get the current color state (for testing).
## @return "normal", "warning", or "full"
func get_color_state() -> String:
	if _capacity <= 0:
		return "normal"

	var percentage := float(_current_amount) / float(_capacity)

	if percentage >= 1.0:
		return "full"
	elif percentage >= GameConstants.STORAGE_WARNING_THRESHOLD:
		return "warning"
	return "normal"

# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Animate from one amount to another.
func _animate_amount(from: int, to: int) -> void:
	# Kill existing tween to prevent stacking
	if _amount_tween and _amount_tween.is_running():
		_amount_tween.kill()

	_displayed_amount = float(from)
	_amount_tween = create_tween()
	_amount_tween.tween_method(_update_displayed_amount, float(from), float(to), TWEEN_DURATION)


## Callback for tween animation - update displayed amount.
func _update_displayed_amount(value: float) -> void:
	_displayed_amount = value
	_update_label()


## Update the amount label text.
func _update_label() -> void:
	if not is_node_ready() or not _amount_label:
		return

	var display_value := int(round(_displayed_amount))
	if _capacity > 0:
		_amount_label.text = "%d/%d" % [display_value, _capacity]
	else:
		_amount_label.text = str(display_value)


## Update color based on fill percentage.
func _update_color_state() -> void:
	if not is_node_ready() or not _amount_label:
		return

	if _capacity <= 0:
		_amount_label.modulate = NORMAL_COLOR
		return

	var percentage := float(_current_amount) / float(_capacity)

	if percentage >= 1.0:
		_amount_label.modulate = FULL_COLOR
	elif percentage >= GameConstants.STORAGE_WARNING_THRESHOLD:
		_amount_label.modulate = WARNING_COLOR
	else:
		_amount_label.modulate = NORMAL_COLOR
