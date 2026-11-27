# 检查与证据

框架静态约束和实际本地包的构建/隔离验证，见[框架与包验证](framework-verification.md)。

## 统一入口

在模组根目录用 PowerShell 7 调用 [check-neverbrith.ps1](../../tools/check-neverbrith.ps1)：

```powershell
# 默认试点：四个历史夹具问题、启动/前置/本地化、记忆紊乱相关 Lua 测试
pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile Pilot

# 全部 tests/*_test.lua；仍不等于所有语言和全部 PowerShell 测试
pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll

# Lua 不在 PATH 时显式指定；报告路径相对模组根目录，写文件仅在指定时发生
pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile Pilot -LuaPath (Get-Command lua -CommandType Application -ErrorAction Stop).Source -ReportPath reports/local-checks/pilot.json
```

入口使用 Lua 5.4。优先使用显式 `-LuaPath`，否则查找当前 `PATH`，再尝试当前用户的 `Programs/Lua/bin/lua.exe`。不会安装运行器或修改全局环境；显式路径无效时不会偷偷换另一个解释器。沙箱拒绝启动属于环境阻塞，不能当作测试失败或测试通过。

每个子进程默认最多运行 60 秒，可用 `-TimeoutSeconds` 调整；超时终止该子进程树并报告失败。测试以模组根目录为工作目录，逐文件使用独立 Lua 进程。

## 两种范围共同包含什么

- 根目录、`generated/` 和 `tests/` 直接包含的 Lua，以及 `scripts/`、`tests/support/` 递归包含的 Lua 文件语法解析；不执行被解析的源码，不扫描嵌套工作树。
- 所选 Lua 行为测试。`Pilot` 的明确列表由检查脚本维护；`LuaAll` 发现 `tests/` 直接包含的 `*_test.lua`，发现零个测试必须失败。
- 项目[通用验证器](../../tools/validators/validate-isaac-mod.ps1)、[严格验证器](../../tools/validators/validate-neverbrith.ps1)。严格验证器内部对生成道具登记使用 `-Check`；Skill 包来源是 `.agents/skills`。
- [知识检查](../../tests/project_knowledge_test.ps1)：检查项目导航/API 页面可达与链接、共享模块用法覆盖、有效 Skill 入口及项目评估上下文。它不证明每项接口语义正确或 AI 实际遵循规则。
- [My Stuff 专项检查](../../tools/validate_mystuff_local_ids.ps1)、[README 检查](../../tests/compatibility_docs_test.ps1)的 `-ReadmeOnly` 分支，以及[知识导航检查](../../tests/agent_wiki_navigation_test.ps1)。

这些配置不会自动运行其他 PowerShell、Python、Node 测试、资源生成器、语言切换、工作簿写回或上传脚本。它们也不调用完整兼容示例测试或入口自测。按改动选择额外检查，不把 `LuaAll` 写成“整个项目全部检查通过”。

[公共完整入口夹具](../../tests/support/neverbirth_fixture.lua)提供测试环境和真实 `main.lua` 加载，返回回调记录、道具 ID 和 EID 调用；测试应显式调用该夹具，不再执行或截取本地化测试来建立环境。旧专项夹具通过 [REPENTOGON 夹具](../../tests/repentogon_test_fixture.lua)实际加载从主文件迁出的 `scripts/` 模块，避免把新路径静默替换为空函数。[首批加载检查](../../tests/batch1_loading_test.lua)包含缺失模块和重复回调反例。

Lua 测试可能用 `io.tmpfile()` 构造原生对象边界的模拟值，因此不能统称为完全不写磁盘。语法检查使用临时 UTF-8 文件清单避免 Windows 命令行长度上限，运行后清理；报告的 `InputFiles` 保留实际解析清单。指定 `-ReportPath` 会创建或覆盖该 JSON 报告；记录每项命令参数、输出、退出码、耗时和警告数量。

## 如何判断结果

原生商店价格探针需要同时考虑 `Price`、`ShopItemId` 和 `AutoUpdatePrice`：
普通房间中 `Isaac.Spawn` 的免费底座不能只赋一个正价格就当作正常商店槽位。
本机 `Morph(..., KeepPrice=true)` 会保留立即价格，但重新开启自动定价；
价格应在后续更新和实际购买后核验。正常价格与折扣测试优先使用引擎生成的商店槽位；
若夹具确实需要固定自定义价格，由夹具在 Morph 后恢复它自己的定价策略，不在道具回调中全局锁价。
具体复现、修正探针与运行命令见 [Condom 价格专项诊断](../../reports/condom-price/2026-11-26/delivery.md)。

| 状态或退出码 | 含义 |
| --- | --- |
| `passed` | 该子检查实际运行并返回成功；仅覆盖所选范围 |
| `failed` | 测试、语法、缺失检查文件、零测试或超时等失败 |
| `blocked` / `not_run` | 运行器或启动条件不满足；不能记作通过 |
| 总退出码 `0` | 本次选择的检查全部通过，警告仍需阅读 |
| 总退出码 `1` | 至少一个检查失败；报告同时保留其他阻塞情况 |
| 总退出码 `2` | 无已执行失败，但存在阻塞或未运行项 |

## 严格验证器的扫描范围

