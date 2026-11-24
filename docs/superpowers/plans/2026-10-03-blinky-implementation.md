# 凸眼鱼 / Blinky Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans to implement this plan task by task in the current session. No commits or publishing are authorized.

**Goal:** 按已确认合同实现吸取、储物选择、投掷、受创吸血及本局保存。

**Architecture:** `blinky_core.lua` 保存纯规则与可序列化储物，`blinky.lua` 负责原生对象、输入和攻击；复用选择器并新增可选请求适配。主入口只追加 ID、双语描述和模块接入。保存使用现有共享根，凸眼鱼字段独立于沙漏快照。

**Tech Stack:** Lua 5.4、Isaac Repentance API、项目现有 REPENTOGON 前置、XML、RGBA PNG/ANM2、PowerShell 检查器。

**Spec:** [已确认设计](../specs/2026-10-03-blinky-pending-design.md)

## Constraints and review focus

- 保留当前未提交工作；本地 ID 追加 64（开发途中 63 已被炸弹套装占用）。
- 所有设计数值取自规格；原生近战、钉子、火焰参数需要查证。
- 价格/充能/种子/已开箱状态按实例保存；同组选项独立保留。
- 清单无限、整局持久，沙漏不回滚该字段；优先用来源账本消除回溯原物，能力不足时采用用户允许的复制。
- 删除目标前确认可记录；吐出失败保留条目；切房及退出时归还未完成的无伤害运输对象。
- 全局伤害回调仅跟踪本道具标记目标；取消伤害与其他来源击杀不能记红心。
- UI 按所属玩家隔离，开菜单/确认按键释放保护保持有效。

## Tasks

- [x] 1. 创建行为测试并观察缺模块失败；实现纯规则、储物身份与来源账本，覆盖伤害、扇形、状态保存、失败保留及奖励去重。
- [x] 2. 扩展选择器请求来源、唯一身份、确认键与显示载体；加入回归测试，保留旧调用默认行为。
- [x] 3. 实现原生吸取、选项组、投掷和输入状态；增加模拟集成测试，覆盖实际回调和敌人击杀来源。
- [x] 4. 追加三语 XML、恶魔房池、双语 EID、图标和本地格 64；接入主入口并生成登记数据。
- [x] 5. 运行专项、全 Lua 回归及静态检查，完成一次独立代码审查，记录实际结果和实机测试卡。

## Commands

- `lua tests/blinky_core_test.lua`
- `lua tests/inventory_selector_behavior_test.lua`
- `lua tests/blinky_behavior_test.lua`
- `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/blinky/2026-10-03/checks.json`
- `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1`

## Execution ledger

- Task 5：最终 LuaAll exit 0：75 selected checks / 68 Lua tests / 97 syntax files，0 failed，6 既有资源警告；6 条专项命令 exit 0，回调15组、选择器14组；结果见 `reports/blinky/2026-10-03/checks.json` 和 `verification.json`。
- Final review：再次吸取、空底座、可移动 TNT、近战侧弧、Schoolbag 组合键、延迟神圣箱持久身份已修正；独立复核15组 exit 0。详见 `reports/blinky/2026-10-03/review.md`。
- 真实游戏未启动验收；并行炸弹套装任务的临时原生入口由该任务自行清理，本轮不覆盖其改动。

- Task 1：缺模块失败 exit 1 → `lua tests/blinky_core_test.lua` exit 0。
- Task 2：`lua tests/inventory_selector_behavior_test.lua` 14 cases，exit 0。
- Task 3：缺 `blinky.lua` 失败 exit 1 → 回调测试 6 cases，exit 0；扩展边界检查继续执行。
- Task 4：图标已生成和打包；登记生成器 exit 0，64 rows；本地化测试 exit 0。
- Ruling：63 在本轮开发中被另一项炸弹套装开发占用，顺延到 64；只编辑新的 64 格。

- Ruling: 用户“直接开始开发”已授权实施；计划与执行在当前会话完成，不再要求重复确认。
- Ruling: 现有工作区包含其他已实施功能，直接以当前源码为集成基线，不切换到缺少未提交功能的隔离 checkout。
- 原生实机表现独立于模拟测试；最终交付不标记未经用户确认的游戏验收通过。
