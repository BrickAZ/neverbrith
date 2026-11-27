-- Complete small feature; installed at its original cache-registration position.
return function(Neverbirth, dependencies)
    local Items = { EssentialBalm = assert(dependencies.ItemId) }

function Neverbirth:EvaluateEssentialBalm(player, cacheFlag)
    local itemCount = player:GetCollectibleNum(Items.EssentialBalm)
    if itemCount <= 0 then
        return
    end

    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        player.Damage = player.Damage + 1 * itemCount
    elseif cacheFlag == CacheFlag.CACHE_SHOTSPEED then
        player.ShotSpeed = player.ShotSpeed - 0.2 * itemCount
    elseif cacheFlag == CacheFlag.CACHE_TEARCOLOR then
        player.TearColor = Color(0.2, 1.0, 0.2, 1.0)
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateEssentialBalm)


    return { Evaluate = Neverbirth.EvaluateEssentialBalm }
end
