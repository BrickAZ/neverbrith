-- Private presentation ownership for Everchanging.
return function(Neverbirth, deps)
    local DebugLog = deps.DebugLog
    local STYLE_REGISTRY = deps.Registry.StyleRegistry
    local GetEverchangingRuntime = deps.State.GetEverchangingRuntime
    local IsStyleEligibleForPlayer = deps.Selection.IsStyleEligibleForPlayer
    local ResolveStyleResources = deps.Resources.ResolveStyleResources
    local IsCompatiblePlayer = deps.PlayerAnm2.IsCompatiblePlayer
    local ApplyPlayerAnm2 = deps.PlayerAnm2.ApplyPlayerAnm2
    local RestorePlayerAnm2 = deps.PlayerAnm2.RestorePlayerAnm2
    local PlayerAnm2Matches = deps.PlayerAnm2.PlayerAnm2Matches

    local function ClearEverchangingStyle(player)
        local runtime = GetEverchangingRuntime(player)
        if not runtime then
            return false
        end
        local changedAny = RestorePlayerAnm2(player, runtime)
        for _, costume in ipairs(runtime.appliedCostumeIds) do
            local costumeId = type(costume) == "table" and costume.id or costume
            if type(costumeId) == "number"
                and player.TryRemoveNullCostume then
                local ok = pcall(function()
                    player:TryRemoveNullCostume(costumeId)
                end)
                changedAny = changedAny or ok
            end
        end
        runtime.appliedStyleId = nil
        runtime.appliedRole = nil
        runtime.appliedCostumeIds = {}
        runtime.failedStyleId = nil
        runtime.dirty = false
        return changedAny
    end

    local function CostumeListsMatch(left, right)
        if #left ~= #right then
            return false
        end
        for index = 1, #left do
            local leftId = type(left[index]) == "table" and left[index].id or left[index]
            local rightId = type(right[index]) == "table" and right[index].id or right[index]
            if leftId ~= rightId then
                return false
            end
        end
        return true
    end

    local function ApplyEverchangingStyle(player, styleId, role)
        local runtime = GetEverchangingRuntime(player)
        if not runtime then return false end
        local style = styleId and STYLE_REGISTRY.byId[styleId] or nil
        if not style or not IsStyleEligibleForPlayer(player, style) then
            ClearEverchangingStyle(player)
            return false
        end
        if not IsCompatiblePlayer(player, runtime) then
            ClearEverchangingStyle(player)
            runtime.failedStyleId = styleId
            runtime.dirty = false
            return false
        end
        local resources = ResolveStyleResources(style, role)
        if not resources then
            ClearEverchangingStyle(player)
            runtime.failedStyleId = styleId
            runtime.dirty = false
            return false
        end
        local styleStateMatches = runtime.appliedStyleId == styleId
            and runtime.appliedRole == role
            and runtime.appliedPlayerAnm2 == resources.playerAnm2
            and CostumeListsMatch(runtime.appliedCostumeIds, resources.costumes)
        if styleStateMatches and PlayerAnm2Matches(player, resources.playerAnm2) ~= false then
            runtime.failedStyleId = nil
            runtime.dirty = false
            return true
        end
        if styleStateMatches and resources.playerAnm2 then
            runtime.appliedPlayerAnm2 = nil
            if ApplyPlayerAnm2(player, runtime, resources.playerAnm2) then
                if not runtime.anm2DriftLogged then
                    runtime.anm2DriftLogged = true
                    DebugLog("[neverbirth] Everchanging repaired a player ANM2 reset for style "
                        .. tostring(styleId))
                end
                runtime.failedStyleId = nil
                runtime.dirty = false
                return true
            end
            runtime.failedStyleId = styleId
            runtime.dirty = false
            return false
        end
        ClearEverchangingStyle(player)
        if resources.playerAnm2 and not ApplyPlayerAnm2(player, runtime, resources.playerAnm2) then
            runtime.failedStyleId = styleId
            runtime.dirty = false
            return false
        end
        local applied = {}
        for _, costume in ipairs(resources.costumes) do
            if not player.AddNullCostume then break end
            local ok = pcall(function() player:AddNullCostume(costume.id) end)
            if not ok then break end
            applied[#applied + 1] = costume
        end
        if #applied ~= #resources.costumes then
            runtime.appliedCostumeIds = applied
            ClearEverchangingStyle(player)
            runtime.failedStyleId = styleId
            DebugLog("[neverbirth] Everchanging failed to apply style " .. tostring(styleId)
                .. " role " .. tostring(role or "regular"))
            return false
        end
        runtime.appliedStyleId = styleId
        runtime.appliedRole = role
        runtime.appliedCostumeIds = applied
        runtime.failedStyleId = nil
        runtime.dirty = false
        return true
    end

    local function SyncEverchangingVisual(player, state, runtime, count)
        if not state or not runtime then
            return false
        end
        if count <= 0 then
            if runtime.appliedStyleId ~= nil
                or runtime.appliedRole ~= nil
                or #runtime.appliedCostumeIds > 0
                or runtime.appliedPlayerAnm2 ~= nil
                or runtime.failedStyleId ~= nil then
                ClearEverchangingStyle(player)
            else
                runtime.dirty = false
            end
            return false
        end

        local playerAnm2Drifted = false
        local currentStyle = state.styleId and STYLE_REGISTRY.byId[state.styleId] or nil
        local fullResource = currentStyle
            and not currentStyle.pairRoles
            and currentStyle.resources
            and currentStyle.resources.full
            or nil
        if runtime.appliedStyleId == state.styleId
            and runtime.appliedRole == nil
            and runtime.appliedPlayerAnm2
            and fullResource
            and fullResource.anm2 then
            playerAnm2Drifted = PlayerAnm2Matches(player, fullResource.anm2) == false
        end
        if runtime.dirty
            or playerAnm2Drifted
            or (runtime.appliedStyleId ~= state.styleId
                and runtime.failedStyleId ~= state.styleId) then
            ApplyEverchangingStyle(player, state.styleId, nil)
        end
        return playerAnm2Drifted
    end

    local function ApplyEverchangingPair(pair, style)
        local jacobRuntime = GetEverchangingRuntime(pair.jacob)
        local esauRuntime = GetEverchangingRuntime(pair.esau)
        local jacobResources = ResolveStyleResources(style, "jacob")
        local esauResources = ResolveStyleResources(style, "esau")
        if not jacobRuntime or not esauRuntime or not jacobResources or not esauResources
            or not IsCompatiblePlayer(pair.jacob, jacobRuntime)
            or not IsCompatiblePlayer(pair.esau, esauRuntime) then
            ClearEverchangingStyle(pair.jacob)
            ClearEverchangingStyle(pair.esau)
            return false
        end

        local jacobOk = ApplyEverchangingStyle(pair.jacob, style.id, "jacob")
        local esauOk = ApplyEverchangingStyle(pair.esau, style.id, "esau")
        if not jacobOk or not esauOk then
            ClearEverchangingStyle(pair.jacob)
            ClearEverchangingStyle(pair.esau)
            return false
        end
        return true
    end

    return {
        ClearEverchangingStyle = ClearEverchangingStyle,
        CostumeListsMatch = CostumeListsMatch,
        ApplyEverchangingStyle = ApplyEverchangingStyle,
        SyncEverchangingVisual = SyncEverchangingVisual,
        ApplyEverchangingPair = ApplyEverchangingPair,
    }
end
