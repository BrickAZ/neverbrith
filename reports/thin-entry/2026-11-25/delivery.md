# 已重构道具的阶段性交付

日期：2026-11-25（Europe/Warsaw）。仅本地实施和检查，未提交、推送或发布。

## 当前范围与结论

按用户最后的“先只保证已经重构的道具，没重构的先不管”收口。该指令到达时，初始清单中的 27 件内联道具已经迁出；此后只修复、审查并验证已经落地的模块，没有再新增迁移。本轮为**阶段性完成**：当前离线检查、限定独立复审和已有原生场景通过，仍不等于整轮架构或全部道具实机验收完成。

完整逐项清单及唯一入口见[实施清单](../../../docs/superpowers/plans/2026-11-25-thin-entry-refactor.md)。清单状态使用“已迁移待验收”，因为全部道具的必要原生场景、人工体验等尚未闭合。

- **已经迁移**：前两批 18 件，加本轮初始清单 27 件，共 45 件。七件狗粮已有各自入口，共用一个获取记账系统；八音盒、小皮鞋等复杂道具有明确目录入口。
- **本次初始清单仍未迁移**：0 件；27 件的代码迁移落地不代表 27 件逐项完成实机验收。
- **暂不继续处理**：原有其他独立模块的进一步改造、全模组公共能力的后续归并，以及尚未完成的整轮性能与打包验收。未扩展这些模块的玩法或把它们标为本批已验收。
- **内容例外**：ds4 在本轮基线中只有 ID／文本，没有独立玩法实现，仍由内容目录持有；骰子套装归共享系统。柴刀保留原有角色禁用政策。

## 当前职责与本轮修正

main.lua 负责前置检查、Mod／服务创建、显式依赖与顺序安装；道具规则、私有状态、处理函数及登记语句位于各自模块。为保留原有穿插顺序，部分模块返回多个安装阶段，由入口在原位置调用。

| 公共职责 | 当前所有者与消费者 |
| --- | --- |
| ID、别名、文本与语言 | scripts/catalog/collectibles.lua、eid_descriptions.lua、pickup_texts.lua；runtime/localization.lua 与 pickup_banners.lua 消费 |
| 原存档读写 | scripts/runtime/persistence.lua；各道具通过原 Section 或显式 GetRoot／Save 获取当前根，保留原存档键、玩家键、版本与保存时机 |
| 安装与失败清理 | scripts/runtime/feature_installation.lua；全入口事务记录回调、Mod 导出和旧全局兼容导出，失败时反向恢复 |
| 七件狗粮共同机制 | scripts/systems/collectible_stats.lua 和 dog_food_acquisition.lua；七件定义各有文件，护齿磨牙骨持有自己的击退规则 |
| 盒子共同机制 | scripts/features/boxes/shared.lua 与 heart_bonuses.lua；两件盒子各有独立玩法入口，奖励心回调只登记一次 |
| 民俗组共享机制 | folk_world、folk_parasite_state、folk_survival_cooldown、folk_visual_effects、folk_lifecycle、folk_costumes 与 player_geometry；消费者显式取得所需服务 |
| 小皮鞋与三件流量奖励 | 小皮鞋持有选择／表现／返还，三件流量道具各有入口，热度共享原时钟与状态段 |
| EID | scripts/integrations/eid.lua；回调仍在原位置登记，描述在玩法安装提交后发布 |
| 骰子套装 | scripts/systems/dice_set.lua；保留原存档段和登记位置 |

本轮检查实际发现并修复：

1. EID 文本目录遗漏阴的诅咒原生能力参数注入，现通过完整入口分别验证能力 0／1 的中英文描述。
2. 肉块隐式使用黑太岁的保护冷却。两者现接收同一共享查询，默认仍为 60 帧，并保留旧公开字段在安装后动态覆盖的语义。
3. 黑太岁与巴比伦好女孩隐式使用 Mod 上的表现函数。现接收同一显式表现实例，原兼容别名及登记顺序保留。
4. 护齿磨牙骨目标过滤遗漏局部玩家实体常量。现使用局部常量，其他 Mod 同名全局不会干扰目标判断。
5. 疯狂的椰子拾取判定隐式依赖避孕套的两个常量。现使用自己的原生常量，独立工厂测试覆盖正常入队和重复碰撞去重。
6. EID 提前发布及 API 抛错泄漏。玩法中途安装失败现在不会发布任何描述；EID 写入失败会恢复本次条目、原归属及指示器，并清除新增空语言表。对同一故障 API 仅尝试一次，替换 API 或重新启动可再尝试；缺失 EID 仍支持晚加载。恢复合同经本机已安装 EID 的实际 Lua 写入函数验证。该故障处理修订不改变正常成功的文本内容。

七咒之戒提供正式伤害倍率查询，主入口不再通过其 TestAPI 为斗气拳套取得倍率。原 truthy 状态判定和倍数保留。

