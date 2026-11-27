# 陈列室与选择房间共同能力

真实消费者是[未生证明](../../scripts/features/certificate_of_neverbirth.lua)和[再契象](../../scripts/features/house_vs_elephant.lua)。两件各自创建 Room 实例、持有自己的 Config、运行状态与 lifetime；私有 ledger、gallery、flow、pickups、runtime 只接收本实例依赖。共享模块不会登记 callback，不创建或保存会话，不抽 RNG、不请求道具池。完整回调仍由各道具入口按原顺序安装；不得为获取方法重复执行道具工厂。

## 房间、位置与分页

[archive_room.lua](../../scripts/systems/archive_room.lua) 返回 `Archive` 表，所有方法点调用。`Archive.Create(getPlayers, vectorErrorPrefix)` 返回与当前道具依赖绑定的 Room 表；`getPlayers()` 每次返回当前玩家数组，`vectorErrorPrefix` 是本件 Vector 构造失败时的诊断前缀。实例只捕获这两个依赖，不缓存玩家、Room、Level 或 Entity。共享模块有些方法也直接导出供边界检查使用。

| Archive 接口 | 参数、返回与副作用 |
| --- | --- |
| `Call(object, method, ...)` | method 为成员名；存在 function 才以 object 为首参数 `pcall`，返回第一个结果与成功布尔值。成功的 nil/false 均保留；缺方法/调用抛错返回 nil,false。成员读取本身不受保护，后续多返回值被丢弃 |
| `VectorXY(value)` | 读取 X/Y，缺少时读 x/y，再 tonumber，缺失或不可转换值返回 0。返回两个数；不复制或改变传入对象 |
| `CurrentGame()` | 只接受 type(Game)==function，保护调用并将失败/false 结果归为 nil。与 `world_queries.TryGame` 接受可调用表及 false 结果的合同不同，不能互换 |
| `CurrentDimension(level, descriptor)` | 缺任一参数返回 0；从 SafeGridIndex/GridIndex/current index 找候选，依次检查维度 0、1、2 的 descriptor 指针哈希；首个相同者返回该维度，失败返回 0。只查询，不缓存、不改地图 |
| `PageEdges(count, pageIndex)` | count 为调用者已算出的正整数页数；pageIndex 经 tonumber/floor，默认 1，再夹到 1..count。返回新的 `{previous=前页或nil,next=后页或nil}`；不变更会话 |
| `SafeBounds(room, edgeMargin, controlReserve)` | 后两项为世界坐标距离，调用者传数值；保护取得房间左上/右下，扣除边距并在底部保留机关行。成功返回新的 left/right/top/bottom/galleryBottom 表；缺边界返回 nil,"unavailable"，区域不足返回 nil,"too_small"。不输出诊断，由道具决定 |

Room 实例中的 `call`、`vectorXY`、`currentGame`、`currentDimension`、`safeBounds`、`pageEdges` 分别是以上函数的同一引用；额外实例方法如下：

| Room 接口 | 参数、返回与责任 |
| --- | --- |
| `makeVector(x,y)` | 通过受保护的原生 Vector 构造，成功返回真正的引擎值；失败或 nil 结果抛带本件前缀的错误。不用 Lua 表替代原生参数 |
| `playerKey(player)` | 延续两件原有 `tostring(player and player.InitSeed or "")` 身份。只用于已有合同，不宣称支持所有角色身份共享 |
| `findPlayer(key)` | key 为既有存档字符串/数值或 nil；扫描当前 getPlayers，按上述字符串键返回第一个玩家引用或 nil。不保存引用 |
| `capturePlayerPositions()` | 返回新的 plain-table 数组，每项 `{key,x,y}`；不保留 Vector/Player，允许按旧字段存档 |
| `restorePlayerPositions(session)` | 遍历 session.originPlayerPositions（无 session/字段则空），按 live 玩家键重找实体，赋予原生 Vector；x/y 不可转换时用 0。不改 session，不保存；无法找到的玩家跳过，位置赋值异常按原合同传播 |
| `gridPositions(room,bounds,count,accepts?)` | bounds 为 SafeBounds 结果，count 为调用者已限制的 0..6 整数；按原 3 列×2 行顺序生成原生 Vector。若有 accepts，则每个槽位调用 `accepts(room,position,18)`，只保留真值，结果紧凑排列。返回新数组；不自动判断网格碰撞，也不修改世界 |
| `controlPosition(bounds,role)` | role 为 previous/return/next；在底部机关行用中心及 48..112 间距生成原生 Vector。其他 role 沿用中心位置；不替调用者做合法性查询 |

实际接入示例（两件入口均创建一次）：

