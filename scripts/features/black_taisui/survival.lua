-- Owns lethal interception, body-ward consumption and gameplay spore effects.
return function(Neverbirth, dependencies)
    local Runtime = assert(dependencies.Runtime)
    local Presentation = dependencies.Presentation
    local VisualEffects = dependencies.VisualEffects
    local GetSurvivalCooldown = dependencies.GetSurvivalCooldown
    local GetFolkRoomKey = dependencies.GetFolkRoomKey
    local GetFolkFloorKey = dependencies.GetFolkFloorKey
    local BlackTaisuiId = dependencies.BlackTaisuiId
    local PlayerHasCollectible = dependencies.PlayerHasCollectible
    local IsIncomingDamageLethal = dependencies.IsIncomingDamageLethal
    local IsVulnerableEnemy = dependencies.IsVulnerableEnemy
    local SpawnFolkEffect = dependencies.SpawnFolkEffect
    local FOLK_BLACK_CREEP = (EffectVariant and (EffectVariant.PLAYER_CREEP_BLACK or EffectVariant.CREEP_RED or EffectVariant.POOF01)) or 1
    function Runtime:IsBlackTaisuiIgnoredDamage(flags)
        flags = tonumber(flags) or 0
        local ignoredFlags = {
            DamageFlag and DamageFlag.DAMAGE_FAKE,
            DamageFlag and DamageFlag.DAMAGE_IV_BAG,
            DamageFlag and DamageFlag.DAMAGE_DEVIL,
            DamageFlag and DamageFlag.DAMAGE_CURSED_DOOR,
            DamageFlag and DamageFlag.DAMAGE_NOKILL,
        }
        for _, flag in ipairs(ignoredFlags) do
            if flag and (flags & flag) ~= 0 then
                return true
            end
        end
        return false
    end

    function Runtime:BlackTaisuiDamageIsLethal(player, amount)
        return IsIncomingDamageLethal(player, tonumber(amount) or 0)
    end

    function Runtime:TriggerBlackTaisuiSpores(player, reason, strong)
        if not player then
            return
        end
        local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
        local key = tostring(reason or "spore") .. ":" .. tostring(GetFolkRoomKey())
        if state.sporeKeys[key] then
            return
        end
        state.sporeKeys[key] = true
        SpawnFolkEffect(FOLK_BLACK_CREEP, player.Position or Vector(320, 280), player)
        VisualEffects:Spawn(strong and "BlackTaisuiFearPulse" or "BlackTaisuiSpore", player.Position or Vector(320, 280), player)
        if player.SetColor then
            pcall(function()
                player:SetColor(Color(0.22, 0.22, 0.22, 1, 0, 0, 0.08), strong and 45 or 20, 1, true, false)
            end)
        end
        if not Isaac.GetRoomEntities then
            return
        end
        local ref = EntityRef(player)
        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            if IsVulnerableEnemy(entity) and entity.AddFear then
                pcall(function()
                    entity:AddFear(ref, Runtime.BlackTaisuiFearDuration, false)
                end)
            end
        end
    end

    function Neverbirth:BlackTaisuiDeathSaveAvailable(player)
        if not player or not PlayerHasCollectible(player, BlackTaisuiId) or Neverbirth:GetBlackTaisuiStage(player) < 3 then
            return false
        end
        local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
        return state.deathSavedFloorKey ~= GetFolkFloorKey()
    end

    function Runtime:RestoreBlackTaisuiDeathSaveHealth(player)
        if player.GetMaxHearts and player:GetMaxHearts() > 0 then
            if player.GetHearts and player.AddHearts then
                local current = tonumber(player:GetHearts()) or 0
                player:AddHearts(1 - current)
            end
        elseif player.AddBlackHearts then
            player:AddBlackHearts(2)
        end
    end

    function Neverbirth:ApplyBlackTaisuiDeathSave(player, reviveDeadPlayer)
        if Neverbirth.AvadaKedavra and Neverbirth.AvadaKedavra.IsFailureDeath(player) then return false end
        if not player or not Neverbirth:BlackTaisuiDeathSaveAvailable(player) then return false end
        if reviveDeadPlayer then
            if not player.Revive or not player.IsDead then return false end
            local ok = pcall(function() player:Revive() end)
            if not ok or player:IsDead() then return false end
        end
        local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
        state.deathSavedFloorKey = GetFolkFloorKey()
        state.deathSaveFeedbackFrames = 90
        state.deathSaveFeedbackKey = "blackTaisuiBlock"
        Runtime:RestoreBlackTaisuiDeathSaveHealth(player)
        player:SetMinDamageCooldown(GetSurvivalCooldown())
        Presentation.DeathSaveFeedback(player)
        Runtime:TriggerBlackTaisuiSpores(player, "death-save:" .. tostring(GetFolkFloorKey()), true)
        if Isaac and Isaac.DebugString then
            Isaac.DebugString("[neverbirth] Black Taisui blocked lethal damage; survival cooldown granted")
        end
        return true
    end

    function Neverbirth:HandleBlackTaisuiDamage(entity, amount, flags)
        if not Runtime.running or Runtime.disposed then return nil end
        local player = entity and entity.ToPlayer and entity:ToPlayer()
        if not player or (tonumber(amount) or 0) <= 0 or not PlayerHasCollectible(player, BlackTaisuiId) then
            return nil
        end
        if Runtime:IsBlackTaisuiIgnoredDamage(flags) then
            return nil
        end

        if Neverbirth:BlackTaisuiDeathSaveAvailable(player) and Runtime:BlackTaisuiDamageIsLethal(player, amount) then
            if Neverbirth:ApplyBlackTaisuiDeathSave(player, false) then return false end
            return nil
        end

        local maxHearts = player.GetMaxHearts and player:GetMaxHearts() or tonumber(player.maxHearts) or 0
        if maxHearts > 0 and DamageFlag and DamageFlag.DAMAGE_RED_HEARTS and ((tonumber(flags) or 0) & DamageFlag.DAMAGE_RED_HEARTS) ~= 0 then
            Runtime:AddBlackTaisuiParasite(player, (tonumber(amount) or 0) * 2, "red-damage")
        elseif maxHearts <= 0 then
            Runtime:AddBlackTaisuiParasite(player, (tonumber(amount) or 0), "soul-damage")
        end

        return nil
    end

    Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.HandleBlackTaisuiDamage, EntityType.ENTITY_PLAYER)

end
