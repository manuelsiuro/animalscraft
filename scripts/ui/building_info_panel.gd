## BuildingInfoPanel - Displays selected building's information in a UI panel.
## Listens to EventBus for selection changes and updates in real-time.
## Mirrors AnimalStatsPanel architecture for consistency.
##
## Features:
## - Worker assignment/unassignment (Story 3-10)
## - PROCESSOR building input requirements display (Story 4-5)
## - Real-time production progress bar with cozy styling (Story 4-6)
## - Storage capacity display with color-coded warnings (Story 4-6)
##
## Architecture: scripts/ui/building_info_panel.gd
## Stories: 3-9, 3-10, 4-5, 4-6
class_name BuildingInfoPanel
extends Control

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _panel: PanelContainer = $PanelContainer
@onready var _building_name_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/BuildingNameLabel
@onready var _building_type_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/TypeLabel
@onready var _workers_label: Label = $PanelContainer/MarginContainer/VBoxContainer/WorkersRow/WorkersLabel
@onready var _production_section: Control = $PanelContainer/MarginContainer/VBoxContainer/ProductionSection
@onready var _output_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ProductionSection/OutputRow/OutputLabel
@onready var _cycle_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ProductionSection/CycleRow/CycleLabel
@onready var _status_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ProductionSection/StatusRow/StatusLabel
@onready var _worker_section: Control = $PanelContainer/MarginContainer/VBoxContainer/WorkerSection
@onready var _worker_icons_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/WorkerSection/WorkerIconsContainer
@onready var _assign_worker_button: Button = $PanelContainer/MarginContainer/VBoxContainer/WorkerSection/AssignWorkerButton

# PROCESSOR building UI elements (Story 4-5)
@onready var _inputs_section: Control = $PanelContainer/MarginContainer/VBoxContainer/ProductionSection/InputsSection
@onready var _inputs_container: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/ProductionSection/InputsSection/InputsContainer
@onready var _recipe_flow_row: Control = $PanelContainer/MarginContainer/VBoxContainer/ProductionSection/RecipeFlowRow
@onready var _recipe_flow_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ProductionSection/RecipeFlowRow/RecipeFlowLabel

# Progress bar and storage display UI elements (Story 4-6)
@onready var _progress_bar_row: Control = $PanelContainer/MarginContainer/VBoxContainer/ProductionSection/ProgressBarRow
@onready var _production_progress_bar: ProgressBar = $PanelContainer/MarginContainer/VBoxContainer/ProductionSection/ProgressBarRow/ProductionProgressBar
@onready var _progress_percent_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ProductionSection/ProgressBarRow/ProgressPercentLabel
@onready var _storage_row: Control = $PanelContainer/MarginContainer/VBoxContainer/ProductionSection/StorageRow
@onready var _output_storage_icon: Label = $PanelContainer/MarginContainer/VBoxContainer/ProductionSection/StorageRow/OutputStorageIcon
@onready var _output_storage_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ProductionSection/StorageRow/OutputStorageLabel

# =============================================================================
# CONSTANTS
# =============================================================================

## Production status display strings
const STATUS_IDLE := "Idle (No Workers)"
const STATUS_ACTIVE := "Active"
const STATUS_PAUSED := "Paused (Storage Full)"
## PROCESSOR-specific status strings (Story 4-5)
const STATUS_WAITING := "Waiting for Inputs"
const STATUS_PRODUCING := "Producing %s"
## SHELTER-specific status strings (Story 5-11)
const STATUS_SHELTER_EMPTY := "Ready for Animals"
const STATUS_SHELTER_PARTIAL := "%d/%d Resting"
const STATUS_SHELTER_FULL := "Full (%d/%d)"

## Storage display color constants (Story 4-6)
const COLOR_STORAGE_NORMAL := Color(1, 0.95, 0.9, 1)  # Light/white
const COLOR_STORAGE_WARNING := Color(0.9, 0.7, 0.3, 1)  # Orange
const COLOR_STORAGE_FULL := Color(0.9, 0.3, 0.3, 1)  # Red

## Maximum worker icons to display before showing overflow indicator (M4 fix)
const MAX_WORKER_ICONS_DISPLAY := 4

## Resource icons for input/output display (Story 4-5)
const RESOURCE_ICONS := {
	"wheat": "🌾",
	"wood": "🪵",
	"flour": "🌸",
	"bread": "🍞",
	"stone": "🪨",
}

# =============================================================================
# STATE
# =============================================================================

## Currently displayed building reference
var _current_building: Building = null

## Cache worker slots reference for signal disconnection
var _cached_worker_slots: WorkerSlotComponent = null

## Reference to WorkerSelectionOverlay (assigned from game.tscn or found at runtime)
var _worker_selection_overlay: Control = null