```lua
local Room = include("scripts.systems.archive_room").Create(
    GetPlayers, "[neverbirth][Certificate]")
local gallery = include("scripts.features.certificate_of_neverbirth.gallery")(
    Neverbirth, { Room = Room, State = state, Config = Config,
        GetPlayers = GetPlayers, Log = DebugLog, Controls = Controls, ledger = ledger })
```

`gallery` 片段依赖都来自该入口已经创建的本件实例；实际参数以入口为准。不得为了这个例子另建第二份 ledger/state。边界失败诊断、Certificate 的 `IsPositionInRoom` 检查、House 不额外过滤位置的政策保留在各自 gallery；PageEdges 共用，但两件的页内容、已领取过滤和页数来源不同。

## 机关交互

[archive_controls.lua](../../scripts/systems/archive_controls.lua) 返回无状态 `Controls` 表，全部点调用；两个 gallery 为真实消费者。

| 接口 | 合同 |
| --- | --- |
| `PlayAnimation(effect,requested,onMissing?)` | requested 为动画名或 nil；没有名称/精灵/Play 时返回 false。若有 HasAnimation，受保护查询失败或不严格为 true 时调用可选 onMissing(requested)，然后返回 false。只有真正调用 Play(name,true) 时第二返回值 attempted 才为 true；第一值为 pcall 是否成功，Play 返回 false 仍算调用成功。GetSprite/成员读取按原合同直接执行，onMissing 抛错也传播 |
| `MakeHarmless(effect)` | 四项独立 pcall：Timeout=-1、CollisionDamage=0、实际枚举存在时设置实体/网格无碰撞。不登记实体，不返回成功承诺，单项失败不阻止后续赋值 |
| `AnyPlayerWithin(control,radius,getPlayers,vectorXY)` | control 缺失返回 false；每次调用扫描当前玩家，距离平方 ≤ radius² 返回 true。radius 为世界坐标距离，两件传 24；vectorXY 为上述数值查询。只判断距离，不验证控件归属/有效性，调用者先执行本件 findControl/findPortal |
| `UpdateTouchLatches(session,roles,entered)` | session 必须为本件会话，roles 为有序数组；每个 role 调用 entered(session,role)。仅将已离开的 role 从 `session.controlTouchLatch` 清除，不把正在触碰自动标为已触发；返回新的 touching 表。真正触发时的置位、回调更新次数、冷却、页面切换和优先顺序仍归 flow/runtime |

Certificate 在调用 PlayAnimation 前写 requested marker；仅 attempted 为 true 时更新 played marker。House 不创建这些诊断字段。两件仍使用各自已有实体字段名、Variant 查询规则、实体缓存与异常处理；公共模块不合并它们的生成/删除政策。

## 生命周期和存档边界

- 两件继续使用原 persistence.Section 和字段布局；ledger 每次访问 live Store，不缓存被 Replace 的旧表。Save 调用点留在原业务操作位置。共同模块不写存档，也不把运行时引用放入存档。
- Certificate 保存会话栈、嵌套 token、原房间/维度/位置及页信息；House 保存遇见历史与单个选择会话，保持全队三份预留与队列确认，Continue 中止选择并请求返回原房间。公共模块不决定这些规则。
- 接管接口由私有 flow 持有，两个入口返回本实例的 CarrierAPI，main 保存并通过明确的 provider 连接。事件时调用 provider 取得对方，不从 Neverbirth 查找对方。旧 `CertificateOfNeverbirthCarrierAPI` / `HouseVsElephantCarrierAPI` 仍是同一接口对象的兼容别名；现有 TestAPI 名字与回调函数引用保留。
- 一份 lifetime 表由本件入口创建并注入。退局先按旧顺序保存，再停止运行并清理临时表；卸载只处理自己的 Mod，清理幂等，已 disposed 实例不能通过 GameStarted 复活。Certificate 的旧运行视图保留给现有测试；不新增对外私有状态挂载。
- 新局、Continue、换房、沙漏、退出及卸载由原生回调所有者负责。共享模块没有独立沙漏快照或恢复保证；本批不扩展原有存档/回退语义。返回值中的玩家/实体是实时引用，调用者不得序列化或跨生命周期长期保存。

## 检查入口

