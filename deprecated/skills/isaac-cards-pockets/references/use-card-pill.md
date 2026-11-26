> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-cards-pockets/references/use-card-pill.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Use Card And Pill Callbacks

Use this for `MC_USE_CARD`, `MC_USE_PILL`, and custom pocket item behavior.

## Rules

- Custom card/rune/soul stone behavior uses `MC_USE_CARD` with the correct card id.
- Custom pill behavior uses `MC_USE_PILL` or the repo's pill effect convention.
- Do not mix card id and pill effect id.
- If a card triggers an active-item-like effect, use `isaac-active-item-mechanics` for the complex interaction.
- If the card effect causes damage interception, stats, visuals, SFX, or entities, use the relevant sibling skill.

## Recursion And Same-Frame Guards

If a card simulates another card, repeats a card effect, or is triggered by another item:

- Track same-frame state to avoid recursive `MC_USE_CARD`.
- State whether the card is consumed.
- State whether non-player sources can trigger it.

## Review Checklist

- Correct id lookup.
- Correct callback.
- Consumption/trigger source is explicit.
- Edge cases are listed.

