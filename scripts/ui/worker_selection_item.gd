## WorkerSelectionItem - Individual item in the worker selection overlay.
## Displays animal info (icon, name, energy) and emits pressed signal when tapped.
##
## Architecture: scripts/ui/worker_selection_item.gd
## Story: 3-10-assign-animals-to-buildings
class_name WorkerSelectionItem
extends Control

# =============================================================================
# SIGNALS
# =============================================================================

## Emitted when item is pressed/tapped
signal pressed()

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _button: Button = $Button
@onready var _icon_label: Label = $Button/HBoxContainer/IconLabel
@onready var _name_label: Label = $Button/HBoxContainer/NameLabel
@onready var _energy_label: Label = $Button/HBoxContainer/EnergyLabel

# =============================================================================
# STATE
# =============================================================================

## Reference to the animal this item represents
var _animal: Animal = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	if _button:
		_button.pressed.connect(_on_button_pressed)


## Setup item with animal data
func setup(animal: Animal) -> void:
	if not is_instance_valid(animal):
		return

	_animal = animal

	# Update icon
	if _icon_label:
		_icon_label.text = _get_animal_icon(animal)

	# Update name
	if _name_label:
		var animal_id := animal.get_animal_id() if animal.has_method("get_animal_id") else "Animal"
		_name_label.text = animal_id

	# Update energy
	if _energy_label:
		var energy_percent := _get_energy_percent(animal)
		_energy_label.text = "%d%%" % energy_percent
		# Color code energy level
		if energy_percent < 30:
			_energy_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1))
		elif energy_percent < 60:
			_energy_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 1))
		else:
			_energy_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1))


## Get animal icon based on type
func _get_animal_icon(animal: Animal) -> String:
	var stats := animal.get_stats() if animal.has_method("get_stats") else null
	if stats and "animal_type" in stats:
		match stats.animal_type:
			"rabbit":
				return "Rabbit"
			"squirrel":
				return "Squirrel"
			"deer":
				return "Deer"
			"fox":
				return "Fox"
	return "Animal"


## Get energy percentage from animal
func _get_energy_percent(animal: Animal) -> int:
	var stats_comp := animal.get_node_or_null("StatsComponent")
	if not stats_comp:
		return 100

	var energy := 100
	var max_energy := 100

	if stats_comp.has_method("get_energy"):
		energy = stats_comp.get_energy()
	if stats_comp.has_method("get_max_energy"):
		max_energy = stats_comp.get_max_energy()

	if max_energy <= 0:
		return 100

	return int(float(energy) / float(max_energy) * 100.0)


## Handle button pressed
func _on_button_pressed() -> void:
	pressed.emit()


## Get the animal this item represents (for testing)
func get_animal() -> Animal:
	return _animal
