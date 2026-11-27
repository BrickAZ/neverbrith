local Installation = dofile("scripts/runtime/feature_installation.lua")
function include(name) return dofile(name:gsub('%.', '/') .. '.lua') end
local install = dofile("scripts/features/good_girl_of_babylon.lua")
local names = {
    "GetGoodGirlState", "PlayerHasGoodGirl", "GoodGirlHasFullRedHearts", "IsGoodGirlPresentable",
    "GetGoodGirlCostumeId", "RemoveGoodGirlCostume", "AddGoodGirlCostume", "ApplyGoodGirlCostume",
    "GetGoodGirlItemPool", "GetGoodGirlItemConfig", "GetGoodGirlRewardSeed", "IsGoodGirlKnownCardSubtype",
    "AddGoodGirlCardCandidate", "CollectGoodGirlCardCandidates", "GetGoodGirlRewardCardSubtype",
    "RefreshGoodGirlCache", "IsGoodGirlRedHeartDamage", "FearGoodGirlEnemies",
    "CharmGoodGirlRoomEnemies", "SpawnGoodGirlReward",
}

ModCallbacks = {
    MC_EVALUATE_CACHE = 1, MC_ENTITY_TAKE_DMG = 2, MC_POST_NEW_ROOM = 3, MC_POST_UPDATE = 4,
}
EntityType = { ENTITY_PLAYER = 1 }
local mod, callbacks = {}, {}
function mod:AddCallback(event, fn) callbacks[fn] = event end
function mod:RemoveCallback(event, fn)
    assert(callbacks[fn] == event)
    callbacks[fn] = nil
end

local prior = {}
for index, name in ipairs(names) do
    if index % 2 == 0 then prior[name] = function() return index end end
    rawset(_G, name, prior[name])
end

local service = Installation.Create(mod)
service.Run("GoodGirl", function()
    install(mod, {
        World = {
            GetFolkPlayerKey = function(player) return tostring(player.InitSeed) end,
            GetFolkRoomKey = function() return "1:0:1" end,
            PlayerHasCollectible = function(_, id) return id == 97 end,
        },
        GoodGirlOfBabylonId = 97,
        GetPlayers = function() return {} end,
        PublishGlobal = service.PublishGlobal,
        VisualEffects = {},
    })
end)
for _, name in ipairs(names) do
    assert(type(rawget(_G, name)) == "function" and rawget(_G, name) ~= prior[name], name)
end
local player = { InitSeed = 12, GetMaxHearts = function() return 2 end, GetHearts = function() return 2 end }
local state = GetGoodGirlState(player)
assert(state == mod.GoodGirl.states["12"] and state.roomKey == "1:0:1")
assert(IsGoodGirlPresentable(player, state))
assert(next(callbacks) ~= nil)

local ok, err = pcall(service.Run, "LaterFailure", function() error("injected later failure") end)
assert(not ok and tostring(err):find("injected later failure", 1, true))
assert(next(callbacks) == nil)
for _, name in ipairs(names) do assert(rawget(_G, name) == prior[name], name) end
assert(mod.GoodGirl == nil)
print("Good Girl compatibility exports: 20 names, successful calls, restoration after later failure")
