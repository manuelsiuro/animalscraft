## BaseState - Abstract base class for animal AI states.
## Each state implements enter(), exit(), and update() methods.
##
## Architecture: scripts/entities/animals/animal_states/base_state.gd
## Story: 2-8-implement-animal-ai-state-machine
class_name BaseState
extends RefCounted

## Reference to AIComponent
var ai: Node

## Reference to parent Animal
var animal: Node


## Initialize state with references
func _init(p_ai: Node, p_animal: Node) -> void:
	ai = p_ai
	animal = p_animal


## Called when entering this state
func enter() -> void:
	pass  # Override in subclass


## Called when exiting this state
func exit() -> void:
	pass  # Override in subclass


## Called every frame while in this state
func update(_delta: float) -> void:
	pass  # Override in subclass


## Get state name for debugging
func get_state_name() -> String:
	return "BaseState"
