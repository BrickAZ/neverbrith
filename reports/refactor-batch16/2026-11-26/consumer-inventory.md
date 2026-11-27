# 第十六批职责、状态与公共能力清单

本批基线为 2026-11-26 开工时实际工作副本，见 baseline-manifest.json；不使用 Git HEAD 替代已有改动。入口保持 main.lua 原加载顺序，根目录三文件现在只做必要接口门禁、一次创建各私有实例、依赖连接与原顺序安装。三件各有一个 config 和五个私有职责模块，共 18 文件。

| 道具 / 本地 ID | 实际入口与私有目录 | 所有权与拆分 | 本批状态 |
| --- | --- | --- | --- |
| 我即神明 / 59 / IAmAGod | i_am_a_god.lua → scripts/features/i_am_a_god/ | config 参数；state 身份/房间禁疗账本/活动状态/门和泪标记清理；health 生命上限快照与禁疗事件；presentation 王冠/判决/语音；combat 激活、倍率与判决；lifecycle 时钟、进出房间/楼层/局、死亡和移除 | 已迁移，模拟与结构对照通过；本批未重跑原生/人工验收 |
| 神性过载 / 60 / GodComplex | god_complex.lua → scripts/features/god_complex/ | config 参数；state 运行状态/旧形态记录/清理；targeting 敌人分类、优先级和距离；presentation 图形；combat 攻击归属/伤害回执/击杀/三形态攻击；lifecycle 使用、属性、禁火与退出/计时 | 同上 |
| 炸弹套装 / 63 / BombSuit | bomb_suit.lua → scripts/features/bomb_suit/ | config 参数；state 引线、回执、射击与原生炸弹作用域数据/清理；bombs 原生载体和散射后代归属；presentation 提示音/引线绘制；damage 卖血排除、实伤回执与触发；lifecycle 输入、时钟和中断 | 同上；BombSuit 公开查询名称、返回及副作用保持 |

每个 state 工厂拥有一次安装的 Data 对象；其他私有模块显式接收该实例。Data 只在该道具目录内共享，不发布到 Mod、不进入 SaveData。模块函数与对应 Installers 紧邻；Installers 只登记原生回调，不充当事件总线。子模块不自行重复安装，根入口按原顺序点调用一次。

依赖无环：我即神明 state → health/presentation → combat → lifecycle；神性过载 state → targeting → presentation/combat → lifecycle；炸弹套装 state → bombs/presentation → damage/lifecycle。每个箭头为被依赖者到消费者，消费者还可直接依赖 state。config 是本次 include 创建的参数表，没有可推进的模块状态。

## 计时与恢复合同

| 项目 | 我即神明 | 神性过载 | 炸弹套装 |
| --- | --- | --- | --- |
| 时钟 | MC_POST_UPDATE；同 Game frame 最多 +1；暂停不推进；180 次更新结算，121 时切过载表现 | 同 Game frame 最多 +1；暂停不推进；240 次更新清理；Solar 5 次、Eye 6 次及目标冷却 15 次保持原边界 | 同 Game frame 最多 +1；暂停不推进；90 次更新自爆，提示音帧表保持 |
| 活动所有者 | 全局唯一激活者，增益只给本人，受伤风险与禁疗作用于原队伍范围 | 按指针+InitSeed 的每玩家状态；各自形态和伤害回执 | 原指针键（无 GetPtrHash 时 InitSeed 回退）；各自引线、快照与后代标记 |
| 持久化 | iAmAGod 原 version/run/floor/rooms；仅保存禁疗房间，不保存活动、实体/精灵和生命快照 | godComplex 原 version/run/players；InitSeed:ControllerIndex 记录上次形态，不保存活动 | 无新存档；引线和实体归属运行期持有 |
| 换房/换层 | 停止活动、清表现与快照；换层清禁疗房间；重入本层已标记房间继续禁疗 | 换房/换层 clear，保留上次形态 | 普通换房/换层继续计时，自爆取到期当前位置；沙漏 LOAD clear |
| 死亡/失去末份 | stop；禁疗账本保持；复活重建生命上限，避免剥夺原生复活生命 | stop，仅清该玩家临时泪标记、自建弹幕、目标、伤害回执；历史形态保持 | stop，恢复速度与射击，不自爆；减少但仍持有一份不取消 |
| 退出/继续/新局/卸载 | 原事件与 Save 时机保持；活动取消，继续恢复旧房间标记，新局清账本 | 活动取消；继续保留形态历史，新局清历史；原 Save 时机保持 | 退出/继续/新局/本 Mod 卸载 clear；无引线恢复 |

