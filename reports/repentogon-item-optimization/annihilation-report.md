# 诛修复结果（2026-09-05）

状态：模块与严格 Lua 行为测试修复完成；未进行游戏内验收。未提交 Git，未修改 main、XML、美术或其他道具模块。

## 修改文件

- `annihilation.lua`
- `tests/annihilation_behavior_test.lua`
- 本报告。

## 实施内容

1. EntityRef 不再以 `type == function` 判定：在 pcall 中实际调用构造器，同时支持普通函数与 callable 构造器。构造失败/返回 nil 时跳过伤害，无普通 table fallback；保留原错误并按失败类别只记录一次。TakeDamage 抛错同样只记一次；取消和失败不触发 c356 充能。
2. 玩家状态、NPC 集合和每波命中键统一为 `GetPtrHash + InitSeed`。GetState、使用、cache、泪弹和每帧玩家刷新都解析该键并更新 owner 包装引用。缺少身份时安全拒绝激活/跟踪并报一次，不回退 ControllerIndex 或包装对象。死亡通过稳定 NPC 集合键消耗资格并保留原 GetData 已解析标记。
3. 原生 Isaac.Spawn 分支显式 ToEffect；设置/GetSprite/Load/Play/IsPlaying/Scale 在保护范围内。失败移除半完成视觉，不影响成立的伤害状态。光环/激活视觉更新异常被隔离并清理。Vector 复制通过实际构造器调用，兼容 __call，波原点不再直接持有输入向量。模块没有 Color 写入路径，因此没有新增非原生颜色表。
4. 可通过初始化 context.Diagnostics=true 或现有返回 API 的 SetDiagnostics(true) 开启阶段诊断；默认关闭。覆盖 init、use、first-update、first-damage、first-shot、end:room/expired/invalid-owner/game-start/exit/manual。失败类日志独立一次记录，不逐帧刷屏。
5. SpawnerEntity 明确存在但不是玩家时，不再借 Parent 玩家误认其泪弹；使魔拥有的攻击保留。没有 SpawnerEntity 时保留原 Parent 玩家兼容路径。
6. 保持 150 帧、4 帧首跳/间隔、75 半径实时 x0.4、115 冲击波实时 x1、同波同敌一次、range x0.45、频率 x0.60、每敌/Boss 死亡所有已激活玩家 +9 无上限。8 格 XML 注册不动。c356 原主副手各 1 格实现不迁移。

## TDD 证据

使用技能 test-driven-development、isaac-damage-health-contracts 及所要求的 damage-health-review/tbd-disclosure 引用。先加测试，观察正式模块失败后修改生产代码。

### 第一轮 RED

命令：`lua tests/annihilation_behavior_test.lua`，exit 1。

```text
FAIL: tests/annihilation_behavior_test.lua:548: callable EntityRef must execute: expected 1, got 0
FAIL: tests/annihilation_behavior_test.lua:558: fresh wrapper state: expected table: ..., got nil
test failures: expected 0, got 2
```

修复构造器与稳定键后同命令 exit 0：`annihilation_behavior_test: ok`。

### 第二轮 RED

补严格原生 Spawn、ToEffect、typed vector、阶段诊断、构造和伤害异常测试。命令同上，exit 1。

```text
FAIL: tests/annihilation_behavior_test.lua:594: native spawn ToEffect conversion: expected 2, got 0
test failures: expected 0, got 1
```

修复原生视觉路径/阶段诊断后同命令 exit 0：`annihilation_behavior_test: ok`。

### 第三轮 RED

补 GetSprite、Load false、Play 抛错、更新属性抛错及使魔攻击边界。命令同上，exit 1。

```text
FAIL: tests/annihilation_behavior_test.lua:664: invalid visual write Position
test failures: expected 0, got 1
```

修复视觉更新隔离后同命令 exit 0：`annihilation_behavior_test: ok`。

## 最终验证

- `lua tests/annihilation_behavior_test.lua`：exit 0，`annihilation_behavior_test: ok`。原 11 项测试全部保留，新增 5 项分组测试通过。
- `luac -p annihilation.lua tests/annihilation_behavior_test.lua`：exit 0，无输出。
- `git diff --check -- annihilation.lua tests/annihilation_behavior_test.lua`：exit 0，仅 Git LF 将转 CRLF 的提示，无空白错误。

覆盖包括普通/callable EntityRef、异常与取消、fresh 包装跨使用/cache/tears/state、同控制器不同实体、NPC 命中/死亡去重、空房/重复用/失去主动/换房与死亡清理、实时伤害、Boss/友军、主副手充能、原生特效转换/失败/清理和属性写入异常。

## 未验证边界

- 以上是正式模块在 Lua 严格替身环境中的行为证据，不是 REPENTOGON 游戏运行证据。当前没有游戏控制入口，未启动游戏，不能宣称游戏验收通过。
- 游戏内 EntityRef userdata、命中引擎语义、真实特效加载与可见度、波浪深度/脚底位置、实际计帧/联机实体包装仍需游戏验收。
- 不在本次范围的原生充能迁移未实施。
- 标准 apply_patch 因 Windows ACL helper 启动失败，使用 brief 已允许的同一 Codex patch 引擎，经 require_escalated 批准运行；没有使用文本替换脚本写生产代码。

## 独立 Review 后修复：失效 owner 的确定清理

Review 指出：旧 endState 在内部更新/clearAll 中重新调用 entityKey(player)，owner 已失效且 GetPtrHash 抛错时会早退；postUpdate 遗留 state，clearAll 虽清空表但遗漏视觉。

已通过正式回归证实。新增两条独立测试：激活并创建冲击波后，owner.Exists=false，GetPtrHash(owner) 抛出 `owner native handle no longer valid`；分别执行一帧 update 和 newRoom，要求状态/NPC 集合为空且 aura、activation、wave 全部移除。

RED 命令 `lua tests/annihilation_behavior_test.lua`，exit 1：

```text
FAIL: tests/annihilation_behavior_test.lua:700: update must remove invalid owner state: expected nil, got 1:1
FAIL: tests/annihilation_behavior_test.lua:703: room must remove every invalid owner visual
test failures: expected 0, got 2
```

修复：新增私有 endStateByKey(key,state,...)；postUpdate 将当前表键传给 updateState，失效 owner 和到期结束直接走保存键清理；clearAll 保存键/状态快照并调用该内部路径。外部 EndState(player) 接口保留，不改变现有调用合同。

另外新增 ToEffect 返回 nil/抛错的原生分支测试，验证原始通用实体 Remove 被调用且伤害仍成立；这两个分支在本轮修改前即通过，因此仅补测试覆盖，无新增生产修复。

GREEN 及最终命令：

- `lua tests/annihilation_behavior_test.lua`：exit 0，`annihilation_behavior_test: ok`，现共 19 项测试入口（原 11 项 + 前次 5 项 + 本次 3 项）。
- `luac -p annihilation.lua tests/annihilation_behavior_test.lua`：exit 0，无输出。
- `git diff --check -- annihilation.lua tests/annihilation_behavior_test.lua reports/repentogon-item-optimization/annihilation-report.md`：exit 0，仅 LF/CRLF 提示。

本轮使用 receiving-code-review 技能先核验意见并以 TDD 修复；范围仍只有原三个文件，无游戏验收。
