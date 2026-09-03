# Neverbirth Compatibility API for Other Mods

[Chinese version](COMPATIBILITY.zh-CN.md)

This guide is for Isaac mod authors who want their own content to work with Neverbirth. It assumes that you know basic Isaac modding terms and Lua, but it does not assume that you already know how Neverbirth's items work.

## What other mods can integrate

Neverbirth currently lets other mods integrate with three of its items:

1. **Fortune Rivalling Heaven Gu:** Tell Neverbirth how much Luck another collectible or trinket needs to reach its highest possible activation chance.
2. **Memory Disorder:** Allow a custom player character to be selected as one of Memory Disorder's temporary identities.
3. **Dice Set:** Mark a custom dice-themed active item so Dice Set can recognize and count it.

### Terms used in this guide

- **Luck threshold** means the Luck value at which an item's luck-based effect reaches its highest possible activation chance. That highest chance is not necessarily 100%.
- An **active item** is a collectible that the player activates manually from an active-item slot, such as the D6.
- A **dice-themed active item** is an active item presented as a die or built around a dice-like effect. It does not mean a die that is currently active.
- The **compatibility API** is the small set of functions and tables that Neverbirth intentionally allows other mods to use.

> Only the functions and tables explicitly documented here are intended for other mods to use. Calling unlisted `Neverbirth.*` methods or accessing `TestAPI`, `CarrierAPI`, runtime state tables, or other internal fields is not supported.

## API status

| Neverbirth Item | What Another Mod Can Add | Status | Public Entry Points |
| --- | --- | --- | --- |
| Fortune Rivalling Heaven Gu | Luck thresholds for custom collectibles and trinkets | Supported, but not yet versioned | `RegisterLuckCap`, `RegisterLuckCapResolver`, `RegisterTrinketLuckCap`, `RegisterTrinketLuckCapResolver` |
| Memory Disorder | Custom character identity profiles | Supported through an experimental raw profile table | `Neverbirth.MemoryDisorderCharacterProfiles` |
| Dice Set | Custom dice-themed active items | Supported, but not yet versioned | `RegisterDiceItem` |

There is currently no `Neverbirth.Compat` namespace, `API_VERSION`, or formal `OnReady` callback. Compatibility mods must detect the capabilities they need instead of making assumptions based solely on Neverbirth's version number.

## Names, Global Object, and IDs

This project retains several historical spellings. Compatibility code must use the actual names rather than correcting them:

- Mod folder: `neverbrith`;
- `RegisterMod` name: `neverbirth`;
- Publicly accessible global object: `_G.Neverbirth`.

When obtaining Neverbirth, check whether the required capability exists:

```lua
local neverbirth = _G and rawget(_G, "Neverbirth")
if not neverbirth or type(neverbirth.RegisterLuckCap) ~= "function" then
    -- Neverbirth is absent, or this version does not provide the capability.
    return
end
```

### Do Not Use XML-Local IDs

Numbers such as `id="24"` and `id="55"` in `content/items*.xml` are Neverbirth's own stable local IDs, used by this project's resources and generation workflow. They are not the global runtime collectible IDs assigned by the game.

Third-party mods should resolve the runtime IDs of their own content using the names under which they registered that content. For example:

```lua
local myItemId = Isaac.GetItemIdByName("My Mod Item")
```

Do not pass Neverbirth's XML-local IDs to any of the registration functions below. Neverbirth does not currently expose its runtime `Items` table either.

## Load Order

Neverbirth creates `_G.Neverbirth` while loading `main.lua`, but the functions and table described in this guide are established later as that file continues executing or loads modules. Checking only `_G.Neverbirth ~= nil` is therefore insufficient; check the specific function or table you need as well.

Implement each registration as an idempotent `tryRegister` operation:

1. Try once immediately when your mod loads;
2. If the required function or table is not yet available, try again in your own `MC_POST_GAME_STARTED` callback;
3. After success, use your own boolean flag to prevent duplicate registration;
4. If Neverbirth is absent, skip silently without breaking your mod's core functionality;
5. Do not poll every frame indefinitely while waiting for Neverbirth.

