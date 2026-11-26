> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-neverbrith-dev/references/implementation-checklist.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Neverbrith Implementation Checklist

Use this as the final review surface before handing off code or a prompt.

## Item Registration

- Basic item spec is present: names for discovered locales, internal name, type, mechanic summary, trigger timing, stack behavior, quality, pools, tags, pickup text, art, optional EID surface, and visual carrier when relevant.
- Missing basic fields are reported as `TBD`; they are not guessed.
- Item is present in all relevant XML language files.
- Internal name matches Lua lookup.
- Active/passive type matches design.
- `cache` attribute matches actual `MC_EVALUATE_CACHE` flags.
- `gfx` asset exists or the handoff clearly asks an art agent to create it.
- Pool placement is intentional, not guessed.

## Stat Cache

- Stat logic lives in `MC_EVALUATE_CACHE`.
- Temporary state is keyed per player.
- State changes call `AddCacheFlags` and `EvaluateItems`.
- Tests run each cache flag branch.

## Damage

- Player filtering is explicit.
- Amount filtering is explicit.
- Fake/cost damage policy is explicit.
- Self-created damage cannot recurse.
- Returning `false` is limited to intentional damage cancellation.
- Tests cover at least one ignored damage source.

## Handoff Prompt

When writing a prompt for another Codex agent, include:

- Item names for the project's actual locale surfaces.
- Internal item name.
- Item type: active or passive.
- Mechanic summary in one paragraph.
- Quality, pools/weights, tags, pickup text, art path, optional EID text, and unresolved `TBD` fields.
- Active-item charge policy or passive-item cache/stack policy.
- Visual carrier when the item has any visual effect.
- Route(s): registration, stat cache, damage interception.
- Exact existing examples to read.
- Required files to edit.
- Edge cases.
- Required tests.
