## Animal - Base class for all animal entities in AnimalsCraft.
## Follows composition pattern with child component nodes.
## Animals are Node3D positioned on the Y=0 ground plane.
##
## Architecture: scripts/entities/animals/animal.gd
## Story: 2-1-create-animal-entity-structure
## Updated: 2-3-implement-animal-selection (visual feedback, selection signals)
class_name Animal
extends Node3D

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when animal is selected by player
signal selected()

## Emitted when animal is deselected
signal deselected()

# =============================================================================
# PROPERTIES
# =============================================================================

## Current hex coordinate of this animal
var hex_coord: HexCoord

## Stats resource for this animal type
var stats: AnimalStats

## Whether animal has been properly initialized
var _initialized: bool = false

## Current building this animal is assigned to (Story 3-8).
## Used for worker assignment tracking and cleanup.
var _current_building: Node = null

## Target building this animal is walking towards (Story 5-11).
## Used by ShelterSeekingSystem for routing and by RestingState for recovery bonus.
var _target_building: Node = null

## Whether this animal is wild (Story 5-2).
## Wild animals belong to enemy herds and display visual distinction.
var is_wild: bool = false

# =============================================================================
# COMPONENTS (child nodes, assigned in _ready)
# =============================================================================

@onready var _visual: Node3D = $Visual
@onready var _selectable: SelectableComponent = $SelectableComponent
@onready var _movement: Node = $MovementComponent
@onready var _stats_component: Node = $StatsComponent
@onready var _ai: Node = $AIComponent

# =============================================================================
# SELECTION VISUAL (Story 2-3)
# =============================================================================

## Selection highlight node (created dynamically)
var _selection_highlight: MeshInstance3D

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	add_to_group("animals")
	_setup_selection_visual()
	_setup_components()


## Initialize animal with hex position and stats.
## Must be called after scene instantiation.
## @param hex: The hex coordinate to place the animal
## @param animal_stats: The stats resource for this animal type
func initialize(hex: HexCoord, animal_stats: AnimalStats) -> void:
	if _initialized:
		GameLogger.warn("Animal", "Animal already initialized: %s" % (animal_stats.animal_id if animal_stats else "unknown"))
		return

	hex_coord = hex
	stats = animal_stats

	# Position at hex world location
	if hex:
		position = HexGrid.hex_to_world(hex)
	else:
		GameLogger.warn("Animal", "Initialized with null hex coordinate")

	# Initialize stats component if it exists and has initialize method
	if _stats_component and _stats_component.has_method("initialize"):
		_stats_component.initialize(animal_stats)

	_initialized = true

	if animal_stats:
		GameLogger.info("Animal", "Spawned %s at %s" % [animal_stats.animal_id, hex])
	else:
		GameLogger.info("Animal", "Spawned animal at %s" % hex)

	# Notify other systems
	EventBus.animal_spawned.emit(self)


func _setup_components() -> void:
	# Wire up component references and connect signals

	# Connect to selectable component signals (Story 2-3)
	if _selectable:
		_selectable.selection_changed.connect(_on_selection_changed)


func _setup_selection_visual() -> void:
	# Create selection highlight as child node
	_selection_highlight = MeshInstance3D.new()
	_selection_highlight.name = "SelectionHighlight"

	# Create highlight mesh (torus ring around entity)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.6
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


## Play selection "juice" - scale pulse + SFX for satisfying feedback (AC8)
func _play_selection_juice() -> void:
	# Scale pulse animation (1.0 → 1.1 → 1.0 over 0.2s)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3(1.1, 1.1, 1.1), 0.1)
	tween.tween_property(self, "scale", Vector3.ONE, 0.1)

	# Play selection SFX (placeholder - unique per animal type in future)
	# Uses play_ui_sfx which constructs path: res://assets/audio/sfx/sfx_ui_{name}.ogg
	# Check file exists to avoid log spam until audio assets are created (Code Review fix)
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

# =============================================================================
# PUBLIC API
# =============================================================================

## Check if animal is properly initialized
func is_initialized() -> bool:
	return _initialized


## Get current hex coordinate
func get_hex_coord() -> HexCoord:
	return hex_coord


## Get animal stats
func get_stats() -> AnimalStats:
	return stats


## Get the animal's unique identifier (from stats)
func get_animal_id() -> String:
	if stats:
		return stats.animal_id
	return ""


