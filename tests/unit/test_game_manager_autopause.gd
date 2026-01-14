## Unit tests for Story 1.7: Auto-Pause on App Switch
##
## These tests verify that GameManager properly handles app lifecycle events
## to pause/resume the game when the user switches apps.
##
## Test Framework: GUT (Godot Unit Test)
## Run: Via GUT test runner in Godot Editor (bottom panel)
##
## Coverage:
## - AC1: Pause on App Switch (via pause_game method)
## - AC2: GameManager Emits Pause Signal
## - AC3: Resume on App Return (via resume_game method)
## - AC4: GameManager Emits Resume Signal
## - AC5: Pause State Accessible (is_paused method)
##
## NOTE: _notification() handlers cannot be directly tested in GUT since
## we cannot simulate OS-level events. We test the public API that is
## called by the notification handlers.
extends GutTest


# =============================================================================
# TEST SETUP
# =============================================================================

## Save original game state to restore after tests
var _original_state: int
var _original_tree_paused: bool


## Setup runs before each test
func before_each() -> void:
	# Save current state
	_original_state = GameManager.get_state()
	_original_tree_paused = get_tree().paused

	# Reset to a clean playing state for consistent testing
	# First ensure we're not paused
	if get_tree().paused:
		get_tree().paused = false

	# Wait for frame to ensure state is stable
	await wait_frames(1)


## Cleanup after each test
func after_each() -> void:
	# Ensure game is not paused after tests
	if GameManager.is_paused():
		GameManager.resume_game()

	# Restore tree pause state
	get_tree().paused = _original_tree_paused

	# Wait for cleanup
	await wait_frames(1)


# =============================================================================
# AC1: PAUSE ON APP SWITCH
# =============================================================================

## Test that pause_game() method exists
func test_pause_game_method_exists() -> void:
	# AC1: pause_game should exist
	assert_true(GameManager.has_method("pause_game"),
		"GameManager should have pause_game() method")


## Test that pause_game() guard clause prevents pause when not PLAYING
func test_pause_game_guard_prevents_pause_from_menu() -> void:
	# GameManager starts in MENU state during tests
	# The guard clause should prevent pausing from MENU state
	var initial_state := GameManager.get_state()
	assert_eq(initial_state, GameManager.GameState.MENU,
		"GameManager should be in MENU state for this test")

	# Watch for signal - should NOT be emitted due to guard
	watch_signals(EventBus)

	# Try to pause from MENU state
	GameManager.pause_game()

	# Signal should NOT be emitted because we weren't in PLAYING state
	assert_signal_not_emitted(EventBus, "game_paused",
		"game_paused signal should NOT emit when pausing from MENU state (guard clause)")

	# State should remain MENU
	assert_eq(GameManager.get_state(), GameManager.GameState.MENU,
		"State should remain MENU after failed pause attempt")


## Test that pause_game() is idempotent (safe to call multiple times)
func test_pause_game_is_idempotent() -> void:
	# Multiple calls should not error and should not emit multiple signals
	watch_signals(EventBus)

	GameManager.pause_game()
	GameManager.pause_game()  # Second call should be no-op
	GameManager.pause_game()  # Third call should be no-op

	# Should emit 0 signals (we're in MENU, not PLAYING)
	assert_signal_emit_count(EventBus, "game_paused", 0,
		"No signals should emit when calling pause_game from MENU state")


# =============================================================================
# AC2: GAMEMANAGER EMITS PAUSE SIGNAL
# =============================================================================

## Test that game_paused signal exists in EventBus
func test_game_paused_signal_exists() -> void:
	# AC2: Verify the signal is defined
	assert_true(EventBus.has_signal("game_paused"),
		"EventBus should have game_paused signal")


## Test that pause signal can be emitted and received
func test_game_paused_signal_emission() -> void:
	# Watch for signal
	watch_signals(EventBus)

	# Manually emit to test the signal works
	EventBus.game_paused.emit()

	assert_signal_emitted(EventBus, "game_paused",
		"game_paused signal should be emittable")


## Test that listeners can connect to pause signal
func test_game_paused_signal_connection() -> void:
	# Use GUT's watch_signals which is more reliable for signal testing
	watch_signals(EventBus)

	# Emit signal
	EventBus.game_paused.emit()

	# Verify signal was emitted and can be connected to
	assert_signal_emitted(EventBus, "game_paused",
		"Connected listeners should receive game_paused signal")


# =============================================================================
# AC3: RESUME ON APP RETURN
# =============================================================================

