# 第十一批：焚尽郁结迁移与复用清单

本批一件：焚尽郁结 / BurnAwayResentment。此前 38 件见[共同能力清单](../../refactor-shared/2026-11-26/consumer-inventory.md)，第十批两件见[第十批清单](../../refactor-batch10/2026-11-26/consumer-inventory.md)，全量原入口清单见[薄入口计划](../../../docs/superpowers/plans/2026-11-25-thin-entry-refactor.md)。已存在独立入口不自动代表完成逐件职责验收。

| 归属 | 状态/责任 | 接口与生命周期 |
| --- | --- | --- |
| burn_away_resentment.lua | 原配置、每件一次的实例与 lifetime，原顺序安装 | main.lua 的原调用不动，不保存游戏状态 |
| queries | 本件生命/敌人/房间/伤害来源事实 | 无模块状态；缺 API、异常、严格 true/false 判定保留 |
| attributes | 属性刷新及 cache 回调 | 只读取 live public states；伤害/速度和直接减少 MaxFireDelay 的原公式保留 |
| ledger | GetState、附加房间、积层、换层清明结算 | public states 兼容视图仍由本件拥有；以原 folk 玩家/房间/楼层键索引，非序列化状态 |
| presentation | 状态 Sprite、爆发 Sprite/位置/年龄 | 独占 bursts；移除本人、换房、换层、结束/继续、退出/卸载的原清理规则，36 次 update 上限 |
| combat | 主动爆发、3 次 update 内受伤确认、damageDepth | 独占重入深度；先清层并记 pendingClarity，再刷新 cache/绘制/原生伤害与 burn |
| runtime | update、换房/换层、开始/退出/卸载及清理协调 | 每个处理器与注册相邻，9 个登记按旧顺序；释放旧状态中的 player/Sprite/pending 引用 |

现有公开 `BurnAwayResentment.states`、`GetState`、`GetPlayerHeadWorldPosition` 与三个具名 Mod 回调保留。查询和绘制继续动态读取公开别名，不缓存被替换的 states 或 GetState；不新增 production TestAPI。GetState 返回本件可变运行表、可能懒创建；不能写入存档或宣称跨进程恢复。

| 共同能力 | 实际消费者/接入 | 保留差异与理由 |
| --- | --- | --- |
| folk_world | queries、ledger、runtime、presentation 使用原依赖 | 不改变持有、玩家键、房间键/楼层键或查询时机 |
| player_geometry | 原入口注入，公开头部位置别名由 presentation 动态调用 | 既有炸弹套装、我即神明等消费者沿用原共同实现；焚尽原 WorldToScreen 失败回退保留，不冒充坐标修复 |
| combat_source.TryPlayer | queries 的直接攻击 owner 转换 | 种类白名单、一级 owner 优先级、转换失败 Type 回退都由本件持有；详细合同见[API](../../../docs/api/shared-mechanics.md) |
| 敌人有效性 | 保留本件 queries | 柴刀要求 Position、允许 active enemy、friendly/dead 真值判断不同，不合并 |
| 生命/受伤确认 | 保留本件 queries/combat | incoming_damage 含 HasMortalDamage 且 getter 错误传播不同；本件逐 getter 保护并将骨心计 2，三次更新观察真实减少 |
| 清明射击属性 | 保留本件 attributes | 原行为直接减间隔；fire_rate 提供射速单位换算，不可互换 |

当前状态：已验收（第十一批范围）。正式 LuaAll 150 项通过，旧/新原生各 5 场景 25 项通过，五组观测及七组模拟轨迹一致；证据和边界见[交付记录](delivery.md)。其他未授权迁移的道具及根目录模块保持此前状态。人工体验、多人原生、跨进程 Continue 与原生沙漏未包含在本批验收内。
