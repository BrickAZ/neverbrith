local savedArg=arg;arg={'--fixture'}
local fixture=dofile('tests/folk_horror_items_behavior_test.lua');arg=savedArg
local failures,checks={},0
local function check(name,fn)
    checks=checks+1;local ok,err=pcall(fn)
    if not ok then failures[#failures+1]=name..': '..tostring(err) end
end
local function start(e,continued)
    local callbacks=e.getCallbacks(ModCallbacks.MC_POST_GAME_STARTED)
    assert(#callbacks>0)
    for _,fn in ipairs(callbacks)do fn(e.mod,continued) end
end
local function owner(e,seed,copies)
    return e.newPlayer({initSeed=seed,collectibles={[e.items.BlackTaisui]=1,[e.items.MeatLump]=copies or 1}})
end
local function prepared()
    local store={snapshot={sentinel={keep=77},blackTaisui={runSeed='TEST RUN',extension='keep'}}}
    local e=fixture({savedStore=store})
    local a,b=owner(e,101,2),owner(e,202,1)
    e.mod:SetBlackTaisuiParasiteValue(a,16);e.mod:SetBlackTaisuiParasiteValue(b,8)
    e.mod:TrackMeatLumpPlayerCopies(a);e.mod:TrackMeatLumpPlayerCopies(b)
    e.mod:AddMeatLumpLife(a,1)
    assert(e.mod:GetMeatLumpLifeCount(a)==3 and e.mod:GetMeatLumpLifeCount(b)==1)
    return e,store,a,b
end
local function cache(e,p)
    p.evaluations=0
    function p:EvaluateItems()
        self.evaluations=self.evaluations+1
        self.Damage,self.MoveSpeed,self.MaxFireDelay,self.TearRange,self.Luck=3.5,1,10,260,0
        for _,flag in ipairs({CacheFlag.CACHE_DAMAGE,CacheFlag.CACHE_SPEED,CacheFlag.CACHE_FIREDELAY,CacheFlag.CACHE_RANGE,CacheFlag.CACHE_LUCK})do
            e.runEvaluate(self,flag)
        end
    end
end
check('same seed new run clears saved progression for every player',function()
    local e,store,a,b=prepared();cache(e,a);a:EvaluateItems()
    local matureDamage=a.Damage
    start(e,false)
    for _,p in ipairs({a,b})do
        assert(e.mod:GetBlackTaisuiParasiteValue(p)==0,'parasite carried into new run')
        assert(e.mod:GetMeatLumpLifeCount(p)==0,'life carried into new run')
        assert(not e.mod:GetBlackTaisuiSavedPlayer(p).meatLumpSpawned,'reward already-paid marker carried over')
    end
    assert(a.Damage<matureDamage,'new-run cache still uses old mature stage')
    assert(next(store.snapshot.blackTaisui.meatLumpCounts)==nil,'acquisition snapshot must reset')
    assert(store.snapshot.sentinel.keep==77 and store.snapshot.blackTaisui.extension=='keep','unowned data lost')
    start(e,false)
    assert(e.mod:GetMeatLumpLifeCount(a)==0,'repeated cleanup must remain empty')
    e.mod:TrackMeatLumpPlayerCopies(a)
    assert(e.mod:GetMeatLumpLifeCount(a)==2,'new run counts its own copies exactly once')
    e.mod:TrackMeatLumpPlayerCopies(a);assert(e.mod:GetMeatLumpLifeCount(a)==2)
    e.mod:SetBlackTaisuiParasiteValue(a,16)
    assert(e.mod:GetBlackTaisuiSavedPlayer(a).meatLumpSpawned,'new run may earn stage-three reward again')
end)
check('fresh module instance restores saved run without replaying grants',function()
    local first,store,a=prepared()
    local oldData=first.mod:GetBlackTaisuiData()
    for _,fn in ipairs(first.getCallbacks(ModCallbacks.MC_PRE_GAME_EXIT))do fn(first.mod,true) end
    local restored=fixture({savedStore=store});local p,q=owner(restored,101,2),owner(restored,202,1)
    start(restored,true)
    assert(restored.mod:GetBlackTaisuiData()~=oldData,'must decode into a fresh instance')
    assert(restored.mod:GetBlackTaisuiParasiteValue(p)==16 and restored.mod:GetBlackTaisuiParasiteValue(q)==8)
    assert(restored.mod:GetMeatLumpLifeCount(p)==3 and restored.mod:GetMeatLumpLifeCount(q)==1)
    restored.runPostAddCollectible(restored.items.MeatLump,p);restored.mod:TrackMeatLumpPlayerCopies(p)
    assert(restored.mod:GetMeatLumpLifeCount(p)==3,'loaded copies must not add lives again')
    local count=#restored.spawns;restored.mod:EnsureBlackTaisuiStageThreeReward(p)
    assert(#restored.spawns==count,'loaded paid reward must not spawn again')
    assert(store.snapshot.sentinel.keep==77 and store.snapshot.blackTaisui.extension=='keep')
end)
check('fresh loader same-seed new run resets persisted old save',function()
    local _,store=prepared();local e=fixture({savedStore=store});start(e,false)
    local p=owner(e,101,2)
    assert(e.mod:GetBlackTaisuiParasiteValue(p)==0 and e.mod:GetMeatLumpLifeCount(p)==0)
    assert(not e.mod:GetBlackTaisuiSavedPlayer(p).meatLumpSpawned)
end)
check('different seed new run retains extension fields',function()
    local _,store=prepared();local e=fixture({savedStore=store,runSeed='NEW RUN'});start(e,false)
    assert(store.snapshot.blackTaisui.runSeed=='NEW RUN')
    assert(store.snapshot.blackTaisui.extension=='keep' and store.snapshot.sentinel.keep==77)
    assert(next(store.snapshot.blackTaisui.meatLumpLives)==nil)
end)
local function brokenMask()
    local e=fixture();local p=e.newPlayer({initSeed=301,coins=5,collectibles={[e.items.CoinFacedMask]=1}})
    cache(e,p);e.runNewRoom();p.coins=0;e.runDamage(p,1,0,e.newEnemy())
    assert(p.Luck==-2);return e,p
end
check('mask removed before next cache never reapplies penalty',function()
    local e,p=brokenMask();p.collectibles[e.items.CoinFacedMask]=nil;p:EvaluateItems()
    assert(p.Luck==0,'absent item still applies penalty')
    e.mod:UpdateCoinFacedMaskCostumes();assert(p.Luck==0)
end)
check('mask removal without automatic cache refresh settles once',function()
    local e,p=brokenMask();local before=p.evaluations
    p.collectibles[e.items.CoinFacedMask]=nil;e.mod:UpdateCoinFacedMaskCostumes()
    assert(p.Luck==0 and p.evaluations==before+1,'cleanup must refresh existing penalty once')
    for _=1,20 do e.mod:UpdateCoinFacedMaskCostumes() end
    assert(p.evaluations==before+1,'idle update must not repeatedly refresh')
end)
check('one player losing mask preserves the other penalty',function()
    local e,p=brokenMask();local q=e.newPlayer({initSeed=302,coins=5,collectibles={[e.items.CoinFacedMask]=1}})
    cache(e,q);e.runNewRoom();p.coins=5;e.mod:UpdateCoinFacedMaskCostumes()
    p.coins=0;q.coins=0;e.runDamage(p,1,0,e.newEnemy());e.runDamage(q,1,0,e.newEnemy())
    assert(p.Luck==-2 and q.Luck==-2)
    local qBefore=q.evaluations;p.collectibles[e.items.CoinFacedMask]=nil;e.mod:UpdateCoinFacedMaskCostumes()
    assert(p.Luck==0 and q.Luck==-2 and q.evaluations==qBefore,'other player was changed')
end)
for _,err in ipairs(failures)do print('FAIL '..err) end
assert(#failures==0,#failures..' / '..checks..' folk lifecycle regressions failed')
print('folk lifecycle regression: '..checks..' scenarios passed')
