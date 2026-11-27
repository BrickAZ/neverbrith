# 射击权限作用域

[scripts/systems/shooting_scope.lua](../../scripts/systems/shooting_scope.lua) 返回函数表。加载不注册回调、不访问游戏。正式神性过载、炸弹套装和斗气拳套通过 `ForOwner(service, name)` 绑定同一安装的[控制占用服务](control-ownership.md)，每件仍拥有自己的句柄表。未传服务的旧独立工厂保留下面的历史局部快照接口。

`ForOwner(service, name)` 返回具有相同 Block/Restore 调用形状的专属适配。Block 在调用原生 setter 前先把 Capture 句柄放入调用者表；Restore 先从表移除句柄再释放它。某件提前释放时，仍有其他 owner 则保持 false，最后一个 owner 恢复最初 bool。`service` 省略时直接返回历史 Shooting 表；正常生产接线始终显式传入服务。

## 调用合同

- `Shooting.Block(scopes, key, player)`：点调用。`scopes` 为调用者拥有的可写表，`key` 为该调用者原有玩家键，`player` 为提供 `CanShoot()` / `SetCanShoot(boolean)` 的玩家。若该键不存在，先存 `{player=player, value=player:CanShoot()}`，随后调用 `SetCanShoot(false)`；重复调用仍会禁止射击，但不覆盖第一次记录的值。返回 nil。
- `Shooting.Restore(scopes, key, exists)`：点调用。先取出该键并置 nil，再以 `exists(player)` 核验实体。记录存在且实体有效时调用 `SetCanShoot(value)`，准确恢复先前的 true 或 false。无记录或实体无效时不调用原生 setter；返回 nil。`exists` 由消费者传入，保留它原有的严格/宽松实体检查合同。

两函数均直接传播查询/setter/有效性检查的异常，不增加 pcall。Restore 在任何可能重入的引擎调用前解除记录；setter 出错后不会遗留该快照。库不推进 RNG、不请求道具池、不保存数据、不返回内部表或引擎对象；会修改传入表和玩家射击权限。

`scopes` 中含玩家实体引用，只用于运行期，不能序列化。库不会判断道具是否持有、活动阶段、暂停、换房、死亡或退出，也不自动注册/清理。消费者负责在 POST 玩家更新、停止状态及清理路径恢复剩余记录。

## 实际消费者与嵌套顺序

神性过载的 [state](../../scripts/features/god_complex/state.lua) 持有 `shootRestore`，其 [lifecycle](../../scripts/features/god_complex/lifecycle.lua) 仅在 Solar 形态 PRE 玩家更新 +10000 阶段 Block，POST -10000 阶段 Restore。

炸弹套装的 [state](../../scripts/features/bomb_suit/state.lua) 持有 `shootScopes`，其 [lifecycle](../../scripts/features/bomb_suit/lifecycle.lua) 在引线活动时 PRE -20000 阶段 Block，POST +20000 阶段 Restore。斗气拳套为 PRE -30000 / POST +30000 的外层。正式共享模式保留这些正常嵌套次序，也能保护提前结束时仍活跃的其他 owner；旧独立局部快照模式只保证原嵌套次序。两种模式均不得用作重排既有回调优先级的理由。

```lua
local Shooting = include("scripts.systems.shooting_scope")
-- scopes 由当前道具实例持有，key 沿用该道具自己的身份合同。
Shooting.Block(scopes, key, player)
-- 对应 POST / 中断清理：先内后外，沿既有回调优先级。
Shooting.Restore(scopes, key, exists)
```

检查入口：[shooting_scope_test.lua](../../tests/shooting_scope_test.lua) 检查嵌套、原值 false、重复 PRE、无记录、失效实体、异常时先解除记录；两件既有行为测试执行真实消费者回调。完整入口安装及回滚见 [batch16_loading_test.lua](../../tests/batch16_loading_test.lua)。这些为模拟契约验证；原生时序和其他 Mod 同时禁火仍需实际游戏验证。
