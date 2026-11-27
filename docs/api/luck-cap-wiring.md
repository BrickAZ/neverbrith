# 虚空针尖与鸿运齐天蛊：幸运阈值连接

虚空针尖拥有自身的幸运阈值和触发概率。鸿运齐天蛊消费该阈值，在已有幸运登记系统中建立条目。两个模块由 `main.lua` 连接，鸿运不读取另一件道具挂在 `Neverbirth` 上的字段。

## 导出与调用

`include("scripts.features.needletick")(mod, dependencies)` 在原位置登记虚空针尖回调，返回 `{ GetLuckCap = function }`。装配层只执行工厂一次，保存返回实例，并把 `needletick.GetLuckCap` 传给鸿运的 `GetNeedletickLuckCap` 参数。

```lua
local needletick = featureInstallation.Run("Needletick", function()
    return include("scripts.features.needletick")(mod, {
        ItemId = Items.Needletick, IsValidItemId = IsValidItemId,
    })
end)
-- 其他道具仍按原顺序安装。
local fortune = include("scripts.features.fortune_rivalling_heaven_gu")(mod, {
    Items = Items, GetPlayers = GetPlayers,
    IsValidItemId = IsValidItemId, Log = DebugLog,
    GetNeedletickLuckCap = needletick.GetLuckCap,
})
```

`GetLuckCap()` 为无参数的点调用，返回该次安装所属虚空针尖的当前数值阈值，默认仍是10。它不消耗 RNG、不登记回调、不读写存档、不改变世界。返回的是数值，不是可修改状态表；不同 Mod 实例的查询不会串用。

鸿运的 `GetNeedletickLuckCap` 是必需函数；缺失或类型错误时，入口在发布本件方法/状态或登记回调之前报错。该函数在每次 `RegisterVerifiedFortuneLuckCaps()` 重建审查表时调用一次，取到的值按原有固定阈值登记；不改为逐帧动态查询。调用方保证返回有效数值。

## 兼容与生命周期

既有 `mod.NeedletickLuckCap` 与 `mod.GetNeedletickChance(luck)` 保留。前者仍由虚空针尖拥有；查询和原概率公式读取同一份兼容配置，避免把两个10分别复制到两个道具中。原5%起始、10幸运达到15%上限的概率曲线不变。若旧兼容调用方修改阈值，虚空针尖查询会读取修改值；鸿运仍需按原有方式重建登记才使用新值。

查询不持有玩家或房间对象，没有新局/换房/沙漏状态，也不引入持久化。完整重新安装必须向鸿运传入该次安装返回的查询，不能为取得查询再次运行虚空针尖工厂。原回调顺序、过滤条件及原生返回值不变。

真实消费者：[main 装配](../../main.lua)、[鸿运入口](../../scripts/features/fortune_rivalling_heaven_gu.lua)、[鸿运审查表](../../scripts/features/fortune_rivalling_heaven_gu/audit.lua)。检查：[依赖与身体边界](../../tests/fortune_laxative_boundaries_test.lua)、[第九批依赖](../../tests/batch9_dependencies_test.lua)、[鸿运 custom cache](../../tests/fortune_custom_cache_behavior_test.lua)、[虚空针尖行为](../../tests/needletick_behavior_test.lua)。
