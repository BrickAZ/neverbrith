# 第十八批所有权与公共能力核对

基线是开工时工作区，不是 Git HEAD。两件在此前已有独立根模块；本批把其内部职责分开，没有迁出其他道具或调整 main.lua 装配位置。

| 道具 | 兼容入口 → 正式入口 | 私有模块 | 状态与边界 |
| --- | --- | --- | --- |
| 胆小鬼之夜 | night_of_the_cowards.lua → scripts/features/night_of_the_cowards.lua | queries：世界/实体资格；grants：一次 c20 赠予；aura：变形/光环；fear：禁射/恐惧图示；runtime：启停与生命周期 | 每次安装创建 runtime；auras、blockedPlayers、fearSprites、localC20Grants 保留原表身份与替换点。nightOfTheCowards.runSeed/c20Granted 保留原数值种子比较、InitSeed 字符串玩家键、保存调用点。换房清光环/禁射，继续与退出按原回调处理。 |
| 神风特攻队 | kamikaze_squad.lua → scripts/features/kamikaze_squad.lua | queries：查询/资格/身份/诊断；targets：房间敌人索引；units：持有者、单位、生成/追踪/爆炸/清理；runtime：回调协调 | 每次安装创建 holders、hostiles、hostileSet、roomSeeded；持有者键仍为 GetPtrHash:InitSeed。新房/层/局/继续/退出静默清理，死亡/丢失/离开玩家列表只清相应持有者。没有新增序列化或沙漏合同。 |

两根工厂仍返回原接口；NightOfTheCowardsTestAPI 保留原函数、Callbacks 和 Runtime。神风特攻队原 GetState 会更新 player 引用，GetLiveCount 会 prune 单位，继续保留这些既有副作用，不把旧查询声明为纯函数。生产模块没有消费 TestAPI。每个私有工厂只构造一个实例，返回本批所需的局部函数和显式 Installers；装配层按原语句顺序安装，原生 handler 与绑定仍同文件紧邻。

## 为什么不合并这些相似辅助函数

| 候选 | 已有能力 | 本批结论 |
| --- | --- | --- |
| 玩家枚举 | scripts/runtime/players.lua | main.lua 已把同一个 GetPlayers 注入两件。胆小鬼包装会 pcall 并要求 table；神风优先直接调用 context 并传播错误，缺省才自行枚举。保留各自兼容工厂合同。 |
| 数量/持有判定 | scripts/systems/collectible_stats.lua | Count 缺 GetCollectibleNum 时返回 0；胆小鬼会回退 HasCollectible。Has 优先 HasCollectible，与两件当前优先数量不同。神风还保留无 pcall、ID=0 和未取整边界。不能等价替换。 |
| 实体存在/死亡/友方/敌人 | 两件原 helpers；combat_source.TryPlayer | 胆小鬼用 type/function + pcall + 精确 true；神风直接原生调用并使用 truthiness。胆小鬼光环允许 boss/不可受伤 NPC，变形再排除；神风只追踪可受伤且非自有的敌人。公共 TryPlayer 没有胆小鬼的 Type==PLAYER 回退。保留私有策略。 |
| 玩家头部世界坐标 | scripts/systems/player_geometry.lua | 公共几何消费 PositionOffset/GetFlyingOffset 并有无玩家回退；胆小鬼只计算 Position.Y-max(18,max(0,Size)+4)。渲染偏移属于现有表现，不在结构迁移中改动。 |
| 运行存档区 | persistence / run_section | 装配仍共享 persistence.GetRoot/Save。run_section 严格比较 runSeed；胆小鬼允许旧数值字符串，getter 异常还回退 localC20Grants。保留本件解析，不改存档。 |
| 生成与变形 | 原生 Isaac.Spawn / NPC:Morph | 光环与自爆 NPC 的实体种类、归属标记、异常策略、初始化顺序和失败结算不同，不建立只包一层原生调用的公共库。 |

本批没有新增或修改公共库，因此公共 API 索引无新增条目。其他根模块和其他批次不在本批迁移范围；整轮薄入口/公共能力重构完成度不能由这两件的结果推导。

## 保留的细节

- 胆小鬼先写 transformed 标记，再检查变形资格；不符合资格者以后仍不重试，只有 Morph 抛错清标记。基线与候选共同验证这一行为，没有把它顺带改成新玩法。
- c20 赠予不会在道具丢失时撤销；继续依旧记录防重发。本批没有新增按玩家索引存档或跨进程身份保证。
- 光环删除只有在 ownerData 仍指向该光环时才清反向引用，防止覆盖后来替换的光环。
- 神风爆炸先验证原生 Vector/Color/玩家来源，失败保留单位并标记不重试；通过后先标记、摘除引用、Remove，再调用一次爆炸。既有传参 40 和半径倍数 2 保持，未据此宣称等同原生 Mulliboom 自带死亡爆炸。
- holders 仍用 pairs 迭代；跨 Lua 进程遍历顺序不保证一致。对照探针显式选择同一玩家的单位，不能以“生成数组第一只”假定同一玩家。
