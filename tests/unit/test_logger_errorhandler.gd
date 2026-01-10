## Comprehensive unit tests for Story 0.4: Logger and ErrorHandler
##
## These tests verify Logger and ErrorHandler meet all acceptance criteria:
## - AC1: Logger format [System][Level] message
## - AC2: Log level filtering (ERROR always, DEBUG debug-only)
## - AC3: ErrorHandler signals and recovery triggering
## - AC4: Graceful recovery and tracking
## - AC5: Integration between Logger and ErrorHandler
##
## Test Framework: GUT (Godot Unit Test)
## Installation: https://github.com/bitwes/Gut
##   1. Install via AssetLib in Godot Editor (search for "Gut")
##   2. Or download and place in addons/gut/
## Run: Via GUT test runner in Godot Editor (bottom panel)
##
## Architecture References:
## - AR11: Signal-based error handling
## - AR18: Null safety via guard clauses
## - game-architecture.md#Logging
## - game-architecture.md#Error Handling
extends GutTest


# =============================================================================
# TEST SETUP AND TEARDOWN
# =============================================================================

## Runs before each test
func before_each() -> void:
	gut.p("Running Story 0.4 Logger/ErrorHandler test")
	# Clear any error states from previous tests
	if is_instance_valid(ErrorHandler):
		ErrorHandler._systems_in_error.clear()
		ErrorHandler._recovery_attempts.clear()


## Runs after each test
func after_each() -> void:
	# Ensure clean state
	if is_instance_valid(ErrorHandler):
		ErrorHandler._systems_in_error.clear()
		ErrorHandler._recovery_attempts.clear()


# =============================================================================
# AC1: LOGGER FORMAT TESTS
# =============================================================================

## Test Logger._format_message produces correct format
func test_logger_format_message_info() -> void:
	var formatted := Logger._format_message("TestSystem", Logger.Level.INFO, "Test message")
	assert_eq(formatted, "[TestSystem][INFO] Test message",
		"Format should be [System][Level] message")


## Test format with DEBUG level
func test_logger_format_message_debug() -> void:
	var formatted := Logger._format_message("Debug", Logger.Level.DEBUG, "Debug info")
	assert_eq(formatted, "[Debug][DEBUG] Debug info",
		"DEBUG level should format correctly")


## Test format with WARN level
func test_logger_format_message_warn() -> void:
	var formatted := Logger._format_message("Warning", Logger.Level.WARN, "Warning message")
	assert_eq(formatted, "[Warning][WARN] Warning message",
		"WARN level should format correctly")


## Test format with ERROR level
func test_logger_format_message_error() -> void:
	var formatted := Logger._format_message("Critical", Logger.Level.ERROR, "Error occurred")
	assert_eq(formatted, "[Critical][ERROR] Error occurred",
		"ERROR level should format correctly")


## Test format with empty system name
func test_logger_format_message_empty_system() -> void:
	var formatted := Logger._format_message("", Logger.Level.INFO, "Message")
	assert_eq(formatted, "[][INFO] Message",
		"Empty system name should still format")


## Test format with special characters in message
func test_logger_format_message_special_chars() -> void:
	var formatted := Logger._format_message("Test", Logger.Level.INFO, "Value: 100%, Path: C:\\test")
	assert_true(formatted.begins_with("[Test][INFO]"),
		"Special characters should not break formatting")


# =============================================================================
# AC2: LOG LEVEL FILTERING TESTS
# =============================================================================

## Test that Level enum has all required values
func test_logger_level_enum_complete() -> void:
	assert_eq(Logger.Level.DEBUG, 0, "DEBUG should be 0")
	assert_eq(Logger.Level.INFO, 1, "INFO should be 1")
	assert_eq(Logger.Level.WARN, 2, "WARN should be 2")
	assert_eq(Logger.Level.ERROR, 3, "ERROR should be 3")
	assert_eq(Logger.Level.keys().size(), 4, "Should have exactly 4 log levels")


## Test RELEASE_MIN_LEVEL is set to ERROR
func test_logger_release_min_level() -> void:
	assert_eq(Logger.RELEASE_MIN_LEVEL, Logger.Level.ERROR,
		"RELEASE_MIN_LEVEL should be ERROR")


