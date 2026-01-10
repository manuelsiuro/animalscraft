## Main scene entry point for AnimalsCraft
##
## This is the application's primary entry point, loaded first when the game starts.
## It serves as the root scene for the entire application lifecycle.
##
## Architecture Role:
## - Initializes core systems and validates autoloads are ready
## - Provides scene transition entry point (via GameManager in future stories)
## - Implements graceful error handling per AR11 (signal-based, never crash)
## - Follows AR18 null safety with early return guard clauses
##
## Future Integration Points:
## - Story 0.2: Will verify all 8 autoloads are initialized
## - Story 0.5: Will handle scene transitions via GameManager
## - Epic 6: Will integrate main menu and save/load flow
##
## @tutorial: See Architecture Doc - Main Scene Structure
class_name Main
extends Node


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

	print("[Main] AnimalsCraft v0.1.0 initialized")
	print("[Main] Project Foundation - Story 0.1 complete")


## Verify expected scene structure exists
## Returns true if all required nodes are present
func _verify_scene_structure() -> bool:
	# AR18: Null safety - check all expected child nodes
	# Note: Story 0.1 has minimal structure; this will expand in Story 0.2+

	# Validate we're the root node
	if get_parent() != get_tree().root:
		push_error("[Main] Main scene must be root node")
		return false

	return true
