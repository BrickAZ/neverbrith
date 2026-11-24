# 阴的诅咒精确爆炸免疫封锁 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为固定 REPENTOGON 构建增加按来源否决爆炸免疫的原生回调，接入阴的诅咒，并交付可审阅、可恢复的本地候选构建及分层验证记录。

**Architecture:** 原生层在各个经审计的爆炸免疫决策点调用同一个接口，保留原始伤害调用、副效果和后续非免爆保护。独立 Lua 分派规则累积所有监听器的否决；neverbrith 监听器只读取本局诅咒状态和实际受伤玩家的黑蜡烛。源码、编译产物与诊断工具隔离保存，安装文件替换在候选构建和恢复方案可审阅后单独处理。

**执行记录:** Tasks 1–5 已完成候选与离线验证；Task 6 诊断/验收卡已准备，安装和实机矩阵尚未执行。以带日期的 delivery/checks 为实际证据。`IsExplosionImmunityAllowed` 实现另接受真实 native frame 的 hit 快照，详见执行裁决。`main.lua` EID 依据真实能力切换，未改锁定 Q4 语义。

**Tech Stack:** Windows、Win32/x86、VS 2022/MSVC、CMake 3.31.8、REPENTOGON 1.0.12a 固定源码、LibZHL/ASMPatcher、Lua 5.4、PowerShell 7。

**Spec:** [已确认规格](../specs/2026-10-02-yins-curse-explosion-immunity-interface-design.md)。用户于 2026-10-02 以“开始吧”确认方案一规格并要求推进。

## Global Constraints

- 诅咒未激活时，接口监听器不改变任何免疫。
- 不新增黑蜡烛免疫，不改变首次取得阴的诅咒时锁定的品质 4 分支。
- 不剥离 `DAMAGE_EXPLOSION`，不改原伤害参数，不通过健康重建或第二次 `TakeDamage` 仿造结果。
- 不整件 `BlockCollectible` 或临时删除 Pyromaniac、Host Hat 等来源。
- 保留爆炸治疗、火焰防护、投射物阻挡等非封锁目标的能力及原生相对顺序。
- 黑蜡烛检查按本次实际受伤玩家；禁止用玩家 0 或取得道具时的快照替代。
- 新接口的 false 与现有伤害回调的 false 含义不同，文档及测试必须显式说明。
- 所有适用监听器执行完，任一有效 false 保持否决，后置 nil/true/异常不能撤销它。
- 原生调用栈状态不持久化。
- 模拟 Lua 测试不能证明原生出口和副效果，编译成功也不能证明实机通过。
- 保留当前工作区已有改动；不提交、不推送、不发送上游消息、不发布创意工坊；ds4 不在本轮范围内。

## Review Focus

1. 同一来源的满血提前返回与治疗后返回都必须被覆盖，治疗次数不能增加：Task 1 出口清单、Task 3 补丁结构检查、Task 6 实机治疗/伤害分离日志。
2. 前置 false 后再出现 true、异常、非法类型或快照篡改时，否决必须保留：Task 2 `false_then_true_error_invalid_and_mutation`。
3. 双人、双角色及嵌套伤害必须使用各自目标和调用上下文，返回后清空临时引用：Task 3 `nested_calls_restore_parent_and_target`、Task 4 `coop_candle_is_target_local`。
4. 部分补丁成功、来源漏审、DLL/脚本混装不得宣称 API 版本 1：Task 3 `incomplete_adapter_set_reports_zero`、Task 5 清单与候选构建检查。
5. 重复加载、卸载、续局及取得/失去黑蜡烛不得留下注册或改变已锁定分支：Task 2 卸载测试、Task 4 保存/当前玩家测试、Task 6 生命周期实机记录。

---

## 目录和固定基线

模组根记为 `M = E:/Isaac - Repentance/mods/neverbrith`。新原生源码根固定为 `N = M/worktrees/repentogon-yin-native/source`，构建根为 `M/worktrees/repentogon-yin-native/build`，工具根为 `M/worktrees/repentogon-yin-native/tools`。这三个目录不能作为游戏加载入口。新源码是独立第三方仓库；不要重置、搬移或切换当前脏的模组工作区。

