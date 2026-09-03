# Neverbirth 第三方兼容接口

[英文版本](COMPATIBILITY.md)

本文面向希望让自己的 Mod 内容接入 Neverbirth 的作者，也面向以后维护这些接口的人。

当前文档只承诺三个兼容表面：

1. 鸿运齐天蛊（Fortune Rivalling Heaven Gu）的幸运阈值注册；
2. 记忆紊乱（Memory Disorder）的外部角色档案白名单；
3. 骰子套装（Dice Set）的自定义骰子主动道具注册。

> 允许其他 Mod 为 Neverbirth 编写兼容；只有本文明确列出的接口属于受支持的公共兼容表面。直接调用未列出的 `Neverbirth.*` 方法，或操作 `TestAPI`、`CarrierAPI`、运行时状态表及其他内部字段，不属于受支持的用法。

## 当前状态

| 兼容表面 | 状态 | 公共入口 |
| --- | --- | --- |
| 鸿运齐天蛊 | 支持，但尚未版本化 | `RegisterLuckCap`、`RegisterLuckCapResolver`、`RegisterTrinketLuckCap`、`RegisterTrinketLuckCapResolver` |
| 记忆紊乱 | 支持，实验性原始档案表 | `Neverbirth.MemoryDisorderCharacterProfiles` |
| 骰子套装 | 支持，但尚未版本化 | `RegisterDiceItem` |

当前还没有 `Neverbirth.Compat` 命名空间、`API_VERSION` 或正式的 `OnReady` 回调。兼容 Mod 必须按能力检测接口，不能只根据 Neverbirth 的版本号作假设。

## 名称、全局对象与 ID

本项目保留了几个历史拼写。兼容代码必须使用实际名称，不能自行修正：

- Mod 文件夹：`neverbrith`；
- `RegisterMod` 名称：`neverbirth`；
- 对外可见全局对象：`_G.Neverbirth`。

获取 Neverbirth 时应检查目标能力是否存在：

```lua
local neverbirth = _G and rawget(_G, "Neverbirth")
if not neverbirth or type(neverbirth.RegisterLuckCap) ~= "function" then
    -- Neverbirth 不存在，或当前版本没有这个能力。
    return
end
```

### 不要使用 XML 本地 ID

`content/items*.xml` 中的 `id="24"`、`id="55"` 等数字是 Neverbirth 自己的稳定本地编号，用于本项目资源和生成流程。它们不是游戏分配的全局运行时收藏品 ID。

第三方 Mod 应通过自己拥有的注册名称取得自己内容的运行时 ID，例如：

```lua
local myItemId = Isaac.GetItemIdByName("My Mod Item")
```

不要把 Neverbirth XML 的本地编号传给以下任何注册函数。Neverbirth 当前也没有公开自己的运行时 `Items` 表。

## 加载顺序

Neverbirth 在加载 `main.lua` 时创建 `_G.Neverbirth`，但三个兼容能力是在该文件继续执行或加载模块后才建立的。因此，只检查 `_G.Neverbirth ~= nil` 不够，还必须检查具体函数或表。

推荐把每项注册写成幂等的 `tryRegister`：

1. Mod 加载时立即尝试一次；
2. 如果目标能力尚未出现，在自己的 `MC_POST_GAME_STARTED` 中再尝试一次；
3. 成功后由自己的布尔标记阻止重复注册；
4. Neverbirth 不存在时安静跳过，不能让自己的核心功能报错；
5. 不要用永久的逐帧轮询等待 Neverbirth。

本文各节的示例都遵守这个边界。

## 鸿运齐天蛊：幸运阈值注册

### 兼容目的

当玩家持有鸿运齐天蛊以及另一个具有幸运概率上限的收藏品或饰品时，鸿运齐天蛊需要知道该内容在多少幸运值时达到满概率。

第三方内容可以登记固定阈值，也可以用 resolver 根据玩家、道具份数或饰品倍率动态计算阈值。只有实际持有鸿运齐天蛊的玩家会获得幸运补足；注册本身不会改变未持有者。

### 公共签名

```lua
Neverbirth:RegisterLuckCap(itemId, fixedCap) -- 返回 boolean
Neverbirth:RegisterLuckCapResolver(itemId, resolverFn) -- 返回 boolean

Neverbirth:RegisterTrinketLuckCap(trinketId, fixedCap) -- 返回 boolean
Neverbirth:RegisterTrinketLuckCapResolver(trinketId, resolverFn) -- 返回 boolean
```

