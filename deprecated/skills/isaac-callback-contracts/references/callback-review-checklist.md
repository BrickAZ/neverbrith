> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-callback-contracts/references/callback-review-checklist.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Callback Review Checklist

Before code:

- Does the callback observe the intended moment?
- Is the registration filter as narrow as possible?
- Does the handler signature match the callback family?
- Are relevant source, flag, ownership, and state guards inside the handler?
- Is the return policy verified for this exact callback type?
- Does a changed state request the correct cache refresh?

After code, test:

- registration exists and handler is callable;
- eligible event fires once;
- wrong item/entity/card does not fire;
- important excluded event does not fire;
- return/cancellation behavior matches the contract;
- duplicate registration is absent;
- state/cache refresh occurs when required.
