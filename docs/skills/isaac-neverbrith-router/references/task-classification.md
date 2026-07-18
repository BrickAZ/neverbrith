# Task Classification Checklist

Use this checklist to translate a natural-language Isaac mod request into implementation surfaces.

## Questions

1. What is the player-facing object: collectible, trinket, card, pill, challenge, entity, visual-only effect, UI, description, or audio cue?
2. Does the request create a new registered thing in XML?
3. Does it require a Lua callback, or is it pure metadata/assets?
4. Does the visual attach to Isaac's body, exist in the world, exist on the screen, or appear only inside EID/text?
5. Does it need collision, damage, targeting, HP, AI, pickup behavior, or entity lifetime?
6. Does it need state beyond one callback invocation?
7. Does the state reset on room, floor, run, challenge start, item loss, player death, or game reload?
8. Does it need localization, EID, MCM, Encyclopedia, StageAPI, Boss Bars, or other optional dependency handling?
9. Does it need sound, shader, screen render, or input interception?
10. What can be left as `TBD` instead of guessed?
11. Does the task ask for validation, debugging, proof, or a reproducible test plan?
12. Does the task risk changing module boundaries, callback ownership, load order, or shared helpers?

## Common Misroutes

- "Add an effect around the player" can mean a loose Lua `Sprite`, a costume, or a registered effect entity. Ask whether it needs collision or entity logic.
- "Make a card" is not an item. It needs `pocketitems.xml`, card id lookup, art/HUD keys, descriptions, and card callbacks.
- "Make a trinket" is not an item. It needs trinket XML, trinket id lookup, held/smelted/golden behavior, and multiplier decisions.
- "Make a challenge" is not only a starting item list. It also needs challenge gating, run leakage checks, and behavior restrictions outside the challenge.
- "Active item" is not one template. Decide charge policy, slot, continuing callbacks, UI/input, and state lifetime.
- "Save this" should not mean serializing Isaac userdata. Store plain data and reconstruct runtime references.
- "Looks correct" is not verification. Use validators, tests, and explicit in-game checks.
