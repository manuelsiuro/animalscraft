## Unit tests for HexTile territory state visuals
## Tests territory state transitions, visual updates, and animations.
##
## Story: 1-5-display-territory-states
extends GutTest

# =============================================================================
# TEST SETUP
# =============================================================================

const HEX_TILE_SCENE := preload("res://scenes/world/hex_tile.tscn")

var hex_tile: HexTile

func before_each() -> void:
	hex_tile = HEX_TILE_SCENE.instantiate()
	add_child(hex_tile)
	await wait_frames(1)  # Wait for _ready() to complete
	hex_tile.initialize(HexCoord.new(0, 0), HexTile.TerrainType.GRASS)

func after_each() -> void:
	if hex_tile:
		hex_tile.queue_free()

# =============================================================================
# SETUP TESTS
# =============================================================================

func test_fog_mesh_exists() -> void:
	assert_not_null(hex_tile.fog_mesh, "Fog overlay should exist")

func test_border_mesh_exists() -> void:
	assert_not_null(hex_tile.border_mesh, "Border polygon should exist")

func test_initial_territory_state_is_uninitialized() -> void:
	assert_eq(hex_tile.territory_state, -1, "Initial state should be uninitialized (-1)")

func test_initial_fog_mesh_is_hidden() -> void:
	assert_false(hex_tile.fog_mesh.visible, "Fog should be initially hidden")

func test_initial_border_is_transparent() -> void:
	var _mat := hex_tile.border_mesh.get_surface_override_material(0)
	assert_not_null(_mat, "Material should exist for hex_tile.border_mesh")
	assert_eq(_mat.albedo_color.a, 0.0, "Border should be initially transparent")

# =============================================================================
# STATE TRANSITION TESTS
# =============================================================================

func test_set_territory_state_unexplored() -> void:
	hex_tile.set_territory_state(0)  # UNEXPLORED
	assert_eq(hex_tile.territory_state, 0, "State should be UNEXPLORED")
	# Fog should be visible after transition starts
	assert_true(hex_tile.fog_mesh.visible, "Fog should be visible for unexplored")

func test_set_territory_state_scouted() -> void:
	# First set to unexplored
	hex_tile.set_territory_state(0)  # UNEXPLORED
	# Wait for tween to complete
	if hex_tile._tween:
		await hex_tile._tween.finished

	# Now scout
	hex_tile.set_territory_state(1)  # SCOUTED
	# Wait for tween to complete
	if hex_tile._tween:
		await hex_tile._tween.finished

	assert_eq(hex_tile.territory_state, 1, "State should be SCOUTED")
	assert_false(hex_tile.fog_mesh.visible, "Fog should be hidden for scouted")

func test_set_territory_state_claimed() -> void:
	hex_tile.set_territory_state(3)  # CLAIMED
	# Wait for tween to complete
	if hex_tile._tween:
		await hex_tile._tween.finished

	assert_eq(hex_tile.territory_state, 3, "State should be CLAIMED")
	var _mat := hex_tile.border_mesh.get_surface_override_material(0)
	assert_not_null(_mat, "Material should exist for hex_tile.border_mesh")
	assert_eq(_mat.albedo_color, hex_tile.COLOR_CLAIMED, "Border should be player color")

func test_set_territory_state_contested() -> void:
	hex_tile.set_territory_state(2)  # CONTESTED
	# Wait for tween to complete
	if hex_tile._tween:
		await hex_tile._tween.finished

	assert_eq(hex_tile.territory_state, 2, "State should be CONTESTED")
	var _mat := hex_tile.border_mesh.get_surface_override_material(0)
	assert_not_null(_mat, "Material should exist for hex_tile.border_mesh")
	assert_eq(_mat.albedo_color, hex_tile.COLOR_CONTESTED, "Border should be red")

func test_set_territory_state_neglected() -> void:
	hex_tile.set_territory_state(4)  # NEGLECTED
	# Wait for tween to complete
	if hex_tile._tween:
		await hex_tile._tween.finished

	assert_eq(hex_tile.territory_state, 4, "State should be NEGLECTED")
	var _mat := hex_tile.border_mesh.get_surface_override_material(0)
	assert_not_null(_mat, "Material should exist for hex_tile.border_mesh")
	assert_eq(_mat.albedo_color, hex_tile.COLOR_NEGLECTED, "Border should be gray")

# =============================================================================
# ANIMATION TESTS
# =============================================================================

func test_state_transition_uses_tween() -> void:
	hex_tile.set_territory_state(3)  # CLAIMED
	# Tween should be created
	assert_not_null(hex_tile._tween, "Tween should be created")
	assert_true(hex_tile._tween.is_running(), "Tween should be running")

func test_rapid_state_changes_cancel_previous_tween() -> void:
	hex_tile.set_territory_state(3)  # CLAIMED
	var first_tween := hex_tile._tween
	assert_true(first_tween.is_running(), "First tween should be running")

	# Immediately change state again
	hex_tile.set_territory_state(2)  # CONTESTED
	var second_tween := hex_tile._tween

	# First tween should be killed
	assert_false(first_tween.is_running(), "First tween should be killed")
	# Second tween should be running
	assert_true(second_tween.is_running(), "Second tween should be running")

func test_state_transition_duration() -> void:
	var start_time := Time.get_ticks_msec()
	hex_tile.set_territory_state(3)  # CLAIMED

	# Wait for tween to complete
	if hex_tile._tween:
		await hex_tile._tween.finished

	var end_time := Time.get_ticks_msec()
	var duration := (end_time - start_time) / 1000.0

	# Duration should be approximately STATE_TRANSITION_DURATION (0.4s)
	assert_between(duration, 0.3, 0.6, "Transition should take ~0.4 seconds")

