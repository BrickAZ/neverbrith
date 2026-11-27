# 未生证明与再契象：显式跨模块依赖

日期：2026-11-26。范围仅为两件道具之间的接口连接、main 装配、相关测试和 API 说明。未迁移或修改其他道具玩法，未提交、推送或发布。

## 实现

旧实现共五处从公共 Mod 对象查找对方：未生证明的 useItem/newRoom/update 读取 House CarrierAPI，再契象的接管与返回读取 Certificate CarrierAPI。

现在两个工厂各返回自己的 CarrierAPI，main 创建一次并保存到局部变量，通过 `GetHouseCarrier` / `GetCertificateCarrier` provider 显式注入。本件入口仅向实际消费者传递该依赖，三个私有消费模块不再读取对方的公共字段。provider 在事件时解析，安装期不查询尚未装配的对方；没有新增中转服务、全局 registry、调度器、回调或存档字段。

原 `Neverbirth.CertificateOfNeverbirthCarrierAPI` 和 `Neverbirth.HouseVsElephantCarrierAPI` 保留为同一对象的兼容别名，方法签名和直接调用不变。修改接口对象上的方法仍可见；替换整个公共字段不再改变内部实例配对，这是本次移除隐藏依赖的明确边界。缺少 provider 在任何本件注册/发布前失败；独立宿主显式返回 nil 时沿用无支持所有者的原拒绝/返回行为。

