-- Owns the five-tick rush freeze and exactly the sprite flags it adds.
return function(mod, deps)
    local game,now,exists,records=deps.Game,deps.Now,deps.Exists,deps.State
    local freezeUntil,frozen=-1,{}
    local function thaw()
        for _,v in pairs(frozen) do
            if exists(v.entity) then
                v.entity.Velocity=v.velocity
                if v.spriteFlag then v.entity:ClearEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE) end
            end
        end
        frozen={}
    end
    local function freeze(e)
        if now()>=freezeUntil then return end
        local hash=GetPtrHash(e)
        if not frozen[hash] then
            local added=not e:HasEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE)
            frozen[hash]={entity=e,velocity=e.Velocity,position=e.Position,spriteFlag=added}
            if added then e:AddEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE) end
        end
        e.Velocity=Vector(0,0)
        return true
    end
    local function beginFreeze()
        freezeUntil=math.max(freezeUntil,now()+5)
        game:GetRoom():SetPauseTimer(5)
        for _,e in ipairs(Isaac.GetRoomEntities()) do freeze(e) end
    end
    local api = {Entity=freeze, Begin=beginFreeze, Thaw=thaw}
    function api.IsActive() return now()<freezeUntil end
    function api.ThawExpired() if now()>=freezeUntil and next(frozen) then thaw() end end
    function api.HoldPositions()
        for _,v in pairs(frozen) do if exists(v.entity) then v.entity.Position=v.position; v.entity.Velocity=Vector(0,0) end end
    end
    function api.Stop() thaw(); freezeUntil=-1 end
    function api.Interrupt() freezeUntil=now(); thaw() end
    function api.InstallUpdates()
    for _,name in ipairs({'MC_PRE_TEAR_UPDATE','MC_PRE_FAMILIAR_UPDATE','MC_PRE_BOMB_UPDATE',
        'MC_PRE_PICKUP_UPDATE','MC_PRE_KNIFE_UPDATE','MC_PRE_PROJECTILE_UPDATE','MC_PRE_LASER_UPDATE',
        'MC_PRE_EFFECT_UPDATE','MC_PRE_NPC_UPDATE','MC_PRE_SLOT_UPDATE'}) do
        mod:AddPriorityCallback(ModCallbacks[name],-30000,function(_,e) if records.IsReady() then return freeze(e) end end)
    end
    end
    return api
end
