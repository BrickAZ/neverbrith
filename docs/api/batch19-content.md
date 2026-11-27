# 获取组道具的正式协作边界

第 19 批逐件入口、状态和共享差异见[消费者清单](../../reports/refactor-batch19/2026-11-27/consumer-inventory.md)。[共享身份/获取/快照与装配](shared-state.md) 和 [普通数据复制](plain-data.md) 分别拥有公共机制合同；此页只补道具间实际使用的接口。

所有根工厂 `(mod, context)` 均在调用时安装本件回调，正式 main/装配只调用一次并保存实例。公开 `mod.DivineLeftHand`、`mod.EchoBaby`、`mod.Blinky`、`mod.LowGrade`、`mod.InventorySelector` 是对应工厂返回对象的别名，不是另一份状态；不通过 TestAPI 连接生产功能。

| 点调用接口 | 返回/所有权及副作用 |
| --- | --- |
| `DivineLeftHand.GetTemporaryCount(player,id)` | 返回确定归属且不含歧义的临时份数。查询会同步真实历史；账本变化会按原规则保存，不能当无副作用 UI 纯函数缓存。历史读取失败记日志并返回 0。背包条目适配是正式消费者。 |
| `EchoBaby.GetRewards(player)` | 返回新 `{damage,tears}` 值表，不暴露内部奖励记录。首次访问可能沿原规则解析保存区域；实际属性结算和跟班生成仍在原回调。 |
| `EchoBaby.IsCopy(familiar)` | 查询实体 GetData 的复制标记；无实体时保持原 nil 返回。不能用于推断其当前 AI 或伤害已被引擎接受。 |
| `LowGrade.GetDurability(token)` | 返回匹配实物的剩余耐久，未就绪或未找到返回 nil；不修改/复制全部账本。 |
| `Blinky.GetEntries(player)` | 返回当前身体储物数组的内部引用，首次可能初始化区域。消费者按只读方式遍历，不缓存到恢复/替换之后，不直接增删。 |
| `Blinky.Spit(player,uid)` | 通过储物 Core 执行一次具体吐出操作，返回成功布尔值。成功才移走该实物，可能消费 RNG、生成实体、登记在途记录并保存；无目标/生成失败保留原条目。不能作为预览查询。 |

## 选择器

`InventorySelector.Open(player,request)` 返回是否打开；request 的 `execute(player,entry)` 是正式操作。`getEntries` 可覆盖默认背包来源，`valid` 负责调用者持续有效性，`onCancel(reason)` 接收取消。每次确认重新读取条目和资格；execute 必须严格返回 true 才成功关闭，不在选择器中直接扣费或决定道具效果。凸眼鱼传入储物条目与自身 Spit 操作；临时复制只向默认条目提供临时份数。

条目规范化产生新展示行，但 `payload` 保留调用者提供的引用；不要把它写入选择器存档，选择器本身没有持久区。`GetSession(player)` 返回运行期内部会话或 nil，仅用于观察，不由消费者改写；关闭/换房/换层/失效后引用失效。`Close(player,reason)` 幂等结束当前会话，并按原规则保留按键释放保护。`IsBlocking(player)` 为布尔查询，覆盖活动会话与释放保护；拳套消费该查询，结束一次会话不代表按键已经松开。

身体背包键用于会话归属，控制器同时只能由一份会话驱动；关闭先解除会话记录，再调用外部取消函数。输入读取异常和调用者操作异常沿现有受保护路径记录并清理，不改变原射击/移动政策。新局/Continue、退出、游戏结束、卸载清掉运行期会话和相应释放记录；换房/换层取消会话，释放保护按既有处理保留。

## 兼容入口与恢复边界

`pending_content_state.lua` 保留工厂转发；Blinky 的旧 Mod 字段回退和装配可接受旧 context 的合同继续保留。正式 main 已显式传入当前实例及存档 Scope。删除这些适配前必须确认旧外部调用方已退出，不能以本批内部消费者迁完为由立即删除公开路径。

临时复制、回声宝宝、零分考卷通过获取服务注册沙漏参与者；各自恢复校验、保存和缓存刷新政策不同，未统一。Blinky 储物明确不加入共享回退，只处理在途物品返回和原生房间来源协调；没有因整理引入新沙漏语义。实际检查范围见批次交付，离线 Continue 和多玩家对象不能替代跨进程或真实多人验证。
