# 阴的诅咒：精确爆炸免疫封锁的接口调查

日期：2026-10-02。结论：**当前接口下未实现**。本次没有修改 `yins_curse.lua`。用户已确认只封锁爆炸免疫，不能整件禁用 Pyromaniac/Host Hat，不能用第二次 `TakeDamage` 冒充原生免疫失效；黑蜡烛只解除阴的诅咒封锁。

## 证据

本机最近日志为 REPENTOGON 1.0.12a。只读检查游戏 `isaac-ng.exe`，SHA256 为 `530B4D2ACCEF833B8DBF6F1A9F781FE1E051C1916CA5ACDB579DF05A34640627`。调查使用本机 `C:/msys64/ucrt64/bin/objdump.exe`，结合该版本官方特征签名定位 `Entity_Player::TakeDamage`，并未改写可执行文件。

| 本机地址/行为 | 意义 |
| --- | --- |
| TakeDamage `0x73c930`；HasCollectible `0x73af30` | 与 1.0.12a 签名匹配的函数入口 |
| `0x73ce4e` 查 Pyromaniac 223；`0x73ce6a/0x73ce78` 查火/爆炸标志；`0x73cf01 → 0x741614` | 爆炸免疫在标准伤害回调前返回 false |
| `0x73cf0b` 查 Host Hat 375；`0x73cfe7 → 0x741614` | 另一免爆来源同样提前返回 |
| Host Hat 另在 `0x73d2e8` 判断投射物阻挡 | 整件 BlockCollectible 会同时影响用户要求保留的能力 |
| 标准伤害回调补丁点 `0x73dba1` | 位于上面两个提前免伤分支之后，无法观察已被挡掉的爆炸伤害 |

官方 [1.0.12a CustomCallbacks.cpp](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/LuaInterfaces/CustomCallbacks.cpp#L487) 的 `MC_PRE_PLAYER_TAKE_DMG` 在原生函数前调用 Lua，但只解析 false 取消，随后将原 damage/flags/source/countdown 传入 `super`；不能指定“只跳过爆炸免疫分支”。标准伤害补丁可核对 [ASMCallbacks.cpp](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/Patches/ASMPatches/ASMCallbacks.cpp#L90)，回调返回处理可核对 [main_ex.lua](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/resources/scripts/main_ex.lua#L560)。本轮没有在该版本公开 Lua 玩家接口中发现按原因移除免疫的 setter。

## 所需后续能力

需要原生层在爆炸免疫判断处提供按玩家、按爆炸原因的精确旁路或等价 setter。应保留 Pyromaniac 的其他能力、Host Hat 投射物阻挡，以及黑蜡烛的解除语义，再验证与其余免爆来源的关系。该需求超出当前模组 Lua 和已安装 1.0.12a 的公开接口；不能以静态测试通过或替代机制将其标为完成。
