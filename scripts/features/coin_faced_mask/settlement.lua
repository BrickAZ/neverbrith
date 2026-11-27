return function(Neverbirth, dependencies)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local CombatSource = include("scripts.systems.combat_source")
    local GetFolkRoomKey = dependencies.World.GetFolkRoomKey
    local PlayerHasCollectible = dependencies.World.PlayerHasCollectible
    local GetPlayerCoins = dependencies.World.GetPlayerCoins
    local AddPlayerCoins = dependencies.World.AddPlayerCoins
    local IsVulnerableEnemy = dependencies.World.IsVulnerableEnemy
    local CoinFacedMaskId = dependencies.CoinFacedMaskId
    local MASK_REQUIRED_COINS = dependencies.RequiredCoins
    local MASK_CONFUSION_DURATION = 90
    local MASK_LUCK_PENALTY = -2
    local COIN_MASK_VISUAL_NONE = "none"
    local COIN_MASK_VISUAL_BROKEN = "broken"
    local ApplyCoinFacedMaskCostume = dependencies.Presentation.Apply
    local coinFacedMaskSettling = 0

    local function RefreshMaskLuck(player)
        if player and player.AddCacheFlags and CacheFlag then
            player:AddCacheFlags(CacheFlag.CACHE_LUCK)
            if player.EvaluateItems then
                player:EvaluateItems()
            end
        end
    end

    local function DisturbMaskEnemies(player)
        if not Isaac.GetRoomEntities then
            return
        end

        local ref = EntityRef(player)
        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            if IsVulnerableEnemy(entity) and entity.AddConfusion then
                pcall(function()
                    entity:AddConfusion(ref, MASK_CONFUSION_DURATION, false)
                end)
            end
        end
    end

    local function HasCoinFacedMaskDamageFlag(flags, flag)
        return type(flags) == "number" and type(flag) == "number" and (flags & flag) ~= 0
    end

    local function IsIgnoredCoinFacedMaskDamage(flags)
        local ignoredFlags = {
            DamageFlag and DamageFlag.DAMAGE_FAKE,
            DamageFlag and DamageFlag.DAMAGE_IV_BAG,
            DamageFlag and DamageFlag.DAMAGE_DEVIL,
            DamageFlag and DamageFlag.DAMAGE_CURSED_DOOR,
            DamageFlag and DamageFlag.DAMAGE_NOKILL,
        }

        for _, flag in ipairs(ignoredFlags) do
            if HasCoinFacedMaskDamageFlag(flags, flag) then
                return true
            end
        end

        return false
    end

    local function GetCoinFacedMaskDamageSourceEntity(source)
        return CombatSource.Entity(source)
    end

    local function IsCoinFacedMaskMonsterDamage(source)
        local sourceEntity = GetCoinFacedMaskDamageSourceEntity(source)
        if not sourceEntity then
            return true
        end

        if CombatSource.TryPlayer(sourceEntity) then return false end

        if IsVulnerableEnemy(sourceEntity) then
            return true
        end

        return sourceEntity.Type ~= (EntityType and EntityType.ENTITY_PLAYER or 1)
    end

    function Neverbirth:HandleCoinFacedMaskDamage(entity, amount, flags, source)
        if not dependencies.Runtime.running or dependencies.Runtime.disposed then return nil end
        local player = entity and entity.ToPlayer and entity:ToPlayer()
        if coinFacedMaskSettling > 0 or not player or (tonumber(amount) or 0) <= 0 or not PlayerHasCollectible(player, CoinFacedMaskId) or IsIgnoredCoinFacedMaskDamage(flags) or not IsCoinFacedMaskMonsterDamage(source) then
            return nil
        end

        if not dependencies.State.Consume(player) then
            return nil
        end

        if GetPlayerCoins(player) >= MASK_REQUIRED_COINS then
            AddPlayerCoins(player, -MASK_REQUIRED_COINS)
            ApplyCoinFacedMaskCostume(player, COIN_MASK_VISUAL_NONE)
            return false
        end

        dependencies.State.Break(player, MASK_LUCK_PENALTY)
        ApplyCoinFacedMaskCostume(player, COIN_MASK_VISUAL_BROKEN)
        RefreshMaskLuck(player)
        DisturbMaskEnemies(player)
        return nil
    end
    function callbackInstallers.Neverbirth_HandleCoinFacedMaskDamage()
        return Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.HandleCoinFacedMaskDamage, EntityType.ENTITY_PLAYER)
    end

    function Neverbirth:EvaluateCoinFacedMask(player, cacheFlag)
        if not dependencies.Runtime.running or dependencies.Runtime.disposed then return end
        if not CacheFlag or cacheFlag ~= CacheFlag.CACHE_LUCK or not PlayerHasCollectible(player, CoinFacedMaskId) then
            return
        end

        local state = dependencies.State.Find(player)
        local penalty = tonumber(state and state.roomKey == GetFolkRoomKey() and state.luckPenalty) or 0
        if penalty ~= 0 then
            player.Luck = player.Luck + penalty
        end
    end
    function callbackInstallers.Neverbirth_EvaluateCoinFacedMask()
        return Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateCoinFacedMask)
    end

    local function InstallCallbacks()
        callbackInstallers.Neverbirth_HandleCoinFacedMaskDamage()
        callbackInstallers.Neverbirth_EvaluateCoinFacedMask()
    end

    return { RefreshLuck = RefreshMaskLuck, DisturbEnemies = DisturbMaskEnemies,
        InstallCallbacks = InstallCallbacks }
end
