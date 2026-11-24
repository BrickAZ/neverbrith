local n=0;local function ok(v,m)assert(v,m);n=n+1 end
ModCallbacks={};for i,name in ipairs({'MC_PRE_PLAYER_UPDATE','MC_INPUT_ACTION','MC_ENTITY_TAKE_DMG','MC_PRE_USE_ITEM',
 'MC_POST_NEW_ROOM','MC_POST_GAME_STARTED','MC_PRE_GAME_EXIT','MC_PRE_MOD_UNLOAD','MC_POST_GLOWING_HOURGLASS_LOAD',
 'MC_POST_ENTITY_REMOVE','MC_POST_TEAR_INIT','MC_PRE_TEAR_UPDATE','MC_POST_LASER_INIT','MC_PRE_LASER_UPDATE',
 'MC_POST_KNIFE_INIT','MC_PRE_KNIFE_UPDATE','MC_POST_BOMB_INIT','MC_PRE_BOMB_UPDATE','MC_POST_PROJECTILE_INIT',
 'MC_PRE_PROJECTILE_UPDATE','MC_POST_EFFECT_INIT','MC_EXECUTE_CMD'})do ModCallbacks[name]=i end
ButtonAction={ACTION_LEFT=0,ACTION_RIGHT=1,ACTION_UP=2,ACTION_DOWN=3,ACTION_SHOOTLEFT=4,ACTION_SHOOTRIGHT=5,
 ACTION_SHOOTUP=6,ACTION_SHOOTDOWN=7,ACTION_BOMB=8,ACTION_ITEM=9,ACTION_PILLCARD=10}
