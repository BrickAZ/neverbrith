-- Private inventory ownership; constructed once by the item entry.
return function(Neverbirth, deps)
    local ITEM_ID = deps.State.ITEM_ID
    local SLOT_TRINKET_ID = deps.State.SLOT_TRINKET_ID
    local HEALTH_CAP = deps.State.HEALTH_CAP
    local KEY_CAP = deps.State.KEY_CAP
    local BOMB_CAP = deps.State.BOMB_CAP
    local COIN_CAP = deps.State.COIN_CAP
    local COIN_DEAL_CAP = deps.State.COIN_DEAL_CAP
    local SLOT_PRIMARY = deps.State.SLOT_PRIMARY
    local SLOT_SECONDARY = deps.State.SLOT_SECONDARY
    local PICKUP_TRINKET = deps.State.PICKUP_TRINKET
    local ENTITY_PICKUP = deps.State.ENTITY_PICKUP
    local IDS = deps.State.IDS
    local BANNED_COLLECTIBLES = deps.State.BANNED_COLLECTIBLES
    local PROTECTED_COLLECTIBLES = deps.State.PROTECTED_COLLECTIBLES
    local DebugLog = deps.State.DebugLog
    local GetPlayerKey = deps.State.GetPlayerKey

    local function GetCollectibleConfig(itemId)
        if not Isaac or not Isaac.GetItemConfig then return nil end
        local itemConfig = Isaac.GetItemConfig()
        if not itemConfig or not itemConfig.GetCollectible then return nil end
        return itemConfig:GetCollectible(itemId)
    end

    local function GetCollectibleCount(player, itemId)
        if not player or not player.GetCollectibleNum then return 0 end
        return player:GetCollectibleNum(itemId, true) or player:GetCollectibleNum(itemId) or 0
    end

    local function HasCollectible(player, itemId)
        if not player then return false end
        if player.HasCollectible then return player:HasCollectible(itemId, true) end
        return GetCollectibleCount(player, itemId) > 0
    end

    local function GetTrinketMultiplier(player, trinketId)
        if not player or not player.GetTrinketMultiplier then return 0 end
        return player:GetTrinketMultiplier(trinketId) or 0
    end

    local function RequestCaches(player)
        if not player then return end
        local flags =
            ((CacheFlag and CacheFlag.CACHE_DAMAGE) or 1)
            | ((CacheFlag and CacheFlag.CACHE_FIREDELAY) or 2)
            | ((CacheFlag and CacheFlag.CACHE_SHOTSPEED) or 4)
            | ((CacheFlag and CacheFlag.CACHE_FLYING) or 128)
            | ((CacheFlag and CacheFlag.CACHE_LUCK) or 1024)
        if player.AddCacheFlags then player:AddCacheFlags(flags) end
        if player.EvaluateItems then player:EvaluateItems() end
    end

    local function RemoveAllCopies(player, itemId)
        if not player or not player.RemoveCollectible then return false end
        local changed = false
        local count = GetCollectibleCount(player, itemId)
        for _ = 1, math.min(count, 64) do
            player:RemoveCollectible(itemId)
            changed = true
        end
        return changed
    end

    local function RemoveBannedTrinket(player)
        if not player or not player.TryRemoveTrinket then return false end
        local changed = false
        local count = math.min(GetTrinketMultiplier(player, IDS.MonkeyPaw), 64)
        for _ = 1, count do
            if player:TryRemoveTrinket(IDS.MonkeyPaw) then changed = true end
        end
        return changed
    end

    local function DropHeldTrinkets(player)
        if not player or not player.GetTrinket or not player.TryRemoveTrinket then return false end
        local changed = false
        local held = { player:GetTrinket(0) or 0, player:GetTrinket(1) or 0 }
        for slot = 0, 1 do
            local trinketId = held[slot + 1]
            if trinketId > 0 and trinketId ~= SLOT_TRINKET_ID and player:TryRemoveTrinket(trinketId) then
                changed = true
                if Isaac and Isaac.Spawn and player.Position then
                    Isaac.Spawn(ENTITY_PICKUP, PICKUP_TRINKET, trinketId, player.Position,
                        (Vector and Vector.Zero) or Vector(0, 0), player)
                end
            end
        end
        return changed
    end

    local function EnsureSlotTrinket(player)
        if SLOT_TRINKET_ID <= 0 or not player or not player.GetTrinket or not player.AddTrinket then return false end
        if player:GetTrinket(0) == SLOT_TRINKET_ID or player:GetTrinket(1) == SLOT_TRINKET_ID then return false end
        player:AddTrinket(SLOT_TRINKET_ID, false)
        return player:GetTrinket(0) == SLOT_TRINKET_ID or player:GetTrinket(1) == SLOT_TRINKET_ID
    end

    local function RemoveBannedSources(player)
        local changed = false
        for itemId in pairs(BANNED_COLLECTIBLES) do
            if RemoveAllCopies(player, itemId) then changed = true end
        end
        if RemoveBannedTrinket(player) then changed = true end
        return changed
    end

    local function ProtectCompatibleCollectibles(player, state)
        local changed = false
        for _, itemId in ipairs(PROTECTED_COLLECTIBLES) do
            local key = tostring(itemId)
            local current = GetCollectibleCount(player, itemId)
            local protected = tonumber(state.protectedCounts[key]) or 0
            if current > protected then
                state.protectedCounts[key] = current
                changed = true
            elseif current < protected and player.AddCollectible then
                for _ = current + 1, protected do player:AddCollectible(itemId, 0, false) end
                changed = true
            end
        end
        return changed
    end

    local function EnsureRingInPrimary(player, state)
        if not state or not state.active or not player or not player.GetActiveItem then return false end
        if player:GetActiveItem(SLOT_PRIMARY) == ITEM_ID then return false end
        if player.AddCollectible then
            player:AddCollectible(ITEM_ID, 0, false, SLOT_PRIMARY)
            DebugLog("restored protected primary active for player " .. GetPlayerKey(player))
            return true
        end
        return false
    end

    local function EnsureNativeSecondary(player, state)
        local itemId = state and tonumber(state.nativeSecondary) or 0
        if itemId <= 0 or not player or not player.GetActiveItem then return false end
        if player:GetActiveItem(SLOT_SECONDARY) == itemId then return false end
        if player.AddCollectible then
            player:AddCollectible(itemId, 0, false, SLOT_SECONDARY)
            DebugLog("restored retained native secondary for player " .. GetPlayerKey(player))
            return true
        end
        return false
    end

    local function GetTotalHealthCapacity(player)
        if not player then return 0 end
        local maxHearts = player.GetMaxHearts and player:GetMaxHearts() or 0
        local soulHearts = player.GetSoulHearts and player:GetSoulHearts() or 0
        local boneHearts = player.GetBoneHearts and player:GetBoneHearts() or 0
        local eternalHearts = player.GetEternalHearts and player:GetEternalHearts() or 0
        return math.max(0, maxHearts) + math.max(0, soulHearts)
            + math.max(0, boneHearts) * 2 + math.max(0, eternalHearts)
    end

    local function ClampHealth(player)
        local overflow = GetTotalHealthCapacity(player) - HEALTH_CAP
        if overflow <= 0 then return false end
        local changed = false

        if overflow > 0 and player.GetEternalHearts and player.AddEternalHearts then
            local remove = math.min(overflow, math.max(0, player:GetEternalHearts() or 0))
            if remove > 0 then player:AddEternalHearts(-remove); overflow = overflow - remove; changed = true end
        end
        if overflow > 0 and player.GetSoulHearts and player.AddSoulHearts then
            local remove = math.min(overflow, math.max(0, player:GetSoulHearts() or 0))
            if remove > 0 then player:AddSoulHearts(-remove); overflow = overflow - remove; changed = true end
        end
        if overflow > 0 and player.GetBoneHearts and player.AddBoneHearts then
            local available = math.max(0, player:GetBoneHearts() or 0)
            local remove = math.min(available, math.ceil(overflow / 2))
            if remove > 0 then player:AddBoneHearts(-remove); overflow = math.max(0, overflow - remove * 2); changed = true end
        end
        if overflow > 0 and player.GetMaxHearts and player.AddMaxHearts then
            local remove = math.min(overflow, math.max(0, player:GetMaxHearts() or 0))
            if remove > 0 then player:AddMaxHearts(-remove, false); changed = true end
        end
        return changed
    end

    local function IsKeeper(player)
        if not player or not player.GetPlayerType then return false end
        local playerType = player:GetPlayerType()
        return playerType == ((PlayerType and PlayerType.PLAYER_KEEPER) or 14)
            or playerType == ((PlayerType and PlayerType.PLAYER_KEEPER_B) or 33)
    end

    local function GetCoinCap(player)
        if IsKeeper(player) then return nil end
        if HasCollectible(player, IDS.PoundOfFlesh)
            or GetTrinketMultiplier(player, IDS.KeepersBargain) > 0 then
            return COIN_DEAL_CAP
        end
        return COIN_CAP
    end

    local function ClampResources(player)
        local changed = false
        if player.GetNumKeys and player.AddKeys then
            local current = player:GetNumKeys()
            if current > KEY_CAP then player:AddKeys(KEY_CAP - current); changed = true end
        end
        if player.GetNumBombs and player.AddBombs then
            local current = player:GetNumBombs()
            if current > BOMB_CAP then player:AddBombs(BOMB_CAP - current); changed = true end
        end
        local cap = GetCoinCap(player)
        if cap and player.GetNumCoins and player.AddCoins then
            local current = player:GetNumCoins()
            if current > cap then player:AddCoins(cap - current); changed = true end
        end
        return changed
    end

    local function AddSecondaryCharge(player, state)
        local itemId = tonumber(state.nativeSecondary) or 0
        if itemId <= 0 or not player.GetActiveItem or player:GetActiveItem(SLOT_SECONDARY) ~= itemId then return false end
        if type(player.AddActiveCharge) ~= "function" then return false end
        -- Force preserves a fixed +1 for timed/special actives; native capacity still applies.
        local added = player:AddActiveCharge(1, SLOT_SECONDARY, true, false, true)
        return (tonumber(added) or 0) > 0
    end

    return {
        GetCollectibleConfig = GetCollectibleConfig,
        GetCollectibleCount = GetCollectibleCount,
        HasCollectible = HasCollectible,
        GetTrinketMultiplier = GetTrinketMultiplier,
        RequestCaches = RequestCaches,
        RemoveAllCopies = RemoveAllCopies,
        RemoveBannedTrinket = RemoveBannedTrinket,
        DropHeldTrinkets = DropHeldTrinkets,
        EnsureSlotTrinket = EnsureSlotTrinket,
        RemoveBannedSources = RemoveBannedSources,
        ProtectCompatibleCollectibles = ProtectCompatibleCollectibles,
        EnsureRingInPrimary = EnsureRingInPrimary,
        EnsureNativeSecondary = EnsureNativeSecondary,
        GetTotalHealthCapacity = GetTotalHealthCapacity,
        ClampHealth = ClampHealth,
        IsKeeper = IsKeeper,
        GetCoinCap = GetCoinCap,
        ClampResources = ClampResources,
        AddSecondaryCharge = AddSecondaryCharge,
    }
end
