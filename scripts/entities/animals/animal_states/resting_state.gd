## RestingState - Animal is resting to recover energy.
## Gradually restores energy and improves mood.
## Supports 2x recovery rate when resting in a Shelter (Story 5-11).
##
## Architecture: scripts/entities/animals/animal_states/resting_state.gd
## Story: 2-8-implement-animal-ai-state-machine, 5-11-create-shelter-building-for-resting
class_name RestingState
extends BaseState

## Base energy recovery rate per second (outdoor resting)
const BASE_ENERGY_RECOVERY_RATE: float = 0.33  # ~3 seconds per energy point

## Mood improvement interval (seconds)
const MOOD_IMPROVE_INTERVAL: float = 5.0

## Time accumulators
var _recovery_time: float = 0.0
var _mood_time: float = 0.0

## Effective recovery multiplier (1.0 outdoor, 2.0 in shelter) (Story 5-11)
var _recovery_multiplier: float = 1.0

## Reference to shelter if resting in one (Story 5-11)
var _shelter: Node = null


func enter() -> void:
	_recovery_time = 0.0
	_mood_time = 0.0
	_recovery_multiplier = 1.0
	_shelter = null

	if is_instance_valid(animal):
		# Check if animal has a shelter assignment (Story 5-11)
		_shelter = _get_assigned_shelter()
		if _shelter and _shelter.has_method("get_recovery_multiplier"):
			_recovery_multiplier = _shelter.get_recovery_multiplier()  # 2.0 in shelter
			var animal_id: String = animal.get_animal_id() if animal.has_method("get_animal_id") else "unknown"
			GameLogger.info("RestingState", "%s resting in shelter - %.1fx recovery rate" % [animal_id, _recovery_multiplier])
		else:
			_recovery_multiplier = 1.0  # Outdoor rest

		# Play rest animation if available
		var anim_player: AnimationPlayer = animal.get_node_or_null("Visual/AnimationPlayer") as AnimationPlayer
		if anim_player:
			if anim_player.has_animation("rest"):
				anim_player.play("rest")
			elif anim_player.has_animation("idle"):
				anim_player.play("idle")

		# Emit resting signal
		if is_instance_valid(EventBus):
			EventBus.animal_resting.emit(animal)

		var animal_id: String = ""
		if animal.has_method("get_animal_id"):
			animal_id = animal.get_animal_id()
		GameLogger.info("RestingState", "%s entered Resting - recovering energy" % animal_id)


func exit() -> void:
	if is_instance_valid(animal):
		var animal_id: String = ""
		if animal.has_method("get_animal_id"):
			animal_id = animal.get_animal_id()

		# Only emit recovery signal if energy is actually full (AC4)
		var stats: Node = animal.get_node_or_null("StatsComponent")
		var fully_recovered: bool = false
		if stats and stats.has_method("is_energy_full"):
			fully_recovered = stats.is_energy_full()

		if fully_recovered:
			if is_instance_valid(EventBus):
				EventBus.animal_recovered.emit(animal)
			GameLogger.info("RestingState", "%s fully recovered - exiting Resting" % animal_id)
		else:
			GameLogger.info("RestingState", "%s interrupted rest - exiting Resting (not fully recovered)" % animal_id)

	# Clear shelter reference (Story 5-11)
	_shelter = null
	_recovery_multiplier = 1.0


func update(delta: float) -> void:
	if not is_instance_valid(animal):
		return

	var stats: Node = animal.get_node_or_null("StatsComponent")
	if not stats:
		return

	# Calculate effective recovery rate with shelter multiplier (Story 5-11)
	var effective_rate: float = BASE_ENERGY_RECOVERY_RATE * _recovery_multiplier
	# Outdoor: 0.33 * 1.0 = 0.33 energy/sec (~3 sec per point)
	# Shelter: 0.33 * 2.0 = 0.66 energy/sec (~1.5 sec per point)

	# Recover energy
	_recovery_time += delta
	if _recovery_time >= (1.0 / effective_rate):
		_recovery_time = 0.0
		if stats.has_method("restore_energy"):
			stats.restore_energy(1)

	# Improve mood periodically
	_mood_time += delta
	if _mood_time >= MOOD_IMPROVE_INTERVAL:
		_mood_time = 0.0
		if stats.has_method("increase_mood"):
			stats.increase_mood()

	# Check if fully recovered
	if stats.has_method("is_energy_full") and stats.is_energy_full():
		if is_instance_valid(ai) and ai.has_method("transition_to"):
			ai.transition_to(ai.AnimalState.IDLE)


## Get the assigned shelter for this animal (Story 5-11)
## @return ShelterComponent node or null if not assigned to a shelter
func _get_assigned_shelter() -> Node:
	if not is_instance_valid(animal):
		return null

	# Check if animal has a target building that is a shelter
	# This is set by the ShelterSeekingSystem when routing to shelter
	if animal.has_method("get_target_building"):
		var target_building: Node = animal.get_target_building()
		if is_instance_valid(target_building) and target_building.has_method("get_shelter"):
			var shelter_comp: Node = target_building.get_shelter()
			if shelter_comp and shelter_comp.has_method("is_initialized") and shelter_comp.is_initialized():
				return shelter_comp

	# Alternative: Check if animal is currently a worker at a shelter building
	if animal.has_method("get_assigned_building"):
		var assigned: Node = animal.get_assigned_building()
		if is_instance_valid(assigned) and assigned.has_method("is_shelter") and assigned.is_shelter():
			return assigned.get_shelter()

	return null


## Get current recovery multiplier (for testing/debugging)
func get_recovery_multiplier() -> float:
	return _recovery_multiplier


func get_state_name() -> String:
	return "RestingState"