InputHook={IS_ACTION_PRESSED=0,IS_ACTION_TRIGGERED=1,GET_ACTION_VALUE=2}
Direction={LEFT=0,UP=1,RIGHT=2,DOWN=3};PillCardSlot={PRIMARY=0};PocketItemType={ACTIVE_ITEM=2}
local callbacks={};local mod={};local time,paused=0,false;local people={};local buttons={}
function mod:AddPriorityCallback(id,priority,fn,filter)
 callbacks[id]=callbacks[id] or {};callbacks[id][#callbacks[id]+1]={fn=fn,priority=priority,filter=filter}
 table.sort(callbacks[id],function(a,b)return a.priority<b.priority end)
end
function mod:AddCallback(id,fn,filter)self:AddPriorityCallback(id,0,fn,filter)end
local function dispatch(name,...)
 for _,r in ipairs(callbacks[ModCallbacks[name] or name] or {})do local v=r.fn(mod,...);if v~=nil then return v end end
end
local function ent(kind,parent)
 local e={Type=kind,SpawnerEntity=parent,data={}}
 function e:GetData()return self.data end;function e:ToPlayer()return self.Type==1 and self or nil end
 function e:ToFamiliar()return nil end;function e:Exists()return not self.removed end;function e:Remove()self.removed=true end
 return e
end
local function person(id)
 local p=ent(1);p.InitSeed=id;p.ControllerIndex=id;p.items={};p.slots={[0]=0};p.canShoot=false
 function p:HasCollectible(x)return self.items[x]==true end;function p:GetActiveItem(slot)return self.slots[slot] or 0 end
 function p:GetHeadDirection()return self.head or Direction.RIGHT end;function p:IsDead()return self.dead or false end
 function p:GetPocketItem()return self.pocket end
 function p:SetCanShoot()error('must not mutate another system CanShoot flag')end
 return p
end
local game={};function game:GetFrameCount()return time*30 end;function game:IsPaused()return paused end
function game:GetNumPlayers()return #people end;Game=function()return game end
local p,q=person(1),person(2);people={p,q}
Input={GetActionValue=function(action,controller)
 local who=controller==1 and p or q
 -- Exercise the adapter's raw-read bypass through the exact same input hook.
 local hook=dispatch('MC_INPUT_ACTION',who,InputHook.GET_ACTION_VALUE,action)
 if hook~=nil then return hook end
 return buttons[controller] and buttons[controller][action] or 0
end}
Isaac={GetPlayer=function(i)return people[i+1]end,DebugString=function()end}
include=function(name)return dofile(name..'.lua')end
local service=include('motion_input')(mod,{GetPlayers=function()return people end,Now=function()return time end,Key=function(who)return tostring(who.InitSeed)end})
ok(mod.MotionInput==service,'bootstrap exports one service')
local executions={};local function bind(id,profile)
 return {collectibleId=id,profile=profile,has=function(who)return who:HasCollectible(id)end,
 availability=function(who)return who.status or 'ready'end,
 execute=function(who,command)
  executions[#executions+1]={player=who,command=command}
  local attack=ent(2,who);dispatch('MC_POST_TEAR_INIT',attack)
  ok(not attack.removed,'synchronous skill attack whitelisted before init returns')
  ok(dispatch('MC_ENTITY_TAKE_DMG',ent(10),1,0,{Entity=who},0)==nil,'direct skill damage allowed')
  return {ok=true}
 end}
end
service:RegisterOwner('wave',bind(101,'wave_tap'));service:RegisterOwner('double',bind(102,'double_wave_tap'))
ok(not p:HasCollectible(101),'registration grants no inventory or effect')
local function tick(t,item,shoot,active,who)
 time=t;who=who or p;if item then who.slots[0]=item end
 buttons[who.ControllerIndex]={[ButtonAction.ACTION_SHOOTRIGHT]=shoot and 1 or 0,[ButtonAction.ACTION_ITEM]=active and 1 or 0}
 dispatch('MC_PRE_PLAYER_UPDATE',who)
end
tick(0,0,false,false);p.items[101]=true;tick(.1,101,false,false)
ok(service:IsRestricted(p),'held item restricts attacks even without active held')
ok(dispatch('MC_INPUT_ACTION',p,InputHook.GET_ACTION_VALUE,ButtonAction.ACTION_SHOOTRIGHT)==0,'native shoot suppressed')
ok(dispatch('MC_INPUT_ACTION',p,InputHook.IS_ACTION_TRIGGERED,ButtonAction.ACTION_BOMB)==false,'native bomb prevented before consume')
ok(dispatch('MC_INPUT_ACTION',q,InputHook.GET_ACTION_VALUE,ButtonAction.ACTION_SHOOTRIGHT)==nil,'coop input unaffected')
tick(.2,nil,false,true);tick(.3,nil,true,true);tick(.4,nil,true,true)
ok(#executions==1 and executions[1].command.facing=='right','raw arrow survives suppression and hold dedup')
ok(service:GetDiagnosticText(p):find('已释放',1,true)~=nil,'successful input is not diagnosed as unfinished')
tick(.5,nil,false,true);tick(.6,nil,true,true);ok(#executions==2,'fresh click reexecutes')
local native=ent(7,p);dispatch('MC_POST_LASER_INIT',native);ok(native.removed,'native laser output removed')
ok(dispatch('MC_ENTITY_TAKE_DMG',ent(10),1,0,{Entity=p},0)==false,'native direct attack damage cancelled')
ok(dispatch('MC_ENTITY_TAKE_DMG',p,1,0,{Entity=p},0)==nil,'health cost not cancelled')
local res=dispatch('MC_PRE_USE_ITEM',101,nil,p,0,0)
-- Installed 1.0.12a resources/scripts/enums.lua: only boolean true cancels PRE_USE_ITEM.
local charge,nativeUses=4,0
if res~=true then charge=charge-1;nativeUses=nativeUses+1 end
ok(charge==4 and nativeUses==0,'native boolean cancellation prevents item use and charge consumption')
ok(dispatch('MC_PRE_USE_ITEM',999,nil,p,0,0)==nil,'unregistered active untouched')
p.items[102]=true;tick(.7,102,true,true);ok(#executions==2,'slot switch cannot reuse held arrow')
tick(.8,nil,false,true);tick(.9,nil,true,true);tick(1,nil,false,true);tick(1.2,nil,true,true)
ok(#executions==3,'double executes only after second click')
tick(1.3,nil,false,true);tick(1.4,nil,true,true);dispatch('MC_POST_NEW_ROOM')
tick(1.5,nil,false,true);tick(1.6,nil,true,true);ok(#executions==3,'room clears pending first tap')
p.items[101]=nil;ok(service:IsRestricted(p),'one of two remains')
p.items[102]=nil;ok(not service:IsRestricted(p),'last item loss immediately lifts restriction')
ok(p.canShoot==false,'another system flag untouched')
p.items[101]=true;tick(1.7,101,false,false);paused=true;tick(1.8,nil,true,true);paused=false;tick(1.9,nil,true,true)
ok(#executions==3,'pause preserves held baseline and prevents ghost click')
tick(2,nil,false,true);tick(2.1,nil,true,true);ok(#executions==4,'new click after resume works')
q.items[101]=true;tick(2.2,101,false,true,q);tick(2.3,nil,true,true,q)
ok(#executions==5 and executions[5].player==q,'coop independent input state')
local bad=pcall(function()service:RegisterOwner('bad',bind(101,'wave_tap'))end);ok(not bad,'duplicate runtime ID rejected')
bad=pcall(function()service:RegisterOwner('bad',bind(103,'imaginary'))end);ok(not bad,'unknown profile rejected')

service:RegisterOwner('reverse',bind(103,'reverse_qcf'));p.items[103]=true
time=2.4;buttons[1]={[ButtonAction.ACTION_SHOOTUP]=1};dispatch('MC_PRE_PLAYER_UPDATE',p)
tick(2.5,103,false,false)
ok(service:GetState(p).facing=='up','switching owner preserves this run last explicit shot')
dispatch('MC_POST_NEW_ROOM');tick(2.6,nil,false,false)
ok(service:GetState(p).facing=='up','room reset preserves shot memory while clearing attempt')
dispatch('MC_POST_GAME_STARTED');p.head=Direction.UP;tick(2.7,nil,false,false)
ok(service:GetState(p).facing=='up','new run falls back to current head')
p.head=Direction.LEFT;tick(2.8,nil,false,false)
ok(service:GetState(p).facing=='left','never-shot head fallback updates every sample')

local before=#executions
p.slots[0]=999;p.slots[1]=101;tick(3,nil,true,true)
ok(service:IsRestricted(p) and #executions==before,'unselected schoolbag item restricts without executing')
p.items[102]=true;p.slots[2]=102;p.pocket={GetType=function()return PocketItemType.ACTIVE_ITEM end,GetSlot=function()return 3 end}
local function pocket(t,shoot,both)
 time=t;buttons[1]={[5]=shoot and 1 or 0,[10]=1,[9]=both and 1 or 0};dispatch('MC_PRE_PLAYER_UPDATE',p)
end
pocket(3.1,false);pocket(3.2,true);pocket(3.3,false);pocket(3.4,true)
ok(#executions==before+1,'selected pocket active uses pillcard hold and its own double tap profile')
pocket(3.5,false,true);pocket(3.6,true,true)
ok(#executions==before+1,'simultaneous active-slot keys do not choose an arbitrary owner')
p.pocket=nil;p.slots[2]=0

local failed=0
service:RegisterOwner('failed',{collectibleId=104,profile='wave_tap',has=function(who)return who:HasCollectible(104)end,
 execute=function()failed=failed+1;return {ok=false,reason='target'}end})
p.items[104]=true;tick(3.7,104,false,true);tick(3.8,nil,true,true);tick(3.9,nil,true,true)
ok(failed==1 and service:GetState(p).lastEvent.reason=='target','execution failure is consumed once and reported')

p.status='recovery';tick(4,101,false,true);tick(4.1,nil,true,true)
ok(service:GetState(p).pending and #executions==before+1,'recovery buffers without executing')
p.status='ready';tick(4.2,nil,true,true)
ok(#executions==before+2,'recovery ready releases exactly one pending command')
p.status='resource';tick(4.3,nil,false,true);tick(4.4,nil,true,true);p.status='ready';tick(4.5,nil,true,true)
ok(#executions==before+2 and service:GetState(p).lastEvent.reason=='resource','resource failure does not wait or retry')
p.status='recovery';tick(4.6,nil,false,true);tick(4.7,nil,true,true)
p.dead=true;tick(4.8,nil,true,true);p.dead=false;p.status='ready';tick(4.9,nil,true,true)
ok(#executions==before+2 and not service:GetState(p).pending,'death cancels pending and held input stays consumed')

local seen={}
for _,entry in ipairs(executions)do
 local id=tostring(entry.player.InitSeed)..':'..entry.command.serial
 ok(not seen[id],'completion serial is unique per player across owners, rooms and resets');seen[id]=true
end
dispatch('MC_PRE_MOD_UNLOAD',{})
ok(service:IsRestricted(p),'other mod unload does not detach service')
service:UnregisterOwner('wave');service:UnregisterOwner('double');service:UnregisterOwner('reverse')
service:UnregisterOwner('failed')
ok(not service:IsRestricted(p) and not service:IsRestricted(q),'unregister last binding restores all users')
service:Shutdown();ok(dispatch('MC_INPUT_ACTION',p,2,4)==nil,'shutdown callbacks inert')
service:RegisterOwner('shutdown_owner',bind(105,'wave_tap'))
people=nil
ok(pcall(function()service:UnregisterOwner('shutdown_owner')end),'unregister during native shutdown must never enumerate destroyed Game players')
print('motion_input_behavior: '..n..' assertions passed')
