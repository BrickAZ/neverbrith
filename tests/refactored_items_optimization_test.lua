-- Regression cases for the reviewed batch 1-4 items, through production modules.
local failures, checks = {}, 0
local function check(label, fn)
    checks = checks + 1
    local ok, err = pcall(fn)
    if not ok then failures[#failures + 1] = label .. ': ' .. tostring(err) end
end
local luaRoot = arg and arg[1] or ''
local fixture = dofile('tests/support/neverbirth_fixture.lua')
local function spring()
    local e = fixture({ Root = luaRoot })
    local p = { InitSeed = 123, charges = {[0]=0,[1]=4,[2]=0,[3]=0}, TearFlags=0, evaluations=0, damage=0 }
    function p:GetActiveCharge(slot) return self.charges[slot or 0] end
    function p:GetActiveItem(slot) return self.items and self.items[slot] or 0 end
    function p:DischargeActiveItem(slot) self.charges[slot or 0]=0 end
    function p:TakeDamage(n) self.damage=self.damage+n end
    function p:AddCacheFlags() end
    function p:EvaluateItems() self.evaluations=self.evaluations+1 end
    function p:AddEntityFlags() end
    function p:ClearEntityFlags() end
    function p:ToPlayer() return self end
    Isaac.FindByType=function(kind) return kind==EntityType.ENTITY_PLAYER and {p} or {} end
    return Neverbirth, p, e.itemIds.Aphrodisiac
end
for slot=0,3 do
    check('Chunyao uses slot '..slot, function()
        local mod,p,id=spring();p.charges[slot]=1
        assert(mod:UseChunyao(id,nil,p,0,slot)==true,'charged selected slot must activate')
        assert(p.charges[slot]==0 and p.damage==1,'only one activation cost')
        for other=0,3 do if other~=slot then
            assert(p.charges[other]==(other==1 and 4 or 0),'another slot was discharged')
        end end
    end)
end
check('native single-use pocket has no charge bar',function()
    local mod,p,id=spring();p.items={[3]=id}
    assert(p:GetActiveCharge(3)==0)
    assert(mod:UseChunyao(id,nil,p,0,3)==true and p.damage==1,'owned single-use pocket must activate')
    p.items={};assert(mod:UseChunyao(id,nil,p,0,3)==false and p.damage==1,'empty pocket cannot activate')
end)
check('Chunyao cache at effect boundaries', function()
    local mod,p,id=spring();p.charges[0]=1;mod:UseChunyao(id,nil,p,0,0)
    for _=1,30 do mod:UpdateChunyaoEffects() end
    assert(p.evaluations==1,'unchanged timers must not recalculate stats')
    p.charges[0]=1;mod:UseChunyao(id,nil,p,0,0)
    for _=1,59 do mod:UpdateChunyaoEffects() end
    assert(p.evaluations==2,'two live stacks still use activation caches')
    mod:UpdateChunyaoEffects();assert(p.evaluations==3,'first expiry refreshes once')
    for _=1,30 do mod:UpdateChunyaoEffects() end
    assert(p.evaluations==4,'second expiry refreshes once')
end)
check('single Chunyao effect needs only two cache refreshes',function()
    local mod,p,id=spring();p.charges[0]=1;mod:UseChunyao(id,nil,p,0,0)
    for _=1,90 do mod:UpdateChunyaoEffects() end
    assert(p.evaluations==2,'one activation plus one expiration')
end)
local loadBoxes = assert(loadfile('tests/angelbox_behavior_test.lua'))('--fixture')
local function start(e, continued)
    for _,fn in ipairs(e.getCallbacks(ModCallbacks.MC_POST_GAME_STARTED)) do fn(e.mod,continued) end
end
for _,name in ipairs({'Angelbox','Devilbox'}) do
    check(name..' same-seed fresh run and continue',function()
        local e=loadBoxes();local id=e.items[name]
        local p=e.newPlayer({initSeed=123,activeItems={[0]=id},activeCharges={[0]=4}})
        e.getCallback(ModCallbacks.MC_USE_ITEM,id)(e.mod,id,nil,p,0,0)
        local field=name=='Angelbox' and 'addedSoulHearts' or 'addedBlackHearts'
        assert(p[field]==6,'first use baseline')
        local root=e.savedStore;root.snapshot.sentinel={value=42};root.snapshot[name:lower()].extension='keep'
        local floorFields={'pendingRewards','appliedChanceFloors',name=='Angelbox' and 'enteredAngelFloors' or 'enteredDevilFloors',name=='Angelbox' and 'forcedAngelFloors' or 'forcedDevilFloors'}
        for _,field in ipairs(floorFields) do root.snapshot[name:lower()][field].oldFloor=17 end
        local continued=loadBoxes(root);start(continued,true)
        for _,field in ipairs(floorFields) do assert(continued.savedStore.snapshot[name:lower()][field].oldFloor==17,'continue keeps '..field) end
        local q=continued.newPlayer({initSeed=123,activeItems={[0]=id},activeCharges={[0]=4}})
        continued.getCallback(ModCallbacks.MC_USE_ITEM,id)(continued.mod,id,nil,q,0,0)
        assert(q[field]==0,'continue must preserve first-use record')
        local fresh=loadBoxes(root);start(fresh,false)
        local r=fresh.newPlayer({initSeed=123,activeItems={[0]=id},activeCharges={[0]=4}})
        fresh.getCallback(ModCallbacks.MC_USE_ITEM,id)(fresh.mod,id,nil,r,0,0)
        assert(r[field]==6,'same-seed new run must recover first-use benefit')
        assert(fresh.savedStore.snapshot.sentinel.value==42 and fresh.savedStore.snapshot[name:lower()].extension=='keep','unknown fields preserved')
        local section=fresh.savedStore.snapshot[name:lower()]
        for _,field in ipairs(floorFields) do assert(next(section[field])==nil,'fresh run clears '..field) end
    end)
end
check('Box bonus dedup lifetime',function()
    local e=loadBoxes();e.newPlayer()
    e.mod:HandleBoxHeartPickupInit(e.newSoulHeartPickup(nil,5));assert(#e.spawned==1)
    start(e,true);e.mod:HandleBoxHeartPickupInit(e.newSoulHeartPickup(nil,5));assert(#e.spawned==1,'same-instance continue keeps dedup')
    start(e,false);e.mod:HandleBoxHeartPickupInit(e.newSoulHeartPickup(nil,5));assert(#e.spawned==2,'new run forgets old seed')
end)
for _,err in ipairs(failures) do print('FAIL '..err) end
assert(#failures==0, tostring(#failures)..' / '..checks..' optimization regressions failed')
print('refactored item optimization: '..checks..' regressions passed')
