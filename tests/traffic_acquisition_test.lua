local fixture=dofile('tests/support/traffic_fixture.lua')
local failures,checks={},0
local function check(name,fn)
    checks=checks+1;local ok,err=pcall(fn)
    if not ok then failures[#failures+1]=name..': '..tostring(err) end
end
check('script grants leave nearby choice intact',function()
    local e=fixture();local choices=e.api.SpawnTrafficBossReward(3)
    for _,pickup in ipairs(choices) do e.event(ModCallbacks.MC_POST_PICKUP_UPDATE,pickup) end
    local p=e.player(100);e.grant(p,e.items.TrafficHeat);e.update()
    assert(not choices[1].removed and not choices[2].removed,'external grant stole choice')
    assert(e.api.GetPersistentData().heatByPlayer['100']==1,'external grant still pays its own reward')
end)
check('two queued coop choices settle once',function()
    local e=fixture();local choices=e.api.SpawnTrafficBossReward(3)
    local a,b=e.player(100),e.player(200)
    e.queuePickup(a,choices[1]);e.queuePickup(b,choices[2])
    e.flushPickup(a);e.flushPickup(b);e.update()
    assert(e.pool.draws==1,'first physical Exposure pays once')
    assert((e.api.GetPersistentData().heatByPlayer['200'] or 0)==0,'losing queued choice must not pay heat')
    assert(b:GetCollectibleNum(e.items.TrafficHeat)==0,'losing one-shot item removed')
    e.update(10);assert(e.pool.draws==1,'no duplicate later settlement')
end)
check('script grant during queue cannot claim physical receipt',function()
    local e=fixture();local choices=e.api.SpawnTrafficBossReward(3)
    local p=e.player(100);e.queuePickup(p,choices[2])
    e.grant(p,e.items.TrafficHeat);e.update()
    assert(not choices[1].removed,'still queued; scripted grant must not resolve choice')
    e.flushPickup(p);e.update()
    assert(choices[1].removed,'native queue flush resolves exact choice')
    assert(e.api.GetPersistentData().heatByPlayer['100']==2,'two genuinely acquired copies each pay')
end)
check('first confirmed player wins independently of update order',function()
    local e=fixture();local choices=e.api.SpawnTrafficBossReward(3)
    local a,b=e.player(100),e.player(200)
    e.queuePickup(a,choices[1]);e.queuePickup(b,choices[2])
    e.flushPickup(b);e.flushPickup(a);e.update()
    assert(e.pool.draws==0,'later Exposure cannot win just because player one updates first')
    assert(e.api.GetPersistentData().heatByPlayer['200']==1,'first confirmed Heat wins')
end)
check('reward spawning uses injected tier rules',function()
    local e=fixture();local called=0;local state={}
    local rules={GetRewardItemsForTier=function(tier)
        assert(tier==2);called=called+1;return {e.items.TrafficHeat}
    end}
    local rewards=dofile('scripts/features/little_leather_shoes/rewards.lua')({
        Runtime=state,Rules=rules,Presentation={},Items=e.items,Unboxing={},AddHeat=function() end,
        GetPlayers=function() return {} end,IsValidItemId=function(id) return id>0 end,
        CopyPosition=function(p) return p end, DataOf=function(p) return p:GetData() end,
        EntityKey=function(p) return tostring(p.InitSeed) end,PlayerKey=tostring,RoomKey=function() return 'room' end,
        Log=function() end,Animations={}
    })
    rewards.ResetFloor();local result=rewards.SpawnBossReward(2)
    assert(called==1 and result[1].SubType==e.items.TrafficHeat,'real spawner must consume supplied rule result')
end)
check('cancelled contact and removed pedestal grant',function()
    local e=fixture();local choices=e.api.SpawnTrafficBossReward(3);local p=e.player(100)
    e.event(ModCallbacks.MC_POST_PICKUP_UPDATE,choices[2])
    e.acquisitionEvent(ModCallbacks.MC_PRE_PICKUP_COLLISION,choices[2],p,false)
    e.frame=3;e.acquisitionEvent(ModCallbacks.MC_POST_UPDATE)
    choices[2]:Remove();e.grant(p,e.items.TrafficHeat);e.update()
    assert(not choices[1].removed,'removed pedestal is not acquisition proof')
end)
check('only acquired group resolves, regardless distance',function()
    local e=fixture();local near=e.api.SpawnTrafficBossReward(3);local actual=e.api.SpawnTrafficBossReward(3)
    for _,pickup in ipairs(near) do e.event(ModCallbacks.MC_POST_PICKUP_UPDATE,pickup) end
    actual[2].Position=Vector(999,999)
    local p=e.player(100);p.Position=near[2].Position
    e.queuePickup(p,actual[2]);e.flushPickup(p);e.update()
    assert(actual[1].removed and not near[1].removed and not near[2].removed,'must use receipt identity, never distance')
end)
for _,err in ipairs(failures) do print('FAIL '..err) end
assert(#failures==0,#failures..' / '..checks..' traffic regressions failed')
print('traffic acquisition: '..checks..' production-receipt scenarios passed')
