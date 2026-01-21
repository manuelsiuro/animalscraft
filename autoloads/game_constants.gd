## Game-wide constants for AnimalsCraft.
## Autoload singleton - access via GameConstants.CONSTANT_NAME
##
## Architecture: autoloads/game_constants.gd
## Order: 1 (no dependencies)
## Source: game-architecture.md#Configuration
## NOTE: No class_name to avoid conflict with autoload singleton
extends Node

# =============================================================================
# HEX GRID CONSTANTS
# =============================================================================

## Size of each hex tile in pixels (pointy-top orientation)
const HEX_SIZE: float = 64.0

## Default map dimensions (can be overridden by biome configs)
const DEFAULT_MAP_WIDTH: int = 40
const DEFAULT_MAP_HEIGHT: int = 30

# =============================================================================
# ENTITY LIMITS
# =============================================================================

## Maximum animals allowed in the game world
const MAX_ANIMALS: int = 200

## Maximum buildings allowed in the game world
const MAX_BUILDINGS: int = 100

## Maximum workers that can be assigned to a single building
const MAX_WORKERS_PER_BUILDING: int = 5

# =============================================================================
# PATHFINDING CONSTANTS
# =============================================================================

## Maximum path requests processed per frame (performance limit)
const MAX_PATH_REQUESTS_PER_FRAME: int = 50

## Maximum path length before giving up
const MAX_PATH_LENGTH: int = 100

## Path cache TTL in seconds
const PATH_CACHE_TTL: float = 30.0

# =============================================================================
# SAVE SYSTEM CONSTANTS
# =============================================================================

## Auto-save interval in seconds
const AUTOSAVE_INTERVAL: float = 60.0

## Maximum number of save slots
const MAX_SAVE_SLOTS: int = 3

## Current save schema version
const SAVE_SCHEMA_VERSION: int = 1

## Save file directory
const SAVE_DIRECTORY: String = "user://saves/"

## Emergency save filename
const EMERGENCY_SAVE_FILE: String = "emergency_save.json"

# =============================================================================
# CAMERA CONSTANTS
# =============================================================================

## Minimum zoom level (zoomed out - overview)
const CAMERA_ZOOM_MIN: float = 0.5

## Maximum zoom level (zoomed in - detail)
const CAMERA_ZOOM_MAX: float = 2.0

## Default zoom level
const CAMERA_ZOOM_DEFAULT: float = 1.0

## Camera pan speed multiplier
const CAMERA_PAN_SPEED: float = 1.0

## Camera smooth follow lerp weight
const CAMERA_SMOOTH_LERP: float = 5.0

# =============================================================================
# COMBAT CONSTANTS
# =============================================================================

## Minimum team size for combat
const COMBAT_MIN_TEAM_SIZE: int = 1

## Maximum team size for combat
const COMBAT_MAX_TEAM_SIZE: int = 5

## Defense multiplier in combat formula
const COMBAT_DEFENSE_MULTIPLIER: float = 0.7

## Random variance in attack power (as percentage)
const COMBAT_RANDOM_VARIANCE: float = 0.2

# =============================================================================
# RESOURCE CONSTANTS
# =============================================================================

## Default maximum stack size for resources without explicit limit
const DEFAULT_RESOURCE_STACK_SIZE: int = 999

## Threshold for low resource warnings (for future UI alerts)
const RESOURCE_LOW_THRESHOLD: int = 10

# =============================================================================
# STORAGE CONSTANTS (Story 3-3)
# =============================================================================

## Storage warning threshold (emit signal at 80% capacity)
const STORAGE_WARNING_THRESHOLD: float = 0.8

## Storage warning reset threshold (reset warning when below 70%)
## Uses hysteresis to prevent signal spam
const STORAGE_WARNING_RESET_THRESHOLD: float = 0.7

## Default village storage capacity per resource type (without storage buildings)
const DEFAULT_VILLAGE_STORAGE_CAPACITY: int = 100

## Storage capacity bonus from Stockpile building
const STOCKPILE_STORAGE_BONUS: int = 50

# =============================================================================
# PRODUCTION CONSTANTS
# =============================================================================

## Base production time multiplier
const PRODUCTION_TIME_MULTIPLIER: float = 1.0

## Energy cost per production cycle
const PRODUCTION_ENERGY_COST: int = 1

# =============================================================================
# PROGRESSION CONSTANTS
# =============================================================================

## Territory claim percentage to unlock next biome
const BIOME_UNLOCK_PERCENTAGE: float = 0.8

## Starting animals count
const STARTING_ANIMALS: int = 2

# =============================================================================
# AUDIO CONSTANTS
# =============================================================================

## Default music volume (0.0 to 1.0)
const DEFAULT_MUSIC_VOLUME: float = 0.8

## Default SFX volume (0.0 to 1.0)
const DEFAULT_SFX_VOLUME: float = 1.0

## Music fade duration in seconds
const MUSIC_FADE_DURATION: float = 1.0

# =============================================================================
# DEBUG CONSTANTS (Development Only)
# =============================================================================

## Enable debug overlay in release builds via hidden activation
const DEBUG_HIDDEN_ACTIVATION_TAPS: int = 3

## Debug overlay update interval in seconds
const DEBUG_UPDATE_INTERVAL: float = 0.5

# =============================================================================
# SELECTION CONSTANTS (Story 2-3)
# =============================================================================

## Maximum time for a touch to count as a tap (milliseconds)
## Mobile-friendly default (300ms) accommodates players of all ages
const TAP_MAX_DURATION_MS: int = 300

## Maximum movement distance for a touch to count as a tap (pixels)
## Beyond this threshold, the touch is treated as a drag/pan
const TAP_MAX_DISTANCE_PX: float = 10.0

## Default tap radius for selectable entities (pixels)
## Used to determine if a tap hits an entity
const SELECTION_TAP_RADIUS: float = 32.0

# =============================================================================
# UI UTILITY FUNCTIONS
# =============================================================================

## Get emoji icon for animal type (used in combat UI and other displays).
## @param animal_type The animal type string (e.g., "rabbit", "fox")
## @return The emoji icon for the animal type, or default paw icon
static func get_animal_icon(animal_type: String) -> String:
	match animal_type:
		"rabbit":
			return "🐰"
		"fox":
			return "🦊"
		"deer":
			return "🦌"
		"bear":
			return "🐻"
		"wolf":
			return "🐺"
		_:
			return "🐾"