参数：

| 参数 | 含义 |
| --- | --- |
| `itemId` | 收藏品的正数运行时 ID |
| `trinketId` | 饰品的正数运行时 ID |
| `fixedCap` | 建议使用非负数，表示该内容达到满概率需要的幸运值 |
| `resolverFn` | 动态阈值函数，签名为 `resolverFn(player, id, count)` |

resolver 参数：

| 参数 | 收藏品注册 | 饰品注册 |
| --- | --- | --- |
| `player` | 当前结算幸运的玩家 | 当前结算幸运的玩家 |
| `id` | 登记的收藏品 ID | 登记的饰品 ID |
| `count` | `GetCollectibleNum` 得到的份数 | `GetTrinketMultiplier` 得到的倍率，覆盖普通、吞下和金饰品 |

返回与结算规则：

- 正数 ID 配合可转换为数字的固定阈值，或配合函数类型的 resolver，注册返回 `true`；其他输入返回 `false`；
- 负数固定阈值目前也会被登记并返回 `true`，但在实际结算时会被忽略，因此兼容代码不得使用负数阈值；
- resolver 由 Neverbirth 通过保护调用执行；抛错、非数字或负数结果不会参与本次阈值计算；
- 多个有效条目同时生效时取最高阈值；
- Neverbirth 只会提高不足的幸运值，不会降低玩家原本更高的幸运值；
- 同一 ID 允许登记多个条目，当前没有注销、替换或自动去重接口；
- 重复登记虽然通常不会叠加最终幸运值，但会留下重复 resolver 调用，因此兼容 Mod 必须只注册一次。

resolver 会在幸运缓存计算路径中执行。它应保持快速、确定、无副作用；不要在里面生成实体、保存数据、使用非确定随机数或注册回调。

### 固定阈值示例

```lua
local MyMod = RegisterMod("My Mod", 1)
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

MyMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function()
    tryRegisterFortuneCompat()
end)
```

### 动态阈值示例

```lua
-- 放在 tryRegisterFortuneCompat 取得 neverbirth 和 myLuckyItem 之后。
fortuneCompatRegistered = neverbirth:RegisterLuckCapResolver(myLuckyItem, function(player, itemId, count)
    if count >= 2 then
        return 8
    end

    return 12
end) == true
```

示例只演示接口。`8`、`12` 和双份条件必须来自兼容 Mod 自己已经验证的机制，不能凭感觉填写。

## 记忆紊乱：外部角色档案

### 兼容目的

记忆紊乱会在每次实际入房时从可用角色档案中选择一个身份。Neverbirth 自带原版角色档案；第三方角色只有被明确加入白名单后，才会进入候选池。

当前唯一受支持的外部表是：

```lua
Neverbirth.MemoryDisorderCharacterProfiles
```

不要把 `Neverbirth.MemoryDisorder` 中的 `Runtime`、状态方法或测试辅助方法当成公共接口。

### 档案结构

```lua
{
    id = "my_mod:my_character",
    playerType = myPlayerType,

    isCompatible = function(player, context)
        return true
    end,

    healthMode = "ordinary",
    keeperHeartCap = nil,

    collectibles = {},
    actives = {},
    pocketActives = {},
    pocketCards = {},
    randomPill = false,

    onApply = function(player, state, context) end,
    onRemove = function(player, state, context) end,
}
```

字段：

| 字段 | 必需 | 当前合同 |
| --- | --- | --- |
| `id` | 是 | 跨版本稳定、全局唯一的字符串；建议使用 `mod_id:character_id`。该值会进入 Neverbirth 的本局保存状态 |
| `playerType` | 是 | 角色的正数运行时 PlayerType，例如由 `Isaac.GetPlayerTypeByName` 取得 |
| `isCompatible` | 强烈建议 | `function(player, context) -> boolean`；只有明确返回 `true` 才加入本次候选。省略时当前实现会把档案视为可用 |
| `healthMode` | 否 | `ordinary`、`soul_only`、`keeper` 或 `lost`；省略时按 `ordinary` 处理 |
| `keeperHeartCap` | Keeper 模式时建议 | Keeper 可承载的心上限，使用 Isaac 的半心单位 |
| `collectibles` | 否 | 临时收藏品运行时 ID 数组 |
| `actives` | 否 | 临时主动道具数组；每项为 `{ id, slot, charge }` |
| `pocketActives` | 否 | 临时口袋主动数组；每项为 `{ id, slot, charge }` |
| `pocketCards` | 否 | `PocketItemSlot -> Card ID` 映射 |
| `randomPill` | 否 | 为 `true` 时尝试在主口袋槽放入一颗随机药丸 |
| `onApply` | 否 | 身份和声明组件应用后调用 |
| `onRemove` | 否 | 离开该身份或失去记忆紊乱时调用 |

