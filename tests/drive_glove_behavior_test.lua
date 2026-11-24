-- Callback adapter tests with native ordering: early guard, shields, late
-- in-place damage override, then health receipt. Visuals are checked separately.
local count=0
local function ok(value,label) assert(value,label); count=count+1 end
local function near(a,b,label) ok(math.abs(a-b)<1e-6,label..': '..tostring(a)) end
ModCallbacks={}
for i,name in ipairs({'MC_PRE_PLAYER_UPDATE','MC_POST_PLAYER_UPDATE','MC_PRE_PLAYER_TAKE_DMG','MC_ENTITY_TAKE_DMG',
 'MC_POST_ENTITY_TAKE_DMG','MC_POST_NPC_DEATH','MC_INPUT_ACTION','MC_PRE_USE_ITEM','MC_USE_ITEM','MC_PRE_USE_CARD',
 'MC_PRE_USE_PILL','MC_PRE_PICKUP_COLLISION','MC_POST_TRIGGER_WEAPON_FIRED','MC_EVALUATE_CACHE','MC_POST_UPDATE',
 'MC_POST_GAME_STARTED','MC_PRE_GAME_EXIT','MC_POST_NEW_ROOM','MC_POST_GLOWING_HOURGLASS_LOAD','MC_POST_ADD_COLLECTIBLE',
 'MC_PRE_TEAR_UPDATE','MC_PRE_FAMILIAR_UPDATE','MC_PRE_BOMB_UPDATE','MC_PRE_PICKUP_UPDATE','MC_PRE_KNIFE_UPDATE',
 'MC_PRE_PROJECTILE_UPDATE','MC_PRE_LASER_UPDATE','MC_PRE_EFFECT_UPDATE','MC_PRE_NPC_UPDATE','MC_PRE_SLOT_UPDATE',
 'MC_PRE_MOD_UNLOAD','MC_EXECUTE_CMD','MC_POST_WEAPON_FIRE'}) do ModCallbacks[name]=i end
EntityType={ENTITY_PLAYER=1,ENTITY_TEAR=2,ENTITY_BOMBDROP=4,ENTITY_PICKUP=5,ENTITY_SLOT=6,ENTITY_LASER=7,ENTITY_PROJECTILE=9,ENTITY_EFFECT=1000}
EntityFlag={FLAG_NO_SPRITE_UPDATE=1<<32,FLAG_FRIENDLY=1<<29,FLAG_POISON=1<<6,FLAG_BURN=1<<27,FLAG_BLEED_OUT=1<<34}
TearFlags={TEAR_POISON=1<<4,TEAR_BURN=1<<22}
WeaponType={WEAPON_TEARS=1,WEAPON_BRIMSTONE=2,WEAPON_LASER=3,WEAPON_KNIFE=4,WEAPON_BOMBS=5,WEAPON_ROCKETS=6,
 WEAPON_MONSTROS_LUNGS=7,WEAPON_LUDOVICO_TECHNIQUE=8,WEAPON_TECH_X=9,WEAPON_BONE=10,WEAPON_SPIRIT_SWORD=11,WEAPON_FETUS=12}
WeaponModifier={CHOCOLATE_MILK=1,CURSED_EYE=2,BRIMSTONE=4,MONSTROS_LUNG=8,NEPTUNUS=256}
CacheFlag={CACHE_DAMAGE=1,CACHE_FIREDELAY=2}
ButtonAction={ACTION_LEFT=0,ACTION_RIGHT=1,ACTION_UP=2,ACTION_DOWN=3,ACTION_SHOOTLEFT=4,ACTION_SHOOTRIGHT=5,
 ACTION_SHOOTUP=6,ACTION_SHOOTDOWN=7,ACTION_BOMB=8,ACTION_ITEM=9,ACTION_PILLCARD=10,ACTION_DROP=11,ACTION_PAUSE=12}
InputHook={IS_ACTION_PRESSED=0,IS_ACTION_TRIGGERED=1,GET_ACTION_VALUE=2}
PocketItemType={PILL=0,CARD=1,ACTIVE_ITEM=2};PillCardSlot={PRIMARY=0}
CollectibleType={COLLECTIBLE_WAFER=108,COLLECTIBLE_GLASS_CANNON=352,COLLECTIBLE_IV_BAG=135,COLLECTIBLE_RAZOR_BLADE=126}
DamageFlag={DAMAGE_EXPLOSION=1<<2,DAMAGE_LASER=1<<3,DAMAGE_ACID=1<<4,DAMAGE_RED_HEARTS=1<<5,DAMAGE_COUNTDOWN=1<<6,
 DAMAGE_SPIKES=1<<7,DAMAGE_POOP=1<<9,DAMAGE_DEVIL=1<<10,DAMAGE_INVINCIBLE=1<<13,DAMAGE_POISON_BURN=1<<15,
 DAMAGE_CURSED_DOOR=1<<16,DAMAGE_IV_BAG=1<<18,DAMAGE_PITFALL=1<<19,DAMAGE_CHEST=1<<20,DAMAGE_FAKE=1<<21,
 DAMAGE_NO_MODIFIERS=1<<25,DAMAGE_NO_PENALTIES=1<<28,DAMAGE_FIRE=2,DAMAGE_CRUSH=1<<24}
