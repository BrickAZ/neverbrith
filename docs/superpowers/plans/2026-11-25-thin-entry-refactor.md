# 完整薄入口重构

状态：范围已按用户后续指令收窄，只保证当前已经重构的道具；停止新增迁移。以下保留初始清单，当前逐项迁移落地但仍按阶段性收尾记录，不宣称完整目标架构已经验收。

当前已确认道具和并行批次的记录统一从[进度入口](../../architecture/refactor-progress.md)查阅；下表保留历史阶段状态，不替代后续批次交付或修复记录。

2026-11-26 后续授权：第十批单独完成未生证明、再契象的进一步拆分和共同房间能力；下面只更新这两行的本批验收状态，其他行仍保留本表的历史记录。详细证据及跨进程 Continue、多人原生和人工体验边界见[第十批交付](../../../reports/refactor-batch10/2026-11-26/delivery.md)。

用户合同：main.lua 只做前置检查、创建 Mod/共享服务、依赖组装和显式顺序 include 安装。默认每件道具一个入口，复杂道具可拥有独立目录。玩法、私有状态、回调和生命周期均由所属模块持有；共同机制由共享系统持有。保留玩法、数值、品质、池、资源、存档格式和回调相对顺序，不把旧主文件整体转移到另一个大文件。

## 初始范围（逐项追踪）

下列 27 件在本轮基线 main.lua 中仍拥有实现；“已迁移”必须包含分散的回调和生命周期，不能只搬主体。

| 道具 | 状态 | 目标入口 |
| --- | --- | --- |
| 调试控制器 | 已迁移待验收 | scripts/features/debug_controller.lua |
| 老大的指令 | 已迁移待验收 | scripts/features/boss_order.lua |
| 生死一念间 | 已迁移待验收 | scripts/features/between_death_and_life.lua |
| 铜钱剑 | 已迁移待验收 | scripts/features/coin_sewn_sword.lua |
| 铜钱面具 | 已迁移待验收 | scripts/features/coin_faced_mask.lua |
| 黑太岁 | 已迁移待验收 | scripts/features/black_taisui.lua |
| 肉块 | 已迁移待验收 | scripts/features/meat_lump.lua |
| 净化迷幻菇 | 已迁移待验收 | scripts/features/cleansed_wavy_cap.lua |
| 巴比伦好女孩 | 已迁移待验收 | scripts/features/good_girl_of_babylon.lua |
| 强力泻药 | 已迁移待验收 | scripts/features/strong_laxative.lua |
| 通天塔 | 已迁移待验收 | scripts/features/tower_of_babel.lua |
| 月色真美 | 已迁移待验收 | scripts/features/the_moon_is_beautiful.lua |
| 焚尽郁结 | 已验收（第十一批范围），见[交付](../../../reports/refactor-batch11/2026-11-26/delivery.md) | scripts/features/burn_away_resentment.lua → queries/attributes/ledger/presentation/combat/runtime |
| 柴刀（保留原禁用角色政策） | 第十四批职责拆分；正式角色仍禁用 | scripts/features/cleaver.lua；[职责清单](../../../reports/refactor-batch14/2026-11-26/consumer-inventory.md)、[验证边界](../../../reports/refactor-batch14/2026-11-26/delivery.md) |
| 天使盒 | 已迁移待验收 | scripts/features/boxes/angelbox.lua |
| 恶魔盒 | 已迁移待验收 | scripts/features/boxes/devilbox.lua |
| 避孕套 | 已迁移待验收 | scripts/features/condom.lua |
| 疯狂的椰子 | 已迁移待验收 | scripts/features/crazy_coconut.lua |
| 鸿运齐天蛊 | 已迁移待验收 | scripts/features/fortune_rivalling_heaven_gu.lua |
| 小皮鞋 | 已迁移待验收 | scripts/features/little_leather_shoes/init.lua |
| 流量：开箱 | 已迁移待验收 | scripts/features/traffic_unboxing.lua |
| 流量：曝光 | 已迁移待验收 | scripts/features/traffic_exposure.lua |
| 流量：热度 | 已迁移待验收 | scripts/features/traffic_heat.lua |
| 未生证明 | 已验收（第十批范围） | scripts/features/certificate_of_neverbirth.lua → 同名目录 ledger/gallery/flow/pickups/runtime；共同 archive_room/archive_controls |
| 再契象 | 已验收（第十批范围） | scripts/features/house_vs_elephant.lua → 同名目录 ledger/gallery/flow/pickups/runtime；共同 archive_room/archive_controls |
| 千变万化 | 已验收（第十二批范围），见[交付](../../../reports/refactor-batch12/2026-11-26/delivery.md) | scripts/features/everchanging.lua → registry/state/selection/resources/player_anm2/presentation/runtime |
| ACE 反作弊系统 | 第十五批已完成职责拆分与限定原生对照；人工/整轮验收另列 | scripts/features/ace_anti_cheat_system.lua；[本批证据](../../../reports/refactor-batch15/2026-11-26/delivery.md) |

