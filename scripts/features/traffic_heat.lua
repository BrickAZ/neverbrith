-- Owns permanent heat stacks, deferred cache refresh and its cache callback.
return function(Neverbirth, dependencies)
-- Keep native bindings beside handlers; invoke at their original installation phase.
local callbackInstallers = {}
local AddTears = include("scripts.systems.fire_rate")
local Store, state = assert(dependencies.Store), assert(dependencies.RefreshRuntime)
local GetFrame = assert(dependencies.GetFrame)
local GetPlayers, playerKey, call, log = dependencies.GetPlayers, dependencies.PlayerKey, dependencies.Call, dependencies.Log
local FIRE_DELAY = (CacheFlag and CacheFlag.CACHE_FIREDELAY) or 16
    local function addTears(maxFireDelay, heatCount)
        local delay = tonumber(maxFireDelay) or 0
        local count = math.max(0, math.floor(tonumber(heatCount) or 0))
        if count == 0 then return delay end
        return AddTears(delay, 0.5 * count)
    end

    local function persistent()

        Store.Replace(type(Store.Get()) == "table" and Store.Get() or {})
        local value = Store.Get()
        value.heatByPlayer = type(value.heatByPlayer) == "table" and value.heatByPlayer or {}
        return value
    end

    local function queueHeatRefresh(player)
        if not player then return end
        state.pendingHeatRefreshes[playerKey(player)] = { player = player, due = (GetFrame() or 0) + 1 }
    end

    local function processHeatRefreshes()
        for key, value in pairs(state.pendingHeatRefreshes) do
            if (GetFrame() or 0) >= (value.due or 0) then
                local player = value.player
                local exists, existsOk = call(player, "Exists")
                if player and (not existsOk or exists == true) then
                    if player.AddCacheFlags then player:AddCacheFlags(FIRE_DELAY) end
                    if player.EvaluateItems then player:EvaluateItems() end
                end
                state.pendingHeatRefreshes[key] = nil
            end
        end
    end

    local function queueOwnedHeatRefreshes()
        local save = persistent()
        for _, player in ipairs(GetPlayers()) do
            local count = math.max(0, math.floor(tonumber(save.heatByPlayer[playerKey(player)]) or 0))
            if count > 0 then queueHeatRefresh(player) end
        end
    end

    local function resetRun()
        local save = persistent()
        local previous = save.heatByPlayer
        save.heatByPlayer = {}
        state.pendingHeatRefreshes = {}
        Store.Save()
        -- Initial player caches can already contain the previous run's bonus.
        for _, player in ipairs(GetPlayers()) do
            if (tonumber(previous[playerKey(player)]) or 0) > 0 then
                if player.AddCacheFlags then player:AddCacheFlags(FIRE_DELAY) end
                if player.EvaluateItems then player:EvaluateItems() end
            end
        end
    end

    local function addHeat(player)
        local save = persistent(); local key = playerKey(player)
        save.heatByPlayer[key] = math.max(0, math.floor(tonumber(save.heatByPlayer[key]) or 0)) + 1
        log("heat player=" .. key .. " stacks=" .. save.heatByPlayer[key])
        Store.Save()
        queueHeatRefresh(player)
    end

    local function evaluateHeat(_, player, cacheFlag)
        if cacheFlag ~= FIRE_DELAY or not player then return end
        local count = math.max(0, math.floor(tonumber(persistent().heatByPlayer[playerKey(player)]) or 0))
        if count > 0 then player.MaxFireDelay = addTears(player.MaxFireDelay, count) end
    end
    function callbackInstallers.evaluateHeat()
        return Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, evaluateHeat)
    end

return { ResetRun = resetRun, ResetTransient = function() state.pendingHeatRefreshes = {} end, AddTears = addTears, GetData = persistent, Add = addHeat, ProcessRefreshes = processHeatRefreshes, QueueOwnedRefreshes = queueOwnedHeatRefreshes, Evaluate = evaluateHeat, InstallCallback = function() callbackInstallers.evaluateHeat() end }
end
