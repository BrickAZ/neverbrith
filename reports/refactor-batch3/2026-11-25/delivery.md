# 第三批四件道具重构交付

日期：2026-11-25（Europe/Warsaw）。本地修改与验证；未提交、推送或发布。

## 实际范围

用户批准第三批：天使盒、恶魔盒、老大的指令、生死一念间。开工时四件已在此前薄入口工作中迁入独立模块，因此本次沿用现有实现，不覆盖其他任务，不将既有迁移算作本次新增代码。

本次实际运行代码变更为 boxes/angelbox.lua、devilbox.lua、shared.lua 三份，以及新增 active_charge.lua、reward_selection.lua 两份。main.lua、老大的指令、生死一念间、交易房与奖励心模块、前两批其他道具均保持本次基线字节。

| 道具 | 唯一入口 | 本批结果 |
| --- | --- | --- |
| 老大的指令 | scripts/features/boss_order.lua | 核对完整召唤/分节组/死亡奖励/运行清理归属；保留现有实现并重新验证 |
| 生死一念间 | scripts/features/between_death_and_life.lua | 核对 deathTrial 区域和完整试炼状态；补充重新加载、跨层奖励和种子变化测试；记录既有原生拾取问题 |
| 天使盒 | scripts/features/boxes/angelbox.lua | 实际消费同一份主动槽充能与奖励筛选实现；自身保留首次使用、资格、品质、池和回退配置 |
| 恶魔盒 | scripts/features/boxes/devilbox.lua | 同上；延后的 InstallCallbacks 阶段不变 |

## 共用能力核对

- active_charge.lua：两件各自创建轻量绑定，内部无玩家/实体缓存。查找顺序、优先槽、容量限制、原生返回的实际接受量、Force=true/Overcharge=false 全部保留。
- reward_selection.lua：两件各自提供品质、池、候选表及回退值，复用一个筛选算法。保持最多 120 次、原种子序列、优先不同奖励、重复候选优于回退，以及原缺少池/配置的行为。恶魔盒空列表回退 118、最终回退 278 的原差异明确保留。
- shared.lua：只构造上述能力，安装时不查询活跃房间、不抽 RNG、不读写存档；世界查询仍在事件发生时执行。
- heart_bonuses.lua 与 box_deal_rooms.lua：沿用单一奖励心递归/去重所有者和真实交易房转换所有者，无新重复实现。
- 本批没有抽取跨道具通用奖励资格服务。两盒每层待发记录、进入记录和旧概率迁移仍在各自模块中，属于尚未进一步归并的相似机制；不宣称全模组公共能力整理完成。
- 生死一念间的充能缺省值、pcall 边界、激活房间判断与两盒不同，不接入两盒的充能实现。

存档格式、数据键、首次使用语义、品质/道具池、资源、随机数消费和公开回调均未改。共享服务不持有存档根的旧引用。

## 恢复点与非相关改动

baseline/ 是开工时实际工作区的 1032 份文件、171095008 字节；不是 Git HEAD，也不是第二批前的旧快照。复制时逐份校验，清单 baseline-manifest.json。candidate-runtime/ 是最终运行内容及测试的独立副本，1037 份文件、171103149 字节；清单 candidate-runtime-manifest.json。

verify-scope.mjs 对所有基线文件检查仅有三份运行模块、一份测试夹具和项目地图发生变化；对独立候选逐文件核对一致性。新增两份运行模块、三份专项测试及本批计划/报告。内容与非相关源码的具体计数见 scope-parity.json。

## 检查命令与证据

工作目录为模组根目录；lua 为 C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe（5.4.6）。

| 命令 | 退出码与覆盖 |
| --- | --- |
| pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' -ReportPath reports/refactor-batch3/2026-11-25/baseline-checks.json | 0；108 项通过，基线 101 个 Lua 测试，6 条已有通用资源警告 |
| lua tests/box_reward_selection_test.lua | 0；12 个真实消费者场景：准确抽取顺序、重复候选、120 次上限、缺少池/配置、旧数值待发格式、两盒存档隔离 |
| lua tests/batch3_lifecycle_test.lua | 0；实际入口加载与试炼已登记处理器：新实例继续、已发奖励不重发、新楼层、种子变化、未知字段保存 |
| lua reports/refactor-batch3/2026-11-25/run-baseline-tests.lua tests/box_reward_selection_test.lua（及 batch3_lifecycle_test.lua） | 两次均 0；新增行为断言在修改前生产源码上也成立 |
| lua tests/batch3_loading_test.lua | 0；四件入口与共享模块各加载一次，关键公开方法的实际来源与登记次数 |
| lua reports/refactor-batch3/2026-11-25/compare-registration.lua | 0；472 条全局事件、优先级、过滤器、处理器身份与登记次序相同 |
| lua tests/thin_entry_installation_test.lua | 0；53 个导入失败与 3 个登记后失败的回调/导出回滚及重新安装 |
| lua reports/refactor-batch3/2026-11-25/check-negative-cases.lua reward（及 charge） | 两次均 0；内存中破坏筛选预算或 Force 参数后，真实消费者测试明确失败；未修改磁盘生产文件 |
| 独立 candidate-runtime/ 中执行 8 个专项 Lua 测试 | 全部 0；详见 candidate-checks.json |

