# Neverbrith Project Routing Table

The general skill taxonomy belongs to `isaac-repentance-router`. These
entries add the contracts specific to this checkout.

| Task | Project route |
| --- | --- |
| Collectible registration, behavior or lookup | Use `isaac-neverbrith-dev` for the project adapter. Its registration reference points to the actual XML, locale templates, generated registry and behavior owner. The generic collectible, active/passive, economy and damage contracts stay with the applicable specialists. |
| Native ESC/My Stuff or Last Will collectible portrait | Locate the repository's migration guidance from `docs/agent/index.md`. Use `isaac-anm2-visuals` for the portrait and check its stable XML-local ID independently from the colored icon. |
| REPENTOGON loading, builds or extension behavior | The neverbrith bootstrap requires REPENTOGON. Read the checkout README and `main.lua`. Use `isaac-repentogon-compat` for loading and version evidence and the focused callbacks, content, world or UI skill for the requested API. |
| Descriptions or localization | Use the project map to find the current XML, language templates, EID owner and text tests; select the description, localization or exact API specialist by the requested surface. |
| Validation or reproduction | Use `isaac-neverbrith-validator-profile` and `docs/agent/testing.md` for the repository entry point. Use `isaac-testing-debugging` for symptom and in-game evidence. |

For projectile mechanics, player/familiar-owned attacks use
`isaac-projectile-combat` and NPC/Boss-owned patterns use `isaac-npc-boss-ai`.
If ownership is unknown, trace the firing or spawning source and damage
credit. Use `isaac-entities` for a separate XML/type/variant or generic entity
lifecycle question.
