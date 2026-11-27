-- Registration stays in main.lua at the original interleaved positions.
return function(Neverbirth, dependencies)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local Items = { UtilityKnife = assert(dependencies.ItemId) }
    local GetPlayers = assert(dependencies.GetPlayers)
    local GetCurrentRunSeed = assert(dependencies.GetCurrentRunSeed)
    local Store = assert(dependencies.Store)

local DAMAGE_UP = 1
local running, disposed = true, false
-- Weak player-instance keys distinguish startup receipts from an old same-seed
-- player. Values are plain counts; neither map keeps an engine player alive.
local startedPlayers = setmetatable({}, { __mode = "k" })
local startupReceipts = setmetatable({}, { __mode = "k" })

local function RefreshDamage(player)
    if player and player.AddCacheFlags then player:AddCacheFlags(CacheFlag.CACHE_DAMAGE) end
    if player and player.EvaluateItems then player:EvaluateItems() end
end

local getRunData = include("scripts.runtime.run_section")(Store, GetCurrentRunSeed,
    function() return { runSeed = GetCurrentRunSeed(), playerCounts = {} } end, { "playerCounts" })
function Neverbirth:GetUtilityKnifeData()
    return getRunData()
end

function Neverbirth:EvaluateUtilityKnife(player, cacheFlag)
    if cacheFlag ~= CacheFlag.CACHE_DAMAGE then
        return
    end

    if not player or not player.GetCollectibleNum then
        return
    end

    local count = player:GetCollectibleNum(Items.UtilityKnife)
    if count <= 0 then
        return
    end

    player.Damage = player.Damage + DAMAGE_UP * count
end
function callbackInstallers.Neverbirth_EvaluateUtilityKnife()
    return Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateUtilityKnife)
end

local function FindUtilityKnifePickupPlayer(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        local valueType = type(value)
        if valueType == "table" or valueType == "userdata" then
            local hasToPlayer, toPlayer = pcall(function()
                return value.ToPlayer
            end)
            if hasToPlayer and type(toPlayer) == "function" then
                local ok, player = pcall(function()
                    return value:ToPlayer()
                end)
                if ok and player then
                    return player
                end
            end

            local hasCollectibleAccessor, collectibleAccessor = pcall(function()
                return value.GetCollectibleNum
            end)
            if hasCollectibleAccessor and type(collectibleAccessor) == "function" then
                return value
            end
        end
    end

    return nil
end

function Neverbirth:GrantUtilityKnifeBrokenHeart(...)
    if not running or disposed then return end
    local player = FindUtilityKnifePickupPlayer(...)
    if not player or not player.AddBrokenHearts then
        return
    end

    local data = self:GetUtilityKnifeData()
    local key = tostring(player.InitSeed or "")
    local count = 0
    if player.GetCollectibleNum then
        count = tonumber(player:GetCollectibleNum(Items.UtilityKnife)) or 0
    end

    if count > 0 then
        data.playerCounts[key] = math.max(tonumber(data.playerCounts[key]) or 0, count)
        if not startedPlayers[player] then
            startupReceipts[player] = math.max(startupReceipts[player] or 0, count)
        end
    end
    player:AddBrokenHearts(1)
    Store.Save()
end
function callbackInstallers.Neverbirth_GrantUtilityKnifeBrokenHeart()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, Neverbirth.GrantUtilityKnifeBrokenHeart, Items.UtilityKnife)
end

function Neverbirth:TrackUtilityKnifeCopies()
    if not running or disposed then return end
    local data = self:GetUtilityKnifeData()

    for _, player in ipairs(GetPlayers()) do
        if player and player.GetCollectibleNum then
            local key = tostring(player.InitSeed or "")
            local currentCount = tonumber(player:GetCollectibleNum(Items.UtilityKnife)) or 0
            local previousCount = tonumber(data.playerCounts[key]) or 0

            if currentCount > previousCount then
                local gained = currentCount - previousCount
                if player.AddBrokenHearts then
                    player:AddBrokenHearts(gained)
                end
                data.playerCounts[key] = currentCount
                Store.Save()
            elseif currentCount < previousCount then
                data.playerCounts[key] = currentCount
                Store.Save()
            end
            if currentCount ~= previousCount then RefreshDamage(player) end
        end
    end
end
function callbackInstallers.Neverbirth_TrackUtilityKnifeCopies()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.TrackUtilityKnifeCopies)
end

local resetRun = include("scripts.runtime.new_run_reset")({ Reset = { function()
    -- A start seed is not a run identity: same-seed restarts are fresh runs.
    local data = Store.Get()
    data.runSeed, data.playerCounts = GetCurrentRunSeed(), {}
    for _, player in ipairs(GetPlayers()) do
        local receipt = startupReceipts[player]
        if receipt and player.GetCollectibleNum then
            data.playerCounts[tostring(player.InitSeed or "")] = math.min(receipt,
                math.max(0, tonumber(player:GetCollectibleNum(Items.UtilityKnife)) or 0))
        end
    end
    Store.Save()
end } })
function Neverbirth:StartUtilityKnifeRun(isContinued)
    if disposed then return end
    running = true
    resetRun(self, isContinued)
    startupReceipts = setmetatable({}, { __mode = "k" })
    startedPlayers = setmetatable({}, { __mode = "k" })
    for _, player in ipairs(GetPlayers()) do
        startedPlayers[player] = true
        RefreshDamage(player)
    end
end
function callbackInstallers.StartRun()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.StartUtilityKnifeRun)
end

function Neverbirth:ExitUtilityKnife()
    running = false
    startupReceipts = setmetatable({}, { __mode = "k" })
    startedPlayers = setmetatable({}, { __mode = "k" })
end
function callbackInstallers.Exit()
    if ModCallbacks.MC_PRE_GAME_EXIT then
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, Neverbirth.ExitUtilityKnife)
    end
end

function Neverbirth:UnloadUtilityKnife(unloaded)
    if unloaded ~= nil and unloaded ~= self then return end
    running, disposed = false, true
    startupReceipts = setmetatable({}, { __mode = "k" })
    startedPlayers = setmetatable({}, { __mode = "k" })
end
function callbackInstallers.Unload()
    if ModCallbacks.MC_PRE_MOD_UNLOAD then
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, Neverbirth.UnloadUtilityKnife)
    end
end

return {
    InstallCache = function() callbackInstallers.Neverbirth_EvaluateUtilityKnife() end,
    InstallUpdate = function()
        callbackInstallers.Neverbirth_TrackUtilityKnifeCopies()
        callbackInstallers.StartRun()
        callbackInstallers.Exit()
        callbackInstallers.Unload()
    end,
    InstallPickup = function() callbackInstallers.Neverbirth_GrantUtilityKnifeBrokenHeart() end,
}
end