# =============================================================================
# VISUAL STATE TESTS
# =============================================================================

func test_unexplored_has_fog() -> void:
	hex_tile.set_territory_state(0)  # UNEXPLORED
	assert_true(hex_tile.fog_mesh.visible, "Unexplored should have fog")

func test_scouted_has_desaturated_terrain() -> void:
	hex_tile.set_territory_state(1)  # SCOUTED
	# Wait for tween to complete
	if hex_tile._tween:
		await hex_tile._tween.finished

	# Terrain should be desaturated (modulate applied)
	# We can check if modulate is not white (default)
	var _mat := hex_tile.mesh_instance.get_surface_override_material(0)
	assert_not_null(_mat, "Material should exist for hex_tile.mesh_instance")
	assert_ne(_mat.albedo_color, Color.WHITE, "Scouted terrain should be desaturated")

func test_claimed_has_player_color_border() -> void:
	hex_tile.set_territory_state(3)  # CLAIMED
	if hex_tile._tween:
		await hex_tile._tween.finished

	var _mat := hex_tile.border_mesh.get_surface_override_material(0)
	assert_not_null(_mat, "Material should exist for hex_tile.border_mesh")
	assert_eq(_mat.albedo_color, hex_tile.COLOR_CLAIMED, "Claimed should have player color border")

func test_contested_has_red_border() -> void:
	hex_tile.set_territory_state(2)  # CONTESTED
	if hex_tile._tween:
		await hex_tile._tween.finished

	var _mat := hex_tile.border_mesh.get_surface_override_material(0)
	assert_not_null(_mat, "Material should exist for hex_tile.border_mesh")
	assert_eq(_mat.albedo_color, hex_tile.COLOR_CONTESTED, "Contested should have red border")

# =============================================================================
# EDGE CASE TESTS
# =============================================================================

func test_set_same_state_does_not_retween() -> void:
	hex_tile.set_territory_state(3)  # CLAIMED
	if hex_tile._tween:
		await hex_tile._tween.finished

	# Set same state again
	var tween_before := hex_tile._tween
	hex_tile.set_territory_state(3)  # CLAIMED again

	# Should not create new tween
	assert_eq(hex_tile._tween, tween_before, "Should not create new tween for same state")

func test_multiple_terrain_types_maintain_colors() -> void:
	# Test with different terrain types
	var terrain_types := [HexTile.TerrainType.GRASS, HexTile.TerrainType.WATER, HexTile.TerrainType.ROCK]

	for terrain in terrain_types:
		if hex_tile:
			hex_tile.queue_free()

		hex_tile = HEX_TILE_SCENE.instantiate()
		add_child(hex_tile)
		hex_tile.initialize(HexCoord.new(0, 0), terrain)

		hex_tile.set_territory_state(3)  # CLAIMED
		if hex_tile._tween:
			await hex_tile._tween.finished

		# Border should still be player color regardless of terrain
		var _mat := hex_tile.border_mesh.get_surface_override_material(0)
		assert_not_null(_mat, "Material should exist for hex_tile.border_mesh")
		assert_eq(_mat.albedo_color, hex_tile.COLOR_CLAIMED, "Border color should be consistent across terrain types")

# =============================================================================
# PERFORMANCE TESTS (AC6)
# =============================================================================

func test_many_simultaneous_state_changes() -> void:
	# AC6: Multiple state changes can happen simultaneously
	# Test that 50+ tiles changing state at once maintains 60 FPS
	var tiles: Array[HexTile] = []
	var tile_count := 50

	# Create 50 tiles
	for i in range(tile_count):
		var tile := HEX_TILE_SCENE.instantiate()
		add_child(tile)
		tile.initialize(HexCoord.new(i, 0), HexTile.TerrainType.GRASS)
		tiles.append(tile)

	# Measure frame time while changing all states simultaneously
	var start_time := Time.get_ticks_usec()

	# Change all tiles to CLAIMED at once
	for tile in tiles:
		tile.set_territory_state(3)  # CLAIMED

	var end_time := Time.get_ticks_usec()
	var duration_ms := (end_time - start_time) / 1000.0

	# Should complete state change initiation in < 16.67ms (60 FPS)
	assert_lt(duration_ms, 16.67, "50 simultaneous state changes should complete in < 16.67ms for 60 FPS")

	# Wait for all tweens to complete
	for tile in tiles:
		if tile._tween:
			await tile._tween.finished

	# Verify all tiles changed state
	for tile in tiles:
		assert_eq(tile.territory_state, 3, "All tiles should be CLAIMED")

	# Cleanup
	for tile in tiles:
		tile.queue_free()

# =============================================================================
# HELPER FUNCTION TESTS
# =============================================================================

func test_desaturate_color() -> void:
	var original := Color("#7CBA5F")
	var desaturated := hex_tile._desaturate_color(original, 0.5)

	# Saturation should be reduced (Godot 4 has direct h, s, v properties)
	assert_lt(desaturated.s, original.s, "Saturation should be reduced")

func test_get_terrain_color() -> void:
	var grass_color := hex_tile._get_terrain_color(HexTile.TerrainType.GRASS)
	assert_eq(grass_color, Color("#7CBA5F"), "Should return grass color")

	var water_color := hex_tile._get_terrain_color(HexTile.TerrainType.WATER)
	assert_eq(water_color, Color("#4A90C2"), "Should return water color")

	var rock_color := hex_tile._get_terrain_color(HexTile.TerrainType.ROCK)
	assert_eq(rock_color, Color("#8B8B83"), "Should return rock color")
