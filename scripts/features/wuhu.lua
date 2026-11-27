-- Complete small feature; installed at its original cache-registration position.
return function(Neverbirth, dependencies)
    local Items = { Wuhu = assert(dependencies.ItemId) }

function Neverbirth:EvaluateWuhu(player, cacheFlag)
    local itemCount = player:GetCollectibleNum(Items.Wuhu)
    if itemCount <= 0 then
        return
    end

    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        player.Damage = player.Damage + 40 * itemCount
    elseif cacheFlag == CacheFlag.CACHE_SHOTSPEED then
        player.ShotSpeed = player.ShotSpeed - 1 * itemCount
    elseif cacheFlag == CacheFlag.CACHE_SPEED then
        player.MoveSpeed = player.MoveSpeed + 1 * itemCount
    elseif cacheFlag == CacheFlag.CACHE_TEARCOLOR then
        player.TearColor = Color()
    end

    player.MaxFireDelay = 0
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateWuhu)


    return { Evaluate = Neverbirth.EvaluateWuhu }
end
