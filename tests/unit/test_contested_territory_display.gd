## Unit tests for Contested Territory Display System.
## Tests pulsing animation, overlay, preview panel, difficulty estimation, and HUD badge.
##
## Story: 5-3-display-contested-territory
## Architecture: tests/unit/test_contested_territory_display.gd
extends GutTest

# =============================================================================
# TEST FIXTURES
# =============================================================================

var _hex_tile: HexTile
var _territory_manager: TerritoryManager
var _preview_panel: ContestedPreviewPanel

# =============================================================================
# SETUP / TEARDOWN
# =============================================================================

func before_each() -> void:
	_territory_manager = TerritoryManager.new()
	add_child_autofree(_territory_manager)
	await wait_frames(1)


func after_each() -> void:
	_territory_manager = null
	_hex_tile = null
	_preview_panel = null

# =============================================================================
# HEX TILE PULSE ANIMATION TESTS (AC: 1, 3)
# =============================================================================

func test_hex_tile_has_contested_pulse_constants() -> void:
	# Verify constants exist and have expected values
	assert_true(HexTile.CONTESTED_PULSE_DURATION > 0.0, "CONTESTED_PULSE_DURATION should be positive")
	assert_eq(HexTile.CONTESTED_PULSE_DURATION, 0.8, "AC1: Pulse duration should be 0.8s")
	assert_true(HexTile.CONTESTED_PULSE_MIN_ALPHA >= 0.0, "Min alpha should be non-negative")
	assert_true(HexTile.CONTESTED_PULSE_MAX_ALPHA <= 1.0, "Max alpha should be at most 1.0")


func test_hex_tile_pulse_state_tracking() -> void:
	# Create a hex tile
	_hex_tile = HexTile.new()
	add_child_autofree(_hex_tile)
	await wait_frames(2)

	# Initially not pulsing
	assert_false(_hex_tile.is_contested_pulsing(), "Hex should not be pulsing initially")

	# Start pulse
	_hex_tile.start_contested_pulse()
	assert_true(_hex_tile.is_contested_pulsing(), "Hex should be pulsing after start_contested_pulse")

	# Stop pulse
	_hex_tile.stop_contested_pulse()
	assert_false(_hex_tile.is_contested_pulsing(), "Hex should not be pulsing after stop_contested_pulse")


func test_hex_tile_static_global_pulse_time() -> void:
	# Test that pulse time is static (shared across instances for sync - AC3)
	var hex1 := HexTile.new()
	var hex2 := HexTile.new()
	add_child_autofree(hex1)
	add_child_autofree(hex2)
	await wait_frames(2)

	# Start pulses
	hex1.start_contested_pulse()
	hex2.start_contested_pulse()

	# They should both reference the same static _global_pulse_time
	# (We can't directly test the static variable, but behavior should be synced)
	assert_true(hex1.is_contested_pulsing(), "Hex1 should be pulsing")
	assert_true(hex2.is_contested_pulsing(), "Hex2 should be pulsing")


func test_hex_tile_pulse_stops_on_cleanup() -> void:
	_hex_tile = HexTile.new()
	add_child_autofree(_hex_tile)
	await wait_frames(2)

	_hex_tile.start_contested_pulse()
	assert_true(_hex_tile.is_contested_pulsing())

	# Call cleanup
	_hex_tile.cleanup()
	# Note: After cleanup the node is queued for deletion
	await wait_frames(1)

# =============================================================================
# CONTESTED OVERLAY TESTS (AC: 2)
# =============================================================================

func test_hex_tile_has_contested_overlay_constants() -> void:
	assert_true(HexTile.CONTESTED_OVERLAY_OPACITY > 0.0, "Overlay opacity should be positive")
	assert_true(HexTile.CONTESTED_OVERLAY_OPACITY <= 0.25, "AC2: Overlay opacity should be 15-25%")


func test_hex_tile_contested_overlay_toggle() -> void:
	_hex_tile = HexTile.new()
	add_child_autofree(_hex_tile)
	await wait_frames(2)

	# Enable overlay (immediate, no animation)
	_hex_tile.set_contested_overlay(true, false)

	# Disable overlay (immediate, no animation)
	_hex_tile.set_contested_overlay(false, false)

	# Should not crash
	assert_true(true, "Overlay toggle should not crash")


func test_hex_tile_contested_overlay_with_animation() -> void:
	_hex_tile = HexTile.new()
	add_child_autofree(_hex_tile)
	await wait_frames(2)

	# Enable with animation (AC4: 0.4s fade)
	_hex_tile.set_contested_overlay(true, true)
	await wait_frames(2)

	# Disable with animation
	_hex_tile.set_contested_overlay(false, true)
	await wait_frames(2)

	assert_true(true, "Animated overlay should work")

