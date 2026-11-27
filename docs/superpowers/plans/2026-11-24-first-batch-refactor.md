# 第一批十件道具重构实施计划

> **For agentic workers:** 使用 superpowers:executing-plans 在当前会话逐项实施。用户已明确授权本批实施；不提交、推送或发布。

**Goal:** 将风油精、芜湖、七件狗粮和八音盒迁出 main.lua，保持玩法、注册顺序、资源及旧存档格式。

**Architecture:** 功能模块使用现有工厂风格；main.lua 在原注册位置安装模块。存档服务拥有唯一根对象，未迁移内容继续通过旧接口适配；新功能仅拿到自己的数据区域。八音盒分开运行接入、纯规则和表现。

**Tech Stack:** Lua 5.4、现有 Isaac / REPENTOGON、PowerShell 7；无新增依赖。

**Spec:** [已确认目标架构](../../architecture/2026-11-24-neverbirth-target-architecture.md)，以及本聊天已确认的十件首批名单。

## 固定约束

- 保留目录 neverbrith 与公开 Neverbirth 拼写、XML/ID/品质/池/资源及字段名。
- 不统一玩家身份、不改计时单位、不合并保存频率、不新增沙漏回退政策。
- 原生回调事件、过滤、返回值和相对顺序保持；旧公开方法委托同一模块实例。
- 基线为 315e1635cf0068f510b9dce2bead85bc11b65f34，开始时 Git 工作区干净。
- 修改直接落在用户指定工作区；恢复副本与运行记录保存在 reports/refactor-batch1/2026-11-24。禁止重置无关文件。

## Review Focus

- 缓存事件顺序变化导致芜湖与射速加成组合变化：真实入口记录及属性组合对照。
- 加载和继续时重复生命奖励：狗粮现有继续/多人断言和存档回归。
- 新存档服务更换根表导致旧消费者失去状态：共享实例与保留未知字段测试。
- 八音盒死亡债务、护盾先后和 C 计划计时变化：保留现有行为及真实注册顺序测试。
- 新目录未被加载、语法检查或打包发现：入口路径检查、缺失/重复注册反例及完整运行文件清单。

## Task 1：基线与公共测试环境

**Files:** tests/support/neverbirth_fixture.lua；tests/localization_test.lua；使用其加载器的相关测试；tools/check-neverbrith.ps1；tests/check_neverbrith_runner_test.ps1。

**Interfaces:** 公共夹具直接返回加载函数 `(options)`，返回结构和原 loadNeverbirthWithEID 一致；保留现有必要测试全局观察值。

- [x] 保存实际运行源码、资源、测试和配置副本及哈希；在副本运行完整入口检查。
- [x] 记录 LuaAll 与原生基线，区分已知问题和本批新增差异。
- [x] 从本地化测试提取夹具；将直接执行/截取本地化测试的消费者改成显式调用公共夹具，不删除原断言。
- [x] 将 scripts 与 tests/support 纳入语法扫描，并增加嵌套语法错误反例。
- [x] 执行相关测试及检查入口自测。

## Task 2：风油精与芜湖

**Files:** scripts/features/essential_balm.lua；scripts/features/wuhu.lua；main.lua；tests/basic_stat_items_test.lua。

**Interfaces:** 工厂 (Neverbirth, { ItemId })；保留 EvaluateEssentialBalm / EvaluateWuhu 方法与原回调注册。

- [x] 以实际 main.lua 建立多份、移除、组合及缓存顺序对照。
- [x] 将两个处理器完整迁入单文件模块，在原位置安装。
- [x] 验证回调恰好一次，原属性计算和颜色覆盖不变。

## Task 3：存档服务与狗粮

**Files:** scripts/runtime/persistence.lua；scripts/runtime/legacy_save_schema.lua；scripts/features/dog_food_series.lua；main.lua；tests/persistence_test.lua。

**Interfaces:** persistence.Create(mod, { Json, Log, Initialize }) 返回 GetRoot(), Save(), Section(name, initialize)。Section 返回 Get()/Replace(value)/Save()；每次 Get 访问当前区域，避免重置后旧引用。legacy_save_schema 保留旧默认初始化；本批例外继续包含八音盒/狗粮空区域，以保持其他模块先保存时的首份序列化形状。后续建立功能默认值登记与序列化对照后再移除这些兼容默认值。

- [x] 验证懒加载一次、旧根保留、未知字段保留、区域替换后重新获取及序列化失败不写入。
- [x] 提取唯一 JSON 读写服务；原 EnsureMusicboxDataLoaded / SaveMusicboxData 委托同一实例。
- [x] 狗粮完整迁入一个模块，显式传入 Items/GetPlayers/IsValidItemId/Log/RunSeed/Store。
- [x] 保留狗粮计数、拾取延迟、继续初始化、多人和击退合同，执行专项测试。

## Task 4：八音盒完整迁移

**Files:** scripts/features/musicbox/init.lua；core.lua；presentation.lua；main.lua；tests/musicbox_core_test.lua；tests/musicbox_behavior_test.lua。

**Interfaces:** init 工厂接收 ItemId/GetPlayers/GetCurrentRunSeed/Log/Store/IsIncomingDamageLethal。致命伤害查询由 `scripts/systems/incoming_damage.lua` 提供，供八音盒、黑太岁和肉块复用。core 只处理死亡债务匹配、倒计时及显示阶段计算；presentation 创建并保留旧 Neverbirth.Musicbox 公开表，读取运行状态并处理声音/特效。

- [x] 固定核心计时和阶段边界断言。
- [x] 迁出所有八音盒及 C 计划专属代码，原注册位置加载，八音盒通过自身区域接入状态；首次保存形状沿用 Task 3 的兼容例外。
- [x] 保留公开方法、状态来源、保存时机、原生事件过滤和返回值。
- [x] 运行八音盒、伤害顺序、启动、本地化、存档和全部 Lua 回归。

## Task 5：原生、工具、导航与交付

**Files:** docs/agent/project-map.md；docs/agent/testing.md；本批 reports 下交付与检查记录。

- [x] 用固定场景比较实际引擎属性、狗粮奖励、八音盒倒计时/免伤/死亡、音乐和特效资源；恢复验证用设置与存档并核对哈希。
- [x] 执行 LuaAll、检查入口自测、严格验证器和导航检查；保留警告及缺失覆盖。
- [x] 记录完整加载/资源清单与候选恢复副本；证据不等同发布授权。
- [x] 使用执行技能要求的一次独立最终代码审阅，修正有证据的问题。
- [x] 交付变更、实际命令/退出码、原生范围及回退步骤。