The examples in each section follow these rules.

## Fortune Rivalling Heaven Gu: Provide an item's Luck threshold

### Purpose

Some collectibles and trinkets have effects whose activation chance improves with Luck, then stops improving after a particular Luck value. This guide calls that value the item's **Luck threshold**. Reaching the threshold means reaching the effect's highest possible chance; it does not necessarily mean a 100% chance.

When a player holds Fortune Rivalling Heaven Gu together with one of those items, Fortune Rivalling Heaven Gu can raise the player's Luck to the highest relevant registered threshold. To support a third-party item, its mod must tell Neverbirth what that threshold is.

A third-party mod can provide a fixed threshold or use a resolver to calculate one dynamically based on the player, collectible copy count, or trinket multiplier. Only players who actually hold Fortune Rivalling Heaven Gu receive the Luck adjustment; adding an entry to the API does not affect other players by itself.

### Public Signatures

```lua
Neverbirth:RegisterLuckCap(itemId, fixedCap) -- Returns boolean
Neverbirth:RegisterLuckCapResolver(itemId, resolverFn) -- Returns boolean

Neverbirth:RegisterTrinketLuckCap(trinketId, fixedCap) -- Returns boolean
Neverbirth:RegisterTrinketLuckCapResolver(trinketId, resolverFn) -- Returns boolean
```

Parameters:

| Parameter | Meaning |
| --- | --- |
| `itemId` | A positive runtime collectible ID |
| `trinketId` | A positive runtime trinket ID |
| `fixedCap` | The Luck value at which this content reaches its highest possible activation chance; use a non-negative number |
| `resolverFn` | A dynamic threshold function with the signature `resolverFn(player, id, count)` |

Resolver parameters:

| Parameter | Collectible Registration | Trinket Registration |
| --- | --- | --- |
| `player` | The player whose luck is currently being evaluated | The player whose luck is currently being evaluated |
| `id` | The registered collectible ID | The registered trinket ID |
| `count` | The copy count returned by `GetCollectibleNum` | The multiplier returned by `GetTrinketMultiplier`, covering normal, swallowed, and golden trinkets |

Return values and evaluation rules:

- Registration returns `true` for a positive ID paired with either a fixed threshold convertible to a number or a function-valued resolver; other inputs return `false`;
- Negative fixed thresholds are currently accepted and return `true`, but are ignored during evaluation. Compatibility code must therefore not use negative thresholds;
- Neverbirth executes resolvers through a protected call. Errors, non-numeric results, and negative results are excluded from that evaluation;
- When multiple valid entries apply, the highest threshold is used;
- Neverbirth only raises luck that is below the threshold; it does not lower a player's already higher luck;
- Multiple entries may be registered for the same ID. There is currently no unregister, replace, or automatic deduplication interface;
- Although duplicate registrations usually do not stack the final luck value, they cause duplicate resolver calls. Compatibility mods must register only once.

Resolvers run in the luck cache calculation path. Keep them fast, deterministic, and free of side effects. Do not spawn entities, save data, use non-deterministic randomness, or register callbacks inside them.

### Fixed-Threshold Example

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

### Dynamic-Threshold Example

```lua
-- Place this inside tryRegisterFortuneCompat after resolving neverbirth and myLuckyItem.
fortuneCompatRegistered = neverbirth:RegisterLuckCapResolver(myLuckyItem, function(player, itemId, count)
    if count >= 2 then
        return 8
    end

    return 12
end) == true
```

This example demonstrates only the interface. The values `8` and `12`, and the two-copy condition, must come from verified mechanics in the compatibility mod, not guesswork.

## Memory Disorder: Add a custom character identity

### Purpose

Memory Disorder temporarily changes the player into different character identities. Every time the player actually enters a room, it selects one identity from the character profiles currently available to that player.

Neverbirth already includes profiles for vanilla characters. A custom character is not considered automatically: the character's mod must add a profile to the external allowlist. That profile tells Neverbirth which PlayerType to use, when the character is compatible, and which temporary health rules, items, or callbacks belong to the identity.

