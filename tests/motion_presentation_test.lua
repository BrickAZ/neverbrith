local n=0;local function ok(v,m)assert(v,m);n=n+1 end
local V={};V.__index=V
function Vector(x,y)return setmetatable({X=x,Y=y},V)end
function V.__add(a,b)return Vector(a.X+b.X,a.Y+b.Y)end
function V.__sub(a,b)return Vector(a.X-b.X,a.Y-b.Y)end
function V.__mul(a,b)if type(a)=='number'then a,b=b,a end;return Vector(a.X*b,a.Y*b)end
function V:Rotated(a)local r=math.rad(a);return Vector(self.X*math.cos(r)-self.Y*math.sin(r),self.X*math.sin(r)+self.Y*math.cos(r))end
function Color(...)return {...}end
RenderMode={RENDER_NULL=0,RENDER_NORMAL=1,RENDER_SKIP=2,RENDER_WATER_ABOVE=3,RENDER_WATER_REFRACT=4,RENDER_WATER_REFLECT=5};local mode=RenderMode.RENDER_NORMAL
ModCallbacks={};for i,name in ipairs({'MC_POST_UPDATE','MC_POST_RENDER','MC_PRE_PLAYER_RENDER','MC_PRE_NPC_RENDER',
 'MC_PRE_PLAYER_UPDATE','MC_INPUT_ACTION','MC_ENTITY_TAKE_DMG','MC_PRE_USE_ITEM','MC_POST_NEW_ROOM','MC_POST_NEW_LEVEL',
 'MC_POST_GAME_STARTED','MC_PRE_GAME_EXIT','MC_PRE_MOD_UNLOAD','MC_POST_GLOWING_HOURGLASS_LOAD','MC_POST_ENTITY_REMOVE',
 'MC_POST_TEAR_INIT','MC_PRE_TEAR_UPDATE','MC_POST_LASER_INIT','MC_PRE_LASER_UPDATE','MC_POST_KNIFE_INIT','MC_PRE_KNIFE_UPDATE',
 'MC_POST_BOMB_INIT','MC_PRE_BOMB_UPDATE','MC_POST_PROJECTILE_INIT','MC_PRE_PROJECTILE_UPDATE','MC_POST_EFFECT_INIT','MC_EXECUTE_CMD','MC_POST_ADD_COLLECTIBLE','MC_POST_PLAYER_RENDER'})do ModCallbacks[name]=i end
ButtonAction={ACTION_LEFT=0,ACTION_RIGHT=1,ACTION_UP=2,ACTION_DOWN=3,ACTION_SHOOTLEFT=4,ACTION_SHOOTRIGHT=5,
 ACTION_SHOOTUP=6,ACTION_SHOOTDOWN=7,ACTION_BOMB=8,ACTION_ITEM=9,ACTION_PILLCARD=10}
