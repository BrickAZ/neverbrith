---
name: isaac-neverbrith-router
description: First-pass dispatcher for Binding of Isaac Repentance `neverbrith` mod work. Use this before implementing, fixing, reviewing, or writing a handoff prompt for any neverbrith gameplay, item, trinket, card, challenge, entity, visual, audio, description, validation, debugging, architecture, or stateful mechanic, especially when the user's request mixes "change Isaac himself", "special effect", "entity", "card", "challenge", "active item", UI, sounds, descriptions, tests, or save/state behavior. 中文触发：以撒 mod、neverbrith、道具、饰品、卡牌、挑战、实体、改以撒本体、特效、动画、音效、描述、验证、排错、状态、存档、拆模块。 This skill exists to prevent choosing the wrong Isaac modding surface at the start.
---

# Isaac Neverbrith Router

Use this skill as the first stop for neverbrith implementation and handoff work.

The goal is to classify the user's request before writing code. Many Isaac mod bugs come from choosing the wrong surface: treating a registered entity as a loose sprite, treating a player costume as a visual effect, treating a card as a collectible, or putting persistent state in a table that only survives one room.

## First Move

Before editing or writing a code prompt:

1. Restate the user's request as one or more content surfaces.
2. Identify whether the request changes gameplay, visuals, descriptions, audio/render feedback, saved state, or only metadata.
3. Choose one primary skill. Add sibling skills only for concrete secondary surfaces; do not load a broad checklist merely because a task is non-trivial.
4. Identify the current implementation owner: `main.lua` only as bootstrap, or the specific module/callback file that owns the behavior.
5. For design, reward, balance, and visual decisions, read `references/user-decision-authority.md`. Keep unknown fields as `TBD` instead of inventing defaults.

Read `references/task-classification.md` for the classification checklist and `references/skill-routing-matrix.md` for the sibling skill map.

## Multi-Surface Order

When a request has multiple surfaces, process only the applicable layers in
this order:

1. Define the mechanic contract when trigger, success, exclusions, reward, or
   settlement is unclear.
2. Select the owning content surface: item, trinket, card, challenge, entity,
   reward, or visual-only asset.
3. Select callbacks only after the event and owner are clear.
4. Add state lifecycle only when behavior survives a callback or needs reset.
5. Add ANM2, audio, descriptions, and optional compatibility as secondary
   presentation surfaces.
6. Finish with static validation, behavior tests, and in-game checks.

Do not let a later layer answer an earlier unknown. For example, UI work cannot
decide an active item's failed-use rule, and a callback cannot decide which
reward the user intended.

## Content Surfaces

Classify the task into one or more of these surfaces:

