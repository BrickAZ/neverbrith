# 存档初始化所有权收尾

日期：2026-11-27（Europe/Warsaw）。19 个原 legacy 区域的首次加载声明现由对应 feature/system 拥有；正式 main 按原顺序组合声明，persistence 仍在第一次 GetRoot/Section.Get/Save 时执行初始化。未修改磁盘格式、版本字段、区域名称、保存时机、未知字段或玩法政策。

## 实现

- 19 份 save_schema 只导出 Name 与可选 Initialize(region)，不实例化玩法、不注册回调、不访问游戏。空区域仍在第一次加载时创建，未推迟到持有道具或第一次更新。
- scripts/runtime/legacy_save_schema.lua 成为 compose(schemas) -> initialize(root)；底座不再持有任何道具名或反向 include 玩法。组合时拒绝空/缺项数组、无效声明、重复区域及无效初始化函数，保留原顺序并复制名称与函数引用。
- 持久区域仍由既有访问和生命周期代码负责 runSeed、已有 version、局/房间重置、Continue 和沙漏。没有新增格式迁移、自动修复范围或 Save 前重复规范化。
- persistence.lua 的加载失败锁定、Scope、Section 和保存实现未改。所有者初始化异常继续进入现有失败锁定，不会发布或保存半初始化根。
- 主代理已接入 main 的有序声明并更新 API 索引；本子任务没有编辑 main 或总索引。完整用法、参数、引用和实际所有者见 [persistence.md](../../../../docs/api/persistence.md)。

旧 legacy_save_schema 导出属于内部装配合同；实际生产直接调用者检索只有 main，tests/batch1_loading 仅检查模块被加载。该内部导出由 initialize(root) 改为 compose(schemas)，不能把旧根直接传入。新接口拒绝旧对象/空表形式，避免静默漏初始化；对外 Mod 工厂、GetSaveRoot、Scope、Section、Save 不变。

## 检查

实际命令：`pwsh -NoProfile -File reports/framework-closure/2026-11-27/save-ownership/run-checks.ps1`，退出码 0。完整命令、每项退出码及日志名见 [checks.json](checks.json)。Lua 为 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`。

| 检查 | 退出码 / 证据 |
| --- | --- |
| persistence_test.lua | 0；既有延迟加载、错误锁定、安全保存、失败重试 |
| persistence_scope_test.lua | 0；既有权限、nil/false、替换和全根保存 |
| persistence_schema_ownership_test.lua | 0；19 区域首次形状、有效旧数据与引用保持、原有标量/子表修复、声明错误、第一次 Save 与初始化失败禁写 |
| persistence_schema_loading_test.lua | 0；真实 main 19 声明单次加载、原顺序、19 个缺失模块的完整安装回滚 |
| batch1_loading_test.lua | 0；既有真实入口、重复实例、签名及反例 |
| batch13_loading_test.lua | 0；集成追加：精确保留 17 个玩法模块断言，单独要求新增 owner schema 加载一次；16 个登记失败回滚不变 |
| framework_shared_wiring_test.lua | 0；实际分区消费者、共享实例及缺模块回滚 |
| compare.lua | 0；开工冻结旧版与当前实现：98 份数据样本、196 组加载/首次保存/再次保存序列，结果及调用轨迹完全相同 |

`git diff --check -- scripts/runtime/legacy_save_schema.lua docs/api/persistence.md` 退出 0。`manifest.py` 退出 0，记录子任务拥有文件的前后哈希，见 [owned-manifest.json](owned-manifest.json)。main 与 API 索引由主代理另记。

主代理第一次整轮 LuaAll 为 180 通过、1 失败、0 警告：第 13 批加载夹具按路径前缀把新 save_schema 误算入原 17 个玩法模块。仅将这一份非玩法声明分开计数，原 17 个模块与 16 条回调的精确断言保持，新增 schema 必须恰好加载一次；缺声明回滚由 persistence_schema_loading_test 已覆盖。单独重跑 `lua tests/batch13_loading_test.lua` 退出 0，日志和命令已追加 checks.json，未来 run-checks.ps1 也包含此项。没有修改生产逻辑或把断言放宽为下限。

旧新对照使用确定性普通数据编码器，避免键遍历顺序误判；它比较传入编码器的数据与保存调用轨迹，不声明原生 JSON 字节序相同。本轮未启动游戏；跨进程 Continue/原生沙漏与整轮验证由主代理统一调度。

并行期间曾运行 `pwsh -NoProfile -File tests/project_knowledge_test.ps1`，退出 1：API 总索引当时已加入另一子任务尚未写出的 plain-data.md 链接。本子任务未覆盖该任务文件，也未将该次结果记为通过；最终全量知识检查由主代理在并行文件全部落盘后运行。

## 回退

仅按 owned-manifest.json 恢复原 legacy 组合器位置和存档说明，移除本批新增 schema/测试；同时由主代理撤回 main 的 schema 接线和相应 API 索引条目。保存格式没有升级，回退代码不需要迁移用户存档。不得覆盖整工作区或开工后其他任务的修改。
