-- Native-engine objects are test doubles. This suite proves Lua orchestration,
-- NOT the engine's Anti-Gravity + Brimstone visuals/timing or revive ordering.
local function eq(a, b, label)
    assert(a == b, (label or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
local names = {
    "MC_PRE_PLAYER_UPDATE", "MC_POST_PLAYER_UPDATE", "MC_INPUT_ACTION", "MC_POST_NPC_INIT",
    "MC_POST_ENTITY_REMOVE", "MC_POST_NEW_ROOM", "MC_POST_GAME_STARTED", "MC_PRE_GAME_EXIT",
    "MC_POST_EFFECT_INIT", "MC_PRE_EFFECT_UPDATE", "MC_POST_EFFECT_UPDATE", "MC_POST_LASER_INIT",
    "MC_POST_FIRE_BRIMSTONE", "MC_PRE_LASER_COLLISION", "MC_POST_LASER_COLLISION",
    "MC_ENTITY_TAKE_DMG", "MC_POST_ENTITY_TAKE_DMG", "MC_POST_ENTITY_KILL", "MC_NPC_UPDATE", "MC_PRE_PLAYER_REVIVE", "MC_POST_UPDATE",
    "MC_EXECUTE_CMD", "MC_POST_FIRE_TEAR", "MC_POST_FIRE_KNIFE", "MC_POST_FIRE_BONE_CLUB",
    "MC_POST_FIRE_SWORD", "MC_POST_FIRE_BOMB", "MC_POST_WEAPON_FIRE", "MC_POST_PLAYER_RENDER", "MC_EVALUATE_CACHE",
}
ModCallbacks = {}; for i, n in ipairs(names) do ModCallbacks[n] = i end
EntityType = { ENTITY_PLAYER=1, ENTITY_TEAR=2, ENTITY_BOMB=4, ENTITY_LASER=7, ENTITY_KNIFE=8, ENTITY_EFFECT=1000 }
EntityFlag = { FLAG_FRIENDLY=1, FLAG_CHARM=2, FLAG_NO_TARGET=4, FLAG_NO_STATUS_EFFECTS=8 }
EffectVariant = { BRIMSTONE_SWIRL=71 }
LaserVariant = { THICK_RED=1, THIN_RED=2 }
WeaponType = { WEAPON_BRIMSTONE=2 }
WeaponModifier = { BRIMSTONE=4, ANTI_GRAVITY=32 }
CacheFlag = { CACHE_WEAPON=1, CACHE_TEARFLAG=2, CACHE_FIREDELAY=4, CACHE_DAMAGE=8 }
TearFlags = { TEAR_WAIT=1<<17 }
DamageFlag = { DAMAGE_POISON_BURN=16, DAMAGE_FAKE=32 }
ButtonAction = { ACTION_SHOOTLEFT=4, ACTION_SHOOTRIGHT=5, ACTION_SHOOTUP=6, ACTION_SHOOTDOWN=7 }
InputHook = { IS_ACTION_PRESSED=0, IS_ACTION_TRIGGERED=1, GET_ACTION_VALUE=2 }
local vectorMT = {__add=function(a,b) return Vector(a.X+b.X,a.Y+b.Y) end}
Vector = setmetatable({Zero={X=0,Y=0}}, {__call=function(_,x,y) return setmetatable({X=x,Y=y},vectorMT) end})
RenderMode = {RENDER_NORMAL=0,RENDER_WATER_REFRACT=1,RENDER_WATER_REFLECT=2}
GetPtrHash = function(e) return e.InitSeed end
local nextSeed=0
local function entity(t,v)
    nextSeed=nextSeed+1
    local e={Type=t,Variant=v or 0,InitSeed=nextSeed,HitPoints=100,MaxHitPoints=100,Position=Vector(0,0),data={}}
    function e:Exists() return not self.removed end
    function e:HasMortalDamage() return (self.bufferedDamage or 0)>=self.HitPoints end
    function e:IsDead() return self.dead == true or self.HitPoints<=0 end
    function e:Remove() self.removed=true end
    function e:GetData() return self.data end
    function e:ToPlayer() if self.Type==1 then return self end end
    function e:ToNPC() if self.Type>=10 and self.Type<1000 then return self end end
    function e:IsActiveEnemy() return self:ToNPC()~=nil and not self.decor end
    function e:IsVulnerableEnemy() return not self.invulnerable end
    function e:HasEntityFlags(f) return ((self.flags or 0)&f)~=0 end
    return e
end
local function weapon(owner,t)
    local w={owner=owner,kind=t,mods=0,charge=0,delay=0,maxDelay=30,chargeWrites=0,delayWrites=0}
    function w:GetOwner() return self.owner end
    function w:GetWeaponType() return self.kind end
    function w:GetModifiers() return self.mods end
    function w:SetModifiers(n) self.mods=self.mods|n end -- 1.0.12a is OR, not assignment.
    function w:SetCharge(n) self.charge=n; self.chargeWrites=self.chargeWrites+1 end
    function w:GetCharge() return self.charge end
    function w:SetFireDelay(n) self.delay=n; self.delayWrites=self.delayWrites+1 end
    function w:GetMaxFireDelay() return self.maxDelay end
    return w
end
local function fixture()
    local callbacks,players,npcs,logs,sprites={},{},{},{},{}
    Sprite=function()
        local s={loads=0,updates=0,frames=0}
        function s:Load(path) self.loads=self.loads+1; self.path=path end
        function s:Play(anim) self.anim=anim; self.frames=0 end
        function s:SetFrame(anim,n) self.anim=anim; self.frames=n end
        function s:IsPlaying(anim) return self.anim==anim end
        function s:IsFinished(anim) return self.anim==anim and self.frames>=9 end
        function s:Update() self.updates=self.updates+1; self.frames=self.frames+1 end
        function s:Render(pos) self.rendered=pos end
        sprites[#sprites+1]=s; return s
    end
    local mod={}
    function mod:AddPriorityCallback(id,priority,fn,filter)
        callbacks[id]=callbacks[id] or {}; table.insert(callbacks[id],{fn=fn,filter=filter,priority=priority})
    end
    function mod:AddCallback(id,fn,filter) self:AddPriorityCallback(id,0,fn,filter) end
    local function call(name,...)
        local result
        for _,cb in ipairs(callbacks[ModCallbacks[name]] or {}) do
            local ret=cb.fn(mod,...); if ret~=nil then result=ret end
        end
        return result
    end
    local frame=0
    Game=function() return {GetFrameCount=function() return frame end,IsPaused=function() return false end,
        GetRoom=function() return {GetRenderMode=function() return 0 end} end} end
    Isaac={
        CreateWeapon=function(t,p) p.created=p.created+1; return weapon(p,t) end,
        DestroyWeapon=function(w) for slot,current in pairs(w.owner.weapons) do if current==w then w.owner.weapons[slot]=nil end end end,
        GetRoomEntities=function() return npcs end,
        FindByType=function() return {} end, -- A type lookup is not an all-NPC snapshot.
        WorldToScreen=function(v) return Vector(v.X+100,v.Y+200) end,
        DebugString=function(s) logs[#logs+1]=s end,
        ConsoleOutput=function(s) logs[#logs+1]=s end,
    }
    Input={GetActionValue=function(a,c) return players[c+1].input[a] or 0 end}
    local function player()
        local p=entity(1); p.baseDamage=3.5; p.Damage=3.5; p.baseTearFlags=4; p.TearFlags=4; p.ControllerIndex=#players; p.ControlsEnabled=true
        p.baseFireDelay=10; p.MaxFireDelay=10
        p.input={}; p.held=true; p.weapons={}; p.created=0; p.kills=0; p.canShoot=true
        function p:HasCollectible(id) return id==57 and self.held end
        function p:GetWeapon(slot) return self.weapons[slot] end
        function p:SetWeapon(w,slot) self.weapons[slot]=w end
        function p:EnableWeaponType(t,on) self.enabledWeaponType=on and t or nil end
        function p:CanShoot() return self.canShoot end
        function p:SetCanShoot(v) self.canShoot=v end
        function p:AddCacheFlags(flags) self.cacheRefresh=true; self.cacheFlags=(self.cacheFlags or 0)|flags end
        function p:EvaluateItems()
            local flags=self.cacheFlags or 0; self.cacheFlags=0
            if (flags & CacheFlag.CACHE_DAMAGE)~=0 then
                self.Damage=self.baseDamage; call('MC_EVALUATE_CACHE',self,CacheFlag.CACHE_DAMAGE)
            end
            if (flags & CacheFlag.CACHE_TEARFLAG)~=0 then
                self.TearFlags=self.baseTearFlags; call('MC_EVALUATE_CACHE',self,CacheFlag.CACHE_TEARFLAG)
            end
            if (flags & CacheFlag.CACHE_FIREDELAY)~=0 then
                self.MaxFireDelay=self.baseFireDelay; call('MC_EVALUATE_CACHE',self,CacheFlag.CACHE_FIREDELAY)
            end
            if (flags & CacheFlag.CACHE_WEAPON)~=0 then self.weapons[1]=weapon(self,1) end
        end
        function p:IsCoopGhost() return self.ghost==true end
        function p:Kill() self.kills=self.kills+1; self.dead=true end
        p.weapons[1]=weapon(p,1); players[#players+1]=p
        p:AddCacheFlags(CacheFlag.CACHE_DAMAGE|CacheFlag.CACHE_TEARFLAG|CacheFlag.CACHE_FIREDELAY); p:EvaluateItems()
        return p
    end
    dofile('avada_kedavra.lua')(mod,{ItemId=57,GetPlayers=function() return players end})
    local function npc()
        local n=entity(10); npcs[#npcs+1]=n; call('MC_POST_NPC_INIT',n); return n
    end
    -- Engine boundary double: the native weapon, not module callbacks, owns
    -- charge accumulation/reset. It is deliberately driven separately so the
    -- tests can detect Lua writes that override native progress.
    local function nativeStep(p,spawnNative,interpolated)
        local w=p:GetWeapon(1)
        if not w then return end
        w.maxDelay=p.MaxFireDelay
        local input={}
        for action=4,7 do
            local override=call('MC_INPUT_ACTION',p,InputHook.GET_ACTION_VALUE,action)
            input[action]=override==nil and (p.input[action] or 0) or override
        end
        local x,y=input[5]-input[4],input[7]-input[6]
        local shooting=x~=0 or y~=0
        call('MC_POST_WEAPON_FIRE',w,Vector(x,y),shooting,interpolated==true)
        if not interpolated then
            if shooting then
                w.charge=math.min(w.charge+1,w.maxDelay)
            else
                if w.charge>=w.maxDelay and spawnNative then spawnNative() end
                w.charge=0
            end
        end
    end
    local function tick(p,spawnNative)
        frame=frame+1
        call('MC_PRE_PLAYER_UPDATE',p)
        nativeStep(p,spawnNative)
        call('MC_POST_PLAYER_UPDATE',p)
        call('MC_POST_UPDATE')
    end
    local function release(p,spawnNative)
        tick(p) -- thirtieth held frame completes charging
        p.input={}
        tick(p,spawnNative) -- released frame emits
    end
    local function root(p)
        local e=entity(1000,71); e.SpawnerEntity=p; e.Parent=p
        call('MC_POST_EFFECT_INIT',e); return e
    end
    local function laser(r)
        call('MC_PRE_EFFECT_UPDATE',r)
        local e=entity(7,1); e.Parent=r; e.SpawnerEntity=r
        call('MC_POST_LASER_INIT',e); call('MC_POST_FIRE_BRIMSTONE',e)
        call('MC_POST_EFFECT_UPDATE',r); return e
    end
    local function remove(e) e:Remove(); call('MC_POST_ENTITY_REMOVE',e) end
    return {mod=mod,call=call,player=player,npc=npc,tick=tick,release=release,root=root,laser=laser,remove=remove,logs=logs,sprites=sprites,
        advance=function() frame=frame+1 end,nativeStep=nativeStep}
end

-- Different Lua wrappers for the same engine entity, deliberately without __eq.
local function alias(e) return setmetatable({}, {__index=e,__newindex=e}) end
local failures={}
local function check(label,body)
    local ok,err=pcall(body)
    print((ok and 'PASS: ' or 'FAIL: ')..label..(ok and '' or ': '..tostring(err)))
    if not ok then failures[#failures+1]=label..': '..tostring(err) end
end
local function shot(f,p)
    p.input[5]=1; for _=1,29 do f.tick(p) end
    local r; f.release(p,function() r=f.root(p) end)
    return r,f.laser(r)
end
local function hit(f,p,l,n,amount,flags,source)
    source=source or alias(p); flags=flags or 0
    f.call('MC_PRE_LASER_COLLISION',alias(l),alias(n))
    f.call('MC_ENTITY_TAKE_DMG',alias(n),amount,flags,{Entity=source},0)
    n.bufferedDamage=(n.bufferedDamage or 0)+amount
    f.call('MC_POST_ENTITY_TAKE_DMG',alias(n),amount,flags,{Entity=source},0)
    f.call('MC_POST_LASER_COLLISION',alias(l),alias(n))
end
local function finish(f,p,r,l)
    f.remove(r); f.remove(l); f.tick(p); f.tick(p)
end
check('native charge is preserved; Lua never drives ordinary charge or cooldown',function()
    local f=fixture(); local p=f.player(); f.npc(); p.input[5]=1; f.tick(p)
    local w=p:GetWeapon(1); w.charge=12.5
    local writes,delays=w.chargeWrites,w.delayWrites
    f.advance(); f.call('MC_PRE_PLAYER_UPDATE',p)
    f.call('MC_POST_WEAPON_FIRE',w,Vector(1,0),true,false)
    f.call('MC_POST_WEAPON_FIRE',w,Vector(1,0),true,true)
    f.call('MC_POST_PLAYER_UPDATE',p); f.call('MC_POST_UPDATE')
    eq(w:GetCharge(),12.5,'module must not reset, increment or force native charge')
    eq(w.chargeWrites,writes,'no charge writes while charging')
    eq(w.delayWrites,delays,'no cooldown writes while charging')
    f.call('MC_EXECUTE_CMD','avada_status','')
    assert(f.logs[#f.logs]:find('charge=12.50/30',1,true),'console accepts fractional native charge')
    w.charge=30; p.input={}; f.advance(); f.call('MC_PRE_PLAYER_UPDATE',p)
    f.call('MC_POST_WEAPON_FIRE',w,Vector(0,0),false,false)
    eq(w:GetCharge(),30,'release observer leaves charge intact for native Fire')
    eq(w.delayWrites,delays,'release observer does not force cooldown')
end)
check('combat input passes through unchanged including analog and trigger state',function()
    local f=fixture(); local p=f.player(); f.npc(); p.input[5]=0.37; p.input[6]=0.71; f.tick(p)
    for _,hook in pairs(InputHook) do
        for action=4,7 do eq(f.call('MC_INPUT_ACTION',p,hook,action),nil,'native input remains authoritative') end
    end
end)
check('native UI owns all charge rendering',function()
    local f=fixture(); local p=f.player(); f.npc(); p.input[5]=1
    for _=1,40 do f.tick(p); f.call('MC_POST_PLAYER_RENDER',p,Vector.Zero) end
    eq(#f.sprites,0,'no duplicate/custom chargebar Sprite')
end)
check('native charge parameter stays one second through stat changes and restores on removal',function()
    local f=fixture(); local p=f.player(); f.npc()
    for _,delay in ipairs({0.5,10,60}) do
        p.baseFireDelay=delay; p:AddCacheFlags(CacheFlag.CACHE_FIREDELAY); p:EvaluateItems()
        eq(p.MaxFireDelay,30,'fixed native charge threshold')
    end
    p.input[5]=1; for _=1,30 do f.tick(p) end
    eq(p:GetWeapon(1):GetCharge(),30,'engine accumulates one second of charge')
    p.held=false; f.tick(p); eq(p.MaxFireDelay,60,'removal restores current natural fire delay')
end)
check('full charge holds until release; aim changes keep charge',function()
    local f=fixture(); local p=f.player(); f.npc(); p.input[5]=1
    for _=1,120 do f.tick(p) end
    eq(f.mod.AvadaKedavra.Status(p).casts,0,'holding full charge must not cast')
    eq(f.mod.AvadaKedavra.Status(p).charge,30,'charge caps at full')
    eq(p:GetWeapon(1):GetCharge(),30,'native weapon retains full charge while held')
    p.input[5]=0; p.input[6]=1; f.tick(p)
    eq(f.mod.AvadaKedavra.Status(p).charge,30,'aim without losing full charge')
    eq(f.call('MC_INPUT_ACTION',p,InputHook.GET_ACTION_VALUE,6),nil,'new aim passes through to native weapon')
    p.input={}; local r
    f.tick(p,function() r=f.root(p) end)
    eq(f.mod.AvadaKedavra.Status(p).casts,1,'one cast on release')
    assert(r.CollisionDamage,'released attack has ownership')
    for _=1,40 do f.tick(p) end
    eq(f.mod.AvadaKedavra.Status(p).casts,1,'released key does not produce more casts')
end)
check('buffered lethal hit is credited after actual death, across wrappers',function()
    local f=fixture(); local p=f.player(); local n=f.npc(); local r,l=shot(f,p)
    hit(f,p,l,n,100)
    eq(n.HitPoints,100,'post damage still exposes old HP')
    finish(f,p,r,l)
    eq(p.kills,0,'await accepted lethal hit resolution even after beam removal')
    n.HitPoints=0; n.dead=true; n.bufferedDamage=0
    f.call('MC_POST_ENTITY_KILL',alias(n)); f.call('MC_NPC_UPDATE',alias(n))
    f.tick(p); f.tick(p); eq(p.kills,0,'confirmed direct kill saves caster')
end)
check('NPC update confirms buffered death without requiring kill callback',function()
    local f=fixture(); local p=f.player(); local n=f.npc(); local r,l=shot(f,p)
    hit(f,p,l,n,100); n.HitPoints=0; n.dead=true; n.bufferedDamage=0
    f.call('MC_NPC_UPDATE',alias(n)); finish(f,p,r,l)
    eq(p.kills,0,'post NPC update confirms actual death')
end)
check('nonlethal hit followed by teammate kill does not count',function()
    local f=fixture(); local p=f.player(); local q=f.player(); q.held=false
    local n=f.npc(); local r,l=shot(f,p); hit(f,p,l,n,10)
    f.call('MC_ENTITY_TAKE_DMG',n,100,0,{Entity=q},0); n.bufferedDamage=110
    f.call('MC_POST_ENTITY_TAKE_DMG',n,100,0,{Entity=q},0)
    n.dead=true; n.HitPoints=0; f.call('MC_POST_ENTITY_KILL',n)
    finish(f,p,r,l); eq(p.kills,1,'foreign killing blow cannot save the cast')
end)
check('already mortal target cannot be claimed by a later laser hit',function()
    local f=fixture(); local p=f.player(); local n=f.npc(); local r,l=shot(f,p)
    n.bufferedDamage=100; hit(f,p,l,n,100)
    n.dead=true; n.HitPoints=0; f.call('MC_POST_ENTITY_KILL',n)
    finish(f,p,r,l); eq(p.kills,1,'pre-existing fatal damage is not this cast kill')
end)
check('cancelled damage and surviving buffered hit do not count as kills',function()
    local f=fixture(); local p=f.player(); local n=f.npc(); local r,l=shot(f,p)
    f.call('MC_PRE_LASER_COLLISION',l,n)
    f.call('MC_ENTITY_TAKE_DMG',n,100,0,{Entity=p},0)
    f.call('MC_POST_LASER_COLLISION',l,n) -- cancelled, no accepted damage
    finish(f,p,r,l); eq(p.kills,1,'cancelled hit does not count')
    f=fixture(); p=f.player(); n=f.npc(); r,l=shot(f,p)
    hit(f,p,l,n,100); n.bufferedDamage=0 -- shield/phase survives
    f.call('MC_NPC_UPDATE',n); finish(f,p,r,l)
    eq(p.kills,1,'mortal buffer without actual death does not count')
end)
check('direct laser source and poison exclusion use accepted-hit evidence',function()
    local f=fixture(); local p=f.player(); local n=f.npc(); local r,l=shot(f,p)
    hit(f,p,l,n,100,0,alias(l)); n.dead=true; n.HitPoints=0
    f.call('MC_POST_ENTITY_KILL',n); finish(f,p,r,l); eq(p.kills,0,'laser source owns kill')
    f=fixture(); p=f.player(); n=f.npc(); r,l=shot(f,p)
    hit(f,p,l,n,100,DamageFlag.DAMAGE_POISON_BURN,alias(l)); n.dead=true; n.HitPoints=0
    f.call('MC_POST_ENTITY_KILL',n); finish(f,p,r,l); eq(p.kills,1,'poison kill is excluded')
end)
assert(#failures==0,table.concat(failures,'\n'))

-- A POST callback on the base Weapon is not a Brimstone emission receipt.
-- Clearing charge here or closing ownership here prevents the native output.
do
    local f=fixture(); local p=f.player(); f.npc(); p.input[5]=1
    for _=1,29 do f.tick(p) end
    f.release(p,function()
        local w=p:GetWeapon(1)
        eq(w:GetCharge(),w:GetMaxFireDelay(),'base Weapon callback preserves native full charge')
        local primary=entity(7,1); primary.SpawnerEntity=p
        f.call('MC_POST_LASER_INIT',primary)
        f.call('MC_POST_FIRE_BRIMSTONE',primary)
        eq(primary.removed,nil,'native primary survives the earlier base Weapon callback')
        eq(primary.CollisionDamage,17.5,'native primary retains cast damage after base Weapon callback')
        local swirl=entity(1000,71); swirl.Parent=primary; swirl.SpawnerEntity=primary
        f.call('MC_POST_EFFECT_INIT',swirl)
        eq(swirl.CollisionDamage,17.5,'native swirl inherits primary cast after base callback')
    end)
end

-- The old bridge erased charge and cast ownership at POST_PLAYER_UPDATE,
-- before a late native weapon pass. Interpolated passes must not double time.
local f=fixture(); local p=f.player(); f.npc(); p.input[5]=1
for _=1,29 do
    f.tick(p)
    local charged=f.mod.AvadaKedavra.Status(p).charge
    f.call('MC_PRE_PLAYER_UPDATE',p)
    eq(f.mod.AvadaKedavra.Status(p).charge,charged,'one charge tick per game frame')
    f.call('MC_POST_PLAYER_UPDATE',p)
    eq(f.call('MC_INPUT_ACTION',p,InputHook.GET_ACTION_VALUE,5),nil,'native input remains valid after player callback')
end
eq(#f.sprites,0,'native UI has no mod-rendered duplicate')
f.tick(p); p.input={}
f.advance(); f.call('MC_PRE_PLAYER_UPDATE',p)
f.call('MC_POST_PLAYER_UPDATE',p)
assert(p:GetWeapon(1):GetCharge()>0,'release charge survives post-player callback')
f.call('MC_POST_WEAPON_FIRE',p:GetWeapon(1),Vector(0,0),false,false)
local lateRoot=f.root(p)
eq(lateRoot.CollisionDamage,17.5,'late native root retains cast owner')
eq(f.mod.AvadaKedavra.Status(p).casts,1,'pending cast not discarded before native fire')
f.call('MC_POST_UPDATE')
eq(#f.sprites,0,'no custom chargebar resources')
f.call('MC_POST_NEW_ROOM')
f.call('MC_POST_PLAYER_RENDER',p,Vector(0,0))
eq(f.mod.AvadaKedavra.Status(p).charge,0,'room cancels charge')

f=fixture(); p=f.player()
p.input[5]=1
for _=1,60 do f.tick(p) end
eq(f.mod.AvadaKedavra.Status(p).charge,0,'empty room')
eq(p.kills,0,'empty room cannot fail')
local n=f.npc()
for i=1,29 do f.tick(p); eq(f.mod.AvadaKedavra.Status(p).charge,i,'fixed charge') end
local r
p.baseDamage=7; p:AddCacheFlags(CacheFlag.CACHE_DAMAGE); p:EvaluateItems()
f.release(p,function() r=f.root(p) end)
eq(f.mod.AvadaKedavra.Status(p).charge,0,'fire resets charge')
eq(r.CollisionDamage,35,'live cached damage, multiplied only once')
eq(p.created,1,'weapon not rebuilt every frame')
eq(p:GetWeapon(1):GetModifiers(),32,'native antigravity modifier')
eq(p.enabledWeaponType,2,'native player weapon type enabled as well as slot bound')
local l=f.laser(r); eq(l.CollisionDamage,35,'native child damage')
f.call('MC_PRE_LASER_COLLISION',l,n)
n.HitPoints=0
f.call('MC_POST_ENTITY_TAKE_DMG',n,35,0,{Entity=p},0)
f.call('MC_POST_ENTITY_KILL',n)
f.call('MC_POST_LASER_COLLISION',l,n)
f.remove(r); f.remove(l); f.tick(p); f.tick(p)
eq(p.kills,0,'direct native kill succeeds')

-- A friendly NPC and damage-over-time must not count, even with a cast source.
f=fixture(); p=f.player(); n=f.npc(); p.input[5]=1
for _=1,29 do f.tick(p) end
f.release(p,function() r=f.root(p) end); l=f.laser(r)
local ally=f.npc(); ally.flags=1; ally.HitPoints=0
f.call('MC_POST_ENTITY_TAKE_DMG',ally,35,0,{Entity=l},0)
n.HitPoints=0
f.call('MC_POST_ENTITY_TAKE_DMG',n,35,DamageFlag.DAMAGE_POISON_BURN,{Entity=l},0)
f.remove(l); f.remove(r); f.tick(p); f.tick(p)
eq(p.kills,1,'friendly and status kills do not count')

-- Cancel controls, damage independence, no hidden fire-rate dependency.
f=fixture(); p=f.player(); n=f.npc(); p.input[5]=1
for _=1,12 do f.tick(p) end
f.call('MC_POST_ENTITY_TAKE_DMG',p,1,0,{Entity=n},0)
eq(f.mod.AvadaKedavra.Status(p).charge,12,'damage does not cancel')
p.input[5]=0; f.tick(p); eq(f.mod.AvadaKedavra.Status(p).charge,0,'release cancels')
p.input[5]=1; f.tick(p); p.input[5]=0; p.input[6]=1; f.tick(p)
eq(f.mod.AvadaKedavra.Status(p).charge,2,'direction change keeps native-style charge')
f.tick(p); f.call('MC_POST_NEW_ROOM'); eq(f.mod.AvadaKedavra.Status(p).charge,0,'room reset')
n.invulnerable=true; f.tick(p); eq(f.mod.AvadaKedavra.Status(p).charge,0,'invulnerable not combat')
n.invulnerable=false; n.flags=1; f.tick(p); eq(f.mod.AvadaKedavra.Status(p).charge,0,'friendly excluded')
n.flags=0; n.boss=true; f.tick(p); eq(f.mod.AvadaKedavra.Status(p).charge,1,'boss included')
n.dead=true; f.tick(p); eq(f.mod.AvadaKedavra.Status(p).charge,0,'clear cancels without cast')
eq(p.kills,0)

-- Two owners, concurrent casts, no revive leakage to a teammate.
f=fixture(); p=f.player(); local q=f.player(); n=f.npc(); p.input[5]=1
q.held=false
for _=1,29 do f.tick(p) end
f.release(p,function() r=f.root(p) end); l=f.laser(r)
p.input[5]=1
for _=1,29 do f.tick(p) end
local r2; f.release(p,function() r2=f.root(p) end)
eq(f.mod.AvadaKedavra.Status(p).casts,2,'casts are independently owned, no busy cap')
f.call('MC_POST_ENTITY_TAKE_DMG',n,100,0,{Entity=q},0); n.dead=true; f.call('MC_POST_ENTITY_KILL',n)
f.remove(r); f.remove(l); f.tick(p); f.tick(p)
eq(p.kills,1,'foreign kill does not save failed cast')
eq(q.kills,0,'teammate remains alive')
eq(f.call('MC_PRE_PLAYER_REVIVE',p),false,'owner revival veto')
eq(f.call('MC_PRE_PLAYER_REVIVE',q),nil,'teammate revive preserved')
f.tick(p); eq(p.kills,1,'failure only once')
p.ghost=true; f.tick(p); eq(f.call('MC_PRE_PLAYER_REVIVE',p),nil,'ghost clears temporary veto')
f.call('MC_POST_GAME_STARTED',false); eq(f.call('MC_PRE_PLAYER_REVIVE',p),nil,'new run reset')

-- Wrong engine output is a diagnostic, not a fake laser or a punishment.
f=fixture(); p=f.player(); n=f.npc(); p.input[5]=1
for _=1,30 do f.tick(p) end
p.input={}; for _=1,3 do f.tick(p) end
eq(p.kills,0,'failed native emission cannot falsely kill player')
assert(#f.logs>0,'missing native emission must be visible in diagnostics')
p.held=false; f.tick(p); assert(p.cacheRefresh,'loss restores native weapon cache')
eq(p.enabledWeaponType,nil,'loss clears the borrowed weapon type before native cache restore')

-- Weapon acquisition order: only the holder's weapon is replaced.
f=fixture(); p=f.player(); q=f.player(); q.held=false; n=f.npc()
p.weapons[1]=weapon(p,5); p.weapons[2]=weapon(p,4)
f.tick(p); eq(p.weapons[1]:GetWeaponType(),2); eq(p.weapons[2],nil)
p.weapons[1]=weapon(p,3); f.tick(p); eq(p.weapons[1]:GetWeaponType(),2)
f.tick(q); eq(q.weapons[1]:GetWeaponType(),1)
local tear=entity(2); tear.SpawnerEntity=p; f.call('MC_POST_FIRE_TEAR',tear); eq(tear.removed,true)
local other=entity(2); other.SpawnerEntity=q; f.call('MC_POST_FIRE_TEAR',other); eq(other.removed,nil)

-- A swirl/laser INIT can precede native assignment of its owner. No early
-- deletion and no loss of cast damage when the initialized callbacks follow.
f=fixture(); p=f.player(); n=f.npc(); p.input[5]=1
for _=1,29 do f.tick(p) end
f.tick(p); p.input={}
f.advance(); f.call('MC_PRE_PLAYER_UPDATE',p)
r=entity(1000,71); f.call('MC_POST_EFFECT_INIT',r)
f.call('MC_POST_PLAYER_UPDATE',p)
f.call('MC_POST_WEAPON_FIRE',p:GetWeapon(1),Vector(0,0),false,false)
r.SpawnerEntity=p
f.call('MC_PRE_EFFECT_UPDATE',r)
eq(r.CollisionDamage,17.5,'late owner assignment adopted by effect update')
l=entity(7,1); f.call('MC_POST_LASER_INIT',l)
eq(l.removed,nil,'do not delete uninitialized native laser')
l.SpawnerEntity=p
f.call('MC_POST_FIRE_BRIMSTONE',l)
eq(l.CollisionDamage,17.5,'native update context identifies child laser')
eq(l.removed,nil,'native brimstone child survives')
f.call('MC_POST_EFFECT_UPDATE',r); f.call('MC_POST_UPDATE')
p.removed=true; f.call('MC_POST_UPDATE')
eq(r.removed,true,'owner disappearing removes owned swirl')
eq(l.removed,true,'owner disappearing removes owned laser')

-- Primary laser and swirl can initialize in either order.
f=fixture(); p=f.player(); f.npc(); p.input[5]=1
for _=1,29 do f.tick(p) end
f.tick(p); p.input={}
f.advance(); f.call('MC_PRE_PLAYER_UPDATE',p)
f.call('MC_POST_WEAPON_FIRE',p:GetWeapon(1),Vector(0,0),false,false)
l=entity(7,1); l.SpawnerEntity=p
f.call('MC_POST_LASER_INIT',l); f.call('MC_POST_FIRE_BRIMSTONE',l)
eq(l.removed,nil,'native release output is not deleted before swirl initialization')
r=entity(1000,71); r.Parent=l; r.SpawnerEntity=l
f.call('MC_POST_EFFECT_INIT',r)
eq(r.CollisionDamage,17.5,'swirl can inherit its cast from native laser parent')
f.call('MC_POST_WEAPON_FIRE',p:GetWeapon(1),Vector(0,0),false,false)

-- Each player's native weapon keeps its own charge and input.
f=fixture(); p=f.player(); q=f.player(); f.npc(); p.input[5]=1; q.input[6]=1
for _=1,10 do
    f.advance(); f.call('MC_PRE_PLAYER_UPDATE',p); f.call('MC_PRE_PLAYER_UPDATE',q)
    f.nativeStep(p); f.nativeStep(q); f.call('MC_POST_UPDATE')
end
eq(#f.sprites,0,'both players use native charge UI')
eq(f.mod.AvadaKedavra.Status(q).charge,10,'second player charge')
p.input[5]=0; f.advance(); f.call('MC_PRE_PLAYER_UPDATE',p); f.call('MC_PRE_PLAYER_UPDATE',q)
f.nativeStep(p); f.nativeStep(q)
eq(f.mod.AvadaKedavra.Status(p).charge,0,'first player cancels')
eq(f.mod.AvadaKedavra.Status(q).charge,11,'first player does not cancel teammate')
-- Diagnostic state survives releasing the key to open the console, so a
-- missing chargebar can be distinguished from a failed native emission.
f=fixture(); p=f.player(); p.input[5]=1
f.tick(p); eq(f.mod.AvadaKedavra.Status(p).phase,'no_enemy','reports combat gate')
f.npc(); for _=1,5 do f.tick(p) end
p.input[5]=0; f.tick(p)
eq(f.mod.AvadaKedavra.Status(p).phase,'idle','reports released input')
eq(f.mod.AvadaKedavra.Status(p).peakCharge,5,'console retains evidence of earlier charging')
p.ControlsEnabled=false; f.tick(p)
eq(f.mod.AvadaKedavra.Status(p).phase,'controls_disabled','reports disabled controls')
f.call('MC_POST_NEW_ROOM')
eq(f.mod.AvadaKedavra.Status(p).peakCharge,0,'room clears diagnostic charge peak')
-- September 16 user repros. These model the confirmed native boundary,
-- not the engine animation: Laser::Update tests TEAR_WAIT, not Weapon modifiers.
local regressionErrors={}
local function regression(label,body)
    local ok,err=pcall(body)
    if ok then print('PASS: '..label) else
        regressionErrors[#regressionErrors+1]=label..': '..tostring(err)
        print('FAIL: '..regressionErrors[#regressionErrors])
    end
end
regression('panel damage cache, repeat evaluation, pickup, removal and co-op',function()
    local f=fixture(); local p=f.player(); local q=f.player()
    eq(p.Damage,17.5,'3.5 base is 17.5 on the actual player stat')
    p:AddCacheFlags(CacheFlag.CACHE_DAMAGE); p:EvaluateItems(); eq(p.Damage,17.5,'cache does not compound')
    p.baseDamage=7; p:AddCacheFlags(CacheFlag.CACHE_DAMAGE); p:EvaluateItems(); eq(p.Damage,35,'later stat changes included')
    f.call('MC_EVALUATE_CACHE',p,CacheFlag.CACHE_FIREDELAY); eq(p.Damage,35,'unrelated cache leaves damage alone')
    q.held=false; q:AddCacheFlags(CacheFlag.CACHE_DAMAGE|CacheFlag.CACHE_TEARFLAG); q:EvaluateItems()
    eq(q.Damage,3.5,'non-holder teammate unaffected'); eq(q.TearFlags,4,'teammate native flags retained')
    f.tick(p); p.held=false; f.tick(p)
    eq(p.Damage,7,'removal restores damage'); eq(p.TearFlags,4,'removal restores previous flags')
end)
regression('native TEAR_WAIT branch, delayed swirl and missed cast death',function()
    local f=fixture(); local p=f.player(); f.npc(); p.input[5]=1
    for _=1,29 do f.tick(p) end
    local l,r
    f.release(p,function()
        l=entity(7,1); l.SpawnerEntity=p; l.TearFlags=p.TearFlags
        f.call('MC_POST_LASER_INIT',l); f.call('MC_POST_FIRE_BRIMSTONE',l)
    end)
    assert((l.TearFlags & TearFlags.TEAR_WAIT)~=0,'native laser requires TEAR_WAIT to create its swirl')
    eq(l.CollisionDamage,p.Damage,'projectile uses the panel value without a second multiplier')
    f.tick(p); eq(p.kills,0,'no death before delayed native laser update')
    -- The real native update consumes this flag, creates effect 71 and parents
    -- the original laser to it. Do not emulate this in production Lua.
    l.TearFlags=l.TearFlags & ~TearFlags.TEAR_WAIT
    r=f.root(p); l.Parent=r; f.call('MC_PRE_EFFECT_UPDATE',r); f.call('MC_POST_EFFECT_UPDATE',r)
    for _=1,6 do f.tick(p) end
    eq(p.kills,0,'wait for full native lifetime')
    f.remove(r); f.tick(p); eq(p.kills,0,'surviving native laser delays settlement')
    f.remove(l); f.tick(p); f.tick(p)
    eq(p.kills,1,'missed completed cast kills caster once')
    eq(f.call('MC_PRE_PLAYER_REVIVE',p),false,'missed cast cannot revive')
end)
regression('emitted laser cannot be cancelled as missing output',function()
    local f=fixture(); local p=f.player(); f.npc(); p.input[5]=1
    for _=1,29 do f.tick(p) end
    local l
    f.release(p,function()
        l=entity(7,1); l.SpawnerEntity=p
        f.call('MC_POST_FIRE_BRIMSTONE',l)
    end)
    for _=1,6 do f.tick(p) end
    eq(l.removed,nil,'do not truncate a confirmed native attack without a swirl')
    eq(p.kills,0,'live laser has not finished')
    f.remove(l); f.tick(p); f.tick(p)
    eq(p.kills,1,'confirmed output still settles without a swirl receipt')
end)
assert(#regressionErrors==0,table.concat(regressionErrors,'\n'))
print('avada_kedavra_behavior_test: PASS (Lua orchestration only; native game acceptance is separate)')
