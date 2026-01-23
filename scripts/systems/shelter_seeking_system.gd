## ShelterSeekingSystem - Event-driven system for routing tired animals to shelters.
## Listens to EventBus.animal_energy_depleted and routes animals to nearest available shelter.
## Implements reservation system to handle race conditions (Party Mode feedback).
##
## Architecture: scripts/systems/shelter_seeking_system.gd
## Story: 5-11-create-shelter-building-for-resting
## SRP Compliance: Decoupled from AIComponent - uses event-driven architecture (Party Mode feedback)
class_name ShelterSeekingSystem
extends Node

# =============================================================================
# CONSTANTS
# =============================================================================

## Maximum hex distance for auto-seek behavior (Party Mode feedback - player agency)
## Animals beyond this radius will rest in place instead of walking to shelter
const SHELTER_SEEK_RADIUS: int = 5

## Reservation timeout in seconds - if animal doesn't arrive, slot is released
const RESERVATION_TIMEOUT: float = 30.0

# =============================================================================
# PROPERTIES
# =============================================================================

## Pending reservations: animal_instance_id -> {shelter: Building, timestamp: float}
var _pending_reservations: Dictionary = {}

## Track if system is initialized
var _initialized: bool = false

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	add_to_group("systems")
	_connect_signals()
	_initialized = true
	GameLogger.info("ShelterSeekingSystem", "Initialized - listening for energy depletion events")


func _connect_signals() -> void:
	# Listen for animal energy depletion events (event-driven decoupling)
	if is_instance_valid(EventBus):
		EventBus.animal_energy_depleted.connect(_on_animal_energy_depleted)
		EventBus.animal_movement_completed.connect(_on_animal_movement_completed)
		EventBus.animal_movement_cancelled.connect(_on_animal_movement_cancelled)
		EventBus.animal_recovered.connect(_on_animal_recovered)
		EventBus.animal_removed.connect(_on_animal_removed)


func _exit_tree() -> void:
	_disconnect_signals()


func _disconnect_signals() -> void:
	if is_instance_valid(EventBus):
		if EventBus.animal_energy_depleted.is_connected(_on_animal_energy_depleted):
			EventBus.animal_energy_depleted.disconnect(_on_animal_energy_depleted)
		if EventBus.animal_movement_completed.is_connected(_on_animal_movement_completed):
			EventBus.animal_movement_completed.disconnect(_on_animal_movement_completed)
		if EventBus.animal_movement_cancelled.is_connected(_on_animal_movement_cancelled):
			EventBus.animal_movement_cancelled.disconnect(_on_animal_movement_cancelled)
		if EventBus.animal_recovered.is_connected(_on_animal_recovered):
			EventBus.animal_recovered.disconnect(_on_animal_recovered)
		if EventBus.animal_removed.is_connected(_on_animal_removed):
			EventBus.animal_removed.disconnect(_on_animal_removed)


func _process(delta: float) -> void:
	# Clean up expired reservations
	_cleanup_expired_reservations()

# =============================================================================
# PUBLIC API
# =============================================================================

## Find nearest shelter with capacity within seek radius
## @param from_hex HexCoord to search from
## @param radius Maximum hex distance to search
## @return Building (shelter) or null if none available within radius
func find_nearest_shelter_within_radius(from_hex: HexCoord, radius: int = SHELTER_SEEK_RADIUS) -> Node:
	if not from_hex:
		return null

	# PERFORMANCE: Use dedicated "shelters" group (Party Mode feedback)
	var shelters := get_tree().get_nodes_in_group(GameConstants.GROUP_SHELTERS)
	var nearest: Node = null
	var min_distance: float = INF

	for shelter in shelters:
		if not is_instance_valid(shelter):
			continue

		# Get shelter component and check capacity
		if not shelter.has_method("get_shelter"):
			continue
		var shelter_comp: Node = shelter.get_shelter()
		if not shelter_comp or not shelter_comp.has_method("has_capacity"):
			continue
		if not shelter_comp.has_capacity():
			continue

		# Get shelter hex and calculate distance
		if not shelter.has_method("get_hex_coord"):
			continue
		var shelter_hex := shelter.get_hex_coord() as HexCoord
		if not shelter_hex:
			continue

		var distance := HexGrid.hex_distance(from_hex, shelter_hex)

		# Check if within radius (player agency - Party Mode feedback)
		if distance > radius:
			continue

		# Track nearest
		if distance < min_distance:
			min_distance = distance
			nearest = shelter
		elif distance == min_distance and nearest != null:
			# Tiebreaker: use lower instance_id for deterministic behavior (testing)
			if shelter.get_instance_id() < nearest.get_instance_id():
				nearest = shelter

	return nearest


## Check if an animal has a pending reservation
func has_reservation(animal: Node) -> bool:
	if not is_instance_valid(animal):
		return false
	return _pending_reservations.has(animal.get_instance_id())