- 上游：`https://github.com/TeamREPENTOGON/REPENTOGON.git`。
- 标签：`1.0.12a`；2026-10-02 只读 `git ls-remote` 返回提交 `4675b426d1ce7973595172984c366354e5bb66f9`。后续按提交取源，不浮动到 main 或最新版本。
- 游戏：`E:/Isaac - Repentance/isaac-ng.exe`；本轮调查 SHA256 为 `530B4D2ACCEF833B8DBF6F1A9F781FE1E051C1916CA5ACDB579DF05A34640627`。执行时重新检查；不一致则重新定位和审计。
- 编译器：`C:/Program Files/Microsoft Visual Studio/2022/Community`，已发现 MSVC `14.44.35207`、MSBuild、VsDevCmd 与 SDK `10.0.22621.0`。当前搜索未找到 CMake。
- CMake 固定使用官方 `v3.31.8` 的 `cmake-3.31.8-windows-x86_64.zip`，与同发布的 `cmake-3.31.8-SHA-256.txt` 校验；只在隔离工具根解压，不修改全局 PATH。
- 官方构建使用 `Visual Studio 17 2022`、`-A Win32`、`--config Release`。`ISAAC_DIRECTORY` 必须显式为空，禁止构建后自动复制到安装目录。
- 报告根：`reports/yins-curse/native-interface/2026-10-02/`。这里记录命令、退出码、源码身份和证据层级；没有运行的检查保持 `not_run`。

**Unverified — discovery required**：完整原版免爆出口、所有继续执行点和 ABI、回调数字编号、侧效果 helper 精确语义以及真实游戏表现。这些由 Task 1/3/6 查证；不向用户索取技术猜测。

## Task 1: 固定源码，闭合原生出口审计，取得未修改构建基线

**Files:**

- Create: `M/tools/build-yin-native.ps1`，仅获取固定源码/工具、配置、编译和记录，不安装。
- Create: `M/reports/yins-curse/native-interface/2026-10-02/source-manifest.json`。
- Create: `M/reports/yins-curse/native-interface/2026-10-02/immunity-sites.md`。
- Inspect: `N/libzhl/functions/EntityPlayer.zhl`，`N/libzhl/LuaCore.h`，`N/libzhl/ASMPatcher.hpp`，`N/repentogon/LuaInterfaces/CustomCallbacks.cpp`，`N/repentogon/Patches/ASMPatches/ASMCallbacks.cpp`，`N/repentogon/resources/scripts/enums_ex.lua`，`N/repentogon/resources/scripts/main_ex.lua`，`N/CMakeLists.txt`。

**Interfaces:**

- Consumes: 已确认规格、游戏 SHA256、固定源码 commit。
- Produces: `source-manifest.json` 含 `sourceCommit`、递归子模块提交、工具版本/校验和、`gameSha256`、`callbackId`、`coverageComplete` 和 `sites[]`。
- 每个 `sites[]` 记录 `sourceKey`、`siteKey`、`collectibleId`（可空）、保护原因、原生条件、特征字节/唯一匹配要求、栈/寄存器/标志位约束、允许/否决目标、副效果及关联证据。地址只作为固定 EXE 的调查结果。
- `build-yin-native.ps1 -Stage Baseline|Candidate` 使用固定目录，失败返回非零，输出构建日志与产物 SHA256；不能接受游戏目录作为输出路径。

- [x] **Step 1:** 获取固定 commit 和递归子模块，确认 `git rev-parse HEAD` 等于上述 commit；保存 `git submodule status --recursive`。获取 CMake 便携 ZIP、核对官方 SHA256 后解压。重读源码中的构建要求与自动复制分支，不用网站缓存内容覆盖固定 checkout。
- [x] **Step 2:** 从实际 TakeDamage 和相关爆炸保护入口追踪所有爆炸专属条件、提前返回及原生来源。起点为已发现的 Pyromaniac 满血/治疗路径和 Host Hat 免爆路径；检查所有剩余 flags 分支、调用者及非收藏品保护。将一般无敌、火焰保护、尚未产生伤害的拆弹等行为明确区分。只有清单闭合才写 `coverageComplete=true`。
- [x] **Step 3:** 对每个决策点说明同一次调用继续路径；核实纵火狂治疗 helper 和宿主帽反馈何时发生，记录混合火/爆炸标志的实际分支优先级。无法证实的点保持未验证，不编写猜测跳转。
- [x] **Step 4:** 全源检索回调编号、500 位 CallbackState、枚举、返回类型表和分派表，选择不冲突且在位图内的编号，记入 manifest。`MC_PRE_PLAYER_EXPLOSION_IMMUNITY` 是新符号；编号在这一步查证后锁定。
- [x] **Step 5:** 实现只构建脚本，运行未修改原生基线。核对生成 PE 为 x86、所有构建输出在隔离目录，保存命令/退出码和摘要。

