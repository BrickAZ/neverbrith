-- Preserve the public factory path for the game and standalone Lua consumers.
if include then return include("scripts.features.memory_disorder") end
return require("scripts.features.memory_disorder")
