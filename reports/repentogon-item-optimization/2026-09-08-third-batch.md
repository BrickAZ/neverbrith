# 2026-09-08 忏悔龙优化：第三批伤害记账

## 结论：P3 部分完成，未完成项没有包装为通过

已修正 ACE 的“后续 PRE 取消 / 最终改零的请求也成为伤害候选”问题。空摇篮和黑太岁没有切换生产时序；ACE 多条已接受伤害队列的独立实际扣血归属也仍未解决。**真实游戏内验收全部未验证。**

目标保持普通 REPENTOGON 1.0.12a，不升级到＋。没有修改玩法数值、伤害倍数、惩罚、道具池、资源或角色注册。没有调用第二次 TakeDamage，没有增加忙等或性能负载；ACE既有惩罚实现不在本批修改范围。没有操作游戏、读写运行进程内存或修改游戏程序。保留脏工作区，无提交、推送、发布。

## 本批实际文件

- `main.lua`：ACE 的 `npcDamage` 增加时序/剩余限制注释；唯一 NPC 观察注册从 `MC_ENTITY_TAKE_DMG` 移为 `MC_POST_ENTITY_TAKE_DMG`，优先级 `IMPORTANT`。
- `tests/damage_acceptance_test.lua`：真实注册记录＋当前安装版 Lua PRE dispatcher；12条默认验收、3条玩家已知反例、1条队列已知反例。
- `tests/repentogon_test_fixture.lua`：补同版本 `MC_POST_ENTITY_TAKE_DMG = 1006`、`MC_POST_NPC_DEATH = 29`、`MC_POST_ENTITY_KILL = 68` 枚举。
- `tests/empty_cradle_behavior_test.lua`：补独立模块的 no-op include，恢复原有 main.lua 单元测试基线，不改变生产。
- 本报告、`progress.md`、`damage-timing-audit.md`。

## ACE 改了什么，没改什么

原先候选在 PRE 创建。若随后另一个处理器取消这一击，候选仍存在；同帧下一击真正扣血时，旧候选也借同一次HP下降被确认，于是一次命中记成两次。PRE把最终伤害改成0也有相同问题。

现在只在原生NPC POST处创建最终正数候选，因此上述取消/零量请求不会入列。`IMPORTANT` 仅表示尽早观察POST，并不是承诺早于所有第三方同优先级处理器。

保持不变：

- 每敌人的监视、命中数、死亡去重、每房第三次一击击杀惩罚。
- 玩家受到伤害同次翻倍；没有补一次伤害。
- Boss、小Boss及原有目标排除，召唤/分裂监视、合作全局一次观察。
- 旧的HP/死亡观察与换房、新局、移除持有后的状态清理。
- 不新增NPC `DAMAGE_FAKE`过滤，不用`HasMortalDamage`作为POST候选排除条件。

**仍有缺口：两个POST候选不代表两个实际已扣血事件。** 现有后续HP观察无法为每条已接受队列记录提供独立证明。本次没有用FIFO分配、均分HP差或“见POST就+1”改写命中定义。

## 为什么不能直接把三个道具全部改成 POST

核查官方同版本源码并只读检查本机磁盘程序，NPC与玩家的时序不同：

| 对象 | 1.0.12a POST所在位置 | 可证明 / 不可证明 |
| --- | --- | --- |
| NPC | 伤害记录压入队列并累计pending damage之后；实际HP尚未在此扣除 | 能排除后续PRE取消；不能证明队列中每条记录后来都实际扣血 |
| 玩家 | 原生扣心路径之后，按原生返回成功标志进入POST | POST参数来自可变的剩余伤害变量，经常可能为0；前后心数净差也不等于期间实际扣除量 |

玩家同一次流程可包含护盾、心资源转换、回血、复活或嵌套伤害。仅“PRE存心数，POST相减”会混淆净变化与真实承伤，且取消的内层请求也会扰乱简单栈配对。这里缺的是逐事件提交证据，不是让用户重新选择玩法。

### 同版本可复核来源（不是游戏内证明）

