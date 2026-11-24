# 项目知识索引

这里保存 neverbrith 的项目导航。先结合当前任务阅读代码和测试，按下面的入口补充必要信息；不要求遍历整个知识库。

| 当前任务 | 先读 | 读取目的 |
| --- | --- | --- |
| 接手项目、找实现归属、判断目录用途 | [项目地图](project-map.md) | 区分运行源码、工具和历史材料，找到模块接入点 |
| 框架重构：目标架构、状态边界与迁移路线 | [目标架构与渐进重构路线](../architecture/2026-11-24-neverbirth-target-architecture.md) | 用户已认可的架构方向；区分当前源码证据、目标合同和未实施迁移，保持既有玩法与存档语义 |
| 修改、排错或验收，选择可执行检查 | [检查与证据](testing.md) | 选择范围、运行器和命令，区分失败、未运行与实机验证 |
| 记忆紊乱行为、图标、配置模拟接口 | [记忆紊乱专题](topics/memory-disorder.md) | 找到完整加载链、测试和原生边界 |
| 临时复制、零分考卷、回声宝宝、背包选择器 | [本轮实现专题](topics/pending-content.md) | 找到已批准合同、模块、调用接口、资源和实机边界 |
| 阴的诅咒精确爆炸免疫封锁 | [方案一原生接口规格](../superpowers/specs/2026-10-02-yins-curse-explosion-immunity-interface-design.md)、[候选交付与检查](../../reports/yins-curse/native-interface/2026-10-02/delivery.md)、[实机证据](../../reports/yins-curse/native-interface/2026-10-02/game-acceptance.md)、[实施计划](../superpowers/plans/2026-10-02-yins-curse-explosion-immunity-interface.md) | 修正版候选已安装，真实能力为 1；核心与部分进阶/生命周期实测通过，未闭合验收项见证据卡 |
| My Stuff、死亡图标、本地 ID | [现有资源契约说明](../mystuff_item_id_migration.md) | 读取已维护的资源规则，不另复制一份 |
| 外部 Mod 兼容接口 | [兼容指南](../../COMPATIBILITY.zh-CN.md) | 核对已有公开接口和限制 |
| 道具审批或设计包流程 | [审批流程](../item-approval-ai-review-runbook.md)、[设计包流程](../item-design-agent-runbook.md) | 只在任务涉及对应流程时读取；执行前辨认写回操作 |
| 凸眼鱼 / Blinky：持续吸取、储物与投掷 | [已确认设计](../superpowers/specs/2026-10-03-blinky-pending-design.md)、[开发交付与实机测试卡](../../reports/blinky/2026-10-03/delivery.md) | `blinky.lua`/`blinky_core.lua` 已接入；核对价格与选项保留、受创红心及沙漏备用行为；实机验收状态看交付记录 |
| 炸弹套装 / Bomb Suit：受伤后计时自爆 | [已确认设计](../superpowers/specs/2026-10-03-bomb-suit-design.md)、[开发交付与实机证据](../../reports/bomb-suit/2026-10-03/delivery.md) | `bomb_suit.lua` 已接入；核对卖血范围、普通炸弹继承、散射归属和换房/沙漏取消边界；验收状态看交付记录 |
| AZ 折翼咳血主动道具：三秒飞行、假死、全房伤害 | [设计文档](../superpowers/specs/2026-10-12-azazel-broken-wings-active-item-design.md) | 核心玩法与原版 AZ 翅膀方向已确认；区分假死动作与红心代价致死，旧悬浮分镜已替代；尚未指定的身份与边界见文档 |
| 斗气拳套 / Drive Glove：蓝防、绿冲、斗气与力竭 | [机制设计](../superpowers/specs/2026-10-13-drive-parry-rush-active-item-design.md)、[第一版交付记录](../../reports/drive-rush/2026-10-14/implementation-v1/delivery.md)、[缩放与灰白反馈修订](../../reports/drive-rush/2026-10-14/visual-contact-fix/delivery.md)、[三种防御原声音效](../../reports/drive-rush/2026-10-14/audio-v1/delivery.md)、[蓝防启动与绿冲原音](../../reports/drive-rush/2026-10-15/audio-start-rush/delivery.md)、[蓝防操作与力竭原音修订](../../reports/drive-rush/2026-10-15/burnout-input/delivery.md)、[实机测试卡](../../reports/drive-rush/2026-10-14/implementation-v1/game-acceptance.md)、[实施计划](../superpowers/plans/2026-10-14-drive-glove.md) | 玩法、已采用动画和60×8 HUD已接入当前安装目录；核对30Hz计时、3f完美、成功后6f内退出免后摇、其余退出12f、连续转向／反向刹车和曲线路程、奖励去重、力竭与玩家存档。品质0，本地ID65；蓝防已改为不能移动／射击，单次有效方向立即绿冲；普通防御、普通蓝防、完美蓝防、蓝防启动、绿冲及进入／退出力竭的七种街霸6原音已接入；引擎事件和实际输出的验证范围分别见对应音效交付记录，其他声音事件待定。自动化和部分原生引擎检查已运行，人工手感、画面及复杂组合仍待验收，具体证据见交付记录 |
| 通用搓招：键盘容错、波动点击与原生攻击限制 | [输入设计](../superpowers/specs/2026-10-22-motion-input-system-design.md)、[实施计划](../superpowers/plans/2026-10-22-motion-input-system.md)、[真实战斗交付](../../reports/motion-items/2026-10-24/combat-v1/delivery.md) | 全部指令使用射击箭头，WASD只移动；四件主动持有即绑定、不需arm。共享核心保留通用双击能力但不恢复已删候选。正式道具现转交独立战斗模块；品质／池不动，真实游戏证据以交付记录为准 |
| 已确认招式演出、360指令投／720三气大招 | [已确认战斗合同](../superpowers/specs/2026-10-24-motion-combat-first-pass-proposal.md)、[实施计划](../superpowers/plans/2026-10-24-motion-combat.md)、[战斗交付与证据](../../reports/motion-items/2026-10-24/combat-v1/delivery.md) | `motion_combat.lua`／`motion_combat_core.lua`拥有真实弹体、近战、抓取、伤害回执、OD和720资源；`motion_items.lua`只绑定正式道具，`motion_presentation.lua`只绘制角色／特效与被传入的真实NPC。720用V9，其他资源不改；后台验收不接管键鼠 |
| 街霸6原版SA条：积攒、满气闪光与消耗 | [SA HUD计划](../superpowers/plans/2026-10-25-motion-sa-hud.md)、[资源来源与实机证据](../../reports/motion-sa-hud/2026-10-25/v1/delivery.md) | `motion_sa_hud.lua`只读战斗气量，默认原版SA数字／条形／关键帧转换为独立ANM2；玩家各自显示，隐藏和退出清理。规则、OD、品质、池不变；预览图与真实引擎证据分别记录 |
| 查阅已归档的待开发道具与系统 | [回声宝宝](../superpowers/specs/2026-09-28-echo-baby-pending-design.md)、[神的左手，恶魔之右手](../superpowers/specs/2026-09-28-divine-left-hand-demonic-right-hand-pending-design.md)、[背包系统](../superpowers/specs/2026-09-28-inventory-selection-system-pending-design.md) | 区分已记录的玩法、候选联动和待定边界；待开发记录不代表已实现或已验收 |
| 全局回放与接管练习：原生检查点、隔离和确定性 | [八组原生接口设计](../superpowers/specs/2026-10-22-global-replay-native-interfaces-design.md)、[分批验证计划](../superpowers/plans/2026-10-22-global-replay-native-interfaces.md) | 文档阶段，尚未实现；优先验证战斗现场完整恢复，最终覆盖整局、跨重启保存与分享、练习进度隔离，以及结束后精确返回发起时的原房间状态 |
| 不确定属于哪类 Isaac 开发问题 | [现有项目路由 Skill](../skills/isaac-neverbrith-router/SKILL.md) | 选择具体领域 Skill，按需读取其参考文档 |

