## Game scene - Main gameplay container
##
## This scene contains all gameplay systems and is the primary container for the game world.
## Loaded by Main scene or directly for testing purposes.
##
## Architecture Role:
## - Manages three core subsystems: World (game state), UI (player interface), Camera (viewport)
## - Implements AR4 composition-based entity architecture foundation
## - Provides integration points for EventBus (AR5) communication
## - Follows AR11 graceful error handling and AR18 null safety patterns
##
## Child Node Structure:
## - World (Node2D): Contains hex grid, entities, and game state (Epic 1+)
## - UI (CanvasLayer): HUD, menus, and player interaction (Epic 2+)
## - Camera (Camera2D): Pan/zoom controls and viewport management (Epic 1)
##
## Story 0.5 Additions:
## - EventBus connections for scene lifecycle events
## - Proper cleanup on _exit_tree
## - Scene loaded signal emission
##
## Future Integration Points:
## - Story 1.1: World node will host HexGrid system
## - Story 2.1: UI will display animal selection and stats
## - Story 1.3: Camera will implement touch pan/zoom controls
##
## @tutorial: See Architecture Doc - Game Scene Structure
class_name Game
extends Node


## References to core subsystem nodes
@onready var world: Node2D = $World
@onready var ui: CanvasLayer = $UI
@onready var camera: Camera2D = $Camera


## Track if scene has been fully initialized
var _initialized := false


## Initialize game scene and validate subsystems
## Implements AR11 error handling and AR18 null safety
func _ready() -> void:
	# AR18: Early return guard clause - verify node is in tree
	if not is_inside_tree():
		push_error("[Game] Node not in scene tree - initialization failed")
		return

	# AR11: Graceful error handling - validate subsystems
	if not _verify_subsystems():
		push_error("[Game] Critical subsystems missing - game cannot function")
		# AR11: Graceful degradation - continue but log error
		return

	# Connect to EventBus lifecycle signals (Story 0.5)
	_connect_eventbus_signals()

	# Configure Camera2D for game viewport
	_configure_camera()

	# Mark as initialized
	_initialized = true

	# Log success using Logger if available
	if is_instance_valid(Logger):
		Logger.info("Game", "Game scene loaded successfully")
		Logger.info("Game", "World, UI, and Camera subsystems ready")
	else:
		print("[Game] Game scene loaded successfully")
		print("[Game] World, UI, and Camera subsystems ready")


## Cleanup when scene is being removed from tree
## Disconnects all EventBus signals to prevent memory leaks
func _exit_tree() -> void:
	# Emit scene unloading signal before cleanup
	if is_instance_valid(EventBus):
		EventBus.scene_unloading.emit("game")

	# Disconnect all EventBus signals (Story 0.5)
	_disconnect_eventbus_signals()

	if is_instance_valid(Logger):
		Logger.info("Game", "Game scene unloading - cleanup complete")


## Verify all required child nodes exist
## Returns true if World, UI, and Camera are present
func _verify_subsystems() -> bool:
	# AR18: Null safety - check all critical child nodes
	var all_valid := true

	if not world:
		push_error("[Game] World node missing - cannot render game state")
		all_valid = false

	if not ui:
		push_error("[Game] UI node missing - player cannot interact")
		all_valid = false

	if not camera:
		push_error("[Game] Camera node missing - cannot display viewport")
		all_valid = false

	return all_valid


## Connect to EventBus signals for scene lifecycle events
func _connect_eventbus_signals() -> void:
	# AR18: Null safety guard
	if not is_instance_valid(EventBus):
		push_warning("[Game] EventBus not available - cannot connect signals")
		return

	# Connect to game state signals with signal verification
	if EventBus.has_signal("game_paused"):
		EventBus.game_paused.connect(_on_game_paused)
	else:
		push_warning("[Game] EventBus missing 'game_paused' signal")

	if EventBus.has_signal("game_resumed"):
		EventBus.game_resumed.connect(_on_game_resumed)
	else:
		push_warning("[Game] EventBus missing 'game_resumed' signal")


## Disconnect from EventBus signals during cleanup
func _disconnect_eventbus_signals() -> void:
	# AR18: Null safety guard
	if not is_instance_valid(EventBus):
		return

	# Safely disconnect all signals
	if EventBus.game_paused.is_connected(_on_game_paused):
		EventBus.game_paused.disconnect(_on_game_paused)

	if EventBus.game_resumed.is_connected(_on_game_resumed):
		EventBus.game_resumed.disconnect(_on_game_resumed)


## Configure Camera2D for mobile portrait viewport
func _configure_camera() -> void:
	# AR18: Null safety guard
	if not camera:
		return

	# Set camera as current for this scene
	camera.make_current()

	# Configure for 1080x1920 portrait
	camera.position = Vector2.ZERO

	# Set initial zoom level for portrait mode
	# Zoom out slightly to show more of the game world
	camera.zoom = Vector2(0.8, 0.8)

	# Set camera limits to prevent panning off-screen
	# These will be updated dynamically when world size is known (Story 1.1)
	# For now, set reasonable defaults
	camera.limit_left = -500
	camera.limit_right = 500
	camera.limit_top = -1000
	camera.limit_bottom = 1000

	# Enable camera smoothing for better feel
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0

	if is_instance_valid(Logger):
		Logger.debug("Game", "Camera configured: zoom=%.1f, limits set, smoothing enabled" % camera.zoom.x)


## Handle game pause event
func _on_game_paused() -> void:
	if is_instance_valid(Logger):
		Logger.debug("Game", "Game paused - subsystems notified")

	# Future: Pause animations, disable input, etc.


## Handle game resume event
func _on_game_resumed() -> void:
	if is_instance_valid(Logger):
		Logger.debug("Game", "Game resumed - subsystems notified")

	# Future: Resume animations, enable input, etc.


## Check if the game scene is fully initialized
## @return true if all subsystems are ready
func is_initialized() -> bool:
	return _initialized


## Get reference to World node for external access
## @return World node or null if not available
func get_world() -> Node2D:
	return world


## Get reference to UI node for external access
## @return UI node or null if not available
func get_ui() -> CanvasLayer:
	return ui


## Get reference to Camera node for external access
## @return Camera node or null if not available
func get_camera() -> Camera2D:
	return camera
