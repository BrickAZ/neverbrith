# Neverbirth compatibility API

[简体中文](COMPATIBILITY.zh-CN.md)

| Integration | What it does |
| --- | --- |
| Fortune Rivalling Heaven Gu | Register the Luck needed for your item's proc chance to reach its maximum, so Fortune can raise the holder's Luck accordingly. |
| Dice Set | Make your custom dice active count toward Dice Set. |
| Memory Disorder | Add your custom character to the random identity pool. |

Use the global `Neverbirth` after both mods have loaded; skip compatibility if the required function or table is absent. Item, trinket, and character IDs are **runtime IDs**. Register each entry once. These interfaces are provisional and unversioned; EID is optional.

## Fortune Rivalling Heaven Gu

Only applies while the player holds Fortune and a registered owner item or trinket. The highest applicable threshold wins; higher existing Luck is preserved. A threshold is where the effect reaches its maximum chance, which need not be 100%.

### RegisterLuckCap

```lua
Neverbirth:RegisterLuckCap(itemId, fixedCap) -- boolean
```

Register a collectible's fixed threshold. `itemId`: positive integer collectible ID; `fixedCap`: non-negative number. Returns `true` on registration, `false` for an invalid ID or missing threshold.

### RegisterTrinketLuckCap

```lua
Neverbirth:RegisterTrinketLuckCap(trinketId, fixedCap) -- boolean
```

The trinket equivalent. `trinketId`: positive integer trinket ID; `fixedCap` and return value follow `RegisterLuckCap`.

### RegisterLuckCapResolver

```lua
Neverbirth:RegisterLuckCapResolver(itemId, resolverFn) -- boolean
```

Register a dynamic collectible threshold. `resolverFn(player, itemId, count)` returns a non-negative number; `count` is the player's copy count. Returns `false` for an invalid ID or non-function resolver, otherwise `true`. Resolver errors and invalid or negative results are ignored.

### RegisterTrinketLuckCapResolver

```lua
Neverbirth:RegisterTrinketLuckCapResolver(trinketId, resolverFn) -- boolean
```

The trinket equivalent. The callback receives `(player, trinketId, multiplier)`; `multiplier` includes golden and smelted trinket effects. Registration and return rules follow `RegisterLuckCapResolver`.

**Register each Luck entry once:** duplicate registrations accumulate. Resolvers must be fast and free of side effects.

### InvalidateFortuneLuck

```lua
Neverbirth:InvalidateFortuneLuck(player) -- no return value
```

Refresh a live player's dynamic threshold on the next Neverbirth update. `player`: `EntityPlayer` or `nil`; omit it to refresh all current players. Registration and registered owner-count changes already trigger refreshes. Call this after changing other resolver inputs, such as health or your mod's own state. Ordinary `CACHE_LUCK` evaluation alone does not refresh the threshold. Do not call from inside a resolver.

## Dice Set

### RegisterDiceItem

```lua
Neverbirth:RegisterDiceItem(itemId, options) -- boolean
```

Register your dice-themed active item. Collected, held, or used dice count once per player; merely seeing a pedestal does not count. `itemId`: positive integer collectible ID. The caller must ensure it is an active item. Returns `true` for a valid ID, otherwise `false`.

`options` is a table or `nil`:

| Field | Meaning |
| --- | --- |
| `protectStats` | Defaults to `true`; only `false` opts this die out of Dice Set's stat protection. |
| `name` | Optional stored label; does not change the displayed item name. |

Re-registering the same ID replaces its options. Crooked Penny and Glitched Crown remain excluded. There is no unregister API or `refundCharges` option.

## Memory Disorder

### MemoryDisorderCharacterProfiles

```lua
table.insert(Neverbirth.MemoryDisorderCharacterProfiles, profile)
```

An array of character profiles, initially empty. Appending a profile makes that character eligible for Memory Disorder's future random identity selections; it does not immediately transform a player. Unregistered mod characters are not selected automatically.

| Profile field | Type | Meaning |
| --- | --- | --- |
| `id` | `string` | Required stable, unique key, such as `my_mod:my_character`. It is used to look up saved identities; do not reuse a vanilla profile ID or change it between sessions. |
| `playerType` | `integer` | Required runtime character type, resolved with `Isaac.GetPlayerTypeByName`. Reject failed lookups before appending. |
| `isCompatible` | `function` or `nil` | Optional `(player, context) -> boolean` eligibility check for the current holder. Only `true` admits the profile; errors exclude it. Omission allows it without this check. `context` is internal; do not rely on its fields. |

For custom unlocks, check your own unlock state in `isCompatible`; a profile's `achievement` field is not automatically checked for mod characters. Append once, keep the original array, and register again on each mod load before a saved run is restored. The table does not validate character existence or remove duplicates.

This entry point covers candidate registration. Custom health systems, linked bodies, and character-specific state still need their own compatibility testing. Other profile fields and `Neverbirth.MemoryDisorder` helpers are internal.

<details>
<summary>Complete example: register one always-unlocked custom character</summary>

Assumes your mod already has `MyMod`. Replace `My Character` and `my_mod:my_character`. For an unlockable character, add `isCompatible` using your mod's unlock check.

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

The immediate attempt supports early registration; game start retries if Neverbirth loaded later. The ID check prevents repeated inserts.

</details>

Source: [Luck and dice APIs](main.lua), [character profiles](memory_disorder.lua). Behavior checks: [Luck](tests/fortune_custom_cache_behavior_test.lua), [dice](tests/dice_set_behavior_test.lua), [characters](tests/memory_disorder_behavior_test.lua). These checks do not replace in-game compatibility testing.
