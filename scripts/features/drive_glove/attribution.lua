-- Private Drive Glove attribution; instantiated once by init.lua.
return function(mod, deps)
    local callbackInstallers = {}
    local C,records,now=deps.Core,deps.State,deps.Now
    local data,state,key,held=records.Data,records.Get,records.Key,records.IsHeld
    local D,exists,players,flush=deps.Rules,deps.Exists,records.Players,deps.Flush
    local nativeAttribution=deps.NativeAttribution
    local statusOwnerFields={'poisonOwner','burnOwner','bleedOwner'}
    local hits,attackOwners={},{}
    local function owner(entity,depth,seen)
        if not exists(entity) or (depth or 0)>10 then return end
        seen=seen or {}; local hash=GetPtrHash(entity); if seen[hash] then return end; seen[hash]=true
        local p=entity:ToPlayer(); if p then return p end
        local familiar=entity:ToFamiliar(); if familiar then return familiar.Player end
        return owner(entity.Parent,(depth or 0)+1,seen) or owner(entity.SpawnerEntity,(depth or 0)+1,seen)
    end
    local function ownerKey(entity)
        if not entity then return end
        local id=GetPtrHash(entity)..':'..entity.InitSeed
        local p=owner(entity)
        if p then attackOwners[id]={entity=entity,key=key(p)}
        elseif exists(entity) and (exists(entity.Parent) or exists(entity.SpawnerEntity)) then
            -- A real replacement source can revoke ownership. A disappeared
            -- familiar merely clears native pointers; retain its projectile's
            -- creation snapshot until that projectile itself is removed.
            attackOwners[id]={entity=entity,key=false}
        end
        return p and key(p) or attackOwners[id] and attackOwners[id].key
    end
    local function hitRecord(e)
        -- Native death may expose a new GetData table. Keep attribution outside
        -- that table, scoped to this room and the entity's pointer plus InitSeed.
        local id=GetPtrHash(e)..':'..e.InitSeed
        local d=hits[id]
        if not d or d.type~=e.Type or d.variant~=e.Variant then
            d={entity=e,type=e.Type,variant=e.Variant};hits[id]=d
        end
        return d
    end
    local function statusApplied(_,e,source,kind)
        if not records.IsReady() or not exists(e) or not e:ToNPC() or not statusOwnerFields[kind] then return end
        -- Emitted only after native eligibility and payload selection. Store a
        -- player key now, while a tear/familiar source is still alive.
        local k=ownerKey(source and source.Entity)
        hitRecord(e)[statusOwnerFields[kind]]=k or false
    end
    function callbackInstallers.statusApplied()
        return mod:AddCallback('REPENTOGON_POST_DOT_APPLIED',statusApplied)
    end
    local function statusCopied(_,from,to,overwrite)
        if not records.IsReady() or not exists(from) or not exists(to) or not to:ToNPC() then return end
        local a,b=hitRecord(from),hitRecord(to)
        for _,info in ipairs({{'poisonOwner',EntityFlag.FLAG_POISON,'GetPoisonDamage'},
            {'burnOwner',EntityFlag.FLAG_BURN,'GetBurnDamage'},
            {'bleedOwner',EntityFlag.FLAG_BLEED_OUT,'GetBleedingCountdown'}}) do
            -- Match native CopyStatusEffects payload overwrite/nonzero rules.
            if overwrite or from[info[3]] and from[info[3]](from)~=0 then
                b[info[1]]=from:HasEntityFlags(info[2]) and a[info[1]] or false
            end
        end
    end
    function callbackInstallers.statusCopied()
        return mod:AddCallback('REPENTOGON_POST_DOT_COPY',statusCopied)
    end
    local function npcAttackSource(_,e,_,_,source)
        if e:ToNPC() then ownerKey(source and source.Entity) end
    end
    function callbackInstallers.npcAttackSource()
        return mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,30000,npcAttackSource)
    end
    local function npcDamage(_,e,amount,flags,source)
        if not e:ToNPC() or amount<=0 or D.Flag(flags,'DAMAGE_FAKE') then return end
        local d=hitRecord(e)
        local k=ownerKey(source and source.Entity)
        local kind=nativeAttribution and source and Isaac.GetCurrentDotDamageKind(e,source) or 0
        if statusOwnerFields[kind] then
            d.NeverbirthDriveLastHit=d[statusOwnerFields[kind]] or false
            return
        end
        -- Unscoped/sourceless synthetic damage is not a native status tick.
        -- Never infer its owner from active flags or the last ordinary attacker.
        -- Clear stale ownership on a genuine environmental final hit.
        d.NeverbirthDriveLastHit=k or false
    end
    function callbackInstallers.npcDamage()
        return mod:AddPriorityCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,30000,npcDamage)
    end
    local function died(_,npc)
        local d=hits[GetPtrHash(npc)..':'..npc.InitSeed]
        if not d then return end
        if d.NeverbirthDrivePaid or not npc:IsEnemy() or npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return end
        d.NeverbirthDrivePaid=true
        local k=d.NeverbirthDriveLastHit
        if not k then return end
        for _,p in ipairs(players()) do
            if key(p)==k and held(p) then
                local s,t=data(p),state(p); C.SetGauge(s,t,s.gauge+1,'Gain'); flush(p,s,t); return
            end
        end
    end
    function callbackInstallers.died()
        return mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH,died)
    end
    local function reset() hits={}; attackOwners={} end
    local function update()
        for id,hit in pairs(hits) do
            if not exists(hit.entity) then hits[id]=nil
            else
                if not hit.entity:HasEntityFlags(EntityFlag.FLAG_POISON) then hit.poisonOwner=nil end
                if not hit.entity:HasEntityFlags(EntityFlag.FLAG_BURN) then hit.burnOwner=nil end
                if not hit.entity:HasEntityFlags(EntityFlag.FLAG_BLEED_OUT) then hit.bleedOwner=nil end
            end
        end
        for id,attack in pairs(attackOwners) do
            if not exists(attack.entity) then attackOwners[id]=nil end
        end
    end
    function callbackInstallers.sources()
        for _,name in ipairs({'MC_POST_TEAR_INIT','MC_POST_LASER_INIT','MC_POST_KNIFE_INIT','MC_POST_BOMB_INIT','MC_POST_EFFECT_INIT'}) do
            if ModCallbacks[name] then mod:AddCallback(ModCallbacks[name],function(_,entity) ownerKey(entity) end) end
        end
    end

    return {
        Install = callbackInstallers,
        Reset=reset, Update=update,

    }
end