## Current storage display color (tracked for testing) - Story 4-6
var _current_storage_color: Color = COLOR_STORAGE_NORMAL

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Initially hidden
	visible = false

	# Connect to EventBus selection signals
	if EventBus:
		EventBus.building_selected.connect(_on_building_selected)
		EventBus.building_deselected.connect(_on_building_deselected)
		EventBus.building_removed.connect(_on_building_removed)
		# Connect production signals once in _ready() - filter by building in handlers
		EventBus.production_started.connect(_on_production_started)
		EventBus.production_halted.connect(_on_production_halted)
		EventBus.resource_gathering_paused.connect(_on_gathering_paused)
		EventBus.resource_gathering_resumed.connect(_on_gathering_resumed)
		# PROCESSOR-specific signals for real-time input availability updates (Story 4-5)
		EventBus.resource_changed.connect(_on_resource_changed)
		EventBus.production_completed.connect(_on_production_completed_for_display)
		# SHELTER-specific signals for occupancy updates (Story 5-11)
		EventBus.animal_entered_shelter.connect(_on_shelter_occupancy_changed)
		EventBus.animal_left_shelter.connect(_on_shelter_occupancy_changed)

	# Connect assign worker button (Story 3-10)
	if _assign_worker_button:
		_assign_worker_button.pressed.connect(_on_assign_worker_pressed)

	# Find WorkerSelectionOverlay (deferred to allow scene to initialize)
	call_deferred("_find_worker_selection_overlay")

	# Apply cozy theme styling to progress bar (Story 4-6, Task 1.6)
	_apply_progress_bar_styling()

	GameLogger.info("UI", "BuildingInfoPanel initialized")


## Process function for real-time progress bar updates (Story 4-6)
func _process(_delta: float) -> void:
	# Early exit checks (cheap) - AC12: no performance impact
	if not visible:
		return
	if not is_instance_valid(_current_building):
		return

	# Type check only if we pass visibility checks
	var data := _current_building.get_data()
	if not data or not data.is_producer():
		return

	var processor := _current_building.get_processor()
	if not processor or not processor.is_initialized():
		return

	# Only update progress bar (not full display refresh) - AC2, AC12
	_update_progress_bar_display(processor)


func _exit_tree() -> void:
	# Cleanup signal connections
	_disconnect_building_signals()

	if EventBus:
		if EventBus.building_selected.is_connected(_on_building_selected):
			EventBus.building_selected.disconnect(_on_building_selected)
		if EventBus.building_deselected.is_connected(_on_building_deselected):
			EventBus.building_deselected.disconnect(_on_building_deselected)
		if EventBus.building_removed.is_connected(_on_building_removed):
			EventBus.building_removed.disconnect(_on_building_removed)
		# Disconnect production signals connected in _ready()
		if EventBus.production_started.is_connected(_on_production_started):
			EventBus.production_started.disconnect(_on_production_started)
		if EventBus.production_halted.is_connected(_on_production_halted):
			EventBus.production_halted.disconnect(_on_production_halted)
		if EventBus.resource_gathering_paused.is_connected(_on_gathering_paused):
			EventBus.resource_gathering_paused.disconnect(_on_gathering_paused)
		if EventBus.resource_gathering_resumed.is_connected(_on_gathering_resumed):
			EventBus.resource_gathering_resumed.disconnect(_on_gathering_resumed)
		# Disconnect PROCESSOR-specific signals (Story 4-5)
		if EventBus.resource_changed.is_connected(_on_resource_changed):
			EventBus.resource_changed.disconnect(_on_resource_changed)
		if EventBus.production_completed.is_connected(_on_production_completed_for_display):
			EventBus.production_completed.disconnect(_on_production_completed_for_display)
		# Disconnect SHELTER-specific signals (Story 5-11)
		if EventBus.animal_entered_shelter.is_connected(_on_shelter_occupancy_changed):
			EventBus.animal_entered_shelter.disconnect(_on_shelter_occupancy_changed)
		if EventBus.animal_left_shelter.is_connected(_on_shelter_occupancy_changed):
			EventBus.animal_left_shelter.disconnect(_on_shelter_occupancy_changed)

# =============================================================================
# PUBLIC API
# =============================================================================

## Show panel for specified building
func show_for_building(building: Building) -> void:
	if not is_instance_valid(building):
		GameLogger.warn("UI", "Cannot show info for invalid building")
		return

	# Disconnect previous building if any
	_disconnect_building_signals()

	# Store reference and connect to signals
	_current_building = building
	_connect_building_signals(building)

	# Update display with current values
	_update_display()

	# Show panel
	visible = true
	GameLogger.debug("UI", "Building info panel shown for: %s" % building.get_building_id())


## Hide panel
func hide_panel() -> void:
	_disconnect_building_signals()
	_current_building = null
	visible = false
	GameLogger.debug("UI", "Building info panel hidden")


## Check if panel is currently visible
func is_showing() -> bool:
	return visible and _current_building != null


## Get the current building being displayed (for testing)
func get_current_building() -> Building:
	return _current_building


