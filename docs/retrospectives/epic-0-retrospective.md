# Epic 0: Project Foundation - Retrospective

**Date:** 2026-01-11
**Epic:** 0 - Project Foundation
**Status:** Complete

## Summary

Epic 0 established the foundational infrastructure for AnimalsCraft, a cozy mobile game for Android. This epic covered project initialization, autoload singletons, event bus architecture, logging/error handling, and scene management.

## Stories Completed

| Story | Title | Status |
|-------|-------|--------|
| 0.1 | Initialize Godot Project | Done |
| 0.2 | Core Autoloads | Done |
| 0.3 | EventBus Signal Hub | Done |
| 0.4 | Logger and ErrorHandler | Done |
| 0.5 | Scene Management | Done |
| 0.6 | Android Export Configuration | Done |

## What Went Well

1. **Solid Architecture Foundation**
   - EventBus pattern enables decoupled system communication
   - Autoload singleton hierarchy properly ordered by dependencies
   - Error handling follows "cozy game" philosophy (never crash, always recover)

2. **Comprehensive Test Coverage**
   - 147 unit tests covering all core systems
   - Tests verify architecture compliance, not just functionality
   - GUT test framework properly integrated

3. **Mobile-First Configuration**
   - Portrait orientation (1080x1920) configured
   - Mobile renderer enabled
   - Touch emulation for desktop testing
   - Android export with Gradle build system

## Challenges Identified

### Challenge 1: Missing Test Infrastructure in Story 0.1

**Issue:** Story 0.1 created test files but didn't install the GUT test framework, leaving tests non-functional.

**Resolution:** Installed GUT addon (v9.3.0), created `.gutconfig.json`, and verified all tests run.

**Lesson Learned:** Test infrastructure should be installed and verified as part of the first story that creates tests.

### Challenge 2: Autoload Naming Conflicts

**Issue:** Multiple critical issues discovered when running tests:
- `class_name` declarations on autoloads conflicted with singleton access
- `Logger` autoload name shadowed Godot's native Logger class
- `log()` function name conflicted with built-in math function

**Resolution:**
- Removed `class_name` from all 6 autoload scripts
- Renamed Logger autoload to GameLogger in project.godot
- Renamed `log()` function to `write()`
- Fixed GUT addon's internal Logger conflict

**Lesson Learned:** Always verify autoload names don't conflict with Godot built-ins. Test autoloads in isolation before integration.

### Challenge 3: Test Design Patterns

**Issue:** Signal emission tests using lambda callbacks failed silently due to GDScript closure behavior in GUT context.

**Resolution:** Converted all signal tests to use GUT's built-in `watch_signals()` and `assert_signal_emitted()` methods.

**Lesson Learned:** Use framework-native testing patterns rather than custom implementations. GUT's signal watcher is more reliable than manual callback tracking.

### Challenge 4: ErrorHandler Auto-Recovery Design

**Issue:** Tests expected error state to persist after `handle_error()`, but the auto-recovery design immediately clears state for unknown systems.

**Resolution:** Updated tests to either:
- Directly manipulate internal state for state-verification tests
- Use `watch_signals()` to verify signal emission flow
- Test the actual behavior (auto-recovery) rather than assumed behavior

**Lesson Learned:** Tests should verify actual system behavior, not assumed behavior. Read implementation before writing tests.

## Metrics

| Metric | Value |
|--------|-------|
| Tests Written | 147 |
| Tests Passing | 147 (100%) |
| Test Files | 5 |
| Autoloads Created | 8 |
| Scenes Created | 2 (main.tscn, game.tscn) |
| Lines of Test Code | ~1,500 |

## Action Items for Future Epics

1. **Pre-Story Checklist** - Create and enforce a checklist before marking stories as "done"
2. **Test-First Approach** - Run tests after every code change, not just at epic completion
3. **Naming Conventions** - Document and verify naming conventions against Godot reserved names
4. **Documentation** - Add architecture decision records (ADRs) for significant choices

## Pre-Review Checklist (Formalized)

Before marking any story as complete:

- [ ] All code compiles without errors or warnings
- [ ] All existing tests pass (`147/147`)
- [ ] New tests written for new functionality
- [ ] Test framework (GUT) loads and recognizes tests
- [ ] Autoload names don't conflict with Godot built-ins
- [ ] No `class_name` on autoload scripts
- [ ] Signal names follow `{noun}_{past_tense_verb}` convention
- [ ] Error handling follows "cozy game" philosophy
- [ ] Mobile configuration unchanged (1080x1920 portrait)
- [ ] Code follows GDScript style guide

## Next Epic Recommendations

With the foundation solid, recommended next steps:

1. **Epic 1: Hex Grid System** - Core world representation
2. **Epic 1: Resource System** - Wood, wheat, flour management
3. **Epic 1: Basic UI** - HUD and menus

The test infrastructure is now verified and working. Future development can proceed with confidence that the foundation is stable.
