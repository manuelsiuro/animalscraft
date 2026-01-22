## Global event bus for decoupled system communication.
## Autoload singleton - access via EventBus.signal_name
##
## Architecture: autoloads/event_bus.gd
## Order: 4 (no dependencies)
## Source: game-architecture.md#Event System
##
## =============================================================================
## NAMING CONVENTION
## =============================================================================
## Pattern: {noun}_{past_tense_verb}
## Examples: animal_selected, resource_changed, combat_ended, milestone_reached
##
## =============================================================================
## USAGE EXAMPLES
## =============================================================================
##
## EMITTING A SIGNAL (from any system):
##   EventBus.resource_changed.emit("wood", new_wood_count)
##   EventBus.animal_selected.emit(animal_node)
##   EventBus.combat_ended.emit(true, ["rabbit", "fox"])
##
## CONNECTING TO A SIGNAL (in _ready):
##   func _ready() -> void:
##       EventBus.resource_changed.connect(_on_resource_changed)
##
##   func _on_resource_changed(resource_type: String, amount: int) -> void:
##       if resource_type == "wood":
##           wood_label.text = str(amount)
##
## SAFE DISCONNECTION (in _exit_tree):
##   func _exit_tree() -> void:
##       if EventBus.resource_changed.is_connected(_on_resource_changed):
##           EventBus.resource_changed.disconnect(_on_resource_changed)
##
## ONE-SHOT CONNECTION (fires once then auto-disconnects):
##   EventBus.milestone_reached.connect(_on_first_milestone, CONNECT_ONE_SHOT)
##
## =============================================================================
## WHEN TO USE EVENTBUS vs DIRECT SIGNALS
## =============================================================================
##
## USE EVENTBUS for:
##   - System-to-system communication (e.g., Combat → UI, Resources → Save)
##   - Global state changes (pause, save, milestone)
##   - Decoupled observers (UI listening to game events)
##   - Broadcasting to unknown listeners
##
## USE DIRECT SIGNALS for:
##   - Parent-child communication within same entity
##   - Component-to-component within same scene
##   - Tight coupling is intentional and appropriate
##   - Performance-critical inner loops
##
## ARCHITECTURE RULE (AR5):
##   EventBus is the ONLY approved mechanism for system-to-system communication.
##   Direct imports between systems (e.g., Combat importing Production) are PROHIBITED.
##
## =============================================================================
extends Node

# =============================================================================
# SELECTION EVENTS
# =============================================================================

## Emitted when an animal is selected by the player.
## @param animal The Animal node that was selected (can be null for forward reference)
signal animal_selected(animal: Node)

## Emitted when the current animal selection is cleared.
signal animal_deselected()

## Emitted when a building is selected by the player.
## @param building The Building node that was selected
signal building_selected(building: Node)

## Emitted when the current building selection is cleared.
signal building_deselected()

## Emitted when a hex tile is selected.
## @param hex_coord The Vector2i axial coordinates of the selected hex
signal hex_selected(hex_coord: Vector2i)

# =============================================================================
# RESOURCE EVENTS
# =============================================================================

## Emitted when any resource amount changes.
## @param resource_type The type of resource (e.g., "wood", "wheat", "flour")
## @param new_amount The new total amount of that resource
signal resource_changed(resource_type: String, new_amount: int)

## Emitted when a resource storage is completely emptied.
## @param resource_type The type of resource that was depleted
signal resource_depleted(resource_type: String)

## Emitted when resource storage reaches capacity.
## @param resource_type The type of resource that hit the limit
signal resource_full(resource_type: String)

## Emitted when a resource reaches 80% storage capacity (Story 3-3).
## Warning is only emitted once per threshold crossing (not repeatedly).
## Resets when resource drops below 70% threshold.
## @param resource_id The resource type identifier
signal resource_storage_warning(resource_id: String)

## Emitted when gathering is paused due to full storage (Story 3-3).
## Actual gathering behavior responds in Story 3-8.
## @param resource_id The resource type identifier
## @param reason The reason gathering was paused (e.g., "storage_full")
signal resource_gathering_paused(resource_id: String, reason: String)

## Emitted when gathering resumes after storage space freed (Story 3-3).
## @param resource_id The resource type identifier
signal resource_gathering_resumed(resource_id: String)

## Emitted when total storage capacity changes (building placed/destroyed) (Story 3-3).
## @param resource_id The resource type identifier
## @param new_capacity The new total storage capacity
signal storage_capacity_changed(resource_id: String, new_capacity: int)

# =============================================================================
# TERRITORY EVENTS
# =============================================================================

## Emitted when the player claims a new territory hex.
## @param hex_coord The Vector2i axial coordinates of the claimed hex
signal territory_claimed(hex_coord: Vector2i)

## Emitted when a territory hex is lost (e.g., enemy capture).
## @param hex_coord The Vector2i axial coordinates of the lost hex
signal territory_lost(hex_coord: Vector2i)