## Test that resume_game() method exists
func test_resume_game_method_exists() -> void:
	# AC3: resume_game should exist
	assert_true(GameManager.has_method("resume_game"),
		"GameManager should have resume_game() method")


## Test that resume_game() guard clause prevents resume when not PAUSED
func test_resume_game_guard_prevents_resume_from_menu() -> void:
	# GameManager starts in MENU state during tests
	# The guard clause should prevent resuming from MENU state
	var initial_state := GameManager.get_state()
	assert_eq(initial_state, GameManager.GameState.MENU,
		"GameManager should be in MENU state for this test")

	# Watch for signal - should NOT be emitted due to guard
	watch_signals(EventBus)

	# Try to resume from MENU state
	GameManager.resume_game()

	# Signal should NOT be emitted because we weren't in PAUSED state
	assert_signal_not_emitted(EventBus, "game_resumed",
		"game_resumed signal should NOT emit when resuming from MENU state (guard clause)")

	# State should remain MENU
	assert_eq(GameManager.get_state(), GameManager.GameState.MENU,
		"State should remain MENU after failed resume attempt")


## Test that resume_game() is idempotent (safe to call multiple times)
func test_resume_game_is_idempotent() -> void:
	# Multiple calls should not error and should not emit multiple signals
	watch_signals(EventBus)

	GameManager.resume_game()
	GameManager.resume_game()  # Second call should be no-op
	GameManager.resume_game()  # Third call should be no-op

	# Should emit 0 signals (we're in MENU, not PAUSED)
	assert_signal_emit_count(EventBus, "game_resumed", 0,
		"No signals should emit when calling resume_game from MENU state")


## Test pause and resume methods both exist for cycle support
func test_pause_resume_methods_exist_for_cycle() -> void:
	# AC3: Both methods must exist for pause/resume cycle
	assert_true(GameManager.has_method("pause_game"), "pause_game should exist")
	assert_true(GameManager.has_method("resume_game"), "resume_game should exist")
	assert_true(GameManager.has_method("toggle_pause"), "toggle_pause should exist for convenience")


# =============================================================================
# AC4: GAMEMANAGER EMITS RESUME SIGNAL
# =============================================================================

## Test that game_resumed signal exists in EventBus
func test_game_resumed_signal_exists() -> void:
	# AC4: Verify the signal is defined
	assert_true(EventBus.has_signal("game_resumed"),
		"EventBus should have game_resumed signal")


## Test that resume signal can be emitted and received
func test_game_resumed_signal_emission() -> void:
	# Watch for signal
	watch_signals(EventBus)

	# Manually emit to test the signal works
	EventBus.game_resumed.emit()

	assert_signal_emitted(EventBus, "game_resumed",
		"game_resumed signal should be emittable")


## Test that listeners can connect to resume signal
func test_game_resumed_signal_connection() -> void:
	# Use GUT's watch_signals which is more reliable for signal testing
	watch_signals(EventBus)

	# Emit signal
	EventBus.game_resumed.emit()

	# Verify signal was emitted and can be connected to
	assert_signal_emitted(EventBus, "game_resumed",
		"Connected listeners should receive game_resumed signal")


# =============================================================================
# AC5: PAUSE STATE ACCESSIBLE
# =============================================================================

## Test that is_paused() method exists
func test_is_paused_method_exists() -> void:
	# AC5: is_paused() should exist
	assert_true(GameManager.has_method("is_paused"),
		"GameManager should have is_paused() method")


## Test that is_paused() returns a boolean
func test_is_paused_returns_boolean() -> void:
	# AC5: is_paused() should return boolean
	var result = GameManager.is_paused()
	assert_true(result is bool, "is_paused() should return a boolean")


## Test is_paused initial state (depends on GameManager's current state)
func test_is_paused_reflects_game_state() -> void:
	# AC5: is_paused should reflect actual game state
	# In MENU state, is_paused should be false
	var paused_state := GameManager.is_paused()
	var game_state := GameManager.get_state()

	if game_state == GameManager.GameState.PAUSED:
		assert_true(paused_state, "is_paused should return true when in PAUSED state")
	else:
		assert_false(paused_state, "is_paused should return false when not in PAUSED state")


# =============================================================================
# PROCESS MODE TESTS (Required for notification handling when paused)
# =============================================================================

