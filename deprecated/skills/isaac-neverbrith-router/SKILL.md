---
name: isaac-neverbrith-router
description: "Use when scoping gameplay, registration, art, dependencies, save state, debugging or validation work in a confirmed neverbrith checkout, especially when multiple Isaac skills could apply. 中文触发：neverbrith 技能路由、机制、实体、以撒本体、存档、验证。"
---

> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../.agents/skills/isaac-neverbrith-router/SKILL.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Isaac Neverbrith Router

This is the project overlay for neverbrith. The general skill taxonomy belongs
to `isaac-repentance-router` when available. In a checkout with only project
skills, use the task classifier below and select the relevant specialist
from the available skill descriptions.

1. Confirm the checkout with `isaac-mod-context`. Read its `AGENTS.md` and
   `docs/agent/index.md`, then trace the bootstrap and actual behavior owner.
2. Classify the request with [task classification](references/task-classification.md).
   Choose one primary specialist and companions for additional stated surfaces.
   Use the [project routing table](references/skill-routing-matrix.md) for
   decisions specific to this checkout.
3. Preserve approved decisions with [user decision authority](references/user-decision-authority.md).
   List unresolved user choices separately from missing technical evidence.
4. Follow `docs/agent/testing.md` through `isaac-neverbrith-validator-profile`.
   Add `isaac-testing-debugging` for symptom triage and runtime proof.

For a mixed request, settle the affected gameplay contract before choosing
callbacks; then add lifecycle, registration, presentation and verification
as the scope requires. For ambiguous projectile ownership, trace who fires
or spawns the attack and who receives damage credit. A reflected enemy shot
routes by the owner of the affected behavior after reflection.

For a non-trivial change or handoff, report the affected surface, primary
specialist and companions, current owner and evidence, relevant approved or
unresolved design choices, technical discovery gaps, and verification route.
