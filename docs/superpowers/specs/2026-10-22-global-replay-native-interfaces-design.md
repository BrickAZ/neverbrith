# 全局回放与接管练习：八组原生接口详细设计

记录日期：2026-10-22。配套文档：[分批验证计划](../plans/2026-10-22-global-replay-native-interfaces.md)。

**文档状态**：设计提案，等待评审；只整理接口契约、恢复协议和验证门槛。本文中的 `Replay*` 名称、类型、状态码及新文件路径都是拟议设计，不是当前 REPENTOGON 已有 API。所有候选实现和实机用例均为 `NOT_STARTED`。

**本轮授权**：编写设计与验证计划。未编写 Lua/C++、测试运行器或安装脚本，未编译、替换 DLL、启动候选功能、提交或发布。

## 1. 已锁定的最终目标

| 需求 | 必须满足的行为 | 验收归属 |
| --- | --- | --- |
| R01 | 录制并播放完整一局，覆盖房间、楼层、返回旧房间及结局，不将最终目标缩减成单房间 | B10、B11 |
| R02 | 回放保存到磁盘，退出游戏、重启后仍能播放 | B09、B10 |
| R03 | 回放可以分享；接收方在被支持的游戏、原生扩展、Mod 和资源环境中验证后播放 | B09、B11 |
| R04 | 从回放中的目标战斗现场接管，按真实游戏规则练习，可重复从同一目标点重试 | B06、B11 |
| R05 | 观看、跳转、练习及其失败都不改变正式局进度、正式 Continue、成就、解锁或其他持久化数据 | B00、B07、B11 |
| R06 | 结束练习，返回发起练习时的原房间及当时的正式局状态；恢复到发起帧，不退化为重新进房或房间入口快照 | B06、B11 |
| R07 | 优先证明战斗现场完整恢复，再开放正式局回放入口；恢复不能遗漏飞行物、敌人 AI、武器状态和 Mod 私有状态 | B01—B06 |
| R08 | 回放使用实际模拟与游戏动画；相同检查点、输入和环境的重演必须能检查确定性 | B08、B10 |
| R09 | 不支持、损坏、失步或恢复失败有明确拒绝与恢复路径；不得靠近似重建继续覆盖正式局 | 所有批次 |
| R10 | 兼容现有 neverbrith 玩法与沙漏语义；回放专用快照不顺带改变道具规则 | B06、B08 |

跨不同游戏版本自动迁移、任意第三方 Mod 无条件兼容、在线多人同步不作为首个兼容版本的承诺。它们属于能力边界，不能被用来删掉 R01—R10。版本不匹配必须明确拒绝或走独立迁移验证，不能宣称“种子相同就能播”。本地多人、多实体玩家及其输入属于状态覆盖清单，应测试或明确报告暂未覆盖。

## 2. 研究依据与当前缺口

### 2.1 本机基线

| 项目 | 本次调研基线 |
| --- | --- |
| 游戏 | `E:\Isaac - Repentance\isaac-ng.exe`，x86，8,820,736 字节 |
| 游戏 SHA-256 | `530B4D2ACCEF833B8DBF6F1A9F781FE1E051C1916CA5ACDB579DF05A34640627` |
| 已安装原生扩展 SHA-256 | `A053418AD4851C91203F2E6A7F09E6D1A96FBC8A3294AE31D615FA40EA990B5F` |
| 项目版本门槛 | `main.lua` 当前接受 `1.0.12a-yin-api1-dev`；不能把回放接口悄悄并入并冒用此能力版本 |
| 本地原生研究源树 | `worktrees/repentogon-yin-native/source`，HEAD `4675b426d1ce7973595172984c366354e5bb66f9`，存在其他任务的本地修改 |
| 上游比较基线 | REPENTOGON 提交 `e2c5aecacbbb83bb5938cfa89c0a58b78e616a36`，面向较新的 Repentance+；其结构和 ABI 不能直接套入本机旧版 |

这些值是调研锚点，不是后续每批都可以跳过的环境检查。实施时要重新记录 EXE/DLL/Mod 哈希和本地差异；当前安装内容不得由本计划自动覆盖。

### 2.2 已确认事实与设计影响

| 证据 | 已确认事实 | 对设计的约束 |
| --- | --- | --- |
| E01 | 本机 `Game::SaveState` 会汇集 Room、Level、PlayerManager 等状态，也会进入扩展保存路径 | 可复用部分存档结构；Capture 不是天然只读，必须证明不触发正式写盘、不改变宿主逻辑状态 |
| E02 | `Room::save_entity` 的持久化过滤排除常规泪弹、激光、敌方弹幕等瞬态对象 | 普通 SaveState 加暴露一个 Lua 函数不能构成完整战斗快照 |
| E03 | 本机自定义道具池与沙漏回调使用固定存档/沙漏槽识别；陌生 GameState 指针可得到 `-1` 并跳过扩展状态 | 任意检查点需要独立 ID 和扩展注册协议，不能把第三个快照伪装为已有沙漏槽 |
| E04 | GameState、实体、道具池等含动态容器、指针、RNG、相互引用 | 内存整块复制不等于深拷贝，更不等于可跨重启的文件 |
| E05 | 项目现有状态服务只覆盖已注册的部分内容；其他模块仍有闭包、实体键、计时、输入与直接 SaveData | 增加回放专用参与者注册，不把当前沙漏参与者覆盖面当成全局状态覆盖面 |
| E06 | 成就、完成标记、捐款、道具池及 Mod 数据有多条内存修改、文件写入和外部提交路径 | 必须同时隔离读视图、内存副作用、直接写盘和异步外部提交 |
| E07 | 项目存在 `Input.GetActionValue`、按键直读、`Isaac.GetTime`、全局帧计数和 `math.random` 回退 | 只录 MC_INPUT_ACTION 的最终值、只恢复 Game 帧数或只保存局种子均不足 |
| E08 | 较新上游已有 GameState 读写、Mod 数据注册和部分实体扩展保存机制，但仍与固定槽及原生持久化过滤关联 | 可参考设计和部分实现，仍须逐字段、逐调用链验证本机移植及瞬态战斗完整性 |