- [共同能力边界](../../tests/archive_room_shared_test.lua)：成功 nil/false、缺方法/抛错、维度、当前玩家重绑、布局、动画失败、距离和触碰锁。
- [两件联合生命周期](../../tests/batch10_pair_lifecycle_test.lua)：嵌套/接管/恢复、失败返回、Continue 与同种子新局、三人同时预留、布局差异、Store 替换及卸载。
- [实际加载与故障回滚](../../tests/batch10_loading_test.lua)：真实入口、导入次数、callback 所有者/身份、12 个注册失败阶段。原有[未生证明](../../tests/certificate_of_neverbirth_behavior_test.lua)与[再契象](../../tests/house_vs_elephant_behavior_test.lua)行为断言保留，仅源代码检查沿实际 literal include 树读取。
- [显式依赖与实例隔离](../../tests/archive_dependency_wiring_test.lua)：实际入口持有本次实例、安装期不解析未就绪对方、缺少 provider 在注册前失败、provider 显式返回 nil、公共别名替换不改变内部配对、嵌套接管返回和两实例卸载隔离。
- 本批冻结旧/新源码、保存轨迹、登记顺序、原生场景及限制见[交付记录](../../reports/refactor-batch10/2026-11-26/delivery.md)。统一命令见[检查与证据](../agent/testing.md)。上述模拟检查不等同于原生玩家碰撞、跨进程 Continue 或人工画面验收。

## 两件道具的显式装配接口

`certificate_of_neverbirth` 和 `house_vs_elephant` 均导出 `(mod, deps) -> CarrierAPI` 工厂。创建会注册本件原生回调，因此 main 在既有安装事务中各调用一次，顺序仍为未生证明、再契象；不能为取得接口再创建第二份道具。ledger/gallery/flow 等是私有实现，不作为外部调用入口。

除原有 Store、Items、GetPlayers、GetCurrentRunSeed、Log 之外，未生证明必须接收 `GetHouseCarrier`，再契象必须接收 `GetCertificateCarrier`，两者都是无参数函数。缺失或非函数在本件发布状态、登记回调前失败，不回退读取公共 Mod 字段。构造期间不调用 provider；第一次使用发生在后续原生事件，届时 main 已完成两件装配。provider 只返回本次安装持有的接口，不创建模块、请求随机数、写存档或执行世界操作。

实际 main 的连接方式：

```lua
local certificateCarrier, houseCarrier
certificateCarrier = include("scripts.features.certificate_of_neverbirth")(mod, {
    Store = persistence.Section("certificateOfNeverbirth"), Items = Items,
    GetPlayers = GetPlayers, GetCurrentRunSeed = GetCurrentRunSeed, Log = DebugLog,
    GetHouseCarrier = function() return houseCarrier end,
})
houseCarrier = include("scripts.features.house_vs_elephant")(mod, {
    Store = persistence.Section("houseVsElephant"), Items = Items,
    GetPlayers = GetPlayers, GetCurrentRunSeed = GetCurrentRunSeed, Log = DebugLog,
    GetCertificateCarrier = function() return certificateCarrier end,
})
```

没有对方的独立测试/宿主必须显式传 `function() return nil end`。这保留无对方时的原规则：未生证明不被外部占用阻挡；再契象可在普通房间独立使用，但在无支持所有者的特殊房间拒绝接管且不消耗道具。provider/方法异常沿原调用路径传播，不将依赖失败解释为成功。

| 返回接口（全部点调用） | 参数、结果和实际消费者 |
| --- | --- |
| House `IsActive()` | 无参数；仍在运行且当前 session 为 table 时为 true，包含原进入/返回阶段。未生证明的 useItem、newRoom、update 用它维持互斥；查询可能触发既有账本懒初始化，不推进 RNG 或新增保存点。 |
| Certificate `SuspendCurrent()` | 无参数；当前栈顶为 active/capacity_failure 时移除本件底座/机关并返回原 token，否则 nil。再契象接管使用；不弹出会话栈、不更改 token 规则。 |
| Certificate `RestoreCurrent(token)` | token 必须匹配当前栈顶；不运行或不匹配返回 false，否则返回原 spawnGallery 结果。再契象返回及接管失败恢复使用；会执行既有底座/机关重建及其原保存行为。 |
| Certificate `IsCurrent(token?)` | 不运行时 false；运行中存在栈顶且 token 为 nil 或匹配时为 true。保留现有外部查询接口，本次没有新增生产消费者。 |

返回值是本件 flow 拥有的同一个接口表，不是状态副本。旧公共字段指向这个对象，既有方法签名、直接调用和对象上的方法替换仍可见；将整个 `Neverbirth.*CarrierAPI` 字段替换为另一个表不再重定向内部依赖。接口仅供当前安装使用，不序列化、不跨 Mod 实例缓存；正式装配不提供单件运行中替换或混合新旧实例的保证。

新局/Continue、退出暂停与卸载失效继续由各本件 lifetime 和原生处理器负责。新的 bootstrap 建立新的两局部引用，不复用前次 provider；安装失败仍由现有事务撤回回调和公共导出。本次连接不新增状态字段、生命周期回调、计时器、总分发器或公共服务。
