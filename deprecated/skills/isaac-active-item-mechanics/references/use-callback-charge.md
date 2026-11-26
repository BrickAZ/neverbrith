> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-active-item-mechanics/references/use-callback-charge.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Use Callback And Charge Policy

Use this when an active item has conditional use, failed-use behavior, zero charge, or slot-specific charge handling.

## Questions To Answer

- Which slot can trigger it: primary active, pocket active, all active slots, or a specific slot passed by the callback?
- Does pressing the item always start the effect?
- If the condition fails, should the item consume charge?
- If the item starts a multi-frame state, when is the charge actually consumed?
- Does the item need manual charge changes with `player:GetActiveCharge`, `player:SetActiveCharge`, or an existing helper?
- Does Battery or other extra-charge logic matter?

## Rules

- Do not assume `return true` or `return false` without checking the repo's callback style and the intended failed-use policy.
- Do not implement manual charge handling unless the design needs it. Isaac active callbacks often handle charge through the return value and item config.
- For zero-charge active items, still specify whether the use can fail and whether the failure should play feedback.
- For slot-specific behavior, keep the callback's `slot` or `vardata` parameter visible in the design and tests.

## Review Checklist

- `MC_USE_ITEM` is registered with the correct item id when supported.
- The callback parameters match the Isaac API style used in the repo.
- Failed-use charge policy is stated in the prompt or code comments.
- Tests or handoff notes cover at least one successful use and one failed use.