SlotVariant={BLOOD_DONATION_MACHINE=2,DEVIL_BEGGAR=5}; RoomType={ROOM_DEFAULT=1,ROOM_SACRIFICE=13}
LevelStage={STAGE4_1=7};PlayerType={PLAYER_THELOST=10,PLAYER_THELOST_B=31};TrinketType={TRINKET_BLIND_RAGE=82}
UseFlag={USE_CARBATTERY=1<<5};PickupVariant={PICKUP_COLLECTIBLE=100};ItemType={ITEM_ACTIVE=3}
EntityGridCollisionClass={GRIDCOLL_NONE=0,GRIDCOLL_WALLS=3,GRIDCOLL_GROUND=5,GRIDCOLL_NOPITS=6}
GridCollisionClass={COLLISION_NONE=0,COLLISION_PIT=1,COLLISION_OBJECT=2,COLLISION_SOLID=3,COLLISION_WALL=4,COLLISION_WALL_EXCEPT_PLAYER=5}
local vec={}; vec.__index=vec
local function V(x,y) return setmetatable({X=x,Y=y},vec) end
function vec.__add(a,b)return V(a.X+b.X,a.Y+b.Y)end
function vec.__sub(a,b)return V(a.X-b.X,a.Y-b.Y)end
function vec.__mul(a,b)return V(a.X*b,a.Y*b)end
function vec:LengthSquared()return self.X^2+self.Y^2 end
function vec:Length()return math.sqrt(self:LengthSquared())end
function vec:Dot(b)return self.X*b.X+self.Y*b.Y end
function vec:GetAngleDegrees()return math.deg(math.atan(self.Y,self.X))end
Vector=setmetatable({FromAngle=function(a)return V(math.cos(math.rad(a)),math.sin(math.rad(a)))end},{__call=function(_,x,y)return V(x,y)end})
local callbacks,frame,root,people,entities={},0,{}, {},{}
local room={blocked=false,type=1}
function room:GetType()return self.type end
function room:SetPauseTimer(n)self.pause=n end
function room:IsPositionInRoom(p)return p.X>=0 and p.X<=1000 and p.Y>=0 and p.Y<=800 end
function room:GetGridCollisionAtPos()return self.collision or (self.blocked and 3 or 0) end
local game={};function game:GetFrameCount()return frame end;function game:IsPaused()return false end
function game:GetRoom()return room end;function game:GetLevel()return {GetStage=function()return 1 end}end
Game=function()return game end
local function dispatch(name,filter,...)
    local result
    for _,c in ipairs(callbacks[ModCallbacks[name] or name] or {}) do
        if not c.filter or c.filter==filter then
            local v=c.fn(nil,...)
            if v~=nil then result=v; if type(v)~='table' then return v end end
        end
    end
    return result
end
local mod={PendingContentState={InventoryPlayerKey=function(p)return tostring(p.InitSeed)end}}
function mod:AddPriorityCallback(id,priority,fn,filter)
    assert(id,'callback must exist');callbacks[id]=callbacks[id] or {}
    table.insert(callbacks[id],{priority=priority,fn=fn,filter=filter})
    table.sort(callbacks[id],function(a,b)return a.priority<b.priority end)
end
function mod:AddCallback(id,fn,filter)self:AddPriorityCallback(id,0,fn,filter)end
local entitySeed=100
local function entity(type,position,velocity)
 entitySeed=entitySeed+1
 local e={Type=type,InitSeed=entitySeed,Position=position or V(100,100),Velocity=velocity or V(0,0),data={},flags=0}
 function e:Exists()return not self.removed end;function e:ToPlayer()return self.Type==1 and self or nil end
 function e:ToNPC()return self.Type==10 and self or nil end;function e:ToFamiliar()return self.familiar end
 function e:ToTear()return self.Type==2 and self or nil end;function e:ToLaser()return self.Type==7 and self or nil end
 function e:ToKnife()return nil end;function e:ToBomb()return self.Type==4 and self or nil end
 function e:GetData()return self.data end;function e:HasEntityFlags(f)return self.flags&f~=0 end
 function e:AddEntityFlags(f)self.flags=self.flags|f end;function e:ClearEntityFlags(f)self.flags=self.flags&(~f)end
 function e:IsEnemy()return self.Type==10 end
 return e
