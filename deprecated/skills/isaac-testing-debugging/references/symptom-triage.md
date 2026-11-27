> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-testing-debugging/references/symptom-triage.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Symptom Triage

Map the symptom to the likely failing surface before editing.

| Symptom | Likely surfaces |
| --- | --- |
| Blank or wrong card | pocket XML, pickup art, HUD key, card id lookup, generation callback |
| Item does nothing | collectible id lookup, callback registration, ownership check, active slot, charge return |
| Passive stats wrong | cache flags, `MC_EVALUATE_CACHE`, item count, multiplier, cache re-evaluation |
| Damage behavior loops | damage flags, source entity, recursion guard, state settlement |
| Visual missing | asset path, `.anm2` animation name, sprite update/render owner, XML registration |
| Entity stands still | type/variant/subtype, update callback, animation update, owner state |
| Challenge affects normal run | missing `Isaac.GetChallenge()` gate, stale state, callback too broad |
| Works until room change | room reset, owner key, entity remove cleanup |
| Works until reload | SaveData shape, runtime reconstruction, userdata serialization mistake |

If multiple surfaces fit, use `isaac-mod-context` to discover project structure, then choose the sibling skills named by the symptom routes.
