# 第二十一批逐件与共享能力清单

基线为本目录 `baseline/` 与 `baseline-manifest.json`。本批五件此前已有运行实现；只调整所有权、装配和同义键算法，不重新设计玩法。其他批次仍按[既有入口迁移记录](../../../docs/superpowers/plans/2026-11-25-thin-entry-refactor.md)及各批报告跟踪，本批不宣称整轮验收完成。

| 道具 | 实际入口与所有权 | 共享依赖 | 遗留路径与退出条件 | 状态 |
| --- | --- | --- | --- | --- |
| 斗气拳套 / DriveGlove | scripts/features/drive_glove/init.lua；state/freeze/input/players/weapons/damage/attribution/lifecycle 各自负责对应状态与处理器 | 原 Core/Damage/Weapon/Audio/Visuals；显式玩家 Key；既有 persistence 和安装事务 | drive_glove.lua 仅返回唯一工厂，无第二套处理器；保留旧引用兼容，不强制删路径 | 已迁移待验收：本批自动验证完成，人工/多人/跨进程边界未覆盖；见 delivery.md |
| 360 / Piledriver360 | scripts/features/motion_items/piledriver_360.lua，拥有身份/profile、普通/OD数值及帧映射 | 既有 MotionInput/MotionCombat/MotionPresentation，使用同一 Specifications 引用 | motion_items.lua 继续按原顺序绑定，已删内嵌配置；无重复道具实现 | 同上 |
| 720 / Ultimate720 | scripts/features/motion_items/ultimate_720.lua，拥有身份、单版本数值和直接源帧映射 | 同上；SA HUD/获取、退款与沙漏仍由 combat 负责 | 无旧内嵌配置；第 289 tick 控制恢复和394帧FX保留 | 同上 |
| 波动 / MotionWave | scripts/features/motion_items/motion_wave.lua，拥有身份/profile、弹体数值和时序 | 同一输入/战斗/表现，实际弹体与扣血仍归 combat | 无旧内嵌配置；没有新增 OD | 同上 |
| 升龙 / DragonPunch | scripts/features/motion_items/dragon_punch.lua，拥有身份/profile、普通/OD窗与源帧映射 | 原水平 DP 识别、移动锁定、受伤保护与演出 | 无旧内嵌配置；anyDirection 是原适配字段，不放开上下方向 | 同上 |

本批玩法全部原已处在独立根模块，main.lua 不留五件的规则或状态；现在显式给斗气拳套传入旧玩家身份提供者。main 的无关装配与其他任务改动保留。状态/存档/回调的实际证据与限制以同目录 delivery.md 为准。

| 共享候选 | 本批处理与消费者 | 语义依据与边界 |
| --- | --- | --- |
| pointer + InitSeed 身份 | 新增 scripts/systems/entity_identity.lua；motion_input、motion_input_shooting 两处、motion_items、motion_combat、motion_presentation 共六处算法切换到唯一实现 | 原相同表达式完整保留。显式提供者优先级/false返回差异保留；不是持久化身份 |
| 输入、指令执行、战斗与演出 | 沿用既有共享实例，四件读取同一 Core Specifications | 配置各自拥有，实际伤害/控制/目标与演出共享不复制；无需新的事件总线 |
| 防御／支付识别 | Drive Glove 和 Motion Combat 继续共用 drive_glove_damage.Payment/Flag 等原规则 | 本轮没有新造通用伤害层；防御优先级、OD免伤条件、受创取消、环境伤害及倍率不同 |
| 玩家保存身份 | main 显式提供旧 InventoryPlayerKey，拳套保留旧独立调用兼容 | PendingContentState 的 Lazarus/form 语义不同于 pointer 键；不改变旧存档键 |
| 射速换算 | 拳套 Core.Tears 保留 | 拳套 `max(-.99,delay)`、力竭乘数及奖励最少4发，与共享 fire_rate 正增量／0.0001 下界不同，合并会改变异常/负间隔行为 |
| 原生来源转换 | 拳套归属和 motion 门禁保留独立 | 拳套递归深度10且按 Parent优先／保存消失跟班来源快照；motion 广度最多64节点且使用命令 token；combat_source 的 pcall ToPlayer 吞错误合同不同 |
| 冻结／控制占用 | 拳套 freeze 拥有添加的 flags；搓招保留原输入/目标租约与pose释放 | 原生 CanShoot、动作锁定、游戏暂停及租约恢复不等价，不能合成一个全局锁而改变时序 |
| 存档／沙漏 | 沿用既有根与独立存档区域，实际保存点不变 | 拳套沙漏只取消瞬态；motion 有 SA/OD快照。Core.Record 一个保留原种子类型，一个字符串化，不能为了重用统一 |

当前已发现、同合同的六处实体键重复已消除。公共用法与消费者测试见 `docs/api/drive-motion.md` 和 `docs/api/shared-mechanics.md`。既有动作资源、字体、音频与 HUD 不重建。
