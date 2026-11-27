# 玩家、种子与基础操作

来源：[players](../../scripts/runtime/players.lua)、[run_seed](../../scripts/runtime/run_seed.lua)、[log](../../scripts/runtime/log.lua)、[world_feedback](../../scripts/runtime/world_feedback.lua)。它们不注册回调，不保存道具状态；装配与消费者见 [main.lua](../../main.lua)。

```lua
local GetPlayers = include("scripts.runtime.players")
local GetCurrentRunSeed = include("scripts.runtime.run_seed")
local Log = include("scripts.runtime.log")
local Feedback = include("scripts.runtime.world_feedback")
```

| 接口 | 参数、返回和失败 | 所有权 / 时机 / 副作用 |
| --- | --- | --- |
| `GetPlayers()` | 返回新的玩家数组；优先 Game:GetNumPlayers + Isaac.GetPlayer，必要时回退 FindByType | 数组新建，元素是实时玩家对象；回退分支没有包住所有异常。不是存档身份键、对象快照或“排除所有幽灵”的保证。需要引擎环境 |
| `GetCurrentRunSeed()` | 优先 GetStartSeedString；其次 GetStartSeed 转字符串；无法取得返回 `"unknown"` | 不消费 RNG；不是局唯一 ID，同种子重开仍是新局。GetSeeds 等并非全部受 pcall 保护 |
| `Log(message)` | 传日志字符串；无有用返回；优先 Isaac.DebugString，之后 print | 只写诊断输出，不渲染 HUD；要求正常 Isaac 全局环境，调用失败不普遍吞掉 |
| `Feedback.Darken(amount)` | amount 默认 0；无有用返回；没有 game/Darken 时不执行 | 调用 `Game():Darken(amount, 2)`；第二参数固定为现有原生调用值 2，不从此接口推断秒数。是世界表现操作，不是纯查询 |

使用示例（在已运行游戏事件内，依赖由装配层传入也等价）：

```lua
for _, player in ipairs(GetPlayers()) do
    -- 将真实 player 交给该道具的已定义业务操作。
end
Log("[neverbirth] run seed=" .. tostring(GetCurrentRunSeed()))
```

不把返回的玩家存入 JSON；跨换房、退出或玩家重建后重新查询。种子 `unknown` 不能用来合并独立玩家/独立局状态。生命周期由消费者拥有。

验证入口：[首批加载](../../tests/batch1_loading_test.lua)、[完整入口安装](../../tests/thin_entry_installation_test.lua)、[民俗运行状态](../../tests/folk_run_state_regression_test.lua)。这些是相关覆盖入口，不表示每个异常路径都有独立测试；实际结果按本次检查记录报告。

## 新局清理处理器

来源：[new_run_reset.lua](../../scripts/runtime/new_run_reset.lua)。`include("scripts.runtime.new_run_reset")(steps)` 返回原生 handler `function(_,isContinued)`，不注册 callback、不派发事件。

`steps.Reset` 为必需的无参函数数组；`steps.Players` 为可选的逐玩家清理函数数组，提供时必须同时提供 `steps.GetPlayers()`。继续游戏直接返回；新局先对所有玩家按 Players 数组顺序清理，再按 Reset 数组顺序执行共享状态重置。两组顺序及“全部玩家清理完再重置”不可互换。

函数保存传入 steps 表的引用，不做拷贝或验证，不捕获清理异常，也不自动 Save。它不是重复调用幂等保证；消费者负责注册一次、玩家身份和重置函数语义。真实消费者：[folk_lifecycle.lua](../../scripts/systems/folk_lifecycle.lua)、[两盒心奖励](../../scripts/features/boxes/heart_bonuses.lua)、[避孕套](../../scripts/features/condom.lua)、[疯狂的椰子](../../scripts/features/crazy_coconut.lua)。用于新 callback 时，保持[开发规范](../agent/development-conventions.md)中的本地处理器与绑定紧邻。

避孕套与椰子在 `InstallGameStarted()` 中创建本地处理器并紧邻绑定，由各自状态模块清理并保存已有字段；椰子同时释放旧拾取来源引用、刷新开局持有者的伤害缓存。继续游戏保持原数据。同种子新局、多人旧账本、待结算记录及安装失败清理的覆盖见[运行生命周期回归](../../tests/condom_coconut_run_lifecycle_test.lua)。
