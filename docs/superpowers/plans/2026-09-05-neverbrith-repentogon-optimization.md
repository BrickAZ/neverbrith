# Neverbrith 忏悔龙 / 忏悔龙＋道具优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. 用户后续已授权按顺序执行；执行范围不包含安装游戏更新、提交、推送或发布。下方原始任务合同保留为设计记录，最新决策及状态以执行结果表和验收记录为准。

**Goal:** 在不改变用户已锁定玩法、数值、资源与道具池的前提下，使用实际运行环境支持的 REPENTOGON 功能替换高风险兼容写法，逐件完成自动回归和游戏内验收。

**Architecture:** 保留现有根目录 Lua 模块和 `main.lua` 的组织，不进行全模组重构。依次改进同次伤害、原生生命归属、有效受伤记账、充能、真实拾取与缓存；新版接口通过独立能力核验后再接入。技术探索与确定性改造分开，未通过游戏验证的方案不能替换已验证路线。

**Tech Stack:** Binding of Isaac、REPENTOGON / 用户称“忏悔龙＋”的新版环境、Lua、XML、现有 Lua 行为测试、PowerShell 验证器。

**状态（2026-09-05）：当前普通 REPENTOGON 1.0.12a 可支持部分已完成代码、受控回归与最终审查；总计划未全部完成，所有游戏内验收均未验证。**

执行记录：[总验收](<E:/Isaac - Repentance/mods/neverbrith/reports/repentogon-item-optimization/acceptance.md>)、[进度](<E:/Isaac - Repentance/mods/neverbrith/reports/repentogon-item-optimization/progress.md>)、[接口与实验边界](<E:/Isaac - Repentance/mods/neverbrith/reports/repentogon-item-optimization/experiments.md>)。

最新用户决策覆盖原方案：开发环境是普通忏悔龙，不是忏悔龙＋；肉块保留挡下致命伤，不执行 P2 的先死亡再复活迁移。诛与神风失效修复已先行执行。P1 最终审查发现的倍伤/致命挡伤顺序问题已修正为EARLY注册，真实注册排序12组合通过，最终独立复审Approved（仅代码层）。

## Global Constraints

- 工作目录固定为 `E:\Isaac - Repentance\mods\neverbrith`。
- REPENTOGON 是用户已确认的前置，不重新询问是否允许使用，不新增无需求的纯原版降级机制。
- 用户补充：存在其称为“忏悔龙＋、1.1.12”的更高版本，并说明新版兼容原忏悔龙。以兼容新版为目标，但不把口头版本名称直接当成具体接口已验证证据。
- 本次本地文件证据：`E:\Isaac - Repentance\resources\scripts\main_ex.lua` 声明 `1.0.12a`；这是磁盘文件记录，不代表其他启动路径或之后更新的进程版本。
- 本次可核实的官方新增接口记录使用 `1.1.0`、`1.1.2` 等标签；直接查询官方 `1.1.12` 发布标签返回 404。保留用户说法，不擅自改写为其他版本；执行时通过实际运行日志、`REPENTOGON.Version` 和对应发布/提交记录解决这一技术差异，不要求用户重新决定功能设计。
- 向后兼容旧模组，不等于旧环境拥有新版接口；本计划也不承诺 1.0.12a 可以执行全部新版功能。
- 不安装、更新、降级游戏或忏悔龙，不改变启动参数、配置及其他模组；需要此类操作时另获授权。
- 不改品质、充能、道具池、权重、伤害倍率、次数、延长上限、食物门槛或已确认的二选一规则。
- 保留所有已有未提交改动。只用 `apply_patch` 修改目标文件；不执行 `git reset --hard`、整文件恢复或批量暂存。
- 不重新注册已被用户取消注册的模组角色，不改贴图、音频、ANM2，除非某个验收发现资源合同确实阻塞且用户批准资源修改。
- 每玩家状态与来源归属必须独立；房间状态不能意外变成本局状态，永久标记也不能因移除道具被清除。
- 不将 `MC_POST_ADD_COLLECTIBLE` / `FirstTime` 等同于真实底座拾取；不将伤害后回调出现等同于非零生命损失。
- 静态、模拟 Lua、原生回调探针和真实游戏验收分开报告；未执行的测试一律标记“未验证”。
- EID 只同步已经实现并证明的效果，不把版本限制说明塞成长篇玩家文案，不提前宣称真 3 FPS 或真崩溃。
- 不使用忙等、耗尽 CPU、外部强退、内存破坏或存档破坏实现 ACE 的惩罚。

---

## 1. 实际文件地图与拆分方式

这是一个总计划，各任务作为独立小批次执行；不得一次改完全部道具后才测试。下面位置以 2026-09-05 审查为索引，执行前用函数名重新定位，不依赖旧行号。