最终同一 LuaAll 命令改用 `-ReportPath reports/refactor-batch3/2026-11-25/final-checks.json`，退出 0：111 项通过，104 个 Lua 测试，234 份 Lua 语法文件，0 失败/阻塞；6 条原有通用资源警告，严格验证器 0 警告。LuaAll 不包括项目所有语言/工具测试，不代表人工验收。

`node reports/refactor-batch3/2026-11-25/verify-scope.mjs` 退出 0：704 份 content/resources/generated 文件、122 份非本次修改的其他 Lua 文件未变，独立候选与当前工作区一致。`git -c core.safecrlf=false diff --check` 退出 0，输出在 diff-check.txt。

## 原生对照

沿用项目后台启动器与恢复工具，真实游戏 v1.7.9b.J835、REPENTOGON 1.0.12a-yin-api1-dev。未升级运行时。每次只控制自有隐藏进程，不使用键鼠，先快照 227 份配置/存档；恢复详情逐次保存在 result.json。

最终配对命令：

```powershell
pwsh -NoProfile -File reports/refactor-batch3/2026-11-25/run-native.ps1 -Attempt baseline-native-verified -Baseline -TimeLimitSeconds 55
pwsh -NoProfile -File reports/refactor-batch3/2026-11-25/run-native.ps1 -Attempt candidate-native-verified -TimeLimitSeconds 55
node reports/refactor-batch3/2026-11-25/compare-native.mjs baseline-native-verified candidate-native-verified
```

探针覆盖两盒首次心转换、真实溢出心碰撞充能、真实入口/交易房、奖励品质及去重；老大的指令原生目标、击杀和卡牌奖励去重；生死一念间真实底座拾取观测、手动使用消耗、激活房间排除、后续敌人强化、实际 Boss 清房后死亡证明及去重。

基线通过原入口配合精确重定向三份变化的盒子模块读取快照。其他生产文件与基线一致；不是仅替换 main.lua 后仍误用新盒子模块。最终探针和配对观测见 native-comparison.json。

最终两个启动命令及比较命令均退出 0。baseline-native-verified 与 candidate-native-verified 各 35 项通过、0 失败，5 组原始观测逐字段一致；游戏均正常退出 0。每轮恢复 6 个变化文件、归档 3 个本次新建文件，0 恢复错误、0 未解决新文件，main.lua 逐字节恢复；收尾无游戏进程遗留。日志在关闭后完整落盘，启动器标记 COMPLETED_LOG_FLUSHED_ON_EXIT；不能把该标记误解为场景未跑完。

前置失败保留，不当作通过：

- baseline-native-01：25 通过、8 失败；心掉落尚未完成出现过程，且试炼脚本取得未自动激活。
- baseline-native-02：30 通过、3 失败；心碰撞已通过，试炼底座拾取动画尚未完成便执行后续使用。
- baseline-native-03：33 通过、1 失败；试炼实际拾取与手动激活通过，固定等待后尚未完成 Boss 清房。
- baseline-native-04：35 通过；candidate-native-01 为 33 通过、2 失败，清房前置条件未成立。两者均不是最终配对。
- 最终探针改为等待真正获得道具，并在原生 Boss 死亡/敌人生成期间持续处理存活敌人直到 IsClear。上述调整仅作用于报告探针；生产机制未因测试失败修改。

## 已确认的旧问题与证据边界

生死一念间的 FindBetweenDeathLifePickupPlayer 只接受 type(value)=="table"。真实玩家为 userdata；最终基线和候选在实际底座拾取完成后都记录 retained=true、active=false。手动充满后使用则消耗道具、保存试炼、强化后续敌人并在清房后发放死亡证明。本批保持这一已有行为，未把结构重构混成无说明的拾取机制修复。

跨进程继续、原生多人/全部角色、分节 Boss 的全部实际组合、视觉/声音/手感仍不构成本次完整人工验收。继续与分节边界有离线行为测试；原生记录只证明本次探针中的具体场景。本次四件收口不等于整轮架构全部验收。

## 回退

退出游戏，检查之后是否又有修改，再从本批 baseline/ 恢复 angelbox.lua、devilbox.lua、shared.lua；保留其他任务的文件。旧三份模块不会引用本次新 helper，可暂留新文件。无需存档转换，不运行全仓库 reset/clean，不覆盖后续游玩进度。测试/文档按本批差异分别回退。
