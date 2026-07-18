---
name: isaac-entities
description: Add, fix, review, or write handoff prompts for registered Binding of Isaac Repentance entities in neverbrith. Use this whenever a task mentions entities2.xml, entity type/variant/subtype, custom effect entities, familiars, tears, lasers, knives, pickups, NPCs, bosses, collision, entity HP, AI, targeting, contact damage, spawn callbacks, entity:GetData(), or an anm2 visual that needs gameplay behavior. This skill exists because entity work is not the same as a loose Sprite visual.
---

# Isaac Entities

Use this skill for registered or behavior-owning entities in neverbrith.

The goal is to avoid a common category error: implementing a visual-only `Sprite` when the design needs an entity with variant/subtype, collision, lifetime, callbacks, and data.

## First Move

Before editing or writing a prompt:

1. Decide whether the request needs a registered entity or only a visual carrier.
2. If it is visual-only, use `isaac-anm2-visuals` instead.
3. If it has collision, AI, HP, pickup behavior, targeting, contact damage, projectile behavior, familiar behavior, or entity lifetime, continue here.
4. Read `content/entities2.xml` if present, existing entity callbacks, and the closest local entity example before adding a new one.
5. If the entity owns state beyond a single callback, also use `isaac-state-lifecycle`.
6. After file changes, use `isaac-validators` for XML/path checks and `isaac-testing-debugging` for spawn/collision/update verification planning.

Reference examples when local neverbrith examples are not enough:

- YSD: `E:/Isaac - Repentance/ysd/content/entities2.xml`, `E:/Isaac - Repentance/ysd/scripts/`.
- Reverie: `E:/Isaac - Repentance/reverie/content/entities2.xml`, `E:/Isaac - Repentance/reverie/scripts/`.

## Route The Entity

- **Entity registration**: XML type/variant/subtype, name, anm2 path, collision fields, shadow, boss/familiar/pickup distinctions. Read `references/entity-registration.md`.
- **Behavior callbacks**: spawn, init, update, render, collision, damage, death/remove, familiar cache, pickup behavior. Read `references/behavior-callbacks.md`.
- **Visuals and collision**: anm2 animation names, sprite lifetime, collision radius, grid collision, contact damage, world-space versus screen-space visuals. Read `references/visuals-and-collision.md`.
- **State lifecycle**: entity `GetData()`, owner player links, saved plain data, room cleanup, reload safety. Use `isaac-state-lifecycle`.
- **Final review**: read `references/entity-review-checklist.md`.

## Hard Rules

- Do not implement collision or AI with a loose Lua `Sprite`.
- Do not invent type/variant/subtype values. Read current XML and reference examples.
- Do not assume anm2 animation names. Read the `.anm2` before calling `sprite:Play(...)`.
- Do not store live `Entity`, `Player`, `Sprite`, or callback userdata in persistent save data.
- If the entity is tied to a player, specify the owner key and what happens when the player dies, leaves, or the room changes.
- If the entity can damage enemies or players, specify damage source, collision route, flags, cooldown, and whether it can self-trigger loops.
- If this is only a decorative effect, say so and route back to `isaac-anm2-visuals`.

## Handoff Prompt Template

```markdown
## Entity Spec

- Entity kind: effect | familiar | tear | laser | knife | pickup | NPC | boss | other
- XML registration:
- Type / variant / subtype:
- ANM2 path and animation names:
- Spawn route:
- Update/AI route:
- Collision and damage route:
- Owner and state lifetime:
- Reset/remove conditions:
- SFX/render/description surfaces:
- Existing examples to read:
- Required tests/manual checks:
```

## Final Review

Before saying entity work is complete, report:

- The entity route and why it is not only a visual sprite.
- The XML registration or existing entity id used.
- Every callback touched.
- The state owner and cleanup path.
- The anm2 path and animation names.
- Any collision, damage, or remove behavior that still needs in-game verification.
