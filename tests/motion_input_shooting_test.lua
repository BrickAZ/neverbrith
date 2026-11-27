include=function(name)return dofile(name..'.lua')end
local S=include('motion_input_shooting')
local n=0;local function ok(v,m) assert(v,m);n=n+1 end
local function entity(kind,owner)
    local e={Type=kind,SpawnerEntity=owner,data={}}
    function e:GetData()return self.data end
    function e:ToPlayer()return self.Type==1 and self or nil end
    function e:ToFamiliar()return self.Type==3 and self or nil end
    function e:Exists()return not self.removed end
    function e:Remove()self.removed=true end
    return e
end
local p,q=entity(1),entity(1);p.InitSeed=1;q.InitSeed=2
local gate=S.New({Key=function(e)return tostring(e.InitSeed)end})
gate:Update(p,{});gate:Update(q,{})
ok(not gate:IsRestricted(p),'no owner has no restriction')
gate:Update(p,{a=true,b=true});ok(gate:IsRestricted(p),'multiple owners')
gate:Update(p,{b=true});ok(gate:IsRestricted(p),'dropping one keeps restriction')
ok(not gate:IsRestricted(q),'coop isolated')
for _,kind in ipairs({2,4,7,8,9})do
    local shot=entity(kind,p);ok(gate:ObserveEntity(shot),'native entity blocked type '..kind);ok(shot.removed,'native output removed')
    local other=entity(kind,q);ok(not gate:ObserveEntity(other) and not other.removed,'other player output kept')
end
local npc=entity(10);local ref={Entity=p}
ok(gate:ShouldBlockDamage(npc,ref),'direct native bone/contact damage blocked')
ok(not gate:ShouldBlockDamage(p,ref),'health costs are not attack cancellation')
ok(not gate:ShouldBlockDamage(npc,{Entity=nil}),'environment is not guessed')
local nativeEffect=entity(1000,p);gate:ObserveEntity(nativeEffect)
ok(not nativeEffect.removed and gate:ShouldBlockDamage(npc,{Entity=nativeEffect}),'effect visuals kept but owned damage blocked')
local familiar=entity(3);familiar.Player=p
local tear=entity(2,familiar);gate:ObserveEntity(tear);ok(tear.removed,'non-command familiar output blocked')
local commandEntities={}
gate:WithCommand(p,{serial=1},function()
    ok(not gate:ShouldBlockDamage(npc,ref),'direct skill damage allowed in scope')
    for _,kind in ipairs({2,4,7,8,9,1000})do
        local shot=entity(kind,p);gate:ObserveEntity(shot);commandEntities[#commandEntities+1]=shot
        ok(not shot.removed,'same entity class skill kept '..kind)
    end
end)
for _,shot in ipairs(commandEntities)do ok(not gate:ShouldBlockDamage(npc,{Entity=shot}),'command token survives callback')end
ok(gate:ShouldBlockDamage(npc,ref),'command scope does not tag the player forever')
local child=entity(2,commandEntities[1]);gate:ObserveEntity(child)
ok(not child.removed and not gate:ShouldBlockDamage(npc,{Entity=child}),'derived attack inherits command')
local mixed=entity(7,p);mixed.Parent=commandEntities[1];gate:ObserveEntity(mixed)
ok(not mixed.removed,'marked parent wins over direct player spawner')
child.SpawnerEntity=nil;ok(not gate:ShouldBlockDamage(npc,{Entity=child}),'parent disappearance preserves provenance')
local success=pcall(function()gate:WithCommand(p,{serial=2},function()error('expected executor failure')end)end)
ok(not success and gate:ShouldBlockDamage(npc,ref),'scope restored after error')
local later=entity(7,p);ok(gate:MarkAttack(p,later,1),'issued command can mark async result')
ok(not gate:ObserveEntity(later),'explicit async command allowed')
ok(not gate:MarkAttack(p,entity(2,p),999),'unknown serial rejected')
ok(not gate:MarkAttack(q,entity(2,p),1),'wrong player serial rejected')
-- Pointer/entity ref cycles terminate without attributing them to a random player.
local a,b=entity(1000),entity(1000);a.Parent=b;b.Parent=a
ok(not gate:ShouldBlockDamage(npc,{Entity=a}),'cyclic unknown chain does not hang')
gate:StatusApplied(npc,{Entity=p},1)
ok(gate:ShouldBlockDamage(npc,{Entity=nil},1),'native unmarked poison blocked with exact status source')
gate:StatusApplied(npc,{Entity=child},1)
ok(not gate:ShouldBlockDamage(npc,{Entity=nil},1),'skill poison retained')
gate:StatusApplied(npc,{Entity=q},2)
ok(not gate:ShouldBlockDamage(npc,{Entity=nil},2),'coop burn retained')
gate:StatusApplied(npc,{Entity=nil},1)
ok(not gate:ShouldBlockDamage(npc,{Entity=nil},1),'environment overwrite clears previous status source')
local copy=entity(10);gate:StatusApplied(npc,{Entity=p},3);gate:CopyStatus(npc,copy,true)
ok(gate:ShouldBlockDamage(copy,{Entity=nil},3),'native status copy preserves source')
gate:ReleasePlayer(p)
ok(not gate:IsRestricted(p),'last owner released')
local shot=entity(2,p);ok(not gate:ObserveEntity(shot),'normal output resumes')
local live=true;local dynamic=S.New({Key=function(e)return tostring(e.InitSeed)end,IsOwned=function(who)return who==p and live end})
dynamic:Update(p,{x=true});live=false
ok(not dynamic:IsRestricted(p),'inventory rechecked at actual hit')
print('motion_input_shooting: '..n..' assertions passed')
