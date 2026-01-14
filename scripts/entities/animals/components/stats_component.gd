## StatsComponent - Holds and manages runtime animal stats.
## Separates runtime state from base stats resource.
##
## Architecture: scripts/entities/animals/components/stats_component.gd
## Story: 2-2-implement-animal-stats
class_name StatsComponent
extends Node

# =============================================================================
# ENUMS
# =============================================================================

## Mood states affecting stat effectiveness
enum Mood { HAPPY, NEUTRAL, SAD }

## Mood modifier multipliers
const MOOD_MODIFIERS := {
	Mood.HAPPY: 1.0,
	Mood.NEUTRAL: 0.85,
	Mood.SAD: 0.7
}

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when energy changes
signal energy_changed(current: int, max_energy: int)

## Emitted when mood changes
signal mood_changed(current_mood: String)

# =============================================================================
# PROPERTIES
# =============================================================================

## Reference to base stats resource (read-only, shared)
var _base_stats: AnimalStats

## Current energy (runtime value, can deplete and restore)
var _current_energy: int = 0

## Current mood state (runtime value)
var _current_mood: Mood = Mood.HAPPY

## Whether component has been initialized
var _initialized: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

## Initialize with animal stats resource.
## Sets up runtime values from base stats.
## @param animal_stats: The base stats resource for this animal type
func initialize(animal_stats: AnimalStats) -> void:
	if _initialized:
		GameLogger.warn("StatsComponent", "Already initialized")
		return

	_base_stats = animal_stats

	if animal_stats:
		_current_energy = animal_stats.energy
	else:
		_current_energy = 3  # Default fallback
		GameLogger.warn("StatsComponent", "Initialized without AnimalStats resource")

	_current_mood = Mood.HAPPY
	_initialized = true

	GameLogger.debug("StatsComponent", "Initialized: E%d/%d, Mood=%s" % [
		_current_energy, get_max_energy(), _mood_to_string(_current_mood)
	])


## Check if component is initialized
func is_initialized() -> bool:
	return _initialized

# =============================================================================
# ENERGY MANAGEMENT
# =============================================================================

## Get current energy level
func get_energy() -> int:
	return _current_energy


## Get maximum energy (from base stats)
func get_max_energy() -> int:
	if _base_stats:
		return _base_stats.energy
	return 3


## Deplete energy by specified amount.
## Clamps to 0 and emits signals.
## @param amount: Energy to deplete (positive integer)
func deplete_energy(amount: int) -> void:
	if amount <= 0:
		return

	var old_energy := _current_energy
	var max_energy := get_max_energy()
	_current_energy = maxi(_current_energy - amount, 0)

	if _current_energy != old_energy:
		energy_changed.emit(_current_energy, max_energy)
		GameLogger.debug("StatsComponent", "Energy depleted: %d → %d" % [old_energy, _current_energy])

		# Check for energy depleted condition
		if _current_energy == 0:
			_on_energy_depleted()


## Restore energy by specified amount.
## Clamps to max_energy and emits signals.
## @param amount: Energy to restore (positive integer)
func restore_energy(amount: int) -> void:
	if amount <= 0:
		return

	var old_energy := _current_energy
	var max_energy := get_max_energy()
	_current_energy = mini(_current_energy + amount, max_energy)

	if _current_energy != old_energy:
		energy_changed.emit(_current_energy, max_energy)
		GameLogger.debug("StatsComponent", "Energy restored: %d → %d" % [old_energy, _current_energy])


## Check if energy is fully depleted
func is_energy_depleted() -> bool:
	return _current_energy <= 0


## Check if energy is at maximum
func is_energy_full() -> bool:
	return _current_energy >= get_max_energy()


## Internal handler when energy reaches zero
func _on_energy_depleted() -> void:
	GameLogger.info("StatsComponent", "Energy depleted for animal")
	# Notify parent animal and EventBus
	var parent := get_parent()
	if parent:
		EventBus.animal_energy_depleted.emit(parent)