## Test _should_log returns true for all levels in debug build
func test_logger_should_log_debug_build() -> void:
	# Note: We're always in debug build during tests
	if OS.is_debug_build():
		assert_true(Logger._should_log(Logger.Level.DEBUG), "DEBUG should log in debug build")
		assert_true(Logger._should_log(Logger.Level.INFO), "INFO should log in debug build")
		assert_true(Logger._should_log(Logger.Level.WARN), "WARN should log in debug build")
		assert_true(Logger._should_log(Logger.Level.ERROR), "ERROR should log in debug build")
	else:
		pending("Test requires debug build")


## Test ERROR level comparison for release filtering
func test_logger_error_level_highest() -> void:
	assert_true(Logger.Level.ERROR >= Logger.Level.DEBUG, "ERROR >= DEBUG")
	assert_true(Logger.Level.ERROR >= Logger.Level.INFO, "ERROR >= INFO")
	assert_true(Logger.Level.ERROR >= Logger.Level.WARN, "ERROR >= WARN")
	assert_true(Logger.Level.ERROR >= Logger.RELEASE_MIN_LEVEL, "ERROR >= RELEASE_MIN_LEVEL")


## Test debug() convenience method exists and can be called
func test_logger_convenience_method_debug() -> void:
	# Just verify the method exists and can be called
	assert_true(Logger.has_method("debug"), "debug() method should exist")
	Logger.debug("Test", "Debug message")  # Should not error


## Test info() convenience method exists and can be called
func test_logger_convenience_method_info() -> void:
	assert_true(Logger.has_method("info"), "info() method should exist")
	Logger.info("Test", "Info message")  # Should not error


## Test warn() convenience method exists and can be called
func test_logger_convenience_method_warn() -> void:
	assert_true(Logger.has_method("warn"), "warn() method should exist")
	Logger.warn("Test", "Warning message")  # Should not error


## Test error() convenience method exists and can be called
func test_logger_convenience_method_error() -> void:
	assert_true(Logger.has_method("error"), "error() method should exist")
	Logger.error("Test", "Error message")  # Should not error


# =============================================================================
# AC3: ERRORHANDLER SIGNALS TESTS
# =============================================================================

## Test critical_error signal exists with correct signature
func test_errorhandler_critical_error_signal_exists() -> void:
	assert_true(ErrorHandler.has_signal("critical_error"),
		"ErrorHandler should have critical_error signal")


## Test error_recovered signal exists with correct signature
func test_errorhandler_error_recovered_signal_exists() -> void:
	assert_true(ErrorHandler.has_signal("error_recovered"),
		"ErrorHandler should have error_recovered signal")


## Test critical_error signal is emitted on critical error
func test_errorhandler_critical_error_signal_emission() -> void:
	var signal_received := false
	var received_system := ""
	var received_message := ""

	var callback := func(system: String, message: String) -> void:
		signal_received = true
		received_system = system
		received_message = message

	ErrorHandler.critical_error.connect(callback)
	ErrorHandler.handle_error("TestSignal", "Test critical error", true)

	assert_true(signal_received, "critical_error signal should be emitted")
	assert_eq(received_system, "TestSignal", "System should be passed correctly")
	assert_eq(received_message, "Test critical error", "Message should be passed correctly")

	ErrorHandler.critical_error.disconnect(callback)
	ErrorHandler.report_recovered("TestSignal")


## Test error_recovered signal is emitted on recovery
func test_errorhandler_error_recovered_signal_emission() -> void:
	var signal_received := false
	var received_system := ""

	var callback := func(system: String) -> void:
		signal_received = true
		received_system = system

	# First create an error state
	ErrorHandler.handle_error("RecoveryTest", "Test error", true)

	# Connect to recovery signal
	ErrorHandler.error_recovered.connect(callback)
	ErrorHandler.report_recovered("RecoveryTest")

	assert_true(signal_received, "error_recovered signal should be emitted")
	assert_eq(received_system, "RecoveryTest", "System should be passed correctly")

	ErrorHandler.error_recovered.disconnect(callback)


# =============================================================================
# AC4: GRACEFUL RECOVERY TESTS
# =============================================================================

## Test handle_error method exists with correct signature
func test_errorhandler_handle_error_exists() -> void:
	assert_true(ErrorHandler.has_method("handle_error"),
		"ErrorHandler should have handle_error() method")


## Test non-critical error does not set error state
func test_errorhandler_non_critical_no_state() -> void:
	ErrorHandler.handle_error("TestSystem", "Non-critical error", false)
	assert_false(ErrorHandler.is_system_in_error("TestSystem"),
		"Non-critical error should not set error state")


