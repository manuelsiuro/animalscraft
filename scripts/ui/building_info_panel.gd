## BuildingInfoPanel - Displays selected building's information in a UI panel.
## Listens to EventBus for selection changes and updates in real-time.
## Mirrors AnimalStatsPanel architecture for consistency.
##
## Architecture: scripts/ui/building_info_panel.gd
## Story: 3-9-implement-building-selection
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

# =============================================================================
# CONSTANTS
# =============================================================================

## Production status display strings
const STATUS_IDLE := "Idle (No Workers)"
const STATUS_ACTIVE := "Active"
const STATUS_PAUSED := "Paused (Storage Full)"

# =============================================================================
# STATE
# =============================================================================

## Currently displayed building reference
var _current_building: Building = null

## Cache worker slots reference for signal disconnection
var _cached_worker_slots: WorkerSlotComponent = null

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

	GameLogger.info("UI", "BuildingInfoPanel initialized")


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

	# Production section (for gatherers)
	_update_production_display(data)


## Update worker count display
func _update_workers_display(data: BuildingData) -> void:
	if not _workers_label:
		return

	var slots := _current_building.get_worker_slots()
	if slots:
		var current_workers := slots.get_worker_count()
		var max_workers := data.max_workers
		_workers_label.text = "Workers: %d/%d" % [current_workers, max_workers]
	else:
		_workers_label.text = "Workers: 0/%d" % data.max_workers


## Update production status display (for gatherer buildings)
func _update_production_display(data: BuildingData) -> void:
	if not _production_section:
		return

	# Only show production section for gatherer buildings
	if not data.is_gatherer():
		_production_section.visible = false
		return

	_production_section.visible = true

	# Output resource
	if _output_label:
		_output_label.text = data.output_resource_id.capitalize()

	# Cycle time
	if _cycle_label:
		_cycle_label.text = "%.1fs" % data.production_time

	# Production status
	if _status_label:
		_status_label.text = _get_production_status_text(data)


## Get production status text based on building state
func _get_production_status_text(data: BuildingData) -> String:
	if not _current_building.is_production_active():
		return STATUS_IDLE

	# Null safety: ResourceManager may be unavailable during shutdown
	if is_instance_valid(ResourceManager) and ResourceManager.is_gathering_paused(data.output_resource_id):
		return STATUS_PAUSED

	return STATUS_ACTIVE
