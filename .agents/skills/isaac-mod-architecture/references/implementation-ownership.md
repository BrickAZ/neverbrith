# Implementation Ownership

Use this reference whenever a task says "where should this code go?" or a content skill mentions `main.lua`.

## Rule

Treat `main.lua` as the starting point for discovering the load path. It is not automatically the destination for new behavior.

Distinguish these responsibilities when locating affected code; they need not be separate files or repeated output fields:

- **Bootstrap owner**: the file that loads modules or creates the mod object.
- **Behavior owner**: the file that owns the item, card, entity, challenge, or callback behavior.
- **Shared owner**: a helper justified by repeated stable logic or an explicit independent responsibility, such as persistence isolation or an external-API boundary.
- **Verification owner**: the closest behavior test and the static validator command.

## Decision Order

1. Read `main.lua` to find the current include/require/load pattern.
2. Locate the nearest existing behavior of the same content type.
3. Add local behavior beside that owner.
4. Extract a shared helper when repeated stable logic or a concrete independent responsibility justifies the boundary. A single current consumer is acceptable for such infrastructure; keep item-specific policy with its owner.
5. Change the bootstrap/load order only when a new module needs it; report that separately from the feature change.

## Handoff Reference

For a Lua handoff, include the relevant ownership and load-order facts. This is an optional field list, not a fixed response format:

```markdown
- Bootstrap owner:
- Behavior owner:
- Shared owner, if any:
- Load-order change, if any:
```

This keeps future item work compatible with both the current monolithic layout and a later modular layout.
