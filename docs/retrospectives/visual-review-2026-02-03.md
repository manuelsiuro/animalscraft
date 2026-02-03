# Visual Review Retrospective - 2026-02-03

## Overview

A comprehensive visual review was performed to ensure all graphical elements, 3D objects, terrain tiles, buildings, and animals render correctly in the AnimalsCraft game.

## Issues Identified and Fixed

### 1. Splash Screen Stuck / Game Not Starting

**Problem:** Game was stuck on splash screen, not transitioning to main menu.

**Root Cause:** Signal timing issues - `new_game_started` signal was emitted before WorldManager._ready() completed.

**Fix (game_manager.gd):**
```gdscript
func start_new_game() -> void:
    change_to_game_scene()
    await EventBus.scene_loaded           # Wait for scene to load
    await get_tree().process_frame        # Wait for _ready()
    await get_tree().process_frame        # Extra frame for safety
    EventBus.new_game_started.emit()      # NOW safe to emit
```

**Lesson:** When using deferred scene changes, always use `await` on signals/frames before emitting dependent signals.

---

### 2. Only One Terrain Tile Visible

**Problem:** Terrain tiles were invisible or showing as tiny points.

**Root Cause:** 3D GLB terrain models were at unit scale (1.0) but hex tiles are 64 world units. Also, models were on XY plane instead of XZ ground plane.

**Fix (hex_tile.gd):**
```gdscript
# Scale model to match HEX_SIZE
var scale_factor: float = GameConstants.HEX_SIZE  # 64.0
_terrain_model.scale = Vector3(scale_factor, scale_factor, scale_factor)

# Rotate model to correct orientation (-90° on X to lay flat)
_terrain_model.rotation_degrees.x = -90.0
```

**Lesson:** 3D models from Blender/GLB are often at unit scale and may need rotation corrections for Godot's Y-up coordinate system.

---

### 3. Surface Material Access Error

**Problem:** `Index p_surface = 0 is out of bounds` error when setting territory state.

**Root Cause:** When using 3D terrain models, the procedural mesh_instance is hidden and has no surfaces, but code tried to access its material.

**Fix (hex_tile.gd):**
```gdscript
func _get_safe_surface_material(mesh_node: MeshInstance3D) -> StandardMaterial3D:
    if not mesh_node or not mesh_node.mesh:
        return null
    if mesh_node.mesh.get_surface_count() == 0:
        return null
    return mesh_node.get_surface_override_material(0) as StandardMaterial3D
```

**Lesson:** Always check mesh validity and surface count before accessing materials.

---

### 4. Tween With No Tweeners Error

**Problem:** "Tween started with no Tweeners" error during state transitions.

**Root Cause:** When using 3D models, procedural mesh is hidden so no materials to animate, leaving tween empty.

**Fix (hex_tile.gd):**
```gdscript
func _animate_state_transition() -> void:
    _tween = create_tween()
    # Add minimal no-op callback to ensure tween always has an operation
    _tween.tween_callback(func(): pass).set_delay(0.0)
    # ... rest of state-specific animations
```

**Lesson:** Tweens must have at least one tweener, even if it's a no-op.

---

### 5. Animals and Buildings Not Visible

**Problem:** Animals and buildings were not visible after spawning.

**Root Cause:** 3D models at unit scale (1.0) in a world where tiles are 64 units - entities were microscopic.

**Fix (animal.gd, building.gd):**
```gdscript
# Animal scale
const ANIMAL_VISUAL_SCALE: float = 12.0

# Building scale (larger because some models are flat)
const BUILDING_VISUAL_SCALE: float = 40.0

func initialize(...) -> void:
    if _visual:
        _visual.scale = Vector3(VISUAL_SCALE, VISUAL_SCALE, VISUAL_SCALE)
```

**Lesson:** Define explicit scale constants for each entity type based on visual requirements.

---

### 6. Cannot Select Animals (Selection Radius Too Small)

**Problem:** Tapping on animals didn't select them.

**Root Cause:** Selection radius was calculated as `tap_radius / HEX_SIZE` = 32/64 = 0.5 world units, which is invisible.

**Fix (selectable_component.gd):**
```gdscript
func is_position_in_range(world_pos: Vector3) -> bool:
    var distance := Vector2(world_pos.x - entity_pos.x, world_pos.z - entity_pos.z).length()
    return distance <= tap_radius  # Use tap_radius directly (32 world units)
```

