## BuildingGhostPreview - Visual preview during building placement.
## Shows semi-transparent building at cursor position with validity feedback.
## Temporary component, destroyed after placement completes/cancels.
##
## Architecture: scripts/entities/buildings/building_ghost_preview.gd
## Scene: scenes/entities/buildings/building_ghost_preview.tscn
## Story: 3-5-implement-building-placement-drag-and-drop, 3-6-display-placement-validity-indicators
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

## Icon colors for colorblind accessibility (distinct shapes + colors)
## Story: 3-6-display-placement-validity-indicators
const ICON_COLOR_VALID := Color(0.2, 0.8, 0.2)    # Green checkmark
const ICON_COLOR_WATER := Color(0.3, 0.6, 0.9)    # Blue droplet
const ICON_COLOR_OCCUPIED := Color(0.9, 0.3, 0.3) # Red lock
const ICON_COLOR_UNCLAIMED := Color(0.6, 0.6, 0.6) # Gray flag
const ICON_COLOR_TERRAIN := Color(0.9, 0.7, 0.2)  # Orange warning
const ICON_COLOR_AFFORD := Color(0.9, 0.8, 0.2)   # Yellow coin

## Icon size for validity indicators
const ICON_SIZE := 32

# =============================================================================
# NODE REFERENCES
# =============================================================================

## The visual mesh for the ghost preview
@onready var _mesh: MeshInstance3D = $MeshInstance3D

## The validity icon sprite (Story 3-6)
var _validity_icon: Sprite3D = null

## The material applied to the mesh
var _material: StandardMaterial3D

## Animation player for pulse/glow effects (Story 3-6)
var _animation_player: AnimationPlayer = null

## Tween for glow effect
var _glow_tween: Tween = null

## Tween for pulse effect
var _pulse_tween: Tween = null

# =============================================================================
# PRE-CACHED ICON TEXTURES (Story 3-6)
# =============================================================================

## Pre-cached icon textures to avoid lazy-load hitches during drag
var _icon_valid: ImageTexture = null
var _icon_water: ImageTexture = null
var _icon_occupied: ImageTexture = null
var _icon_unclaimed: ImageTexture = null
var _icon_terrain: ImageTexture = null
var _icon_afford: ImageTexture = null

# =============================================================================
# STATE
# =============================================================================

## The building data this preview represents
var _building_data: BuildingData

## Whether current position is valid
var _is_valid: bool = false

## Current invalidity reason (Story 3-6)
## NOTE: Typed as int (not InvalidityReason enum) because the enum is defined in
## BuildingPlacementManager autoload. GDScript cross-file enum access is awkward,
## and using int provides cleaner API for set_invalidity_reason(reason: int).
## Values: NONE=0, WATER=1, OCCUPIED=2, UNCLAIMED=3, TERRAIN_INCOMPATIBLE=4, CANNOT_AFFORD=5
var _current_reason: int = 0  # InvalidityReason.NONE

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Setup material
	_setup_material()

	# Pre-cache icon textures for 60fps performance (Story 3-6)
	_precache_icon_textures()

	# Setup validity icon sprite (Story 3-6)
	_setup_validity_icon()

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
# VALIDITY ICON SYSTEM (Story 3-6)
# =============================================================================

## Pre-cache all icon textures in _ready() to avoid lazy-load hitches.
## CRITICAL: Must complete before any placement interaction for 60fps.
## Story 3-6 Code Review: Added null checks for defensive error handling.
func _precache_icon_textures() -> void:
	_icon_valid = _create_icon_texture(ICON_COLOR_VALID, "checkmark")
	_icon_water = _create_icon_texture(ICON_COLOR_WATER, "droplet")
	_icon_occupied = _create_icon_texture(ICON_COLOR_OCCUPIED, "lock")
	_icon_unclaimed = _create_icon_texture(ICON_COLOR_UNCLAIMED, "flag")
	_icon_terrain = _create_icon_texture(ICON_COLOR_TERRAIN, "warning")
	_icon_afford = _create_icon_texture(ICON_COLOR_AFFORD, "coin_x")

	# Defensive null checks - log errors if icon creation failed
	var icons := {
		"valid": _icon_valid, "water": _icon_water, "occupied": _icon_occupied,
		"unclaimed": _icon_unclaimed, "terrain": _icon_terrain, "afford": _icon_afford
	}
	for icon_name in icons:
		if not icons[icon_name]:
			if GameLogger:
				GameLogger.error("BuildingGhostPreview", "Failed to create %s icon texture" % icon_name)


## Create a procedural icon texture with distinct shape for colorblind accessibility.
## @param color The icon color
## @param shape The shape type: checkmark, droplet, lock, flag, warning, coin_x
## @return The generated ImageTexture
func _create_icon_texture(color: Color, shape: String) -> ImageTexture:
	var img := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)

	# Draw distinct shapes for colorblind accessibility
	match shape:
		"checkmark":
			_draw_checkmark(img, color)
		"droplet":
			_draw_droplet(img, color)
		"lock":
			_draw_lock(img, color)
		"flag":
			_draw_flag(img, color)
		"warning":
			_draw_warning_triangle(img, color)
		"coin_x":
			_draw_coin_x(img, color)

	var texture := ImageTexture.create_from_image(img)
	return texture


