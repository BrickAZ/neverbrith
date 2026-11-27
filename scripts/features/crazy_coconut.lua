-- Owns this feature's rules, state and callbacks. Dependencies are provided by main.lua.
return function(Neverbirth, dependencies)
local Store = assert(dependencies.Store)
local Items = assert(dependencies.Items)
local GetPlayers = assert(dependencies.GetPlayers)
local GetCurrentRunSeed = assert(dependencies.GetCurrentRunSeed)
local IsValidItemId = assert(dependencies.IsValidItemId)
local DebugLog = assert(dependencies.Log)
local PICKUP_ENTITY = (EntityType and EntityType.ENTITY_PICKUP) or 5
local COLLECTIBLE_VARIANT = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
Neverbirth.CrazyCoconutPickupSources = Neverbirth.CrazyCoconutPickupSources or {}
local runtime = { running = true, disposed = false }

local Attributes = include('scripts.features.crazy_coconut.attributes')(Neverbirth, dependencies)
local ledgerDependencies = {}
for key, value in pairs(dependencies) do ledgerDependencies[key] = value end
ledgerDependencies.RefreshCache = Attributes.RefreshCache
local Ledger = include('scripts.features.crazy_coconut.ledger')(Neverbirth, ledgerDependencies)
local Acquisition = include('scripts.features.crazy_coconut.acquisition')(Neverbirth, {
    Store = Store, Items = Items, GetPlayers = GetPlayers,
    IsValidItemId = IsValidItemId, Log = DebugLog, Ledger = Ledger,
    Runtime = runtime, RefreshCache = Attributes.RefreshCache,
})

return {
InstallGameStarted = function()
    local resetRun = include("scripts.runtime.new_run_reset")({ Reset = { function()
        Ledger.ResetRun()
        Neverbirth.CrazyCoconutPickupSources = {}
    end } })
    local function OnCrazyCoconutGameStarted(mod, isContinued)
        if runtime.disposed then return end
        runtime.running = true
        resetRun(mod, isContinued)
        -- Both restored holders and players who lost their old bonus need a fresh cache.
        for _, player in ipairs(GetPlayers()) do Attributes.RefreshCache(player) end
    end
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, OnCrazyCoconutGameStarted)

    local function OnCrazyCoconutExit()
        runtime.running = false
        for key in pairs(Neverbirth.CrazyCoconutPickupSources) do Neverbirth.CrazyCoconutPickupSources[key] = nil end
        -- Pending settlement is plain saved data; it resumes on Continue.
    end
    if ModCallbacks.MC_PRE_GAME_EXIT then
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, OnCrazyCoconutExit)
    end

    local function OnCrazyCoconutUnload(_, unloaded)
        if unloaded ~= nil and unloaded ~= Neverbirth then return end
        OnCrazyCoconutExit()
        runtime.disposed = true
    end
    if ModCallbacks.MC_PRE_MOD_UNLOAD then
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, OnCrazyCoconutUnload)
    end
end,
InstallEvaluateCrazyCoconut = function() Attributes.InstallEvaluate()
 end,
InstallTrackCrazyCoconutCopies = function() Acquisition.InstallTrackCopies()
 end,
InstallHandleCrazyCoconutCollectiblePickup = function() Acquisition.InstallPickup(COLLECTIBLE_VARIANT)
 end,
}

end
