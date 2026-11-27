-- Item-owned visuals; the entry coordinates installation of the callback owners.
return function(Neverbirth, dependencies)
    local Costumes = include("scripts.systems.null_costumes")
    local VisualEffects = assert(dependencies.VisualEffects)
    local GetFolkPlayerKey = dependencies.World.GetFolkPlayerKey

    local function GetGoodGirlCostumeId()
        return Costumes.GetCachedId(Neverbirth.GoodGirl, "costumeId", Neverbirth.GoodGirl.CostumePath)
    end

    local function RemoveGoodGirlCostume(player, costumeId)
        Costumes.Remove(player, costumeId)
    end

    local function AddGoodGirlCostume(player, costumeId)
        Costumes.Add(player, costumeId)
    end

    local function ApplyGoodGirlCostume(player, active)
        if not player then return end
        local key = GetFolkPlayerKey(player)
        local visualState = active and "presentable" or "none"
        Costumes.Transition(function() return Neverbirth.GoodGirl.costumeStates end, key, visualState, function()
            local costumeId = GetGoodGirlCostumeId()
            if costumeId then
                RemoveGoodGirlCostume(player, costumeId)
                if active then AddGoodGirlCostume(player, costumeId) end
            end
        end)
    end

    function Neverbirth:EnsureGoodGirlFollowEffect(state, field, key, player)
        if type(state) ~= "table" or not player then
            return nil
        end

        local effect = state[field]
        if not VisualEffects:IsActive(effect) then
            effect = VisualEffects:Spawn(key, player.Position or Vector(320, 280), player)
            state[field] = effect
        else
            VisualEffects:BindOwner(effect, key, player)
            VisualEffects:RefreshTimeout(effect, key)
        end

        return effect
    end

    local function RemoveGoodGirlFollowEffect(state, field)
        if type(state) ~= "table" then
            return
        end

        local effect = state[field]
        if VisualEffects:IsActive(effect) and effect.Remove then
            effect:Remove()
        end
        state[field] = nil
    end

    return {
        RemoveFollowEffect = RemoveGoodGirlFollowEffect,
        GetGoodGirlCostumeId = GetGoodGirlCostumeId,
        RemoveGoodGirlCostume = RemoveGoodGirlCostume,
        AddGoodGirlCostume = AddGoodGirlCostume,
        ApplyGoodGirlCostume = ApplyGoodGirlCostume,
    }
end