基础配置/编译命令（由脚本使用已验证的便携 cmake.exe 调用）：

```powershell
& $yinCmake -S $yinSource -B $yinBuild -G 'Visual Studio 17 2022' -A Win32 -DCMAKE_BUILD_TYPE=Release -DISAAC_DIRECTORY:PATH=
& $yinCmake --build $yinBuild --config Release
```

通过条件：源码/子模块身份可复查，出口无未解释遗漏，callbackId 可用，baseline configure/build 退出码均为 0。构建失败时先解决实际工具/源依赖问题，不将其转换成玩法待定项。

## Task 2: 新回调枚举和独立 Lua 否决分派

**Files:**

- Modify: `N/repentogon/resources/scripts/enums_ex.lua`，新增唯一枚举。
- Modify: `N/repentogon/resources/scripts/main_ex.lua`，新增返回类型规则、独立分派函数与 `CustomRunCallbackLogic` 条目。
- Modify: `N/docs/docs/enums/ModCallbacks.md`，记录真实签名、短生命周期和 false 的专用语义。
- Create: `M/tests/native/repentogon_explosion_dispatch_test.lua`，加载固定 checkout 的真实分派代码，不复制其实现。

**Interfaces:**

- Consumes: Task 1 的 `callbackId`。
- Produces: `RunPlayerExplosionImmunityCallback(callbackID, param, player, hit, immunity)`，通过现有 `Isaac.RunCallbackWithParam`/原生 registry 分派，返回 `false` 表示累计否决，未否决返回 nil。
- 监听器签名：`handler(mod, player, hit, immunity)`。无过滤参数；按已有优先级/注册顺序执行。每个监听器收到独立的 hit/immunity 值快照；快照改写不改变原生参数或后续监听器看到的值。

- [x] **Step 1:** 编写 `all_listeners_and_priority_order`、`false_then_true_error_invalid_and_mutation`、`no_false_returns_nil`、`unload_removes_listener`。断言所有监听器均执行，false 后 true/nil/异常/数字/table 不恢复资格；非法返回有诊断；同优先级保留注册顺序；后续监听器看到原始快照值；卸载只移除所属 Mod。
- [x] **Step 2:** 运行 `lua tests/native/repentogon_explosion_dispatch_test.lua worktrees/repentogon-yin-native/source`，确认缺少新分派功能时失败。夹具加载真实相关迭代器/分派代码与原注册规则；需要的游戏对象为模拟值，报告标为离线分派测试。
- [x] **Step 3:** 在现有类型检查与分派表中接入新函数；累积 `veto = veto or ret == false`，不首个非 nil 返回。异常使用原有诊断路径，不能重置累计结果；对每个监听器复制快照字段。不要修改其他回调默认返回规则。
- [x] **Step 4:** 重跑测试至退出码 0，并验证既有 MC_ENTITY_TAKE_DMG 和默认首个非 nil 规则保持原行为。更新新回调文档，明确 true 不授予免疫。

## Task 3: 原生上下文、来源适配和能力版本

**Files:**

