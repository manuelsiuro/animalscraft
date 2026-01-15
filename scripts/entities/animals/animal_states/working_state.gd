## WorkingState - Animal is working at a building.
## PLACEHOLDER: Full implementation in Story 3.8 (Resource Gathering)
##
## Architecture: scripts/entities/animals/animal_states/working_state.gd
## Story: 2-8-implement-animal-ai-state-machine
class_name WorkingState
extends BaseState

## Energy depletion rate per second (for testing)
const ENERGY_DRAIN_RATE: float = 0.5

## Time accumulator for energy drain
var _work_time: float = 0.0


func enter() -> void:
	_work_time = 0.0

	if is_instance_valid(animal):
		# Play work animation if available
		var anim_player: AnimationPlayer = animal.get_node_or_null("Visual/AnimationPlayer") as AnimationPlayer
		if anim_player and anim_player.has_animation("work"):
			anim_player.play("work")

		var animal_id: String = ""
		if animal.has_method("get_animal_id"):
			animal_id = animal.get_animal_id()
		GameLogger.debug("WorkingState", "%s entered Working (placeholder)" % animal_id)


func exit() -> void:
	if is_instance_valid(animal):
		var animal_id: String = ""
		if animal.has_method("get_animal_id"):
			animal_id = animal.get_animal_id()
		GameLogger.debug("WorkingState", "%s exiting Working" % animal_id)


func update(delta: float) -> void:
	# TODO: Story 3.8 - Full working implementation
	# - Check if building has required inputs
	# - Produce outputs on timer
	# - Handle production completion

	if not is_instance_valid(animal):
		return

	# Placeholder: Drain energy over time for testing
	_work_time += delta

	if _work_time >= (1.0 / ENERGY_DRAIN_RATE):
		_work_time = 0.0

		var stats: Node = animal.get_node_or_null("StatsComponent")
		if stats and stats.has_method("deplete_energy"):
			stats.deplete_energy(1)

			# Energy depletion triggers transition via signal
			# (handled by AIComponent._on_energy_changed)


func get_state_name() -> String:
	return "WorkingState"