## Check if this animal is currently selected (Story 2-3)
func is_selected() -> bool:
	if _selectable:
		return _selectable.is_selected()
	return false


## Set the building this animal is assigned to (Story 3-8).
## @param building The Building node this animal is working at
func set_assigned_building(building: Node) -> void:
	_current_building = building
	if building:
		GameLogger.debug("Animal", "%s assigned to building" % get_animal_id())


## Get the building this animal is assigned to (Story 3-8).
## @return The Building node or null if not assigned
func get_assigned_building() -> Node:
	return _current_building


## Clear the building assignment (Story 3-8).
## Called when animal is removed from building or building is destroyed.
func clear_assigned_building() -> void:
	if _current_building:
		GameLogger.debug("Animal", "%s cleared building assignment" % get_animal_id())
	_current_building = null


## Check if this animal is assigned to a building (Story 3-8).
## @return true if animal has a building assignment
func has_assigned_building() -> bool:
	return is_instance_valid(_current_building)


## Set the target building this animal is moving towards (Story 5-11).
## Used by ShelterSeekingSystem for shelter routing.
## @param building The Building node this animal is walking to (or null to clear)
func set_target_building(building: Node) -> void:
	_target_building = building
	if building:
		var building_id: String = building.get_building_id() if building.has_method("get_building_id") else "unknown"
		GameLogger.debug("Animal", "%s: Target set to %s" % [get_animal_id(), building_id])
	else:
		GameLogger.debug("Animal", "%s: Target building cleared" % get_animal_id())


## Get the target building this animal is walking towards (Story 5-11).
## @return The Building node or null if no target
func get_target_building() -> Node:
	return _target_building


## Check if this animal has a target building (Story 5-11).
## @return true if animal is walking towards a building
func has_target_building() -> bool:
	return is_instance_valid(_target_building)


## Set whether this animal displays wild indicator (Story 5-2).
## Wild animals have a subtle red tint to distinguish from player-owned animals.
## @param enabled True to show wild indicator, false to hide it
func set_wild_indicator(enabled: bool) -> void:
	is_wild = enabled
	_apply_wild_visual(enabled)


## Check if this animal is wild (Story 5-2).
## @return True if animal belongs to wild/enemy herd
func is_wild_animal() -> bool:
	return is_wild


## Apply visual distinction for wild animals.
## Uses subtle red tint on mesh material.
## IMPORTANT: Creates unique material per animal to avoid shared material bugs.
## @param enabled Whether to enable or disable the visual
func _apply_wild_visual(enabled: bool) -> void:
	if not _visual:
		return

	# Find MeshInstance3D children to apply tint
	for child in _visual.get_children():
		if child is MeshInstance3D:
			var mesh_instance: MeshInstance3D = child
			# Always use material_override to avoid modifying shared materials
			var material: StandardMaterial3D = mesh_instance.material_override as StandardMaterial3D
			if not material:
				# Create a new material override (don't modify shared surface materials)
				material = StandardMaterial3D.new()
				mesh_instance.material_override = material

			if enabled:
				material.albedo_color = Color(1.0, 0.85, 0.85)  # Subtle pink/red
			else:
				material.albedo_color = Color.WHITE

# =============================================================================
# CLEANUP
# =============================================================================

## Clean up animal resources before removal.
## Call this before queue_free() for proper cleanup.
func cleanup() -> void:
	# 1. Stop processes
	set_process(false)
	set_physics_process(false)

	# 2. Emit removal signal before cleanup (only if initialized)
	if _initialized:
		EventBus.animal_removed.emit(self)

	# 3. Disconnect signals to prevent orphan connections
	if _selectable and _selectable.selection_changed.is_connected(_on_selection_changed):
		_selectable.selection_changed.disconnect(_on_selection_changed)

	# AIComponent handles its own signal cleanup in _exit_tree()

	# 4. Clear references
	hex_coord = null
	stats = null
	_current_building = null
	_target_building = null

	# 5. Remove from groups
	remove_from_group("animals")

	# 6. Queue for deletion
	queue_free()

# =============================================================================
# STRING REPRESENTATION
# =============================================================================

func _to_string() -> String:
	if stats:
		return "Animal<%s at %s>" % [stats.animal_id, hex_coord]
	return "Animal<uninitialized>"