- Create: `N/repentogon/Patches/PlayerExplosionImmunity.h`，声明 hit、来源、RAII 上下文与公共决策接口。
- Create: `N/repentogon/Patches/PlayerExplosionImmunity.cpp`，原生桥接、调用作用域和能力状态。
- Create: `N/repentogon/Patches/ASMPatches/ASMExplosionImmunity.h` / `.cpp`，只实现 Task 1 审计的原生决策点。
- Modify: `N/repentogon/Patches/ASMPatches.cpp`，注册新适配入口。
- Modify: `N/repentogon/LuaInterfaces/CustomCallbacks.cpp` 的玩家 TakeDamage hook，围绕实际原生调用建立作用域；沿用其真实签名和既有 PRE 行为。
- Modify: `N/repentogon/LuaInterfaces/LuaIsaac.cpp`，注册能力查询。
- Modify: `N/CMakeLists.txt`，增加默认关闭的 `REPENTOGON_EXPLOSION_IMMUNITY_TESTS` 和独立测试目标。
- Create: `N/tests/explosion_immunity/context_test.cpp`、`N/tests/explosion_immunity/CMakeLists.txt`。
- Create: `M/tests/native/yin_native_patch_contract_test.ps1`，核对实际构建、源码 manifest 和补丁反汇编/结构证据。

**Interfaces:**

- `DamageHit`：`uint64_t callId; Entity_Player* player; float damage; unsigned long long flags; EntityRef* source; int countdown;`。
- `ImmunitySource`：`const char* sourceKey; const char* siteKey; std::optional<int> collectibleId;`，reason 向 Lua 固定输出 `EXPLOSION_IMMUNITY`。
- `DamageCallScope(Entity_Player*, float, unsigned long long, EntityRef*, int)`：构造推入独立上下文，析构恢复父调用；不可复制。
- `const DamageHit* GetCurrentDamageHit(const Entity_Player* player)`：只返回当前栈顶对应实际目标的上下文，不搜索父调用冒充本次命中。
- `bool IsExplosionImmunityAllowed(Entity_Player*, const ImmunitySource&)`：只有 Lua 累积有效 false 才返回 false；不能直接作为 TakeDamage 的返回值。
- `bool InstallPlayerExplosionImmunityPatches()`：预检查全部必需位置后接入；特征不唯一/不匹配时不得执行猜测写入。
- `int GetPlayerExplosionImmunityAPIVersion()` / Lua `Isaac.GetPlayerExplosionImmunityAPIVersion()`：完整原生来源适配和匹配的脚本分派可用时返回 1，否则返回 0。

- [x] **Step 1:** 编写 `nested_calls_restore_parent_and_target`，断言不同 callId、目标/参数独立、内层退出恢复父层、全部退出无引用；编写 `incomplete_adapter_set_reports_zero`，断言缺任何审计来源、错误特征或不匹配分派时能力不为 1。运行新增测试目标的最小独立构建，记录实际失败。
- [x] **Step 2:** 实现调用作用域与只读值快照桥接，按固定源中的 Lua 对象推送/栈恢复惯例处理 player、EntityRef 和 flags；注册 Lua 能力函数。原伤害 hook 的取消、调用次数、参数和返回结果保持其语义；桥接失败保留原生免疫并诊断。
- [x] **Step 3:** 按 Task 1 每条 site 的 ABI 实现局部适配：先保留应发生的原生副效果，再对该爆炸免疫出口调用公共决策函数。否决后进入清单证明的继续点，使下一个免爆来源、原伤害回调和非免爆保护仍执行。火焰、宿主帽投射物分支不接入本接口。
- [x] **Step 4:** 在写入前验证所有必要特征和继续点，保证失败时不留下活动的部分封锁；使用现有补丁管理器可验证的恢复方式，若不支持恢复则全部预检查成功后才写入。能力版本须同时核验来源清单与 Lua 分派身份，不能靠枚举存在返回 1。
- [x] **Step 5:** 编译测试/候选 DLL，执行 `ctest --test-dir worktrees/repentogon-yin-native/build -C Release --output-on-failure` 和 `pwsh -NoProfile -File tests/native/yin_native_patch_contract_test.ps1 -NativeRoot worktrees/repentogon-yin-native/source -BuildRoot worktrees/repentogon-yin-native/build`。检查每条覆盖、保存寄存器/flags/栈平衡和实际生成跳转；无订阅者沿原生结果分支。结构检查不写成实机副效果通过。

## Task 4: neverbrith 条件接入与缺失能力提示

**Files:**

