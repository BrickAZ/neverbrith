# 阴的诅咒原生接口候选交付

状态：用户授权后，**修正版候选已安装**，真实 API 返回 `1`；核心与部分进阶/生命周期实机检查通过，完整验收仍有未闭合项目。游戏 EXE 未改变；23 个原生替换文件已备份校验，测试后的用户原续局、Mod 数据和设置已恢复。没有提交、推送或发布创意工坊。ds4 按用户决定排除。最新安装、失败修复和实机证据见 [runtime-results.md](runtime-results.md)。

规格见[已确认设计](../../../../docs/superpowers/specs/2026-10-02-yins-curse-explosion-immunity-interface-design.md)，步骤见[实施计划](../../../../docs/superpowers/plans/2026-10-02-yins-curse-explosion-immunity-interface.md)。本次源码、构建和离线证据不等于游戏副效果验收。

## 实现与身份

REPENTOGON 源码固定在 `1.0.12a` / `4675b426d1ce7973595172984c366354e5bb66f9`，隔离源码在 `worktrees/repentogon-yin-native/source`。候选标识为 `1.0.12a-yin-api1-dev`，使用 MSVC 14.44.35207、Win32/x86、Release、CMake 3.31.8。递归子模块和游戏 hash 见[source-manifest.json](source-manifest.json)。所有 CMake 构建明确 `ISAAC_DIRECTORY:PATH=`，未自动部署。

新增回调 1485：`MC_PRE_PLAYER_EXPLOSION_IMMUNITY(mod, player, hit, immunity)`。任一合法 false 否决当前来源的免爆资格，所有监听器仍执行；true/nil/异常/非法返回不能撤回否决。按监听器复制 hit、immunity 与 EntityRef 值，修改不回写原始伤害参数。实体引用仍为实际对象，不承诺隔离主动修改实体的任意 Mod 行为。

原生审计闭合到六个位置：纵火狂满血/治疗后两个出口、宿主帽成功反馈之前、吐根限定炸弹/刀分支、合作宝宝皮肤 20。细节和排除范围见[immunity-sites.md](immunity-sites.md)。不修改火焰或投射物保护，不取消伤害、不整件禁用、不补第二次伤害。纵火狂缺血路径先执行原治疗，再决定是否免爆。

每次原生伤害由 RAII 建立独立 callId，嵌套退出恢复父调用；参数快照读自当前决策点的真实 EBP 栈帧。全部六处特征唯一、继续点正确、游戏磁盘 hash 支持、原生接入完成、Lua 枚举/分派/来源副本函数匹配，才允许能力查询返回 1。当前真实游戏已返回 1，并观察到嵌套玩家返回后恢复父 callId；限定刀和宝宝站点仍没有实际资格命中证据。

neverbrith 在能力 v1 可用时注册；诅咒已激活且实际受伤玩家当前无黑蜡烛才返回 false。缺失能力只给一次明确日志，保留现有 Q4 路线和其他玩法。中英 EID 根据加载时真实能力显示对应行为。未改品质、道具池、资源设计或存档结构。

## 已运行检查

| 检查 | 证据和实际结果 | 能证明的范围 |
| --- | --- | --- |
| 固定基线构建 | `build-yin-native.ps1 -Stage Baseline` exit 0；[baseline-commands.json](baseline-commands.json) | 原生工程可编译；不是未经修改的洁净基线 |
| 首次基线失败与兼容修正 | ANTLR 缺少 `<chrono>`，首次 exit 1；仅补显式 include 后通过 | 保留依赖差异，未假称首次成功 |
| 候选构建 | `build-yin-native.ps1 -Stage Candidate` exit 0；[candidate-commands.json](candidate-commands.json) | 自定义 Win32 DLL 和配套脚本生成 |
| 原生合同 | `tests/native/yin_native_patch_contract_test.ps1` exit 0；[native-contracts.log](native-contracts.log) | 3 个 CTest 目标：嵌套上下文/能力状态、实际 EXE 六处扫描和跳转目标、96 条真实执行 x86 stub 路线的寄存器/EFLAGS/栈/x87/XMM/MXCSR |
| Lua 实际分派核心 | `tests/native/repentogon_explosion_dispatch_test.lua` exit 0 | 7 项：顺序、累积否决、异常/非法返回、逐监听器副本、卸载、旧分派/伤害语义、过滤拒绝 |
| Yin 模块专项 | `tests/yins_curse_explosion_immunity_test.lua` exit 0 | 四组合、实际玩家与当前黑蜡烛、已保存激活、缺失/异常能力、双语能力说明 |
| 模组 LuaAll | [checks.json](checks.json)：exit 0，71 项检查，64 个 Lua 测试文件、89 个语法文件 | 6 条既有通用资源警告；严格/My Stuff 0 警告。范围见报告，不等于全项目全部检查或实机 |
| 定制构建启动门禁 | `repentogon_bootstrap_test.lua` exit 0，17 个实际入口 case；[bootstrap-green.log](bootstrap-green.log) | 只允许此次固定定制标识，其他未知 dev/nightly 保持拒绝，实际伤害分派仍必需 |
| 默认关闭/诊断唯一性 | `yin_explosion_diagnostics_test.lua` exit 0；[diagnostics-green.log](diagnostics-green.log) | opt-in、重复加载不重注册、一次治疗事件仅一条返回日志、关闭/重开 |
| 可应用源码补丁 | [source-roundtrip.json](source-roundtrip.json)：exit 0 | 取固定 commit 的受影响文件，forward apply 实际生成 19 个文件，与当前源只归一 CRLF 后一致；不等于全新目录完整重编译 |
| 安装/恢复夹具 | `tests/native/yin_native_install_test.ps1` exit 0；[install-green.log](install-green.log) | 只在隔离假游戏目录验证：Verify 不写、备份校验、恢复原文件/删除本次新增文件、拒绝损坏候选 |
| 真实安装目录只读校验 | `install-yin-native.ps1 -Mode Verify` exit 0；[candidate-verify.log](candidate-verify.log) | 候选与原文件及游戏校验匹配；未执行真实 Install |

