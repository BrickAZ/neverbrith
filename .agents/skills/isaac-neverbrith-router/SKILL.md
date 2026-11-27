---
name: isaac-neverbrith-router
description: "Use when scoping gameplay, registration, art, dependencies, save state, debugging or validation work in a confirmed neverbrith checkout, especially when multiple Isaac skills could apply. 中文触发：neverbrith 技能路由、机制、实体、以撒本体、存档、验证。"
---

# Isaac Neverbrith Router

This is the project overlay for neverbrith. The general skill taxonomy belongs
to `isaac-repentance-router` when available. In a checkout with only project
skills, use the task classifier below and select the relevant specialist
from the available skill descriptions.

1. Confirm the checkout with `isaac-mod-context`. Read its `AGENTS.md` and
   `docs/agent/index.md`, then trace the bootstrap and actual behavior owner.
   For shared-library or callback layout work, follow the development conventions
   and public API links in that index. For skill maintenance, follow its skill
   authority page; `docs/skills` is an archive, not an installed instruction source.
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

Use the [shared execution and reporting policy](../isaac-mod-context/references/tbd-disclosure.md).
For an implementation or fix, continue from routing into the selected specialist
and the project checks without asking for a second confirmation. Reuse current
context; do not rediscover facts just to fill a route form. For a non-trivial
change or handoff, communicate only the route, ownership, decisions and evidence
that help execute or assess the task. A route-only answer is appropriate when
the user explicitly requested routing only.
