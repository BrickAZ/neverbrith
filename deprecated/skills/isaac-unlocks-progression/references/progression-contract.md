> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-unlocks-progression/references/progression-contract.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Progression Contract

Use this before creating an unlock or persistent availability gate.

## Required Fields

- User-approved condition and reward intent.
- Exact event that proves completion.
- Stable persistence key and default value.
- Version/migration policy.
- Idempotent grant behavior.
- Separate availability check used by pools, rewards, character selection, or
  other content surfaces.
- Co-op, continue, reload, and failed-run behavior.

Use semantic labels such as “unlock-completed marker” and “one-time reward
settlement marker” until the project save schema is discovered. Do not invent
key paths in a contract. If a completed record lacks a valid grant marker, do
not automatically regrant an economic reward: preserve recovery evidence and
make the regrant policy `TBD` unless migration data proves it is safe.

## Failure Policy

Missing fresh-profile data may use a documented default. Treat malformed or
unrecognized existing data differently: do not overwrite its raw payload with
a default in the same session, block permanent grants, and preserve a recovery
path. Never grant a one-time reward repeatedly because a decode/load error
silently reset its flag.