ds4 在基线中只有 ID/文本登记，没有独立玩法函数；明确归入内容目录，不伪造空玩法模块。骰子套装属于共享变身系统，单独追踪。

前两批已迁移的 18 件如下。七件狗粮现已补齐逐道具入口，共同获取记账由一个系统持有。下表入口均相对 scripts/features/，历史实机验收边界仍见各批交付记录。

| 道具 | 当前唯一入口 |
| --- | --- |
| 风油精 | essential_balm.lua |
| 芜湖 | wuhu.lua |
| 八音盒 | musicbox/init.lua |
| 高蛋白肉条 | protein_strip.lua |
| 活力狗饼干 | energy_kibble.lua |
| 轻盈低脂罐头 | lean_can.lua |
| DHA 鱼油 | dha_fish_oil.lua |
| 护齿磨牙骨 | dental_chew.lua |
| 幸运肝粒 | lucky_liver_bites.lua |
| 羊奶布丁 | goat_milk_pudding.lua |
| 春药 | chunyao.lua |
| 美工刀 | utility_knife.lua |
| 虚空针尖 | needletick.lua |
| 绝育证明 | sterilization_certificate.lua |
| 剪碎的塔罗 | shredded_tarot.lua |
| 血颅蛊 | blood_skull_gu.lua |
| 未剪断的脐带 | uncut_cord.lua |
| 空摇篮 | empty_cradle.lua |

本批初始 27 件清单中仍未迁移：0 件。已有其他独立模块未因本次收口而自动列为已验收，后续改造暂缓。当前 45 件迁移落地与离线检查通过，不能替代全部道具的实机验收。

收尾证据：[阶段性交付记录](../../../reports/thin-entry/2026-11-25/delivery.md)。最终 LuaAll 为 108 项通过、101 个 Lua 测试、229 个语法文件；472 条回调登记、138 条 EID 描述与基线一致；最终原生既有 7 场景 42 项通过。全部原生玩法、人工体验、性能和包级验收仍有未完成范围。

## 公共职责与任务

1. 保存实际工作区基线、完整清单和回调签名；先运行 LuaAll。
2. 民俗组逐道具拆分：共享世界查询、表现、生命查询和状态适配独立归属，保留交错注册顺序。
3. 独立道具逐项迁移：Boss/试炼、盒子、获取组、后段大型功能；小皮鞋奖励各有入口。
4. 入口基础职责拆分：ID 目录、语言与横幅、EID 兼容、日志/玩家/种子查询、骰子套装、七件狗粮配置入口、遗留存档访问。主入口只显式装配。
5. 统一安装故障清理，真实入口注册签名对照、行为/状态/生命周期、负例与资源哈希验证；原生加载与受影响场景验证。
6. 独立审查、修复和收尾，最终逐项列已迁移/未迁移及未验证的实机边界。

## 实施约束与回退

- 当前源码未提交；基线 reports/thin-entry/2026-11-25/baseline，不能用 Git HEAD 替代。
- 主代理独占 main.lua；子代理只创建其任务拥有的模块和明确锚点迁移脚本，避免并发修改入口。
- 模块导出安装阶段方法，交错注册仍在入口原序调用；回调函数实现和注册语句归模块。
- 已外置模块保持原入口；仅整理实际留在 main 的实现及必要接口。以旧工厂返回值或正式 API 注入，正式代码不新增 TestAPI 依赖。
- 不提交、不推送、不发布、不变更资源和 XML，不改变已禁用功能的启用状态。
- 发生错误时仅恢复本轮范围的基线；报告不得将离线通过等同于人工实机验收。

## 第二十批：记忆紊乱独立模块

2026-11-26 用户授权对原根目录独立道具继续拆分。记忆紊乱现由 `scripts/features/memory_disorder.lua` 装配十个私有模块，旧 `memory_disorder.lua` 保留工厂兼容路径；角色切换、临时构筑、生命账本、伙伴归还、图标与虚空资格保持原语义。具体职责和本批状态见[迁移/复用清单](../../../reports/refactor-batch20/2026-11-26/consumer-inventory.md)，实际验证范围见[交付](../../../reports/refactor-batch20/2026-11-26/delivery.md)。本段不改变其他批次状态，不代表整轮或原生验收完成。
