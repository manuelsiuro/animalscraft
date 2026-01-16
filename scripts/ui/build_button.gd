## BuildButton - HUD button that opens the building menu.
## Positioned in bottom area for easy thumb access on mobile.
##
## Architecture: scripts/ui/build_button.gd
## Story: 3-4-create-building-menu-ui
class_name BuildButton
extends Control

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when the build button is pressed
signal pressed()

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _button: Button = $Button

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	if _button:
		_button.pressed.connect(_on_button_pressed)

	GameLogger.info("UI", "BuildButton initialized")


func _exit_tree() -> void:
	if _button and _button.pressed.is_connected(_on_button_pressed):
		_button.pressed.disconnect(_on_button_pressed)

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_button_pressed() -> void:
	pressed.emit()
	GameLogger.debug("UI", "Build button pressed")