## Get the shelter an animal has reserved (or null)
func get_reserved_shelter(animal: Node) -> Node:
	if not is_instance_valid(animal):
		return null
	var animal_id := animal.get_instance_id()
	if _pending_reservations.has(animal_id):
		return _pending_reservations[animal_id].shelter
	return null

# =============================================================================
# EVENT HANDLERS
# =============================================================================

## Handle animal energy depletion - find and route to nearest shelter
func _on_animal_energy_depleted(animal: Node) -> void:
	if not is_instance_valid(animal):
		return

	# Skip if animal already has a reservation
	if has_reservation(animal):
		return

	# Get animal's current hex
	var animal_hex: HexCoord = null
	if animal.has_method("get_hex_coord"):
		animal_hex = animal.get_hex_coord()
	elif "hex_coord" in animal:
		animal_hex = animal.hex_coord

	if not animal_hex:
		GameLogger.warn("ShelterSeekingSystem", "Cannot find hex for depleted animal")
		return

	# Find nearest shelter within radius
	var shelter := find_nearest_shelter_within_radius(animal_hex, SHELTER_SEEK_RADIUS)

	if not shelter:
		# No shelter available/in range - animal will rest in place
		var animal_id := _get_animal_id(animal)
		GameLogger.debug("ShelterSeekingSystem", "%s: No shelter within %d hexes - resting in place" % [animal_id, SHELTER_SEEK_RADIUS])
		return

	# Try to reserve a slot
	if _reserve_shelter_slot(animal, shelter):
		# Route animal to shelter
		_route_animal_to_shelter(animal, shelter)
	else:
		# Reservation failed (race condition) - rest in place
		var animal_id := _get_animal_id(animal)
		GameLogger.debug("ShelterSeekingSystem", "%s: Failed to reserve shelter slot - resting in place" % animal_id)


## Handle animal movement completed - check if arrived at shelter
func _on_animal_movement_completed(animal: Node) -> void:
	if not is_instance_valid(animal):
		return

	if not has_reservation(animal):
		return

	var shelter := get_reserved_shelter(animal)
	_on_animal_arrived_at_shelter(animal, shelter)


## Handle animal movement cancelled - release reservation
func _on_animal_movement_cancelled(animal: Node) -> void:
	_release_reservation(animal)


## Handle animal recovered - release any reservation
func _on_animal_recovered(animal: Node) -> void:
	_release_reservation(animal)


## Handle animal removed - clean up reservation
func _on_animal_removed(animal: Node) -> void:
	_release_reservation(animal)

# =============================================================================
# RESERVATION SYSTEM (Race Condition Handling - Party Mode feedback)
# =============================================================================

## Reserve a shelter slot for an animal
## @return true if reservation successful
func _reserve_shelter_slot(animal: Node, shelter: Node) -> bool:
	if not is_instance_valid(animal) or not is_instance_valid(shelter):
		return false

	# Check shelter has capacity
	var shelter_comp: Node = shelter.get_shelter() if shelter.has_method("get_shelter") else null
	if not shelter_comp or not shelter_comp.has_method("has_capacity") or not shelter_comp.has_capacity():
		return false

	# Store reservation
	var animal_id := animal.get_instance_id()
	_pending_reservations[animal_id] = {
		"shelter": shelter,
		"timestamp": Time.get_ticks_msec() / 1000.0
	}

	var animal_name := _get_animal_id(animal)
	var shelter_id: String = shelter.get_building_id() if shelter.has_method("get_building_id") else "unknown"
	GameLogger.info("ShelterSeekingSystem", "%s: Reserved slot at %s" % [animal_name, shelter_id])

	return true


## Release an animal's reservation
func _release_reservation(animal: Node) -> void:
	if not is_instance_valid(animal):
		return

	var animal_id := animal.get_instance_id()
	if _pending_reservations.has(animal_id):
		_pending_reservations.erase(animal_id)
		var animal_name := _get_animal_id(animal)
		GameLogger.debug("ShelterSeekingSystem", "%s: Reservation released" % animal_name)


## Clean up reservations that have timed out
func _cleanup_expired_reservations() -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	var expired_ids: Array = []

	for animal_id in _pending_reservations:
		var reservation: Dictionary = _pending_reservations[animal_id]
		var elapsed: float = current_time - reservation.timestamp
		if elapsed > RESERVATION_TIMEOUT:
			expired_ids.append(animal_id)

	for animal_id in expired_ids:
		_pending_reservations.erase(animal_id)
		GameLogger.debug("ShelterSeekingSystem", "Reservation expired for animal_id: %d" % animal_id)

# =============================================================================
# ROUTING
# =============================================================================