详细参数、返回值、副作用、实例所有权、生命周期、示例和消费者见 [API 说明](../../../docs/api/archive-rooms.md#两件道具的显式装配接口)及 [索引](../../../docs/api/index.md)。

## 范围与并行工作

- 保存开始时 206 个根目录/scripts/generated Lua 文件为 baseline，不使用 Git HEAD 覆盖脏工作区。
- 正式运行改动仅六个文件：main.lua、两件入口、Certificate flow/runtime、House flow。冻结候选的全部其他生产 Lua 与 baseline 一致，见 [改动清单](candidate-changed-files.json)和 [差异](production.diff)。
- 新增 `tests/archive_dependency_wiring_test.lua`；既有 pair fixture 接收明确的两接口，独立生命周期 fixture 显式传无对方 provider，原行为断言不删除、不放宽。
- 另一任务在本轮期间更新千变万化资源模块，并多次暂时替换 main 执行原生探针。本轮没有覆盖它。首次候选捕获遇到临时入口后，改用 baseline 加六个本轮改动生成独立候选；正式入口恢复及最终检查结束后，六文件均与受测版本一致。其他并行变化单列于 [范围核对](source-parity.json)，没有回退。
- 一次当前工作区 LuaAll 被并行探针干扰，80 通过、73 失败；失败栈进入 `reports/refactor-batch12/2026-11-26/probe.lua`，不是把失败改判为成功。原始结果保存在 [受干扰 JSON](lua-all-concurrent-probe.json) / [日志](lua-all-concurrent-probe.txt)，随后重新运行完整检查。

## 自动与前后对照

Lua 运行器为 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`。下列命令从模组根目录执行；`<本报告>` 表示 `reports/refactor-fixes/2026-11-26-archive-dependencies`。

| 检查 | 实际命令与结果 |
| --- | --- |
| 新依赖回归（修改前） | `lua.exe tests/archive_dependency_wiring_test.lua`；退出 1，六个场景暴露公共查找、未导出实例及缺少显式依赖，见 regression-before.txt。 |
| 新依赖回归（修改后） | `lua.exe <本报告>/run-frozen.lua candidate-runtime tests/archive_dependency_wiring_test.lua`；退出 0，7 场景通过，包括后补的安装期不查询对方，见 regression-after.txt。 |
| 现有行为与状态对照 | 对 baseline/candidate-runtime 分别运行 `run-frozen.lua <版本> tests/<certificate_of_neverbirth_behavior_test或house_vs_elephant_behavior_test或batch10_pair_lifecycle_test或four_items_run_boundary_test>.lua`；八次退出 0。覆盖原行为、三人领取、嵌套、接管、返回失败、Continue、同种子新局及扩展字段保留。 |
| 加载与回滚 | `lua.exe tests/batch10_loading_test.lua`；退出 0，私有模块一次创建、回调归属及12个注册失败阶段回滚通过。原运行时生命周期专项也退出 0。 |
| 完整入口登记 | `lua.exe <本报告>/compare-registration.lua`；退出 0，legacy 520、complete 534 条登记前后一致，包含事件、过滤、优先级、处理器身份及相对顺序。见 registration-comparison.txt。 |
| 存档/世界操作轨迹 | `lua.exe <本报告>/run-frozen.lua <版本> <本报告>/trace.lua`；两次退出 0，7 组轨迹各405370字节，SHA256 相同。包含全部 plain-table Save 根数据、位置、实体、房间转换和日志，见 trace-comparison.json。 |
| 当前工作区 LuaAll | 退出 0；153 项通过、0 失败、0 阻塞，包含145个 Lua 测试、359个 Lua语法文件。详见 [最终 JSON](lua-all.json) / [日志](lua-all.txt)。通用验证器6条既有资源警告，严格验证器0警告。 |

本次完整检查命令：

```powershell
pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/refactor-fixes/2026-11-26-archive-dependencies/lua-all.json
```

当前总数包含并行任务增加的测试/源码，不将全部增量算成本批新增。通用警告仍是三个语言 items XML 中的 `gfx/UI/NeverbirthDeathItems.anm2` 与 `Collectibles_025_Breakfast.png` 未解析路径；本批未改资源。运行器的 `InGameVerified=false` 表示 LuaAll 本身不启动游戏，下节本轮原生证据单独成立。

## 本轮原生对照

本机 REPENTOGON `1.0.12a-yin-api1-dev`，使用同一份第十批探针，在冻结 baseline 和 candidate-runtime 各运行一次。两次各 **3 个场景、26 个断言通过、0 失败**；6 组观测完全一致。

1. 使用未生证明、分页，核对底座、机关、页码和会话栈。
2. 嵌套第二层未生证明，再契象接管；接管期间拒绝未生证明；返回子会话、父会话，再回到原房间与原位置。
3. 原房间记录道具，进入再契象选择房间，通过原生碰撞领取三件；前两件继续留在房间，第三件关闭会话并返回。

实际命令：

```powershell
pwsh -NoProfile -File reports/refactor-fixes/2026-11-26-archive-dependencies/run-native.ps1 -Attempt native-baseline-01 -Baseline -TimeLimitSeconds 55
pwsh -NoProfile -File reports/refactor-fixes/2026-11-26-archive-dependencies/run-native.ps1 -Attempt native-candidate-01 -TimeLimitSeconds 55
node reports/refactor-fixes/2026-11-26-archive-dependencies/compare-native.mjs native-baseline-01 native-candidate-01
```

三条命令均退出 0。结果分别见 [旧版](native-baseline-01/result.json)、[新版](native-candidate-01/result.json)、[比较](native-comparison.json)。游戏日志中的完整总结在正常退出时落盘，所以状态为 `COMPLETED_LOG_FLUSHED_ON_EXIT`；不是把没有完成的探针超时当成通过。

每次先备份227个配置/存档文件，结束后恢复6个实际变化文件，并按精确路径、时间与哈希证明归档3个本次新生成文件。两次 `mainRestored`、`stateRestored`、`cleanShutdown` 为 true，恢复错误及未知新增文件均为空。未使用桌面键鼠，只正常关闭本脚本启动的隐藏游戏进程。运行器拒绝覆盖其他任务临时入口或与共享游戏实例并行。

## 按验收标准判定

- **逐道具所有权/薄入口**：通过本批适用项。规则与状态仍归两件私有模块，main 只连接依赖。
- **显式依赖/实例隔离**：通过。内部不读取对方公共 Mod 字段；单次安装、未就绪/缺失 provider、公共别名替换及跨实例卸载有回归。
- **玩法/存档/原生顺序**：通过本批覆盖场景。没有修改账本字段、序号、保存调用点、领取数量、嵌套/Continue政策、RNG、资源、品质或池；原登记序列、完整模拟保存轨迹及原生观测保持。
- **失败清理**：现有安装事务继续拥有回调和导出撤回；12个本件登记失败场景通过，没有新增自建回滚系统。
- **生命周期**：同种子新局、Continue、退出/卸载、过期实例由自动检查覆盖，原生覆盖本轮嵌套/接管/返回和实际领取。本轮未另做跨进程 Continue、真实多人、沙漏原生回退或人工画面/手感验收，不扩大为整个框架完成。
- **公共接口交付**：API 文档、真实装配消费者和专项检查同批更新。沿用 archive_room/archive_controls，没有为这次互调再造重复公共机制。

## 撤回

无需迁移存档。需要撤回时先核对当前文件仍为本次版本，仅恢复六个允许文件中本轮差异，并同步撤回依赖测试/文档的对应变化；baseline 保存了运行代码原版。不能整体恢复快照、重置整个仓库或覆盖并行任务的修改。
