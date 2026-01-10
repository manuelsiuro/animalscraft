## Structured logging system for AnimalsCraft.
## Autoload singleton - access via Logger.log(system, level, message)
##
## Architecture: autoloads/logger.gd
## Order: 2 (no dependencies)
## Source: game-architecture.md#Logging
##
## Format: [System][LEVEL] Message
## Example: [Combat][INFO] Battle started: 3v2
class_name Logger
extends Node

# =============================================================================
# LOG LEVELS
# =============================================================================

## Log severity levels in order of importance
enum Level {
	DEBUG,  ## Diagnostics (dev only)
	INFO,   ## Milestones and state changes
	WARN,   ## Unexpected but handled
	ERROR   ## Something broke
}

## Minimum log level for release builds
## Only ERROR and above are logged in release
const RELEASE_MIN_LEVEL: Level = Level.ERROR

# =============================================================================
# CONFIGURATION
# =============================================================================

## Enable file logging for errors in release builds
var _enable_file_logging: bool = true

## File path for persistent error logs
const ERROR_LOG_PATH: String = "user://error_log.txt"

## Maximum error log file size in bytes (1MB)
const MAX_LOG_FILE_SIZE: int = 1048576

# =============================================================================
# INTERNAL STATE
# =============================================================================

## Track if we've initialized file logging
var _file_logging_initialized: bool = false

# =============================================================================
# PUBLIC API
# =============================================================================

## Log a message with the specified system name and severity level.
##
## @param system The system/module name (e.g., "Combat", "Save", "AI")
## @param level The severity level (DEBUG, INFO, WARN, ERROR)
## @param message The log message
##
## Usage:
##   Logger.log("Combat", Logger.Level.INFO, "Battle started: 3v2")
##   Logger.log("Save", Logger.Level.ERROR, "Failed to write save file")
func log(system: String, level: Level, message: String) -> void:
	# Filter by build type and log level
	if not _should_log(level):
		return

	var formatted := _format_message(system, level, message)
	_output_message(formatted, level)

	# Also write errors to file in release builds
	if level == Level.ERROR and _enable_file_logging and not OS.is_debug_build():
		_write_to_file(formatted)


## Convenience method for debug logging.
## Only outputs in debug builds.
func debug(system: String, message: String) -> void:
	log(system, Level.DEBUG, message)


## Convenience method for info logging.
func info(system: String, message: String) -> void:
	log(system, Level.INFO, message)


## Convenience method for warning logging.
func warn(system: String, message: String) -> void:
	log(system, Level.WARN, message)


## Convenience method for error logging.
func error(system: String, message: String) -> void:
	log(system, Level.ERROR, message)


# =============================================================================
# INTERNAL METHODS
# =============================================================================

## Check if a message at the given level should be logged.
func _should_log(level: Level) -> bool:
	if OS.is_debug_build():
		return true
	return level >= RELEASE_MIN_LEVEL


## Format the log message with system and level prefix.
## Format: [System][LEVEL] Message (per Architecture spec)
func _format_message(system: String, level: Level, message: String) -> String:
	var level_str := Level.keys()[level]
	return "[%s][%s] %s" % [system, level_str, message]


## Output the message to the appropriate destination.
func _output_message(formatted: String, level: Level) -> void:
	match level:
		Level.ERROR:
			push_error(formatted)
		Level.WARN:
			push_warning(formatted)
		_:
			print(formatted)


## Write an error message to the persistent log file.
func _write_to_file(message: String) -> void:
	if not _file_logging_initialized:
		_init_file_logging()

	var file := FileAccess.open(ERROR_LOG_PATH, FileAccess.READ_WRITE)
	if file == null:
		# Try to create new file
		file = FileAccess.open(ERROR_LOG_PATH, FileAccess.WRITE)
		if file == null:
			return  # Can't write to file, silently fail

	# Check file size and rotate if needed
	if file.get_length() > MAX_LOG_FILE_SIZE:
		file.close()
		_rotate_log_file()
		file = FileAccess.open(ERROR_LOG_PATH, FileAccess.WRITE)
		if file == null:
			return

	# Seek to end and write
	file.seek_end()
	var timestamp := Time.get_datetime_string_from_system()
	file.store_line("[%s] %s" % [timestamp, message])
	file.close()


## Initialize file logging system.
func _init_file_logging() -> void:
	_file_logging_initialized = true
	# Ensure the file exists
	if not FileAccess.file_exists(ERROR_LOG_PATH):
		var file := FileAccess.open(ERROR_LOG_PATH, FileAccess.WRITE)
		if file != null:
			file.store_line("=== AnimalsCraft Error Log ===")
			file.close()


## Rotate log file when it gets too large.
func _rotate_log_file() -> void:
	var backup_path := ERROR_LOG_PATH.replace(".txt", "_old.txt")

	# Remove old backup if exists
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)

	# Rename current to backup
	if FileAccess.file_exists(ERROR_LOG_PATH):
		DirAccess.rename_absolute(ERROR_LOG_PATH, backup_path)
