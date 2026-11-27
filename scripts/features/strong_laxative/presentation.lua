-- Owns appearance and costume caches; gameplay timers remain with players.
return function(Neverbirth, dependencies)
    local private = dependencies.Private or {}
    local CombatSource = include("scripts.systems.combat_source")
    local Costumes = include("scripts.systems.null_costumes")
    local StrongLaxativeConfig = dependencies.Config
    local StrongLaxativeId = dependencies.ItemId
    local strongLaxativeCostumeStates = {}
    local costumeOwners = {}
    local costumeCache = {}

    -- GetData is stable across Lua wrappers for the same native body, and a new
    -- body gets a different table even when its gameplay player key is reused.
    -- Only use the table as a local identity: do not write mod fields into it.
    local function GetCostumeOwner(player)
        if player.GetData then
            local ok, data = pcall(function() return player:GetData() end)
            if ok and type(data) == "table" then return data end
        end
        return player -- entity-like callers without the native GetData surface
    end

    function Neverbirth.StrongLaxative.GetCostumeId()
        return Costumes.GetCachedId(costumeCache, "id", StrongLaxativeConfig.CostumePath)
    end

    function Neverbirth.StrongLaxative.RemoveCostume(player, costumeId)
        Costumes.Remove(player, costumeId)
    end

    function private.AddCostume(player, costumeId)
        Costumes.Add(player, costumeId)
    end

    function Neverbirth.StrongLaxative.ApplyCostume(player, active)
        if not player then return end
        local key = GetCostumeOwner(player)
        costumeOwners[key] = active and player or nil
        local visualState = active and "active" or "none"
        Costumes.Transition(function() return strongLaxativeCostumeStates end, key, visualState, function()
            local costumeId = Neverbirth.StrongLaxative.GetCostumeId()
            if costumeId then
                Neverbirth.StrongLaxative.RemoveCostume(player, costumeId)
                if active then private.AddCostume(player, costumeId) end
            end
        end)
    end

    local function InstallPickupCallback()
      function Neverbirth:RefreshStrongLaxativeOnPickup(...)
        if private.IsRuntimeActive and not private.IsRuntimeActive() then return end
        local player = nil
        for index = 1, select("#", ...) do
            local value = select(index, ...)
            if type(value) == "table" and value.ToPlayer then
                local maybePlayer = CombatSource.TryPlayer(value)
                if maybePlayer then
                    player = maybePlayer
                    break
                end
            end
        end

        if player then
            Neverbirth.StrongLaxative.ApplyCostume(player, true)
        end
      end
        if ModCallbacks.MC_POST_ADD_COLLECTIBLE then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, Neverbirth.RefreshStrongLaxativeOnPickup, StrongLaxativeId)
        end
    end

    local function ResetRuntime()
        local previous = costumeOwners
        costumeOwners, strongLaxativeCostumeStates = {}, {}
        for _, player in pairs(previous) do
            pcall(function()
                if not player.Exists or player:Exists() then
                    Neverbirth.StrongLaxative.RemoveCostume(player, Neverbirth.StrongLaxative.GetCostumeId())
                end
            end)
        end
        costumeCache = {}
    end
    return { InstallPickupCallback = InstallPickupCallback, ResetRuntime = ResetRuntime }
end