## Get the building name displayed (for testing)
func get_building_name() -> String:
	if _building_name_label:
		return _building_name_label.text
	return ""


## Get the worker count text (for testing)
func get_worker_count_text() -> String:
	if _workers_label:
		return _workers_label.text
	return ""


## Get the production status text (for testing)
func get_production_status() -> String:
	if _status_label:
		return _status_label.text
	return ""


## Check if inputs section is visible (for testing) - Story 4-5
func is_inputs_section_visible() -> bool:
	return _inputs_section != null and _inputs_section.visible


## Get the recipe flow text (for testing) - Story 4-5
func get_recipe_flow_text() -> String:
	if _recipe_flow_label:
		return _recipe_flow_label.text
	return ""


## Get input requirement count (for testing) - Story 4-5
func get_input_requirements_count() -> int:
	if not _inputs_container:
		return 0
	return _inputs_container.get_child_count()


## Check if recipe flow row is visible (for testing) - Story 4-5
func is_recipe_flow_visible() -> bool:
	return _recipe_flow_row != null and _recipe_flow_row.visible


## Get progress bar value (0-100) (for testing) - Story 4-6
func get_progress_bar_value() -> float:
	if _production_progress_bar:
		return _production_progress_bar.value
	return 0.0


## Check if progress bar is visible (for testing) - Story 4-6
func is_progress_bar_visible() -> bool:
	return _progress_bar_row != null and _progress_bar_row.visible


## Get storage display text (for testing) - Story 4-6
func get_storage_display_text() -> String:
	if _output_storage_label:
		return _output_storage_label.text
	return ""


## Get storage display color (for testing) - Story 4-6
func get_storage_display_color() -> Color:
	return _current_storage_color


## Check if storage row is visible (for testing) - Story 4-6
func is_storage_row_visible() -> bool:
	return _storage_row != null and _storage_row.visible

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_building_selected(building: Node) -> void:
	var typed_building := building as Building
	if typed_building:
		show_for_building(typed_building)


func _on_building_deselected() -> void:
	hide_panel()


func _on_building_removed(building: Node, _hex: Vector2i) -> void:
	# If removed building was the one we're showing, hide panel
	if building == _current_building:
		hide_panel()


func _on_workers_changed(_count: int) -> void:
	_update_display()


func _on_production_started(building: Node) -> void:
	# Only update if it's the currently displayed building
	if is_instance_valid(_current_building) and building == _current_building:
		_update_display()


func _on_production_halted(building: Node, _reason: String) -> void:
	# Only update if it's the currently displayed building
	if is_instance_valid(_current_building) and building == _current_building:
		_update_display()


func _on_gathering_paused(resource_id: String, _reason: String) -> void:
	# Update if current building produces this resource
	if is_instance_valid(_current_building):
		var data := _current_building.get_data()
		if data and data.output_resource_id == resource_id:
			_update_display()


func _on_gathering_resumed(resource_id: String) -> void:
	# Update if current building produces this resource
	if is_instance_valid(_current_building):
		var data := _current_building.get_data()
		if data and data.output_resource_id == resource_id:
			_update_display()


## Handle resource change for PROCESSOR input availability updates (AC4) - Story 4-5
func _on_resource_changed(resource_id: String, _new_amount: int) -> void:
	# Only update if showing a PROCESSOR building
	if not is_instance_valid(_current_building):
		return

	var data := _current_building.get_data()
	if not data or not data.is_producer():
		return

	# Get processor component
	var processor := _current_building.get_processor()
	if not processor or not processor.is_initialized():
		return

	# Only update if this resource is an input for our recipe
	var inputs: Array[Dictionary] = processor.get_input_requirements()
	for input in inputs:
		if input.get("resource_id", "") == resource_id:
			_update_display()
			break


## Handle production completed for display refresh (Story 4-5)
func _on_production_completed_for_display(building: Node, _output_type: String) -> void:
	# Only update if it's the currently displayed building
	if is_instance_valid(_current_building) and building == _current_building:
		_update_display()


## Handle shelter occupancy changes (Story 5-11)
func _on_shelter_occupancy_changed(_animal: Node, shelter: Node) -> void:
	# Only update if it's the currently displayed building
	if is_instance_valid(_current_building) and shelter == _current_building:
		_update_display()

# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Connect to building's signals for real-time updates
func _connect_building_signals(building: Building) -> void:
	# Connect to worker slots for worker count changes
	var slots := building.get_worker_slots()
	if slots:
		_cached_worker_slots = slots
		if not slots.workers_changed.is_connected(_on_workers_changed):
			slots.workers_changed.connect(_on_workers_changed)
	# Note: Production signals (production_started, production_halted, etc.)
	# are connected once in _ready() and filter by building in handlers