| 文件 | 相关机制 / 定位点 | 允许的改动边界 |
| --- | --- | --- |
| `E:\Isaac - Repentance\mods\neverbrith\main.lua` | ACE `playerDamage` / `npcDamage`；`HandleEmptyCradleDamage`；`HandleBlackTaisuiDamage`；肉块生命函数；椰子、美工刀、流量、鸿运、狗粮 | 只改当前任务负责的函数、回调和必要接线；不拆整个入口 |
| `E:\Isaac - Repentance\mods\neverbrith\ring_of_the_seven_curses.lua` | `OnEntityTakeDamage`、底座补偿、禁用品和保护数量 | 首批只改伤害；Q4 保留与额外补偿流程不动 |
| `E:\Isaac - Repentance\mods\neverbrith\revive_my_love.lua` | `triggerDeath`、`syncExtraLife`、可见性与控制恢复 | 作为已有原生生命路线的回归基准，不再次推倒重写 |
| `E:\Isaac - Repentance\mods\neverbrith\annihilation.lua` | `chargeActiveSlot`、`damageNpc`、状态与射击替换 | 改原生充能接入及可确认的命中记账；保持状态合同 |
| `E:\Isaac - Repentance\mods\neverbrith\big_dog_bark.lua` | `captureFoodPickup`、`settleFoodPickups` | 拾取确认；保留冲刺、扑咬、回响、输入和声音状态机 |
| `E:\Isaac - Repentance\mods\neverbrith\memory_disorder.lua` | `reconcileTemporaryCopies`、`removeTemporaryComponents`、`addTemporaryCollectible` | 新版分组能力迁移；主动、口袋、生命账本单独保留 |
| `E:\Isaac - Repentance\mods\neverbrith\kamikaze_squad.lua` | `triggerExplosion`、自爆与 owner 标记 | 仅迁移已确认的爆炸来源和范围控制；不复制原版 AI |
| `E:\Isaac - Repentance\mods\neverbrith\yins_curse.lua` | `decideExplosionDamage`、`playerDamage` | 提前爆炸免疫与禁防爆可行性核验；不改 Q4 路线快照 |
| `E:\Isaac - Repentance\mods\neverbrith\night_of_the_cowards.lua` | c20 赠送、恐惧状态视觉、光环跟随 | 仅作为回归边界，不随此次迁移重写视觉或撤回 c20 |
| `E:\Isaac - Repentance\mods\neverbrith\content\items.xml`、`items.en_us.xml`、`items.zh_cn.xml`（同目录） | 生命标签、后期固定属性注册 | 仅在对应阶段确有需要时同步三份；不改 ID、池归属 |
| `E:\Isaac - Repentance\mods\neverbrith\tests\` | 现有独立 Lua 行为测试 | 扩展对应测试；不要只添加搜索源码字符串的断言 |

后续执行时新建的证据文件：

- `E:\Isaac - Repentance\mods\neverbrith\reports\repentogon-item-optimization\environment.md`：实际构建、能力和签名表。
- `E:\Isaac - Repentance\mods\neverbrith\reports\repentogon-item-optimization\baseline.md`：现有差异、测试基线与已存在警告。
- `E:\Isaac - Repentance\mods\neverbrith\reports\repentogon-item-optimization\acceptance.md`：每批自动结果、实机矩阵及未验证项。
- `E:\Isaac - Repentance\mods\neverbrith\reports\repentogon-item-optimization\experiments.md`：禁防爆、低频更新、精确权重的探索结果。

这些报告已在后续获授权的执行轮次创建；其内容严格区分源码、静态、Lua 测试与未进行的游戏验收。

## 2. 分期顺序与版本门槛

| 批次 | 内容 | 前提 |
| --- | --- | --- |
| P0 | 环境、当前差异和测试基线 | 所有任务之前 |
| P1 | ACE ＋ 七咒之戒同次伤害 | 1.0.12a 已有相关 Lua 分发证据，仍核验当前进程 |
| P2 | 肉块生命管理；Revive My Love 回归 | 原生 revive 标签和死亡回调 |
| P3 | 空摇篮、黑太岁有效受伤；ACE 有效命中次数 | 同版本伤害前后时序和取消语义 |
| P4 | 诛原生充能与联动归属 | `AddActiveCharge`，当前 1.0.12a 文档已有 |
| P5 | 大狗叫、椰子、美工刀、流量拾取事件 | 添加/移除回调＋真实来源合同 |
| P6 | 鸿运缓存与清房事件 | 普通自定义缓存；新版本才有完整房间 POST clear 时需区分 |
| P7 | 记忆紊乱分组临时能力 | 1.1.2 系列分组能力及需要的修复补丁 |
| P8 | 神风特攻队原版爆炸范围接入 | 1.1.2 系列 `MC_PRE_BOMB_DAMAGE`，原生来源实測通过 |
| P9 | 狗粮系列固定属性 XML | 1.1.0 起原生 XML 属性，计算阶段对照通过 |
| P10 | 阴的诅咒 / ACE 更新限制 / 七咒权重实验 | 独立探针；有证据才进入生产实现 |
| P11 | 组合回归与最终交付 | 逐项证据，不以通过一项推定全部通过 |

未取得新版环境证据时，可继续 P1–P6 中已证实支持的部分；P7–P10 中依赖新接口的实现暂停，不猜签名、不偷偷回退为旧模拟方案。不要为一个后期实验把整个模组的最低版本无理由提高。

## 3. 通用命令与结果要求

以下是**稍后执行**的命令，不代表计划编写时已运行。PowerShell 中先设置真实路径：

```powershell
$root = 'E:\Isaac - Repentance\mods\neverbrith'
$lua = 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe'
$luac = 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\luac.exe'
$git = 'C:\Users\Anton\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe'
Set-Location -LiteralPath $root
& $git status --short
& $git diff --check
```

单批测试运行模板（逐个替换为本任务明确列出的测试文件）：

```powershell
& $lua (Join-Path $root 'tests\ace_anti_cheat_behavior_test.lua')
if ($LASTEXITCODE -ne 0) { throw 'ACE regression failed' }
& $luac -p (Join-Path $root 'main.lua')
if ($LASTEXITCODE -ne 0) { throw 'Lua syntax failed' }
```

通用与 Neverbrith 专用验证器：

```powershell
& 'C:\Users\Anton\.codex\skills\isaac-validators\scripts\validate-isaac-mod.ps1' `
    -Root $root -ModObjectName 'Neverbirth' -LuaDirectories @('.') `
    -ResourceDirectories @('resources', 'resources-dlc3')
