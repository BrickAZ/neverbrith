> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-mechanic-contracts/references/surface-ownership-and-compat.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Surface Ownership And Compatibility

Mechanics often fail because the requested outcome is implemented on the wrong carrier.

## Carrier Questions

Ask these before implementation:

1. Does the mechanic alter player stats/body, a world entity, a pickup/card, or only presentation?
2. Does it require collision, HP, targeting, or gameplay damage?
3. Which item/card/entity/challenge owns the behavior and may replace a target?
4. Is a target from another mod merely observed, or deliberately integrated through an optional API?

## Compatibility Rule

The current project may validate and replace content it owns. It must not globally treat unknown cards, entities, variants, or pickups as broken. When an optional integration is absent, use a no-op or retain the original target.

## Presentation Rule

Visual/audio feedback describes the mechanic but does not define it. First decide whether gameplay succeeded; then choose a costume, Lua sprite, registered entity, sound, shader, or UI to show that result.