end
local function player()
 local p=entity(1);p.InitSeed=#people+1;p.ControllerIndex=#people;p.has=true;p.inputs={};p.active={[0]=900}
 p.hearts=12;p.soul=0;p.bone=0;p.cooldown=0;p.Damage=3.5;p.MaxFireDelay=10;p.MoveSpeed=1;p.Size=10;p.canShoot=true
 p.GridCollisionClass=5;p.ControlsEnabled=true;p.owns={}
 function p:HasCollectible(id)return id==900 and self.has or self.owns[id]==true end
 function p:GetActiveItem(slot)return self.has and (self.active[slot] or 0) or 0 end
 function p:GetPocketItem()return {GetType=function()return self.pocketType or 0 end,GetSlot=function()return self.pocketSlot or 0 end}end
 function p:GetPlayerType()return 0 end
 function p:IsDead()return false end;function p:IsCoopGhost()return false end;function p:AreControlsEnabled()return self.ControlsEnabled end
 function p:CanShoot()return self.canShoot end;function p:SetCanShoot(v)self.canShoot=v end
 function p:AddCacheFlags()end
 function p:EvaluateItems()
  self.Damage=3.5;self.MaxFireDelay=10
  dispatch('MC_EVALUATE_CACHE',nil,self,1);dispatch('MC_EVALUATE_CACHE',nil,self,2)
 end
 function p:GetHearts()return self.hearts end;function p:GetSoulHearts()return self.soul end;function p:GetBoneHearts()return self.bone end
 function p:GetDamageCooldown()return self.cooldown end;function p:SetMinDamageCooldown(v)self.cooldown=math.max(self.cooldown,v)end
 function p:GetDamageCountdown()return 0 end;function p:SetDamageCountdown()end
 function p:GetFireDamageCooldown()return 0 end;function p:SetFireDamageCooldown()end
 function p:GetKnockbackCountdown()return self.knockback or 0 end
 function p:GetTrinketMultiplier()return 0 end;function p:GetWeapon()return self.weapon end
 people[#people+1]=p;entities[#entities+1]=p;return p
end
Input={GetActionValue=function(action,controller)
 local p=people[controller+1];local v=dispatch('MC_INPUT_ACTION',nil,p,InputHook.GET_ACTION_VALUE,action)
 return v==nil and (p.inputs[action] or 0) or v
end}
GetPtrHash=function(e)return tostring(e)end
local soundCalls={}
local soundIds={['Drive Glove Guard']=1001,['Drive Glove Parry']=1002,['Drive Glove Perfect Parry']=1003,
 ['Drive Glove Blue Start']=1004,['Drive Glove Rush Start']=1005,
 ['Drive Glove Burnout Enter']=1006,['Drive Glove Burnout Exit']=1007}
SFXManager=function()return {Play=function(_,id,volume,delay,loop,pitch)
 soundCalls[#soundCalls+1]={id=id,volume=volume,delay=delay,loop=loop,pitch=pitch}
end}end
Isaac={GetRoomEntities=function()return entities end,GetItemConfig=function()return {GetCollectible=function(_,id)return {Type=id==7 and 3 or 1}end}end,
 ConsoleOutput=function()end,GetSoundIdByName=function(name)return soundIds[name]end,DebugString=function()end,
 GetStatusAttributionAPIVersion=function()return 1 end,GetCurrentDotDamageKind=function(_,ref)return ref.DotKind or 0 end}
include=function(path)
 if path=='drive_glove_visuals' then return function()return {Events=function()end,Update=function()end,ClearRoom=function()end}end end
 return dofile(path..'.lua')
end
local p=player();local q=player()
local api=dofile('drive_glove.lua')(mod,{ItemId=900,GetSaveRoot=function()return root end,GetCurrentRunSeed=function()return 22 end,
 GetPlayers=function()return people end,Save=function()end})
dispatch('MC_POST_GAME_STARTED',nil,false)
local function tick()
 frame=frame+1
 for _=1,2 do -- Native player updates twice per 30 Hz game frame.
 for _,who in ipairs(people) do
  local skip=dispatch('MC_PRE_PLAYER_UPDATE',nil,who)
  if not skip then
   who.Position=who.Position+V(Input.GetActionValue(1,who.ControllerIndex)-Input.GetActionValue(0,who.ControllerIndex),
      Input.GetActionValue(3,who.ControllerIndex)-Input.GetActionValue(2,who.ControllerIndex))*.5
   dispatch('MC_POST_PLAYER_UPDATE',nil,who)
  end
 end
 end
 dispatch('MC_POST_UPDATE',nil)
end
local function reset(who)
 local s,t=api.GetState(who);api.Core.End(t,'test');t.needsRelease=false;t.lastPressed=false;t.lastMoveDir=nil;t.lastTick=nil;t.pressedActions={}
 s.gauge=6;s.burnout=false;t.reward=nil;t.gift=nil;t.grantCharge=nil;t.cacheDirty=true
 who.inputs={};who.cooldown=0;who.hearts=12;who.mantle=nil;who.has=true;who:EvaluateItems()
 return s,t
end
local function damage(who,source,flags,amount)
 flags=flags or DamageFlag.DAMAGE_NO_MODIFIERS;amount=amount or 1
 local ref={Entity=source,Type=source and source.Type or 0}
 if dispatch('MC_PRE_PLAYER_TAKE_DMG',nil,who,amount,flags,ref,0)==false then return false end
 if who.cooldown>0 then return false end
 if who.mantle then who.mantle=nil;return false end
 local result=dispatch('MC_ENTITY_TAKE_DMG',1,who,amount,flags,ref,0)
 if result==false then return false end
 if type(result)=='table' then amount=result.Damage or amount end
 who.hearts=who.hearts-amount
 dispatch('MC_POST_ENTITY_TAKE_DMG',1,who,amount,flags,ref,0)
 return true
end
local bullet=entity(9,V(40,100),V(5,0))
do
 local s,t=reset(p);p.inputs[1]=1;p.mantle=true
 ok(not damage(p,bullet),'guard cancels');near(s.gauge,5,'guard cost');ok(p.hearts==12 and p.mantle,'guard precedes mantle')
 ok(p.cooldown==60,'native half-heart iframe');damage(p,bullet);near(s.gauge,5,'no repeated fees in iframe')
 p.cooldown=0;s.gauge=.5;damage(p,bullet);ok(s.burnout and s.gauge==0,'last hit overdraw')
 near(p.Damage,2.625,'burnout immediate damage');near(30/(p.MaxFireDelay+1),30/11*.75,'burnout immediate tears')
 p.cooldown=0;p.mantle=nil;damage(p,bullet);ok(p.hearts==11,'burnout guard fails')
 near(api.GetState(q).gauge,6,'independent player meter')
end
do
 local s,t=reset(p);p.inputs[9]=1;tick();ok(t.mode=='blue','held native active starts blue')
 ok(Input.GetActionValue(4,0)==0,'blue blocks firing input');ok(p:CanShoot(),'shoot permission restored after player update')
 damage(p,bullet);ok(t.reward and s.gauge==6,'perfect blue native dispatch')
 p.inputs[9]=0;tick();ok(t.mode=='idle','success early release has no recovery')
 reset(p);p.inputs[9]=1;tick();p.inputs[9]=0
 for _=1,6 do tick() end
 ok(t.mode=='recovery','whiff recovery');local position=p.Position;p.inputs[1]=1;tick();near((p.Position-position):Length(),0,'recovery immobile')
 ok(Input.GetActionValue(8,0)==0 and Input.GetActionValue(10,0)==0,'recovery bomb and card locked')
 p.cooldown=0;damage(p,bullet);ok(p.hearts==12 and t.mode=='recovery','recovery direction guard no cancel')
end
do
 local s,t=reset(p);api.Core.StartBlue(s,t,frame);p.inputs[9]=1
 local before=s.gauge;damage(p,p,DamageFlag.DAMAGE_IV_BAG|DamageFlag.DAMAGE_INVINCIBLE)
 ok(p.hearts==11 and not t.reward,'life payment not parried');near(s.gauge,before,'payment no meter benefit')
 local bomb=entity(4,V(40,100));p.cooldown=0;damage(p,bomb,DamageFlag.DAMAGE_EXPLOSION)
 ok(p.hearts==10,'bomb bypasses blue')
 reset(p);p.inputs[1]=1;damage(p,entity(10,V(50,100)));ok(p.hearts==11,'contact cannot normal guard')
 reset(p);p.inputs[1]=1;damage(p,entity(7),DamageFlag.DAMAGE_LASER);ok(p.hearts==11,'laser cannot normal guard')
 reset(p);p.inputs[1]=1;damage(p,nil);ok(p.hearts==11,'sourceless cannot normal guard')
 reset(p);p.inputs[9]=1;api.Core.StartBlue(s,t,frame);damage(p,nil);ok(p.hearts==12,'blue blocks sourceless')
end
do
 local s,t=reset(p);p.inputs[9]=1;tick();p.inputs[1]=1;tick()
 ok(t.mode=='startup' and room.pause==5,'single direction enters room freeze')
 local begin=p.Position
 for _=1,4 do tick() end
 near((p.Position-begin):Length(),0,'startup stops motion');ok(t.moveFrames==0,'startup excluded from movement clock')
 tick();near((p.Position-begin):Length(),260/18,'first rush frame exact speed')
 for _=1,3 do tick() end
 p.inputs[1]=0;p.inputs[0]=1;tick();ok(t.mode=='idle' and t.moveFrames==4,'reverse brakes after four moves')
 reset(p);api.Core.StartBlue(s,t,frame);api.Core.StartRush(s,t,frame,1,0)
 damage(p,bullet);ok(p.hearts==10 and t.mode=='idle','unblocked rush double damage and interrupt')
 reset(p);api.Core.StartBlue(s,t,frame);api.Core.StartRush(s,t,frame,1,0);p.mantle=true
 damage(p,bullet);ok(p.hearts==12 and t.mode=='startup','other shield continues rush')
end
do
 local s,t=reset(p);api.Core.SetGauge(s,t,0);p.has=false;local before=s.gauge;tick()
 near(s.gauge,before,'removed meter frozen');ok(s.burnout,'removed burnout retained')
 p.has=true;tick();ok(s.gauge<.1 and s.burnout,'reacquire no refill or cleanse')
 local enemy=entity(10);enemy.SpawnerEntity=nil
 local familiar=entity(3);familiar.familiar={Player=p}
 local tear=entity(2);tear.SpawnerEntity=familiar
 dispatch('MC_POST_ENTITY_TAKE_DMG',10,enemy,3,0,{Entity=tear},0)
 -- The native death callback can expose a fresh GetData table.
 function enemy:GetData()return {} end
 dispatch('MC_POST_NPC_DEATH',nil,enemy)
 near(s.gauge,1.01,'owned familiar kill restores one');dispatch('MC_POST_NPC_DEATH',nil,enemy);near(s.gauge,1.01,'death paid once')
 local otherEnemy=entity(10);dispatch('MC_POST_ENTITY_TAKE_DMG',10,otherEnemy,3,0,{Entity=tear},0)
 dispatch('MC_POST_ENTITY_TAKE_DMG',10,otherEnemy,3,0,{Entity=nil},0);dispatch('MC_POST_NPC_DEATH',nil,otherEnemy)
 near(s.gauge,1.01,'environment final hit clears stale owner')
end
do
 local s,t=reset(p);s.gauge=2;p.inputs[1]=1;tick();near(s.gauge,2.005,'walking once per logic frame with two player updates')
 p.knockback=5;tick();near(s.gauge,2.005+1/300,'knockback with held input only natural regen');p.knockback=0
end
do
 local function sweep(gridClass,collision)
  local s,t=reset(p);p.GridCollisionClass=gridClass;room.collision=collision
  api.Core.StartBlue(s,t,frame);api.Core.StartRush(s,t,frame,1,0)
  for _=1,6 do tick() end
  return t
 end
 ok(sweep(5,1).reason=='obstacle','ground rush stops at pit')
 ok(sweep(6,1).mode=='rush','native no-pits collision can cross pit')
 ok(sweep(6,3).reason=='obstacle','no-pits collision still stops at solid')
 room.collision=nil;p.GridCollisionClass=5
end
do
 local s,t=reset(p);p.active={[0]=0,[2]=900};p.pocketType=PocketItemType.CARD;p.pocketSlot=1
 p.inputs[10]=1;tick();ok(t.mode=='idle','selected card Q does not start stored glove');near(s.gauge,6,'selected card does not spend drive')
 s,t=reset(p);p.pocketType=PocketItemType.ACTIVE_ITEM;p.pocketSlot=3;p.inputs[10]=1;tick()
 ok(t.mode=='blue' and t.slot==2,'selected pocket active uses Q')
 s,t=reset(p);p.active[0]=900;p.inputs[10]=1;tick()
 ok(t.mode=='blue' and t.slot==2,'primary glove does not hide selected pocket glove Q')
 p.active={[0]=900};p.pocketType=nil;p.pocketSlot=nil
end
do
 local a=reset(p);local b=reset(q);a.gauge=2;b.gauge=2
 local e=entity(10);e.flags=EntityFlag.FLAG_POISON
 local poison=entity(2);poison.SpawnerEntity=p;poison.TearFlags=TearFlags.TEAR_POISON
 local plain=entity(2);plain.SpawnerEntity=q;plain.TearFlags=0
 dispatch('MC_POST_ENTITY_TAKE_DMG',10,e,1,0,{Entity=poison},0)
 dispatch('REPENTOGON_POST_DOT_APPLIED',nil,e,{Entity=poison},1)
 dispatch('MC_POST_ENTITY_TAKE_DMG',10,e,1,0,{Entity=plain},0)
 dispatch('MC_POST_ENTITY_TAKE_DMG',10,e,1,DamageFlag.DAMAGE_POISON_BURN,{DotKind=1},0)
 dispatch('MC_POST_NPC_DEATH',nil,e)
 near(a.gauge,3,'poison kill stays with status attacker');near(b.gauge,2,'plain hit cannot steal poison kill')
 local unknown=entity(10);unknown.flags=EntityFlag.FLAG_POISON
 dispatch('MC_POST_ENTITY_TAKE_DMG',10,unknown,1,0,{Entity=plain},0)
 dispatch('MC_POST_ENTITY_TAKE_DMG',10,unknown,1,DamageFlag.DAMAGE_POISON_BURN,{Entity=nil},0)
 dispatch('MC_POST_NPC_DEATH',nil,unknown);near(b.gauge,2,'untraceable poison never credits unrelated hit')
end
do
 local a=reset(p);local b=reset(q);a.gauge=2;b.gauge=2
 local e=entity(10);e.flags=EntityFlag.FLAG_POISON
 local poison=entity(2);poison.SpawnerEntity=p;poison.TearFlags=TearFlags.TEAR_POISON
 dispatch('MC_POST_ENTITY_TAKE_DMG',10,e,1,0,{Entity=poison},0)
 dispatch('REPENTOGON_POST_DOT_APPLIED',nil,e,{Entity=poison},1)
 e.flags=0;tick() -- Observe the original status ending before an unknown reapplication.
 e.flags=EntityFlag.FLAG_POISON
 dispatch('MC_POST_ENTITY_TAKE_DMG',10,e,1,DamageFlag.DAMAGE_POISON_BURN,{Entity=nil},0)
 dispatch('MC_POST_NPC_DEATH',nil,e)
 near(a.gauge,2+1/300,'expired poison owner cannot claim unknown reapplication')
 near(b.gauge,2+1/300,'unknown reapplication leaves other player unchanged')
end
do
 local s,t=reset(p);soundCalls={};p.inputs[1]=1
 damage(p,bullet);ok(#soundCalls==1 and soundCalls[1].id==1001,'guard plays its original sound once')
 damage(p,bullet);tick();ok(#soundCalls==1,'iframe and update do not replay guard sound')
 reset(p);soundCalls={};p.inputs[9]=1;tick()
 ok(#soundCalls==1 and soundCalls[1].id==1004,'accepted blue startup plays once')
 for _=1,4 do tick() end
 damage(p,bullet);ok(#soundCalls==2 and soundCalls[2].id==1002,'ordinary parry plays only parry success sound')
 damage(p,bullet);ok(#soundCalls==2,'parry iframe does not replay sound')
 reset(p);soundCalls={};p.inputs[9]=1;tick();damage(p,bullet)
 ok(#soundCalls==2 and soundCalls[2].id==1003,'perfect parry plays only perfect success sound')
 local reward=t.reward
 p.cooldown=0;api.Core.End(t,'test');t.needsRelease=false;api.Core.StartBlue(s,t,frame);damage(p,bullet)
 ok(t.reward==reward,'second perfect retains earliest shooting reward')
 ok(#soundCalls==4 and soundCalls[3].id==1004 and soundCalls[4].id==1003,'second valid blue and perfect still play sounds')
 p.inputs[9]=0;tick();ok(#soundCalls==4,'successful release does not replay sound')
 reset(p);soundCalls={};p.inputs[9]=1;tick();p.inputs[9]=0
 for _=1,20 do tick() end
 ok(#soundCalls==1 and soundCalls[1].id==1004,'whiff hold recovery and regeneration do not replay startup')
 p.inputs[1]=1;s.gauge=.5;damage(p,bullet)
 ok(s.burnout and #soundCalls==3 and soundCalls[2].id==1006 and soundCalls[3].id==1001,'last affordable guard plays burnout entry and guard')
 p.cooldown=0;damage(p,bullet);ok(#soundCalls==3,'failed burnout guard is silent')
 for _,call in ipairs(soundCalls) do
  ok(call.volume==1 and call.delay==0 and call.loop==false and call.pitch==1,'one shot normal pitch full tail')
 end
end
do
 local s,t=reset(p);soundCalls={};p.inputs[9]=1;tick()
 for _=1,30 do tick() end
 ok(#soundCalls==1 and soundCalls[1].id==1004,'long blue hold never loops startup sound')
 p.inputs[1]=1;tick()
 ok(t.mode=='startup' and #soundCalls==2 and soundCalls[2].id==1005,'single direction sounds at rush startup')
 for _=1,5 do tick() end
 ok(t.mode=='rush' and #soundCalls==2,'movement after freeze does not replay rush sound')
 p.inputs[3]=1;tick();p.inputs[1]=0;tick();tick()
 ok(#soundCalls==2,'smooth steering never replays rush sound')
 p.inputs[3]=0;p.inputs[2]=1;p.inputs[0]=1;tick()
 ok(t.mode=='idle' and #soundCalls==2,'reverse brake does not replay rush sound')
 s,t=reset(p);soundCalls={};s.gauge=.49;p.inputs[9]=1;tick()
 ok(s.burnout and #soundCalls==1 and soundCalls[1].id==1006,'unaffordable blue plays only burnout entry')
 for _=1,8 do tick() end
 p.inputs[9]=0;tick();p.inputs[9]=1;tick()
 ok(#soundCalls==1,'burnout retry has no additional sound')
 for _,gauge in ipairs({.49,.5}) do
  s,t=reset(p);soundCalls={};p.inputs[9]=1;tick()
  s.gauge=gauge;p.inputs[1]=1;tick()
  if gauge==.49 then
   ok(s.burnout and t.mode=='recovery' and #soundCalls==2 and soundCalls[2].id==1006,'unaffordable rush adds burnout sound only')
  else
   ok(s.burnout and t.mode=='startup' and #soundCalls==3 and soundCalls[2].id==1006 and soundCalls[3].id==1005,'paid final rush sounds with burnout entry')
   for _=1,5 do tick() end
   ok(t.mode=='rush' and #soundCalls==3,'paid final movement does not replay sound')
  end
 end
 for _,call in ipairs(soundCalls) do
  ok(call.volume==1 and call.delay==0 and not call.loop and call.pitch==1,'startup sounds preserve pitch and full one-shot tail')
 end
end
do
 local s,t=reset(p);p.Velocity=V(7,3);p.inputs[9]=1;p.inputs[4]=1;tick()
 ok(t.mode=='blue' and p.Velocity:Length()==0,'blue immediately stops prior movement velocity')
 local pos=p.Position
 for _=1,8 do tick() end
 near((p.Position-pos):Length(),0,'holding blue and shooting cannot walk')
 p.inputs[1]=1
 ok(Input.GetActionValue(1,0)==0 and Input.GetActionValue(4,0)==0,'blue blocks native move and shoot before reading raw intent')
 tick();ok(t.mode=='startup' and t.heading==0,'blocked native move still gives raw direction to rush')
 -- Finish the room freeze before starting an independent held-input case.
 for _=1,5 do tick() end
 s,t=reset(p);p.inputs[9]=1;p.inputs[1]=1;p.inputs[3]=1;local before=s.gauge;tick()
 ok(t.mode=='startup' and t.heading==45,'active plus held diagonal immediately commits to rush')
 near(s.gauge,before-1,'same-update blue plus rush pays each cost once')
 for _=1,5 do tick() end
 s,t=reset(p);p.inputs[9]=1;p.inputs[1]=.1;p.inputs[3]=.1;tick()
 ok(t.mode=='blue','stick deadzone remains stationary blue')
 pos=p.Position;tick();near((p.Position-pos):Length(),0,'stick drift cannot cause slow blue walking')
 p.inputs[9]=0;p.inputs[1]=0;p.inputs[3]=0
 for _=1,20 do tick() end
 p.inputs[1]=1;tick();ok(p.Position.X>pos.X,'movement restored after blue release and recovery')
end
do
 local s,t=reset(p);soundCalls={};api.Core.SetGauge(s,t,0);tick()
 ok(#soundCalls==1 and soundCalls[1].id==1006,'burnout entry plays once')
 for _=1,5 do tick() end
 api.Core.SetGauge(s,t,3,'Gain');tick();ok(#soundCalls==1,'partial burnout recovery remains silent')
 api.Core.SetGauge(s,t,6,'Gain');tick()
 ok(#soundCalls==2 and soundCalls[2].id==1007,'leaving burnout plays recovery once')
 for _=1,5 do tick() end
 api.Core.SetGauge(s,t,6,'Refill');tick();ok(#soundCalls==2,'already full cannot replay recovery')
 s,t=reset(p);soundCalls={};p.inputs[9]=1;tick();damage(p,bullet)
 ok(#soundCalls==2 and soundCalls[2].id==1003,'perfect full refill does not play burnout recovery')
end
do
 local s,t=reset(p);p.inputs[9]=1;tick();damage(p,bullet);p.inputs[9]=0;tick()
 ok(t.mode=='idle','successful release ends blue')
 p.inputs[9]=1;tick();ok(t.mode=='blue','fresh press immediately after successful release is accepted')
 s,t=reset(p);p.inputs[9]=1;tick();p.inputs[9]=0
 repeat tick() until t.mode=='recovery'
 repeat tick() until t.mode=='idle'
 p.inputs[9]=1;tick();ok(t.mode=='blue','fresh press immediately after recovery is accepted')
 s,t=reset(p);p.inputs[9]=1;tick();p.inputs[9]=0
 repeat tick() until t.mode=='recovery'
 p.inputs[9]=1
 repeat tick() until t.mode=='idle'
 tick();ok(t.mode=='idle','press inside recovery is not buffered')
 p.inputs[9]=0;tick();p.inputs[9]=1;tick();ok(t.mode=='blue','fresh press after blocked hold works')
end
do
 local s,t=reset(p);p.Position=V(100,100);p.inputs[1]=1
 local incoming=entity(9,V(40,100),V(5,0));damage(p,incoming)
 near(math.abs(t.impactAngle),180,'guard spark faces incoming side')
 -- Curved projectiles use their current velocity, not their owner's position.
 p.cooldown=0;incoming.Position=V(120,100);damage(p,incoming)
 near(math.abs(t.impactAngle),180,'curved projectile spark uses incoming velocity')
 s,t=reset(p);p.inputs[9]=1;tick();damage(p,nil,DamageFlag.DAMAGE_SPIKES)
 ok(t.impactKind=='Floor','blue floor damage selects floor effect')
 p.cooldown=0;damage(p,nil);ok(t.impactKind=='Center','sourceless blue selects center effect')
end
do
 local s,t=reset(p);api.Core.StartBlue(s,t,frame);api.Core.StartRush(s,t,frame,1,0)
 for _=1,7 do tick() end
 frame=frame+1;dispatch('MC_PRE_PLAYER_UPDATE',nil,p)
 local target=p.Position+V(0,20);p.Position=target
 dispatch('MC_POST_PLAYER_UPDATE',nil,p)
 ok(t.mode=='idle' and t.reason=='takeover','short forced displacement ends rush')
 near((p.Position-target):Length(),0,'short forced displacement is preserved')
end
do
 local s,t=reset(p);p.inputs[5]=1
 local w={GetWeaponType=function()return WeaponType.WEAPON_TEARS end,
  GetModifiers=function()return WeaponModifier.CURSED_EYE end,
  GetMaxFireDelay=function()return 10 end,GetCharge=function()return 0 end}
 p.weapon=w;t.mode='rush';t.moveFrames=5;t.remaining=100
 t.rushShot={primed=true,identity='1:2'};api.Core.GrantReward(s,t,frame);t.grantCharge=nil
 dispatch('MC_POST_TRIGGER_WEAPON_FIRED',nil,1,1,p,w)
 local first=frame
 ok(t.mode=='idle' and t.reason=='shot','first burst emission ends rush')
 ok(t.reward.started==first,'first burst emission starts reward')
 for _=1,4 do
  frame=frame+1
  ok(Input.GetActionValue(5,0)==0,'held key cannot truncate native release burst')
  dispatch('MC_POST_TRIGGER_WEAPON_FIRED',nil,1,1,p,w)
  dispatch('MC_POST_UPDATE',nil)
  ok(t.rushShot and t.rushShot.finishing,'burst survives through end-of-frame emission settlement')
  ok(t.reward.started==first,'later burst emissions never reset reward')
 end
 frame=frame+1;dispatch('MC_POST_UPDATE',nil)
 ok(t.rushShot==nil and Input.GetActionValue(5,0)==1,'normal firing returns after native burst ends')
 t.rushShot={primed=true,finishing=true,emittedAt=frame,identity='1:2'}
 dispatch('MC_POST_NEW_ROOM',nil)
 ok(t.rushShot==nil and Input.GetActionValue(5,0)==1,'room change cannot retain the release input mask')
 p.weapon=nil
end
do
 local a=reset(p);local b=reset(q);a.gauge=2;b.gauge=2
 local function apply(e,who,kind)
  dispatch('REPENTOGON_POST_DOT_APPLIED',nil,e,{Entity=who},kind)
  e.flags=e.flags|(kind==1 and EntityFlag.FLAG_POISON or EntityFlag.FLAG_BURN)
 end
 local function kill(e,kind)
  dispatch('MC_POST_ENTITY_TAKE_DMG',10,e,3.5,DamageFlag.DAMAGE_POISON_BURN,{DotKind=kind},0)
  dispatch('MC_POST_NPC_DEATH',nil,e)
 end
 local e=entity(10);apply(e,p,1);apply(e,q,2);kill(e,1)
 near(a.gauge,3,'native poison payload owns lethal tick with both statuses');near(b.gauge,2,'other burn owner receives nothing')
 e=entity(10);apply(e,p,1);apply(e,q,2);kill(e,2)
 near(a.gauge,3,'poison owner cannot steal lethal burn');near(b.gauge,3,'native burn payload owns lethal tick')
 local familiar=entity(3);familiar.familiar={Player=q}
 e=entity(10);apply(e,familiar,1);familiar.removed=true;kill(e,1)
 near(b.gauge,4,'script familiar status keeps owner after applicator disappears')
 local removed=entity(2);removed.SpawnerEntity=p
 local late=entity(10);dispatch('MC_POST_ENTITY_TAKE_DMG',10,late,.1,0,{Entity=removed},0)
 removed.removed=true;apply(late,removed,2);kill(late,2)
 near(a.gauge,4,'status applied after tear removal uses its hit snapshot')
 a.gauge=3
 local lost=entity(2);lost.SpawnerEntity=p;local victim=entity(10)
 dispatch('MC_POST_ENTITY_TAKE_DMG',10,victim,.1,0,{Entity=lost},0)
 lost.SpawnerEntity=nil;apply(victim,lost,2);kill(victim,2)
 near(a.gauge,4,'living projectile retains owner when familiar pointer disappears')
 a.gauge=3
 e=entity(10);apply(e,p,1);apply(e,q,1);kill(e,1)
 near(a.gauge,3,'replaced status does not credit old owner');near(b.gauge,5,'accepted replacement takes payload ownership')
 e=entity(10);apply(e,p,1);apply(e,nil,1);kill(e,1)
 near(a.gauge,3,'unowned accepted payload clears old player')
 e=entity(10);apply(e,p,1);kill(e,0)
 near(a.gauge,3,'unscoped synthetic poison hit cannot steal native status credit')
 local copy=entity(10);dispatch('REPENTOGON_POST_DOT_COPY',nil,e,copy,true)
 copy.flags=e.flags;kill(copy,1);near(a.gauge,4,'copied native status carries payload owner')
 e=entity(10);apply(e,p,1);dispatch('MC_POST_NEW_ROOM',nil);kill(e,1)
 near(a.gauge,4,'room reset removes delayed ownership')
 local cancelled=entity(10)
 dispatch('MC_POST_ENTITY_TAKE_DMG',10,cancelled,100,0,{Entity=p},0)
 dispatch('MC_ENTITY_TAKE_DMG',10,cancelled,100,0,{Entity=q},0) -- cancelled after PRE; no POST
 dispatch('MC_POST_NPC_DEATH',nil,cancelled)
 near(a.gauge,5,'cancelled later hit cannot steal a queued death');near(b.gauge,5,'cancelled attacker gains nothing')
 local bleed=entity(10);bleed.flags=EntityFlag.FLAG_BLEED_OUT
 dispatch('REPENTOGON_POST_DOT_APPLIED',nil,bleed,{Entity=q},3)
 dispatch('MC_POST_ENTITY_TAKE_DMG',10,bleed,3.1,0,{DotKind=3},0)
 dispatch('MC_POST_NPC_DEATH',nil,bleed);near(b.gauge,6,'native bleeding uses its own payload owner')
end
print('Drive Glove callbacks: '..count..' assertions passed')