初始 stub 测试失败为 segfault，原因是上游 `ASMPatch::AddBytes(string)` 截断零字节；保存指令和 siteIndex 改用 `ByteBuffer::AddAny/AddByte`，现验证所有六个编号的 96 条路线。失败日志保留，没有把崩溃当作“测试通过”。普通 C++ 构建警告也保留在日志。

## 候选与替换范围

本机最新验收补充：[checks-final-verified.json](checks-final-verified.json) exit 0，72 项检查、65 个 Lua 测试文件；[native-contracts-revision2.log](native-contracts-revision2.log) 4 CTest exit 0，新增真实 Lua 栈回归。旧测试的四个官方版本字面断言在安装定制构建后失败，现只接受官方 1.0.12a 或本次明确批准的标识，并将排序函数与旧伤害分派函数逐段核对原审计源码；原行为断言保留，另有错误版本/变更逻辑拒绝反例。

当前修正版源码补丁的复现证据是 [source-roundtrip-revision2.json](source-roundtrip-revision2.json)：精确固定 commit 的 ZIP archive 保留原始末尾换行，forward apply exit 0，全部 21 个文件仅归一 CRLF 后一致。上表的 19 文件记录属于首版，失败首启及首版 manifest/patch 均保留在 runtime-attempt-1。

完整候选在[release/yin-native-interface/2026-10-02/candidate](../../../../release/yin-native-interface/2026-10-02/candidate/)，精确文件和 SHA256 见[candidate-manifest.json](candidate-manifest.json)，候选内也附同一清单和 `SHA256SUMS.txt`。运行文件 37 个，本机比较需替换 23 个，没有新增文件：5 个匹配构建的 DLL、2 个机制/分派 Lua 文件、16 个仅换行符不同的上游资源文件。另有 14 个运行文件 hash 一致，无需替换。安装脚本只操作清单差异，不删目录，不覆盖未列出的原生库或 Mod 文件。

DLL 是 `dsound.dll`、`libzhl.dll`、`zhlREPENTOGON.dll`、`Lua5.4.dll`、`freetype.dll`。不部署编译工具、测试 EXE、ANTLR 编译依赖或可选 Delirium DLL。这个候选的更新器沿用 dev-build 跳过更新规则，额外识别 `-yin-api`；恢复官方文件后恢复官方更新行为，避免自动换掉配套接口。

源码差异在候选 `source-patches/repentogon-yin.patch`；依赖修正在 `source-patches/antlr4-chrono.patch`。上游 commit 和递归子模块由 source manifest 固定；附 GPL 许可。要复现：取得固定源码与固定子模块，在源码根用 `git apply repentogon-yin.patch`，在 `libs/antlr4` 用 `git apply antlr4-chrono.patch`，再运行构建工具的 Candidate 阶段。不能对已修改源码重复 apply；先用 `git apply --check` 判断。工具下载有官方 SHA256 校验，源码 clone 不会自动应用此功能补丁。

## 安装与恢复

本计划的单独替换授权已由用户明确提供。实际 Verify、Install、首启缺陷后的 Rollback，以及修正版再次 Verify/Install 均已执行，命令退出码见 [runtime-results.md](runtime-results.md)。当前有效恢复备份是 `release/yin-native-interface/2026-10-02/backups/20261002-authorized-revision2/`。

以下为安装工具调用方式；本机已安装，不能把原文件 hash 的 Verify 当作“当前已安装文件与候选比较”，当前比较另见 [installation-verification.json](installation-verification.json)。再次部署前仍需关闭 Isaac 与更新器：

```powershell
pwsh -NoProfile -File tools/install-yin-native.ps1 -Mode Verify
pwsh -NoProfile -File tools/install-yin-native.ps1 -Mode Install
```

工具再次核对游戏 hash、所有候选 hash、包装时的安装文件 hash；原文件发生变化时停止。备份保存在模组内 `release/yin-native-interface/2026-10-02/backups/<时间-GUID>/`，输出精确路径；复制前备份和 SHA256 全部成功，才开始替换。安装失败会尝试用已校验备份恢复，并核验原 hash；不能只凭重试认为已回滚。

恢复时游戏关闭，使用 Install 输出的那一份备份：

```powershell
pwsh -NoProfile -File tools/install-yin-native.ps1 -Mode Rollback -BackupDirectory '<精确备份路径>'
```

常规 Rollback 拒绝覆盖安装之后再次改变的文件，需先查清差异。恢复已校验原文件，删除本次原本不存在的新增文件；不删除备份和存档。候选安装不会自动启动游戏。

## 实机与审查

[game-acceptance.md](game-acceptance.md) 提供诊断开关、测试卡和逐行状态。真实 API 1、核心 19/19、进阶 8/10、生命周期 3/4 均有游戏日志；限定刀/宝宝资格、宿主帽画面与投射物、真实关闭后继续及人工 UI 尚未闭合，不能称为完整玩法验收通过。首启能力查询栈泄漏已修复并补真实 Lua 栈回归；4 CTest、限定修复的独立复核通过。实机诊断 `__newindex` 错误也已修复并回归。[独立审查](review.md)保留原候选审查及新栈修复复核。执行裁决见[execution-decisions.md](execution-decisions.md)。
