# 公共 API 索引

先按任务查下表，再读对应说明和当前源码。这里记录当前实现，不承诺所有接口都已统一成目标架构。调用示例中的 `mod`、`json`、`deps` 来自现有装配环境；不要为了复用而重复初始化有状态模块。

**覆盖范围**：当前 `scripts/runtime`、`scripts/systems`、`scripts/catalog`、`scripts/integrations` 的全部模块，以及两盒共享的五个模块。目录中也有内容专属系统和启动适配，它们已标明用途，不全部推广成通用 lib。根目录旧模块的对外接口仍见[兼容指南](../../COMPATIBILITY.zh-CN.md)与[项目地图](../agent/project-map.md)，道具私有实现不属于本索引。

| 能力 / 当前模块 | 使用说明 |
| --- | --- |
| [players](../../scripts/runtime/players.lua)：当前玩家列表 | [运行基础](runtime-basics.md) |
| [run_seed](../../scripts/runtime/run_seed.lua)：当前种子字符串 | [运行基础](runtime-basics.md) |
| [new_run_reset](../../scripts/runtime/new_run_reset.lua)：新局清理处理器工厂 | [运行基础](runtime-basics.md) |
| [run_section](../../scripts/runtime/run_section.lua)：按种子解析当前存档区域 | [存档](persistence.md) |
| [world_queries](../../scripts/runtime/world_queries.lua)：受保护世界查询与既有键算法 | [基础机制](shared-mechanics.md) |
| [log](../../scripts/runtime/log.lua)：日志适配 | [运行基础](runtime-basics.md) |
| [world_feedback](../../scripts/runtime/world_feedback.lua)：房间变暗操作 | [运行基础](runtime-basics.md) |
| [persistence](../../scripts/runtime/persistence.lua)：单实例存档服务 | [存档](persistence.md) |
| [player_identity](../../scripts/runtime/player_identity.lua)：既有逻辑玩家与身体背包键 | [共享状态与装配](shared-state.md) |
| [snapshot_participants](../../scripts/runtime/snapshot_participants.lua)：每实例快照参与者 | [共享状态与装配](shared-state.md) |
| [acquisition_state](../../scripts/systems/acquisition_state.lua)：实际获得、实物记录与沙漏槽接入 | [共享状态与装配](shared-state.md) |
| [low_grade_eid](../../scripts/integrations/low_grade_eid.lua)：零分考卷可选 EID 登记 | [共享状态与装配](shared-state.md) |
| [legacy_save_schema](../../scripts/runtime/legacy_save_schema.lua)：所有者旧格式初始化组合器 | [存档](persistence.md) |
| [dice_set/save_schema](../../scripts/systems/dice_set/save_schema.lua)：骰子套装旧格式声明 | [存档](persistence.md) |
| [plain_data](../../scripts/runtime/plain_data.lua)：普通数据树复制 | [普通数据复制](plain-data.md) |
| 临时复制、回声宝宝、凸眼鱼、零分考卷与背包选择器：所有权、共享边界与兼容入口 | [获取组接口](batch19-content.md) |
| [control_ownership](../../scripts/systems/control_ownership.lua)：按所有者申请和释放射击权限 | [控制占用](control-ownership.md) |
| [feature_installation](../../scripts/runtime/feature_installation.lua)：安装事务 | [安装](installation.md) |
| [localization](../../scripts/runtime/localization.lua)：运行文本与字体 | [文本与横幅](presentation.md) |
| [pickup_banners](../../scripts/runtime/pickup_banners.lua)：中文拾取横幅 | [文本与横幅](presentation.md) |
| [item_diagnostics](../../scripts/runtime/item_diagnostics.lua)：启动 ID 日志 | [登记与 EID](catalog-and-eid.md) |
| [card_rewards](../../scripts/systems/card_rewards.lua)：卡牌候选与卡池请求 | [卡牌与属性查询](gameplay-queries.md) |
| [collectible_stats](../../scripts/systems/collectible_stats.lua)：数量与射速换算 | [卡牌与属性查询](gameplay-queries.md) |
| [active_slots](../../scripts/systems/active_slots.lua)：现有主动槽枚举 | [基础机制](shared-mechanics.md) |
| [collectible_rng](../../scripts/systems/collectible_rng.lua)：明确回退策略的随机抽取 | [基础机制](shared-mechanics.md) |
| [combat_source](../../scripts/systems/combat_source.lua)：来源实体与玩家转换 | [基础机制](shared-mechanics.md) |
| [attack_ownership](../../scripts/systems/attack_ownership.lua)：阿瓦达攻击接管查询 | [攻击接管查询](shared-mechanics.md#攻击接管查询) |
| [entity_identity](../../scripts/systems/entity_identity.lua)：瞬态 pointer/InitSeed 键 | [基础机制](shared-mechanics.md) |
| [斗气拳套](../../drive_glove.lua)和[搓招 Core](../../motion_combat_core.lua)：实例装配、逐件配置与共享引用 | [斗气拳套与搓招系统](drive-motion.md) |
| [fire_rate](../../scripts/systems/fire_rate.lua)：正射速增量换算 | [基础机制](shared-mechanics.md) |
| [null_costumes](../../scripts/systems/null_costumes.lua)：服装 ID 缓存与状态转换 | [基础机制](shared-mechanics.md) |
| [shooting_scope](../../scripts/systems/shooting_scope.lua)：调用者拥有的射击权限快照与恢复 | [射击权限作用域](shooting-scope.md) |
| [incoming_damage](../../scripts/systems/incoming_damage.lua)：致命伤害预判 | [卡牌与属性查询](gameplay-queries.md) |
| [player_geometry](../../scripts/systems/player_geometry.lua)：头部世界位置 | [卡牌与属性查询](gameplay-queries.md) |
| [folk_world](../../scripts/systems/folk_world.lua)：民俗组世界、金币、RNG 能力 | [民俗组服务](folk-services.md) |
| [folk_costumes](../../scripts/systems/folk_costumes.lua)：服装移除适配 | [民俗组服务](folk-services.md) |
| [folk_survival_cooldown](../../scripts/systems/folk_survival_cooldown.lua)：共享保命冷却参数 | [民俗组服务](folk-services.md) |
| [folk_parasite_state](../../scripts/systems/folk_parasite_state.lua)：旧存档区域和运行状态 | [民俗组服务](folk-services.md) |
| [folk_lifecycle](../../scripts/systems/folk_lifecycle.lua)：新局清理协调 | [民俗组服务](folk-services.md) |
| [folk_visual_effects](../../scripts/systems/folk_visual_effects.lua)：特效生成与跟随 | [民俗组服务](folk-services.md) |
| [archive_room](../../scripts/systems/archive_room.lua)：陈列室世界查询、玩家位置与布局 | [陈列室共同能力](archive-rooms.md) |
| [archive_controls](../../scripts/systems/archive_controls.lua)：机关动画、无碰撞与触碰锁 | [陈列室共同能力](archive-rooms.md) |
| 未生证明 / 再契象：CarrierAPI 返回值、显式 provider 与兼容别名 | [两件道具的显式装配接口](archive-rooms.md#两件道具的显式装配接口) |
| 虚空针尖 / 鸿运齐天蛊：GetLuckCap 返回查询与显式依赖 | [幸运阈值连接](luck-cap-wiring.md) |
| [dice_set](../../scripts/systems/dice_set.lua)：骰子套装内容系统 | [内容专属系统](content-systems.md) |
| [dog_food_acquisition](../../scripts/systems/dog_food_acquisition.lua)：狗粮获取记账 | [内容专属系统](content-systems.md) |
| 大狗叫、蓄风棒、回响碎片：组内状态、目标、效果与水迹实例 | [大狗组接口与生命周期](big-dog-family.md) |
| [collectibles](../../scripts/catalog/collectibles.lua)：运行时道具 ID | [登记与 EID](catalog-and-eid.md) |
| [item_id](../../scripts/catalog/item_id.lua)：既有 ID 宽松判定 | [登记与 EID](catalog-and-eid.md) |
| [item_config](../../scripts/catalog/item_config.lua)：配置与宝宝标签查询 | [登记与 EID](catalog-and-eid.md) |
| [pickup_texts](../../scripts/catalog/pickup_texts.lua)：横幅文本登记 | [登记与 EID](catalog-and-eid.md) |
| [eid_descriptions](../../scripts/catalog/eid_descriptions.lua)：EID 数据 | [登记与 EID](catalog-and-eid.md) |
| [eid](../../scripts/integrations/eid.lua)：EID 发布和失败恢复 | [登记与 EID](catalog-and-eid.md) |
| [boxes/shared](../../scripts/features/boxes/shared.lua)：两盒共享装配 | [两盒](boxes.md) |
| [boxes/active_charge](../../scripts/features/boxes/active_charge.lua)：特殊充能 | [两盒](boxes.md) |
| [boxes/reward_selection](../../scripts/features/boxes/reward_selection.lua)：奖励筛选工厂 | [两盒](boxes.md) |
| [boxes/reward_ledger](../../scripts/features/boxes/reward_ledger.lua)：独立区域的首用、待发奖励与概率账本 | [两盒](boxes.md) |
| [boxes/reward_delivery](../../scripts/features/boxes/reward_delivery.lua)：奖励生成与结算顺序 | [两盒](boxes.md) |

所有接口按当前实现区分点/冒号调用、引用与副本。命名为 Get/Is 的旧接口仍可能进行懒初始化，不可仅凭名称推断纯度。本文档不扩展旧存档键、多人身份或回溯保证。

维护要求见[开发规范](../agent/development-conventions.md)。新增共享目录或共享子模块时同步扩展本索引与[知识检查](../../tests/project_knowledge_test.ps1)的发现范围。静态覆盖检查可发现模块遗漏和断链，不证明函数语义全部正确。
