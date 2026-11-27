# 已重构道具公共能力补全：验证记录

实施范围为第一至第九批 38 件，四步均完成。逐件依据见 [consumer-inventory.md](consumer-inventory.md)，公共能力与 API 用法入口见[目标架构 12.2](../../../docs/architecture/2026-11-24-neverbirth-target-architecture.md)。本次验收的是该范围内共同机制的实际复用及行为兼容，没有宣称整个 Mod 的最终架构或人工游戏验收完成。

## 四步结果

1. 从当前源码和既有服务建立消费者清单，覆盖38件；没有开始 ACE、焚尽郁结等下一批。
2. 完成12类共同能力的提取/扩展和消费：存档区域、costume、世界/房间/楼层查询、主动槽、RNG、持有查询、战斗来源、射速换算、卡牌算法、盒子账本/发奖、新局清理、渲染偏移。
3. 同合同旧算法退出；薄适配保留旧名字和动态方法行为。33个既有运行文件修改、10个共同模块新增，相关代码7183→6570行（净减少613）。没有按道具ID分支建立总状态机，也没有合并原生回调分发。
4. 共同边界、真实消费者、冻结旧新版、完整加载回滚、回调顺序和选定原生场景分别验证。47个既有行为合同在旧新版各通过一次。

## 冻结与范围

- baseline：1104文件、171236847字节；candidate-runtime：1124文件、171297289字节。两个副本及 SHA256 manifest 不覆盖。
- [scope-parity.json](scope-parity.json)：679个资源文件、25个content/generated文件共704个全部一致；main.lua 与冻结基线一致且临时原生探针已撤下；当前全部运行文件与候选快照哈希相符。
- 明确排除的7个模块保持字节一致：ACE、焚尽郁结、未诞生证明、菜刀、调试遥控器、房子与大象、千变万化。
- 工作期间另有项目知识/Skill 规范任务修改 AGENTS、docs 和检查工具。本轮保留其改动，按新规则补充本轮 API、两项盒子库发现条目和项目地图链接。非运行文件差异列在 scope-parity.json；不能把这些并行变化都计为本次重构。
- 已有 GoodGirl 生命周期修复包含在基线中；对应回归继续通过。

## 自动检查与命令

以下命令均在 Mod 根目录执行，Lua 为 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`。最终命令退出码均为0。

| 命令 | 实际结果 |
| --- | --- |
| `lua tests/shared_capabilities_contract_test.lua` | 世界查询异常/false、房间身份惰性回退、部分槽枚举、RNG错误与消费、live区域/隔离、新局顺序/失败、来源及射速边界通过 |
| `lua tests/shared_costume_consumers_test.lua` | 三个实际消费者执行共同方法；静止不重复增删；各自负缓存/重试/重入政策、表重绑、公开动态方法通过 |
| `lua tests/shared_box_ledger_test.lua` | 两区域/两楼层隔离、旧数值记录、正负概率撤回、生成顺序及返回nil/抛错区别通过 |
| `lua reports/refactor-shared/2026-11-26/compare-registration.lua` | 基础475、扩展489项注册的事件、优先级、过滤、处理器身份和相对顺序完全一致 |
| `node reports/refactor-shared/2026-11-26/run-parity.mjs` | [47/47旧新行为对照](behavior-parity.json)；dofile/loadfile/只读io.open均重定向冻结生产源码，不混读当前main |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' -ReportPath reports/refactor-shared/2026-11-26/final-checks-02.json` | [137通过、0失败、0未运行](final-checks-02.json)，129个Lua测试、314个Lua文件语法检查；通用验证器6条既有警告，严格验证器0警告 |
| `node reports/refactor-shared/2026-11-26/compare-native.mjs native-baseline-01 native-candidate-01` | 两次实际原生结果一致，见下文 |
| `node reports/refactor-shared/2026-11-26/verify-scope.mjs` | 38件范围、704内容/资源、排除项、当前候选哈希及入口恢复通过 |
| `git -c core.safecrlf=false diff --check` | 通过；不替代未跟踪文件语法与范围检查 |

## 原生旧新对照

同一 probe 分别运行冻结旧、新版：

```
pwsh -NoProfile -File reports/refactor-shared/2026-11-26/run-native-isolated.ps1 -Attempt native-baseline-01 -Baseline -TimeLimitSeconds 80
pwsh -NoProfile -File reports/refactor-shared/2026-11-26/run-native-isolated.ps1 -Attempt native-candidate-01 -TimeLimitSeconds 80
```

两次各9组场景、62检查通过，0失败，进程正常退出0。[结构化对照](native-comparison.json)验证所有检查值、9组观察结果及10条椰子结算轨迹一致：避孕套封禁与Morph；椰子自身/中性物品/真实增伤物品结算；Fortune阈值、失效与静止时零刷新；真实costume ID、好女孩跟随实体与状态清理；两盒首次加心、溢出充能、门/房间类型、品质奖励、消耗和去重；老大的指令真实生成/死亡卡牌奖励。

每次事前保护227个存档/配置文件，结束恢复6个变化文件，并归档3个经日志和时间确认的新增测试存档；未识别新增文件0、恢复错误0，入口恢复为true。无桌面鼠标/键盘输入，只关闭本次隐藏启动的进程。状态为 `COMPLETED_LOG_FLUSHED_ON_EXIT`：日志在正常关闭时才刷新，不能描述成轮询中实时观察到完成。

保留原避孕套价格行为：设置7，Morph立即仍为7，随后原生更新成为99；此次原样对照，没有夹带价格修复。外观检查证明真实API调用、实体与状态，不代替人工观察画面。

## 过程中的失败与修正

- 初次预检131通过、2失败：旧 batch8 加载测试固定“两个卡牌消费者”，现已接入老大而更新为三个；并行文档任务的知识检查链接当时暂缺，后由该任务补齐。没有覆盖其他任务工作来消除失败。
- 原生比较器第一次因日志内 JSON 对象键顺序不同报失败（`id,quality` 与 `quality,id`）；原生断言均通过。比较器改为解析嵌入JSON后比较全部字段和值，保留数组顺序与其他文本。未删掉观察字段、未改变生产代码或放宽原生检查。
- 同期规范要求处理器紧邻绑定；泻药拾取处理器与恶魔盒重置处理器放入原有安装位置，保持相同登记序列；针对性加载/回滚与最终全量检查通过。

## 边界与回退

本轮共同能力清单中的适用消费者已切换，没有留下“提了库但消费者以后再迁”的项目。Fortune审计状态、各种获取确认、伤害取消/记录/保命及表现生命周期保留独立的原因逐件写入清单，而非用“特殊道具”统称略过。

没有人工验收整局、所有角色与全部外部Mod组合，也没有给ACE预建无人消费的审计框架。没有提交、推送、打包发布或创意工坊发布。回退仅按 scope-parity.json 的运行文件允许列表逐文件恢复 baseline，新增10个模块按明确清单处理；不能 reset 整个工作区，也不能回退同期知识任务。