# =============================================================================
# MOOD MANAGEMENT
# =============================================================================

## Get current mood
func get_mood() -> Mood:
	return _current_mood


## Get current mood as string
func get_mood_string() -> String:
	return _mood_to_string(_current_mood)


## Set mood directly (with validation)
## @param mood: The new mood state
func set_mood(mood: Mood) -> void:
	if mood == _current_mood:
		return

	var old_mood := _current_mood
	_current_mood = mood

	var mood_string := _mood_to_string(mood)
	mood_changed.emit(mood_string)
	GameLogger.debug("StatsComponent", "Mood changed: %s → %s" % [
		_mood_to_string(old_mood), mood_string
	])

	# Notify EventBus
	var parent := get_parent()
	if parent:
		EventBus.animal_mood_changed.emit(parent, mood_string)


## Decrease mood by one step (Happy → Neutral → Sad)
func decrease_mood() -> void:
	match _current_mood:
		Mood.HAPPY:
			set_mood(Mood.NEUTRAL)
		Mood.NEUTRAL:
			set_mood(Mood.SAD)
		Mood.SAD:
			pass  # Already at lowest


## Increase mood by one step (Sad → Neutral → Happy)
func increase_mood() -> void:
	match _current_mood:
		Mood.SAD:
			set_mood(Mood.NEUTRAL)
		Mood.NEUTRAL:
			set_mood(Mood.HAPPY)
		Mood.HAPPY:
			pass  # Already at highest


## Get mood modifier multiplier
func get_mood_modifier() -> float:
	return MOOD_MODIFIERS.get(_current_mood, 1.0)


## Convert mood enum to string
func _mood_to_string(mood: Mood) -> String:
	match mood:
		Mood.HAPPY:
			return "happy"
		Mood.NEUTRAL:
			return "neutral"
		Mood.SAD:
			return "sad"
		_:
			return "unknown"


## Convert string to mood enum
static func string_to_mood(mood_string: String) -> Mood:
	match mood_string.to_lower():
		"happy":
			return Mood.HAPPY
		"neutral":
			return Mood.NEUTRAL
		"sad":
			return Mood.SAD
		_:
			return Mood.HAPPY  # Default fallback

# =============================================================================
# STAT ACCESSORS (BASE VALUES)
# =============================================================================

## Get base stats resource
func get_base_stats() -> AnimalStats:
	return _base_stats


## Get base speed stat
func get_speed() -> int:
	if _base_stats:
		return _base_stats.speed
	return 3


## Get base strength stat
func get_strength() -> int:
	if _base_stats:
		return _base_stats.strength
	return 3


## Get specialty string
func get_specialty() -> String:
	if _base_stats:
		return _base_stats.specialty
	return ""


## Get biome
func get_biome() -> String:
	if _base_stats:
		return _base_stats.biome
	return "plains"


## Get animal ID
func get_animal_id() -> String:
	if _base_stats:
		return _base_stats.animal_id
	return ""

# =============================================================================
# EFFECTIVE STATS (WITH MOOD MODIFIER)
# =============================================================================

## Get effective speed (base speed * mood modifier)
func get_effective_speed() -> float:
	return get_speed() * get_mood_modifier()


## Get effective strength (base strength * mood modifier)
func get_effective_strength() -> float:
	return get_strength() * get_mood_modifier()


## Get effective stat by name (for generic access)
## @param stat_name: "speed", "strength", or "energy"
func get_effective_stat(stat_name: String) -> float:
	match stat_name.to_lower():
		"speed":
			return get_effective_speed()
		"strength":
			return get_effective_strength()
		"energy":
			return float(_current_energy)
		_:
			GameLogger.warn("StatsComponent", "Unknown stat: %s" % stat_name)
			return 0.0

# =============================================================================
# DEBUG / STRING
# =============================================================================

func _to_string() -> String:
	return "StatsComponent<E%d/%d S%d St%d M=%s>" % [
		_current_energy, get_max_energy(), get_speed(), get_strength(),
		_mood_to_string(_current_mood)
	]
