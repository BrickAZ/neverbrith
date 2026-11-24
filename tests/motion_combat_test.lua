local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
local source=io.open('motion_combat.lua');check(source~=nil,'world combat executor is missing');source:close()
local V={};V.__index=V
function Vector(x,y)return setmetatable({X=x,Y=y},V)end
function V.__add(a,b)return Vector(a.X+b.X,a.Y+b.Y)end
function V.__sub(a,b)return Vector(a.X-b.X,a.Y-b.Y)end
function V.__mul(a,b)if type(a)=='number'then a,b=b,a end;return Vector(a.X*b,a.Y*b)end
function V:Length()return math.sqrt(self.X^2+self.Y^2)end
function Color(...)return {...}end
EntityFlag={FLAG_FRIENDLY=1,FLAG_CHARM=2,FLAG_NO_SPRITE_UPDATE=4}
EntityCollisionClass={ENTCOLL_NONE=0};EntityGridCollisionClass={GRIDCOLL_NONE=0};GridCollisionClass={COLLISION_OBJECT=2,COLLISION_SOLID=3}
EntityType={ENTITY_PLAYER=1,ENTITY_EFFECT=1000};EffectVariant={EFFECT_NULL=0}
RoomType={ROOM_SACRIFICE=2}
DamageFlag={DAMAGE_IV_BAG=1,DAMAGE_CHEST=2,DAMAGE_DEVIL=4,DAMAGE_FAKE=8,DAMAGE_SPIKES=16}
ButtonAction={ACTION_LEFT=0,ACTION_RIGHT=1,ACTION_UP=2,ACTION_DOWN=3,ACTION_ITEM=9}
InputHook={GET_ACTION_VALUE=2};Keyboard={KEY_LEFT_SHIFT=340}
Input={IsButtonPressed=function()return false end}
EntityRef=function(e)return {Entity=e}end
include=function(n)return dofile(n..'.lua')end
local callbacks,frame,paused,entities,root,od={},0,false,{}, {},false
ModCallbacks={};for _,name in ipairs({'MC_ENTITY_TAKE_DMG','MC_POST_ENTITY_TAKE_DMG','MC_POST_UPDATE','MC_POST_NEW_ROOM','MC_POST_NEW_LEVEL','MC_POST_GAME_STARTED','MC_PRE_GAME_EXIT','MC_PRE_MOD_UNLOAD','MC_PRE_NPC_UPDATE','MC_INPUT_ACTION','MC_PRE_PLAYER_TAKE_DMG','MC_POST_RENDER','MC_POST_GLOWING_HOURGLASS_SAVE','MC_POST_GLOWING_HOURGLASS_LOAD'})do ModCallbacks[name]=name end
local mod={};function mod:AddPriorityCallback(id,priority,fn)callbacks[id]=callbacks[id]or{};table.insert(callbacks[id],{fn=fn,priority=priority});table.sort(callbacks[id],function(a,b)return a.priority<b.priority end)end
function mod:AddCallback(id,fn)self:AddPriorityCallback(id,0,fn)end
local function dispatch(id,...)for _,c in ipairs(callbacks[id]or{})do local r=c.fn(mod,...);if r~=nil then return r end end end
local room={GetGridCollisionAtPos=function(_,p)return p.X>=200 and 4 or 0 end,GetClampedPosition=function(_,p)return p end,GetType=function()return 1 end}
local game={GetFrameCount=function()return frame end,IsPaused=function()return paused end,GetRoom=function()return room end}
Game=function()return game end
local function npc(x,y,hp,boss)
 local n={Position=Vector(x,y),Velocity=Vector(2,3),Size=10,HitPoints=hp,Type=10,InitSeed=#entities+50,flags=0,EntityCollisionClass=4,CollisionDamage=1,boss=boss,data={}}
 function n:Exists()return not self.removed end;function n:IsDead()return self.HitPoints<=0 end;function n:ToNPC()return self end
 function n:ToPlayer()return nil end;function n:IsVulnerableEnemy()return self.EntityCollisionClass~=0 and not self.invulnerable and not self:IsDead()end
 function n:IsActiveEnemy()return true end;function n:IsBoss()return self.boss or false end
 function n:HasEntityFlags(f)return self.flags&f~=0 end;function n:AddEntityFlags(f)self.flags=self.flags|f end
 function n:ClearEntityFlags(f)self.flags=self.flags&~f end;function n:GetData()return self.data end
 function n:SetColor()self.flashes=(self.flashes or 0)+1 end
 function n:TakeDamage(d,_,src)
  check(mod.MotionInput.scope~=nil,'delayed damage keeps command provenance');self.source=src.Entity
  dispatch('MC_ENTITY_TAKE_DMG',self,d,0,src,0)
  if self.cancel then return false end
  if self.deferred then self.pending=(self.pending or 0)+d else self.HitPoints=math.max(0,self.HitPoints-d)end
  dispatch('MC_POST_ENTITY_TAKE_DMG',self,d,0,src,0);return true
 end
 entities[#entities+1]=n;return n
end
local p={Position=Vector(40,50),Velocity=Vector(0,0),Size=10,Damage=10,ControllerIndex=0,InitSeed=1,items={[1]=true,[2]=true,[3]=true,[4]=true}}
function p:Exists()return true end;function p:IsDead()return self.dead or false end;function p:HasCollectible(id)return self.items[id]end
local q=setmetatable({InitSeed=2,items=p.items},{__index=p})
Isaac={GetEntityVariantByName=function()return 3026 end,GetRoomEntities=function()return entities end,DebugString=function()end,Spawn=function(kind,variant,_,pos,_,owner)
 check(kind==1000 and variant==3026,'wave uses its registered entity, never invalid null effect')
 local e={Position=pos,Velocity=Vector(0,0),SpawnerEntity=owner,Visible=true};function e:Exists()return not self.removed end;function e:Remove()self.removed=true end;function e:ToEffect()return self end;return e end}
mod.MotionInput={WithCommand=function(self,_,cmd,fn)self.scope=cmd.serial;local r=fn();self.scope=nil;return r end,MarkAttack=function()return true end,GetState=function()return {}end,IsRestricted=function()return true end}
function mod.MotionInput:IsODModifierPressed(player)
 check(player==p or player==q,'combat asks the input service about the owning player')
 return od
end
local presentations={}
local motionAssets=dofile('generated/motion_presentation.lua')
mod.MotionPresentation={Play=function(_,who,name,options)presentations[who]={key=name,options=options,combat=true,sourceOwner=options.sourceOwner};return {ok=true}end,
 Stop=function(_,who)presentations[who]=nil end,SetCombatFrame=function(_,who,t)presentations[who].frame=t;return true end,
 SetTarget=function(_,who,target)presentations[who].target=target;return true end,FinishTarget=function()end,
 GetState=function(_,who)return presentations[who]end,GetTargetPosition=function(_,who)return presentations[who]and presentations[who].landing end,RenderProjectile=function()end,
 GetHorizontalTravel=function(_,who,t)local s=presentations[who];local a=motionAssets[s.key];return a[(s.options.variant or 'normal')..'_frames'][t+1].feet[1]-a.start_feet[1]end,
 GetVerticalHeight=function(_,who,t)local s=presentations[who];local a=motionAssets[s.key];return a[(s.options.variant or 'normal')..'_frames'][t+1].feet[2]-a.start_feet[2]end,
 ReleasePlayerPose=function(_,who)presentations[who].freeActor=true end,
 StartRecoveryTail=function(_,who,id)presentations[who].recoveryTail=true;presentations[who].collectibleId=id end}
local context={Key=function(who)return tostring(who.InitSeed)end,GetSaveRoot=function()return root end,GetCurrentRunSeed=function()return 123 end,
 GetPlayers=function()return {p,q}end}
context.HUD={Update=function()end,Render=function()end,Reset=function()end,Shutdown=function()end,Prune=function()end}
local api=include('motion_combat')(mod,context)
local serial=0
local function attack(name,id)serial=serial+1;return api:Execute(p,name,{serial=serial,facing='right'},{id=id,owner='test'})end
local function tick(n)for _=1,n do
 for _,e in ipairs(entities)do if e.pending then e.HitPoints=math.max(0,e.HitPoints-e.pending);e.pending=nil end end
 frame=frame+1;dispatch('MC_POST_UPDATE')
end end
local function reset()api:Reset('test');presentations={};entities={};od=false;p.dead=false;p.Position=Vector(40,50);p.Velocity=Vector(0,0);p.items={[1]=true,[2]=true,[3]=true,[4]=true};api:GetRecord(p).od=0 end
local n=npc(105,50,100);check(attack('wave',1).ok,'wave starts');tick(6);check(#api.shots==1,'wave emits real world entity');p.Position=Vector(40,100);tick(8)
check(n.HitPoints==90 and n.source==p,'wave travels independently and damages true enemy');check(api:GetRecord(p).energy==10,'actual damage grants energy');check(#api.shots==0,'wave consumed on first hit');p.Position=Vector(40,50)
reset();n=npc(230,50,100);attack('wave',1);tick(35);check(n.HitPoints==100 and #api.shots==0,'wall blocks swept projectile')
reset();n=npc(70,50,100);local back=npc(0,50,100);attack('dp',2);tick(31);check(n.HitPoints==80 and back.HitPoints==100,'DP frontal damage once across active window')
reset();n=npc(70,50,100);n.cancel=true;local energy=api:GetRecord(p).energy;attack('dp',2);tick(31);check(api:GetRecord(p).energy==energy,'cancelled damage cannot build meter')
reset();n=npc(70,50,100);n.deferred=true;energy=api:GetRecord(p).energy;attack('dp',2);tick(15)
check(n.HitPoints==80 and api:GetRecord(p).energy==math.min(90,energy+20),'deferred native HP changes grant only settled damage')
reset();n=npc(70,50,100);od=true;attack('dp',2);tick(51);check(n.HitPoints==50,'OD DP two real stages');check(api:GetRecord(p).od>0,'OD cooldown committed');check(not attack('dp',2).ok,'OD cooldown rejects rather than downgrades');check(api:GetRecord(q).od==0,'OD cooldown per player');paused=true;local remaining=api:GetRecord(p).od;tick(20);check(api:GetRecord(p).od==remaining,'paused cooldown frozen');paused=false
reset();n=npc(70,50,100);api:Execute(p,'dp',{serial=9001,facing='right',odRequested=true},{id=2,owner='test'});check(api:GetState(p).variant=='od','executor respects the OD captured with the command, not the current Shift state');tick(51)
reset();n=npc(70,50,100);od=true;api:Execute(p,'dp',{serial=9002,facing='right',odRequested=false},{id=2,owner='test'});check(api:GetState(p).variant=='normal','an explicit ordinary buffered command cannot turn into OD from a later Shift press')
for _,variant in ipairs({'normal','od'})do for _,sign in ipairs({-1,1})do
 reset();od=variant=='od';n=npc(40+30*sign,50,500)
 check(attack('circle_360',3).ok,'both 360 variants can start their landing splash');tick(6)
 local center=Vector(40+30*sign,80);presentations[p].landing=center
 local near=npc(center.X+60*sign,center.Y,100)
 local edge=npc(center.X+80*sign,center.Y,100)
 local backEdge=npc(center.X-80*sign,center.Y,100)
 local vertical=npc(center.X,center.Y+80,100)
 local outside=npc(center.X+80.01*sign,center.Y,100)
 local diagonal=npc(center.X+60,center.Y+60,100)
 local friendly=npc(center.X+5,center.Y,100);friendly.flags=EntityFlag.FLAG_FRIENDLY
 local charmed=npc(center.X+6,center.Y,100);charmed.flags=EntityFlag.FLAG_CHARM
 local invulnerable=npc(center.X+7,center.Y,100);invulnerable.invulnerable=true
 local cancelled=npc(center.X+8,center.Y,100);cancelled.cancel=true
 tick((variant=='od'and 34 or 42)-7)
 check(near.HitPoints==100 and n.HitPoints==500,'landing splash never hits before the existing slam tick')
 tick(1)
 check(near.HitPoints==70 and edge.HitPoints==70 and backEdge.HitPoints==70 and vertical.HitPoints==70,'360 splash is a complete 80-unit circle around the real landing rather than player position')
 check(n.HitPoints==(variant=='od'and 440 or 470),'held primary receives only its ordinary or OD direct slam, never splash too')
 check(outside.HitPoints==100 and diagonal.HitPoints==100,'360 splash excludes centers outside its exact radius')
 check(friendly.HitPoints==100 and charmed.HitPoints==100 and invulnerable.HitPoints==100 and cancelled.HitPoints==100,'landing splash respects existing exclusions and damage cancellation')
 check(near.source==p and edge.source==p,'landing splash preserves player command damage attribution')
 tick(20);check(near.HitPoints==70 and n.HitPoints==(variant=='od'and 440 or 470),'landing splash and primary settle once during the full action')
end end
reset();n=npc(70,50,5);attack('circle_360',3);tick(6);local splashVictim=npc(120,50,100);api:GetRecord(p).energy=0
tick(37);check(n:IsDead()and splashVictim.HitPoints==70,'a lethal primary slam still damages nearby enemies')
check(api:GetRecord(p).energy==35,'360 splash builds meter only from actual primary and secondary HP loss including overkill')
reset();n=npc(70,50,500,true);attack('circle_360',3);tick(6);presentations[p].landing=Vector(600,600)
local bossNeighbor=npc(120,50,100);tick(37)
check(bossNeighbor.HitPoints==70 and n.HitPoints==470 and n.Position.X==70,'Boss splash uses its real retained position rather than a cinematic target offset')
reset();n=npc(70,50,100);local oldvel=n.Velocity;check(attack('circle_360',3).ok,'360 has a real candidate');tick(6);check(n.EntityCollisionClass==0 and presentations[p].target==n,'real grab disables contact and supplies true target');check(dispatch('MC_PRE_NPC_UPDATE',n)==true,'grabbed AI stopped');tick(35);check(n.HitPoints==100,'slower 360 does not deal early damage');tick(1);check(n.HitPoints==70,'360 real HP changes on delayed slam');tick(15);check(not api:IsBusy(p),'slower 360 ends after 54 action ticks plus existing hitstop');check(n.EntityCollisionClass==4 and n.CollisionDamage==1 and n.flags==0,'grab restores owned native state');check(n.Velocity==oldvel,'grab restores velocity')
reset();n=npc(10,50,100);check(attack('circle_360',3).ok,'independent 360 grabs a close enemy behind the stale facing');tick(55);check(n.HitPoints==70,'back-side 360 settles actual damage')
reset();n=npc(140,50,100);local far=attack('circle_360',3)
check(not far.ok and far.reason=='Out of grab range'and api:GetState(p).feedback.text:find('64',1,true),'a real enemy outside the 36-unit grab envelope reports the 64-unit gap, not no target')
reset();n=npc(70,50,100);od=true;attack('circle_360',3);n.Position=Vector(150,50);tick(7);check(n.HitPoints==100 and n.EntityCollisionClass==0 and api:GetRecord(p).od>0 and api:IsBusy(p),'a target in range at command confirmation cannot evade the six-frame startup with movement')
reset();n=npc(70,50,100);local replacement=npc(73,50,100);attack('circle_360',3);n.Position=Vector(150,50);tick(6)
check(presentations[p]and presentations[p].target==n and n.EntityCollisionClass==0 and replacement.EntityCollisionClass==4,'360 preserves its confirmed target over a newly closer replacement')
reset();n=npc(70,50,100);replacement=npc(73,50,100);attack('circle_360',3);n.removed=true;tick(6)
check(presentations[p]and presentations[p].target==replacement,'candidate death before contact does not cancel another available legal grab')
reset();n=npc(70,50,100);attack('circle_360',3);p.Position=Vector(50,50);tick(6);check(p.Position.X==50,'grab locks at successful contact, not pre-movement start');api:Reset('test');p.Position=Vector(40,50)
reset();n=npc(70,50,100);od=true;attack('circle_360',3);tick(49);check(n.HitPoints==40,'OD360 actual slam');check(api:GetRecord(p).od>0,'OD360 shares cooldown with DP')
reset();n=npc(70,50,100,true);attack('circle_360',3);tick(55);check(n.Position.X==70 and n.Position.Y==50,'Boss stays at original position');check(not attack('circle_360',3).ok,'Boss anti-grab respected');tick(90);check(attack('circle_360',3).ok,'Boss anti-grab expires')
reset();api:GetRecord(p).energy=0;check(not attack('circle_720',4).ok,'720 needs meter');api:GetRecord(p).energy=90;check(not attack('circle_720',4).ok and api:GetRecord(p).energy==90,'720 empty room does not spend')
n=npc(70,50,400);n.invulnerable=true;local denied=attack('circle_720',4)
check(not denied.ok and denied.reason=='Target invulnerable'and api:GetRecord(p).energy==90,'full meter with a visible invulnerable enemy reports the actual target condition without spending');n.removed=true
n=npc(70,50,400);local other=npc(120,50,400);check(attack('circle_720',4).ok,'720 real target begins');check(api:GetRecord(p).energy==0 and presentations[p].options.target==n,'720 spends and binds true enemy');tick(262);check(n.HitPoints==250 and other.HitPoints==300,'720 primary and room damage each once');check(api:GetRecord(p).energy==0,'720 never fills own meter')
while api:GetState(p).frame and api:GetState(p).frame<289 do tick(1)end
check(not api:IsBusy(p)and presentations[p].recoveryTail,'720 release detaches the cosmetic tail from combat control')
check(dispatch('MC_INPUT_ACTION',p,2,0)==nil and dispatch('MC_PRE_PLAYER_TAKE_DMG',p,1,0,EntityRef(n),0)==nil,'720 tail has neither movement lock nor invulnerability')
check(n.EntityCollisionClass==4 and attack('wave',1).ok,'released target restores and next move can replace the cosmetic tail')
reset();api:GetRecord(p).energy=90;n=npc(70,50,10);attack('circle_720',4);tick(270);check(n:IsDead() and api:IsBusy(p),'own lethal slam does not abort V9');tick(140);check(not api:IsBusy(p),'lethal V9 completes')
reset();api:GetRecord(p).energy=90;n=npc(70,50,400);attack('circle_720',4);n.removed=true;tick(1);check(not api:IsBusy(p) and api:GetRecord(p).energy==90,'external victim removal refunds and cleans')
reset();n=npc(70,50,100);attack('circle_360',3);tick(6);dispatch('MC_POST_NEW_ROOM');check(n.EntityCollisionClass==4 and n.flags==0 and not api:IsBusy(p),'room transition restores real victim')
api:GetRecord(p).energy=47;api:GetRecord(p).od=83;dispatch('MC_POST_GLOWING_HOURGLASS_SAVE',2);api:GetRecord(p).energy=1;api:GetRecord(p).od=1;dispatch('MC_POST_GLOWING_HOURGLASS_LOAD',2);check(api:GetRecord(p).energy==47 and api:GetRecord(p).od==83,'hourglass restores energy and cooldown')
local saved=api:Capture();api:GetRecord(p).energy=0;api:Restore(saved);check(api:GetRecord(p).energy==47,'continue-compatible primitive record')
api:GetRecord(p).energy=0;api:GetRecord(p).od=51
check(api:OnAcquire(p,'circle_720')and api:GetRecord(p).energy==90 and api:GetRecord(p).od==51,'actual 720 acquisition fills three SA bars without changing OD')
api:GetRecord(p).energy=17;tick(3);check(api:GetRecord(p).energy==17,'holding 720 does not refill the spent meter every update')
check(not api:OnAcquire(p,'circle_360')and api:GetRecord(p).energy==17,'other collectibles cannot grant the new 720 acquisition benefit')
dispatch('MC_PRE_GAME_EXIT');api:OnAcquire(p,'circle_720');dispatch('MC_POST_GAME_STARTED',true)
check(api:GetRecord(p).energy==17,'collectible reconstruction on continue does not refill saved SA')
dispatch('MC_PRE_GAME_EXIT');api:OnAcquire(p,'circle_720');dispatch('MC_POST_GAME_STARTED',false)
check(api:GetRecord(p).energy==90,'new-run starting 720 grants the acquisition meter after state initialization')
reset();n=npc(70,50,100);od=true;attack('dp',2)
check(dispatch('MC_PRE_PLAYER_TAKE_DMG',p,1,0,EntityRef(n),0)==false,'OD startup protected')
check(dispatch('MC_PRE_PLAYER_TAKE_DMG',p,1,DamageFlag.DAMAGE_IV_BAG,{},0)==nil,'life payments allowed')
check(dispatch('MC_PRE_PLAYER_TAKE_DMG',p,1,0,{},0)==false,'OD protected phase includes source-less ordinary damage')
for _,t in ipairs({0,6,12,21,22,32})do api.sessions['1'].tick=t
 check(dispatch('MC_PRE_PLAYER_TAKE_DMG',p,1,DamageFlag.DAMAGE_SPIKES,{},0)==false,'OD environmental invulnerability throughout both rises')end
api.sessions['1'].tick=33;check(dispatch('MC_PRE_PLAYER_TAKE_DMG',p,1,0,EntityRef(n),0)==nil,'OD recovery vulnerable')
for _,variant in ipairs({'normal','od'})do for _,facing in ipairs({'left','right'})do
 reset();od=variant=='od';local sign=facing=='right'and 1 or -1
 api:Execute(p,'dp',{serial=9009,facing=facing},{id=2,owner='test'})
 for action=0,3 do check(dispatch('MC_INPUT_ACTION',p,InputHook.GET_ACTION_VALUE,action)==0,'whole uppercut blocks WASD')end
 local landed=false
 for i=1,(variant=='od'and 50 or 30)-1 do
  if not landed then p.Position=Vector(999,999);p.Velocity=Vector(-4,9)end;tick(1)
  local wasLanded=landed;landed=api:GetState(p).landed or landed
  if not landed then check(p.Position.Y==50 and p.Velocity.X==0 and p.Velocity.Y==0,'airborne uppercut ignores player drift and preserves ground Y')end
  if landed and not wasLanded then p.Position=Vector(p.Position.X,60)end
 end
 check(landed and dispatch('MC_INPUT_ACTION',p,2,0)==nil and presentations[p].freeActor,'last landing releases movement and native pose before remaining recovery')
 check(math.abs(p.Position.X-(40+sign*(variant=='od'and 57 or 51)))<.001,'uppercut follows approved horizontal source distance')
 check(p.Position.Y==60,'movement after landing is not snapped back during recovery')
 tick(1);check(not api:IsBusy(p)and dispatch('MC_INPUT_ACTION',p,2,0)==nil,'input returns after uppercut')
end end
reset();p.Position=Vector(190,50);attack('dp',2);tick(29);check(p.Position.X<=190 and p.Position.Y==50,'forced uppercut stops body at wall')
for _,variant in ipairs({'normal','od'})do
 reset();od=variant=='od';local victims={};for i=1,12 do victims[i]=npc(1000,50,400)end;attack('dp',2)
 for i=1,(variant=='od'and 50 or 30)do if i>=6 and i<=17 then victims[i-5].Position=Vector(p.Position.X+20,50)end;tick(1)end
 check(not api:IsBusy(p),'multi-target hits cannot extend uppercut control duration')
end
api:Shutdown()
print('motion_combat: '..checks..' assertions passed')

