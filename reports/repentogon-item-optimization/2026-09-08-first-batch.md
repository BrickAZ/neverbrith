# 2026-09-08 忏悔龙优化：第一批交付

> 后续修正：本报告是第一批当时的实现记录。七咒副手的 `Force=false` 在[第二批](2026-09-08-second-batch.md)改为true，避免特殊充能主动被拒绝，以及计时主动把+1解释成充满。容量仍由原生限制；下表旧参数及“不强制”不再代表当前代码。

## 状态与范围

本批完成代码接入及离线验证；**游戏内未验证，不代表全部道具优化完成**。
按当前项目普通 REPENTOGON 1.0.12a 合同实现，没有升级到“＋”，没有修改道具数值、道具池、XML、本地化、贴图或 ANM2。
保留工作区既有未提交改动；没有提交、推送或发布。

## 实际修改文件

生产：
- main.lua：血颅蛊来源查询、铜钱剑输入控制。
- ring_of_the_seven_curses.lua：副手原生充能。
- yins_curse.lua：黑蜡烛爆炸免疫回调提前。

测试：
- tests/blood_skull_gu_behavior_test.lua
- tests/folk_horror_items_behavior_test.lua
- tests/ring_of_the_seven_curses_behavior_test.lua
- tests/yins_curse_damage_order_test.lua（新增）
- tests/repentogon_test_fixture.lua（补 MC_PRE_PLAYER_TAKE_DMG 枚举）

记录：
- reports/repentogon-item-optimization/2026-09-08-first-batch.md（本文）
- reports/repentogon-item-optimization/progress.md

## 机制与边界

| 道具 | 本批改动 | 保留的玩法 / 限制 |
| --- | --- | --- |
| 血颅蛊 | 使用 familiar:GetItemConfig().ID；去掉猜测字段、静态 variant 对照、最多1000项配置扫描 | 仍只处理实际使用者的合格跟班，要求本人仍持有来源收藏品；nil、读取失败、未持有来源时跳过，不牺牲不明来源的跟班。原收益、黑心数量、空目标反噬均未改 |
| 七咒之戒 | AddActiveCharge(1, SLOT_SECONDARY, true, false, false)，以实际接受量是否 >0 返回成功 | 保留原两房间计数、owner、保留副主动身份与槽位检查；不强制、不超充；Q4留底座与补偿/cycle去重不改 |
| 阴的诅咒 | 黑蜡烛免疫改在 MC_PRE_PLAYER_TAKE_DMG 执行，不加错误 EntityType 筛选 | 仅全局诅咒已激活且实际受伤玩家当下持有黑蜡烛的爆炸返回 false；不复制 TakeDamage。宿主帽/纵火狂“禁防爆”仍未解决，不能称全覆盖 |
| 铜钱剑 | MC_PRE_PLAYER_UPDATE 读取原始射击方向并释放；MC_INPUT_ACTION 屏蔽举剑者射击；不再用 POST_FIRE_TEAR 删弹或为删弹扫描全房间 | 仍为使用主动→举剑→按方向发射；重复使用无方向取消。原剑气、伤害、花钱、充能与协同不改；不删除已存在的攻击；让位于阿瓦达 |

### 铜钱剑状态生命周期

- coinSwordHoldStates：每玩家 InitSeed 对应举剑状态与主动槽。
- Neverbirth.__coinSwordInputBlocks：释放帧的一次更新输入占用，持续到该玩家下次 PRE_PLAYER_UPDATE。
- Neverbirth.__coinSwordReadingInput：原始输入读取重入保护；读取失败也复位。
- 只有射击动作查询返回 0/false，移动和其他玩家输入不拦截。
- 换房、换层、新局/继续初始化、退出清理；玩家实体移除按 owner 清理。
- 玩家死亡、被移除、主动槽不再为铜钱剑或控制被禁用时，不释放剑气；无花钱/充能消耗。
- 不序列化上述临时状态，不缓存原生 Weapon 指针。

**输入拦截不等于清除原生已蓄力/连发/延迟发射状态。**
硫磺火、科技X、巧克力奶、妈刀“先蓄力后举剑”没有实机证据，既不能确认必然漏发，也不能宣称绝不漏发。
本批未擅自通过清空原生武器或全房删攻击来制造“兼容”。

## 版本证据