## Route animal to walk to shelter
func _route_animal_to_shelter(animal: Node, shelter: Node) -> void:
	if not is_instance_valid(animal) or not is_instance_valid(shelter):
		return

	# Get shelter hex
	var shelter_hex: HexCoord = null
	if shelter.has_method("get_hex_coord"):
		shelter_hex = shelter.get_hex_coord()

	if not shelter_hex:
		GameLogger.warn("ShelterSeekingSystem", "Cannot get shelter hex for routing")
		_release_reservation(animal)
		return

	# Set animal's target building for RestingState to use
	if animal.has_method("set_target_building"):
		animal.set_target_building(shelter)

	# Issue movement command
	var movement: Node = animal.get_node_or_null("MovementComponent")
	if movement and movement.has_method("move_to"):
		movement.move_to(shelter_hex)
		var animal_name := _get_animal_id(animal)
		var shelter_id: String = shelter.get_building_id() if shelter.has_method("get_building_id") else "unknown"
		GameLogger.info("ShelterSeekingSystem", "%s: Routing to shelter %s at %s" % [animal_name, shelter_id, shelter_hex])
	else:
		GameLogger.warn("ShelterSeekingSystem", "Cannot route - no MovementComponent")
		_release_reservation(animal)


## Handle animal arrival at shelter
func _on_animal_arrived_at_shelter(animal: Node, shelter: Node) -> void:
	if not is_instance_valid(animal):
		return

	var animal_name := _get_animal_id(animal)

	# Verify reservation is still valid
	var reserved_shelter := get_reserved_shelter(animal)
	if reserved_shelter != shelter:
		GameLogger.debug("ShelterSeekingSystem", "%s: Reservation mismatch on arrival" % animal_name)
		_release_reservation(animal)
		_fallback_to_outdoor_rest(animal)
		return

	# Clear reservation
	_release_reservation(animal)

	# Check shelter still has capacity (race condition handling)
	if not is_instance_valid(shelter):
		GameLogger.debug("ShelterSeekingSystem", "%s: Shelter destroyed - outdoor rest" % animal_name)
		_fallback_to_outdoor_rest(animal)
		return

	var shelter_comp: Node = shelter.get_shelter() if shelter.has_method("get_shelter") else null
	if not shelter_comp or not shelter_comp.has_method("has_capacity") or not shelter_comp.has_capacity():
		# Shelter full (race condition) - fall back to outdoor rest
		GameLogger.debug("ShelterSeekingSystem", "%s: Shelter full on arrival - outdoor rest" % animal_name)
		_fallback_to_outdoor_rest(animal)
		return

	# Add animal as worker to shelter (triggers entry via Building._on_worker_added)
	var worker_slots: Node = shelter.get_worker_slots() if shelter.has_method("get_worker_slots") else null
	if worker_slots and worker_slots.has_method("add_worker"):
		if worker_slots.add_worker(animal):
			var shelter_id: String = shelter.get_building_id() if shelter.has_method("get_building_id") else "unknown"
			GameLogger.info("ShelterSeekingSystem", "%s: Entered shelter %s" % [animal_name, shelter_id])

			# Set assigned building for RestingState recovery bonus
			if animal.has_method("set_assigned_building"):
				animal.set_assigned_building(shelter)

			# Trigger resting state with shelter context
			var ai: Node = animal.get_node_or_null("AIComponent")
			if ai and ai.has_method("transition_to"):
				ai.transition_to(ai.AnimalState.RESTING)
		else:
			GameLogger.debug("ShelterSeekingSystem", "%s: Failed to add to shelter - outdoor rest" % animal_name)
			_fallback_to_outdoor_rest(animal)
	else:
		_fallback_to_outdoor_rest(animal)


## Fallback to outdoor resting when shelter is unavailable
func _fallback_to_outdoor_rest(animal: Node) -> void:
	if not is_instance_valid(animal):
		return

	# Clear target building
	if animal.has_method("set_target_building"):
		animal.set_target_building(null)

	# Ensure animal is on valid hex before resting (AC: 22)
	# Note: Current implementation relies on pathfinding to put animal on valid hex.
	# If future stories add water/invalid hexes, add is_hex_valid_for_rest() to HexGrid.
	# For now, animals falling back to outdoor rest will be at their current valid position.

	# Transition to resting state (outdoor, no shelter)
	var ai: Node = animal.get_node_or_null("AIComponent")
	if ai and ai.has_method("transition_to"):
		ai.transition_to(ai.AnimalState.RESTING)

	var animal_name := _get_animal_id(animal)
	GameLogger.debug("ShelterSeekingSystem", "%s: Resting outdoors" % animal_name)

# =============================================================================
# HELPERS
# =============================================================================

func _get_animal_id(animal: Node) -> String:
	if animal.has_method("get_animal_id"):
		return animal.get_animal_id()
	return "animal_%d" % animal.get_instance_id()
