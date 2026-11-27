-- Private combat responsibilities for god_complex; created once by its entry.
return function(mod, context, deps)
    local callbackInstallers = {}
    local data = deps.State.Data
    local INDIRECT = deps.Config.INDIRECT
    local SOLAR_DAMAGE_RADIUS = deps.Config.SOLAR_DAMAGE_RADIUS
    local key = deps.State.key
    local same = deps.State.same
    local exists = deps.State.exists
    local enemy = deps.Targeting.enemy
    local combat = deps.Targeting.combat
    local finalDeathType = deps.Targeting.finalDeathType
    local distance = deps.Targeting.distance
    local chooseTarget = deps.Targeting.chooseTarget
    local frame = deps.State.frame
    local state = deps.State.state

    local function ownerOf(e,seen,depth)
        if not e or (depth or 0)>12 then return nil end
        seen=seen or {};local k=key(e);if seen[k] then return nil end;seen[k]=true
        -- SpawnerEntity/Parent are base Entity userdata, even for Type=PLAYER.
        -- Resolve the typed player before calling IsCoopGhost/HasCollectible.
        if e.Type==EntityType.ENTITY_PLAYER then return e:ToPlayer() end
        if e.Type~=EntityType.ENTITY_TEAR and e.Type~=EntityType.ENTITY_LASER
            and e.Type~=EntityType.ENTITY_KNIFE then return nil end
        for _,parent in pairs({spawner=e.SpawnerEntity,parent=e.Parent}) do
            if parent.Type==EntityType.ENTITY_FAMILIAR or parent:ToNPC() then return nil end
        end
        return ownerOf(e.SpawnerEntity,seen,(depth or 0)+1) or ownerOf(e.Parent,seen,(depth or 0)+1)
    end

    local function tearAncestor(e,seen,depth)
        if not e or (depth or 0)>12 then return nil end
        seen=seen or {};local k=key(e);if seen[k] then return nil end;seen[k]=true
        if e.Type==EntityType.ENTITY_TEAR then return ownerOf(e) end
        if e.Type~=EntityType.ENTITY_EFFECT and e.Type~=EntityType.ENTITY_BOMB then return nil end
        return tearAncestor(e.SpawnerEntity,seen,(depth or 0)+1) or tearAncestor(e.Parent,seen,(depth or 0)+1)
    end

    local function directOwner(target,flags,source,extra)
        if data.internalHit and same(data.internalHit.target,target) and same(source and source.Entity,data.internalHit.player) then return nil end
        local e=(extra and extra.Entity) or (source and source.Entity)
        if not e then return nil end
        -- A proved tear explosion remains direct even when FIRE is also set.
        -- Ordinary burning ticks without EXPLOSION still take the indirect path.
        if (flags & DamageFlag.DAMAGE_EXPLOSION)~=0 then return tearAncestor(e) end
        if (flags & INDIRECT)~=0 then return nil end
        if e.Type==EntityType.ENTITY_TEAR or e.Type==EntityType.ENTITY_LASER or e.Type==EntityType.ENTITY_KNIFE then return ownerOf(e) end
        local c=data.collisions[key(target)]
        if c and c.frame==frame() and same(e,c.player) then return c.player end
        -- An arbitrary Player EntityRef is not proof of a weapon hit.
    end

    local function restrict(s,target)
        return s.form=='Solar' or (s.form=='Eye' and (not enemy(s.target,true) or not same(s.target,target)))
    end

    local function signature(e) return tostring(e.Type)..':'..tostring(e.Variant)..':'..tostring(e.SubType) end

    local function preDamage(_,e,amount,flags,source,count,extra)
        if not data.ready or not e:ToNPC() then return end
        local k=key(e);data.before[k]=nil
        local p=directOwner(e,flags,source,extra);local s=p and state(p)
        if s and restrict(s,e) then return false end
        if s and s.form=='War' and amount>0 and enemy(e,false) and finalDeathType(e)
            and not e:HasMortalDamage() and not data.settled[k] then
            data.before[k]={state=s,entity=e,signature=signature(e),frame=frame()}
        end
    end
    function callbackInstallers.preDamage()
        return mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,-100,preDamage)
    end

    local function confirmDeath(e)
        local k=key(e);local r=data.pending[k]
        if not r or data.settled[k] or r.signature~=signature(e) or not state(r.state.player)
            or data.active[key(r.state.player)]~=r.state or not finalDeathType(e) then data.pending[k]=nil;return end
        -- POST_ENTITY_KILL is authoritative even before IsDead is updated.
        if not r.deathSeen and not e:IsDead() then return end
        data.settled[k]=true;data.pending[k]=nil
        for i=0,7 do
            local angle=i*math.pi/4
            local b=Isaac.Spawn(EntityType.ENTITY_PROJECTILE,ProjectileVariant.PROJECTILE_NORMAL,0,
                e.Position,Vector(math.cos(angle)*5,math.sin(angle)*5),e):ToProjectile()
            if b then b.ProjectileFlags=0;r.state.projectiles=r.state.projectiles or {};r.state.projectiles[#r.state.projectiles+1]=b end
        end
        -- Native normal projectile collision damage/appearance; never a player tear.
    end

    local function postDamage(_,e,amount,flags,source,count,extra)
        if not e:ToNPC() then return end
        local k=key(e);local r=data.before[k];data.before[k]=nil
        if not r or r.frame~=frame() or r.signature~=signature(e) then return end
        local p=directOwner(e,flags,source,extra)
        if not same(p,r.state.player) or amount<=0 then return end
        if r.deathSeen or e:HasMortalDamage() or e:IsDead() then
            r.updates=0;data.pending[k]=r
            if r.deathSeen or e:IsDead() then confirmDeath(e) end
        end
    end
    function callbackInstallers.postDamage()
        return mod:AddPriorityCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,1000,postDamage)
    end

    local function loseTarget(e)
        for _,s in pairs(data.active) do
            if s.form=='Eye' and same(s.target,e) then
                s.target=nil;s.cooldown=15;s.cooldownFrame=frame();s.strikes={}
            end
        end
    end

    local function entityKilled(_,e)
        if not e:ToNPC() then return end
        local k=key(e);local r=data.before[k] or data.pending[k]
        if r then r.deathSeen=true end
        confirmDeath(e)
    end
    function callbackInstallers.entityKilled()
        return mod:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL,entityKilled)
    end

    local function npcDeath(_,e)
        -- Late fallback: this event follows the death animation, whereas the
        -- War burst belongs at POST_ENTITY_KILL when that animation begins.
        entityKilled(nil,e)
        loseTarget(e)
    end
    function callbackInstallers.npcDeath()
        return mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH,npcDeath)
    end

    local function npcUpdate(_,e)
        local r=data.pending[key(e)]
        if r then
            if e:IsDead() then confirmDeath(e)
            else
                r.updates=r.updates+1
                if r.signature~=signature(e) or not e:HasMortalDamage() or r.updates>=2 then data.pending[key(e)]=nil end
            end
        end
    end
    function callbackInstallers.npcUpdate()
        return mod:AddCallback(ModCallbacks.MC_NPC_UPDATE,npcUpdate)
    end

    local function removed(_,e)
        local k=key(e);data.pending[k]=nil;data.before[k]=nil;data.collisions[k]=nil
        loseTarget(e)
        -- Remove is never proof of a final death (morphs/room unloads also remove).
    end
    function callbackInstallers.removed()
        return mod:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE,removed)
    end

    local function preCollision(_,attack,target)
        if not target:ToNPC() then return end
        local p=ownerOf(attack)
        if p and state(p) then data.collisions[key(target)]={attack=attack,player=p,frame=frame()} end
    end
    function callbackInstallers.preCollision()
        return mod:AddPriorityCallback(ModCallbacks.MC_PRE_LASER_COLLISION,-1000,preCollision)
    end
    function callbackInstallers.preCollision2()
        return mod:AddPriorityCallback(ModCallbacks.MC_PRE_KNIFE_COLLISION,-1000,preCollision)
    end

    local function postCollision(_,attack,target)
        local c=data.collisions[key(target)]
        if c and same(c.attack,attack) then data.collisions[key(target)]=nil end
    end
    function callbackInstallers.postCollision()
        return mod:AddPriorityCallback(ModCallbacks.MC_POST_LASER_COLLISION,1000,postCollision)
    end
    function callbackInstallers.postCollision2()
        return mod:AddPriorityCallback(ModCallbacks.MC_POST_KNIFE_COLLISION,1000,postCollision)
    end

    local function fireTear(_,tear)
        local p=ownerOf(tear);local s=p and state(p)
        if s and s.form=='War' then
            local bits=s.addedPiercing or 0
            tear:AddTearFlags(TearFlags.TEAR_PIERCING)
            s.tears[key(tear)]={entity=tear,bits=bits}
        end
    end
    function callbackInstallers.fireTear()
        return mod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR,fireTear)
    end

    local function hit(s,e,amount)
        local previous=data.internalHit;data.internalHit={player=s.player,target=e}
        local ok,err=pcall(e.TakeDamage,e,amount,0,EntityRef(s.player),0)
        data.internalHit=previous
        if not ok then error(err) end
    end

    local function solar(s,entities)
        for _,e in ipairs(entities) do
            if enemy(e,false) and s.age%5==0 and distance(e,s.player)<=SOLAR_DAMAGE_RADIUS*SOLAR_DAMAGE_RADIUS then hit(s,e,s.player.Damage*0.80)
            elseif exists(e) and e.Type==EntityType.ENTITY_PROJECTILE and e.Variant==ProjectileVariant.PROJECTILE_NORMAL
                and distance(e,s.player)<=72*72 then
                local b=e:ToProjectile();local src=e.SpawnerEntity
                -- Unknown/special projectiles and allied projectiles are never removed.
                if b and b.ProjectileFlags==0 and not b:HasEntityFlags(EntityFlag.FLAG_FRIENDLY|EntityFlag.FLAG_CHARM)
                    and src and src:ToNPC() and not src:HasEntityFlags(EntityFlag.FLAG_FRIENDLY|EntityFlag.FLAG_CHARM) then b:Remove() end
            end
        end
    end

    local function eye(s)
        if s.target and not enemy(s.target,true) then
            s.target=nil;s.cooldown=15;s.cooldownFrame=frame();s.strikes={};return
        end
        if not s.target then
            if not combat() then s.cooldown=nil;s.strikes={};return end
            if s.cooldown then
                if s.cooldownFrame~=frame() then s.cooldown=s.cooldown-1;s.cooldownFrame=frame() end
                if s.cooldown>0 then return end
            end
            s.target=chooseTarget(s.player);s.cooldown=nil;s.nextHit=s.age+6
            if not s.target then return end
        end
        if s.age>=s.nextHit then
            s.nextHit=s.age+6
            local e=s.target;hit(s,e,s.player.Damage*3)
            s.strikeIndex=s.strikeIndex%2+1
            local sprite=s.visuals['strike'..s.strikeIndex]
            if sprite then sprite:Play('Judgment',true);s.strikes[s.strikeIndex]={sprite=sprite,position=e.Position,age=0} end
            if not enemy(e,true) then s.target=nil;s.cooldown=15;s.cooldownFrame=frame() end
        end
    end

    return {
        Installers = callbackInstallers,
        ownerOf = ownerOf,
        tearAncestor = tearAncestor,
        directOwner = directOwner,
        restrict = restrict,
        signature = signature,
        preDamage = preDamage,
        confirmDeath = confirmDeath,
        postDamage = postDamage,
        loseTarget = loseTarget,
        entityKilled = entityKilled,
        npcDeath = npcDeath,
        npcUpdate = npcUpdate,
        removed = removed,
        preCollision = preCollision,
        postCollision = postCollision,
        fireTear = fireTear,
        hit = hit,
        solar = solar,
        eye = eye,
    }
end
