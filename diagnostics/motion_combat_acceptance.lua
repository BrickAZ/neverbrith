-- Temporary hidden-game acceptance. Never loaded by the normal mod bootstrap.
-- All input is injected at Lua boundaries; this sends no OS mouse/key events.
return function(mod,options)
 local game=Game();local phase='menu';local boot=0;local index,passed,failed=0,0,0
 local current,prepareAt;local values={};local shift=false;local npcs={}
 local cases={
  {move='wave',name='Wave',zh='波动',multiplier=1,offset=85,directions={5}},
  {move='dp',name='Dragon Punch',zh='升龙',multiplier=2,directions={5,7,{5,7}}},
  {move='dp',name='Dragon Punch',zh='升龙',od=true,multiplier=5,directions={5,7,{5,7}}},
  {move='circle_360',name='360',multiplier=3,directions={5,7,4,6}},
  {move='circle_360',name='360',od=true,rejectOD=true,directions={5,7,4,6}},
  {move='circle_360',name='360',od=true,multiplier=6,directions={5,7,4,6},waitOD=true},
  {move='circle_720',name='720',multiplier=15,directions={5,7,4,6,5,7,4,6}},
  {move='circle_360',name='360',boss=true,multiplier=3,directions={5,7,4,6}},
  {move='circle_360',name='360',empty=true,directions={5,7,4,6}},
  {move='circle_720',name='720',noMeter=true,directions={5,7,4,6,5,7,4,6}},
  {move='circle_720',name='720',lethal=true,multiplier=15,directions={5,7,4,6,5,7,4,6}},
  {move='circle_720',name='720',interrupt=true,directions={5,7,4,6,5,7,4,6}},
 }
 if options.Fixes then
  for _,case in ipairs({
   {move='circle_360',name='360',multiplier=3,directions={5,7,4,6},replaceTarget=true},
   {move='circle_360',name='360',multiplier=3,directions={5,7,4,6},replaceTarget=true,removeCandidate=true},
   {move='dp',name='Dragon Punch',zh='升龙',od=true,multiplier=5,directions={5,7,{5,7}},releaseShift=true,waitOD=true},
   {move='circle_360',name='360',od=true,multiplier=6,directions={5,7,4,6},releaseShift=true,waitOD=true},
  })do cases[#cases+1]=case end
 end
 if options.ExitDuringPlayback then cases={cases[7]}end
 if options.NativePlayer and not options.ExitDuringPlayback then
  for _,case in ipairs({
   {move='dp',name='Dragon Punch',zh='升龙',multiplier=2,offset=-30,directions={4,7,{4,7}},expectedFacing='left',nativeHappy=true},
   {move='dp',name='Dragon Punch',zh='升龙',multiplier=2,offset={0,-30},directions={6,4,{4,6}},expectedFacing='up'},
   {move='dp',name='Dragon Punch',zh='升龙',multiplier=2,offset={0,30},directions={7,5,{5,7}},expectedFacing='down'},
   {move='dp',name='Dragon Punch',zh='升龙',multiplier=2,directions={5,6,{5,6}},expectedFacing='right'},
   {move='circle_360',name='360',multiplier=3,offset=-30,directions={4,6,5,7},expectedFacing='left'},
   {move='circle_360',name='360',multiplier=3,offset={0,-30},directions={6,4,7,5},expectedFacing='up'},
   {move='dp',name='Dragon Punch',zh='升龙',od=true,multiplier=5,offset=-30,directions={4,7,{4,7}},expectedFacing='left',releaseShift=true,waitOD=true},
   {move='circle_720',name='720',invulnerable=true,directions={5,7,4,6,5,7,4,6}},
  })do cases[#cases+1]=case end
 end
 if options.Horizontal then
  for _,case in ipairs(cases)do
   if case.move=='dp'and(case.expectedFacing=='up'or case.expectedFacing=='down'or case.directions[1]==5 and case.directions[2]==6)then
    case.rejectMotion=true;case.expectedFacing=nil
   end
  end
  cases[#cases+1]={move='circle_360',name='360',multiplier=3,directions={5,7,4,6},naturalAI=true}
  cases[#cases+1]={move='circle_720',name='720',multiplier=15,directions={5,7,4,6,5,7,4,6},naturalAI=true}
 end
 if options.Additions then
  cases[#cases+1]={move='circle_720',name='720',multiplier=15,directions={{6,7}},shortcut=true}
  cases[#cases+1]={move='circle_720',name='720',multiplier=15,directions={{6,7}},shortcut=true,forceShift=true}
  cases[#cases+1]={move='circle_720',name='720',directions={{6,7}},shortcut=true,noMeter=true}
  cases[#cases+1]={move='circle_720',name='720',directions={{6,7}},shortcut=true,empty=true}
 end
 if options.ControlCinema then
  cases={cases[2],cases[3],cases[17],cases[23],cases[7],cases[27],cases[28],cases[12],
   {move='dp',name='Dragon Punch',zh='升龙',multiplier=0,offset=-80,directions={5,7,{5,7}},wall=true}}
  cases[2].invulnMatrix=true
  if options.Attempt:match('%-spin$')then cases={cases[5]}end
 end
 if options.Responsiveness then
  cases={cases[1],cases[2],cases[3],cases[4],cases[6],cases[7],cases[8]}
  for i=1,4 do cases[i].nativeHappy=nil;cases[i].crowd=i<=2 end
  cases[3].offset=-200;cases[3].multiplier=0;cases[4].offset=-200;cases[4].multiplier=0
  cases[6].replaceTail=true
 end
 if options.LandingSplash then
  cases={
   {move='circle_360',name='360',multiplier=3,directions={5,7,4,6},splashMatrix=true,expectedFacing='right'},
   {move='circle_360',name='360',od=true,multiplier=6,offset=-30,directions={4,7,5,6},splashMatrix=true,expectedFacing='left',waitOD=true},
   {move='circle_360',name='360',boss=true,multiplier=3,directions={5,7,4,6},splashMatrix=true},
   {move='circle_360',name='360',lethal=true,multiplier=3,directions={5,7,4,6},splashMatrix=true},
   {move='circle_720',name='720',multiplier=15,directions={5,7,4,6,5,7,4,6}},
   {move='circle_720',name='720',multiplier=15,directions={{6,7}},shortcut=true,forceShift=true},
   {move='circle_720',name='720',multiplier=15,directions={{6,7}},shortcut=true,lethal=true},
   {move='circle_720',name='720',directions={{6,7}},shortcut=true,interrupt=true},
  }
 end
 local function log(s)Isaac.DebugString('[Motion runtime probe] '..s)end
 if options.Attempt:find('trace',1,true)then
  cases={cases[1],cases[2],cases[3],cases[4],cases[5]}
  for _,name in ipairs({'MC_ENTITY_TAKE_DMG','MC_POST_ENTITY_TAKE_DMG'})do
   mod:AddPriorityCallback(ModCallbacks[name],99999999,function(_,e,amount,flags,source)
    if e.Type~=EntityType.ENTITY_PLAYER then log('TRACE '..name..' hp='..e.HitPoints..' damage='..amount..' entity='..GetPtrHash(e)..' collision='..e.EntityCollisionClass)end
   end)
  end
 end
 local function check(name,v,detail)
  if v then passed=passed+1 else failed=failed+1 end
  log((v and 'PASS 'or 'FAIL ')..index..':'..(current and current.move or '-')..' '..name..' '..tostring(detail or ''))
 end
 local nativeValue,nativeButton=Input.GetActionValue,Input.IsButtonPressed
 Input.GetActionValue=function(action,controller)if phase=='running'then return values[action]or 0 end;return nativeValue(action,controller)end
 Input.IsButtonPressed=function(button,controller)if phase=='running'and button==Keyboard.KEY_LEFT_SHIFT then return shift end;return nativeButton(button,controller)end
 mod:AddPriorityCallback(ModCallbacks.MC_INPUT_ACTION,-9999999,function(_,_,hook,action)
  if phase=='running'then
   if options.Responsiveness and action==ButtonAction.ACTION_ITEM then return end
   return hook==InputHook.GET_ACTION_VALUE and 0 or false
  end
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_INPUT_ACTION,9999999,function(_,_,hook,action)
  if options.Responsiveness and phase=='running'and current and action==ButtonAction.ACTION_ITEM then
   local value=values[action]or 0
   if hook==InputHook.GET_ACTION_VALUE then return value end
   if hook==InputHook.IS_ACTION_TRIGGERED then return value>0 and game:GetFrameCount()-current.start==5 end
   return value>0
  end
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_PRE_USE_ITEM,-40000,function(_,id,_,p)
  if options.Responsiveness and phase=='running'and current and id==current.id then current.nativeUseCalls=(current.nativeUseCalls or 0)+1 end
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,9999999,function(_,e,_,_,source)
  if not options.LandingSplash or not current or not current.splashSamples then return end
  for _,sample in ipairs(current.splashSamples)do if GetPtrHash(e)==GetPtrHash(sample.n)then
   sample.hits=(sample.hits or 0)+1;sample.source=source and source.Entity and GetPtrHash(source.Entity)
  end end
 end)
 mod:AddCallback(ModCallbacks.MC_PRE_RENDER,function()
  if phase~='menu'then return end;boot=boot+1;if boot<5 then return end
  phase='starting';log('START attempt='..options.Attempt..' version='..REPENTOGON.Version..' combat=true')
  Isaac.StartNewGame(0,0,0,31415926)
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_POST_GAME_STARTED,9999999,function()
  phase='running';prepareAt=game:GetFrameCount()+20
  -- The unrelated Ring starts on a pedestal in this room and claims the main
  -- active slot if picked up. Remove room pickups before any test collision;
  -- this is only the owned new test run, never the user's running game.
  local removed=0
  for _,e in ipairs(Isaac.GetRoomEntities())do if e.Type==EntityType.ENTITY_PICKUP then e:Remove();removed=removed+1 end end
  log('ISOLATION removed starting-room pickups='..removed)
  if options.Attempt:find('trace',1,true)then
   mod.MotionCombat.DamageProbe=function(n,before,after)log('TRACE returned hp='..before..' -> '..after..' fresh='..n:ToNPC().HitPoints)end
  end
  check('combat-loaded',mod.MotionCombat~=nil)
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_EVALUATE_CACHE,9999999,function(_,p,cache)
  if phase=='running'and cache==CacheFlag.CACHE_DAMAGE then p.Damage=10 end
 end)
 local function cleanup()
  mod.MotionCombat:Reset('probe case')
  for _,n in ipairs(npcs)do if n:Exists()then n:Remove()end end;npcs={}
 end
 local function spawn(p,offset,boss,hp)
  local n=Isaac.Spawn(boss and EntityType.ENTITY_MONSTRO or EntityType.ENTITY_GAPER,0,0,
   p.Position+(type(offset)=='table'and Vector(offset[1],offset[2])or Vector(offset,0)),Vector(0,0),nil):ToNPC()
  n.MaxHitPoints=hp;n.HitPoints=hp;n:GetData().NeverbirthCombatAcceptance=true
  n:AddEntityFlags(EntityFlag.FLAG_NO_KNOCKBACK|EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
  npcs[#npcs+1]=n;return n
 end
 local function start(p)
  cleanup();if current and current.id then p:RemoveCollectible(current.id)end
  index=index+1;current=cases[index];values={};shift=false
  if not current then
   phase='done';Input.GetActionValue=nativeValue;Input.IsButtonPressed=nativeButton
   log('SUMMARY checks='..passed..' passed fail='..failed..' cases='..(index-1))
   for _=1,48 do log('DONE '..string.rep('.',1024))end
   return
  end
  local id=Isaac.GetItemIdByName(current.name);if id<0 and current.zh then id=Isaac.GetItemIdByName(current.zh)end
  current.id=id;p:AddCollectible(id,0,false);p:AddCacheFlags(CacheFlag.CACHE_DAMAGE);p:EvaluateItems()
  if options.Horizontal then p:AddHearts(p:GetEffectiveMaxHearts())end
  if options.Fixes and current.move=='circle_720'then check('acquiring-720-grants-three-SA',mod.MotionCombat:GetRecord(p).energy==90)end
  p.Position=game:GetRoom():GetCenterPos();p.Velocity=Vector(0,0)
  if current.wall then p.Position=game:GetRoom():GetClampedPosition(p.Position+Vector(10000,0),p.Size)end
  current.start=game:GetFrameCount();current.maxFrame=-1;current.renders=0
  current.modifierBase=p.ControlsCooldown or 0;current.modifierExtraBase=p.IsExtraAnimationFinished and p:IsExtraAnimationFinished()
  current.hp=current.lethal and 10 or 2000
  if not current.empty then current.target=spawn(p,current.offset or 30,current.boss,current.hp);current.original=current.target.Position
   current.collision=current.target.EntityCollisionClass;current.flags=current.target:GetEntityFlags()
  end
  if current.move=='circle_720'and not current.empty and not current.noMeter and not current.interrupt then current.other=spawn(p,120,false,2000)end
  if current.splashMatrix then
   current.splashSamples={}
   for _,sample in ipairs({
    {name='near',x=40,y=0,multiplier=3},{name='edge',x=80,y=0,multiplier=3},
    {name='back-edge',x=-80,y=0,multiplier=3},{name='vertical-edge',x=0,y=80,multiplier=3},
    {name='outside',x=80.5,y=0,multiplier=0},{name='diagonal-outside',x=60,y=60,multiplier=0},
    {name='friendly',x=30,y=-30,multiplier=0,friendly=true},{name='invulnerable',x=-30,y=-30,multiplier=0,invulnerable=true},
   })do
    sample.n=spawn(p,{200,#current.splashSamples*20-70},false,2000)
    if sample.friendly then sample.n:AddEntityFlags(EntityFlag.FLAG_FRIENDLY)end
    if sample.invulnerable then sample.n.EntityCollisionClass=EntityCollisionClass.ENTCOLL_NONE end
    current.splashSamples[#current.splashSamples+1]=sample
   end
  end
  if current.invulnerable then
   current.target.EntityCollisionClass=EntityCollisionClass.ENTCOLL_NONE
   if current.other then current.other:Remove();current.other=nil end
  end
  if current.noMeter then mod.MotionCombat:GetRecord(p).energy=0 end
  if current.lethal or current.interrupt or options.ExitDuringPlayback then mod.MotionCombat:GetRecord(p).energy=90;log('SETUP meter=90 for lethal/interruption/exit negative case')end
  current.energyBefore=mod.MotionCombat:GetRecord(p).energy
  if current.naturalAI then current.warmup=game:GetFrameCount()+30 end
  if current.waitOD and mod.MotionCombat:GetRecord(p).od>0 then current.waiting=true end
  check('formal-held',p:HasCollectible(id)and p:GetActiveItem(0)==id,id)
  check('no-rehearsal',not next(mod.MotionInput.rehearsals))
 end
 mod:AddPriorityCallback(ModCallbacks.MC_PRE_NPC_UPDATE,-999999,function(_,n)
  if phase=='running'and n:GetData().NeverbirthCombatAcceptance and not(current and current.naturalAI)and not mod.MotionCombat.grabs[tostring(GetPtrHash(n))..':'..tostring(n.InitSeed)]then
   n.Velocity=Vector(0,0);return true
  end
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,-9999999,function(_,p)
  if phase~='running'then return end;local now=game:GetFrameCount();values={};shift=false
  if prepareAt and now>=prepareAt then prepareAt=nil;start(p)end
  if not current or phase~='running'or current.finished then return end
  if current.warmup then if now<current.warmup then current.start=now;return end;current.warmup=nil;current.start=now end
  if current.waiting then
   if mod.MotionCombat:GetRecord(p).od>0 then current.start=now;return end
   current.waiting=false;check('shared-OD-waited',true)
  end
  local t=now-current.start
  if t>=1 and t<=3 then values[ButtonAction.ACTION_SHOOTRIGHT]=1 end
  if t>=5 and t<35 then values[ButtonAction.ACTION_ITEM]=1;shift=current.od and(not current.releaseShift or t<10)or false end
  if current.shortcut and t>=8 then
   values[ButtonAction.ACTION_ITEM]=1;values[ButtonAction.ACTION_SHOOTUP]=1;values[ButtonAction.ACTION_SHOOTDOWN]=1
   shift=current.forceShift or false
  end
  local step=math.floor((t-8)/2)+1
  if step>=1 and step<=#current.directions then
   local dirs=current.directions[step];if type(dirs)=='number'then dirs={dirs}end
   for _,action in ipairs(dirs)do values[action]=1 end
  end
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_POST_RENDER,9999999,function()
  if phase~='running'or not current then return end
  local s=mod.MotionPresentation:GetState(Isaac.GetPlayer(0))
  if s and s.renderedFrame==s.frame then
   if options.Additions then
    if s.fist and s.fist.alpha>0 and s.fist.alpha<1 then current.fists=current.fists or {};current.fists[s.fist.stage]=true end
    if s.actionPhase then current.actionPhases=current.actionPhases or {};current.actionPhases[s.actionPhase]=true end
   end
   current.renders=current.renders+1;current.maxFrame=math.max(current.maxFrame,s.frame);current.cinema=current.cinema or s.sourceCinema
   if options.NativePlayer then
    current.nativeUnchanged=(current.nativeUnchanged~=false)and s.nativeActor and not s.hasPlayerCopy
    if options.ControlCinema and s.cinema and s.cinematicActorFrame==s.frame and math.abs(s.cameraScale or 0)>2 then current.closeupSeen=true end
    local sprite=Isaac.GetPlayer(0):GetSprite();current.nativeFrames=current.nativeFrames or {};current.nativeFrames[sprite:GetAnimation()..':'..sprite:GetFrame()]=true
    -- Entity.Color is the base tint. SetColor is composed into the live
    -- native Sprite.Color by the renderer; inspect the actually drawn tint.
    local color=Isaac.GetPlayer(0):GetSprite().Color
    if current.od and type(color.B)=='number'and color.B<.8 then current.goldSeen=true end
    if current.od and options.Attempt:find('gold-trace',1,true)and s.frame>=18 and not current.colorTraced then
     current.colorTraced=true;local p=Isaac.GetPlayer(0);local sprite=p:GetSprite()
     log('COLOR_TRACE entityB='..tostring(p.Color.B)..' spriteB='..tostring(sprite.Color.B))
     if p.GetColorParams then for _,cp in ipairs(p:GetColorParams())do log('COLOR_TRACE queueB='..tostring(cp:GetColor().B)..' priority='..cp:GetPriority()..' life='..cp:GetLifespan())end end
    end
   elseif options.Fixes then
    for _,part in pairs(s.partAnchors or {})do
     current.anchorSamples=(current.anchorSamples or 0)+1
     if(part.effective-part.expected):Length()>.001 or part.overlay and part.overlay~=''then current.anchorErrors=(current.anchorErrors or 0)+1 end
     if part.native:Length()>.001 then current.nativePositionSeen=true end
    end
   end
  end
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_RENDER,9999999,function()
  if phase=='running'and current and current.began and not current.finished then current.nativeRenders=(current.nativeRenders or 0)+1 end
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,-10000,function()
  if options.LandingSplash and phase=='running'and current and current.splashSamples and not current.splashPlaced then
   local p=Isaac.GetPlayer(0);local s=mod.MotionCombat:GetState(p);local slam=current.od and 34 or 42
   if s.move=='circle_360'and s.frame==slam-1 then
    mod.MotionPresentation:SetCombatFrame(p,73,false)
    local center=current.boss and current.target.Position or mod.MotionPresentation:GetTargetPosition(p)or current.target.Position
    current.splashOrigin=Vector(center.X,center.Y);current.splashPlaced=true
    for _,sample in ipairs(current.splashSamples)do
     sample.n.Position=current.splashOrigin+Vector(sample.x,sample.y);sample.n.Velocity=Vector(0,0)
     check('splash-before-slam-'..sample.name,sample.n:ToNPC().HitPoints==2000)
    end
   end
  end
  if not options.ControlCinema or phase~='running'or not current or not current.began or current.finished then return end
  local p=Isaac.GetPlayer(0);local s=mod.MotionCombat:GetState(p)
  if s.move=='dp'and s.frame<(current.od and 49 or 29)then
   if not s.landed then p.Position=p.Position+Vector(7,6);p.Velocity=Vector(-4,9)
   elseif options.Responsiveness then p.Position=p.Position+Vector(0,3)end
  end
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_RENDER,999999,function(_,p,offset)
  if not options.Horizontal or phase~='running'or not current or not current.began then return end
  local s=mod.MotionPresentation:GetState(p)
  if s and s.poseBase and s.nativePose then
   current.poseSamples=(current.poseSamples or 0)+1
   local base=s.poseBase;local pose=s.nativePose
   if pose.cinema then
    local actual=Isaac.WorldToScreen(p.Position)+p.SpriteOffset+offset
    if(actual-pose.screenRoot):Length()>.001 then current.poseErrors=(current.poseErrors or 0)+1 end
    current.cameraSamples=(current.cameraSamples or 0)+1
    if s.frame>=217 and s.frame<255 then
     if math.abs(p.SpriteScale.X)<math.abs(p.SpriteScale.Y)*.75 then current.cinematicNarrow=true end
     if p.SpriteScale.X*base.scale.X<0 then current.cinematicTurn=true end
    end
   else
    if math.abs(offset.Y-base.renderInput.Y-pose.height)>.001 or math.abs(offset.X-base.renderInput.X)>.001 then current.poseErrors=(current.poseErrors or 0)+1 end
    if pose.height<-.5 then current.jumpSeen=true end
   end
   if math.abs(p.SpriteOffset.Y-base.offset.Y)>.001 then current.poseErrors=(current.poseErrors or 0)+1 end
   if p.SpriteScale.X*base.scale.X<0 then current.flipSeen=true end
   current.poseBase={y=base.offset.Y,x=base.scale.X,r=base.rotation}
  end
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,9999999,function()
  if phase~='running'or not current or current.waiting or current.finished then return end
  local p=Isaac.GetPlayer(0);local combat=mod.MotionCombat;local s=combat:GetState(p);local art=mod.MotionPresentation:GetState(p)
  local event=mod.MotionInput:GetState(p).lastEvent;local now=game:GetFrameCount()
  if s.move and not current.began then
   current.began=now;current.damage=p.Damage;current.castOrigin=s.origin or Vector(p.Position.X,p.Position.Y)
   check('formal-combat-start',s.move==current.move and s.variant==(current.od and 'od'or 'normal'))
   check('gameplay-art',art and art.combat and not art.presentationOnly and not art.rehearsal)
   if current.expectedFacing then check('direction-from-input-or-target',s.facing==current.expectedFacing,s.facing)end
   if current.nativeHappy then p:AnimateHappy()end
   check('real-target',not current.move:find('circle_')or GetPtrHash(s.target)==GetPtrHash(current.target))
   if s.target then log('TRACE targetptr='..GetPtrHash(s.target)..' expectedptr='..GetPtrHash(current.target))end
   if current.replaceTarget then
    local old=current.target;current.departedTarget=old
    local alternative=spawn(p,33,false,current.hp)
    old.Position=p.Position+Vector(150,0)
    if current.removeCandidate then old:Remove();current.target=alternative;current.collision=alternative.EntityCollisionClass
    else current.confirmedTargetKept=true end
   end
   if current.releaseShift then check('OD-from-latched-early-Shift',s.variant=='od'and not shift and event and event.odRequested==true)end
   if current.move=='dp'and current.od and not current.invulnMatrix then
    current.healthBefore=p:GetHearts()+p:GetSoulHearts()+p:GetBoneHearts()*2
    p:TakeDamage(1,0,EntityRef(current.target),0)
    p:TakeDamage(1,DamageFlag.DAMAGE_IV_BAG,EntityRef(p),0)
    current.healthCheck=now+2
   end
   if current.move=='circle_720'then
    check('V9',art.version=='v9'and art.frames==394)
    check('meter-spent',s.energy==0,s.energy)
   end
  end
  if options.Responsiveness and now-current.start>=5 and now-current.start<=11 then
   if(p.ControlsCooldown or 0)>current.modifierBase then current.modifierLock=true end
   if current.modifierExtraBase and p.IsExtraAnimationFinished and not p:IsExtraAnimationFinished()then current.modifierLock=true end
  end
  if options.Responsiveness and s.move=='dp'then
   if s.landed then current.landFrame=current.landFrame or s.frame
    if math.abs(p.Position.Y-s.origin.Y)>2 then current.freeMoveSeen=true end
   end
   if current.crowd and s.frame>=6 and(s.frame<=15 or current.od and s.frame>=22 and s.frame<=31)then
    current.crowdFrames=current.crowdFrames or {}
    if not current.crowdFrames[s.frame]then current.crowdFrames[s.frame]=true;spawn(p,(s.facing=='left'and -20 or 20),false,2000)end
   end
  end
  if options.ControlCinema and s.move=='dp'and s.origin and not s.landed then
   current.controlSamples=(current.controlSamples or 0)+1
   current.travelSign=s.facing=='left'and -1 or 1
   current.controlOrigin=s.origin
   if math.abs(p.Position.Y-s.origin.Y)>.01 or(p.Position.X-s.origin.X)*current.travelSign<-.01 then current.controlErrors=(current.controlErrors or 0)+1 end
   current.controlDistance=(p.Position.X-s.origin.X)*current.travelSign
  end
  if options.Responsiveness and current.move=='circle_720'and art and art.recoveryTail and not current.tailReleased then
   current.tailReleased=true;current.tailStart=now
   check('720-release-unlocks-before-FX-tail',not combat:IsBusy(p)and not s.move and art.freeActor and art.frame==289,art.frame)
   p.Position=p.Position+Vector(-40,-35);current.tailFreePosition=Vector(p.Position.X,p.Position.Y)
   p:AddHearts(p:GetEffectiveMaxHearts());p:ResetDamageCooldown()
   current.tailHealth=p:GetHearts()+p:GetSoulHearts()+p:GetBoneHearts()*2
   p:TakeDamage(1,0,EntityRef(current.target),0)
   if current.replaceTail then
    local nextMove=combat:Execute(p,'wave',{serial=888888,facing='left'},{owner='probe-tail-followup'})
    check('new-action-replaces-cosmetic-tail',nextMove.ok and not mod.MotionPresentation:GetState(p).recoveryTail)
   end
  end
  if current.tailStart and not current.tailVerified and now>=current.tailStart+2 then
   current.tailVerified=true
   check('720-tail-is-vulnerable',current.tailHealth-(p:GetHearts()+p:GetSoulHearts()+p:GetBoneHearts()*2)==1)
   check('720-tail-does-not-reset-movement',(p.Position-current.castOrigin):Length()>20)
  end
  if current.matrixPending and now>=current.matrixPending.at then
   local m=current.matrixPending;local hp=p:GetHearts()+p:GetSoulHearts()+p:GetBoneHearts()*2
   check('OD-real-health-stage-'..m.tick,m.before-hp==m.loss,'loss='..(m.before-hp)..' expected='..m.loss)
   current.matrixPending=nil
  end
  if current.invulnMatrix and s.move=='dp'and not current.matrixPending then
   current.matrixDone=current.matrixDone or {}
   for _,point in ipairs({1,9,23,31,37,46})do if s.frame==point and not current.matrixDone[point]then
    current.matrixDone[point]=true;p:AddHearts(p:GetEffectiveMaxHearts());p:ResetDamageCooldown()
    local hp=p:GetHearts()+p:GetSoulHearts()+p:GetBoneHearts()*2
    p:TakeDamage(1,DamageFlag.DAMAGE_SPIKES,EntityRef(nil),0)
    current.matrixPending={before=hp,loss=point<=32 and 0 or 1,tick=point,at=now+2};break
   end end
  end
  if options.Attempt:find('trace',1,true)and current.target and current.target:Exists()then
   if current.lastHP~=current.target.HitPoints then current.lastHP=current.target.HitPoints;log('TRACE tick='..now..' hp='..current.lastHP..' targetptr='..GetPtrHash(current.target))end
   if s.move and s.grabbed and not current.traceGrab then current.traceGrab=true;log('TRACE grabbed vulnerable='..tostring(current.target:IsVulnerableEnemy())..' active='..tostring(current.target:IsActiveEnemy(false)))end
  end
  if s.grabbed then
   current.grabbed=true
   if not current.grabLogged then
    current.grabLogged=true;check('controlled-real-NPC',current.target.EntityCollisionClass==EntityCollisionClass.ENTCOLL_NONE)
    log('GRAB npc='..current.target.Type..' seed='..current.target.InitSeed)
   end
  end
  if current.interrupt and current.began and now-current.began==15 then current.target:Remove()end
  if current.healthCheck and now>=current.healthCheck then
   check('enemy-protection-payment-exclusion',current.healthBefore-(p:GetHearts()+p:GetSoulHearts()+p:GetBoneHearts()*2)==1)
   current.healthCheck=nil
  end
  if options.ExitDuringPlayback and s.move and s.frame>=50 then
   for _,session in pairs(combat.sessions)do session.tick=50 end
   mod.MotionPresentation:SetCombatFrame(p,50,false)
   if not current.exitLogged then
    current.exitLogged=true;check('exit-with-live-V9-and-real-grab',s.grabbed and art and art.sourceCinema)
    log('SUMMARY checks='..passed..' passed fail='..failed..' cases=1')
    for _=1,48 do log('DONE '..string.rep('.',1024))end
   end
   return
  end
  if current.empty or current.noMeter or current.rejectOD or current.invulnerable or current.rejectMotion then
   if now-current.start>45 then
    if current.rejectMotion then
     check('vertical-or-upward-DP-rejected',not current.began and not art and(not event or event.kind~='execute'))
     check('rejected-motion-keeps-energy',s.energy==current.energyBefore,s.energy)
    else
     check('rejected-no-success-film',not current.began and not art and event and event.kind=='failure',event and event.reason)
     check('no-resource-loss',current.invulnerable and s.energy==90 or not current.invulnerable and(s.energy==0 or current.empty or current.rejectOD),s.energy)
    end
    if current.invulnerable then check('visible-invulnerable-target-explained',event and event.reason=='Target invulnerable',event and event.reason)end
    if current.rejectOD then check('OD-not-silently-normal',event and event.reason=='OD cooldown',event and event.reason)end
    current.finished=true;prepareAt=now+3
   end
  elseif current.began and not s.move and not(art and art.recoveryTail)then
   if current.interrupt then
    check('external-removal-refund',s.energy==90,s.energy)
    check('cancel-art',art==nil)
   else
    local hp=current.target:Exists()and current.target.HitPoints or 0;local actual=current.hp-math.max(0,hp)
    local expected=math.min(current.hp,current.damage*current.multiplier)
    check('actual-HP-delta',math.abs(actual-expected)<.05,'before='..current.hp..' after='..hp..' expected='..expected)
    if current.splashSamples then
     check('splash-placed-at-real-landing',current.splashPlaced)
     for _,sample in ipairs(current.splashSamples)do
      local expectedSplash=current.damage*sample.multiplier;local delta=2000-sample.n:ToNPC().HitPoints
      check('splash-HP-'..sample.name,math.abs(delta-expectedSplash)<.05,'loss='..delta..' expected='..expectedSplash)
      if sample.multiplier>0 then
       check('splash-single-owned-hit-'..sample.name,sample.hits==1 and sample.source==GetPtrHash(p),sample.hits)
      else check('splash-excluded-no-hit-'..sample.name,(sample.hits or 0)==0,sample.hits)end
     end
    end
    if current.other then check('room-HP-delta',math.abs(current.other.HitPoints-(2000-current.damage*10))<.05,current.other.HitPoints)end
    if current.move:find('circle_')then
     check('real-grab-happened',current.grabbed)
     if current.target:Exists()and not current.target:IsDead()then
      check('collision-restored',current.target.EntityCollisionClass==current.collision)
      check('sprite-flag-restored',not current.target:HasEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE))
      if current.boss then check('Boss-position-retained',(current.target.Position-current.original):Length()<.1)end
     end
    end
    if current.move=='circle_720'then
     check('V9-rendered-to-end',current.cinema and current.maxFrame>=(current.replaceTail and 288 or 392),current.maxFrame)
     check('no-self-meter',s.energy==0,s.energy)
    elseif current.move=='wave'then check('effective-damage-meter',math.abs(s.energy-10)<.05,s.energy)end
   if current.od then check('OD-cooldown-active',s.od>0,s.od)end
   if options.NativePlayer then
    check('native-player-render-not-cancelled',current.nativeUnchanged and(current.nativeRenders or 0)>0,current.nativeRenders)
    if current.nativeHappy then local n=0;for _ in pairs(current.nativeFrames or {})do n=n+1 end;check('native-animation-continues',n>2,n)end
    if current.od then check('OD-gold-without-player-copy',current.goldSeen)end
    if options.Horizontal and current.move~='wave'then
     check('approved-jump-on-real-native-player',current.jumpSeen and not current.poseErrors,current.poseSamples)
     check('native-pose-restored-after-render',current.poseBase and math.abs(p.SpriteOffset.Y-current.poseBase.y)<.001 and math.abs(p.SpriteScale.X-current.poseBase.x)<.001 and math.abs(p.SpriteRotation-current.poseBase.r)<.001)
     if current.move:find('circle_')then check('native-whole-body-horizontal-flip',current.flipSeen)end
    end
   elseif options.Fixes then
    check('native-layer-anchors-once',(current.anchorSamples or 0)>0 and not current.anchorErrors and current.nativePositionSeen,current.anchorSamples)
    if current.replaceTarget then check('contact-frame-replacement-grab',current.grabbed and current.target.HitPoints<current.hp)end
   end
    if current.boss then
     -- The radius matrix adds other legal grab candidates. Isolate the
     -- Boss again before testing its own post-release anti-grab window.
     if current.splashSamples then
      for _,sample in ipairs(current.splashSamples)do sample.n:Remove()end
      p.Position=current.original-Vector(30,0);p.Velocity=Vector(0,0)
     end
     local attempt=combat:Execute(p,'circle_360',{serial=999999,facing='right'},{id=current.id,owner='probe-negative'})
     check('Boss-antigrab',not attempt.ok and attempt.reason=='Boss recovering',attempt.reason)
    end
    if options.Additions then
     if current.move=='dp'then check('white-fist-actually-rendered',current.fists and current.fists[1]and(not current.od or current.fists[2]))end
     if current.move=='circle_360'and current.od then local a=current.actionPhases or {};check('OD-SPD-distinct-brace-rise-dive-slam',a.brace and a['horizontal-rise']and a.dive and a.slam)end
     if current.shortcut then
      local last=mod.MotionInput:GetState(p).lastEvent
      check('shortcut-held-does-not-repeat',last and last.kind=='execute'and last.profile=='circle_720',last and last.reason)
      check('shortcut-720-has-no-OD',not current.od and s.od==0)
     end
    end
    if options.ControlCinema then
     if current.move=='dp'then
      check('forced-horizontal-control',current.controlSamples and not current.controlErrors,current.controlSamples)
      check('forced-distance-or-wall',current.wall and current.controlDistance<2 or not current.wall and math.abs(current.controlDistance-(current.od and 57 or 51))<.2,current.controlDistance)
     elseif current.move=='circle_720'then
      check('live-native-V9-closeup',current.closeupSeen and(current.cameraSamples or 0)>20,current.cameraSamples)
      check('native-cinematic-horizontal-yaw',current.cinematicNarrow and current.cinematicTurn)
     end
    end
    if options.Responsiveness then
     check('native-active-modifier-adds-no-extra-lock',not current.modifierLock,current.nativeUseCalls or 0)
     if current.move=='dp'then
      check('fixed-uppercut-duration',now-current.began<=(current.od and 50 or 30),now-current.began)
      check('landing-restores-movement-before-recovery-ends',current.landFrame and current.freeMoveSeen,current.landFrame)
     end
    end
    check('actually-rendered',current.renders>0,current.renders)
   end
   current.finished=true;prepareAt=now+4
  elseif now-current.start>520 then
   check('starts-and-finishes',false,event and (event.kind..':'..tostring(event.reason))or 'no input event')
   current.finished=true;prepareAt=now+3
  end
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_PRE_GAME_EXIT,9999999,function()
  if not options.ExitDuringPlayback or not current or not current.exitLogged then return end
  check('exit-releases-real-grab',not next(mod.MotionCombat.sessions)and(not current.target:Exists()or current.target.EntityCollisionClass==current.collision))
  check('exit-clears-presentation',not next(mod.MotionPresentation.states))
  log('SUMMARY checks='..passed..' passed fail='..failed..' cases=1')
 end)
end