## 实际执行与结果

以下命令从模组根目录执行。Lua 完整路径为 C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe。

| 命令／证据 | 退出码 | 结果 |
| --- | ---: | --- |
| pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/thin-entry/2026-11-25/final-checks.json | 0 | 108 项通过；101 个 Lua 测试；229 个 Lua 文件语法检查；0 失败／阻塞 |
| lua reports/thin-entry/2026-11-25/compare-registration.lua | 0 | 真实入口对照基线，472 条全局登记序列的事件、优先级、过滤器、处理器及相对顺序一致 |
| lua reports/thin-entry/2026-11-25/compare-eid.lua | 0 | 138 条本地化描述的 ID、语言、名称和文本一致 |
| lua tests/thin_entry_installation_test.lua（包含于 LuaAll） | 0 | 51 个实际 feature 导入故障、3 个登记后故障，回调／Mod 导出／全局恢复与新鲜加载通过 |
| lua tests/eid_installation_lifecycle_test.lua | 修前 1，修后 0 | 延迟发布、第二条写后错误、旧条目与归属恢复、限次失败和替换 API 恢复 |
| lua tests/crazy_coconut_dependencies_test.lua | 修前 1，修后 0 | 无避孕套字段时的合法底座碰撞、原候选数据和去重 |
| lua tests/dog_food_series_behavior_test.lua | 修前 1，修后 0 | 原狗粮行为与同名全局污染反例 |
| lua tests/folk_modules_shared_dependencies_test.lua | 0 | 默认／动态冷却、独立死亡保护、共享表现重绑及寿命刷新 |
| lua tests/folk_modules_good_girl_exports_test.lua | 0 | 20 个旧兼容导出及后续安装失败恢复 |
| pwsh -NoProfile -File reports/thin-entry/2026-11-25/run-native.ps1 -Attempt current-modules-native-02 -TimeLimitSeconds 50 | 0 | 最终版本真实游戏加载，7 场景 42 项通过，游戏正常退出 |
| node reports/thin-entry/2026-11-25/compare-native.mjs | 0 | 与第二批真实基线的 5 组属性观测逐字段相同，入口逐字节恢复 |
| 内容哈希复核（content-parity.json） | 0 | 704 个 content／resources／generated 文件未改变 |
| git diff --check | 0 | 无差异格式错误；Git 的 LF／CRLF 提示保留 |

LuaAll 保留 6 条基线已有通用资源解析警告，涉及三份 items XML 中的 deathanm2 与原版 Breakfast 贴图。严格验证器本次为 0 警告；没有修改资源来消除通用验证器的路径规则差异。完整逐命令记录见 [final-checks.json](final-checks.json)。

原生运行启动前快照 227 份相关配置／存档；结束后恢复 6 个变化文件，并归档 3 个本次进程新建文件，0 恢复错误、0 未解决新文件。main.lua 与运行前逐字节相同，游戏进程无遗留。详情见 [最终原生结果](current-modules-native-02/result.json) 和 [原生基线对照](native-final-comparison.json)。日志在正常退出时完整落盘，因此运行器状态为 COMPLETED_LOG_FLUSHED_ON_EXIT。

原生 7 场景覆盖第二批八件道具的既有回归：春药、美工刀、虚空针尖、绝育证明、剪碎的塔罗、血颅蛊，以及脐带／空摇篮的伤害结算组合。它证明最终完整入口能在本机引擎运行，不证明本轮 27 件的全部真实机制均已逐件实测。

## 审查与验收边界

- [主体审查](current-review.md)：3 项 Important 全部关闭；无 Critical。独立对照旧 Mod 顶层公开字段，缺失 0 项、旧标量／类型差异 0。
- [民俗组审查](task-folk-review.md)：2 项 Important 全部关闭。独立工厂与兼容导出回归通过。
- 旧存档格式和继续／新局／换房／失去道具／清理合同由现有专项 Lua 测试覆盖；本轮没有全面完成跨进程继续、多玩家原生、全部组合与人工视听体验验收。
- 原生塔罗的既有自动幸运缓存缺口保留：从底座取得后 Luck 仍为 0，显式刷新缓存后为 3。原始观测与基线一致，不能把显式刷新通过写成旧问题已修复。
- 本轮未完成性能前后实测及实际发布包的隔离验证；不宣称性能改善或包级通过。用户收窄范围后不继续这些整轮项目。
- 公共能力已明确本次相关所有者与消费者；对原有其他独立模块的同义实现未完成全模组逐项审计，不宣称公共复用目标已全部通过。

基线为本轮开始时的实际未提交工作区，963 个文件保存在 baseline/ 并带 baseline-manifest.json。历史迁移脚本只记录实施过程，不是最终源码生成器，不应在现状重跑；它们不包含之后的全部修复。若回退，应依据清单逐文件处理，不覆盖后来产生的无关工作或游玩存档。
