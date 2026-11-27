-- Private selection ownership for Everchanging.
return function(Neverbirth, deps)
    local Store = deps.Store
    local IsValidItemId = deps.IsValidItemId
    local DebugLog = deps.DebugLog
    local EVERCHANGING = deps.ItemId
    local STYLE_REGISTRY = deps.Registry.StyleRegistry
    local emptyRegistryLogged = false
    local GetEverchangingPlayerState = deps.State.GetEverchangingPlayerState
    local GetEverchangingRuntime = deps.State.GetEverchangingRuntime
    local GetEverchangingCount = deps.State.GetEverchangingCount

    local function GetNormalTwinRole(player)
        if not player or not player.GetPlayerType or type(PlayerType) ~= "table" then return nil end
        local ok, playerType = pcall(function() return player:GetPlayerType() end)
        if not ok then return nil end
        if playerType == PlayerType.PLAYER_JACOB then return "jacob" end
        if playerType == PlayerType.PLAYER_ESAU then return "esau" end
        return nil
    end

    local function GetNormalTwinPair(player)
        local role = GetNormalTwinRole(player)
        if not role or not player.GetOtherTwin then return nil end
        local ok, other = pcall(function() return player:GetOtherTwin() end)
        if not ok or not other or other == player then return nil end
        local otherRole = GetNormalTwinRole(other)
        if role == "jacob" and otherRole == "esau" then return { jacob=player, esau=other } end
        if role == "esau" and otherRole == "jacob" then return { jacob=other, esau=player } end
        return nil
    end

    local function IsStyleEligibleForPlayer(player, style)
        if not style then return false end
        if style.eligibility == "normal_jacob_esau_pair" then
            return GetNormalTwinPair(player) ~= nil
        end
        return true
    end

    local function SelectStyle(player, currentStyleId, registry)
        registry = registry or STYLE_REGISTRY
        if type(registry) ~= "table" or #registry == 0 then
            if not emptyRegistryLogged then
                emptyRegistryLogged = true
                DebugLog("[neverbirth] Everchanging style registry is empty")
            end
            return nil
        end
        local eligible = {}
        for _, style in ipairs(registry) do
            if IsStyleEligibleForPlayer(player, style) then
                eligible[#eligible + 1] = style
            end
        end
        if #eligible == 0 then return nil end
        local candidates = {}
        for _, style in ipairs(eligible) do
            if #eligible == 1 or style.id ~= currentStyleId then
                candidates[#candidates + 1] = style
            end
        end
        if #candidates == 0 then return eligible[1] end
        if not player or not player.GetCollectibleRNG or not IsValidItemId(EVERCHANGING) then
            DebugLog("[neverbirth] Everchanging collectible RNG unavailable")
            return nil
        end
        local ok, rng = pcall(function() return player:GetCollectibleRNG(EVERCHANGING) end)
        if not ok or not rng or not rng.RandomInt then
            DebugLog("[neverbirth] Everchanging collectible RNG resolution failed")
            return nil
        end
        local rollOk, roll = pcall(function() return rng:RandomInt(#candidates) end)
        if not rollOk then
            DebugLog("[neverbirth] Everchanging collectible RNG draw failed")
            return nil
        end
        return candidates[(tonumber(roll) or 0) % #candidates + 1]
    end

    local function UpdateEverchangingSelection(player)
        local state = GetEverchangingPlayerState(player)
        local runtime = GetEverchangingRuntime(player)
        if not state or not runtime then
            return nil, nil, 0, false
        end

        local count = GetEverchangingCount(player)
        local changed = count ~= state.knownCopies
        local styleChanged = false
        if count <= 0 then
            if state.styleId ~= nil or state.knownCopies ~= 0 then
                state.styleId = nil
                state.knownCopies = 0
                Store.Save()
            end
            return state, runtime, 0, changed
        end

        local draws = math.max(0, count - state.knownCopies)
        if not state.styleId and draws == 0 then
            draws = 1
        end
        for _ = 1, draws do
            local selected = SelectStyle(player, state.styleId, STYLE_REGISTRY)
            if selected then
                styleChanged = styleChanged or state.styleId ~= selected.id
                state.styleId = selected.id
                state.rollCount = state.rollCount + 1
            end
        end
        if changed or draws > 0 then
            state.knownCopies = count
            Store.Save()
        end
        if changed or styleChanged then
            runtime.dirty = true
        end
        return state, runtime, count, changed or styleChanged
    end

    return {
        GetNormalTwinRole = GetNormalTwinRole,
        GetNormalTwinPair = GetNormalTwinPair,
        IsStyleEligibleForPlayer = IsStyleEligibleForPlayer,
        SelectStyle = SelectStyle,
        UpdateEverchangingSelection = UpdateEverchangingSelection,
    }
end
