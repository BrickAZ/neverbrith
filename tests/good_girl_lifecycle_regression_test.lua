local savedArg=arg;arg={'--fixture'}
local fixture=dofile('tests/good_girl_of_babylon_behavior_test.lua');arg=savedArg
local failures,count={},0
local function check(name,fn)
    count=count+1
    local ok,err=pcall(fn)
    if not ok then failures[#failures+1]=name..': '..tostring(err) end
end
local function cachedPlayer(e,options)
    local p=e.newPlayer(options)
    p.evaluations=0
    function p:EvaluateItems()
        self.evaluations=self.evaluations+1
        self.Damage,self.MoveSpeed,self.Luck,self.MaxFireDelay=3.5,1,0,10
        for _,flag in ipairs({CacheFlag.CACHE_DAMAGE,CacheFlag.CACHE_SPEED,CacheFlag.CACHE_LUCK,CacheFlag.CACHE_FIREDELAY})do
            e.runEvaluate(self,flag)
        end
    end
    p:EvaluateItems();e.runPostUpdate()
    return p
end
check('health transitions refresh once in both directions',function()
    local e=fixture();local p=cachedPlayer(e,{hearts=4,maxHearts=6})
    local before=p.evaluations
    p.hearts=6;e.runPostUpdate()
    assert(p.Luck==2 and p.MaxFireDelay==9.4,'full health bonuses missing')
    assert(p.evaluations==before+1)
    e.runPostUpdate(20);assert(p.evaluations==before+1,'idle full health refreshed repeatedly')
    p.hearts=4;e.runPostUpdate()
    assert(p.Luck==0 and p.MaxFireDelay==10,'non-damage health loss left old bonuses')
    assert(p.evaluations==before+2)
    e.runPostUpdate(20);assert(p.evaluations==before+2)
end)
check('broken state stays broken when healed and echo expires normally',function()
    local e=fixture();local p=cachedPlayer(e)
    e.runDamage(p,1,DamageFlag.DAMAGE_RED_HEARTS);p.hearts=4
    local before=p.evaluations;local state=GetGoodGirlState(p)
    assert(state.echoFrames==150 and p.Damage==4.7 and p.Luck==-2)
    e.runPostUpdate(10);p.hearts=6;e.runPostUpdate()
    assert(state.broken and p.Luck==-2 and p.MaxFireDelay==10)
    assert(p.evaluations==before,'healing cannot reactivate broken presentable state')
    e.runPostUpdate(139)
    assert(state.echoFrames==0 and p.Damage==3.5 and p.MoveSpeed==1 and p.Luck==-2)
    assert(p.evaluations==before+1,'echo expiry refreshes once')
end)
check('removal ends echo and visuals but preserves room settlement',function()
    local e=fixture();local p=cachedPlayer(e)
    e.runDamage(p,1,DamageFlag.DAMAGE_RED_HEARTS);e.runPostUpdate()
    e.setRoomClear(true);e.runPostUpdate()
    local state=GetGoodGirlState(p);local effect=state.echoEffect
    assert(state.rewarded and state.redDamaged and effect)
    local before=p.evaluations
    p.collectibles[e.items.GoodGirlOfBabylon]=nil;e.runPostUpdate()
    assert(state.echoFrames==0 and state.echoEffect==nil and state.haloEffect==nil,'echo survives removal')
    assert(effect.removed,'follow effect not removed')
    assert(state.broken and state.redDamaged and state.rewarded,'room records erased')
    assert(p.Damage==3.5 and p.MoveSpeed==1 and p.Luck==0,'removed item stats remain')
    assert(p.evaluations==before+1)
    e.runPostUpdate(180);assert(p.evaluations==before+1,'absent item keeps refreshing')
    local rolls=p.rngIndex
    p.collectibles[e.items.GoodGirlOfBabylon]=1;p:EvaluateItems();e.runPostUpdate()
    assert(GetGoodGirlState(p)==state and state.echoFrames==0 and p.Damage==3.5)
    assert(state.rewarded and state.broken and p.Luck==-2 and p.rngIndex==rolls,'reacquisition replays room benefits')
end)
check('removal after echo expiry clears broken luck once',function()
    local e=fixture();local p=cachedPlayer(e)
    e.runDamage(p,1,DamageFlag.DAMAGE_RED_HEARTS);e.runPostUpdate(150)
    local before=p.evaluations;local state=GetGoodGirlState(p)
    p.collectibles[e.items.GoodGirlOfBabylon]=nil;e.runPostUpdate(20)
    assert(p.Luck==0 and p.evaluations==before+1 and state.broken)
end)
check('removal clears active halo and is safe after native cache first',function()
    local e=fixture();local p=cachedPlayer(e)
    local state=GetGoodGirlState(p);local halo=state.haloEffect
    assert(halo)
    p.collectibles[e.items.GoodGirlOfBabylon]=nil;p:EvaluateItems();e.runPostUpdate()
    assert(p.Luck==0 and p.MaxFireDelay==10 and state.haloEffect==nil and halo.removed)
    local before=p.evaluations;e.runPostUpdate(20);assert(p.evaluations==before)
end)
check('player transitions and new room stay independent',function()
    local e=fixture();local p=cachedPlayer(e,{initSeed=101,hearts=4,maxHearts=6})
    local q=cachedPlayer(e,{initSeed=202})
    e.runDamage(q,1,DamageFlag.DAMAGE_RED_HEARTS);e.runPostUpdate()
    local qState=GetGoodGirlState(q);local qBefore=q.evaluations;local echo=qState.echoFrames
    p.hearts=6;e.runPostUpdate()
    assert(p.Luck==2 and q.Luck==-2 and q.evaluations==qBefore and qState.echoFrames==echo-1)
    p.collectibles[e.items.GoodGirlOfBabylon]=nil;e.runPostUpdate()
    assert(q.evaluations==qBefore and q.Damage==4.7)
    p.collectibles[e.items.GoodGirlOfBabylon]=1;e.runNewRoom()
    assert(not GetGoodGirlState(q).broken and q.Luck==2 and q.Damage==3.5)
    local before=q.evaluations;e.runPostUpdate(20);assert(q.evaluations==before,'new room refresh should not repeat')
end)
for _,failure in ipairs(failures)do print('FAIL '..failure)end
assert(#failures==0,#failures..'/'..count..' Good Girl lifecycle scenarios failed')
print('Good Girl lifecycle regression: '..count..' scenarios passed')