The only currently supported external table is:

```lua
Neverbirth.MemoryDisorderCharacterProfiles
```

Do not treat `Runtime`, state methods, or test helpers under `Neverbirth.MemoryDisorder` as public interfaces.

### Profile Structure

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

Fields:

| Field | Required | Current Contract |
| --- | --- | --- |
| `id` | Yes | A globally unique string that remains stable across versions; `mod_id:character_id` is recommended. This value is stored in Neverbirth's saved run state |
| `playerType` | Yes | A positive runtime PlayerType for the character, for example one obtained through `Isaac.GetPlayerTypeByName` |
| `isCompatible` | Strongly recommended | `function(player, context) -> boolean`; the profile joins the current candidate pool only when this function explicitly returns `true`. If omitted, the current implementation considers the profile available |
| `healthMode` | No | `ordinary`, `soul_only`, `keeper`, or `lost`; defaults to `ordinary` when omitted |
| `keeperHeartCap` | Recommended for Keeper mode | The Keeper heart capacity, expressed in Isaac's half-heart units |
| `collectibles` | No | An array of runtime collectible IDs to grant temporarily |
| `actives` | No | An array of temporary active items; each entry is `{ id, slot, charge }` |
| `pocketActives` | No | An array of temporary pocket active items; each entry is `{ id, slot, charge }` |
| `pocketCards` | No | A `PocketItemSlot -> Card ID` mapping |
| `randomPill` | No | When `true`, attempts to place a random pill in the primary pocket slot |
| `onApply` | No | Called after the identity and its declared components have been applied |
| `onRemove` | No | Called when leaving this identity or losing Memory Disorder |

`state` and `context` are currently passed to compatibility functions, but remain internal Neverbirth objects. Third-party code must not rely on their field names, persistence structure, or methods remaining stable in future versions. Any third-party state that needs long-term storage should be owned by the third-party mod itself.

### Lifecycle Order

When switching away from an external identity, the current sequence is:

1. Record health changes that occurred during that identity;
2. Call the old profile's `onRemove`;
3. Remove only the temporary components that Neverbirth recorded for that identity;
4. Switch PlayerType;
5. Apply the new profile's health mode and temporary components;
6. Call the new profile's `onApply`.

External mods must not remove every copy of an item with the same ID in `onRemove`, or delete entities that are not explicitly owned by their mod or this profile.

The external profile's `isCompatible` is responsible for checking whether the character is unlocked, required dependencies are present, and switching to that PlayerType is currently safe. Neverbirth does not automatically read third-party character achievement or unlock fields.

### Complete Registration Example

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
            -- If this character requires an unlock, call your mod's unlock check here.
            return true
        end,

        collectibles = {
            startingItem,
        },

        onApply = function(player, state, context)
            -- Create only temporary state owned by this mod.
        end,

        onRemove = function(player, state, context)
            -- Remove only the state created by this mod.
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

Do not put `-1` or `0` in component arrays. The example leaves the existing state unchanged and returns `false` if the character or starting item cannot be resolved.

### Current Limitations

- There is no `RegisterMemoryDisorderProfile` function; external code must currently append profiles to the allowlist array;
- There is no built-in duplicate `id` check. Duplicate entries pollute the candidate pool, so the example checks for them explicitly;
- There is no interface for unregistering a profile;
- Non-standard health systems, dual-body characters, engine-created secondary bodies, and special resources require separate in-game verification;
- Errors in `onApply`, `onRemove`, and `isCompatible` are caught by protected calls, but profile authors should still log enough information to diagnose problems;
- In multiplayer, selection and evaluation are performed separately for each player. Compatibility code must use the actual player, not player 0 or a single global "current character."

## Dice Set: Add a custom dice-themed active item

### Purpose

Dice Set keeps a separate record for each player of the different dice-themed active items that player has seen or used. After three different dice items, that player unlocks the set. Once unlocked, using a recognized die makes Dice Set protect damage, fire-rate, and range-related results from falling below its recorded baseline.

If another mod provides a dice-themed active item, it can explicitly add that item to Dice Set's recognition list. This works even if the item's name does not contain one of Neverbirth's recognized dice keywords.