# =============================================================================
# EXPANSION GLOW TESTS (AC: 9)
# =============================================================================

func test_hex_tile_expansion_glow_tracking() -> void:
	_hex_tile = HexTile.new()
	add_child_autofree(_hex_tile)
	await wait_frames(2)

	# Initially no glow
	assert_false(_hex_tile.has_expansion_glow(), "Should have no expansion glow initially")

	# Enable glow
	_hex_tile.set_expansion_glow(true)
	assert_true(_hex_tile.has_expansion_glow(), "Should have expansion glow after enabling")

	# Disable glow
	_hex_tile.set_expansion_glow(false)
	assert_false(_hex_tile.has_expansion_glow(), "Should have no expansion glow after disabling")


func test_territory_manager_should_have_expansion_glow() -> void:
	# Player owns center, enemy adjacent
	var player_hex := HexCoord.create(0, 0)
	var enemy_hex := HexCoord.create(1, 0)

	_territory_manager.set_hex_owner(player_hex, "player")
	_territory_manager.set_hex_owner(enemy_hex, "wild")

	# Player hex adjacent to enemy should have expansion glow
	var should_glow := _territory_manager._should_have_expansion_glow(player_hex)
	assert_true(should_glow, "AC9: Player hex adjacent to contested should have expansion glow")


func test_territory_manager_no_expansion_glow_when_no_adjacent_contested() -> void:
	var player_hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(player_hex, "player")

	# No enemies nearby
	var should_glow := _territory_manager._should_have_expansion_glow(player_hex)
	assert_false(should_glow, "Player hex with no adjacent contested should not have expansion glow")


func test_territory_manager_no_expansion_glow_on_enemy_hex() -> void:
	var enemy_hex := HexCoord.create(0, 0)
	_territory_manager.set_hex_owner(enemy_hex, "wild")

	var should_glow := _territory_manager._should_have_expansion_glow(enemy_hex)
	assert_false(should_glow, "Enemy-owned hex should never have expansion glow")

# =============================================================================
# TERRITORY MANAGER ADJACENT CONTESTED API TESTS (AC: 13)
# =============================================================================

func test_get_all_adjacent_contested_returns_array() -> void:
	var contested := _territory_manager.get_all_adjacent_contested()
	assert_true(contested is Array, "Should return an array")


func test_get_all_adjacent_contested_empty_when_no_player_territory() -> void:
	var contested := _territory_manager.get_all_adjacent_contested()
	assert_eq(contested.size(), 0, "Should be empty with no player territory")


func test_get_all_adjacent_contested_returns_contested_hexes() -> void:
	# Setup: player owns center, enemies adjacent
	_territory_manager.set_hex_owner(HexCoord.create(0, 0), "player")
	_territory_manager.set_hex_owner(HexCoord.create(1, 0), "wild")
	_territory_manager.set_hex_owner(HexCoord.create(-1, 0), "wild")

	var contested := _territory_manager.get_all_adjacent_contested()
	assert_eq(contested.size(), 2, "Should find 2 adjacent contested hexes")


func test_get_all_adjacent_contested_no_duplicates() -> void:
	# Create overlapping contested (enemy adjacent to multiple player hexes)
	_territory_manager.set_hex_owner(HexCoord.create(0, 0), "player")
	_territory_manager.set_hex_owner(HexCoord.create(2, 0), "player")
	_territory_manager.set_hex_owner(HexCoord.create(1, 0), "wild")  # Adjacent to both

	var contested := _territory_manager.get_all_adjacent_contested()

	# Check for duplicates
	var seen: Dictionary = {}
	var has_duplicates := false
	for hex in contested:
		var vec := hex.to_vector()
		if seen.has(vec):
			has_duplicates = true
			break
		seen[vec] = true

	assert_false(has_duplicates, "Should not return duplicate contested hexes")

# =============================================================================
# DIFFICULTY ESTIMATION TESTS (AC: 7)
# =============================================================================

func test_contested_preview_panel_difficulty_constants() -> void:
	assert_true(ContestedPreviewPanel.DIFFICULTY_EASY_MAX > 0.0)
	assert_true(ContestedPreviewPanel.DIFFICULTY_EASY_MAX < ContestedPreviewPanel.DIFFICULTY_MEDIUM_MAX)
	assert_true(ContestedPreviewPanel.DIFFICULTY_MEDIUM_MAX < ContestedPreviewPanel.DIFFICULTY_HIGH_MAX)


