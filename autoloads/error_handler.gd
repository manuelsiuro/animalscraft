## Graceful error handling for AnimalsCraft.
## Autoload singleton - access via ErrorHandler.handle_error()
##
## Architecture: autoloads/error_handler.gd
## Order: 3 (depends on Logger)
## Source: game-architecture.md#Error Handling
##
## Philosophy: AnimalsCraft is a cozy game - NEVER crash, NEVER show scary errors.
## All errors are handled silently with attempted recovery.
class_name ErrorHandler
extends Node

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when a critical error occurs that may affect gameplay.
## Connect to this for systems that need to respond to errors.
signal critical_error(system: String, message: String)

## Emitted when a system has successfully recovered from an error.
signal error_recovered(system: String)

# =============================================================================
# ERROR LEVELS
# =============================================================================

## Error severity levels (internal use)
enum ErrorLevel {
	RECOVERABLE,  ## Log and continue
	CRITICAL      ## Attempt recovery, emergency save
}

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Track systems currently in error state for recovery monitoring
var _systems_in_error: Dictionary = {}

## Track recovery attempts to prevent infinite loops
var _recovery_attempts: Dictionary = {}

## Maximum recovery attempts before giving up
const MAX_RECOVERY_ATTEMPTS: int = 3

# =============================================================================
# PUBLIC API
# =============================================================================

## Handle an error from a game system.
##
## @param system The system/module that encountered the error
## @param message Description of what went wrong
## @param is_critical If true, triggers emergency save and recovery attempt
##
## Usage:
##   ErrorHandler.handle_error("Save", "Failed to write save file", true)
##   ErrorHandler.handle_error("AI", "Animal stuck, resetting path", false)
func handle_error(system: String, message: String, is_critical: bool = false) -> void:
	# Always log the error (with null safety check for Logger dependency)
	if is_instance_valid(Logger):
		Logger.error(system, message)
	else:
		push_error("[ErrorHandler][ERROR] %s: %s" % [system, message])

	if is_critical:
		_handle_critical_error(system, message)
	else:
		_handle_recoverable_error(system, message)


## Report that a system has recovered from an error state.
## Call this after successful recovery to clear error tracking.
##
## @param system The system that recovered
func report_recovered(system: String) -> void:
	if _systems_in_error.has(system):
		_systems_in_error.erase(system)
		_recovery_attempts.erase(system)
		if is_instance_valid(Logger):
			Logger.info("ErrorHandler", "%s recovered from error state" % system)
		error_recovered.emit(system)


## Check if a system is currently in an error state.
##
## @param system The system to check
## @return True if the system is in an error state
func is_system_in_error(system: String) -> bool:
	return _systems_in_error.has(system)


## Get the current error message for a system.
##
## @param system The system to check
## @return The error message, or empty string if no error
func get_error_message(system: String) -> String:
	if _systems_in_error.has(system):
		return _systems_in_error[system]
	return ""


# =============================================================================
# INTERNAL METHODS
# =============================================================================

## Handle a critical error with emergency save and recovery.
func _handle_critical_error(system: String, message: String) -> void:
	# Track this error
	_systems_in_error[system] = message

	# Emit signal for listeners
	critical_error.emit(system, message)

	# Trigger emergency save if SaveManager is available
	# Note: SaveManager may not be loaded yet during early initialization
	_trigger_emergency_save()

	# Attempt recovery
	_attempt_recovery(system)


## Handle a recoverable error (log only).
func _handle_recoverable_error(system: String, _message: String) -> void:
	# For recoverable errors, we just log (already done in handle_error)
	# Systems should handle their own recovery for non-critical issues
	pass


## Attempt to recover a system from an error state.
func _attempt_recovery(system: String) -> void:
	# Track recovery attempts
	if not _recovery_attempts.has(system):
		_recovery_attempts[system] = 0

	_recovery_attempts[system] += 1

	# Check if we've exceeded max attempts
	if _recovery_attempts[system] > MAX_RECOVERY_ATTEMPTS:
		if is_instance_valid(Logger):
			Logger.error("ErrorHandler", "Max recovery attempts reached for %s, giving up" % system)
		return

	if is_instance_valid(Logger):
		Logger.info("ErrorHandler", "Attempting recovery for %s (attempt %d/%d)" % [
			system,
			_recovery_attempts[system],
			MAX_RECOVERY_ATTEMPTS
		])

	# System-specific recovery strategies
	match system:
		"Save":
			_recover_save_system()
		"Audio":
			_recover_audio_system()
		"Game":
			_recover_game_system()
		_:
			# Generic recovery - just clear error state
			_generic_recovery(system)


## Trigger an emergency save to preserve player progress.
func _trigger_emergency_save() -> void:
	# Check if SaveManager exists and is ready
	if not is_instance_valid(get_node_or_null("/root/SaveManager")):
		if is_instance_valid(Logger):
			Logger.warn("ErrorHandler", "SaveManager not available for emergency save")
		return

	# Call emergency save using call_deferred to avoid issues during error handling
	SaveManager.call_deferred("emergency_save")


## Recovery strategy for Save system errors.
func _recover_save_system() -> void:
	if is_instance_valid(Logger):
		Logger.info("ErrorHandler", "Attempting Save system recovery...")
	# SaveManager will handle its own recovery when available
	# Just clear error state and let it retry on next save
	report_recovered("Save")


## Recovery strategy for Audio system errors.
func _recover_audio_system() -> void:
	if is_instance_valid(Logger):
		Logger.info("ErrorHandler", "Attempting Audio system recovery...")

	# Check if AudioManager exists and call reset directly (trust dependency exists)
	var audio_manager := get_node_or_null("/root/AudioManager")
	if is_instance_valid(audio_manager):
		audio_manager.reset()

	report_recovered("Audio")


## Recovery strategy for Game system errors.
func _recover_game_system() -> void:
	if is_instance_valid(Logger):
		Logger.info("ErrorHandler", "Attempting Game system recovery...")

	# Check if GameManager exists and call reset directly (trust dependency exists)
	var game_manager := get_node_or_null("/root/GameManager")
	if is_instance_valid(game_manager):
		game_manager.reset_to_safe_state()

	report_recovered("Game")


## Generic recovery for unknown systems.
func _generic_recovery(system: String) -> void:
	if is_instance_valid(Logger):
		Logger.info("ErrorHandler", "Generic recovery for %s - clearing error state" % system)
	# Just clear the error state and hope for the best
	# Cozy game philosophy: never crash, always try to continue
	report_recovered(system)
