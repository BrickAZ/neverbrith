# 2026-09-08 忏悔龙优化：第二批交付

## 结论与边界

本批完成八音盒、天使盒、恶魔盒的代码优化，并修正七咒副手和诛的原生充能参数遗漏。针对性 Lua 测试、语法、两套验证器及独立代码复审通过。**真实游戏内未验证，整个优化计划尚未全部完成。**

当前目标仍是普通 REPENTOGON 1.0.12a；没有升级到＋，没有改道具数值、XML、道具池、语言、贴图或 ANM2。未启动/操控游戏，未接触运行进程内存。保留现有未提交改动，没有提交、推送或发布。

## 实际修改文件

生产：

- `main.lua`：八音盒伤害时序；天使盒和恶魔盒原生充能事务。
- `ring_of_the_seven_curses.lua`：副手精确加一格的 Force 参数修正。
- `annihilation.lua`：车载电池每命中主/副手各加一格的 Force 参数修正。

测试：

- `tests/angelbox_behavior_test.lua`
- `tests/musicbox_behavior_test.lua`
- `tests/ring_of_the_seven_curses_behavior_test.lua`
- `tests/annihilation_behavior_test.lua`

记录：本文件、同目录 `progress.md`、`2026-09-08-first-batch.md` 的后续修正说明。

## 机制变化

| 道具 | 本批实现 | 保持不变 |
| --- | --- | --- |
| 八音盒 | 已经存在的免伤在 `MC_PRE_PLAYER_TAKE_DMG` 提前取消伤害，避免先消耗原生护盾；首次致命伤触发仍留在原来的 `MC_ENTITY_TAKE_DMG` | Panic 能看到 ACE/七咒修改后的伤害；原20秒、后续死亡、债务和继续游戏状态不改；只处理实际受伤玩家 |
| 天使盒 | 溢出魂心充能调用原生 `AddActiveCharge`；仅在实际接受量大于0后手动加入可容纳血量、播放拾取声、移除心 | 四格、首次使用、溢出换算、奖励、owner/槽位均不改 |
| 恶魔盒 | 溢出黑心使用同样的原生事务 | 四格、首次使用、黑心换算及奖励不改 |
| 七咒之戒 | 副手 `AddActiveCharge(1, SLOT_SECONDARY, true, false, true)` | 仍只为记录的保留副主动充能；两房间间隔、Q4补偿、cycle去重不改 |
| 诛 | 每次符合原联动的命中，主/副手分别 `AddActiveCharge(1, slot, true, false, true)` | 仍需当前诛状态及车载电池；命中定义、两个槽位和每槽+1不改，不碰口袋槽 |

两盒保留原来的使用后放电逻辑；不是把所有 `SetActiveCharge` 一概替换。新充能接受量为0或API不存在时不做setter回退，不手工吃掉心，也不先手工回血后交还原版，避免一次拾取双算。

`Force=true` **不是无限充能**：这里绕过正充能的类型转换，容量仍由原生决定。`Overcharge=false` 意味着本次不强制超充，不承诺禁用 The Battery 等原生额外电量规则。两盒自身仍按四格剩余空间限定请求量。

## 为什么修正上一批 Force=false

实际原生逻辑不只是“是否接受普通充能”：

- `Force=false`、正充能、ChargeType=2（special）：返回0。天使盒和恶魔盒当前 XML 都是 special。
- `Force=false`、正充能、ChargeType=1（timed）：把请求量替换为原生最大充能，可能把“加1格”变成充满。
- `Force=true`：跳过上述类型分支，随后仍按原生最大容量减当前电量，限制实际增加量。

上一批七咒副手与此前诛迁移使用了 false，本批已修正。原来的手工+1实现没有排除 timed/special，因此此次是恢复原定定额语义，不是追加一种奖励。

### 可复核的版本证据（不是游戏内证明）

- 安装脚本：`E:/Isaac - Repentance/resources/scripts/main_ex.lua` 标记 1.0.12a。
- [官方1.0.12a玩家绑定](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/LuaInterfaces/Entities/LuaEntityPlayer.cpp)：AddActiveCharge转发 `charge, slot, flashHUD, overcharge, force` 并返回实际增加量。
- [同tag EntityPlayer.zhl](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/libzhl/functions/EntityPlayer.zhl)：函数签名及二进制匹配模式。
- [同tag ItemConfigItem.zhl](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/libzhl/functions/ItemConfigItem.zhl)：chargeType字段偏移0xAC。
- [同tag CustomCallbacks.cpp](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/LuaInterfaces/CustomCallbacks.cpp)：AddActiveCharge hook仅管理最大充能callback cache并调用super，没有重写上述类型分支；PRE玩家伤害返回false在原生伤害流程之前取消。

只读检查本机 `E:/Isaac - Repentance/isaac-ng.exe`：

- SHA-256：`530B4D2ACCEF833B8DBF6F1A9F781FE1E051C1916CA5ACDB579DF05A34640627`
- 官方签名只匹配一处，文件偏移0x357430；按.text映射得到VA 0x758030。
- 0x7580bc检查第五参数Force；非零跳过chargeType分支。0x7580c2读0xAC；special走return0，timed在0x7580dc取得max并覆盖请求量。
- 0x7580e6之后仍获取真实槽位最大值并按剩余空间夹取，因此Force不绕过容量。
- `GetActiveMaxCharge(slot)` 的slot3在0x757e47附近提前返回0。当前测试据此让slot3拒绝充能，不能把四个槽位全部报告为成功。

