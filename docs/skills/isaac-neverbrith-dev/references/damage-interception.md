# Damage Interception Reference

Use this reference for `MC_ENTITY_TAKE_DMG` work. This is the most fragile item category because a callback can accidentally cancel real damage, trigger on paid damage, or recurse into itself.

## Callback Shape

```lua
function Neverbirth:HandleItemNameDamage(entity, amount, flags, source, countdown)
    local player = entity and entity.ToPlayer and entity:ToPlayer()
    if not player then
        return nil
    end

    local damageAmount = tonumber(amount) or 0
    if damageAmount <= 0 then
        return nil
    end

    if not PlayerHasItemName(player) then
        return nil
    end

    -- Decide whether to react, block, rewrite, or only record.
    return nil
end

Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.HandleItemNameDamage, EntityType.ENTITY_PLAYER)
```

Return values matter:

- `return nil`: do not change normal damage processing.
- `return false`: cancel the incoming damage.

Only return `false` after all filters pass.

## Required Filters

Before changing damage behavior, decide each filter explicitly:

- Is the damaged entity definitely a player?
- Does the player have the item?
- Is `amount > 0`?
- Should fake damage count?
- Should IV Bag, Devil deals, cursed doors, sacrifice rooms, blood donation, or other cost damage count?
- Should self-inflicted mod settlement damage count?
- Should already-delayed or already-settling damage count?
- Does the behavior differ in multiplayer?

## Damage Categories

These categories should be called out in code or tests when relevant:

- **Combat damage**: enemy, projectile, explosion, creep, spike, or room hazard damage. Most "when hurt" items mean this.
- **Red-heart flagged damage**: damage with `DAMAGE_RED_HEARTS`. This flag does not prove what heart type was actually removed.
- **Cost damage**: `DAMAGE_IV_BAG`, `DAMAGE_DEVIL`, `DAMAGE_CURSED_DOOR`, sacrifice room, slot-like sources, and item costs. Many reward-on-hit items should ignore these.
- **Fake damage**: `DAMAGE_FAKE`. Usually ignore it for real damage rewards.
- **Settlement damage**: damage created by this mod via `player:TakeDamage(...)`. Guard it with a state flag to avoid recursive callback loops.
- **Protection/behavior flags**: `DAMAGE_NOKILL`, `DAMAGE_INVINCIBLE`, `DAMAGE_IGNORE_ARMOR`, `DAMAGE_NO_MODIFIERS`. These change how damage resolves; they are not a damage source by themselves.

## Recursion Guard Template

Use a per-player guard when the item calls `player:TakeDamage(...)` inside or after a damage callback.

```lua
local itemNameSettling = {}

local function GetItemNamePlayerKey(player)
    return tostring(player and player.InitSeed or "")
end

local function ApplyItemNameSettlementDamage(player, amount)
    local playerKey = GetItemNamePlayerKey(player)
    itemNameSettling[playerKey] = true

    if player and player.TakeDamage then
        player:TakeDamage(amount, DamageFlag.DAMAGE_INVINCIBLE, EntityRef(player), 0)
    end

    itemNameSettling[playerKey] = nil
end

function Neverbirth:HandleItemNameDamage(entity, amount, flags, source)
    local player = entity and entity.ToPlayer and entity:ToPlayer()
    local playerKey = GetItemNamePlayerKey(player)

    if itemNameSettling[playerKey] then
        return nil
    end

    -- normal logic
end
```

If the project already has another global guard for a related mechanic, such as backlash depth, check it before adding a second overlapping guard.

## Cost Damage Filter Template

```lua
local ITEM_NAME_COST_DAMAGE_FLAGS = {
    DamageFlag and DamageFlag.DAMAGE_FAKE,
    DamageFlag and DamageFlag.DAMAGE_IV_BAG,
    DamageFlag and DamageFlag.DAMAGE_DEVIL,
    DamageFlag and DamageFlag.DAMAGE_CURSED_DOOR,
}

local function HasItemNameDamageFlag(flags, flag)
    return flag ~= nil and flag ~= 0 and ((tonumber(flags) or 0) & flag) ~= 0
end

local function IsItemNameCostDamage(flags, source)
    for _, flag in pairs(ITEM_NAME_COST_DAMAGE_FLAGS) do
        if HasItemNameDamageFlag(flags, flag) then
            return true
        end
    end

    local sourceEntity = source and source.Entity or source
    if sourceEntity and sourceEntity.Type == EntityType.ENTITY_SLOT then
        return true
    end

    return false
end
```

Sacrifice rooms are not always exposed as a clean flag; inspect the current room type if the design cares.

## Heart Type Inference

Do not assume `DAMAGE_RED_HEARTS` is the full truth. For reward logic that depends on red, soul, or black heart loss:

1. Check explicit red-heart flag first.
2. Inspect `player:GetSoulHearts()`.
3. Inspect `player:GetBlackHearts()` if black-heart distinction matters.
4. Cover the inference in tests.

The existing Empty Cradle implementation is the local pattern for this category.

## Damage Interception Checklist

- Callback is registered for `EntityType.ENTITY_PLAYER` unless non-player damage is intentional.
- Callback returns `nil` for irrelevant damage and `false` only when intentionally blocking incoming damage.
- Cost/fake damage policy is explicit.
- Any self-created `TakeDamage` path has a recursion guard.
- Tests cover normal combat damage, ignored cost/fake damage, repeated hits, and multiplayer separation when state is per-player.
- If delayed damage exists, tests cover immediate hit, stored state, settlement, and reentry.
