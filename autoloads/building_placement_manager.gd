## BuildingPlacementManager - Manages building placement workflow.
## Autoload singleton - access via BuildingPlacementManager.method()
##
## Architecture: autoloads/building_placement_manager.gd
## Order: 12 (after ResourceManager, before GameManager)
## Source: game-architecture.md#Building System
## Story: 3-5-implement-building-placement-drag-and-drop
##
## Usage:
##   EventBus.building_placement_started.connect(_on_placement_started)
##   # Manager handles rest via input
##
## Flow:
##   1. BuildingMenuPanel emits building_placement_started
##   2. Manager enters placement mode, spawns ghost preview
##   3. User drags finger - ghost follows, snapping to hexes
##   4. On release: if valid hex, place building; else cancel
extends Node

# =============================================================================
# PLACEMENT STATE
# =============================================================================

## Whether placement mode is currently active
var is_placing: bool = false

## The building data for the current placement
var current_building_data: BuildingData = null

## The current preview hex coordinate (Vector2i for HexGrid compatibility)
var current_preview_hex: Vector2i = Vector2i.ZERO

## Whether current hex position is valid for placement
var _is_current_hex_valid: bool = false

## Ghost preview node reference
var _ghost_preview: Node3D = null

## Ghost preview scene
const GHOST_PREVIEW_SCENE := "res://scenes/entities/buildings/building_ghost_preview.tscn"

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Connect to EventBus placement signal (emitted by BuildingMenuPanel)
	if EventBus:
		EventBus.building_placement_started.connect(_on_building_placement_started)

	GameLogger.info("BuildingPlacementManager", "Building placement system initialized")


func _exit_tree() -> void:
	# Cleanup signal connections
	if EventBus and EventBus.building_placement_started.is_connected(_on_building_placement_started):
		EventBus.building_placement_started.disconnect(_on_building_placement_started)

	# Cleanup any active placement
	if is_placing:
		_cleanup_placement()


func _unhandled_input(event: InputEvent) -> void:
	if not is_placing:
		return

	# Handle touch/mouse input for placement
	if event is InputEventScreenTouch:
		_handle_touch_event(event as InputEventScreenTouch)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		_handle_drag_event(event as InputEventScreenDrag)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event as InputEventMouseMotion)
		get_viewport().set_input_as_handled()

# =============================================================================
# PUBLIC API
# =============================================================================

## Start placement mode with given building data.
## Called when user selects a building from the menu.
## @param building_data The BuildingData resource to place
func start_placement(building_data: BuildingData) -> void:
	if is_placing:
		GameLogger.warn("BuildingPlacementManager", "Already in placement mode, cancelling previous")
		cancel_placement()

	if not building_data:
		GameLogger.error("BuildingPlacementManager", "Cannot start placement with null building data")
		return

	current_building_data = building_data
	is_placing = true
	_is_current_hex_valid = false

	# Spawn ghost preview
	_spawn_ghost_preview()

	GameLogger.info("BuildingPlacementManager", "Started placement mode for: %s" % building_data.display_name)


## Cancel the current placement and cleanup.
## Resources are NOT deducted on cancellation.
func cancel_placement() -> void:
	if not is_placing:
		return

	GameLogger.info("BuildingPlacementManager", "Placement cancelled for: %s" % (current_building_data.display_name if current_building_data else "unknown"))

	_cleanup_placement()

	# Emit placement ended signal (not placed)
	if EventBus:
		EventBus.building_placement_ended.emit(false)


## Confirm placement at current location.
## Only succeeds if current hex is valid.
## @return true if placement succeeded
func confirm_placement() -> bool:
	if not is_placing:
		GameLogger.warn("BuildingPlacementManager", "Cannot confirm - not in placement mode")
		return false

	if not _is_current_hex_valid:
		GameLogger.debug("BuildingPlacementManager", "Cannot confirm - current hex is invalid")
		cancel_placement()
		return false

	# Place the building
	var success := _place_building()

	if success:
		GameLogger.info("BuildingPlacementManager", "Building placed: %s at %s" % [current_building_data.display_name, current_preview_hex])
	else:
		GameLogger.warn("BuildingPlacementManager", "Placement failed for: %s" % current_building_data.display_name)
		cancel_placement()

	return success

# =============================================================================
# INPUT HANDLERS
# =============================================================================

func _handle_touch_event(event: InputEventScreenTouch) -> void:
	if event.pressed:
		# Touch started - update position
		_update_ghost_position(event.position)
	else:
		# Touch released - try to place or cancel
		_on_placement_release()


func _handle_drag_event(event: InputEventScreenDrag) -> void:
	# Update ghost position as finger drags
	_update_ghost_position(event.position)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		# Mouse pressed - update position
		_update_ghost_position(event.position)
	else:
		# Mouse released - try to place or cancel
		_on_placement_release()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	# Update ghost position during mouse movement (when button held)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_ghost_position(event.position)

