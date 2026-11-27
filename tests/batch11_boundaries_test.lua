local build = dofile('tests/support/burn_away_resentment_fixture.lua')
local function eq(a,b,message) assert(a==b,(message or '')..': '..tostring(a)..' ~= '..tostring(b)) end
local function near(a,b) assert(math.abs(a-b)<0.00001,tostring(a)..' ~= '..tostring(b)) end
local function setup()
    local e=build(); local p=e.newPlayer(); local enemy=e.newEnemy()
    e.mod:UpdateBurnAwayResentment()
    return e,p,enemy,e.mod.BurnAwayResentment.GetState(p)
end
local cases=0
local function check(label,fn) fn();cases=cases+1;print('PASS burn boundary: '..label) end

check('late enemy spawn, counted room reentry and ready-room policy',function()
    local e=build();local p=e.newPlayer();e.mod:UpdateBurnAwayResentment()
    local s=e.mod.BurnAwayResentment.GetState(p);eq(s.roomHadEnemies,false)
    s.currentLayers=6;local enemy=e.newEnemy();e.mod:UpdateBurnAwayResentment();eq(s.readyRoomKey,s.roomKey)
    enemy.removed=true;e.setRoomClear(true);e.mod:UpdateBurnAwayResentment();eq(s.roomCounted,true)
    e.runNewRoom();e.setRoomIndex(1);e.setRoomClear(false);e.newEnemy();e.mod:UpdateBurnAwayResentment()
    eq(s.roomCounted,true,'returning to counted room');eq(s.currentLayers,6)
end)
check('direct owner fallback, familiar exclusion and first-owner precedence',function()
    for _,kind in ipairs({'tear','laser','knife','bomb','familiar','nested','type-fallback','first-owner'}) do
        local e,p,enemy,s=setup();s.currentLayers=6;s.readyRoomKey=s.roomKey
        local types={tear=EntityType.ENTITY_TEAR,laser=EntityType.ENTITY_LASER,knife=EntityType.ENTITY_KNIFE,bomb=EntityType.ENTITY_BOMB}
        local source={Type=types[kind] or EntityType.ENTITY_TEAR,SpawnerEntity=p}
        if kind=='familiar' then source.Type=3 end
        if kind=='nested' then source.SpawnerEntity={Parent=p} end
        if kind=='type-fallback' then p.ToPlayer=function()error('conversion unavailable')end end
        if kind=='first-owner' then source.SpawnerEntity={};source.Parent=p end
        e.mod:HandleBurnAwayResentmentDamage(enemy,1,0,EntityRef(source),0)
        eq(s.floorSettled,not(kind=='familiar' or kind=='nested' or kind=='first-owner'),kind)
    end
end)
check('cancelled hurt expires on third update and lethal damage never queues',function()
    local e,p,enemy,s=setup();s.currentLayers=4
    e.mod:HandleBurnAwayResentmentDamage(p,1,0,EntityRef(enemy),0);eq(s.pendingHurtBurst.frames,3)
    e.mod:UpdateBurnAwayResentment();eq(s.pendingHurtBurst.frames,2)
    e.mod:UpdateBurnAwayResentment();eq(s.pendingHurtBurst.frames,1)
    e.mod:UpdateBurnAwayResentment();eq(s.pendingHurtBurst,nil);eq(s.currentLayers,4)
    e.mod:HandleBurnAwayResentmentDamage(p,8,0,EntityRef(enemy),0);eq(s.pendingHurtBurst,nil)
    e.mod:HandleBurnAwayResentmentDamage(p,1,DamageFlag.DAMAGE_NOKILL,EntityRef(enemy),0);eq(s.pendingHurtBurst,nil)
end)
check('health failures, string values and bone half-heart contribution',function()
    local e,p,enemy,s=setup();s.currentLayers=3
    p.GetHearts=function()error('released getter')end;p.GetSoulHearts=function()return '2'end;p.GetBoneHearts=function()return '1'end
    e.mod:HandleBurnAwayResentmentDamage(p,1,0,EntityRef(enemy),0);eq(s.pendingHurtBurst.preHealth,4)
    p.GetSoulHearts=function()return 0 end;e.mod:UpdateBurnAwayResentment()
    eq(s.floorSettled,true);eq(s.pendingClarity,3);eq(enemy.damageTaken,15)
end)
check('failed target damage does not suppress burn or later targets and nested damage is guarded',function()
    local e,p,enemy,s=setup();local second=e.newEnemy();s.currentLayers=6;s.readyRoomKey=s.roomKey
    enemy.TakeDamage=function()error('target damage failure')end
    local hits=0
    second.TakeDamage=function(_,amount)
        hits=hits+1;eq(amount,30)
        e.mod:HandleBurnAwayResentmentDamage(second,1,0,EntityRef({Type=EntityType.ENTITY_TEAR,SpawnerEntity=p}),0)
    end
    e.mod:HandleBurnAwayResentmentDamage(enemy,1,0,EntityRef({Type=EntityType.ENTITY_TEAR,SpawnerEntity=p}),0)
    eq(hits,1);eq(enemy.burnDuration,90);eq(second.burnDuration,90);eq(s.pendingClarity,6)
end)
check('strict friendly/dead results and unavailable liveness retain original policy',function()
    for _,value in ipairs({true,1,false}) do
        local e,p,enemy,s=setup();s.currentLayers=6;s.readyRoomKey=s.roomKey
        EntityFlag=EntityFlag or {};EntityFlag.FLAG_FRIENDLY=1
        enemy.HasEntityFlags=function()return value end;enemy.Exists=function()error('unavailable')end;enemy.IsDead=function()return 1 end
        e.mod:HandleBurnAwayResentmentDamage(enemy,1,0,EntityRef({Type=EntityType.ENTITY_TEAR,SpawnerEntity=p}),0)
        eq(s.floorSettled,value~=true)
    end
end)
check('public state replacement and GetState/head aliases remain dynamic',function()
    local e,p,enemy,s=setup();local view=e.mod.BurnAwayResentment
    local called=0;local original=view.GetState
    view.GetState=function(player)called=called+1;return original(player)end
    view.states={};e.mod:UpdateBurnAwayResentment();eq(called,1);assert(original(p)~=s)
    view.GetPlayerHeadWorldPosition=function()return Vector(31,47)end
    e.runRender();local render=e.spriteEvents[#e.spriteEvents]
    eq(render.type,'render');eq(render.position.X,1031);eq(render.position.Y,2047)
end)
check('world and screen coordinates stay distinct, existing failed conversion fallback preserved',function()
    local e=build();local p=e.newPlayer({position=Vector(100,200),positionOffset=Vector(7,11),flyingOffset=Vector(13,17),size=20})
    e.mod:UpdateBurnAwayResentment();e.runRender();local r=e.spriteEvents[#e.spriteEvents]
    eq(r.position.X,1120);eq(r.position.Y,2204)
    Isaac.WorldToScreen=function()error('camera unavailable')end;e.runRender();r=e.spriteEvents[#e.spriteEvents]
    eq(r.position.X,120);eq(r.position.Y,204)
end)
check('visual completion, room cleanup and 36-update timeout',function()
    local e,p,enemy,s=setup();s.currentLayers=6;s.readyRoomKey=s.roomKey
    e.mod:HandleBurnAwayResentmentDamage(enemy,1,0,EntityRef({Type=EntityType.ENTITY_TEAR,SpawnerEntity=p}),0)
    local function burstRenders()
        local n=0;for _,r in ipairs(e.spriteEvents)do if r.type=='render' and r.path:find('PurgeWave',1,true)then n=n+1 end end;return n
    end
    e.runRender();eq(burstRenders(),1)
    for _=1,35 do e.mod:UpdateBurnAwayResentment() end
    e.runRender();eq(burstRenders(),2)
    e.mod:UpdateBurnAwayResentment();e.runRender();eq(burstRenders(),2)
    e.runNewRoom();e.runRender();eq(burstRenders(),2)

    for _,boundary in ipairs({'finished','room'})do
        local x,owner,target,record=setup();record.currentLayers=6;record.readyRoomKey=record.roomKey
        x.mod:HandleBurnAwayResentmentDamage(target,1,0,EntityRef({Type=EntityType.ENTITY_TEAR,SpawnerEntity=owner}),0)
        local burst
        for _,sprite in ipairs(x.sprites)do if sprite.path:find('PurgeWave',1,true)then burst=sprite end end
        assert(burst);x.runRender();eq(#burst.renders,1)
        if boundary=='finished' then
            burst.IsFinished=function(_,animation)eq(animation,'Burst');return true end
            x.mod:UpdateBurnAwayResentment()
        else x.runNewRoom() end
        x.runRender();eq(#burst.renders,1,boundary..' clears an active burst before timeout')
    end
end)
check('clarity keeps direct delay arithmetic and current-floor banking',function()
    local e,p,enemy,s=setup();s.pendingClarity=5;s.currentLayers=2;e.runNewLevel()
    eq(s.currentFloorClarity,5);eq(s.currentLayers,0);eq(s.pendingClarity,0)
    p.MaxFireDelay=10;p.Damage=10;e.mod:EvaluateBurnAwayResentment(p,CacheFlag.CACHE_FIREDELAY)
    e.mod:EvaluateBurnAwayResentment(p,CacheFlag.CACHE_DAMAGE);near(p.MaxFireDelay,9.4);near(p.Damage,11.75)
    e.runGameStarted(true);eq(next(e.mod.BurnAwayResentment.states),nil)
    eq(s.player,nil);eq(s.statusSprite,nil);eq(s.pendingHurtBurst,nil)
end)
print('burn boundaries: '..cases..' cases passed')
