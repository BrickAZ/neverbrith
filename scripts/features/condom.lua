-- Owns this feature's rules, state and callbacks. Dependencies are provided by main.lua.
return function(Neverbirth, dependencies)
local Store = assert(dependencies.Store)
local Items = assert(dependencies.Items)
local GetCurrentRunSeed = assert(dependencies.GetCurrentRunSeed)

local Presentation = include('scripts.features.condom.presentation')(Neverbirth, dependencies)
local privateDependencies = {}
for key, value in pairs(dependencies) do privateDependencies[key] = value end
privateDependencies.ShowFeedback = Presentation.ShowFeedback
local Bans = include('scripts.features.condom.bans')(Neverbirth, privateDependencies)
privateDependencies.IsBannedCollectible = Bans.IsBannedCollectible
local Replacement = include('scripts.features.condom.replacement')(Neverbirth, privateDependencies)

return {
InstallGameStarted = function()
    local resetRun = include("scripts.runtime.new_run_reset")({ Reset = { Bans.ResetRun } })
    local function OnCondomGameStarted(mod, isContinued)
        resetRun(mod, isContinued)
    end
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, OnCondomGameStarted)
end,
InstallPickupInit = function() Replacement.InstallPickupInit() end,
InstallPickupMorph = function() Replacement.InstallPickupMorph() end,
InstallUseCondom = function() Bans.InstallUseCondom()
 end,
}

end
