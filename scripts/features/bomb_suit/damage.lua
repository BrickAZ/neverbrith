-- Private damage responsibilities for bomb_suit; created once by its entry.
return function(mod, context, deps)
    local callbackInstallers = {}
    local data = deps.State.Data
    local BONUS = deps.Config.BONUS
    local BLOOD_SLOT = deps.Config.BLOOD_SLOT
    local DEVIL_BEGGAR = deps.Config.DEVIL_BEGGAR
    local key = deps.State.key
    local held = deps.State.held
    local refresh = deps.State.refresh
    local stateFor = deps.State.stateFor
    local sourceOwner = deps.Bombs.sourceOwner
    local beep = deps.Presentation.beep

    local function isBloodPayment(flags, source)
        if (flags & DamageFlag.DAMAGE_IV_BAG) ~= 0 then return true end
        local entity = source and source.Entity
        local kind = entity and entity.Type or (source and source.Type)
        local variant = entity and entity.Variant or (source and source.Variant)
        return kind == EntityType.ENTITY_SLOT and (variant == BLOOD_SLOT or variant == DEVIL_BEGGAR)
    end

    local function health(player)
        return {player:GetHearts(), player:GetSoulHearts(), player:GetBoneHearts()}
    end

    local function lostHealth(player, old)
        if not old then return false end
        local current = health(player)
        -- A shield's loss is not heart loss. Bone-container loss is real damage
        -- even when the red-heart counter remains unchanged.
        for i = 1, 3 do if current[i] < old[i] then return true end end
        return false
    end

    local function sourceKey(source)
        local entity = source and source.Entity
        if entity then return "entity:" .. key(entity) end
        return "ref:" .. tostring(source and source.Type or 0) .. ":" .. tostring(source and source.Variant or 0)
    end

    local function preDamage(_, player, amount, flags, source, countdown, extraSource)
        if not data.ready then return end
        flags = flags or 0
        local k = key(player)
        local state = stateFor(player)
        local payment = isBloodPayment(flags, source)
        -- nil preserves the original native hit. false cancels before native
        -- shields/health; do not spend a mantle merely to ignore an armed hit.
        if state and not payment then return false end
        local owner = sourceOwner(source and source.Entity) or sourceOwner(extraSource and extraSource.Entity)
        if owner == k and not payment then return false end
        if not state and held(player) and amount > 0 and (flags & DamageFlag.DAMAGE_FAKE) == 0 then
            local frame = Game():GetFrameCount()
            local receipts = data.before[k]
            if not receipts or receipts.frame ~= frame then receipts={frame=frame}; data.before[k]=receipts end
            -- Cancellation has no POST callback. Bound candidates to one frame
            -- and match by source; do not let fake/payment nested hits erase a
            -- real outer candidate or assume every PRE has a paired POST.
            receipts[#receipts+1] = {health=health(player),source=sourceKey(source),payment=payment}
            if #receipts > 16 then table.remove(receipts,1) end
        end
    end
    function callbackInstallers.preDamage()
        return mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG, -20000, preDamage)
    end

    local function postDamage(_, entity, amount, flags, source)
        if not data.ready then return end
        local player = entity:ToPlayer(); if not player then return end
        local k = key(player)
        if stateFor(player) or not held(player) or amount <= 0 or (flags & DamageFlag.DAMAGE_FAKE) ~= 0 then return end
        local receipts = data.before[k]
        if not receipts or receipts.frame ~= Game():GetFrameCount() then return end
        local receipt
        local payment = isBloodPayment(flags, source)
        for i=#receipts,1,-1 do
            local candidate = receipts[i]
            if candidate.source==sourceKey(source) and candidate.payment==payment
                and (payment or lostHealth(player,candidate.health)) then
                receipt=table.remove(receipts,i)
                if payment then
                    -- Only older snapshots precede this payment. Newer nested
                    -- candidates already contain its loss and must not be adjusted.
                    local current=health(player)
                    for j=1,i-1 do for h=1,3 do
                        receipts[j].health[h]=receipts[j].health[h]-math.max(0,receipt.health[h]-current[h])
                    end end
                end
                break
            end
        end
        if payment or not receipt then return end
        data.before[k]=nil
        data.active[k] = {player=player, age=0, lastFrame=Game():GetFrameCount()}
        refresh(player); beep(data.active[k])
        if Sprite then
            local ok, sprite = pcall(function()
                local s = Sprite(); s:Load("gfx/Effects/BombSuit/fuse.anm2", true); s:Play("Fuse", true); return s
            end)
            if ok then data.active[k].fuse = sprite end
        end
    end
    function callbackInstallers.postDamage()
        return mod:AddPriorityCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG, -20000, postDamage, EntityType.ENTITY_PLAYER)
    end

    local function evaluate(_, player, flag)
        if flag == CacheFlag.CACHE_SPEED and data.ready and data.active[key(player)] and held(player) then
            player.MoveSpeed = player.MoveSpeed + BONUS
        end
    end
    function callbackInstallers.evaluate()
        return mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, evaluate)
    end

    return {
        Installers = callbackInstallers,
        isBloodPayment = isBloodPayment,
        health = health,
        lostHealth = lostHealth,
        sourceKey = sourceKey,
        preDamage = preDamage,
        postDamage = postDamage,
        evaluate = evaluate,
    }
end
