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
@onready var _worker_section: Control = $PanelContainer/MarginContainer/VBoxContainer/WorkerSection
@onready var _worker_icons_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/WorkerSection/WorkerIconsContainer
@onready var _assign_worker_button: Button = $PanelContainer/MarginContainer/VBoxContainer/WorkerSection/AssignWorkerButton

# =============================================================================
# CONSTANTS
# =============================================================================

## Production status display strings
const STATUS_IDLE := "Idle (No Workers)"
const STATUS_ACTIVE := "Active"
const STATUS_PAUSED := "Paused (Storage Full)"

## Maximum worker icons to display before showing overflow indicator (M4 fix)
const MAX_WORKER_ICONS_DISPLAY := 4

# =============================================================================
# STATE
# =============================================================================

## Currently displayed building reference
var _current_building: Building = null

## Cache worker slots reference for signal disconnection
var _cached_worker_slots: WorkerSlotComponent = null

## Reference to WorkerSelectionOverlay (assigned from game.tscn or found at runtime)
var _worker_selection_overlay: Control = null

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

	# Connect assign worker button (Story 3-10)
	if _assign_worker_button:
		_assign_worker_button.pressed.connect(_on_assign_worker_pressed)

	# Find WorkerSelectionOverlay (deferred to allow scene to initialize)
	call_deferred("_find_worker_selection_overlay")

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

	# Worker section with assign button (Story 3-10)
	_update_worker_section(data)


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
func _update_worker_section(data: BuildingData) -> void:
	if not _worker_section:
		return

	# AC11: Only show worker section for gatherer buildings
	if not data.is_gatherer():
		_worker_section.visible = false
		return

	_worker_section.visible = true

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
