# 待开发道具与背包选择系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Independent modules may be developed in parallel under dispatching-parallel-agents; shared registration and integration are serialized by the primary agent.

**Goal:** 实现已批准的临时复制、零分考卷、回声宝宝和通用背包选择器，保留当前工作区既有改动。

**Architecture:** 新行为分别放在根目录模块，以 `return function(mod, context)` 接入。共享已确认拾取实例和房间回退由 `pending_content_state.lua` 管理；每个内容模块独立管理自身状态，通过现有 SaveData 根保存，不复制游戏实体对象。

**Tech Stack:** Isaac Repentance、当前 REPENTOGON 1.0.12a、Lua 5.4、现有 PowerShell 检查入口。

**Spec:** `reports/batch-completion/2026-10-02-proposed-contracts.md`，其中四组候选规则于本轮用户回复“1”后采用。原四份 2026-09-28 pending-design 文档继续提供已确认核心效果。

**执行状态（2026-10-02）**：五个任务的模块、资源、注册与自动检查已落地，下面保留实施时的原清单。实际逐项证据见[交付记录](../../../reports/batch-completion/2026-10-02-delivery.md)：62 Lua/87 语法/69 检查退出 0；实机未验收，神的左手原生历史歧义仍不能完整覆盖所有份数清理，阴的诅咒精确免爆封锁未实现。用户已明确排除 ds4。未执行提交/发布/审批写回。

## Global Constraints

- 不改变既定名称、描述、品质、道具池、权重、核心数值；不定义 ds4 的缺失玩法。
- 采用已安装 1.0.12a 的真实接口；不安装、更新或要求更高版本才能启用核心玩法。
- `main.lua` 只新增接入块、ID/语言登记；其他任务拥有的脏改动保留。自定义角色仍停用。
- 不提交、推送、发布或改写用户可玩验收状态。
- 自动测试与实机验收分开。无法静态证明的引擎表现明确记录，不用模拟测试冒充。

## Review Focus

- 同名正常道具与临时贡献并存时，清理只移除自有临时贡献。
- 同一拾取物重复碰撞、举起延迟、被移除或取消时不得重复结算；另一份同名实物仍能结算。
- 沙漏回退、正常续局和拉撒路换形态，不产生额外奖励或丢失合法状态。
- 金色饰品、吞下、转交和第五次有效伤害，不误删其他饰品或重置耐久。
- 原生跟班的完整来源组、手柄菜单输入和控制恢复需额外审查并提供实机检查卡。

## Shared Interfaces

所有模块公共 context：`GetSaveRoot() -> table`、`GetCurrentRunSeed() -> string`、`GetPlayers() -> players`、`Save()`、`DebugLog(string)`。

共享状态服务：`State.PlayerKey(player) -> string`（拉撒路两形态规范化）、`State.FloorKey() -> string`、`State.RoomKey() -> string`、`State.PickupToken(pickup) -> string`、`State.SubscribeAcquisition(fn)`（`fn(player, itemId, token, physical, temporary)`）、`State.Snapshot()`、`State.Restore()`、`State.RegisterParticipant(name, capture, restore)`。识别失败必须明确诊断，不把 ID 当实物身份。

## Task 1: 身份／回退服务与临时复制

**Files:** Create `pending_content_state.lua`, `divine_left_hand.lua`, `tests/pending_content_state_test.lua`, `tests/divine_left_hand_behavior_test.lua`; primary agent owns integration files.

**Interfaces:** `include("pending_content_state")(mod, context) -> State`; `include("divine_left_hand")(mod, context)` with `context.State`, `context.ItemId`. Public temporary count function for selector: `mod.DivineLeftHand.GetTemporaryCount(player,id)`.

- [ ] 写并运行缺失模块失败测试：重复碰撞与真实授予确认，非实物授予标记，跨玩家／续局／沙漏。
- [ ] 验证已安装引擎的 Innate／history／移除接口，选用只清理自有贡献的方案；不对正常道具按数量猜测删除。
- [ ] 实现最后正常取得目标、合法性、失败不扣费、成功临时贡献、下层清理、续局和回退。
- [ ] 运行两个专项测试，保存命令、实际退出码和关键引擎边界。

