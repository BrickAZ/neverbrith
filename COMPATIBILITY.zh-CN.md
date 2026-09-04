# Neverbirth 兼容接口指南

[English](COMPATIBILITY.md)

| Neverbirth 道具 | 其他 Mod 可以添加什么 | 状态 | 入口 |
| --- | --- | --- | --- |
| 鸿运齐天蛊 | 自定义收藏品和饰品的幸运阈值 | 临时公开，尚未版本化 | `RegisterLuckCap`、`RegisterLuckCapResolver`、`RegisterTrinketLuckCap`、`RegisterTrinketLuckCapResolver` |
| 骰子套装 | 自定义骰子类主动道具 | 临时公开，尚未版本化 | `RegisterDiceItem` |

当前公开版本没有为记忆紊乱提供兼容接口。

## 其他 Mod 可以接入什么

其他 Mod 可以把自己的收藏品或饰品注册为鸿运齐天蛊的幸运阈值拥有者，也可以把自己的某个主动道具明确注册为骰子套装中的骰子。这些接入是可选的：即使其他 Mod 没有注册任何内容，Neverbirth 仍可正常运行。

## 本文术语

“幸运阈值”是某项效果达到最高触发概率时所需的幸运值。最高触发概率不一定是 100%。

“主动道具”是放在主动道具槽里、由玩家按键使用的收藏品，例如 D6。

“骰子类主动道具”是外观或效果以骰子为主题的主动道具，不是“当前处于激活状态的骰子”。

## 接口状态与稳定性

本文列出的入口为临时公开，尚未版本化。它们是已发布源码中对接其他 Mod 的入口，并不表示每个未列出的 Neverbirth 函数都稳定。任一 Mod 更新时，请检查当前源码与本指南。

## 获取 Neverbirth 与运行时 ID

### 名称与全局对象

Neverbirth 通过全局值 `Neverbirth` 提供其对接对象。兼容 Mod 应以防御性方式查询它；对象或所需函数不存在时，应跳过注册。

### 使用运行时 ID，不要使用 XML 本地 ID

本文所有 `itemId` 和 `trinketId` 都是 Isaac 通过名称查询得到的运行时 ID，而不是内容文件中的 XML 本地 ID。仅在相关 Mod 内容可用后查询 ID，并拒绝缺失或非正数的结果。

## 加载顺序

以下示例假定你的 Mod 已有自己的 `MyMod` 对象。不要为了增加 Neverbirth 兼容性再次调用 `RegisterMod`。

```lua
local neverbirth = _G and rawget(_G, "Neverbirth")
if not neverbirth or type(neverbirth.RegisterLuckCap) ~= "function" then
    return
end
```

```lua
local myItemId = Isaac.GetItemIdByName("My Mod Item")
```

请在两个 Mod 都已加载后查询。以下注册示例会立即尝试一次，并在游戏开始后再次尝试；因此，即使全局对象在启动流程较晚阶段才可用，示例仍可安全运行。

## 鸿运齐天蛊

### 这项兼容有什么用

该效果仅在玩家同时拥有鸿运齐天蛊，并持有相匹配、已注册为拥有者的收藏品或饰品时生效。它会找出可用的最高幸运阈值，并在需要时将玩家幸运提高至该值；它绝不会降低缓存链已经产生的更高幸运值。

### 函数与参数

```lua
Neverbirth:RegisterLuckCap(itemId, fixedCap)
Neverbirth:RegisterLuckCapResolver(itemId, resolverFn)
Neverbirth:RegisterTrinketLuckCap(trinketId, fixedCap)
Neverbirth:RegisterTrinketLuckCapResolver(trinketId, resolverFn)
```

幸运注册会在运行时 ID 为正数，且提供数值固定阈值或函数 resolver 时返回 `true`。负阈值可以注册，但计算时会被忽略，因此调用方不得使用负阈值。

对 resolver 的调用受到保护；报错、非数值结果和负数结果都会被忽略。多个可用条目会采用最高阈值，Neverbirth 绝不会降低已存在的更高幸运值。

重复的幸运注册会造成重复的 resolver 调用。调用方必须让注册具备幂等性。resolver 函数运行在幸运缓存路径中，必须快速、确定且没有副作用。

对于 resolver，参数依次是 `player`、已注册的运行时 ID，以及玩家当前拥有该拥有者的数量。收藏品使用对应的 collectible 函数，饰品使用对应的 trinket 函数。

### 固定阈值示例

