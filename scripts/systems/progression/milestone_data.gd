## Data resource defining a single milestone achievement.
##
## Milestones track player progress and can trigger unlock rewards.
## Each milestone has a type that determines how progress is measured.
##
## Architecture: scripts/systems/progression/milestone_data.gd
## Story: 6-5-implement-milestone-system
class_name MilestoneData
extends Resource

# =============================================================================
# ENUMS
# =============================================================================

## Type of milestone determining how progress is tracked
enum Type {
	POPULATION,   ## Triggered when animal count reaches threshold
	BUILDING,     ## Triggered on first placement of building type
	TERRITORY,    ## Triggered when claimed hex count reaches threshold
	COMBAT,       ## Triggered when combat win count reaches threshold
	PRODUCTION,   ## Triggered on first production of resource type
}

# =============================================================================
# EXPORTED PROPERTIES
# =============================================================================

## Unique identifier for this milestone (e.g., "pop_5", "first_farm")
@export var id: String = ""

## Display name shown to player (e.g., "Growing Community")
@export var display_name: String = ""

## Description of achievement (e.g., "Reach 5 animals in your village")
@export var description: String = ""

## Type of milestone determining tracking behavior
@export var type: Type = Type.POPULATION

## Threshold value for count-based milestones (POPULATION, TERRITORY, COMBAT)
## For BUILDING/PRODUCTION types, this is ignored (threshold is always 1)
@export var threshold: int = 0

## Trigger value for first-time milestones (BUILDING, PRODUCTION)
## For BUILDING: building type string (e.g., "farm", "mill")
## For PRODUCTION: output resource id (e.g., "bread")
## For count-based types, this is ignored
@export var trigger_value: String = ""

## Building types unlocked when this milestone is achieved
## Empty array if no unlocks
@export var unlock_rewards: Array[String] = []
