> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-cards-pockets/references/card-generation.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Card Generation And Replacement

Use this when a card appears in random generation, challenge starting inventory, item effects, or replacement callbacks.

## Routes

- `MC_GET_CARD`: replace card selection from the card pool.
- Challenge XML `startingcard`: static starting card id.
- Challenge Lua: pocket setup or special starting logic.
- Item/pickup behavior: spawn or transform card pickups.

## Hard Rules

- Return card ids from card callbacks, not pickup subtypes or collectible ids.
- Gate replacement rules to the owning item/challenge so they do not affect normal card generation.
- If a challenge grants a card, coordinate with `isaac-challenges`.
- If a card pickup is spawned manually, verify the expected pickup variant/subtype convention in the current repo.
- Do not make custom cards appear randomly unless the design says they should.

## Review Checklist

- Generation route is explicit.
- Replacement is gated.
- Starting card id matches `pocketitems.xml`.
- Normal card pool behavior is unaffected unless intentional.

