# 第十五批职责与共享能力清单

三个原入口均保留为唯一兼容入口，main.lua 原加载位置与参数不变。每个入口创建五个私有模块实例，子模块返回普通函数表，安装方法显式调用一次；没有总事件分发器、依赖环或 require 单例状态。各入口中的 TestAPI 仅组装旧观察接口，生产代码不通过它协作。

| 道具 | 入口及私有目录 | 状态与生命周期 | 本批迁移与遗留 |
| --- | --- | --- | --- |
| 阴的诅咒 | yins_curse.lua → scripts/features/yins_curse/{state,queries,pedestals,acquisition,runtime}.lua | state 管理 yinCurse 和每次安装 runtime；acquisition 保留碰撞快照/POST_ADD 与 8 帧结算；runtime 保留 Continue、新局、换房、退出和免爆 veto | 实现已迁出根入口；原接口、API v1 能力守卫和九个登记阶段不变，无旧业务副本 |
| 七咒之戒 | ring_of_the_seven_curses.lua → scripts/features/ring_of_the_seven_curses/{state,inventory,world,rewards,runtime}.lua | state 管理 ringOfSevenCurses；rewards 管理底座代际/选择循环/掉落豁免/交易候选；runtime 保留首房机会过期、充能与每十帧诅咒检查 | 实现已迁出根入口；正式 GetRingOfSevenCursesIncomingDamageMultiplier 委托同一 State 实例；十五个登记阶段原序，无旧副本 |
| ACE 反作弊系统 | scripts/features/ace_anti_cheat_system.lua → 同名目录的 {state,queries,audit,combat,runtime}.lua | state 保存 runtime 与 running/disposed；audit 拥有时钟/限时工作量/房间减速/团灭，combat 拥有 NPC 记录；runtime 管理获得/失去/新房/新局/退出/卸载 | 155 个函数总迁移的一部分；十一登记阶段不变。旧 HP 观察结算仍不是原生逐队列项的独立扣血收据 |

## 公共能力核对

| 候选及已发现消费者 | 共同实现或保留差异 | 本批结论 |
| --- | --- | --- |
| Game 查询：ACE、world_queries 既有 folk_world/两盒/card_rewards/血颅蛊等消费者 | ACE 先检查 type(Game)==function；公共 TryGame 捕获调用失败；ACE 将 false 结果按旧逻辑转 nil。无缓存、无新世界操作 | ACE 已切换 world_queries.TryGame，原 pcall 算法删除；公共实现不改，真实消费与边界有测试 |
| 道具计数：三件及 collectible_stats | ACE 只接受原生 number、不取整、失败回退 Has；阴传 true，数值化取整，不回退；七咒先 true 再普通调用，异常传播、值不钳制。Stats 默认 count 调用也不同 | 保留各自查询政策，避免合并后改变真假/异常/副作用次数 |
| 玩家标识：三件及既有玩家键 | 阴/ACE 使用 InitSeed 或空字符串；七咒依序 InitSeed、ControllerIndex、GetPtrHash、tostring。ACE playerKey 为已有未调用函数，未借重构删除 | 保留键格式；不将不同存档语义统一成通用 ID |
| 保存与种子：阴、七咒、run_section、persistence | 阴 protected GetRoot/Save，种子字符串与测试覆盖；七咒 GetRoot/Save 异常传播且有旧 mod 表兜底；run_section 为严格种子比较并依赖区域 Store | 保留现有 root provider 和字段，继续复用 main 注入的 persistence。没有捕获旧 root，查询始终获取当前根 |
| 方法调用：ACE safeCall、world_queries.TryMethod、archive_room | ACE 要 type==function，转发参数，返回 result,ok；World 只调用无参数方法，返回首值；archive_room 查询有其既有上下文语义 | 本批没有完全同合同的第二个消费者，不另建工具库 |
| 玩家转换：阴、combat_source.TryPlayer | 阴只调用 function 成员，失败后还可将有 HasCollectible 的模拟/兼容对象视作玩家；公共转换无此后备；ACE 与七咒伤害回调直接 ToPlayer 并传播异常 | 保留原所有权与失败边界 |
| Q4 可交互底座：阴、七咒 | 阴检查 Type、数值化、碰撞类别并捕获 Exists；七咒直接检查 Variant/Wait/Exists，不捕获错误。阴只处理第一次；七咒按底座代际与 native cycle 补偿 | 规则归属独立；位置距离、门口/碰撞筛选、价格及选项组行为不合并 |
| NPC 筛选与扣血：ACE、七咒、其他 combat 查询 | ACE 排除 Boss/分节主身/抗击退等；七咒包含 Boss 并排除友好/魅惑。ACE 记录请求后观察 HP；七咒立即一次翻倍 MaxHP/HP | 保留独立，不把不同事件与去重标记合并 |
| 受伤 ×2：ACE、七咒、incoming_damage | 两件修改同次伤害，但资格分别为当前持有与永久合约；已有 incoming_damage 计算致命性而非修改。只有单行乘法共同 | 原 EARLY 次序保持，实际原生 dispatcher 组合与保护回调继续检查；不建道具 ID 分发服务 |
| 射速：七咒、fire_rate | 七咒按 0.75 倍射速转换；fire_rate 是正射速加法且有不同下界 | 保留倍数政策，避免改变低值及异常输入 |

## 验收边界

初始完整已迁移清单继续由 docs/superpowers/plans/2026-11-25-thin-entry-refactor.md 维护；本批增加对两个原根模块的内部职责核验，并收口 ACE。其他批次的实现、原生和人工状态不因本表自动变化。安装失败、存档、回调与原生证据见同目录 delivery.md；公共用法在 docs/api/shared-mechanics.md。
