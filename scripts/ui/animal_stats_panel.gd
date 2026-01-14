## AnimalStatsPanel - Displays selected animal's stats in a UI panel.
## Listens to EventBus for selection changes and StatsComponent for real-time updates.
##
## Architecture: scripts/ui/animal_stats_panel.gd
## Story: 2-4-display-animal-stats-panel
class_name AnimalStatsPanel
extends Control

# =============================================================================
# NODE REFERENCES
# =============================================================================

@onready var _panel: PanelContainer = $PanelContainer
@onready var _animal_type_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/AnimalTypeLabel
@onready var _mood_indicator: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/MoodIndicator
@onready var _energy_bar: TextureProgressBar = $PanelContainer/MarginContainer/VBoxContainer/EnergyRow/EnergyBar
@onready var _speed_value: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsRow/SpeedContainer/SpeedValue
@onready var _strength_value: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsRow/StrengthContainer/StrengthValue
@onready var _specialty_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SpecialtyLabel

# =============================================================================
# CONSTANTS
# =============================================================================

## Mood emoji mapping
const MOOD_EMOJIS := {
	"happy": "😊",
	"neutral": "😐",
	"sad": "😢"
}

## Energy bar animation duration
const ENERGY_TWEEN_DURATION: float = 0.3

# =============================================================================
# STATE
# =============================================================================

## Currently displayed animal reference
var _current_animal: Animal = null

## Active tween for energy bar animation
var _energy_tween: Tween = null

# =============================================================================
# LIFECYCLE
# =============================================================================

func _ready() -> void:
	# Initially hidden
	visible = false

	# Connect to EventBus selection signals
	if EventBus:
		EventBus.animal_selected.connect(_on_animal_selected)
		EventBus.animal_deselected.connect(_on_animal_deselected)

	GameLogger.info("UI", "AnimalStatsPanel initialized")


func _exit_tree() -> void:
	# Cleanup signal connections
	_disconnect_current_animal()

	if EventBus:
		if EventBus.animal_selected.is_connected(_on_animal_selected):
			EventBus.animal_selected.disconnect(_on_animal_selected)
		if EventBus.animal_deselected.is_connected(_on_animal_deselected):
			EventBus.animal_deselected.disconnect(_on_animal_deselected)

# =============================================================================
# PUBLIC API
# =============================================================================

## Show panel for specified animal
func show_for_animal(animal: Animal) -> void:
	if not is_instance_valid(animal):
		GameLogger.warn("UI", "Cannot show stats for invalid animal")
		return

	# Disconnect previous animal if any
	_disconnect_current_animal()

	# Store reference and connect to signals
	_current_animal = animal
	_connect_animal_signals(animal)

	# Update display with current values
	_update_display()

	# Show panel
	visible = true
	GameLogger.debug("UI", "Stats panel shown for: %s" % animal.get_animal_id())


## Hide panel
func hide_panel() -> void:
	_disconnect_current_animal()
	_current_animal = null
	visible = false
	GameLogger.debug("UI", "Stats panel hidden")


## Check if panel is currently visible
func is_showing() -> bool:
	return visible and _current_animal != null


## Get the current animal being displayed (for testing)
func get_current_animal() -> Animal:
	return _current_animal

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

func _on_animal_selected(animal: Node) -> void:
	var typed_animal := animal as Animal
	if typed_animal:
		show_for_animal(typed_animal)


func _on_animal_deselected() -> void:
	hide_panel()


func _on_energy_changed(current: int, max_energy: int) -> void:
	_animate_energy_bar(current, max_energy)


func _on_mood_changed(mood_string: String) -> void:
	_update_mood_indicator(mood_string)

# =============================================================================
# PRIVATE METHODS
# =============================================================================

## Connect to animal's StatsComponent signals
func _connect_animal_signals(animal: Animal) -> void:
	var stats := _get_stats_component(animal)
	if stats:
		if not stats.energy_changed.is_connected(_on_energy_changed):
			stats.energy_changed.connect(_on_energy_changed)
		if not stats.mood_changed.is_connected(_on_mood_changed):
			stats.mood_changed.connect(_on_mood_changed)


## Disconnect from current animal's signals
func _disconnect_current_animal() -> void:
	if not is_instance_valid(_current_animal):
		return

	var stats := _get_stats_component(_current_animal)
	if stats:
		if stats.energy_changed.is_connected(_on_energy_changed):
			stats.energy_changed.disconnect(_on_energy_changed)
		if stats.mood_changed.is_connected(_on_mood_changed):
			stats.mood_changed.disconnect(_on_mood_changed)


## Get stats component from animal (handles both direct property and node lookup)
func _get_stats_component(animal: Animal) -> StatsComponent:
	if not is_instance_valid(animal):
		return null

	# Try getting component via node path
	var stats := animal.get_node_or_null("StatsComponent") as StatsComponent
	return stats


## Update all display fields from current animal
func _update_display() -> void:
	if not is_instance_valid(_current_animal):
		return

	var stats := _get_stats_component(_current_animal)
	if not stats:
		return

	# Animal type/name
	_animal_type_label.text = _current_animal.get_animal_id().capitalize()

	# Mood indicator
	_update_mood_indicator(stats.get_mood_string())

	# Energy bar (immediate update, no animation on initial display)
	var current_energy := stats.get_energy()
	var max_energy := stats.get_max_energy()
	_energy_bar.max_value = max_energy
	_energy_bar.value = current_energy

	# Speed and Strength
	_speed_value.text = str(stats.get_speed())
	_strength_value.text = str(stats.get_strength())

	# Specialty
	_specialty_label.text = stats.get_specialty()


## Update mood indicator emoji
func _update_mood_indicator(mood_string: String) -> void:
	_mood_indicator.text = MOOD_EMOJIS.get(mood_string.to_lower(), "😐")


## Animate energy bar to new value
func _animate_energy_bar(current: int, max_energy: int) -> void:
	# Kill any existing tween
	if _energy_tween and _energy_tween.is_running():
		_energy_tween.kill()

	# Update max value immediately
	_energy_bar.max_value = max_energy

	# Animate current value
	_energy_tween = create_tween()
	_energy_tween.tween_property(_energy_bar, "value", float(current), ENERGY_TWEEN_DURATION)