## Disconnect from building-specific signals (worker slots only)
func _disconnect_building_signals() -> void:
	# Disconnect worker slots signal
	if _cached_worker_slots and is_instance_valid(_cached_worker_slots):
		if _cached_worker_slots.workers_changed.is_connected(_on_workers_changed):
			_cached_worker_slots.workers_changed.disconnect(_on_workers_changed)
	_cached_worker_slots = null
	# Note: Production signals are connected once in _ready() and disconnected in _exit_tree()
	# They filter by building in handlers, so no per-building disconnect needed


## Update all display fields from current building
func _update_display() -> void:
	if not is_instance_valid(_current_building):
		hide_panel()
		return

	var data := _current_building.get_data()
	if not data:
		return

	# Building name
	if _building_name_label:
		_building_name_label.text = data.display_name

	# Building type
	if _building_type_label:
		_building_type_label.text = data.get_type_name()

	# Worker slots
	_update_workers_display(data)

	# Production section (for gatherers) OR shelter status (Story 5-11)
	_update_production_display(data)

	# Worker section with assign button (Story 3-10)
	# NOTE: For shelters, workers_label doubles as capacity display (Story 5-11)
	_update_worker_section(data)


## Update worker count display
## For SHELTER buildings, shows "Resting: X/Y" instead of "Workers: X/Y" (Story 5-11)
func _update_workers_display(data: BuildingData) -> void:
	if not _workers_label:
		return

	var slots := _current_building.get_worker_slots()
	if slots:
		var current_workers := slots.get_worker_count()
		var max_workers := data.max_workers

		# SHELTER buildings show "Resting" instead of "Workers" (Story 5-11, AC 19)
		if data.building_type == BuildingTypes.BuildingType.SHELTER:
			_workers_label.text = "Resting: %d/%d" % [current_workers, max_workers]
		else:
			_workers_label.text = "Workers: %d/%d" % [current_workers, max_workers]
	else:
		if data.building_type == BuildingTypes.BuildingType.SHELTER:
			_workers_label.text = "Resting: 0/%d" % data.max_workers
		else:
			_workers_label.text = "Workers: 0/%d" % data.max_workers


## Update production status display (for gatherer, processor, AND shelter buildings)
## Story 5-11: Shelters show recovery status instead of production
func _update_production_display(data: BuildingData) -> void:
	if not _production_section:
		return

	# SHELTER buildings show simplified status (Story 5-11)
	if data.building_type == BuildingTypes.BuildingType.SHELTER:
		_update_shelter_display(data)
		return

	# Show production section for BOTH gatherer AND processor buildings (AC11)
	if not data.is_gatherer() and not data.is_producer():
		_production_section.visible = false
		_hide_processor_ui()
		return

	_production_section.visible = true

	# Branch based on building type (Story 4-5)
	if data.is_producer():
		_update_processor_display(data)
	else:
		_update_gatherer_display(data)


## Update display for SHELTER buildings (Story 5-11)
func _update_shelter_display(data: BuildingData) -> void:
	# Hide PROCESSOR-specific UI
	_hide_processor_ui()

	# Show production section for status display
	_production_section.visible = true

	# Get shelter component for status
	var shelter_comp: Node = null
	if _current_building.has_method("get_shelter"):
		shelter_comp = _current_building.get_shelter()

	# Output label - show recovery bonus info
	if _output_label:
		_output_label.text = "2x Recovery"

	# Cycle time - show recovery rate
	if _cycle_label:
		_cycle_label.text = "0.66 E/s"

	# Production status - show occupancy status (AC 18, 19)
	if _status_label:
		_status_label.text = _get_shelter_status_text(shelter_comp, data)


## Get status text for SHELTER buildings (AC 18, 19)
func _get_shelter_status_text(shelter_comp: Node, data: BuildingData) -> String:
	var occupancy := 0
	var max_capacity := data.max_workers

	if shelter_comp and shelter_comp.has_method("get_occupancy"):
		occupancy = shelter_comp.get_occupancy()
	elif is_instance_valid(_current_building):
		var slots := _current_building.get_worker_slots()
		if slots:
			occupancy = slots.get_worker_count()

	if occupancy == 0:
		return STATUS_SHELTER_EMPTY
	elif occupancy >= max_capacity:
		return STATUS_SHELTER_FULL % [occupancy, max_capacity]
	else:
		return STATUS_SHELTER_PARTIAL % [occupancy, max_capacity]


## Update display for GATHERER buildings (Farm, Sawmill)
func _update_gatherer_display(data: BuildingData) -> void:
	# Hide PROCESSOR-specific UI (AC9)
	_hide_processor_ui()

	# Output resource
	if _output_label:
		_output_label.text = data.output_resource_id.capitalize()

	# Cycle time
	if _cycle_label:
		_cycle_label.text = "%.1fs" % data.production_time

	# Production status
	if _status_label:
		_status_label.text = _get_gatherer_status_text(data)