**Lesson:** Selection radius should be in world units, not converted from pixels.

---

### 7. Animal Moves Backwards

**Problem:** When animals moved, they faced away from their movement direction.

**Root Cause:** GLB models are exported facing -Z, but movement code assumed +Z facing.

**Fix (movement_component.gd):**
```gdscript
func _update_target_rotation(direction: Vector3) -> void:
    # Add PI (180°) offset because GLB models face -Z
    _target_rotation = atan2(direction.x, direction.z) + PI
```

**Lesson:** GLB models typically face -Z axis; add PI rotation offset for correct facing.

---

### 8. Animal Spawns on Same Hex as Stockpile

**Problem:** Squirrel spawned on same hex as stockpile, couldn't move.

**Root Cause:** Building's hex occupancy was marked in deferred initialize(), so animal spawn check didn't see it.

**Fix (world_manager.gd):**
```gdscript
func _spawn_initial_stockpile() -> void:
    var building := BuildingFactory.create_building("stockpile", stockpile_hex)
    add_child(building)
    # Mark hex occupied IMMEDIATELY after add_child, don't wait for initialize()
    HexGrid.mark_hex_occupied(stockpile_hex.to_vector(), building)

func _spawn_initial_animals() -> void:
    # Check hex occupancy before spawning
    if not HexGrid.is_hex_occupied(hex.to_vector()):
        spawn_hexes.append(hex)
```

**Lesson:** Mark occupancy immediately after entity creation, not in deferred methods.

---

## Files Modified

### Core Scripts
- `autoloads/game_manager.gd` - Signal timing fix
- `scripts/world/hex_tile.gd` - 3D model support, safe material access
- `scripts/world/world_manager.gd` - Initial entity spawning
- `scripts/entities/animals/animal.gd` - Visual scaling
- `scripts/entities/buildings/building.gd` - Visual scaling
- `scripts/entities/animals/components/selectable_component.gd` - Selection radius fix
- `scripts/entities/animals/components/movement_component.gd` - Rotation offset
- `scripts/ui/menus/main_menu.gd` - Use GameManager for scene change

### Unit Tests Updated
- `tests/unit/test_selectable_component.gd` - Updated boundary tests
- `tests/unit/test_movement_component.gd` - Added rotation offset tests
- `tests/unit/test_hex_tile.gd` - Added 3D model tests
- `tests/unit/test_world_manager.gd` - Added spawn tests
- `tests/unit/test_animal.gd` - Added visual scale tests
- `tests/unit/test_building_entity.gd` - Added visual scale tests
- `tests/unit/test_main_menu.gd` - Added GameManager integration tests

### Documentation Updated
- `_bmad-output/project-context.md` - Added visual entity patterns

---

## Key Patterns Established

### Entity Visual Scale Pattern
```gdscript
const ENTITY_VISUAL_SCALE: float = X.0

func initialize(...) -> void:
    if _visual:
        _visual.scale = Vector3(ENTITY_VISUAL_SCALE, ENTITY_VISUAL_SCALE, ENTITY_VISUAL_SCALE)
```

### Safe Material Access Pattern
```gdscript
func _get_safe_surface_material(mesh_node: MeshInstance3D) -> StandardMaterial3D:
    if not mesh_node or not mesh_node.mesh:
        return null
    if mesh_node.mesh.get_surface_count() == 0:
        return null
    return mesh_node.get_surface_override_material(0) as StandardMaterial3D
```

### Scene Load Timing Pattern
```gdscript
change_to_game_scene()
await EventBus.scene_loaded
await get_tree().process_frame
await get_tree().process_frame
# Now safe to interact with scene
```

---

## Test Results

All 30 new tests pass:
- test_selectable_component.gd - Updated 2 tests
- test_movement_component.gd - Added 3 tests (45/45 total)
- test_hex_tile.gd - Added 8 tests (27/27 total)
- test_world_manager.gd - Added 6 tests (31/31 total)
- test_animal.gd - Added 3 tests (40/40 total)
- test_building_entity.gd - Added 3 tests (66/66 total)
- test_main_menu.gd - Added 4 tests (27/27 total)

---

## Recommendations for Future Work

1. **Document scale factors** in BuildingData/AnimalStats resources instead of hardcoding
2. **Create visual validation tests** that verify entities are visible at expected scales
3. **Add GLB import settings** documentation for artists
4. **Consider visual debug mode** to show bounding boxes and selection radii
