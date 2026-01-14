---
project_name: 'AnimalsCraft'
user_name: 'Manu'
date: '2026-01-13'
sections_completed: ['technology_stack', 'language_rules', 'framework_rules', 'testing_rules', 'code_quality', 'workflow_rules', 'critical_rules']
status: 'complete'
rule_count: 45
optimized_for_llm: true
---

# Project Context for AI Agents

_This file contains critical rules and patterns that AI agents must follow when implementing code in this project. Focus on unobvious details that agents might otherwise miss._

---

## Technology Stack & Versions

- **Engine**: Godot 4.5 (Mobile)
- **Language**: GDScript with static typing
- **Testing**: GUT v9.3.0
- **Target Platform**: Android (portrait 1080x1920)
- **Renderer**: Mobile renderer
- **Touch Input**: Native touch with mouse emulation for desktop testing

## Critical Implementation Rules

### GDScript Language Rules

#### 3D Coordinate System (CRITICAL)
- **Y axis = UP** (height/vertical)
- **X axis = LEFT/RIGHT** (horizontal)
- **Z axis = FORWARD/BACK** (depth)
- Use `Vector3` for ALL world positions
- Use `AABB` for 3D bounds (NOT Rect2)
- Ground plane is at `Y = 0`

#### Null Safety (AR18)
- Always use guard clauses: `if not node: return`
- Check autoloads: `if is_instance_valid(GameLogger):`
- Never assume nodes exist - verify first

#### Static Typing
- Use type hints on all function parameters
- Use type hints on return values
- Use `:=` for type inference on variables

#### Naming Conventions
- `snake_case` for files and variables
- `PascalCase` for class names
- `SCREAMING_SNAKE_CASE` for constants
- Private members prefixed with `_`

### Godot Framework Rules

#### Camera3D System (CRITICAL - NOT Camera2D!)

**THIS PROJECT USES Camera3D, NOT Camera2D. The implementation is fundamentally different:**

| Feature | Camera2D (WRONG) | Camera3D (CORRECT) |
|---------|------------------|-------------------|
| Pan | `offset` property | `global_position.x/z` |
| Zoom | `zoom` property | `global_position.y` (height) |
| Bounds | `limit_*` properties | Manual AABB clamping |
| Screen→World | `get_canvas_transform()` | Raycast to Y=0 plane |

**Pan Implementation:**
```gdscript
# CORRECT: Camera3D pan via position
_camera.global_position.x -= drag_delta.x * pan_scale
_camera.global_position.z -= drag_delta.y * pan_scale
```

**Zoom Implementation:**
```gdscript
# CORRECT: Camera3D zoom via Y height
# Lower Y = zoomed in, Higher Y = zoomed out
_camera.global_position.y = clampf(new_height, ZOOM_HEIGHT_MIN, ZOOM_HEIGHT_MAX)
```

**Screen-to-World Conversion:**
```gdscript
# CORRECT: Raycast to Y=0 ground plane
var ray_origin: Vector3 = _camera.project_ray_origin(screen_pos)
var ray_direction: Vector3 = _camera.project_ray_normal(screen_pos)
var t: float = -ray_origin.y / ray_direction.y
var world_pos: Vector3 = ray_origin + ray_direction * t
```

#### Autoload Singletons

**NEVER use `class_name` on autoload scripts** - causes conflicts with singleton access.

**Autoload Load Order (dependencies must load first):**
1. GameConstants (no dependencies)
2. GameLogger (no dependencies)
3. ErrorHandler (uses GameLogger)
4. EventBus (no dependencies)
5. Settings (uses EventBus)
6. AudioManager (uses Settings, EventBus)
7. SaveManager (uses EventBus, GameLogger)
8. GameManager (uses all above)

#### EventBus Communication
- Cross-system communication MUST use EventBus signals
- Signal naming: `{noun}_{past_tense_verb}` (e.g., `territory_claimed`)
- Never directly reference other systems - emit signals instead

### Testing Rules (GUT Framework)

#### Test File Organization
- Test files: `tests/unit/test_<feature_name>.gd`
- Test functions: `test_<what_is_being_tested>()`
- All tests extend `GutTest`

#### GUT Signal Testing Pattern
```gdscript
# CORRECT: Use GUT's built-in signal watchers
watch_signals(EventBus)
EventBus.territory_claimed.emit(hex)
assert_signal_emitted(EventBus, "territory_claimed")

# WRONG: Manual callback tracking (unreliable in GUT)
var signal_received = false
EventBus.territory_claimed.connect(func(): signal_received = true)
```

#### Async Test Pattern
```gdscript
# Wait for _ready() to complete before testing
func before_each() -> void:
    node = MyNode.new()
    add_child(node)
    await wait_frames(1)  # REQUIRED for node initialization
```

