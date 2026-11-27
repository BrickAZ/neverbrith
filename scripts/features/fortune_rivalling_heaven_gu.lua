-- Owns this feature's rules, state and callbacks. Dependencies are provided by main.lua.
return function(Neverbirth, dependencies)
local private = {}
local provided = dependencies
dependencies = {}
for key, value in pairs(provided) do dependencies[key] = value end
dependencies.Private = private
local Items = assert(dependencies.Items)
local GetPlayers = assert(dependencies.GetPlayers)
local IsValidItemId = assert(dependencies.IsValidItemId)
local DebugLog = assert(dependencies.Log)
assert(type(dependencies.GetNeedletickLuckCap) == "function",
    "FortuneRivallingHeavenGu requires GetNeedletickLuckCap")
-- 鸿运齐天蛊：本表是截图审查表，也是运行时注册的唯一来源。
-- 旧版本条目保留审查记录，但普通 Repentance 不会激活它们。
Neverbirth.FortuneRivallingHeavenGu = Neverbirth.FortuneRivallingHeavenGu or {}
Neverbirth.FortuneRivallingHeavenGu.luckCaps = { collectible = {}, trinket = {} }
Neverbirth.FortuneRivallingHeavenGu.auditRows = {}
private.luckDependencies = { collectible = {}, trinket = {} }
Neverbirth.FortuneRivallingHeavenGu.players = {}

include('scripts.features.fortune_rivalling_heaven_gu.audit')(Neverbirth, dependencies)
include('scripts.features.fortune_rivalling_heaven_gu.registry')(Neverbirth, dependencies)
local Runtime = include('scripts.features.fortune_rivalling_heaven_gu.runtime')(Neverbirth, dependencies)

Neverbirth:RegisterVerifiedFortuneLuckCaps()

return {
InstallEvaluateFortuneRivallingHeavenGu = function() Runtime.InstallEvaluateFortuneRivallingHeavenGu()
 end,
InstallTrackFortuneRivallingHeavenGuLuckSources = function() Runtime.InstallTrackFortuneRivallingHeavenGuLuckSources()
 end,
InstallEvaluateFortuneCustomCache = function() Runtime.InstallEvaluateFortuneCustomCache()
 end,
InstallResetFortuneLuckRuntime = function() Runtime.InstallResetFortuneLuckRuntime()
 end,
InstallInvalidateFortuneLuck = function() Runtime.InstallInvalidateFortuneLuck()
 end,
InstallOnFortunePlayerInit = function() Runtime.InstallOnFortunePlayerInit()
 end,
InstallOnFortuneCollectibleAdded = function() Runtime.InstallOnFortuneCollectibleAdded()
 end,
InstallOnFortuneCollectibleRemoved = function() Runtime.InstallOnFortuneCollectibleRemoved()
 end,
InstallOnFortuneTrinketAdded = function() Runtime.InstallOnFortuneTrinketAdded()
 end,
InstallOnFortuneTrinketRemoved = function() Runtime.InstallOnFortuneTrinketRemoved()
 end,
}

end
