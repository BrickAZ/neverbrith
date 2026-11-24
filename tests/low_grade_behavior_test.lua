local function eq(a,b,m) assert(a==b,(m or "assertion")..": expected "..tostring(b)..", got "..tostring(a)) end
local function near(a,b,m) assert(math.abs(a-b)<0.00001,m or "numeric assertion") end
local loader=loadfile("low_grade.lua")
assert(loader,"Low Grade runtime module must exist before the approved behavior can be delivered")
ModCallbacks={MC_POST_GAME_STARTED=1,MC_POST_NEW_LEVEL=2,MC_PRE_SPAWN_CLEAN_AWARD=3,
 MC_POST_ENTITY_TAKE_DMG=1006,MC_EVALUATE_CACHE=5,MC_PRE_PICKUP_COLLISION=6,
 MC_POST_PICKUP_INIT=7,MC_POST_PICKUP_UPDATE=8,MC_POST_PLAYER_UPDATE=9,
 MC_POST_TRIGGER_TRINKET_ADDED=1096,MC_POST_TRIGGER_TRINKET_REMOVED=1097,MC_POST_PICKUP_COLLISION=1239,MC_PRE_GAME_EXIT=10}
CallbackPriority={LATE=1000}
EntityType={ENTITY_PLAYER=1,ENTITY_PICKUP=5,ENTITY_SLOT=6}
PickupVariant={PICKUP_TRINKET=350}
TrinketType={TRINKET_GOLDEN_FLAG=32768}
RoomType={ROOM_BOSS=5,ROOM_SACRIFICE=13}
CacheFlag={CACHE_DAMAGE=1,CACHE_FIREDELAY=2,CACHE_RANGE=4}
DamageFlag={DAMAGE_FAKE=1<<21,DAMAGE_NO_PENALTIES=1<<28,DAMAGE_IV_BAG=1<<18,
 DAMAGE_DEVIL=1<<10,DAMAGE_CURSED_DOOR=1<<16,DAMAGE_CHEST=1<<20,DAMAGE_SPIKES=1<<7}
