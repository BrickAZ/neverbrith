# 神风特攻队 / Kamikaze Squad 不生效：诊断与修复计划

> **For agentic workers:** REQUIRED SUB-SKILL: 使用 `superpowers:executing-plans` 按任务执行。原编写轮次仅做排查与 Markdown；用户后续已批准实施，以下原诊断证据保留，最新状态见本节与执行报告。

**执行状态（2026-09-05）：稳定owner身份、90帧计时/每人2只、目标锁定、原生NPC转换和一次安全爆炸调用已修改，离线回归及分项审查通过。游戏内生成/爱心/追击仍未验证；固定40与RadiusMult2不是已测量原版伤害和实际双倍半径的证明，外部致死爆炸路径也仍待验证。**

详见[神风执行报告](<E:/Isaac - Repentance/mods/neverbrith/reports/repentogon-item-optimization/kamikaze-report.md>)、[接口实验边界](<E:/Isaac - Repentance/mods/neverbrith/reports/repentogon-item-optimization/experiments.md>)、[最终验收记录](<E:/Isaac - Repentance/mods/neverbrith/reports/repentogon-item-optimization/acceptance.md>)。环境固定普通 REPENTOGON 1.0.12a，不升级。

**Goal:** 修复神风特攻队始终不生成的首要失效链路，并恢复锁定追击、单次原版爆炸及每玩家独立上限合同。

**Architecture:** 保留 `kamikaze_squad.lua` 作为唯一机制 owner，优先修正实体身份与计时状态的关联，再处理独立的目标锁定偏差。原版 NPC、友好状态与爆炸 API 的引擎边界单独验证，不制作新实体、美术或复制原版 AI。

**Tech Stack:** Isaac Repentance Lua、项目现有 REPENTOGON 环境、原版 Mulliboom、XML、现有 Lua 行为测试、PowerShell。

## 全局约束

- 项目根目录：`E:\Isaac - Repentance\mods\neverbrith`；文中相对路径均相对于此处。
- 原诊断轮次只新增 Markdown；后续获授权执行修改 Lua/测试，不改 XML/PNG，不运行游戏，不提交 Git commit。
- 以后执行时保留所有既有未提交改动；不为本次问题升级引擎或重构其他道具。
- 品质 0、被动、`offensive summonable`、道具房与贪婪道具房维持现有注册。
- 有有效敌人时每持有者独立累积 90 帧，生成 1 只；每持有者最多同时 2 只，上限时暂停生成计时。无有效敌人停止新生成。
- 使用原版 Mulliboom、原版永久友好/爱心表现；不得影响自然生成或其他来源的同类实体。
- 生成后锁定最近有效敌人；目标有效时保持锁定，失效才重选；极近距离或清房时自爆。
- 一次完整爆炸，原版伤害、原版半径的 2 倍；所有玩家可以被波及，爆炸免疫、护盾、无敌帧等仍走引擎语义。不做直接扣心或双重爆炸。
- 不跨房跟随；换房、换层、新局、继续、玩家死亡及实体移除均清理其临时跟踪。不新增存档状态。

## 一、结论与证据等级

**当前最可信的“不生成”原因是：每帧重新取得玩家包装，却直接以玩家对象作表键保存计时；旧包装被误判为已离开的玩家，状态反复重建，90 帧计时无法累积。**

已用未修改的正式模块做离线对照，复现了“300 帧仍不生成，计时停在 1”。这证明了该代码对包装变化的失效，不等同于已经在当前游戏进程内读取到相同断点；游戏内最后一步确认仍未完成。

另有一个已复现的玩法偏差：追击目标每帧重选，违背“锁定后只在失效时重新锁定”。它不是零生成的原因，必须与首要故障分开修复。

### 1. 注册、拾取与模块接线存在

| 位置 | 已核实的内容 |
|---|---|
| `main.lua:60`、`:130` | `Kamikaze Squad` / `神风特攻队` 名称解析及 `Items.KamikazeSquad` |
| `main.lua:20617` | include 正式模块并传入 `ItemId`、`GetPlayers`、`DebugLog` |
| `content/items.xml:354` | 被动、本地 ID 54、品质 0、正确标签及图标名 |
| `content/items.en_us.xml`、`content/items.zh_cn.xml` | 对应中英文注册存在 |
| `content/itempools*.xml` | 普通 treasure 和 greedTreasure 条目存在 |
| `resources/gfx/Items/Collectibles/KamikazeSquad.png` | 当前注册使用的图标文件存在 |
| 最新可用游戏日志 | 解析运行时 ID 786，且有玩家获得该收藏品的记录 |

日志：`C:\Users\Anton\Documents\My Games\Binding of Isaac Repentance\log.txt`，最后修改时间 2026-09-05 12:27:21。第 84 行记录 ID；第 294、299、332 行记录将 `786 (Kamikaze Squad)` 加给玩家。

