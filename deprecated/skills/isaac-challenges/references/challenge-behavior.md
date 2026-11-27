> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-challenges/references/challenge-behavior.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Challenge Behavior Restrictions

Use this for no-shooting, input restrictions, card replacement, boss/NPC modifications, damage rules, or special win/loss logic.

## Common Routes

- No shooting: prefer XML `canshoot="false"` when sufficient; use input/action callbacks only when the rule is dynamic.
- Card replacement: use `MC_GET_CARD` or current repo helper.
- Boss/NPC modification: use NPC update or damage callbacks, gated by challenge id.
- Damage behavior: coordinate with the current project's item/damage implementation surface and `isaac-mechanic-contracts`.
- Visual/audio feedback: coordinate with `isaac-audio-render-feedback`.

## Hard Rules

- Do not implement global input blocking for a challenge unless the challenge explicitly needs it.
- If modifying boss health or damage, restrict the target entity type/variant.
- If a rule changes item pools, make sure it does not affect normal runs.
- Challenge restrictions should be easy to audit from the Lua module, not hidden across unrelated files.

## Review Checklist

- Restriction is expressible in XML or Lua for a reason.
- Callback target is narrow.
- Normal runs and other challenges are unaffected.
- Relevant sibling skill is used for damage, active mechanics, visuals, or compatibility text.
