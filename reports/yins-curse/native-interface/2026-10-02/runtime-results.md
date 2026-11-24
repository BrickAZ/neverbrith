# 本轮安装与实机证据

用户明确授权“备份并安装候选，随后进行实机验收”。当前安装的是 `1.0.12a-yin-api1-dev` 修正版 2；真实 API 返回 `1`，不是离线夹具返回值。核心 19/19、进阶 8/10、生命周期 3/4；其中两个未闭合资格场景有重复尝试，不能将重复尝试或部分矩阵折算为完整验收。

## 安装与修复

- 安装前 `install-yin-native.ps1 -Mode Verify` exit 0；游戏和更新器关闭。
- 首次 Install exit 0，23 个替换文件全部备份校验。首启在运行 neverbrith 时中止：新能力查询遗留 5 个 Lua 栈元素，实际 `LuaStackProtector` 是检查器，不自动恢复栈。原日志在 [runtime-attempt-1](runtime-attempt-1/repentogon.log)。
- 首次 Rollback exit 0，23 个原 hash 恢复。真实 Lua 回归先 RED exit 1，再用作用域恢复栈顶修复能力和调试查询；原 protector 保留。Candidate 重新编译 exit 0，4 CTest exit 0。独立审查直接执行同一个 Release 栈测试 exit 0，核对 LuaResults 析构顺序，无未闭合 Critical/Important。
- 修正版重新包装、Verify、Install 均 exit 0；精确备份在 `release/yin-native-interface/2026-10-02/backups/20261002-authorized-revision2/`。[安装校验](installation-verification.json)确认 37 个运行文件、23 个原文件备份及未改变的游戏 EXE。
- 第二次真实启动成功读取版本、API 1、回调 1485、阴的诅咒实际 ID 779。探针阶段停留开场动画，菜单完成标记未达到，runner exit 2；API 证据独立成立。没有将这次超时改记为整轮成功。
- 首个伤害测试局的诊断设置触发 Isaac 表 `__newindex` 写保护错误，矩阵未开始。诊断改用 REPENTOGON 同样采用的 `rawset`；带写保护表的回归 RED exit 1 → GREEN exit 0。
- 第一次核心矩阵的失败包括测试误把参数 1 当作一颗心，和误以为旧 `MC_ENTITY_TAKE_DMG` 取消位于免爆判断之前。对照日志确认 1 是半颗心；旧取消仍阻止健康损失，但发生在免爆判断之后。保留失败日志，再分别测试这个旧入口和更早的 `MC_PRE_PLAYER_TAKE_DMG`。

## 真实游戏矩阵

运行 EXE SHA256 `530B4D2ACCEF833B8DBF6F1A9F781FE1E051C1916CA5ACDB579DF05A34640627`；运行 DLL 身份逐次保存在各 attempt 的 candidate manifest。全部为新建种子局 `123456789`，未继续用户原局。普通以撒 InitSeed `781984010`，另一个真实合作玩家 `1311766408`；Jacob/Esau 类型 19/20，InitSeed `781984010` / `1094652252`。实际启用内容 Mod 和运行 Lua 脚本清单保存在每份 game-log 启动段，没有临时关闭其他 Mod。

| 阶段 | 证据与结果 | 解释 |
| --- | --- | --- |
| 核心最终复跑 | [runtime-core-3/game-log.txt](runtime-core-3/game-log.txt)、[run.json](runtime-core-3/run.json)：19/19，runner exit 0 | 无/有诅咒、黑蜡烛与来源组合；纵火狂满血/缺血、宿主帽、多来源、纯火/混合标志、两个旧取消入口、API 0 回退、异常/非法返回链、实际实体炸弹 |
| 进阶最终复跑 | [runtime-advanced-2/game-log.txt](runtime-advanced-2/game-log.txt)、[run.json](runtime-advanced-2/run.json)：8/10，runner exit 0 | 无订阅者、斗篷、无敌帧、旧参数修改、逐监听器快照、吐根限定炸弹、真实合作玩家与嵌套上下文通过；knife/baby 资格没有通过 |
| 生命周期 | [runtime-lifecycle-1/game-log.txt](runtime-lifecycle-1/game-log.txt)、[run.json](runtime-lifecycle-1/run.json)：3/4，runner exit 0 | Jacob/Esau、实际房间沙漏回溯、九命猫死亡后复活通过；即刻测试原生宝宝仍没有进入资格 |