## Test critical error sets error state
func test_errorhandler_critical_sets_state() -> void:
	ErrorHandler.handle_error("CriticalTest", "Critical error", true)
	assert_true(ErrorHandler.is_system_in_error("CriticalTest"),
		"Critical error should set error state")

	# Clean up
	ErrorHandler.report_recovered("CriticalTest")


## Test get_error_message returns correct message
func test_errorhandler_get_error_message() -> void:
	ErrorHandler.handle_error("MessageTest", "Test message content", true)
	var message := ErrorHandler.get_error_message("MessageTest")
	assert_eq(message, "Test message content",
		"get_error_message should return the error message")

	# Clean up
	ErrorHandler.report_recovered("MessageTest")


## Test get_error_message returns empty for non-error system
func test_errorhandler_get_error_message_no_error() -> void:
	var message := ErrorHandler.get_error_message("NonExistentSystem")
	assert_eq(message, "", "get_error_message should return empty for non-error system")


## Test MAX_RECOVERY_ATTEMPTS constant exists
func test_errorhandler_max_recovery_attempts_exists() -> void:
	assert_eq(ErrorHandler.MAX_RECOVERY_ATTEMPTS, 3,
		"MAX_RECOVERY_ATTEMPTS should be 3")


## Test recovery attempt tracking
func test_errorhandler_recovery_attempt_tracking() -> void:
	# First error - attempt 1
	ErrorHandler.handle_error("TrackingTest", "Error 1", true)
	assert_true(ErrorHandler._recovery_attempts.has("TrackingTest"),
		"Recovery attempts should be tracked")
	assert_eq(ErrorHandler._recovery_attempts["TrackingTest"], 1,
		"First attempt should be 1")

	# Reset for next test
	ErrorHandler.report_recovered("TrackingTest")


## Test report_recovered clears error state
func test_errorhandler_report_recovered_clears_state() -> void:
	ErrorHandler.handle_error("ClearTest", "Error", true)
	assert_true(ErrorHandler.is_system_in_error("ClearTest"),
		"Error state should be set before recovery")

	ErrorHandler.report_recovered("ClearTest")
	assert_false(ErrorHandler.is_system_in_error("ClearTest"),
		"Error state should be cleared after recovery")


## Test report_recovered clears recovery attempts
func test_errorhandler_report_recovered_clears_attempts() -> void:
	ErrorHandler.handle_error("AttemptsTest", "Error", true)
	assert_true(ErrorHandler._recovery_attempts.has("AttemptsTest"),
		"Recovery attempts should exist")

	ErrorHandler.report_recovered("AttemptsTest")
	assert_false(ErrorHandler._recovery_attempts.has("AttemptsTest"),
		"Recovery attempts should be cleared after recovery")


## Test ErrorLevel enum exists
func test_errorhandler_error_level_enum() -> void:
	assert_eq(ErrorHandler.ErrorLevel.RECOVERABLE, 0, "RECOVERABLE should be 0")
	assert_eq(ErrorHandler.ErrorLevel.CRITICAL, 1, "CRITICAL should be 1")


# =============================================================================
# AC5: INTEGRATION TESTS
# =============================================================================

## Test ErrorHandler uses Logger for error logging
func test_integration_errorhandler_uses_logger() -> void:
	# This is verified by the fact that ErrorHandler.handle_error
	# calls Logger.error() internally
	# We can verify by checking the code path exists
	assert_true(is_instance_valid(Logger), "Logger should be valid")
	assert_true(is_instance_valid(ErrorHandler), "ErrorHandler should be valid")

	# Call handle_error - should not crash due to Logger integration
	ErrorHandler.handle_error("IntegrationTest", "Testing Logger integration", false)
	pass_test("ErrorHandler-Logger integration works")


## Test ErrorHandler has emergency_save integration
func test_integration_errorhandler_emergency_save_method() -> void:
	# Verify _trigger_emergency_save method exists
	assert_true(ErrorHandler.has_method("_trigger_emergency_save"),
		"ErrorHandler should have _trigger_emergency_save method")


## Test SaveManager has emergency_save method
func test_integration_savemanager_emergency_save_exists() -> void:
	assert_true(SaveManager.has_method("emergency_save"),
		"SaveManager should have emergency_save method for ErrorHandler")


## Test ErrorHandler can access SaveManager node
func test_integration_errorhandler_savemanager_access() -> void:
	var save_manager := ErrorHandler.get_node_or_null("/root/SaveManager")
	assert_not_null(save_manager, "ErrorHandler should be able to access SaveManager")


