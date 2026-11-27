# 第十三批共享能力与保留差异

这是本批的共享能力清单，与 consumer-inventory.md 的逐件状态分别维护。详细接口和副作用集中在 [big-dog-family.md](../../../docs/api/big-dog-family.md)。

| 候选 / 已发现消费者 | 共同实现与实例所有者 | 本批处理 / 保留差异 | 状态与证据 |
| --- | --- | --- | --- |
| 玩家/保存状态：大狗输入、食物、冲刺、回响、水迹、生命周期 | big_dog_bark/state.lua 唯一 Runtime，入口一次创建，具名传给消费者 | 从原闭包整体迁出，不让每件各建账本；InitSeed、活 context、保存点保留 | 已迁移并通过本批对照；boundaries / trace / 原生 JSON |
| 向量/配置/世界/持有查询：大狗各私有模块、Rod、Echo | big_dog_bark/queries.lua 一次创建 | 同组所有消费者使用同一实现；保留数值回退及引擎调用错误合同 | 已迁移并通过本批对照；两份既有行为测试和提取比对 |
| 效果生成/方向表现/伤害调用：大狗、回响、水迹 | big_dog_bark/effects.lua，同一实例 | 一处维护，共享原生实体参数；各件保留自身 Variant、动画政策和伤害公式 | 已迁移并通过本批对照；原生普通/强化冲刺和回响 |
| 房间目标/线段查询/一次命中：冲刺、回响、咀嚼、水迹 | big_dog_bark/targets.lua，同一实例与房间目录 | 冲刺、回响各自持有 hitMap；不把不同攻击合并成一次命中账本 | 已迁移并通过本批对照；既有目标测试、原生独立命中 |
| 水迹节点/合并/贡献者/结算：冲刺、回响 | big_dog_bark/trails.lua，共用 State.Runtime | 保留每敌每帧最高贡献者与原更新时间；不生成两套水迹管理器 | 已迁移并通过本批对照；双玩家离线轨迹、原生水迹伤害 |
| 主动槽枚举：本组；已有 active_slots 消费者血颅蛊、剪碎塔罗、两盒 | 已有 scripts/systems/active_slots.lua 与本组 Queries.hasBigDogActive | 公共能力对部分枚举不补缺项，本组逐槽补 0/1/2/3；不强行迁移到不同合同 | 保留独立，有源码语义依据；玩法数值未改 |
| 持有/数量：本组；已有 collectible_stats 消费者 folk_world、针尖、狗粮 | 已有 scripts/systems/collectible_stats.lua 与本组 Queries | 公共 Has 在方法缺失/失败时尝试数量，本组只接受原 HasCollectible 的 true；Count 的方法类型检查和 ID 校验策略也由本组保留 | 保留独立，有源码语义依据；Rod 委托原本组查询 |
| 可选世界访问：本组；已有 world_queries 使用者见公共 API | scripts/runtime/world_queries.lua 与本组 getCurrentRoom | 本组只接受 function 类型的 Game/GetRoom，并把 false 结果归 nil；通用方法允许可调用对象且保留返回值。普通 API 调用近似不等于整个失败合同相同 | 保留独立，有源码语义依据；原函数体保持 |
| 食物取得/保存：本组；已有 dog_food_acquisition 等服务 | 本组 food/state | 本组原碰撞快照、队列/数量二次确认及 2/10 帧延迟/超时独立；不为复用更换取得事件或玩家键 | 保留独立政策；既有食物测试、旧新轨迹和真实四次底座拾取 |

本批没有新增全项目公共库，没有留下确认同合同、应合并却仅因时间而推迟的组内副本。其他批次的公共系统整理、整包打包及最终多人/跨进程验收不由本表宣告完成。
