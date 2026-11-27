# 项目地图

## 运行源码

2026-11-27 共享状态、按字段存档分区与显式依赖收尾，以及资源定位修正，见[本轮交付与证据](../../reports/framework-finish/2026-11-27/delivery.md)。自定义角色仍暂停开发，旧内容原位暂留；正式登记资源继续按实际路径检查。

| 位置 | 当前职责与阅读方式 |
| --- | --- |
| [main.lua](../../main.lua) | 当前负责前置检查、Mod/共享服务创建与按原顺序组装模块。已迁出道具的逐项清单及阶段状态见[本轮记录](../superpowers/plans/2026-11-25-thin-entry-refactor.md)；入口变短不代表全部实机验收完成 |
| 根目录 Lua 模块 | 专题实现或保留的旧工厂路径；例如 [memory_disorder.lua](../../memory_disorder.lua)转入[记忆紊乱装配入口](../../scripts/features/memory_disorder.lua)。从 `main.lua` 的 `include(...)` 和对应 `*_BEGIN` 标记追踪传入依赖及回调归属 |
| [scripts/features/](../../scripts/features/) | 按道具命名的实现入口；复杂功能使用自己的目录。八音盒分为 [接入](../../scripts/features/musicbox/init.lua)、[规则](../../scripts/features/musicbox/core.lua)和[表现](../../scripts/features/musicbox/presentation.lua)。[狗粮组装](../../scripts/features/dog_food_series.lua)显式创建七件道具入口，共用[获取记账](../../scripts/systems/dog_food_acquisition.lua)。回调仍按原相对位置安装 |
| 第十三批大狗组三件 | 根目录 [big_dog_bark.lua](../../big_dog_bark.lua) 保留兼容工厂；[大狗入口](../../scripts/features/big_dog_bark.lua) 创建一次私有实例并按原顺序安装。[蓄风棒](../../scripts/features/wind_charge_rod.lua)提供实际使用的持有判定，[回响碎片](../../scripts/features/echo_shard.lua)拥有回响数据、伤害和实体更新。共同能力、存档与计时合同见[组内接口](../api/big-dog-family.md)，证据见[交付](../../reports/refactor-batch13/2026-11-26/delivery.md) |
| 第二批独立道具模块 | [春药](../../scripts/features/chunyao.lua)、[美工刀](../../scripts/features/utility_knife.lua)、[虚空针尖](../../scripts/features/needletick.lua)、[绝育证明](../../scripts/features/sterilization_certificate.lua)、[剪碎的塔罗](../../scripts/features/shredded_tarot.lua)、[血颅蛊](../../scripts/features/blood_skull_gu.lua)、[脐带](../../scripts/features/uncut_cord.lua)、[空摇篮](../../scripts/features/empty_cradle.lua)。血颅蛊实例提供只读反噬查询给脐带/空摇篮；美工刀使用独立存档区域，回调保留在入口原有穿插位置 |
| 第十批房间选择道具 | [未生证明](../../scripts/features/certificate_of_neverbirth.lua)、[再契象](../../scripts/features/house_vs_elephant.lua)各自拥有 ledger/gallery/flow/pickups/runtime；共用[房间与机关能力](../api/archive-rooms.md)，保留不同的会话、领取与继续游戏策略。证据见[交付记录](../../reports/refactor-batch10/2026-11-26/delivery.md) |
| 第十一批焚尽郁结 | [入口](../../scripts/features/burn_away_resentment.lua)创建 queries/attributes/ledger/presentation/combat/runtime 六个私有实例；复用 folk_world、player_geometry 和 combat_source。运行时楼层记账、爆发确认及视觉分别拥有状态；Continue 仍清空本件状态。责任与证据见[清单](../../reports/refactor-batch11/2026-11-26/consumer-inventory.md)及[交付](../../reports/refactor-batch11/2026-11-26/delivery.md) |
| 第十二批千变万化 | [入口](../../scripts/features/everchanging.lua)创建 registry/state/selection/resources/player_anm2/presentation/runtime 七个私有实例。复用 null_costumes 的 ID 缓存，保留五个外观、双人资格、抽选与存档语义；外观应用和资源查询失败策略仍由本件拥有。责任与证据见[清单](../../reports/refactor-batch12/2026-11-26/consumer-inventory.md)及[交付](../../reports/refactor-batch12/2026-11-26/delivery.md) |
| 第十四批攻击接管与结算 | [诛](../../annihilation.lua)、[阿瓦达啃大瓜](../../avada_kedavra.lua)、[柴刀](../../scripts/features/cleaver.lua)分别组装五、七、八个私有模块；共用[攻击接管查询](../api/shared-mechanics.md#攻击接管查询)，保留不同的输入、命中和临时状态政策。柴刀原角色仍禁用。职责见[清单](../../reports/refactor-batch14/2026-11-26/consumer-inventory.md)，验证范围见[交付](../../reports/refactor-batch14/2026-11-26/delivery.md) |
| 第十五批全局限制与处罚 | [阴的诅咒](../../yins_curse.lua)、[七咒之戒](../../ring_of_the_seven_curses.lua)、[ACE](../../scripts/features/ace_anti_cheat_system.lua)各创建五个私有模块，分别拆分状态、规则与回调；原入口、原生免疫接口、伤害次序和存档语义保留。职责与共享能力见[清单](../../reports/refactor-batch15/2026-11-26/consumer-inventory.md)，检查范围见[交付](../../reports/refactor-batch15/2026-11-26/delivery.md) |
| [存档服务](../../scripts/runtime/persistence.lua)与[旧格式适配](../../scripts/runtime/legacy_save_schema.lua) | 单一懒加载根实例；各模块使用 Section 或按旧字段授权的 Scope，正式入口不再把完整根交给旧模块。保留 nil 清理、区域替换、未知字段及首次默认形状，详见[用法](../api/persistence.md) |
| 获取、身份与快照 | [获取接入](../../scripts/systems/acquisition_state.lua)、[持久身份](../../scripts/runtime/player_identity.lua)、[参与者注册表](../../scripts/runtime/snapshot_participants.lua)各有归属。旧 pending_content_state.lua 转发工厂；主入口保存同一实例并连接消费者。接口、兼容边界与测试见[共享状态](../api/shared-state.md) |
| 第二十一批输入与战斗道具 | [斗气拳套入口](../../scripts/features/drive_glove/init.lua)组装状态、冻结、输入、移动、武器、受伤、归属和生命周期；根目录工厂兼容保留。四件配置分别在 [360](../../scripts/features/motion_items/piledriver_360.lua)、[720](../../scripts/features/motion_items/ultimate_720.lua)、[波动](../../scripts/features/motion_items/motion_wave.lua)、[升龙](../../scripts/features/motion_items/dragon_punch.lua)，由既有 motion 输入/战斗/表现实例实际消费。合同见[API](../api/drive-motion.md)，范围与证据见[本批清单](../../reports/refactor-batch21/2026-11-26/consumer-inventory.md) |
| [模块安装保护](../../scripts/runtime/feature_installation.lua) | 当前正常启动的全部装配处在一个事务内；内部阶段共用登记记录。失败时撤销本次回调、Mod 顶层导出及显式发布的旧全局兼容名字；恢复旧全局 Mod。只在同步安装时跟踪，不参与逐帧调度或存档。完整入口故障覆盖见[安装失败检查](../../tests/thin_entry_installation_test.lua) |
| [内容目录](../../scripts/catalog/collectibles.lua)、[运行语言](../../scripts/runtime/localization.lua)及 [EID 适配](../../scripts/integrations/eid.lua) | ID 解析与文本数据、语言运行逻辑、外部 EID 登记分别拥有明确入口；拾取横幅由[横幅服务](../../scripts/runtime/pickup_banners.lua)处理 |
| [致命伤害查询](../../scripts/systems/incoming_damage.lua) | 八音盒、黑太岁和肉块共用的原有查询，显式接入；不决定各道具的保护顺序 |
| [repentogon_dependency_guard.lua](../../repentogon_dependency_guard.lua) | 前置不满足时的诊断与掉落保护；正常玩法启动从 `main.lua` 开头继续追踪 |
| [generated/neverbirth_collectibles.lua](../../generated/neverbirth_collectibles.lua) | 生成的道具登记数据；来源与只检查命令见下文，不手工改生成结果 |
| [content/](../../content/) | 道具、道具池、实体等注册；存在原生资源入口，不能一概认为只有 XML |
| [resources/](../../resources/) | 图像、动画、音频等资源；每种显示表面分别核对消费者和路径 |
| [tests/](../../tests/)、[tools/](../../tools/) | 模拟行为、资源契约及维护工具；维护工具可能写 XML、图片或工作簿，先读参数与副作用 |

定位道具时先搜索英文标识和中文名，再确认实际所有者。例如：

```powershell
rg -n 'MEMORY_DISORDER_BEGIN|initializeMemoryDisorder|GetCollectibleConfigs' main.lua
rg -n 'GetItemConfig|GetCollectibles' tests/dice_set_behavior_test.lua scripts/features/memory_disorder
```

## 注册、语言与资源关联

- 道具注册通常涉及 [items.xml](../../content/items.xml)、[英文模板](../../content/items.en_us.xml)、[中文模板](../../content/items.zh_cn.xml)。原生 XML 本地 ID、运行时道具 ID 和测试模拟 ID 是不同概念。
- 道具池变更同时核对 [基础道具池](../../content/itempools.xml)、[英文道具池](../../content/itempools.en_us.xml)、[中文道具池](../../content/itempools.zh_cn.xml)；不自行补选未确认的池或权重。
- 文本变更沿当前实现寻找 XML、EID 与运行时提示，并阅读 [localization_test.lua](../../tests/localization_test.lua)。语言模板同步会覆盖基础 XML，不能当作无副作用的检查。
- 生成登记数据使用 [generate-neverbirth-collectibles.ps1](../../tools/generate-neverbirth-collectibles.ps1)。`-Check` 仅验证同步；省略它会写生成文件。
- ESC/My Stuff 与死亡图标遵循[现有迁移说明](../mystuff_item_id_migration.md)；底座、举起图标、EID、暂停页和死亡页需要分别核对，不能相互替代验收。

## 开发材料边界

有效 Isaac Skills 维护在 [`.agents/skills/`](../../.agents/skills/)；旧包归入 [`deprecated/skills/`](../../deprecated/skills/README.md)，`docs/skills/` 只保留说明和命令转发，不能作为当前指令来源。项目验证器已归入 [tools/validators/](../../tools/validators/)，旧验证路径只转发。来源、版本管理及维护规则见 [Skill 权威来源](skill-authority.md)。公共模块用法见[公共 API 索引](../api/index.md)，源码职责与文件位置仍由本页导航。

`reports/`、`diagnostics/`、`outputs/` 保存任务产物；`release/`、`worktrees/`、`.worktrees/` 可包含发布包或独立源码副本。它们不是当前模组 Lua 入口的组成部分。寻找当前实现先限定根目录相关模块、`tests/`、`content/` 和 `resources/`，需要历史证据时再单独阅读这些目录。

本页只界定导航范围，不授权清理、移动或删除这些材料。检查前保留工作区已有变更。运行方式与当前声明的依赖边界见 [README](../../README.zh-CN.md)，验证命令见[检查与证据](testing.md)。

首批范围、接口及撤回边界见[实施计划](../superpowers/plans/2026-11-24-first-batch-refactor.md)。打包或复制实际运行内容时需要包含 `scripts/`；仅复制根目录 Lua 会遗漏新模块。真实加载清单由严格验证器从入口追踪。

第二批边界与状态合同见[重构方案](../superpowers/specs/2026-11-24-second-batch-refactor-design.md)，实施与检查步骤见[第二批实施计划](../superpowers/plans/2026-11-25-second-batch-refactor.md)。后续验证结果以带日期的交付记录为准。

第三批四件的收口范围见[第三批实施计划](../superpowers/plans/2026-11-25-third-batch-refactor.md)：老大的指令、生死一念间、天使盒和恶魔盒沿用已有独立入口。两盒通过 `boxes/shared.lua` 创建主动槽充能与奖励筛选能力，具体实现分别在 `boxes/active_charge.lua` 和 `boxes/reward_selection.lua`；道具自身保留品质、池、回退候选及奖励资格政策。两盒奖励心仍由 `heart_bonuses.lua` 单独处理，实际交易房仍由根目录 `box_deal_rooms.lua` 负责。

第四批的小皮鞋与三件流量奖励见[第四批实施计划](../superpowers/plans/2026-11-25-fourth-batch-refactor.md)。`little_leather_shoes/init.lua` 保留死亡链、返场、清房与楼层结算，组内 `rules.lua` 提供纯规则，`rewards.lua` 管理二选一和取得后的奖励派发，`presentation.lua` 管理 HUD、连线和拾取动画完成通知。`traffic_heat.lua` 通过独立刷新队列与时钟查询管理永久热度；开箱和曝光沿用各自奖励模块。`runtime_views.lua` 限制各模块的状态字段访问，同时保留原公开平面状态及存档字段。

第五批的黑太岁、肉块与净化迷幻菇见[第五批实施计划](../superpowers/plans/2026-11-25-fifth-batch-refactor.md)。`black_taisui.lua` 组装同名目录中的成长/阶段奖励、保命/孢子、净化/显形、表现及组内生命周期模块，原交错登记顺序仍由显式安装方法保留。肉块的 `ledger.lua` 管理旧存档中的取得计数与额外生命，`presentation.lua` 只显示查询到的生命数；净化迷幻菇通过玩家接口管理属性应用和换层重置。旧 `folk_parasite_state.lua` 保留存档与运行状态的兼容布局，不代表三件道具共用同一份玩法实现。

第六批的铜钱剑与铜钱面具见[第六批实施计划](../superpowers/plans/2026-11-25-sixth-batch-refactor.md)。`coin_sewn_sword.lua` 组装道具自己的 `rules`、`aiming`、`input`、`attack`、`qi` 与 `presentation`；输入模块管理持剑和释放当次的输入锁，消费与剑气战斗分别拥有实现，原 `InstallHoldCallbacks` 接入位置保持不变。`coin_faced_mask.lua` 保留生命周期协调，`state` 独占玩家房间状态写入，`settlement` 负责伤害与幸运结算，`presentation` 负责服装缓存。两件继续复用 `folk_world` 的金币接口，各自决定消费政策，不增加存档字段。

第七批的强力泻药与通天塔见[第七批实施计划](../superpowers/plans/2026-11-25-seventh-batch-refactor.md)。`strong_laxative.lua` 组装 `players`、`creep`、`poop`、`presentation` 和 `synergies`：分别管理玩家计时、液体战斗、随机生成与房间数量、服装、生成时联动取样；根目录 `strong_laxative_synergies.lua` 只保留兼容导出。通天塔自己的 `creep_variants` 目录模块管理移除类型集合，入口继续提供 `RemoveCreepIfActive` 给强力泻药。两件使用不同的免伤/移除范围；玩家状态分别持有，每房大便上限按原语义共享，回调顺序及存档格式不变。

第八批的巴比伦好女孩与月色真美见[第八批实施计划](../superpowers/plans/2026-11-26-eighth-batch-refactor.md)。各自入口登记回调，并组装道具目录内的状态/房间、战斗、奖励和表现模块；好女孩通过安装事务保留旧全局导出，月色真美保留 `Neverbirth.Moon` 动态方法接口。`systems/card_rewards.lua` 只提供无状态的配置显示验证、候选去重排序和卡池双次调用；两件道具分别拥有 EID 查询、重试次数、种子偏移、空候选处理及奖励结算政策，不共用玩法状态或存档。

第九批的避孕套、疯狂的椰子与鸿运齐天蛊见[第九批实施计划](../superpowers/plans/2026-11-26-ninth-batch-refactor.md)。三个入口保留原显式安装方法和交错登记位置。避孕套由自己的 `bans`、`replacement`、`presentation` 管理本局名单与选择、底座替换、名称反馈；椰子由 `ledger`、`attributes`、`acquisition` 管理旧存档视图、伤害与拾取结算，其中候选推进和同批次结算分开维护。鸿运由 `audit`、`registry`、`runtime` 分别持有需求表、追加注册与最大值计算、依赖快照和两阶段缓存刷新；公开扩展接口及状态格式保持原样。

已完成批次的公共能力补全（38 件）的消费者清单与保留差异统一维护在[目标架构第 12.2 节](../architecture/2026-11-24-neverbirth-target-architecture.md)。使用或扩展这些能力先查[公共 API 索引](../api/index.md)，此次旧新行为与原生对照证据见[交付记录](../../reports/refactor-shared/2026-11-26/delivery.md)。

第十六批我即神明、神性过载、炸弹套装见[实施记录](../superpowers/plans/2026-11-26-sixteenth-batch-refactor.md)。根目录三个入口连接各自 config、state 与战斗/表现/生命周期模块，目录为 scripts/features/i_am_a_god、god_complex、bomb_suit。两件禁火消费者复用 shooting_scope；计时、换房、禁疗、形态历史与爆炸后代归属仍属各道具。具体状态合同与验证边界见[消费者清单](../../reports/refactor-batch16/2026-11-26/consumer-inventory.md)。

第十八批胆小鬼之夜、神风特攻队见[实施计划](../superpowers/plans/2026-11-26-eighteenth-batch-refactor.md)。根目录兼容工厂分别转交 [night_of_the_cowards](../../scripts/features/night_of_the_cowards.lua) 和 [kamikaze_squad](../../scripts/features/kamikaze_squad.lua)；同名目录管理各自的查询、NPC 行为、实体归属和生命周期，胆小鬼另有 c20 赠予及恐惧显示模块。原装配位置、回调顺序和存档键保留，公共能力差异与清理责任见[消费者清单](../../reports/refactor-batch18/2026-11-26/consumer-inventory.md)。