- [1.0.12a EntityFamiliar.GetItemConfig](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/docs/docs/EntityFamiliar.md)：返回实际授予跟班的 ItemConfig；非道具生成可为 nil。
- [1.0.12a EntityPlayer.AddActiveCharge](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/docs/docs/EntityPlayer.md)：5 参数及实际增加量返回。
- [同 tag 玩家 C++ 绑定](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/LuaInterfaces/Entities/LuaEntityPlayer.cpp)：378–389 原生充能绑定。
- [同 tag 回调文档](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/docs/docs/enums/ModCallbacks.md)：MC_PRE_PLAYER_TAKE_DMG=1008、MC_PRE_PLAYER_UPDATE=1160，筛选为 PlayerVariant。
- [同 tag C++ 回调入口](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/LuaInterfaces/CustomCallbacks.cpp)：玩家 PRE_UPDATE 在 native Update 之前；PRE_TAKE_DMG 的 false 在 native TakeDamage 之前取消。
- [原版 MC_INPUT_ACTION 合同](https://wofsauge.github.io/IsaacDocs/rep/enums/ModCallbacks.html#mc_input_action)：GET_ACTION_VALUE 返回数字，PRESSED/TRIGGERED 返回布尔；回调不进行游戏状态推进。

以上是版本源码证据，不是实机证明。

## TDD 与命令

工作目录：E:/Isaac - Repentance/mods/neverbrith
Lua/luac：C:/Users/Anton/AppData/Local/Programs/Lua/bin/
PowerShell：C:/Program Files (x86)/PowerShell/7/pwsh.exe

先加失败用例，再改生产：
- 血颅蛊：同 variant、同时持有两件来源时，旧实现移除 c8 而非原生返回的1201，RED→GREEN；nil/error/unowned不得回退猜测。
- 七咒之戒：动态最大充能高/低、0实际接受、缺API、房间原生调用共5组旧实现失败→全通过。
- 阴的诅咒：新注册/模拟原生护盾测试从3通过5失败→8通过0失败。
- 铜钱剑：举剑时 native input 期望0而旧实现为nil，RED→GREEN；释放时序、重入、owner、取消和生命周期测试通过。

实际执行（下列 lua 命令均使用上述绝对路径）：

~~~powershell
lua.exe tests/blood_skull_gu_behavior_test.lua
lua.exe tests/folk_horror_items_behavior_test.lua --coin-sword
lua.exe tests/ring_of_the_seven_curses_behavior_test.lua
lua.exe tests/yins_curse_behavior_test.lua
lua.exe tests/yins_curse_damage_order_test.lua
lua.exe tests/repentogon_bootstrap_test.lua
lua.exe tests/repentogon_damage_dispatch_test.lua
~~~

全部退出码0。前置测试14个重复加载用例通过；阴的诅咒伤害顺序8/8；既有Yin回归一并执行本地化测试通过。

8个本批Lua文件分别运行 luac.exe -p，全部退出码0。
git diff --check 全工作区退出码0；只有既有 LF→CRLF 提示，无 whitespace error。

~~~powershell
& 'C:/Users/Anton/.codex/skills/isaac-validators/scripts/validate-isaac-mod.ps1' -Root . -ModObjectName Neverbirth
& './docs/skills/isaac-neverbrith-validator-profile/scripts/validate-neverbrith.ps1' -Root .
~~~

- 通用：15警告，0失败。3条早餐原版资源引用本地未解析、11条启发式热路径警告、1条GetPlayer(0)所有者警告。
- 专用：确认57条收藏品；269警告，0失败。266条重复注册警告来自嵌套 .worktrees/worktrees 副本参与扫描，3条为早餐资源。未删除工作副本，未改资源来压警告。

### 已知旧测试问题

- 血颅蛊旧测试初次运行缺 include，已补与现有测试相同的“独立模块不在此测试执行”替身，再观察上述真实预期 RED。
- 民俗道具整套 tests/folk_horror_items_behavior_test.lua 在本批开始前即失败于 Cleansed Wavy Cap timed charge mode XML断言；结束后仍在相同断言失败。本批只修铜钱剑并提供 --coin-sword 组，**没有把整套测试说成通过**。
- 没有重跑或宣称全仓库所有旧行为套件全绿。

## 审查

按 requesting-code-review 技能进行独立只读审查：限定本批差异未发现可确认的新引入 Critical/Important 问题。
已接受并记录原生预蓄力武器未验证限制；重命名“删泪弹”旧测试名，补游戏开始/退出的铜钱剑清理测试。
审查通过仅属于代码层，不是联机或游戏验收。

## 实机验收清单：全部未验证

1. 血颅蛊：两件收藏品生成同 variant 跟班、双人不同来源、第三方未设原生来源的跟班；只移除正确来源且不重生。
2. 戒指：副手标准/动态最大充能道具、已充满、没有副手、两名玩家独立补电；HUD闪烁及原生接受量。
3. 阴的诅咒：黑蜡烛+神圣斗篷受到爆炸时保持护盾；失去黑蜡烛立刻不再取消；队友无黑蜡烛正常结算。
4. 铜钱剑：举剑等待、方向发射、重复主动取消、换房/死亡/换主动；没有原生泪弹跟着此次输入额外射出。
5. 铜钱剑：硫磺火/科技X/巧克力奶/妈刀先蓄力后举剑；尚未决定有问题时的武器级最小修复，先实测，不据假设改玩法。
6. 铜钱剑+阿瓦达与合作：仅正确使用者受影响，阿瓦达保持最高攻击优先级。

## 后续尚未迁移

有效伤害记账、脐带付债成功确认、真实食物/底座拾取来源等继续遵循 experiments.md：
MC_POST_ENTITY_TAKE_DMG 不能单独证明非零HP已经提交；POST_ADD_COLLECTIBLE不能单独证明实际底座拾取。
本批未把这些不确定的引擎时序替换成未经验证的简化逻辑。需要同版本实机逐事件证据后再接下一批。
