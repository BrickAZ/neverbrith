-- Private Drive Glove damage; instantiated once by init.lua.
return function(mod, deps)
    local callbackInstallers = {}
    local C,records,now=deps.Core,deps.State,deps.Now
    local data,state,key,held=records.Data,records.Get,records.Key,records.IsHeld
    local D,game,context=deps.Rules,deps.Game,deps.Context
    local movement,rushing=deps.Input.Movement,deps.Input.Rushing
    local freeze,flush=deps.Freeze,deps.Flush
    local function payment(p,flags,source)
        local t=records.Peek(p)
        return D.Payment(p,flags,source,game:GetRoom(),t and t.paymentFrame==now())
    end
    local function earlyDamage(_,p,amount,flags,source,countdown)
        if not records.IsReady() or amount<=0 then return end
        local s=data(p); if not s or not held(p) then return end
        local t=state(p)
        if payment(p,flags,source) then return end
        if D.Invulnerable(p,flags) then return end
        if s.burnout then return end
        local normalAmount=D.NormalAmount(p,amount,flags,game)
        if context.IncomingDamageMultiplier then normalAmount=normalAmount*context.IncomingDamageMultiplier(p) end
        local defended
        if t.mode=='blue' and not D.Bomb(flags,source) then
            defended=C.Parry(s,t,now())
        else
            local direction=D.NormalDirection(p,flags,source)
            local input=movement(p)
            if direction and C.GuardDirection(input.X,input.Y,direction.X,direction.Y) then
                defended=C.Guard(s,t,normalAmount)
                -- A bomb can overdraw the meter during blue and force recovery.
                if s.burnout and t.mode=='blue' then C.Recovery(t,now()) end
            end
        end
        if not defended then return end
        -- Native invulnerability is based on the incoming amount, before Womb,
        -- Wafer and coin-heart normalization; the gauge uses final heart damage.
        D.Cooldown(p,amount,flags,countdown)
        t.impactKind,t.impactAngle=D.Impact(p,flags,source)
        flush(p,s,t)
        return false
    end
    function callbackInstallers.earlyDamage()
        return mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,-30000,earlyDamage)
    end
    local function lateDamage(_,entity,amount,flags,source,countdown)
        local p=entity:ToPlayer(); if not p or not records.IsReady() then return end
        local t=records.Peek(p)
        if not t or not rushing(t) or payment(p,flags,source) or D.Flag(flags,'DAMAGE_FAKE') then return end
        t.damageReceipts=t.damageReceipts or {}
        t.damageReceipts[#t.damageReceipts+1]={health=D.Health(p),frame=now(),flags=flags,source=source and source.Entity}
        -- REPENTOGON's in-place argument override; no recursive second TakeDamage.
        return {Damage=amount*2}
    end
    function callbackInstallers.lateDamage()
        return mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,30000,lateDamage,EntityType.ENTITY_PLAYER)
    end
    local function postDamage(_,entity)
        local p=entity:ToPlayer(); if not p then return end
        local t=records.Peek(p); if not t or not t.damageReceipts then return end
        local receipt=table.remove(t.damageReceipts)
        if receipt and receipt.frame==now() and D.LostHealth(receipt.health,p) then
            C.End(t,'damage'); t.planned=nil
            if freeze.IsActive() then freeze.Interrupt() end
        end
    end
    function callbackInstallers.postDamage()
        return mod:AddPriorityCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,30000,postDamage,EntityType.ENTITY_PLAYER)
    end

    return {
        Install = callbackInstallers,

    }
end
