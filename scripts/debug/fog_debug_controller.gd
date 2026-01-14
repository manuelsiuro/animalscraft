## FogDebugController - Debug tools for testing fog of war system.
## Allows manual fog reveal via mouse click and performance testing.
##
## Architecture: scripts/debug/fog_debug_controller.gd
## Parent: Child of Game node
## Story: 1-6-implement-fog-of-war
extends Node

# =============================================================================
# PROPERTIES
# =============================================================================

## Reference to WorldManager
var _world_manager: WorldManager

## Reference to FogOfWar
var _fog_of_war: FogOfWar

## Debug mode enabled flag
var _debug_mode_enabled := false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Get references from scene tree
	_world_manager = get_tree().get_first_node_in_group("world_managers")
	_fog_of_war = get_tree().get_first_node_in_group("fog_of_war")

	if _world_manager == null:
		push_warning("[FogDebugController] WorldManager not found in scene")

	if _fog_of_war == null:
		push_warning("[FogDebugController] FogOfWar not found in scene")

	# Log debug controller ready
	if is_instance_valid(GameLogger):
		GameLogger.info("FogDebugController", "Debug controller ready - Press F2 to toggle debug mode")

# =============================================================================
# INPUT HANDLING
# =============================================================================

func _input(event: InputEvent) -> void:
	# F2 toggles debug mode
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_F2:
			_toggle_debug_mode()
			get_viewport().set_input_as_handled()
			return

	# Only process mouse clicks if debug mode is enabled
	if not _debug_mode_enabled:
		return

	# Left click to reveal hex
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_debug_click(event.position)
			get_viewport().set_input_as_handled()
		# Right click for mass reveal test (AC5 performance testing)
		elif event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_test_mass_reveal()
			get_viewport().set_input_as_handled()

# =============================================================================
# DEBUG ACTIONS
# =============================================================================

## Toggle debug mode on/off.
func _toggle_debug_mode() -> void:
	_debug_mode_enabled = not _debug_mode_enabled

	var status := "ENABLED" if _debug_mode_enabled else "DISABLED"
	if is_instance_valid(GameLogger):
		GameLogger.info("FogDebugController", "Debug mode %s - Click hexes to reveal fog" % status)
	else:
		print("[FogDebugController] Debug mode %s" % status)

## Handle debug click on hex to reveal fog.
##
## @param screen_pos The screen position that was clicked
func _handle_debug_click(screen_pos: Vector2) -> void:
	if _world_manager == null or _fog_of_war == null:
		return

	# Get camera
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	# TODO (Story 1-3): Implement proper 3D screen-to-world raycasting
	# For now, use placeholder position
	var world_pos := Vector3.ZERO

	# Get hex coordinate at that position
	var hex := HexGrid.world_to_hex(world_pos)

	# Reveal the hex
	_fog_of_war.reveal_hex(hex)

	if is_instance_valid(GameLogger):
		GameLogger.debug("FogDebugController", "Debug reveal: %s" % hex.to_vector())

## Test mass fog reveal for performance (AC5).
## Reveals 20 random unexplored hexes simultaneously.
func _test_mass_reveal() -> void:
	if _world_manager == null or _fog_of_war == null:
		return

	# Collect unexplored hexes
	var center := HexCoord.new(0, 0)
	var test_hexes: Array[HexCoord] = []

	# Get hexes in range 5-10 (likely unexplored)
	for radius in range(5, 11):
		var ring := HexGrid.get_hex_ring(center, radius)
		for hex in ring:
			if test_hexes.size() >= 20:
				break
			test_hexes.append(hex)
		if test_hexes.size() >= 20:
			break

	if test_hexes.is_empty():
		if is_instance_valid(GameLogger):
			GameLogger.warn("FogDebugController", "No unexplored hexes found for mass reveal test")
		return

	# Measure performance
	var start_time := Time.get_ticks_usec()

	# Reveal all test hexes
	for hex in test_hexes:
		_fog_of_war.reveal_hex(hex)

	var end_time := Time.get_ticks_usec()
	var duration_ms := (end_time - start_time) / 1000.0

	# Log results
	if is_instance_valid(GameLogger):
		GameLogger.info("FogDebugController",
			"Mass reveal test: %d hexes revealed in %.2fms (target: < 16.67ms for 60 FPS)" % [test_hexes.size(), duration_ms])
	else:
		print("[FogDebugController] Mass reveal: %d hexes in %.2fms" % [test_hexes.size(), duration_ms])
