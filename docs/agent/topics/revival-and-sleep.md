# 复活与健康睡眠

本页记录两件道具的源码归属和联动入口。当前装配见 [main.lua](../../../main.lua)，迁移合同见[第十七批计划](../../superpowers/plans/2026-11-26-seventeenth-batch-refactor.md)。

| 道具 | 入口和私有模块 | 状态与生命周期 |
| --- | --- | --- |
| 复活吧，我的爱人！ | [入口](../../../scripts/features/revive_my_love.lua)、[状态](../../../scripts/features/revive_my_love/state.lua)、[表现操作](../../../scripts/features/revive_my_love/presentation.lua)、[运行回调](../../../scripts/features/revive_my_love/runtime.lua) | `reviveMyLove.runSeed / triggeredByPlayer` 沿用字符串种子和 InitSeed 键。生前控制/可见/碰撞快照与动画实体只存在当前安装实例。房间/退出完成序列并恢复玩家；新局重置次数，继续保留次数。 |
| 健康睡眠 | [入口](../../../scripts/features/healthy_sleep.lua)、[状态](../../../scripts/features/healthy_sleep/state.lua)、[覆盖层表现](../../../scripts/features/healthy_sleep/presentation.lua)、[输入](../../../scripts/features/healthy_sleep/input.lua)、[床与结算](../../../scripts/features/healthy_sleep/runtime.lua)、[生命周期](../../../scripts/features/healthy_sleep/lifecycle.lua) | `healthySleep` 的 version/run/floor/bed/sleep 原结构保留。层级生成锁、睡眠进度与受益者保存；输入按住帧数、上次时间、覆盖层颜色只存在当前安装实例。继续恢复已有进度且不计退出时间；换房、失去全部持有者或受益者全死亡取消，原版床一次性标记保留。 |

旧根目录 [revive_my_love.lua](../../../revive_my_love.lua)、[healthy_sleep.lua](../../../healthy_sleep.lua) 保留工厂路径兼容，供主入口、历史探针与外部直接加载者使用，没有重复绑定。若未来退出这些旧路径，须先迁移所有实际消费者。本批私有模块由所属入口创建一次，不作为跨道具公共 API。

复活入口接收 `IsFailureDeath(player)` 点调用查询；主入口提供延迟读取 `Neverbirth.AvadaKedavra.IsFailureDeath` 的闭包，因此阿瓦达晚于复活安装仍有效，替换提供方后也不会保留旧闭包。旧工厂路径为未提供查询的既有调用者保留相同适配；它用代理读取原 context，不冻结后续 context 更新。原 `ReviveMyLoveTestAPI` 仅供测试观察，不作为生产依赖。

七咒的原生床碰撞拦截在睡眠之前安装。七咒否决原版睡眠后，不出现 `SLEEP` 覆盖层和床 `Target` 交接，因此健康睡眠不创建受益者或输入锁。非七咒玩家仍可使用床；妈妈床的例外仍归七咒模块管理。

两件共同复用已有存档服务与运行种子查询，健康睡眠还复用玩家枚举、运行文本服务。复活的严格原生玩家枚举不同于公共枚举的容错回退；复活的生命值设定不同于睡满后的补满红心加魂心；前者按逻辑更新计看门狗，后者按实际时间计睡眠，均保留私有政策。没有新建通用控制锁或第二份 SaveData 服务。

相关检查：[复活行为](../../../tests/revive_my_love_behavior_test.lua)、[睡眠行为](../../../tests/healthy_sleep_behavior_test.lua)、[安装及回滚](../../../tests/batch17_loading_test.lua)、[联动与清理](../../../tests/batch17_boundaries_test.lua)。自动化覆盖和原生/人工验收边界以[本批交付](../../../reports/refactor-batch17/2026-11-26/delivery.md)的实际执行记录为准。

复活动画期间由私有 `holdPresentation` 维持位置、速度、控制、可见和无碰撞；`MC_PRE_PLAYER_UPDATE` 维持并跳过玩家原生更新，`MC_POST_UPDATE` 补齐死亡结算覆写后的首帧交接。死亡路径可能不调用 `MC_POST_PLAYER_UPDATE`，不能仅依赖该回调补锁。看门狗仍只按 30 Hz 逻辑更新计时，结束/换房/退出仍恢复生前快照。回调顺序追踪、真实伤害与注入移动/射击、解除后的正向对照见[生命周期缺陷修复](../../../reports/lifecycle-fixes/2026-11-27/delivery.md)。
