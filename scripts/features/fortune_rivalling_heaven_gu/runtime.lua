-- Owns handlers and native bindings; the entry schedules installation.
return function(Neverbirth, dependencies)
local private = assert(dependencies.Private)
-- Native bindings are declared here; the entry chooses their installation phase.
local callbackInstallers = {}
local GetPlayers = assert(dependencies.GetPlayers)
local DebugLog = assert(dependencies.Log)
local runtimeActive = true
    local disposed = false
local cacheTag = "neverbrith_fortune_required_luck"

function Neverbirth:InvalidateFortuneLuck(player)
    if not runtimeActive then return end
    local state = self.FortuneRivallingHeavenGu
    if not player then
        for _, owner in ipairs(GetPlayers()) do self:InvalidateFortuneLuck(owner) end
        return
    end
    if not player.GetData or (player.Exists and not player:Exists()) then return end
    local key = player:GetData()
    if not state.players[key] then
        state.players[key] = { owner = player, collectible = {}, trinket = {} }
    end
    state.players[key].dirty = true
end
function callbackInstallers.InstallInvalidateFortuneLuck()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.InvalidateFortuneLuck)
end

function Neverbirth:ResetFortuneLuckRuntime()
    if disposed then return end
    -- Inventory-derived caches never persist; Continue rebuilds from live owners.
    for _, runtime in pairs(self.FortuneRivallingHeavenGu.players) do runtime.owner = nil end
    self.FortuneRivallingHeavenGu.players = {}
    runtimeActive = true
    self:InvalidateFortuneLuck()
end
function callbackInstallers.InstallResetFortuneLuckRuntime()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetFortuneLuckRuntime)
end

local function ClearRuntimeForExit()
    if not runtimeActive then return end
    runtimeActive = false
    local previous = Neverbirth.FortuneRivallingHeavenGu.players
    Neverbirth.FortuneRivallingHeavenGu.players = {}
    for _, runtime in pairs(previous) do
        local player = runtime.owner
        runtime.owner = nil
        if player then
            pcall(function()
                if player.Exists and not player:Exists() then return end
                player:AddCustomCacheTag(cacheTag, true)
                player:AddCacheFlags(CacheFlag.CACHE_LUCK)
                player:EvaluateItems()
            end)
        end
    end
end
local function InstallTeardown()
    if ModCallbacks.MC_PRE_GAME_EXIT then
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
            ClearRuntimeForExit()
        end)
    end
    if ModCallbacks.MC_PRE_MOD_UNLOAD then
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, function(_, mod)
            if mod ~= Neverbirth then return end
            disposed = true
            ClearRuntimeForExit()
        end)
    end
end

function Neverbirth:OnFortunePlayerInit(player)
    self:InvalidateFortuneLuck(player)
end
function callbackInstallers.InstallOnFortunePlayerInit()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, Neverbirth.OnFortunePlayerInit)
end

function Neverbirth:OnFortuneCollectibleAdded(itemId, charge, firstTime, slot, varData, player)
    self:OnFortuneCollectibleRemoved(player, itemId)
end
function callbackInstallers.InstallOnFortuneCollectibleAdded()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, Neverbirth.OnFortuneCollectibleAdded)
end

function Neverbirth:OnFortuneCollectibleRemoved(player, itemId)
    if player and (private.luckDependencies.collectible[itemId]
        or private.PlayerHasFortuneRivallingHeavenGu(self, player)) then
        self:InvalidateFortuneLuck(player)
    end
end
function callbackInstallers.InstallOnFortuneCollectibleRemoved()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED, Neverbirth.OnFortuneCollectibleRemoved)
end

function Neverbirth:OnFortuneTrinketChanged(player)
    self:InvalidateFortuneLuck(player)
end
function callbackInstallers.InstallOnFortuneTrinketAdded()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_TRIGGER_TRINKET_ADDED, Neverbirth.OnFortuneTrinketChanged)
end
function callbackInstallers.InstallOnFortuneTrinketRemoved()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_TRIGGER_TRINKET_REMOVED, Neverbirth.OnFortuneTrinketChanged)
end

