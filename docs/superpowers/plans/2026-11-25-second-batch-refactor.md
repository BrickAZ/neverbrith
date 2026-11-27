# 第二批八件道具重构实施计划

> **For agentic workers:** 使用 superpowers:executing-plans 在本会话实施，最后一次独立代码审阅。用户已于 2026-11-25 要求实施已审阅的八件方案；无需再确认范围，不提交、推送或发布。

**Goal:** 将八件完整玩法迁出 main.lua，并以血颅蛊的正式查询接口替换三件道具的共享反噬变量。

**Architecture:** 沿用工厂模块、显式依赖和原位回调登记。美工刀复用唯一存档实例的 utilityKnife 区域；其余模块保持运行时状态。入口持有血颅蛊实例，脐带和空摇篮使用延迟查询闭包，构造期间不调用。

**Tech Stack:** 现有 Lua 5.4、Isaac / REPENTOGON、PowerShell 7，无新增运行依赖。

**Spec:** [第二批方案](../specs/2026-11-24-second-batch-refactor-design.md)。

## Global Constraints

- 保留八件原数值、品质、池、资源、保存/沙漏语义、玩家键和公开 Neverbirth 方法。
- 基线为实施前实际工作区，包含第一批未提交成果及后续八音盒测试改动；不可用 HEAD 覆盖。
- 回调保持事件、顺序、过滤、优先级和返回值，尤其美工刀分散的登记位置。
- 在指定工作区实施，报告和恢复副本保存于 reports/refactor-batch2/2026-11-25，不清理其他改动。

## Review Focus

- 脐带先于血颅蛊安装，延迟查询在装配时被错误调用：真实入口加载及模块缺失反例。
- 反噬深度在嵌套或异常扣血后泄漏：正常/异常反噬后普通伤害恢复及既有债务不误结算。
- 春药计时或属性覆盖改变：错时叠加、90 帧边界、多人与芜湖/风油精组合。
- 美工刀区域替换或双路径结算改变：存档继续、库存增长与原生拾取回调对照，已存在问题独立记录。
- 实体回调被遗漏或回调位置改变：真实入口登记全量对照、缺失模块反例、针尖去重与绝育无人持有零扫描。

## Task 1：行为基线与恢复点

**Files:** tests/chunyao_behavior_test.lua；tests/batch2_damage_synergy_test.lua；tests/batch2_loading_test.lua；reports/refactor-batch2/2026-11-25/。

**Interfaces:** 使用 tests/support/neverbirth_fixture.lua 的 Root/OnInclude/OmitModule；全量登记基线使用相同夹具。新增测试只调用实际安装的处理器。

- [x] 保存实际运行源码/测试/资源及 SHA256 清单，执行迁移前 LuaAll，记录退出码与旧警告。
- [x] 补春药低充能、90 帧、错时双份、多人及属性组合行为；补三件正常/异常反噬与随后普通伤害。先对旧入口运行，Expected: PASS；这些是特征基线，不为满足新接口而改变旧玩法。
- [x] 新增八模块真实加载/注册测试，Expected: 在迁移前因未加载八模块而 FAIL；迁移后 PASS。
- [x] 使用同一原生探针对基线与候选做八件对照；每次独立游戏进程、保存恢复校验，Expected: 0 失败且恢复成功。

## Task 2：春药与美工刀

**Files:** scripts/features/chunyao.lua；scripts/features/utility_knife.lua；main.lua。

**Interfaces:** chunyao(Neverbirth,{ItemId,GetPlayers}) 注册原三回调；utility_knife(Neverbirth,{ItemId,GetPlayers,GetCurrentRunSeed,Store}) 定义公开方法但不集中登记，Store= persistence.Section('utilityKnife')。

- [x] 原块完整迁移，保留美工刀各原登记语句及 UtilityKnifeDamageUp 常量。
- [x] Run: lua tests/chunyao_behavior_test.lua；lua tests/condom_utility_knife_behavior_test.lua。Expected: PASS，无玩法差异。

## Task 3：实体与卡牌道具

**Files:** scripts/features/needletick.lua；sterilization_certificate.lua；shredded_tarot.lua；main.lua。

**Interfaces:** 工厂显式传入 ItemId、实际使用的 GetPlayers/IsValidItemId/Log；模块在原区块位置创建和登记，保留公开方法与常量。

- [x] 完整迁出三块；保持原 RNG、房间扫描和主动槽逻辑。
- [x] Run: lua tests/needletick_behavior_test.lua；lua tests/sterilization_certificate_behavior_test.lua；lua tests/shredded_tarot_behavior_test.lua。Expected: PASS。

## Task 4：三件反噬联动

**Files:** scripts/features/blood_skull_gu.lua；uncut_cord.lua；empty_cradle.lua；main.lua；tests/batch2_damage_synergy_test.lua；tests/empty_cradle_seed_boundary_test.lua。

**Interfaces:** blood_skull_gu 返回 {IsBacklashActive=function()->boolean}，私有持有深度。uncut_cord/empty_cradle 接收 IsBloodSkullBacklashActive=function()->boolean；empty_cradle 另接收原 GetCurrentRunSeed 函数，保留跨局楼层键。入口 local bloodSkullGuModule 保有唯一实例，闭包仅在伤害回调内查询。

- [x] 三件完整迁移，两个读取点替换正式查询，删除主文件旧共享深度；原 pcall 及深度恢复不变。
- [x] Run: lua tests/blood_skull_gu_behavior_test.lua；lua tests/uncut_cord_behavior_test.lua；lua tests/empty_cradle_behavior_test.lua；lua tests/batch2_damage_synergy_test.lua。Expected: PASS。
- [x] Run: lua tests/empty_cradle_seed_boundary_test.lua。Expected: 同玩家、同章节只改运行种子即清除旧加成并重置奖励资格，不受同名全局函数影响。
- [x] Run: lua tests/batch2_loading_test.lua；lua reports/refactor-batch2/2026-11-25/compare-registration.lua。Expected: 全部八模块加载一次，缺失/重复反例可检测，登记与基线一致。

## Task 5：验收与交付

**Files:** docs/agent/project-map.md；方案状态；本批 delivery.md、progress.md 和证据。

- [x] Run: pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' -ReportPath reports/refactor-batch2/2026-11-25/final-checks.json。Expected: 0 失败/阻塞，旧警告单独记录。
- [x] 检查器本身未修改则不重跑其自测；导航修改后 Run: pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1。Expected: PASS。
- [x] 完成候选原生与基线对照、资源哈希、独立副本加载及 main 临时探针清理核对。
- [x] 按执行技能完成一次独立最终审阅，依据事实修正重要问题并验证。
- [x] 记录每项实际命令/退出码、现有行为问题、真实验收范围及回退到本批基线的方法。
