> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-challenges/references/starting-inventory.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Starting Inventory And Item Pools

Use this when a challenge grants items, smelts trinkets, sets pocket actives, or removes items from pools.

## Routes

- XML starting inventory: use `startingitems`, `startingtrinkets`, `startingcard`, `startingpill` when the effect is simple.
- Lua starting inventory: use when order matters, smelting is required, pocket active is needed, or custom pool removal is needed.

## Hard Rules

- First-run inventory setup should usually skip continued saves.
- If smelting trinkets, state why and use the repo's established flags.
- If setting pocket active, specify slot and charge behavior.
- If adding custom collectibles at start, decide whether to remove them from the item pool.
- Do not add the same item in XML and Lua unless duplication is intended.

## Review Checklist

- Inventory source is XML, Lua, or both by design.
- Duplication is avoided.
- Pool removal is intentional.
- Multiplayer behavior is considered when looping players.

