## StatsComponent - Holds and manages runtime animal stats.
## Stub implementation - full functionality in Story 2-2.
##
## Architecture: scripts/entities/animals/components/stats_component.gd
## Story: 2-1-create-animal-entity-structure (stub)
## Full Implementation: 2-2-implement-animal-stats
class_name StatsComponent
extends Node

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

## Reference to base stats resource
var _base_stats: AnimalStats

## Current energy (runtime value, can change)
var _current_energy: int = 0

## Current mood state
var _current_mood: String = "happy"

# =============================================================================
# LIFECYCLE
# =============================================================================

## Initialize with animal stats resource
func initialize(animal_stats: AnimalStats) -> void:
	_base_stats = animal_stats
	if animal_stats:
		_current_energy = animal_stats.energy
	else:
		_current_energy = 3  # Default fallback

# =============================================================================
# PUBLIC API (STUB)
# =============================================================================

## Get base stats resource
func get_base_stats() -> AnimalStats:
	return _base_stats


## Get current energy level
func get_energy() -> int:
	return _current_energy


## Get max energy (from base stats)
func get_max_energy() -> int:
	if _base_stats:
		return _base_stats.energy
	return 3


## Get current mood
func get_mood() -> String:
	return _current_mood


## Modify energy (stub - full implementation in Story 2-2)
func modify_energy(amount: int) -> void:
	var max_energy := get_max_energy()
	_current_energy = clampi(_current_energy + amount, 0, max_energy)
	energy_changed.emit(_current_energy, max_energy)


## Set mood (stub - full implementation in Story 2-2)
func set_mood(mood: String) -> void:
	_current_mood = mood
	mood_changed.emit(mood)
