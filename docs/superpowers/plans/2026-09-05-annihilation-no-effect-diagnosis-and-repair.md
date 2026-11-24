# 诛 / Annihilation 不生效：诊断与修复实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: 使用 `superpowers:executing-plans` 按任务执行。原编写轮次只做诊断；用户后续已批准实施，以下原诊断证据保留，最新状态见本节与执行报告。

**执行状态（2026-09-05）：构造器、稳定身份、视觉失败隔离、owner清理与原生主副手充能已修改，并通过离线行为回归和分项独立审查。游戏内表现仍未验证，不宣称已在游戏里恢复。**

开发环境已由用户确认是普通 REPENTOGON 1.0.12a，不是＋，不升级。详见[诛执行报告](<E:/Isaac - Repentance/mods/neverbrith/reports/repentogon-item-optimization/annihilation-report.md>)、[原生充能报告](<E:/Isaac - Repentance/mods/neverbrith/reports/repentogon-item-optimization/native-core-report.md>)、[最终验收记录](<E:/Isaac - Repentance/mods/neverbrith/reports/repentogon-item-optimization/acceptance.md>)。

**Goal:** 找出“诛完全不生效”的运行时断点，恢复原有玩法合同，建立能识别引擎接口错误的回归测试。

**Architecture:** 保留现有 `annihilation.lua` 独立状态模块，先观察注册、使用、状态、伤害、视觉五个边界，再做最小修复。伤害来源、实体身份与视觉实例分别验证，不用一次大重构掩盖根因。

**Tech Stack:** Isaac: Repentance Lua、当前安装的 REPENTOGON、XML/ANM2、PowerShell、仓库现有 Lua 行为测试。

## 全局约束

- 工作目录：`E:\Isaac - Repentance\mods\neverbrith`；下文相对路径均相对于此目录。
- 原诊断轮次仅新增 Markdown；后续获授权实施已修改 Lua/测试，未启动游戏、未进行游戏内验收。
- 保留所有既有未提交改动，不替换整份 `main.lua`、注册 XML 或其他道具模块。
- 用户已改为默认依赖忏悔龙；不得为此次故障自行安装、升级或切换游戏版本。
- 用户称目标版本为“忏悔龙+ 1.1.12”；本地 `resources/scripts/main_ex.lua` 标记为 `1.0.12a`。执行前以本次启动日志及实际能力为准，不能只凭名称认定 API 可用。
- 维持原数值：8 格充能；初始 150 帧；光环半径 75、首次第 4 帧、此后每 4 帧、实时 Damage × 0.40；冲击波最大半径 115、实时 Damage × 1.00、同圈同敌最多一次；射程 × 0.45；射击频率 × 0.60；每名有效敌人死亡给所有已激活者各加 9 帧，没有延长上限。
- 保留 c356 车载电池合同：诛状态内按既定有效命中定义，主手和副手主动各充 1 格。修复伤害失效不能顺手改充能语义。
- 空房可用、正常消耗；重复激活不叠加；换房立即清理；主动被移除后不依赖 `HasCollectible` 错误取消已激活状态。

## 一、排查结论

**尚未在游戏内锁定“所有效果消失”的唯一根因。已通过离线反例确认一条会使伤害完全失效、并且不输出错误的代码路径；同时发现现有测试无法覆盖的状态身份和引擎视觉边界。**

不能把当前结论简化成“XML 没注册”或“ANM2 名字错了”，也不能把离线测试通过当作道具已正常工作。

### 1. 已核实：注册及静态接线存在

| 位置 | 当前证据 | 能证明什么 |
|---|---|---|
| `main.lua:59`、`:129` | `Annihilation` / `诛` 名称解析及 Items 字段存在 | 有道具 ID 解析入口 |
| `content/items.xml:352` 及中英文语言文件 | 主动、品质 3、8 格充能、`firedelay range` cache、`offensive` 标签、XML 本地 ID 53 | 静态注册存在；本地 ID 不是运行时 ID |
| `main.lua:20602` 附近 | `include("annihilation")` 后调用初始化器，传入 ItemId 和 3022/3023/3024 三个视觉 variant | 模块接线存在；不证明本次使用回调真的执行 |
| `annihilation.lua:450` | `MC_USE_ITEM` 处理器参数位置与此处注册方式相符 | 没有找到明显的使用者参数错位 |
| 最新可用日志第 87 行 | `Annihilation id=785 \| giveitem c785 \| spawn 5.100.785` | 那次启动成功解析 ID；不证明激活、伤害或渲染成功 |