属性恢复顺序保持：先解除活动记录，再 EvaluateItems；只清本次额外添加的泪标记。所有用户数据字段、RNG 调用顺序、Save 调用位置及回调返回值保持原样。本批不新增我即神明/神性过载的沙漏政策，不统一三件道具的换房或存档行为。

## 公共能力盘点

| 候选 / 已发现消费者 | 结论与实际接法 | 保留差异或后续范围 |
| --- | --- | --- |
| CanShoot 快照与 SetCanShoot 暂时封锁：神性过载、炸弹套装、斗气拳套 | 两件本批消费者已改为 [shooting_scope](../../../scripts/systems/shooting_scope.lua) 的 Block/Restore；各自 state 表、键及 exists 谓词不变 | 斗气拳套的 t.shootScope 挂在动作状态，清理时还受动作/控制状态影响；本批不迁移其状态存储与动作逻辑。公共库不负责跨模式仲裁 |
| 头部世界定位：我即神明、炸弹套装及其他既有消费者 | 沿用 main 传入的 player_geometry.GetPlayerHeadWorldPosition，无重复初始化另一件道具 | 神性过载头部/地面/屏幕偏移为其特效合同；不能直接改用同一个头部锚点 |
| 玩家枚举 | 沿用 GetPlayers；我即神明自身补入 Forgotten 的 inactive body 并去重 | 不能将补身体逻辑推广至所有道具 |
| 玩家/房间/楼层键 | 各件保留当前严格引擎查询与键格式 | world_queries 现有接口使用受保护查询/不同键；我即神明和神性过载的 descriptor 获取顺序不同，不为一行拼接改变引擎调用合同；指针身份不可替代持久玩家键 |
| 攻击来源归属 | 神性过载 combat 保留攻击祖先/跟班硬边界/碰撞作用域；炸弹套装 bombs 保留标记与散射候选确认 | 普通 combat_source.TryPlayer 不表达递归边界、原生碰撞窗口与半伤害散射确认；直接统一会误收来源 |
| 时钟、状态退出、缓存刷新 | 保持各件自己的推进及结算 authority | 相同 age/lastFrame 形状不代表同一活动范围、换房或结算政策。公共库不承担玩法状态机 |

公共库详细合同、参数、异常、实例、真实消费者和测试见[射击权限说明](../../../docs/api/shooting-scope.md)。共同能力的本批目标已接入两件真实消费者；不据此宣称其他批次的动作控制已统一。

## 审查与撤回

133 个业务函数逐体比较：129 个仅将旧私有变量限定到 data；4 个（两件 restoreShoot、两件 prePlayer）切换到共享实现，并执行嵌套/原值 false/异常清理反例。配置常量从冻结源码原样提取；公开 BombSuit 查询保持，未增加生产 TestAPI。加载测试覆盖 18 私有模块一次创建和 71 个登记位置的失败回滚。

撤回只还原 baseline/ 下的三根入口和本批改动的三个行为测试、资源测试，再撤下本批私有目录/公共模块及新增测试/导航。保存格式未变，不需要存档迁移。不要用整目录或 Git reset 撤回，否则会覆盖同期任务。完整结果、实际命令和未覆盖范围见[交付](delivery.md)。
