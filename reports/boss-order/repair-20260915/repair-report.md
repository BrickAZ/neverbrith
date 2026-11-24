# 老大的指令修复记录

日期：2026-09-15。代码已修复，自动验证已通过；真实游戏中的身体联结、碰撞和击杀过程仍需重启后复测。

## 改动

- Larry Jr. 每次生成一只、五个节段；Chub 每次生成一只、三个节段。使用同位置连续原版 Spawn 的方式完成组装，Pin 保持一次原版生成。
- 多节 Boss 按本次召唤管理成员。头部/中段先死不会立即发牌，所有成员死亡后在更新回调中只结算三张牌。
- 支持同帧多节死亡、重复 kill/death 回调，以及先死的实体已经移除后其他身体才死亡；发牌使用保存的位置和种子，绝不把已移除实体或普通快照表传给原生 Spawn。
- 连续召唤避开已有同类身体；墙体、房间外或所有候选位置都不可用时，使用失败并保留充能。
- 生成途中失败或无法标记成员时，回收本次生成的实体；之前的召唤和房间已有敌人不受影响。
- 明确返回 `Discharge=false`、`Remove=false`、`ShowAnim=false` 处理失败。单纯返回 false 只影响动画，不能表达保留充能。
- 将小肉山改为 `ENTITY_GURDY_JR / 99`，同时校准 Duke/Loki 的数值回退及测试枚举。
- 切房清理待结算队列；每局独立标识阻止旧实体回调跨重开产生奖励。

## 文件和范围

- `main.lua`：本轮补丁仅修改“老大的指令”区块。
- `tests/boss_order_behavior_test.lua`：补全 include 和退出回调测试环境，校准枚举，新增 11 项针对性回归，合计 27 项。
- 本目录：修复前快照、失败测试证据、最终验证结果及补丁。
- 修复期间发现同一 main.lua 的“避孕套”部分存在并行变化，已保留。`workspace-changes-during-repair.diff` 是整个文件在此期间的变化，不能视为本轮补丁；`boss-order-change.diff` 才是本次 BossOrder 的独立差异。
- 没有修改 XML、道具描述、成功使用时的充能规则、怪物/精英怪奖励规则或原有召唤抽签概率。

## 生命周期

召唤组由成员的 `GetData()` 持有；待结算集合仅引用发生过死亡的组。没有待结算组时更新回调立即返回。
每次使用获得独立组，不按同类怪物编号收编房间敌人。Larry 自然断链后，原成员继续归属于同一次召唤。
成员被移除或变成其他实体，不被当成完整击杀。切房不把旧房奖励带到新房；若原生实体回到房间时仍保留 GetData，后续死亡可重新排队。
没有新增 SaveData 格式。跨退出续玩仍受原有实体 GetData 生命周期限制，本轮没有宣称实现存档级召唤奖励恢复。

## 验证

- 先运行新增测试，旧代码明确失败：Larry 预期五节，实际一节。
- 另外记录了失败充能返回值、两次召唤重叠、无合法坐标的失败测试，再逐项修复。
- 最终完整加载 `main.lua` 的 BossOrder 行为测试：27 项通过。
- `tests/localization_test.lua`：通过。
- `tests/repentogon_bootstrap_test.lua`：14 个场景通过。
- `luac -p main.lua` 与 `luac -p tests/boss_order_behavior_test.lua`：通过。
- `git diff --check -- main.lua tests/boss_order_behavior_test.lua`：通过。
- 通用静态校验和项目严格校验结果分别保存在 `generic-validation.txt`、`strict-validation.txt`。警告包括既有资源路径、高频加载和嵌套工作树重复扫描；未扩展修复范围。
- 结构/参数测试使用 Lua 5.4.6；模拟器不执行游戏原生 AI，不能证明画面、原生联结、碰撞或真实死亡动画已经正确。

最终各命令退出码见 `verification.json`。测试对 Vector 构造、原生实体 spawner 与已移除实体使用也做了边界断言。

## 加载与复测

修复时检测到游戏仍在运行，本轮未操作或重载当前游戏。完成其他道具测试后，完全退出并重新启动以加载最新代码。

1. 用“老大的指令”召唤 Larry/Chub，先不攻击，确认身体完整并且不会自行立即死亡。
2. 先打掉头或中段，确认剩余身体还在时不发牌；全部击败只发三张。
3. 一次击杀多个节段，确认不重复发牌。
4. 连续召唤两组，检查两组位置/身体和奖励相互独立。
5. 检查召唤池中的小肉山不再错误变成恶名假面。

原始故障日志仍保留在 `../20260915-225255-815/game-log.txt`，未覆盖。

## 技术依据

- 本机 `resources/ambush.xml` 第 300、309 行：Larry 的 chunks=5、Chub 的 chunks=3。count 与 chunks 分开处理，一次召唤没有扩大到原版 Boss Rush 的三只 Larry。
- [IsaacScript 的 spawnBoss 实现](https://github.com/IsaacScript/isaacscript/blob/main/packages/isaacscript-common/src/functions/bosses.ts)：同位置连续生成多节 Boss 的原版实体；查阅时源码快照保存在 `upstream-bosses.ts`。
- [MC_USE_ITEM 返回值契约](https://wofsauge.github.io/IsaacDocs/rep/enums/ModCallbacks.html#mc_use_item)：布尔值控制动画，表的 Discharge 字段控制充能消耗。

采用的技能：isaac-neverbrith-router、isaac-npc-boss-ai、isaac-neverbrith-dev、isaac-state-lifecycle、isaac-callback-contracts、isaac-testing-debugging、isaac-validators、isaac-neverbrith-validator-profile、systematic-debugging、test-driven-development、verification-before-completion。
