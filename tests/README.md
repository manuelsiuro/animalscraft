# AnimalsCraft Test Suite

This directory contains automated tests for the AnimalsCraft project.

## Structure

```
tests/
├── unit/          # Unit tests for individual components
│   └── test_project_initialization.gd  # Story 0.1 smoke tests
└── README.md      # This file
```

## Test Framework

We use **GUT (Godot Unit Test)** for testing Godot projects.

### Installation (Story 0.2+)

GUT will be installed as part of Story 0.2 when we set up the test infrastructure.

**Installation Steps:**
1. Download GUT from [https://github.com/bitwes/Gut](https://github.com/bitwes/Gut)
2. Install via Godot Asset Library or manually
3. Add GUT autoload in project settings
4. Configure test runner scene

### Running Tests

**Once GUT is installed:**

1. **Via Godot Editor:**
   - Open the GUT panel (usually bottom panel)
   - Click "Run All Tests"
   - View results in the panel

2. **Via Command Line:**
   ```bash
   godot --headless --script addons/gut/gut_cmdln.gd -gtest=res://tests/unit/
   ```

3. **Continuous Integration:**
   - Tests can be integrated into CI/CD pipelines
   - See Story 0.2 for GitHub Actions setup

## Test Naming Conventions

- Test files: `test_<feature_name>.gd`
- Test functions: `test_<what_is_being_tested>()`
- Helper functions: `_helper_<purpose>()`

## Current Test Coverage

### Story 0.1: Initialize Godot Project
- ✅ `test_project_initialization.gd` - Verifies AC1-AC4
  - Project configuration validity
  - Mobile renderer enabled
  - Display settings (1080x1920 portrait)
  - Folder structure exists
  - Main and Game scenes load
  - Game scene subsystems present

**Coverage:** 6/6 tests covering all acceptance criteria

## Future Tests

### Story 0.2: Core Autoloads
- Autoload initialization order
- EventBus signal definitions
- Logger formatting
- ErrorHandler graceful degradation

### Epic 1+: Feature Tests
- Hex grid coordinate math
- Pathfinding algorithms
- Animal state machines
- Combat calculations
- Production chains

## Best Practices

1. **One Assertion Per Test** - Keep tests focused and clear
2. **AAA Pattern** - Arrange, Act, Assert structure
3. **No External Dependencies** - Tests should be isolated
4. **Fast Execution** - Keep unit tests under 100ms each
5. **Clear Failure Messages** - Use descriptive assert messages

## Architecture Compliance

All tests follow these architecture requirements:

- **AR18**: Null safety with guard clauses
- **AR11**: Graceful error handling (never crash)
- **AR13**: snake_case file names, PascalCase class names

## Resources

- [GUT Documentation](https://github.com/bitwes/Gut/wiki)
- [Godot Testing Best Practices](https://docs.godotengine.org/en/stable/tutorials/scripting/unit_testing.html)
- Architecture Document: `_bmad-output/game-architecture.md`
