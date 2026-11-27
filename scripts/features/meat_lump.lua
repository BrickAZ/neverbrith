return function(Neverbirth, dependencies)
    local running, disposed = true, false
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local GetSurvivalCooldown = assert(dependencies.GetSurvivalCooldown)
    local MeatLumpId = dependencies.MeatLumpId
    local IsValidItemId = dependencies.IsValidItemId
    local GetPlayers = dependencies.GetPlayers
    local IsIncomingDamageLethal = dependencies.IsIncomingDamageLethal

    local MeatLumpLifeHudX = 132
    local MeatLumpLifeHudY = 28

    function Neverbirth:GrantMeatLumpOneUp(itemId, charge, firstTime, slot, varData, player)
        if not running or disposed then return end
        Neverbirth:TrackMeatLumpPlayerCopies(player)
    end
    function callbackInstallers.Neverbirth_GrantMeatLumpOneUp()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, Neverbirth.GrantMeatLumpOneUp, MeatLumpId)
    end

    local ledger = include("scripts.features.meat_lump.ledger")({
        MeatLumpId = MeatLumpId, IsValidItemId = IsValidItemId, GetSaveData = dependencies.GetSaveData, Store = dependencies.Store,
    })
    function Neverbirth:TrackMeatLumpPlayerCopies(player)
        if not running or disposed then return end
        return ledger.TrackCopies(player)
    end
    function callbackInstallers.Neverbirth_TrackMeatLumpPlayerCopies()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED, Neverbirth.TrackMeatLumpPlayerCopies, MeatLumpId)
    end
    function Neverbirth:GetMeatLumpLifeCount(player) return ledger.GetCount(player) end
    function Neverbirth:AddMeatLumpLife(player, amount) return ledger.Add(player, amount) end
    local function ConsumeMeatLumpLife(player) return ledger.Consume(player) end

    local function RestoreMeatLumpLifeHealth(player)
        if not player then
            return
        end
        local maxHearts = player.GetMaxHearts and (tonumber(player:GetMaxHearts()) or 0) or tonumber(player.maxHearts) or 0
        if maxHearts > 0 and player.GetHearts and player.AddHearts then
            local current = tonumber(player:GetHearts()) or 0
            player:AddHearts(math.max(0, 1 - current))
        elseif player.AddBlackHearts then
            player:AddBlackHearts(2)
        elseif player.AddSoulHearts then
            player:AddSoulHearts(2)
        end
    end

    function Neverbirth:ApplyMeatLumpLife(player, reviveDeadPlayer)
        if not running or disposed then return false end
        if Neverbirth.AvadaKedavra and Neverbirth.AvadaKedavra.IsFailureDeath(player) then return false end
        if not player or Neverbirth:GetMeatLumpLifeCount(player) <= 0 then return false end
        if reviveDeadPlayer then
            if not player.Revive or not player.IsDead then return false end
            local ok = pcall(function() player:Revive() end)
            if not ok or player:IsDead() then return false end
        end
        if not ConsumeMeatLumpLife(player) then
            return false
        end
        RestoreMeatLumpLifeHealth(player)
        player:SetMinDamageCooldown(GetSurvivalCooldown())
        if player and player.SetColor and Color then
            pcall(function()
                player:SetColor(Color(0.25, 0.15, 0.18, 1, 0.08, 0, 0.08), 45, 1, true, false)
            end)
        end
        if Isaac and Isaac.DebugString then
            Isaac.DebugString("[neverbirth] Meat Lump blocked lethal damage; lives=" .. Neverbirth:GetMeatLumpLifeCount(player) .. "; survival cooldown granted")
        end
        return true
    end

    function Neverbirth:HandleMeatLumpDamage(entity, amount, flags)
        if not running or disposed then return nil end
        local player = entity and entity.ToPlayer and entity:ToPlayer()
        if not player or (tonumber(amount) or 0) <= 0 or Neverbirth:GetMeatLumpLifeCount(player) <= 0 then
            return nil
        end
        local nonLethalFlags = (DamageFlag.DAMAGE_FAKE or 0) | (DamageFlag.DAMAGE_NOKILL or 0)
        if ((tonumber(flags) or 0) & nonLethalFlags) ~= 0 then return nil end
        if IsIncomingDamageLethal(player, tonumber(amount) or 0) and Neverbirth:ApplyMeatLumpLife(player, false) then
            return false
        end
        return nil
    end
    function callbackInstallers.Neverbirth_HandleMeatLumpDamage()
        return Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.HandleMeatLumpDamage, EntityType.ENTITY_PLAYER)
    end

    function Neverbirth:RecoverMeatLumpDeadPlayers()
        if not running or disposed then return end
        for _, player in ipairs(GetPlayers()) do
            if Neverbirth:GetMeatLumpLifeCount(player) > 0 and player and player.IsDead then
                local ok, dead = pcall(function()
                    return player:IsDead()
                end)
                if ok and dead then
                    Neverbirth:ApplyMeatLumpLife(player, true)
                end
            end
        end
    end
    function callbackInstallers.Neverbirth_RecoverMeatLumpDeadPlayers()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.RecoverMeatLumpDeadPlayers)
    end

    function Neverbirth:TrackMeatLumpOneUpCopies()
        if not running or disposed then return end
        if not IsValidItemId(MeatLumpId) then
            return
        end
        for _, player in ipairs(GetPlayers()) do
            Neverbirth:TrackMeatLumpPlayerCopies(player)
        end
    end
    function callbackInstallers.Neverbirth_TrackMeatLumpOneUpCopies()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.TrackMeatLumpOneUpCopies)
    end

    local presentation = include("scripts.features.meat_lump.presentation")({
        GetLifeCount = function(player) return Neverbirth:GetMeatLumpLifeCount(player) end,
        GetOrigin = function() return MeatLumpLifeHudX, MeatLumpLifeHudY end,
        RenderText = function(...) return Neverbirth:RenderRuntimeText(...) end,
    })
    local RenderLife = presentation.RenderLife

    local function InstallDamageCallbacks()
        callbackInstallers.Neverbirth_HandleMeatLumpDamage()
        if ModCallbacks.MC_POST_UPDATE then
            callbackInstallers.Neverbirth_RecoverMeatLumpDeadPlayers()
        end
    end

    local function InstallTrackingCallback()
        callbackInstallers.Neverbirth_TrackMeatLumpOneUpCopies()
    end

    local function InstallCollectibleCallbacks()
        if ModCallbacks.MC_POST_ADD_COLLECTIBLE and IsValidItemId(MeatLumpId) then
            callbackInstallers.Neverbirth_GrantMeatLumpOneUp()
        end
        if ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED and IsValidItemId(MeatLumpId) then
            callbackInstallers.Neverbirth_TrackMeatLumpPlayerCopies()
        end
    end

    return {
        Pause = function() running = false end,
        Resume = function() if not disposed then running = true end end,
        Dispose = function() running, disposed = false, true end,
        RenderLife = RenderLife,
        InstallDamageCallbacks = InstallDamageCallbacks,
        InstallTrackingCallback = InstallTrackingCallback,
        InstallCollectibleCallbacks = InstallCollectibleCallbacks,
    }
end
