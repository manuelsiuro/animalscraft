## Building - Base class for all building entities in AnimalsCraft.
## Follows composition pattern with child component nodes.
## Buildings are Node3D positioned on the Y=0 ground plane.
##
## Architecture: scripts/entities/buildings/building.gd
## Story: 3-1-create-building-entity-structure
class_name Building
extends Node3D

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when building is selected by player
signal selected()

## Emitted when building is deselected
signal deselected()

# =============================================================================
# PROPERTIES
# =============================================================================

## Current hex coordinate of this building
var hex_coord: HexCoord

## Data resource for this building type
var data: BuildingData

## Whether building has been properly initialized
var _initialized: bool = false

## Track if production has been started (for signal emission) (Story 3-8)
var _production_active: bool = false

# =============================================================================
# COMPONENTS (child nodes, assigned in _ready)
# =============================================================================

@onready var _visual: Node3D = $Visual
@onready var _selectable: SelectableComponent = $SelectableComponent
@onready var _worker_slots: WorkerSlotComponent = $WorkerSlotComponent

## GathererComponent for production - optional, only for gatherer buildings (Story 3-8)
## Note: Using Node type to avoid load order issues with class_name
var _gatherer: Node = null

## ProcessorComponent for recipe-based production - optional, only for PROCESSOR buildings (Story 4-4)
## Note: Using Node type to avoid load order issues with class_name
var _processor: Node = null

## ShelterComponent for animal rest recovery - optional, only for SHELTER buildings (Story 5-11)
## Note: Using Node type to avoid load order issues with class_name
var _shelter: Node = null

# =============================================================================
# SELECTION VISUAL (same pattern as Animal)
# =============================================================================

## Selection highlight node (created dynamically)
var _selection_highlight: MeshInstance3D

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	add_to_group("buildings")
	_setup_selection_visual()
	_setup_components()


## Initialize building with hex position and data.
## Must be called after scene instantiation.
## @param hex: The hex coordinate to place the building
## @param building_data: The data resource for this building type
func initialize(hex: HexCoord, building_data: BuildingData) -> void:
	if _initialized:
		GameLogger.warn("Building", "Building already initialized: %s" % (building_data.building_id if building_data else "unknown"))
		return

	hex_coord = hex
	data = building_data

	# Position at hex world location
	if hex:
		position = HexGrid.hex_to_world(hex)
	else:
		GameLogger.warn("Building", "Initialized with null hex coordinate")

	# Initialize worker slots if it exists and has initialize method
	if _worker_slots and _worker_slots.has_method("initialize"):
		_worker_slots.initialize(building_data.max_workers if building_data else 0)

	# Initialize GathererComponent for gatherer buildings (Story 3-8)
	if building_data and building_data.is_gatherer():
		_gatherer = get_node_or_null("GathererComponent")
		if _gatherer and _gatherer.has_method("initialize"):
			_gatherer.initialize(self, building_data.output_resource_id, building_data.production_time)

	# Initialize ProcessorComponent for PROCESSOR buildings (Story 4-4)
	if building_data and building_data.is_producer():
		_processor = get_node_or_null("ProcessorComponent")
		if _processor and _processor.has_method("initialize"):
			_processor.initialize(self, building_data.production_recipe_id)

	# Initialize ShelterComponent for SHELTER buildings (Story 5-11)
	if building_data and building_data.building_type == BuildingTypes.BuildingType.SHELTER:
		_shelter = get_node_or_null("ShelterComponent")
		if _shelter and _shelter.has_method("initialize"):
			_shelter.initialize(self)
		# Add to "shelters" group for efficient lookup (Party Mode performance feedback)
		add_to_group(GameConstants.GROUP_SHELTERS)

	# Mark hex as occupied
	_mark_hex_occupied()

	_initialized = true

	if building_data:
		GameLogger.info("Building", "Spawned %s at %s" % [building_data.building_id, hex])
	else:
		GameLogger.info("Building", "Spawned building at %s" % hex)

	# Notify other systems
	EventBus.building_spawned.emit(self)


func _setup_components() -> void:
	# Wire up component references and connect signals

	# Connect to selectable component signals
	if _selectable:
		_selectable.selection_changed.connect(_on_selection_changed)

	# Connect to worker slot signals (PARTY MODE feature)
	if _worker_slots:
		_worker_slots.worker_added.connect(_on_worker_added)
		_worker_slots.worker_removed.connect(_on_worker_removed)


