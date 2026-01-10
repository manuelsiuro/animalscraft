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

	print("[Game] Game scene loaded successfully")
	print("[Game] World, UI, and Camera subsystems ready")


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
