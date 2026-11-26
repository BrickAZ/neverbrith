---
name: isaac-stageapi-compat
description: Add, review, or debug third-party StageAPI integration for Binding of Isaac Repentance mods. Use for StageAPI custom rooms, stages, doors, room transitions, callbacks, and version-sensitive room/stage enhancements. Require an explicitly declared and usable StageAPI installation first; never assume a StageAPI version, function, or fallback path. 中文触发：StageAPI、自定义楼层、自定义房间、StageAPI 房间、StageAPI 门、StageAPI 兼容。
---

# Isaac StageAPI Compatibility

## User Decisions and Technical Discovery

Read the [shared decision and evidence policy](../isaac-mod-context/references/tbd-disclosure.md).

StageAPI is a third-party expansion route, not a substitute for project
discovery or official API behavior. It may be a declared required dependency or
a guarded optional enhancement; undeclared means optional.

## First Move

1. Use `isaac-mod-context` and `isaac-rooms-stages` to discover the mod's
   declared dependency, current room/stage authority, and official fallback.
2. Prove four separate facts before selecting a method: runtime object,
   installed version/API surface, bootstrap/load order, and ready/loaded state.
   A non-nil global may exist before StageAPI has finished registering itself.
3. Classify StageAPI as required, optional enhancement, or undeclared. For an
   optional path, define the official equivalent or explicit absence of the
   enhancement. For a required path, define the clear pre-registration stop
   boundary. Keep unapproved content, IDs, weights, and transition policy as
   `TBD`.

## Hard Rules

- Do not `require` StageAPI or call it before a guarded availability check.
- Do not treat object existence as readiness. Register through a ready hook
  proven by the installed build, or a discovered project bootstrap that runs
  after StageAPI marks itself loaded. If the installed build exposes
  `RunWhenMarkedLoaded`, verify its signature before using it.
- The ready hook and any retry must be idempotent: immediate-ready and
  deferred-ready paths must converge on the same single registration.
- Never make a normal run crash, softlock, or mutate unrelated rooms when an
  optional library is absent or unsupported. If StageAPI is explicitly required,
  stop this mod before partial room/stage registration and report the dependency.
- Own only rooms, doors, state, and callbacks created by this integration.
  Route lifecycle to `isaac-state-lifecycle` and callback details to
  `isaac-callback-contracts`.
- Test no-StageAPI behavior separately from the installed-StageAPI branch;
  test repeated registration and room transition cleanup.

## Bundled Offline Reference

Read `references/stageapi-contract.md` before selecting a StageAPI load,
registration, or fallback strategy. It records maintainer-documented scope and
tooling boundaries, while installed StageAPI code/docs remain authoritative.
## Contract Reference

```markdown
## StageAPI Compatibility Contract
- Dependency mode and declaration:
- Object/version/bootstrap/ready proof:
- Required stop boundary or optional official/no-op fallback:
- Owned room/stage/door identifiers:
- Registration and lifecycle timing:
- No-StageAPI and unsupported-version behavior:
- Tests and in-game checks:
```
