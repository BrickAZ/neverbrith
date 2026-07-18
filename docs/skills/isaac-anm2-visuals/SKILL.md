---
name: isaac-anm2-visuals
description: Work with `.anm2` visual assets for Binding of Isaac Repentance mods, especially neverbrith. Use this whenever the user asks to create, fix, review, or write a prompt for Isaac `.anm2` visuals, costumes, Lua-loaded Sprite effects, UI/HUD sprites, EID inline icons, or vanilla animation-template reuse. If the visual needs collision, AI, HP, pickup behavior, contact damage, or entities2.xml registration, also use isaac-entities.
---

# Isaac ANM2 Visuals

Use this skill for `.anm2` visual work in Isaac Repentance mods.

The goal is to stop plausible-looking but broken visual hookups: confusing player-body changes with effects, wrong paths, wrong animation names, missing XML registration, bad sprite lifetime, EID icons that do not render, or hand-built `.anm2` files that should have reused a vanilla template.

## First Move

Before editing or writing a prompt, first translate the user's visual request into a carrier. Read `references/visual-carrier-decision.md` when the request says things like "on Isaac", "on the player's head", "around the player", "effect", "body", "appearance", "halo", "mark", or "UI".

Answer these questions before choosing a route:

1. Where does the visual attach: player body, near the player, room/world, screen UI, or EID text?
2. Does it need to follow player body animation and facing direction?
3. Does it need collision, damage, AI, or entity variant/subtype?
4. How long does it live: permanent, conditional, timed, or one-shot?
5. Who owns it: costume XML, Lua `Sprite`, EID, vanilla template, or entity XML?

Then identify the visual route:

- **Costume / player overlay**: player head/body/wing/mask/held visual tied to costumes. Read `references/costumes.md`.
- **Lua Sprite effect**: visual feedback loaded and rendered by Lua with `Sprite:Load`, `:Play`, `:Update`, `:Render`. Read `references/lua-sprite-effects.md`.
- **UI / HUD sprite**: screen-space sprite, button guide, meter, counter, choice panel, or overlay. Read `references/ui-hud-sprites.md`.
- **EID / inline icon**: EID icon, transformation icon, card/pill icon, or text inline visual. Read `references/eid-icons.md`.
- **Vanilla template reuse**: reusing an existing Isaac `.anm2` skeleton and replacing spritesheets or animation/frame. Read `references/vanilla-template-reuse.md`.

If the request is actually about `content/entities2.xml`, entity type/variant/subtype, collision radius, grid collision, NPCs, familiars, tears, lasers, knives, or effects with entity registration, use `isaac-entities` for behavior and registration. Keep this skill only for the `.anm2`, spritesheet, animation-name, and visual-carrier checks.

## Reference Mods

Use local reference mods when available:

- Minimal reference: `E:/Isaac - Repentance/ysd`
- Large Touhou/Reverie reference: `E:/Isaac - Repentance/reverie`
- Current mod: `E:/Isaac - Repentance/mods/neverbrith`

Prefer neverbrith local examples first. Use YSD for small clean patterns and Reverie for broad examples.

## Implementation Rules

- Always connect `.anm2` path, spritesheet PNG path, animation name, and Lua/XML reference as one unit.
- Do not invent animation names. Read the `.anm2` and use its `DefaultAnimation` or named `Animation`.
- Do not assume case-insensitive paths. Match existing repo casing and Isaac's resource-root conventions.
- For generated `.anm2`, keep the first version simple: one spritesheet, one layer, clear pivot, explicit width/height, and one or two animation names.
- If writing a code prompt, include exact files to read, expected asset paths, expected animation names, and the route checklist.
- After file changes, use `isaac-validators` for static path checks when possible, then list in-game render checks separately.

## Local Neverbrith Examples

- EID icon: `resources/gfx/EID/DiceSetIcon.anm2`, registered through EID icon support in `main.lua`.
- Lua visual effect: `resources/gfx/Effects/GoodGirlOfBabylon/GoodGirlHalo.anm2`.
- UI sprite: `resources/gfx/UI/DebugController/DebugControllerKeys.anm2`.
- Costumes: `content/costumes2.xml`, `resources/gfx/characters/costume_*.anm2`.

## Final Review

Before saying the visual work is complete, report:

- The selected route.
- Every `.anm2` path and PNG spritesheet path touched.
- Every XML or Lua file that references the `.anm2`.
- The animation names used.
- Whether the asset is loaded by XML, `Isaac.GetCostumeIdByPath`, EID, or manual `Sprite:Load`.
- Any rendering behavior that still needs in-game verification.
