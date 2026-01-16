## WorkerSelectionOverlay - Modal overlay for selecting animals to assign to buildings.
## Shows list of idle animals when "Assign Worker" button is pressed.
## Dismisses on backdrop tap, close button, or animal selection.
##
## Architecture: scripts/ui/worker_selection_overlay.gd
## Story: 3-10-assign-animals-to-buildings
class_name WorkerSelectionOverlay
extends Control

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a worker is successfully assigned
signal worker_assigned(animal: Animal, building: Building)

## Emitted when overlay is closed (by any method)
signal closed()

# =============================================================================
# CONSTANTS
# =============================================================================

## AIComponent state constants (match AIComponent.AnimalState enum)
const AI_STATE_IDLE := 0

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _backdrop: Control = $Backdrop
@onready var _panel: PanelContainer = $Panel
@onready var _title_label: Label = $Panel/MarginContainer/VBoxContainer/Header/TitleLabel
@onready var _close_button: Button = $Panel/MarginContainer/VBoxContainer/Header/CloseButton
@onready var _scroll_container: ScrollContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer
@onready var _animal_list: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ScrollContainer/AnimalList
@onready var _no_animals_label: Label = $Panel/MarginContainer/VBoxContainer/NoAnimalsLabel

# =============================================================================
# STATE
# =============================================================================

## Reference to target building
var _target_building: Building = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	visible = false

	# Connect backdrop tap to dismiss (AC6)
	if _backdrop:
		_backdrop.gui_input.connect(_on_backdrop_input)

	# Connect close button (AC6)
	if _close_button:
		_close_button.pressed.connect(_on_close_pressed)

	# Listen for building removal (AC12)
	if EventBus:
		EventBus.building_removed.connect(_on_building_removed)

	GameLogger.info("UI", "WorkerSelectionOverlay initialized")


func _exit_tree() -> void:
	# Disconnect EventBus signals
	if EventBus:
		if EventBus.building_removed.is_connected(_on_building_removed):
			EventBus.building_removed.disconnect(_on_building_removed)

# =============================================================================
# PUBLIC API
# =============================================================================

## Show overlay for a specific building (AC3)
func show_for_building(building: Building) -> void:
	if not is_instance_valid(building):
		GameLogger.warn("UI", "Cannot show worker selection for invalid building")
		return

	_target_building = building

	# Update title
	var data := building.get_data()
	if _title_label and data:
		_title_label.text = "Assign Worker to %s" % data.display_name

	# Populate idle animals
	_populate_animal_list()

	# Show overlay
	visible = true
	GameLogger.debug("UI", "WorkerSelectionOverlay shown for %s" % building.get_building_id())


## Hide overlay (AC5, AC6)
func hide_overlay() -> void:
	_target_building = null
	_clear_animal_list()
	visible = false
	closed.emit()
	GameLogger.debug("UI", "WorkerSelectionOverlay hidden")


## Get the target building (for testing)
func get_target_building() -> Building:
	return _target_building


## Check if overlay is currently visible
func is_showing() -> bool:
	return visible

# =============================================================================
# ANIMAL LIST MANAGEMENT
# =============================================================================

## Populate the animal list with idle animals (AC3, AC9)
func _populate_animal_list() -> void:
	_clear_animal_list()

	var idle_animals := _get_idle_animals()

	# AC9: Show message if no idle animals available
	if idle_animals.is_empty():
		if _no_animals_label:
			_no_animals_label.visible = true
		if _scroll_container:
			_scroll_container.visible = false
		return

	if _no_animals_label:
		_no_animals_label.visible = false
	if _scroll_container:
		_scroll_container.visible = true

	# Create item for each idle animal
	for animal in idle_animals:
		var item := _create_animal_item(animal)
		if _animal_list:
			_animal_list.add_child(item)


## Clear all animal items from list
func _clear_animal_list() -> void:
	if not _animal_list:
		return

	for child in _animal_list.get_children():
		child.queue_free()


