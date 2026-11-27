# 第二十批职责、复用与迁移清单

| 道具 | 唯一入口 | 状态与回调所有者 | 旧入口 | 状态 |
| --- | --- | --- | --- | --- |
| 记忆紊乱 / MemoryDisorder / 本地 ID 55 | scripts/features/memory_disorder.lua | state 拥有 version 1 存档；identity/pairs/health/inventory 各自处理切换、伙伴、生命与构筑；icons/void_route/lifecycle 拥有原生回调 | memory_disorder.lua 仅返回原工厂，供 main.lua、直接 Lua 测试和旧消费者加载 | 结构迁移及专项离线验收完成；本轮原生与人工验收未完成 |

十个私有模块及加载关系见[专题](../../../docs/agent/topics/memory-disorder.md)。没有新增公共库或改变公共库接口；子模块只服务本件道具。

| 复用候选 | 已有消费者与实际接法 | 本批结论与语义依据 |
| --- | --- | --- |
| 共享存档 | main.lua 注入 persistence.GetRoot/Save；本件及其他旧工厂共用根实例 | 继续复用；不复制 I/O 或改动 memoryDisorder version 1 区域 |
| 玩家枚举、种子 | main.lua 的 GetPlayers/GetCurrentRunSeed 来自 runtime/players、runtime/run_seed，也供其他道具使用 | 正式路径继续复用；独立工厂缺省分支保留原 `"0"`、无 ToPlayer 变换及旧异常传播，不统一到 `"unknown"` 或附加 FindByType 查询 |
| 变暗 | main.lua 注入 world_feedback.Darken | 继续复用；本件仅计算原 15/30 帧的曲线与最大暗度 |
| 安装失败清理 | 整个主入口使用 feature_installation.Run | 继续复用，验证十个子模块缺失及十一个回调登记失败；不另建事务或事件总线 |
| 主动槽 | 公共 active_slots 供多件道具枚举最多四槽 | 本件按原三个槽分别保留 0/1/2 缺省与快照，不引入 pocket2 或更改部分 enum 行为 |
| 配置查询 | catalog/item_config 与 icons 都用 Size + GetCollectible | 前者筛宝宝标签，后者筛未见被动、隐藏项、图像路径、排除本件，并缓存原生配置；不将不同筛选/缓存生命周期合并 |
| 玩家/伙伴身份 | 其他道具按 InitSeed 等键持久化；本件需要主副体类型、ControllerIndex 与指针重绑 | 保留持久键和运行时键两层；精确伙伴移除与临时持有权代理是本件切换协议，不泛化为所有多人身份 |
| 普通表复制 | echo_baby、inventory_selector、low_grade 等也有复制代码 | 本件复制普通表、nil 转空表且不保留元表；其他 clone 可保留标量或处理不同对象。没有同合同公共复制入口；保留一个私有实现，state/health/pairs 实际复用同一函数 |
| RNG | collectible_rng 提供道具 RNG；本件使用 runSeed + 玩家键 + salt 的独立种子哈希 | 保留 hash、shift 35 与不消费玩家 RNG 的合同，不因通用随机工具而改变身份/图标序列 |

回退只需恢复本次冻结的 memory_disorder.lua，并移除本批新入口/私有目录及专属加载测试；不要用 Git HEAD 回滚整个工作区。其余文件存在其他任务改动，导航回退应只撤销本批链接和段落。