## Draw a checkmark shape (V-shaped tick)
func _draw_checkmark(img: Image, color: Color) -> void:
	var cx := ICON_SIZE / 2
	var cy := ICON_SIZE / 2

	# Draw V-shaped checkmark
	for i in range(8):
		# Left diagonal up
		_draw_pixel_safe(img, cx - 8 + i, cy + i - 2, color)
		_draw_pixel_safe(img, cx - 8 + i + 1, cy + i - 2, color)
		# Right diagonal down (longer)
		if i < 12:
			_draw_pixel_safe(img, cx - 2 + i, cy + 4 - i, color)
			_draw_pixel_safe(img, cx - 2 + i + 1, cy + 4 - i, color)


## Draw a water droplet shape (teardrop)
func _draw_droplet(img: Image, color: Color) -> void:
	var cx := ICON_SIZE / 2
	var cy := ICON_SIZE / 2

	# Draw teardrop shape
	for y in range(ICON_SIZE):
		for x in range(ICON_SIZE):
			var dx := float(x - cx)
			var dy := float(y - cy - 4)

			# Bottom circle
			if dy > 0:
				var dist := sqrt(dx * dx + dy * dy)
				if dist < 10:
					_draw_pixel_safe(img, x, y, color)
			# Top point (inverted triangle)
			elif dy > -12:
				var width := 10.0 * (1.0 + dy / 12.0)
				if abs(dx) < width:
					_draw_pixel_safe(img, x, y, color)


## Draw a padlock shape
func _draw_lock(img: Image, color: Color) -> void:
	var cx := ICON_SIZE / 2
	var cy := ICON_SIZE / 2

	# Draw body (rectangle)
	for y in range(cy - 2, cy + 8):
		for x in range(cx - 7, cx + 7):
			_draw_pixel_safe(img, x, y, color)

	# Draw shackle (arc at top)
	for angle in range(0, 180, 10):
		var rad := deg_to_rad(float(angle))
		var rx := int(cos(rad) * 5)
		var ry := int(-sin(rad) * 7)
		_draw_pixel_safe(img, cx + rx, cy - 4 + ry, color)
		_draw_pixel_safe(img, cx + rx + 1, cy - 4 + ry, color)


## Draw a flag on pole shape
func _draw_flag(img: Image, color: Color) -> void:
	var cx := ICON_SIZE / 2

	# Draw pole
	for y in range(4, ICON_SIZE - 4):
		_draw_pixel_safe(img, cx - 6, y, color)
		_draw_pixel_safe(img, cx - 5, y, color)

	# Draw flag rectangle
	for y in range(4, 16):
		for x in range(cx - 4, cx + 10):
			_draw_pixel_safe(img, x, y, color)


## Draw a warning triangle with exclamation
func _draw_warning_triangle(img: Image, color: Color) -> void:
	var cx := ICON_SIZE / 2
	var cy := ICON_SIZE / 2

	# Draw triangle outline
	for y in range(ICON_SIZE):
		var row_from_top := y - 4
		if row_from_top >= 0 and row_from_top < 22:
			var half_width := int(row_from_top * 0.6)
			_draw_pixel_safe(img, cx - half_width, y, color)
			_draw_pixel_safe(img, cx + half_width, y, color)
			if row_from_top == 21:
				for x in range(cx - half_width, cx + half_width + 1):
					_draw_pixel_safe(img, x, y, color)

	# Draw exclamation mark
	for y in range(10, 18):
		_draw_pixel_safe(img, cx, y, Color.WHITE)
		_draw_pixel_safe(img, cx + 1, y, Color.WHITE)
	# Dot
	_draw_pixel_safe(img, cx, 21, Color.WHITE)
	_draw_pixel_safe(img, cx + 1, 21, Color.WHITE)


## Draw a coin with X overlay
func _draw_coin_x(img: Image, color: Color) -> void:
	var cx := ICON_SIZE / 2
	var cy := ICON_SIZE / 2

	# Draw circle (coin)
	for y in range(ICON_SIZE):
		for x in range(ICON_SIZE):
			var dx := float(x - cx)
			var dy := float(y - cy)
			var dist := sqrt(dx * dx + dy * dy)
			if dist < 12 and dist > 9:
				_draw_pixel_safe(img, x, y, color)
			elif dist <= 9:
				_draw_pixel_safe(img, x, y, color.darkened(0.2))

	# Draw X overlay
	for i in range(-6, 7):
		_draw_pixel_safe(img, cx + i, cy + i, Color.RED)
		_draw_pixel_safe(img, cx + i + 1, cy + i, Color.RED)
		_draw_pixel_safe(img, cx + i, cy - i, Color.RED)
		_draw_pixel_safe(img, cx + i + 1, cy - i, Color.RED)


