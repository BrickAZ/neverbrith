-- Coordinates item owners and preserves the original installation phases.
return function(Neverbirth, dependencies)
    -- Native bindings are declared here; the entry chooses their installation phase.
    local callbackInstallers = {}
    local VisualEffects = assert(dependencies.VisualEffects)
    local GetFolkPlayerKey = dependencies.World.GetFolkPlayerKey
    local GetFolkRandomInt = dependencies.World.GetFolkRandomInt
    local IsVulnerableEnemy = dependencies.World.IsVulnerableEnemy
    local GoodGirlOfBabylonId = dependencies.GoodGirlOfBabylonId
    local GOOD_GIRL_TEARS_BONUS = 0.6
    local GOOD_GIRL_LUCK_BONUS = 2
    local GOOD_GIRL_BROKEN_LUCK_PENALTY = -2
    local GOOD_GIRL_ECHO_DAMAGE_BONUS = 1.2
    local GOOD_GIRL_ECHO_SPEED_BONUS = 0.15
    local GOOD_GIRL_FEAR_RADIUS = 120
    local GOOD_GIRL_FEAR_DURATION = 2 * 30
    local GOOD_GIRL_CHARM_CHANCE = 15
    local GOOD_GIRL_CHARM_DURATION = 90
    local State = dependencies.State
    local GetGoodGirlState = State.GetGoodGirlState
    local PlayerHasGoodGirl = State.PlayerHasGoodGirl
    local IsGoodGirlPresentable = State.IsGoodGirlPresentable
    local ApplyGoodGirlCostume = dependencies.Presentation.ApplyGoodGirlCostume

    local function RefreshGoodGirlCache(player)
        if not player or not player.AddCacheFlags or not CacheFlag then
            return
        end

        local flags = 0
        if CacheFlag.CACHE_FIREDELAY then flags = flags | CacheFlag.CACHE_FIREDELAY end
        if CacheFlag.CACHE_LUCK then flags = flags | CacheFlag.CACHE_LUCK end
        if CacheFlag.CACHE_DAMAGE then flags = flags | CacheFlag.CACHE_DAMAGE end
        if CacheFlag.CACHE_SPEED then flags = flags | CacheFlag.CACHE_SPEED end
        if flags ~= 0 then
            local state = State.Find(player)
            if state and PlayerHasGoodGirl(player) then
                -- Explicit damage/room refreshes already reconcile this condition.
                State.ObservePresentable(state, IsGoodGirlPresentable(player, state))
            end
            player:AddCacheFlags(flags)
            if player.EvaluateItems then
                player:EvaluateItems()
            end
        end
    end

    local function IsGoodGirlRedHeartDamage(player, amount, flags)
        if (tonumber(amount) or 0) <= 0 then
            return false
        end
        if flags and DamageFlag and DamageFlag.DAMAGE_FAKE and (flags & DamageFlag.DAMAGE_FAKE) ~= 0 then
            return false
        end
        if flags and DamageFlag and DamageFlag.DAMAGE_IV_BAG and (flags & DamageFlag.DAMAGE_IV_BAG) ~= 0 then
            return false
        end
        if flags and DamageFlag and DamageFlag.DAMAGE_RED_HEARTS and (flags & DamageFlag.DAMAGE_RED_HEARTS) ~= 0 then
            return true
        end

        local soulHearts = 0
        if player and player.GetSoulHearts then
            soulHearts = tonumber(player:GetSoulHearts()) or 0
        end
        local redHearts = 0
        if player and player.GetHearts then
            redHearts = tonumber(player:GetHearts()) or 0
        end

        -- MC_ENTITY_TAKE_DMG fires before health changes. Without an explicit red
        -- heart flag, we only treat the hit as red damage when no soul/black layer
        -- is available to absorb it.
        return soulHearts <= 0 and redHearts > 0
    end

    local function FearGoodGirlEnemies(player)
        if not Isaac.GetRoomEntities then
            return
        end

        local origin = player and player.Position or Vector(320, 280)
        local ref = EntityRef(player)
        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            if IsVulnerableEnemy(entity) and entity.Position and (entity.Position - origin):Length() <= GOOD_GIRL_FEAR_RADIUS and entity.AddFear then
                pcall(function()
                    entity:AddFear(ref, GOOD_GIRL_FEAR_DURATION)
                end)
            end
        end
    end

    local function CharmGoodGirlRoomEnemies(player)
        if not Isaac.GetRoomEntities or not IsGoodGirlPresentable(player, GetGoodGirlState(player)) then
            return
        end

        local ref = EntityRef(player)
        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            if IsVulnerableEnemy(entity) then
                local data = entity.GetData and entity:GetData() or nil
                local key = "NeverbirthGoodGirlCharmChecked" .. tostring(GetFolkPlayerKey(player))
                if not data or data[key] ~= true then
                    if data then
                        data[key] = true
                    end
                    if GetFolkRandomInt(player, GoodGirlOfBabylonId, 100) < GOOD_GIRL_CHARM_CHANCE then
                        local charmed = false
                        if entity.AddCharmed then
                            charmed = pcall(function()
                                entity:AddCharmed(ref, GOOD_GIRL_CHARM_DURATION)
                            end)
                        elseif entity.AddConfusion then
                            charmed = pcall(function()
                                entity:AddConfusion(ref, GOOD_GIRL_CHARM_DURATION, false)
                            end)
                        elseif entity.AddEntityFlags and EntityFlag and EntityFlag.FLAG_CHARM then
                            entity:AddEntityFlags(EntityFlag.FLAG_CHARM)
                            charmed = true
                        end
                        if charmed then
                            VisualEffects:Spawn("GoodGirlCharm", entity.Position or player.Position or Vector(320, 280), player)
                        end
                    end
                end
            end
        end
    end

    function Neverbirth:EvaluateGoodGirlOfBabylon(player, cacheFlag)
        if not dependencies.Runtime.running or dependencies.Runtime.disposed then return end
        if not PlayerHasGoodGirl(player) then
            return
        end

        local state = GetGoodGirlState(player)
        local presentable = IsGoodGirlPresentable(player, state)

        if cacheFlag == CacheFlag.CACHE_FIREDELAY and presentable then
            player.MaxFireDelay = player.MaxFireDelay - GOOD_GIRL_TEARS_BONUS
        elseif cacheFlag == CacheFlag.CACHE_LUCK then
            if presentable then
                player.Luck = player.Luck + GOOD_GIRL_LUCK_BONUS
            end
            if state.broken then
                player.Luck = player.Luck + GOOD_GIRL_BROKEN_LUCK_PENALTY
            end
        elseif cacheFlag == CacheFlag.CACHE_DAMAGE and (tonumber(state.echoFrames) or 0) > 0 then
            player.Damage = player.Damage + GOOD_GIRL_ECHO_DAMAGE_BONUS
        elseif cacheFlag == CacheFlag.CACHE_SPEED and (tonumber(state.echoFrames) or 0) > 0 then
            player.MoveSpeed = player.MoveSpeed + GOOD_GIRL_ECHO_SPEED_BONUS
        end
    end
    function callbackInstallers.InstallEvaluate()
        return Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateGoodGirlOfBabylon)
    end

    function Neverbirth:HandleGoodGirlOfBabylonDamage(entity, amount, flags)
        if not dependencies.Runtime.running or dependencies.Runtime.disposed then return nil end
        local player = entity and entity.ToPlayer and entity:ToPlayer()
        if not player or not PlayerHasGoodGirl(player) then
            return nil
        end

        local state = GetGoodGirlState(player)
        if not IsGoodGirlPresentable(player, state) or not IsGoodGirlRedHeartDamage(player, amount, flags) then
            return nil
        end

        State.Break(state)
        FearGoodGirlEnemies(player)
        ApplyGoodGirlCostume(player, false)
        dependencies.Presentation.RemoveFollowEffect(state, "haloEffect")
        VisualEffects:Spawn("GoodGirlBreak", player.Position or Vector(320, 280), player)
        if player.SetColor then
            player:SetColor(Color(0.65, 0.05, 0.05, 1, 0.15, 0, 0), 45, 1, true, false)
        end
        RefreshGoodGirlCache(player)
        return nil
    end
    function callbackInstallers.InstallDamage()
        return Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.HandleGoodGirlOfBabylonDamage, EntityType.ENTITY_PLAYER)
    end

    return {
        RefreshGoodGirlCache = RefreshGoodGirlCache,
        IsGoodGirlRedHeartDamage = IsGoodGirlRedHeartDamage,
        FearGoodGirlEnemies = FearGoodGirlEnemies,
        CharmGoodGirlRoomEnemies = CharmGoodGirlRoomEnemies,
        InstallEvaluate = callbackInstallers.InstallEvaluate,
        InstallDamage = callbackInstallers.InstallDamage,
    }
end
