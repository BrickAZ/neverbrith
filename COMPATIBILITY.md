# Neverbirth compatibility guide

| Neverbirth item | What another mod can add | Status | Entry points |
| --- | --- | --- | --- |
| Fortune Rivalling Heaven Gu | Luck thresholds for custom collectibles and trinkets | Provisional and unversioned | `RegisterLuckCap`, `RegisterLuckCapResolver`, `RegisterTrinketLuckCap`, `RegisterTrinketLuckCapResolver` |
| Dice Set | Custom dice-themed active items | Provisional and unversioned | `RegisterDiceItem` |

Memory Disorder does not expose a public compatibility API in the published version.

## What another mod can add

Another mod can register its own collectibles or trinkets as Luck-threshold owners for Fortune Rivalling Heaven Gu, or explicitly register one of its active items as a die for Dice Set. These integrations are optional: Neverbirth continues to work when another mod does not register anything.

## Terms used in this guide

A Luck threshold is the Luck value where an effect reaches its highest possible activation chance. That chance is not necessarily 100%.

An active item is a collectible the player activates manually from an active-item slot, such as the D6.

A dice-themed active item is an active item presented as a die or built around a dice-like effect. It does not mean a die that is currently active.

## API status and stability

The entry points in this guide are provisional and unversioned. They are the published integration surface in the released source tree, not a promise that every unlisted Neverbirth function is stable. Check the current source and this guide when updating either mod.

## Finding Neverbirth and using runtime IDs

### Names and global object

Neverbirth exposes its integration object through the global `Neverbirth` value. A compatible mod should look it up defensively and skip registration when the object or required function is unavailable.

### Runtime IDs, not XML-local IDs

Every `itemId` and `trinketId` in this guide is a runtime ID returned by Isaac's name lookup, not an XML-local ID from a content file. Resolve an ID only after the relevant mod content is available, and reject a missing or non-positive result.

## Load order

The examples below assume that your mod already has its own `MyMod` object. Do not call `RegisterMod` again just to add Neverbirth compatibility.

```lua
local neverbirth = _G and rawget(_G, "Neverbirth")
if not neverbirth or type(neverbirth.RegisterLuckCap) ~= "function" then
    return
end
```

```lua
local myItemId = Isaac.GetItemIdByName("My Mod Item")
```

Do the lookup after both mods have loaded. The registration examples below try immediately and again after game start, so they remain safe if the global becomes available later in the startup sequence.

## Fortune Rivalling Heaven Gu

### What the integration does

Fortune Rivalling Heaven Gu uses registered entries only when the player owns the matching collectible or trinket. It finds the highest applicable Luck threshold and raises the player's Luck to that value when needed; it never lowers a higher Luck value already produced by the cache chain.

### Functions and parameters

```lua
Neverbirth:RegisterLuckCap(itemId, fixedCap)
Neverbirth:RegisterLuckCapResolver(itemId, resolverFn)
Neverbirth:RegisterTrinketLuckCap(trinketId, fixedCap)
Neverbirth:RegisterTrinketLuckCapResolver(trinketId, resolverFn)
```

Luck registration returns `true` for a positive runtime ID with a numeric fixed threshold or function resolver. Negative thresholds may register but are ignored during evaluation, so callers must not use them.

Resolver calls are protected; errors, non-numeric results, and negative results are ignored. Multiple applicable entries use the highest threshold, and Neverbirth never lowers higher existing Luck.

Duplicate Luck registrations create duplicate resolver calls. Callers must make registration idempotent. Resolver functions run in the Luck cache path and must remain fast, deterministic, and free of side effects.

For a resolver, the arguments are `player`, the registered runtime ID, and the player's current copy count for that owner. Use the collectible functions for collectibles and the trinket functions for trinkets.

### Fixed-threshold example

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

### Dynamic-threshold example

```lua
fortuneCompatRegistered = neverbirth:RegisterLuckCapResolver(myLuckyItem, function(player, itemId, count)
    if count >= 2 then
        return 8
    end
    return 12
end) == true
```

Keep this resolver side-effect free. In particular, do not register again from the resolver; registration belongs in an idempotent load-time or game-start path.

## Dice Set

### What the integration does

Dice Set counts recognized dice items that the player has collected, held, or used. Merely seeing a pedestal does not count. A recognized item contributes once per player toward the set; the caller is responsible for registering only an actual dice-themed active item.

### Function and parameters

```lua
Neverbirth:RegisterDiceItem(itemId, options)
```

`itemId` is a positive runtime collectible ID. `options` must be a table or `nil`. `options.name` is stored but does not change player-facing text. Only `protectStats = false` disables stat protection for that die.

`RegisterDiceItem` returns `true` for a valid positive ID and `false` for an invalid ID. Re-registering an ID replaces its options. The caller must ensure the ID belongs to an active item.

Crooked Penny and Glitched Crown remain excluded. There is no unregister API. `refundCharges` is not supported.

### Registration example

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

### Automatic detection and EID

Name-based dice detection is a fallback. Explicit registration is preferred. EID is optional and does not control core registration or Dice Set behavior.

## Interfaces that are not public

The following are not public integration interfaces: test APIs, carrier APIs, runtime state, `RegisterPickupBannerText`, `RegisterFortuneLuckEntry`, and any unlisted helper or callback. This list is not a versioned public contract; do not integrate against these surfaces.

## Maintainer appendix

The source and behavior tests below are useful static references for maintainers. They verify the released source contracts, but they do not prove in-game load order, third-party-mod interaction, gameplay balance, or visual behavior.

| Integration | Implementation | Main tests |
| --- | --- | --- |
| Fortune Rivalling Heaven Gu | `RegisterLuckCap*` and `RegisterTrinketLuckCap*` in [`main.lua`](main.lua) | [`tests/condom_utility_knife_behavior_test.lua`](tests/condom_utility_knife_behavior_test.lua) |
| Dice Set | Dice Set functions in [`main.lua`](main.lua) | [`tests/dice_set_behavior_test.lua`](tests/dice_set_behavior_test.lua) |
