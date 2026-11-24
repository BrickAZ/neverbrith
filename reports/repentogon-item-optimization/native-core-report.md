# P0 / P1 / P4 原生接口迁移报告

日期：2026-09-05。工作目录：E:/Isaac - Repentance/mods/neverbrith。
本子批只执行 native-core-brief 的入口门禁、同次伤害、诛充能；未改 P2/P3/P5/P6、肉块挡伤、ACE 惩罚/CPU workload、七咒 Q4 补偿。
保留进入本子批前已审查的诛/神风修复，以及用户已有脏改动；没有提交、升级、启动游戏或派生子代理。

## 运行时和原生证据

- 本机 E:/Isaac - Repentance/resources/scripts/main_ex.lua:2 明确 Real=true；:4 为 Version=1.0.12a；:12 起 MeetsVersion 只提取数字并接受 dev build。
- 同文件 :1338 的全局 _RunEntityTakeDmgCallback：修改表更新下游参数；false 立即取消；true 不终止；不填 flags/countdown 则保留，Source 不被重写。
- tests/repentogon_damage_dispatch_test.lua 直接读取本机上述文件，验证版本字符串、提取实际函数并执行。测试替身仅供应 callback iterator/调用入口；金额传播算法不是手写模拟。此证据仍不是原生 C++ 扣血或游戏内观察。
- [官方 1.0.12a EntityPlayer 文档](https://raw.githubusercontent.com/TeamREPENTOGON/REPENTOGON/1.0.12a/docs/docs/EntityPlayer.md)：AddActiveCharge(Charge, Slot, FlashHUD=true, Overcharge=false, Force=false)，返回实际增加量。此次显式传 1、主/副槽、true、false、false。
- [Isaac.ConsoleOutput API](https://wofsauge.github.io/IsaacDocs/rep/Isaac.html#consoleoutput)：用于前置提示输出；有函数存在检查，无新增窗口/渲染回调。

## P0 门禁：红 → 绿

首次测试：tests/repentogon_bootstrap_test.lua，退出 1，missing 分支触发 REGISTRATION_BOUNDARY，证明旧入口在缺失前置时已调用 RegisterMod。
实现后 11 类初始版本用例通过。
第二轮新增 Real/分发器/优先控制台提示用例，先退出 1（仍使用 DebugString 而未走控制台）；完善门禁后 14 类、每类重复加载 2 次全部通过。

实际合同：

- 入口内联 do 块先于 RegisterMod 和任何 include。
- 要求 REPENTOGON 为 table、Real==true、Version 为受支持字符串，且实际使用的 _RunEntityTakeDmgCallback 为 function。
- 版本语法为三个无前导零数字段加可选一个小写字母；数值逐段比较，最低 1.0.12a，不接受 1.0.12、匿名 dev、自定义后缀或伪版本表。
- 失败停止初始化；同 Lua 全局生命周期只发一次中英提示。优先 Isaac.ConsoleOutput，缺少时 DebugString，再缺少时 print；不主动打开控制台、不建立 UI。中文在真实游戏控制台字体中的显示未验证。
- 门禁不执行伤害、存档、生成实体或注册回调。Lua 门禁不承诺阻止引擎提前解析已发布 XML。
- tests/repentogon_test_fixture.lua 仅声明 Real/Version 和不可实际调用的分发器占位；旧 full-main 测试在 dofile(main.lua) 前显式调用，无生产 test bypass，无无关扩展回调枚举。

22 个 full-main 测试在门禁与 P1 完成后再次运行：仍为原基线的 3 通过 / 19 失败；3 个通过为 cleaver_character、localization、uncut_cord。16 个 include=nil 失败（含 empty_cradle、dog_food）和 3 个旧断言失败均保留，不计作本次回归，不声称整库全绿。旧断言仍为 Needletick 英文副标题、Crazy Coconut XML quality/cache、Cleansed Wavy Cap timed charge。

## P1 同次伤害：红 → 绿

- ACE 新测试使用计数并抛错的 TakeDamage；迁移前退出 1：same-hit rewrite must not call TakeDamage，expected 0, got 1。
- 七咒新测试同样先退出 1：ring must not call TakeDamage，expected 0, got 1。
- 之后才修改两处生产回调。现均只返回 { Damage = amount * 2 }（ACE 保留原 tonumber 规范化）。
- 移除 ACE playerDamageReplacementDepth 和戒指 damageRewrite 及其复位；不保留递归 fallback。
- ACE Capabilities 改为 sameHitDamageRewrite=true / guardedDamageReplacement=false，更新“无法重写”的过时日志，其余惩罚能力不动。
- 完整 ACE 与完整七咒测试均退出 0。覆盖金额 1/2→2/4，ACE 另含0.5→1；zero、非持有者、戒指未激活不变；返回表不写来源、标志、倒计时。
- 真实本机 Lua 分发器集成测试退出 0：ACE→戒指、戒指→ACE均 x4；中间 true 继续；在四个位置插入 false 均取消整链，下游不再执行；没有假 HP 扣血，也没有额外 TakeDamage。
- 原资格保持：ACE 的承伤翻倍按持有者判断，不新增 runtime.active 限制；戒指按本局已激活状态判断。

## P4 诛原生充能：红 → 绿

- 新测试先将 SetActiveCharge 设为禁止调用，添加 AddActiveCharge 参数/返回替身；迁移前退出 1：native calls should charge both slots，expected 2, got 0。
- 之后才迁移 chargeActiveSlot 至 AddActiveCharge；按实际新增值 >0 计成功。删除仅供手工拼格子的 getCollectibleConfig/getCollectibleMaxCharge。
- 只保留原 chargeCarBatterySynergy 的激活者+c356资格，主/副各调用一次，不碰 pocket。有效命中/取消/失败、同波去重、多敌重复命中、实时伤害、范围与时长均由原已审查逻辑继续拥有。
- 接口缺失或抛错仅一条 nativeCharge 日志，不退回手工充能。无正增加量时返回 false，不把 pcall 成功当成充电成功。
- 完整诛测试退出 0，新增普通双槽参数、0/负数/false/非数字返回、正小数返回、空/满槽、动态最大值、特殊主动拒绝、异常与缺失一次日志；原双玩家、无 c356、同波同实体、取消/失败不充能等测试保持。
- AddActiveCharge mock 只证明项目调用参数与返回处理；HUD 闪烁、动态/特殊主动原生规则、双人实机均未验证。

## 本批修改文件

生产：main.lua（P0入口与ACE伤害块）、ring_of_the_seven_curses.lua（伤害及其专属锁）、annihilation.lua（充能helper及已无用的手工配置计算）。

专用测试：tests/ace_anti_cheat_behavior_test.lua、tests/ring_of_the_seven_curses_behavior_test.lua、tests/annihilation_behavior_test.lua。

新增：tests/repentogon_bootstrap_test.lua、tests/repentogon_damage_dispatch_test.lua、tests/repentogon_test_fixture.lua、本报告。

下列 22 个旧入口测试仅在原 dofile(main.lua) 前新增显式 fixture 调用（其中其他历史改动不属于本批）：

- tests/angelbox_behavior_test.lua
- tests/between_death_and_life_behavior_test.lua
- tests/blood_skull_gu_behavior_test.lua
- tests/boss_order_behavior_test.lua
- tests/burn_away_resentment_behavior_test.lua
- tests/cleaver_character_behavior_test.lua
- tests/condom_utility_knife_behavior_test.lua
- tests/debug_controller_behavior_test.lua
- tests/dice_set_behavior_test.lua
- tests/dog_food_series_behavior_test.lua
- tests/empty_cradle_behavior_test.lua
- tests/folk_horror_items_behavior_test.lua
- tests/good_girl_of_babylon_behavior_test.lua
- tests/localization_test.lua
- tests/moon_is_beautiful_behavior_test.lua
- tests/musicbox_behavior_test.lua
- tests/needletick_behavior_test.lua
- tests/shredded_tarot_behavior_test.lua
- tests/sterilization_certificate_behavior_test.lua
- tests/strong_laxative_behavior_test.lua
- tests/tower_of_babel_behavior_test.lua
- tests/uncut_cord_behavior_test.lua

## 实际执行命令与最终结果

运行器：C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe，语法器同目录 luac.exe。
命令形状：& '<lua.exe绝对路径>' tests/<文件>；每个脚本均单独检查退出码。

最终退出 0：

- tests/repentogon_bootstrap_test.lua（14 cases, repeated loads）
- tests/repentogon_damage_dispatch_test.lua（本机1.0.12a真实Lua分发器）
- tests/ace_anti_cheat_behavior_test.lua
- tests/ring_of_the_seven_curses_behavior_test.lua
- tests/annihilation_behavior_test.lua
- tests/kamikaze_squad_behavior_test.lua（既有独立修复回归）
- tests/revive_my_love_behavior_test.lua（14 passed）
- tests/localization_test.lua

22 个 full-main 脚本另逐个执行，结果与 full-main-baseline.md 一致（3通过/19既有失败）。
本批全部 31 个 Lua 文件执行 luac.exe -p，全部通过。
git diff --check 未发现空白错误；Git 提示工作区 LF 将转换 CRLF，未主动格式化或整文件改换行。
新文件另做行尾空白扫描，结果见最终工具记录。
两套最终验证器由主代理统一执行，本子批不重复运行。

## 操作和验证边界

使用执行计划、TDD、REPENTOGON 兼容/回调、主动道具充能及完成前验证技能；技能促成明确版本/能力门禁、同次返回链而非重放、原生充能返回值判断和逐批红绿记录。
标准 apply_patch helper 部分调用遭 deny-read ACL 故障，后改用同 codex.exe --codex-run-as-apply-patch 引擎并 require_escalated 明确理由；没有修改 ACL。P0 额外门禁补丁一度遭自动审查以证据不足拒绝，补充只读本机源码及 API 文档证据后重新获准，没有绕过拒绝。
所有修改均为 apply_patch 精确块；没有 shell 文本直接写文件。
未执行任何游戏内验证：缺失前置实际提示、伤害盾/无敌帧/献血触发次数、两件叠加真实生命损失、诛双主动HUD及特殊主动均仍未验证。

## 独立审查后测试盲点修正

独立审查指出：新增身份门禁后，旧版本、dev、自定义后缀和前导零负例未带 Real=true，会提前在身份检查拒绝，因而没有实际覆盖版本解析。
本次仅为 tests/repentogon_bootstrap_test.lua 中 old base、old patch、dev、unknown、leading zero 五个版本负例补 Real=true；保留独立 fake table、version alone 身份负例。没有修改生产代码或扩大范围。

实际重新执行：

- & 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' tests/repentogon_bootstrap_test.lua：退出 0，14 cases, repeated loads。
- & 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/luac.exe' -p tests/repentogon_bootstrap_test.lua：退出 0。

修正后的负例通过真实身份与分发器前置后，才由版本解析/最低版本比较拒绝。此前 P0 的版本覆盖描述以本次重新执行结果为准。
