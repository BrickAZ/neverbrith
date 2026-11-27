-- Extracted engine double; original behavior assertions remain in the test.
return function()
-- Native-engine objects are test doubles. This suite proves Lua orchestration,
-- NOT the engine's Anti-Gravity + Brimstone visuals/timing or revive ordering.
function include(name) return dofile(name:gsub("%.", "/") .. ".lua") end
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
    return {players=players,npcs=npcs,mod=mod,call=call,player=player,npc=npc,tick=tick,release=release,root=root,laser=laser,remove=remove,logs=logs,sprites=sprites,
        advance=function() frame=frame+1 end,nativeStep=nativeStep}
end

    return {
        eq = eq,
        entity = entity,
        weapon = weapon,
        fixture = fixture,
    }
end
