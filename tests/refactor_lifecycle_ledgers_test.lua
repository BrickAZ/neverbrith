-- Exercise registered owner callbacks, saved ledgers and real cache consumers.
local failures, cases = {}, 0
local function check(name, run)
    cases = cases + 1
    local ok, err = pcall(run)
    if not ok then failures[#failures + 1] = name .. ': ' .. tostring(err) end
end
local function fixture(feature)
    ModCallbacks = { MC_POST_UPDATE=1, MC_EVALUATE_CACHE=2, MC_POST_ADD_COLLECTIBLE=3,
        MC_POST_GAME_STARTED=4, MC_PRE_GAME_EXIT=5, MC_PRE_MOD_UNLOAD=6, MC_PRE_PICKUP_COLLISION=7 }
    CacheFlag={CACHE_DAMAGE=1}
    EntityType={ENTITY_PICKUP=5};PickupVariant={PICKUP_COLLECTIBLE=100}
    include=function(name)return assert(loadfile(name:gsub('%.','/')..'.lua'))()end
    local mod, callbacks, players = {}, {}, {}
    function mod:AddCallback(event,fn,filter)
        callbacks[event]=callbacks[event] or {};table.insert(callbacks[event],{fn=fn,filter=filter})
    end
    local data, saves = {}, 0
    local store={Get=function()return data end,Replace=function(value)data=value end,Save=function()saves=saves+1 end}
    local p={InitSeed=101,count=1,Damage=3.5,broken=0,evaluations=0}
    function p:GetCollectibleNum(id)return id==42 and self.count or 0 end
    function p:AddBrokenHearts(n)self.broken=self.broken+n end
    function p:AddCacheFlags(flag)assert(flag==CacheFlag.CACHE_DAMAGE)end
    function p:EvaluateItems()
        self.evaluations=self.evaluations+1;self.Damage=3.5
        for _,r in ipairs(callbacks[ModCallbacks.MC_EVALUATE_CACHE] or {})do r.fn(mod,self,CacheFlag.CACHE_DAMAGE)end
    end
    players[1]=p
    local api=include('scripts.features.'..feature)(mod,{
        ItemId=42,Items={CrazyCoconut=42},Store=store,GetCurrentRunSeed=function()return 'SAME SEED' end,
        GetPlayers=function()return players end,IsValidItemId=function(id)return type(id)=='number' and id>0 end,Log=function()end,
    })
    if feature=='utility_knife' then api.InstallCache();api.InstallUpdate();api.InstallPickup()
    else api.InstallGameStarted();api.InstallEvaluateCrazyCoconut();api.InstallTrackCrazyCoconutCopies();api.InstallHandleCrazyCoconutCollectiblePickup()end
    local function event(id,...)
        assert(callbacks[id] and #callbacks[id]>0,'missing lifecycle callback '..id)
        for _,r in ipairs(callbacks[id])do r.fn(mod,...)end
    end
    return {mod=mod,p=p,store=store,event=event,players=players,saves=function()return saves end}
end
check('knife same-seed restart clears counts before fallback acquisition',function()
    local e=fixture('utility_knife')
    e.store.Replace({runSeed='SAME SEED',playerCounts={['101']=4,['202']=9},extension='keep'})
    e.event(ModCallbacks.MC_POST_GAME_STARTED,false)
    assert(next(e.store.Get().playerCounts)==nil,'same-seed restart retained prior counts')
    assert(e.store.Get().extension=='keep','foreign save field changed')
    assert(e.p.evaluations>0 and e.p.Damage==4.5,'new run did not refresh damage')
    e.mod:TrackUtilityKnifeCopies();e.mod:TrackUtilityKnifeCopies()
    assert(e.p.broken==1 and e.store.Get().playerCounts['101']==1,'fresh acquisition not exactly once')
end)
check('knife continue preserves ledger and restores cache without pickup',function()
    local e=fixture('utility_knife');local saved={runSeed='SAME SEED',playerCounts={['101']=1}}
    e.store.Replace(saved);e.event(ModCallbacks.MC_POST_GAME_STARTED,true)
    assert(e.store.Get()==saved and saved.playerCounts['101']==1)
    e.mod:TrackUtilityKnifeCopies()
    assert(e.p.broken==0 and e.p.Damage==4.5 and e.p.evaluations>0,'continue granted heart or failed cache restoration')
end)
check('knife pre-start acquisition receipt survives new-run reset exactly once',function()
    local e=fixture('utility_knife')
    e.event(ModCallbacks.MC_POST_ADD_COLLECTIBLE,e.p)
    assert(e.p.broken==1,'registered add callback did not grant pickup cost')
    e.event(ModCallbacks.MC_POST_GAME_STARTED,false)
    e.mod:TrackUtilityKnifeCopies();e.mod:TrackUtilityKnifeCopies()
    assert(e.p.broken==1,'GAME_STARTED discarded an already-paid current-player receipt')
    e.event(ModCallbacks.MC_PRE_GAME_EXIT,true)
    e.event(ModCallbacks.MC_POST_GAME_STARTED,false)
    e.mod:TrackUtilityKnifeCopies()
    assert(e.p.broken==2,'old receipt leaked into a later same-seed restart')
end)
check('knife loss refreshes damage through count fallback',function()
    local e=fixture('utility_knife');e.mod:TrackUtilityKnifeCopies();e.p:EvaluateItems()
    assert(e.p.Damage==4.5);e.p.count=0;e.mod:TrackUtilityKnifeCopies()
    assert(e.p.Damage==3.5,'knife loss left stale damage')
end)
check('coconut continue restores growth cache and loss removes contribution',function()
    local e=fixture('crazy_coconut')
    local saved={runSeed='SAME SEED',players={['101']=5},playerCounts={['101']=1},pending={},naturalDamage={}}
    e.store.Replace(saved);e.event(ModCallbacks.MC_POST_GAME_STARTED,true)
    assert(e.p.Damage==18.5,'continue failed to restore growth cache')
    e.p.count=0;e.mod:TrackCrazyCoconutCopies()
    assert(e.p.Damage==3.5 and saved.players['101']==5,'loss cache or retained growth contract broken')
end)
check('coconut exit releases references and pauses saved pending work',function()
    local e=fixture('crazy_coconut')
    local pending={{itemId=99,beforeCount=0,beforeDamage=3.5,coconutCount=1,sourceKey='old',traceToken='old',remainingUpdates=2}}
    local saved={runSeed='SAME SEED',players={['101']=5},playerCounts={['101']=1},pending={['101']=pending},naturalDamage={}}
    e.store.Replace(saved)
    e.mod.CrazyCoconutPickupSources.old={Exists=function()error('stale pickup accessed')end}
    e.event(ModCallbacks.MC_PRE_GAME_EXIT,true);e.event(ModCallbacks.MC_PRE_GAME_EXIT,true)
    assert(next(e.mod.CrazyCoconutPickupSources)==nil,'pickup reference retained on exit')
    e.mod:TrackCrazyCoconutCopies()
    assert(pending[1].remainingUpdates==2 and saved.players['101']==5,'exit advanced pending ledger')
    e.event(ModCallbacks.MC_POST_GAME_STARTED,true)
    e.mod:TrackCrazyCoconutCopies();assert(pending[1].remainingUpdates==1,'continue did not resume pending work')
end)
check('coconut unload is scoped, idempotent and cannot resume',function()
    local e=fixture('crazy_coconut');e.mod.CrazyCoconutPickupSources.old={}
    e.event(ModCallbacks.MC_PRE_MOD_UNLOAD,{})
    assert(e.mod.CrazyCoconutPickupSources.old,'another mod unload cleared state')
    e.event(ModCallbacks.MC_PRE_MOD_UNLOAD,e.mod);e.event(ModCallbacks.MC_PRE_MOD_UNLOAD,e.mod)
    assert(next(e.mod.CrazyCoconutPickupSources)==nil)
    e.event(ModCallbacks.MC_POST_GAME_STARTED,true)
    e.p.GetCollectibleNum=function()error('disposed owner queried')end
    e.mod:TrackCrazyCoconutCopies()
end)
check('coconut completed queued receipt releases its source without waiting for exit',function()
    local e=fixture('crazy_coconut')
    local receipt={itemId=99,beforeCount=0,beforeDamage=3.5,coconutCount=1,sourceKey='queued',traceToken='queued',remainingUpdates=1,queueSeen=true}
    e.store.Replace({runSeed='SAME SEED',players={['101']=1},playerCounts={['101']=1},pending={['101']={receipt}},naturalDamage={}})
    e.mod.CrazyCoconutPickupSources.queued={Exists=function()return false end}
    e.mod:TrackCrazyCoconutCopies()
    assert(#e.store.Get().pending['101']==0,'due receipt did not settle')
    assert(e.mod.CrazyCoconutPickupSources.queued==nil,'settled receipt retained a pickup reference')
end)
check('coconut internals stay local while tested compatibility remains',function()
    local e=fixture('crazy_coconut')
    for _,name in ipairs({'TraceCrazyCoconut','ShouldCrazyCoconutRewardCollectible',
        'GetCrazyCoconutPickupSourceKey','IsCrazyCoconutPickupSourceAlive','GetCrazyCoconutQueuedCollectibleId',
        'QueueCrazyCoconutCandidate','RefreshCrazyCoconutCache','AnyPlayerHasCrazyCoconut',
        'CrazyCoconutDamagePerLayer','CrazyCoconutTraceEnabled'})do
        assert(e.mod[name]==nil,'private global remains: '..name)
    end
    assert(type(e.mod.GetCrazyCoconutData)=='function' and type(e.mod.GetCrazyCoconutNaturalDamage)=='function')
end)
for _,failure in ipairs(failures)do print('FAIL '..failure)end
assert(#failures==0,#failures..'/'..cases..' ledger lifecycle cases failed')
print('Refactored ledger lifecycle: '..cases..' cases passed')
