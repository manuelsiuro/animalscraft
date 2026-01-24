## Main scene entry point for AnimalsCraft
##
## This is the application's primary entry point, loaded first when the game starts.
## It serves as the root scene for the entire application lifecycle.
##
## Architecture Role:
## - Initializes core systems and validates all 8 autoloads are ready
## - Provides scene transition entry point (via GameManager)
## - Implements graceful error handling per AR11 (signal-based, never crash)
## - Follows AR18 null safety with early return guard clauses
##
## Autoload Verification (Story 0.5):
## - Verifies all 8 autoloads are accessible: GameConstants, GameLogger, ErrorHandler,
##   EventBus, Settings, AudioManager, SaveManager, GameManager
## - Emits EventBus.autoloads_ready() on success
## - Emits EventBus.autoloads_failed(missing) on failure with graceful degradation
##
## @tutorial: See Architecture Doc - Main Scene Structure
class_name Main
extends Node


## List of required autoloads in initialization order.
## Critical autoloads (first 4) are required for basic operation.
## Non-critical autoloads (last 4) allow graceful degradation.
const CRITICAL_AUTOLOADS := ["GameConstants", "GameLogger", "ErrorHandler", "EventBus"]
const NON_CRITICAL_AUTOLOADS := ["Settings", "AudioManager", "SaveManager", "GameManager"]


## Track if autoloads have been verified
var _autoloads_verified := false

## Auto-transition timer to game scene after splash screen
var _transition_timer := 0.0
const SPLASH_SCREEN_DURATION := 2.0  # seconds to show welcome screen


## Initialize main scene and verify core systems
## Implements AR11 error handling and AR18 null safety
func _ready() -> void:
	# AR18: Early return guard clause - verify node is in tree
	if not is_inside_tree():
		push_error("[Main] Node not in scene tree - initialization failed")
		return

	# AR11: Graceful error handling - log but don't crash
	if not _verify_scene_structure():
		push_warning("[Main] Scene structure validation failed - some features may not work")

	# Verify all autoloads are ready (Story 0.5)
	var autoload_result := _verify_autoloads()
	_autoloads_verified = autoload_result.all_critical_ready

	if autoload_result.all_ready:
		# All autoloads ready - emit success signal
		if is_instance_valid(EventBus) and EventBus.has_signal("autoloads_ready"):
			EventBus.autoloads_ready.emit()
		GameLogger.info("Main", "All 8 autoloads verified and ready")
	elif autoload_result.all_critical_ready:
		# Critical autoloads ready, some non-critical missing - graceful degradation
		if is_instance_valid(EventBus) and EventBus.has_signal("autoloads_failed"):
			EventBus.autoloads_failed.emit(autoload_result.missing)
		GameLogger.warn("Main", "Non-critical autoloads missing: %s - some features disabled" % [autoload_result.missing])
	else:
		# Critical autoloads missing - cannot operate safely
		push_error("[Main] CRITICAL: Required autoloads missing: %s" % [autoload_result.missing])
		# Try to emit if EventBus exists
		if is_instance_valid(EventBus) and EventBus.has_signal("autoloads_failed"):
			EventBus.autoloads_failed.emit(autoload_result.missing)
		return

	# Log successful initialization
	if is_instance_valid(GameLogger):
		GameLogger.info("Main", "AnimalsCraft v0.1.0 initialized")
		GameLogger.info("Main", "Project Foundation - Story 0.5 complete")
		GameLogger.info("Main", "Splash screen will auto-transition to game in %.1f seconds" % SPLASH_SCREEN_DURATION)
	else:
		print("[Main] AnimalsCraft v0.1.0 initialized")


## Verify expected scene structure exists
## Returns true if all required nodes are present
func _verify_scene_structure() -> bool:
	# AR18: Null safety - check all expected child nodes

	# Validate we're the root node
	if get_parent() != get_tree().root:
		push_error("[Main] Main scene must be root node")
		return false

	return true


## Verify all autoloads are accessible and initialized.
## Returns a Dictionary with verification results:
## - all_ready: bool - true if ALL autoloads are accessible
## - all_critical_ready: bool - true if all CRITICAL autoloads are accessible
## - missing: Array[String] - list of missing autoload names
## - verified: Array[String] - list of verified autoload names
func _verify_autoloads() -> Dictionary:
	var result := {
		"all_ready": true,
		"all_critical_ready": true,
		"missing": [] as Array[String],
		"verified": [] as Array[String]
	}

	# Check critical autoloads
	for autoload_name in CRITICAL_AUTOLOADS:
		if _is_autoload_ready(autoload_name):
			result.verified.append(autoload_name)
		else:
			result.missing.append(autoload_name)
			result.all_ready = false
			result.all_critical_ready = false

	# Check non-critical autoloads
	for autoload_name in NON_CRITICAL_AUTOLOADS:
		if _is_autoload_ready(autoload_name):
			result.verified.append(autoload_name)
		else:
			result.missing.append(autoload_name)
			result.all_ready = false

	return result


## Check if a specific autoload is accessible and valid.
## Uses get_node_or_null to safely check without errors.
## @param autoload_name The name of the autoload singleton
## @return true if the autoload exists and is valid
func _is_autoload_ready(autoload_name: String) -> bool:
	# AR18: Null safety - use safe node lookup
	var autoload := get_node_or_null("/root/" + autoload_name)

	if autoload == null:
		return false

	# Additional validation - ensure it's a valid instance
	if not is_instance_valid(autoload):
		return false

	return true


## Get the autoload verification status.
## @return true if autoloads have been verified and critical ones are ready
func are_autoloads_ready() -> bool:
	return _autoloads_verified


## Process function to handle auto-transition timer
func _process(delta: float) -> void:
	# Only count timer if autoloads are ready
	if not _autoloads_verified:
		return

	# Increment transition timer
	_transition_timer += delta

	# Auto-transition to game scene after splash duration
	if _transition_timer >= SPLASH_SCREEN_DURATION:
		go_to_game()
		set_process(false)  # Stop processing after transition


## Request transition to appropriate scene based on first launch detection.
## First launch: Start game directly with tutorial (AC2 - Story 6-9)
## Subsequent launches: Go to main menu for load/continue options
func go_to_game() -> void:
	# AR18: Null safety guard
	if not is_instance_valid(GameManager):
		push_error("[Main] Cannot transition - GameManager not available")
		return

	# Story 6-9 AC2: First launch detection
	if GameManager.is_first_launch():
		if is_instance_valid(GameLogger):
			GameLogger.info("Main", "First launch detected - starting tutorial game directly")
		GameManager.start_first_launch_game()
	else:
		if is_instance_valid(GameLogger):
			GameLogger.info("Main", "Returning player - transitioning to main menu")
		GameManager.change_to_main_scene()
