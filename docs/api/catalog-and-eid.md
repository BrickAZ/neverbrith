# 内容登记查询与 EID

## ID 与配置

[collectibles.lua](../../scripts/catalog/collectibles.lua) 导出无参工厂；`include(... )()` 返回新的 Items 表，按既有候选名称用 Isaac.GetItemIdByName 查找，未找到为-1。这是运行时 ID，不是 XML 本地 ID，不登记新的原生道具。装配层创建后传入；消费者不自行重新解析来替代已有实例。

[item_id.lua](../../scripts/catalog/item_id.lua) 导出 `IsValidItemId(id)`：nil 为 false，number 仅判断 >0，其他非 nil 类型为 true。它保留旧夹具和兼容输入行为，**不验证正整数、原生配置存在或道具已注册**；不要把它当作新的外部输入安全校验器。

[item_config.lua](../../scripts/catalog/item_config.lua) 工厂接收 `(mod,{GetPlayers=...})`，安装以下 mod 冒号方法，不返回服务、无自动 callback：

| 方法 | 合同 |
| --- | --- |
| `GetItemConfigObject()` | Isaac.GetItemConfig 的实时对象或 nil；并非所有原生异常都被捕获 |
| `GetCollectibleConfig(itemId)` | 配置对象或 nil |
| `IsBabyTaggedCollectible(itemId)` | TAG_BABY 存在、Tags 为 number 且位存在才 true，否则 false |
| `CollectBabyTaggedItems()` | 用原生容器 Size 与逐 ID GetCollectible 得到新 ID 数组；不使用 pairs 遍历原生容器，不依赖 GetTaggedItems |
| `AnyPlayerOwnsCollectible(itemId)` | 逐当前玩家 GetCollectibleNum>0 即 true；无玩家符合 false |

```lua
local babyIds = mod:CollectBabyTaggedItems()
local owned = mod:AnyPlayerOwnsCollectible(existingId)
```

数组可由调用者拥有，配置和玩家对象仍是实时引擎引用。没有 RNG/存档写入；角色与道具获得事件政策属于消费者。真实使用：[避孕套](../../scripts/features/condom.lua)、[鸿运齐天蛊](../../scripts/features/fortune_rivalling_heaven_gu.lua)。

## 文本数据与诊断

[pickup_texts.lua](../../scripts/catalog/pickup_texts.lua) 导出 `(mod,Items)` 安装函数：调用已经安装的 RegisterPickupBannerText 登记文本，无返回服务；需要先创建 pickup_banners。具体中文/英文内容在源码维护。

[eid_descriptions.lua](../../scripts/catalog/eid_descriptions.lua) 导出 `(Items,yinExplosionApiReady)` 工厂，返回 **两项** `Descriptions, LanguageOrder`。Descriptions 按运行时 ID、语言键保存 name/eidDescription；Yin 能力参数决定对应说明文本，不做能力探测，也不发布到 EID。传入完整当前 Items，避免缺键构表失败。

[item_diagnostics.lua](../../scripts/runtime/item_diagnostics.lua) 导出 `(Items,IsValidItemId,Log)` 函数；调用即遍历并写 giveitem/spawn 命令文本。无 callback/返回值，不执行这些控制台命令。当前内部打印开关为 true，输出遍历顺序不作保证。

## EID 发布

[integrations/eid.lua](../../scripts/integrations/eid.lua) 工厂接收 `(mod,{Descriptions=...,LanguageOrder=...,IsValidItemId=...,Log=...})`。创建时定义 mod:TryRegisterEIDDescriptions 并立即登记一个 MC_POST_UPDATE；返回 `{Publish=...}`，使用点调用。

```lua
local descriptions, languages = include("scripts.catalog.eid_descriptions")(Items, yinReady)
local integration = include("scripts.integrations.eid")(mod, {
    Descriptions = descriptions, LanguageOrder = languages,
    IsValidItemId = IsValidItemId, Log = Log,
})
local publishedNow = integration.Publish()
```

`Publish()` 仅本次成功完成登记时 true；EID 缺失、同实例已登记、或同一个失败 provider 尚未替换时 false。false 不是一律“错误”。缺失 EID 保持可重试；若 addCollectible 抛错，恢复本模块涉及的 description 键、临时 _currentMod 和新建 indicator，记住失败对象/函数；直到对象或函数改变，或者新 bootstrap，才重试。

成功标记属于这个实例：成功后即使全局 EID 对象被替换，也不会自动重新发布，不能由失败重试行为推导完整热重载支持。恢复日志不等于任意 EID 插件副作用全部可撤销；该模块只管理源码记录的字段。

`mod:TryRegisterEIDDescriptions()` 是 callback 入口，无成功返回值；需要结果时用 Publish。消费者不重新 include 来取得方法，也不再自己重复 addCollectible。

检查：[localization_test.lua](../../tests/localization_test.lua)、[eid_installation_lifecycle_test.lua](../../tests/eid_installation_lifecycle_test.lua)、[batch9_dependencies_test.lua](../../tests/batch9_dependencies_test.lua)、[condom_utility_knife_behavior_test.lua](../../tests/condom_utility_knife_behavior_test.lua)。
