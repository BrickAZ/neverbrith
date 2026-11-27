# 第二十批：记忆紊乱交付

本件的结构重构与离线验收完成，已经落到当前工作区；本轮原生及人工验收未完成。没有提交、推送或发布。保留其他批次未提交改动，以本批开工时实际 `memory_disorder.lua` 为比较基线，不使用 Git HEAD 代替。

## 结果与范围

- 根目录 `memory_disorder.lua` 收缩为三行兼容入口，仍返回同签名工厂。实际装配在 `scripts/features/memory_disorder.lua`，十个私有模块分别拥有玩家访问、角色配置、生命、临时构筑、存档、伙伴、身份切换、图标、虚空路线和生命周期。
- 90 个原函数正文逐字保持；角色表、常量和初始状态保持。保留 11 个回调的相对顺序、过滤与返回方式，处理器和对应安装器同文件紧邻。
- 正式路径继续复用已注入的 persistence、players、run_seed、world_feedback 和主入口安装事务。没有新增公共库；不同语义的主动槽、配置查询、玩家键和 RNG 保留差异。逐项依据见 [consumer-inventory.md](consumer-inventory.md)。
- 保留 `memoryDisorder` version 1、持久/运行时身份键、原存档字段和保存时机、自定义角色数组与原内部 API。品质、道具池、资源、本地 ID 55 均未由本批改动；没有新增沙漏政策。
- 四份既有专项测试不改断言、不改夹具；新增 `tests/memory_disorder_loading_test.lua`，覆盖完整入口中的模块缺失、登记失败回滚、回调顺序/过滤与重新安装状态隔离。

## 实际检查

以下命令从模组根目录执行，Lua 为 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`，版本 5.4.6。每个冻结 Lua 用例的命令与退出码保存在 [frozen-comparison.json](frozen-comparison.json)，原始状态轨迹和命令在 [equivalence.json](equivalence.json)。

| 命令 | 退出码与结果 |
| --- | --- |
| `lua tests/memory_disorder_behavior_test.lua` | 0，原行为场景通过 |
| `lua tests/memory_disorder_health_regression_test.lua` | 0，9 组生命回归通过 |
| `lua tests/memory_disorder_pairs_regression_test.lua` | 0，8 组伙伴回归通过 |
| `lua tests/memory_disorder_icons_test.lua` | 0，10 组图标回归通过 |
| `lua tests/memory_disorder_loading_test.lua` | 0，10 个缺失模块、11 个回调失败位置及新实例隔离通过 |
| `node reports/refactor-batch20/2026-11-26/verify.mjs` | 0，90 函数正文一致；四组旧新运行/存档轨迹共 1,265 个观察一致 |
| `lua reports/refactor-batch20/2026-11-26/closure-equivalence.lua` | 0，90 个具名函数、100 个总函数、109 个表、368 个捕获值的结构和共享引用一致 |
| `node reports/refactor-batch20/2026-11-26/compare-all.mjs` | 0，候选 157/157、旧版本 156/156 Lua 用例通过，零新增/共同失败；500 文件语法通过 |
| `pwsh -NoProfile -File tools/validators/validate-neverbrith.ps1 -Root reports/refactor-batch20/2026-11-26/frozen -GameRoot 'E:/Isaac - Repentance'` | 0，严格验证零警告、零失败 |
| `pwsh -NoProfile -File tools/validators/validate-isaac-mod.ps1 -Root reports/refactor-batch20/2026-11-26/frozen -ModObjectName Neverbirth -SkillRoot reports/refactor-batch20/2026-11-26/frozen/.agents/skills` | 0，通用验证零失败，6 条资源定位警告，见下文 |
| `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1` | 前次 0，9 页可达、258 本地链接有效；最终复核 1，其他任务新增第十三批尚不存在的交付链接，见下文 |
| `node reports/refactor-batch20/2026-11-26/check-scope.mjs` | 0，12 个运行文件与已测冻结副本一致，四份原测试和主入口接入段不变 |
| `git diff --check -- memory_disorder.lua docs/agent/topics/memory-disorder.md docs/agent/project-map.md` | 0 |

冻结环境把当前运行模块、测试、配置和资源复制到本目录 `frozen/`，主入口使用本批开工时未挂载临时探针的副本。旧新两次仅替换该副本内的 `memory_disorder.lua`；基线不运行专门要求新布局的新增加载测试，其余 156 个用例相同。检查结束恢复冻结候选入口。没有替换共享工作区 `main.lua`。因此这里证明冻结组合的全部 Lua 行为通过，不能标为仍在变化的整份工作区已完成全量验收。

轨迹探针对双方固定 `pairs` 顺序以排除不同进程的字符串哈希序，并按 ID/路径比较原生配置模拟对象；原四组测试也在正常 `pairs` 下独立通过。闭包图比较进一步检查实际绑定和共享表，避免只凭正文相同推断依赖正确。

通用验证器的 6 条警告为三个语言 items XML 各自的 `NeverbirthDeathItems.anm2` 与原版 Breakfast 图像解析；严格验证器按 content 相对路径/明确游戏目录检查，零警告。保留两份原始日志，不把通用定位限制隐去。

## 共享工作区的未通过检查

最初实际运行 `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/refactor-batch20/2026-11-26/first-checks.json`，退出码 1：82 项通过、78 项失败、1 项阻塞、6 条警告。原始记录见 [first-checks.json](first-checks.json)。当时主入口被其他任务挂载原生探针，另有并行模块/测试未收口；没有把该次结果写成通过。随后采用上面的冻结环境完成全部 Lua 用例对照，全部通过。

该入口的语法子进程还遇到 Windows 命令行过长（“文件名或扩展名太长”），本批没有改动公共检查器；冻结比较通过 stdin 提供文件清单，实际调用 `loadfile` 解析 500 个文件，补足了本批语法证据。

`pwsh -NoProfile -File tests/project_knowledge_test.ps1` 最后仍返回 1：其他任务新增的 `scripts/systems/attack_ownership.lua` 尚未被公共 API 索引覆盖，见 [knowledge-final.log](knowledge-final.log)。本批未创建或修改该公共模块及其 API 文档，不代替其所有者填写未经确认的使用合同。

导航检查前次通过（9 页、258 链接）。最终复核时其他任务已向共享 project-map.md 新增第十三批链接，而 `reports/refactor-batch13/2026-11-26/delivery.md` 尚不存在，因此退出码改为 1，见 [navigation.log](navigation.log)。没有删掉其他任务的链接或编造其交付文件；也不把此前通过写成最终整个知识库通过。

## 审查、原生边界和回退

独立只读审查没有发现本次引入的可操作问题，详见 [review.md](review.md)；提供的闭包图检查由主代理再次执行。审查并不替代原生测试。

本轮未启动游戏：共享入口正被其他批次轮流挂载原生测试探针，未争抢入口或存档。角色原生健康/伙伴状态、跨进程 Continue、联机与图标各原生表面仍未在本轮验收，详见 [native-boundary.md](native-boundary.md)。不复用历史报告充当本次实测。

可按 [consumer-inventory.md](consumer-inventory.md) 的范围恢复本批冻结旧入口。不要回滚整个工作区、其他批次模块或共享 main.lua；本批运行文件的哈希见 [final-scope.json](final-scope.json)。
