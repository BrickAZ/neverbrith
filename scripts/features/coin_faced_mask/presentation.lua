-- Costume cache is presentation-owned; it never queries or changes the wallet.
return function(Neverbirth, dependencies)
    local Costumes = include("scripts.systems.null_costumes")
    local GetFolkPlayerKey = dependencies.GetPlayerKey
    local COIN_MASK_COSTUME_PATHS = {
        "gfx/characters/costume_coin_faced_mask.anm2",
    }
    local COIN_MASK_BROKEN_COSTUME_PATHS = {
        "gfx/characters/costume_coin_faced_mask_broken.anm2",
    }
    local COIN_MASK_VISUAL_NONE = "none"
    local COIN_MASK_VISUAL_ACTIVE = "active"
    local COIN_MASK_VISUAL_BROKEN = "broken"
    local coinFacedMaskCostumeStates = {}
    local coinFacedMaskCostumeIds = {}

    local function GetCoinMaskCostumeId(path)
        if not Isaac or not Isaac.GetCostumeIdByPath then return nil end
        if coinFacedMaskCostumeIds[path] ~= nil then return coinFacedMaskCostumeIds[path] end
        return Costumes.GetCachedId(coinFacedMaskCostumeIds, path, path, true)
    end

    local function GetFirstCoinMaskCostumeId(paths)
        for _, path in ipairs(paths or {}) do
            local costumeId = GetCoinMaskCostumeId(path)
            if costumeId then
                return costumeId
            end
        end
        return nil
    end

    local function TryRemoveCoinMaskCostume(player, costumeId)
        Costumes.Remove(player, costumeId)
    end

    local function TryAddCoinMaskCostume(player, costumeId)
        Costumes.Add(player, costumeId)
    end

    local function ApplyCoinFacedMaskCostume(player, visualState)
        if not player then return end
        local key = GetFolkPlayerKey(player)
        visualState = visualState or COIN_MASK_VISUAL_NONE
        Costumes.Transition(function() return coinFacedMaskCostumeStates end, key, visualState, function()
            local activeCostume = GetFirstCoinMaskCostumeId(COIN_MASK_COSTUME_PATHS)
            local brokenCostume = GetFirstCoinMaskCostumeId(COIN_MASK_BROKEN_COSTUME_PATHS)
            if activeCostume then TryRemoveCoinMaskCostume(player, activeCostume) end
            if brokenCostume then TryRemoveCoinMaskCostume(player, brokenCostume) end
            if visualState == COIN_MASK_VISUAL_ACTIVE then
                TryAddCoinMaskCostume(player, activeCostume)
            elseif visualState == COIN_MASK_VISUAL_BROKEN then
                TryAddCoinMaskCostume(player, brokenCostume)
            end
        end)
    end

    local function GetCoinFacedMaskVisualState(state)
        if state and state.active then
            return COIN_MASK_VISUAL_ACTIVE
        end
        if state and (tonumber(state.luckPenalty) or 0) ~= 0 then
            return COIN_MASK_VISUAL_BROKEN
        end
        return COIN_MASK_VISUAL_NONE
    end

    local function ClearPlayerCostume(player)
        ApplyCoinFacedMaskCostume(player, COIN_MASK_VISUAL_NONE)
    end

    local function ResetRuntime()
        coinFacedMaskCostumeStates = {}
    end
    return { GetVisualState = GetCoinFacedMaskVisualState, Apply = ApplyCoinFacedMaskCostume, ClearPlayerCostume = ClearPlayerCostume,
        ResetRuntime = ResetRuntime }
end
