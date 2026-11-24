# 阴的诅咒：黑蜡烛规则修正与接口核查

日期：2026-09-16。

## 结果

**完整需求尚未实现。** 已修正“黑蜡烛直接赋予爆炸免疫”的错误；无黑蜡烛时封锁所有爆炸免疫的功能仍缺失。拾取激活、首个品质 4 道具结算和续局修复继续保留。

用户确认的规则没有待选择项：黑蜡烛只解除封锁，仍需原有防爆来源；没有黑蜡烛时只取消角色的爆炸免疫，相关道具的其他功能必须保留。

| 阴的诅咒已激活时 | 目标行为 | 当前实现 |
| --- | --- | --- |
| 无黑蜡烛，无防爆来源 | 正常处理爆炸伤害 | 模块不额外取消伤害 |
| 无黑蜡烛，有防爆来源 | 封锁爆炸免疫，保留该来源的其他功能 | **未实现：原有防爆仍会生效** |
| 有黑蜡烛，无防爆来源 | 正常处理爆炸伤害 | 已删除黑蜡烛额外免爆逻辑 |
| 有黑蜡烛，有防爆来源 | 由原来源正常处理爆炸免疫和其他功能 | 模块不再提前取消伤害，交回原流程 |

表内“正常处理”包含原有护盾等规则，并不意味着每次命中都必定扣血。脚本验证不替代游戏内原生效果验证。

## 已确认的代码原因与修改

旧 `decideExplosionDamage` 在诅咒激活、伤害含 `DAMAGE_EXPLOSION` 且受伤玩家持有黑蜡烛时返回 `false`。它挂在 `MC_PRE_PLAYER_TAKE_DMG`，所以只有黑蜡烛也能直接免爆，并提前截断原来的爆炸处理。无黑蜡烛分支只返回 `nil`，从来没有封锁原有防爆。

本轮删除该函数、对应伤害回调、爆炸标记常量和无用测试接口。没有把函数改成一个空实现后声称封锁已完成。中英文 EID 与本地化断言已同步纠正，游戏说明明确当前已有防爆仍会生效。

首个品质 4 的分支仍按第一次真实获得阴的诅咒时是否持有黑蜡烛锁定，后续获得黑蜡烛不会改写它；永久诅咒存档结构保持原样。

## 接口调查与证据

本机安装脚本 `E:/Isaac - Repentance/resources/scripts/main_ex.lua` 标识 REPENTOGON `1.0.12a`。调查包括该版本的官方回调文档、原生桥接源码、玩家接口及本机 Lua 伤害分派函数；另核对了 `1.1.2g` 的相关文档。

1. **提前受伤回调不能强迫原生防爆失效。** `MC_PRE_PLAYER_TAKE_DMG` 对应的 C++ `Entity_Player::TakeDamage` hook 只识别布尔 `false` 来终止调用；否则将原参数交给原生处理。返回 `true` 或伤害修改表都不能在这里改写原生免疫判断。[1.0.12a 原生桥接源码](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/LuaInterfaces/CustomCallbacks.cpp)
2. **普通伤害回调的修改表不等于免疫控制点。** 安装版 `_RunEntityTakeDmgCallback` 能组合伤害数值、标记和冷却修改，`false` 则取消整个分派；它不提供“此次取消仅由爆炸免疫造成”的原因，也不保证原生免疫挡下的命中会交给普通回调。[1.0.12a Lua 分派源码](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/resources/scripts/main_ex.lua)
3. **`BlockCollectible` 会影响整件道具。** 官方实现让被屏蔽道具的普通 `HasCollectible` 返回假、`GetCollectibleNum` 返回零，不能只关掉防爆。用它处理宿主帽／纵火狂无法保证保留其他功能。[1.0.12a 玩家接口源码](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/LuaInterfaces/Entities/LuaEntityPlayer.cpp)
4. **新版的爆炸回调也不是每位受害者的免疫开关。** `1.1.2g` 文档中的 `MC_PRE_BOMB_DAMAGE` 能修改或取消整次爆炸，按来源类型过滤，不按受伤玩家提供选择性免疫控制。它不能直接解决多人各自按黑蜡烛决定免疫的规则；本轮没有升级游戏。[1.1.2g 回调文档](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.1.2g/docs/docs/enums/ModCallbacks.md#mc_pre_bomb_damage)

**调查结论：尚未找到满足完整规则的公开 Lua 控制点。** 这不证明引擎内部不存在共同判断，而是目前公开的接口没有提供已验证的接入方式。移除爆炸标记后补发伤害、穿透所有无敌或屏蔽整件道具，都会改变用户要求保留的其他处理，不能作为完成依据。

下一步技术工作是寻找或补充原生爆炸免疫判断的专用接口，并证明其只影响免疫分支；第三方以自己的回调取消爆炸时，还需能区分取消原因的兼容约定。没有将这一技术缺口转成用户需重新选择规则的问题。

## 本轮验证

运行器：`C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`、同目录 `luac.exe`，Lua 5.4.6。

| 检查 | 结果 |
| --- | --- |
| 更新后的 `tests/yins_curse_damage_order_test.lua`，修改生产代码前 | **2 通过／8 失败**；旧回调错误返回 `false` 被捕捉 |
| 同一测试，修改生产代码后 | **10 通过／0 失败** |
| `tests/yins_curse_repentogon_test.lua` | **13 通过／0 失败** |
| `tests/yins_curse_behavior_test.lua` | 通过，包含整个 `main.lua` 加载和本地化断言 |
| `tests/repentogon_damage_dispatch_test.lua` | 通过，使用本机安装版的实际 Lua 分派函数 |
| `luac -p` | `main.lua`、`yins_curse.lua`、以上三个阴的诅咒测试及 `tests/localization_test.lua` 均通过 |
| 相关已跟踪文件 `git diff --check` | 通过，仅提示 Git 换行转换策略 |
| 通用静态验证 | **11 warning / 0 failure**；早餐资源引用 3 条、其他高频资源加载 7 条、首位玩家归属提示 1 条 |
| 修改后游戏内测试 | **未执行；无用户通过确认** |

新的 10 项伤害回归加载真实模块，以简化原生防爆／护盾对象验证：黑蜡烛单独不取消伤害、不保住本应消耗的护盾；有防爆来源时原有处理仍可到达；移除来源后黑蜡烛不保留免疫；合作、普通伤害及运行时重置不会产生额外免疫。模拟中的来源效果计数不证明纵火狂治疗等具体原生功能已经实测。

通用静态验证命令：`powershell -ExecutionPolicy Bypass -File C:/Users/Anton/.codex/skills/isaac-validators/scripts/validate-isaac-mod.ps1 -Root . -ModObjectName Neverbirth`。警告均不指向本次删除的伤害逻辑。

**这些通过项不覆盖缺失的“无黑蜡烛封锁防爆”功能。** 旧 8 项直接免爆测试已按用户确认作废，不再作为当前行为依据。待完整机制落地后，必须补上无黑蜡烛＋各防爆来源的有效回归及游戏验证。

同步记录：[道具复测表](../item-retest-tracker.md)。
