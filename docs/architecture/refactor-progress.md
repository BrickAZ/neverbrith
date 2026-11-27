# 已重构道具进度入口

核对日期：2026-11-27（Europe/Warsaw）。这是当前状态入口；历史计划和批次报告保留原范围。本轮用户已授权多子代理完成框架收尾，当前全量登记以[逐件清单](refactor-inventory.md)和[共享能力总表](shared-capability-status.md)为准。

当前 content/items.xml 共 69 件 collectible：68 件已有玩法均有独立有效入口/配置及结构核验记录，ds4 仅登记不新增玩法；另列 2 件配套饰品。结构完成不等于整轮或全部实机验收完成。第 16 批三件已有本轮指定场景原生补充；第 17/20 批三件已执行限定生命周期原生对照，双方 27/2 诊断相同但两项旧问题未关闭。本轮第 19/22 批完成结构与离线核验，原生和人工边界分别保留。

“职责已重构”说明模块归属已经落地，不等于所有实机场景均已验收。每件的实际自动/原生覆盖及限制以链接交付为准。多窗口同时工作时，只更新自己有证据的行，不按文件或 delivery.md 的存在自动升级状态。

## 已确认的第一至第十二批：42件

下面逐件列出入口及交付。共享能力、具体保留差异和状态所有权继续由[38件消费者清单](../../reports/refactor-shared/2026-11-26/consumer-inventory.md)及各批清单维护；这里不复制多份接口合同。后续修复没有扩大任何历史实机验收范围。