```lua
local fortuneCompatRegistered = false

local function tryRegisterFortuneCompat()
    if fortuneCompatRegistered then
        return true
    end

    local neverbirth = _G and rawget(_G, "Neverbirth")
    if not neverbirth or type(neverbirth.RegisterLuckCap) ~= "function" then
        return false
    end

    local myLuckyItem = Isaac.GetItemIdByName("My Lucky Item")
    if type(myLuckyItem) ~= "number" or myLuckyItem <= 0 then
        return false
    end

    fortuneCompatRegistered = neverbirth:RegisterLuckCap(myLuckyItem, 10) == true
    return fortuneCompatRegistered
end

tryRegisterFortuneCompat()
MyMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, tryRegisterFortuneCompat)
```

### 动态阈值示例

```lua
local fortuneResolverCompatRegistered = false

local function tryRegisterFortuneResolverCompat()
    if fortuneResolverCompatRegistered then
        return true
    end

    local neverbirth = _G and rawget(_G, "Neverbirth")
    if not neverbirth or type(neverbirth.RegisterLuckCapResolver) ~= "function" then
        return false
    end

    local myLuckyItem = Isaac.GetItemIdByName("My Lucky Item")
    if type(myLuckyItem) ~= "number" or myLuckyItem <= 0 then
        return false
    end

    fortuneResolverCompatRegistered = neverbirth:RegisterLuckCapResolver(myLuckyItem, function(player, itemId, count)
        if count >= 2 then
            return 8
        end
        return 12
    end) == true
    return fortuneResolverCompatRegistered
end

tryRegisterFortuneResolverCompat()
MyMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, tryRegisterFortuneResolverCompat)
```

请保持此 resolver 没有副作用。尤其不要从 resolver 中再次注册；注册应放在具备幂等性的加载期或游戏开始路径中。

## 骰子套装

### 这项兼容有什么用

骰子套装会统计玩家已拾取、持有或使用的已识别骰子道具。只看见一个底座不计入统计。每个已识别道具对每名玩家只为套装贡献一次；调用方负责只注册真正以骰子为主题的主动道具。

### 函数与参数

```lua
Neverbirth:RegisterDiceItem(itemId, options)
```

`itemId` 是正数运行时收藏品 ID。`options` 必须是表或 `nil`。`options.name` 会被保存，但不会改变面向玩家的文本。只有 `protectStats = false` 会关闭该骰子的属性保护。

`RegisterDiceItem` 会对有效的正数 ID 返回 `true`，对无效 ID 返回 `false`。重复注册同一 ID 会替换其 options。调用方必须确保该 ID 属于主动道具。

Crooked Penny 和 Glitched Crown 仍被排除。没有注销 API，也不支持 `refundCharges`。

### 注册示例

```lua
local diceCompatRegistered = false

local function tryRegisterDiceCompat()
    if diceCompatRegistered then
        return true
    end

    local neverbirth = _G and rawget(_G, "Neverbirth")
    if not neverbirth or type(neverbirth.RegisterDiceItem) ~= "function" then
        return false
    end

    local myDice = Isaac.GetItemIdByName("My Custom Dice")
    if type(myDice) ~= "number" or myDice <= 0 then
        return false
    end

    diceCompatRegistered = neverbirth:RegisterDiceItem(myDice, {
        name = "My Custom Dice",
        protectStats = true,
    }) == true
    return diceCompatRegistered
end

tryRegisterDiceCompat()
MyMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, tryRegisterDiceCompat)
```

### 自动识别与 EID

按名称识别骰子只是后备方式，优先使用显式注册。EID 是可选的，不控制核心注册或骰子套装行为。

## 不公开的接口

以下内容不是公开对接接口：测试 API、carrier API、运行时状态、`RegisterPickupBannerText`、`RegisterFortuneLuckEntry`，以及任何未列出的 helper 或 callback。此列表不是版本化的公共合同；不要基于这些内容进行对接。

## 维护者附录

下列源码和行为测试可作为维护者的静态参考。它们验证已发布源码的合同，但不能证明游戏内加载顺序、第三方 Mod 交互、游戏平衡或视觉行为。

| 对接项 | 实现 | 主要测试 |
| --- | --- | --- |
| 鸿运齐天蛊 | [`main.lua`](main.lua) 中的 `RegisterLuckCap*` 和 `RegisterTrinketLuckCap*` | [`tests/condom_utility_knife_behavior_test.lua`](tests/condom_utility_knife_behavior_test.lua) |
| 骰子套装 | [`main.lua`](main.lua) 中的骰子套装函数 | [`tests/dice_set_behavior_test.lua`](tests/dice_set_behavior_test.lua) |