## Task 2: 背包选择器

**Files:** Create `inventory_selector.lua`, `tests/inventory_selector_behavior_test.lua`. Implementer cannot edit main/content/resources or other task modules.

**Interfaces:** `mod.InventorySelector.Open(player, request) -> bool`; request has `title`, optional `eligible(player, entry)`, `execute(player, entry) -> bool`, optional `valid(player) -> bool`, `onCancel(reason)`. Entries include `id`, `count`, `temporaryCount`, `name`, `gfx`, `type`, `order`. `Close(player,reason)`, `GetSession(player)`. Context optionally supplies `GetEntries(player)`; primary wires shared inventory sources.

- [ ] 写并运行失败测试：同名合并、确认重验、执行失败、取消／房间变化／死亡、同时合作输入、确认键释放恢复。
- [ ] 实现原生方向／菜单确认返回输入、选择者移动射击屏蔽、图标网格翻页与名字显示；不暂停世界。
- [ ] 使用调试命令打开只返回选定目标的演示；不新增免费玩法操作。
- [ ] 专项测试通过并报告界面实机未验证项。

## Task 3: 零分考卷

**Files:** Create `low_grade.lua`, `tests/low_grade_behavior_test.lua`. Implementer cannot edit shared files.

**Interfaces:** `include("low_grade")(mod, context)` with `context.TrinketId` and `context.State`. Module can own physical trinket receipt tracking and register its capture/restore functions with State.

- [ ] 查本地版本原生饰品／损伤接口及 A+ 口径；写并运行失败测试，覆盖每层分别受伤、滚动三层、第三层头目结算与每层一次。
- [ ] 实现每份五次耐久、黄金／盒子倍率、吞下和转交身份、续局、沙漏与玩家隔离。
- [ ] Cache 仅加攻击 5、射速 5、射程 5，正确换算射程单位和射速，可突破上限，不加移速。
- [ ] 专项测试通过，提供原生饰品掉落／吞下与头目结算的实机检查项。

## Task 4: 回声宝宝

**Files:** Create `echo_baby.lua`, `tests/echo_baby_behavior_test.lua`. Implementer cannot edit shared registration/resources files.

**Interfaces:** `include("echo_baby")(mod, context)` with `context.ItemId`, `context.FamiliarVariant`, `context.State`; physical acquisitions delivered by shared service. Module registers capture/restore functions with State.

- [ ] 查已安装原生跟班配置来源、CheckFamiliar、连体变身、宝宝标签接口；失败测试覆盖非追溯、互斥奖励、实物去重、不同同名份数、5.0 射速记录与其他突破上限来源。
- [ ] 实现本体每 28 帧 3 伤害灵体泪弹、按原生基准跟随射击、直接连体。
- [ ] 来源组精确复制，不加收藏品或额外非跟班效果；无法对应的特殊来源明确诊断，不按变体猜测来源。
- [ ] 实现永久本局奖励、失去停止新增、多份本体与非倍增奖励、续局／沙漏／拉撒路共享。
- [ ] 专项测试通过，报告跟班原生 AI、资源与献祭边界。

## Task 5: 注册、资源与整体集成

**Files:** Modify `main.lua`, `content/items*.xml`, `content/itempools*.xml`, `content/entities2.xml`, generated registry and My Stuff atlas through its existing contract; create approved icons, Echo Baby animation, selector assets as needed. Primary agent owns these files.

- [ ] 分配当前空闲本地 ID、实体 Variant、饰品 ID；三语言 XML 同步，池权重保持已确认值。
- [ ] 生成并检查像素资源、真实 ANM2 链、My Stuff 草图；不覆写无关格。
- [ ] 把模块与现有 SaveData、玩家枚举、语言、EID、pickup banner 接入；完善缺少必要枚举的旧测试夹具，不削弱断言。
- [ ] 运行所有新专项、LuaAll、生成登记检查、My Stuff 和必要资源契约检查；记录命令、退出码、警告和未验证范围。
- [ ] 独立审查各模块及完整变更，修复重要问题后重跑相关检查。
- [ ] 阴的诅咒精确封锁单列技术调查结果；无符合已确认约束的方案时保持未完成并报告证据。ds4 仍等待效果定义。