这些证明那次启动的注册和获得流程存在，**不证明生成 update 被执行**。日志中没有匹配到该模块的错误堆栈，也没有持有者计时、生成尝试或清理原因日志。本模块收到 `context.DebugLog`，却没有实际使用它。

本地 ID 54 与运行时 ID 786 不可混用；以后测试应重新解析 ID，不能永久硬编码 786。

### 2. 首要失效链：对象表键导致计时反复清零

相关代码：

- `main.lua:919` 的 `GetPlayers()` 每次调用 `Isaac.GetPlayer(index)`，并可能再次 `ToPlayer()`。
- `kamikaze_squad.lua:112`：`runtime.holders[player]` 保存状态。
- `:286–302`：以当帧对象建立 `seenPlayers[player]`，再清理不在此表的旧 owner。
- `:320–324`：只有留下的 state 才累加 timer，达到 90 后生成。

失效过程：

```text
第 1 帧：包装 A → 创建 state(A) → timer = 1
第 2 帧：同一玩家的新包装 B → 创建 state(B)
        seenPlayers 中没有 A → clearHolder(A)
        state(B).timer = 1
后续每帧重复 → 永远到不了 90 → 不生成 NPC
```

Isaac API 文档明确区分“同一底层实体”与“不同 Lua 引用包装”，建议用底层指针标识比较实体：[GetPtrHash](https://wofsauge.github.io/IsaacDocs/rep/GlobalFunctions.html#getptrhash)。本项目的用法直接依赖包装相同，因此不是安全的身份策略。当前安装版本的实际取值仍需短探针复核。

本次内存对照没有修改生产文件，只将测试的 `GetPlayers` 改为每次返回访问同一玩家数据的新代理：

```text
原始行为测试：kamikaze_squad_behavior_test: ok
严格包装测试：frame 90 should spawn one Mulliboom: expected 1, got 0

stable wrapper:
frames=300 spawned=2 remaining holder timer=0
fresh wrapper:
frames=300 spawned=0 remaining holder timer=1
```

原测试的 `GetPlayers = function() return players end` 永远返回同一组 Lua table，掩盖了这个边界。

### 3. 独立缺陷：写入了目标，却不读取它来维持锁定

`kamikaze_squad.lua:260` 的 `updateOwnedUnit` 每次先运行 `nearestHostile(unit.Position)`，再覆盖 `data[TARGET_KEY]`，没有“原目标仍有效则继续”的分支。

本次对照：先锁定 A，保持 A 存活，再加入更近的 B。结果：

```text
valid target replaced before death=true
now targets nearer enemy=true
```

因此目标切换不只发生在死亡/失效后。此处只需恢复锁定规则，不应给怪物添加新 AI、移动速度或额外攻击机制。

### 4. 爆炸链路：参数顺序存在依据，但原版等价性尚未证明

已核实：

- 本机 `E:\Isaac - Repentance\resources\entities2.xml:983` 注册 `Mulliboom` 为 type 16、variant 2，原版 ANM2 为 `016.002_Mulliboom.anm2`；collisionDamage 为 0。
- 正式模块生成 `(EntityType.ENTITY_MULLIGAN, 2, 0)`，随后 `AddCharmed(EntityRef(owner), -1)` 及 FRIENDLY 标记；没有注册自定义 NPC。
- `detonate` 先置已结算标记，再 `Remove()`，随后调用一次 `Game():BombExplosionEffects(...)`，意图避免 Kill 带来的原版第二次爆炸。
- 本机 `resources/scripts/main.lua:526–529` 的 Lua 包装签名与模块参数顺序相符。`DamageSource=true`、`DAMAGE_EXPLOSION` 被传入，不能无依据归因为爆炸参数错位。
- [BombExplosionEffects 文档](https://wofsauge.github.io/IsaacDocs/rep/Game.html#bombexplosioneffects) 将它定义为包含伤害和视觉的完整爆炸接口。

仍需核查，不能包装成已实现的事项：

1. 模块固定 `40` 伤害，注释称其为原版数值；当前 XML 不包含爆炸伤害，这条注释不是数值证明。
2. 通用爆炸接口的 `RadiusMult=2` 是否确实等于“自然 Mulliboom 实际爆炸半径的 2 倍”，需要基线对照。
3. 自有 NPC 如果先被外部攻击杀死，当前 `MC_POST_NPC_DEATH` 只移除引用；它没有把该死亡统一接入自定义双倍范围路径。原生 AI/死亡是否会先触发普通爆炸，尚未验证。
4. `detonate` 在确认爆炸调用可完成前先移除实体。接口缺失或抛错时可能只消失不爆炸；不能靠每帧重试或追加一次爆炸掩盖失败。
5. `Pathfinder:FindGridPath` 的假测试只记录调用，并不运行原版 AI；不能证明实际追击、爱心、障碍物绕行和碰撞。

## 二、修复实施任务

### Task 1：用稳定 owner 身份恢复 90 帧计时

**修改范围：** `kamikaze_squad.lua`、`tests/kamikaze_squad_behavior_test.lua`；`main.lua` 只在需要接入已有身份工具或诊断入口时做最小改动。

- [ ] 先用只读控制台表达式复核同一玩家的包装与底层身份：

```lua
local a = Isaac.GetPlayer(0):ToPlayer()
local b = Isaac.GetPlayer(0):ToPlayer()
local t = {}; t[a] = true
print(a == b, t[b], GetPtrHash(a), GetPtrHash(b))
```

- [ ] 记录模块一次初始化、第一次识别 owner、timer 1/89/90、生成尝试及清理原因。利用现有 `context.DebugLog`，默认关闭诊断；同一错误只记录一次，禁止逐帧刷屏。
- [ ] 将新包装反例加入正式测试，先证明原代码在第 90 帧失败。夹具可采用下面的代理结构，并给测试用稳定 key 返回同一底层玩家身份：

```lua
GetPlayers = function()
    local result = {}
    for index, player in ipairs(players) do
        result[index] = setmetatable({}, {
            __index = player,
            __newindex = player,
        })
    end
    return result
end
```

- [ ] 玩家状态、`seenPlayers`、stale 清理、公开 `GetState/GetLiveCount` 使用同一个稳定身份入口。可按当前 API 验证后使用 `GetPtrHash(player)`；不要以 ControllerIndex 单独作键，也不要为了测试而在引擎 key 失败时偷偷退回对象键。
- [ ] `clearHolder` 接受内部 owner key；在当帧重新取到玩家时更新对应状态的有效玩家引用，不能因包装变了清理状态。
- [ ] 自有 NPC 数据增加稳定 owner key，`isOwnedUnit` 不再依赖 `data[OWNER_KEY] ~= owner` 的包装比较。跨帧引用使用项目已验证的引用策略；如使用 `EntityPtr`，每次取 `.Ref` 并检查失效，禁止把指针 hash 当持久化存档身份。参考 [EntityPtr](https://wofsauge.github.io/IsaacDocs/rep/EntityPtr.html)。
- [ ] 用同样原则核对 hostileSet、NPC 移除匹配和自有单位列表，避免不同 NPC 包装导致重复追踪、移除失败。保留换房/新局清空，防止地址复用污染后续实体。
- [ ] 回归：89 帧不生成、90 帧 1 只、180 帧 2 只；稳定包装和新包装都通过；两名持有者各 2 只。真实离开、死亡、失去道具才按既有规则清理。

**验收：** 日志中同一 owner 的 timer 确实从 1 增至 90，正常战斗房中 NPC 出现。离线反例通过但未见游戏生成时，不宣称已修好。

### Task 2：恢复真正的目标锁定，不复制 AI

**修改范围：** 正式模块 `updateOwnedUnit` 和对应行为测试。

- [ ] 补测试：锁定 A 后加入更近 B，A 仍有效则目标仍为 A；A 死亡、移除或转友好后才改锁最近有效目标。
- [ ] 最小语义结构如下；目标引用的解析必须沿用 Task 1 确定的有效实体引用方式：

```lua
local data = unit:GetData()
local target = data[TARGET_KEY]
if not isValidHostile(target) then
    target = nearestHostile(unit.Position)
    data[TARGET_KEY] = target
end
if not target then
    detonate(unit)
    return
end
```

- [ ] 保留原版友好状态、寻路接口及极近距离判定；确认正常 NPC AI 与当前 update 顺序不会立即覆盖 Target/寻路结果。若存在覆盖，先记录 native update 的前后值，再选择限定自有实体的正确回调，不全局接管 Mulliboom。
- [ ] 无有效敌人时统一进入现有单次自爆路径，不停留跟随玩家。

**验收：** 稳定锁定、失效重选、实际移动及极近自爆都成立；自然 Mulliboom 的 Target、友好标记与 AI 没有被改变。

### Task 3：验证并收紧一次爆炸合同

**修改范围：** `triggerExplosion/detonate` 及其测试。只在确实需要原生拦截时接入本机已验证可用的 REPENTOGON 回调；不要猜测高版本回调已存在。

- [ ] 先测自然 Mulliboom 基线：记录一次爆炸来源、伤害、实际作用半径和玩家承伤。在相同条件下测本模组棉花怪，不用注释或固定数字测试代替原版基线。
- [ ] 分别覆盖接触自爆、清房自爆、外部击杀、重复死亡/移除回调，记录每只实体的爆炸结算次数。
- [ ] 若能用当前引擎原生爆炸回调识别自有来源并只改半径，优先评估该方案；必须先验证 owner 可追溯、作用半径恰好 ×2、没有二次放大，不能全局改所有炸弹。
- [ ] 若保留 `Remove + BombExplosionEffects` 路线，补接口可用性、真实 Vector/Color/Source 校验和一次失败日志；在移除前验证依赖，确保不出现“无爆炸能力仍成功移除”。失败路径不可无限重试，不可既原生爆又手动补爆。
- [ ] 保留爆炸对所有合作玩家的原生伤害路径；不得为模拟原版数值直接扣血或绕开护盾、爆炸免疫与无敌帧。
- [ ] 区分清房引爆与过门静默清理，防止回调顺序导致应爆者静默移除，或过门后在新房误爆。

**验收：** 一只只产生一次完整爆炸；伤害与自然基线一致、实际半径 2 倍；三种死亡/清理入口和玩家防护均有游戏证据。若当前引擎尚不能验证其中一项，保留“未验证”，不硬写已完成。

### Task 4：最终回归与交付

- [ ] 跑现有行为测试，并保留新增包装变化、目标持续有效、原生 Spawn 接口、原生 AI/外部致死及爆炸失败分支覆盖。
- [ ] 不把现有 `test_real_bomb_explosion_path_preserves_all_native_semantic_arguments` 的名称当证明：它实际仍是 Lua 记录桩，应改名或明确它只验证参数派发。
- [ ] 检查真实 `Isaac.Spawn` 路径：返回 NPC、owner 标签、原版友好爱心、位置安全；严格假接口拒绝普通表伪造的 Vector/Color/EntityRef，而非只收集参数。
- [ ] 运行命令并报告新增失败与既有告警，不修无关文件：

```powershell
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\luac.exe' -p kamikaze_squad.lua
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests/kamikaze_squad_behavior_test.lua
& '.\docs\skills\isaac-validators\scripts\validate-isaac-mod.ps1' -Root . -ModObjectName Neverbirth
& '.\docs\skills\isaac-neverbrith-validator-profile\scripts\validate-neverbrith.ps1' -Root .
& 'C:\Users\Anton\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe' diff --check
```

执行验证器前按其技能复核当前入口与参数。若更改 main.lua，另做完整入口语法检查，不只解析此模块。

## 三、游戏内验收清单：本次全部未验证

| 场景 | 通过条件 |
|---|---|
| 普通战斗房 | 玩家身边每 90 帧尝试生成，最多 2 只；空房 300 帧不生成 |
| 单人持有 | NPC 为 16.2.0，原版爱心可见，不把玩家当主动攻击目标 |
| 锁定与追击 | A 有效时不转追更近 B，A 失效后立即改追最近敌人；绕行与接触自爆正常 |
| 爆炸对比 | 相同测量条件下伤害与原版一致，半径确为 2 倍，每只一次 |
| 保护机制 | 持有者及合作玩家可被波及；免爆、护盾、无敌帧和魂心承伤仍正常 |
| 清房与过门 | 清房余下单位立即完整自爆，过门不带单位、不残留 timer/owner |
| 外部杀死召唤物 | 不漏爆、不双爆、不回落为未经确认的普通半径 |
| 合作、死亡与继续 | 两位持有者各有独立 90 帧和 2 只上限；失效 owner/继续后不残留引用 |

## 四、本次已做与未做

已做：阅读正式模块、main 接线及玩家获取函数、注册/池/图标引用、全部现有神风行为测试、最新可用日志、本机原版实体 XML 与爆炸 Lua 包装；核对 API 文档。

实际检查结果：

- `luac -p kamikaze_squad.lua`：通过。
- 原 `kamikaze_squad_behavior_test.lua`：通过。
- 内存新包装测试：失败于第 90 帧 0 生成；进一步 300 帧对照确认 timer 持续为 1。
- 内存目标锁定测试：确认原目标存活时仍会换追更近目标。
- 第一次组合诊断脚本的目标探针截取定位失败，未产生有效目标结果；随后按实际 `local tests` 边界重新运行成功，以上目标结论只采用成功的后一次结果。

未做：生产修复、测试落盘修改、全项目验证器重跑、游戏内实际生成/爆炸/合作验证、引擎升级及 Git 提交。

**交接顺序：先修稳定身份与计时，再修目标锁定，最后通过原版基线确认爆炸合同。** 不要将“诛”的 EntityRef 类型门槛问题照搬为神风根因：神风当前 `AddCharmed(EntityRef(owner), -1)` 没有同样的类型前置检查。

相关总计划：`docs/superpowers/plans/2026-09-05-neverbrith-repentogon-optimization.md` 的 P8。先恢复基本生成，再判断是否采用该计划的原生爆炸优化；本文件不代表总计划已执行。