| 检查 | 实际读取范围与边界 |
| --- | --- |
| 回调与实体名称查询 | 从所选 `-Root` 的 `main.lua` 开始，递归跟随直接、静态字符串形式的 `include` 和本地 `require`；注释和字符串示例不作为加载指令。条件分支内的加载也纳入清单，循环引用只扫描一次。 |
| 历史副本与工作树 | 不递归枚举整个仓库；未被入口加载的 `outputs/`、`reports/`、`release/`、`diagnostics/`、`tmp/`、工作树、测试及未使用模块不参加上述 Lua 检查。若入口明确加载其中的文件，该文件仍会检查。独立副本可另选 `-Root` 验证，需具备所需生成登记检查入口。 |
| 无法静态确定的加载 | 动态参数、无法解析的模块字面量、未知外部 `require` 会警告扫描范围不完整；缺失的入口或明确 `include` 文件报失败。游戏提供的 `json` 单独列为外部模块。加载器别名、替换和运行时修改加载路径不在追踪能力内。 |
| 内容与资源 | 继续检查 `content/` 直接包含的 XML、实体至 ANM2/贴图链、卡牌字段、道具池语言一致性与生成登记。`deathanm2` 相对其 XML 所在的 `content/` 目录解析，不能用 `resources/` 中的同名文件代替。 |
| 游戏原生资源 | 普通资源先查模组；未命中时只检查选定游戏目录中已解包的 `resources-dlc3/`、`resources-dlc2/`、`resources/`。必须找到实际文件才能记为 `Native asset found`；只证明文件存在。 |
| Skill 包 | 检查有效 `.agents/skills/` 的元数据、评估 JSON 与相对参考；不读取历史 `docs/skills/` 作为当前指令，不修改 Skill。官方 HTTPS 引用允许存在，本机绝对路径仍会报告。 |

严格验证器会打印本次 Lua 文件清单、外部模块和游戏资源查找目录。回调检查仍只识别已有的直接 `Neverbirth:AddCallback(..., Neverbirth.Handler, ...)` 形式及相应函数声明，不是完整 Lua 语义分析，也不能证明回调在运行时只执行一次。

若模组位于 `游戏目录/mods/模组目录`，且父级存在 `isaac-ng.exe`，可自动定位游戏目录；独立副本可直接调用严格验证器并传入 `-GameRoot` 指定游戏安装目录。显式目录无效会报失败；没有可用的解包目录时，原生资源标为未验证，未解析引用继续警告。不会解包游戏、下载资源或修改任何资源文件。

通用验证器同样按声明 XML 所在 content 目录解析 `deathanm2`，并支持自动定位或显式 `-GameRoot` 查找解包原版资源；只有实际文件存在才能消除对应警告。两份验证器仍各自保留原始输出，资源存在性不等于游戏渲染通过。修改该路径规则时运行 `pwsh -NoProfile -File tests/generic_validator_assets_test.ps1`，检查有效路径、缺失反例、错误位置、目录伪装成文件及停用归档隔离。

自定义角色目前暂停开发：`content/players.xml` 不登记角色，正式入口不加载角色玩法；未被运行登记引用的旧角色资源暂留，不作为缺失资源补全任务，也不扫描历史/归档目录来制造告警。仍由正式道具使用的死亡图标和原版 Breakfast 贴图继续按实际路径检查，不因角色停用而跳过。

## 修改—检查—修复

1. 阅读所属专题、实际源码和最接近的测试，记录原有工作区状态。
2. 运行最小相关检查，保存修复前的真实失败，先区分玩法缺陷与测试夹具不完整。
3. 只改问题所有者或确实缺失的夹具契约；保留原断言，不吞异常、不跳过待测回调。
4. 重跑目标测试；再按影响范围运行 `Pilot` 或 `LuaAll` 及专项检查。
5. 核对差异和未触及文件，报告失败、警告、未运行项以及实机验收步骤。

修改检查入口本身时额外运行：

```powershell
pwsh -NoProfile -File tests/check_neverbrith_runner_test.ps1 -LuaPath (Get-Command lua -CommandType Application -ErrorAction Stop).Source
```

该自测在独立临时目录用真实子进程检验成功、失败传播、源码语法错误、运行器缺失、超时和零测试等情况，最后清理自身目录。

修改严格验证器的扫描或资源查找规则时，额外运行[范围与资源反例测试](../../tests/strict_validator_scope_test.ps1)：

```powershell
pwsh -NoProfile -File tests/strict_validator_scope_test.ps1
```

该测试用独立临时夹具检验历史副本隔离、真实重复和缺失处理函数、加载边界、资源位置与游戏资源可用/不可用情形；生成登记器在夹具中只验证 `-Check` 调用，真实生成登记另由项目验证器检查。它不包含在 `Pilot` / `LuaAll` 的自动选择列表中。

修改 Skill 来源或验证器转发入口时，额外运行[来源与转发检查](../../tests/skill_source_validation_test.ps1)：

```powershell
pwsh -NoProfile -File tests/skill_source_validation_test.ps1
```

它检查有效包中的 HTTPS 链接被接受、本机绝对路径被拒绝、旧归档不会替代有效包，以及新旧验证入口保留成功和失败退出码；不包含在 `Pilot` / `LuaAll` 的自动选择列表中。

## 实机证据

模拟接口验证逻辑与调用契约；原生渲染、输入、碰撞、音频、回调实际时序、真实存档继续及第三方 Mod 组合仍需对应实机验证。每次报告必须列出实际执行的层级；测试通过不得自动更新用户确认的可玩状态。

稳定的排错方法按需读取[测试排错 Skill](../../.agents/skills/isaac-testing-debugging/SKILL.md)与[验证 Skill](../../.agents/skills/isaac-validators/SKILL.md)。本页维护项目入口，具体机制规则由有效 Skill 维护；来源说明见 [Skill 权威来源](skill-authority.md)。