`state` 和 `context` 当前会传入兼容函数，但它们仍是 Neverbirth 内部对象；第三方代码不能依赖其字段名、持久化结构或方法在未来保持不变。需要长期保存的第三方状态应由第三方 Mod 自己拥有。

### 生命周期顺序

切换离开一个外部身份时，当前顺序是：

1. 记录该身份期间的生命变化；
2. 调用旧档案的 `onRemove`；
3. 只撤销 Neverbirth 为该身份记录的临时组件；
4. 切换 PlayerType；
5. 应用新档案的生命模式和临时组件；
6. 调用新档案的 `onApply`。

外部 Mod 不应在 `onRemove` 中清空玩家的全部同 ID 道具，也不应删除没有明确归属给自己或本档案的实体。

角色是否解锁、依赖是否存在，以及该 PlayerType 当前能否安全转换，都由外部档案的 `isCompatible` 负责判断。Neverbirth 不会自动读取外部角色的成就或解锁字段。

### 完整注册示例

```lua
local MyMod = RegisterMod("My Character Mod", 1)
local PROFILE_ID = "my_character_mod:my_character"
local memoryCompatRegistered = false

local function containsProfile(profiles, id)
    for _, profile in ipairs(profiles) do
        if type(profile) == "table" and profile.id == id then
            return true
        end
    end

    return false
end

local function tryRegisterMemoryDisorderCompat()
    if memoryCompatRegistered then
        return true
    end

    local neverbirth = _G and rawget(_G, "Neverbirth")
    local profiles = neverbirth and neverbirth.MemoryDisorderCharacterProfiles
    if type(profiles) ~= "table" then
        return false
    end

    if containsProfile(profiles, PROFILE_ID) then
        memoryCompatRegistered = true
        return true
    end

    local myPlayerType = Isaac.GetPlayerTypeByName("My Character", false)
    if type(myPlayerType) ~= "number" or myPlayerType <= 0 then
        return false
    end

    local startingItem = Isaac.GetItemIdByName("My Character Starting Item")
    if type(startingItem) ~= "number" or startingItem <= 0 then
        return false
    end

    profiles[#profiles + 1] = {
        id = PROFILE_ID,
        playerType = myPlayerType,
        healthMode = "ordinary",

        isCompatible = function(player, context)
            -- 如角色需要解锁，请在这里调用自己 Mod 的解锁判断。
            return true
        end,

        collectibles = {
            startingItem,
        },

        onApply = function(player, state, context)
            -- 只建立本 Mod 自己拥有的临时状态。
        end,

        onRemove = function(player, state, context)
            -- 只撤销本 Mod 自己建立的状态。
        end,
    }

    memoryCompatRegistered = true
    return true
end

tryRegisterMemoryDisorderCompat()

MyMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function()
    tryRegisterMemoryDisorderCompat()
end)
```

不要把 `-1` 或 `0` 放入组件数组。示例会在角色或起始道具无法解析时保留原状并返回 `false`。

### 当前限制

- 没有 `RegisterMemoryDisorderProfile` 函数；外部代码目前必须向白名单数组追加档案；
- 没有内建重复 `id` 检查，重复项会污染候选池，因此示例主动查重；
- 没有注销档案接口；
- 非标准生命系统、双体角色、引擎派生副体和特殊资源必须单独实机验证；
- `onApply`、`onRemove` 和 `isCompatible` 的错误会被保护调用拦截，但档案作者仍应自行记录足够的诊断信息；
- 多人模式按玩家分别选择和结算，兼容代码不能用玩家 0 或一个全局“当前角色”代替实际玩家。

## 骰子套装：自定义骰子注册

### 兼容目的

骰子套装按玩家记录见过或使用过的不同骰子主动道具。达到三个不同骰子后，该玩家解锁套装；已解锁玩家使用骰子时，套装会保护伤害、射速和射程相关结果不低于它记录的基线。

第三方骰子即使名称不包含 Neverbirth 的骰子关键词，也可以通过公共注册进入该系统。

