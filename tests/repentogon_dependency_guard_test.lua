-- The real entrypoint and guard run with ONLY vanilla API doubles. No RGON enums.
-- Catches silent startup failure, gameplay includes, foreign-item removal, and
-- head text in the wrong coordinate domain or outside the starting room.
local registry = dofile("generated/neverbirth_collectibles.lua")
local function fixture(locale, failFont)
    local callbacks, drawn, loadedFonts, lookedUp = {}, {}, {}, {}
    local removedItems, removedTrinkets, owned, names = {}, {}, {}, {}
    for index, row in ipairs(registry) do
        local id = 1000 + index
        names[locale == "zh" and row.names[#row.names] or row.names[1]] = id
        owned[id] = true
    end
    local roomIndex, startingIndex, count = 84, 84, 2
    local poolReady = false
    local poolReads = 0
    local players = {
        { Position = { X = 300, Y = 180 }, PositionOffset = { X = 7, Y = -13 }, SpriteOffset = { X = 3, Y = -11 } },
        { Position = { X = 470, Y = 200 }, PositionOffset = { X = -9, Y = 17 }, SpriteOffset = { X = -5, Y = 19 } },
    }
    local colorMeta = {}
    local pool = {
        RemoveCollectible = function(_, id) assert(owned[id], "foreign item removed"); removedItems[id] = true end,
        RemoveTrinket = function(_, id) assert(id == 801, "foreign trinket removed"); removedTrinkets[id] = true end,
    }
    local level = {
        GetCurrentRoomIndex = function() return roomIndex end,
        GetStartingRoomIndex = function() return startingIndex end,
    }
    local mod = { AddCallback = function(_, id, fn, filter)
        assert(type(id) == "number", "non-vanilla callback used")
        callbacks[id] = callbacks[id] or {}
        table.insert(callbacks[id], { fn = fn, filter = filter })
    end }
    local env = setmetatable({ Options = { Language = locale } }, { __index = _G })
    env._G = env
    env.ModCallbacks = { MC_POST_UPDATE = 1, MC_POST_RENDER = 2, MC_POST_PLAYER_INIT = 9,
        MC_POST_GAME_STARTED = 15, MC_PRE_GAME_EXIT = 16, MC_POST_NEW_LEVEL = 18,
        MC_POST_PICKUP_INIT = 34, MC_POST_PICKUP_UPDATE = 35,
        MC_POST_GET_COLLECTIBLE = 63, MC_GET_PILL_EFFECT = 65, MC_GET_TRINKET = 66 }
    env.CollectibleType = { COLLECTIBLE_BREAKFAST = 25 }
    env.TrinketType = { TRINKET_PAPER_CLIP = 19, TRINKET_GOLDEN_FLAG = 32768 }
    env.PillEffect = { PILLEFFECT_BAD_GAS = 0 }
    env.PickupVariant = { PICKUP_COLLECTIBLE = 100, PICKUP_TRINKET = 350 }
    env.EntityType = { ENTITY_PICKUP = 5 }
    env.Game = function() return {
        GetLevel = function() return level end, GetNumPlayers = function() return count end,
        GetItemPool = function()
            assert(poolReady, "item pool accessed before run initialization completed")
            poolReads = poolReads + 1
            return pool
        end,
    } end
    env.KColor = setmetatable({}, { __call = function(_, r, g, b, a)
        return setmetatable({ R = r, G = g, B = b, A = a }, colorMeta)
    end })
    env.Font = setmetatable({}, { __call = function()
        local path
        return {
            Load = function(_, value) path = value; loadedFonts[#loadedFonts + 1] = value end,
            IsLoaded = function() return not failFont end,
            GetStringWidthUTF8 = function(_, value) return utf8.len(value) * 8 end,
            DrawStringScaledUTF8 = function(_, value, x, y, sx, sy, color)
                assert(getmetatable(color) == colorMeta, "requires native-compatible KColor")
                drawn[#drawn + 1] = { text = value, x = x, y = y, color = color, font = path }
            end,
        }
    end })
    env.RegisterMod = function() return mod end
    env.Isaac = {
        ConsoleOutput = function() end,
        GetItemIdByName = function(name) lookedUp[name] = true; return names[name] or -1 end,
        GetTrinketIdByName = function(name) assert(name == "Seven Curses Slot Seal"); return 801 end,
        GetPillEffectByName = function(name)
            return name == (locale == "zh" and "蓄风药剂" or "Wind Charge Potion") and 91 or -1
        end,
        GetPlayer = function(i) return players[i + 1] end,
        WorldToScreen = function(position)
            assert(position == players[1].Position or position == players[2].Position,
                "use the logical world anchor exactly once, without visual offsets")
            return { X = position.X + 11, Y = position.Y + 23 }
        end,
        GetScreenWidth = function() return 640 end,
        RenderText = function(value, x, y) drawn[#drawn + 1] = { text = value, x = x, y = y } end,
    }
    env.include = function(name)
        assert(name == "repentogon_dependency_guard" or name == "generated.neverbirth_collectibles",
            "gameplay module loaded without REPENTOGON: " .. name)
        return assert(loadfile(name:gsub("%.", "/") .. ".lua", "t", env))()
    end
    assert(loadfile("main.lua", "t", env))()
    local function fire(name, ...)
        local handlers = callbacks[env.ModCallbacks[name]]
        assert(handlers, "missing vanilla safety callback: " .. name)
        local result
        for _, cb in ipairs(handlers) do
            if cb.filter == nil or cb.filter == select(1, ...).Variant then
                local value = cb.fn(mod, ...)
                if value ~= nil then result = value end
            end
        end
        return result
    end
    return { env = env, fire = fire, drawn = drawn, loadedFonts = loadedFonts,
        removedItems = removedItems, removedTrinkets = removedTrinkets, owned = owned,
        players = players,
        moveRoom = function(value) roomIndex = value end,
        setPlayerCount = function(value) count = value end,
        setPoolReady = function(value) poolReady = value end,
        poolReads = function() return poolReads end,
        clearDraw = function() for i = #drawn, 1, -1 do drawn[i] = nil end end,
    }
end

for _, locale in ipairs({ "en", "zh" }) do
    local f = fixture(locale)
    assert(f.env.Neverbirth == nil, "failed dependency must not export gameplay API")
    f.fire("MC_POST_PLAYER_INIT", f.players[1])
    f.fire("MC_POST_NEW_LEVEL") -- Initial floor arrives before MC_POST_GAME_STARTED.
    assert(f.poolReads() == 0 and next(f.removedItems) == nil,
        "startup callbacks must not touch an uninitialized native item pool")
    assert(f.fire("MC_POST_GET_COLLECTIBLE", 1001) == 25,
        "early drops must still be blocked before pool cleanup")
    f.setPoolReady(true)
    f.fire("MC_POST_GAME_STARTED", false)
    for id in pairs(f.owned) do assert(f.removedItems[id], "owned item still in pools: " .. id) end
    assert(f.removedTrinkets[801], "hidden seal still in trinket pool")
    local reads = f.poolReads()
    f.fire("MC_POST_UPDATE")
    f.fire("MC_POST_UPDATE")
    assert(f.poolReads() == reads, "pool cleanup must not repeat every frame")
    for _, callback in ipairs({ "MC_POST_NEW_LEVEL", "MC_POST_GAME_STARTED" }) do
        for id in pairs(f.removedItems) do f.removedItems[id] = nil end
        f.removedTrinkets[801] = nil
        f.fire(callback, true)
        f.fire("MC_POST_UPDATE")
        for id in pairs(f.owned) do assert(f.removedItems[id], "pool exclusion lost on run/floor change") end
        assert(f.removedTrinkets[801])
    end
    for id in pairs(f.owned) do assert(f.fire("MC_POST_GET_COLLECTIBLE", id) == 25) end
    assert(f.fire("MC_POST_GET_COLLECTIBLE", 1) == nil, "changed vanilla item")
    assert(f.fire("MC_POST_GET_COLLECTIBLE", 5000) == nil, "changed another mod's item")
    assert(f.fire("MC_GET_TRINKET", 801) == 19)
    assert(f.fire("MC_GET_TRINKET", 32768 + 801) == 32768 + 19)
    assert(f.fire("MC_GET_TRINKET", 61) == nil)
    assert(f.fire("MC_GET_PILL_EFFECT", 91) == 0)
    assert(f.fire("MC_GET_PILL_EFFECT", 1) == nil)
    for _, callback in ipairs({ "MC_POST_PICKUP_INIT", "MC_POST_PICKUP_UPDATE" }) do
        for _, data in ipairs({ { 100, 1001, 25 }, { 350, 33569, 32787 }, { 100, 5000, 5000 } }) do
            local pickup = { Type = 5, Variant = data[1], SubType = data[2], Price = 15, OptionsPickupIndex = 7 }
            function pickup:Morph(kind, variant, subtype, keepPrice, keepSeed, ignoreModifiers)
                assert(kind == 5 and variant == self.Variant)
                assert(keepPrice and keepSeed and ignoreModifiers, "replacement must preserve pickup contract")
                self.SubType = subtype
            end
            f.fire(callback, pickup)
            assert(pickup.SubType == data[3], "missed direct or morphed pickup")
        end
    end
    f.fire("MC_POST_GAME_STARTED", false)
    f.fire("MC_POST_RENDER")
    assert(#f.drawn == 12, "three lines with shadow above each co-op player")
    assert(f.drawn[2].y == 127 and f.drawn[8].y == 147, "wrong head anchor / double offset")
    assert(f.drawn[2].text:find(locale == "zh" and "未生" or "neverbirth", 1, true))
    assert(f.drawn[4].text:find("1.0.12a", 1, true), "warning must state minimum version")
    assert(f.drawn[6].text:find(locale == "zh" and "重启" or "restart", 1, true), "actionable next step")
    local loads = #f.loadedFonts
    f.clearDraw(); f.fire("MC_POST_RENDER")
    assert(#f.loadedFonts == loads, "font reloaded every frame")
    f.moveRoom(85); f.clearDraw(); f.fire("MC_POST_RENDER")
    assert(#f.drawn == 0, "warning outside starting room")
    f.moveRoom(84); f.fire("MC_POST_RENDER"); assert(#f.drawn == 12, "warning does not return")
    f.fire("MC_PRE_GAME_EXIT"); f.clearDraw(); f.fire("MC_POST_RENDER")
    assert(#f.drawn == 0, "warning leaked after exit")
    f.fire("MC_POST_GAME_STARTED", true); f.fire("MC_POST_RENDER")
    assert(#f.drawn == 12, "continued runs need warning too")
    f.setPlayerCount(0); f.clearDraw(); f.fire("MC_POST_RENDER"); assert(#f.drawn == 0)
    f.setPlayerCount(1); f.env.Options.Language = locale == "zh" and "en" or "zh"
    f.fire("MC_POST_RENDER")
    assert(f.drawn[2].text:find(locale == "zh" and "neverbirth" or "未生", 1, true), "language switch ignored")
end

-- Continue, co-op initialization, in-run Lua reload and exit all use the same
-- real entrypoint. The pool double refuses calls while native state is unready.
local continued = fixture("en")
continued.fire("MC_POST_PLAYER_INIT", continued.players[1])
continued.setPoolReady(true)
continued.fire("MC_POST_GAME_STARTED", true)
assert(continued.poolReads() == 1, "continued run must clean the initialized pool")
continued.setPoolReady(false)
continued.fire("MC_POST_PLAYER_INIT", continued.players[2])
continued.setPoolReady(true)
continued.fire("MC_POST_UPDATE")
assert(continued.poolReads() == 2, "co-op initialization must defer cleanup")
continued.setPoolReady(false)
continued.fire("MC_POST_NEW_LEVEL")
continued.fire("MC_PRE_GAME_EXIT")
continued.fire("MC_POST_UPDATE")
assert(continued.poolReads() == 2, "queued cleanup must not run after exit")
continued.fire("MC_POST_PLAYER_INIT", continued.players[1])
continued.fire("MC_POST_NEW_LEVEL")
continued.setPoolReady(true)
continued.fire("MC_POST_GAME_STARTED", false)
assert(continued.poolReads() == 3, "new run after exit must re-arm pool cleanup")

local reloaded = fixture("zh")
reloaded.setPlayerCount(0)
reloaded.fire("MC_POST_UPDATE")
assert(reloaded.poolReads() == 0, "no-player update must not access the pool")
reloaded.setPlayerCount(1)
reloaded.setPoolReady(true)
reloaded.fire("MC_POST_UPDATE") -- Reload does not replay MC_POST_GAME_STARTED.
for id in pairs(reloaded.owned) do
    assert(reloaded.removedItems[id], "in-run reload must restore pool exclusion")
end
reloaded.fire("MC_POST_UPDATE")
assert(reloaded.poolReads() == 1, "reload cleanup must run only once")

local fallback = fixture("zh", true)
fallback.fire("MC_POST_RENDER")
assert(#fallback.drawn > 0 and fallback.drawn[1].text:find("neverbirth", 1, true), "font failure must still warn")
print("REPENTOGON dependency guard passed: vanilla-only loading, " .. #registry
    .. " items, trinket/pill, pickups, co-op, rooms, lifecycle, localization, font fallback")
