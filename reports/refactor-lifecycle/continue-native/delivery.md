# 后台真实 Continue 验证补充

日期：2026-11-26。本次完成真实跨进程 Continue：两个不同的隐藏游戏进程，原生保存后从磁盘加载，39 条断言通过、0 失败。没有操作桌面键鼠、焦点或可见菜单，没有改动生产 Lua、根目录旧模块、接口、数值或存档格式，没有提交、推送或打包。

原始证据：[最终结果](background-03/result.json)、[保存进程日志](background-03/seed-game-log.txt)、[读档进程日志](background-03/resume-game-log.txt)、[保存前检查点](background-03/checkpoint.json)、[两个进程之间的磁盘文件哈希](background-03/between-processes-saves.json)、[源码与清理复核](background-03/source-verification.json)。

## 后台方法与真实性

- 本机引擎版本 `1.0.12a-yin-api1-dev`。安装的 `zhlREPENTOGON.dll` 与本地构建文件 SHA256 相同：`A053418AD4851C91203F2E6A7F09E6D1A96FBC8A3294AE31D615FA40EA990B5F`。
- 对照本地匹配源码 [`Quickstart.cpp`](../../../worktrees/repentogon-yin-native/source/repentogon/Patches/Quickstart.cpp)：`-quickstart` 调用 `SetSaveSlot`，读取真实 GameState，只有有效存档才启动。没有手工调用生产 `MC_POST_GAME_STARTED(true)` 处理器。
- 使用临时独立测试 Mod `zz_neverbirth_continue_probe` 安装观察器，不向生产 `main.lua` 注入代码。启动使用 `Start-Process -WindowStyle Hidden -ArgumentList '-quickstart'`。只对本次拥有的隐藏进程发送正常关闭消息；没有键盘、鼠标、前台窗口或桌面输入调用。
- 空槽直接 `Isaac.StartNewGame` 在本环境中没有生成可用原生 GameState。因此成功方案先将已初始化槽的原生文件复制到隔离槽 3，首次后台 Continue 后立即建立固定种子测试新局。初始化副本只用于让引擎进入有效的已选存档环境，不是本轮恢复断言的目标。
- 保存进程 PID `19360`：测试局种子 `27182818` / `B32V WHV6`，`continued=false`。使用真实 `AddCollectible` 获取 7 件道具；通过已有保存状态/API 设置椰子 3 层和黑太岁寄生值 16，真实使用净化蘑菇。保存前采集状态与属性，正常关闭，接收真实保存退出事件。
- 两进程之间实际存在 `rep_gamestate3.dat`，长度 **53330**，SHA256 `081250F0CA17BCAE9D0AA39E45600AAFA8A067DAA90E7BEEF0FF87BF7A790128`；同时记录 Neverbirth 的 `save3.dat`，长度 **5272**，SHA256 `91E019F82E281848906AD65F659633D4273E41DE6D4626B812A91CE3D7F3A7EF`。
- 全新读档进程 PID `49988`：日志 `RNG Start Seed: B32V WHV6 (27182818) [Continue, 3]`，原生启动回调 `continued=true`。该进程没有获取测试道具、设置成长、设置账本或调用新局入口。传入的检查点只用于断言比较。

原生探针：[Lua](background-probe.lua)、[PowerShell 运行器](background.ps1)。实际执行副本另存在最终目录的 `seed-probe.lua`、`resume-probe.lua`，方便对应日志复核。

## 状态和缓存检查

夹具持有美工刀、疯狂椰子、黑太岁、鸿运齐天蛊、针尖、巴比伦好女孩和净化蘑菇。针尖与好女孩参与组合属性，没有单独覆盖它们的全部触发条件。

| 检查对象 | 保存前 / 预期 | 真实读档观察 |
| --- | --- | --- |
| 局与玩家身份 | 种子 27182818，玩家 InitSeed 4239131901 | 两者一致 |
| 美工刀 | 保存计数 1，碎心 1 | 启动时及后续更新均为 1，没有重复获取代价 |
| 疯狂椰子 | 保存成长 3 层 | 恢复 3 层，临时 Pickup 来源表为空 |
| 黑太岁 | 寄生值 16，`meatLumpSpawned=true` | 阶段值与一次性奖励标记均恢复；不以此代替全部奖励实体去重场景 |
| 净化蘑菇 | 当局临时减速 0.03、射速加成 0.75 | 新进程临时状态均为 0，属性相应恢复；保持原 runtime-only 合同，没有增加存档字段 |
| 鸿运齐天蛊 | 根据当前背包得到幸运下限 10 | 运行时 owner 绑定当前原生玩家，自动恢复到 10 |
| 读档后移除椰子 | 移除 3 层对应的 9 点伤害 | 伤害 15 → 6 |
| 再移除美工刀 | 移除 1 点伤害 | 伤害 6 → 5 |
| 再移除鸿运齐天蛊 | 去掉幸运下限 | 幸运 10 → 2 |