### 公共签名

```lua
Neverbirth:RegisterDiceItem(itemId, options) -- 返回 boolean
```

参数：

| 参数 | 必需 | 当前合同 |
| --- | --- | --- |
| `itemId` | 是 | 第三方骰子主动道具的正数运行时收藏品 ID |
| `options.name` | 否 | 可读名称，会存入注册表；当前不要依赖它改变玩家可见文本 |
| `options.protectStats` | 否 | 默认 `true`；设为 `false` 时仍算骰子，但该道具使用后不启动骰子套装的属性保护 |

返回规则：

- 正数 ID 注册返回 `true`；无效 ID 返回 `false`；
- 同一 ID 再次注册会覆盖它之前的骰子选项，而不是创建多个条目；
- 当前函数只验证 ID，不验证收藏品类型。调用方必须保证它是真正的主动道具；
- 弯曲的硬币和故障王冠在识别逻辑中被明确排除，注册函数不能把它们重新加入骰子套装；
- 当前没有注销接口。

### 注册示例

```lua
local MyMod = RegisterMod("My Dice Mod", 1)
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

MyMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function()
    tryRegisterDiceCompat()
end)
```

### 不受支持的旧选项

不要传入或依赖：

```lua
refundCharges = true
```

当前 `RegisterDiceItem` 不读取这个字段，骰子套装也不会返还或修改主动道具充能。旧测试数据中出现该字段不代表它是公共合同。

### 自动识别与 EID

Neverbirth 也会尝试把具有正充能且名称包含已知骰子关键词的主动道具识别为骰子。这只是兼容回退，不应代替显式注册。

如果 EID 存在并提供所需能力，Neverbirth 会为识别到的骰子显示骰子套装进度。EID 是可选依赖；没有 EID 时，注册和核心骰子套装行为仍应继续工作。

## 明确不公开的内部表面

以下名字即使可以从 `_G.Neverbirth` 访问，也不属于本文公共合同：

- 所有以 `TestAPI` 结尾的表；
- `CertificateOfNeverbirthCarrierAPI`；
- `HouseVsElephantCarrierAPI`；
- `Neverbirth.MemoryDisorder.Runtime`；
- `Neverbirth.Everchanging.StyleRegistry`；
- `RegisterPickupBannerText`；
- `RegisterFortuneLuckEntry`；
- 未在本文列出的状态表、辅助方法和回调处理函数。

兼容作者不得依靠这些对象的名称、字段、调用顺序或长期存在。维护者可以在不更新本文公共兼容版本的情况下修改它们。

## 维护者检查清单

修改这三个兼容表面时，至少检查：

- 公共函数名、参数和布尔返回值是否仍与本文一致；
- 鸿运齐天蛊的 resolver 是否仍按实际玩家调用，并正确区分收藏品份数和饰品倍率；
- 记忆紊乱外部档案是否继续默认空、按玩家过滤、只撤销自己记录的临时组件；
- 档案 `id` 是否仍是保存和恢复时使用的稳定身份键；
- 骰子注册是否仍让第三方主动道具计入三个不同骰子的进度；
- `protectStats = false` 是否仍只关闭该骰子的属性保护，而不取消骰子身份；
- EID 缺失时是否仍能正常加载和运行核心机制；
- 重复注册、无效 ID、多人模式、继续游戏和 Mod 缺失路径是否安全；
- 静态测试结果不能代替真实双 Mod 加载顺序和游戏内验证。

相关实现与测试：

| 表面 | 实现 | 主要测试 |
| --- | --- | --- |
| 鸿运齐天蛊 | [`main.lua`](main.lua) 中的 `RegisterLuckCap*` 与 `RegisterTrinketLuckCap*` | [`tests/condom_utility_knife_behavior_test.lua`](tests/condom_utility_knife_behavior_test.lua) |
| 记忆紊乱 | [`memory_disorder.lua`](memory_disorder.lua) | [`tests/memory_disorder_behavior_test.lua`](tests/memory_disorder_behavior_test.lua) |
| 骰子套装 | [`main.lua`](main.lua) 中的骰子套装区块 | [`tests/dice_set_behavior_test.lua`](tests/dice_set_behavior_test.lua) |

发布兼容接口变更前，还应重新运行项目的 Lua 行为测试、XML/资源验证器，并在同时启用 Neverbirth 与至少一个测试兼容 Mod 的情况下完成实机检查。