## Update display for PROCESSOR buildings (Mill, Bakery) - Story 4-5, 4-6
func _update_processor_display(data: BuildingData) -> void:
	# Get processor component
	var processor := _current_building.get_processor() if _current_building else null
	if not processor or not processor.is_initialized():
		_hide_processor_ui()
		return

	# Show inputs section (AC1, AC11)
	if _inputs_section:
		_inputs_section.visible = true

	# Update input requirements (AC2, AC3)
	_update_inputs_display(processor)

	# Update recipe flow display (AC7, AC8)
	_update_recipe_flow_display(processor)

	# Update progress bar display (Story 4-6: AC1, AC3)
	_update_progress_bar_display(processor)

	# Update storage display (Story 4-6: AC4, AC5, AC6)
	_update_storage_display(processor)

	# Update output label from recipe
	var outputs: Array[Dictionary] = processor.get_output_types()
	if _output_label and outputs.size() > 0:
		var output_name: String = outputs[0].get("resource_id", "").capitalize()
		_output_label.text = output_name

	# Cycle time from recipe
	if _cycle_label:
		_cycle_label.text = "%.1fs" % processor.get_production_time()

	# Production status (AC5, AC6, AC10)
	if _status_label:
		_status_label.text = _get_processor_status_text(processor)


## Hide PROCESSOR-specific UI elements (Story 4-6: also hide progress bar and storage)
func _hide_processor_ui() -> void:
	if _inputs_section:
		_inputs_section.visible = false
	if _recipe_flow_row:
		_recipe_flow_row.visible = false
	# Story 4-6: Hide progress bar and storage row for GATHERER buildings (AC9)
	if _progress_bar_row:
		_progress_bar_row.visible = false
	if _storage_row:
		_storage_row.visible = false


## Get production status text for GATHERER buildings
func _get_gatherer_status_text(data: BuildingData) -> String:
	if not _current_building.is_production_active():
		return STATUS_IDLE

	# Null safety: ResourceManager may be unavailable during shutdown
	if is_instance_valid(ResourceManager) and ResourceManager.is_gathering_paused(data.output_resource_id):
		return STATUS_PAUSED

	return STATUS_ACTIVE


## Get production status text for PROCESSOR buildings (AC5, AC6, AC10) - Story 4-5
func _get_processor_status_text(processor: Node) -> String:
	# Check worker count first
	if not _current_building.is_production_active():
		return STATUS_IDLE

	# Check storage full (any output) - AC10
	var outputs: Array[Dictionary] = processor.get_output_types()
	for output in outputs:
		var resource_id: String = output.get("resource_id", "")
		if is_instance_valid(ResourceManager) and ResourceManager.is_gathering_paused(resource_id):
			return STATUS_PAUSED

	# Check waiting for inputs - AC5
	if processor.get_waiting_worker_count() > 0:
		return STATUS_WAITING

	# Must be producing - AC6 (get output name)
	if outputs.size() > 0:
		var output_name: String = outputs[0].get("resource_id", "").capitalize()
		return STATUS_PRODUCING % output_name

	return STATUS_ACTIVE


## Update input requirements display (AC2, AC3, AC4) - Story 4-5
func _update_inputs_display(processor: Node) -> void:
	if not _inputs_container:
		return

	# Clear existing items
	for child in _inputs_container.get_children():
		child.queue_free()

	# Get recipe inputs
	var inputs: Array[Dictionary] = processor.get_input_requirements()
	var recipe: RecipeData = processor.get_recipe()
	if recipe == null:
		return

	# Create display item for each input
	for input in inputs:
		var resource_id: String = input.get("resource_id", "")
		var amount_required: int = input.get("amount", 0)
		var amount_available := ResourceManager.get_resource_amount(resource_id) if is_instance_valid(ResourceManager) else 0

		var item := _create_input_requirement_row(resource_id, amount_required, amount_available)
		_inputs_container.add_child(item)


## Create a single input requirement row (AC2, AC3) - Story 4-5
func _create_input_requirement_row(resource_id: String, amount_required: int, amount_available: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	# Resource icon
	var icon := Label.new()
	icon.text = RESOURCE_ICONS.get(resource_id, "📦")
	icon.add_theme_font_size_override("font_size", 14)
	icon.custom_minimum_size = Vector2(20, 0)
	row.add_child(icon)

	# "Needs:" label
	var needs_label := Label.new()
	needs_label.text = "Needs:"
	needs_label.add_theme_font_size_override("font_size", 12)
	needs_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7, 1))
	row.add_child(needs_label)

	# Amount and resource name
	var amount_label := Label.new()
	amount_label.text = "%d %s" % [amount_required, resource_id.capitalize()]
	amount_label.add_theme_font_size_override("font_size", 12)
	amount_label.add_theme_color_override("font_color", Color(1, 0.95, 0.9, 1))
	amount_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(amount_label)

	# Status indicator (AC2, AC3)
	var status_label := Label.new()
	if amount_available >= amount_required:
		# Available (green checkmark)
		status_label.text = "✓ Available"
		status_label.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4, 1))
	else:
		# Missing (red X with amount needed)
		var short := amount_required - amount_available
		status_label.text = "✗ Need %d more" % short
		status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1))
	status_label.add_theme_font_size_override("font_size", 12)
	row.add_child(status_label)

	return row