- **Collectible registration**: `items*.xml`, explicit stable local id, colored collectible PNG, `gfxroot + gfx`, or ESC/death-portrait registration boundary. Use `isaac-collectible-registration`; add `isaac-neverbrith-dev` for this project's lookup and callback wiring.
- **Passive collectible behavior**: held ownership/count, cache effects, acquisition/loss, co-op, or passive-owned state. Use `isaac-neverbrith-dev` with `isaac-passive-collectibles`.
- **Damage/health behavior**: cancellation, replacement, shield, healing, lethal, i-frames, or re-entry. Use `isaac-damage-health-contracts`; keep `isaac-neverbrith-dev` only for project integration.
- **Item synergy**: two or more inputs, precedence, duplicate prevention, loss, or external content eligibility. Use `isaac-item-synergies`.
- **Reroll/removal boundary**: Morph, removal, replacement, reacquisition, temporary grants, or stale owned state. Use `isaac-reroll-removal-contracts`.
- **Randomness contract**: seeded RNG, draw timing, owner-specific streams, restart determinism, or per-frame random behavior. Use `isaac-rng-determinism`.
- **Trinket**: `trinkets.xml`, held/smelted/golden behavior, `Isaac.GetTrinketIdByName`, `player:HasTrinket`, `GetTrinketMultiplier`. Use `isaac-trinkets`.
- **Complex active item**: held input, charge policy, slot handling, temporary UI, card/pill interaction, room/floor state. Use `isaac-active-item-mechanics`.
- **Card, rune, soul stone, or pill**: `pocketitems.xml`, `MC_USE_CARD`, `MC_GET_CARD`, blank card art, HUD keys. Use `isaac-cards-pockets`.
- **Challenge**: `content/challenges.xml`, challenge starting inventory, stage restrictions, special rules, non-leak checks. Use `isaac-challenges`.
- **Player or character**: custom player registration, tainted variant, starting inventory, Birthright behavior, co-op player identity, or per-player character state. Use `isaac-players-characters`.
- **NPC or boss AI**: NPC/boss phase, attack state, projectile pattern, death settlement, or multiple-instance isolation. Use `isaac-npc-boss-ai`.
- **Room or stage**: one room, layout, legal doors, room transition, stage/floor mutation, or room-local encounter state. Use `isaac-rooms-stages`.
- **Owned room network**: multiple custom rooms acting as one area, node/edge graph, entry/return, or partial allocation failure. Use `isaac-room-networks`.
- **Game-level Dimension**: Dimension identity, entry/exit, return context, or cross-dimension isolation. Use `isaac-dimensions`; do not treat a room network as a new Dimension.
- **Unlock or progression**: completion condition, achievement, persistent unlock flag, one-time grant, or availability gate. Use `isaac-unlocks-progression`.
- **Custom familiar**: item/character-owned companion count, `CACHE_FAMILIARS`, `CheckFamiliar`, `MC_FAMILIAR_INIT/UPDATE`, follow/orbit, collision, owner, multi-copy, or co-op behavior. Use `isaac-familiars`; add `isaac-entities` for XML/type/variant/subtype facts.
- **Player/familiar projectile combat**: player/familiar tears, lasers, knives, bombs, attack spawn, split/reflect, hit/damage, projectile ownership, source credit, or projectile cleanup. Use `isaac-projectile-combat`; add `isaac-entities` for registration facts and `isaac-familiars` when the shooter is a custom familiar.
- **Registered entity**: `entities2.xml`, type/variant/subtype, effect/tear/pickup/NPC behavior, collision, entity callbacks. Use `isaac-entities`.
- **Character art**: player skins, hair, head decorations, portraits, names, co-op art, or generated player surfaces. Use `isaac-character-art-surfaces`; add `isaac-anm2-visuals` for the actual carrier.
- **Existing-vanilla reskin**: resource-only exact-path override, runtime actor/spritesheet swap, Null Costume overlay, or load-order conflict. Use `isaac-reskins-resource-overrides`.
- **ANM2 visual asset**: costume, loose Lua `Sprite`, UI/HUD sprite, EID icon, vanilla animation template reuse. Use `isaac-anm2-visuals`.
- **Audio/render feedback**: SFX, music, shader parameters, `MC_POST_RENDER`, `MC_GET_SHADER_PARAMS`, input interception for feedback. Use `isaac-audio-render-feedback`.
- **Descriptions and dependency gates**: XML/EID/wiki text synchronization, optional-library classification, or shared compatibility text. Use `isaac-compat-descriptions`.
- **Runtime localization**: language tables, `Options.Language`, language-specific assets, fonts, or runtime fallback. Use `isaac-localization-runtime`.
- **Exact optional EID integration**: concrete EID calls, registration, version, or duplicate handling. Use `isaac-eid-compat`.
- **Exact optional MCM integration**: Mod Config Menu controls, registration, late loading, or duplicate handling. Use `isaac-mcm-compat` with `isaac-config-options` for setting authority.
- **Exact optional StageAPI integration**: StageAPI rooms, stages, doors, transitions, callbacks, or versions. Use `isaac-stageapi-compat`.
- **Exact optional REPENTOGON integration**: REPENTOGON callbacks, XML, globals, Lua 5.4, or version gates. Use `isaac-repentogon-compat`.
- **Configuration options**: config setting, toggle/default authority, saved preferences, malformed-data recovery, or gameplay setting gate. Use `isaac-config-options`; MCM UI additionally uses `isaac-mcm-compat`.
- **Performance hot path**: per-frame scans, repeated Spawn, resource reload, cache churn, or render/update stutter. Use `isaac-performance-hotpaths`.
- **State lifecycle**: `GetData()`, local state tables, room/floor/run reset, SaveData/LoadData, reload safety. Use `isaac-state-lifecycle`.
- **Mechanic contract**: trigger meaning, eligibility, exclusions, success/failure, delayed settlement, repetition, recursion, gameplay versus presentation, and compatibility boundary. Use `isaac-mechanic-contracts` before choosing callbacks when the mechanic is not already explicit.
- **Callback contract**: callback selection, timing, registration filters, handler signatures, return policies, cache refresh, priority, and duplicate registration. Use `isaac-callback-contracts` after a mechanic is clear.
- **Item economy**: quality, item pools, weights, depletion, tags, unlock availability, pool dilution, and itempools language sync. Use `isaac-item-economy` for where and how often a collectible appears.
- **Rewards and pickups**: reward source, candidate selection, pickup Spawn/Morph, repeat boundaries, de-duplication, and failed replacement preservation. Use `isaac-rewards-pickups`.
- **Validation or debugging**: static checks, XML parse, duplicate ids, missing assets, failing tests, in-game verification plan, symptom triage. Use `isaac-validators` and/or `isaac-testing-debugging`.
- **Architecture**: module boundaries, callback registration organization, shared helpers, load order, reducing `main.lua` growth. Use `isaac-mod-architecture`.

