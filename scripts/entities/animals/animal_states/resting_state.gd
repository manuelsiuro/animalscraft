## RestingState - Animal is resting to recover energy.
## Gradually restores energy and improves mood.
##
## Architecture: scripts/entities/animals/animal_states/resting_state.gd
## Story: 2-8-implement-animal-ai-state-machine
class_name RestingState
extends BaseState

## Energy recovery rate per second
const ENERGY_RECOVERY_RATE: float = 0.33  # ~3 seconds per energy point

## Mood improvement interval (seconds)
const MOOD_IMPROVE_INTERVAL: float = 5.0

## Time accumulators
var _recovery_time: float = 0.0
var _mood_time: float = 0.0


func enter() -> void:
	_recovery_time = 0.0
	_mood_time = 0.0

	if is_instance_valid(animal):
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


func update(delta: float) -> void:
	if not is_instance_valid(animal):
		return

	var stats: Node = animal.get_node_or_null("StatsComponent")
	if not stats:
		return

	# Recover energy
	_recovery_time += delta
	if _recovery_time >= (1.0 / ENERGY_RECOVERY_RATE):
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


func get_state_name() -> String:
	return "RestingState"