- Modify: `M/yins_curse.lua`，替换当前原生接口 TODO，接入能力探测与监听器。
- Create: `M/tests/yins_curse_explosion_immunity_test.lua`。
- Preserve/regress: `M/tests/yins_curse_behavior_test.lua`、`M/tests/yins_curse_repentogon_test.lua`、`M/tests/yins_curse_damage_order_test.lua`。
- Modify: `M/docs/agent/index.md` 的本机制导航，`M/COMPATIBILITY.zh-CN.md`、`M/COMPATIBILITY.md` 的对应能力说明。

**Interfaces:**

- Consumes: `Isaac.GetPlayerExplosionImmunityAPIVersion() == 1`，新枚举及 Task 2/3 回调契约，既有 `getSavedState()`、`yinCurseActive` 和实际 player 的 `HasCollectible(BLACK_CANDLE_ID)`。
- Produces: `prePlayerExplosionImmunity(_, player, hit, immunity) -> false|nil`；已激活且实际目标无黑蜡烛时 false，其余 nil。只有能力和枚举均经核验才注册。
- 未启用时单次明确诊断；保留当前其他道具功能与依赖处理。不修改存档结构、品质 4 锁定、道具池、资源和属性。

- [x] **Step 1:** 新测试覆盖 `four_candle_immunity_combinations`、`inactive_never_vetoes`、`coop_candle_is_target_local`、`current_candle_does_not_change_q4_mode`、`continue_restores_run_activation`、`missing_partial_or_throwing_capability_does_not_register`。模拟原生“免疫资格继续”而非 false 取消伤害；不模拟出有黑蜡烛即免疫的错误规则。
- [x] **Step 2:** 运行 `& "$env:LOCALAPPDATA/Programs/Lua/bin/lua.exe" tests/yins_curse_explosion_immunity_test.lua`，确认新功能缺失时失败。
- [x] **Step 3:** 实现严格能力探测、无过滤注册和条件监听器；每次判定读取当前保存状态/实际目标黑蜡烛。回调不调用 TakeDamage、不改血、不保存原生引用。完善缺失能力提示与文档。
- [x] **Step 4:** 运行新测试及现有三个 Yin 测试至退出码 0；检查所有其他注册未改变，黑蜡烛获得/移除立即影响下一次判定，原存档可继续读取。更新旧测试中“尚未实现”的说明，明确缺失新能力的夹具只验证既有回退行为，保留原断言。

## Task 5: 候选构建、完整回归和可恢复交付

**Files:**

- Extend: `M/tools/build-yin-native.ps1` 的 Candidate 阶段。
- Modify: `N/repentogon/Version.h`、`N/repentogon/resources/scripts/main_ex.lua` 的候选身份，与 CMake 的 `CMAKE_REPENTOGON_VERSION` 参数一致。
- Create: `M/reports/yins-curse/native-interface/2026-10-02/candidate-manifest.json`、`checks.json`、`delivery.md`。
- Create: `M/release/yin-native-interface/2026-10-02/candidate/` 的本次原生产物与对应脚本、patch/source 清单和安装/恢复说明。

**Interfaces:**

- Consumes: Tasks 1–4 的固定源码、出口覆盖、接口测试和模块接入。
- Produces: 具备自定义构建身份的完整候选目录；manifest 记录相对文件、SHA256、源 commit、patch 身份、架构、API 版本、依赖和构建日志。与安装目录比较得出确切替换清单及原文件恢复清单。

- [x] **Step 1:** 给候选 native 与 `main_ex.lua` 一致的自定义版本标识 `1.0.12a-yin-api1-dev`，避免误报为官方原版；记录完整本地差异。使用 Candidate 阶段重新配置/编译，关闭自动部署。
- [x] **Step 2:** 重跑原生上下文/分派/补丁检查，再运行 `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath "$env:LOCALAPPDATA/Programs/Lua/bin/lua.exe" -ReportPath reports/yins-curse/native-interface/2026-10-02/checks.json`。记录真实退出码和原始警告，不以新增能力掩盖旧资源警告。
- [x] **Step 3:** 按固定源码的运行依赖制作完整候选目录；核对 DLL 架构与 Lua 脚本一致性，保存 checksum。无需替换的依赖也说明是否与已安装文件相同；不能仅复制 zhlREPENTOGON.dll 然后假定脚本自动更新。
- [x] **Step 4:** 写出确切安装文件清单、备份位置/校验要求、恢复步骤及游戏进程关闭条件。在授权替换已安装原生文件前展示这个候选和检查结果；不运行安装脚本、不自动启动游戏、不接触存档。未获得安装/实机证据时，delivery 状态必须是候选已构建或仍有失败，而非玩法完成。