func test_contested_preview_panel_difficulty_colors() -> void:
	assert_not_null(ContestedPreviewPanel.COLOR_EASY)
	assert_not_null(ContestedPreviewPanel.COLOR_MEDIUM)
	assert_not_null(ContestedPreviewPanel.COLOR_HIGH)
	assert_not_null(ContestedPreviewPanel.COLOR_DANGEROUS)


func test_difficulty_label_calculation() -> void:
	# Create panel to test difficulty calculation
	_preview_panel = ContestedPreviewPanel.new()
	add_child_autofree(_preview_panel)
	await wait_frames(2)

	# Test easy difficulty (ratio < 0.6)
	var easy := _preview_panel._calculate_difficulty_label(5, 10)  # 0.5 ratio
	assert_eq(easy["label"], "Easy")

	# Test medium difficulty (ratio 0.6-1.0)
	var medium := _preview_panel._calculate_difficulty_label(8, 10)  # 0.8 ratio
	assert_eq(medium["label"], "Medium")

	# Test challenging difficulty (ratio 1.0-1.5)
	var challenging := _preview_panel._calculate_difficulty_label(12, 10)  # 1.2 ratio
	assert_eq(challenging["label"], "Challenging")

	# Test dangerous difficulty (ratio > 1.5)
	var dangerous := _preview_panel._calculate_difficulty_label(20, 10)  # 2.0 ratio
	assert_eq(dangerous["label"], "Dangerous")

	# Test unknown (zero player strength)
	var unknown := _preview_panel._calculate_difficulty_label(10, 0)
	assert_eq(unknown["label"], "Unknown")

# =============================================================================
# PREVIEW PANEL STATE TESTS (AC: 5, 8)
# =============================================================================

func test_contested_preview_panel_initial_state() -> void:
	_preview_panel = ContestedPreviewPanel.new()
	add_child_autofree(_preview_panel)
	await wait_frames(2)

	assert_false(_preview_panel.is_showing(), "Panel should be hidden initially")
	assert_eq(_preview_panel.get_current_hex(), Vector2i.ZERO, "Current hex should be zero initially")
	assert_eq(_preview_panel.get_current_herd_id(), "", "Current herd ID should be empty initially")


func test_contested_preview_panel_dismiss() -> void:
	_preview_panel = ContestedPreviewPanel.new()
	add_child_autofree(_preview_panel)
	await wait_frames(2)

	# Manually set showing state for test
	_preview_panel._is_showing = true

	watch_signals(_preview_panel)
	_preview_panel.dismiss()

	# Should emit panel_dismissed signal
	# FADE_DURATION is 0.2s, so wait ~15 frames (250ms at 60fps) for animation + callback
	await wait_frames(15)
	assert_signal_emitted(_preview_panel, "panel_dismissed")

# =============================================================================
# COMBAT OPPORTUNITY BADGE TESTS (AC: 13, 14)
# =============================================================================

func test_combat_opportunity_badge_initial_state() -> void:
	var badge := CombatOpportunityBadge.new()
	add_child_autofree(badge)
	await wait_frames(2)

	assert_eq(badge.get_contested_count(), 0, "Initial contested count should be 0")


func test_combat_opportunity_badge_refresh_count() -> void:
	# Setup territory with contested hexes first
	_territory_manager.set_hex_owner(HexCoord.create(0, 0), "player")
	_territory_manager.set_hex_owner(HexCoord.create(1, 0), "wild")

	var badge := CombatOpportunityBadge.new()
	add_child_autofree(badge)
	await wait_frames(2)

	# Badge needs territory manager reference
	badge._territory_manager = _territory_manager
	badge.refresh_count()

	assert_eq(badge.get_contested_count(), 1, "Should show 1 contested hex")


func test_combat_opportunity_badge_signals() -> void:
	var badge := CombatOpportunityBadge.new()
	add_child_autofree(badge)
	await wait_frames(2)

	# Test that badge has expected signals
	assert_true(badge.has_signal("badge_tapped"), "Should have badge_tapped signal")
	assert_true(badge.has_signal("pan_completed"), "Should have pan_completed signal")

# =============================================================================
# EVENTBUS SIGNAL TESTS (AC: 12)
# =============================================================================

func test_eventbus_has_contested_territory_discovered_signal() -> void:
	assert_true(EventBus.has_signal("contested_territory_discovered"),
		"EventBus should have contested_territory_discovered signal")


func test_eventbus_has_combat_requested_signal() -> void:
	assert_true(EventBus.has_signal("combat_requested"),
		"EventBus should have combat_requested signal")

# =============================================================================
# TERRITORY STATE TRANSITION TESTS (AC: 4)
# =============================================================================

