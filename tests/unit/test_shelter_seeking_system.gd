## Unit tests for ShelterSeekingSystem
## Tests find_nearest_shelter, radius limits, and reservation system.
##
## Story: 5-11-create-shelter-building-for-resting
extends GutTest

var shelter_seeking_system: ShelterSeekingSystem
var mock_shelters: Array = []
var mock_animals: Array = []

func before_each() -> void:
	# Create ShelterSeekingSystem
	shelter_seeking_system = ShelterSeekingSystem.new()
	add_child(shelter_seeking_system)
	await wait_frames(2)  # Allow initialization

	# Clear previous mocks
	mock_shelters.clear()
	mock_animals.clear()


func after_each() -> void:
	# Clean up shelters (remove from group first)
	for shelter in mock_shelters:
		if is_instance_valid(shelter):
			shelter.remove_from_group(GameConstants.GROUP_SHELTERS)
			shelter.queue_free()
	mock_shelters.clear()

	# Clean up animals
	for animal in mock_animals:
		if is_instance_valid(animal):
			animal.queue_free()
	mock_animals.clear()

	# Clean up system
	if is_instance_valid(shelter_seeking_system):
		shelter_seeking_system.queue_free()
	shelter_seeking_system = null


## Create a mock shelter at specified hex coordinates
func _create_mock_shelter(q: int, r: int, capacity: int = 4, occupancy: int = 0) -> Node:
	var shelter := Node3D.new()
	shelter.set_meta("hex_q", q)
	shelter.set_meta("hex_r", r)
	shelter.set_meta("building_id", "shelter_%d_%d" % [q, r])

	# Add to shelters group (required for system to find it)
	shelter.add_to_group(GameConstants.GROUP_SHELTERS)

	# Create mock shelter component
	var shelter_comp := _MockShelterComponent.new()
	shelter_comp._capacity = capacity
	shelter_comp._occupancy = occupancy
	shelter_comp.name = "ShelterComponent"
	shelter.add_child(shelter_comp)

	# Add methods the system expects
	shelter.set_script(_MockShelterBuildingScript)

	add_child(shelter)
	mock_shelters.append(shelter)
	return shelter


## Create a mock animal at specified hex coordinates
func _create_mock_animal(q: int, r: int) -> Node:
	var animal := Node3D.new()
	animal.set_meta("hex_q", q)
	animal.set_meta("hex_r", r)
	animal.set_meta("animal_id", "animal_%d_%d" % [q, r])

	# Add mock hex_coord
	var hex := HexCoord.new(q, r)
	animal.set_meta("hex_coord", hex)

	# Add methods the system expects
	animal.set_script(_MockAnimalScript)

	add_child(animal)
	mock_animals.append(animal)
	return animal


# =============================================================================
# FIND NEAREST SHELTER TESTS (AC: 8)
# =============================================================================

func test_find_nearest_shelter_returns_null_when_no_shelters() -> void:
	var animal := _create_mock_animal(0, 0)
	var hex := HexCoord.new(0, 0)

	var result := shelter_seeking_system.find_nearest_shelter_within_radius(hex)

	assert_null(result, "Should return null when no shelters exist")


func test_find_nearest_shelter_returns_nearest() -> void:
	# Create shelters at different distances
	_create_mock_shelter(1, 0)  # Distance 1
	_create_mock_shelter(3, 0)  # Distance 3

	var hex := HexCoord.new(0, 0)
	var result := shelter_seeking_system.find_nearest_shelter_within_radius(hex)

	assert_not_null(result, "Should find a shelter")
	assert_eq(result.get_meta("hex_q"), 1, "Should return nearest shelter")


func test_find_nearest_shelter_respects_radius_limit() -> void:
	# Create shelter beyond radius (default radius is 5)
	_create_mock_shelter(6, 0)  # Distance 6 > radius 5

	var hex := HexCoord.new(0, 0)
	var result := shelter_seeking_system.find_nearest_shelter_within_radius(hex, 5)

	assert_null(result, "Should return null when shelter beyond radius")


