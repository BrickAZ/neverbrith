# 斗气拳套：持续伤害击杀归属修复

日期：2026-10-15。依据用户授权，修复玩家／跟班施加的中毒、燃烧及流血归属，防止多人串回气。当前 Lua 位于已安装模组目录；原生来源接口已安装，未提交、推送或发布。

## 行为与边界

- 仍由真正死亡事件结算，一名敌人只结算一次，向致死攻击所属、当前持有拳套的玩家回 **1格**。命中不回气；道具离身时不回气。
- 玩家、所属攻击及跟班的原生 `AddPoison`、`AddBurn`、`AddBleeding` 均记录生效来源。后续普通命中不能抢占持续伤害来源；毒、火、流血各自保存玩家键。
- 原生扣血路径明确标识本次为毒、火或流血。两个玩家在同一敌人上施加不同状态时，按此次实际被接受的伤害事件选择对应来源；同帧原生接受多次伤害时，保留最后一次接受的伤害来源。不会用附近玩家、玩家0、状态颜色或上一发普通子弹猜测。
- 原生重复毒／火保留最大伤害值：较弱施加只延长时间时保留原伤害来源；较强或等值输入被原生选中时更新来源。没有改原生比较、持续时间、上限、叠加、免疫、扣血量或周期。
- 跟班消失后，已经发出的泪弹可能仍存在但 `SpawnerEntity` 被引擎清空。保存攻击创建／命中时的所有者快照，直到攻击实体移除；后续 DOT 只保存玩家键，因此弹体和跟班消失不丢失已经施加的归属。明确的新来源可以更新归属。
- 归属在 `MC_POST_ENTITY_TAKE_DMG` 提交；PRE 只读取攻击来源。较晚回调取消的攻击不能抢走已有致死事件；零伤害和假伤害不改写归属。
- 源实体与目标身份使用指针＋InitSeed，并检查目标类型／Variant；房间、开局、退出、沙漏回退仍走原有清理。普通攻击快照随实体消失清理，状态来源随状态消失清理。只持久保存原有斗气／力竭字段，没有增加读档补发或奖励续接。
- 原生分节状态复制与 REPENTOGON `CopyStatusEffects` 携带相同的来源记录；无来源的新状态会清掉旧来源。友方死亡、直接移除以及确实无法归属玩家的环境伤害仍不回气。

## 为什么需要本机原生接口

原安装的 REPENTOGON `1.0.12a-yin-api1-dev` 在状态施加时没有对 Lua 暴露来源通知，毒／火扣血均以无实体的 `DAMAGE_POISON_BURN` 进入 Lua。仅检查 TearFlags 无法覆盖脚本直接施加，也无法区分同一目标上的不同 DOT。

本次在现有原生分支增加只读来源接口：

| 接口 | 合同 |
| --- | --- |
| `Isaac.GetStatusAttributionAPIVersion()` | 七个目标位置全部通过可执行文件身份与字节检查并安装后返回1，否则0 |
| `Isaac.GetCurrentDotDamageKind(entity, source)` | 仅在该目标、该原生 EntityRef 的实际扣血调用范围内返回1毒／2火／3流血，其余0；嵌套调用使用自己的来源引用，不能继承外层身份 |
| `REPENTOGON_POST_DOT_APPLIED` 字符串回调 | `(mod, target, source, kind)`；在通过原生资格与伤害值选择后通知，返回值不影响原生处理；没有另施加状态 |
| `REPENTOGON_POST_DOT_COPY` 字符串回调 | `(mod, from, to, overwrite)`；对应原生分节复制与显式复制规则，只同步归属元数据 |

安装只替换 `E:\Isaac - Repentance\zhlREPENTOGON.dll`，保留现有阴的诅咒接口；`isaac-ng.exe` 未改。DLL SHA-256：`A053418AD4851C91203F2E6A7F09E6D1A96FBC8A3294AE31D615FA40EA990B5F`。可执行文件 SHA-256：`530B4D2ACCEF833B8DBF6F1A9F781FE1E051C1916CA5ACDB579DF05A34640627`。

接口针对本机已核对的版本；如果日后替换 REPENTOGON／游戏导致能力缺失，会记录能力缺失，停止猜测无来源 DOT 归属。泛用第三方脚本若故意传入空来源且没有任何玩家链，不能从空信息恢复玩家；这仍属于设计中“无法归属玩家”的范围。

## 本次证据