## Safely draw a pixel with bounds checking
func _draw_pixel_safe(img: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, color)


## Setup the validity icon Sprite3D with billboard mode.
func _setup_validity_icon() -> void:
	_validity_icon = Sprite3D.new()
	_validity_icon.name = "ValidityIcon"

	# Billboard mode - always faces camera
	_validity_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	# Position above the ghost (visual hierarchy with 50% alpha ghost)
	_validity_icon.position = Vector3(0, 1.2, 0)

	# Scale for visibility
	_validity_icon.pixel_size = 0.02

	# Start hidden until reason is set
	_validity_icon.visible = false

	# Rendering settings for proper transparency
	_validity_icon.no_depth_test = true
	_validity_icon.render_priority = 1

	add_child(_validity_icon)


## Set invalidity reason with accessibility checks.
## Story: 3-6-display-placement-validity-indicators
## @param reason The InvalidityReason value from BuildingPlacementManager
func set_invalidity_reason(reason: int) -> void:
	var was_valid := _is_valid
	_is_valid = (reason == 0)  # InvalidityReason.NONE = 0
	_current_reason = reason

	_update_validity_visual()
	_update_validity_icon()
	_update_animations(was_valid)


## Update the validity icon based on current reason.
func _update_validity_icon() -> void:
	if not _validity_icon:
		return

	# Match reason to pre-cached texture
	# InvalidityReason enum: NONE=0, WATER=1, OCCUPIED=2, UNCLAIMED=3, TERRAIN_INCOMPATIBLE=4, CANNOT_AFFORD=5
	var texture: ImageTexture = null

	match _current_reason:
		0:  # NONE - valid
			texture = _icon_valid
		1:  # WATER
			texture = _icon_water
		2:  # OCCUPIED
			texture = _icon_occupied
		3:  # UNCLAIMED
			texture = _icon_unclaimed
		4:  # TERRAIN_INCOMPATIBLE
			texture = _icon_terrain
		5:  # CANNOT_AFFORD
			texture = _icon_afford
		_:
			texture = _icon_occupied  # Default fallback

	if texture:
		_validity_icon.texture = texture
		_validity_icon.visible = true
	else:
		_validity_icon.visible = false


## Update animations based on validity state (Story 3-6).
## Respects reduced motion accessibility setting (NFR13).
func _update_animations(was_valid: bool) -> void:
	# Check reduced motion setting
	var reduced_motion := false
	if Settings:
		reduced_motion = Settings.is_reduce_motion_enabled()

	if _is_valid:
		_stop_pulse_animation()
		if not reduced_motion:
			_start_glow_effect()
		else:
			_stop_glow_effect()
	else:
		_stop_glow_effect()
		if not reduced_motion:
			_start_pulse_animation()
		else:
			_stop_pulse_animation()
			# Reset scale for static invalid indicator
			scale = Vector3.ONE


## Start subtle glow effect for valid placement (Story 3-6).
func _start_glow_effect() -> void:
	_stop_glow_effect()

	if not _material:
		return

	# Subtle emission pulse for "YES HERE!" feeling
	_glow_tween = create_tween()
	_glow_tween.set_loops()
	_glow_tween.tween_property(_material, "emission_energy_multiplier", 0.3, 0.5)
	_glow_tween.tween_property(_material, "emission_energy_multiplier", 0.1, 0.5)

	# Enable emission
	_material.emission_enabled = true
	_material.emission = COLOR_VALID


## Stop glow effect.
func _stop_glow_effect() -> void:
	if _glow_tween and _glow_tween.is_running():
		_glow_tween.kill()
		_glow_tween = null

	if _material:
		_material.emission_enabled = false


## Start subtle pulse animation for invalid placement (Story 3-6).
## Scale 1.0 -> 1.05 -> 1.0, 0.5s loop
func _start_pulse_animation() -> void:
	_stop_pulse_animation()

	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(self, "scale", Vector3(1.05, 1.05, 1.05), 0.25)
	_pulse_tween.tween_property(self, "scale", Vector3.ONE, 0.25)


## Stop pulse animation and reset scale.
func _stop_pulse_animation() -> void:
	if _pulse_tween and _pulse_tween.is_running():
		_pulse_tween.kill()
		_pulse_tween = null

	# Reset scale to avoid phantom animation artifacts
	scale = Vector3.ONE


## Get the current invalidity reason.
## @return The current reason value
func get_invalidity_reason() -> int:
	return _current_reason

# =============================================================================
# STRING REPRESENTATION
# =============================================================================

func _to_string() -> String:
	if _building_data:
		return "BuildingGhostPreview<%s, valid=%s>" % [_building_data.display_name, _is_valid]
	return "BuildingGhostPreview<uninitialized>"
