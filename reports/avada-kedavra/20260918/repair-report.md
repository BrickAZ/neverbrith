# 阿瓦达啃大瓜：原版蓄力接管，2026-09-18

## 结果与用户确认

用户指出上一版蓄力仍显得是自写实现，并明确选择：**保留固定 1 秒，只采用原版操作和反馈**。

本轮已移除 Lua 蓄力计时器、自绘蓄力条、方向量化和手动触发武器。普通蓄力、满蓄力保持、满蓄力反馈、换向与松键释放由实际原版硫磺火武器处理；Lua 只固定原版蓄力所用参数，并在原生释放前登记本次攻击归属。

**状态：代码与本地检查通过，待游戏核对。** 未进行修复后的实机操作／渲染验证，既有击杀修复也没有用户通过确认。

## 原因和实现

上一版每次更新都把原生蓄力清零，由自己的 `s.charge` 递增至 30；释放时再手动 `SetCharge`、`SetFireDelay`。Lua 还重采样和量化射击输入，自己渲染 `gfx/chargebar.anm2`。这些路径让原版武器无法持续拥有真实蓄力状态。

现在的执行链：

1. 在属性缓存 `CACHE_FIREDELAY` 中固定 `player.MaxFireDelay = 30`。原版玩家更新将这个值写入武器最大射击间隔；标准硫磺火以其作为蓄力阈值，进度由原版每个逻辑更新累积。三份 items XML 的该道具均增加 `firedelay` 缓存声明。
2. 普通战斗中 `MC_INPUT_ACTION` 返回 nil，保留引擎自己的键盘／手柄输入。Lua 不再设置每帧蓄力值，不强迫射击冷却，也不合成按键触发状态。
3. 原版硫磺火执行蓄力和反馈。模块不再创建蓄力条 Sprite，也不注册玩家渲染回调。原版条遵循 `ChargeBars`；只读检查本机当前值为 1，没有更改 options.ini。
4. 安装版 `MC_POST_WEAPON_FIRE` 位于基类 Fire 返回后、派生硫磺火真正创建攻击之前。模块观察“满蓄力且已松键”的原生状态，在原版攻击生成前建好归属记录；不写入进度或冷却。
5. 只有明确取消时才清零武器蓄力，例如换房、失去道具、死亡或不允许攻击。失去道具会刷新武器与属性缓存，恢复当前其他道具决定的自然射速。
6. 诊断读取原生 `GetCharge()`；它可以带小数，`avada_status` 已从整数格式改为两位小数，避免控制台报错。

面板攻击力 ×5、原生 TEAR_WAIT 反重力漩涡、攻击归属、已接受致命伤后确认真实死亡的逻辑保持。此次没有更改 main.lua、本地化文案、图像或音频。

### 固定时长的实际含义

持有道具时固定原版射击间隔参数，所以普通射速属性增减不会改变 1 秒蓄力；面板射速也会反映该固定参数。移除时恢复当前自然射速。固定时间按正常游戏逻辑更新计量，暂停或游戏变速不作为真实墙钟 1 秒保证。特殊武器协同、多阶段 Boss 与其他 Mod 叠加需单独实测。

## 安装版本和原版证据

按本机 REPENTOGON **1.0.12a** 的接口核对；没有使用该版本缺失的 Lua `Weapon:GetMaxCharge()`，也没有通过脚本修改游戏进程内存。下列地址来自只读磁盘 `isaac-ng.exe` 的静态反汇编。

- [EntityPlayer.zhl（1.0.12a）](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/libzhl/functions/EntityPlayer.zhl)：`_maxfiredelay` 位于玩家偏移 0x13a8；武器槽从 0x1328 起。
- [Weapon.zhl（1.0.12a）](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/libzhl/functions/Weapon.zhl)：武器最大间隔位于 +0x10，当前蓄力位于 +0x14。
- [LuaWeapon.cpp（1.0.12a）](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/LuaInterfaces/LuaWeapon.cpp)：确认可调用的 GetCharge、GetMaxFireDelay 等接口。没有假设未提供的 SetMaxFireDelay 接口。
- [CustomCallbacks.cpp（1.0.12a）](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/LuaInterfaces/CustomCallbacks.cpp)：核对 Weapon Fire 回调位置。
- 本机 0x745909 → 0x74590f：读取玩家 +0x13a8 并写入武器 +0x10。
- 本机 0x9504c0 的标准硫磺火最大蓄力分支读取武器 +0x10；0x94f311 至 0x94f31b 由原版累积进度；0x94f304／0x94f377 分别进入蓄力／蓄满 ItemAnim；0x943970 的原版蓄力条读取武器实际进度和最大蓄力。