## Update recipe flow display "2 Wheat → 1 Flour (3.0s)" (AC7, AC8) - Story 4-5
func _update_recipe_flow_display(processor: Node) -> void:
	if not _recipe_flow_row or not _recipe_flow_label:
		return

	_recipe_flow_row.visible = true

	var inputs: Array[Dictionary] = processor.get_input_requirements()
	var outputs: Array[Dictionary] = processor.get_output_types()
	var production_time: float = processor.get_production_time()

	# Build input string
	var input_parts: Array[String] = []
	for input in inputs:
		var resource_id: String = input.get("resource_id", "")
		var amount: int = input.get("amount", 0)
		input_parts.append("%d %s" % [amount, resource_id.capitalize()])
	var input_str := " + ".join(input_parts) if input_parts.size() > 1 else (input_parts[0] if input_parts.size() > 0 else "")

	# Build output string
	var output_parts: Array[String] = []
	for output in outputs:
		var resource_id: String = output.get("resource_id", "")
		var amount: int = output.get("amount", 0)
		output_parts.append("%d %s" % [amount, resource_id.capitalize()])
	var output_str := " + ".join(output_parts) if output_parts.size() > 1 else (output_parts[0] if output_parts.size() > 0 else "")

	# Format: "2 Wheat → 1 Flour (3.0s)"
	_recipe_flow_label.text = "%s → %s (%.1fs)" % [input_str, output_str, production_time]


# =============================================================================
# PROGRESS BAR AND STORAGE DISPLAY (Story 4-6)
# =============================================================================

## Apply cozy theme styling to the progress bar (Task 1.6)
func _apply_progress_bar_styling() -> void:
	if not _production_progress_bar:
		return

	# Fill style - warm green matching cozy game theme
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.4, 0.7, 0.3, 1)  # Warm green
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	_production_progress_bar.add_theme_stylebox_override("fill", fill_style)

	# Background style - dark with transparency
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	_production_progress_bar.add_theme_stylebox_override("background", bg_style)


## Update progress bar display for PROCESSOR buildings (AC1, AC2, AC3, AC7, AC8, AC10)
func _update_progress_bar_display(processor: Node) -> void:
	if not _progress_bar_row or not _production_progress_bar or not _progress_percent_label:
		return

	# Show progress bar row for PROCESSOR
	_progress_bar_row.visible = true

	# Get max progress across all workers (AC3)
	var max_progress := _get_max_worker_progress(processor)

	# Set progress bar value (0-100) (AC1, AC4)
	var progress_percent := max_progress * 100.0
	_production_progress_bar.value = progress_percent

	# Update percentage label text (AC8 - shows 0% when no workers or all waiting)
	_progress_percent_label.text = "%d%%" % int(progress_percent)


## Get maximum progress across all producing workers (AC3)
func _get_max_worker_progress(processor: Node) -> float:
	var max_progress := 0.0

	if not is_instance_valid(_current_building):
		return 0.0

	var slots := _current_building.get_worker_slots()
	if not slots:
		return 0.0

	var workers: Array[Animal] = slots.get_workers()
	for worker in workers:
		if not is_instance_valid(worker):
			continue
		# Skip workers that are waiting (not producing) - they have no progress
		if processor.is_worker_waiting(worker):
			continue

		var progress: float = processor.get_worker_progress(worker)
		if progress > max_progress:
			max_progress = progress

	return max_progress


## Update storage display for PROCESSOR buildings (AC4, AC5, AC6)
## Note: Storage updates on events (selection, resource_changed), not every frame - intentional for performance
func _update_storage_display(processor: Node) -> void:
	if not _storage_row or not _output_storage_label:
		return

	_storage_row.visible = true

	var outputs: Array[Dictionary] = processor.get_output_types()
	if outputs.is_empty():
		_storage_row.visible = false
		return

	var resource_id: String = outputs[0].get("resource_id", "")
	var current := ResourceManager.get_resource_amount(resource_id) if is_instance_valid(ResourceManager) else 0

	# Get capacity from ResourceManager (uses resource data's max_stack_size)
	var capacity := GameConstants.DEFAULT_VILLAGE_STORAGE_CAPACITY
	if is_instance_valid(ResourceManager) and ResourceManager.has_method("get_storage_limit"):
		capacity = ResourceManager.get_storage_limit(resource_id)

	# Icon (AC4)
	if _output_storage_icon:
		_output_storage_icon.text = RESOURCE_ICONS.get(resource_id, "📦")

	# Calculate fill percentage
	var fill_percent := 0.0
	if capacity > 0:
		fill_percent = float(current) / float(capacity) * 100.0

	# Format and color based on fill level (AC4, AC5, AC6)
	var display_text := "%s: %d/%d" % [resource_id.capitalize(), current, capacity]
	var display_color := COLOR_STORAGE_NORMAL

	if fill_percent >= 100.0:
		display_text += " FULL"
		display_color = COLOR_STORAGE_FULL
	elif fill_percent >= 80.0:
		display_color = COLOR_STORAGE_WARNING

	_output_storage_label.text = display_text
	_output_storage_label.add_theme_color_override("font_color", display_color)
	_current_storage_color = display_color  # Track for testing API


