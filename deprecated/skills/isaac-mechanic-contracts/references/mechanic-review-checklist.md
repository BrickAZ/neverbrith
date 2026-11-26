> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-mechanic-contracts/references/mechanic-review-checklist.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Mechanic Review Checklist

Before implementation, verify the contract answers:

- What exact event starts the mechanic?
- What happens on an ineligible attempt?
- What is changed immediately?
- What persists, and why?
- What can trigger it again?
- What is excluded and why?
- What ends, interrupts, or settles it?
- What belongs to gameplay and what belongs to presentation?
- Which targets are owned by the current project versus another mod?
- Which existing reference and tests cover the same risk?

After implementation, test at minimum:

- eligible success;
- ineligible failure/no-op;
- each important exclusion;
- repeated or recursive trigger;
- state interruption/reset;
- normal-run or other-mod non-interference when relevant.
