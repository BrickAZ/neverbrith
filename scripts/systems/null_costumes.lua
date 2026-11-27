-- Stateless operations. Each presentation owns its cache and visual-state table.
local Costumes = {}

function Costumes.GetCachedId(cache, key, path, deferFailureCache)
    if cache[key] ~= nil then return cache[key] or nil end
    -- Mask publishes a failed lookup after the native call; the single-costume
    -- owners install the false sentinel first. Keep that reentry distinction.
    if not deferFailureCache then cache[key] = false end
    local resolved = false
    if Isaac and Isaac.GetCostumeIdByPath then
        local ok, id = pcall(function() return Isaac.GetCostumeIdByPath(path) end)
        if ok and type(id) == "number" and id > 0 then
            resolved = id
            cache[key] = id
        end
    end
    if deferFailureCache then cache[key] = resolved end
    return cache[key] or nil
end

function Costumes.Remove(player, id)
    if player and id and player.TryRemoveNullCostume then
        pcall(function() player:TryRemoveNullCostume(id) end)
    end
end

function Costumes.Add(player, id)
    if player and id and player.AddNullCostume then
        pcall(function() player:AddNullCostume(id) end)
    end
end

-- Update the remembered state only after the item transition returns. Native
-- add/remove failures remain swallowed by Add/Remove, as before extraction.
function Costumes.Transition(getStates, key, visualState, apply)
    if getStates()[key] == visualState then return end
    apply()
    getStates()[key] = visualState
end

return Costumes
