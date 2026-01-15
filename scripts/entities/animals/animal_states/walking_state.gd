## WalkingState - Animal is moving toward destination.
## MovementComponent handles actual movement, we manage state.
##
## Architecture: scripts/entities/animals/animal_states/walking_state.gd
## Story: 2-8-implement-animal-ai-state-machine
class_name WalkingState
extends BaseState


func enter() -> void:
	# Walk animation handled by MovementComponent
	if is_instance_valid(animal):
		var animal_id: String = ""
		if animal.has_method("get_animal_id"):
			animal_id = animal.get_animal_id()
		GameLogger.debug("WalkingState", "%s entered Walking" % animal_id)


func exit() -> void:
	if is_instance_valid(animal):
		var animal_id: String = ""
		if animal.has_method("get_animal_id"):
			animal_id = animal.get_animal_id()
		GameLogger.debug("WalkingState", "%s exiting Walking" % animal_id)


func update(_delta: float) -> void:
	# Movement handled by MovementComponent
	# Check if movement was interrupted externally
	if not is_instance_valid(animal):
		return

	var movement: Node = animal.get_node_or_null("MovementComponent")
	if movement and movement.has_method("is_moving"):
		if not movement.is_moving():
			# Movement ended but we didn't get signal - transition to Idle
			if is_instance_valid(ai) and ai.has_method("transition_to"):
				ai.transition_to(ai.AnimalState.IDLE)


func get_state_name() -> String:
	return "WalkingState"