## Get list of idle animals available for assignment (AC3)
func _get_idle_animals() -> Array[Animal]:
	var result: Array[Animal] = []

	var all_animals := get_tree().get_nodes_in_group("animals")

	for node in all_animals:
		var animal := node as Animal
		if not is_instance_valid(animal):
			continue
		if not animal.is_initialized():
			continue

		# Check if already assigned to a building
		if animal.has_assigned_building():
			continue

		# Check if in IDLE state
		var ai := animal.get_node_or_null("AIComponent")
		if not ai:
			continue

		if ai.has_method("get_current_state"):
			if ai.get_current_state() == AI_STATE_IDLE:
				result.append(animal)

	# Sort by distance to target building if available
	if is_instance_valid(_target_building):
		var building_pos := _target_building.global_position
		result.sort_custom(func(a: Animal, b: Animal) -> bool:
			return a.global_position.distance_to(building_pos) < b.global_position.distance_to(building_pos)
		)

	return result


## Create an item for the animal list (AC4)
func _create_animal_item(animal: Animal) -> Control:
	# Load item scene if available, otherwise create dynamically
	var item_scene_path := "res://scenes/ui/worker_selection_item.tscn"
	if ResourceLoader.exists(item_scene_path):
		var item_scene := load(item_scene_path) as PackedScene
		if item_scene:
			var item := item_scene.instantiate() as Control
			if item.has_method("setup"):
				item.setup(animal)
			if item.has_signal("pressed"):
				item.pressed.connect(_on_animal_item_pressed.bind(animal))
			return item

	# Fallback: Create simple button
	return _create_fallback_animal_item(animal)


## Create fallback item when scene is not available
func _create_fallback_animal_item(animal: Animal) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Get animal info
	var animal_id := animal.get_animal_id() if animal.has_method("get_animal_id") else "Animal"
	var energy_percent := 100

	# Get energy from stats component
	var stats_comp := animal.get_node_or_null("StatsComponent")
	if stats_comp and stats_comp.has_method("get_energy"):
		var energy: int = stats_comp.get_energy()
		var max_energy: int = stats_comp.get_max_energy() if stats_comp.has_method("get_max_energy") else 100
		if max_energy > 0:
			energy_percent = int(float(energy) / float(max_energy) * 100)

	button.text = "%s  Energy: %d%%" % [animal_id, energy_percent]
	button.add_theme_font_size_override("font_size", 16)

	# Connect press event
	button.pressed.connect(_on_animal_item_pressed.bind(animal))

	return button


## Get the number of animal items displayed (for testing)
func get_animal_item_count() -> int:
	if not _animal_list:
		return 0
	return _animal_list.get_child_count()


## Check if "no animals" message is visible (for testing)
func is_no_animals_message_visible() -> bool:
	if not _no_animals_label:
		return false
	return _no_animals_label.visible

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

## Handle animal item pressed - assign to building (AC4, AC5)
func _on_animal_item_pressed(animal: Animal) -> void:
	if not is_instance_valid(_target_building):
		GameLogger.warn("UI", "Target building no longer valid")
		hide_overlay()
		return

	if not is_instance_valid(animal):
		GameLogger.warn("UI", "Selected animal no longer valid")
		_populate_animal_list()  # Refresh list
		return

	# Assign animal to building's hex (AC4)
	var hex_coord := _target_building.get_hex_coord()
	if not hex_coord:
		GameLogger.error("UI", "Target building has no hex coordinate")
		hide_overlay()
		return

	# Store building reference before hide clears it
	var building_ref := _target_building

	# Use AssignmentManager for consistent assignment behavior
	var assignment_success := AssignmentManager.assign_to_hex(animal, hex_coord)

	# Emit signal for UI feedback (AC10) - even if assignment validation fails,
	# the UI selection was made and panel should refresh
	worker_assigned.emit(animal, building_ref)

	if assignment_success:
		GameLogger.info("UI", "Worker assigned from overlay: %s -> %s" % [
			animal.get_animal_id() if animal.has_method("get_animal_id") else "unknown",
			building_ref.get_building_id()
		])
	else:
		GameLogger.debug("UI", "Worker selection made but assignment validation failed")

	# AC5: Close overlay after selection
	hide_overlay()


## Handle backdrop input - dismiss on tap (AC6)
func _on_backdrop_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_overlay()
	elif event is InputEventScreenTouch and event.pressed:
		hide_overlay()


## Handle close button pressed (AC6)
func _on_close_pressed() -> void:
	hide_overlay()


## Handle building removed - close if showing that building (AC12)
func _on_building_removed(building: Node, _hex: Vector2i) -> void:
	if building == _target_building:
		GameLogger.debug("UI", "Target building removed - closing overlay")
		hide_overlay()