# =============================================================================
# WORKER SECTION (Story 3-10)
# =============================================================================

## Find the WorkerSelectionOverlay in the scene tree
func _find_worker_selection_overlay() -> void:
	# Look for overlay in UI layer (sibling or child)
	var ui_layer: Node = get_parent()
	if ui_layer:
		_worker_selection_overlay = ui_layer.get_node_or_null("WorkerSelectionOverlay")
	if _worker_selection_overlay:
		GameLogger.debug("UI", "Found WorkerSelectionOverlay")


## Update worker section visibility and button state (AC1, AC2, AC11)
## Updated Story 4-5: Show worker section for BOTH gatherer AND processor buildings
## Updated Story 5-11: Show worker section for SHELTER buildings (animals inside)
func _update_worker_section(data: BuildingData) -> void:
	if not _worker_section:
		return

	# SHELTER buildings show occupants without assign button (Story 5-11)
	if data.building_type == BuildingTypes.BuildingType.SHELTER:
		_worker_section.visible = true
		# Hide assign button for shelters - animals auto-seek (AC 8)
		if _assign_worker_button:
			_assign_worker_button.visible = false
		# Still show worker icons (resting animals)
		_update_worker_icons()
		return

	# Show worker section for gatherer AND processor buildings (Story 4-5)
	if not data.is_gatherer() and not data.is_producer():
		_worker_section.visible = false
		return

	_worker_section.visible = true
	if _assign_worker_button:
		_assign_worker_button.visible = true

	# Update assign worker button state (AC1, AC2)
	_update_assign_button_state()

	# Update worker icons display (AC7 - display assigned workers)
	_update_worker_icons()


## Update assign worker button enabled/disabled state (AC1, AC2)
func _update_assign_button_state() -> void:
	if not _assign_worker_button:
		return

	if not is_instance_valid(_current_building):
		_assign_worker_button.disabled = true
		return

	var slots := _current_building.get_worker_slots()
	if not slots:
		_assign_worker_button.disabled = true
		return

	# AC2: Disable button when slots are full
	_assign_worker_button.disabled = not slots.is_slot_available()


## Update worker icons in the container (AC7)
func _update_worker_icons() -> void:
	if not _worker_icons_container:
		return

	# Clear existing icons
	for child in _worker_icons_container.get_children():
		child.queue_free()

	if not is_instance_valid(_current_building):
		return

	var slots := _current_building.get_worker_slots()
	if not slots:
		return

	# Get assigned workers
	var workers: Array[Animal] = slots.get_workers()

	for i in range(mini(workers.size(), MAX_WORKER_ICONS_DISPLAY)):
		var worker := workers[i]
		if not is_instance_valid(worker):
			continue

		var icon := _create_worker_icon(worker)
		_worker_icons_container.add_child(icon)

	# Show overflow indicator if more workers than displayed
	if workers.size() > MAX_WORKER_ICONS_DISPLAY:
		var overflow := Label.new()
		overflow.text = "+%d" % (workers.size() - MAX_WORKER_ICONS_DISPLAY)
		overflow.add_theme_font_size_override("font_size", 14)
		overflow.add_theme_color_override("font_color", Color(0.8, 0.75, 0.7, 1))
		_worker_icons_container.add_child(overflow)


## Create a clickable worker icon (AC7, AC8)
## M1 fix: Use actual animal type for icon
## M5 fix: Include energy in tooltip
func _create_worker_icon(animal: Animal) -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(32, 32)

	# M1 fix: Get correct icon based on animal type
	button.text = _get_animal_icon_emoji(animal)

	# M5 fix: Add energy info to tooltip
	var energy_text := _get_animal_energy_text(animal)
	button.tooltip_text = "Click to unassign\n%s" % energy_text

	# Style the button
	button.add_theme_font_size_override("font_size", 18)

	# Connect press to unassign handler
	button.pressed.connect(_on_worker_icon_pressed.bind(animal))

	return button


## Get emoji icon based on animal type (M1 fix)
func _get_animal_icon_emoji(animal: Animal) -> String:
	if not is_instance_valid(animal):
		return "🐾"

	var stats = animal.get_stats() if animal.has_method("get_stats") else null
	if stats and "animal_type" in stats:
		match stats.animal_type:
			"rabbit":
				return "🐰"
			"squirrel":
				return "🐿️"
			"deer":
				return "🦌"
			"fox":
				return "🦊"

	return "🐾"  # Default animal paw


