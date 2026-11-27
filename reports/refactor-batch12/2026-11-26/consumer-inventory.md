# 千变万化职责与共同能力

所有路径相对模组根目录；模块均为一次安装创建的私有工厂，不通过重新执行工厂取得方法。

| 所有者 | 职责与状态 |
| --- | --- |
| scripts/features/everchanging.lua | 校验旧依赖，创建七个实例、共享本次安装的 lifetime；组装原 EverchangingTestAPI，安装原八个回调 |
| everchanging/registry.lua | 原五个 StyleSpecs、顺序、外观/角色资源校验，StyleRegistry 数组与 byId 指向同一外观表 |
| everchanging/state.lua | 每次读取当前 Store；runSeed 字符串比较、InitSeed 玩家键、knownCopies/rollCount/styleId 归一化；玩家 GetData 中原运行时键，弱玩家登记 |
| everchanging/selection.lua | 正常雅各/以扫资格、候选顺序、不连续重复、原生 RNG 异常边界；新增份数抽选、成功次数和保存时机 |
| everchanging/resources.lua | 路径到 costume ID、正/负缓存、缺失资源诊断、成对角色资源解析；卸载只清本实例缓存 |
| everchanging/player_anm2.lua | Stranger 排除与玩家主 ANM2 兼容性；原文件、主动画和叠加动画保存/恢复，路径归一化、第三方文件所有权保护 |
| everchanging/presentation.lua | 服装应用/移除、部分成功后的清理、双人双侧回滚、主 ANM2 漂移修复；资源策略和成功判断仍属本件 |
| everchanging/runtime.lua | 单人/双人同步、调试命令、运行时重建、换房/换层标脏、新局/Continue/退出/卸载；八个处理器及其安装器紧邻 |

依赖为有向无环：registry → state/selection/player_anm2；state → selection/presentation/runtime；resources 和 player_anm2 → presentation；selection/presentation → runtime；入口保留并传递每个实例。表中箭头表示被依赖者指向消费者。所有实例只在入口创建一次；原外部 API 名称和函数引用保持。

共同能力：`scripts/systems/null_costumes.lua.GetCachedId(cache,path,path,true)`，不修改公共库实现。原生查询返回后本件再次向当前 cache 发布结果，保留查询期间重入卸载替换表的写入语义。公共库 Add/Remove 无成功返回值，本件需要失败回滚，不能直接替代。详细用法与其他真实消费者见[公共 API](../../../docs/api/shared-mechanics.md)。

未合并的相似能力：run_section 的种子严格比较/替换与本件字符串比较和 Save 时机不同；通用 collectible RNG 不能表达本件候选过滤、模运算和三类诊断；通用服装增删不能承担双人原子回滚。它们不是本批新增框架的理由。

保持项：道具 local ID 38、品质 0、商店权重 0.5、不入宝箱池；五个资源定义及元数据、原除外角色；每新增一份抽一次，归零清选择但保留历史次数，Continue 不重抽；实体运行状态不序列化。所有 content/resources/generated 按初始基线哈希保持。主入口没有本批永久改动；同期陈列室显式依赖装配已在正式原生旧/新两侧对齐。

检查：旧行为/完整 ANM2 合同、生命周期检查；batch12_boundaries 九组；batch12_loading 七模块单次创建与八阶段失败回滚；50 个函数文本对照（限定所有权适配和一个共享缓存适配）；13 组保存/RNG/外观调用轨迹；原生范围及最终计数见[交付](delivery.md)。