| 道具 | 当前独立入口 | 职责状态 | 批次证据 |
| --- | --- | --- | --- |
| 风油精 | [essential_balm.lua](../../scripts/features/essential_balm.lua) | 职责已重构 | [第 1 批](../../reports/refactor-batch1/2026-11-24/delivery.md) |
| 芜湖 | [wuhu.lua](../../scripts/features/wuhu.lua) | 职责已重构 | [第 1 批](../../reports/refactor-batch1/2026-11-24/delivery.md) |
| 八音盒 | [musicbox/init.lua](../../scripts/features/musicbox/init.lua) | 职责已重构 | [第 1 批](../../reports/refactor-batch1/2026-11-24/delivery.md) |
| 高蛋白肉条 | [protein_strip.lua](../../scripts/features/protein_strip.lua) | 职责已重构 | [第 1 批](../../reports/refactor-batch1/2026-11-24/delivery.md) |
| 活力狗饼干 | [energy_kibble.lua](../../scripts/features/energy_kibble.lua) | 职责已重构 | [第 1 批](../../reports/refactor-batch1/2026-11-24/delivery.md) |
| 轻盈低脂罐头 | [lean_can.lua](../../scripts/features/lean_can.lua) | 职责已重构 | [第 1 批](../../reports/refactor-batch1/2026-11-24/delivery.md) |
| DHA鱼油 | [dha_fish_oil.lua](../../scripts/features/dha_fish_oil.lua) | 职责已重构 | [第 1 批](../../reports/refactor-batch1/2026-11-24/delivery.md) |
| 护齿磨牙骨 | [dental_chew.lua](../../scripts/features/dental_chew.lua) | 职责已重构 | [第 1 批](../../reports/refactor-batch1/2026-11-24/delivery.md) |
| 幸运肝粒 | [lucky_liver_bites.lua](../../scripts/features/lucky_liver_bites.lua) | 职责已重构 | [第 1 批](../../reports/refactor-batch1/2026-11-24/delivery.md) |
| 羊奶布丁 | [goat_milk_pudding.lua](../../scripts/features/goat_milk_pudding.lua) | 职责已重构 | [第 1 批](../../reports/refactor-batch1/2026-11-24/delivery.md) |
| 春药 | [chunyao.lua](../../scripts/features/chunyao.lua) | 职责已重构 | [第 2 批](../../reports/refactor-batch2/2026-11-25/delivery.md) |
| 美工刀 | [utility_knife.lua](../../scripts/features/utility_knife.lua) | 职责已重构 | [第 2 批](../../reports/refactor-batch2/2026-11-25/delivery.md) |
| 虚空针尖 | [needletick.lua](../../scripts/features/needletick.lua) | 职责已重构 | [第 2 批](../../reports/refactor-batch2/2026-11-25/delivery.md) |
| 绝育证明 | [sterilization_certificate.lua](../../scripts/features/sterilization_certificate.lua) | 职责已重构 | [第 2 批](../../reports/refactor-batch2/2026-11-25/delivery.md) |
| 剪碎的塔罗 | [shredded_tarot.lua](../../scripts/features/shredded_tarot.lua) | 职责已重构 | [第 2 批](../../reports/refactor-batch2/2026-11-25/delivery.md) |
| 血颅蛊 | [blood_skull_gu.lua](../../scripts/features/blood_skull_gu.lua) | 职责已重构 | [第 2 批](../../reports/refactor-batch2/2026-11-25/delivery.md) |
| 未剪断的脐带 | [uncut_cord.lua](../../scripts/features/uncut_cord.lua) | 职责已重构 | [第 2 批](../../reports/refactor-batch2/2026-11-25/delivery.md) |
| 空摇篮 | [empty_cradle.lua](../../scripts/features/empty_cradle.lua) | 职责已重构 | [第 2 批](../../reports/refactor-batch2/2026-11-25/delivery.md) |
| 老大的指令 | [boss_order.lua](../../scripts/features/boss_order.lua) | 职责已重构 | [第 3 批](../../reports/refactor-batch3/2026-11-25/delivery.md) |
| 生死一念间 | [between_death_and_life.lua](../../scripts/features/between_death_and_life.lua) | 职责已重构 | [第 3 批](../../reports/refactor-batch3/2026-11-25/delivery.md) |
| 天使盒 | [boxes/angelbox.lua](../../scripts/features/boxes/angelbox.lua) | 职责已重构 | [第 3 批](../../reports/refactor-batch3/2026-11-25/delivery.md) |
| 恶魔盒 | [boxes/devilbox.lua](../../scripts/features/boxes/devilbox.lua) | 职责已重构 | [第 3 批](../../reports/refactor-batch3/2026-11-25/delivery.md) |
| 小皮鞋 | [little_leather_shoes/init.lua](../../scripts/features/little_leather_shoes/init.lua) | 职责已重构 | [第 4 批](../../reports/refactor-batch4/2026-11-25/delivery.md) |
| 流量开箱 | [traffic_unboxing.lua](../../scripts/features/traffic_unboxing.lua) | 职责已重构 | [第 4 批](../../reports/refactor-batch4/2026-11-25/delivery.md) |
| 流量曝光 | [traffic_exposure.lua](../../scripts/features/traffic_exposure.lua) | 职责已重构 | [第 4 批](../../reports/refactor-batch4/2026-11-25/delivery.md) |
| 流量热度 | [traffic_heat.lua](../../scripts/features/traffic_heat.lua) | 职责已重构 | [第 4 批](../../reports/refactor-batch4/2026-11-25/delivery.md) |
| 黑太岁 | [black_taisui.lua](../../scripts/features/black_taisui.lua) | 职责已重构 | [第 5 批](../../reports/refactor-batch5/2026-11-25/delivery.md) |
| 肉块 | [meat_lump.lua](../../scripts/features/meat_lump.lua) | 职责已重构 | [第 5 批](../../reports/refactor-batch5/2026-11-25/delivery.md) |
| 净化迷幻菇 | [cleansed_wavy_cap.lua](../../scripts/features/cleansed_wavy_cap.lua) | 职责已重构 | [第 5 批](../../reports/refactor-batch5/2026-11-25/delivery.md) |
| 铜钱剑 | [coin_sewn_sword.lua](../../scripts/features/coin_sewn_sword.lua) | 职责已重构 | [第 6 批](../../reports/refactor-batch6/2026-11-25/delivery.md) |
| 铜钱面具 | [coin_faced_mask.lua](../../scripts/features/coin_faced_mask.lua) | 职责已重构 | [第 6 批](../../reports/refactor-batch6/2026-11-25/delivery.md) |
| 强力泻药 | [strong_laxative.lua](../../scripts/features/strong_laxative.lua) | 职责已重构 | [第 7 批](../../reports/refactor-batch7/2026-11-25/delivery.md) |
| 通天塔 | [tower_of_babel.lua](../../scripts/features/tower_of_babel.lua) | 职责已重构 | [第 7 批](../../reports/refactor-batch7/2026-11-25/delivery.md) |
| 巴比伦好女孩 | [good_girl_of_babylon.lua](../../scripts/features/good_girl_of_babylon.lua) | 职责已重构 | [第 8 批](../../reports/refactor-batch8/2026-11-26/delivery.md) |
| 月色真美 | [the_moon_is_beautiful.lua](../../scripts/features/the_moon_is_beautiful.lua) | 职责已重构 | [第 8 批](../../reports/refactor-batch8/2026-11-26/delivery.md) |
| 避孕套 | [condom.lua](../../scripts/features/condom.lua) | 职责已重构 | [第 9 批](../../reports/refactor-batch9/2026-11-26/delivery.md) |
| 疯狂的椰子 | [crazy_coconut.lua](../../scripts/features/crazy_coconut.lua) | 职责已重构 | [第 9 批](../../reports/refactor-batch9/2026-11-26/delivery.md) |
| 鸿运齐天蛊 | [fortune_rivalling_heaven_gu.lua](../../scripts/features/fortune_rivalling_heaven_gu.lua) | 职责已重构 | [第 9 批](../../reports/refactor-batch9/2026-11-26/delivery.md) |
| 未生证明 | [certificate_of_neverbirth.lua](../../scripts/features/certificate_of_neverbirth.lua) | 职责已重构 | [第10批](../../reports/refactor-batch10/2026-11-26/delivery.md) |
| 再契象 | [house_vs_elephant.lua](../../scripts/features/house_vs_elephant.lua) | 职责已重构 | [第10批](../../reports/refactor-batch10/2026-11-26/delivery.md) |
| 焚尽郁结 | [burn_away_resentment.lua](../../scripts/features/burn_away_resentment.lua) | 职责已重构 | [第11批](../../reports/refactor-batch11/2026-11-26/delivery.md) |
| 千变万化 | [everchanging.lua](../../scripts/features/everchanging.lua) | 职责已重构 | [第12批](../../reports/refactor-batch12/2026-11-26/delivery.md) |

