## BuildingGhostPreview - Visual preview during building placement.
## Shows semi-transparent building at cursor position with validity feedback.
## Temporary component, destroyed after placement completes/cancels.
##
## Architecture: scripts/entities/buildings/building_ghost_preview.gd
## Scene: scenes/entities/buildings/building_ghost_preview.tscn
## Story: 3-5-implement-building-placement-drag-and-drop
class_name BuildingGhostPreview
extends Node3D

# =============================================================================
# CONSTANTS
# =============================================================================

## Valid placement color (green, semi-transparent)
const COLOR_VALID := Color(0.0, 1.0, 0.0, 0.5)

## Invalid placement color (red, semi-transparent)
const COLOR_INVALID := Color(1.0, 0.0, 0.0, 0.5)

## Default ghost height
const DEFAULT_HEIGHT := 0.8

# =============================================================================
# NODE REFERENCES
# =============================================================================

## The visual mesh for the ghost preview
@onready var _mesh: MeshInstance3D = $MeshInstance3D

## The material applied to the mesh
var _material: StandardMaterial3D

# =============================================================================
# STATE
# =============================================================================

## The building data this preview represents
var _building_data: BuildingData

## Whether current position is valid
var _is_valid: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Setup material
	_setup_material()

	# If setup() was called before _ready(), apply deferred visual update now
	# This handles the case where setup() is called before node is in scene tree
	if _building_data:
		_update_visual_for_building(_building_data)


## Setup the preview with building data.
## @param building_data The BuildingData resource to preview
## NOTE: If called before node is in scene tree, visual update is deferred to _ready()
func setup(building_data: BuildingData) -> void:
	_building_data = building_data

	if building_data:
		# Only update visual if _mesh is available (node in scene tree)
		# Otherwise, _ready() will handle it
		if _mesh:
			_update_visual_for_building(building_data)

		if GameLogger:
			GameLogger.debug("BuildingGhostPreview", "Setup for: %s" % building_data.display_name)

# =============================================================================
# PUBLIC API
# =============================================================================

## Update the world position of the preview.
## @param world_pos The Vector3 world position to move to
func update_position(world_pos: Vector3) -> void:
	position = world_pos


## Set whether current position is valid for placement.
## Updates visual feedback (green = valid, red = invalid).
## @param is_valid Whether the position is valid
func set_valid(is_valid: bool) -> void:
	_is_valid = is_valid
	_update_validity_visual()


## Check if current position is valid.
## @return true if position is valid for placement
func is_valid() -> bool:
	return _is_valid

# =============================================================================
# VISUAL SETUP
# =============================================================================

## Setup the semi-transparent material.
func _setup_material() -> void:
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = COLOR_VALID
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	if _mesh:
		_mesh.material_override = _material


## Update visual based on building data.
## @param building_data The building data to visualize
func _update_visual_for_building(building_data: BuildingData) -> void:
	if not _mesh:
		return

	# Create mesh based on building type
	var mesh := _create_building_placeholder_mesh(building_data)
	_mesh.mesh = mesh


## Create a placeholder mesh for the building type.
## @param building_data The building data
## @return A mesh representing the building footprint
func _create_building_placeholder_mesh(building_data: BuildingData) -> Mesh:
	# Create cylinder as placeholder (similar to building visual)
	var cylinder := CylinderMesh.new()

	# Size based on building type
	match building_data.building_type:
		BuildingTypes.BuildingType.GATHERER:
			cylinder.top_radius = 0.5
			cylinder.bottom_radius = 0.5
			cylinder.height = 1.0
		BuildingTypes.BuildingType.STORAGE:
			cylinder.top_radius = 0.6
			cylinder.bottom_radius = 0.6
			cylinder.height = 0.8
		BuildingTypes.BuildingType.PROCESSOR:
			cylinder.top_radius = 0.55
			cylinder.bottom_radius = 0.55
			cylinder.height = 1.2
		_:
			cylinder.top_radius = 0.4
			cylinder.bottom_radius = 0.4
			cylinder.height = DEFAULT_HEIGHT

	return cylinder


## Update the validity visual (color change).
func _update_validity_visual() -> void:
	if not _material:
		return

	if _is_valid:
		_material.albedo_color = COLOR_VALID
	else:
		_material.albedo_color = COLOR_INVALID

# =============================================================================
# STRING REPRESENTATION
# =============================================================================

func _to_string() -> String:
	if _building_data:
		return "BuildingGhostPreview<%s, valid=%s>" % [_building_data.display_name, _is_valid]
	return "BuildingGhostPreview<uninitialized>"