斗气拳套的操作、成功反馈、普通防御伤害换算及持续按键蓄力取消修订，另见[2026-10-15修复与专项回归](../../reports/drive-rush/2026-10-15/mechanic-fixes/delivery.md)。该记录中保留的持续伤害缺口已在[持续伤害归属修复](../../reports/drive-rush/2026-10-15/dot-ownership/delivery.md)处理；后者记录本机原生来源接口、玩家／跟班的毒火流血、多人与原生伤害对照证据。

## 如何维护

2026-10-24招式修复：四件演出的原生Sprite接口、POST_RENDER模式、V9的64层引擎兼容和卸载后Game访问已修正，见[修复与后台实机证据](../../reports/motion-items/2026-10-24/runtime-fix-v1/delivery.md)。源V9不改，运行时副本50层；后台引擎绘制／退出与人工键盘手感分开记录。

同日后续用户纠正优先于上述初版接法：全部方向指令迁移到射击箭头，正式副本剔除演示敌人及其贴图，当前720运行时为46层；资源清理记录见[箭头与正式资源清理](../../reports/motion-items/2026-10-24/formal-arrow-cleanup-v1/delivery.md)。用户随后批准[具体战斗方案](../superpowers/specs/2026-10-24-motion-combat-first-pass-proposal.md)全部参数并要求实际扣血验证，接法、检查命令与实机边界改由[战斗交付](../../reports/motion-items/2026-10-24/combat-v1/delivery.md)记录，不再将动画播完当作战斗通过。