function Neverbirth:EvaluateFortuneCustomCache(player, tag, value)
    if not runtimeActive then return value end
    return math.max(tonumber(value) or 0, private.GetFortuneRivallingHeavenGuRequiredLuck(self, player))
end
function callbackInstallers.InstallEvaluateFortuneCustomCache()
    return Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CUSTOM_CACHE, Neverbirth.EvaluateFortuneCustomCache,
        cacheTag)
end

function Neverbirth:EvaluateFortuneRivallingHeavenGu(player, cacheFlag)
    if not runtimeActive then return end
    if not CacheFlag or cacheFlag ~= CacheFlag.CACHE_LUCK or not private.PlayerHasFortuneRivallingHeavenGu(self, player) then
        return
    end
    -- CACHE_LUCK 开始时的 Luck 是原缓存链结果：只补差额，不保存层数，也不累计。
    player.Luck = math.max(tonumber(player.Luck) or 0,
        player:GetCustomCacheValue(cacheTag))
end
function callbackInstallers.InstallEvaluateFortuneRivallingHeavenGu()
    return Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateFortuneRivallingHeavenGu)
end

function Neverbirth:TrackFortuneRivallingHeavenGuLuckSources()
    if not runtimeActive then return end
    local state = self.FortuneRivallingHeavenGu
    for _, runtime in pairs(state.players) do runtime.seen = false end
    for _, player in ipairs(GetPlayers()) do
        if player.GetData and (not player.Exists or player:Exists()) then
            local key = player:GetData()
            if not state.players[key] then self:InvalidateFortuneLuck(player) end
            local runtime = state.players[key]
            runtime.seen = true
            for kind, ids in pairs(private.luckDependencies) do
                for id in pairs(ids) do
                    local count = kind == "collectible"
                        and math.max(0, tonumber(player:GetCollectibleNum(id)) or 0)
                        or private.GetFortuneTrinketMultiplier(self, player, id)
                    if runtime[kind][id] ~= count then
                        runtime[kind][id] = count
                        runtime.dirty = true
                    end
                end
            end
            if runtime.dirty and not runtime.flushing then
                runtime.dirty = false
                runtime.flushing = true
                -- 1.0.12a normal caches precede custom caches: two-phase flush.
                local ok = pcall(function()
                    player:AddCustomCacheTag(cacheTag, true)
                    player:AddCacheFlags(CacheFlag.CACHE_LUCK)
                    player:EvaluateItems()
                end)
                runtime.flushing = false
                if not ok then
                    runtime.dirty = true
                    -- Bound repeated native failures to one log per runtime owner.
                    if not runtime.flushErrorReported then
                        runtime.flushErrorReported = true
                        DebugLog("[Neverbirth] 鸿运缓存刷新失败；将在后续更新重试。")
                    end
                end
            end
        end
    end
    for key, runtime in pairs(state.players) do
        if not runtime.seen then state.players[key] = nil end
    end
end
function callbackInstallers.InstallTrackFortuneRivallingHeavenGuLuckSources()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.TrackFortuneRivallingHeavenGuLuckSources)
end

return { InstallEvaluateFortuneRivallingHeavenGu = callbackInstallers.InstallEvaluateFortuneRivallingHeavenGu, InstallTrackFortuneRivallingHeavenGuLuckSources = callbackInstallers.InstallTrackFortuneRivallingHeavenGuLuckSources, InstallEvaluateFortuneCustomCache = callbackInstallers.InstallEvaluateFortuneCustomCache, InstallResetFortuneLuckRuntime = function() callbackInstallers.InstallResetFortuneLuckRuntime(); InstallTeardown() end, InstallInvalidateFortuneLuck = callbackInstallers.InstallInvalidateFortuneLuck, InstallOnFortunePlayerInit = callbackInstallers.InstallOnFortunePlayerInit, InstallOnFortuneCollectibleAdded = callbackInstallers.InstallOnFortuneCollectibleAdded, InstallOnFortuneCollectibleRemoved = callbackInstallers.InstallOnFortuneCollectibleRemoved, InstallOnFortuneTrinketAdded = callbackInstallers.InstallOnFortuneTrinketAdded, InstallOnFortuneTrinketRemoved = callbackInstallers.InstallOnFortuneTrinketRemoved }
end