- [官方1.0.12a ASMCallbacks.cpp](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/Patches/ASMPatches/ASMCallbacks.cpp)：`ProcessPostDamageCallback` 与 `InjectPostDamageCallback`，玩家剩余量来自 `[ebp-0x100]`，NPC来自参数槽，玩家按成功标志调用，特殊白火路径排除。
- [官方1.0.12a Entity.zhl](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/libzhl/functions/Entity.zhl)、[EntityPlayer.zhl](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/libzhl/functions/EntityPlayer.zhl)：TakeDamage / AddHearts函数匹配契约。
- [DamageFlag文档](https://wofsauge.github.io/IsaacDocs/rep/enums/DamageFlag.html)：DAMAGE_FAKE描述针对玩家效果，不能据此假设NPC正数伤害也被原生清零。

本机 `E:/Isaac - Repentance/isaac-ng.exe`，SHA256：`530B4D2ACCEF833B8DBF6F1A9F781FE1E051C1916CA5ACDB579DF05A34640627`。独立只读核查定位：

- NPC `Entity::TakeDamage`：VA `0x684bb0–0x685008`。`0x684fe6`压入队列，`0x684ffd`写累计量，是POST注入附近；此时未扣HP。
- 后续消费：`0x686da7`检查不可受伤状态，`0x686db3`开始遍历，`0x686dd0`附近跳过非正记录，`0x686e81–0x686e93`扣HP。部分特殊AI路径可清理队列。因此POST接受不等于逐条已提交。
- `HasMortalDamage`附近 `0x685010`比较pending damage和HP；致死队列在POST时已经可为true，不能以此拒绝候选。
- 玩家 `TakeDamage`：`0x73c930`起，`0x74063e`调用AddHearts，POST在`0x741616`附近；fake路径`0x73d8f6`附近清零剩余伤害。NPC上述TakeDamage/消费路径未使用同样的fake清零门槛。

只读检查命令模式：

```powershell
Get-FileHash 'E:/Isaac - Repentance/isaac-ng.exe' -Algorithm SHA256
& 'C:/msys64/ucrt64/bin/objdump.exe' -d -M intel --start-address=0x684bb0 --stop-address=0x685030 'E:/Isaac - Repentance/isaac-ng.exe'
& 'C:/msys64/ucrt64/bin/objdump.exe' -d -M intel --start-address=0x686d80 --stop-address=0x687040 'E:/Isaac - Repentance/isaac-ng.exe'
```

## 测试结果

先写测试再改生产：新ACE组旧代码4失败/6通过（取消借用、零量借用、错误PRE注册、最终负量候选）；仅迁POST后10/10通过。审查后额外固化两种死亡通知顺序，最终12/12通过。空摇篮旧测试本来因缺include报错；仅补fixture后原奖励回归通过。

项目根执行，Lua工具目录为 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/`：

```powershell
lua.exe tests/damage_acceptance_test.lua
lua.exe tests/ace_anti_cheat_behavior_test.lua
lua.exe tests/empty_cradle_behavior_test.lua
lua.exe tests/repentogon_damage_order_test.lua
lua.exe tests/repentogon_damage_dispatch_test.lua
lua.exe tests/repentogon_bootstrap_test.lua
lua.exe tests/musicbox_behavior_test.lua
lua.exe tests/angelbox_behavior_test.lua
lua.exe tests/localization_test.lua
lua.exe tests/ring_of_the_seven_curses_behavior_test.lua
lua.exe tests/annihilation_behavior_test.lua
lua.exe tests/yins_curse_damage_order_test.lua
```

12个常规入口均exit0。新12例包含取消＋正常同帧、最终改零/负值、唯一无filter的POST注册、两个明确提交的fixture事件、首次监视致死队列、NPC fake标记、Boss排除、实体隔离及换房清理。其中一例仅证明POST回调本身不直接记账、非致死且HP未变的模拟不记账；旧settlement仍有IsDead/HasMortalDamage接受分支，不能扩大为所有未提交场景。旧ACE测试覆盖惩罚状态机；新测试通过真实捕获的注册分别执行NPC_DEATH→ENTITY_KILL和相反顺序，验证候选清空、命中与死亡计数都只有一次。

**这些使用实际注册与安装版Lua dispatcher，但NPC队列/HP是显式测试替身，不是原生战斗。**

明确保留的失败命令：

```powershell
lua.exe tests/damage_acceptance_test.lua --strict-player
lua.exe tests/damage_acceptance_test.lua --strict-queue
```

- strict-player：exit1，3/3失败。取消的第一次伤害仍消耗空摇篮本层资格；取消的第二次仍降级奖励；黑太岁取消红心伤害仍增加2点寄生值。这三个生产问题本批未修复。
- strict-queue：exit1，1/1失败。模拟两个已接受记录只提交一个，ACE仍把1次记成2次。这是保留的观察歧义反例；不宣称本脚本实际运行了原生特殊AI队列。
- 既有民俗整套 `folk_horror_items_behavior_test.lua` 仍在旧Cleansed Wavy Cap XML预期处失败；本批基线核对时已见，未改无关XML凑通过。

四个Lua文件（main.lua、新测试、通用fixture、空摇篮测试）`luac.exe -p`均exit0。

```powershell
& 'C:/Users/Anton/.codex/skills/isaac-validators/scripts/validate-isaac-mod.ps1' -Root . -ModObjectName Neverbirth
& './docs/skills/isaac-neverbrith-validator-profile/scripts/validate-neverbrith.ps1' -Root .
git diff --check
```

两套静态验证：通用15 warning/0 failure；专用269 warning/0 failure。警告与上一批相同，含原版早餐路径、启发式热路径、owner提示和嵌套工作副本重复扫描。没有删工作副本或改资源压警告。

`git diff --check`通过，只有既有LF→CRLF提示。另对新测试/新报告运行`git diff --no-index --check -- NUL <文件>`，无whitespace错误；no-index因文件有差异返回1，不把它错误报告为exit0。独立只读审查确认本轮局部生产改动无新增严重问题；审查中提出的测试和措辞意见已纳入。

最终复查仍使用仓库现有`core.autocrlf=true`：标准`git diff --check`返回0，42条LF→CRLF提示，无其他输出。曾尝试仅对一个检查命令临时传入`-c core.autocrlf=false`，造成大量既有CRLF被当作尾随空白、返回2；没有修改仓库Git配置或批量改换行。该非默认检查不作为本批合规结论，随后已按原配置重跑确认。

## 后续验证门槛

游戏内全部**未验证**，不能把这批12条Lua通过说成真实伤害系统已验收。

1. ACE：同帧取消＋真实命中、最终0＋真实命中，观察只记真实候选；单次致死仍结算一次。另验证合作激活/移除和过门清理，不改房内第三次一击击杀规则。
2. 只读诊断需要同时记录PRE/POST、玩家各类心数、NPC候选与下一次更新。必须覆盖同一次先扣心后回血、取消内层/成功外层、魂/骨/黑心转换和真实同帧多次伤害。
3. 下一步须证明实际提交的事件归属，或者找到同版本可用的更下层可靠接口。不能以POST次数、总净掉血、FIFO或均分代替锁定的“有效非零伤害”定义。

本次未接入自动游戏探针，也未向玩家制造额外伤害。玩家反例和NPC复杂队列归属在解决前，P3保持部分完成。
