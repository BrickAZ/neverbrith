# 阿瓦达啃大瓜：蓄满松键与延迟击杀结算修复

日期：2026-09-17。状态：代码和本地验证已完成，待游戏核对。

## 本轮用户反馈与操作契约

1. 蓄力完成自动释放，玩家无法决定施放时间。改为按住射击蓄力 1 秒；蓄满后继续按住保持，松键才释放。蓄力途中和蓄满后均可调整方向，提前松键取消。
2. 施放以后无论是否击杀敌人都会死亡。只有本次施法没有直接击杀敌人时，才在原版漩涡与光束全部结束后判定失败。

上一轮的面板攻击力乘 5、TEAR_WAIT 原版反重力硫磺火路线继续保留。本轮没有再次叠乘攻击伤害。

## 证据与根因

### 释放条件

旧 `prePlayer` 在 charge 到 30 时立即创建施法记录并为原版武器置满蓄力，因此玩家继续按住也会触发发射。现将这一步移到满蓄力后的无射击输入帧；长按阶段持续保持原版武器未被武装，避免自行施法。

### 击杀漏记

旧代码只在伤害完成、光束碰撞完成回调内检查 `HitPoints <= 0`，没有在敌人后续实际死亡时补确认。

原版 `TakeDamage` 会把伤害加入缓冲队列，血量到后续更新才改变。于是「伤害回调已经执行」不等于「HitPoints 已减到零」。旧测试直接在伤害回调前设血量为零，掩盖了这个时序问题。参考 [Entity.TakeDamage](https://wofsauge.github.io/IsaacDocs/rep/Entity.html#takedamage) 与 [Entity.HasMortalDamage](https://wofsauge.github.io/IsaacDocs/rep/Entity.html#hasmortaldamage)。

同版本 [REPENTOGON 1.0.12a ASMCallbacks.cpp](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/Patches/ASMPatches/ASMCallbacks.cpp) 将 POST_ENTITY_TAKE_DMG 接到伤害缓冲写入附近。本机 EXE 的对应片段见 [native-damage-buffer.txt](native-damage-buffer.txt)：0x684fe6 加入伤害记录，0x684ff2/0x684ffd 累加并写入缓冲值，然后返回。这是磁盘文件的只读检查，没有操作运行中游戏进程。

本次备份 [game-log.txt](game-log.txt) 包含三次 `normal owner-only death`。日志没有每次命中的细节，不能单凭该日志还原玩家现场的全部击杀过程。

另将实体归属比较从 Lua 包装对象相等改为 `GetPtrHash + InitSeed`，避免同一引擎实体以不同 Lua 包装进入回调时漏掉匹配。该风险由测试替身复现；没有断言它一定发生在上述实测中。

## 实现

- 蓄力固定 30 个游戏更新帧；满蓄力保持，松键创建一次施法。换向保留进度；未满松键、失去控制、换房、失去道具等取消蓄力。
- 在伤害前记录是否已经受到致命伤、原血量与敌对资格。只在已接受伤害的 POST 回调内确认本次光束造成了新的致命状态。
- 用原版 `HasMortalDamage()` 识别已进入缓冲但尚未扣血的致命伤，记录目标与施法归属。
- 经 `MC_POST_ENTITY_KILL`、`MC_NPC_UPDATE`、实体移除或更新检查确认目标实际死亡，才将该次施法标为成功。
- 光束结束时若仍有致命伤待确认，暂停失败结算。缓冲被护盾或阶段机制抵消、目标没有死亡时清除收据；按 NPC 实际更新清理，不保留无限期的击杀归属。
- 只有本次施法的直接致命伤计数；队友补刀、早已受到致命伤的目标、毒伤、假伤和被取消的伤害不计数。
- 同步中英文说明。测试共用夹具补充实际原版回调 `MC_NPC_UPDATE = 0`。
- 对照安装版 `resources/scripts/enums.lua` 与 `enums_ex.lua` 核对本模块全部 29 个回调名称，见 [native-callbacks.txt](native-callbacks.txt)。不使用不存在的 `MC_POST_NPC_UPDATE`。

## 失败复现与通过结果

新增 7 组回归，见 [测试源码](../../../tests/avada_kedavra_behavior_test.lua)。旧模块在其中 4 组失败，修复后 7 组均通过。

| 新回归组 | 旧模块 | 修复后 |
| --- | --- | --- |
| 长按蓄满不自动施法、换向保留蓄力、松键只发一次 | 失败 | 通过 |
| 血量未更新的致命伤，光束先消失，之后才死亡；不同 Lua 包装 | 失败 | 通过 |
| 没有先收到 KILL 回调，NPC 更新确认实际死亡 | 失败 | 通过 |
| 非致命命中后队友补刀 | 通过 | 通过 |
| 目标此前已被其他伤害判定致命 | 通过 | 通过 |
| 取消伤害、致命缓冲被抵消后存活 | 通过 | 通过 |
| 光束实体直接作为伤害来源、排除毒伤 | 失败 | 通过 |

失败证据：[red-test.txt](red-test.txt)。最终执行输出：[tests.txt](tests.txt)。测试使用引擎对象替身，证明 Lua 调度与判定，不证明原版视觉或真实游戏回调时序全部通过。

| 检查 | 本轮结果 |
| --- | --- |
| 阿瓦达全部行为测试 | 通过，含 7 组新增及既有面板、原生输出、打空死亡、生命周期与合作等用例 |
| 本地化／真实 main.lua 入口加载 | 通过 |
| 湮灭回归 | 通过 |
| 复活吧我的爱回归 | 14 项通过 |
| REPENTOGON 启动 | 14 种情况及重复加载通过 |
| 实际注册的伤害顺序 | 12 项通过 |
| Lua 语法 | 本轮 5 个 Lua 文件通过 |
| 道具 XML／资源注册 | 通过，见 [registration.txt](registration.txt) |
| 通用静态验证 | 11 warning / 0 failure，见 [validation-generic.txt](validation-generic.txt) |
| neverbrith 专用静态验证 | 571 warning / 0 failure，见 [validation-specialized.txt](validation-specialized.txt)；包含资源及嵌套工作树／快照重复注册提示 |

没有宣称全仓库行为测试全部通过，也没有把脚本通过记为游戏通过。

## 改动与复测

本轮限定差异见 [final.patch](final.patch)。生产代码：[avada_kedavra.lua](../../../avada_kedavra.lua)；专项测试：[avada_kedavra_behavior_test.lua](../../../tests/avada_kedavra_behavior_test.lua)。

1. 完整退出并重开游戏加载新模块。有敌人时按住射击超过 1 秒：蓄满继续保持，不自动施放；调整方向后松键才施放。
2. 不到 1 秒就松键：取消，不生成攻击，不触发失败死亡。
3. 用一次施法直接击杀敌人，等漩涡和光束全部结束：施法者应存活。分别测试击杀最后一个敌人与仍有其他敌人存活。
4. 朝空方向施法并保留其他活敌人：攻击彻底结束后施法者死亡。队友击杀不应救下打空者。
5. 继续核对原版反重力漩涡、面板 3.5 → 17.5、蓄力条、合作隔离、换房／移除取消和本次失败复活拦截。多阶段 Boss 的真实死亡顺序仍需游戏核对。
6. 若仍出现击杀后误死，可在控制台执行 `avada_trace on` 后复现一次，再执行 `avada_trace off`。日志应能区分“已接受致命伤”和“已确认直接击杀”。

用户尚未确认本轮实机结果；复测表保持“已修复，待游戏核对”。