2026-10-25后续[抓取／OD／头身修复](../../reports/motion-items/2026-10-25/grab-od-body-fix-v1/delivery.md)：360接触帧重选合法目标，OD左Shift请求随搓招和收招缓存保留，原生图层偏移只应用一次并去除私有重复Overlay。用户新决定为实际获得720补满三气，覆盖旧初始0气；继续／沙漏保持恢复值，其他数值／池／品质不变。

同日后续接法见[独立方向与原生玩家](../../reports/motion-items/2026-10-25/native-player-free-direction-v1/delivery.md)。用户再纠正后的当前实现见[水平指令、正常AI抓取与原生动作](../../reports/motion-items/2026-10-25/horizontal-native-action-v1/delivery.md)：正式升龙只接受623／421、626／424、323／121，上下不能替代前后；360在指令完成时按原距离确认目标，第六帧抓取，取消起手移动导致的重查抓空。真实玩家保持原动画和服饰，按源动作整体起跳／横转，渲染后恢复，不隐藏／克隆／改帧玩家；720仍用V9FX／声音／时序。后台原生26场景324项和正常Haunt AI实测通过，人工画面与键盘手感另行评价。

同日追加[升龙白拳、360节奏／OD动作及720快捷输入](../../reports/motion-items/2026-10-25/fist-spd-shortcut-v1/delivery.md)：普通360经确认改为1.8秒，OD按完整官方SPD参考重排；升龙普通／OD两段使用独立透明白拳FX，720新增主动键＋↑↓且只有一个版本。输入规则和动作约束以[本轮计划](../superpowers/plans/2026-10-25-motion-fist-spd-shortcut.md)为准，池／品质不变；真实引擎与离线预览分别记录。

随后[升龙强制移动、OD无敌与720原生特写](../../reports/motion-items/2026-10-25/dp-control-cinema-v1/delivery.md)修正了升龙只在画面起跳而仍可自由移动、OD漏掉普通环境伤害、正式路径关闭V9镜头的问题。普通／OD升龙按源脚点水平推进且封锁WASD，OD起手至第二段结束免常规伤害、收招可受伤；720通过真实玩家原生Render恢复V9缩放、构图和横转，不克隆玩家。伤害／气量／池／品质不变，实际边界与恢复记录见交付。

接续的[多余硬直修复](../../reports/motion-items/2026-10-25/recovery-control-v1/delivery.md)将升龙的移动锁定限制到最后落地，取消逐个命中导致的反复停表；收招时间和OD保护0–32帧保留。720在289帧释放目标时交还控制并解除保护，剩余V9 FX独立收尾至394帧，可被新招替换；不再有返回房间后继续约3.5秒的无敌站立。当前恢复规则见[计划](../superpowers/plans/2026-10-25-motion-recovery-control.md)。

- 一条稳定规则只维护一处，其他页面链接过去。项目事实尽量链接源码、符号、测试和配置，避免复制完整清单或易失效的行号。
- 只为真实重复出现的定位需求增加专题；不为每个函数、每次修复或每条规则单独建页面。
- 临时失败、运行日志、测试数量与验收结论放在带日期的 `reports/` 中；不能因一次修复自动增加永久玩法约束。
- 修改相关代码时复核专题中的关系。移动页面或改变链接时运行[导航检查](../../tests/agent_wiki_navigation_test.ps1)。该检查能发现断链和孤立页面，不能证明文档事实仍然正确。
- 当前知识页不保存已验证版本清单或测试通过徽章。运行结果必须来自本次执行；人工确认状态以用户确认记录为准。