InputHook={IS_ACTION_PRESSED=0,IS_ACTION_TRIGGERED=1,GET_ACTION_VALUE=2};PillCardSlot={PRIMARY=0};PocketItemType={ACTIVE_ITEM=2}
local calls,loads,audio,stopped={},{},{},{};local frame,paused=0,false;local callbacks={};local mod={}
local loadFailure,renderFailure
function mod:AddPriorityCallback(id,priority,fn)
 callbacks[id]=callbacks[id]or{};callbacks[id][#callbacks[id]+1]={fn=fn,priority=priority}
 table.sort(callbacks[id],function(a,b)return a.priority<b.priority end)
end
function mod:AddCallback(id,fn)self:AddPriorityCallback(id,0,fn)end
local function dispatch(name,...)
 local previous=mode
 if name=='MC_POST_RENDER' and (mode==RenderMode.RENDER_NORMAL or mode==RenderMode.RENDER_WATER_ABOVE)then mode=RenderMode.RENDER_NULL end
 for _,r in ipairs(callbacks[ModCallbacks[name]]or{})do local v=r.fn(mod,...);if v~=nil then mode=previous;return v end end
 mode=previous
end
local function layer(id)return {GetLayerID=function()return id end,GetSpritesheetPath=function()return 'current_skin.png'end}end
function Sprite()
 local s={Scale=Vector(1,1),Color=Color(1,1,1,1),Rotation=0,FlipX=false,FlipY=false}
 function s:Load(path)if path==loadFailure then error('load failed')end;self.path=path;loads[#loads+1]=path end
 function s:GetFilename()return self.path end
 function s:GetAllLayers()return {layer(1),layer(4)}end
 function s:ReplaceSpritesheet(id,path)self[id]=path end
 function s:LoadGraphics()end
 function s:GetAnimationData(name)
  if self.path=='body_costume.anm2' and name:sub(1,4)~='Walk' then return nil end
  return {GetName=function()return name end,GetLayer=function(_,id)return {GetFrame=function()
   return {GetPos=function()return Vector(0,id==1 and 2 or id==4 and -5 or 0)end}
  end}end}
 end
 function s:SetFrame(anim,t)self.anim=anim;self.tick=t end
 function s:GetAnimation()return self.anim or 'WalkRight'end
 function s:GetFrame()return self.tick or 0 end
 function s:GetOverlayAnimation()return self.overlay or ''end
 function s:GetOverlayFrame()return 0 end
 function s:SetOverlayFrame(name)self.overlay=name end
 function s:RemoveOverlay()self.overlay=nil end
 function s:RenderLayer(id,pos)
  assert(id<64,'native Sprite supports only layer IDs 0 through 63')
  if renderFailure then error('render failed')end
  local nativeOffset=Vector(0,(id==1 and 2 or id==4 and -5 or 0)*self.Scale.Y):Rotated(self.Rotation)
  calls[#calls+1]={path=self.path,id=id,pos=pos,effectivePos=pos+nativeOffset,scale=self.Scale,rotation=self.Rotation,anim=self.anim,tick=self.tick,color=self.Color,skin=self[1],overlay=self.overlay}
 end
 function s:Render(pos)self:RenderLayer(-1,pos)end
 return s
end
local sfx={};function sfx:Play(id,gain,delay,loop,pitch)audio[#audio+1]={id=id,gain=gain,loop=loop,pitch=pitch}end
function sfx:Stop(id)stopped[#stopped+1]=id end;SFXManager=function()return sfx end
local function player(id)
 local sprite=Sprite();sprite:Load('player.anm2')
 local p={Type=1,InitSeed=id,ControllerIndex=id,Position=Vector(40+id,60),PositionOffset=Vector(11,17),SpriteOffset=Vector(7,13),
 Visible=true,Color=Color(.8,.9,1,1),SpriteScale=Vector(1,1),Velocity=Vector(2,3),items={},slots={[0]=0},data={}}
 function p:GetSprite()return sprite end;function p:Exists()return not self.removed end
 function p:Render(offset)
  assert(getmetatable(offset)==V,'native player Render requires a Vector')
  local delta=dispatch('MC_PRE_PLAYER_RENDER',self,offset);if delta==false then return end
  local root=Isaac.WorldToScreen(self.Position)+self.SpriteOffset+offset+(delta or Vector(0,0))
  calls[#calls+1]={path='native-player-render',id=0,pos=root,scale=self.SpriteScale,rotation=self.SpriteRotation,nativeOwner=self,
   anim=sprite:GetAnimation(),tick=sprite:GetFrame()}
  dispatch('MC_POST_PLAYER_RENDER',self)
 end
 function p:ToPlayer()return self end;function p:IsDead()return self.dead or false end
 function p:GetData()return self.data end;function p:HasCollectible(id)return self.items[id]==true end
 function p:GetActiveItem(slot)return self.slots[slot]or 0 end;function p:GetPocketItem()return nil end
 function p:GetHeadDirection()return 2 end;function p:GetCostumeLayerMap()return {}end;function p:GetCostumeSpriteDescs()return {}end
 return p
end
local p,q=player(1),player(2);local people={p,q};local buttons={}
local room={GetRenderMode=function()return mode end}
local game={GetFrameCount=function()return frame end,IsPaused=function()return paused end,GetRoom=function()return room end,GetNumPlayers=function()return #people end}
Game=function()return game end
Isaac={GetPlayer=function(i)return people[i+1]end,GetScreenWidth=function()return 640 end,GetScreenHeight=function()return 416 end,
 WorldToScreen=function(v)return Vector(v.X*1.5+91,v.Y*.7+23)end,GetSoundIdByName=function(name)return #name+100 end,DebugString=function()end}
Input={GetActionValue=function(action,controller)
 local who=people[controller];local value=dispatch('MC_INPUT_ACTION',who,2,action)
 if value~=nil then return value end;return buttons[controller]and buttons[controller][action]or 0
end}
include=function(name)return dofile(name..'.lua')end
local context={GetPlayers=function()return people end,Key=function(who)return tostring(who.InitSeed)end}
local input=include('motion_input')(mod,context)
local runtime=include('motion_presentation')(mod,context)
ok(mod.MotionPresentation==runtime,'bootstrap exposes presentation service')
local originalColor=p.Color;local originalScale=p.SpriteScale;local originalVelocity=p.Velocity
p:GetSprite():SetOverlayFrame('HeadDown',0)
ok(runtime:Play(p,'wave',{rehearsal=true,facing='right'}).ok,'wave starts from approved asset')
ok(dispatch('MC_PRE_PLAYER_RENDER',p,Vector(99,99))==false,'owned player render suppressed with exact false return')
ok(dispatch('MC_PRE_PLAYER_RENDER',q,Vector(0,0))==nil,'other player render untouched')
calls={};dispatch('MC_POST_RENDER')
local body
for _,c in ipairs(calls)do if c.path=='player.anm2'and c.id==1 then body=c;break end end
ok(body and math.abs(body.effectivePos.X-(p.Position.X*1.5+91))<.01,'one non-identity WorldToScreen conversion anchors body')
ok(math.abs(body.effectivePos.Y-(p.Position.Y*.7+23))<.01,'native layer position is applied exactly once at the approved wave body pivot')
local head;for _,c in ipairs(calls)do if c.path=='player.anm2'and c.id==4 then head=c;break end end
ok(head and math.abs(head.effectivePos.Y-body.effectivePos.Y+7)<.01,'native head/body spacing matches the authored pose, not twice its native offset')
ok(not body.overlay and not head.overlay and p:GetSprite():GetOverlayAnimation()=='HeadDown','private split sprites remove duplicate native overlays without changing the live player')
ok(body.skin=='current_skin.png','current skin copied onto private sprite')
ok(runtime:GetState(p).renderedFrame==0,'diagnostic frame is recorded only after the real draw path succeeds')
local before=#loads;dispatch('MC_POST_RENDER');dispatch('MC_POST_RENDER');ok(#loads==before,'render never reloads resources')
ok(p.Visible and p.Color==originalColor and p.SpriteScale==originalScale and p.Velocity==originalVelocity,'render changes no native actor properties')
mode=RenderMode.RENDER_WATER_REFLECT;local count=#calls;dispatch('MC_POST_RENDER');ok(#calls==count and dispatch('MC_PRE_PLAYER_RENDER',p)==nil,'reflection pass is neither drawn nor hidden');mode=RenderMode.RENDER_NORMAL
p.Visible=false;count=#calls;dispatch('MC_POST_RENDER')
ok(#calls==count and dispatch('MC_PRE_PLAYER_RENDER',p)==nil,'another system hidden player is never made visible by presentation');p.Visible=true
local convert=Isaac.WorldToScreen;Isaac.WorldToScreen=function()error('no transform')end
count=#calls;dispatch('MC_POST_RENDER');ok(#calls==count and dispatch('MC_PRE_PLAYER_RENDER',p)==nil,'failed conversion preserves live player and skips owned draw');Isaac.WorldToScreen=convert
local function update()frame=frame+1;dispatch('MC_POST_UPDATE')end
update();local at=runtime:GetState(p).frame
paused=true;update();update();ok(runtime:GetState(p).frame==at,'pause freezes presentation clock');paused=false
runtime:Play(p,'dp',{variant='od',rehearsal=true,facing='up'});calls={};dispatch('MC_POST_RENDER')
ok(runtime:GetState(p).variant=='od','OD selected explicitly')
for _,c in ipairs(calls)do if c.path=='player.anm2'and c.id==4 then ok(c.anim=='HeadUp' and c.rotation==0,'upward attack keeps upright native head')end end
ok(not runtime:Play(p,'circle_720',{variant='od',rehearsal=true}).ok,'720 has no OD variant')
ok(runtime:GetState(p).key=='dp','invalid request preserves current performance')
ok(not runtime:Play(p,'circle_360',{}).ok,'real grapples require caller-owned target rather than inventing selection')
local enemySprite=Sprite();enemySprite:Load('live_enemy.anm2')
local enemy={Size=17,Position=Vector(80,60),Exists=function()return true end,IsDead=function()return false end,GetSprite=function()return enemySprite end}
ok(runtime:Play(p,'circle_360',{target=enemy}).ok,'gameplay presentation accepts an explicit live enemy reference')
local drewLiveEnemy=false
for _=1,12 do
 calls={};dispatch('MC_POST_RENDER')
 for _,c in ipairs(calls)do if c.path=='live_enemy.anm2' then drewLiveEnemy=true end end
 update()
end
ok(drewLiveEnemy,'victim rendering uses the supplied enemy sprite, never a fixed demo enemy')
runtime:Play(p,'circle_720',{rehearsal=true});local loaded=#loads
for _=1,22 do update()end
ok(runtime:GetState(p).cinema,'720 enters confirmed closeup at source frame21')
calls={};dispatch('MC_POST_RENDER');ok(#calls>0,'720 cinematic draws in game render callback')
ok(#loads==loaded,'cuts use cached sprites')
runtime:Play(q,'circle_360',{rehearsal=true});ok(runtime:GetState(p) and runtime:GetState(q),'two player states coexist')
dispatch('MC_POST_NEW_ROOM');ok(not runtime:GetState(p)and not runtime:GetState(q),'room transition clears all performances')
ok(dispatch('MC_PRE_PLAYER_RENDER',p)==nil,'cleanup releases player render immediately')
local success=true
input:RegisterOwner('wave',{collectibleId=101,profile='wave_tap',has=function(who)return who:HasCollectible(101)end,
 execute=function()return {ok=success}end})
p.items[101]=true;p.slots[0]=101
local function sample(values)buttons[1]=values;frame=frame+1;dispatch('MC_PRE_PLAYER_UPDATE',p)end
sample({});sample({[9]=1});sample({[9]=1,[5]=1})
ok(runtime:GetState(p)and runtime:GetState(p).key=='wave','real successful input automatically starts performance')
local started=runtime:GetState(p).started;sample({[9]=1,[5]=1});ok(runtime:GetState(p).started==started,'held arrow cannot restart performance')
runtime:Stop(p);success=false;sample({[9]=1});sample({[9]=1,[5]=1})
ok(not runtime:GetState(p),'failed execution never plays success performance')
p.items[101]=nil;ok(runtime:Arm(p,'circle_360','od').ok,'rehearsal arms without collectible registration')
ok(input:IsRestricted(p)and not input:IsRestricted(q),'rehearsal attack restriction belongs only to armed player')
ok(dispatch('MC_PRE_USE_ITEM',999,nil,p)==true,'rehearsal cannot use native active or consume its charge')
sample({});sample({[9]=1});sample({[9]=1,[5]=1});sample({[9]=1,[7]=1});sample({[9]=1,[4]=1});sample({[9]=1,[6]=1})
ok(runtime:GetState(p)and runtime:GetState(p).key=='circle_360'and runtime:GetState(p).variant=='od','shared wide 360 parser drives selected OD rehearsal')
p.dead=true;update();ok(not runtime:GetState(p)and not input:IsRestricted(p),'death releases playback and rehearsal restriction');p.dead=false
runtime:Play(p,'wave',{rehearsal=true});for _=1,66 do update()end
ok(not runtime:GetState(p),'66-frame wave ends at its confirmed duration')
runtime:Play(p,'circle_720',{rehearsal=true});for _=1,5 do update()end
ok(#audio>0,'registered Japanese audio dispatched on authored frame')
for _,a in ipairs(audio)do ok(a.pitch==1 and not a.loop,'native voice pitch and one-shot playback preserved')end
dispatch('MC_POST_GLOWING_HOURGLASS_LOAD');ok(not runtime:GetState(p),'hourglass load clears transient performance')
runtime:Play(p,'wave',{rehearsal=true})
loadFailure='gfx/Effects/MotionShowcase/v7/dp_runtime.anm2'
ok(not runtime:Play(p,'dp',{rehearsal=true}).ok and runtime:GetState(p).key=='wave','load failure preserves an existing valid performance')
loadFailure=nil;renderFailure=true;dispatch('MC_POST_RENDER');renderFailure=false
ok(not runtime:GetState(p)and dispatch('MC_PRE_PLAYER_RENDER',p)==nil,'render exception cancels safely and restores native rendering')
local costumeHead,costumeBody=Sprite(),Sprite();costumeHead:Load('head_costume.anm2');costumeBody:Load('body_costume.anm2')
function p:GetCostumeSpriteDescs()return {{GetSprite=function()return costumeHead end},{GetSprite=function()return costumeBody end}}end
function p:GetCostumeLayerMap()return {{costumeIndex=0,layerID=0},{costumeIndex=1,layerID=0}}end
runtime:Play(p,'wave',{facing='left',rehearsal=true});calls={};dispatch('MC_POST_RENDER')
local headCostume,bodyCostume
for _,c in ipairs(calls)do
 if c.path=='head_costume.anm2' then headCostume=c end
 if c.path=='body_costume.anm2' then bodyCostume=c end
end
ok(headCostume and headCostume.anim=='HeadLeft','current head costume follows the native facing')
ok(bodyCostume and bodyCostume.anim=='WalkLeft','body costume remains attached to body, not head')
function p:GetCostumeSpriteDescs()return {}end;function p:GetCostumeLayerMap()return {}end
ok(not runtime:Play(nil,'wave',{}).ok,'missing owner fails before accessing its facing')
local source=include('generated/motion_presentation');local checkedFrames=0
for _,move in ipairs({'wave','dp','circle_360','circle_720'})do
 for _,variant in ipairs({'normal','od'})do if source[move].variants[variant]then
  for _,face in ipairs({'right','down','left','up'})do
   ok(runtime:Play(p,move,{variant=variant,facing=face,rehearsal=true}).ok,'approved variant starts in each direction')
   for t=0,source[move].frames-1 do
    calls={};dispatch('MC_POST_RENDER');local state=runtime:GetState(p)
    ok(state and state.frame==t,'every authored frame survives playback')
    for _,c in ipairs(calls)do
     assert(c.pos.X==c.pos.X and c.pos.Y==c.pos.Y and math.abs(c.pos.X)<100000 and math.abs(c.pos.Y)<100000,'finite coordinates')
     assert(type(c.rotation)=='number' and c.scale.X>0 and c.scale.Y>0,'valid engine scale and rotation')
     if c.path=='player.anm2'and(c.id==1 or c.id==4)and c.color==originalColor then
      local which=c.id==1 and 'body'or 'head';local f=source[move][variant..'_frames'][t+1];local pose=f[which];local cam=f.camera
      local expected
      if f.cinema then expected=Vector(320,248)+Vector(pose[1],pose[2])*2
      else local origin=source[move].start_feet;local dir=Vector(1,0):Rotated(({right=0,down=90,left=180,up=270})[face])
       expected=Isaac.WorldToScreen(p.Position)+dir*(pose[1]/cam[3]+cam[1]-origin[1])+Vector(0,pose[2]/cam[3]+cam[2]-origin[2])
      end
      assert(math.abs(c.effectivePos.X-expected.X)<.001 and math.abs(c.effectivePos.Y-expected.Y)<.001,'every native part reaches its authored anchor after actual layer displacement')
      assert(not c.overlay,'no duplicate native overlay on any variant/frame/direction')
     end
    end
    update();checkedFrames=checkedFrames+1
   end
   ok(not runtime:GetState(p),'every variant cleans up at its own endpoint')
  end
 end end
end
ok(checkedFrames==3328,'all 832 approved frames exercised in all four directions')
ok(p.Visible and p.Color==originalColor and p.SpriteScale==originalScale and p.Velocity==originalVelocity,'exhaustive playback preserves native gameplay properties')

ok(runtime:Play(p,'wave',{combat=true,facing='right'}).ok,'combat actor playback accepts external clock')
local startFrame=runtime:GetState(p).frame;update();update()
ok(runtime:GetState(p).frame==startFrame,'combat animation never advances on preview clock')
runtime:SetCombatFrame(p,20,false);calls={};dispatch('MC_POST_RENDER')
local bakedWave=false
for _,c in ipairs(calls)do if c.path:find('wave_runtime',1,true)and c.id==source.wave.native_layer_map['32']then bakedWave=true end end
ok(not bakedWave,'actor playback omits the demonstration wave trajectory')
runtime:Play(p,'dp',{combat=true,facing='right'});runtime:SetCombatFrame(p,77,false);calls={};dispatch('MC_POST_RENDER')
local anchoredBody
for _,c in ipairs(calls)do if c.path=='player.anm2'and c.id==1 then anchoredBody=c end end
ok(not anchoredBody and dispatch('MC_PRE_PLAYER_RENDER',p)~=false,'formal combat draws FX and never replaces or cancels the native player')
for _,move in ipairs({'wave','dp','circle_360','circle_720'})do
 p:GetSprite():SetFrame('Hit',3)
 local oldLoads=#loads
 runtime:Play(p,move,{combat=true,facing='left',target=move=='circle_720'and enemy or nil})
 for i=oldLoads+1,#loads do ok(loads[i]~='player.anm2','formal play never clones a player sprite')end
 runtime:SetCombatFrame(p,math.min(50,source[move].frames-1),false);calls={};dispatch('MC_POST_RENDER')
 for _,call in ipairs(calls)do ok(call.path~='player.anm2','formal render contains no copied player head/body')end
 ok(dispatch('MC_PRE_PLAYER_RENDER',p)~=false and p:GetSprite():GetAnimation()=='Hit'and p:GetSprite():GetFrame()==3,'native hurt animation survives '..move)
 ok(runtime:GetState(p).cinema==(move=='circle_720'),'only formal V9 uses native actor cinema')
 if move=='circle_720'then
  local seen=false;for _,call in ipairs(calls)do if call.path=='native-player-render'then
   seen=call.nativeOwner==p and math.abs(call.scale.Y)>2 and call.pos.X>0 and call.pos.X<640
  end end
  ok(seen and runtime:GetState(p).cinematicActorFrame==50,'closeup actually draws the live native actor enlarged on screen')
 end
 dispatch('MC_POST_PLAYER_RENDER',p)
end
-- The engine keeps its real player frames, but the approved jump/spin must
-- still reach that native actor as a reversible whole-sprite render pose.
for _,move in ipairs({'dp','circle_360','circle_720'})do
 local frames=source[move].normal_frames;local peak=1
 for i,f in ipairs(frames)do if f.feet[2]<frames[peak].feet[2]then peak=i end end
 local oldOffset=Vector(p.SpriteOffset.X,p.SpriteOffset.Y);local oldScale=Vector(p.SpriteScale.X,p.SpriteScale.Y);p.SpriteRotation=11
 runtime:Play(p,move,{combat=true,facing='right',target=move=='circle_720'and enemy or nil})
 runtime:SetCombatFrame(p,peak-1,false)
 local animation,tick=p:GetSprite():GetAnimation(),p:GetSprite():GetFrame()
 for _=1,3 do
  local delta=dispatch('MC_PRE_PLAYER_RENDER',p,Vector(13,27))
  ok(delta~=false,'whole native render pose never cancels the player')
  local lift=frames[peak].feet[2]-source[move].start_feet[2]
  ok(lift<0 and getmetatable(delta)==V and math.abs(delta.Y-lift)<.001 and p.SpriteOffset.Y==oldOffset.Y,'jump uses the native additive render-offset API, without duplicate SpriteOffset displacement for '..move)
  ok((Vector(13,27)+delta).Y==27+lift,'existing callback offset is applied exactly once')
  ok(p:GetSprite():GetAnimation()==animation and p:GetSprite():GetFrame()==tick,'native frame continues under whole-body pose')
  dispatch('MC_POST_PLAYER_RENDER',p)
  ok(p.SpriteOffset.Y==oldOffset.Y and p.SpriteScale.X==oldScale.X and p.SpriteRotation==11,'render pose restores native fields without compounding')
 end
 dispatch('MC_PRE_PLAYER_RENDER',p);runtime:Stop(p)
 ok(p.SpriteOffset.Y==oldOffset.Y and p.SpriteRotation==11,'cancellation restores a pending native pose')
end
runtime:Play(p,'circle_360',{combat=true,facing='right'})
local narrow,turned=false,false
for tick=0,source.circle_360.frames-1 do
 runtime:SetCombatFrame(p,tick,false);dispatch('MC_PRE_PLAYER_RENDER',p)
 narrow=narrow or math.abs(p.SpriteScale.X)<.99;turned=turned or p.SpriteScale.X<0
 dispatch('MC_POST_PLAYER_RENDER',p)
end
ok(narrow and turned,'native horizontal spin narrows edge-on and turns as a whole instead of merely toggling a symmetric image')
runtime:Stop(p)
local ptrBefore=GetPtrHash;local npcWrapper={}
GetPtrHash=function(who)return (who==npcWrapper or who==enemy)and 12345 or tostring(who)end
runtime:Play(p,'circle_360',{combat=true,facing='right'})
ok(runtime:SetTarget(p,enemy),'confirmed grab attaches actual target sprite')
ok(dispatch('MC_PRE_NPC_RENDER',npcWrapper)==false,'distinct native userdata wrappers for one NPC are hidden by pointer identity')
runtime:SetCombatFrame(p,73,true);runtime:FinishTarget(p,true);update()
ok(runtime:GetState(p)~=nil,'own lethal hit can retain captured target art without a live NPC')
ok(dispatch('MC_PRE_NPC_RENDER',npcWrapper)==false,'settled target stays hidden while its captured art is still drawn')
runtime:FinishTarget(p,false);ok(dispatch('MC_PRE_NPC_RENDER',npcWrapper)==nil,'release restores real target rendering');runtime:Stop(p)
GetPtrHash=ptrBefore

-- Actual item owners use the same input and rendering modules, without Arm or
-- XML-local IDs. Combat is isolated by a fake executor here; actual collision,
-- HP, grabs, OD and meter are exercised in motion_combat_test and native tests.
local executions,acquired=0,{}
mod.MotionCombat={OnAcquire=function(_,who,move)acquired[#acquired+1]={who,move};return true end,
 IsBusy=function(_,who)return runtime:GetState(who)~=nil end,Execute=function(_,who,move,command,owner)
 executions=executions+1
 return runtime:Play(who,move,{variant='normal',facing=command.facing,presentationOnly=true,sourceOwner=owner.owner})
end}
local itemContext={Items={Piledriver360=901,Ultimate720=902,MotionWave=903,DragonPunch=904},Key=context.Key}
local items=include('motion_items')(mod,itemContext)
ok(#items.registered==4,'four formal owners registered')
p.items[902]=true;dispatch('MC_POST_ADD_COLLECTIBLE',902,0,false,0,0,p)
ok(#acquired==1 and acquired[1][1]==p and acquired[1][2]=='circle_720','native 720 inventory addition delegates the full-meter grant to combat')
dispatch('MC_POST_ADD_COLLECTIBLE',903,0,true,0,0,p)
ok(#acquired==1,'unrelated acquisitions do not fill SA');p.items[902]=nil
ok(not input:IsRestricted(q),'registration never grants an item')
local function beginFormal(id)
 dispatch('MC_POST_NEW_ROOM');p.items={[id]=true};p.slots[0]=id
 sample({});sample({[9]=1})
 ok(input:IsRestricted(p),'holding a formal item restricts native weapons without Arm')
 ok(dispatch('MC_PRE_USE_ITEM',id,nil,p)==true,'formal active use cancels native charge settlement')
end
local function formalKeys(move,shoot)
 local values={[9]=1}
 for _,action in ipairs(move or {})do values[action+4]=1 end
 if shoot then values[shoot]=1 end
 sample(values)
end
local function verifyFormal(move)
 local state=runtime:GetState(p)
 ok(state and state.key==move and state.variant=='normal','formal motion starts approved normal art')
 ok(state.presentationOnly and not state.rehearsal,'formal performance is presentation-only, not console rehearsal')
 ok(state.sourceOwner=='motion_item:'..move,'playback belongs to its item')
 local started=state.started
 formalKeys({},5)
 ok(runtime:GetState(p).started==started,'held input cannot duplicate or restart formal performance')
 return state
end
beginFormal(903);formalKeys({},5);verifyFormal('wave')
ok(runtime:GetState(p).version=='v7','wave retains approved source')
beginFormal(904)
sample({[9]=1,[1]=1});sample({[9]=1,[3]=1});sample({[9]=1,[1]=1})
ok(not runtime:GetState(p),'WASD cannot complete any direction-based item motion')
ok(dispatch('MC_INPUT_ACTION',p,2,1)==nil,'movement input is left to the real game')
beginFormal(904);formalKeys({1});formalKeys({3});formalKeys({1,3})
ok(verifyFormal('dp').facing=='right','arrow motion never rotates the front reference while the active key is held')
beginFormal(901);formalKeys({1});formalKeys({3});formalKeys({0});formalKeys({2});verifyFormal('circle_360')
calls={};dispatch('MC_POST_RENDER')
local targetDrawn=false
for _,call in ipairs(calls)do
 if call.path:find('circle_360.anm2',1,true)then
  for _,layer in ipairs(source.circle_360.layers)do
   if layer[1]==call.id and layer[2]:find('target_',1,true)==1 then targetDrawn=true end
  end
 end
end
ok(not targetDrawn,'formal graphics never draw a baked demonstration opponent')
beginFormal(902)
for _,action in ipairs({1,3,0,2})do formalKeys({action})end
ok(not runtime:GetState(p),'720 first circle does not release 360')
for _,action in ipairs({1,3,0,2})do formalKeys({action})end
ok(verifyFormal('circle_720').version=='v9','formal 720 uses V9')
for _=1,22 do update()end
ok(runtime:GetState(p).cinema,'formal 720 enters its closeup and camera cuts')
q.items[903]=true;q.slots[0]=903
buttons[2]={};frame=frame+1;dispatch('MC_PRE_PLAYER_UPDATE',q)
buttons[2]={[9]=1};frame=frame+1;dispatch('MC_PRE_PLAYER_UPDATE',q)
buttons[2]={[9]=1,[5]=1};frame=frame+1;dispatch('MC_PRE_PLAYER_UPDATE',q)
ok(runtime:GetState(q)and runtime:GetState(q).sourceOwner=='motion_item:wave','second player owns an independent formal playback')
p.items={};update()
ok(not runtime:GetState(p)and runtime:GetState(q),'losing item stops only its owner performance')
ok(not input:IsRestricted(p)and input:IsRestricted(q),'last item removal lifts only that player restriction')
beginFormal(903);p.slots[0]=999;p.slots[1]=903;formalKeys({},5)
ok(input:IsRestricted(p)and not runtime:GetState(p),'unselected Schoolbag item restricts but cannot execute')
p.slots[2]=903
function p:GetPocketItem()return {GetType=function()return PocketItemType.ACTIVE_ITEM end,GetSlot=function()return 3 end}end
sample({});sample({[10]=1});sample({[10]=1,[5]=1})
ok(runtime:GetState(p)and runtime:GetState(p).sourceOwner=='motion_item:wave','selected pocket active drives its formal owner')
function p:GetPocketItem()return nil end;p.slots[1]=0;p.slots[2]=0
beginFormal(904);loadFailure='gfx/Effects/MotionShowcase/v7/dp_runtime.anm2'
formalKeys({1});formalKeys({3});formalKeys({1,3});formalKeys({1,3})
ok(not runtime:GetState(p)and input:GetState(p).lastEvent.reason=='resource','formal resource failure is reported without replaying')
loadFailure=nil;formalKeys({1,3})
ok(not runtime:GetState(p),'failed command is not retried when a resource becomes available')
beginFormal(903);formalKeys({},5)
runtime:Play(p,'dp',{rehearsal=true});p.items={};update()
ok(runtime:GetState(p)and runtime:GetState(p).key=='dp','item loss cannot cancel a later unrelated preview')
beginFormal(903);formalKeys({},5);p.dead=true;update();p.dead=false
ok(not runtime:GetState(p),'death cancels formal performance')
local replacement=include('motion_items')(mod,itemContext)
ok(not items.active and #replacement.registered==4,'reload replaces owners without duplicate bindings')
replacement:Shutdown()
ok(executions>5,'formal input delegates completed commands to combat executor')
ok(not input.bindings['motion_item:wave'] and not input:IsRestricted(q),'formal shutdown removes only its owners and restrictions')
local skipped=include('motion_items')(mod,{Items={MotionWave=-1,DragonPunch=0}})
ok(#skipped.registered==0,'missing runtime names never fall back to XML local IDs')
skipped:Shutdown()
mode=RenderMode.RENDER_NORMAL;p.Visible=true
for _,case in ipairs({{'normal',30,1,'right'},{'normal',30,1,'left'},{'od',23,1,'right'},{'od',45,2,'left'}})do
 runtime:Play(p,'dp',{combat=true,variant=case[1],facing=case[4]});runtime:SetCombatFrame(p,case[2],false)
 dispatch('MC_POST_RENDER');local state=runtime:GetState(p);local fist=state.fist
 ok(fist and fist.stage==case[3]and fist.alpha<1,'white fist is translucent and follows the correct uppercut stage')
 local origin=Isaac.WorldToScreen(p.Position)+p.SpriteOffset
 ok((fist.position.X-origin.X)*(case[4]=='left'and -1 or 1)>0,'white fist follows horizontal attack side')
 runtime:SetCombatFrame(p,77,false);dispatch('MC_POST_RENDER');ok(not runtime:GetState(p).fist,'fist vanishes after the rise')
 runtime:Stop(p)
end
runtime:Play(p,'circle_720',{combat=true,target=enemy});runtime:SetCombatFrame(p,289,false)
runtime:StartRecoveryTail(p)
ok(runtime:GetState(p).recoveryTail and runtime:GetState(p).freeActor,'720 recovery tail is a separate cosmetic phase')
ok(dispatch('MC_PRE_PLAYER_RENDER',p)==nil and dispatch('MC_PRE_NPC_RENDER',enemy)==nil,'tail owns neither native player pose nor released opponent render')
for _=1,105 do update()end
ok(not runtime:GetState(p),'detached V9 tail still reaches the original end and cleans up')
runtime:Play(p,'circle_720',{combat=true,target=enemy});runtime:SetCombatFrame(p,289,false);runtime:StartRecoveryTail(p)
runtime:Play(p,'dp',{combat=true});ok(runtime:GetState(p).key=='dp'and not runtime:GetState(p).recoveryTail,'new action can replace a cosmetic tail')
runtime:Stop(p)
runtime:Play(p,'circle_720',{combat=true,target=enemy});runtime:SetCombatFrame(p,289,false);runtime:StartRecoveryTail(p)
paused=true;update();update();ok(runtime:GetState(p).frame==289,'pause freezes the detached tail without reacquiring player control');paused=false
update();ok(runtime:GetState(p).frame==290,'detached tail resumes on the next update')
runtime:Stop(p)
p.items[902]=true
runtime:Play(p,'circle_720',{combat=true,target=enemy});runtime:SetCombatFrame(p,289,false);runtime:StartRecoveryTail(p,902)
p.items[902]=nil;update();ok(not runtime:GetState(p),'losing 720 clears its detached tail')
runtime:Play(p,'circle_720',{combat=true,target=enemy});runtime:SetCombatFrame(p,289,false);runtime:StartRecoveryTail(p)
p.dead=true;update();p.dead=false;ok(not runtime:GetState(p),'death clears the detached tail')
for _,event in ipairs({'MC_POST_NEW_ROOM','MC_POST_NEW_LEVEL','MC_POST_GAME_STARTED','MC_PRE_GAME_EXIT','MC_POST_GLOWING_HOURGLASS_LOAD'})do
 runtime:Play(p,'circle_720',{combat=true,target=enemy});runtime:SetCombatFrame(p,289,false);runtime:StartRecoveryTail(p)
 dispatch(event);ok(not runtime:GetState(p),'detached tail is cleared on '..event)
end
runtime:Play(p,'dp',{rehearsal=true});dispatch('MC_PRE_MOD_UNLOAD',{})
ok(runtime:GetState(p),'other mod unload does not cancel our performance')
dispatch('MC_PRE_MOD_UNLOAD',mod);ok(not runtime:GetState(p) and not runtime.active,'own unload detaches callbacks')
ok(input.presentationSink==nil,'unload detaches only owned presentation sink')
print('motion_presentation: '..n..' assertions passed')
