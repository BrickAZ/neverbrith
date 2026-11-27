local loader=dofile('tests/support/neverbirth_fixture.lua')
local env=loader()
local mod,ids=Neverbirth,env.itemIds
local players={}
Isaac.FindByType=function(kind)return kind==EntityType.ENTITY_PLAYER and players or {}end
local function player(seed,x)
    local p={InitSeed=seed,Position=Vector(x or 100,100),Damage=3.5,TearFlags=0,entityFlags=0,damageCalls=0}
    function p:ToPlayer()return self end
    function p:GetCollectibleNum(id)return id==ids.UncutCord and 1 or 0 end
    function p:GetActiveCharge()return 1 end
    function p:DischargeActiveItem()end
    function p:TakeDamage()self.damageCalls=self.damageCalls+1 end
    function p:AddCacheFlags()end
    function p:AddEntityFlags(flags)self.entityFlags=self.entityFlags|flags end
    function p:ClearEntityFlags(flags)self.entityFlags=self.entityFlags&~flags end
    function p:EvaluateItems()
        self.Damage,self.MaxFireDelay,self.TearFlags,self.TearColor=3.5,9,0,Color.Default
        for _,flag in ipairs({CacheFlag.CACHE_DAMAGE,CacheFlag.CACHE_FIREDELAY,CacheFlag.CACHE_TEARFLAG,CacheFlag.CACHE_TEARCOLOR})do
            mod:EvaluateChunyao(self,flag)
        end
    end
    function p:GetCollectibleRNG()return {RandomFloat=function()return 0 end}end
    return p
end
local function event(id,name,...)
    local fn=assert(mod[name],'missing '..name)
    local count=0
    for _,record in ipairs(env.callbacks[id] or {})do
        if record.fn==fn then count=count+1;record.fn(mod,...)end
    end
    assert(count==1,name..' must be registered exactly once')
end
local a=player(101);players={a}
mod:UseChunyao(nil,nil,a)
local fresh=player(101);players={fresh}
event(ModCallbacks.MC_POST_GAME_STARTED,'ResetChunyaoState',false)
fresh:EvaluateItems()
assert(fresh.Damage==3.5 and fresh.TearFlags==0,'same-seed new run must not inherit Chunyao')
mod:UseChunyao(nil,nil,fresh)
for _=1,10 do mod:UpdateChunyaoEffects()end
event(ModCallbacks.MC_PRE_GAME_EXIT,'ExitChunyao')
local realFind=Isaac.FindByType
Isaac.FindByType=function()error('player access after exit')end
for _=1,100 do mod:UpdateChunyaoEffects()end
assert(mod:UseChunyao(nil,nil,fresh)==false)
Isaac.FindByType=realFind
local continued=player(101);players={continued}
event(ModCallbacks.MC_POST_GAME_STARTED,'ResetChunyaoState',true)
assert(continued.Damage==4,'same-instance continue restores remaining effect')
for _=1,79 do mod:UpdateChunyaoEffects()end
assert(continued.Damage==4,'exit/continue must not advance or reset timer')
mod:UpdateChunyaoEffects()
assert(continued.Damage==3.5 and continued.TearFlags==0)
mod:UseChunyao(nil,nil,continued)
event(ModCallbacks.MC_PRE_MOD_UNLOAD,'UnloadChunyao',{})
continued:EvaluateItems();assert(continued.Damage==4,'ignore another mod unload')
event(ModCallbacks.MC_PRE_MOD_UNLOAD,'UnloadChunyao',mod)
event(ModCallbacks.MC_PRE_MOD_UNLOAD,'UnloadChunyao',mod)
event(ModCallbacks.MC_POST_GAME_STARTED,'ResetChunyaoState',false)
assert(mod:UseChunyao(nil,nil,continued)==false,'disposed instance stays inactive')

-- Cord keeps plain debt across same-instance continue, with no old entity fallback.
local roomIndex,clear,enemies=1,false,true
local previousGame=Game
Game=function()
    local g=previousGame()
    g.GetRoom=function()return {IsClear=function()return clear end,GetSpawnSeed=function()return roomIndex end}end
    g.GetLevel=function()return {GetCurrentRoomIndex=function()return roomIndex end}end
    return g
end
Isaac.GetRoomEntities=function()return enemies and {{IsVulnerableEnemy=function()return true end}} or {}end
local old=player(202,100);players={old}
assert(mod:HandleUncutCordDamage(old,2)==false)
event(ModCallbacks.MC_PRE_GAME_EXIT,'ExitUncutCord')
old.Position=nil;old.InitSeed=nil
setmetatable(old,{__index=function()error('stale player accessed')end})
local current=player(202,500);players={current}
event(ModCallbacks.MC_POST_GAME_STARTED,'ResetUncutCordState',true)
local xs={};Isaac.WorldToScreen=function(pos)xs[#xs+1]=pos.X;return pos end
mod.RenderRuntimeText=function()end
mod:RenderUncutCordFeedbacks()
assert(#xs>0 and xs[1]==500,'render must resolve current player')
players={};xs={};mod:RenderUncutCordFeedbacks();assert(#xs==0,'absent owner must not use old reference')
clear,enemies=true,false;mod:UpdateUncutCordRooms()
roomIndex,clear,enemies=2,false,true;mod:TrackUncutCordNewRoom()
clear,enemies=true,false;mod:UpdateUncutCordRooms()
players={current};mod:UpdateUncutCordRooms()
assert(current.damageCalls==1,'defer settled debt until current owner exists')
mod:UpdateUncutCordRooms();assert(current.damageCalls==1,'debt settles only once')

event(ModCallbacks.MC_POST_GAME_STARTED,'ResetUncutCordState',false)
assert(mod:HandleUncutCordDamage(current,2)==false)
current.TakeDamage=function()error('injected damage failure')end
local ok,err=pcall(mod.HandleUncutCordDamage,mod,current,1)
assert(not ok and tostring(err):find('injected damage failure',1,true),'preserve error diagnosis')
current.TakeDamage=function(self)self.damageCalls=self.damageCalls+1 end
assert(mod:HandleUncutCordDamage(current,1)==false,'failure must release settlement guard')
local count=current.damageCalls
assert(mod:HandleUncutCordDamage(current,1)==nil and current.damageCalls==count+1,'later debt settles normally')
event(ModCallbacks.MC_PRE_GAME_EXIT,'ExitUncutCord')
Isaac.FindByType=function()error('player query after cord exit')end
Game=function()error('Game after cord exit')end
mod:UpdateUncutCordRooms();mod:RenderUncutCordFeedbacks();mod:TrackUncutCordNewRoom()
assert(mod:HandleUncutCordDamage(current,1)==nil)
event(ModCallbacks.MC_PRE_MOD_UNLOAD,'UnloadUncutCord',mod)
event(ModCallbacks.MC_POST_GAME_STARTED,'ResetUncutCordState',false)
assert(mod:HandleUncutCordDamage(current,1)==nil)
print('batch2 lifecycle passed: new run, same-instance continue, old entity release, delayed owner, error unwind and disposal')
