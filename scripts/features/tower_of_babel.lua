return function(Neverbirth, dependencies)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local PlayerHasCollectible = dependencies.World.PlayerHasCollectible
    local TowerOfBabelId = dependencies.TowerOfBabelId
    local GetPlayers = dependencies.GetPlayers
    local CreepVariants = dependencies.CreepVariants

    local TowerOfBabelConfig = {
        EntityEffect = (EntityType and EntityType.ENTITY_EFFECT) or 1000,
        CreepVariants = include("scripts.features.tower_of_babel.creep_variants")(CreepVariants),
    }

    local TowerOfBabel = {}

    function TowerOfBabel.PlayerHas(player)
        return PlayerHasCollectible(player, TowerOfBabelId)
    end

    function TowerOfBabel.AnyPlayerHas()
        for _, player in ipairs(GetPlayers()) do
            if TowerOfBabel.PlayerHas(player) then
                return true
            end
        end

        return false
    end

    function TowerOfBabel.IsCreepVariant(variant)
        for _, creepVariant in ipairs(TowerOfBabelConfig.CreepVariants) do
            if type(creepVariant) == "number" and variant == creepVariant then
                return true
            end
        end

        return false
    end

    function TowerOfBabel.RemoveCreepIfActive(effect)
        if not effect or not TowerOfBabel.AnyPlayerHas() then
            return false
        end

        if effect.Type ~= nil and effect.Type ~= TowerOfBabelConfig.EntityEffect then
            return false
        end

        if not TowerOfBabel.IsCreepVariant(effect.Variant) then
            return false
        end

        local data = effect.GetData and effect:GetData() or nil
        if type(data) == "table" then
            data.NeverbirthTowerOfBabelRemoved = true
        end

        if effect.Remove then
            pcall(function()
                effect:Remove()
            end)
            return true
        end

        return false
    end

    function Neverbirth:RemoveTowerOfBabelCreepOnInit(effect)
        TowerOfBabel.RemoveCreepIfActive(effect)
    end
    function callbackInstallers.Neverbirth_RemoveTowerOfBabelCreepOnInit(variant)
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, Neverbirth.RemoveTowerOfBabelCreepOnInit, variant)
    end

    function Neverbirth:RemoveTowerOfBabelNewCreepOnUpdate(effect)
        if not effect then
            return
        end

        local frameCount = tonumber(effect.FrameCount) or 0
        if frameCount > 1 then
            return
        end

        TowerOfBabel.RemoveCreepIfActive(effect)
    end
    function callbackInstallers.Neverbirth_RemoveTowerOfBabelNewCreepOnUpdate(variant)
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, Neverbirth.RemoveTowerOfBabelNewCreepOnUpdate, variant)
    end

    local function RegisterTowerOfBabelCreepCallbacks()
        for _, variant in ipairs(TowerOfBabelConfig.CreepVariants) do
            if ModCallbacks.MC_POST_EFFECT_INIT then
                callbackInstallers.Neverbirth_RemoveTowerOfBabelCreepOnInit(variant)
            end
            if ModCallbacks.MC_POST_EFFECT_UPDATE then
                callbackInstallers.Neverbirth_RemoveTowerOfBabelNewCreepOnUpdate(variant)
            end
        end
    end

    RegisterTowerOfBabelCreepCallbacks()

    return { RemoveCreepIfActive = TowerOfBabel.RemoveCreepIfActive }
end
