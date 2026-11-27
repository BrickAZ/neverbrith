-- Private resources ownership for Everchanging.
return function(Neverbirth, deps)
    local DebugLog = deps.DebugLog
    local Costumes = include("scripts.systems.null_costumes")
    local costumeIdCache, resourceFailureLogged = {}, {}

    local function GetCostumeId(costumePath)
        if costumeIdCache[costumePath] ~= nil then
            return costumeIdCache[costumePath] or nil
        end

        local costumeId = Costumes.GetCachedId(costumeIdCache, costumePath, costumePath, true)
        -- A native lookup can reenter unload and replace this instance's cache.
        -- Publish to the current table after it returns, as the original owner did.
        costumeIdCache[costumePath] = costumeId or false
        if not costumeId and not resourceFailureLogged[costumePath] then
            resourceFailureLogged[costumePath] = true
            DebugLog("[neverbirth] Everchanging missing costume resource: " .. tostring(costumePath))
        end
        return costumeId
    end

    local function ResolveStyleResources(style, role)
        if type(style) ~= "table" then return nil end
        local resourceSet = style
        if style.pairRoles then
            resourceSet = role and style.pairRoles[role] or nil
            if not resourceSet then
                DebugLog("[neverbirth] Everchanging style " .. tostring(style.id)
                    .. " missing paired role " .. tostring(role))
                return nil
            end
        end
        local resolved = { playerAnm2 = nil, costumes = {} }
        for _, slot in ipairs(resourceSet.slots or {}) do
            local resource = resourceSet.resources and resourceSet.resources[slot]
            if slot == "full" then
                local anm2 = resource and resource.anm2
                if type(anm2) ~= "string" or anm2 == "" then return nil end
                resolved.playerAnm2 = anm2
            else
                local costumePath = resource and resource.costume
                local costumeId = costumePath and GetCostumeId(costumePath) or nil
                if not costumeId then
                    DebugLog("[neverbirth] Everchanging style " .. tostring(style.id)
                        .. " role " .. tostring(role or "regular")
                        .. " failed at slot " .. tostring(slot)
                        .. " path " .. tostring(costumePath))
                    return nil
                end
                resolved.costumes[#resolved.costumes + 1] = {
                    id = costumeId,
                    path = costumePath,
                    slot = slot,
                }
            end
        end
        return resolved
    end

    local function ResolveStyleCostumes(style, role)
        local resolved = ResolveStyleResources(style, role)
        return resolved and resolved.costumes or nil
    end

    local function ClearCaches()
        costumeIdCache, resourceFailureLogged = {}, {}
    end

    return {
        GetCostumeId = GetCostumeId,
        ResolveStyleResources = ResolveStyleResources,
        ResolveStyleCostumes = ResolveStyleCostumes,
        ClearCaches = ClearCaches,
    }
end