## Emitted when fog of war is revealed for a hex.
## @param hex_coord The Vector2i axial coordinates of the revealed hex
signal fog_revealed(hex_coord: Vector2i)

## Emitted when a wild herd spawns in the world.
## @param herd_id Unique identifier for the herd
## @param hex_coord The Vector2i axial coordinates of the herd location
## @param animal_count Number of animals in the herd
signal wild_herd_spawned(herd_id: String, hex_coord: Vector2i, animal_count: int)

## Emitted when a wild herd is removed (defeated, despawned, etc.).
## @param herd_id Unique identifier for the removed herd
## @param hex_coord The Vector2i axial coordinates where herd was located
signal wild_herd_removed(herd_id: String, hex_coord: Vector2i)

## Emitted when territory ownership changes (not just visual state).
## @param hex_coord The Vector2i axial coordinates of the changed hex
## @param old_owner The previous owner_id ("" for unowned)
## @param new_owner The new owner_id
signal territory_ownership_changed(hex_coord: Vector2i, old_owner: String, new_owner: String)

## Story 5-3: Emitted when player requests to start combat with a wild herd.
## @param hex_coord The contested hex location
## @param herd_id The wild herd to fight
signal combat_requested(hex_coord: Vector2i, herd_id: String)

## Story 5-3: Emitted when contested territory is discovered via scouting/fog reveal.
## @param hex_coord The discovered contested hex
## @param herd_id The wild herd at that location
signal contested_territory_discovered(hex_coord: Vector2i, herd_id: String)

# =============================================================================
# PROGRESSION EVENTS
# =============================================================================

## Emitted when the player reaches a milestone.
## @param milestone_id The ID of the reached milestone (e.g., "first_farm")
signal milestone_reached(milestone_id: String)

## Emitted when a new building type is unlocked.
## @param building_type The type of building that was unlocked (e.g., "mill")
signal building_unlocked(building_type: String)

## Emitted when a new biome is unlocked.
## @param biome_id The ID of the unlocked biome (e.g., "forest")
signal biome_unlocked(biome_id: String)

## Emitted when a new animal type is unlocked.
## @param animal_type The type of animal that was unlocked
signal animal_unlocked(animal_type: String)

# =============================================================================
# COMBAT EVENTS
# =============================================================================

## Emitted when combat begins at a location.
## @param hex_coord The Vector2i axial coordinates where combat is happening
signal combat_started(hex_coord: Vector2i)

## Emitted when combat ends.
## @param won True if the player won the battle
## @param captured_animals Array of animal types that were captured
signal combat_ended(won: bool, captured_animals: Array)

## Emitted when an animal is captured during combat.
## @param animal_type The type of animal captured
signal animal_captured(animal_type: String)

## Story 5-8: Emitted when a wild animal is recruited to the player's village.
## Fired per animal during the recruitment process, after animal_spawned completes.
## @param animal_type The type of animal recruited (e.g., "rabbit")
## @param animal The Animal node that was recruited
signal animal_recruited(animal_type: String, animal: Node)

## Story 5-8: Emitted when a batch recruitment operation completes.
## Fired once after all selected animals have been recruited.
## @param recruited_count The total number of animals recruited in this batch
signal recruitment_completed(recruited_count: int)

## Story 5-4: Emitted when player confirms combat team selection.
## @param team Array of Animal nodes selected for combat (untyped Array, cast elements to Animal)
## @param hex_coord The contested hex location
## @param herd_id The wild herd to fight
## @note Consumers should cast: `var animal := team[i] as Animal`
signal combat_team_selected(team: Array, hex_coord: Vector2i, herd_id: String)

## Story 5-5: Emitted during combat when an attack occurs.
## Used by animation/UI systems (Story 5-6) to display attack visuals.
## @param attacker The CombatUnit performing the attack (has .animal property)
## @param defender The CombatUnit being attacked (has .animal property)
## @param damage The damage dealt
## @param defender_hp The defender's HP after damage
signal combat_attack_occurred(attacker: RefCounted, defender: RefCounted, damage: int, defender_hp: int)

# =============================================================================
# GAME STATE EVENTS
# =============================================================================

## Emitted when the game is paused.
signal game_paused()

## Emitted when the game is resumed from pause.
signal game_resumed()

## Emitted when a save operation completes.
## @param success True if the save was successful
signal save_completed(success: bool)

## Emitted when a load operation completes.
## @param success True if the load was successful
signal load_completed(success: bool)

## Emitted when a new game is started.
signal new_game_started()

## Emitted when the game is about to quit.
signal game_quitting()

# =============================================================================
# PRODUCTION EVENTS
# =============================================================================

## Emitted when a building starts producing.
## @param building The Building node that started production
signal production_started(building: Node)

## Emitted when a building completes a production cycle.
## @param building The Building node that completed production
## @param output_type The type of resource produced
signal production_completed(building: Node, output_type: String)

## Emitted when production is halted (e.g., no inputs).
## @param building The Building node that stopped
## @param reason The reason production stopped
signal production_halted(building: Node, reason: String)