# =============================================================================
# POSITION AND VALIDITY
# =============================================================================

## Update ghost preview position based on screen coordinates.
## @param screen_pos The screen position from input event
func _update_ghost_position(screen_pos: Vector2) -> void:
	if not _ghost_preview:
		return

	# Convert screen position to world position
	var world_pos := _screen_to_world(screen_pos)
	if world_pos == Vector3.ZERO:
		# Failed to convert (no valid intersection)
		return

	# Convert world position to hex coordinate
	var hex := HexGrid.world_to_hex(world_pos)
	var hex_vec := hex.to_vector()

	# Skip update if same hex
	if hex_vec == current_preview_hex and _ghost_preview.visible:
		return

	current_preview_hex = hex_vec

	# Snap ghost to hex center
	var snapped_pos := HexGrid.hex_to_world(hex)
	_ghost_preview.position = snapped_pos
	_ghost_preview.visible = true

	# Check validity and update visual
	_is_current_hex_valid = is_placement_valid(hex_vec, current_building_data)
	_update_ghost_validity(_is_current_hex_valid)


## Convert screen position to world position via camera raycast.
## @param screen_pos The screen position to convert
## @return World position on ground plane, or Vector3.ZERO if no intersection
func _screen_to_world(screen_pos: Vector2) -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return Vector3.ZERO

	var from := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)

	# Intersect with ground plane (Y=0)
	var plane := Plane(Vector3.UP, 0.0)
	var intersection = plane.intersects_ray(from, dir)

	if intersection:
		return intersection
	return Vector3.ZERO


## Check if placement is valid at given hex coordinate.
## @param hex_coord The Vector2i hex coordinate to check
## @param building_data The building data to validate
## @return true if placement is valid
func is_placement_valid(hex_coord: Vector2i, building_data: BuildingData) -> bool:
	if not building_data:
		return false

	# Create HexCoord for lookups
	var hex := HexCoord.from_vector(hex_coord)

	# Check if hex exists in world
	var world_managers := get_tree().get_nodes_in_group("world_managers")
	if world_managers.is_empty():
		GameLogger.warn("BuildingPlacementManager", "No WorldManager found")
		return false

	var world_manager: WorldManager = world_managers[0] as WorldManager
	if not world_manager:
		return false

	var tile := world_manager.get_tile_at(hex)
	if not tile:
		GameLogger.debug("BuildingPlacementManager", "No tile at hex %s" % hex_coord)
		return false

	# Check terrain is not water (TerrainType.WATER = 1)
	if tile.terrain_type == HexTile.TerrainType.WATER:
		GameLogger.debug("BuildingPlacementManager", "Cannot build on water at %s" % hex_coord)
		return false

	# Check hex is not occupied
	if HexGrid.is_hex_occupied(hex_coord):
		GameLogger.debug("BuildingPlacementManager", "Hex occupied at %s" % hex_coord)
		return false

	# Check territory is claimed (TerritoryState.CLAIMED = 3)
	var territory_manager := world_manager.get_territory_manager()
	if territory_manager:
		var state := territory_manager.get_territory_state(hex)
		if state != TerritoryManager.TerritoryState.CLAIMED:
			GameLogger.debug("BuildingPlacementManager", "Hex not claimed at %s (state: %d)" % [hex_coord, state])
			return false

	# Check player can afford building
	if not _can_afford(building_data):
		GameLogger.debug("BuildingPlacementManager", "Cannot afford %s" % building_data.display_name)
		return false

	return true


## Check if player can afford the building cost.
## @param building_data The building to check
## @return true if player has sufficient resources
func _can_afford(building_data: BuildingData) -> bool:
	if not building_data:
		return false

	var costs: Dictionary = building_data.build_cost
	if costs.is_empty():
		return true

	for resource_id in costs:
		var required: int = costs[resource_id]
		if not ResourceManager.has_resource(resource_id, required):
			return false

	return true

# =============================================================================
# GHOST PREVIEW
# =============================================================================

## Spawn the ghost preview node.
func _spawn_ghost_preview() -> void:
	if _ghost_preview:
		_ghost_preview.queue_free()

	# Try to load and instantiate the ghost preview scene
	if ResourceLoader.exists(GHOST_PREVIEW_SCENE):
		var scene := load(GHOST_PREVIEW_SCENE) as PackedScene
		if scene:
			_ghost_preview = scene.instantiate()
			# Setup with building data
			if _ghost_preview.has_method("setup"):
				_ghost_preview.call("setup", current_building_data)
			# Add to scene tree
			get_tree().current_scene.add_child(_ghost_preview)
			_ghost_preview.visible = false  # Hidden until first position update
			return

	# Fallback: Create simple placeholder ghost
	_ghost_preview = _create_fallback_ghost()
	get_tree().current_scene.add_child(_ghost_preview)
	_ghost_preview.visible = false


