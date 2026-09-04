local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, message)
    if not value then error(message or "expected truthy value", 2) end
end

ModCallbacks = {
    MC_POST_PLAYER_INIT = 1,
    MC_POST_GAME_STARTED = 2,
    MC_POST_PLAYER_UPDATE = 3,
    MC_POST_PEFFECT_UPDATE = 4,
    MC_POST_NEW_ROOM = 5,
}

local DANTE_TYPE = 42
local DANTE_COSTUME = 17507
local resolvedNames = {}
local resolvedPaths = {}
Isaac = {
    GetPlayerTypeByName = function(name, tainted)
        resolvedNames[#resolvedNames + 1] = { name = name, tainted = tainted }
        return name == "Dante" and tainted == false and DANTE_TYPE or -1
    end,
    GetCostumeIdByPath = function(path)
        resolvedPaths[#resolvedPaths + 1] = path
        return path == "gfx/characters/costume_dante_hair.anm2" and DANTE_COSTUME or -1
    end,
}

local callbacks = {}
local mod = {}
function mod:AddCallback(callbackId, callbackFn)
    callbacks[callbackId] = callbacks[callbackId] or {}
    callbacks[callbackId][#callbacks[callbackId] + 1] = callbackFn
end

local function makePlayer(playerType)
    local data = {}
    local player = { playerType = playerType, addCalls = {}, removeCalls = {} }
    function player:GetPlayerType() return self.playerType end
    function player:GetData() return data end
    function player:AddNullCostume(costumeId) self.addCalls[#self.addCalls + 1] = costumeId end
    function player:TryRemoveNullCostume(costumeId) self.removeCalls[#self.removeCalls + 1] = costumeId end
    return player
end

local players = {}
local initialize = assert(dofile("dante_character.lua"), "dante_character.lua must return an initializer")
initialize(mod, {
    GetPlayers = function() return players end,
    DebugLog = function() end,
})

local api = assert(mod.DanteVisualTestAPI, "Dante visual test API must be exposed")
assertEquals(api.PlayerName, "Dante", "registered player lookup name")
assertEquals(api.CostumePath, "gfx/characters/costume_dante_hair.anm2", "costume lookup path")
assertEquals(#(callbacks[ModCallbacks.MC_POST_PLAYER_INIT] or {}), 1, "player init callback count")
assertEquals(#(callbacks[ModCallbacks.MC_POST_GAME_STARTED] or {}), 1, "game started callback count")
assertEquals(callbacks[ModCallbacks.MC_POST_PLAYER_UPDATE], nil, "Dante hair must not poll every player update")
assertEquals(callbacks[ModCallbacks.MC_POST_PEFFECT_UPDATE], nil, "Dante hair must not poll every peffect update")
assertEquals(callbacks[ModCallbacks.MC_POST_NEW_ROOM], nil, "Dante hair must not re-add on every room")

local dante = makePlayer(DANTE_TYPE)
local isaac = makePlayer(0)
callbacks[ModCallbacks.MC_POST_PLAYER_INIT][1](mod, dante)
callbacks[ModCallbacks.MC_POST_PLAYER_INIT][1](mod, isaac)
assertEquals(#dante.addCalls, 1, "Dante init applies one hair costume")
assertEquals(dante.addCalls[1], DANTE_COSTUME, "Dante init costume id")
assertEquals(#isaac.addCalls, 0, "non-Dante init remains untouched")

players = { dante, isaac }
callbacks[ModCallbacks.MC_POST_GAME_STARTED][1](mod, false)
assertEquals(#dante.addCalls, 1, "new-game sync must not duplicate the already applied costume")
assertEquals(#isaac.addCalls, 0, "new-game sync must isolate the non-Dante player")

local continuedDante = makePlayer(DANTE_TYPE)
local secondDante = makePlayer(DANTE_TYPE)
players = { continuedDante, isaac, secondDante }
callbacks[ModCallbacks.MC_POST_GAME_STARTED][1](mod, true)
assertEquals(#continuedDante.addCalls, 1, "continue reconstructs first Dante hair")
assertEquals(#secondDante.addCalls, 1, "continue reconstructs second Dante hair independently")
assertEquals(#isaac.addCalls, 0, "continue does not leak hair to another player")

api.SyncPlayer(continuedDante)
assertEquals(#continuedDante.addCalls, 1, "idempotent sync does not stack the costume")
continuedDante.playerType = 0
api.SyncPlayer(continuedDante)
assertEquals(#continuedDante.removeCalls, 1, "identity change removes the previously owned Dante hair")
assertEquals(continuedDante.removeCalls[1], DANTE_COSTUME, "identity-change removal uses the resolved costume id")

assertEquals(resolvedNames[1].name, "Dante", "Dante type must be resolved by registered name")
assertEquals(resolvedNames[1].tainted, false, "Dante type lookup must request the normal form")
assertEquals(resolvedPaths[1], "gfx/characters/costume_dante_hair.anm2", "costume id must be resolved by real resource path")
assertTruthy(#resolvedNames <= 2 and #resolvedPaths <= 2, "player type and costume path should be cached")

print("Dante separated hair lifecycle tests passed")

