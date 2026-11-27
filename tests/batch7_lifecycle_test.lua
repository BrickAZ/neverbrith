-- The same entry-driven scenarios run against a frozen baseline or current source.
local root, originalDofile = arg and arg[1], dofile
if root then
    dofile = function(path)
        if not path:match('^tests[/\\]') and not path:match('^%a:') then path = root .. path end
        return originalDofile(path)
    end
end
local savedArg = arg; arg = { '--fixture' }
local fixture = dofile('tests/strong_laxative_behavior_test.lua')
local towerFixture = dofile('tests/tower_of_babel_behavior_test.lua'); arg = {}
local function eq(a,b,label) assert(a==b, label .. ': '..tostring(a)..' ~= '..tostring(b)) end
local function player(e, copies, seed)
    return e.newPlayer({initSeed=seed, velocity=Vector(2,0), collectibles={[e.items.StrongLaxative]=copies or 1}})
end
local function creeps(e)
    local result={}
    for _,entity in ipairs(e.spawns) do
        if entity.GetData and entity:GetData().NeverbirthStrongLaxativeCreep then result[#result+1]=entity end
    end
    return result
end

-- A failed grid attempt does not consume the room allowance; random calls stay ordered.
do
    local e=fixture(); local p=player(e,20,71); p.Velocity=Vector(0,0)
    local mod=Neverbirth; local rngCalls={}
    function p:GetCollectibleRNG() return {RandomInt=function(_,n) rngCalls[#rngCalls+1]=n;return 0 end} end
    local room=Game():GetRoom(); local original=room.SpawnGridEntity
    room.SpawnGridEntity=function()return false end
    e.runPostUpdate(60)
    eq(mod.StrongLaxative.GetPoopRoomCount('1:0:1'),0,'failed grid does not count')
    eq(table.concat(rngCalls,','),'100,8,12','chance, position and variant consume RNG in order')
    room.SpawnGridEntity=original; e.runPostUpdate(60)
    eq(#e.gridSpawns,1,'retry at next scheduled roll succeeds')
    e.runPostUpdate(60*14); eq(#e.gridSpawns,15,'room cap')
    local count=#rngCalls; e.runPostUpdate(120)
    eq(#rngCalls,count,'cap prevents extra random consumption')
    e.runNewRoom(2); e.runPostUpdate(60); eq(#e.gridSpawns,16,'new room allowance')
    e.runNewRoom(1); e.runPostUpdate(60); eq(#e.gridSpawns,17,'reentry retains original reset policy')
end

-- Players have separate clocks, but the room allowance is shared.
do
    local e=fixture(); local a,b=player(e,20,81),player(e,20,82)
    a.Velocity,b.Velocity=Vector(0,0),Vector(0,0)
    local sa,sb=Neverbirth.StrongLaxative.GetState(a),Neverbirth.StrongLaxative.GetState(b)
    assert(sa~=sb); sa.sentinel=123
    e.runPostUpdate(59); eq(#e.gridSpawns,0,'no early roll')
    e.runPostUpdate(1); eq(#e.gridSpawns,2,'independent players roll')
    e.runPostUpdate(60*7); eq(#e.gridSpawns,15,'players share fifteen total')
    e.runNewRoom(3); eq(sa.poopTimer,0,'reset first clock'); eq(sb.poopTimer,0,'reset second clock')
    eq(sa.sentinel,123,'room reset preserves foreign state fields')
    a.collectibles[e.items.StrongLaxative]=0; e.runPostUpdate(1)
    a.collectibles[e.items.StrongLaxative]=1
    assert(Neverbirth.StrongLaxative.GetState(a)~=sa,'reacquire creates a new player clock')
    assert(Neverbirth.StrongLaxative.GetState(b)==sb,'other player retains its state')
end

-- Generation failures retry without starting the six-update cooldown.
do
    local e=fixture(); local p=player(e,1,91)
    local spawn=Isaac.Spawn; Isaac.Spawn=function() return nil end
    e.runPostUpdate(1); eq(Neverbirth.StrongLaxative.GetState(p).creepCooldown,0,'failed spawn keeps cooldown ready')
    Isaac.Spawn=spawn; e.runPostUpdate(1); eq(#creeps(e),1,'next update retries')
    e.runPostUpdate(5); eq(#creeps(e),1,'five intervening updates')
    e.runPostUpdate(1); eq(#creeps(e),2,'sixth update spawns')
    local old=creeps(e)[1]; local enemy=e.newEnemy(p.Position)
    p.Damage=100; p.collectibles[e.items.StrongLaxative]=0; e.runPostUpdate(1)
    e.runEffectUpdate(old,10); eq(enemy.damageTaken,1,'old creep keeps damage snapshot after item loss')
    p.alive=false; local age=old:GetData().Age; e.runEffectUpdate(old,1)
    assert(old.removed); eq(old:GetData().Age,age,'invalid owner exits before ticking')
end

-- Tower is a team-wide policy. Init removal and update fallback must agree.
do
    local e=towerFixture(); local p=player(e,20,101)
    local mod=Neverbirth
    local old=mod.StrongLaxative.SpawnCreep(p); old.FrameCount=30
    local tower=e.newPlayer({initSeed=102,collectibles={[e.items.TowerOfBabel]=1}})
    mod:RemoveTowerOfBabelNewCreepOnUpdate(old); assert(not old.removed,'existing creep stays')
    local fresh=mod.StrongLaxative.SpawnCreep(p)
    assert(fresh.removed and fresh:GetData().NeverbirthTowerOfBabelRemoved,'new creep removed and marked')
    local age=fresh:GetData().Age; mod:UpdateStrongLaxativeCreep(fresh)
    eq(fresh:GetData().Age,age,'removed creep cannot advance or damage')
    e.runPostUpdate(60)
    eq(mod.StrongLaxative.GetState(p).poopTimer,0,'tower owner roll timer')
    eq(mod.StrongLaxative.GetCopyCount(p),20,'tower test copies')
    eq(#e.gridSpawns,1,'poop still spawns with tower')
    tower.collectibles[e.items.TowerOfBabel]=0
    local after=mod.StrongLaxative.SpawnCreep(p); assert(not after.removed,'removing last tower permits new creep')
    tower.collectibles[e.items.TowerOfBabel]=1; after.FrameCount=1
    mod:RemoveTowerOfBabelNewCreepOnUpdate(after); assert(after.removed,'first-update fallback')
end
dofile=originalDofile; arg=savedArg
print('batch7 lifecycle: failure/RNG order, shared room cap, independent clocks, snapshot lifetime, removal order and tower coop passed')
