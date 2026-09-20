-- Explicit runtime prerequisite and callback enums missing in legacy fixtures.
return function()
    REPENTOGON = { Real = true, Version = "1.0.12a" }
    CallbackPriority = { IMPORTANT = -200, EARLY = -100, DEFAULT = 0, LATE = 100 }
    WeaponType = WeaponType or { WEAPON_BRIMSTONE = 2 }
    EffectVariant = EffectVariant or {}
    if not include then
        function include(name)
            return dofile(name:gsub("%.", "/") .. ".lua")
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
        MC_EVALUATE_CUSTOM_CACHE = 1224,
        MC_POST_TRIGGER_COLLECTIBLE_REMOVED = 1095,
        MC_POST_TRIGGER_TRINKET_ADDED = 1096,
        MC_POST_TRIGGER_TRINKET_REMOVED = 1097,
        MC_POST_PLAYER_INIT = 9,
        MC_POST_GAME_STARTED = 15,
        MC_PRE_GAME_EXIT = 16,
        MC_POST_NEW_ROOM = 19,
        MC_POST_WEAPON_FIRE = 1105,
        MC_PRE_PLAYER_TAKE_DMG = 1008,
        MC_POST_ENTITY_TAKE_DMG = 1006,
        MC_POST_NPC_DEATH = 29,
        MC_POST_ENTITY_KILL = 68,
        MC_NPC_UPDATE = 0,
    }
    for name, id in pairs(fortuneCallbacks) do
        if ModCallbacks and ModCallbacks[name] == nil then ModCallbacks[name] = id end
    end
    -- Ordinary full-main tests do not dispatch damage; the dedicated integration
    -- test separately executes the actual installed implementation.
    _RunEntityTakeDmgCallback = function() error("fixture dispatcher must not be used") end
end
