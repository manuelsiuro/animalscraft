## Manages milestone celebration popups.
## Listens to EventBus.milestone_reached, queues multiple milestones,
## and handles game pause/resume during celebrations.
##
## Add this as a child of the Game scene's UI CanvasLayer.
## The manager creates and displays MilestoneCelebrationPopup instances.
##
## Architecture: scripts/ui/gameplay/milestone_celebration_manager.gd
## Story: 6-6-display-milestone-celebrations
class_name MilestoneCelebrationManager
extends CanvasLayer

# =============================================================================
# PRELOADS
# =============================================================================

## Preload popup class for type checking
const MilestoneCelebrationPopupClass := preload("res://scripts/ui/gameplay/milestone_celebration_popup.gd")

# =============================================================================
# CONSTANTS
# =============================================================================

## Path to the popup scene
const POPUP_SCENE_PATH: String = "res://scenes/ui/gameplay/milestone_celebration_popup.tscn"

# =============================================================================
# STATE
# =============================================================================

## Queue of milestone IDs to celebrate (AC6)
var _celebration_queue: Array[String] = []

## Currently active popup (null if none)
## NOTE: Using Node type due to circular reference issues with class_name
var _active_popup: Node = null

## Whether we paused the game for celebration (AC7)
var _paused_for_celebration: bool = false

## Cached popup scene
var _popup_scene: PackedScene = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Set to high layer so it appears above game UI
	layer = 90

	# Load popup scene
	_popup_scene = load(POPUP_SCENE_PATH) as PackedScene
	if _popup_scene == null:
		GameLogger.error("MilestoneCelebrationManager", "Failed to load popup scene: %s" % POPUP_SCENE_PATH)
		return

	# Connect to EventBus (AC9)
	EventBus.milestone_reached.connect(_on_milestone_reached)

	GameLogger.info("MilestoneCelebrationManager", "Initialized")


func _exit_tree() -> void:
	# Disconnect from EventBus
	if EventBus.milestone_reached.is_connected(_on_milestone_reached):
		EventBus.milestone_reached.disconnect(_on_milestone_reached)

	# Clean up active popup
	if _active_popup and is_instance_valid(_active_popup):
		_active_popup.queue_free()
		_active_popup = null

	# Resume game if we paused it
	_resume_game_if_paused()

# =============================================================================
# PUBLIC API
# =============================================================================

## Get the number of queued milestones.
func get_queue_count() -> int:
	return _celebration_queue.size()


## Check if a celebration is currently active.
func is_celebrating() -> bool:
	return _active_popup != null and is_instance_valid(_active_popup) and _active_popup.visible


## Clear the celebration queue (for testing or emergency cancellation).
func clear_queue() -> void:
	_celebration_queue.clear()

# =============================================================================
# EVENT HANDLERS (AC9)
# =============================================================================

## Handle milestone reached event from EventBus.
func _on_milestone_reached(milestone_id: String) -> void:
	if milestone_id.is_empty():
		GameLogger.warn("MilestoneCelebrationManager", "Received empty milestone ID")
		return

	# Add to queue (AC6)
	_celebration_queue.append(milestone_id)
	GameLogger.debug("MilestoneCelebrationManager", "Queued milestone: %s (queue size: %d)" % [milestone_id, _celebration_queue.size()])

	# Show if no active popup
	if _active_popup == null:
		_show_next_celebration()

# =============================================================================
# PRIVATE METHODS - CELEBRATION FLOW (AC6, AC7, AC9)
# =============================================================================

## Show the next celebration from the queue.
func _show_next_celebration() -> void:
	if _celebration_queue.is_empty():
		_resume_game_if_paused()
		return

	# Get next milestone ID
	var milestone_id: String = _celebration_queue.pop_front()

	# Fetch milestone data (AC9)
	var milestone := MilestoneManager.get_milestone(milestone_id)
	if milestone == null:
		GameLogger.warn("MilestoneCelebrationManager", "Milestone not found: %s" % milestone_id)
		# Try next in queue
		_show_next_celebration()
		return

	# Pause game (AC7)
	_pause_game_for_celebration()

	# Create and show popup
	_active_popup = _create_popup()
	if _active_popup == null:
		GameLogger.error("MilestoneCelebrationManager", "Failed to create popup for: %s" % milestone_id)
		_show_next_celebration()
		return

	_active_popup.celebration_dismissed.connect(_on_celebration_dismissed)
	_active_popup.show_milestone(milestone)

	GameLogger.info("MilestoneCelebrationManager", "Showing celebration for: %s" % milestone.display_name)


## Create a new popup instance.
## @return The new popup instance or null if failed
func _create_popup() -> Node:
	if _popup_scene == null:
		return null

	var popup := _popup_scene.instantiate()
	if popup == null:
		return null

	add_child(popup)

	# Center the popup on screen
	if popup is Control:
		popup.anchors_preset = Control.PRESET_CENTER

	return popup


## Handle celebration dismissed signal.
func _on_celebration_dismissed() -> void:
	# Clean up current popup
	if _active_popup and is_instance_valid(_active_popup):
		_active_popup.celebration_dismissed.disconnect(_on_celebration_dismissed)
		_active_popup.queue_free()
	_active_popup = null

	# Process next in queue (AC6)
	# Use call_deferred to avoid issues with signal handlers
	call_deferred("_show_next_celebration")

# =============================================================================
# PRIVATE METHODS - PAUSE/RESUME (AC7)
# =============================================================================

## Pause the game for celebration.
func _pause_game_for_celebration() -> void:
	if _paused_for_celebration:
		return  # Already paused by us

	_paused_for_celebration = true
	EventBus.game_paused.emit()
	GameLogger.debug("MilestoneCelebrationManager", "Game paused for celebration")


## Resume the game if we paused it.
func _resume_game_if_paused() -> void:
	if not _paused_for_celebration:
		return  # We didn't pause it

	_paused_for_celebration = false
	EventBus.game_resumed.emit()
	GameLogger.debug("MilestoneCelebrationManager", "Game resumed after celebration")
