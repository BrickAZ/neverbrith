# 斗气拳套与搓招系统接口

这是内容专属系统的装配及共享配置合同。玩法从[知识索引](../agent/index.md)进入；结构范围见[第二十一批计划](../superpowers/plans/2026-11-26-twenty-first-batch-refactor.md)。

## 斗气拳套

[`drive_glove.lua`](../../drive_glove.lua)返回[`drive_glove/init.lua`](../../scripts/features/drive_glove/init.lua)工厂。调用一次 `include('drive_glove')(mod, context)`，返回实例并发布为 `mod.DriveGlove`。无有效正 `ItemId` 时保持原提前退出；有效安装创建一份状态、冻结、输入、移动、武器、受伤、归属和生命周期实例，按原顺序登记原生回调。根目录纯规则、伤害规则、武器规则、声音和表现保留。重新执行有状态工厂不是取得既有实例的方法，也不代表支持热重载。

`context` 接收 `ItemId`（运行时 ID）、`GetPlayers()`（当前玩家数组）、`GetSaveRoot()`（当前可写存档根）、`GetCurrentRunSeed()`（原种子值）、可选 `Save()` 和 `IncomingDamageMultiplier(player)`。本批显式增加 `Key(player)`，返回旧 inventory/form 玩家键。正式入口传入对 `PendingContentState.InventoryPlayerKey` 的动态查询；旧单独调用方没有 Key 时仍使用该旧接口。玩家、存档、种子与保存函数通过原 context 动态读取。

```lua
local drive = include('drive_glove')(mod, {
    ItemId = Items.DriveGlove,
    Key = function(p) return mod.PendingContentState.InventoryPlayerKey(p) end,
    GetPlayers = GetPlayers,
    GetSaveRoot = persistence.GetRoot,
    GetCurrentRunSeed = GetCurrentRunSeed,
    Save = persistence.Save,
})
local active = drive.IsActive(player) -- 点调用，只读取当前 runtime
```

| 导出 | 合同 |
| --- | --- |
| `ItemId` | 本实例运行时 ID |
| `IsActive(player)` | 点调用；当前 runtime 是否非 idle，不创建记录 |
| `GetState(player)` | 点调用；返回 saved、runtime 两个内部引用；按旧规则创建/修复存档区域并懒创建 runtime，属于有副作用的旧调试接口。普通消费者不得改写私有字段 |
| `Core` / `Damage` | 原规则模块引用；真实伤害与保存操作仍由接入层负责 |

`state.lua` 拥有运行表。新局清理 driveGlove 保存区；继续仅重建 runtime；退出恢复冻结/射击权限、保存再清理 runtime。换房取消临时战斗状态并保存；沙漏只执行原房间取消，不新增斗气快照。freeze 只撤销自身添加的 sprite flag，保留五逻辑帧冻结和原暂停调用点。本次不增加跨进程身份、多人或其他系统控制权保证。

## 四件搓招配置

[`motion_combat_core.lua`](../../motion_combat_core.lua)静态加载[360](../../scripts/features/motion_items/piledriver_360.lua)、[720](../../scripts/features/motion_items/ultimate_720.lua)、[波动](../../scripts/features/motion_items/motion_wave.lua)、[升龙](../../scripts/features/motion_items/dragon_punch.lua)，每件返回无注册副作用的配置表。

| 字段 | 合同 |
| --- | --- |
| `field` / `key` / `profile` | 道具登记字段、战斗动作名、输入 profile 字符串 |
| `anyDirection` | 可选布尔值，保持原 DP 适配入口；当前识别器仍执行已确认的水平方向限制 |
| `combat.normal` / `combat.od` | 原数值表；damage/splash 为面板倍率；duration/spawn/windows/grab/slam/release 为 30 Hz tick；几何值为原世界单位，speed 为每 tick 位移；未提供的变体为 nil |
| `frames[variant]` | `{逻辑起点,逻辑终点,源帧起点,源帧终点}` 顺序数组 |
| `directFrames` | 720 为 true，逻辑 tick 直接映射到 V9 源帧 |