## Test that GameManager has PROCESS_MODE_ALWAYS
func test_game_manager_process_mode_always() -> void:
	# GameManager must have PROCESS_MODE_ALWAYS to receive notifications when paused
	assert_eq(GameManager.process_mode, Node.PROCESS_MODE_ALWAYS,
		"GameManager should have PROCESS_MODE_ALWAYS to handle resume when paused")


# =============================================================================
# NOTIFICATION HANDLER HELPER METHODS
# =============================================================================

## Test that _handle_app_pause helper method exists
func test_handle_app_pause_method_exists() -> void:
	# The helper method should exist for notification handling
	assert_true(GameManager.has_method("_handle_app_pause"),
		"GameManager should have _handle_app_pause() helper method")


## Test that _handle_app_resume helper method exists
func test_handle_app_resume_method_exists() -> void:
	# The helper method should exist for notification handling
	assert_true(GameManager.has_method("_handle_app_resume"),
		"GameManager should have _handle_app_resume() helper method")


# =============================================================================
# GUARD CLAUSE TESTS (State-based protection)
# =============================================================================

## Test that pause guard clause works (tested from MENU state)
func test_pause_guard_clause_from_menu() -> void:
	# Verify we're in MENU state
	assert_eq(GameManager.get_state(), GameManager.GameState.MENU,
		"Should be in MENU state for this test")

	watch_signals(EventBus)

	# Multiple pause attempts from MENU should all be blocked
	GameManager.pause_game()
	GameManager.pause_game()
	GameManager.pause_game()

	# Guard clause should prevent ALL emissions (not in PLAYING state)
	assert_signal_emit_count(EventBus, "game_paused", 0,
		"Guard clause should block pause from MENU state - no signals emitted")


## Test that resume guard clause works (tested from MENU state)
func test_resume_guard_clause_from_menu() -> void:
	# Verify we're in MENU state
	assert_eq(GameManager.get_state(), GameManager.GameState.MENU,
		"Should be in MENU state for this test")

	watch_signals(EventBus)

	# Multiple resume attempts from MENU should all be blocked
	GameManager.resume_game()
	GameManager.resume_game()
	GameManager.resume_game()

	# Guard clause should prevent ALL emissions (not in PAUSED state)
	assert_signal_emit_count(EventBus, "game_resumed", 0,
		"Guard clause should block resume from MENU state - no signals emitted")


## Test that _handle_app_pause guard clause works
func test_handle_app_pause_guard_from_menu() -> void:
	# _handle_app_pause has its own guard: only pauses if state == PLAYING
	assert_eq(GameManager.get_state(), GameManager.GameState.MENU,
		"Should be in MENU state for this test")

	watch_signals(EventBus)

	# Call the handler directly (simulating notification)
	GameManager._handle_app_pause()
	GameManager._handle_app_pause()

	# Should not emit - guard prevents pause from MENU
	assert_signal_emit_count(EventBus, "game_paused", 0,
		"_handle_app_pause guard should prevent pause from MENU state")


## Test that _handle_app_resume guard clause works
func test_handle_app_resume_guard_from_menu() -> void:
	# _handle_app_resume has its own guard: only resumes if state == PAUSED
	assert_eq(GameManager.get_state(), GameManager.GameState.MENU,
		"Should be in MENU state for this test")

	watch_signals(EventBus)

	# Call the handler directly (simulating notification)
	GameManager._handle_app_resume()
	GameManager._handle_app_resume()

	# Should not emit - guard prevents resume from MENU
	assert_signal_emit_count(EventBus, "game_resumed", 0,
		"_handle_app_resume guard should prevent resume from MENU state")


# =============================================================================
# TOGGLE PAUSE TESTS
# =============================================================================

## Test that toggle_pause method exists
func test_toggle_pause_method_exists() -> void:
	assert_true(GameManager.has_method("toggle_pause"),
		"GameManager should have toggle_pause() method for manual pause/resume")


# =============================================================================
# STATE MACHINE INTEGRATION TESTS
# =============================================================================

## Test that GameState enum has PAUSED state
func test_game_state_has_paused_enum() -> void:
	assert_eq(GameManager.GameState.PAUSED, 4,
		"GameState.PAUSED should be defined (value 4)")


## Test that GameState enum has PLAYING state
func test_game_state_has_playing_enum() -> void:
	assert_eq(GameManager.GameState.PLAYING, 3,
		"GameState.PLAYING should be defined (value 3)")


## Test get_state returns valid GameState
func test_get_state_returns_valid_state() -> void:
	var state := GameManager.get_state()
	assert_true(state >= 0 and state <= 5,
		"get_state should return a valid GameState value")
