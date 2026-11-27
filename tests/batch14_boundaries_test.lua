-- Interactions use real public APIs from both modules, with engine objects doubled.
local groups = 0
local function check(name, fn)
    local observation = fn(); groups = groups + 1
    print('PASS ' .. name .. ' | ' .. tostring(observation or 'ok'))
end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function ownsAttack()
    local support=dofile('tests/support/avada_kedavra_fixture.lua')()
    return support.fixture().mod.AvadaKedavra.OwnsAttack
end
check('Annihilation yields tears to actual Avada ownership but retains aura', function()
    local owns=ownsAttack();local h=dofile('tests/support/annihilation_fixture.lua')();local e=h.makeEnvironment()
    local p=e.players[1];local npc=h.makeNpc();e.roomEntities[1]=npc
    e.mod.AvadaKedavra={OwnsAttack=owns};p.collectibles[57]=1;e.use(p)
    local tear=h.makeTear(p);e.fireTear(tear);eq(tear.removed,false);e.update(4)
    eq(#npc.damageEvents,1);eq(npc.damageEvents[1].amount,p.Damage*0.4)
    p.collectibles[57]=nil;local nextTear=h.makeTear(p);e.fireTear(nextTear);eq(nextTear.removed,true)
    local state=e.api.GetState(p);eq(#state.shockwaves,1)
    local allyTear=h.makeTear(e.players[2]);e.fireTear(allyTear);eq(allyTear.removed,false)
    return 'aura='..npc.damageEvents[1].amount..';waves='..#state.shockwaves..';ally=false'
end)
check('Annihilation source precedence and dynamic replacement are retained', function()
    local h=dofile('tests/support/annihilation_fixture.lua')();local e=h.makeEnvironment();local p=e.players[1];e.use(p)
    local tear=h.makeTear({ToPlayer=function() return nil end});tear.Parent=p;e.fireTear(tear);eq(tear.removed,false)
    e.mod.AvadaKedavra={OwnsAttack=function()return true end};local t=h.makeTear(p);e.fireTear(t);eq(t.removed,false)
    e.mod.AvadaKedavra={OwnsAttack=function()return false end};e.fireTear(t);eq(t.removed,true)
    e.mod.AvadaKedavra.OwnsAttack=function()error('ownership failure')end
    local ok,err=pcall(e.fireTear,h.makeTear(p));assert(not ok and tostring(err):find('ownership failure',1,true))
    return 'parentIgnored=true;liveReplacement=true;errorPropagated=true'
end)
check('Cleaver refuses and cancels swings under actual Avada ownership', function()
    local owns=ownsAttack();local h=dofile('tests/support/cleaver_character_fixture.lua')();local e=h.loadNeverbirth({roomClear=false})
    eq(Neverbirth.Cleaver.Config.Registered,false);h.configureCleaver()
    local p=e.newPlayer({playerType=42,collectibles={[57]=1}});local ally=e.newPlayer({playerType=42,collectibles={}})
    Neverbirth.AvadaKedavra={OwnsAttack=owns};eq(Neverbirth.Cleaver.TrySwing(p,Vector(1,0)),false)
    assert(Neverbirth.Cleaver.TrySwing(ally,Vector(1,0)))
    p.collectibles[57]=nil;assert(Neverbirth.Cleaver.TrySwing(p,Vector(1,0)))
    for _=1,10 do e.runPostUpdate()end
    local carrier=assert(Neverbirth.Cleaver.GetState(p).swing.nativeKnife);p.collectibles[57]=1;e.runPostUpdate()
    eq(Neverbirth.Cleaver.GetState(p).swing,nil);assert(carrier.removed)
    assert(Neverbirth.Cleaver.GetState(ally).swing)
    return 'blocked=true;cancelled=true;otherOwnerActive=true'
end)
check('Cleaver public methods remain dynamic and room reset releases references', function()
    local h=dofile('tests/support/cleaver_character_fixture.lua')();local e=h.loadNeverbirth();h.configureCleaver()
    local p=e.newPlayer({playerType=42});local calls=0
    Neverbirth.Cleaver.GetTriggeredShootDirection=function(player)eq(player,p);calls=calls+1;return Vector(1,0)end
    e.runPostUpdate();assert(calls>0);assert(Neverbirth.Cleaver.GetState(p).swing)
    for _=1,10 do e.runPostUpdate()end
    local carrier=assert(e.getLatestKnife());e.runNewRoom();assert(carrier.removed);eq(Neverbirth.Cleaver.GetState(p).swing,nil)
    eq(next(Neverbirth.Cleaver.shadows),nil)
    return 'dynamicInput=true;swingsEmpty=true;carrierRemoved=true'
end)
check('Cleaver world offsets cross camera transform exactly once', function()
    local h=dofile('tests/support/cleaver_character_fixture.lua')();local e=h.loadNeverbirth({roomClear=true});h.configureCleaver()
    e.newPlayer({playerType=42,collectibles={},position=Vector(40,50),positionOffset=Vector(3,7),flyingOffset=Vector(5,-11)})
    e.runPostUpdate();local calls={}
    Isaac.WorldToScreen=function(v)calls[#calls+1]=v;return Vector(v.X+100,v.Y+200)end
    e.runRender();eq(#calls,1);eq(calls[1].X,48);eq(calls[1].Y,46)
    local rendered=e.spriteEvents[#e.spriteEvents];eq(rendered.type,'render')
    eq(rendered.path,Neverbirth.Cleaver.Config.HoldVisualPath);eq(rendered.position.X,148);eq(rendered.position.Y,246)
    return 'world=48,46;screen=148,246'
end)
check('Avada reset rebinds state and restores weapon without resetting cast sequence', function()
    local h=dofile('tests/support/avada_kedavra_fixture.lua')();local e=h.fixture();local p=e.player();e.npc()
    p.input[5]=1;for _=1,29 do e.tick(p) end
    local first;e.release(p,function()first=e.root(p)end)
    local firstMark=first:GetData().NeverbirthAvadaCast;assert(firstMark)
    e.call('MC_POST_GAME_STARTED',true);eq(e.mod.AvadaKedavra.Status(p).phase,'not_initialized');eq(p:GetWeapon(1):GetWeaponType(),1)
    p.input[5]=1;for _=1,29 do e.tick(p) end
    local second;e.release(p,function()second=e.root(p)end)
    local secondMark=second:GetData().NeverbirthAvadaCast;assert(secondMark.id>firstMark.id)
    e.mod.AvadaKedavra.IsFailureDeath=function(q)eq(q,p);return true end;eq(e.call('MC_PRE_PLAYER_REVIVE',p),false)
    return 'castIds='..firstMark.id..','..secondMark.id..';weaponRestored=true;dynamicRevive=true'
end)
check('real Annihilation aura kill is not an Avada laser receipt', function()
    local h=dofile('tests/support/avada_kedavra_fixture.lua')();local e=h.fixture();local p=e.player();local target=e.npc()
    p.input[5]=1;for _=1,29 do e.tick(p)end
    local root;e.release(p,function()root=e.root(p)end);local laser=e.laser(root)
    ModCallbacks.MC_USE_ITEM=801;ModCallbacks.MC_POST_NPC_DEATH=802;CacheFlag.CACHE_RANGE=16
    EntityRef=function(value)return {Entity=value}end
    function target:TakeDamage(amount,flags,source)
        e.call('MC_ENTITY_TAKE_DMG',self,amount,flags,source,0)
        self.dead=true;self.HitPoints=0
        e.call('MC_POST_ENTITY_TAKE_DMG',self,amount,flags,source,0)
        e.call('MC_POST_ENTITY_KILL',self);return true
    end
    local api=dofile('annihilation.lua')(e.mod,{ItemId=9053,Variants={},GetPlayers=function()return e.players end,
        GetRoomEntities=function()return e.npcs end,SpawnEffect=function()return nil end})
    api.StartState(p);for _=1,4 do e.advance();e.call('MC_POST_UPDATE')end
    assert(target.dead);e.remove(root);e.remove(laser);e.tick(p);e.tick(p)
    eq(p.kills,1);eq(e.mod.AvadaKedavra.IsFailureDeath(p),true)
    return 'auraKilled=true;AvadaFailure=true;ownerKills='..p.kills
end)
print('batch14 boundaries: '..groups..' groups passed')