本轮相关收尾：[未生证明/再契象显式依赖](../../reports/refactor-fixes/2026-11-26-archive-dependencies/delivery.md)、[鸿运/虚空针尖依赖与泻药身体缓存](../../reports/refactor-fixes/2026-11-26-fortune-laxative/delivery.md)。本轮复核范围与新增风险来自[框架复核](../../reports/framework-review/2026-11-26-after-archive-wiring/review.md)；旧报告中的风险描述保留历史语境，修复状态看后续交付。

## 后续批次：按最终交付校正状态

下面只概括各批最终记录的实际范围；相应快照的原生通过不自动覆盖后续共享服务改动。完整逐件状态、依赖与未完成原因见全量清单。

| 批次 / 道具 | 本次读取报告中的状态 | 记录 |
| --- | --- | --- |
| 13：大狗叫、蓄风棒、回响碎片 | 已有交付和对照证据，覆盖范围以原报告为准 | [交付](../../reports/refactor-batch13/2026-11-26/delivery.md) |
| 14：诛、阿瓦达啃大瓜、柴刀 | 职责拆分、旧新行为与专项原生对照完成；人工/多人等边界保留 | [交付](../../reports/refactor-batch14/2026-11-26/delivery.md) |
| 15：阴的诅咒、七咒之戒、ACE | 职责拆分、共享核对与冻结旧新原生对照完成；整体和人工边界保留 | [交付](../../reports/refactor-batch15/2026-11-26/delivery.md) |
| 16：我即神明、神性过载、炸弹套装 | 结构完成；我即神明两侧 29/0 观察一致，神性过载/炸弹套装参与控制四场景候选 30/0；其余分支边界见逐件表 | [交付](../../reports/refactor-batch16/2026-11-26/delivery.md) |
| 17：复活吧，我的爱人！、健康睡眠 | 结构完成；v2 真实复活链路、床接管/取消/再取得每层锁已测，首帧交接及持续无碰撞已专项修复，见[生命周期缺陷修复](../../reports/lifecycle-fixes/2026-11-27/delivery.md)；睡眠长周期待测 | [交付](../../reports/refactor-batch17/2026-11-26/delivery.md) |
| 18：胆小鬼之夜、神风特攻队 | 报告记录职责拆分、旧新对照及专项原生验证完成 | [交付](../../reports/refactor-batch18/2026-11-26/delivery.md) |
| 19：神的左手，恶魔之右手、回声宝宝、凸眼鱼；零分考卷及选择器随组 | 结构核验、同合同复制复用与旧新离线检查完成；本批原生/人工未验收 | [交付](../../reports/refactor-batch19/2026-11-27/delivery.md) |
| 20：记忆紊乱 | 结构完成；v2 真实切换、身份/生命及主动槽恢复通过；同槽卡牌丢失已专项修复，见[生命周期缺陷修复](../../reports/lifecycle-fixes/2026-11-27/delivery.md)；特殊身体/伙伴等待测 | [交付](../../reports/refactor-batch20/2026-11-26/delivery.md) |
| 21：斗气拳套、360、720、波动、升龙 | 结构及原批原生已完成；本轮拳套参与三件 CanShoot 专项候选 30/0，其他输入/抓取/人工边界保留 | [交付](../../reports/refactor-batch21/2026-11-26/delivery.md) |
| 22：调试控制器 | 既有模块职责核验、生命周期/失败安装及旧新离线通过；本批没有生产代码改写，原生/人工待验收 | [交付](../../reports/refactor-batch22/2026-11-27/delivery.md) |

