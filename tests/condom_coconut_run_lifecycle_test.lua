local previousArg=arg;arg={'--fixture'}
local fixture=dofile('tests/condom_utility_knife_behavior_test.lua');arg=previousArg
local failures,count={},0
local function check(name,fn)
    count=count+1
    local ok,err=pcall(fn)
    if not ok then failures[#failures+1]=name..': '..tostring(err)end
end
local function copy(value)
    if type(value)~='table'then return value end
    local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result
end
local function start(e,continued)
    local n=0
    for _,r in ipairs(e.callbackRegistrations[ModCallbacks.MC_POST_GAME_STARTED] or {})do
        r.fn(e.mod,continued);n=n+1
    end
    assert(n>0,'real entry game-start callbacks required')
end
local function player(e,key,copies)
    local p=e.newPlayer({collectibles={[e.items.CrazyCoconut]=copies or 0}})
    p.InitSeed=key
    p.evaluations=0
    function p:EvaluateItems()
        self.evaluations=self.evaluations+1;self.Damage=3.5
        e.runEvaluate(self,CacheFlag.CACHE_DAMAGE)
    end
    return p
end
local function oldSave()
    return {
        unrelated={keep=17},
        condom={runSeed='TEST RUN',banned={['101']=true},extension='condom keep'},
        crazyCoconut={runSeed='TEST RUN',players={['101']=5,['202']=7},
            playerCounts={['101']=1,['202']=2},naturalDamage={['101']=3.5,['202']=3.5},
            pending={['101']={{itemId=201,beforeCount=0,beforeDamage=3.5,coconutCount=1,
                sourceKey='101:old',traceToken='old',remainingUpdates=2}}},nextTraceToken=99,extension='coconut keep'},
    }
end
local function preserved(root)
    assert(root.unrelated.keep==17 and root.condom.extension=='condom keep' and root.crazyCoconut.extension=='coconut keep','unowned fields lost')
end
check('same-seed new run clears all saved players and pending sources',function()
    local root=oldSave();local e=fixture({hasData=true,decodedData=root})
    local p,q=player(e,101,0),player(e,202,0)
    e.mod.CrazyCoconutPickupSources['101:old']={Exists=function()return true end}
    start(e,false)
    assert(next(root.condom.banned)==nil,'old bans survived')
    for _,field in ipairs({'players','playerCounts','pending','naturalDamage'})do
        assert(next(root.crazyCoconut[field])==nil,'old '..field..' survived')
    end
    assert(root.crazyCoconut.nextTraceToken==1 and next(e.mod.CrazyCoconutPickupSources)==nil)
    preserved(root)
    start(e,false)
    p.collectibles[e.items.CrazyCoconut]=1;q.collectibles[e.items.CrazyCoconut]=2
    for _=1,5 do e.mod:TrackCrazyCoconutCopies()end
    p:EvaluateItems();q:EvaluateItems()
    assert(root.crazyCoconut.players['101']==1 and root.crazyCoconut.players['202']==2)
    assert(p.Damage==6.5 and q.Damage==9.5,'new inventory inherited old layers or delayed reward')
end)
check('new-run initial holder cache cannot retain previous growth',function()
    local root=oldSave();local e=fixture({hasData=true,decodedData=root})
    local p=player(e,101,1);p:EvaluateItems();assert(p.Damage==18.5)
    start(e,false)
    assert(p.Damage<=6.5,'initial cache still contains old run layers')
    e.mod:TrackCrazyCoconutCopies();p:EvaluateItems()
    assert(p.Damage==6.5 and root.crazyCoconut.players['101']==1)
end)
check('continue preserves saved data and live pending references',function()
    local root=oldSave();local e=fixture({hasData=true,decodedData=root});local p=player(e,101,1)
    local data=e.mod:GetCrazyCoconutData();local bans=e.mod:GetCondomData()
    local source={Exists=function()return true end};e.mod.CrazyCoconutPickupSources['101:old']=source
    local pending=data.pending['101']
    start(e,true)
    assert(e.mod:GetCrazyCoconutData()==data and e.mod:GetCondomData()==bans)
    assert(bans.banned['101'] and data.players['101']==5 and data.playerCounts['202']==2)
    assert(data.pending['101']==pending and pending[1].remainingUpdates==2 and data.nextTraceToken==99)
    assert(e.mod.CrazyCoconutPickupSources['101:old']==source)
    preserved(root)
end)
check('fresh instance continue restores and settles confirmed pending once',function()
    local root=oldSave();local first=fixture({hasData=true,decodedData=root})
    local oldData=first.mod:GetCrazyCoconutData()
    local restoredRoot=copy(root);local e=fixture({hasData=true,decodedData=restoredRoot})
    local p=player(e,101,1);p.collectibles[e.items.NonBaby]=1;p:EvaluateItems()
    start(e,true)
    assert(e.mod:GetCrazyCoconutData()~=oldData and e.mod:IsCondomBanned(101))
    e.mod:TrackCrazyCoconutCopies();assert(restoredRoot.crazyCoconut.players['101']==5)
    e.mod:TrackCrazyCoconutCopies();assert(restoredRoot.crazyCoconut.players['101']==6)
    for _=1,5 do e.mod:TrackCrazyCoconutCopies()end
    assert(restoredRoot.crazyCoconut.players['101']==6 and #restoredRoot.crazyCoconut.pending['101']==0)
    assert(p.Damage==21.5 and oldData.players['101']==5)
    preserved(restoredRoot)
end)
for _,seed in ipairs({'TEST RUN','DIFFERENT RUN'})do
    check('fresh loader new run resets saved region: '..seed,function()
        local root=copy(oldSave());local e=fixture({hasData=true,decodedData=root,runSeed=seed})
        start(e,false)
        assert(next(root.condom.banned)==nil and next(root.crazyCoconut.players)==nil)
        assert(next(root.crazyCoconut.pending)==nil and root.crazyCoconut.nextTraceToken==1)
        assert(root.condom.runSeed==seed and root.crazyCoconut.runSeed==seed)
        preserved(root)
    end)
end
check('both new game-start registration failures roll back full entry',function()
    local load=dofile('tests/support/neverbirth_fixture.lua');load()
    for _,owner in ipairs({'scripts/features/condom.lua','scripts/features/crazy_coconut.lua'})do
        local previous,partial,callbacks=Neverbirth
        local ok,err=pcall(load,{
            OnModCreated=function(m,c)partial,callbacks=m,c end,
            AfterRegister=function(_,event,fn)
                if event==ModCallbacks.MC_POST_GAME_STARTED and debug.getinfo(fn,'S').source:gsub('\\','/'):find(owner,1,true)then
                    error('new-run registration failure '..owner)
                end
            end,
        })
        assert(not ok and tostring(err):find('new-run registration failure',1,true),owner..' missing callback')
        assert(Neverbirth==previous)
        for _,records in pairs(callbacks)do assert(#records==0,'partial callbacks retained')end
    end
end)
for _,failure in ipairs(failures)do print('FAIL '..failure)end
assert(#failures==0,#failures..'/'..count..' run lifecycle scenarios failed')
print('Condom/Coconut run lifecycle: '..count..' scenarios passed')
