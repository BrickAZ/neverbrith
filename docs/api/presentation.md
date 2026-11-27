# 运行文本与拾取横幅

## Localization

来源：[localization.lua](../../scripts/runtime/localization.lua)。`include("scripts.runtime.localization")(mod)` 向 mod 安装方法和 RuntimeLocalization；不返回服务、不登记 callback。装配时先于横幅和消费文本的道具执行。

以下是 **mod 冒号调用**：

| 方法 | 参数、返回和行为 |
| --- | --- |
| `GetRuntimeLocale()` | 只把游戏语言 `zh` 映射为 `zh_cn`，其他走默认 `en_us` |
| `GetRuntimeText(key, locale?)` | 找指定或当前语言，回退默认语言，再回退 tostring(key or "")；返回文本，不绘制 |
| `FormatRuntimeText(key, values, locale?)` | 将 `{name}` 换成 values[name] 的字符串；缺失值保留占位符。返回字符串 |
| `GetRuntimeTextFont(locale)` | locale 应明确提供；返回缓存 Font 或 nil。失败用 false 缓存，同实例后续不自动重试；不是只读查询 |
| `RenderRuntimeText(key, suffix?, x, y, r?, g?, b?, a?)` | 屏幕文本绘制，颜色默认1；本地字体失败回退默认语言与 Isaac.RenderText。首返回值是绘制调用的成功布尔值；pcall 路径可能还有额外结果/错误信息，调用方不应当承诺固定单返回 |

```lua
local title = mod:GetRuntimeText("blackTaisuiTitle")
local text = mod:FormatRuntimeText("condomBanned", {items = bannedNames})
```

RuntimeLocalization 是内部可变配置，`or` 初始化会保留已存在的表；fontCache 是运行对象，不写入存档。文本键及字体路径以源码为准；字库加载成功不等于所有字形和画面已经实机验证。

## Pickup banners

来源：[pickup_banners.lua](../../scripts/runtime/pickup_banners.lua)。`include(...)(mod,{IsValidItemId=...})` 定义方法，返回三个点调用安装函数：`InstallUpdate()`、`InstallReset()`、`InstallPickup()`。它们分别登记 MC_POST_UPDATE、MC_POST_GAME_STARTED、过滤为道具底座的 MC_PRE_PICKUP_COLLISION；创建模块本身不执行这三次安装。

mod 冒号接口：

| 方法 | 合同 |
| --- | --- |
| `RegisterPickupBannerText(itemId,enName,enSubtitle,zhName,zhSubtitle)` | 合法 ID 才写入 PickupBannerTexts；原地登记，无返回值。重新初始化模块会重建整个文本表 |
| `GetPickupBannerLocale()` | 调用现有 GetRuntimeLocale，需先安装 localization |
| `ShowLocalizedPickupBanner(itemId)` | 找当前语言或英文，调用 HUD.ShowItemText；缺失文本/HUD 返回 false；原生调用通过 pcall，首返回是成功布尔值 |
| `GetPickupBannerQueuedItemId(player)` | 从 QueuedItem.Item.ID/Id 返回数字或 nil |
| `GetPickupBannerSourceKey(pickup)` | 有 InitSeed 返回 `seed:<seed>`，否则 tostring(pickup) |
| `IsPickupBannerSourceAlive(candidate)` | candidate 含 pickup、itemId；底座不存在、变成别的 subtype 或 Exists 失败时 false |
| `TrackLocalizedPickupBannerCollision(pickup,collider)` | 原生回调处理器：仅中文且已登记底座，记玩家/底座/取得前数量；返回 nil，不等于已拾取 |
| `UpdateLocalizedPickupBanners()` | 数量增加或排队道具吻合才显示；失效底座删 pending |
| `ResetLocalizedPickupBanners()` | 替换 pending 表，清除旧实时引用 |

后三类处理器由安装的 callback 驱动，其他模块通常只使用 Register 和 Show。不要手工触发碰撞处理器假装拾取。

PickupBannerState.pending 持有实时玩家和底座，不进入存档；新局事件清理。创建时可能保留旧 state，但文本表重建，所以不要用重复 include/安装去刷新文本。已有不同阶段安装位置见 [main.lua](../../main.lua)，新布局见[开发规范](../agent/development-conventions.md)。三个原生绑定现分别紧贴 `UpdateLocalizedPickupBanners`、`ResetLocalizedPickupBanners`、`TrackLocalizedPickupBannerCollision` 的定义，封装在实例私有安装方法中；返回表的 `InstallUpdate()`、`InstallReset()`、`InstallPickup()` 仍无参数、无有用返回值，由主入口在原来的三个阶段各调用一次。创建模块只定义处理器与安装方法，不提前登记这三个事件。

真实登记数据：[pickup_texts.lua](../../scripts/catalog/pickup_texts.lua)。检查：[localization_test.lua](../../tests/localization_test.lua)、[thin_entry_installation_test.lua](../../tests/thin_entry_installation_test.lua)。