## Create a fallback ghost preview if scene not found.
## @return A simple placeholder Node3D
func _create_fallback_ghost() -> Node3D:
	var ghost := Node3D.new()
	ghost.name = "BuildingGhostPreview"

	# Create visual mesh
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"

	# Create placeholder cylinder mesh
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.4
	cylinder.bottom_radius = 0.4
	cylinder.height = 0.8
	mesh_instance.mesh = cylinder

	# Create semi-transparent material
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.0, 1.0, 0.0, 0.5)  # Green, 50% alpha
	mesh_instance.material_override = material

	# Position cylinder above ground
	mesh_instance.position.y = 0.4

	ghost.add_child(mesh_instance)

	# Store material reference for validity updates
	ghost.set_meta("material", material)

	return ghost


## Update ghost preview validity visual (green/red tint).
## @param is_valid Whether the current position is valid
func _update_ghost_validity(is_valid: bool) -> void:
	if not _ghost_preview:
		return

	# If ghost has set_valid method, use it
	if _ghost_preview.has_method("set_valid"):
		_ghost_preview.call("set_valid", is_valid)
		return

	# Fallback: Update material color directly
	var material = _ghost_preview.get_meta("material") if _ghost_preview.has_meta("material") else null
	if material:
		if is_valid:
			material.albedo_color = Color(0.0, 1.0, 0.0, 0.5)  # Green
		else:
			material.albedo_color = Color(1.0, 0.0, 0.0, 0.5)  # Red

# =============================================================================
# PLACEMENT EXECUTION
# =============================================================================

## Handle release event - confirm or cancel placement.
func _on_placement_release() -> void:
	if _is_current_hex_valid:
		confirm_placement()
	else:
		cancel_placement()


## Place the building at the current location.
## Deducts resources and emits signals.
## @return true if placement succeeded
func _place_building() -> bool:
	if not current_building_data:
		return false

	# Deduct resources
	var costs: Dictionary = current_building_data.build_cost
	for resource_id in costs:
		var amount: int = costs[resource_id]
		ResourceManager.remove_resource(resource_id, amount)

	# Create and place building
	var building := _instantiate_building()
	if not building:
		# Refund resources on failure
		for resource_id in costs:
			var amount: int = costs[resource_id]
			ResourceManager.add_resource(resource_id, amount)
		return false

	# Initialize and add to world
	var hex := HexCoord.from_vector(current_preview_hex)
	building.initialize(hex, current_building_data)

	# Add to world
	var world_managers := get_tree().get_nodes_in_group("world_managers")
	if not world_managers.is_empty():
		var world_manager: WorldManager = world_managers[0] as WorldManager
		if world_manager:
			# Add building as child of world
			world_manager.add_child(building)
	else:
		# Fallback: add to current scene
		get_tree().current_scene.add_child(building)

	# Emit building_placed signal
	if EventBus:
		EventBus.building_placed.emit(building, current_preview_hex)

	# Cleanup placement state
	_cleanup_placement()

	# Emit placement ended signal (placed successfully)
	if EventBus:
		EventBus.building_placement_ended.emit(true)

	return true


## Instantiate a building node from the building data.
## @return The building node, or null if failed
func _instantiate_building() -> Building:
	# Load building scene
	var scene_path := "res://scenes/entities/buildings/building.tscn"

	if not ResourceLoader.exists(scene_path):
		GameLogger.error("BuildingPlacementManager", "Building scene not found: %s" % scene_path)
		return null

	var scene := load(scene_path) as PackedScene
	if not scene:
		GameLogger.error("BuildingPlacementManager", "Failed to load building scene: %s" % scene_path)
		return null

	var building := scene.instantiate() as Building
	if not building:
		GameLogger.error("BuildingPlacementManager", "Failed to instantiate building")
		return null

	return building

# =============================================================================
# CLEANUP
# =============================================================================

## Cleanup placement state and ghost preview.
func _cleanup_placement() -> void:
	is_placing = false
	current_building_data = null
	current_preview_hex = Vector2i.ZERO
	_is_current_hex_valid = false

	# Remove ghost preview
	if _ghost_preview and is_instance_valid(_ghost_preview):
		_ghost_preview.queue_free()
		_ghost_preview = null

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

## Handle building_placement_started signal from BuildingMenuPanel.
## @param building_data The BuildingData resource to place
func _on_building_placement_started(building_data: Resource) -> void:
	if building_data is BuildingData:
		start_placement(building_data as BuildingData)
	else:
		GameLogger.warn("BuildingPlacementManager", "Invalid building_data type received")
