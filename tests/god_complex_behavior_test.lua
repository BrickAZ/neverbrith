-- Engine callbacks are simulated; this does not certify native combat/rendering.
local function eq(a,b,msg) assert(a==b,(msg or 'mismatch')..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b) assert(math.abs(a-b)<0.00001,tostring(a)..' ~= '..tostring(b)) end
local function fixture(saved)
    local f={frame=10,roomId=1,floor=1,entities={},players={},callbacks={},sprites={},spawned={},logs={},saved=saved or {}}
    ModCallbacks=setmetatable({}, {__index=function(t,k) rawset(t,k,k);return k end})
    EntityType={ENTITY_PLAYER=1,ENTITY_TEAR=2,ENTITY_FAMILIAR=3,ENTITY_BOMB=4,ENTITY_LASER=7,ENTITY_KNIFE=8,ENTITY_PROJECTILE=9,ENTITY_EFFECT=1000,
        ENTITY_SLOTH=46,ENTITY_LUST=47,ENTITY_WRATH=48,ENTITY_GLUTTONY=49,ENTITY_GREED=50,ENTITY_ENVY=51,ENTITY_PRIDE=52}
    CacheFlag={CACHE_DAMAGE=1,CACHE_FIREDELAY=2,CACHE_SPEED=4,CACHE_TEARFLAG=8}
    TearFlags={TEAR_PIERCING=2};EntityFlag={FLAG_FRIENDLY=1,FLAG_CHARM=2}
    DamageFlag={DAMAGE_FIRE=2,DAMAGE_EXPLOSION=4,DAMAGE_LASER=8,DAMAGE_ACID=16,DAMAGE_POISON_BURN=1<<15,DAMAGE_FAKE=1<<21}
    ProjectileVariant={PROJECTILE_NORMAL=0};ProjectileFlags={CANT_HIT_PLAYER=1<<31,HIT_ENEMIES=1<<7}
    DamageFlag.DAMAGE_BOOGER=1<<22;DamageFlag.DAMAGE_CLONES=1<<8
    UseFlag={USE_CARBATTERY=1<<5};RoomType={ROOM_DEFAULT=1,ROOM_BOSS=5}
    RenderMode={RENDER_NULL=0,RENDER_NORMAL=1,RENDER_WATER_REFLECT=5}
    local mt={__add=function(a,b)return Vector(a.X+b.X,a.Y+b.Y)end,__sub=function(a,b)return Vector(a.X-b.X,a.Y-b.Y)end}
    Vector=setmetatable({}, {__call=function(_,x,y)return setmetatable({X=x,Y=y},mt)end});Vector.Zero=Vector(0,0)
    EntityRef=function(e)return {Entity=e}end;GetPtrHash=function(e)return e.ptr or e.InitSeed end
    local room={IsClear=function()return f.clear or false end,GetFrameCount=function()return f.roomFrame or 10 end,
        GetType=function()return f.roomType or 1 end,GetRenderMode=function()return f.renderMode or 0 end}
    local level={GetStage=function()return f.floor end,GetStageType=function()return 0 end,GetDungeonPlacementSeed=function()return f.floor*10 end,
        GetDimension=function()return 0 end,GetCurrentRoomDesc=function()return {ListIndex=f.roomId,SafeGridIndex=f.roomId,SpawnSeed=f.roomId+99}end}
    Game=function()return {GetRoom=function()return room end,GetLevel=function()return level end,GetFrameCount=function()return f.frame end,IsPaused=function()return f.paused end}end
    function f:entity(kind,owner)
        local e={Type=kind,Variant=0,SubType=0,InitSeed=#self.entities+100,Position=Vector(0,0),Size=12,HitPoints=1000,SpawnerEntity=owner,flags=0,data={},ProjectileFlags=0}
        function e:Exists()return not self.removed end
        function e:IsDead()return self.dead or false end
        function e:HasMortalDamage()return self.mortal or false end
        function e:ToPlayer()if self.Type==1 then return self end end
        function e:ToNPC()if self.Type>=10 and self.Type<1000 then return self end end
        function e:ToProjectile()if self.Type==9 then return self end end
        function e:IsEnemy()return self:ToNPC()~=nil and not self.notEnemy end
        function e:IsActiveEnemy()return self:IsEnemy() end
        function e:IsVulnerableEnemy()return self:IsEnemy() and not self.invincible end
        function e:IsBoss()return self.boss or false end
        function e:HasEntityFlags(flag)return (self.flags & flag)~=0 end
        function e:GetData()return self.data end
        function e:Remove()self.removed=true;f:call('MC_POST_ENTITY_REMOVE',self)end
        function e:TakeDamage(amount,flags,src,count)return f:damage(self,amount,flags,src,count)end
        function e:AddTearFlags(flags)self.TearFlags=(self.TearFlags or 0)|flags end
        function e:ClearTearFlags(flags)self.TearFlags=(self.TearFlags or 0)&~flags end
        self.entities[#self.entities+1]=e;return e
    end
    function f:player(seed)
        local p=self:entity(1);p.InitSeed=seed;p.ControllerIndex=#self.players;p.baseDamage=10;p.baseSpeed=1;p.baseDelay=10;p.Damage=10;p.MoveSpeed=1;p.MaxFireDelay=10;p.TearFlags=0;p.item=true;p.canShoot=true
        function p:IsCoopGhost()return self.ghost or false end
        function p:AreControlsEnabled()return not self.unsafe end
        function p:HasCollectible()return self.item end
        function p:CanShoot()return self.canShoot end
        function p:SetCanShoot(v)self.canShoot=v end
        function p:AddCacheFlags()end
        function p:EvaluateItems()
            self.Damage=self.baseDamage;self.MoveSpeed=self.baseSpeed;self.MaxFireDelay=self.baseDelay;self.TearFlags=self.baseTearFlags or 0
            for _,flag in pairs(CacheFlag)do f:call('MC_EVALUATE_CACHE',self,flag)end
        end
        p.draws={};p.roll=0
        function p:GetCollectibleRNG(id)
            eq(id,992);return {RandomInt=function(_,n)p.draws[#p.draws+1]=n;return p.roll%n end}
        end
        self.players[#self.players+1]=p;return p
    end
    -- Native SpawnerEntity/Parent/EntityRef expose Entity, not EntityPlayer.
    -- Deliberately omit all player-only methods; ToPlayer is the only bridge.
    function f:basePlayer(p)
        local e={Type=1,InitSeed=p.InitSeed,ptr=GetPtrHash(p)}
        function e:Exists()return p:Exists()end
        function e:IsDead()return p:IsDead()end
        function e:HasMortalDamage()return p:HasMortalDamage()end
        function e:ToNPC()return nil end
        function e:ToPlayer()return p end
        return e
    end
    Isaac={GetRoomEntities=function()return f.entities end,
        WorldToScreen=function(p)
            if f.badConversion then error('camera unavailable')end
            return Vector(p.X*(f.cameraX or 2)+(f.cameraOffsetX or 7),p.Y*(f.cameraY or 2)+(f.cameraOffsetY or 11))
        end,
        Spawn=function(kind,var,sub,pos,vel,owner)local e=f:entity(kind,owner);e.Variant=var;e.SubType=sub;e.Position=pos;e.Velocity=vel;f.spawned[#f.spawned+1]=e;return e end}
    Sprite=function()
        if f.brokenVisual then error('missing PNG')end
        local s={age=0,Scale=Vector(1,1)};function s:Load(path)self.path=path end;function s:Play(a)self.animation=a;self.age=0 end
        function s:GetAnimation()return self.animation end;function s:Update()self.age=self.age+1 end
        function s:GetFrame()return self.age%24 end
        function s:IsFinished(a)return a=='Judgment' and self.age>=12 end
        function s:Render(pos)self.position=pos;self.draws=(self.draws or 0)+1 end
        f.sprites[#f.sprites+1]=s;return s
    end
    function f:call(name,...)
        local result
        for _,c in ipairs(self.callbacks[name] or {})do
            local actor=select(1,...)
            if not c.filter or c.filter==actor or (type(actor)=='table' and actor.Type==c.filter) then
                local r=c.fn(self.mod,...);if r==false then return false end;if r~=nil then result=r end
            end
        end
        return result
    end
    function f:damage(e,amount,flags,src,count,extra,mode)
        flags=flags or 0;src=src or EntityRef(nil)
        if self:call('MC_ENTITY_TAKE_DMG',e,amount,flags,src,count or 0,extra)==false then return false end
        if mode=='cancel' or e.invincible then return false end
        e.hits=e.hits or {};e.hits[#e.hits+1]={amount=amount,source=src.Entity,frame=self.frame}
        if mode=='buffer' then e.mortal=true else e.HitPoints=e.HitPoints-amount;e.mortal=e.HitPoints<=0 end
        if mode=='syncDeath' then e.dead=true;self:call('MC_POST_NPC_DEATH',e)end
        self:call('MC_POST_ENTITY_TAKE_DMG',e,amount,flags,src,count or 0,extra)
        if e.HitPoints<=0 and not e.dead then e.dead=true;self:call('MC_POST_NPC_DEATH',e)end
        return true
    end
    function f:tick(n)
        for _=1,n do
            self.frame=self.frame+1
            for _,p in ipairs(self.players)do self:call('MC_PRE_PLAYER_UPDATE',p);self:call('MC_POST_PLAYER_UPDATE',p)end
            self:call('MC_POST_UPDATE')
        end
    end
    function f:use(p,flags)return self:call('MC_USE_ITEM',992,{RandomInt=function()error('wrong RNG')end},p,flags or 0,0,0)end
    f.mod={}
    function f.mod:AddPriorityCallback(id,priority,fn,filter)
        f.callbacks[id]=f.callbacks[id] or {};table.insert(f.callbacks[id],{fn=fn,filter=filter,priority=priority})
        table.sort(f.callbacks[id],function(a,b)return a.priority<b.priority end)
    end
    function f.mod:AddCallback(id,fn,filter)self:AddPriorityCallback(id,0,fn,filter)end
    f:player(1);f:player(2);f:entity(10)
    include = function(name) return dofile((name:gsub('%.','/'))..'.lua') end
    local file=io.open('god_complex.lua','r');assert(file,'God Complex module missing');file:close()
    dofile('god_complex.lua')(f.mod,{ItemId=992,GetPlayers=function()return f.players end,GetSaveRoot=function()return f.saved end,
        GetCurrentRunSeed=function()return f.runSeed or 'run1' end,Save=function()f.saves=(f.saves or 0)+1 end,DebugLog=function(s)f.logs[#f.logs+1]=s end})
    f:call('MC_POST_GAME_STARTED',saved~=nil)
    return f
end
local tests={}
function tests.invalid_use_has_no_side_effects()
    local f=fixture();local p=f.players[1]
    for _,field in ipairs({'clear','paused'})do f[field]=true;eq(f:use(p).Discharge,false);f[field]=false end
    p.unsafe=true;eq(f:use(p).Discharge,false);p.unsafe=false
    p.dead=true;eq(f:use(p).Discharge,false);p.dead=false
    f.entities[3].removed=true;eq(f:use(p).Discharge,false)
    eq(#p.draws,0);eq(#f.sprites,0);eq(f.saves or 0,0)
end
function tests.rng_first_and_exclude_only_previous_coop()
    for first=0,2 do
        local f=fixture();local p,q=table.unpack(f.players);p.roll=first
        eq(f:use(p).Discharge,true);eq(p.draws[1],3)
        eq(f:use(p).Discharge,false);eq(f:use(p,UseFlag.USE_CARBATTERY).Discharge,false);eq(#p.draws,1)
        eq(f:use(q).Discharge,true);eq(q.draws[1],3)
        f:call('MC_POST_NEW_ROOM');f:tick(1)
        p.roll=0;eq(f:use(p).Discharge,true);eq(p.draws[2],2)
        local second=f.saved.godComplex.players['1:0'];assert(second~=({'Solar','War','Eye'})[first+1])
        f:call('MC_POST_NEW_LEVEL');f:tick(1);p.roll=0;f:use(p);eq(p.draws[3],2)
    end
    local seen={}
    for roll=0,1 do local f=fixture({godComplex={run='run1',players={['1:0']='Solar'}}});f.players[1].roll=roll;f:use(f.players[1]);seen[f.saved.godComplex.players['1:0']]=true end
    assert(seen.War and seen.Eye)
end
function tests.lifecycle_retains_history_and_continue_clears_activity()
    local f=fixture();local p=f.players[1];f:use(p)
    f:call('MC_PRE_TRIGGER_PLAYER_DEATH',p);eq(p.MoveSpeed,1);eq(f.saved.godComplex.players['1:0'],'Solar')
    p.item=false;f:tick(1);p.item=true;f:call('MC_POST_NEW_LEVEL');eq(f.saved.godComplex.players['1:0'],'Solar')
    local g=fixture(f.saved);eq(g.players[1].MoveSpeed,1);g:use(g.players[1]);eq(g.players[1].draws[1],2)
    g:call('MC_POST_GAME_STARTED',false);eq(next(g.saved.godComplex.players),nil)
end
function tests.solar_cadence_radius_and_live_stats()
    local f=fixture();local p,q=table.unpack(f.players);local e=f.entities[3];e.Position=Vector(95,0)
    local outside=f:entity(10);outside.Position=Vector(96,0)
    f:use(p);near(p.MoveSpeed,0.55);eq(q.MoveSpeed,1)
    f:tick(5);eq(#e.hits,1);eq(e.hits[1].amount,8);eq(e.hits[1].source,p);eq(outside.hits,nil)
    f:call('MC_POST_UPDATE');eq(#e.hits,1)
    p.baseDamage=20;p.baseSpeed=1.5;p:EvaluateItems();near(p.MoveSpeed,0.825)
    f:tick(5);eq(e.hits[2].amount,16)
    f:tick(229);near(p.MoveSpeed,0.825);f:tick(1);eq(p.MoveSpeed,1.5)
end
function tests.solar_projectiles_and_scoped_shoot_gate()
    local f=fixture();local p,q=table.unpack(f.players);local enemy=f.entities[3]
    local bullet=f:entity(9,enemy);bullet.Position=Vector(72,0)
    local far=f:entity(9,enemy);far.Position=Vector(73,0)
    local friendly=f:entity(9,q);local odd=f:entity(9,enemy);odd.Variant=1
    local bomb=f:entity(4,p);local laser=f:entity(7,p)
    f:use(p);f:call('MC_PRE_PLAYER_UPDATE',p);eq(p.canShoot,false);eq(q.canShoot,true)
    f:call('MC_POST_PLAYER_UPDATE',p);eq(p.canShoot,true)
    f:tick(1);eq(bullet.removed,true);eq(far.removed,nil);eq(friendly.removed,nil);eq(odd.removed,nil);eq(bomb.removed,nil);eq(laser.removed,nil)
    p.canShoot=false;f:call('MC_PRE_PLAYER_UPDATE',p);f:call('MC_POST_NEW_ROOM');eq(p.canShoot,false)
end
function tests.war_cache_lifetime_and_no_stale_piercing()
    local f=fixture();local p=f.players[1];p.roll=1;f:use(p);eq(p.Damage,20);eq(p.MaxFireDelay,6);eq(p.TearFlags,2)
    local tear=f:entity(2,p);tear.TearFlags=p.TearFlags;f:call('MC_POST_FIRE_TEAR',tear)
    p.baseDamage=25;p.baseDelay=5;p:EvaluateItems();eq(p.Damage,50);eq(p.MaxFireDelay,3)
    f:tick(240);eq(p.Damage,25);eq(p.MaxFireDelay,5);eq(p.TearFlags,0);eq(tear.TearFlags,0)
end
function tests.war_direct_death_once_and_miniboss()
    for _,kind in ipairs({10,46,47,48,49,50,51,52})do
        local f=fixture();local p=f.players[1];p.roll=1;f:use(p);local e=f.entities[3];e.Type=kind;e.boss=kind~=10;e.Variant=kind==51 and 30 or 0;e.HitPoints=10
        local tear=f:entity(2,p);f:damage(e,20,0,EntityRef(tear));eq(#f.spawned,8)
        for _,b in ipairs(f.spawned)do eq(b.Type,9);eq(b.Variant,0);near(math.sqrt(b.Velocity.X^2+b.Velocity.Y^2),5);eq(b.ProjectileFlags,0)end
        f:call('MC_POST_NPC_DEATH',e);e:Remove();eq(#f.spawned,8)
    end
end
function tests.war_rejects_indirect_boss_split_cancelled_and_stale_hits()
    for _,case in ipairs({'bomb','familiar','ally','effect','poison','fire','other','boss','split','cancel','remove','morph','phase','expired'})do
        local f=fixture();local p,q=table.unpack(f.players);p.roll=1;f:use(p);local e=f.entities[3];e.HitPoints=1
        local src=f:entity(2,p);local flags=0;local mode
        if case=='bomb'then src=f:entity(4,p) elseif case=='familiar'then src=f:entity(2,f:entity(3,p))
        elseif case=='ally'then local a=f:entity(10,p);a.flags=1;src=f:entity(2,a)
        elseif case=='effect'then src=f:entity(1000,p) elseif case=='poison'then flags=DamageFlag.DAMAGE_POISON_BURN
        elseif case=='fire'then flags=DamageFlag.DAMAGE_FIRE elseif case=='other'then src.SpawnerEntity=q
        elseif case=='boss'then e.boss=true elseif case=='split'then e.Type=51;e.Variant=20;e.boss=true
        elseif case=='cancel'then mode='cancel' elseif case=='remove'or case=='morph'or case=='phase'then mode='buffer'
        elseif case=='expired'then f:tick(240)end
        f:damage(e,10,flags,EntityRef(src),0,nil,mode)
        if case=='remove'then e:Remove() elseif case=='morph'then e.Type=11;e.dead=true;f:call('MC_POST_NPC_DEATH',e)
        elseif case=='phase'then e.mortal=false;e.HitPoints=100;f:call('MC_NPC_UPDATE',e);e.dead=true;f:call('MC_POST_NPC_DEATH',e)end
        eq(#f.spawned,0,case)
    end
end
function tests.war_buffered_and_synchronous_deaths()
    for _,mode in ipairs({'buffer','syncDeath'})do
        local f=fixture();local p=f.players[1];p.roll=1;f:use(p);local e=f.entities[3];e.HitPoints=1
        f:damage(e,10,0,EntityRef(f:entity(2,p)),0,nil,mode)
        if mode=='buffer'then eq(#f.spawned,0);e.dead=true;f:call('MC_POST_NPC_DEATH',e)end
        eq(#f.spawned,8)
    end
end
function tests.war_burst_starts_at_kill_before_long_death_animation()
    local f=fixture();local p=f.players[1];p.roll=1;f:use(p)
    local e=f.entities[3];e.HitPoints=1;e.Position=Vector(100,80)
    f:damage(e,20,0,EntityRef(f:entity(2,f:basePlayer(p))),0,nil,'buffer')
    eq(#f.spawned,0,'accepted lethal buffer is not yet a kill')
    -- KILL happens before the death animation; IsDead can still be false here.
    f:call('MC_POST_ENTITY_KILL',e)
    eq(#f.spawned,8,'burst must not wait for MC_POST_NPC_DEATH')
    e.dead=true;e.mortal=false;e.HitPoints=0
    for _=1,20 do f:tick(1);f:call('MC_NPC_UPDATE',e)end
    f:call('MC_POST_NPC_DEATH',e);f:call('MC_POST_ENTITY_KILL',e);e:Remove()
    eq(#f.spawned,8,'late death/removal must not duplicate the burst')
    for i,b in ipairs(f.spawned)do
        local angle=(i-1)*math.pi/4
        near(b.Position.X,100);near(b.Position.Y,80)
        near(b.Velocity.X,math.cos(angle)*5);near(b.Velocity.Y,math.sin(angle)*5)
        eq(b.SpawnerEntity,e);eq(b.ProjectileFlags,0)
    end
end
function tests.war_synchronous_kill_waits_for_accepted_damage()
    for _,cancel in ipairs({false,true})do
        local f=fixture();local p=f.players[1];p.roll=1;f:use(p);local e=f.entities[3];e.HitPoints=1
        local source=EntityRef(f:entity(2,p))
        f:call('MC_ENTITY_TAKE_DMG',e,20,0,source,0)
        f:call('MC_POST_ENTITY_KILL',e);eq(#f.spawned,0,'a pre-damage prediction cannot spawn')
        if not cancel then
            f:call('MC_POST_ENTITY_TAKE_DMG',e,20,0,source,0)
            eq(#f.spawned,8,'kill event is sufficient even before IsDead changes')
        else
            f:tick(1);f:call('MC_POST_NPC_DEATH',e);eq(#f.spawned,0)
        end
    end
end
function tests.war_dead_update_resolves_before_stale_buffer_cleanup()
    local f=fixture();local p=f.players[1];p.roll=1;f:use(p);local e=f.entities[3];e.HitPoints=1
    f:damage(e,20,0,EntityRef(f:entity(2,p)),0,nil,'buffer')
    e.dead=true;e.mortal=false;e.HitPoints=0;f:call('MC_NPC_UPDATE',e)
    eq(#f.spawned,8,'confirmed death must precede clearing the consumed damage buffer')
    f:call('MC_POST_NPC_DEATH',e);eq(#f.spawned,8)
end
function tests.war_kill_event_rejects_uncredited_and_ineligible_deaths()
    for _,case in ipairs({'nonlethal','bomb','familiar','teammate','boss','split','morph','expired','phase','stale'})do
        local f=fixture();local p,q=table.unpack(f.players);p.roll=1;f:use(p);local e=f.entities[3];e.HitPoints=1
        local source=f:entity(2,p)
        if case=='nonlethal'then e.HitPoints=100
        elseif case=='bomb'then source=f:entity(4,p)
        elseif case=='familiar'then source=f:entity(2,f:entity(3,p))
        elseif case=='teammate'then source=f:entity(2,q)
        elseif case=='boss'then e.boss=true
        elseif case=='split'then e.Type=51;e.Variant=20;e.boss=true end
        local mode;if case~='nonlethal'then mode='buffer'end
        f:damage(e,2,0,EntityRef(source),0,nil,mode)
        if case=='morph'then e.Type=11
        elseif case=='expired'then f:tick(240)
        elseif case=='phase'then e.mortal=false;e.HitPoints=100;f:call('MC_NPC_UPDATE',e)
        elseif case=='stale'then f:call('MC_NPC_UPDATE',e);f:call('MC_NPC_UPDATE',e)end
        f:call('MC_POST_ENTITY_KILL',e);eq(#f.spawned,0,case)
    end
    local f=fixture();f:call('MC_POST_ENTITY_KILL',f:entity(2));eq(#f.spawned,0)
end
function tests.eye_target_priority_and_cooldown()
    local f=fixture();local p=f.players[1];p.roll=2;local e=f.entities[3];e.HitPoints=500;e.Position=Vector(30,0)
    local close=f:entity(10);close.HitPoints=500;close.Position=Vector(10,0)
    local mini=f:entity(46);mini.boss=true;mini.HitPoints=2000
    f:use(p);local tear=f:entity(2,p)
    eq(f:damage(e,1,0,EntityRef(tear)),false);eq(f:damage(close,1,0,EntityRef(tear)),true)
    f:tick(6);eq(close.hits[#close.hits].amount,30)
    p.Damage=20;f:tick(6);eq(close.hits[#close.hits].amount,60)
    close.invincible=true;close.flags=2;f:tick(6);eq(f:damage(e,1,0,EntityRef(tear)),false)
    close:Remove();local start=f.frame
    for _=1,14 do f:tick(1);eq(f:damage(e,1,0,EntityRef(tear)),false)end
    f:tick(1);eq(f.frame-start,15);eq(f:damage(e,1,0,EntityRef(tear)),true)
    e:Remove();f:tick(16);eq(f:damage(mini,1,0,EntityRef(tear)),true)
end
function tests.eye_boss_room_priority()
    local f=fixture();f.roomType=5;local p=f.players[1];p.roll=2;local boss=f:entity(100);boss.boss=true;boss.HitPoints=10
    f:use(p);local tear=f:entity(2,p);eq(f:damage(f.entities[3],1,0,EntityRef(tear)),false);eq(f:damage(boss,1,0,EntityRef(tear)),true)
end
function tests.eye_attack_family_exceptions_and_tear_explosion()
    local f=fixture();local p,q=table.unpack(f.players);p.roll=2;f:use(p);local other=f:entity(10)
    for _,kind in ipairs({2,7,8})do local src=f:entity(kind,p);eq(f:damage(other,1,0,EntityRef(src)),false)end
    local tear=f:entity(2,p)
    for _,src in ipairs({tear,f:entity(4,tear),f:entity(1000,tear)})do eq(f:damage(other,1,4,EntityRef(src)),false,'tear explosion')end
    for _,src in ipairs({f:entity(4,p),f:entity(1000,p),f:entity(2,q),f:entity(2,f:entity(3,p)),f:entity(2,f:entity(10,p))})do
        eq(f:damage(other,1,4,EntityRef(src)),true,'indirect/teammate exception')
    end
    for _,flag in ipairs({DamageFlag.DAMAGE_POISON_BURN,DamageFlag.DAMAGE_FIRE,DamageFlag.DAMAGE_ACID})do eq(f:damage(other,1,flag,EntityRef(tear)),true)end
    -- 1.0.12a hides the attack behind a Player source; collision scope is proof.
    for _,spec in ipairs({{7,'LASER'},{8,'KNIFE'}})do
        local attack=f:entity(spec[1],p);f:call('MC_PRE_'..spec[2]..'_COLLISION',attack,other,false)
        eq(f:damage(other,1,0,EntityRef(p)),false)
        f:call('MC_POST_'..spec[2]..'_COLLISION',attack,other,false)
        eq(f:damage(other,1,0,EntityRef(p)),true,'unknown player source must not be globally blocked')
    end
end
function tests.cleanups_and_resource_failure()
    for _,event in ipairs({'MC_POST_NEW_ROOM','MC_POST_NEW_LEVEL','MC_PRE_GAME_EXIT','MC_POST_GAME_END'})do
        local f=fixture();local p=f.players[1];p.roll=1;f:use(p);f:call(event);eq(p.Damage,10)
        f:call('MC_POST_RENDER');for _,s in ipairs(f.sprites)do eq(s.draws,nil)end
    end
    local f=fixture();f.brokenVisual=true;eq(f:use(f.players[1]).Discharge,true);f:tick(5);eq(f.entities[3].hits[1].amount,8);assert(#f.logs>0)
end
function tests.world_coordinates_and_render_does_not_tick()
    local f=fixture();local p=f.players[1];p.Position=Vector(40,50);p.Size=20;p.PositionOffset=Vector(80,90);p.SpriteOffset=Vector(100,110)
    f:use(p)
    local halo;for _,s in ipairs(f.sprites)do if s.animation=='SolarHalo'then halo=s end end
    f:call('MC_POST_RENDER');eq(halo.draws,nil,'halo must not draw over the player at end of frame')
    f:call('MC_PRE_PLAYER_RENDER',f.players[2],Vector(200,210));eq(halo.draws,nil,'owner only')
    eq(f:call('MC_PRE_PLAYER_RENDER',p,Vector(200,210)),nil,'must not override player rendering')
    f:call('MC_PRE_PLAYER_RENDER',p,Vector(200,210));eq(f.entities[3].hits,nil)
    near(halo.position.X-0.5*halo.Scale.X,87);near(halo.position.Y+0.5*halo.Scale.Y,111);eq(halo.draws,2)
    f.badConversion=true;f:call('MC_PRE_PLAYER_RENDER',p);eq(halo.draws,2);assert(#f.logs>0)
    f.badConversion=false;f.renderMode=5;f:call('MC_PRE_PLAYER_RENDER',p);eq(halo.draws,2)
    f.renderMode=1;f:call('MC_PRE_PLAYER_RENDER',p);eq(halo.draws,3)
    f:call('MC_POST_NEW_ROOM');f:call('MC_PRE_PLAYER_RENDER',p);eq(halo.draws,3)
end
function tests.solar_visible_boundary_matches_damage_in_every_animation_frame()
    local f=fixture();local p=f.players[1];p.Position=Vector(40,50);f:use(p)
    local halo;for _,s in ipairs(f.sprites)do if s.animation=='SolarHalo'then halo=s end end
    -- Actual alpha bounds of each 64x64 crop (exclusive right/bottom).
    -- The resource contract checks these against the PNG, including its pivot.
    local bounds={{6,14,57,51},{5,13,58,52},{3,12,60,53},{2,11,61,54},
        {3,12,60,53},{4,13,59,52},{6,14,57,51},{7,15,56,50}}
    for _,camera in ipairs({{0.65,0.65,7,11},{2,1.3,-170,89}})do
        f.cameraX,f.cameraY,f.cameraOffsetX,f.cameraOffsetY=table.unpack(camera)
        for age=0,23 do
            halo.age=age;f:call('MC_PRE_PLAYER_RENDER',p,Vector(111,222))
            local b=bounds[math.floor(age/3)+1]
            local left=halo.position.X+(b[1]-32)*halo.Scale.X
            local right=halo.position.X+(b[3]-32)*halo.Scale.X
            local top=halo.position.Y+(b[2]-32)*halo.Scale.Y
            local bottom=halo.position.Y+(b[4]-32)*halo.Scale.Y
            near(left,Isaac.WorldToScreen(p.Position+Vector(-95,0)).X)
            near(right,Isaac.WorldToScreen(p.Position+Vector(95,0)).X)
            near(top,Isaac.WorldToScreen(p.Position+Vector(0,-95)).Y)
            near(bottom,Isaac.WorldToScreen(p.Position+Vector(0,95)).Y)
        end
        p.Position=p.Position+Vector(90,40)
    end
    -- Check gameplay at the very same four world-space boundaries, plus diagonal.
    for _,offset in ipairs({Vector(95,0),Vector(-95,0),Vector(0,95),Vector(0,-95),Vector(57,76)})do
        local inside=f:entity(10);inside.Position=p.Position+offset
        local outside=f:entity(10);outside.Position=p.Position+Vector(offset.X*1.001,offset.Y*1.001)
        f:tick(5);eq(#inside.hits,1);eq(outside.hits,nil)
    end
    -- Enlarging the character must not enlarge the fixed damage range.
    p.SpriteScale=Vector(3,3);f:call('MC_PRE_PLAYER_RENDER',p)
    local b=bounds[math.floor(halo:GetFrame()/3)+1]
    near((b[3]-b[1])*halo.Scale.X,190*f.cameraX)
end
function tests.state_badges_are_small_and_above_the_face()
    for roll=0,2 do
        local f=fixture();local p=f.players[1];p.roll=roll;p.Position=Vector(40,50);p.Size=12
        p.PositionOffset=Vector(80,90);p.SpriteOffset=Vector(100,110);p.SpriteScale=Vector(1,1)
        function p:GetFlyingOffset()return Vector(120,130)end
        f:use(p);local badge=f.sprites[1]
        eq(badge.Scale.X,0.5);eq(badge.Scale.Y,0.5)
        f:call('MC_POST_RENDER');eq(badge.position.X,87);eq(badge.position.Y,71)
        eq(badge.age,0,'render must not advance animation')
        -- A large player needs more clearance; the badge itself stays small.
        p.SpriteScale=Vector(2,2);f:call('MC_POST_RENDER');eq(badge.position.Y,31)
        f.renderMode=5;f:call('MC_POST_RENDER');eq(badge.draws,2)
        f.renderMode=1;f.badConversion=true;f:call('MC_POST_RENDER');eq(badge.draws,2)
        f.badConversion=false;Isaac.WorldToScreen=nil;f:call('MC_POST_RENDER');eq(badge.draws,2)
    end
end
function tests.base_entity_player_ancestry_is_cast_before_player_methods()
    for _,relation in ipairs({'SpawnerEntity','Parent'})do
        local f=fixture();local p=f.players[1];p.roll=1;f:use(p)
        local base=f:basePlayer(p);eq(base.IsCoopGhost,nil)
        local tear=f:entity(2);tear[relation]=base
        f:call('MC_POST_FIRE_TEAR',tear);eq(tear.TearFlags,2)
        local e=f.entities[3];e.HitPoints=1;f:damage(e,2,0,EntityRef(tear));eq(#f.spawned,8)
        p.ghost=true;local ghostTear=f:entity(2,base);f:call('MC_POST_FIRE_TEAR',ghostTear);eq(ghostTear.TearFlags,nil)
    end
    for _,spec in ipairs({{7,'LASER'},{8,'KNIFE'}})do
        local f=fixture();local p=f.players[1];p.roll=2;f:use(p);local other=f:entity(10)
        local base=f:basePlayer(p);local weapon=f:entity(spec[1],base)
        f:call('MC_PRE_'..spec[2]..'_COLLISION',weapon,other,false)
        eq(f:damage(other,1,0,EntityRef(base)),false)
        f:call('MC_POST_'..spec[2]..'_COLLISION',weapon,other,false)
        eq(f:damage(other,1,0,EntityRef(base)),true)
        eq(f:damage(other,1,0,EntityRef(f:entity(2,f:basePlayer(f.players[2])))),true,'teammate exempt')
    end
end
function tests.corpse_projectiles_cleaned_at_expiry_only_for_owner()
    local f=fixture();local p,q=table.unpack(f.players);p.roll=1;q.roll=1;f:use(p);f:use(q)
    local e=f.entities[3];e.HitPoints=1;f:damage(e,2,0,EntityRef(f:entity(2,p)))
    local second=f:entity(10);second.HitPoints=1;f:damage(second,2,0,EntityRef(f:entity(2,q)))
    eq(#f.spawned,16);f:call('MC_PRE_TRIGGER_PLAYER_DEATH',p)
    for i=1,8 do eq(f.spawned[i].removed,true)end
    for i=9,16 do eq(f.spawned[i].removed,nil)end
    eq(q.Damage,20)
end
function tests.paused_clock_wrapper_identity_and_no_fixed_rotation()
    local f=fixture();local p=f.players[1];f:use(p)
    local wrapper=setmetatable({},{__index=p});wrapper.ptr=GetPtrHash(p)
    eq(f:use(wrapper).Discharge,false);eq(#p.draws,1)
    f.paused=true;f:tick(240);eq(p.MoveSpeed,0.55);f.paused=false;f:tick(240);eq(p.MoveSpeed,1)
    -- Solar -> War -> Solar must be possible without drawing Eye.
    p.roll=0;f:use(p);eq(f.saved.godComplex.players['1:0'],'War');f:call('MC_POST_NEW_ROOM');f:tick(1)
    f:use(p);eq(f.saved.godComplex.players['1:0'],'Solar')
end
function tests.newer_extra_source_is_narrow_and_source_chains_are_bounded()
    local f=fixture();local p=f.players[1];p.roll=2;f:use(p);local target=f:entity(10)
    local knife=f:entity(8,p);eq(f:damage(target,1,0,EntityRef(p),0,EntityRef(knife)),false)
    local familiar=f:entity(3,p);local shot=f:entity(2,familiar);eq(f:damage(target,1,0,EntityRef(p),0,EntityRef(shot)),true)
    local a=f:entity(1000);local b=f:entity(4,a);a.Parent=b
    eq(f:damage(target,1,4,EntityRef(a)),true)
end
function tests.eye_loss_cooldown_begins_at_death_not_next_update()
    local f=fixture();local p=f.players[1];p.roll=2;f:use(p);local old=f.entities[3]
    local nextTarget=f:entity(10);local tear=f:entity(2,p)
    old.dead=true;f:call('MC_POST_NPC_DEATH',old)
    f:tick(14);eq(f:damage(nextTarget,1,0,EntityRef(tear)),false)
    f:tick(1);eq(f:damage(nextTarget,1,0,EntityRef(tear)),true)
end
function tests.eye_death_before_update_does_not_consume_first_cooldown_frame()
    local f=fixture();local p=f.players[1];p.roll=2;f:use(p);local old=f.entities[3]
    local other=f:entity(10);local tear=f:entity(2,p)
    f.frame=f.frame+1;old.dead=true;f:call('MC_POST_NPC_DEATH',old);f:call('MC_POST_UPDATE')
    f:tick(14);eq(f:damage(other,1,0,EntityRef(tear)),false)
    f:tick(1);eq(f:damage(other,1,0,EntityRef(tear)),true)
end
function tests.familiar_spawner_cannot_be_overridden_by_player_parent()
    local f=fixture();local p=f.players[1];p.roll=2;f:use(p);local other=f:entity(10)
    local tear=f:entity(2,f:entity(3,p));tear.Parent=p
    eq(f:damage(other,1,0,EntityRef(tear)),true)
end
function tests.war_legacy_player_source_needs_live_weapon_collision()
    for _,spec in ipairs({{7,'LASER'},{8,'KNIFE'}})do
        local f=fixture();local p=f.players[1];p.roll=1;f:use(p);local e=f.entities[3];e.HitPoints=1
        local weapon=f:entity(spec[1],p);f:call('MC_PRE_'..spec[2]..'_COLLISION',weapon,e,false)
        f:damage(e,2,0,EntityRef(p));f:call('MC_POST_'..spec[2]..'_COLLISION',weapon,e,false);eq(#f.spawned,8)
    end
end
function tests.explosive_tear_with_fire_flag_is_still_direct()
    local f=fixture();local p=f.players[1];p.roll=2;f:use(p);local other=f:entity(10)
    local tear=f:entity(2,p)
    eq(f:damage(other,1,DamageFlag.DAMAGE_EXPLOSION|DamageFlag.DAMAGE_FIRE,EntityRef(tear)),false)
    eq(f:damage(other,1,DamageFlag.DAMAGE_EXPLOSION|DamageFlag.DAMAGE_FIRE,EntityRef(f:entity(4,p))),true)
end
function tests.attached_dot_and_shared_damage_are_not_new_direct_hits()
    for _,flag in ipairs({1<<22,1<<8})do
        local f=fixture();local p=f.players[1];p.roll=2;f:use(p);local other=f:entity(10)
        eq(f:damage(other,1,flag,EntityRef(f:entity(2,p))),true)
    end
end
local names={};for n in pairs(tests)do names[#names+1]=n end;table.sort(names)
for _,n in ipairs(names)do tests[n]();print('PASS '..n)end
print('God Complex behavior: '..#names..' tests passed')
