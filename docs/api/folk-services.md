# 民俗组共享服务

这些服务保留当前民俗道具组的键格式、默认值与公开兼容方法，不是自动适用于所有角色和道具的新通用框架。实际创建和依赖顺序见 [main.lua](../../main.lua)。

## World

来源：[folk_world.lua](../../scripts/systems/folk_world.lua)。`include(...)(mod,{IsValidItemId=...})` 返回 table，无 callback；下列是点调用。

| 接口 | 返回、失败和副作用 |
| --- | --- |
| `GetFolkGame()` / `GetFolkRoom()` | 实时引擎对象或 nil；保护对应 Game/Room 查询 |
| `GetFolkRoomKey()` | `stage:stageType:roomIndex`，失败 `0:0:0`；不含 run seed 或 dimension，不是跨局唯一键 |
| `GetFolkFloorKey()` | `stage:stageType`，失败 `0:0`；不代表镜像维度/独立生成身份 |
| `GetFolkPlayerKey(player)` | tostring(InitSeed)，缺失为 `"0"`；不是所有角色切换语义的通用身份服务 |
| `PlayerHasCollectible(player,itemId)` | 合法 ID 才查 HasCollectible；失败可回退数量；返回 boolean |
| `GetPlayerCoins(player)` | 原生数量查询失败时回退 player.coins 或0 |
| `AddPlayerCoins(player,amount)` | 调用 AddCoins，捕获异常，无成功回执；不能作为“已支付”的证明 |
| `GetFolkRandomInt(player,itemId,max)` | max 默认1，<=1 返回0；优先道具 RNG，结果夹在0..max-1；不支持时回退 math.random(max)-1 | 
| `IsVulnerableEnemy(entity)` | 排除玩家类型，再调用实体查询；失败 false |
| `SpawnFolkEffect(variant,position,spawner)` | 生成 effect 类型、subtype0、零速度；position 缺省 Vector(320,280)；无 Spawn 则 nil，原生 Spawn 异常不被捕获 |

常量 `FOLK_ENTITY_PICKUP`、`FOLK_PICKUP_HEART` 是当前引擎值或5/10回退。随机函数实际消耗随机流，math.random 回退不保证与原生道具 RNG 相同；不要用于不应改变游戏随机序列的展示。

```lua
local world = include("scripts.systems.folk_world")(mod, {IsValidItemId = IsValidItemId})
local coins = world.GetPlayerCoins(player)
-- 消费者自己决定是否足够支付以及如何验证支付结果。
```

## 服装和保命冷却

[folk_costumes.lua](../../scripts/systems/folk_costumes.lua)：`include(...)(mod,deps)` 安装 `mod:TryRemoveCollectibleCostume(player,itemId)`，当前不读取 deps，允许省略；无服务返回/回调。找到配置后尝试两种 TryRemoveCollectibleCostume 参数和 RemoveCostume，捕获单次失败；操作会修改玩家表现，无成功回执，不等于移除所有其他道具服装。

[folk_survival_cooldown.lua](../../scripts/systems/folk_survival_cooldown.lua)：`include(...)(mod)` 将公开字段 BlackTaisuiDeathSaveInvincibility 设为60，返回无参查询函数。每次查询读当前字段，因此外部合法修改能被消费者看到。重复创建会重设60；单位和实际传法沿用消费者原生保命调用，不把它解释为60秒。

## 旧寄生状态

[folk_parasite_state.lua](../../scripts/systems/folk_parasite_state.lua)：`include(...)(mod,{World=world,GetCurrentRunSeed=...,Store=...})` 返回点调用接口，创建自己的 blackTaisuiStates 表，无 callback。Store 是现有 blackTaisui 区域；它仍包含肉块的旧字段。