本机二进制定位锚点：Game Save `0x6CC850`、Restore `0x6CBA60`；Room Save `0x7AE2D0`、save_entity `0x7AD7C0`、restore_entity `0x7ADD10`、实体过滤 `0x7AD670`；Manager Load `0x8B47A0`。这些地址仅对上述 EXE 有效。

原生写入器 `0x921A00` 已有签名和字段写入证据；读取候选 `0x924320` 有加载调用及头部读取证据，完整 ABI 仍为 **Unverified — discovery required**。不能在计划中把候选读取器写成可直接调用的已知函数。完整恢复字段、线程边界、所有异步写入源同样需要 B00 的发现记录闭合。

### 2.3 可复核入口

- 项目状态服务：[pending_content_state.lua](../../../pending_content_state.lua)；玩法来源：[drive_glove.lua](../../../drive_glove.lua)、[blinky.lua](../../../blinky.lua)、[bomb_suit.lua](../../../bomb_suit.lua)、[healthy_sleep.lua](../../../healthy_sleep.lua)、[main.lua](../../../main.lua)。Healthy Sleep 的计时归属在独立模块，ACE 在 `main.lua`；实施时复核加载链和状态拥有者。
- 本机原生源树中的 `repentogon/Patches/CustomItemPools.cpp`、`LuaInterfaces/CustomCallbacks.cpp`、`Patches/AchievementsStuff.cpp`、`Patches/CompletionTracker.cpp`、`Patches/PlayerFeatures.cpp`；源树有无关改动，后续只能在另建隔离源树内实施回放接口。
- 上游参考：[GameStateManagement.cpp](https://github.com/TeamREPENTOGON/REPENTOGON/blob/e2c5aecacbbb83bb5938cfa89c0a58b78e616a36/repentogon/SaveStateManagement/GameStateManagement.cpp)、[Lua save_state_manager.lua](https://github.com/TeamREPENTOGON/REPENTOGON/blob/e2c5aecacbbb83bb5938cfa89c0a58b78e616a36/repentogon/resources/scripts/repentogon_extras/save_state_manager.lua)、[EntitySaveStateManagement.cpp](https://github.com/TeamREPENTOGON/REPENTOGON/blob/e2c5aecacbbb83bb5938cfa89c0a58b78e616a36/repentogon/SaveStateManagement/EntitySaveStateManagement.cpp)。只引用这些机制作为比较依据，不把上游可编译等同于本机可用。

## 3. 运行模型与不可变条件

### 3.1 A、B、C 三种状态

| 状态 | 含义 | 允许的操作 |
| --- | --- | --- |
| A：宿主返回点 | 玩家在正式局点击观看/练习入口时，原房间、原位置、原战斗帧及正式进度上下文的完整状态 | 在接管期间冻结、保持独立所有权；不得拿来当工作快照覆盖；隔离完整通过后可写独立救援文件 |
| B：回放目标点 | 录制时的完整检查点及从检查点到目标帧的记录，经验证后形成的目标战斗现场 | 只读；每次练习从 B 的克隆开始；不得被第一次练习的奖励、耗材或实体去重表污染 |
| C：练习分支 | 从 B 接管后，由实时输入继续演算的隔离世界 | 可以按正常玩法消耗与生成内容；只写隔离覆盖层；结束时丢弃 |

目标点可以位于一段录像的中间。若文件只有较早检查点，必须先隔离重演到目标帧并验证，才能生成 B。A 不能替换成 B，也不能用“返回同一个房间编号”冒充返回 A。

### 3.2 会话顺序

`FORMAL → PREPARING → REPLAY_PAUSED/REPLAY_PLAYING → PRACTICE → RETURNING → FORMAL`。

1. 在引擎定义的完整模拟边界暂停，检查能力、内存、受保护写入队列和恢复条件；不在伤害遍历、生成遍历或回调栈中间 Capture。
2. 建立隔离上下文与宿主返回保护；此时仍不替换世界。隔离视图初始继承宿主正式进度，Capture 产生的额外写入只进入可丢弃层。
3. 捕获 A，检查采集没有改变宿主摘要，取得其深拷贝和参与者状态。宿主存在不支持状态则退出 PREPARING，正式局继续。
4. 导入并预检回放环境，把隔离读视图切换成录制时的进度基线；加载回放检查点并演算到 B。整个导入、观看和跳转阶段都受隔离保护。
5. 接管只更换输入来源；从同一 B 重试则重新克隆并恢复 B 和它的隔离覆盖层基线。分支随机流从 B 状态自然演算，不继续硬塞原录像的随机结果。
6. 结束时停止分支输入与模拟，取消或排空分支副作用，保持隔离启用；恢复 A 及宿主进度读视图，验证身份图、摘要和受保护存储。
7. A 验证通过后，才关闭隔离、重新接通正式写入并恢复原输入。若验证失败，保持冻结与隔离，进入 `QUARANTINED`，不让半恢复世界继续正式游戏。

### 3.3 必须始终成立的条件

- 任一活跃练习会话只能有一个 A；禁止嵌套进入回放。重复点击使用已有会话结果或返回 BUSY，不创建第二个宿主栈。
- Capture 不推进逻辑帧、不消耗随机数、不产生玩法回调副作用、不修改正式存档及已有沙漏槽。
- 同一捕获边界的原世界与恢复世界在完整语义摘要上相等；对后续相同输入演算，还必须逐帧相等。
- 恢复原子提交：所有对象、关系、扩展数据、输入前态、时钟与 RNG 一起可见。恢复期间不得让普通更新、伤害、奖励和存档回调看见半成品。
- 与玩法有关的排队事件必须恢复。音频设备、GPU 句柄等运行资源重新绑定；不能把仍会造成伤害或生成实体的动画事件当装饰排除。
- C 内跨房间、跨楼层、死亡、结局或进入分支菜单，都不释放 A，也不把正式会话标记为结束；离开练习统一经 RETURNING 回到 A。分支游戏流程/菜单状态必须能随事务恢复。
- 正式持久化上下文在会话前后相同。练习期间对解锁、计数、查询和收益应体现隔离世界的正常规则，不能以全部返回 false 改变演算。
- 失败日志包含首个差异、阶段和可恢复性；成功日志也必须能证明覆盖对象范围，不能只有 PASS 字样。

## 4. 战斗现场必须覆盖的状态

每行都必须有字段来源、Capture/Restore 所有者、规范化摘要字段和真实用例。B00 生成按具体类型、变种、子类型、武器和阶段展开的覆盖清单。下表不是靠几个常见对象就能声称“全覆盖”的白名单。

| 域 | 最低覆盖内容 | 容易遗漏的后果 | 首批责任 |
| --- | --- | --- | --- |
| S01 世界与关卡 | 局种子、楼层/阶段、维度、当前及历史房间状态、房间描述、门/传送/过渡状态、访问与清理标志、Manager 游戏流程/死亡/结局/菜单状态 | 返回错误房间、房间奖励重发、返程路线改变，或分支死亡销毁 A | B02，跨关卡在 B10 扩展 |
| S02 房间网格 | 网格类型/变种/状态、耐久、破坏进度、网格 RNG、门锁、地形和需要的缓存重建 | 墙石复原错误、碰撞与寻路漂移 | B02 |
| S03 玩家 | 全部玩家与关联角色、生命/资源/装备/主动槽、口袋物、临时效果、变身、运动、无敌与受伤计时 | 当前帧相似，下一次伤害或开火错误 | B02 |
| S04 玩家内部控制 | 蓄力、射击冷却、攻击/武器阶段、输入边沿前态、移动插值和控制锁 | 恢复后多开一枪、松键误触、蓄力清空 | B02、B05 |
| S05 NPC | 原生 AI State/StateFrame、冷却/延时、寻路内部状态、目标、阶段、分段 Boss、附属实体 | 血量位置相同但后续行动不同 | B03 |
| S06 状态效果与归属 | 毒/火/流血等剩余计时、伤害负载、来源实体、阵营、魅惑、冻结和持续伤害关联 | 恢复后伤害数值、击杀归属或触发次数错误 | B03 |
| S07 实体基础与关系 | 类型/变种/子类型、生成顺序、位置/速度/高度、标记、碰撞、Parent/Child/Spawner/Target、删除状态 | 指针悬空、重复实体、先后顺序变化 | B03，后续各批复用 |
| S08 泪弹、敌弹和炸弹 | 原生私有运动量、轨迹/高度、寿命、延迟、反弹/分裂、命中去重、爆炸倒计时与伤害来源 | 瞬态对象丢失或恢复后再次命中 | B04 |
| S09 激光、刀和持续武器 | 端点/角度/长度、父子引用、伤害周期、武器阶段、命中缓存、跟随关系 | 视觉对齐但伤害判定不同 | B05 |
| S10 跟班与战斗效果 | 跟班目标/冷却/队列、环绕关系、特效的伤害/生成事件、弹幕控制器和房间效果 | 缺少延迟攻击或重复召唤 | B05 |
| S11 精灵与动画事件 | 动画/叠加层、帧、播放速度、翻转、触发过的事件与待触发事件、玩法插值 | 同一动画事件第二次造成伤害 | B03、B05 |
| S12 事件队列 | 创建/删除、延迟伤害、奖励、死亡与连锁事件、缓存脏标记、回调延迟任务、次帧任务 | 恢复后漏结算或双倍结算 | B03—B06 |
| S13 原生系统扩展 | 自定义道具池权重/耗尽、Genesis 余量、沙漏内部状态、完成/成就内存读视图 | 下一次掉落不同，或试验污染原有沙漏 | B01、B07、B10 |
| S14 Lua/Mod 状态 | 全局/局/房间/玩家/实体数据、闭包状态、注册表、去重集合、任务、实体引用及生命周期代次 | 外观恢复而机制没有恢复 | B06 |
| S15 时钟与输入 | Game 帧、全局更新相位、逻辑毫秒、overlay 更新序列、按住/触发/释放前态、控制器映射 | 停留时间、睡眠治疗或边沿输入错位 | B01 最小基础，B08 完整闭合 |
| S16 随机状态 | Seeds 派生状态、道具/实体/网格 RNG、全局 MT、Lua 随机状态、扩展流与调用顺序 | 初始帧相同，几帧后分叉 | B01 最小基础，B08 完整闭合 |

**不排除未知对象**：未登记的实体/扩展字段不能默默跳过。预检时报告具体对象及未支持字段；对那个检查点拒绝恢复和接管，并把缺口加入后续开发清单。早期里程碑通过只代表其已列明范围；全局正式入口必须等待覆盖清单和最终门槛闭合。

## 5. 公共数据与事务契约

### 5.1 身份、句柄与错误

| 类型 | 含义与约束 |
| --- | --- |
| `CheckpointId` | 本进程检查点标识，绑定所有者和代次；独立于 SAVE_FILE 和两个沙漏槽；释放后再次使用返回 STALE_HANDLE |
| `SnapshotId` | 可序列化的快照逻辑身份，与进程地址无关；克隆后保留来源并取得独立可写上下文 |
| `StableEntityId` | 在记录上下文中分配的实体出现序号；与世界代次组合映射到当前 userdata；不能用 GetPtrHash/原生地址作文件身份 |
| `RestoreEpoch` | 每次换世界递增；旧实体映射及未重绑的 Lua userdata 一律失效；不得回收给另一个实体后悄悄变有效 |
| `SimulationStamp` | run/room epoch、逻辑 tick、引擎帧、全局更新序号、更新相位和逻辑时间；不同计数器分别记录 |
| `CapturePlan` | 目标范围、实体/参与者清单、边界证据、资源预算、能力与格式版本；由预检生成，不能调用者随意声称 complete |
| `RestoreTransaction` | prepare 后持有的恢复计划、资源预留、回滚所有者和阶段记录；commit/abort 幂等 |
| `OperationResult` | 成功与否、错误码、阶段、受影响对象、是否已提交、宿主能否继续及证据位置；错误不能只返回 nil |

错误码至少区分 `UNSUPPORTED_BUILD`、`UNSUPPORTED_STATE`、`UNSAFE_BOUNDARY`、`BUSY`、`STALE_HANDLE`、`CAPTURE_MUTATED_HOST`、`INVALID_PACKAGE`、`ENVIRONMENT_MISMATCH`、`RESOURCE_LIMIT`、`PARTICIPANT_FAILED`、`REFERENCE_FIXUP_FAILED`、`RESTORE_VALIDATION_FAILED`、`DESYNC`、`ISOLATION_BREACH`、`RETURN_FAILED`。名称是拟议契约；实施可调整拼写，但必须保留这些可区分语义及对应测试。

### 5.2 原子恢复次序

1. **预检**：验证版本、能力、内容身份、数据长度、对象引用和资源预算；拒绝时尚未改当前世界。
2. **保护**：冻结在边界，启用副作用隔离，持有可验证的回滚检查点；普通玩法回调暂不可进入。
3. **重建基础**：恢复关卡/房间、网格、池、玩家容器；仅执行被登记为恢复必需的构造过程，隔离构造副作用。
4. **分配对象**：按保存顺序创建全部实体及内部武器/控制器，建立 StableEntityId 映射，不提前跑 AI、命中、奖励或死亡更新。
5. **还原字段**：写入基础、类型私有、动画事件、状态效果、队列和随机状态；修复 Parent/Child/Spawner/Target 等引用，允许环与空引用但拒绝非法引用。
6. **还原扩展**：先恢复原生扩展，再恢复 Lua 纯数据；最后按映射重绑实体引用、定时任务与模块索引。普通 POST_NEW_ROOM、玩家初始化、沙漏加载等回调不得冒充回放恢复协议。
7. **提交前校验**：图完整性、所有者、队列、时钟/输入/RNG、参与者摘要全部通过，才能发布新世界代次；需要重算的缓存必须验证不会额外消耗 RNG 或触发玩法。
8. **继续或回滚**：成功后按会话模式继续；失败在隔离内回滚并验证。回滚也失败则冻结隔离并保护返回资料，禁止自动继续正式局。

各字段“保存原值”还是“可由原值无副作用重建”必须在字段清单逐项决定，不能以统一调用 EvaluateItems/重新生成房间替代审计。

### 5.3 Mod 参与者协议

回放注册表独立于沙漏注册表。每个参与者声明稳定名称、数据版本、状态域、依赖顺序、序列化能力、引用重绑器、摘要贡献者和隔离写入源。生命周期固定为 `Preflight → Capture → PrepareRestore → RestoreData → ResolveReferences → Validate → Commit/Abort`；这些是拟议协议阶段，并非新增回调枚举已确定。

- Capture 只读并返回独立数据；不得顺手调用 SaveMusicboxData 或 SaveData。
- 参与者不能把 Lua closure、函数、userdata 或线程直接写入分享文件；闭包里的玩法状态显式提升为可恢复数据，代码身份由环境清单固定。
- 缺少必需参与者、版本不符、参与者报错或存在未分类的可变全局状态，都使该快照失去完整能力，不可只记 warning 后继续。
- 原生实体 GetData 不能被认为天然覆盖 Lua 外部表；弱引用、GetPtrHash 键、InitSeed 组合键必须通过映射迁移和重建。
- 恢复框架屏蔽 SaveData 外部副作用不表示参与者可以随意改变宿主内存；仍必须比较 Capture 前后摘要。

## 6. 八组原生接口目录

下列接口是**语义级提案**。表中的输入输出类型属于第 5 节的数据合同，不规定未验证的 C++ ABI；公开 Lua 入口只暴露会话级安全操作。原生内部的分项恢复函数不允许 Mod 在正式局随意混用。

### N1. 独立检查点生命周期

| ID / 拟议操作 | 输入 → 输出 | 必须保证 |
| --- | --- | --- |
| N1.01 `ReplayCheckpoint.GetCaptureBoundary` | 请求范围 → 边界状态、CapturePlan 或拒绝原因 | 明确更新相位和队列；不在回调栈中途强行截取 |
| N1.02 `ReplayCheckpoint.Capture` | CapturePlan、会话上下文 → CheckpointId、摘要、覆盖报告 | 深拷贝；不推进帧/RNG、不写正式存储、不覆盖已有存档与沙漏槽 |
| N1.03 `ReplayCheckpoint.Clone` | CheckpointId → 独立 CheckpointId | A/B/C 所有权隔离；容器、扩展数据、覆盖层无可变共享 |
| N1.04 `ReplayCheckpoint.PrepareRestore` | CheckpointId、目标上下文 → RestoreTransaction | 全量预检和资源预留完成前不破坏当前世界 |
| N1.05 `ReplayCheckpoint.CommitRestore` | RestoreTransaction → OperationResult、RestoreEpoch | 原子发布，内部调用 N2、N6、N7 及扩展协议 |
| N1.06 `ReplayCheckpoint.AbortRestore` | RestoreTransaction → OperationResult | 撤销预留；已开始变更则回滚并验证；不可简单释放当前世界后报错 |
| N1.07 `ReplayCheckpoint.Release` | CheckpointId → OperationResult | 幂等释放，拒绝释放仍作为唯一 A 的检查点；无悬挂引用 |
| N1.08 `ReplayCheckpoint.GetLifetimeStats` | 会话 → 句柄/原生容器/实体引用数量、字节数 | 可验证重复练习后回到基线，避免隐性泄漏 |

任意检查点使用独立扩展上下文。自定义池、Genesis、玩家历史和沙漏内部状态必须显式接入；不修改当前沙漏的两槽轮转和现有物品的沙漏规则。先验证本进程完整检查点，再验证 N3 导出，不直接把原生对象布局作为分享格式。

### N2. 战斗现场完整恢复

| ID / 拟议操作 | 层与输入输出 | 必须保证 |
| --- | --- | --- |
| N2.01 `ReplayWorld.EnumerateLiveState` | 原生查询；当前世界 → 对象、武器、队列、状态字段覆盖清单 | 不以原生持久化过滤作为枚举范围；包括待生成/待删除对象 |
| N2.02 `ReplayWorld.RegisterStateCodec` | 原生扩展注册；类型/版本/字段/引用规则 → 能力条目 | 重复注册冲突拒绝；不支持字段必须显式报告 |
| N2.03 `ReplayWorld.CaptureCombatGraph` | 原生内部；CapturePlan → 可拥有的完整战斗图 | 覆盖 S01—S16；可分批实现但未覆盖前不能标 complete |
| N2.04 `ReplayWorld.RestoreCombatGraph` | 原生内部；战斗图、事务 → 重建与引用修复结果 | 保留对象顺序、原生私有字段、队列、动画事件与归属；无双重构造副作用 |
| N2.05 `ReplayWorld.ValidateCombatGraph` | 图、当前世界、覆盖清单 → 分域验证报告 | 报告缺失、额外、重复、错引用和字段差异 |
| N2.06 `ReplayWorld.ResolveEntity` | StableEntityId、RestoreEpoch → 当前实体或明确失效原因 | 旧 userdata 不跨代继续有效；禁止地址恰巧复用蒙混过关 |

优先级：玩家/网格基础 → NPC/引用/状态效果 → 泪弹/敌弹/炸弹 → 激光/刀/跟班/特效 → Lua/延迟事件混合场景。每一类同时检查当前帧和后续演算；只看截图不能验收这一组。

### N3. 检查点序列化与分享载体

| ID / 拟议操作 | 输入 → 输出 | 必须保证 |
| --- | --- | --- |
| N3.01 `ReplayArchive.ExportCheckpoint` | CheckpointId、环境清单 → 独立包与校验信息 | 不走正式 Continue 槽，不含原生指针或账号私密数据 |
| N3.02 `ReplayArchive.ValidatePackage` | 包、兼容策略、资源预算 → 导入计划或差异报告 | 先验结构/长度/校验/版本/内容身份，再分配与恢复 |
| N3.03 `ReplayArchive.ImportCheckpoint` | 已验证导入计划、隔离上下文 → CheckpointId | 原生、扩展、Mod 数据成套导入；失败不替换当前世界 |

文件包逻辑内容：格式版本、构建与能力版本、GameState/实体编码版本、Mod 加载顺序与源/资源哈希、内容 ID 映射、参与者版本、录制时进度读视图、原生检查点、实体图、Lua 数据、输入流、时钟流、RNG 检查信息、分段摘要、索引与每段校验。

同名道具本地数字 ID 不能作为跨机器内容身份。环境校验既检查 XML/资源也检查实际加载顺序与本地差异；接收方缺 Mod、只改一段 Lua、替换原生 DLL 或资源变动都应得到可读差异。首个版本采用严格匹配策略；未来迁移必须单独实现并验收。

分享包不得携带可执行代码、可被执行的 Lua 表达式、任意本机路径、Steam 身份或可覆盖正式目录的目标路径。导入器读取数据，不安装 Mod，也不执行文件里的代码。压缩/解压及引用规模受导入预算约束；预算超限返回 RESOURCE_LIMIT，不能先改变宿主再报错。

### N4. 回放与练习的数据隔离

| ID / 拟议操作 | 输入 → 输出 | 必须保证 |
| --- | --- | --- |
| N4.01 `ReplaySandbox.Begin` | 宿主上下文、录制进度基线、写入源清单 → SandboxId | 外部写入保护先于导入/播放；不能覆盖正式 Continue |
| N4.02 `ReplaySandbox.GetStatus` | SandboxId → 读视图、覆盖层、挂起任务、保护状态 | 能证明哪个世界拥有每项修改和待提交副作用 |
| N4.03 `ReplaySandbox.RouteProgressAccess` | 原生内部；读/写操作与上下文 → 基线读取或覆盖层结果 | TryUnlock、查询、事件计数、掉落资格均按隔离世界正常反馈 |
| N4.04 `ReplaySandbox.QuiesceSideEffects` | SandboxId → 清空/取消/排队隔离结果 | 外部 Steam/Cloud 提交在调用前拦截；分支任务结束后不能迟到写正式数据 |
| N4.05 `ReplaySandbox.EndAfterReturn` | 已验证的 A 恢复凭证 → OperationResult | 只有 A、正式读视图、受保护存储都通过才重新接通正式写入 |
| N4.06 `ReplaySandbox.GetProtectedStoreDigest` | 受保护源清单 → 文件/内存/外部提交摘要 | 比较受保护值；允许的日志变化另列，不能把所有文件变动当污染 |

受保护面至少包含原生 PersistentGameData 的查询和修改、Continue 及备份、REPENTOGON 成就/完成标记/捐款/道具池 JSON、Neverbirth:SaveData、其他已登记 Mod 数据、Steam 成就与 Cloud 提交，以及对应的内存表和延迟队列。仅修改“禁成就”标记不满足此合同。

隔离使用不可变基线加可丢弃覆盖层。播放采用录制时进度基线；返回采用宿主进度基线。练习可以在覆盖层里解锁、计数和消耗，这些变化影响该分支的查询结果，退出后全部丢弃。若任意未登记写入源可能绕过保护，该环境不允许进入正式局回放。第三方任意 `io/os` 或外部网络写入不能仅凭 SaveData 拦截承诺已隔离，需发现、接入或明确拒绝该环境。

崩溃恢复资料只保存独立 A/会话日志，不把 C 写成正式 Continue。下一次启动先核实正式存储与会话阶段；只有恢复资料完整且版本匹配才能在隔离中恢复并验证 A，之后才重连正式上下文。若原生进程已崩溃而返回资料不完整，保留原正式存储并报告无法完成精确帧返回，绝不把练习局提升为正式局。此为失败处理，不把正常结束返回原房间的 R06 改成尽力而为。

### N5. 统一输入录制与注入

| ID / 拟议操作 | 输入 → 输出 | 必须保证 |
| --- | --- | --- |
| N5.01 `ReplayInput.EnumerateConsumers` | 当前环境 → 原生/Lua 输入读取路径清单 | 包含 MC_INPUT_ACTION 与直接 Input 查询，覆盖键盘/手柄及被使用的鼠标路径 |
| N5.02 `ReplayInput.BeginStream` | 模式、玩家/设备映射、前态 → InputStreamId | 捕获模式与回放模式使用同一输入语义边界 |
| N5.03 `ReplayInput.Sample` | tick、查询相位、玩家、动作/原始控件 → 原始样本 | 在 Mod 转换前录制；同一相位多次读取得到一致样本，不额外消耗边沿 |
| N5.04 `ReplayInput.SetPlaybackSource` | InputStreamId、记录与光标 → OperationResult | 原生和 Lua 直读都走同一记录，再经过当前已匹配的 Mod 转换 |
| N5.05 `ReplayInput.SetBranchSource` | 已验证 B、实时设备前态 → OperationResult | 接管边界只切来源；持续按住、触发、释放行为有确定过渡 |
| N5.06 `ReplayInput.EndStream` | InputStreamId、A 的输入前态 → OperationResult | 退出不会把菜单确认键当正式局主动使用或补发攻击 |

Drive Glove 的输入重入保护和高优先级变换必须只执行一次。不能录制已经变换的结果再在播放时二次变换，也不能仅注入引擎而让 Lua 读到玩家此刻的真实键盘。菜单/播放 UI 输入与模拟输入使用不同通道；UI 暂停/拖动不进入录像动作流。

切换语义固定为完整 tick 边界：B→C 保留 B 的最后输入作为边沿前态，下一 tick 读取实时输入；C→A 先还原 A 的输入前态，下一 tick 再读取正式实时输入。被 UI 消耗的确认/退出键单独屏蔽到本次释放，不要求所有控制键全部松开；其他按键按正常前后态生成边沿。首个恢复帧尚未推进时，输入前态必须与 A/B 相等；续跑对照使用同样的 UI 消耗掩码与后续样本。

### N6. 回放时钟与受控步进

| ID / 拟议操作 | 输入 → 输出 | 必须保证 |
| --- | --- | --- |
| N6.01 `ReplayClock.GetStamp` | 当前相位 → SimulationStamp | 区分 Game 帧、全局帧、overlay 相位和真实时间 |
| N6.02 `ReplayClock.PauseAtBoundary` | 会话 → 暂停边界或拒绝 | 不截断一半更新，不让等待期间玩法计时流逝 |
| N6.03 `ReplayClock.Step` | 会话、输入样本、步数/停止条件 → 已执行 stamps 与首个失败 | 每步执行原游戏更新次序；不靠渲染帧数假定逻辑 tick |
| N6.04 `ReplayClock.BindTimelineTime` | 时间域、记录/分支时钟 → OperationResult | 玩法 elapsed 使用可恢复时钟；性能预算仍用真实单调时间 |
| N6.05 `ReplayClock.RestoreStamp` | 检查点 stamp、相位状态 → OperationResult | 与 N1 提交；恢复多套计数及去重前态，不能只写 Game::_frameCount |

Healthy Sleep 同时使用 GetTime、全局帧和 overlay/update 去重，必须按其原有逻辑恢复并推进。ACE 的真实耗时预算循环必须保留真实时间退出条件；其会影响玩法的锁定/剩余时间另行绑定逻辑时钟。禁止把所有 GetTime 无差别冻结导致预算循环失效或玩法变化。允许倍速和 seek 通过更多受控逻辑步实现，但任何未验证的更新跳过都不能用于接管目标生成。

### N7. RNG 状态与审计

| ID / 拟议操作 | 输入 → 输出 | 必须保证 |
| --- | --- | --- |
| N7.01 `ReplayRng.EnumerateStreams` | 当前世界/Mod → 流所有者、算法与未知来源清单 | 不限于 run seed；覆盖实体、网格、道具、全局 MT、Lua 与原生扩展 |
| N7.02 `ReplayRng.CaptureStreams` | 流清单 → 算法/状态/索引/流身份 | 只读捕获；包括算法隐含状态，不能只存最近种子 |
| N7.03 `ReplayRng.RestoreStreams` | 保存状态与实体映射 → OperationResult | 与世界同事务；重建与缓存不偷偷推进流 |
| N7.04 `ReplayRng.BeginAudit` | 审计级别、会话 → AuditId | 记录稳定流身份、tick/相位、抽取序号和结果摘要，避免地址作身份 |
| N7.05 `ReplayRng.GetFirstDivergence` | 原记录与当前审计 → 首个不同流/序号/调用域 | 能分清输入先变、调用次数先变和状态先变 |

本机已定位全局 Random、RNG::Next、MTRNG::Next，但这不构成所有流的覆盖证明。Lua `math.random` 隐藏状态的读取与恢复方案仍为 **Unverified — discovery required**：须验证原 Lua 运行时状态捕获，或为实际随机消费者建立语义等价、可回滚的显式流方案；不能未经对照便替换全局算法。正式观看若以随机结果审计发现未知流则停播；接管后使用 B 的完整流状态继续产生新结果，不将原录像随机结果无限注入新分支。

### N8. 能力报告与状态校验

| ID / 拟议操作 | 输入 → 输出 | 必须保证 |
| --- | --- | --- |
| N8.01 `ReplayCapabilities.GetReport` | 当前构建与环境 → 能力/编码版本、覆盖域、限制和证据版本 | 不能只检查 DLL 名字或 REPENTOGON 存在；每个能力与通过的覆盖范围关联 |
| N8.02 `ReplayState.ComputeDigest` | 世界/检查点、字段清单版本 → 总摘要与分域摘要 | 同时覆盖原生、Lua、进度读视图、队列、输入、时钟与 RNG |
| N8.03 `ReplayState.Compare` | 两份规范状态 → 首个字段/实体/引用/相位差异 | 缺失字段不能靠忽略差异让摘要相等 |
| N8.04 `ReplayState.GetEvidence` | 操作/会话 → 可归档证据包 | 包含构建、fixture、输入、覆盖表、日志、摘要、首个差异及失败处理结果 |

摘要按显式字段与稳定实体身份规范化，不哈希原生 padding、地址、设备句柄或日志时间。浮点值先按目标构建规定的位级表示比较；不可为通过而默认加误差阈值。若某字段确认为非玩法呈现状态，需在覆盖表说明排除理由和独立呈现验收，不能省略后仍把画面验收算进语义摘要。

## 7. neverbrith 接入责任

| 当前拥有者 | 回放接入要求 | 不可误用的旧行为 |
| --- | --- | --- |
| `pending_content_state.lua` | 复用已知状态域发现结果；回放注册独立快照与引用重绑；恢复不能自动写正式数据 | 当前 Restore 校验 run seed 并会保存；它不是无副作用的完整恢复函数 |
| `drive_glove.lua` 及 core/damage/weapon 等实际模块 | 斗气/力竭、蓝防/绿冲阶段、计时、控制锁、命中/奖励去重、攻击所有者和原生持续伤害归属一起捕获 | 沙漏/换房 cancelRoom 清空状态，不能代替精确恢复；指针键必须重映射 |
| `blinky.lua` / `blinky_core.lua` | 袋内容、在飞投掷、价格/选项关联和目标引用按快照恢复 | 现有袋子故意不跟沙漏回退；回放恢复它不代表修改其沙漏玩法 |
| `bomb_suit.lua` | 引信剩余量、已排队爆炸、来源和多玩家归属准确恢复 | 沙漏取消引信不等于回放应该取消引信 |
| `healthy_sleep.lua` | 睡眠阶段、elapsed、全局帧/overlay 去重、治疗结算和倍率采样恢复 | 只改 lastTime 或只恢复 GameFrame 无法保证同样治疗时刻 |
| ACE 在 `main.lua` 的状态与工作负载路径 | 玩法时钟可恢复；真实预算不冻结；记录实际会影响 gameplay 的状态与异步任务 | 不能把性能循环删掉或改变其锁定效果来换取“确定性” |
| `main.lua` 的共享状态、SaveMusicboxData 与其他模块 | 列明局/房间/玩家/永久数据及所有随机、输入、写盘来源；bootstrap 只负责组装回放服务 | 当前大文件不是已经拆好的独立模块；不能声称只接一个服务就覆盖所有道具 |

后续实施采用独立回放协调模块，不在 `main.lua` 继续堆入世界序列化与隔离实现。既有模块仅通过窄参与者接口暴露自身状态。字段所有者不明、闭包未扫描完成时，保持完整能力关闭。

## 8. 文件与实现边界提案

此节为未来实施位置，不在本轮创建。`NATIVE_ROOT` 指实施时另建的隔离 REPENTOGON 源树；不能直接在现有 Yin/持续伤害研究树中混入回放变更。

| 拟议位置 | 单一责任 |
| --- | --- |
| `NATIVE_ROOT/repentogon/Replay/ReplayCapabilities.{h,cpp}` | 构建门槛、字段/类型覆盖登记和能力报告 |
| `NATIVE_ROOT/repentogon/Replay/ReplayCheckpoint.{h,cpp}` | 句柄、深拷贝、事务、生命周期和 A 保护 |
| `NATIVE_ROOT/repentogon/Replay/ReplayWorldState.{h,cpp}` | 世界/房间/玩家基础状态与调度边界 |
| `NATIVE_ROOT/repentogon/Replay/ReplayEntityState.{h,cpp}` | 实体类型编码、稳定身份、图重建及引用修复 |
| `NATIVE_ROOT/repentogon/Replay/ReplayArchive.{h,cpp}` | 有版本的包、导入预检与原生/扩展整合 |
| `NATIVE_ROOT/repentogon/Replay/ReplaySandbox.{h,cpp}` | 原生持久化、扩展 sidecar、外部提交及异步任务隔离 |
| `NATIVE_ROOT/repentogon/Replay/ReplayInput.{h,cpp}` | 统一输入边界、录制、注入与设备前态 |
| `NATIVE_ROOT/repentogon/Replay/ReplayClock.{h,cpp}` | 相位、暂停、步进及两类时间域 |
| `NATIVE_ROOT/repentogon/Replay/ReplayRng.{h,cpp}` | 随机流状态、所有权与审计 |
| `NATIVE_ROOT/repentogon/Replay/ReplayVerification.{h,cpp}` | 规范状态、摘要、首差与证据 |
| `NATIVE_ROOT/repentogon/LuaInterfaces/LuaReplay.cpp` | 安全会话入口与参与者桥接；具体注册点由 B00 对照当前分支确认 |
| `replay.lua`、`replay_state.lua`、`replay_participants.lua` | 会话协调、Mod 参与者协议与集成注册，不接管既有道具玩法所有权 |
| `replay_archive.lua`、`replay_timeline.lua`、`replay_ui.lua` | Mod 数据编码适配、整局时间线与玩家入口；UI 最后接入 |
| `tests/native/replay/`、`tests/replay/` | 未来原生/协议/失效注入与状态 fixture；真实引擎验收另存 reports |
| `reports/replay/<日期>/<批次>/` | 每批环境、字段清单、真实输入、摘要、首差、受保护存储比较、交付与未过项 |

已有 CMake、Lua 注册、Game/Room 存取、道具池、成就、完成标记、捐款等 hook 的最小接入位置由 B00 输出精确符号清单。不能仅创建上述新文件而遗漏实际调用链。

## 9. 错误、恢复与停止条件

| 故障 | 立即动作 | 宿主/数据处理 | 后续门槛 |
| --- | --- | --- | --- |
| 构建、能力或环境不匹配 | 在 PREPARING/导入预检拒绝 | 保留正式世界和文件；退出临时隔离 | 补证据或安装经单独授权的匹配环境 |
| 边界不安全、内存不足、未知实体/参与者 | Capture/PrepareRestore 失败 | 不销毁当前世界；撤销预留 | 修复覆盖或预算后重试，不能自动删除对象 |
| Capture 改变了宿主 | 标记 CAPTURE_MUTATED_HOST，冻结测试 | 尽可能回滚并验证；禁用该能力 | 返回 B01，不允许继续正式入口 |
| 引用修复、参与者、提交校验失败 | 停止提交，隔离内回滚 | 回滚校验通过才可继续原模式 | 保存首差，修复负责批次 |
| 回滚或 A 返回校验失败 | QUARANTINED，暂停 | 保持保护、不写 C 为 Continue，保留 A/救援资料 | 返回功能关闭；人工/受控恢复独立验证 |
| 逐帧 DESYNC | 停在首个差异 tick | 禁止从该失步状态接管；保持 A 可恢复 | 修复输入/时钟/RNG/缺失字段对应源头 |
| 发现真实进度写入或外部提交 | ISOLATION_BREACH，立即停止所有回放操作 | 冻结、保留前后证据，测试资料由独立测试档修复；不盲写回用户数据 | B07 全面重验，正式入口始终关闭 |
| 文件损坏、截断、版本不符 | 导入前拒绝 | 不执行文件内容，不替换宿主 | 提供具体段/版本差异；不尝试猜字段 |
| 中途退出、崩溃、丢失返回文件 | 依据阶段恢复或保留正式存储 | 只认可验证过的 A；绝不推广练习分支 | 崩溃矩阵通过前不开放正式使用 |

测试失败必须保留“失败”结果；修复后的通过另附复测证据，不改写旧日志。若完整恢复方案被证明不可行，应输出具体缺失字段/调用链和替代研究方向，不把“只允许房间入口”“忽略弹幕”悄悄写成需求变更。

## 10. 里程碑与证据界限

| 里程碑 | 必须通过 | 可以声称什么 | 仍不能声称什么 |
| --- | --- | --- | --- |
| M0 调研基线 | B00 | 目标构建、字段/写入/随机/输入覆盖清单与试验边界已明确 | 回放已实现 |
| M1 战斗恢复 | B01—B06 | 独立测试环境中，列明范围的完整战斗点可恢复与重复演算；A/B/C 返回协议有实机证据 | 正式进度安全、可分享、整局可播 |
| M2 正式数据隔离 | B07，并复跑 M1 涉及隔离的用例 | 已登记环境中观看/练习/异常返回不改受保护进度 | 任意 Mod 可用、跨重启可播 |
| M3 确定性 | B08 | 同环境逐帧输入、时钟和随机审计闭合 | 跨版本自动兼容 |
| M4 持久化与分享 | B09 | 完整检查点/流可跨进程及支持环境分享 | 一段样本通过就代表整局通过 |
| M5 全局闭合 | B10—B11 及所有回归 | 整局、持久分享、接管隔离、精确返回 A 的目标一起通过 | 自动构建/录像截图等于所有玩法实机通过 |

所有数值化验收、用例 ID、依赖与失败回退见[分批验证计划](../plans/2026-10-22-global-replay-native-interfaces.md)。本文件没有把未验证的技术事实标为用户待决定；ABI、字段、回调和覆盖发现以 **Unverified — discovery required** 管理。只有后来确实需要改变玩法/兼容承诺的选择，才单独列为 `TBD — user decision required` 并说明影响。