runner exit 0 只说明找到本次唯一 DONE 标记、保存证据并正常清理；测试断言结果以 `RESULT` 和 `DONE passed` 为准。进阶的 8/10、生命周期的 3/4 绝不是整个矩阵通过。

几个容易误读的结果：

- 纵火狂缺血用伤害参数 1：一次原治疗 +1 半心，免爆否决后一次实际伤害 -1 半心，最终血量相同；独立治疗和 post-damage 日志均存在。
- 连续两次攻击：第一次扣半心，第二次纵火狂原治疗仍补半心，随后原生无敌帧阻止第二次扣血。因此总血量恢复，post-damage 只有一次；接口没有强迫第二次扣血。
- 普通实体炸弹的玩家伤害为 2 半心，flags `1073741828`、countdown 30；Doctor Fetus 与吐根生成的真实炸弹命中为 1 半心，flags 4、countdown 30。两者不是同一个伤害参数。
- 嵌套合作调用：外层 call 9 的纵火狂 → 内层 call 10 → 外层 call 9 的宿主帽。内层玩家持黑蜡烛免爆，外层没有黑蜡烛扣半心；返回后父 callId 恢复。
- 旧普通伤害修改链把实际伤害改为 2 半心、添加原 flags 和 countdown 7；实际扣血及 post 参数均符合修改。新接口快照遵循其原生决策点时序，不伪称发生在更晚的旧回调之后。
- 皮肤 20 宝宝确由原生 `SpawnSelectedBaby` 创建，Variant 1/Subtype 20/BabySkin 20 有日志；后续日志出现无控制器连接，或即刻伤害没有进入接口。这一格仍未通过。
- 吐根刀确由真实射击创建 Type 8 对象；用其作为真实 EntityRef 调用爆炸伤害时没有进入限定免爆分支。不得将“有刀”视为不透明原生资格字节成立；这一格仍未通过。

## 仍未闭合的验收

吐根限定刀资格、合作宝宝皮肤 20 的稳定实际资格；宿主帽成功/失败画面与普通投射物拦截；真实存档关闭后继续；EID 面板/控制器输入及其他人工画面结果仍需对应证据。真实 API 1、30 个通过检查和源码六处闭合不替代这些证据。见 [game-acceptance.md](game-acceptance.md) 中逐行状态。

## 清理与恢复

最终 `check-neverbrith.ps1 -Profile LuaAll` exit 0，72 项通过、65 个 Lua 测试、91 个直接语法文件；6 条既有通用资源警告，严格/My Stuff 0 警告，见 [checks-final-verified.json](checks-final-verified.json)。之前四个精确官方版本断言失败的报告及夹具写入被拒绝后的失败报告仍保留；修复接受范围只增加本次明确标识，并逐段验证旧伤害排序与分派不变。新版 native patch 从精确 ZIP archive forward apply，21 个文件一致，见 [source-roundtrip-revision2.json](source-roundtrip-revision2.json)。

本轮只有显式临时 `main.lua` 入口，所有 attempt 均恢复到原 SHA256 `0971C9500DABFC80912824382346D284A6FF24FE1E149A7BDAA203A1E9E7EDDD`。诊断/测试模块留在 `diagnostics/` 供复查，正常游戏不加载，也不自动执行库存/健康测试设置。

测试前备份 217 个游戏/Mod 数据、设置与云续局文件。`restore-yin-runtime-state.ps1` exit 0：6 个实际变化文件恢复，4 个本轮新建文件先保留副本再移除，217 个原 hash 全部一致；见 [state-restoration.json](state-restoration.json)。测试进程已停止。候选继续安装，用户原有续局与设置已恢复。

需要恢复官方原生文件时，关闭游戏后执行：

```powershell
pwsh -NoProfile -File "E:\Isaac - Repentance\mods\neverbrith\tools\install-yin-native.ps1" -Mode Rollback -BackupDirectory "E:\Isaac - Repentance\mods\neverbrith\release\yin-native-interface\2026-10-02\backups\20261002-authorized-revision2"
```

没有提交、推送或发布；ds4 继续按用户决定排除。