读取顺序明确区分启动快照、自然更新后的快照和测试主动刷新：

| 属性 | 保存前 | 读档自然更新后 | 强制 CACHE_ALL 后 |
| --- | ---: | ---: | ---: |
| Damage | 15 | 15 | 15 |
| MoveSpeed | 0.97000003 | 1 | 1 |
| MaxFireDelay | 8.64999962 | 9.39999962 | 9.39999962 |
| Luck | 10 | 10 | 10 |
| TearRange | 260 | 260 | 260 |

速度和射击间隔的差值对应净化蘑菇不跨进程保存的临时状态。自然恢复后执行 `AddCacheFlags(CACHE_ALL)` / `EvaluateItems()`，五项属性均不变；移除上述道具后再次刷新，五项也均不变，因此没有用测试主动刷新掩盖缺失的恢复路径。

鸿运在 `MC_POST_GAME_STARTED` 观察点的 Luck 为 2，六次自然更新后的观察点为 10。当前生产 runtime 本来就在 POST_UPDATE 进行 custom cache / normal cache 两阶段刷新，与本次观察一致；本报告证明自动恢复，不声称启动处理器内部立即达到最终值。

本轮未复现生产代码缺陷，因此没有新增生产修复或放宽原测试。新增证据是上述真实原生 Lua 断言；失败尝试修正的都是探针入口与恢复脚本。

## 命令与退出码

工作目录均为 Mod 根目录。

| 命令 | 退出码 | 结果 |
| --- | ---: | --- |
| `pwsh -NoProfile -File reports/refactor-lifecycle/continue-native/background.ps1 -Attempt background-01 -SecondsPerProcess 45` | 1 | seed 7/0；Fadeout 后无原生 GameState，resume 未完成。不是道具恢复失败。 |
| `pwsh -NoProfile -File reports/refactor-lifecycle/continue-native/background.ps1 -Attempt background-02 -SecondsPerProcess 40` | 1 | seed 7/0；正常关闭仍无有效原生 GameState，新增磁盘前提检查阻止执行空的 Continue。 |
| `pwsh -NoProfile -File reports/refactor-lifecycle/continue-native/background.ps1 -Attempt background-03 -SecondsPerProcess 40` | 0 | 初始化隔离槽后成功：seed 8/0、resume 31/0，两游戏进程退出码均为 0，正常关闭。 |
| Lua `loadfile` 检查 `background-probe.lua` 及最终两份原生执行副本；PowerShell AST 解析 `background.ps1` | 0 | 三份 Lua 和 PowerShell 均可解析。 |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/refactor-lifecycle/continue-native/check-luaall.json` | 0 | 142 个 `*_test.lua`、348 个语法文件，150 项通过、0 失败、0 未运行；包括通用与严格验证器。 |

完整自动检查证据：[JSON](check-luaall.json)、[日志](check-luaall.log)。通用验证器保留原有 6 条资源路径警告，严格验证器 0 警告。LuaAll 的 `InGameVerified=false` 是运行器本身的覆盖边界；本报告的原生证据单独记录，不修改该标记。数量反映当前工作区，也包括此前其他任务增加的文件，不把它们算成本轮新增测试。

01/02 的原始失败记录保留。它们首次自动恢复留下了本轮新建的 Neverbirth `save3.dat`，随后核对快照缺席、生成时间、测试种子和哈希后移至报告目录；分别见 [01 补充恢复](background-01/supplemental-recovery.json)、[02 补充恢复](background-02/supplemental-recovery.json)。成功运行器已加入这一个确切新文件的归档处理，不扩大为清除其他存档。

## 恢复与证据边界

成功运行前快照 227 个存档/配置文件；结束后校验全部恢复，3 个发生变化的原文件恢复原值，测试生成文件已归档。`stateRestored=true`，`restoreErrors=[]`，`unresolvedNewFiles=[]`，临时测试 Mod 已移除，复核时无 Isaac 进程。恢复辅助函数只写报告中的 main 副本，生产 `main.lua` 全程未由本次运行器写入。

本次运行前后比较 347 个生产/测试 Lua 文件，其中根目录 44 个，哈希变化数均为 0。保留工作区此前其他任务的修改，不使用 Git HEAD 作为本次基线。

**仍未验证**：真实可见菜单按 Continue 的 UI 路径、同进程菜单退局后 Continue、真实热卸载、多人、所有重构道具逐件的原生场景、人工画面与操作感受。本轮证明的是以上组合在本机当前引擎和已启用 Mod 环境中的真实跨进程读档；没有扩大为所有道具及环境的完整验收。
