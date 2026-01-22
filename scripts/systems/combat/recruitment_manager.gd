## RecruitmentManager - Handles animal recruitment after combat victories.
## Creates player animals from captured wild animals and adds them to the village.
## Uses AnimalFactory for creation and emits EventBus signals for cross-system communication.
##
## All methods are static - this is a pure utility class with no instance state.
## Signal emission uses call_deferred to ensure correct ordering:
##   animal_spawned (from Animal) → animal_recruited → recruitment_completed
##
## Architecture: scripts/systems/combat/recruitment_manager.gd
## Parent: Static utility class (never instantiated)
## Story: 5-8-implement-animal-capture
class_name RecruitmentManager
extends Object

# =============================================================================
# CONSTANTS
# =============================================================================

## Default spawn location for recruited animals (player's home hex)
const HOME_HEX := Vector2i(0, 0)

## Fallback spawn location if home hex is blocked
const FALLBACK_HEX := Vector2i(1, 0)

# =============================================================================
# PUBLIC API
# =============================================================================

## Recruit animals of specified types and spawn them at the given hex.
## Handles unknown animal types gracefully by skipping them with a warning.
##
## @param animal_types Array of animal type strings to recruit (e.g., ["rabbit", "fox", "rabbit"])
## @param spawn_hex The HexCoord where animals should spawn
## @param scene_parent The node to add animals as children (typically WorldManager)
## @return Array of successfully recruited Animal nodes
static func recruit_animals(animal_types: Array, spawn_hex: HexCoord, scene_parent: Node) -> Array:
	var recruited: Array = []

	if animal_types.is_empty():
		if is_instance_valid(GameLogger):
			GameLogger.info("RecruitmentManager", "No animals to recruit (empty selection)")
		EventBus.recruitment_completed.emit(0)
		return recruited

	if spawn_hex == null:
		spawn_hex = HexCoord.new(HOME_HEX.x, HOME_HEX.y)
		if is_instance_valid(GameLogger):
			GameLogger.warn("RecruitmentManager", "Null spawn hex, using home hex (0,0)")

	if not is_instance_valid(scene_parent):
		if is_instance_valid(GameLogger):
			GameLogger.error("RecruitmentManager", "Cannot recruit animals: scene_parent is invalid")
		return recruited

	# Process each animal type
	for animal_type in animal_types:
		if animal_type is not String:
			if is_instance_valid(GameLogger):
				GameLogger.warn("RecruitmentManager", "Skipping non-string animal type: %s" % str(animal_type))
			continue

		# Check if animal type is available
		if not AnimalFactory.has_animal_type(animal_type):
			if is_instance_valid(GameLogger):
				GameLogger.warn("RecruitmentManager", "Unknown animal type '%s' skipped (not in AnimalFactory)" % animal_type)
			continue

		# Create animal using factory
		var animal := AnimalFactory.create_animal(animal_type, spawn_hex)
		if not animal:
			if is_instance_valid(GameLogger):
				GameLogger.warn("RecruitmentManager", "Failed to create animal of type: %s" % animal_type)
			continue

		# Add to scene tree (this triggers Animal._ready() which adds to "animals" group)
		scene_parent.add_child(animal)

		# Defensive: Ensure animal is in "animals" group (Task 2.6 requirement)
		# Use call_deferred to run AFTER Animal._ready() completes
		animal.add_to_group.call_deferred("animals")

		recruited.append(animal)

		# Emit animal_recruited signal using call_deferred to ensure correct order:
		# Signal order: animal_spawned (from Animal.initialize) → animal_recruited → recruitment_completed
		# AnimalFactory.create_animal() schedules initialize() via call_deferred, so
		# our call_deferred runs AFTER, maintaining FIFO order.
		EventBus.animal_recruited.emit.call_deferred(animal_type, animal)

		if is_instance_valid(GameLogger):
			GameLogger.info("RecruitmentManager", "Recruited %s at %s" % [animal_type, spawn_hex])

	# Emit batch completion signal (deferred to fire after all animal_recruited signals)
	EventBus.recruitment_completed.emit.call_deferred(recruited.size())

	if is_instance_valid(GameLogger):
		GameLogger.info("RecruitmentManager", "Recruitment complete: %d animals recruited" % recruited.size())

	return recruited


## Get the player's spawn hex location.
## Returns home hex (0,0). Simplified implementation per story requirements.
## Future: Could check for blocking and use fallback (1,0).
##
## @return HexCoord for spawning at player's home location
static func get_player_spawn_hex() -> HexCoord:
	# Simple implementation per story requirements:
	# Return home hex (0,0); blocking check deferred to future story if needed
	return HexCoord.new(HOME_HEX.x, HOME_HEX.y)
