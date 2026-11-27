# 第十四批职责与语义清单

范围为截图中的诛、阿瓦达啃大瓜、柴刀，基线是本次开始时冻结的工作区。所有入口、调用参数、公开 API 和装配次序保留；没有修改内容登记、资源、存档键或新增角色。

| 道具 | 私有模块 | 状态及关键合同 |
| --- | --- | --- |
| 诛 | queries / ledger / presentation / combat / runtime | 入口创建 states/roomNpcs/logicalFrame；150 帧、4 帧光环、8 帧冲击波、击杀 +9 帧、车载电池每次成功命中给主副主动槽 +1 保持。光环按实时玩家伤害，击杀标记去重。换房清状态并刷新属性，开始/退出清状态但不额外刷新。 |
| 阿瓦达啃大瓜 | queries / weapon / casts / entities / hits / controls / runtime | 单次私有 state 管理玩家、NPC、碰撞、伤害前快照、待死亡确认、施法序号和 nativeEffect。所有可重绑表通过 state 当前字段访问。真实 Weapon 拥有蓄力和释放；Lua 只在取消时清充能。原生碰撞收据与接受伤害后的致命转变、实际死亡共同确认直接击杀；落空死亡、复活阻断及武器恢复保持。开始/退出重绑表但不重置 nextCast；换房取消弹体且保留武器状态。 |
| 柴刀 | queries / attributes / geometry / presentation / shadows / controls / combat / runtime | 入口创建 lifetime 与 shadowState；公开 Cleaver 方法和 Config 动态读取不变。影子、挥砍和原生 Knife 均为临时状态。换房移除挥砍并清影子，开始/Continue 清临时状态并保留已评估属性，退出/卸载释放引用并恢复缓存，已卸载实例不能重启。Registered 强制 false 不变。 |

共享 [attack_ownership](../../../scripts/systems/attack_ownership.lua) 只合并三个相同表达式的查询：诛让出射击替换但保留光环；柴刀取消/拒绝挥砍。API 用法、动态读取和异常合同见[公共接口](../../../docs/api/shared-mechanics.md#攻击接管查询)。不新建通用攻击优先级框架。

保留的差异包括：诛只选择当前 SpawnerEntity 或 Parent；阿瓦达按原生标记、碰撞收据及引擎实体身份归属；柴刀最多追溯四层并保留单个启用玩家回退。筛选敌人、原生方法失败处理、所有权解除和输入门控也继续由各道具拥有。无相同合同的部分不强行合并。

原业务函数 163 个（55 / 48 / 60）；正式完整事件集合中的 49 条绑定（11 / 28 / 10）保持。默认完整入口夹具没有两个 Knife 事件，因而为 47 条；测试明确补齐后验证 49 条，不能把夹具缺枚举误报为丢失回调。

本批未添加存档写入，未扩大原来没有的沙漏/跨进程继续保证。柴刀的原生自动探针只临时将潜在角色机制映射到 Isaac，正式注册始终为 false。实际验证命令、结果与局限见[交付](delivery.md)。