日志来源：`C:\Users\Anton\Documents\My Games\Binding of Isaac Repentance\log.txt`，最后修改时间为 2026-09-05 12:27:21。检索 `Annihilation|error|stack traceback` 只出现上述 ID 记录，没有看到诛的使用/状态/伤害日志。该日志不是本次重新启动产生的故障复现记录。

另一个 `Binding of Isaac Repentance+\log.txt` 来自较早时间并提到 D 盘游戏目录，不能混用它证明当前 E 盘代码的故障。

### 2. 首要问题：伤害来源被错误的类型前置检查拦截

位置：`annihilation.lua:331–338`，`damageNpc`：

```lua
local source = type(EntityRef) == "function" and EntityRef(player) or nil
local ok, result = pcall(npc.TakeDamage, npc, amount, 0, source, 0)
```

问题链路：

1. “可调用”不等于 `type(...) == "function"`；带 `__call` 的对象同样可以作为构造器调用。
2. 若当前引擎公开的是这种构造器，代码不会构造来源，而是传入 `nil`。
3. `TakeDamage` 要求合法的 EntityRef 来源；严格接口会拒绝此调用。
4. `pcall` 捕获失败后只返回 `false`，没有输出错误，表现为“没有伤害，也看不到报错”。
5. 光环与冲击波共用 `damageNpc`，所以这条问题会同时影响两者伤害，也使依赖成功命中的充能联动无法触发。