复核摘录：[native-charge-contract.txt](native-charge-contract.txt)。历史探索摘录不作为结论依据；这里使用已核对字段和指令边界的摘录。完整本机参数复制片段另见 [native-player-delay-copy.txt](native-player-delay-copy.txt)。

## 验证

| 检查 | 结果 |
| --- | --- |
| 新增 4 组原生蓄力回归在旧实现运行 | 4 组均失败；既有保持组在新的原生边界模型下也失败，见 [red-test.txt](red-test.txt) |
| 小数蓄力诊断用例修复前 | 复现 `number has no integer representation`，见 [diagnostic-red-test.txt](diagnostic-red-test.txt) |
| 最终阿瓦达行为测试与 2 个 Lua 文件语法 | 通过，包含新增 4 组与原有蓄力、输入、联机隔离、延迟击杀、无输出、打空、面板和生命周期场景，见 [final-target-tests.txt](final-target-tests.txt) |
| 本地化、湮灭、复活吧我的爱、REPENTOGON 实际注册伤害顺序 | 全部通过；后两项分别 14 和 12 个情况，见 [tests.txt](tests.txt) |
| XML／道具资源注册 | 通过；三份 XML 均声明 damage firedelay tearflag，见 [registration.txt](registration.txt) |
| 安装版回调及源码检查 | 28 个回调均存在；无自绘条、输入重采样、逐帧自写计时和 SetFireDelay，仅取消路径写 SetCharge，见 [native-contract-check.txt](native-contract-check.txt) |
| 通用静态验证 | 11 warning / 0 failure，见 [validation-generic.txt](validation-generic.txt) |
| neverbrith 专用静态验证 | 571 warning / 0 failure，扫描含备份和嵌套工作树，见 [validation-specialized.txt](validation-specialized.txt) |
| 限定补丁及空白检查 | 见 [diff-check.txt](diff-check.txt) |

测试的原生边界替身独立推进武器蓄力，并核对生产模块没有写入；它覆盖代码职责和回调编排，不能证明原版实际动画、声音、输入手感或真实碰撞。静态扫描 warning 不能全部归因于本次修改，也未宣称全仓库行为测试全部通过。game-log.txt 是修改前快照，不是本次运行成功证据。

## 游戏复测

1. 完整退出并重启游戏以加载 XML；有敌人时按住射击，观察原版条和满蓄力反馈。约 1 秒蓄满后持续按住，不自动施放；换向继续保持，松键只释放一次；提前松键取消。
2. 分别取得普通射速提升和降低后再次验证 1 秒；移除该道具后验证自然射速恢复。手柄需补测斜向、轻推和释放。
3. 直接击杀敌人后等攻击完全结束应存活；有活敌人时朝空方向施法应在攻击全部结束后死亡。继续核对最后一个敌人与多敌人场景、反重力漩涡、面板 ×5 和合作隔离。
4. 异常时可用 avada_status 读取真实进度，或 avada_trace on 记录一次释放和击杀归属，复现后关闭。实机通过只依据用户明确确认。

## 文件范围

生产模块、该道具三份 XML 缓存声明、两份专项测试，以及 [复测清单](../../item-retest-tracker.md)。本次局部差异见 [final.patch](final.patch)；它以本轮开始前状态为基准，排除仓库已有其他道具改动。

默认沙箱执行和 apply_patch 的 ACL 初始化失败，因此使用已校验的精确补丁，经 git apply --check 后应用；没有删除或覆盖其他任务文件。
