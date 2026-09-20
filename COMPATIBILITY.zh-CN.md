# Neverbirth 兼容 API

[English](COMPATIBILITY.md)

| 对接项 | 接入效果 |
| --- | --- |
| 鸿运齐天蛊 | 登记你的道具达到最高触发概率所需的幸运值，供鸿运为持有者补足幸运。 |
| 骰子套装 | 让你的自定义骰子主动道具计入骰子套装。 |
| 记忆紊乱 | 让你的自定义角色进入随机变身候选。 |

两个 Mod 加载后，通过全局对象 `Neverbirth` 接入；所需函数或表不存在时跳过。道具、饰品和角色 ID 均为**运行时 ID**。每个条目只登记一次。这些接口暂未版本化；EID 可选。

## 鸿运齐天蛊

仅在玩家同时持有鸿运和已登记道具或饰品时生效。多个有效阈值取最高值，不降低已有的更高幸运。阈值表示效果达到最高触发概率所需的幸运值，最高概率不一定是 100%。

### RegisterLuckCap

```lua
Neverbirth:RegisterLuckCap(itemId, fixedCap) -- boolean
```

登记收藏品的固定幸运阈值。`itemId`：正整数收藏品 ID；`fixedCap`：非负数。登记成功返回 `true`；ID 无效或缺少阈值时返回 `false`。

### RegisterTrinketLuckCap

```lua
Neverbirth:RegisterTrinketLuckCap(trinketId, fixedCap) -- boolean
```

饰品版固定阈值登记。`trinketId`：正整数饰品 ID；`fixedCap` 和返回值同 `RegisterLuckCap`。

### RegisterLuckCapResolver

```lua
Neverbirth:RegisterLuckCapResolver(itemId, resolverFn) -- boolean
```

登记收藏品的动态幸运阈值。`resolverFn(player, itemId, count)` 返回非负数，`count` 为持有副本数。ID 无效或 resolver 不是函数时返回 `false`，否则返回 `true`。resolver 报错、结果无效或为负数时，该结果被忽略。

### RegisterTrinketLuckCapResolver

```lua
Neverbirth:RegisterTrinketLuckCapResolver(trinketId, resolverFn) -- boolean
```

饰品版动态阈值登记。回调参数为 `(player, trinketId, multiplier)`，`multiplier` 是包含金饰品、吞下饰品效果的实际倍率。登记规则和返回值同 `RegisterLuckCapResolver`。

**每个幸运条目只登记一次：**重复调用会追加记录。resolver 应快速执行，且没有副作用。

### InvalidateFortuneLuck

```lua
Neverbirth:InvalidateFortuneLuck(player) -- no return value
```

在 Neverbirth 下一次更新时刷新指定玩家的动态阈值。`player`：有效的 `EntityPlayer` 或 `nil`；省略时刷新当前所有玩家。登记接口调用和已登记道具的持有数量变化会自动触发刷新；生命值、自有状态等其他输入变化后，需要主动调用此接口。只刷新普通 `CACHE_LUCK` 不会刷新阈值。不要在 resolver 内调用。

## 骰子套装

### RegisterDiceItem

```lua
Neverbirth:RegisterDiceItem(itemId, options) -- boolean
```

登记自定义骰子类主动道具。已拾取、持有或使用的骰子对每名玩家计数一次，仅看见底座不计数。`itemId`：正整数收藏品 ID，由调用方保证它是主动道具。ID 有效时返回 `true`，否则返回 `false`。

`options` 为表或 `nil`：

| 字段 | 含义 |
| --- | --- |
| `protectStats` | 默认 `true`；只有设为 `false` 才让这个骰子退出骰子套装的属性保护。 |
| `name` | 可选的内部名称，不改变游戏显示名称。 |

重复登记同一 ID 会替换 options。Crooked Penny 和 Glitched Crown 仍被排除。没有注销接口，也不支持 `refundCharges`。

## 记忆紊乱

### MemoryDisorderCharacterProfiles

```lua
table.insert(Neverbirth.MemoryDisorderCharacterProfiles, profile)
```

角色配置数组，初始为空。追加配置后，该角色可参与记忆紊乱后续的随机身份抽取，不会立即让玩家变身。未登记的 Mod 角色不会自动加入。

| 配置字段 | 类型 | 含义 |
| --- | --- | --- |
| `id` | `string` | 必填，稳定且唯一的标识，例如 `my_mod:my_character`。用于查找存档中的身份；不要与原版配置 ID 重名，也不要在不同会话间更换。 |
| `playerType` | `integer` | 必填，通过 `Isaac.GetPlayerTypeByName` 查询的运行时角色类型。查询失败时不要追加配置。 |
| `isCompatible` | `function` 或 `nil` | 可选，`(player, context) -> boolean`，判断当前持有者是否可抽到该角色。仅返回 `true` 时允许，报错时排除；省略则不做此项判断。`context` 为内部上下文，不要依赖其字段。 |

自定义解锁条件应在 `isCompatible` 中检查；Mod 角色配置的 `achievement` 字段不会自动参与解锁判断。只追加一次，保留原数组，并在每次 Mod 加载时、恢复存档前重新登记。此表不会验证角色是否存在，也不会自动去重。

此入口提供候选角色登记。自定义血量系统、关联角色实体和角色专属状态仍需单独验证兼容性。其他配置字段及 `Neverbirth.MemoryDisorder` 下的辅助函数属于内部实现。

<details>
<summary>完整示例：登记一个无需解锁的自定义角色</summary>

假定你的 Mod 已有 `MyMod` 对象。替换 `My Character` 和 `my_mod:my_character`；需要解锁的角色，应添加 `isCompatible` 并调用自己的解锁判断。

```lua
local function registerMemoryDisorderCompat()
    local neverbirth = _G and rawget(_G, "Neverbirth")
    local profiles = neverbirth and neverbirth.MemoryDisorderCharacterProfiles
    if type(profiles) ~= "table" then return end

    local profileId = "my_mod:my_character"
    for _, profile in ipairs(profiles) do
        if profile.id == profileId then return end
    end

    local playerType = Isaac.GetPlayerTypeByName("My Character", false)
    if type(playerType) ~= "number" or playerType < 0 then return end

    table.insert(profiles, {
        id = profileId,
        playerType = playerType,
    })
end

registerMemoryDisorderCompat()
MyMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, registerMemoryDisorderCompat)
```

立即尝试用于尽早登记；若 Neverbirth 加载较晚，则在游戏开始时重试。通过 ID 检查避免重复追加。

</details>

源码：[幸运与骰子接口](main.lua)、[角色配置](memory_disorder.lua)。行为检查：[幸运](tests/fortune_custom_cache_behavior_test.lua)、[骰子](tests/dice_set_behavior_test.lua)、[角色](tests/memory_disorder_behavior_test.lua)。这些检查不能代替游戏内兼容验证。