func test_find_nearest_shelter_finds_shelter_at_edge_of_radius() -> void:
	_create_mock_shelter(5, 0)  # Distance exactly 5 = radius

	var hex := HexCoord.new(0, 0)
	var result := shelter_seeking_system.find_nearest_shelter_within_radius(hex, 5)

	assert_not_null(result, "Should find shelter at exactly radius distance")


func test_find_nearest_shelter_skips_full_shelters() -> void:
	# Create full shelter nearby
	_create_mock_shelter(1, 0, 4, 4)  # Full (4/4)
	# Create available shelter farther
	_create_mock_shelter(3, 0, 4, 2)  # Has space (2/4)

	var hex := HexCoord.new(0, 0)
	var result := shelter_seeking_system.find_nearest_shelter_within_radius(hex)

	assert_not_null(result, "Should find available shelter")
	assert_eq(result.get_meta("hex_q"), 3, "Should skip full shelter and return available one")


func test_find_nearest_shelter_with_multiple_at_same_distance_is_deterministic() -> void:
	# Create two shelters at same distance
	_create_mock_shelter(2, 0)
	_create_mock_shelter(0, 2)  # Same distance in hex grid

	var hex := HexCoord.new(0, 0)
	var result1 := shelter_seeking_system.find_nearest_shelter_within_radius(hex)
	var result2 := shelter_seeking_system.find_nearest_shelter_within_radius(hex)

	assert_eq(result1, result2, "Should return same shelter consistently (deterministic)")


# =============================================================================
# RESERVATION SYSTEM TESTS (AC: 20, 21)
# =============================================================================

func test_has_reservation_returns_false_initially() -> void:
	var animal := _create_mock_animal(0, 0)

	assert_false(shelter_seeking_system.has_reservation(animal))


func test_get_reserved_shelter_returns_null_initially() -> void:
	var animal := _create_mock_animal(0, 0)

	assert_null(shelter_seeking_system.get_reserved_shelter(animal))


# =============================================================================
# CONSTANTS TESTS
# =============================================================================

func test_shelter_seek_radius_is_5() -> void:
	assert_eq(ShelterSeekingSystem.SHELTER_SEEK_RADIUS, 5, "Default seek radius should be 5")


func test_reservation_timeout_is_30_seconds() -> void:
	assert_eq(ShelterSeekingSystem.RESERVATION_TIMEOUT, 30.0, "Reservation timeout should be 30 seconds")


# =============================================================================
# MOCK CLASSES
# =============================================================================

class _MockShelterComponent extends Node:
	var _capacity: int = 4
	var _occupancy: int = 0

	func is_initialized() -> bool:
		return true

	func has_capacity() -> bool:
		return _occupancy < _capacity

	func get_occupancy() -> int:
		return _occupancy

	func get_recovery_multiplier() -> float:
		return 2.0


## Mock script that adds expected methods to shelter nodes
const _MockShelterBuildingScript = preload("res://tests/unit/test_shelter_seeking_system.gd")._MockShelterBuilding


class _MockShelterBuilding extends Node3D:
	func get_shelter() -> Node:
		return get_node_or_null("ShelterComponent")

	func get_hex_coord() -> HexCoord:
		return HexCoord.new(get_meta("hex_q", 0), get_meta("hex_r", 0))

	func get_building_id() -> String:
		return get_meta("building_id", "shelter")

	func get_worker_slots() -> Node:
		return null

	func is_shelter() -> bool:
		return true


const _MockAnimalScript = preload("res://tests/unit/test_shelter_seeking_system.gd")._MockAnimal


class _MockAnimal extends Node3D:
	var _target_building: Node = null
	var _assigned_building: Node = null

	func get_hex_coord() -> HexCoord:
		return get_meta("hex_coord", HexCoord.new(0, 0))

	func get_animal_id() -> String:
		return get_meta("animal_id", "mock_animal")

	func set_target_building(building: Node) -> void:
		_target_building = building

	func get_target_building() -> Node:
		return _target_building

	func set_assigned_building(building: Node) -> void:
		_assigned_building = building

	func get_assigned_building() -> Node:
		return _assigned_building