本轮已将[目标架构12.1](2026-11-24-neverbirth-target-architecture.md#121-全量道具迁移清单模板)的全量表补齐到 69 件道具和 2 件饰品，见[当前逐件清单](refactor-inventory.md)。公共机制另见[共享总表](shared-capability-status.md)。跨进程 Continue 保留[历史限定组合 39 条断言](../../reports/refactor-lifecycle/continue-native/delivery.md)，本轮 [continue-01](../../reports/framework-closure/2026-11-27/continue-01/result.json)两个独立进程 seed 9 + resume 34 = 43 通过/0 失败，追加逻辑/身体身份与 acquisition 账本恢复、不重放检查。

本轮[控制原生对照](../../reports/framework-closure/2026-11-27/control-native-comparison.json)为基线 28 通过/2 失败、package-03 候选 30 通过/0 失败；两条失败精确复现旧版提前释放错误解锁及最终恢复错误，不能把它们写成候选退化或基线通过。[我即神明对照](../../reports/framework-closure/2026-11-27/god-native-comparison.json)两侧各 29 通过/0 失败、2 场景且 PASS 观察一致。以上仅限指定普通玩家和场景，不替代多人、特殊身体、全沙漏及音画/操作手感。

[生命周期 v2 比较](../../reports/framework-closure/2026-11-27/lifecycle-native-comparison.json)两侧各 27 通过/2 失败；比较命令退出 0 表示诊断一致，`acceptancePassed=false`，并非验收成功。原始睡眠推进耗时 2.032/2.031 秒及运行期 bedSeed 不要求字面相等，原观察保留。[调查](../../reports/framework-closure/2026-11-27/native-17-20-baseline-investigation.md)区分了复活首帧控制/可见交接与持续 collision=4（未保持 NONE=0）；尚未实际验证受伤或攻击，不能推断整段复活可被伤害或可射击。记忆紊乱主动槽 34/充能 3 恢复通过，但 SetCard 后 SetPill(0) 清同槽导致原卡丢失，拆分前已有；两项原失败均未豁免。后续按用户修复请求完成[生命周期缺陷修复](../../reports/lifecycle-fixes/2026-11-27/delivery.md)，新增首帧/持续状态、实际伤害与注入移动/射击及双口袋原生验证；旧 v2 对照保留原样。健康睡眠真实床接管、取消和再取得每层锁通过，完整长周期尚未覆盖。

最终候选 [package-03](../../reports/framework-closure/2026-11-27/package-03/manifest.json)的[本地包检查](../../reports/framework-closure/2026-11-27/package-03-checks.json)、[RegistryGenerator 四个正反例](../../reports/framework-closure/2026-11-27/strict-package-generator.json)和[LuaAll final 181 通过/0 失败/0 警告](../../reports/framework-closure/2026-11-27/lua-all-final.json)均有记录。固定恢复场景已完成两组旧新性能对照，未超过预设退化门槛且扫描/保存次数一致，见[测量结果](../../reports/framework-closure/2026-11-27/performance-result.md)；更广场景性能仍待验收；第 17/20 批旧问题已按上述专项关闭；未覆盖分支及其他必要原生/人工证据按[统一交付](../../reports/framework-closure/2026-11-27/delivery.md)继续收尾，当前不标全部验收。
