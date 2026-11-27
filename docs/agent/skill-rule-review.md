# Skill 规则调整

用户已确认按下面的方向调整七类规则。本页记录当前采用的规则；有效指令维护在 `.agents/skills`，旧包已归入 `deprecated/skills`，`docs/skills` 只保留说明和命令转发。共同执行与输出原则由[共享决策规范](../../.agents/skills/isaac-mod-context/references/tbd-disclosure.md)维护。

| 原限制 | 当前规则 | 保留的技术要求与来源 |
| --- | --- | --- |
| 至少两个调用点才能抽公共 helper | 重复逻辑是抽库依据之一；职责明确的存档隔离、外部接口适配或已批准基础设施，可以只有一个当前消费者 | 说明独立职责，避免为假想复用建立框架；保留所有权、实例与加载副作用合同。[模块边界](../../.agents/skills/isaac-mod-architecture/references/module-boundaries.md)、[所有权](../../.agents/skills/isaac-mod-architecture/references/implementation-ownership.md)、[共享 helper](../../.agents/skills/isaac-mod-architecture/references/shared-helpers.md) |
| 附近已经有 pcall 才能使用 | 根据失败是否可恢复、接口是否可选及既定降级行为决定；不再由附近代码风格决定 | 缩小保护范围、保留诊断和回调返回语义，必需能力和程序错误仍须可见。[属性缓存](../../.agents/skills/isaac-neverbrith-dev/references/stat-cache.md) |
| 路由必须固定字段顺序，选完后不写代码 | 简单任务简述必要路线；实施、修复、审查和验证请求在选好技能后继续执行，无须额外批准路由 | 只按实际需要选技能，缺事实就调查；用户只要计划或路由时仍遵守该范围。[通用路由](../../.agents/skills/isaac-repentance-router/SKILL.md)、[项目路由](../../.agents/skills/isaac-neverbrith-router/SKILL.md) |
| 不得为了模式而抓取或复制参考 Mod | 允许用户要求的源码比较，以及解决具体问题所需的参考阅读 | 阅读不等于授权引入依赖；适配前核对加载、拥有者、原生/自定义 API、回调和返回值，保持已批准依赖政策。[主动道具](../../.agents/skills/isaac-active-item-mechanics/SKILL.md) |
| 每次修改回调都新增一套行为测试 | 优先运行已有覆盖；仅为行为变化或真实缺口补测试，已有充分覆盖的布局调整不重复造测试 | 必须证明实际加载后的注册、过滤、触发/排除、返回及关键顺序；只直接调用 handler 的测试不能代替注册证据。[回调合同](../../.agents/skills/isaac-callback-contracts/SKILL.md)、[检查清单](../../.agents/skills/isaac-callback-contracts/references/callback-review-checklist.md) |
| 使用后持续的主动效果一律先填完整状态转换表 | 简单计时效果说明开始、计时、结束与清理；分支、多阶段或延迟结算要写清转换，选择能解释清楚的表或流程描述 | owner/slot、clock、重复使用、扣费/退款、退出与幂等清理仍需明确，保存政策沿用既有决定。[主动道具](../../.agents/skills/isaac-active-item-mechanics/SKILL.md)、[状态生命周期](../../.agents/skills/isaac-state-lifecycle/SKILL.md) |
| 各技能分别要求固定 Final Review、最后重复所有待决事项 | 合并相关检查，按任务报告结果、改动、证据、重要限制及真正未决选择，不强制标题、表格或字段顺序 | 已确认决定与明确授权持续有效；真正未决的玩法/美术/存档政策仍须由用户决定，技术未知由 AI 调查。用户或工具确有固定交付格式时遵守该格式。[共享决策规范](../../.agents/skills/isaac-mod-context/references/tbd-disclosure.md)、[设计权威](../../.agents/skills/isaac-mod-context/references/design-authority.md) |

合同字段和完成检查仍用于检查当前任务涉及的技术问题；不为了缩短输出跳过回调、玩家归属、状态、RNG、存档、依赖或实机证据边界。未被本次修改涉及的领域不机械重验。建库同批保存详细用法与 callback 紧邻处理函数的要求继续见[开发规范](development-conventions.md)。

评估样例已同步：单消费者但职责明确的公共模块、完成路由后继续已批准修复、复用已覆盖真实注册的测试、简单计时效果与明确请求的参考阅读、已批准保存/充能政策不重新询问。新增样例是可供后续评估的案例，不自动代表行为评估已通过；实际检查和抽查结果留在当次交付记录。
