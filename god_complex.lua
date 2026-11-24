-- God Complex / 神性过载. Timed owner-only active; no rewards or room mutations.
-- REPENTOGON 1.0.12a: laser/knife damage can expose Player as its source.
-- Collision scopes supply narrow provenance; optional ExtraSource also supports
-- newer runtimes. Unknown player/effect damage is deliberately left alone.
return function(mod, context)
    local ID=context.ItemId
    if not ID or ID<=0 then return end
    local REQUIRED={'MC_POST_ENTITY_TAKE_DMG','MC_PRE_PLAYER_UPDATE','MC_PRE_LASER_COLLISION',
        'MC_POST_LASER_COLLISION','MC_POST_KNIFE_COLLISION','MC_PRE_PLAYER_RENDER'}
    for _,name in ipairs(REQUIRED) do
        if not ModCallbacks[name] then
            if context.DebugLog then context.DebugLog('[God Complex] Missing callback: '..name) end
            return
        end
    end
    local CACHE=CacheFlag.CACHE_DAMAGE|CacheFlag.CACHE_FIREDELAY|CacheFlag.CACHE_SPEED|CacheFlag.CACHE_TEARFLAG
    local INDIRECT=DamageFlag.DAMAGE_POISON_BURN|DamageFlag.DAMAGE_FIRE|DamageFlag.DAMAGE_ACID|DamageFlag.DAMAGE_FAKE
        |DamageFlag.DAMAGE_BOOGER|DamageFlag.DAMAGE_CLONES
    local NO_USE={Discharge=false,Remove=false,ShowAnim=false}
    local FORMS={'Solar','War','Eye'}
    local ROOT='gfx/Effects/GodComplex/'
    local SOLAR_DAMAGE_RADIUS=95
    -- Alpha bounds in each 64x64 SolarHalo crop; right/bottom are exclusive.
    -- The PNG/ANM2 resource test verifies these and the 3-tick frame duration.
    local SOLAR_HALO_BOUNDS={
        {6,14,57,51},{5,13,58,52},{3,12,60,53},{2,11,61,54},
        {3,12,60,53},{4,13,59,52},{6,14,57,51},{7,15,56,50},
    }
    local active,lastUses,collisions,before,pending,settled,shootRestore={},{},{},{},{},{},{}
    local ready=false
    local badVisuals={}
    local function log(message) if context.DebugLog then context.DebugLog('[God Complex] '..message) end end
    local function key(e) return tostring(GetPtrHash(e))..':'..tostring(e.InitSeed) end
    local function same(a,b) return a and b and key(a)==key(b) end
    -- Matches memory_disorder's existing persistent-player contract. Never save pointers.
    local function saveKey(p) return tostring(p.InitSeed)..':'..tostring(p.ControllerIndex) end
    local function exists(e) return e and e:Exists() end
    local function alive(p) return exists(p) and not p:IsDead() and not p:IsCoopGhost() and not p:HasMortalDamage() end
    local function frame() return Game():GetFrameCount() end
    local function location()
        local l=Game():GetLevel();local d=l:GetCurrentRoomDesc()
        return table.concat({tostring(context.GetCurrentRunSeed()),l:GetStage(),l:GetStageType(),
            l:GetDungeonPlacementSeed(),l:GetDimension(),d.ListIndex,d.SafeGridIndex,d.SpawnSeed},':')
    end
    local function saved()
        local root=context.GetSaveRoot();local run=tostring(context.GetCurrentRunSeed())
        if type(root.godComplex)~='table' or root.godComplex.run~=run then
            root.godComplex={version=1,run=run,players={}}
        end
        if type(root.godComplex.players)~='table' then root.godComplex.players={} end
        return root.godComplex
    end
    local function refresh(p) if exists(p) then p:AddCacheFlags(CACHE);p:EvaluateItems() end end
    local function state(p)
        local s=p and active[key(p)]
        if ready and s and alive(p) and p:HasCollectible(ID) and s.room==location() and s.age<240 then return s end
    end
    local function restoreShoot(k)
        local r=shootRestore[k];shootRestore[k]=nil
        if r and exists(r.player) then r.player:SetCanShoot(r.value) end
    end
    local function stop(k)
        local s=active[k];active[k]=nil;restoreShoot(k)
        if not s then return end
        for _,t in pairs(s.tears) do
            if exists(t.entity) then t.entity:ClearTearFlags(t.bits) end
        end
        for _,projectile in ipairs(s.projectiles or {}) do if exists(projectile) then projectile:Remove() end end
        for id,r in pairs(pending) do if r.state==s then pending[id]=nil end end
        s.target=nil;s.cooldown=nil;s.visuals={};s.strikes={};s.tears={}
        refresh(s.player)
    end
    local function clear()
        local keys={};for k in pairs(active) do keys[#keys+1]=k end
        for _,k in ipairs(keys) do stop(k) end
        for k in pairs(shootRestore) do restoreShoot(k) end
        collisions={};before={};pending={};settled={}
    end
    local function enemy(e,retained)
        if not exists(e) or not e:ToNPC() or e:IsDead() or e.HitPoints<=0 or not e:IsEnemy() then return false end
        -- Retain a locked target through charm, colour, burial and invulnerability.
        return retained or (e:IsActiveEnemy(false) and not e:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
            and not e:HasEntityFlags(EntityFlag.FLAG_CHARM))
    end
    local function combat()
        for _,e in ipairs(Isaac.GetRoomEntities()) do if enemy(e,false) then return true end end
        return false
    end
    local MINI={}
    for _,name in ipairs({'ENTITY_SLOTH','ENTITY_LUST','ENTITY_WRATH','ENTITY_GLUTTONY','ENTITY_GREED','ENTITY_ENVY','ENTITY_PRIDE'}) do
        MINI[EntityType[name]]=true
    end
    local function mini(e)
        if not MINI[e.Type] then return false end
        if e.Type==EntityType.ENTITY_ENVY then
            return e.Variant==0 or e.Variant==1 or e.Variant==10 or e.Variant==11
                or e.Variant==20 or e.Variant==21 or e.Variant==30 or e.Variant==31
        end
        return e.Variant==0 or e.Variant==1 or (e.Type==EntityType.ENTITY_SLOTH and e.Variant==2)
    end
    local function trueBoss(e) return e:IsBoss() and not mini(e) end
    local function finalDeathType(e)
        -- Vanilla Envy's larger variants split instead of finally dying.
        return not trueBoss(e) and (e.Type~=EntityType.ENTITY_ENVY or e.Variant==30 or e.Variant==31)
    end
    local function distance(a,b) local x,y=a.Position.X-b.Position.X,a.Position.Y-b.Position.Y;return x*x+y*y end
    local function chooseTarget(p)
        local best,bestRank,bestHP,bestDistance
        local bossRoom=Game():GetRoom():GetType()==RoomType.ROOM_BOSS
        for _,e in ipairs(Isaac.GetRoomEntities()) do
            if enemy(e,false) then
                local rank=trueBoss(e) and (bossRoom and 0 or 2) or (mini(e) and 1 or (bossRoom and 2 or 0))
                local hp,dist=e.HitPoints,distance(e,p)
                if not best or rank<bestRank or (rank==bestRank and (hp>bestHP or (hp==bestHP and dist<bestDistance))) then
                    best,bestRank,bestHP,bestDistance=e,rank,hp,dist
                end
            end
        end
        return best
    end
    local function visual(file,animation)
        local path=ROOT..file..'.anm2'
        if badVisuals[path] then return nil end
        local ok,s=pcall(function()
            local sprite=Sprite();sprite:Load(path,true);sprite:Play(animation,true)
            if sprite:GetAnimation()~=animation then error('animation missing: '..animation) end
            return sprite
        end)
        if ok then return s end
        badVisuals[path]=true;log('Visual unavailable; gameplay remains active: '..path..' ('..tostring(s)..')')
    end
    local function startVisuals(s)
        s.visuals.state=visual('GodComplexState',s.form)
        -- A small floating status badge, not a full-size mask over Isaac's face.
        if s.visuals.state then s.visuals.state.Scale=Vector(0.5,0.5) end
        if s.form=='Solar' then s.visuals.halo=visual('GodComplexSolarHalo','SolarHalo')
        elseif s.form=='Eye' then
            s.visuals.mark=visual('GodComplexEyeMark','EyeMark')
            -- Two 12-frame strikes can overlap at the six-frame damage cadence.
            s.visuals.strike1=visual('GodComplexJudgment','Judgment')
            s.visuals.strike2=visual('GodComplexJudgment','Judgment')
        end
    end
    local function use(_,id,rng,p,flags,slot)
        if not ready or not alive(p) or not p:HasCollectible(ID) or state(p) or active[key(p)]
            or lastUses[key(p)]==frame() or (flags & UseFlag.USE_CARBATTERY)~=0
            or Game():IsPaused() or p.ControlsEnabled==false or not p:AreControlsEnabled()
            or Game():GetRoom():GetFrameCount()<=0 or Game():GetRoom():IsClear() or not combat() then return NO_USE end
        if not p.SetCanShoot then log('SetCanShoot unavailable; use refused');return NO_USE end
        local old=saved().players[saveKey(p)];local choices={}
        for _,form in ipairs(FORMS) do if form~=old then choices[#choices+1]=form end end
        local form=choices[p:GetCollectibleRNG(ID):RandomInt(#choices)+1]
        local s={player=p,form=form,slot=slot,room=location(),age=0,lastFrame=frame(),tears={},visuals={},strikes={},strikeIndex=0,nextHit=6}
        active[key(p)]=s;lastUses[key(p)]=frame();saved().players[saveKey(p)]=form
        if form=='Eye' then s.target=chooseTarget(p) end
        refresh(p);startVisuals(s);context.Save()
        -- XML maxcharges=2 is the only charge authority, for the supplied slot.
        return {Discharge=true,Remove=false,ShowAnim=true}
    end
    local function evaluate(_,p,flag)
        local s=state(p);if not s then return end
        if s.form=='Solar' and flag==CacheFlag.CACHE_SPEED then p.MoveSpeed=p.MoveSpeed*0.55
        elseif s.form=='War' then
            if flag==CacheFlag.CACHE_DAMAGE then p.Damage=p.Damage*2
            elseif flag==CacheFlag.CACHE_FIREDELAY then p.MaxFireDelay=p.MaxFireDelay*0.60
            elseif flag==CacheFlag.CACHE_TEARFLAG then
                s.addedPiercing=TearFlags.TEAR_PIERCING & ~p.TearFlags
                p.TearFlags=p.TearFlags|TearFlags.TEAR_PIERCING
            end
        end
    end
    -- Traverse only attack ancestry. Familiar/NPC/unknown effect parents are
    -- hard boundaries, even when they in turn have a Player spawner.
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
    local internalHit=nil
    local function directOwner(target,flags,source,extra)
        if internalHit and same(internalHit.target,target) and same(source and source.Entity,internalHit.player) then return nil end
        local e=(extra and extra.Entity) or (source and source.Entity)
        if not e then return nil end
        -- A proved tear explosion remains direct even when FIRE is also set.
        -- Ordinary burning ticks without EXPLOSION still take the indirect path.
        if (flags & DamageFlag.DAMAGE_EXPLOSION)~=0 then return tearAncestor(e) end
        if (flags & INDIRECT)~=0 then return nil end
        if e.Type==EntityType.ENTITY_TEAR or e.Type==EntityType.ENTITY_LASER or e.Type==EntityType.ENTITY_KNIFE then return ownerOf(e) end
        local c=collisions[key(target)]
        if c and c.frame==frame() and same(e,c.player) then return c.player end
        -- An arbitrary Player EntityRef is not proof of a weapon hit.
    end
    local function restrict(s,target)
        return s.form=='Solar' or (s.form=='Eye' and (not enemy(s.target,true) or not same(s.target,target)))
    end
    local function signature(e) return tostring(e.Type)..':'..tostring(e.Variant)..':'..tostring(e.SubType) end
    local function preDamage(_,e,amount,flags,source,count,extra)
        if not ready or not e:ToNPC() then return end
        local k=key(e);before[k]=nil
        local p=directOwner(e,flags,source,extra);local s=p and state(p)
        if s and restrict(s,e) then return false end
        if s and s.form=='War' and amount>0 and enemy(e,false) and finalDeathType(e)
            and not e:HasMortalDamage() and not settled[k] then
            before[k]={state=s,entity=e,signature=signature(e),frame=frame()}
        end
    end
    local function confirmDeath(e)
        local k=key(e);local r=pending[k]
        if not r or settled[k] or r.signature~=signature(e) or not state(r.state.player)
            or active[key(r.state.player)]~=r.state or not finalDeathType(e) then pending[k]=nil;return end
        -- POST_ENTITY_KILL is authoritative even before IsDead is updated.
        if not r.deathSeen and not e:IsDead() then return end
        settled[k]=true;pending[k]=nil
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
        local k=key(e);local r=before[k];before[k]=nil
        if not r or r.frame~=frame() or r.signature~=signature(e) then return end
        local p=directOwner(e,flags,source,extra)
        if not same(p,r.state.player) or amount<=0 then return end
        if r.deathSeen or e:HasMortalDamage() or e:IsDead() then
            r.updates=0;pending[k]=r
            if r.deathSeen or e:IsDead() then confirmDeath(e) end
        end
    end
    local function loseTarget(e)
        for _,s in pairs(active) do
            if s.form=='Eye' and same(s.target,e) then
                s.target=nil;s.cooldown=15;s.cooldownFrame=frame();s.strikes={}
            end
        end
    end
    local function entityKilled(_,e)
        if not e:ToNPC() then return end
        local k=key(e);local r=before[k] or pending[k]
        if r then r.deathSeen=true end
        confirmDeath(e)
    end
    local function npcDeath(_,e)
        -- Late fallback: this event follows the death animation, whereas the
        -- War burst belongs at POST_ENTITY_KILL when that animation begins.
        entityKilled(nil,e)
        loseTarget(e)
    end
    local function npcUpdate(_,e)
        local r=pending[key(e)]
        if r then
            if e:IsDead() then confirmDeath(e)
            else
                r.updates=r.updates+1
                if r.signature~=signature(e) or not e:HasMortalDamage() or r.updates>=2 then pending[key(e)]=nil end
            end
        end
    end
    local function removed(_,e)
        local k=key(e);pending[k]=nil;before[k]=nil;collisions[k]=nil
        loseTarget(e)
        -- Remove is never proof of a final death (morphs/room unloads also remove).
    end
    local function preCollision(_,attack,target)
        if not target:ToNPC() then return end
        local p=ownerOf(attack)
        if p and state(p) then collisions[key(target)]={attack=attack,player=p,frame=frame()} end
    end
    local function postCollision(_,attack,target)
        local c=collisions[key(target)]
        if c and same(c.attack,attack) then collisions[key(target)]=nil end
    end
    local function fireTear(_,tear)
        local p=ownerOf(tear);local s=p and state(p)
        if s and s.form=='War' then
            local bits=s.addedPiercing or 0
            tear:AddTearFlags(TearFlags.TEAR_PIERCING)
            s.tears[key(tear)]={entity=tear,bits=bits}
        end
    end
    local function prePlayer(_,p)
        local s=state(p)
        if s and s.form=='Solar' then
            local k=key(p)
            if not shootRestore[k] then shootRestore[k]={player=p,value=p:CanShoot()} end
            p:SetCanShoot(false)
        end
    end
    local function postPlayer(_,p) restoreShoot(key(p)) end
    local function hit(s,e,amount)
        local previous=internalHit;internalHit={player=s.player,target=e}
        local ok,err=pcall(e.TakeDamage,e,amount,0,EntityRef(s.player),0)
        internalHit=previous
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
    local function update()
        if not ready or Game():IsPaused() then return end
        local entities=next(active) and Isaac.GetRoomEntities() or {}
        local now=frame()
        for k,s in pairs(active) do
            if not state(s.player) then stop(k)
            elseif s.lastFrame~=now then
                s.lastFrame=now;s.age=s.age+1
                if s.age>=240 then stop(k)
                else
                    for _,sprite in pairs(s.visuals) do sprite:Update() end
                    for i,b in pairs(s.strikes) do b.age=b.age+1;if b.age>=12 or b.sprite:IsFinished('Judgment') then s.strikes[i]=nil end end
                    if s.form=='Solar' then solar(s,entities) elseif s.form=='Eye' then eye(s) end
                end
            end
        end
        for k,c in pairs(collisions) do if c.frame<now then collisions[k]=nil end end
        for k,r in pairs(before) do if r.frame<now then before[k]=nil end end
    end
    local function draw(sprite,world,screenOffset,fitSolarHalo)
        if not sprite then return end
        local ok,err=pcall(function()
            if not Isaac.WorldToScreen then error('WorldToScreen unavailable') end
            local screen=Isaac.WorldToScreen(world)
            if fitSolarHalo then
                local b=SOLAR_HALO_BOUNDS[math.floor(sprite:GetFrame()/3)+1]
                -- Project the actual damage boundary, not the transparent
                -- 64px canvas. Fit each animated ellipse to that same range.
                local r=SOLAR_DAMAGE_RADIUS
                local left=Isaac.WorldToScreen(world+Vector(-r,0)).X
                local right=Isaac.WorldToScreen(world+Vector(r,0)).X
                local top=Isaac.WorldToScreen(world+Vector(0,-r)).Y
                local bottom=Isaac.WorldToScreen(world+Vector(0,r)).Y
                local sx,sy=(right-left)/(b[3]-b[1]),(bottom-top)/(b[4]-b[2])
                sprite.Scale=Vector(sx,sy)
                -- The visible ring is slightly off the ANM2 pivot (32,32).
                screen=Vector(left+(32-b[1])*sx,top+(32-b[2])*sy)
            end
            if screenOffset then screen=screen+screenOffset end
            sprite:Render(screen,Vector.Zero,Vector.Zero)
        end)
        if not ok and not badVisuals.render then badVisuals.render=true;log('Owned render skipped: '..tostring(err)) end
    end
    local function head(e) return e.Position+Vector(0,-math.max(18,(e.Size or 12)+4)) end
    local function mainRenderPass()
        if not ready then return false end
        local mode=Game():GetRoom():GetRenderMode()
        return mode==RenderMode.RENDER_NULL or mode==RenderMode.RENDER_NORMAL
    end
    local function renderUnderPlayer(_,p)
        if not mainRenderPass() then return end
        local s=state(p)
        -- PRE_PLAYER_RENDER places the halo behind its owner. Position is the
        -- logical ground anchor; body/flying/callback offsets do not move it.
        -- Return nil so the engine still renders Isaac normally afterwards.
        if s then draw(s.visuals.halo,p.Position,nil,true) end
    end
    local function render()
        if not mainRenderPass() then return end
        for _,s in pairs(active) do
            if state(s.player) then
                -- Clearance is in screen pixels after one camera conversion.
                -- The ANM2 pivot is near the badge bottom; 40px clears a normal
                -- head, and SpriteScale keeps enlarged players clear as well.
                local height=40*math.max(1,s.player.SpriteScale and s.player.SpriteScale.Y or 1)
                draw(s.visuals.state,s.player.Position,Vector(0,-height))
                if s.target and enemy(s.target,true) then draw(s.visuals.mark,head(s.target)) end
                for _,b in pairs(s.strikes) do draw(b.sprite,b.position) end
            end
        end
    end
    local function started(_,continued)
        clear();ready=true;lastUses={};badVisuals={}
        if not continued then context.GetSaveRoot().godComplex=nil end
        saved()
    end
    local function exitGame() clear();if ready then context.Save() end;ready=false;lastUses={} end
    local function died(_,p) if p then stop(key(p)) end end
    local function lost(_,p,id) if id==ID and not p:HasCollectible(ID) then stop(key(p)) end end
    mod:AddCallback(ModCallbacks.MC_USE_ITEM,use,ID)
    mod:AddPriorityCallback(ModCallbacks.MC_EVALUATE_CACHE,20000,evaluate)
    mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,-100,preDamage)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,1000,postDamage)
    mod:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL,entityKilled)
    mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH,npcDeath)
    mod:AddCallback(ModCallbacks.MC_NPC_UPDATE,npcUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE,removed)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_LASER_COLLISION,-1000,preCollision)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_LASER_COLLISION,1000,postCollision)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_KNIFE_COLLISION,-1000,preCollision)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_KNIFE_COLLISION,1000,postCollision)
    mod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR,fireTear)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,10000,prePlayer)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,-10000,postPlayer)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE,update)
    mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_RENDER,renderUnderPlayer)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER,render)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,clear)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,clear)
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,started)
    mod:AddCallback(ModCallbacks.MC_PRE_TRIGGER_PLAYER_DEATH,died)
    mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED,lost)
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT,exitGame)
    mod:AddCallback(ModCallbacks.MC_POST_GAME_END,exitGame)
    mod:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD,function(_,unloaded) if unloaded==mod then exitGame() end end)
end
