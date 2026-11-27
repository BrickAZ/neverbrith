# 普通数据树复制

[plain_data.lua](../../scripts/runtime/plain_data.lua) 返回无状态表 `{CopyTree}`。加载不注册回调、不获取游戏对象、不读写存档，也不推进 RNG。实际消费者是临时复制、回声宝宝、零分考卷和获取服务；每次 `include` 只取得纯函数，不创建共享可变状态。

```lua
local copy = include("scripts.runtime.plain_data").CopyTree
local snapshot = copy({players = {p1 = {records = {{id = 7, temporary = true}}}}})
```

`CopyTree(value)` 为点调用。对于 table，使用 `pairs` 递归复制值到新的普通 table；键保持原引用，不复制元表。对于非 table 叶值，原样返回。nil、false、0、空字符串不被替换；同一个子表若出现两次会产生两个独立副本，不保留共享引用关系。遍历错误直接传播，库不捕获或转换异常。

调用者必须提供符合原有合同的有限、无循环数据树。此接口不是序列化验证器：function/userdata 等非 table 叶值仍按旧实现原样返回，不因此成为可保存数据。禁止用它把 Entity、Player、Sprite 或带环运行图变成存档。使用 `__pairs` 的表仍按其迭代器行为处理；这仅保留旧 Lua 行为，不表示推荐保存带元表对象。

返回 table 及其 table 值归调用者所有，可独立修改。库不保留输入或结果，不需要退出/换房/新局/沙漏清理；快照何时捕获、保存、恢复以及实体重建仍归对应所有者。

| 实际消费者 | 使用位置和所有权 |
| --- | --- |
| [神的左手，恶魔之右手](../../divine_left_hand.lua) | 原生历史的普通记录副本、临时实物账本和沙漏数据；规则及精确移除留在道具 |
| [回声宝宝](../../echo_baby.lua) | 奖励/复制跟班记录和沙漏数据；跟班原生 AI、奖励上限及缓存时机仍由道具处理 |
| [零分考卷](../../low_grade.lua) | 每份饰品耐久状态快照；失效、熔炼、落地与持有者关系仍由饰品处理 |
| [获取服务](../../scripts/systems/acquisition_state.lua) | 获取查询副本、历史候选和快照；将同一函数交给每实例 snapshot_participants |

[Blinky Core.Clone](../../blinky_core.lua) 保留独立：它断言所有非 table 叶值必须为 nil/number/string/boolean，具有更严格的失败合同。不同的树校验不能被此函数弱化。

检查：[plain_data_test.lua](../../tests/plain_data_test.lua) 覆盖副本隔离、重复引用、键/叶值、元表、pairs 和错误传播；[batch19_loading_test.lua](../../tests/batch19_loading_test.lua) 检查四个实际消费者和安装失败回滚。批次旧新行为及实际复制调用计数见[第 19 批交付](../../reports/refactor-batch19/2026-11-27/delivery.md)。
