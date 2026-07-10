# Skill Routing Matrix

Use the smallest set of sibling skills that covers the task.

| User clue | Primary skill | Add these when present |
| --- | --- | --- |
| "new item", passive, active, item pool, quality | `isaac-neverbrith-dev` | `isaac-active-item-mechanics`, `isaac-anm2-visuals`, `isaac-compat-descriptions`, `isaac-state-lifecycle` |
| trinket, gulped, smelted, golden trinket | `isaac-trinkets` | `isaac-state-lifecycle`, `isaac-anm2-visuals`, `isaac-compat-descriptions` |
| charge, held input, selection UI, failed active use | `isaac-active-item-mechanics` | `isaac-audio-render-feedback`, `isaac-state-lifecycle`, `isaac-cards-pockets` |
| custom card, rune, soul stone, pill, blank card | `isaac-cards-pockets` | `isaac-anm2-visuals`, `isaac-compat-descriptions`, `isaac-state-lifecycle` |
| challenge, starting items/cards, stage restriction | `isaac-challenges` | `isaac-cards-pockets`, `isaac-state-lifecycle`, `isaac-compat-descriptions` |
| familiar, effect entity, tear, pickup, NPC, variant | `isaac-entities` | `isaac-anm2-visuals`, `isaac-state-lifecycle`, `isaac-audio-render-feedback` |
| costume, .anm2, halo sprite, UI sprite, EID icon | `isaac-anm2-visuals` | `isaac-entities` if registered behavior is needed |
| SFX, shader, screen overlay, render callback | `isaac-audio-render-feedback` | `isaac-anm2-visuals`, `isaac-state-lifecycle` |
| EID, translation, MCM, Encyclopedia | `isaac-compat-descriptions` | main content skill for the registered object |
| table state, GetData, room/floor reset, SaveData | `isaac-state-lifecycle` | main gameplay skill that owns the mechanic |
| validate, check, missing path, duplicate id, static sanity | `isaac-validators` | main content skill for the changed object |
| debug, prove, reproduce, test, not triggering, leaking | `isaac-testing-debugging` | `isaac-validators`, symptom-specific content skill |
| main.lua too large, modules, load order, shared helper | `isaac-mod-architecture` | affected content skills, `isaac-testing-debugging`, `isaac-validators` |

When two skills compete, choose the content identity first, then add mechanics and presentation skills.
