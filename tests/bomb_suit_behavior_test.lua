-- Standalone event-dispatch tests: final health loss, timed state, ownership,
-- native bomb creation, input and independent co-op/lifecycle behavior.
local tests, passed = {}, 0
local function test(name, fn) tests[#tests + 1] = {name, fn} end
local function eq(a, b, message)
    if a ~= b then error((message or "mismatch") .. ": expected " .. tostring(b) .. ", got " .. tostring(a), 2) end
end
local function truth(value, message) if not value then error(message or "expected truthy", 2) end end

local function environment(options)
    options = options or {}
    ModCallbacks = {MC_PRE_PLAYER_TAKE_DMG=1008, MC_POST_ENTITY_TAKE_DMG=1006,
        MC_EVALUATE_CACHE=8, MC_PRE_PLAYER_UPDATE=1160, MC_POST_PLAYER_UPDATE=31,
        MC_POST_UPDATE=1, MC_POST_GAME_STARTED=15, MC_PRE_GAME_EXIT=16,
        MC_POST_NEW_ROOM=19, MC_POST_NEW_LEVEL=18, MC_PRE_TRIGGER_PLAYER_DEATH=1050,
        MC_POST_TRIGGER_COLLECTIBLE_REMOVED=1095, MC_INPUT_ACTION=13,
        MC_POST_BOMB_INIT=57, MC_POST_EFFECT_INIT=54, MC_POST_TEAR_INIT=39,
        MC_POST_GLOWING_HOURGLASS_LOAD=1301, MC_PRE_MOD_UNLOAD=73,
        MC_PRE_BOMB_UPDATE=1163, MC_POST_BOMB_UPDATE=58, MC_PRE_ENTITY_SPAWN=24}
    CacheFlag={CACHE_SPEED=8}; EntityType={ENTITY_PLAYER=1, ENTITY_BOMBDROP=4, ENTITY_SLOT=6}
    BombVariant={BOMB_NORMAL=0};CollectibleType={COLLECTIBLE_MR_MEGA=106}
    TearFlags={TEAR_SCATTER_BOMB=1<<36}
    DamageFlag={DAMAGE_EXPLOSION=1<<2,DAMAGE_RED_HEARTS=1<<5,DAMAGE_SPIKES=1<<7,
        DAMAGE_DEVIL=1<<10,DAMAGE_INVINCIBLE=1<<13,DAMAGE_CURSED_DOOR=1<<16,
        DAMAGE_IV_BAG=1<<18,DAMAGE_FAKE=1<<21,DAMAGE_NO_PENALTIES=1<<28}
    ButtonAction={ACTION_SHOOTLEFT=4,ACTION_SHOOTRIGHT=5,ACTION_SHOOTUP=6,ACTION_SHOOTDOWN=7,ACTION_BOMB=8}
    InputHook={IS_ACTION_PRESSED=0,IS_ACTION_TRIGGERED=1,GET_ACTION_VALUE=2}
    SoundEffect={SOUND_BEEP=171}
    Vector=function(x,y)return {X=x,Y=y} end
    Color=function(...)return {...} end
    GetPtrHash=function(e)return e.pointer end
    local env={callbacks={},players={},bombs={},sounds={},frame=0,paused=false,spawnFailure=false,seed=2000}
    local mod={}
    function mod:AddPriorityCallback(id, priority, fn, filter)
        env.callbacks[id]=env.callbacks[id] or {}
        table.insert(env.callbacks[id],{priority=priority,fn=fn,filter=filter})
        table.sort(env.callbacks[id],function(a,b)return a.priority<b.priority end)
    end
    function mod:AddCallback(id, fn, filter) self:AddPriorityCallback(id,0,fn,filter) end
    local game={}
    function game:GetFrameCount()return env.frame end
    function game:IsPaused()return env.paused end
    function game:GetNumPlayers()return #env.players end
    Game=function()return game end
    Isaac={GetPlayer=function(i)return env.players[i+1] end,DebugString=function(message)env.error=message end}
    SFXManager=function()return {Play=function(_,id,volume,delay,loop,pitch)
        env.sounds[#env.sounds+1]={id=id,pitch=pitch,frame=env.frame} end} end
    local function dispatch(id, filter, ...)
        for _,r in ipairs(env.callbacks[id] or {})do
            if not r.filter or r.filter==filter then
                local value=r.fn(mod,...)
                if value~=nil then return value end
            end
        end
    end
    env.dispatch=dispatch
    function env.player(extra)
        extra=extra or {};local p={Type=1,Variant=0,InitSeed=#env.players+10,pointer=#env.players+100,
            Position=Vector(80,120),Velocity=Vector(0,0),hearts=8,soul=0,bone=0,
            itemCount=extra.itemCount or 1,canShoot=extra.canShoot~=false,baseSpeed=extra.speed or 1,
            MoveSpeed=extra.speed or 1,alive=true,bombDamage=extra.bombDamage or 100,
            bombFlags=extra.bombFlags or 0,bombs=5,data={}}
        function p:Exists()return true end
        function p:IsDead()return not self.alive end
        function p:HasMortalDamage()return self.mortal or false end
        function p:ToPlayer()return self end
        function p:GetData()return self.data end
        function p:HasCollectible(id)return id==900 and self.itemCount>0 or id==106 and self.mega==true end
        function p:GetEffects()return {HasCollectibleEffect=function(_,id)return id==106 and self.megaEffect==true end}end
        function p:GetBombFlags(fetus)eq(fetus,false);return self.bombFlags end
        function p:GetCollectibleNum()return self.itemCount end
        function p:GetHearts()return self.hearts end
        function p:GetSoulHearts()return self.soul end
        function p:GetBoneHearts()return self.bone end
        function p:CanShoot()return self.canShoot end
        function p:SetCanShoot(value)self.canShoot=value end
        function p:AddCacheFlags()self.refreshes=(self.refreshes or 0)+1 end
        function p:EvaluateItems()
            self.MoveSpeed=self.baseSpeed;dispatch(ModCallbacks.MC_EVALUATE_CACHE, nil,self,8)
        end
        function p:SetColor(...)self.color={...} end
        function p:FireBomb(pos,vel,source)
            self.fireCalls=(self.fireCalls or 0)+1
            if env.spawnFailure then return nil end
            env.seed=env.seed+1
            dispatch(ModCallbacks.MC_PRE_ENTITY_SPAWN,nil,4,0,0,pos,vel,source,env.seed)
            local bomb={Type=4,Variant=0,SubType=0,InitSeed=env.seed,FrameCount=0,scale=1,
                pointer=500+#env.bombs,Position=pos,Velocity=vel,
                SpawnerEntity=source,Parent=source,ExplosionDamage=self.bombDamage,
                Flags=self.bombFlags,RadiusMultiplier=extra.bombRadius or 1,data={},alive=true,owner=self}
            function bomb:GetData()return self.data end
            function bomb:Exists()return self.alive end
            function bomb:ToPlayer()return nil end
            function bomb:SetExplosionCountdown(value)self.countdown=value end
            function bomb:AddTearFlags(value)self.Flags=self.Flags|value end
            function bomb:HasTearFlags(value)return (self.Flags&value)~=0 end
            function bomb:GetScale()return self.scale end
            function bomb:GetExplosionCountdown()return self.countdown or 30 end
            function bomb:Update()
                if dispatch(ModCallbacks.MC_PRE_BOMB_UPDATE,nil,self)==true then return end
                self.updated=true
                if self.countdown and self.countdown>0 then self.countdown=self.countdown-1 end
                if self.countdown==0 then
                    self.exploded=true
                    -- Simulate the native explosion calling the player damage route.
                    env.damage(self.owner,1,DamageFlag.DAMAGE_EXPLOSION,self)
                    if env.onExplode then env.onExplode(self) end
                    self.alive=false
                end
                dispatch(ModCallbacks.MC_POST_BOMB_UPDATE,nil,self)
                self.FrameCount=self.FrameCount+1
            end
            env.bombs[#env.bombs+1]=bomb
            dispatch(ModCallbacks.MC_POST_BOMB_INIT,nil,bomb)
            return bomb
        end
        env.players[#env.players+1]=p;return p
    end
    function env.damage(p,amount,flags,source,settings)
        flags=flags or 0;settings=settings or {};local ref={Entity=source}
        local blocked=dispatch(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,p.Variant,p,amount,flags,ref,0)
        if blocked==false or settings.cancel then return false end
        if not settings.shield and (flags & DamageFlag.DAMAGE_FAKE)==0 and amount>0 then
            if settings.bone then p.bone=p.bone-1
            elseif settings.soul then p.soul=p.soul-amount
            else p.hearts=p.hearts-amount end
        end
        if settings.lethal then p.mortal=true end
        dispatch(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,p.Type,p,amount,flags,ref,0)
        return true
    end
    function env.step(n)
        for _=1,n or 1 do
            env.frame=env.frame+1
            for _,p in ipairs(env.players)do
                dispatch(ModCallbacks.MC_PRE_PLAYER_UPDATE,nil,p)
                if env.engineInput then env.engineInput(p) end
                dispatch(ModCallbacks.MC_POST_PLAYER_UPDATE,nil,p)
            end
            dispatch(ModCallbacks.MC_POST_UPDATE,nil)
        end
    end
    env.mod=mod
    function env.mini(p,damage,flags)
        local b=p:FireBomb(p.Position,Vector(3,0),p)
        b.Parent=nil;b.IsFetus=false;b.scale=0.5;b.ExplosionDamage=damage or 50;b.Flags=flags or 0
        b:SetExplosionCountdown(20);return b
    end
    Isaac.Spawn=function(kind,variant,subtype,pos,vel,source)
        eq(kind,EntityType.ENTITY_BOMBDROP);eq(variant,BombVariant.BOMB_NORMAL);eq(subtype,0)
        local bomb=source:FireBomb(pos,vel,source)
        if not bomb then return nil end
        bomb.ExplosionDamage=100;bomb.Flags=0;bomb.RadiusMultiplier=1;bomb.IsFetus=false
        function bomb:ToBomb()return self end
        return bomb
    end
    dofile('bomb_suit.lua')(mod,{ItemId=900,GetPlayers=function()return env.players end,
        DebugLog=function(message)env.error=message end})
    dispatch(ModCallbacks.MC_POST_GAME_STARTED,nil,false)
    return env
end

test('real hit lands; state begins after loss; +0.5 through cache',function()
    local e=environment();local p=e.player();e.damage(p,1)
    eq(p.hearts,7);eq(p.MoveSpeed,1.5);truth(e.mod.BombSuit.IsActive(p))
    p:EvaluateItems();eq(p.MoveSpeed,1.5,'cache re-evaluation must not stack')
end)
test('cancelled, fake, zero and shielded damage do not arm',function()
    for _,settings in ipairs({{cancel=true},{shield=true},{fake=true},{zero=true}})do
        local e=environment();local p=e.player()
        e.damage(p,settings.zero and 0 or 1,settings.fake and DamageFlag.DAMAGE_FAKE or 0,nil,settings)
        eq(e.mod.BombSuit.IsActive(p),false);e.step(100);eq(#e.bombs,0)
    end
end)
test('soul heart or broken bone heart loss can arm',function()
    for _,kind in ipairs({'soul','bone'})do
        local e=environment();local p=e.player();p.soul=4;p.bone=2
        e.damage(p,1,0,nil,{[kind]=true});truth(e.mod.BombSuit.IsActive(p))
    end
end)
test('lethal hit does not arm or prevent native death',function()
    local e=environment();local p=e.player();e.damage(p,1,0,nil,{lethal=true})
    eq(p.hearts,7);eq(e.mod.BombSuit.IsActive(p),false)
end)
test('90 frames; one native bomb at current position; no bomb resource debit',function()
    local e=environment();local p=e.player();e.damage(p,1);e.step(89)
    eq(#e.bombs,0);p.Position=Vector(220,300);e.step()
    eq(#e.bombs,1);local b=e.bombs[1];eq(b.Position.X,220);eq(b.Position.Y,300)
    eq(b.countdown,0);truth(b.exploded);eq(p.bombs,5);eq(p.hearts,7)
    eq(e.mod.BombSuit.IsActive(p),false);eq(p.MoveSpeed,1);e.step(100);eq(#e.bombs,1)
end)
test('ordinary carrier gets current non-fetus flags and Mr Mega acquired during fuse',function()
    local e=environment();local p=e.player({bombFlags=1})
    e.damage(p,1);p.mega=true;p.bombFlags=123456;e.step(90)
    local b=e.bombs[1];eq(b.ExplosionDamage,185);eq(b.Flags,123456);eq(b.RadiusMultiplier,1)
    eq(b.IsFetus,false)
    eq(b.SpawnerEntity,p);eq(b.Parent,p)
end)
test('ordinary carrier uses 100 damage, and temporary Mr Mega effect uses 185',function()
    for _,effect in ipairs({false,true})do
        local e=environment();local p=e.player();p.megaEffect=effect;e.damage(p,1);e.step(90)
        eq(e.bombs[1].ExplosionDamage,effect and 185 or 100)
    end
end)
test('all non-blood damage is cancelled during fuse, including forced damage',function()
    local e=environment();local p=e.player();e.damage(p,1)
    for _,flags in ipairs({0,DamageFlag.DAMAGE_EXPLOSION,DamageFlag.DAMAGE_SPIKES,
        DamageFlag.DAMAGE_CURSED_DOOR,DamageFlag.DAMAGE_INVINCIBLE})do eq(e.damage(p,2,flags),false) end
    eq(p.hearts,7);e.step(90);eq(#e.bombs,1)
end)
test('IV bag, blood machine and devil beggar never arm; still hurt in fuse; timer is not refreshed',function()
    for _,payment in ipairs({{flag=DamageFlag.DAMAGE_IV_BAG},{flag=DamageFlag.DAMAGE_RED_HEARTS,source={Type=6,Variant=2}},
        {flag=DamageFlag.DAMAGE_RED_HEARTS,source={Type=6,Variant=5}}})do
        local flag,source=payment.flag,payment.source
        local e=environment();local p=e.player();e.damage(p,1,flag)
        if source then
            e=environment();p=e.player();e.damage(p,1,flag,source)
        end
        eq(e.mod.BombSuit.IsActive(p),false);e.damage(p,1);e.step(30)
        eq(e.damage(p,1,flag,source),true);eq(p.hearts,5);e.step(60);eq(#e.bombs,1)
    end
end)
test('other slot variants and absent source are not automatically blood payment',function()
    local e=environment();eq(e.mod.BombSuit.IsBloodPayment(0,{Entity={Type=6,Variant=6}}),false)
    eq(e.mod.BombSuit.IsBloodPayment(0,{Type=6,Variant=5}),true)
    eq(e.mod.BombSuit.IsBloodPayment(0,nil),false)
end)
test('Razor Blood Rights and Sharp Plug-style voluntary damage is not excluded',function()
    local e=environment();local p=e.player()
    local flags=DamageFlag.DAMAGE_RED_HEARTS|DamageFlag.DAMAGE_INVINCIBLE|DamageFlag.DAMAGE_NO_PENALTIES
    eq(e.damage(p,1,flags,p),true);truth(e.mod.BombSuit.IsActive(p))
    eq(e.damage(p,1,flags,p),false);eq(p.hearts,7)
end)
test('multiple copies do not stack speed or bomb count',function()
    local e=environment();local p=e.player({itemCount=5});e.damage(p,1)
    eq(p.MoveSpeed,1.5);e.step(90);eq(#e.bombs,1)
end)
test('input is suppressed during native update and original shoot permission restored',function()
    for _,initial in ipairs({true,false})do
        local e=environment();local p=e.player({canShoot=initial});e.damage(p,1)
        e.engineInput=function(who)eq(who:CanShoot(),false)end
        e.step(1);eq(p:CanShoot(),initial)
        eq(e.dispatch(ModCallbacks.MC_INPUT_ACTION,nil,p,InputHook.GET_ACTION_VALUE,ButtonAction.ACTION_SHOOTUP),0)
        eq(e.dispatch(ModCallbacks.MC_INPUT_ACTION,nil,p,InputHook.IS_ACTION_PRESSED,ButtonAction.ACTION_SHOOTLEFT),false)
        eq(e.dispatch(ModCallbacks.MC_INPUT_ACTION,nil,p,InputHook.IS_ACTION_PRESSED,ButtonAction.ACTION_BOMB),nil)
        e.engineInput=nil;e.step(89);eq(p:CanShoot(),initial)
    end
end)
test('shoot scopes compose with existing God Complex pattern',function()
    local e=environment();local p=e.player();local saved
    e.mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,10000,function(_,who)saved=who:CanShoot();who:SetCanShoot(false)end)
    e.mod:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,-10000,function(_,who)who:SetCanShoot(saved)end)
    e.damage(p,1);e.step(2);eq(p:CanShoot(),true)
end)
test('co-op ownership, simultaneous hits and independent countdowns',function()
    local e=environment();local p=e.player();local q=e.player();local other=e.player({itemCount=0})
    e.damage(p,1);e.step(30);e.damage(q,1);e.damage(other,1)
    eq(other.MoveSpeed,1);e.step(60);eq(#e.bombs,1);eq(e.bombs[1].owner,p)
    truth(e.mod.BombSuit.IsActive(q));e.step(30);eq(#e.bombs,2);eq(e.bombs[2].owner,q)
end)
test('room and floor transitions keep fuse and current-position explosion',function()
    local e=environment();local p=e.player();e.damage(p,1);e.step(40)
    e.dispatch(ModCallbacks.MC_POST_NEW_ROOM,nil);e.dispatch(ModCallbacks.MC_POST_NEW_LEVEL,nil)
    e.step(50);eq(#e.bombs,1)
end)
test('pause freezes countdown even when mock frame increases',function()
    local e=environment();local p=e.player();e.damage(p,1);e.step(30);e.paused=true;e.step(200)
    eq(#e.bombs,0);e.paused=false;e.step(59);eq(#e.bombs,0);e.step();eq(#e.bombs,1)
end)
test('item loss clears speed and prevents delayed bomb; retaining one copy keeps state',function()
    local e=environment();local p=e.player({itemCount=2});e.damage(p,1);e.step(10)
    p.itemCount=1;e.dispatch(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED,900,p,900)
    truth(e.mod.BombSuit.IsActive(p));p.itemCount=0
    e.dispatch(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED,900,p,900)
    eq(p.MoveSpeed,1);e.step(100);eq(#e.bombs,0)
end)
test('unannounced item loss is reconciled before damage cancellation',function()
    local e=environment();local p=e.player();e.damage(p,1);p.itemCount=0
    eq(e.damage(p,1),true);eq(p.hearts,6);e.step(100);eq(#e.bombs,0);eq(p.MoveSpeed,1)
end)
test('death, exit, continue, rewind and unload clear transient state',function()
    for _,kind in ipairs({'death','exit','continue','rewind','unload'})do
        local e=environment();local p=e.player();e.damage(p,1);e.step(25)
        if kind=='death' then e.dispatch(ModCallbacks.MC_PRE_TRIGGER_PLAYER_DEATH,nil,p)
        elseif kind=='exit' then e.dispatch(ModCallbacks.MC_PRE_GAME_EXIT,nil,true)
        elseif kind=='continue' then e.dispatch(ModCallbacks.MC_POST_GAME_STARTED,nil,true)
        elseif kind=='rewind' then e.dispatch(ModCallbacks.MC_POST_GLOWING_HOURGLASS_LOAD,nil)
        else e.dispatch(ModCallbacks.MC_PRE_MOD_UNLOAD,nil,e.mod,false)end
        eq(p.MoveSpeed,1);eq(p:CanShoot(),true);e.step(100);eq(#e.bombs,0)
    end
end)
test('foreign mod unload does not reset our state',function()
    local e=environment();local p=e.player();e.damage(p,1)
    e.dispatch(ModCallbacks.MC_PRE_MOD_UNLOAD,nil,{},false);truth(e.mod.BombSuit.IsActive(p))
end)
test('native bomb failure ends state safely without an alternate explosion',function()
    local e=environment();local p=e.player();e.damage(p,1);e.spawnFailure=true;e.step(90)
    eq(p.MoveSpeed,1);eq(e.mod.BombSuit.IsActive(p),false);eq(#e.bombs,0);truth(e.error)
end)
test('only owned explosion sources remain self-safe after fuse',function()
    local e=environment();local p=e.player();local q=e.player();e.damage(p,1);e.step(90)
    local b=e.bombs[1];eq(e.damage(p,1,DamageFlag.DAMAGE_EXPLOSION,b),false)
    eq(e.damage(q,1,DamageFlag.DAMAGE_EXPLOSION,b),true,'co-op is not blanket immune')
    local unrelated={Type=4,SpawnerEntity=p,GetData=function()return {}end}
    eq(e.damage(p,1,DamageFlag.DAMAGE_EXPLOSION,unrelated),true)
end)
test('owned child provenance stays self-safe, unrelated child remains ordinary',function()
    local e=environment();local p=e.player();local child
    e.onExplode=function(b)
        child={Type=4,Parent=b,pointer=9000,data={}}
        function child:GetData()return self.data end
        e.dispatch(ModCallbacks.MC_POST_BOMB_INIT,nil,child)
    end
    e.damage(p,1);e.step(90);eq(e.damage(p,1,DamageFlag.DAMAGE_EXPLOSION,child),false)
end)
test('another player bomb spawned in the detonation callback is not adopted',function()
    local e=environment();local p=e.player();local q=e.player({itemCount=0});local foreign
    e.onExplode=function() foreign=q:FireBomb(q.Position,Vector(0,0),q) end
    e.damage(p,1);e.step(90)
    eq(foreign:GetData().NeverbirthBombSuitOwner,nil)
    eq(e.damage(p,1,DamageFlag.DAMAGE_EXPLOSION,foreign),true)
end)

test('native Scatter children with only a player spawner inherit ownership on first update',function()
    for _,mega in ipairs({false,true})do
        local e=environment();local p=e.player({bombFlags=TearFlags.TEAR_SCATTER_BOMB});p.mega=mega
        local child;e.onExplode=function(b)child=e.mini(p,b.ExplosionDamage/2)end
        e.damage(p,1);e.step(90);child:Update()
        eq(child:GetData().NeverbirthBombSuitOwner,tostring(p.pointer))
        eq(e.damage(p,1,DamageFlag.DAMAGE_EXPLOSION,child),false)
        eq(e.mod.BombSuit.IsActive(p),false)
    end
end)

test('Scatter candidate rejects unrelated player, ordinary, fetus and wrong-size bombs',function()
    local e=environment();local p=e.player({bombFlags=TearFlags.TEAR_SCATTER_BOMB});local q=e.player()
    local foreign={};e.onExplode=function()
        foreign[1]=e.mini(q)
        foreign[2]=p:FireBomb(p.Position,Vector(0,0),p)
        foreign[3]=e.mini(p);foreign[3].IsFetus=true
        foreign[4]=e.mini(p);foreign[4].scale=1
        foreign[5]=e.mini(p,35)
    end
    e.damage(p,1);e.step(90)
    for _,b in ipairs(foreign)do b:Update();eq(b:GetData().NeverbirthBombSuitOwner,nil)end
end)

test('an unrelated Scatter bomb nested in owned explosion is an ownership barrier',function()
    local e=environment();local p=e.player({bombFlags=TearFlags.TEAR_SCATTER_BOMB});local child
    e.onExplode=function(b)
        if b:GetData().NeverbirthBombSuitOwner then
            local foreign=p:FireBomb(p.Position,Vector(0,0),p)
            foreign.Flags=TearFlags.TEAR_SCATTER_BOMB;foreign:SetExplosionCountdown(1);foreign:Update()
        else child=e.mini(p)end
    end
    e.damage(p,1);e.step(90);child:Update()
    eq(child:GetData().NeverbirthBombSuitOwner,nil)
end)

test('Scatter-sized bombs outside the owned native update are never adopted',function()
    local e=environment();local p=e.player({bombFlags=TearFlags.TEAR_SCATTER_BOMB})
    e.damage(p,1);e.step(90);local child=e.mini(p);child:Update()
    eq(child:GetData().NeverbirthBombSuitOwner,nil)
end)
test('cancelled hit cannot arm from a later shielded notification',function()
    local e=environment();local p=e.player();e.damage(p,1,0,nil,{cancel=true})
    e.damage(p,1,0,nil,{shield=true});eq(e.mod.BombSuit.IsActive(p),false)
end)
test('nested fake, blood payment, shield or cancelled hit cannot erase outer real damage',function()
    for _,kind in ipairs({'fake','payment','shield','cancelled'})do
        local e=environment();local p=e.player();local ref={Entity=nil}
        e.dispatch(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,p.Variant,p,1,0,ref,0)
        if kind=='fake' then e.damage(p,1,DamageFlag.DAMAGE_FAKE)
        elseif kind=='payment' then e.damage(p,1,DamageFlag.DAMAGE_IV_BAG)
        elseif kind=='shield' then e.damage(p,1,0,nil,{shield=true})
        else e.damage(p,1,0,{pointer=902,Type=2},{cancel=true})end
        p.hearts=p.hearts-1
        e.dispatch(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,p.Type,p,1,0,ref,0)
        truth(e.mod.BombSuit.IsActive(p),kind..' overwrote the outer real receipt')
    end
end)
test('fuse feedback accelerates; rendering is not required for detonation',function()
    local e=environment();local p=e.player();e.damage(p,1);e.step(90)
    truth(#e.sounds>=5);truth(e.sounds[#e.sounds].pitch>e.sounds[1].pitch);truth(p.color)
    eq(#e.bombs,1)
end)

test('same-source cancelled nested hit after outer heart loss does not mask the outer hit',function()
    local e=environment();local p=e.player();local ref={Entity=nil}
    e.dispatch(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,p.Variant,p,1,0,ref,0)
    p.hearts=p.hearts-1;e.damage(p,1,0,nil,{cancel=true})
    e.dispatch(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,p.Type,p,1,0,ref,0)
    truth(e.mod.BombSuit.IsActive(p))
end)
test('cancelled candidate followed by payment and shield cannot arm from payment loss',function()
    local e=environment();local p=e.player();e.damage(p,1,0,nil,{cancel=true})
    e.damage(p,1,DamageFlag.DAMAGE_IV_BAG);e.damage(p,1,0,nil,{shield=true})
    eq(e.mod.BombSuit.IsActive(p),false)
end)
test('payment post adjusts only candidates that preceded that payment',function()
    local e=environment();local p=e.player();local ref={Entity=nil}
    e.dispatch(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,p.Variant,p,1,DamageFlag.DAMAGE_IV_BAG,ref,0)
    p.hearts=p.hearts-1
    e.dispatch(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,p.Variant,p,1,0,ref,0)
    e.dispatch(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,p.Type,p,1,DamageFlag.DAMAGE_IV_BAG,ref,0)
    p.hearts=p.hearts-1
    e.dispatch(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,p.Type,p,1,0,ref,0)
    truth(e.mod.BombSuit.IsActive(p))
end)

for _,entry in ipairs(tests)do
    local ok,err=pcall(entry[2]);if not ok then error(entry[1] .. ': ' .. tostring(err),0)end
    passed=passed+1
end
print('Bomb Suit behavior: '..passed..' tests passed')
