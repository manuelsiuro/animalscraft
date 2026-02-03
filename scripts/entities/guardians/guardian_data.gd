## GuardianData - Resource defining stats and configuration for guardian bosses.
## Extends AnimalStats with guardian-specific fields.
## Guardians are powerful biome bosses that unlock new areas when defeated.
##
## Architecture: scripts/entities/guardians/guardian_data.gd
## Story: 7-2-implement-alpha-fox-guardian
class_name GuardianData
extends AnimalStats

# =============================================================================
# GUARDIAN-SPECIFIC PROPERTIES
# =============================================================================

## Unique identifier for this guardian (e.g., "alpha_fox")
@export var guardian_id: String = ""

## ID of the biome this guardian unlocks when defeated (e.g., "forest")
@export var unlocks_biome: String = ""

## Difficulty rating for UI display (e.g., "Easy", "Medium", "Hard")
@export var difficulty_rating: String = "Easy"

## Description of the reward for defeating this guardian
@export var reward_description: String = ""

## Hex coordinates where this guardian spawns (relative to biome border)
@export var spawn_hex: Vector2i = Vector2i.ZERO

## Milestone ID that triggers this guardian's spawn
@export var spawn_milestone: String = ""

# =============================================================================
# VALIDATION
# =============================================================================

## Check if this guardian data is valid (has required fields).
func is_valid() -> bool:
	return guardian_id != "" and unlocks_biome != "" and super.is_valid()

# =============================================================================
# STRING REPRESENTATION
# =============================================================================

func _to_string() -> String:
	return "GuardianData<%s: E%d S%d St%d → %s>" % [guardian_id, energy, speed, strength, unlocks_biome]
