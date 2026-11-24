# 阿瓦达啃大瓜：反重力漩涡、面板倍率与打空惩罚修复

## 当前结论

已完成本轮代码修复与本地验证，**待游戏核对**。用户本轮反馈：发出的是一段硫磺火，未呈现原版反重力硫磺火；希望面板攻击力本身乘 5；攻击打空后角色没有死亡。

本轮没有启动、控制或附加游戏进程；原生证据来自磁盘文件的只读分析。脚本测试不等同于原版视觉、真实输入、碰撞和复活顺序验收。

## 证据与根因

1. 本轮保存的游戏日志记录 `no native Brimstone Swirl after release; nativePassed=true`。日志快照见 [game-log.txt](game-log.txt)。它证明运行过旧的取消分支，不证明原生效果可用。
2. REPENTOGON 1.0.12a 的 `WeaponModifier.ANTI_GRAVITY` 用于武器控制；现有代码未提供原生激光生成漩涡所需的 `TearFlags.TEAR_WAIT`。
3. 本机 EXE 的 `Entity_Laser::Update` 位于 0x8d0aa0：0x8d0ad2 引用常量 0xbc4bd0，文件中是 128 位值 0x20000，即 bit 17 / TEAR_WAIT。成功分支在 0x8d0bed 选择 effect 71 / BRIMSTONE_SWIRL，然后调用原版生成逻辑。激光的泪弹标记由原版 FireBrimstone 从玩家 GetTearHitParams 复制。见 [native-tear-wait.txt](native-tear-wait.txt)。
4. 旧代码只在 beginCast 中计算 `player.Damage * 5`，所以面板未变化。
5. 旧代码只认 `rootSeen`，超过 1 帧未看到 swirl 就取消施法、删除已经生成的激光，并从待结算表移除。这样既可能把光束截断，也直接跳过未击杀惩罚。

匹配版本的接口来源：

- [EntityLaser.zhl](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/libzhl/functions/EntityLaser.zhl)：用于定位原版 Update 及 tearFlags 字段。
- [Weapon.zhl](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/libzhl/functions/Weapon.zhl)：原版 Weapon::FireBrimstone 签名。
- [CustomCallbacks.cpp](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/LuaInterfaces/CustomCallbacks.cpp)：MC_POST_FIRE_BRIMSTONE 挂在原版 Weapon::FireBrimstone 返回后，参数完成初始化后可确认攻击归属。

## 修改

- `CACHE_TEARFLAG` 为持有者添加 TEAR_WAIT，由原版激光更新生成反重力漩涡并处理其生命周期。没有手动生成替代球或自画光束。
- `CACHE_DAMAGE` 在本 Mod 常规属性回调之后乘 5，直接改变玩家 Damage。例如 3.5 → 17.5；属性重新求值从原生基础值开始，不会逐次叠乘。施法与激光读取面板值，不再额外乘 5。
- 三份道具 XML 添加 `cache="damage tearflag"`；首次运行状态建立时补做一次缓存刷新，移除时恢复相关缓存，没有每帧 EvaluateItems。
- 实际激光／漩涡生成后记录 outputSeen。等待漩涡期间不重复为同一施法强制充满；没有漩涡回执时也保留实际发出的攻击，等完整生命周期结束后按直接击杀结果结算。
- 保留“完全没有生成攻击时不制造失败死亡”的边界；打空的真实攻击已进入失败结算，设置本次复活拦截后只 Kill 施法者。
- 中英文描述同步为面板攻击力翻 5 倍。

## 验证结果

| 检查 | 结果 |
| --- | --- |
| 三个新增用户复现场景对修复前模块 | 全部失败：面板仍为 3.5、缺 TEAR_WAIT、实际激光被误删；见 red-test.txt |
| 同一套测试对修复后模块 | 全部通过；见 behavior-test.txt |
| 全部阿瓦达行为测试 | 通过；含原有直接击杀、状态伤害排除、合作隔离、复活拦截、输入取消及换房／移除恢复 |
| XML 注册与资源契约测试 | 通过；三种语言 cache 声明、local ID 57、品质 0、道具池及图标契约 |
| 本地化测试 | 通过；当前 main.lua 完整加载 |
| 湮灭行为测试 | 通过 |
| 复活吧我的爱行为测试 | 14 项通过 |
| 修改过的阿瓦达模块及行为测试 luac -p | 通过，Lua 5.4.6 |
| 通用静态检查 | 11 warning / 0 failure，见 validation-generic.txt |
| neverbrith 专用检查 | 571 warning / 0 failure，见 validation-neverbrith.txt；含快照与工作树的重复注册提示，不是 571 个新问题 |
| 本轮代码文件 git diff --check | 通过 |
| 游戏内验收 | 未执行，等待用户确认；不标为游戏核对通过 |

没有重跑全仓库行为测试。上一轮 folk_horror_items_behavior_test 的其他道具 XML 失败保留在历史报告，本轮没有据此宣称全仓通过。

## 游戏复测

1. 完整重启游戏加载 Lua 和 XML。基础攻击 3.5 时取得道具，应在面板看到 17.5；其他攻击加成刷新后仍只乘一次，移除道具恢复正常数值。
2. 有敌人的房间按同一射击方向约 1 秒，核对蓄力条与原版反重力硫磺火漩涡、随后光束的表现。此前无蓄力条尚无用户明确通过记录，本轮看到光束不能代替蓄力条验收。
3. 对着无敌人的方向发射、保留其他活敌人：等待本次漩涡和光束完全结束，施法者应死亡且该次不能复活；直接击杀至少一个敌人则存活。合作玩家不应被牵连。
4. 空房、提前松键、换方向、换房和移除道具，继续按既有规则取消；若仍异常，开启 avada_trace on 记录一次，再 avada_trace off，并提供 avada_status。

本目录 .before 保存本轮开始时的原始文件，final.patch 为本轮限定变更。
