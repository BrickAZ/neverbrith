local cases = 0
local function check(name, fn)
    fn(); cases = cases + 1; print('PASS batch18: ' .. name)
end
local f = dofile('tests/support/night_of_the_cowards_fixture.lua')
local eq = f.assertEquals
local function cowards() return f.makeEnvironment() end

check('morph failure clears attempt marker and retries with champion and deterministic variant', function()
    local e = cowards(); local n = f.makeNpc({seed=103,champion=7})
    local morph = n.Morph; local calls = 0
    n.Morph = function(...) calls=calls+1;if calls==1 then error('native morph failure') end;return morph(...) end
    eq(e.api.TransformEnemy(n),false);eq(n.data.NeverbirthCowardsNightTransformed,nil)
    eq(e.api.TransformEnemy(n),true);eq(n.Type,27);eq(n.Variant,1);eq(n.morphChampion,7)
    eq(e.api.TransformEnemy(n),false);eq(calls,2)
end)
check('ineligible enemy keeps original attempted marker even after becoming vulnerable', function()
    local e=cowards();local n=f.makeNpc({vulnerable=false})
    eq(e.api.TransformEnemy(n),false);eq(n.data.NeverbirthCowardsNightTransformed,true)
    n.vulnerable=true;eq(e.api.TransformEnemy(n),false);eq(n.morphCalls,0)
end)
check('aura eligibility remains distinct from morph eligibility and protects failed native queries', function()
    local e=cowards();local n=f.makeNpc({boss=true,vulnerable=false})
    eq(e.api.IsAuraEnemy(n),true);eq(e.api.IsTransformableEnemy(n),false)
    n.Exists=function()error('expired handle')end;eq(e.api.IsAuraEnemy(n),false)
    n.Exists=function()return true end;n.IsActiveEnemy=function()return 1 end;eq(e.api.IsAuraEnemy(n),false)
    n.IsActiveEnemy=function()return true end;n.HasEntityFlags=function()return 1 end;eq(e.api.IsAuraEnemy(n),true)
end)
check('aura removal unlinks both sides without removing a replacement owned by another instance', function()
    local e=cowards();e.update();local n=f.makeNpc();e.updateNpc(n);local aura=e.effects[1]
    eq(aura.data.NeverbirthCowardsNightAuraOwner,n);eq(n.data.NeverbirthCowardsNightAura,aura)
    local replacement={};n.data.NeverbirthCowardsNightAura=replacement;n.dead=true;e.updateEffect(aura)
    eq(aura.removed,true);eq(aura.data.NeverbirthCowardsNightAuraOwner,nil)
    eq(n.data.NeverbirthCowardsNightAura,replacement)
end)
check('spawn failure retries while removed cached aura is replaced once', function()
    local e=cowards();local n=f.makeNpc();local spawn=Isaac.Spawn
    Isaac.Spawn=function()error('spawn failed')end;eq(e.api.EnsureAura(n),nil)
    Isaac.Spawn=spawn;local a=e.api.EnsureAura(n);eq(e.api.EnsureAura(n),a);eq(#e.effects,1)
    a.removed=true;local b=e.api.EnsureAura(n);assert(b~=a);eq(#e.effects,2)
end)
check('c20 grant failure is not saved and successful retry is once per seed-keyed player', function()
    local e=cowards();local p=e.players[1];local add=p.AddCollectible
    p.AddCollectible=function()error('grant failed')end;eq(e.api.GrantTranscendenceOnce(p),false);eq(e.getSaveCalls(),0)
    p.AddCollectible=add;eq(e.api.GrantTranscendenceOnce(p),true);eq(e.getSaveCalls(),1)
    eq(e.api.GrantTranscendenceOnce(p),false);eq(#p.addCollectibleCalls,1)
    p.GetCollectibleNum=function()error('count failed')end;p.HasCollectible=function()return true end
    local other=f.makePlayer(3,1,Vector.Zero);eq(e.api.GrantTranscendenceOnce(other),true)
end)
check('continued save accepts numeric-string run seed and resolves replaced root each time', function()
    local seed=12345;local e=f.makeEnvironment({GetCurrentRunSeed=function()return seed end})
    local root={nightOfTheCowards={runSeed='12345',c20Granted={['1']=true}}};e.setSaveRoot(root)
    e.api.Callbacks.GameStarted(nil,true);e.update();eq(#e.players[1].addCollectibleCalls,0)
    root={nightOfTheCowards={runSeed=12345,c20Granted={}}};e.setSaveRoot(root);e.update()
    eq(#e.players[1].addCollectibleCalls,1);eq(root.nightOfTheCowards.c20Granted['1'],true)
    seed=987;e.api.Callbacks.GameStarted(nil,false);e.update()
    eq(root.nightOfTheCowards.runSeed,987);eq(#e.players[1].addCollectibleCalls,2)
end)
check('runtime identity, room and exit clear blocks and auras without undoing flight grant', function()
    local e=cowards();local runtime=e.api.Runtime;local n=f.makeNpc();e.setNearby({n});e.update();e.updateNpc(n)
    eq(runtime.active,true);eq(e.input(e.players[1],InputHook.GET_ACTION_VALUE,ButtonAction.ACTION_SHOOTLEFT),0)
    e.newRoom();eq(e.api.Runtime,runtime);eq(#runtime.auras,0);eq(next(runtime.blockedPlayers),nil)
    eq(runtime.active,true);eq(#e.players[1].addCollectibleCalls,1)
    e.api.Callbacks.PreGameExit();eq(runtime.active,false);eq(next(runtime.fearSprites),nil)
    e.api.Callbacks.GameStarted(nil,true);e.update();eq(#e.players[1].addCollectibleCalls,1)
end)
check('fear render consumes world-to-screen conversion once and skips failed conversion', function()
    local e=cowards();local p=e.players[1];local n=f.makeNpc();e.setNearby({n});e.update()
    p.PositionOffset=Vector(11,13);p.SpriteOffset=Vector(17,19);p.GetFlyingOffset=function()return Vector(23,29)end
    local world;Isaac.WorldToScreen=function(v)world=v;return Vector(v.X+1000,v.Y+2000)end
    e.renderPlayer(p,Vector(31,37));local s=e.luaSprites[1]
    eq(world.X,100);eq(world.Y,76);eq(s.renderPosition.X,1100);eq(s.renderPosition.Y,2076)
    local renders=s.renderCount;Isaac.WorldToScreen=function()error('no camera')end
    e.renderPlayer(p,Vector.Zero);eq(s.renderCount,renders)
end)
check('optional input hooks preserve unfiltered binding and exact false return', function()
    local saved=InputHook;InputHook=nil;local e=cowards();local n=f.makeNpc();e.setNearby({n});e.update()
    eq(e.input(e.players[1],999,ButtonAction.ACTION_SHOOTLEFT),false)
    local count=0;for _,row in ipairs(e.callbacks)do if row.id==ModCallbacks.MC_INPUT_ACTION then count=count+1;eq(row.param,nil)end end
    eq(count,1);InputHook=saved
end)

f=dofile('tests/support/kamikaze_squad_fixture.lua');eq=f.assertEquals
local function squad(options)
    local e=f.makeEnvironment(options);e.players[2].collectibles[9054]=0
    local enemy=f.addEnemy(e,901,Vector(500,100));return e,enemy
end
check('synchronous remove callback cannot double-dispatch explosion or retain owned reference', function()
    local e=squad();e.update(90);local unit=e.spawned[1]
    unit.Remove=function(self)self.removed=true;e.invoke(ModCallbacks.MC_POST_ENTITY_REMOVE,self);eq(e.api.Detonate(self),false)end
    eq(e.api.Detonate(unit),true);eq(#e.explosions,1);eq(e.api.GetLiveCount(e.players[1]),0)
    eq(e.api.Detonate(unit),false);eq(#e.explosions,1)
end)
check('spawn failure consumes interval and waits a full new interval', function()
    local e=squad();local spawn=e.context.SpawnMulliboom;local calls=0
    e.context.SpawnMulliboom=function(...)calls=calls+1;if calls==1 then return nil end;return spawn(...)end
    e.update(90);eq(#e.spawned,0);eq(e.api.GetState(e.players[1]).timer,0)
    e.update(89);eq(calls,1);e.update();eq(calls,2);eq(#e.spawned,1)
end)
check('failed explosion preflight retains unit with no retry; room boundary still removes silently', function()
    local e=squad({useNativeExplosion=true});e.update(90);local unit=e.spawned[1]
    e.players[1].ToPlayer=function()return nil end
    eq(e.api.Detonate(unit),false);eq(unit.removed,false);eq(unit.data.NeverbirthKamikazeSquadExplosionFailed,true)
    e.players[1].ToPlayer=function(self)return self end;eq(e.api.Detonate(unit),false);eq(#e.nativeExplosions,0)
    e.newRoom();eq(unit.removed,true);eq(#e.nativeExplosions,0)
end)
check('failed explosion after removal is never retried', function()
    local e=squad({useNativeExplosion=true,throwExplosion=true});e.update(90);local unit=e.spawned[1]
    eq(e.api.Detonate(unit),false);eq(unit.removed,true);eq(e.getExplosionAttempts(),1)
    e.cleanAward();e.npcUpdate(unit);eq(e.getExplosionAttempts(),1);eq(e.api.GetLiveCount(e.players[1]),0)
end)
check('hostile conversion invalidates cached target and late spawn is found', function()
    local e,enemy=squad();e.update(90);local unit=e.spawned[1]
    eq(unit.Target,enemy);enemy.flags=EntityFlag.FLAG_CHARM
    local other=f.addEnemy(e,902,Vector(400,100));e.npcUpdate(unit);eq(unit.Target,other)
    other.removed=true;e.update();eq(unit.removed,true);eq(#e.explosions,1)
end)
check('fresh native wrappers and player reordering preserve timer and rebind owner', function()
    local e=squad();e.update(45);local original=e.players[1];local state=e.api.GetState(original)
    local wrapper=f.fresh(original);e.players[1],e.players[2]=e.players[2],wrapper
    e.update(45);eq(e.api.GetState(wrapper),state);eq(state.player,wrapper);eq(#e.spawned,1)
    eq(e.spawned[1].data.NeverbirthKamikazeSquadOwner,wrapper)
end)
check('same InitSeed does not merge distinct player handles', function()
    local e=f.makeEnvironment();e.players[2].InitSeed=e.players[1].InitSeed;f.addEnemy(e,903,Vector(500,100))
    e.update(90);eq(#e.spawned,2)
    assert(e.api.GetState(e.players[1])~=e.api.GetState(e.players[2]));eq(e.api.GetLiveCount(e.players[1]),1);eq(e.api.GetLiveCount(e.players[2]),1)
end)
check('missing pointer identity cannot create an owner or accidentally spawn', function()
    local e=squad();local get=GetPtrHash;GetPtrHash=nil;e.update(180)
    eq(e.api.GetState(e.players[1]),nil);eq(#e.spawned,0);GetPtrHash=get
end)
check('GetLiveCount preserves pruning effect and missing owner returns zero without allocation', function()
    local e=squad();eq(e.api.GetLiveCount(e.players[1]),0);eq(e.api.GetState(e.players[1]),nil)
    e.update(90);e.spawned[1].dead=true;eq(e.api.GetLiveCount(e.players[1]),0);eq(#e.api.GetState(e.players[1]).units,0)
end)
print('batch18 boundaries: '..cases..' passed')