func _setup_selection_visual() -> void:
	# Create selection highlight as child node (same as Animal)
	_selection_highlight = MeshInstance3D.new()
	_selection_highlight.name = "SelectionHighlight"

	# Create highlight mesh (torus ring around entity)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5  # Slightly larger than Animal for buildings
	torus.outer_radius = 0.7
	torus.rings = 16
	torus.ring_segments = 32
	_selection_highlight.mesh = torus

	# Create emissive material for glow effect (high contrast for all terrains)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.8, 0.2)  # Golden yellow
	material.emission_enabled = true
	material.emission = Color(1.0, 0.8, 0.2)
	material.emission_energy_multiplier = 2.0
	_selection_highlight.material_override = material

	# Position at entity base (just above ground to avoid z-fighting)
	_selection_highlight.position.y = 0.05
	# Rotate to lay flat on ground plane
	_selection_highlight.rotation_degrees.x = -90

	# Initially hidden
	_selection_highlight.visible = false

	add_child(_selection_highlight)


## Show selection highlight with juice animation
func show_selection_highlight() -> void:
	if _selection_highlight:
		_selection_highlight.visible = true
	_play_selection_juice()


## Hide selection highlight
func hide_selection_highlight() -> void:
	if _selection_highlight:
		_selection_highlight.visible = false


## Play selection "juice" - scale pulse for satisfying feedback
func _play_selection_juice() -> void:
	# Scale pulse animation (1.0 → 1.05 → 1.0 over 0.2s)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.05, 1.05, 1.05), 0.1)
	tween.tween_property(self, "scale", Vector3.ONE, 0.1)

	# Play selection SFX (placeholder until audio assets exist)
	var sfx_path := "res://assets/audio/sfx/sfx_ui_select.ogg"
	if ResourceLoader.exists(sfx_path) and AudioManager and AudioManager.has_method("play_ui_sfx"):
		AudioManager.play_ui_sfx("select")


func _on_selection_changed(is_selected_state: bool) -> void:
	if is_selected_state:
		show_selection_highlight()
		selected.emit()
	else:
		hide_selection_highlight()
		deselected.emit()


## Handle worker_added signal from WorkerSlotComponent (Story 3-8)
## Starts production for the worker on GathererComponent or ProcessorComponent if available.
## For shelters, adds animal to ShelterComponent for recovery tracking (Story 5-11).
func _on_worker_added(animal: Animal) -> void:
	var animal_id := animal.get_animal_id() if animal.has_method("get_animal_id") else "unknown"
	GameLogger.debug("Building", "Worker assigned: %s" % animal_id)

	# Start production on GathererComponent (Story 3-8)
	if _gatherer and _gatherer.is_initialized():
		_gatherer.start_worker(animal)

		# Emit production_started on first worker (AC4)
		if not _production_active:
			_production_active = true
			EventBus.production_started.emit(self)
			GameLogger.info("Building", "Production started at %s" % get_building_id())

	# Start production on ProcessorComponent (Story 4-4)
	if _processor and _processor.is_initialized():
		_processor.start_worker(animal)

		# Emit production_started on first worker
		if not _production_active:
			_production_active = true
			EventBus.production_started.emit(self)
			GameLogger.info("Building", "Production started at %s" % get_building_id())

	# Add animal to ShelterComponent for recovery tracking (Story 5-11)
	if _shelter and _shelter.is_initialized():
		_shelter.add_resting_animal(animal)


## Handle worker_removed signal from WorkerSlotComponent (Story 3-8)
## Stops production for the worker on GathererComponent or ProcessorComponent if available.
## For shelters, removes animal from ShelterComponent (Story 5-11).
func _on_worker_removed(animal: Animal) -> void:
	var animal_id := animal.get_animal_id() if animal and animal.has_method("get_animal_id") else "unknown"
	GameLogger.debug("Building", "Worker unassigned: %s" % animal_id)

	# Stop production on GathererComponent (Story 3-8)
	if _gatherer and _gatherer.is_initialized():
		_gatherer.stop_worker(animal)

		# Emit production_halted when last worker leaves (AC4)
		if _worker_slots and _worker_slots.get_worker_count() == 0:
			_production_active = false
			EventBus.production_halted.emit(self, "no_workers")
			GameLogger.info("Building", "Production halted at %s - no workers" % get_building_id())

	# Stop production on ProcessorComponent (Story 4-4)
	if _processor and _processor.is_initialized():
		_processor.stop_worker(animal)

		# Emit production_halted when last worker leaves
		if _worker_slots and _worker_slots.get_worker_count() == 0:
			_production_active = false
			EventBus.production_halted.emit(self, "no_workers")
			GameLogger.info("Building", "Production halted at %s - no workers" % get_building_id())

	# Remove animal from ShelterComponent (Story 5-11)
	if _shelter and _shelter.is_initialized():
		_shelter.remove_resting_animal(animal)

# =============================================================================
# HEX OCCUPANCY
# =============================================================================

## Mark this building's footprint hexes as occupied.
func _mark_hex_occupied() -> void:
	if not hex_coord:
		return
	if not data:
		return

	var base_vec: Vector2i = hex_coord.to_vector()

	# Mark all footprint hexes
	for offset in data.footprint_hexes:
		var occupied_hex: Vector2i = base_vec + offset
		HexGrid.mark_hex_occupied(occupied_hex, self)


