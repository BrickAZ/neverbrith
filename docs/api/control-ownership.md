# 控制占用：按所有者管理 CanShoot

[control_ownership.lua](../../scripts/systems/control_ownership.lua) 返回 `Controls` 表。当前只处理实际存在的玩家 `CanShoot` 禁火重叠，不负责输入动作、武器归属、冻结、移动轨迹或存档。加载无副作用；每次正式安装由 main 创建一个服务，神性过载、炸弹套装和斗气拳套共享该实例。

```lua
local shootingControls = include('scripts.systems.control_ownership').Create(
    include('scripts.systems.entity_identity'),
    function(player) return player:Exists() end)
local shooting = include('scripts.systems.shooting_scope').ForOwner(shootingControls, 'my_feature')
-- 当前功能拥有 scopes；两个不同功能不能互传句柄或清理对方的表。
shooting.Block(scopes, key, player)
shooting.Restore(scopes, key, function(p) return p:Exists() end)
```

## 服务与句柄

全部为点调用。

| 导出 | 参数与返回 | 合同 |
| --- | --- | --- |
| `Controls.Create(entityKey, exists?)` | 必需运行期实体键函数；可选实体有效性函数；返回新的服务 | 正式入口使用 pointer + spawn seed，不使用逻辑玩家/存档键。没有回调、全局单例、I/O 或 RNG。省略 exists 的调用者必须保证键在活跃句柄之间不会被不同身体复用 |
| `service.Owner(name)` | 非空且在此服务内唯一的字符串；返回专属 owner | 重名或无效名称断言失败。各功能每次安装只创建一次，不能每帧创建；名称不参与玩家身份或保存 |
| `owner.Capture(player)` | 活跃玩家；返回不透明 table 句柄 | 读取 `CanShoot()`，登记此 owner 的占用，但尚不调用 setter。首个占用保存原 bool；后续占用共享此原值。调用者必须先保存返回句柄，再 Block，保证 setter 抛错时仍能清理 |
| `owner.Block(handle)` | 此 owner 的活跃句柄；返回 nil | 调用该句柄玩家的 `SetCanShoot(false)`。不覆盖第一次原值；非法/已释放句柄断言失败 |
| `owner.Release(handle, exists)` | 本 owner 发行的句柄、必需有效性函数；返回 bool | 先解除自己的占用；失效实体不调用 setter；还有任一占用时写 false，最后一个释放时恢复原 bool。第一次释放返回 true，重复释放返回 false；不能释放其他 owner 的句柄 |

`Capture` 与 `Block` 分开是明确的失败清理边界，不是异步协议；正常消费者应连续调用。各功能通过 [shooting_scope](shooting-scope.md) 适配，不直接编辑句柄。句柄本身不公开玩家、原值或内部表；服务/owner/句柄均只存在于当前安装与运行期，不能序列化。

一个 runtime key 可以对应同一原生实体的不同 Lua 包装。若新对象复用同 key，且传入 Create 的 exists 明确判定旧代表实体已经失效，则建立新代次；新身体使用自己的 CanShoot 原值。旧句柄仍可清理，但不会删除新代次占用。仍活着但返回相同 key 的不同原生实体属于提供者违反身份合同，不能靠本服务猜测其真实身份。

有效性查询或 setter 抛错仍传播，Release 不保留已经解绑的句柄。恢复期间同步申请的占用继承该实体尚未恢复的原值；每次有效性查询后重新判定当前代次和 owner，setter 后同时检查新增/释放 owner 两种变化。普通恢复最多写入两次（原写入与一次必要校正）；持续变化超过这个界限会明确报错，不静默成功或无限循环。若 setter 在写入 true 后抛错且仍有同代占用，进行一轮受保护修复，该轮同样最多两次写入；其有效性查询若已释放全部 owner，则不再禁火。修复轮的错误不覆盖原错，重入修复受 guard 限制。临时恢复/修复记录在成功或失败后均移除。普通无重入路径仍只有原来的一次 setter；原生失败或持续重入达到界限时不承诺引擎状态已经成功恢复。

## 实际消费者与时序

| 消费者 | PRE / POST 优先级 | 私有句柄位置 | 结束规则 |
| --- | --- | --- | --- |
| 斗气拳套 | -30000 / +30000 | 当前 runtime 的 shootScope | 每次 PRE 先收回旧句柄，按原 blockFire 判定申请；POST、房间取消、沙漏、退出、新局及失效实体清理自己 |
| 炸弹套装 | -20000 / +20000 | State.shootScopes 中的原玩家键 | 引线期间申请；停止、移除、死亡、沙漏、退出等原路径释放自己；普通换房/换层继续引线 |
| 神性过载 | +10000 / -10000 | State.shootRestore 中的原玩家键 | Solar 形态申请；其他形态不申请；停止、换房/换层、死亡、移除与退出释放自己 |

正常次序仍为拳套→炸弹→神性申请，再按相反顺序释放；每一步原生 setter 值和次数与旧实现一致。变化仅针对占用提前结束、异常清理与失效实体：一个外层功能先结束时不解除内层功能的禁火，最后一个才还原原始 true/false。

正式入口向三个根工厂传相同 `context.ShootingControls`。兼容 standalone 调用没有该参数时保留此前局部快照模式；此模式没有新增跨实例仲裁保证。兼容退出条件是确认所有独立工厂调用方都迁入共享服务并更新相应测试，不以删除旧 Mod 别名替代消费者核对。

## 保留独立的控制合同

- 选择器、铜钱剑和搓招输入回调按当前状态返回 false/0；它们不保存并恢复 CanShoot，因此继续保留原回调次序、让位与过滤规则。拳套开始条件仍显式查询 `IsInventoryBlocking`。
- 搓招的攻击 provenance gate 管理命令来源和实体/伤害放行，不写 CanShoot；战斗 session/目标租约拥有抓取、移动与释放，不能换成一个射击 bool 句柄。
- 拳套五逻辑帧冻结拥有其添加的 sprite flag、速度和位置，退出仍按原冻结合同执行；不是玩家输入权限快照。
- 阿瓦达的 weapon 重建及 `canShootBefore` 恢复属于原生武器归属合同，诛/柴刀/铜钱剑仍经既有攻击接管查询让位。此服务没有把武器重建变成一个常驻禁火 owner，也不承诺对任意外部 `SetCanShoot` 写入的仲裁。
- 复活动画的 ControlsEnabled/Visible 恢复与睡眠计时另有生命周期所有者；没有为了统一接口改动持续时间、暂停或身体规则。

## 检查

[控制服务反例](../../tests/control_ownership_test.lua)覆盖正常 setter/read 轨迹、任意释放次序、原 false、实体替换/同 key 回收、外部句柄拒绝、重复释放、查询/setter 失败和重入。[真实消费者取消](../../tests/control_release_order_test.lua)执行 God/Bomb 实际 state/lifecycle 与 Drive 实际 weapon 恢复。[正式接线](../../tests/control_ownership_consumers_test.lua)加载真实 main，验证三消费者共享同一实例及缺模块回滚。原三件行为套件在冻结旧版及强制共享服务的新版上对照，见[本轮记录](../../reports/framework-closure/2026-11-27/control-ownership/delivery.md)。离线测试不构成原生第三方组合或人工体验验收。
