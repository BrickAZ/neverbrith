# 存档服务与旧格式适配

来源：[persistence.lua](../../scripts/runtime/persistence.lua)、[legacy_save_schema.lua](../../scripts/runtime/legacy_save_schema.lua)。由 [main.lua](../../main.lua)按旧顺序组合各所有者的存档声明，创建一次 persistence 实例，再向道具传对应 Section 或 Scope。模块本身不注册回调。

```lua
local persistence = include("scripts.runtime.persistence").Create(mod, {
    Json = json,
    Initialize = include("scripts.runtime.legacy_save_schema")({
        include("scripts.features.utility_knife.save_schema"),
        -- 示例只安装一个所有者；正式 main 按下表装配全部 19 个旧区域。
    }),
    Log = Log,
})
local itemStore = persistence.Section("utilityKnife") -- 使用已有、被该道具拥有的区域
```

`Create(mod, dependencies)` 是点调用，返回闭包服务。`Json` 必需，含 encode/decode；`Initialize(root)` 与 `Log(message)` 可选，缺省为空操作。Create 不立即读档，首次 GetRoot、区域 Get 或 Save 才加载。mod 的 HasData/LoadData/SaveData 使用原生冒号约定，由服务处理。

| 接口（全部点调用） | 返回与失败 | 副作用和引用合同 |
| --- | --- | --- |
| `persistence.GetRoot()` | 内部根 table；读取、解析或初始化失败会抛错；重入加载也抛错 | 首次加载并调用 Initialize；失败状态在该实例内固定，之后不再重试或退回空档 |
| `persistence.Save()` | 成功 true；加载、序列化、缺失 SaveData、写盘抛错或返回 false 时返回 false | 编码并写整个根对象；不是“只保存当前区域”。不会重建失败实例 |
| `persistence.Section(name, initializeSection?)` | 区域接口 table；name 必须为非空字符串 | 不立即创建区域；各 Section 可不同，但底层根服务必须共享 |
| `section.Get()` | 内部可变区域 table，不是副本 | 不存在或不是 table 时创建；每次 Get 都会调用 initializeSection，因此初始化需可重复。不会自动 Save |
| `section.Replace(value)` | 返回传入的 table；非 table 断言失败 | 用同一个表替换区域，既有旧表引用不会跟随替换；不自动 Save，也不深度验证 JSON 可序列化性 |
| `section.Save()` | 同根 Save | 保存整个根，失败返回 false |

```lua
local data = itemStore.Get()
-- 只更改这件道具拥有、已经定义过的字段。
local saved = itemStore.Save()
-- saved=false 需由调用者按现有失败合同处理，不能报告已写入磁盘。
```

旧格式初始化组合器现在导出 `compose(schemas) -> initialize(root)`，详细声明合同和真实所有者见下节。它不导入玩法模块，不保存具体区域名称；初始化器仍原地补齐旧区域及部分嵌套表，不返回新根、不写盘、不更改玩法数值。旧根字段和首次保存形状保留，删除区域仍需要明确的格式迁移依据。

服务不自动管理新局、Continue、沙漏、按玩家分区或实体重绑。道具根据原合同在对应事件重置/恢复；同种子新局也必须执行新局清理。内存里不要保存不可序列化的玩家、Sprite 或函数。

## 旧格式的按字段存档分区

`persistence.Scope(nameOrNames)` 接收一个非空字段名或非空、无重复的字段名数组，返回 `{ GetRoot, Save }`；均为点调用。创建时复制授权名单，不读取存档、不创建数据、不注册回调。

```lua
local owned = persistence.Scope("driveGlove")
include("drive_glove")(mod, {
    ItemId = itemId, Key = identity.InventoryPlayerKey,
    GetSaveRoot = owned.GetRoot, Save = owned.Save,
    GetPlayers = getPlayers, GetCurrentRunSeed = getRunSeed,
})
```

`owned.GetRoot()` 首先完成原有加载/错误检查，然后返回该 scope 固定身份的代理表。该表只能按授权字段名读取或赋值；越界读写抛错。缺失值仍为 nil，赋值 nil 仍删除字段，false/标量等旧值不被自动修正；字段初始化、校验和重建仍归原消费者。每次字段访问都解析当前真实根，区域替换后不会继续读旧表。授权区域的值是原内部可变引用，并非深复制；消费者仍负责自己保留的旧区域引用。