## Unmark this building's footprint hexes.
func _unmark_hex_occupied() -> void:
	if not hex_coord:
		return
	if not data:
		return

	var base_vec: Vector2i = hex_coord.to_vector()

	# Unmark all footprint hexes
	for offset in data.footprint_hexes:
		var occupied_hex: Vector2i = base_vec + offset
		HexGrid.mark_hex_unoccupied(occupied_hex)

# =============================================================================
# PUBLIC API
# =============================================================================

## Check if building is properly initialized
func is_initialized() -> bool:
	return _initialized


## Get current hex coordinate
func get_hex_coord() -> HexCoord:
	return hex_coord


## Get building data
func get_data() -> BuildingData:
	return data


## Get the building's unique identifier (from data)
func get_building_id() -> String:
	if data:
		return data.building_id
	return ""


## Get the building's type
func get_building_type() -> BuildingTypes.BuildingType:
	if data:
		return data.building_type
	return BuildingTypes.BuildingType.GATHERER


## Check if this building is currently selected
func is_selected() -> bool:
	if _selectable:
		return _selectable.is_selected()
	return false


## Get the worker slot component for external access
func get_worker_slots() -> WorkerSlotComponent:
	return _worker_slots


## Get the gatherer component for external access (Story 3-8).
## @return GathererComponent (as Node) or null if not a gatherer building
func get_gatherer() -> Node:
	return _gatherer


## Check if this building is a gatherer (produces resources) (Story 3-8).
## @return true if this building has a GathererComponent
func is_gatherer() -> bool:
	return _gatherer != null and _gatherer.is_initialized()


## Get the processor component for external access (Story 4-4).
## @return ProcessorComponent (as Node) or null if not a processor building
func get_processor() -> Node:
	return _processor


## Check if this building is a processor (transforms resources via recipes) (Story 4-4).
## @return true if this building has a ProcessorComponent
func is_processor() -> bool:
	return _processor != null and _processor.is_initialized()


## Check if production is currently active (Story 3-8).
## @return true if at least one worker is producing
func is_production_active() -> bool:
	return _production_active


## Get the shelter component for external access (Story 5-11).
## @return ShelterComponent (as Node) or null if not a shelter building
func get_shelter() -> Node:
	return _shelter


## Check if this building is a shelter (provides rest recovery bonus) (Story 5-11).
## @return true if this building has a ShelterComponent
func is_shelter() -> bool:
	return _shelter != null and _shelter.is_initialized()

# =============================================================================
# CLEANUP
# =============================================================================

## Clean up building resources before removal.
## Call this before queue_free() for proper cleanup.
func cleanup() -> void:
	# 1. Stop processes
	set_process(false)
	set_physics_process(false)

	# 2. Emit removal signal before cleanup (only if initialized)
	# Include hex coordinate for path cache invalidation (Epic 2 retrospective)
	if _initialized:
		var hex_vec: Vector2i = hex_coord.to_vector() if hex_coord else Vector2i.ZERO
		EventBus.building_removed.emit(self, hex_vec)

	# 3. Disconnect signals to prevent orphan connections
	if _selectable and _selectable.selection_changed.is_connected(_on_selection_changed):
		_selectable.selection_changed.disconnect(_on_selection_changed)
	if _worker_slots:
		if _worker_slots.worker_added.is_connected(_on_worker_added):
			_worker_slots.worker_added.disconnect(_on_worker_added)
		if _worker_slots.worker_removed.is_connected(_on_worker_removed):
			_worker_slots.worker_removed.disconnect(_on_worker_removed)
		# Clean up worker slot references
		_worker_slots.cleanup()

	# 4. Clean up GathererComponent (Story 3-8)
	if _gatherer:
		_gatherer.cleanup()
		_gatherer = null

	# 4b. Clean up ProcessorComponent (Story 4-4)
	if _processor:
		_processor.cleanup()
		_processor = null

	# 4c. Clean up ShelterComponent (Story 5-11, AC: 23)
	# Notifies resting animals to continue resting outdoors
	if _shelter:
		_shelter.cleanup()
		_shelter = null
		# Remove from shelters group
		remove_from_group(GameConstants.GROUP_SHELTERS)

	# 5. Unmark hex occupancy
	_unmark_hex_occupied()

	# 6. Clear references
	hex_coord = null
	data = null
	_production_active = false

	# 7. Remove from groups
	remove_from_group("buildings")

	# 8. Queue for deletion
	queue_free()

# =============================================================================
# STRING REPRESENTATION
# =============================================================================

func _to_string() -> String:
	if data:
		return "Building<%s at %s>" % [data.building_id, hex_coord]
	return "Building<uninitialized>"