& 'C:\Users\Anton\.codex\skills\isaac-neverbrith-validator-profile\scripts\validate-neverbrith.ps1' -Root $root
& $lua (Join-Path $root 'tests\localization_test.lua')
& $git diff --check
```

执行前读对应 validator 技能；资源目录参数应与 P0 实际目录一致，不将不存在目录的警告藏起来。目标是相关测试退出码 0、Lua 可解析、无新增相关验证失败、当前批次差异无空白错误。已有不相关失败单列基线，不把它们抹掉，也不声称整库全绿。

---

## Task P0：确认真实目标环境和基线

**Files:** 只读根目录及上表文件；执行时新增 `reports\repentogon-item-optimization\environment.md`、`baseline.md`（绝对父目录见文件地图）。

**接口合同：** 输出游戏构建、启动路径、`REPENTOGON.Version` 原文、官方 tag/commit、每个计划接口的最早支持版本/必要修复、签名证据、实机状态。其他任务只消费该表已确认的能力。

- [ ] 保存 `git status --short` 及目标文件现有 diff，区分用户改动与本轮后续改动。
- [ ] 对实际启动环境读取版本和日志。不能因为一个旧目录仍有 `1.0.12a` 就否定用户另外安装的新版，也不能仅靠目录名称断言加载了新版。
- [ ] 将用户“1.1.12 / 忏悔龙＋”称呼与官方版本对照；兼容结论分为“旧 API 仍存在”“返回/时序兼容”“实机回归通过”，不合并为一句全兼容。
- [ ] 核查 `MeetsVersion` 对字母补丁和 dev build 的行为；存在符号不是签名或原生语义证据。不通过生成实体、扣血等变更来探测接口是否存在。
- [ ] 运行上节通用命令及各任务关联测试作为基线，在 `baseline.md` 记录退出码和已有失败。
- [ ] 检查入口能否在缺少必需前置时提前停止初始化并显示一次清晰提示；若缺失，先写门禁测试，再按现有入口加入最小检查。Lua 检查不能替代新版 XML 的加载版本约束。

只读进程内版本探针内容：

```lua
Isaac.DebugString('[Neverbrith audit] REPENTOGON=' .. tostring(REPENTOGON and REPENTOGON.Version))
Isaac.DebugString('[Neverbrith audit] postDamage=' .. tostring(ModCallbacks.MC_POST_ENTITY_TAKE_DMG))
Isaac.DebugString('[Neverbrith audit] preBomb=' .. tostring(ModCallbacks.MC_PRE_BOMB_DAMAGE))
```

**放行条件：** 有可追溯环境表；当前版本不支持的任务明确延后。没有游戏控制入口时记录“实机环境探针未验证”，不伪造输出。

## Task P1：ACE 与七咒之戒改写同一次伤害

**Modify:** `E:\Isaac - Repentance\mods\neverbrith\main.lua` 中 ACE `playerDamage`；`E:\Isaac - Repentance\mods\neverbrith\ring_of_the_seven_curses.lua` 中 `OnEntityTakeDamage`。

**Test:** `E:\Isaac - Repentance\mods\neverbrith\tests\ace_anti_cheat_behavior_test.lua`、`E:\Isaac - Repentance\mods\neverbrith\tests\ring_of_the_seven_curses_behavior_test.lua`。

**接口合同：** 保留当前资格筛选，返回 `{ Damage = amount * 2 }`；不改来源、标志、倒计时，不再次调用 `TakeDamage`。本任务不更改 ACE 惩罚，也不更改七咒底座补偿。

- [ ] 在现有测试中增加“伤害回调不得递归调用玩家 TakeDamage”的失败断言。以抛错的 `TakeDamage` stub 检查，而非只搜索源码。
- [ ] 按实际回调签名调用当前处理器，输入伤害 1、2，应分别返回 2、4；输入 0、不持有、未激活应不改写。
- [ ] 将已有资格判断后的重放块替换成以下返回，不保留失效的重放深度分支作为第二套入口。

```lua
return { Damage = amount * 2 }
```

- [ ] 模拟多个回调顺序：下游收到已修改金额；任一回调返回 false 时整次取消。ACE 与七咒同时生效时记录并验证两个独立 x2 按合同组合，不擅自加互斥。
- [ ] 运行两份测试、`luac -p` 两文件及差异检查。必要时更新旧测试中“必须重入一次”的过时实现断言，保留玩家效果断言。
- [ ] 实机验证半心→一心、一心→两心；护盾/无敌帧不产生额外二次受击，献血与受伤触发次数未被放大。

**放行条件：** 一次伤害只有一条原生结算链；金额、标志、来源、取消行为与组合倍率有证据。

## Task P2：肉块独占生命来源，Revive My Love 保持回归

**2026-09-05 决策覆盖：用户要求保留现有挡伤。以下原生真复活迁移步骤不执行，保留为原方案历史；不修改肉块或 Revive My Love 生产代码。**

**Modify:** `E:\Isaac - Repentance\mods\neverbrith\main.lua` 肉块授予、消耗、恢复、轮询与隐藏 1UP 函数；必要时同步三份 `content\items*.xml`。

**Test:** `E:\Isaac - Repentance\mods\neverbrith\tests\folk_horror_items_behavior_test.lua`、`E:\Isaac - Repentance\mods\neverbrith\tests\revive_my_love_behavior_test.lua`。

**接口合同：** 肉块的当前可用生命由本道具自己的原生生命来源表示；保留原有次数/血量合同。不能删除玩家真实 c11，不把黑太岁的致命伤保护改成真复活。

- [ ] 从现有 EID、存档及测试提取肉块次数和血量语义，加入“同时持有真实 1UP，消耗肉块后 1UP 不变”“双人互不消耗”的失败测试。
- [ ] 注册并解析肉块独有的生命载体；可优先选择自有 null 的 `revive` 标记，运行 ID 必须由实际配置查得，不使用原版 c11 代替。不猜本地 ID 或复用别的道具 null ID。
- [ ] 在已验证死亡顺序中让该来源负责消费与复活；消费失败不返回成功。删除与此职责重复的“推测致命→取消原伤害”和死亡后重复轮询；其他合法挡伤来源继续独立存在。
- [ ] 用旧存档肉块生命数重建一次原生标记，存档计数和原生计数只保留一个消费 owner；迁移幂等，继续游戏不能多授予生命。
- [ ] 运行两份测试及三语 XML/本地化验证；记录原版生命优先于或晚于肉块的实际顺序，不隐瞒顺序差异。
- [ ] 实机覆盖肉块、真实 1UP、Revive My Love 单独及组合，Keeper / Lost / Forgotten 安全存活回退；验证死亡动画、复活房间不重置、角色可见且控制恢复。

**放行条件：** 原版生命不被借用/误删；原有行为合同无暗改；Revive My Love 现有状态机未回归，包括用户此前反馈的“以撒消失”。若原生顺序要求改变已锁定玩法，停止该项并报告冲突，不自行决定。

## Task P3：有效受伤和敌人有效命中计数

**Modify:** `E:\Isaac - Repentance\mods\neverbrith\main.lua` 的空摇篮、黑太岁受伤入口和 ACE `npcDamage` / `settleAllPending`。

**Test:** `E:\Isaac - Repentance\mods\neverbrith\tests\empty_cradle_behavior_test.lua`、`folk_horror_items_behavior_test.lua`、`ace_anti_cheat_behavior_test.lua`（同一 tests 目录）。

**接口合同：** PRE 捕获本事件快照，POST 依据同版本原生时序确认，确认后才提交资格/计数。若 POST 运行时 HP 尚未提交，使用源代码证实的事件结算位置，不把多个候选统统对比同一份下一帧 HP。

- [ ] 加入取消伤害、零伤害、护盾、同帧“一次取消＋一次有效”、同帧两次有效、重入、致死事件去重等失败用例。
- [ ] 用每实体事件序号/调用栈维护快照，仅保留未结束事件；帧末清理孤立候选，不能把没有 POST 的候选当成有效伤害。
- [ ] 空摇篮只有确认有效承伤才设置 `usedThisFloor/pending/damageType`；第二次被取消的受伤不得降级已存奖励。
- [ ] 黑太岁只有确认有效损失才增加受伤寄生值；治疗、容器变化和致命保护仍按原有独立来源处理。
- [ ] ACE 同一有效非零事件仅加 1，实际接受 1 次后死亡才算一击；Boss、小 Boss 仍按其已有排除规则，单房第 3 次一击击杀惩罚不改。
- [ ] 运行三份测试；实机同时启用任意伤害取消来源和多次伤害来源，核对日志中的事件序号、有效次数及奖励变化。

可执行测试输入矩阵须包含：

```lua
local cases = {
    { before = 10, after = 10, canceled = true,  expected = 0 },
    { before = 10, after = 10, canceled = false, expected = 0 },
    { before = 10, after = 7,  canceled = false, expected = 1 },
    { before = 3,  after = 0,  canceled = false, expected = 1 },
}
```

此矩阵只表达账本预期；不能用假设立即扣血的 stub 来“证明”真实 POST 时序。

## Task P4：诛使用原生主动充能

**Modify:** `E:\Isaac - Repentance\mods\neverbrith\annihilation.lua`。

**Test:** `E:\Isaac - Repentance\mods\neverbrith\tests\annihilation_behavior_test.lua`。

**接口合同：** 激活者持有 c356 时，每次符合原合同的命中，主手和副手各加 1 格；不充队友、不充口袋、不引入超充或强制给特殊主动充电。`AddActiveCharge` 返回实际增加量供记录，不以“调用没抛错”代表增加成功。

- [ ] 增加测试：普通双槽、满充、空槽、动态最大充能、另一玩家、无 c356、同一圈重复碰撞。
- [ ] 保留资格条件，替换手算 `SetActiveCharge` 核心为：

```lua
local added = player:AddActiveCharge(1, slot, true, false, false)
return (tonumber(added) or 0) > 0
```

- [ ] 对 `damageNpc` 的返回语义做同版本核查，取消/无效攻击不误发奖励；不得把充能范围扩展到使用者所有无关攻击。来源构造使用可调用性契约，不仅凭 `type(EntityRef) == "function"` 排除合法构造器。
- [ ] 跑完整诛测试，保留 150 帧、75/115 半径、每 4 帧、实时 Damage、死亡 +9 帧无上限、射程 x0.45、频率 x0.60、过门清理等现有断言。
- [ ] 实机双主动、双玩家、车载电池及多发射击组合验收；既不残留普通泪弹，也不因同一圈多次检测重复充能。

**放行条件：** 充能量与归属完全保持，原生 HUD 反馈真实出现，未意外开启超充。

## Task P5：分四个小批次迁移拾取确认

**Modify:** `E:\Isaac - Repentance\mods\neverbrith\big_dog_bark.lua` 和 `E:\Isaac - Repentance\mods\neverbrith\main.lua` 对应道具代码。

**Test:** `E:\Isaac - Repentance\mods\neverbrith\tests\big_dog_bark_behavior_test.lua`、`condom_utility_knife_behavior_test.lua`、`dog_food_series_behavior_test.lua`、`little_leather_shoes_behavior_test.lua`（同一 tests 目录）。

**接口合同：** 添加事件只确认入库；底座碰撞候选负责来源。按当前版本真实签名取得 player，过滤真实/临时/初始来源；一笔拾取事务最多消费一次。不得复制一个通用“数量 +1 就奖励”的错误假设到所有道具。

| 小批次 | 需要保留的判定 | 必增测试 |
| --- | --- | --- |
| P5a 大狗叫 | 本局真实拾取 TAG_FOOD；同种重复真实拾取重复计数；达到 4 永久解锁；先食物后大狗有效 | 初始、读档、缓存、代码赠送不加；双人独立；真实拾取 3→4 正确解锁 |
| P5b 疯狂的椰子 | 正常底座实际拾取与自然攻击力前后差，不能改成“增加攻击标签” | 同 ID 不同自然攻击结果；无攻击收益应奖励，有实际攻击收益不奖励；掉落消失但未入库不奖励 |
| P5c 美工刀和狗粮一次性收益 | 添加事件与旧数量追踪只保留一个结算 owner；准确区分重复实际获得 | 同次回调＋后续更新不重复加收益；继续游戏不重新治疗或授予永久属性 |
| P5d 流量三个衍生 | 原底座/选择组记录，曝光与热度二选一，触发后正常移除 | 选一后另一消失；移除事件不再次触发；两位玩家来源不串 |

- [ ] 按 P5a→P5d 顺序，每小批先增加对应失败用例，运行指定现有测试确认失败原因。
- [ ] 将 `MC_POST_ADD_COLLECTIBLE` 接入当前模块的事务确认函数，使用回调过滤减少无关调用；仅在相关 API 缺少可靠来源的地方保留有界候选，不每帧重新推断全背包。
- [ ] 用事务的 `resolved` 标记及来源实体身份去重；换房清除未提交临时候选，保存正式食物/永久收益记录。
- [ ] 每小批跑对应测试和本地化测试，通过后再处理下一批，不同时更改四套流程。
- [ ] 实机测试商店付款、免费底座、换主动落下物、重骰、继续游戏及双人同房拾取；观察奖励只结算一次。

**放行条件：** “真实获得”语义更可靠，不能仅因减少代码量牺牲来源判定。七咒之戒落地 D6 的排除规则不受影响。

## Task P6：鸿运缓存；未剪断脐带与空摇篮清房事件

**Modify:** `E:\Isaac - Repentance\mods\neverbrith\main.lua` 的幸运来源签名更新、脐带清房推进、空摇篮奖励结算。

**Test:** `E:\Isaac - Repentance\mods\neverbrith\tests\condom_utility_knife_behavior_test.lua`、`uncut_cord_behavior_test.lua`、`empty_cradle_behavior_test.lua`（同一 tests 目录）。

**接口合同：** 鸿运仍取已登记、当前持有来源要求的最高幸运值；只优化失效与重算，不改变白名单/最高阈值。脐带延后偿债本来就属于另一伤害事件，不能套用 P1 去消灭所有后续 `TakeDamage`。

- [ ] 增加拥有/移除收藏品、饰品、金饰品倍率、动态 resolver、继续游戏的缓存测试；无变化的若干帧不得反复排序签名。
- [ ] 采用命名自定义缓存 `neverbrith_fortune_required_luck`；相关变化后标脏并求值，最终 Luck 仍按现有 `max(当前幸运, 所需幸运)` 合成。
- [ ] 对动态 resolver 逐项记录其依赖；道具数量不变但依赖变化时仍必须失效，不能声称仅添加/移除回调覆盖一切。
- [ ] 房间奖励按实际版本选择 clear 入口：1.0.12a 可用 PRE 仅用于排队，之后确认房间真的清空才结算；新版 POST clear 可直接提供更准确的事件通知。不能在 PRE 中预发奖励。
- [ ] 运行三份测试；实机覆盖波次房、重复 clear 通知、已清房返回、付债失败和取消伤害。每房计数只能增加一次。

## Task P7：记忆紊乱的新版分组能力

**Modify:** `E:\Isaac - Repentance\mods\neverbrith\memory_disorder.lua`。

**Test:** `E:\Isaac - Repentance\mods\neverbrith\tests\memory_disorder_behavior_test.lua`。

**接口合同：** 只将实际适用的临时被动能力移入 `neverbrith.memory_disorder` 来源组；角色类型、生命、主动槽、口袋、固有专属行为不自动视为等价。

- [ ] P0 确認分组添加/移除/计数接口以及回调修复存在，读取同 tag 的数量查询语义；旧 `AddInnateCollectible(id, amount)` 不能冒充新版分组 API。
- [ ] 给每个现有角色 profile 分类：可迁移被动能力、真实主动槽、口袋物、生命资源、引擎自动赋予组件。形成 profile 对照表后才修改授予。
- [ ] 添加失败测试：玩家原有同 ID、迁移期间又拾取同 ID、第三方另一 group、角色往返、读档、沙漏、双玩家；移除本组后其他来源完整保留。
- [ ] 可迁移部分使用明确分组，清理只指定本组；不要全局清空所有 innate。

```lua
local GROUP = 'neverbrith.memory_disorder'
player:AddInnateCollectible(itemId, amount, GROUP, -1, true)
local owned = player:GetInnateCollectibleCount(itemId, GROUP)
player:RemoveInnateCollectible(itemId, owned, GROUP)
```

- [ ] 制作已有运行数据的幂等迁移：仅迁移能证明属于本机制的临时份数；无法区分来源的旧数据不得靠删同 ID 猜测解决，保留该状态并报告，不吞用户永久道具。
- [ ] 跑完整 profile 测试；实机至少覆盖普通红心、魂心、骨心角色转换、双人、沙漏及继续游戏。特殊角色未测就不宣布全角色兼容。

**放行条件：** 可迁移能力不再靠同 ID 数量差认领；不能因为引入 group 就放弃生命账本和槽位快照。

## Task P8：神风特攻队原版爆炸入口

**Modify:** `E:\Isaac - Repentance\mods\neverbrith\kamikaze_squad.lua`。

**Test:** `E:\Isaac - Repentance\mods\neverbrith\tests\kamikaze_squad_behavior_test.lua`。

**接口合同：** 原版 Mulliboom、友好爱心、90 帧生成、每玩家上限 2、追踪与残局自爆不改。一次爆炸，原版伤害，实际半径 x2，玩家仍走原版防护。

- [ ] 首先做可移除探针：记录自然 Mulliboom、自有棉花怪、玩家炸弹的原生爆炸 source、damage、radius；确认自有 owner 在爆炸入口仍可识别。
- [ ] 加测试：仅标记自有来源半径 x2，普通 Mulliboom 与其他炸弹原样；重复回调不二次翻倍；同次爆炸不追加第二次 `BombExplosionEffects`。
- [ ] 只有来源追溯被证实时，在 `MC_PRE_BOMB_DAMAGE` 对当前事件返回半径变更：

```lua
-- 在已确认本事件来源属于本道具之后；未匹配返回 nil。
return { Radius = radius * 2 }
```

- [ ] 分别核对爆炸伤害、视觉、推力及 TearFlag 范围。需要其他范围回调时必须同事件归属，不能扩大不相关爆炸。
- [ ] 原生 source 若为 nil 且无可靠身份，保留旧生产路径，不按位置近似误认爆炸。将证据写入 experiments，不包装为迁移完成。
- [ ] 自动测试通过后，实测普通追敌与清房两种自爆，测量两个距离档、双方玩家防爆/护盾/无敌帧，确保只有一次伤害。

## Task P9：狗粮系列固定属性迁移

**Modify:** `E:\Isaac - Repentance\mods\neverbrith\main.lua` 狗粮固定 cache 部分及三份 `content\items*.xml`。

**Test:** `E:\Isaac - Repentance\mods\neverbrith\tests\dog_food_series_behavior_test.lua`、`localization_test.lua`（同一 tests 目录）。

**接口合同：** 高蛋白肉条、活力狗饼干、轻盈低脂罐头、DHA 鱼油、护齿磨牙骨、幸运肝粒、羊奶布丁逐个评估；仅迁移能证明等价的固定持有属性。拾取治疗、食物记录、击退等仍由对应机制拥有。

- [ ] 为每条属性记录当前加算/乘算阶段、每份叠加方式、射速上限、移除行为，建立迁移前基准输出。
- [ ] 使用同版本原生 XML 文档和属性计算实现确认字段映射；`damage/flatdamage`、`tears/flattears` 不互换。不能准确等价的属性保留 Lua。
- [ ] 添加单份、多份、移除、角色伤害倍率、伤害倍率道具、射速上限及临时效果的前后相等测试；纯 stub 不足以证明原生顺序。
- [ ] 每次只迁移一条已确认等价的字段，并删除这条属性对应的 Lua 贡献，防止 XML＋Lua 双倍生效。三语注册使用相同数值。
- [ ] 跑狗粮及本地化测试；实机对照迁移前面板和实际发射节奏，误差不是零且无法解释时撤销当前新改动，不能改数值凑面板。

## Task P10：三个独立可行性实验

**Files:** 对应生产模块先只读；实验代码仅在后续明确启用的开发验证入口执行；证据写入 `E:\Isaac - Repentance\mods\neverbrith\reports\repentogon-item-optimization\experiments.md`。

### P10a 阴的诅咒

- [ ] 先扩展 `E:\Isaac - Repentance\mods\neverbrith\tests\yins_curse_behavior_test.lua`：黑蜡烛免疫先于圣光斗篷；每玩家独立，失去黑蜡烛立即停止额外免疫。
- [ ] 在真实回调入口验证 `MC_PRE_PLAYER_TAKE_DMG` 的取消语义，必要时只将黑蜡烛免疫迁至更早入口。此回调不能通过返回 true 强迫原生免疫失效。
- [ ] 分别检验宿主帽、纵火狂和项目内免疫实现；只有找到不移除道具、不禁掉其他功能、不追加第二次伤害的原生方案才实现禁防爆。
- [ ] 未找到方案就保留“原版/第三方覆盖未完成”的明确结论；禁止用整体 `BlockCollectible` 冒充只禁爆炸免疫。

### P10b ACE 安全低频更新

- [ ] P0 证明新版 `MC_PRE_UPDATE` 的返回契约后，测量更新/渲染/真实时间三种计时，不把 NPC 减速当低帧率。
- [ ] 以单调真实时间控制释放更新，不能在被暂停的 POST_UPDATE 中等待结束计时，否则会自锁；同房连续触发只刷新 5 秒。
- [ ] 验证暂停菜单、失去道具、过门、全队死亡和模组错误后的恢复；没有独立恢复路径就不接生产。
- [ ] 报告实际实现是低频更新还是渲染锁帧；未测得真实 3 FPS 就不能这样命名。此计划不执行进程强退，不新增耗 CPU 循环，当前已确认全队死亡合同独立保留。

### P10c 七咒之戒三件诅咒道具权重 x2

- [ ] 从已批准规格与注册确定三件目标的真实 ID 和池归属，不根据名字猜第三件。
- [ ] 比较原始权重、当前剩余权重、耗损、移除阈值、预览与真实抽取；核查临时池接口的运行与沙漏恢复语义。
- [ ] 用固定种子、池耗损记录及抽样分布证明是否真正权重翻倍。简单再抽一次或增加重复条目不是证明。
- [ ] 必须保持当前 Q4 合同：原 Q4 留在底座且不可拾取，额外补偿可拾取；原底座被重骰成新 Q4 可再次补偿，变成 Q3 则可拾取；角色换下的 D6 不参与。实验不得改全局抽取结果来绕开这些规则。
- [ ] 无精确方案时记录失败条件，保留该权重目标未完成；不添加暗中抽取次数上限当最终效果。

## Task P11：组合回归与交付

**Files:** 所有本计划实际修改文件；更新 `E:\Isaac - Repentance\mods\neverbrith\reports\repentogon-item-optimization\acceptance.md`。

- [ ] 对所有已修改 Lua 单独 `luac -p`；运行所有受影响行为测试和 `localization_test.lua`，记录命令、退出码与测试数量，不引用以前的通过记录。
- [ ] 运行两套验证器及 `git diff --check`；将新增问题与基线既有问题分开。未跟踪新文件也要单独检查，不能只依赖普通 diff。
- [ ] 实机组合矩阵逐项记录：ACE＋七咒、伤害取消＋空摇篮/黑太岁、肉块＋1UP＋Revive My Love、诛＋c356＋双槽、记忆紊乱＋同 ID 永久收藏品、大狗食物＋狗粮/代码赠送、七咒＋Q4 重骰、神风＋各种爆炸保护。
- [ ] 所有相关道具至少覆盖双人归属、移除/重骰、换房/换层、退出继续、新局清理；涉及时长/沙漏/角色转换者补专项。
- [ ] EID 与中英文本只同步已实现机制；不修改不相关措辞，不将未验证实验描述成正式效果。
- [ ] 自审差异，只保留本计划改动。不要自动 `git add .`、提交、推送或发布；若用户另行要求提交，按实际任务文件及改动块暂存。

### 最终结果表（执行时逐行填写）

| 批次 | 静态 | Lua 模拟 | 原生/实机 | 剩余风险 | 状态 |
| --- | --- | --- | --- | --- | --- |
| P0 环境 | 磁盘/日志/前置核验 | 门禁14类用例通过 | 进程探针未验证 | 普通1.0.12a；无运行中的游戏 | 代码与基线已落地 |
| P1 同次伤害 | 语法/复审通过 | 倍率/取消及真实注册排序12组合通过 | 本机Lua分发器已测；游戏未验证 | 第三方更晚priority及C++扣血待测 | 代码落地，待游戏验收 |
| P2 生命归属 | 已审查冲突 | RML旧回归14项通过 | 未验证 | 用户选择保留挡伤 | 不执行真复活迁移 |
| P3 有效伤害 | 已审查同版本时序 | 未实施新账本 | 未验证 | POST不等于HP已提交，缺逐事件证据 | 技术暂停 |
| P4 诛充能 | 语法/接口核验通过 | 主副槽及失败边界通过 | 未验证 | 特殊主动实际HUD/命中归属 | 代码落地，待游戏验收 |
| P5 拾取事件 | 来源边界已审查 | 大狗反例opt-in预期失败 | 未验证 | 碰撞＋同ID代码赠送无法证明拾取来源 | 无生产迁移；b-d未越序 |
| P6 缓存/清房 | 鸿运语法/复审通过 | 新缓存及旧鸿运合同通过 | 未验证 | 清房付债依赖P3；实际库存/沙漏待测 | 仅鸿运缓存落地 |
| P7 临时能力 | 版本门槛已核验 | 无迁移 | 未验证 | 当前版本缺计划所需来源组合同 | 暂缓 |
| P8 原版爆炸 | 当前无PRE_BOMB_DAMAGE | 基础神风修复通过，原生迁移未做 | 未验证 | 固定40/RadiusMult2非实测证明 | 暂缓原生半径迁移 |
| P9 XML 属性 | 当前不满足新字段版本 | 无迁移 | 未验证 | 属性计算阶段等价性 | 暂缓 |
| P10 可行性 | 接口与限制已记录 | 未执行进程内实验 | 未验证 | 全禁防爆/安全低频/精确权重均未获证 | 不宣称实现 |

## 4. 明确保留、不借迁移重写的机制

- 大狗叫已有跟随、蓄力条、取消未满蓄力、扑咬、回响、水迹与声音播放，只做专项回归。
- 胆小鬼之夜保留用户要求的 c20 方案，恐惧圈/玩家状态视觉另按真实渲染问题处理，不视为“用了忏悔龙自动修复”。
- Revive My Love 已有原生死亡回调、额外生命标记和动画状态机，P2 只要求防回归与必要的独立修复，不强制重做。
- 七咒永久规则、Q4 留底座＋额外补偿和饰品栏图标不因重写伤害而变化。
- 流量曝光与热度二选一、原 Boss 奖励门槛不改；不迁移到另一套随机奖励设计。

## 5. 证据来源与执行入口

- [本地 REPENTOGON 版本文件](<E:/Isaac - Repentance/resources/scripts/main_ex.lua>)：本地审查基线。
- [1.0.12a 玩家接口](https://raw.githubusercontent.com/TeamREPENTOGON/REPENTOGON/1.0.12a/docs/docs/EntityPlayer.md)：当前旧版主动充能、自定义缓存及旧 innate 签名。
- [官方回调文档](https://repentogon.com/enums/ModCallbacks.html)：阅读时必须与真实 tag/commit 对齐，不混合版本签名。
- [1.1.0 发布说明](https://github.com/TeamREPENTOGON/REPENTOGON/releases/tag/1.1.0)：原生 XML 属性、新增清房等接口。
- [1.1.2 发布说明](https://github.com/TeamREPENTOGON/REPENTOGON/releases/tag/1.1.2)：分组临时能力、原生爆炸和更新前控制。
- [分组能力当前文档](https://repentogon.com/EntityPlayer.html#addinnatecollectible)：来源隔离、持续时间与存档语义；不是当前本地版本已具备的证明。

稍后用户要求执行本计划时，先完成 P0，再从 P1 开始；每批完成后更新结果表。若某批只剩实机条件不足，应报告精确未验证项，可以继续不依赖该项的安全任务，但不能将其标记完成。

**原计划编写阶段只交付 Markdown；后续执行阶段的真实修改与验证以 acceptance.md 为准。本轮没有升级任何游戏组件，没有修改美术资源，没有进行提交或发布。**
