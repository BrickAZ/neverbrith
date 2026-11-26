> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-cards-pockets/references/card-descriptions-icons.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Card Descriptions And Icons

Use this when adding EID text, inline icons, card/pill icons, or localized descriptions for custom pocket items.

## Surfaces

- `content/pocketitems.xml` description.
- EID `addCard` or equivalent description file, only when EID integration exists.
- EID icon registration, only when EID integration exists.
- HUD/card icon art.
- Every discovered locale surface that owns this text.

## Hard Rules

- EID text does not replace `pocketitems.xml` registration.
- Inline EID icons do not replace pickup/HUD art.
- Keep each discovered locale's descriptions separate; do not invent language files.
- Use `isaac-anm2-visuals` for `.anm2` icon assets.
- Use `isaac-compat-descriptions` for optional EID guards and language sync.

## Review Checklist

- EID guard exists if EID is optional.
- Card id is resolved with `Isaac.GetCardIdByName`.
- Icon art and text formatting are checked.
- Languages are aligned.