API 文档确认构造及参数契约：[EntityRef 构造器](https://wofsauge.github.io/IsaacDocs/rep/EntityRef.html)、[Entity.TakeDamage](https://wofsauge.github.io/IsaacDocs/rep/Entity.html#takedamage)。文档本身不证明本次运行中 `type(EntityRef)` 的结果；**这一点仍需运行时读取**。

本次已进行不落盘的对照实验：保留生产模块不变，只在内存中增强原测试的 `TakeDamage` 来源校验，并分别使用普通函数和可调用表构造器。

```text
annihilation_behavior_test: ok
strict-function-control: true
strict-callable-table: false
frame 4 should deal 40% of current damage: expected 1, got 0
```

这是已复现的接口兼容缺陷，不是游戏内命中测试；它不能单独解释“连光环、射速变化也没有”的所有可能症状。

### 3. 待验证：跨回调直接以实体对象作为状态键

`runtime.states[player]` 同时用于使用、cache、泪弹替换和充能；房间 NPC 集合及每波命中集合也直接用 NPC 对象作键。

需要确认使用回调、cache 回调、`tear.SpawnerEntity:ToPlayer()` 等入口取得的包装对象，是否可以查回同一个 Lua 表项。若包装不同但底层实体相同，会出现“状态已创建，但射击/cache 回调认为没有状态”的情况。

**本次没有证明当前引擎确实发生了包装变化。** 不能仅凭这种风险就改掉整个项目的状态系统。现有测试始终重复使用同一个 Lua table 玩家/NPC，无法排除此问题。

### 4. 已核实的观察缺口：视觉失败与激活成功未区分

`spawnEffect` 在 `annihilation.lua:242` 附近：

- `Isaac.Spawn` 失败被捕获后可能直接返回 `nil`，没有记录具体失败原因。
- ANM2 Load/Play 抛错会记录日志，但没有足够信息证明实体、动画和显示位置确实有效。
- 实体字段赋值不全在保护边界内；当前假实体无法验证它们在原生对象上的行为。
- `startState` 先存入状态，再生成视觉；视觉返回 `nil` 不等于激活失败。于是“状态运行但没有图”与“使用根本没进回调”难以区分。
- 原测试注入假 `context.SpawnEffect`，绕过真正的 `Isaac.Spawn` 接口。

本次已解析三个 ANM2，名称对齐：

| Sprite:Load 路径 | 动画 | variant |
|---|---|---:|
| `gfx/Effects/Annihilation/AnnihilationAura.anm2` | `AuraLoop` | 3022 |
| `gfx/Effects/Annihilation/AnnihilationShockwave.anm2` | `Shockwave` | 3023 |
| `gfx/Effects/Annihilation/AnnihilationActivate.anm2` | `Activate` | 3024 |

对应磁盘文件在 `resources/` 下；注册位于 `content/entities2.xml`。这是 XML/命名检查，**未验证层级、脚底对齐、亮度、播放或实际生成**。不能因此把问题甩给贴图或 ANM2。

## 二、后续修复任务

### Task 1：先定位运行时断点，不先重写

**涉及文件：** `annihilation.lua`；仅在确认入口没有初始化时检查 `main.lua`。沿用现有 `debugLog`，诊断默认关闭，不持续刷屏。

- [ ] 在实际测试局读取构造器与运行时 ID；示例控制台 Lua 表达式如下，读取不改变状态：

```lua
print(type(EntityRef), type(Vector), Isaac.GetItemIdByName("Annihilation"))
local ok, value = pcall(function() return EntityRef(Isaac.GetPlayer(0)) end)
print(ok, type(value))
```

- [ ] 为初始化、使用入口、激活结果、首次 update、第 4 帧伤害、首次射击、结束原因各记一次结构化日志。使用日志包含解析 ID、玩家身份、使用标志、槽位、是否已有状态；不改回调参数顺序。
- [ ] 为现有 `pcall` 的失败分支记录一次错误原文及发生阶段，区分 `spawn`、`EntityRef`、`TakeDamage`、`sprite`。禁止每 NPC 每帧重复记录同一失败。
- [ ] 在正常使用时比较 `useItem`、`evaluateCache`、`postFireTear` 对同一底层玩家的状态命中结果；记录稳定实体标识与是否查到状态。不要只打印对象地址就断定身份不同。
- [ ] 明确分支：没有进入 use → 查 ItemId/模块初始化；进入 use 无 update → 查回调异常/状态清理；有状态无视觉 → 查原生 Effect；有调用无伤害 → 查来源、NPC 资格、伤害返回值。

**验收产物：** 一段可复现日志，能指出第一处失败边界。还没获得它时，不写“唯一根因已确认”。

### Task 2：修复伤害边界并补严格测试

**修改：** `annihilation.lua`、`tests/annihilation_behavior_test.lua`。

- [ ] 在现有测试中增加可调用构造器模式，并强制校验来源。核心夹具如下；必须保留正常函数模式作为对照：

```lua
EntityRef = setmetatable({}, {
    __call = function(_, entity)
        return { Entity = entity, diagnosticRef = true }
    end,
})
-- 放在测试 NPC 的 TakeDamage 开头：
assert(source and source.diagnosticRef, "TakeDamage requires EntityRef")
```

- [ ] 先运行原模块，确认增强测试失败于第 4 帧零命中，而非测试装配错误。
- [ ] 移除 `EntityRef` 的错误 `type == "function"` 前置门槛，采用实际调用结果判定。最小调用结构为：

```lua
local okRef, source = pcall(function() return EntityRef(player) end)
if not okRef or source == nil then
    -- 接入 Task 1 的单次错误记录，不伪造成功命中。
    return false
end
local ok, result = pcall(function()
    return npc:TakeDamage(amount, 0, source, 0)
end)
if not ok then
    -- 接入 Task 1 的单次错误记录，保留错误原文。
    return false
end
```

- [ ] 保留现有有效命中和 c356 充能定义；不得对失败或被取消的命中充能，不以删掉 `pcall` 让整个模块崩掉作为修复。
- [ ] 加入来源正确、伤害取消、接口抛错三类测试；确认光环、冲击波都走相同修复后的接口，伤害实时读取。

**验收：** 普通函数、可调用表两种严格夹具均通过；原始测试继续通过；游戏内敌人血量确实下降并能归因到使用者。

### Task 3：只在证据支持时修复状态身份与视觉边界

**修改：** `annihilation.lua`、同一行为测试；`main.lua` 或 `content/entities2.xml` 仅在查出实际错误时修改。

- [ ] 若 Task 1 证明同实体不同包装导致状态查找失败，为玩家状态引入统一身份入口。优先复用项目现有稳定 key；核对 `GetPtrHash`、实体数据和初始化种子，不能只用 ControllerIndex，避免双角色/合作模式串状态。
- [ ] 对所有状态入口统一应用同一规则，不能只修 `postFireTear`。若 NPC 也存在该问题，同时修正房间集合、每波命中集合和死亡去重，防止同敌被重复命中/延长。
- [ ] 增加“同一底层实体两个包装”和“同控制器不同实体”测试，分别断言状态命中与隔离；再验证换房清空、自然结束、重新开局、对象移除，避免旧 key 重用。
- [ ] 若没有包装问题，记录排除证据，保留当前身份实现，不做预防性大重构。
- [ ] 用原生 `Isaac.Spawn` 路径验证三个特效对象类型、variant、所播动画和生命周期。若必须使用 Effect 专有方法，先 `ToEffect()` 并检查结果，不能把所有字段错误都假设成动画问题。
- [ ] 视觉失败不应静默伪装为显示成功，也不应阻断已经成立的伤害状态；记录失败并独立修复。一次激活每名玩家只拥有一份 AuraLoop。
- [ ] 对半完成激活造成的异常做回滚：清理本次已创建视觉及状态，并刷新本次确实改动过的 cache，防止陷入“已有状态，拒绝再用”。只有证明确实存在该异常路径才改返回语义。

**验收：** 同一玩家各回调查到同一激活状态；另一玩家不受影响；原生特效实际显示且结束后移除。

### Task 4：按原合同完成回归，再考虑优化

**测试文件：** `tests/annihilation_behavior_test.lua`；不另建与正式模块脱节的演示实现。

- [ ] 初始恰为 150 帧，空房使用消耗 8 格、自然结束无退款；重复激活不创建第二套状态。
- [ ] 前 3 帧无光环命中，第 4 帧第一次，之后每 4 帧；中途改变 Damage，下一次结算立即采用新值。
- [ ] 保持射速换算 `(oldMaxFireDelay + 1) / 0.60 - 1` 与射程 `oldRange * 0.45`；开始/结束走 cache，结束精确恢复，不重复累乘。
- [ ] 基础泪弹真正被替换；同圈同敌一次、下一圈可以再次命中；不移除队友、使魔及无关攻击。
- [ ] 普通敌人和 Boss 死亡各加 9 帧，只结算一次，重复死亡可无限延长；非敌对实体不算；所有当前激活者各加 9 帧，未激活者不创建状态。
- [ ] c356：每次既定有效命中主/副手各充 1 格；无物品槽、满充能、被取消伤害及电池二次使用不产生错误计费/额外激活。
- [ ] 过门、换层立即清理状态和临时属性；丢掉/重掷主动不能导致已启动状态泄漏或提前错误取消。

验证命令，均在项目根目录执行：

```powershell
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\luac.exe' -p annihilation.lua
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests/annihilation_behavior_test.lua
& '.\docs\skills\isaac-validators\scripts\validate-isaac-mod.ps1' -Root . -ModObjectName Neverbirth
& '.\docs\skills\isaac-neverbrith-validator-profile\scripts\validate-neverbrith.ps1' -Root .
& 'C:\Users\Anton\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe' diff --check
```

执行前阅读对应验证器技能，核对脚本是否仍为当前项目入口。预期：Lua 语法无错误、行为测试通过、两类验证器没有新增失败、diff 无新空白错误。既有无关告警单独列出，不能顺手修其他模块。

## 三、游戏内验收：当前全部未验证

| 场景 | 必须留下的证据 |
|---|---|
| 空房使用 | 使用前后充能、激活日志、150 更新后清理日志；画面有光环 |
| 普通战斗房 | 75px 光环边界及敌人碰撞体进入范围时的 HP 变化；第 4 帧节奏 |
| 射击替换 | 角色中心扩散的 115px 冲击波、同圈一次命中、没有残留普通泪弹 |
| 临时属性 | 开启前、开启中、结束后面板与 cache 值；射频 60% 而非延迟简单加 40% |
| 击杀续时 | 玩家/使魔/炸弹/状态伤害/Boss 的死亡都延长；密集死亡不截断 |
| 换房与重掷 | 过门立即消失；主动被移除仍按当前房状态生命周期结束 |
| 合作及 c356 | 两位玩家状态隔离，同一死亡延长所有激活者；主副手每命中各充 1 |
| 视觉稳定性 | 暗房、弹幕多、不同体型，脚底对齐且不挡主要画面，结束不残留 |

如果无法控制游戏，本轮交付只能写“自动测试通过，游戏内未验证”，不得写“完全修好了”。

## 四、本次实际执行与交接

已执行：

- 阅读正式注册、模块接线、伤害/状态/视觉实现、行为测试及最新可用日志。
- `luac -p annihilation.lua`：通过。
- `lua tests/annihilation_behavior_test.lua`：`annihilation_behavior_test: ok`。
- 内存增强测试：严格普通函数构造器通过；严格可调用表构造器失败，第 4 帧应有 1 次命中，实际 0 次。
- 三个 ANM2 XML 解析通过，动画名与代码一致。

未执行：生产代码修复、测试文件落盘修改、完整通用/专用验证器重跑、游戏内复现、升级引擎。没有提交 Git commit。

后续开始执行时，先完成 Task 1 的运行时分段证据，再处理已复现的伤害接口缺陷。不要先实施总优化计划中的原生充能重构；“恢复现有功能”先于“替换架构”。

相关总计划：`docs/superpowers/plans/2026-09-05-neverbrith-repentogon-optimization.md`。本文件是诛失效专项诊断，不代表总计划已启动。