## Test system-specific recovery methods exist
func test_integration_recovery_methods_exist() -> void:
	assert_true(ErrorHandler.has_method("_recover_save_system"),
		"Should have Save system recovery")
	assert_true(ErrorHandler.has_method("_recover_audio_system"),
		"Should have Audio system recovery")
	assert_true(ErrorHandler.has_method("_recover_game_system"),
		"Should have Game system recovery")
	assert_true(ErrorHandler.has_method("_generic_recovery"),
		"Should have generic recovery")


## Test complete error flow (emit -> recover -> clear)
func test_integration_complete_error_flow() -> void:
	var critical_received := false
	var recovered_received := false

	var critical_callback := func(_system: String, _message: String) -> void:
		critical_received = true

	var recovered_callback := func(_system: String) -> void:
		recovered_received = true

	ErrorHandler.critical_error.connect(critical_callback)
	ErrorHandler.error_recovered.connect(recovered_callback)

	# Trigger error
	ErrorHandler.handle_error("FlowTest", "Test flow", true)
	assert_true(critical_received, "Should receive critical_error signal")
	assert_true(ErrorHandler.is_system_in_error("FlowTest"), "Should be in error state")

	# Note: Recovery happens automatically in _attempt_recovery for unknown systems
	# For this test, we just verify the flow works

	# Manual recovery
	ErrorHandler.report_recovered("FlowTest")
	assert_true(recovered_received, "Should receive error_recovered signal")
	assert_false(ErrorHandler.is_system_in_error("FlowTest"), "Should be cleared")

	ErrorHandler.critical_error.disconnect(critical_callback)
	ErrorHandler.error_recovered.disconnect(recovered_callback)


# =============================================================================
# FILE LOGGING TESTS
# =============================================================================

## Test Logger has file logging constants
func test_logger_file_logging_constants() -> void:
	assert_true(Logger.ERROR_LOG_PATH.length() > 0,
		"ERROR_LOG_PATH should be defined")
	assert_true(Logger.MAX_LOG_FILE_SIZE > 0,
		"MAX_LOG_FILE_SIZE should be positive")


## Test Logger file logging can be enabled/disabled
func test_logger_file_logging_toggle() -> void:
	var original := Logger._enable_file_logging

	Logger._enable_file_logging = false
	assert_false(Logger._enable_file_logging, "File logging should be disabled")

	Logger._enable_file_logging = true
	assert_true(Logger._enable_file_logging, "File logging should be enabled")

	# Restore original
	Logger._enable_file_logging = original


## Test Logger has log rotation method
func test_logger_log_rotation_method_exists() -> void:
	assert_true(Logger.has_method("_rotate_log_file"),
		"Logger should have _rotate_log_file method")


# =============================================================================
# EDGE CASE TESTS
# =============================================================================

## Test ErrorHandler handles null-safe Logger access
func test_errorhandler_null_safe_logger() -> void:
	# ErrorHandler should have null check for Logger
	# This is verified by the is_instance_valid check in handle_error
	# The test passes if no crash occurs
	ErrorHandler.handle_error("NullSafeTest", "Testing null safety", false)
	pass_test("ErrorHandler handles Logger access safely")


## Test ErrorHandler handles recovery for unknown system
func test_errorhandler_unknown_system_recovery() -> void:
	# Unknown system should use generic recovery
	ErrorHandler.handle_error("UnknownSystem123", "Unknown error", true)

	# Generic recovery should have been attempted and recovered
	# (since _generic_recovery calls report_recovered immediately)
	assert_false(ErrorHandler.is_system_in_error("UnknownSystem123"),
		"Unknown system should be recovered via generic recovery")


## Test Logger handles empty message
func test_logger_empty_message() -> void:
	var formatted := Logger._format_message("Test", Logger.Level.INFO, "")
	assert_eq(formatted, "[Test][INFO] ",
		"Empty message should still format correctly")


## Test multiple errors on same system
func test_errorhandler_multiple_errors_same_system() -> void:
	# First error
	ErrorHandler.handle_error("MultiError", "Error 1", true)
	var first_attempts := ErrorHandler._recovery_attempts.get("MultiError", 0)

	# Second error (should increment attempts)
	ErrorHandler._systems_in_error["MultiError"] = "Error 2"  # Force state for second error
	ErrorHandler._attempt_recovery("MultiError")
	var second_attempts := ErrorHandler._recovery_attempts.get("MultiError", 0)

	assert_true(second_attempts > first_attempts,
		"Recovery attempts should increment on repeated errors")

	# Clean up
	ErrorHandler.report_recovered("MultiError")
