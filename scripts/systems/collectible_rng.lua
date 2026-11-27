-- Stateless RNG mechanics. Item guards and fallback selection remain explicit.
local Rolls = {}
function Rolls.Get(player, itemId, requiredMethod)
    if player and player.GetCollectibleRNG then
        local ok, rng = pcall(function() return player:GetCollectibleRNG(itemId) end)
        if ok and rng and (not requiredMethod or rng[requiredMethod]) then return rng end
    end
    return nil
end
function Rolls.IntOrMath(rng, max)
    if rng then
        local ok, value = pcall(function() return rng:RandomInt(max) end)
        if ok and value ~= nil then return math.max(0, math.min(max - 1, tonumber(value) or 0)) end
    end
    return math.random(max) - 1
end
function Rolls.IntOrRoomSeed(rng, max, getRoom)
    if rng and rng.RandomInt then
        local ok, value = pcall(function() return rng:RandomInt(max) end)
        if ok and type(value) == "number" then
            return math.max(0, math.min(max - 1, math.floor(value)))
        end
    end
    local room = getRoom()
    local seed = room and room.GetSpawnSeed and room:GetSpawnSeed() or 0
    return math.max(0, math.floor(seed) % max)
end
return Rolls