## Task 6: 实机诊断和验收

**Files:**

- Create: `M/diagnostics/yin_explosion_immunity_acceptance.lua`，仅按显式诊断开关加载，无正常游戏逐命中日志。
- Create: `M/reports/yins-curse/native-interface/2026-10-02/game-acceptance.md`。
- Extend: `M/reports/yins-curse/native-interface/2026-10-02/delivery.md`。

**Interfaces:**

- Consumes: 已审阅候选、明确的本地安装授权、真实游戏环境。
- Produces: seed、玩家、启用 Mod、EXE/DLL hash、callId/sourceKey/siteKey、各监听器结果、治疗/免疫/实际伤害分别记录的证据；每格为 passed/failed/not_run。

- [ ] **Step 1:** 在候选可审阅后准备可选择测试场景的诊断脚本和用户测试卡，确认记录只观察同一次原生伤害，不额外补伤。日志字段与规格一致，正常游戏诊断默认关闭。
- [ ] **Step 2:** 取得安装授权后，先核对游戏关闭、EXE hash 和候选清单，备份实际被替换文件并核对 checksum，再仅替换清单内原生文件。失败时用已核验备份恢复；不能靠“再试一次”声称回滚完成。
- [ ] **Step 3:** 实测四种组合、诅咒未激活/无订阅者、纵火狂满血/缺血/火焰/混合标志、宿主帽投射物、多免爆来源、圣光斗篷和无敌帧。记录治疗调用和伤害调用，不能只凭最后血量判断治疗是否保留。
- [ ] **Step 4:** 实测普通伤害取消/修改链、新接口多监听器、合作/双角色/嵌套调用、黑蜡烛取得/失去、致死/复活/续局/状态回退，以及卸载和能力缺失。没有可执行实机接口或用户实测结果时，把对应项留为 not_run 并给出测试卡，不捏造通过。
- [ ] **Step 5:** 结合证据更新 delivery 和项目导航的实际实现状态；只将真正观察并记录的场景称为实机通过。明确发布与上游贡献尚未执行。

## 自检与执行方式

- 规格第 1/2/5 节由 Task 4/6 覆盖；接口返回链由 Task 2；全部原生出口、副效果与同次伤害由 Task 1/3/6；能力完整性由 Task 3/5；交付和安装边界由 Task 5/6。
- Task 1 的 callbackId/来源清单是后续原生和 Lua 注册的唯一输入；不提前捏造编号或“只有两个来源”的完整性结论。
- Task 2/3 的 nil/false 规则与 Task 4 一致；能力缺失时不注册。源路径、接口名、报告目录与验证命令前后一致。
- 计划不包含提交步骤，因为本任务没有提交授权。计划审阅前也不下载依赖、不创建原生工程或修改运行代码。
- 建议由当前会话连续实施（Native），因出口审计、ABI、分派和能力探测紧密相连；最后由新的审查者核对完整差异与证据。若选择逐任务子代理实施，则每个任务由新实施者/审查者完成后进入下一项。执行方式随用户审阅结果确定。

## 官方构建依据

- [固定 commit 的 README](https://github.com/TeamREPENTOGON/REPENTOGON/blob/4675b426d1ce7973595172984c366354e5bb66f9/README.md)。
- [固定 commit 的 CI 构建](https://github.com/TeamREPENTOGON/REPENTOGON/blob/4675b426d1ce7973595172984c366354e5bb66f9/.github/workflows/ci.yml)。
- [固定 commit 的 CMake](https://github.com/TeamREPENTOGON/REPENTOGON/blob/4675b426d1ce7973595172984c366354e5bb66f9/CMakeLists.txt)。
- [CMake v3.31.8 官方发布](https://github.com/Kitware/CMake/releases/tag/v3.31.8)。
