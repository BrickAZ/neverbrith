# P5 拾取确认：RED 与原生来源证据缺口

日期：2026-09-05。状态：BLOCKED。P5a 已复现 RED，尚未进入 GREEN；P5b、P5c、P5d 按规定顺序尚未开始。主代理确认不放宽真实拾取合同、暂停整个 P5。不能将本报告理解为迁移完成。

## 实际修改

- `tests/big_dog_bark_behavior_test.lua`：仅新增 10 行，通过显式参数 `--pending-p5` 复现取消碰撞后同 ID 代码赠送被错误计数。默认入口不运行该待修复诊断；没有修改既有断言。
- 本报告。
- 未修改 `main.lua`、`big_dog_bark.lua` 或任何生产 XML、资源、数值；保留前批改动。未升级、提交、启动或控制游戏。

## P5a 红绿证据

初次加入反例时，直接运行默认入口，在第 1141 行观察到 RED。确认原生证据缺口后，按主代理要求将反例改为 opt-in pending 诊断，避免默认回归永久失败。当前运行 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe tests/big_dog_bark_behavior_test.lua --pending-p5`，退出 1，先输出 `localization tests passed`，随后在第 1142 行失败：

```text
cancelled collision plus same-ID code grant must not forge a food pickup: expected 0, got 1
```

用例只有 PRE collision 候选，未模拟原生成功碰撞，然后给予同 ID 库存增长。现有 `settleFoodPickups` 在 `big_dog_bark.lua:1546` 附近把数量增长 OR 队列消失作为成功，因而错误累计。RED 属于实际行为错误，不是夹具缺少 API。GREEN 未实施。

不带参数的默认命令退出 0，输出 `localization tests passed` 和 `Big Dog Bark behavior tests passed.`。这是旧行为回归通过，不是 P5a 修复通过。`--pending-p5` 当前明确预期失败。

## 调用合同与证据

1. 本机 `E:/Isaac - Repentance/resources/scripts/enums_ex.lua:4` 定义 `MC_POST_ADD_COLLECTIBLE = 1005`，第 191 行定义 `MC_POST_PICKUP_COLLISION = 1239`。
2. 1.0.12a 官方 `CustomCallbacks.cpp:27-92`：`MC_POST_ADD_COLLECTIBLE(_, Type, Charge, FirstTime, Slot, VarData, Player)` 在原生 AddCollectible 返回后发送。该参数列表没有底座/来源/事务身份；FirstTime 不能证明自然拾取。
3. 同文件第 322-350 行：PRE 碰撞返回可跳过原生内部逻辑；POST collision 只在原生内部逻辑被调用后发送。POST 携带精确 pickup、collider、low，1239 注册过滤为 pickup Variant。它可以补强“哪个底座进入原生碰撞”，但本身不等于入库成功，也不能直接奖励。
4. 1.0.12a `LuaEntityPlayer.cpp:184-192`：Lua 的 `player:AddCollectible` 同样进入上述原生 AddCollectible hook，因此代码赠送也发送相同 POST。
5. 公开 `QueueItemData` 只暴露 Charge、Item、Touched，没有 pickup identity 或 transaction ID。QueueItem 文档说明动画后队列入库，但未规定 native FlushQueueItem 内清除 queue 与调用 AddCollectible 的精确先后。

来源：

- [1.0.12a 原生回调实现](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/LuaInterfaces/CustomCallbacks.cpp#L27)
- [1.0.12a 玩家 Lua 入库绑定](https://github.com/TeamREPENTOGON/REPENTOGON/blob/1.0.12a/repentogon/LuaInterfaces/Entities/LuaEntityPlayer.cpp#L184)
- [QueueItemData 公共字段](https://wofsauge.github.io/IsaacDocs/rep/QueueItemData.html)
- [EntityPlayer 队列接口](https://wofsauge.github.io/IsaacDocs/rep/EntityPlayer.html#queueitem)

## 技术缺口（不是用户玩法待定）

POST collision 可把一个实际底座的 queue 新进入阶段归属到玩家，但之后仍须证明某个 POST_ADD 属于该 queue flush，而非同 ID 代码赠送。当前已查源码只是原生方法 hook，没有 FlushQueueItem 内部实现/来源标记。

不能排除的同观测轨迹：已经看到某底座进入 queue；后续发生参数相同的 POST_ADD；最终 queue 空、底座消失、数量增加。此序列既可能是正常原生 flush，也可能是同 ID 代码赠送加队列取消/来源移除。如果只使用 queuedSeen + POST + sourceGone，仍然将后者误认成真实拾取。这里没有将该假设写入生产，也没有用最近同 ID 或数量 +1 替代。

下一步需要同版本原生 flush 时序或更强来源标记证据，以确定可保守排除的阶段。仅靠编造 Lua 夹具的事件顺序不能证明真实引擎合同；无来源的 POST 必须不结算。即使取得正常时序证据，其他 Mod 修改 queue 的兼容边界仍须显式说明。

## 覆盖检查

| 测试 | 当前结果 |
| --- | --- |
| big_dog_bark_behavior_test.lua（默认） | 退出 0，`Big Dog Bark behavior tests passed.` |
| big_dog_bark_behavior_test.lua --pending-p5 | 退出 1，新增 RED，上述 expected 0 got 1；当前预期失败 |
| condom_utility_knife_behavior_test.lua | 既有失败，第 386 行 Crazy Coconut 旧 XML 文案正则 |
| dog_food_series_behavior_test.lua | 既有失败，main.lua:20532 的旧 main-only 夹具缺 include |
| little_leather_shoes_behavior_test.lua | `little leather shoes behavior tests passed`（含 localization passed） |
| localization_test.lua | `localization tests passed` |
| luac -p main.lua、big_dog_bark.lua、四份目标测试 | 退出 0，无语法错误 |
| git diff --check -- big_dog_bark.lua tests/big_dog_bark_behavior_test.lua | 退出 0；仅 Git LF/CRLF 提示，无 diff 空白错误 |

P5b-d 没有进入 TDD，未为旧失败调整 XML 或夹具。没有游戏内时序、商店付款、免费底座、换主动、双人争抢、读档或动画队列验收；这些全部仍未验证。

## 工具边界

普通 shell/apply_patch 遇到辅助程序 `apply deny-read ACLs` 初始化错误。仅对上述测试和本报告使用安装目录内 `codex.exe --codex-run-as-apply-patch` 同引擎提权重试，没有改 ACL 或机器设置。
