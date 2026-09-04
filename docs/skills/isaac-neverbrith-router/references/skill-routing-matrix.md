# Skill Routing Matrix

Use the smallest set of sibling skills that covers the task.

| User clue | Primary skill | Add these when present |
| --- | --- | --- |
| "new item", passive, active, item pool, quality | `isaac-neverbrith-dev` | `isaac-active-item-mechanics`, `isaac-anm2-visuals`, `isaac-compat-descriptions`, `isaac-state-lifecycle` |
| trigger condition, delayed effect, success/failure meaning, exclusion, recursion, loophole | `isaac-mechanic-contracts` | content-identity skill, `isaac-state-lifecycle`, `isaac-testing-debugging` |
| callback, handler, registration, filter, return value, cache refresh, timing | `isaac-callback-contracts` | main content skill, `isaac-mechanic-contracts`, `isaac-testing-debugging` |
| quality, item pool, weight, tags, rarity, unlock, pool dilution | `isaac-item-economy` | `isaac-neverbrith-dev`, `isaac-compat-descriptions`, `isaac-validators` |
| trinket, gulped, smelted, golden trinket | `isaac-trinkets` | `isaac-state-lifecycle`, `isaac-anm2-visuals`, `isaac-compat-descriptions` |
| charge, held input, selection UI, failed active use | `isaac-active-item-mechanics` | `isaac-audio-render-feedback`, `isaac-state-lifecycle`, `isaac-cards-pockets` |
| custom card, rune, soul stone, pill, blank card | `isaac-cards-pockets` | `isaac-anm2-visuals`, `isaac-compat-descriptions`, `isaac-state-lifecycle` |
| challenge, starting items/cards, stage restriction | `isaac-challenges` | `isaac-cards-pockets`, `isaac-state-lifecycle`, `isaac-compat-descriptions` |
| custom player, tainted, Birthright, starting inventory, co-op character behavior | `isaac-players-characters` | starting-content skill, `isaac-state-lifecycle`, `isaac-anm2-visuals`, `isaac-compat-descriptions` |
| NPC, boss, phase, attack pattern, projectile, death behavior | `isaac-npc-boss-ai` | `isaac-entities`, `isaac-state-lifecycle`, `isaac-rewards-pickups`, `isaac-anm2-visuals` |
| special room, room layout, door, room transition, stage, floor | `isaac-rooms-stages` | `isaac-state-lifecycle`, `isaac-entities`, `isaac-rewards-pickups`, `isaac-compat-descriptions` |
| unlock, achievement, completion condition, persistence, one-time grant | `isaac-unlocks-progression` | owned content skill, `isaac-state-lifecycle`, `isaac-item-economy`, `isaac-testing-debugging` |
| familiar, baby, companion, `CheckFamiliar`, familiar cache, follow/orbit, familiar co-op | `isaac-familiars` | `isaac-entities`, `isaac-anm2-visuals`, `isaac-state-lifecycle`, `isaac-audio-render-feedback` |
| player/familiar tear, laser, knife, bomb, attack projectile, split, reflect, projectile collision/damage | `isaac-projectile-combat` | `isaac-familiars`, `isaac-entities`, `isaac-state-lifecycle`, `isaac-anm2-visuals` |
| effect entity, tear, pickup, NPC, variant | `isaac-entities` | `isaac-anm2-visuals`, `isaac-state-lifecycle`, `isaac-audio-render-feedback` |
| costume, .anm2, halo sprite, UI sprite, EID icon | `isaac-anm2-visuals` | `isaac-entities` if registered behavior is needed |
| SFX, shader, screen overlay, render callback | `isaac-audio-render-feedback` | `isaac-anm2-visuals`, `isaac-state-lifecycle` |
| EID, translation, Encyclopedia | `isaac-compat-descriptions` | main content skill for the registered object |
| MCM, setting, toggle, default, saved preference, enable/disable | `isaac-config-options` | `isaac-compat-descriptions`, `isaac-state-lifecycle`, `isaac-mechanic-contracts`, owned content skill |
| table state, GetData, room/floor reset, SaveData | `isaac-state-lifecycle` | main gameplay skill that owns the mechanic |
| validate, check, missing path, duplicate id, static sanity | `isaac-validators` | main content skill for the changed object |
| debug, prove, reproduce, test, not triggering, leaking | `isaac-testing-debugging` | `isaac-validators`, symptom-specific content skill |
| main.lua too large, modules, load order, shared helper | `isaac-mod-architecture` | affected content skills, `isaac-testing-debugging`, `isaac-validators` |

When two skills compete, choose the content identity first, then add mechanics and presentation skills.
