# 公共库与 Callback 开发规范

本页是本项目的稳定规则。既有[目标架构](../architecture/2026-11-24-neverbirth-target-architecture.md)继续规定逐道具所有权、状态和迁移边界。

## 公共库必须交付详细用法

新增公共模块或修改公共导出时，同一批交付实现、实际消费者接入、[公共 API 索引](../api/index.md)及对应说明、相称检查。只有库代码没有用法说明，或只有无人调用的工具文件，都不是完成的公共库交付。

使用或建立公共能力前先查索引和相关模块说明，再核对源码。公共接口说明按模块归档，至少覆盖适用的项目：

- 模块用途、导出形状、加载或创建方式、点调用/冒号调用；实例由谁保存和传入。
- 每个对外函数的参数、类型、单位、默认值、返回值和失败/缺失含义。
- 调用前置条件、初始化和事件时机、注册副作用、是否推进 RNG/请求道具池/改动世界或存档。
- 返回表和引擎对象是内部引用还是副本，可否修改；失效和重绑规则。
- 新局、继续、换房、沙漏和卸载责任；明确由库负责的行为与调用者政策。
- 至少一个真实消费者和相关测试入口。简单接口简写适用项，不添加无意义空表。

公开签名和语义变更时，同批更新消费者、说明和必要测试。源码公开导出旁补充有用的参数/返回注释；详细跨模块用法只维护在 API 文档中。私有函数不因本规则变成公共 API；原 TestAPI 不作为生产接口推广。

库可含查询或显式操作，必须说明副作用。不要把“无模块状态”误当成“无游戏副作用”。`include` 不缓存；有状态或会登记的工厂由装配层创建并保存正确实例，不为取得一个方法重新初始化。

## Callback 紧贴处理函数

callback 处理函数定义结束后，下一段代码就是对应原生绑定，或只封装该绑定的显式安装函数；中间只允许空行、该绑定的说明注释或必要的事件存在性守卫，不插入其他无关函数。函数与绑定必须在同一文件。一个函数绑定多个事件时，绑定连续列出。

普通模块在工厂执行时直接登记：

```lua
return function(mod, deps)
    local function OnUpdate(_)
        return deps.Update()
    end
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, OnUpdate)
end
```

需要保留交错安装顺序时，将实际处理器定义和原生注册一起放进显式安装函数：

```lua
return function(mod, deps)
    local api = {}
    function api.InstallPickupInit()
        local function OnPickupInit(_, pickup)
            return deps.TryReplacePickup(pickup)
        end
        mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT,
            OnPickupInit, PickupVariant.PICKUP_COLLECTIBLE)
    end
    return api
end
```

示例说明组织方式，`deps` 操作需由实际模块提供。安装函数不是幂等承诺；装配层在原位置及[安装事务](../api/installation.md)中调用一次。跨文件共享业务函数时，就地 callback 适配器负责原生参数和返回值；不要让处理器到另一文件寻找自己的绑定。

迁移已有代码时，若处理函数需要提前定义、导出或被其他代码直接引用，保留其定义位置和函数身份，在定义后紧邻声明安装函数。例如：

```lua
return function(mod, deps)
    local callbackInstallers = {}
    function mod:OnPickupInit(pickup)
        return deps.TryReplacePickup(pickup)
    end
    function callbackInstallers.InstallPickupInit()
        return mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT,
            mod.OnPickupInit, PickupVariant.PICKUP_COLLECTIBLE)
    end
    return callbackInstallers
end
```

`callbackInstallers` 是当前模块实例的私有安装方法表，不是事件派发器。父模块只保存同一子模块实例并在原注册位置点调用安装方法；保留外层守卫、循环、阶段和调用次数，不用 `pairs` 或函数定义顺序重新安排安装。原注册表达式仍在安装时读取 handler、priority 和 filter；原位置才可见的局部变量、循环变量应显式传入，不能因移动语句意外变成全局或捕获另一变量。处理器本体不额外套转发函数，原公开接口和返回约定保持不变。

已有 `add(name, fn, ...)` 这类原生注册适配器的实现会接收函数参数，它本身没有一个固定的业务 handler；相邻要求应用在它的实际调用点，具名 handler 后紧贴该适配器调用或显式安装函数，内联 handler 与绑定保留在同一调用中。

已有明确合同的“绑定集合”可以在函数后保存注册描述，并由装配层按明确阶段逐条原生安装；必须把延后注册的含义写进对应库说明。不要为了排版建立总事件派发器、改变 priority/filter/返回值或原顺序。回调名字符串只属于明确的自定义适配器，不是原生 API 的通用用法。

本规则适用于新写及本次实际修改的处理函数/绑定组。未触及的旧回调属于待迁移项；仅补文档不代表已经迁移，也不为文档任务批量重排运行代码。迁移时同时核对调用该方法的其他消费者和旧公开接口。

结构审查检查相邻位置；行为检查验证实际注册、事件过滤、返回与重要顺序。完整 Lua 语法与运行行为不能用一条正则代替。