| 接口 | 合同 |
| --- | --- |
| `GetSaveData()` | 返回内部区域；种子不匹配时 Replace 为 runSeed/players/meatLumpCounts/meatLumpLives，再补齐表。会改内存，不自动保存 |
| `GetRuntimeState(player)` | 按 World 玩家键懒创建内部可变状态；楼层键变化重置 deathSavedFloorKey、sporeKeys、wavySuppressedStacks。不是纯只读查询 |
| `ResetRuntime()` | 替换运行状态表；旧消费者持有的状态对象不会自动重绑 |
| `ResetRun()` | 保留区域其他扩展字段，重设本服务拥有的 runSeed/players/meatLumpCounts/meatLumpLives，重置运行表并 Save；没有保存成功返回值 |

按当前拥有者的调用时机使用；不自动提供跨进程 Continue 或沙漏快照。不要把种子相同当作不必新局清理。

## 生命周期协调

[folk_lifecycle.lua](../../scripts/systems/folk_lifecycle.lua)：`include(...)(mod,{GetPlayers=...,CoinFacedMask=...,BlackTaisui=...,GoodGirl=...})` 接收本次安装的三个实际道具实例，无返回服务。不能为获取接口重新安装道具。实际消费者仍是 [main.lua](../../main.lua) 的原民俗组装配位置。

| 原生处理器 | 时机、参数与副作用 |
| --- | --- |
| `mod:ResetFolkHorrorItemState(isContinued)` | MC_POST_GAME_STARTED；先恢复各实例的运行许可。新局依次移除面具/好女孩服装，再调用面具 ResetRuntime、黑太岁 ResetRun、好女孩 ResetRuntime，保留原重置顺序。清旧状态后刷新此前受影响的缓存。Continue 保留原有纯数据；仅实际退局后重入时请求三个实例刷新当前玩家缓存。|
| `mod:ExitFolkHorrorItemState()` | MC_PRE_GAME_EXIT；仅首次有效退出查询当前玩家并移除本组服装，再暂停三个实例。清 Good Girl halo/echo 实时引用，保留原同实例 Continue 的房间记录与剩余 echo 更新次数。重复退出无额外操作。|
| `mod:UnloadFolkHorrorItemState(unloaded)` | MC_PRE_MOD_UNLOAD；仅 `unloaded == mod` 生效。永久停用本实例，清运行状态/实体引用；不调用 GetPlayers/Game，不清保存区域或保存文件。重复卸载安全，旧 GAME_STARTED 不能复活已释放实例。|

三个事件仅在相应 ModCallbacks 成员存在时注册；处理器与绑定在同文件相邻。协调器不是可任意重排的通用事件分发器。正常退局发生时可以移除当前服装；卸载时世界可能不可用，因此不会重新查询玩家来操作服装。

这三个实例传给协调器的接口均为**点调用**，没有成功回执：

| 实例方法 | 合同与实际消费者 |
| --- | --- |
| `ClearPlayerCostume(player)` | 面具与 Good Girl 提供；移除当前玩家的本组 null costume。协调器在新局/首次退局调用。 |
| `ResetRuntime()` | 面具清房间/服装状态并恢复旧幸运缓存；Good Girl 移除跟随特效、清房间/服装记录并刷新旧状态玩家。只在新局使用，不能拿来代替 Continue。 |
| `BlackTaisui.ResetRun()` | 先记录旧属性来源，再调用既有 ParasiteState.ResetRun 清已拥有保存字段/运行表并 Save，最后刷新旧来源玩家。即使已失去黑太岁，只要旧净化蘑菇数值仍在，速度/射速缓存也会重新求值。 |
| `Pause()` | 停止更新与回调玩法操作；保留原同实例 Continue 的纯数据。Good Girl 释放跟随特效，面具清服装显示缓存。黑太岁同时暂停其净化蘑菇与肉块实例。 |
| `Resume(refresh?)` | 已 Dispose 时无操作。恢复更新；`refresh == false` 只恢复许可，默认请求当前相关玩家重算缓存。黑太岁重新建立健康快照观察边界，避免把退局期间的实体差异算作治疗。不会重放奖励或重置本层计数。 |
| `Dispose()` | 不访问世界，永久停用旧实例并清纯运行状态；Good Girl 移除已持有的 halo/echo。黑太岁同时停用净化蘑菇与肉块，但保留 ParasiteState 保存区域。 |