### Public Signature

```lua
Neverbirth:RegisterDiceItem(itemId, options) -- Returns boolean
```

Parameters:

| Parameter | Required | Current Contract |
| --- | --- | --- |
| `itemId` | Yes | A positive runtime collectible ID for the third-party dice-themed active item |
| `options.name` | No | A readable name stored in the registry; do not currently rely on it to change player-facing text |
| `options.protectStats` | No | Defaults to `true`; when `false`, the item still counts as a die, but using it does not start Dice Set's stat protection |

Return rules:

- Registration returns `true` for a positive ID and `false` for an invalid ID;
- Registering the same ID again replaces its previous dice options instead of creating multiple entries;
- The function currently validates only the ID, not the collectible type. The caller must ensure that the item is actually an active item;
- Crooked Penny and Glitched Crown are explicitly excluded by the detection logic. The registration function cannot add them back to Dice Set;
- There is currently no unregister interface.

### Registration Example

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

### Unsupported Legacy Option

Do not pass or rely on:

```lua
refundCharges = true
```

The current `RegisterDiceItem` does not read this field, and Dice Set does not refund or modify active item charges. Its presence in old test data does not make it part of the public contract.

### Automatic Detection and EID

Neverbirth also attempts to recognize active items as dice when they have a positive charge requirement and their names contain known dice keywords. This is only a compatibility fallback and should not replace explicit registration.

If EID is present and provides the required capabilities, Neverbirth displays Dice Set progress for recognized dice. EID is optional; registration and core Dice Set behavior should continue to work without it.

## Explicitly Non-Public Internals

The following names are not part of this document's public contract, even if they are accessible through `_G.Neverbirth`:

- All tables whose names end in `TestAPI`;
- `CertificateOfNeverbirthCarrierAPI`;
- `HouseVsElephantCarrierAPI`;
- `Neverbirth.MemoryDisorder.Runtime`;
- `Neverbirth.Everchanging.StyleRegistry`;
- `RegisterPickupBannerText`;
- `RegisterFortuneLuckEntry`;
- Any state tables, helper methods, or callback handlers not listed in this document.

Compatibility authors must not depend on these objects' names, fields, call order, or continued existence. Maintainers may change them without updating the public compatibility version described here.

## Maintainer Checklist

When changing any of these three compatibility interfaces, check at least the following:

- Public function names, parameters, and boolean return values still match this document;
- Fortune Rivalling Heaven Gu's resolvers still receive the actual player and correctly distinguish collectible copy counts from trinket multipliers;
- Memory Disorder's external profile list still defaults to empty, is filtered per player, and removes only the temporary components it recorded;
- Profile `id` values remain the stable identity keys used for saving and restoration;
- Dice registration still lets third-party active items count toward the three-distinct-dice requirement;
- `protectStats = false` still disables only that die's stat protection without removing its dice classification;
- Core mechanics still load and run normally when EID is absent;
- Duplicate registration, invalid IDs, multiplayer, continued runs, and missing-mod paths are handled safely;
- Static test results are not treated as a substitute for actual two-mod load-order checks and in-game verification.

Related implementations and tests:

| Interface | Implementation | Main Tests |
| --- | --- | --- |
| Fortune Rivalling Heaven Gu | `RegisterLuckCap*` and `RegisterTrinketLuckCap*` in [`main.lua`](main.lua) | [`tests/condom_utility_knife_behavior_test.lua`](tests/condom_utility_knife_behavior_test.lua) |
| Memory Disorder | [`memory_disorder.lua`](memory_disorder.lua) | [`tests/memory_disorder_behavior_test.lua`](tests/memory_disorder_behavior_test.lua) |
| Dice Set | The Dice Set section in [`main.lua`](main.lua) | [`tests/dice_set_behavior_test.lua`](tests/dice_set_behavior_test.lua) |

Before releasing compatibility interface changes, rerun the project's Lua behavior tests and XML/resource validators, and complete in-game checks with both Neverbirth and at least one test compatibility mod enabled.