Vector=function(x,y) return {X=x,Y=y} end
local ID=201
local function setup(saved)
 local e={floor="f1",room="r1",frame=1,root=saved or {},players={},entities={},spawns={},logs={},participants={}}
 local room={GetType=function() return e.roomType or 1 end,FindFreePickupSpawnPosition=function(_,p)
  assert(p and p.X and p.Y,"native spawn position must be a Vector");return p
 end}
 local level={GetCurrentRoomDesc=function() return {ListIndex=e.roomListIndex or 10} end,
  GetLastBossRoomListIndex=function() return e.lastBossListIndex or 10 end}
 Game=function() return {GetRoom=function() return room end,GetLevel=function() return level end,
  GetFrameCount=function() return e.frame end} end
 Isaac={GetRoomEntities=function() return e.entities end,Spawn=function(_,variant,subtype,pos,vel,spawner)
  local p={Type=5,Variant=variant,SubType=subtype,Position=pos,SpawnerEntity=spawner,token="spawn"..(#e.spawns+1)}
  function p:ToPickup() return self end; function p:GetData() self.data=self.data or {};return self.data end
  e.spawns[#e.spawns+1]=p; e.entities[#e.entities+1]=p;return p
 end}
 local mod={callbacks={}}
 function mod:AddCallback(id,fn,param) self.callbacks[id]=self.callbacks[id] or {}; table.insert(self.callbacks[id],{fn=fn,param=param}) end
 function mod:AddPriorityCallback(id,priority,fn,param) self:AddCallback(id,fn,param) end
 function e.fire(id,...)
  for _,cb in ipairs(mod.callbacks[id] or {}) do cb.fn(mod,...) end
 end
 function e.player(key)
  local p={key=key,InitSeed=100+#e.players,Type=1,Position=Vector(100,100),held={},smelt={},Damage=3.5,MaxFireDelay=5,TearRange=260,MoveSpeed=1,multiplier=nil}
  function p:ToPlayer() return self end
  function p:GetTrinket(slot) return self.held[slot+1] or 0 end
  function p:GetSmeltedTrinkets() return self.smelt end
  function p:GetTrinketMultiplier(id)
   if self.multiplier then return self.multiplier end
   local n=0;for _,raw in ipairs(self.held) do if raw%32768==id then n=n+(raw>=32768 and 2 or 1) end end
   local s=self.smelt[id] or {};return n+(s.trinketAmount or 0)+2*(s.goldenTrinketAmount or 0)
  end
  function p:TryRemoveTrinket(raw)
   for i,v in ipairs(self.held) do if v==raw then table.remove(self.held,i);e.fire(1097,self,raw);return true end end
   return false
  end
  function p:TryRemoveSmeltedTrinket(raw)
   local s=self.smelt[raw%32768];if not s then return end
   local field=raw>=32768 and "goldenTrinketAmount" or "trinketAmount"
   if (s[field] or 0)>0 then s[field]=s[field]-1;e.fire(1097,self,raw) end
  end
  function p:AddCacheFlags(flags) self.cacheFlags=flags end
  function p:EvaluateItems() self.refreshes=(self.refreshes or 0)+1 end
  e.players[#e.players+1]=p;return p
 end
 local state={PlayerKey=function(p) return p.key end,FloorKey=function() return e.floor end,
  RoomKey=function() return e.room end,PickupToken=function(p) return p.token end,
  RegisterParticipant=function(name,capture,restore) e.participants[name]={capture=capture,restore=restore} end}
 e.api=loader()(mod,{TrinketId=ID,State=state,GetSaveRoot=function() return e.root end,
 GetCurrentRunSeed=function() return "run1" end,GetPlayers=function() return e.players end,
 Save=function() e.saves=(e.saves or 0)+1 end,DebugLog=function(s) e.logs[#e.logs+1]=s end})
 e.mod=mod
 function e.start(cont) e.fire(1,cont or false) end
 function e.hit(p,flags) e.fire(1006,p,1,flags or 0,{Type=2,Variant=0},0) end
 function e.level(n) e.floor="f"..n;e.room="r"..n;e.entities={};e.fire(2) end
 function e.boss()
  e.roomType=5
  e.fire(3,{RandomInt=function()return 0 end},Vector(200,200))
  e.roomType=1
 end
 function e.update(p) e.frame=e.frame+1;e.fire(9,p);for _,pick in ipairs(e.entities) do e.fire(8,pick) end end
 function e.pickup(token,raw,pos)
  local p={Type=5,Variant=350,SubType=raw or ID,token=token,Position=pos or Vector(100,100)}
  function p:ToPickup() return self end;function p:GetData() self.data=self.data or {};return self.data end
  e.entities[#e.entities+1]=p;e.fire(7,p);return p
 end
 function e.take(p,pick)
  e.fire(6,pick,p,false);p.held[#p.held+1]=pick.SubType;e.fire(1096,p,pick.SubType,true)
  e.fire(1239,pick,p,false)
  for i,v in ipairs(e.entities) do if v==pick then table.remove(e.entities,i);break end end
  e.update(p)
 end
 return e
end

do
 local e=setup();local p=e.player("p");e.start();e.take(p,e.pickup("destroyed"))
 for i=1,4 do e.hit(p) end
 p:TryRemoveTrinket(ID);e.update(p) -- direct destruction, with no ground entity
 e.take(p,e.pickup("new-real-copy"));e.hit(p)
 eq(p:GetTrinket(0),ID,"fresh physical copy cannot inherit destroyed copy's last hit")
 eq(e.api.GetDurability("new-real-copy"),4,"fresh physical copy starts with five hits")
 eq(e.api.GetDurability("destroyed"),nil,"unspawned removed physical record terminates")
end
do
 local e=setup();local p=e.player("p");e.start()
 e.take(p,e.pickup("range"))
 eq(p.cacheFlags,CacheFlag.CACHE_RANGE,"native trinket pickup must explicitly refresh its range")
 local refreshes=p.refreshes
 e.update(p)
 eq(p.refreshes,refreshes,"steady ownership does not force repeated range evaluation")
 p:TryRemoveTrinket(ID);e.update(p)
 eq(p.refreshes,refreshes+1,"native trinket drop refreshes range once")
end
do
 local e=setup();local p=e.player("p");e.start()
 local pick=e.pickup("wrapped")
 e.fire(6,pick,p,false);p.held={ID};e.fire(1096,p,ID,true)
 e.fire(1239,setmetatable({}, {__index=pick}),p,false);e.update(p)
 eq(e.api.GetDurability("wrapped"),5,"different Lua wrappers identify the same native pickup")
end
do
 local e=setup();local p=e.player("p");e.start()
 local pick=e.pickup("queued-trinket")
 e.fire(6,pick,p,false);p.QueuedItem={Item={ID=ID}}
 e.fire(1239,pick,p,false);e.update(p)
 eq(e.api.GetDurability("queued-trinket"),nil,"pickup animation does not grant durability early")
 p.QueuedItem.Item=nil;p.held={ID};e.fire(1096,p,ID,true);e.update(p)
 eq(e.api.GetDurability("queued-trinket"),5,"native delayed trinket addition keeps the physical token")
end
do
 local e=setup();local p=e.player("p");e.start();e.hit(p);e.take(p,e.pickup("after-cold-save"))
 p.held={} -- native Hourglass restores the first room before any acquisition
 e.participants.lowGrade.restore(nil)
 eq(e.api.GetDurability("after-cold-save"),nil,"empty early snapshot clears later acquisitions")
 e.level(2);e.hit(p);e.level(3);e.hit(p);e.boss()
 eq(#e.spawns,0,"empty early snapshot clears later floor-one damage")
end
do
 local e=setup();local p=e.player("p");e.start();e.take(p,e.pickup("swap-old"));for i=1,3 do e.hit(p) end
 p.held={};e.fire(1097,p,ID);local pick=e.pickup("swap-ground");e.update(p)
 e.fire(6,pick,p,false);p.held={ID};e.fire(1096,p,ID,true);pick.SubType=999
 e.fire(1239,pick,p,false);e.update(p);e.hit(p);e.hit(p)
 eq(p:GetTrinket(0),0,"trinket swap mutating pickup subtype preserves picked copy's durability")
end
do
 local e=setup();local p=e.player("p");e.start();e.take(p,e.pickup("smelt-order"));e.hit(p);e.hit(p)
 p.held={};e.fire(1097,p,ID) -- native removal may precede the swallowed amount becoming visible
 p.smelt[ID]={trinketAmount=1,goldenTrinketAmount=0};e.fire(1096,p,ID,false);e.update(p)
 for i=1,3 do e.hit(p) end
 eq(p.smelt[ID].trinketAmount,0,"smelt callback order cannot create a new five-hit copy")
end
do
 local e=setup();local p=e.player("lazarus");local q=e.player("lazarus");e.start()
 e.take(p,e.pickup("alive"));e.take(q,e.pickup("dead"))
 for i=1,4 do e.hit(p) end
 eq(e.api.GetDurability("alive"),1,"same player alive form retains its topology")
 eq(e.api.GetDurability("dead"),5,"inactive form's different copy is not damaged")
 e.level(2);e.hit(q);e.level(3);e.hit(p);e.boss()
 eq(#e.spawns,1,"forms share progress without receiving two rewards")
end
do
 local e=setup();local p=e.player("p");e.start();e.hit(p);e.level(2);e.hit(p);e.level(3)
 e.roomListIndex=9;e.boss();eq(#e.spawns,0,"XL first boss is not the floor settlement")
 e.hit(p);e.roomListIndex=10;e.boss();eq(#e.spawns,1,"final floor boss owns the settlement")
end
do
 local e=setup();local p=e.player("p1");local q=e.player("p2");e.start()
 e.hit(p);e.hit(p);e.hit(p);e.level(2);e.hit(p);e.level(3);e.hit(p);e.boss()
 eq(#e.spawns,1,"three separately damaged floors produce one reward")
 e.boss();eq(#e.spawns,1,"same floor only settles once")
 e.level(4);e.hit(p);e.boss();eq(#e.spawns,2,"rolling windows overlap while an older copy exists")
 eq(q:GetTrinketMultiplier(ID),0,"co-op player receives no shared progress")
end
do
 local e=setup();local p=e.player("p");e.start();e.hit(p);e.level(2);e.hit(p);e.level(3)
 e.boss();e.hit(p);e.boss();eq(#e.spawns,0,"damage after third boss cannot retroactively grant")
 e.level(4);e.hit(p);e.boss();eq(#e.spawns,1,"late damage still counts as a previous floor")
end
do
 local e=setup();local p=e.player("p");e.start();e.hit(p);e.hit(p);e.hit(p);e.level(2);e.level(3);e.hit(p);e.boss()
 eq(#e.spawns,0,"three hits on one floor cannot fill other floors")
end
do
 local e=setup();local p=e.player("p");e.start();local pick=e.pickup("copy");e.take(p,pick)
 for _,flag in ipairs({DamageFlag.DAMAGE_FAKE,DamageFlag.DAMAGE_NO_PENALTIES,DamageFlag.DAMAGE_IV_BAG,
  DamageFlag.DAMAGE_DEVIL,DamageFlag.DAMAGE_CURSED_DOOR,DamageFlag.DAMAGE_CHEST}) do e.hit(p,flag) end
 e.roomType=13;e.hit(p,DamageFlag.DAMAGE_SPIKES);e.roomType=1
 for i=1,4 do e.hit(p);eq(p:GetTrinket(0),ID,"excluded events do not exhaust durability") end
 e.hit(p);eq(p:GetTrinket(0),0,"fifth real eligible hit removes held copy")
end
do
 local e=setup();local p=e.player("p");local q=e.player("q");e.start();e.take(p,e.pickup("first"))
 for i=1,3 do e.hit(p) end
 p.held={};e.fire(1097,p,ID);local dropped=e.pickup("dropped");e.update(p)
 e.take(q,dropped);e.hit(q);eq(q:GetTrinket(0),ID,"transfer keeps last two hits")
 e.hit(q);eq(q:GetTrinket(0),0,"transfer does not reset the same physical copy")
end
do
 local e=setup();local p=e.player("p");e.start();e.take(p,e.pickup("normal"));e.hit(p);e.hit(p)
 p.held={};p.smelt[ID]={trinketAmount=1,goldenTrinketAmount=0};e.fire(1097,p,ID);e.update(p)
 e.take(p,e.pickup("golden",ID+32768));p.smelt[999]={trinketAmount=2,goldenTrinketAmount=1}
 for i=1,3 do e.hit(p) end
 eq(p.smelt[ID].trinketAmount,0,"only expiring swallowed copy removed")
 eq(p:GetTrinket(0),ID+32768,"new golden copy has its own durability")
 eq(p.smelt[999].trinketAmount,2,"other swallowed trinkets stay intact")
 e.hit(p);e.hit(p);eq(p:GetTrinket(0),0,"golden copy still expires after five hits")
end
do
 local e=setup();local p=e.player("p");e.start();e.take(p,e.pickup("copy"));p.multiplier=3
 e.fire(5,p,1);near(p.Damage,18.5,"native trinket multiplier scales damage")
 e.fire(5,p,2);near(30/(p.MaxFireDelay+1),20,"+15 tears exceeds the usual cap")
 e.fire(5,p,4);near(p.TearRange,860,"+15 panel range is +600 engine units")
 near(p.MoveSpeed,1,"no speed bonus")
 for i=1,5 do e.hit(p) end;eq(p:GetTrinket(0),0,"Mom Box multiplier does not multiply durability")
end
do
 local e=setup();local p=e.player("p");e.start();local blocked=e.pickup("blocked")
 e.fire(6,blocked,p,false) -- another mod rejects collection, so no native add follows
 p.held={ID};e.fire(1096,p,ID,true);e.update(p)
 eq(e.api.GetDurability("blocked"),nil,"canceled collision cannot identify a later scripted addition")
end
do
 local e=setup();local p=e.player("p");e.start();e.take(p,e.pickup("copy"));e.hit(p)
 local participant=assert(e.participants.lowGrade,"Low Grade participates in shared Hourglass snapshots")
 local snap=participant.capture();e.hit(p);e.hit(p);participant.restore(snap)
 local saved=e.root;local c=setup(saved);local q=c.player("p");q.held={ID};c.start(true)
 for i=1,3 do c.hit(q);eq(q:GetTrinket(0),ID,"continue preserves restored one-hit durability") end
 c.hit(q);eq(q:GetTrinket(0),0,"continue removes on restored fifth hit")
end
do
 local e=setup();local p=e.player("p");e.start();local before=e.saves
 e.fire(10,false);eq(e.saves,before,"unsaved exit cannot save continuation state")
 e.start(true);before=e.saves;e.fire(10,true);eq(e.saves,before+1,"saved exit persists current durability")
end
print("low_grade_behavior_test: all approved lifecycle and stat cases passed")
