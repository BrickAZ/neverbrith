# 模块安装事务

来源：[feature_installation.lua](../../scripts/runtime/feature_installation.lua)。[main.lua](../../main.lua)在注册 Mod 后创建服务，整个正常装配位于外层 Run 内。该服务只在同步安装时拦截 AddCallback/AddPriorityCallback；不负责逐帧派发、存档或热重载。

```lua
local installation = include("scripts.runtime.feature_installation").Create(mod)
installation.Run("bootstrap", function()
    installation.PublishGlobal("Neverbirth", mod)
    -- 在这里创建模块，并按现有顺序调用它们的 Install 方法。
end)
```

| 点调用接口 | 参数与返回 | 生命周期与失败 |
| --- | --- | --- |
| `Installation.Create(mod)` | 原生 Mod；返回安装服务 | 每个 Mod 安装创建一次；不自动发布全局 |
| `service.Run(name, install)` | 诊断名称及同步无参函数；保留其全部返回位置，包括 nil | 记录当前外层 Run 注册的 callback、Mod 顶层字段变化和显式全局发布。嵌套 Run 共用外层记录；未被调用者捕获的子阶段错误传播到外层回滚 |
| `service.PublishGlobal(name, value)` | 全局键和值；无有用返回 | 必须处于 active Run，否则断言失败；记录该全局旧值后写 `_G` |

服务保存同一实例历次外层 Run 的历史，包括已经成功返回的 Run。后续外层 Run 失败时，回滚会逆序处理全部历史，移除记录的原生 callback，恢复 Mod 顶层导出及 PublishGlobal 写入；不是只撤销最近一次 Run。发现字段已被不相关替换时不覆盖。清理异常会加入原错误信息。外层 Run 一旦失败，该服务不再接受下一次 Run，应重新开始整个 bootstrap。不要在外层安装函数中吞掉嵌套 Run 的错误并继续宣告安装成功。

**边界**：这不是任意副作用事务。嵌套表的原地修改、任意 `_G` 写入、EID 内部状态、磁盘写入、已经生成的游戏实体都不因这个服务自动恢复。需由相应拥有者明确处理。异步回调里以后才执行的注册也不在已结束的同步事务中。

Run 不保证 Install 幂等，不提供重复安装去重，也不提供通用卸载接口。既有模块的交错安装位置必须保留；新相邻写法见[开发规范](../agent/development-conventions.md)。

现有 callback 的绑定已放回处理函数所在文件，紧贴函数定义；需要延后登记的绑定放在相邻的 `callbackInstallers` 安装方法中。声明这些方法不登记事件，入口仍按原顺序显式调用。每个表属于当前工厂实例，不应遍历安装，也不应重新 `include` 子模块来取得安装方法。已有 mod/TestAPI 中的处理函数仍在原阶段定义，原生登记使用原函数对象；安装方法只延后登记动作，不是运行期 callback 包装。

例如 Condom 的父模块保存 Bans 与 Replacement 两个子模块的返回表：`InstallUseCondom()` 由 Bans 绑定，`InstallPickupInit()` / `InstallPickupMorph()` 由 Replacement 分别绑定；父模块保留三个原有阶段。Good Girl 的 Combat 返回两项私有安装能力，父模块在 Combat、Rewards 都创建后按原次序调用。它们都是道具内部装配接口，无需将私有实现提升为通用库。

检查：[feature_installation_test.lua](../../tests/feature_installation_test.lua)、[完整入口故障覆盖](../../tests/thin_entry_installation_test.lua)、[第二批失败回归](../../tests/batch2_installation_failure_test.lua)。