| 检查 | 命令与退出码 | 结果 |
| --- | --- | --- |
| 先失败的回归 | `lua.exe tests/drive_glove_behavior_test.lua`，退出1，见[red-test.log](red-test.log) | 原实现无法区分两人毒火，断言失败 |
| 原生候选编译 | `pwsh -NoProfile -File tools/build-drive-dot-native.ps1`，退出0 | [构建日志](native-build.log) |
| 双人原生归属 | `pwsh -NoProfile -File tools/accept-drive-glove.ps1 -Attempt dot-ownership-09 -Probe dot_ownership -Seconds 55`，退出0 | **26个场景，83项检查通过**；[游戏日志](../../2026-10-14/implementation-v1/dot-ownership-09/game-log.txt) |
| 修改前后原生对照 | `pwsh -NoProfile -File tools/compare-drive-dot-native.ps1`，退出0 | **8组扣血量与状态倒计时逐字一致**；[对照数据](native-damage-comparison.json) |
| 原有阴接口 C++ 回归 | `ctest.exe --test-dir worktrees/repentogon-yin-native/build -C Release --output-on-failure`，退出0 | 4/4通过，含96条实际执行的 x86 寄存器／栈／浮点保存路径；[日志](native-yin-regression.log) |
| 全项目自动检查 | `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' -ReportPath reports/drive-rush/2026-10-15/dot-ownership/lua-all.json`，退出0 | 80通过／0失败／0阻塞；包含斗气回调138断言；[报告](lua-all.json) |
| 原生基础机制回归 | `pwsh -NoProfile -File tools/accept-drive-glove.ps1 -Attempt dot-regression-runtime-01 -Probe runtime -Seconds 45`，退出0 | 35/35；[日志](../../2026-10-14/implementation-v1/dot-regression-runtime-01/game-log.txt) |
| 原生操作／反馈回归 | `pwsh -NoProfile -File tools/accept-drive-glove.ps1 -Attempt dot-regression-controls-01 -Probe controls -Seconds 40`，退出0 | 29/29；[日志](../../2026-10-14/implementation-v1/dot-regression-controls-01/game-log.txt) |
| 原生伤害换算／蓄力回归 | `pwsh -NoProfile -File tools/accept-drive-glove.ps1 -Attempt dot-regression-mechanics-01 -Probe mechanic_audit -Seconds 55`，退出0 | 103/103；22种伤害配对和9类武器；[日志](../../2026-10-14/implementation-v1/dot-regression-mechanics-01/game-log.txt) |
| 文档导航 | `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1`，退出0 | 5页可达／92个本地链接有效 |

自动检查保留6条已有通用资源警告；严格验证、My Stuff 与导航通过。原生回归合计167项，连同本次归属专项共250项通过。原有立体声音效的声像警告仍出现在原生日志中，本任务没有改音频资源。

原生归属覆盖：两名玩家互换毒火来源、分别由毒和火致死、同帧毒火、脚本施加、玩家毒泪、跟班燃烧泪、来源消失、普通命中插入、强／弱／等值状态刷新、状态免疫拒绝、无来源替换、状态复制、过期重施加、环境补刀、直接玩家补刀、跟班流血、较晚回调取消攻击、道具离身冻结。

原生对照分别加载任务前 DLL 和最终 DLL，运行同一诊断后恢复最终 DLL。毒、火、同帧毒火、错开毒火、移动流血、较弱状态延长和免疫8组均一致；其中单次毒／火扣3.5，同时毒火合计扣7，移动流血测试扣3.1。这里只陈述测试实际值，不将测试值变成道具新数值。

隔离测试使用现有运行器，逐次备份并恢复17项存档／设置，移除临时诊断入口。首次候选曾因补丁工具字符串接口截断零字节而在诊断中崩溃，已改为原始字节缓冲；对应失败日志保留在 `dot-ownership-01`。后续诊断修正了敌人阶段转换、跟班生命周期和流血需实际移动的夹具条件；失败次数不计入通过数量。

这些是原生引擎自动诊断结果；未替代用户的人工多人游玩验收，也未宣称遍历全部角色、分节Boss和第三方模组组合。

## 源码、候选与回退

- [Lua 回调实现](../../../../drive_glove.lua)、[回调回归](../../../../tests/drive_glove_behavior_test.lua)、[双人探针](../../../../diagnostics/drive_glove_dot_ownership.lua)。斗气核心、普通防御数值适配、武器、视觉、音效模块均未修改。
- 原生实现：`worktrees/repentogon-yin-native/source/repentogon/Patches/StatusAttribution.cpp` 与 `.h`，接入现有 `ASMPatches.cpp`、`LuaIsaac.cpp`、`Entities/LuaEntity.cpp`。
- [本轮原生源码补丁](native-source.patch)只包含相对于任务开始时原生分支的改动，保留原有阴接口；[文件哈希](final-file-hashes.json)与[最终完整性核对](final-integrity.json)记录本轮交付身份及恢复情况。
- 最终候选：[candidate-03](candidate-03/candidate-manifest.json)。`candidate` 是失败的初版，`candidate-02` 是中间版本，均不用于最终安装。
- 原始 DLL 专用回退备份：[native-rollback-original](native-rollback-original/restore-manifest.json)。以下命令会核对最终 DLL 身份后恢复任务前 DLL；回退后无来源持续伤害的完整归属能力也会撤回。

```powershell
pwsh -NoProfile -File tools/install-yin-native.ps1 -Mode Rollback -CandidateRoot reports/drive-rush/2026-10-15/dot-ownership/candidate-03 -BackupDirectory reports/drive-rush/2026-10-15/dot-ownership/native-rollback-original
```