# =============================================================================
# ANIMAL EVENTS
# =============================================================================

## Emitted when an animal's energy reaches zero.
## @param animal The Animal node whose energy is depleted
signal animal_energy_depleted(animal: Node)

## Emitted when an animal's energy reaches critically low level.
## This is a warning before full depletion - animal can still work but mood penalty applies.
## @param animal The Animal node whose energy is low
signal animal_energy_low(animal: Node)

## Emitted when an animal's mood changes.
## @param animal The Animal node whose mood changed
## @param mood The new mood as a string ("happy", "neutral", "sad")
signal animal_mood_changed(animal: Node, mood: String)

## Emitted when an animal is spawned.
## @param animal The Animal node that was spawned
signal animal_spawned(animal: Node)

## Emitted when an animal is removed/destroyed.
## @param animal The Animal node that was removed
signal animal_removed(animal: Node)

## Emitted when an animal is assigned to a task.
## @param animal The Animal node that was assigned
## @param target The target (building or hex coord)
signal animal_assigned(animal: Node, target: Variant)

## Emitted when an animal completes its current task.
## @param animal The Animal node that finished
signal animal_task_completed(animal: Node)

## Emitted when an animal enters resting state.
## @param animal The Animal node that is resting
signal animal_resting(animal: Node)

## Emitted when an animal's energy is restored.
## @param animal The Animal node that recovered
signal animal_recovered(animal: Node)

## Emitted when an animal's AI state changes.
## @param animal The Animal node whose state changed
## @param new_state The new state as a string (e.g., "IDLE", "WALKING")
signal animal_state_changed(animal: Node, new_state: String)

## Emitted when an animal starts moving toward a destination.
## @param animal The Animal node that started moving
signal animal_movement_started(animal: Node)

## Emitted when an animal reaches its destination.
## @param animal The Animal node that completed movement
signal animal_movement_completed(animal: Node)

## Emitted when an animal's movement is interrupted or cancelled.
## @param animal The Animal node whose movement was cancelled
signal animal_movement_cancelled(animal: Node)

# =============================================================================
# BUILDING EVENTS
# =============================================================================

## Emitted when a building is spawned/instantiated.
## @param building The Building node that was spawned
signal building_spawned(building: Node)

## Emitted when a building is placed on the hex grid.
## @param building The Building node that was placed
## @param hex_coord The location of the building
signal building_placed(building: Node, hex_coord: Vector2i)

## Emitted when a building is removed/destroyed.
## @param building The Building node that was removed
## @param hex_coord The hex coordinate for path cache invalidation (Epic 2 retrospective action item)
signal building_removed(building: Node, hex_coord: Vector2i)

## Emitted when building placement mode begins (Story 3-4).
## @param building_data The BuildingData resource for the building to be placed
signal building_placement_started(building_data: Resource)

## Emitted when building placement mode ends (cancelled or completed).
## @param placed True if building was placed, false if cancelled
signal building_placement_ended(placed: bool)

# =============================================================================
# CAMERA EVENTS
# =============================================================================

## Emitted when camera zoom level changes.
## @param zoom_height The new camera Y height (lower = zoomed in, higher = zoomed out)
signal camera_zoomed(zoom_height: float)

## Emitted when camera position changes via pan.
## @param position The new camera position (Vector3 with X, Y, Z)
signal camera_panned(position: Vector3)

# =============================================================================
# UI EVENTS
# =============================================================================

## Emitted when a menu is opened.
## @param menu_name The name of the menu that opened
signal menu_opened(menu_name: String)

## Emitted when a menu is closed.
## @param menu_name The name of the menu that closed
signal menu_closed(menu_name: String)

## Emitted when a tutorial hint should be shown.
## @param hint_id The ID of the tutorial hint
signal tutorial_hint_requested(hint_id: String)

## Emitted when the player dismisses a tutorial hint.
## @param hint_id The ID of the dismissed hint
signal tutorial_hint_dismissed(hint_id: String)

# =============================================================================
# SETTINGS EVENTS
# =============================================================================

## Emitted when any setting changes.
## @param setting_name The name of the changed setting
## @param new_value The new value
signal setting_changed(setting_name: String, new_value: Variant)

# =============================================================================
# SCENE LIFECYCLE EVENTS
# =============================================================================

## Emitted when a scene transition is starting.
## @param scene_path The path of the scene being loaded
signal scene_loading(scene_path: String)

## Emitted when a scene has fully loaded and is ready.
## @param scene_name The name of the loaded scene
signal scene_loaded(scene_name: String)

## Emitted when a scene is about to be unloaded.
## @param scene_name The name of the scene being unloaded
signal scene_unloading(scene_name: String)

## Emitted when all autoloads have been verified as ready.
signal autoloads_ready()

## Emitted when autoload verification fails.
## @param missing_autoloads Array of autoload names that are missing
signal autoloads_failed(missing_autoloads: Array)
