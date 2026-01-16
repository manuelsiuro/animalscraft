## WorkingState - Animal is working at a building.
## Handles energy drain, mood penalty, and building validity checks.
## Production timing is handled by GathererComponent, not this state.
##
## Architecture: scripts/entities/animals/animal_states/working_state.gd
## Story: 2-8-implement-animal-ai-state-machine
## Updated: 3-8-implement-resource-gathering (building validity, cleanup)
class_name WorkingState
extends BaseState

## Energy depletion rate per second (1 energy per 2 seconds)
const ENERGY_DRAIN_RATE: float = 0.5

## Mood penalty interval when working at low energy (seconds)
const MOOD_PENALTY_INTERVAL: float = 5.0

## Time accumulator for energy drain
var _work_time: float = 0.0

## Time accumulator for mood penalty when working at low energy
var _mood_penalty_timer: float = 0.0

## Reference to the building this animal is working at (Story 3-8)
var _assigned_building: Node = null


func enter() -> void:
	_work_time = 0.0
	_mood_penalty_timer = 0.0  # Reset mood penalty timer on enter

	if is_instance_valid(animal):
		# Get building reference from Animal (Story 3-8 - AC4.1)
		if animal.has_method("get_assigned_building"):
			_assigned_building = animal.get_assigned_building()

		# Play work animation if available
		var anim_player: AnimationPlayer = animal.get_node_or_null("Visual/AnimationPlayer") as AnimationPlayer
		if anim_player and anim_player.has_animation("work"):
			anim_player.play("work")

		var animal_id: String = ""
		if animal.has_method("get_animal_id"):
			animal_id = animal.get_animal_id()
		GameLogger.debug("WorkingState", "%s entered Working at %s" % [animal_id, _assigned_building])


func exit() -> void:
	_mood_penalty_timer = 0.0  # Reset mood penalty timer on exit

	if is_instance_valid(animal):
		var animal_id: String = ""
		if animal.has_method("get_animal_id"):
			animal_id = animal.get_animal_id()
		GameLogger.debug("WorkingState", "%s exiting Working" % animal_id)

		# Clear building reference in animal (Story 3-8 - AC4.5)
		if animal.has_method("clear_assigned_building"):
			animal.clear_assigned_building()

	# Clear local reference
	_assigned_building = null


func update(delta: float) -> void:
	if not is_instance_valid(animal):
		return

	# Story 3-8 AC4.6: Check building validity - if building freed, transition to IDLE (AC12)
	if _assigned_building != null and not is_instance_valid(_assigned_building):
		GameLogger.info("WorkingState", "Building destroyed - transitioning to IDLE")
		_assigned_building = null
		# Transition to IDLE via AIComponent
		if ai and ai.has_method("transition_to"):
			ai.transition_to(0)  # AIComponent.AnimalState.IDLE
		return

	var stats: Node = animal.get_node_or_null("StatsComponent")
	if not stats:
		return

	# Drain energy over time (AC7 - energy depletion triggers RESTING transition)
	_work_time += delta

	if _work_time >= (1.0 / ENERGY_DRAIN_RATE):
		_work_time = 0.0

		if stats.has_method("deplete_energy"):
			stats.deplete_energy(1)
			# Energy depletion triggers transition via signal
			# (handled by AIComponent._on_energy_changed)

	# Mood penalty when working at low energy (AC3)
	if stats.has_method("is_energy_low") and stats.is_energy_low():
		_mood_penalty_timer += delta
		if _mood_penalty_timer >= MOOD_PENALTY_INTERVAL:
			_mood_penalty_timer = 0.0
			if stats.has_method("decrease_mood"):
				stats.decrease_mood()
				var animal_id: String = ""
				if animal.has_method("get_animal_id"):
					animal_id = animal.get_animal_id()
				GameLogger.info("WorkingState", "%s mood decreased from exhaustion" % animal_id)
	else:
		# Reset mood penalty timer if energy is above low threshold
		_mood_penalty_timer = 0.0


func get_state_name() -> String:
	return "WorkingState"