命令：

```powershell
Get-FileHash 'E:/Isaac - Repentance/isaac-ng.exe' -Algorithm SHA256
& 'C:/msys64/ucrt64/bin/objdump.exe' -h 'E:/Isaac - Repentance/isaac-ng.exe'
& 'C:/msys64/ucrt64/bin/objdump.exe' -d -M intel --start-address=0x758030 --stop-address=0x758330 'E:/Isaac - Repentance/isaac-ng.exe'
& 'C:/msys64/ucrt64/bin/objdump.exe' -d -M intel --start-address=0x757e40 --stop-address=0x757e94 'E:/Isaac - Repentance/isaac-ng.exe'
```

上述映射另由只读代码审查独立复核；没有修改游戏可执行文件，也没有读写运行进程。

## 测试过程与结果

先补测试再改生产：

1. 两盒旧测试和八音盒旧测试先补独立模块include替身，恢复原测试基线；独立模块不在这两个fixture中执行。
2. 两盒新增事务测试在旧setter路径失败；八音盒早期免伤测试在没有PRE处理器时失败。
3. 初版充能测试替身没有模拟special分支，出现过不充分的通过。依据本机原生证据补分支后，32例中24失败/8通过；Force改true后32例通过。随后补slot3原生零容量边界，仍32例通过。
4. 七咒新增timed/special回归，先复现期望1实际6、special不接受；诛先复现期望1实际3。仅修生产Force参数后两套完整测试通过。

最终执行（cwd为项目根，lua/luac绝对目录为 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/`）：

```powershell
lua.exe tests/angelbox_behavior_test.lua
lua.exe tests/musicbox_behavior_test.lua
lua.exe tests/annihilation_behavior_test.lua
lua.exe tests/ring_of_the_seven_curses_behavior_test.lua
lua.exe tests/repentogon_damage_order_test.lua
lua.exe tests/repentogon_damage_dispatch_test.lua
lua.exe tests/repentogon_bootstrap_test.lua
lua.exe tests/yins_curse_damage_order_test.lua
lua.exe tests/yins_curse_behavior_test.lua
lua.exe tests/blood_skull_gu_behavior_test.lua
lua.exe tests/folk_horror_items_behavior_test.lua --coin-sword
```

11个入口均exit0。两盒32个事务用例覆盖两个道具、四槽、正常/拒绝/缺API/容量受限、玩家隔离；slot3按原生0容量不消费。八音盒覆盖原生护盾先后顺序的模拟、普通受伤、致命触发、已经启用的免伤、20秒结束、继续游戏和owner隔离。真实注册伤害顺序12组、bootstrap14组、Yin顺序8组通过；关联本地化通过。

这包括项目真实注册与安装版Lua dispatcher检查，但**没有执行原生游戏战斗**。Lua中的护盾/充能引擎边界仍是测试替身。未宣称全仓库所有历史测试通过。

3个生产和4个测试文件分别运行 `luac.exe -p`，7个全部exit0。

```powershell
& 'C:/Users/Anton/.codex/skills/isaac-validators/scripts/validate-isaac-mod.ps1' -Root . -ModObjectName Neverbirth
& './docs/skills/isaac-neverbrith-validator-profile/scripts/validate-neverbrith.ps1' -Root .
git diff --check
```

- 通用：15 warning、0 failure（3原版早餐资源未解析、11启发式热路径、1玩家0 owner提示）。
- Neverbrith专用：269 warning、0 failure（266重复回调来自嵌套工作副本扫描、3早餐资源提示）。没有通过删除工作副本或改资源压警告。
- `git diff --check`：通过；仅LF→CRLF转换提示，不是whitespace error。
- 独立代码复审：四套受影响行为测试、12组真实注册顺序和7文件语法再次通过，没有残留重要问题。

## 游戏内仍需验收：全部未验证

1. 天使盒/恶魔盒各自首次使用之后，用满血和部分空血下的对应心验证原生充能HUD、四格上限、实际拾取、无双算；满电心不能被错误吃掉。
2. 原生允许的主手/副手/口袋槽分别验证；slot3已知原生零容量只能验证不误消费，不能要求或宣称成功充能。双人不同持有者互不占用。
3. 八音盒启用后遭伤害不消耗圣光斗篷；未启用时先由原生护盾承伤，不提前触发Panic；ACE/七咒倍伤后的致命命中仍能触发。退出继续和20秒后死亡符合旧设计。
4. 七咒保留副手及诛车载电池联动分别测试普通、计时、特殊充能主动：每次符合触发只加1，不直接充满；原生满电/动态容量及The Battery交互符合原生接受量。

后续仍有待研究/实测项：有效非零HP提交判定、真实拾取事件迁移、清房付债，以及原计划中依赖未验证接口的部分。本批没有顺带改这些机制，也没有执行肉块原生复活迁移。