Core 的 `Specifications` 按 360、720、波动、升龙排列。`Definition(move,variant)` 点调用，返回 combat 表引用或 nil。`SourceFrame(move,variant,tick)` 点调用，要求有效定义，先限制在 `[0,duration-1]` 再按原规则映射整数源帧；无效动作仍报错。两者没有 RNG、世界、注册或保存副作用。

其他旧接口保持：`Clone(value)` 递归复制普通表；`Record(root,seed,key)` 创建/修复 motionCombat 区域并返回可写记录；`Gain(record,damage)` 按实际伤害写 energy 并封顶；`SegmentDistance(x,y,ax,ay,bx,by)` 返回距离和 `[0,1]` 比例；`InCone(x,y,fx,fy,reach)` 返回原距离/夹角判定。常量与原边界均未改。

[`motion_combat.lua`](../../motion_combat.lua)创建并保存该 Core，通过 `mod.MotionCombat.Specifications` 发布同一数组；[`motion_items.lua`](../../motion_items.lua)直接复用该引用向既有 MotionInput 实例注册四个 owner，不重新执行 Core 或四件配置。缺少 Specifications 时明确失败，完整入口安装事务回滚。

Specifications 及 Definition 返回值都是**共享表引用，按约定只读**，没有运行时冻结。消费者不得重排、追加或改写。再次 include Core 会产生另一套配置，不能用来取得已安装实例。配置没有玩家/房间/存档状态，也没有生命周期清理任务。

战斗系统继续拥有 session、目标租约、实际扣血回执、SA/OD、`motionCombat` 和 `motionCombatHourglass`。720 获取补满三气、未结算取消退款、换房/退出释放、沙漏恢复及第 289 tick 交还控制保持原样；演出与战斗通过原接口协作。

## 共享能力与检查

输入、来源门禁、正式绑定、战斗实体键和表现统一消费 [entity_identity](../../scripts/systems/entity_identity.lua)，用法见[基础机制](shared-mechanics.md)。斗气拳套存档身份、伤害归属、火力奖励和冻结使用不同合同，继续由本件拥有。

正式装配已改用[共享身份与依赖接线](shared-state.md)：持久 Key 由 player_identity 明确传入；输入、表现、战斗实例由 main 保存并传入正式消费者。各自的 GetSaveRoot 参数实际为[按字段授权的存档视图](persistence.md)，保留 driveGlove / motionCombat 旧字段和保存时机。独立工厂的旧 Mod 字段回退仅用于兼容调用，正式内部协作不靠重新查询这些别名取得实例。

正式 Drive Glove context 还接收同次安装的 `ShootingControls`。拳套只申请自己的 CanShoot 句柄，并与神性过载、炸弹套装共享仲裁；原 PRE/POST 优先级、blockFire、输入、冻结和奖励规则保持。原射击 bool 仅在未传服务的 standalone 兼容路径使用。句柄的原值、有效性、提前结束、异常与实体替换合同见[控制占用](control-ownership.md)。失效实体会解除自身句柄而不调用 setter；setter 失败先解绑再传播，不把失效/异常句柄留给下一局。

真实消费者由正式 main.lua 加载。检查包括[完整安装/回滚](../../tests/batch21_loading_test.lua)、[身份和真实门禁消费](../../tests/batch21_identity_test.lua)、[拳套](../../tests/drive_glove_behavior_test.lua)、[战斗](../../tests/motion_combat_test.lua)、[输入](../../tests/motion_input_behavior_test.lua)、[演出/正式绑定](../../tests/motion_presentation_test.lua)、[数值/帧映射](../../tests/motion_combat_core_test.lua)。本批实际结果见[交付](../../reports/refactor-batch21/2026-11-26/delivery.md)，模拟与原生自动检查都不替代人工手感验收。