## Get animal energy text for tooltip (M5 fix)
func _get_animal_energy_text(animal: Animal) -> String:
	if not is_instance_valid(animal):
		return "Energy: --"

	var stats_comp := animal.get_node_or_null("StatsComponent")
	if not stats_comp:
		return "Energy: --"

	var energy := 100
	var max_energy := 100

	if stats_comp.has_method("get_energy"):
		energy = stats_comp.get_energy()
	if stats_comp.has_method("get_max_energy"):
		max_energy = stats_comp.get_max_energy()

	if max_energy <= 0:
		return "Energy: 100%"

	var percent := int(float(energy) / float(max_energy) * 100.0)
	return "Energy: %d%%" % percent


## Handle worker icon pressed - unassign worker (AC8)
func _on_worker_icon_pressed(animal: Animal) -> void:
	if not is_instance_valid(animal):
		return
	if not is_instance_valid(_current_building):
		return

	var slots := _current_building.get_worker_slots()
	if not slots:
		return

	# Remove from building (AC8)
	if slots.remove_worker(animal):
		# Clear building reference
		animal.clear_assigned_building()

		# Transition to IDLE state
		var ai := animal.get_node_or_null("AIComponent")
		if ai and ai.has_method("transition_to"):
			ai.transition_to(AIComponent.AnimalState.IDLE)

		GameLogger.info("UI", "Unassigned worker from %s" % _current_building.get_building_id())

	# Panel will auto-update via workers_changed signal


## Handle assign worker button pressed (AC3)
## M2 fix: Connect to overlay signals for panel refresh
func _on_assign_worker_pressed() -> void:
	if not is_instance_valid(_current_building):
		GameLogger.warn("UI", "No current building for worker assignment")
		return

	# Find overlay if not cached
	if not _worker_selection_overlay:
		_find_worker_selection_overlay()

	if _worker_selection_overlay and _worker_selection_overlay.has_method("show_for_building"):
		# M2 fix: Connect to worker_assigned signal for panel refresh
		_connect_overlay_signals()
		_worker_selection_overlay.show_for_building(_current_building)
		GameLogger.debug("UI", "Opened worker selection overlay for %s" % _current_building.get_building_id())
	else:
		GameLogger.warn("UI", "WorkerSelectionOverlay not found - cannot assign worker")


## Connect to overlay signals (M2 fix)
func _connect_overlay_signals() -> void:
	if not _worker_selection_overlay:
		return

	# Connect worker_assigned for immediate panel refresh
	if _worker_selection_overlay.has_signal("worker_assigned"):
		if not _worker_selection_overlay.worker_assigned.is_connected(_on_overlay_worker_assigned):
			_worker_selection_overlay.worker_assigned.connect(_on_overlay_worker_assigned)

	# Connect closed to disconnect signals
	if _worker_selection_overlay.has_signal("closed"):
		if not _worker_selection_overlay.closed.is_connected(_on_overlay_closed):
			_worker_selection_overlay.closed.connect(_on_overlay_closed)


## Handle worker assigned from overlay (M2 fix - AC4.4)
func _on_overlay_worker_assigned(_animal: Animal, _building: Building) -> void:
	# Refresh panel display immediately after assignment
	_update_display()


## Handle overlay closed - disconnect signals (M2 fix)
func _on_overlay_closed() -> void:
	_disconnect_overlay_signals()


## Disconnect overlay signals (M2 fix)
func _disconnect_overlay_signals() -> void:
	if not _worker_selection_overlay:
		return

	if _worker_selection_overlay.has_signal("worker_assigned"):
		if _worker_selection_overlay.worker_assigned.is_connected(_on_overlay_worker_assigned):
			_worker_selection_overlay.worker_assigned.disconnect(_on_overlay_worker_assigned)

	if _worker_selection_overlay.has_signal("closed"):
		if _worker_selection_overlay.closed.is_connected(_on_overlay_closed):
			_worker_selection_overlay.closed.disconnect(_on_overlay_closed)


## Set the worker selection overlay reference (for dependency injection/testing)
func set_worker_selection_overlay(overlay: Control) -> void:
	_worker_selection_overlay = overlay


## Get the assign worker button visibility state (for testing)
func is_assign_button_visible() -> bool:
	if not _worker_section or not _assign_worker_button:
		return false
	return _worker_section.visible and _assign_worker_button.visible


## Get the assign worker button disabled state (for testing)
func is_assign_button_disabled() -> bool:
	if not _assign_worker_button:
		return true
	return _assign_worker_button.disabled


## Get the worker icons container (for testing)
func get_worker_icons_count() -> int:
	if not _worker_icons_container:
		return 0
	# Count only buttons (worker icons), not overflow labels
	var count := 0
	for child in _worker_icons_container.get_children():
		if child is Button:
			count += 1
	return count
