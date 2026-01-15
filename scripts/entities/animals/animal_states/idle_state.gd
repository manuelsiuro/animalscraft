## IdleState - Animal is waiting for assignment.
## Plays idle animation after brief settle delay for "alive" feel.
##
## Architecture: scripts/entities/animals/animal_states/idle_state.gd
## Story: 2-8-implement-animal-ai-state-machine
class_name IdleState
extends BaseState

## [PARTY: Samus] Settle delay before idle animation for "alive" feel
const SETTLE_DELAY: float = 0.2


func enter() -> void:
	if is_instance_valid(animal):
		var animal_id: String = ""
		if animal.has_method("get_animal_id"):
			animal_id = animal.get_animal_id()
		GameLogger.debug("IdleState", "%s entered Idle" % animal_id)

	# [PARTY: Samus] Use tween for settle delay - doesn't require update()
	# This works with Link's optimization that skips idle state updates
	if is_instance_valid(animal):
		var anim_player: AnimationPlayer = animal.get_node_or_null("Visual/AnimationPlayer") as AnimationPlayer
		if anim_player and anim_player.has_animation("idle"):
			# Create one-shot timer via tween for settle delay
			var tween := animal.create_tween()
			tween.tween_interval(SETTLE_DELAY)
			tween.tween_callback(func():
				if is_instance_valid(anim_player):
					anim_player.play("idle")
			)


func exit() -> void:
	if is_instance_valid(animal):
		var animal_id: String = ""
		if animal.has_method("get_animal_id"):
			animal_id = animal.get_animal_id()
		GameLogger.debug("IdleState", "%s exiting Idle" % animal_id)


func update(_delta: float) -> void:
	# [PARTY: Link] Idle state is passive - _process() skips this entirely
	# No update logic needed - external triggers handle transitions
	pass


func get_state_name() -> String:
	return "IdleState"
