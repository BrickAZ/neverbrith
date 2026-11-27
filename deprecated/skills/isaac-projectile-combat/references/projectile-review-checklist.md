> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-projectile-combat/references/projectile-review-checklist.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Projectile Review Checklist

## Creation And Identity

- Is the route augment, explicit spawn, or registered custom entity?
- Are callback, type, variant, subtype, ANM2, and animation facts discovered?
- Does each later callback verify the owned-projectile marker or equivalent
  strong identity proof?

## Source And Combat

- Is player/familiar credit resolved from a verified source route?
- Are target eligibility, friendly policy, damage source, cadence, and return
  behavior explicit?
- Can collision, remove, and death settlement occur only once per intended event?
- Are split/reflect children marked and recursion-bounded?

## Lifecycle And Compatibility

- Are timeout, room change, owner disappearance, item loss, and remove behavior explicit?
- Are live entity/player references runtime-only?
- Are foreign/vanilla projectiles left untouched unless deliberately integrated?
- Are optional libraries guarded and non-required?

## Proof

- Does automated coverage prove eligible source, rejected foreign source,
  marker/re-entry behavior, hit cadence, and cleanup?
- Do in-game checks cover player and familiar sources, synergies, collision,
  visual alignment, co-op credit, and room/reload behavior?
