-- Owns handlers and native bindings; the entry schedules installation.
return function(Neverbirth, dependencies)
-- Native bindings are declared here; the entry chooses their installation phase.
local callbackInstallers = {}
local Items = assert(dependencies.Items)
local IsValidItemId = assert(dependencies.IsValidItemId)
local DAMAGE_PER_LAYER = 3

local function RefreshCache(player)
    if not player or not CacheFlag or not CacheFlag.CACHE_DAMAGE then
        return
    end

    if player.AddCacheFlags then
        player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
    end

    if player.EvaluateItems then
        player:EvaluateItems()
    end
end

function Neverbirth:EvaluateCrazyCoconut(player, cacheFlag)
    if cacheFlag ~= CacheFlag.CACHE_DAMAGE then
        return
    end

    if not player or not player.GetCollectibleNum or not IsValidItemId(Items.CrazyCoconut) then
        return
    end

    if (tonumber(player:GetCollectibleNum(Items.CrazyCoconut)) or 0) <= 0 then
        return
    end

    local data = self:GetCrazyCoconutData()
    local key = tostring(player.InitSeed or "")
    local layers = math.max(0, tonumber(data.players[key]) or 0)
    if layers > 0 then
        player.Damage = player.Damage + DAMAGE_PER_LAYER * layers
    end
end
function callbackInstallers.InstallEvaluate()
    return Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateCrazyCoconut)
end

function Neverbirth:GetCrazyCoconutNaturalDamage(player, data, key)
    local displayedDamage = tonumber(player and player.Damage) or 0
    local layers = math.max(0, tonumber(data and data.players and data.players[key]) or 0)
    return displayedDamage - DAMAGE_PER_LAYER * layers
end

return { InstallEvaluate = callbackInstallers.InstallEvaluate, RefreshCache = RefreshCache }
end