净化蘑菇实例另提供内部点调用 `HasCachedStats(player)`，返回当前/残留速度或射速值是否非零；会通过既有 GetRuntimeState 懒建状态，绝不刷新属性。其唯一生产消费者是黑太岁生命周期模块在 ResetRun 前和实际 Continue 后判断缓存失效范围。它不改变“无黑太岁时净化蘑菇数值不参与缓存”的既有 gate，也不改变丢物后本层残留规则。净化蘑菇和肉块的 `Pause/Resume/Dispose` 只由该黑太岁实例转交，Resume 无 refresh 参数。

这些接口没有添加新的存档字段、存盘权威或沙漏恢复机制。同实例 Continue 保留哪些纯数据，仍由原道具状态拥有者决定；跨进程只能恢复现有保存区域中已有的数据。专项检查：[refactor_lifecycle_folk_test.lua](../../tests/refactor_lifecycle_folk_test.lua)，同时保留原批次行为与生命周期检查。

## 视觉特效

[folk_visual_effects.lua](../../scripts/systems/folk_visual_effects.lua)：接收 `{World=world,GetPlayers=...}`，建立/保留 `mod.FolkVisualEffects` 配置，立即安装一个 MC_POST_EFFECT_UPDATE（存在时），返回 `effects` 服务。它的公开接口采用**冒号调用**：

| 接口 | 合同 |
| --- | --- |
| `effects:Spawn(key,position,spawner,timeout?)` | key 对应已有配置；生成 effect 并写所属 key/超时。timeout 向下取整、至少1，默认配置值或45；可启动动画/绑定跟随。缺配置或 variant 无效返回 nil |
| `effects:IsActive(effect)` | Exists 调用成功则返回其布尔值，否则检查 removed/Removed 字段；不代表与某一玩家的绑定仍正确 |
| `effects:BindOwner(effect,key,owner)` | 只用于配置 followOwner=true；把实时 owner、seed 和 offset 写入 effect:GetData，更新跟随；不满足返回 false，完成返回 true |
| `effects:RefreshTimeout(effect,key,timeout?)` | 原地更新超时，规则同 Spawn；没有可写 data 则不操作，无成功回执 |

mod 上对应兼容方法为 `SpawnFolkVisualEffect`、`IsFolkVisualEffectActive`、`BindFolkVisualEffectOwner`、`RefreshFolkVisualEffectTimeout`，同样使用冒号。正常消费者优先使用装配层传入的 effects 实例。

辅助 mod 方法：`GetFolkVisualEffectVariant(key)` 查名并缓存 variant，无配置返回-1；`GetFolkVisualEffectOwnerSeed(owner)` 取 seed；`GetFolkVisualEffectFollowOffset(spec)` 得跟随偏移；`GetFolkVisualEffectPositionOffset(spec,owner)` 合并配置、玩家 PositionOffset/飞行偏移；`ApplyFolkVisualEffectFollowPosition(effect,owner,spec)` 修改位置、偏移、深度和父级；`GetFolkVisualEffectOwner(data)` 优先旧引用，缺失时按 seed 从 GetPlayers 重绑。它们是兼容辅助表面，不是稳定身份或完整失效检测服务。

`UpdateFolkVisualEffect(effect)` 只处理带所属标记的实体；跟随失败、动画结束或超时耗尽时移除。超时单位是该 effect 更新回调次数，不是秒；需要持续效果的消费者主动续期。data 里的实时引用不进入存档，沙漏/继续恢复由相应道具管理。

真实消费者：[黑太岁](../../scripts/features/black_taisui.lua)、[好女孩](../../scripts/features/good_girl_of_babylon.lua)、[铜钱面具](../../scripts/features/coin_faced_mask.lua)。检查：[folk_modules_shared_dependencies_test.lua](../../tests/folk_modules_shared_dependencies_test.lua)、[folk_run_state_regression_test.lua](../../tests/folk_run_state_regression_test.lua)、[good_girl_lifecycle_regression_test.lua](../../tests/good_girl_lifecycle_regression_test.lua)。
