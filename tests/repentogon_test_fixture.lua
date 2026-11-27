-- Explicit runtime prerequisite and callback enums missing in legacy fixtures.
return function(options)
    REPENTOGON = { Real = true, Version = "1.0.12a" }
    CallbackPriority = { IMPORTANT = -200, EARLY = -100, DEFAULT = 0, LATE = 100 }
    WeaponType = WeaponType or { WEAPON_BRIMSTONE = 2 }
    EffectVariant = EffectVariant or {}
    GridEntityType = GridEntityType or { GRID_ROCK=2, GRID_ROCKB=3, GRID_ROCKT=4,
        GRID_ROCK_BOMB=5, GRID_ROCK_ALT=6, GRID_SPIKES=8, GRID_SPIKES_ONOFF=9,
        GRID_TNT=12, GRID_POOP=14, GRID_ROCK_SS=22, GRID_ROCK_SPIKED=25,
        GRID_ROCK_ALT2=26, GRID_ROCK_GOLD=27 }
    ChestSubType = ChestSubType or { CHEST_OPENED=0, CHEST_CLOSED=1 }
    if not include then
        function include(name)
            return dofile(name:gsub("%.", "/") .. ".lua")
        end
    end
    if not (options and options.ExistingIncludeComplete) then
        -- These features used to be inline in main.lua. Legacy item fixtures
        -- must execute them after extraction rather than stub the new paths.
        local previousInclude = include
        function include(name)
            if name:match('^scripts[./]') then
                return dofile(name:gsub('%.', '/') .. '.lua')
            end
            return previousInclude(name)
        end
    end
    local registerMod = RegisterMod
    if registerMod then
        RegisterMod = function(...)
            local mod = registerMod(...)
            if not mod.AddPriorityCallback then
                -- Legacy unit fixtures do not run a priority dispatcher.
                -- Real ordering is covered by repentogon_damage_order_test.lua.
                function mod:AddPriorityCallback(id, _, callback, param)
                    return self:AddCallback(id, callback, param)
                end
            end
            return mod
        end
    end
    local fortuneCallbacks = {
        MC_POST_ADD_COLLECTIBLE = 1005,
        MC_PRE_ADD_COLLECTIBLE = 1004,
        MC_POST_PICKUP_COLLISION = 1239,
        MC_POST_PICKUP_INIT = 34,
        MC_POST_GLOWING_HOURGLASS_SAVE = 1300,
        MC_POST_GLOWING_HOURGLASS_LOAD = 1301,
        MC_INPUT_ACTION = 13,
        MC_EXECUTE_CMD = 22,
        MC_POST_PEFFECT_UPDATE = 4,
        MC_FAMILIAR_INIT = 6,
        MC_FAMILIAR_UPDATE = 3,
        MC_POST_FAMILIAR_FIRE_PROJECTILE = 1252,
        MC_EVALUATE_CUSTOM_CACHE = 1224,
        MC_POST_TRIGGER_COLLECTIBLE_REMOVED = 1095,
        MC_POST_TRIGGER_TRINKET_ADDED = 1096,
        MC_POST_TRIGGER_TRINKET_REMOVED = 1097,
        MC_POST_PLAYER_INIT = 9,
        MC_POST_GAME_STARTED = 15,
        MC_PRE_GAME_EXIT = 16,
        MC_PRE_MOD_UNLOAD = 73,
        MC_POST_NEW_ROOM = 19,
        MC_POST_WEAPON_FIRE = 1105,
        MC_PRE_PLAYER_TAKE_DMG = 1008,
        MC_PRE_PLAYER_UPDATE = 1160,
        MC_PRE_BOMB_UPDATE = 1163,
        MC_PRE_ENTITY_SPAWN = 24,
        MC_POST_BOMB_INIT = 57,
        MC_POST_BOMB_UPDATE = 58,
        MC_POST_EFFECT_INIT = 54,
        MC_POST_TEAR_INIT = 39,
        MC_PRE_TRIGGER_PLAYER_DEATH = 1050,
        MC_POST_ENTITY_TAKE_DMG = 1006,
        MC_POST_NPC_DEATH = 29,
        MC_POST_ENTITY_KILL = 68,
        MC_NPC_UPDATE = 0,
    }
    -- Legacy tests use synthetic IDs (for example POST_ADD=13). New native
    -- enums must not alias those IDs and dispatch a different callback shape.
    local occupied, names = {}, {}
    for name,id in pairs(ModCallbacks or {}) do occupied[id] = name end
    for name in pairs(fortuneCallbacks) do names[#names + 1] = name end
    table.sort(names)
    for _,name in ipairs(names) do
        if ModCallbacks and ModCallbacks[name] == nil then
            local id = fortuneCallbacks[name]
            while occupied[id] do id = id + 2000 end
            ModCallbacks[name], occupied[id] = id, name
        end
    end
    -- Ordinary full-main tests do not dispatch damage; the dedicated integration
    -- test separately executes the actual installed implementation.
    _RunEntityTakeDmgCallback = function() error("fixture dispatcher must not be used") end
end
