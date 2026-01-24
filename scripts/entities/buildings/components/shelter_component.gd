## ShelterComponent - Component for shelter buildings providing animal rest recovery bonus.
## Manages resting animals, capacity, and 2x energy recovery multiplier.
## Emits EventBus signals for shelter enter/leave/capacity changes.
##
## Architecture: scripts/entities/buildings/components/shelter_component.gd
## Story: 5-11-create-shelter-building-for-resting
class_name ShelterComponent
extends Node

# =============================================================================
# CONSTANTS
# =============================================================================

## Energy recovery multiplier for animals resting in shelter (2x normal rate)
const RECOVERY_MULTIPLIER: float = 2.0

## Maximum number of animals that can rest in a shelter
const MAX_CAPACITY: int = 4

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when an animal enters this shelter
signal animal_entered(animal: Node)

## Emitted when an animal leaves this shelter
signal animal_left(animal: Node)

## Emitted when shelter reaches full capacity
signal capacity_reached()

## Emitted when shelter has capacity available after being full
signal capacity_available()

# =============================================================================
# PROPERTIES
# =============================================================================

## Array of animals currently resting in this shelter
var _resting_animals: Array[Node] = []

## Reference to parent Building node (or mock node for testing)
var _building: Node = null

## Whether component has been initialized
var _initialized: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Defer initialization to allow parent to be fully ready
	call_deferred("_initialize")


func _initialize() -> void:
	var parent := get_parent()
	if not parent:
		GameLogger.error("ShelterComponent", "No parent node found")
		return

	_building = parent
	_initialized = true

	var building_id: String = parent.get_building_id() if parent.has_method("get_building_id") else "unknown"
	GameLogger.debug("ShelterComponent", "Initialized for %s" % building_id)


## External initialization call from Building.initialize() if needed
func initialize(building: Node) -> void:
	if _initialized:
		return

	_building = building
	_initialized = true
	var building_id: String = building.get_building_id() if building and building.has_method("get_building_id") else "unknown"
	GameLogger.debug("ShelterComponent", "Initialized externally for %s" % building_id)

# =============================================================================
# PUBLIC API
# =============================================================================

## Check if component is initialized
func is_initialized() -> bool:
	return _initialized


## Get the energy recovery multiplier for this shelter.
## Base is 2.0 (shelter bonus), with Hospital adds additional 2x (total 4x).
## @return Recovery multiplier (2.0 base, or 4.0 with Hospital bonus - Story 6-8)
func get_recovery_multiplier() -> float:
	var base_multiplier := RECOVERY_MULTIPLIER
	# Apply Hospital bonus if available (Story 6-8)
	if is_instance_valid(UpgradeBonusManager):
		base_multiplier *= UpgradeBonusManager.get_rest_multiplier()
	return base_multiplier


## Check if shelter is at full capacity
## @return true if 4 animals are resting
func is_full() -> bool:
	return _resting_animals.size() >= MAX_CAPACITY


## Check if shelter has capacity for more animals
## @return true if fewer than 4 animals are resting
func has_capacity() -> bool:
	return _resting_animals.size() < MAX_CAPACITY


## Get current number of resting animals
## @return count of animals currently in shelter
func get_occupancy() -> int:
	return _resting_animals.size()


## Get maximum capacity
## @return MAX_CAPACITY (4)
func get_max_capacity() -> int:
	return MAX_CAPACITY


## Get array of animals currently resting in shelter
## @return copy of resting animals array
func get_resting_animals() -> Array[Node]:
	return _resting_animals.duplicate()


## Add an animal to rest in this shelter
## @param animal The Animal node to add
## @return true if animal was added, false if shelter is full
func add_resting_animal(animal: Node) -> bool:
	if not is_instance_valid(animal):
		GameLogger.warn("ShelterComponent", "Cannot add invalid animal")
		return false

	if is_full():
		GameLogger.debug("ShelterComponent", "Shelter is full, cannot add animal")
		return false

	# Check if animal is already resting here
	if animal in _resting_animals:
		GameLogger.warn("ShelterComponent", "Animal already resting in this shelter")
		return false

	_resting_animals.append(animal)

	var animal_id := _get_animal_id(animal)
	GameLogger.info("ShelterComponent", "Animal %s entered shelter (%d/%d)" % [
		animal_id, _resting_animals.size(), MAX_CAPACITY
	])

	# Emit local signal
	animal_entered.emit(animal)

	# Emit EventBus signal (deferred for safe signal ordering)
	call_deferred("_emit_entered_signal", animal)

	# Check if we just reached capacity
	if is_full():
		capacity_reached.emit()
		call_deferred("_emit_capacity_reached_signal")

	return true


## Remove an animal from this shelter
## @param animal The Animal node to remove
func remove_resting_animal(animal: Node) -> void:
	if not is_instance_valid(animal):
		# Still try to remove if we have a reference
		var idx := _resting_animals.find(animal)
		if idx >= 0:
			_resting_animals.remove_at(idx)
		return

	if animal not in _resting_animals:
		return

	var was_full := is_full()
	_resting_animals.erase(animal)

	var animal_id := _get_animal_id(animal)
	GameLogger.info("ShelterComponent", "Animal %s left shelter (%d/%d)" % [
		animal_id, _resting_animals.size(), MAX_CAPACITY
	])

	# Emit local signal
	animal_left.emit(animal)

	# Emit EventBus signal (deferred for safe signal ordering)
	call_deferred("_emit_left_signal", animal)

	# Check if we just freed a slot from full capacity
	if was_full and has_capacity():
		capacity_available.emit()
		call_deferred("_emit_capacity_available_signal")


## Remove all animals from shelter (for destruction/cleanup)
## Each animal will receive null shelter reference and rest outdoors
func remove_all_animals() -> void:
	# Copy array since we'll be modifying it
	var animals_to_remove := _resting_animals.duplicate()

	for animal in animals_to_remove:
		remove_resting_animal(animal)

	GameLogger.info("ShelterComponent", "All animals removed from shelter")

# =============================================================================
# SIGNAL EMISSION HELPERS (deferred for safe ordering)
# =============================================================================

func _emit_entered_signal(animal: Node) -> void:
	if is_instance_valid(_building):
		EventBus.animal_entered_shelter.emit(animal, _building)


func _emit_left_signal(animal: Node) -> void:
	if is_instance_valid(_building):
		EventBus.animal_left_shelter.emit(animal, _building)


func _emit_capacity_reached_signal() -> void:
	if is_instance_valid(_building):
		EventBus.shelter_capacity_reached.emit(_building)


func _emit_capacity_available_signal() -> void:
	if is_instance_valid(_building):
		EventBus.shelter_capacity_available.emit(_building)

# =============================================================================
# HELPER METHODS
# =============================================================================

func _get_animal_id(animal: Node) -> String:
	if animal.has_method("get_animal_id"):
		return animal.get_animal_id()
	return "unknown"

# =============================================================================
# CLEANUP
# =============================================================================

## Clean up component before building destruction
func cleanup() -> void:
	# Notify all resting animals about shelter destruction (AC: 23)
	# This removes them from shelter so they can rest outdoors
	remove_all_animals()

	_resting_animals.clear()
	_building = null
	_initialized = false
