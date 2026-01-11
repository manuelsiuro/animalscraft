# Story Completion Checklist

Use this checklist before marking any story as "done". All items must pass.

## Code Quality

- [ ] All code compiles without errors
- [ ] No GDScript warnings in Output panel
- [ ] Code follows [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html)
- [ ] Functions have doc comments for public API
- [ ] No hardcoded magic numbers (use GameConstants)

## Testing

- [ ] GUT test runner opens without errors
- [ ] All existing tests pass (check count: `147+`)
- [ ] New tests written for new functionality
- [ ] Tests use GUT patterns (`watch_signals`, `assert_signal_emitted`)
- [ ] No tests skipped or commented out

## Autoloads (if modified)

- [ ] No `class_name` declaration on autoload scripts
- [ ] Autoload name doesn't conflict with Godot built-ins
- [ ] Autoload order correct in Project Settings
- [ ] Dependencies load before dependents

## Signals (if added)

- [ ] Signal name follows `{noun}_{past_tense_verb}` pattern
- [ ] Signal parameters have type hints
- [ ] Signal documented with `##` comment
- [ ] Added to EventBus if cross-system communication

## Architecture Compliance

- [ ] No direct imports between systems (use EventBus)
- [ ] Error handling uses ErrorHandler.handle_error()
- [ ] Logging uses GameLogger (not print())
- [ ] Null safety via guard clauses (AR18)

## Mobile Compatibility

- [ ] Touch input considered (no hover-only interactions)
- [ ] UI scales properly at 1080x1920
- [ ] No desktop-only features
- [ ] Performance acceptable on mobile renderer

## Git

- [ ] Changes committed with descriptive message
- [ ] Commit follows conventional commits format
- [ ] No untracked files left behind
- [ ] No secrets or credentials in commit

## Final Verification

Run these commands before marking complete:

```bash
# In Godot Editor
1. Project > Reload Current Project
2. Open GUT panel (bottom)
3. Click "Run All"
4. Verify: All tests pass

# In terminal
git status  # Should be clean
```

---

*Created from Epic 0 retrospective lessons learned (2026-01-11)*