`pairs(view)` 只枚举授权且非 nil 的字段；不可依赖顺序。代理不是普通存档根，不能 `rawget/rawset`、改变元表或直接交给 JSON；正式消费者只做已核对的普通字段访问。`Save` 仍保存整个真实根，包括未授权及未知扩展字段，保存时机、返回值和失败保护不变。

当前正式入口将 yinCurse、bigDogBark、reviveMyLove、nightOfTheCowards、memoryDisorder、ringOfSevenCurses、healthySleep、iAmAGod、godComplex、blinky、driveGlove 分别授权给原对应道具。搓招战斗拥有 motionCombat / motionCombatHourglass 两区，获取服务拥有 pendingContent / pendingContentHourglass 两区；神的左手、回声宝宝、零分考卷分别获得 divineLeftHand、echoBaby、lowGrade。旧根字段形状由这个窄视图兼容，不再把完整根权限交给它们。其余已迁移消费者继续使用 Section。

旧格式初始化已经转为所有者声明，由装配层按原顺序注册到组合器；空区域依旧在首次加载时创建，不能改成第一次持有道具才创建。组合器不决定消费者的数据权限。独立旧工厂的 `GetSaveRoot` 参数保留，不自动扩大生产入口授权。检查：[scope 边界](../../tests/persistence_scope_test.lua)、[正式消费者接线](../../tests/framework_shared_wiring_test.lua)、[初始化所有权](../../tests/persistence_schema_ownership_test.lua)。

实例生命周期与当前 Mod 安装一致。没有公开 Reset/Retry/Destroy API；不要猜一个不存在的方法，也不要为消除加载错误在消费者中创建第二个根服务。

真实使用：[美工刀](../../scripts/features/utility_knife.lua)、[八音盒](../../scripts/features/musicbox/init.lua)。检查入口：[persistence_test.lua](../../tests/persistence_test.lua)、[第二批生命周期](../../tests/batch2_lifecycle_test.lua)、[民俗状态回归](../../tests/folk_run_state_regression_test.lua)。

## 当前局区域解析器

[run_section.lua](../../scripts/runtime/run_section.lua) 导出 `createGetter(store,getRunSeed,create,tableFields)`，返回无参 getter。store 为 Section 形状；getRunSeed 返回当前种子，create 返回含正确 runSeed 的新区域，tableFields 是需补齐为 table 的字段名数组。

getter 每次重新 `store.Get()`，不缓存区域引用；若不是 table 或 `data.runSeed ~= getRunSeed()`，调用 create 后 `store.Replace(data)`；再修复 tableFields 所列字段并返回内部可变表。比较是严格类型和值比较，不自动 tostring；`"123"` 与123不同。create 的正确格式是调用者责任，无递归验证、异常吞掉或自动 Save。

这只能识别旧合同中的种子不匹配，不能替代同种子新局重置。调用者仍管理保存、Continue、沙漏及旧引用。真实消费者：[民俗寄生状态](../../scripts/systems/folk_parasite_state.lua)、[椰子账本](../../scripts/features/crazy_coconut/ledger.lua)、[避孕套名单](../../scripts/features/condom/bans.lua)。

## 所有者声明与初始化组合

`legacy_save_schema.lua` 返回纯函数 `compose(schemas)`（点调用）。`schemas` 是非空连续数组，元素为 `{Name=string, Initialize=function(region) ... end}`；Name 必须非空且不可重复，Initialize 可省略。省略表示仅沿旧合同确保根字段为 table，不额外创建子字段。数组缺项、非数组键、重复名称或无效初始化函数在组合阶段断言失败，此时不会读写用户存档。

组合器复制每项的名称和函数引用，保留传入数组顺序；之后修改声明对象或数组不会改变已构造初始化器。它不复制函数的 upvalue，声明函数应无状态。组合器没有模块级可变状态，不访问 Game、RNG、道具池或世界，不注册回调，不读盘，也不创建区域。

返回的 `initialize(root)` 只供 persistence 的加载步骤调用，root 为其内部可变普通数据表。它顺序处理各区域：缺失或不是 table 时替换为空表，再把这一件区域传给所有者 Initialize。返回 nil，不保存；未知根字段、未知子字段、已有有效子表及其引用保持。初始化函数异常直接传播给 persistence 的既有失败锁定，未完成的根不会发布，也不会写盘。初始化不是 Save 前的重复规范化，不参与新局/Continue/沙漏的事件调度。

