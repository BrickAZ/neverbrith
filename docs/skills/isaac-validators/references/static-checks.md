# Static Checks

Static validators are useful when they check facts that do not require Isaac to run.

## Good Static Checks

- XML parses.
- Duplicate ids or names are absent inside a file.
- Referenced files exist at the expected path.
- Language variants contain matching internal names.
- Skill directories contain `SKILL.md` and valid eval JSON.
- Test files exist for non-trivial behavior.

## Weak Static Checks

- Balance.
- Callback timing.
- Shader safety.
- Input behavior.
- Entity collision behavior.
- Whether an animation looks correct in-game.

For weak checks, report a manual in-game verification item instead of pretending the validator proves it.

## Extension Pattern

When adding a check:

1. Make the check deterministic.
2. Keep output actionable: file, field, value, and expected fix.
3. Use warnings for uncertain checks and failures for definite breakage.
4. Avoid network access.
5. Avoid modifying files from a validator.
