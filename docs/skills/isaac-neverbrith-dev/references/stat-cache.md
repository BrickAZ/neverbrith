# Stat Cache Reference

Use this reference when an item changes player stats or tear properties.

## Core Rule

Isaac stat changes should usually be applied through `MC_EVALUATE_CACHE`, not by permanently mutating player fields in random update callbacks.

The cache callback receives one `cacheFlag` at a time. Only modify the field that belongs to the current flag.

## Common Cache Flags

- `CacheFlag.CACHE_DAMAGE`: `player.Damage`
- `CacheFlag.CACHE_FIREDELAY`: `player.MaxFireDelay`
- `CacheFlag.CACHE_SPEED`: `player.MoveSpeed`
- `CacheFlag.CACHE_RANGE`: `player.TearRange`
- `CacheFlag.CACHE_SHOTSPEED`: `player.ShotSpeed`
- `CacheFlag.CACHE_LUCK`: `player.Luck`
- `CacheFlag.CACHE_TEARFLAG`: `player.TearFlags`
- `CacheFlag.CACHE_TEARCOLOR`: `player.TearColor`
- `CacheFlag.CACHE_FAMILIARS`: familiar count or familiar refresh logic

## Passive Stat Template

```lua
function Neverbirth:EvaluateItemName(player, cacheFlag)
    local itemCount = player:GetCollectibleNum(Items.ItemName)
    if itemCount <= 0 then
        return
    end

    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        player.Damage = player.Damage + 1.0 * itemCount
    elseif cacheFlag == CacheFlag.CACHE_SPEED then
        player.MoveSpeed = player.MoveSpeed + 0.15 * itemCount
    elseif cacheFlag == CacheFlag.CACHE_TEARCOLOR then
        player.TearColor = Color(0.2, 1.0, 0.2, 1.0)
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateItemName)
```

## Temporary Stat State

For timed or conditional bonuses:

1. Store state by `player.InitSeed`.
2. When the state changes, call `AddCacheFlags(...)`.
3. Then call `EvaluateItems()`.
4. In `MC_EVALUATE_CACHE`, read the state and apply only the current cache flag.

```lua
local itemNameStates = {}

local function RefreshItemNameCache(player)
    if not player or not player.AddCacheFlags then
        return
    end

    local flags = 0
    if CacheFlag and CacheFlag.CACHE_DAMAGE then
        flags = flags | CacheFlag.CACHE_DAMAGE
    end
    if CacheFlag and CacheFlag.CACHE_SPEED then
        flags = flags | CacheFlag.CACHE_SPEED
    end

    if flags ~= 0 then
        player:AddCacheFlags(flags)
    end
    if player.EvaluateItems then
        player:EvaluateItems()
    end
end
```

Use `pcall` only when the repo's existing nearby code uses it to protect optional API access.

## Fire Delay Care

`CACHE_FIREDELAY` modifies `player.MaxFireDelay`. Lower is faster. Avoid driving it below sane limits unless the item is intentionally extreme and tests cover it.

## Multiples And Stacking

Decide whether multiple copies stack:

- If yes, multiply by `player:GetCollectibleNum(...)`.
- If no, check `> 0` and apply a fixed effect.
- If the item has per-floor or per-room accumulated state, keep the accumulated value in the state table and avoid double-counting copies accidentally.

## Cache Refresh Checklist

- The XML `cache` attribute includes every cache touched by Lua.
- The Lua callback handles only matching `cacheFlag` branches.
- State-changing code calls `AddCacheFlags` and `EvaluateItems`.
- Temporary effects are removed from state before cache refresh when expiring.
- A behavior test runs the evaluate callback for each affected flag.
- Multi-player behavior uses separate keys, usually `player.InitSeed`.