#### Mock World Manager Pattern
```gdscript
# Create mock with inline script
var world_manager = Node3D.new()
var script_mock := GDScript.new()
script_mock.source_code = """
extends Node3D
func get_world_bounds() -> AABB:
    return AABB(Vector3(-500, 0, -500), Vector3(1000, 1, 1000))
"""
script_mock.reload()
world_manager.set_script(script_mock)
```

#### Test Coverage Requirements
- All new functionality must have tests
- Test acceptance criteria from stories
- Current baseline: 348+ tests passing

### Code Quality & Style Rules

#### Documentation Pattern
```gdscript
## Class description - first line is summary
##
## Extended description with details.
## Architecture: path/to/file.gd
## Story: X-Y-story-name
class_name MyClass
extends Node3D
```

#### Error Handling (AR11 - "Cozy Game" Philosophy)
- **Never crash** - always recover gracefully
- Use `ErrorHandler.handle_error()` for errors
- Use `GameLogger` for logging (NOT `print()`)
- Log levels: `debug()`, `info()`, `warn()`, `error()`

#### Logging Pattern
```gdscript
# CORRECT: Use GameLogger
GameLogger.info("Camera", "Camera bounds initialized")
GameLogger.error("HexTile", "Cannot initialize with null hex")

# WRONG: Direct print
print("Camera bounds initialized")  # Never use this
```

#### Resource Cleanup Pattern (AR18)
```gdscript
func cleanup() -> void:
    # 1. Stop all processes
    set_process(false)
    # 2. Disconnect signals
    # 3. Kill active tweens
    if _tween and _tween.is_running():
        _tween.kill()
    # 4. Clear references
    # 5. Remove from groups
    # 6. Queue for deletion
    queue_free()
```

#### Constants Usage
- Use `GameConstants.CONSTANT_NAME` for game-wide values
- Never hardcode magic numbers
- Define local constants for file-specific values

### Development Workflow Rules

#### Story Completion Checklist
Before marking any story complete:
- [ ] All code compiles without errors
- [ ] No GDScript warnings in Output panel
- [ ] All existing tests pass (348+ baseline)
- [ ] New tests written for new functionality
- [ ] Code follows GDScript style guide

#### Git Commit Pattern
- Descriptive commit messages
- Reference story in commits when applicable
- No secrets or credentials in commits

#### Pre-Story Verification
Before starting implementation:
1. Read existing code in affected area
2. Understand current patterns
3. Plan tests for acceptance criteria

#### Mobile Testing
- Always test with touch emulation enabled
- Verify 1080x1920 portrait layout
- No hover-only interactions (touch-first)

### Critical Don't-Miss Rules

#### NEVER DO THESE (Anti-Patterns)

**Camera System:**
- ❌ NEVER use `camera.zoom` - Camera3D has no zoom property
- ❌ NEVER use `camera.offset` - Camera3D has no offset property
- ❌ NEVER use `camera.limit_*` - Camera3D has no limit properties
- ❌ NEVER use `Vector2` for world positions - always `Vector3`
- ❌ NEVER use `Rect2` for bounds - always `AABB`

**Autoloads:**
- ❌ NEVER add `class_name` to autoload scripts
- ❌ NEVER name autoloads same as Godot built-ins (Logger, Node, etc.)
- ❌ NEVER use `log()` as function name (conflicts with math.log)

**Testing:**
- ❌ NEVER use manual lambda callbacks for signal testing
- ❌ NEVER skip `await wait_frames(1)` after adding nodes

**General:**
- ❌ NEVER use `print()` - always use `GameLogger`
- ❌ NEVER hardcode magic numbers - use constants
- ❌ NEVER assume nodes exist - always null check first

#### Edge Cases to Handle

**Hex Grid:**
- Hex coordinates use axial (q, r) system with implicit s = -q - r
- World Y=0 is ground plane, hex tiles are flat on this plane
- `HexGrid.hex_to_world()` returns Vector3 with y=0

**Territory System:**
- Territory states: UNEXPLORED(0), SCOUTED(1), CONTESTED(2), CLAIMED(3), NEGLECTED(4)
- Initial state is -1 (uninitialized) until TerritoryManager assigns
- State transitions use Tween animations

#### Performance Considerations
- Cache viewport size - don't call `get_viewport().get_visible_rect()` every frame
- Use `pow(decay, delta * 60.0)` for frame-independent decay
- Limit path requests per frame via `MAX_PATH_REQUESTS_PER_FRAME`

---

## Usage Guidelines

**For AI Agents:**
- Read this file before implementing any code
- Follow ALL rules exactly as documented
- When in doubt, prefer the more restrictive option
- Update this file if new patterns emerge

**For Humans:**
- Keep this file lean and focused on agent needs
- Update when technology stack changes
- Review quarterly for outdated rules
- Remove rules that become obvious over time

---

_Last Updated: 2026-01-13_
