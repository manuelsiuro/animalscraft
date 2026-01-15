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