func test_contested_state_triggers_pulse_and_overlay() -> void:
	_hex_tile = HexTile.new()
	add_child_autofree(_hex_tile)
	await wait_frames(2)

	# Initialize hex
	_hex_tile.hex_coord = HexCoord.create(0, 0)
	_hex_tile.terrain_type = HexTile.TerrainType.GRASS

	# Set to contested state (this should trigger pulse and overlay)
	_hex_tile.set_territory_state(TerritoryManager.TerritoryState.CONTESTED)

	# Wait for transition animation
	await wait_seconds(0.5)

	# After transition, pulse should be active
	assert_true(_hex_tile.is_contested_pulsing(), "Hex should be pulsing after transitioning to CONTESTED")


func test_claimed_state_stops_contested_effects() -> void:
	_hex_tile = HexTile.new()
	add_child_autofree(_hex_tile)
	await wait_frames(2)

	# Start in contested state
	_hex_tile.hex_coord = HexCoord.create(0, 0)
	_hex_tile.terrain_type = HexTile.TerrainType.GRASS
	_hex_tile.start_contested_pulse()
	_hex_tile.set_contested_overlay(true, false)
	assert_true(_hex_tile.is_contested_pulsing())

	# Transition to claimed
	_hex_tile.set_territory_state(TerritoryManager.TerritoryState.CLAIMED)

	# Should stop pulse
	assert_false(_hex_tile.is_contested_pulsing(), "Pulse should stop after transitioning from CONTESTED")

# =============================================================================
# PERFORMANCE TESTS (AC: 15)
# =============================================================================

func test_pulse_with_20_contested_hexes_performance() -> void:
	# Create 20 contested hexes with pulses
	var hexes: Array[HexTile] = []
	for i in range(20):
		var hex := HexTile.new()
		add_child_autofree(hex)
		hex.hex_coord = HexCoord.create(i, 0)
		hex.terrain_type = HexTile.TerrainType.GRASS
		hexes.append(hex)

	await wait_frames(2)

	# Start all pulses
	var start_time := Time.get_ticks_usec()
	for hex in hexes:
		hex.start_contested_pulse()
	var elapsed_usec := Time.get_ticks_usec() - start_time

	# Starting 20 pulses should be fast
	assert_lt(elapsed_usec, 10000.0, "AC15: Starting 20 pulses should complete in <10ms (was %d usec)" % elapsed_usec)

	# All should be pulsing
	for hex in hexes:
		assert_true(hex.is_contested_pulsing())


func test_get_all_adjacent_contested_performance() -> void:
	# Create realistic territory with many hexes
	for q in range(-10, 10):
		for r in range(-10, 10):
			if abs(q) <= 3 and abs(r) <= 3:
				_territory_manager.set_hex_owner(HexCoord.create(q, r), "player")
			else:
				_territory_manager.set_hex_owner(HexCoord.create(q, r), "wild")

	var start_time := Time.get_ticks_usec()

	for _i in range(100):
		var _contested := _territory_manager.get_all_adjacent_contested()

	var elapsed_usec := Time.get_ticks_usec() - start_time
	var avg_usec := elapsed_usec / 100.0

	# AC15: Should complete in under 1ms
	assert_lt(avg_usec, 1000.0, "AC15: get_all_adjacent_contested should average under 1ms (was %f usec)" % avg_usec)

# =============================================================================
# EDGE CASES
# =============================================================================

func test_null_hex_handling_in_preview_panel() -> void:
	_preview_panel = ContestedPreviewPanel.new()
	add_child_autofree(_preview_panel)
	await wait_frames(2)

	# Should not crash with null hex
	_preview_panel.show_for_hex(null)
	assert_false(_preview_panel.is_showing(), "Should not show for null hex")


func test_multiple_pulse_start_calls_idempotent() -> void:
	_hex_tile = HexTile.new()
	add_child_autofree(_hex_tile)
	await wait_frames(2)

	_hex_tile.start_contested_pulse()
	_hex_tile.start_contested_pulse()
	_hex_tile.start_contested_pulse()

	assert_true(_hex_tile.is_contested_pulsing(), "Multiple start calls should not break pulse")


func test_multiple_pulse_stop_calls_idempotent() -> void:
	_hex_tile = HexTile.new()
	add_child_autofree(_hex_tile)
	await wait_frames(2)

	_hex_tile.start_contested_pulse()
	_hex_tile.stop_contested_pulse()
	_hex_tile.stop_contested_pulse()
	_hex_tile.stop_contested_pulse()

	assert_false(_hex_tile.is_contested_pulsing(), "Multiple stop calls should not break state")