## Hard Routing Rules

- If the request says "effect" but needs collision, AI, HP, targeting, pickup behavior, variant/subtype, or damage contact, route to `isaac-entities`.
- If the request says "familiar", "baby", "companion", "CheckFamiliar", "CACHE_FAMILIARS", "follow", or "orbit", route to `isaac-familiars` first; add `isaac-entities` only for registration facts.
- If the request says "tear", "laser", "knife", "projectile", "split", "reflect", "shot", "SpawnerEntity", or "EntityRef" and the source is a player/familiar, route to `isaac-projectile-combat`; Boss/NPC patterns remain `isaac-npc-boss-ai`.
- If the request says "change Isaac" or "on Isaac's body", decide between costume/player overlay and gameplay stat/body changes before touching anm2.
- If the request says "card" or "rune", do not route it through collectible item registration.
- If the request says "trinket", "gulped", "smelted", or "golden trinket", do not route it through collectible item registration.
- If the request says "character", "tainted", "Birthright", "start with", or "co-op player", route to `isaac-players-characters`; add item/card skills only for the concrete starting content.
- If the request says "boss", "NPC phase", "attack pattern", "projectile", or "death reward", route to `isaac-npc-boss-ai`; add `isaac-entities` for registration and `isaac-rewards-pickups` for a concrete reward path.
- If the request says "special room", "door", "layout", "stage", "floor", or "room transition", route one-room topology to `isaac-rooms-stages`, a multi-room owned area to `isaac-room-networks`, and a true Dimension context to `isaac-dimensions`; do not assume StageAPI is installed.
- If the request says "unlock", "achievement", "completion", "persistent flag", or "one-time reward", route to `isaac-unlocks-progression`; keep the unlock condition and the availability gate separate.
- If the request says "active item", route by the hard part: charge/input/UI/state/damage/card interaction, not by `MC_USE_ITEM` alone.
- If any behavior survives beyond one frame, explicitly route to `isaac-state-lifecycle`.
- If the task's main uncertainty is what a mechanic means rather than how an XML type is registered, route to `isaac-mechanic-contracts` before implementation.
- If the mechanic is clear but callback timing, filter, signature, return, or registration is uncertain, route to `isaac-callback-contracts`.
- If the request asks which pool, quality, weight, tag, unlock route, or rarity an item should have, route to `isaac-item-economy`.
- If the request chooses, spawns, morphs, replaces, or de-duplicates a reward or pickup, route to `isaac-rewards-pickups`; also use `isaac-entities` when the target itself is custom.
- Never replace an explicit user design decision with a default. Mark omissions as `TBD` and label any proposal as a suggestion that needs approval.
- If the request includes player-facing text, route to `isaac-compat-descriptions` even when the main mechanic belongs elsewhere.
- If the request says "setting", "toggle", "option", "enable", "disable", "default value", or "saved preference", route setting authority to `isaac-config-options`; if it explicitly requires MCM calls or controls, add `isaac-mcm-compat`.
- If the request names EID, StageAPI, MCM, or REPENTOGON and requires concrete API work, route to the matching dedicated compatibility skill; `isaac-compat-descriptions` does not replace it.
- If the request creates or registers a collectible, route XML/local-id/colored-icon work to `isaac-collectible-registration` before project-specific behavior wiring.
- If the request includes a visible asset, route to `isaac-anm2-visuals` or `isaac-entities` depending on whether the visual is only a sprite/costume or a registered entity.
- If the request asks "how do I know this works", "check it", "verify", or reports a bug symptom, route to `isaac-testing-debugging` and run `isaac-validators` where possible.
- If the request touches many files, moves callbacks, or adds a reusable helper, route to `isaac-mod-architecture` before editing structure.

## Required Output Before Implementation

For non-trivial work, produce a short routing block before editing:

```markdown
## Isaac Route

- Primary surface:
- Secondary surfaces:
- Skills to load:
- Files to inspect first:
- Current implementation owner:
- Locked / approved / TBD / suggestions:
- Unknown fields kept as TBD:
- In-game checks needed:
```

Then do the work using the selected sibling skills.

## Final Review

Before saying the task is complete, report:

- Which route was selected and why.
- Which sibling skills were used.
- Which files were changed or should be read by the next agent.
- Which surfaces were intentionally not touched.
- Which checks were automated and which still need in-game verification.