以下声明均直接由正式 main 加载一次，无需实例化对应玩法。此表顺序就是旧初始化顺序：

| 根字段 | 声明所有者 | 首次加载时额外确保为 table 的子字段 |
| --- | --- | --- |
| `musicboxDeathDebt` | [save_schema](../../scripts/features/musicbox/save_schema.lua) | `debts` |
| `angelbox` | [save_schema](../../scripts/features/boxes/angelbox_save_schema.lua) | `players`、`pendingRewards`、`enteredAngelFloors`、`appliedChanceFloors`、`forcedAngelFloors` |
| `devilbox` | [save_schema](../../scripts/features/boxes/devilbox_save_schema.lua) | `players`、`pendingRewards`、`enteredDevilFloors`、`appliedChanceFloors`、`forcedDevilFloors` |
| `deathTrial` | [save_schema](../../scripts/features/between_death_and_life/save_schema.lua) | `spawnedByFloor`、`preActivationBossClearedFloors` |
| `diceSet` | [save_schema](../../scripts/systems/dice_set/save_schema.lua) | `players` |
| `condom` | [save_schema](../../scripts/features/condom/save_schema.lua) | `banned` |
| `utilityKnife` | [save_schema](../../scripts/features/utility_knife/save_schema.lua) | `players` |
| `crazyCoconut` | [save_schema](../../scripts/features/crazy_coconut/save_schema.lua) | `players`、`playerCounts`、`pending`、`naturalDamage` |
| `blackTaisui` | [save_schema](../../scripts/features/black_taisui/save_schema.lua) | `players` |
| `certificateOfNeverbirth` | [save_schema](../../scripts/features/certificate_of_neverbirth/save_schema.lua) | 无 |
| `houseVsElephant` | [save_schema](../../scripts/features/house_vs_elephant/save_schema.lua) | 无 |
| `everchanging` | [save_schema](../../scripts/features/everchanging/save_schema.lua) | 无 |
| `dogFoodSeries` | [save_schema](../../scripts/features/dog_food_series/save_schema.lua) | 无 |
| `bigDogBark` | [save_schema](../../scripts/features/big_dog_bark/save_schema.lua) | 无 |
| `yinCurse` | [save_schema](../../scripts/features/yins_curse/save_schema.lua) | 无 |
| `reviveMyLove` | [save_schema](../../scripts/features/revive_my_love/save_schema.lua) | 无 |
| `memoryDisorder` | [save_schema](../../scripts/features/memory_disorder/save_schema.lua) | 无 |
| `ringOfSevenCurses` | [save_schema](../../scripts/features/ring_of_the_seven_curses/save_schema.lua) | 无 |
| `nightOfTheCowards` | [save_schema](../../scripts/features/night_of_the_cowards/save_schema.lua) | 无 |

声明只迁移原 legacy 初始化器已经执行的修复。各道具的 runSeed、已有 version、账本校验和旧格式转换，仍由其现有区域访问/生命周期逻辑负责；没有增加任何 version 字段、缺省校验、保存字段或磁盘格式迁移。musicbox 和 dogFoodSeries 等尚未实际使用时也保留旧空区域，因此最早一次 Save 的形状不变。

此文件路径继续保留以便找到旧装配位置，但其内部装配导出已从 `initialize(root)` 改成 `compose(schemas)`。真实直接调用者只有 main，并已同步改为组合后传给 persistence。非空旧根对象或空表直接作为 compose 参数会明确失败，不能沿用旧调用形式。它不是对外 Mod API；玩法工厂的 Section、Scope、GetSaveRoot 和 Save 合同不变。需要撤回这批时同时撤回 main 的声明接线和组合器，保留已存在的磁盘数据即可。

检查：[19 区域及失败合同](../../tests/persistence_schema_ownership_test.lua)、[开工旧版与当前实现对照](../../reports/framework-closure/2026-11-27/save-ownership/compare.lua)。后者对 98 份空档/旧档/缺损数据和 196 组加载—首次保存—再次保存序列比较结果与调用轨迹。序列化比较使用确定性普通数据编码器隔离键枚举顺序；它证明写盘前数据和调用时机相同，不宣称原生 JSON 字节顺序或实机 Continue 已通过。
