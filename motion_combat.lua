-- Real attacks own collisions, target leases and HP settlement. Rendering never does.
return function(mod,context)
 context=context or {}
 if mod.MotionCombat then mod.MotionCombat:Shutdown() end
 local C=include('motion_combat_core');local D=include('drive_glove_damage')
 local input=assert(mod.MotionInput);local presentation=assert(mod.MotionPresentation);local game=Game()
 local waveVariant=context.WaveVariant
 local function waveRegistered()
  if not waveVariant and Isaac.GetEntityVariantByName then waveVariant=Isaac.GetEntityVariantByName('Neverbirth Motion Wave')end
  return type(waveVariant)=='number'and waveVariant>0
 end
 local api={active=true,sessions={},shots={},grabs={},bossLocks={},feedback={},clock=0};local fallback={}
 local directions={right={1,0},down={0,1},left={-1,0},up={0,-1}}
 local lastFrame=-1;local snapshots={};local dirty=false;local runSeed;local inRun=false
 local receipts={};local currentHit
 local earlyAcquisitions={}
 local function exists(e)return e and e:Exists()end
 local function live(e)return exists(e) and not e:IsDead()end
 local function key(e)return context.Key and context.Key(e)or tostring(e.InitSeed or 0)..':'..tostring(e.ControllerIndex or 0)end
 local function entityKey(e)return (GetPtrHash and tostring(GetPtrHash(e))or tostring(e))..':'..tostring(e.InitSeed or 0)end
 local function same(a,b)return a and b and entityKey(a)==entityKey(b)end
 local function root()return context.GetSaveRoot and context.GetSaveRoot()or fallback end
 local function seed()
  if runSeed==nil then runSeed=context.GetCurrentRunSeed and context.GetCurrentRunSeed()or 0 end
  return runSeed
 end
 local function save()if dirty and context.Save then context.Save()end;dirty=false end
 local function players()return context.GetPlayers and context.GetPlayers()or {}end
 local hud=context.HUD or include('motion_sa_hud')({Key=key,Now=function()return game:GetFrameCount()end,
  IsPaused=function()return game:IsPaused()end,ScreenWidth=function()return Isaac.GetScreenWidth()end,
  ScreenHeight=function()return Isaac.GetScreenHeight()end,HUDOffset=function()return Options and Options.HUDOffset or 0 end,
  Visible=function()
   local mode=game:GetRoom():GetRenderMode()
   if mode~=RenderMode.RENDER_NULL and mode~=RenderMode.RENDER_NORMAL and mode~=RenderMode.RENDER_WATER_ABOVE then return false end
   if game.GetHUD then local h=game:GetHUD();if h and h.IsVisible and not h:IsVisible()then return false end end
   if SeedEffect and SeedEffect.SEED_NO_HUD and game:GetSeeds():HasSeedEffect(SeedEffect.SEED_NO_HUD)then return false end
   return true
  end,Log=context.DebugLog})
 api.HUD=hud;mod.MotionSAHUD=hud
 function api:GetRecord(p)return C.Record(root(),seed(),key(p))end
 function api:OnAcquire(p,move)
  if not self.active or move~='circle_720'or not live(p)then return false end
  if not inRun then earlyAcquisitions[key(p)]=p;return false end
  self:GetRecord(p).energy=C.MAX_ENERGY;dirty=true;return true
 end
 function api:Capture()return C.Clone(root().motionCombat)end
 function api:Restore(value)root().motionCombat=C.Clone(value);dirty=true end
 function api:IsBusy(p)return self.sessions[key(p)]~=nil end
 function api:GetState(p)
  local s=self.sessions[key(p)];local r=self:GetRecord(p)
  return {move=s and s.move,variant=s and s.variant,frame=s and s.tick,target=s and s.target,grabbed=s and s.grabbed or false,
   energy=r.energy,od=r.od,facing=s and(s.facing or s.command.facing),origin=s and s.origin,landed=s and s.landed,serial=s and s.command.serial,settled=s and s.settled or false,feedback=self.feedback[key(p)]}
 end
 local function notify(p,text,success)
  api.feedback[key(p)]={text=text,untilTick=api.clock+30,success=success};return {ok=false,reason=text}
 end
 function api:Feedback(p,text,success)return notify(p,text,success)end
 local function flag(n,f)return f and n:HasEntityFlags(f)end
 local function enemy(n)
  return live(n) and n.ToNPC and n:ToNPC() and n:IsActiveEnemy(false)
   and not flag(n,EntityFlag.FLAG_FRIENDLY) and not flag(n,EntityFlag.FLAG_CHARM)
 end
 local function eligible(n)return enemy(n)and n:IsVulnerableEnemy()end
 local function canGrab(n)
  return eligible(n) and not api.grabs[entityKey(n)] and (api.bossLocks[entityKey(n)]or 0)<=api.clock
 end
 local function inReach(s,n)
  local offset=n.Position-s.player.Position
  local reach=(s.player.Size or 10)+(n.Size or 10)+s.def.reach
  return offset.X^2+offset.Y^2<=reach^2
 end
 local function faceTarget(s,n)
  local d=n.Position-s.player.Position
  if d.X~=0 or d.Y~=0 then
   s.facing=math.abs(d.X)>=math.abs(d.Y)and(d.X>=0 and 'right'or 'left')or(d.Y>=0 and 'down'or 'up')
   local f=directions[s.facing];s.forward=Vector(f[1],f[2])
  end
 end
 local function choose(s)
  s.blockedBoss=nil;s.invulnerableTarget=nil;s.outOfRange=nil;s.nearestGap=nil
  local best,distance
  for _,entity in ipairs(Isaac.GetRoomEntities())do
   local n=entity.ToNPC and entity:ToNPC()
   if n then
   local scope=s.move=='circle_720'or inReach(s,n)
   if s.move=='circle_360'and enemy(n)and not scope then
    local d=(n.Position-s.player.Position):Length();local reach=(s.player.Size or 10)+(n.Size or 10)+s.def.reach
    if not s.nearestGap or d-reach<s.nearestGap then s.nearestGap=d-reach;s.nearestDistance=d;s.nearestReach=reach end
    s.outOfRange=true
   end
   if scope and enemy(n)and not n:IsVulnerableEnemy()then s.invulnerableTarget=true end
   if scope and eligible(n) and (api.bossLocks[entityKey(n)]or 0)>api.clock then s.blockedBoss=true end
   if scope and canGrab(n)then
    local delta=n.Position-s.player.Position;local d=delta.X^2+delta.Y^2
    if not distance or d<distance then best,distance=n,d end
   end
   end
  end
  return best
 end
 local function missingTarget(s,fallback)
  local reason=s.blockedBoss and 'Boss recovering'or s.invulnerableTarget and 'Target invulnerable'or s.outOfRange and 'Out of grab range'or fallback
  local result=notify(s.player,reason)
  if reason=='Out of grab range'then
   local f=api.feedback[key(s.player)];f.text=string.format('Out of grab range (%.0f)',s.nearestGap)
   f.distance=s.nearestDistance;f.reach=s.nearestReach;f.gap=s.nearestGap
  end
  return result
 end
 local function release(s,cancel)
  local lease=s.lease;if not lease then return end
  local n=lease.entity
  if api.grabs[lease.key]==s then api.grabs[lease.key]=nil end
  if exists(n)then
   if n.EntityCollisionClass==EntityCollisionClass.ENTCOLL_NONE then n.EntityCollisionClass=lease.collision end
   if n.CollisionDamage==0 then n.CollisionDamage=lease.damage end
   if lease.spriteFlag then n:ClearEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE)end
   if n.Velocity.X==0 and n.Velocity.Y==0 then n.Velocity=lease.velocity end
   if lease.boss or cancel then n.Position=lease.position
   elseif live(n)then n.Position=game:GetRoom():GetClampedPosition(s.player.Position+s.forward*((s.player.Size or 10)+(n.Size or 10)),n.Size or 10)end
   if lease.boss and s.grabbed then api.bossLocks[lease.key]=api.clock+C.BOSS_ANTIGRAB end
  end
  s.lease=nil;s.grabbed=false
 end
 local function grab(s,n)
  if not canGrab(n)then return false end
  local spriteFlag=not flag(n,EntityFlag.FLAG_NO_SPRITE_UPDATE)
  s.origin=Vector(s.player.Position.X,s.player.Position.Y)
  s.target=n;s.targetKey=entityKey(n);s.lease={entity=n,key=s.targetKey,collision=n.EntityCollisionClass,damage=n.CollisionDamage,
   position=Vector(n.Position.X,n.Position.Y),velocity=n.Velocity,boss=n:IsBoss(),spriteFlag=spriteFlag}
  api.grabs[entityKey(n)]=s;s.grabbed=true
  if spriteFlag then n:AddEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE)end
  n.EntityCollisionClass=EntityCollisionClass.ENTCOLL_NONE;n.CollisionDamage=0;n.Velocity=Vector(0,0)
  return true
 end
 local function finish(s,cancel,recoveryTail)
  release(s,cancel)
  if cancel and s.spent and not s.settled then api:GetRecord(s.player).energy=90;dirty=true end
  local art=presentation:GetState(s.player)
  if art and art.sourceOwner==s.owner and art.combat then
   if recoveryTail then presentation:StartRecoveryTail(s.player,s.id)else presentation:Stop(s.player,true)end
  end
  api.sessions[key(s.player)]=nil
 end
 function api:Reset(reason)
  local pending={};for _,s in pairs(self.sessions)do pending[#pending+1]=s end
  for _,s in ipairs(pending)do finish(s,true)end
  for _,shot in ipairs(self.shots)do if exists(shot.entity)then shot.entity:Remove()end end
  self.shots={};self.grabs={};self.feedback={};self.bossLocks={};receipts={};currentHit=nil;hud:Reset(reason);self.lastReset=reason
 end
 function api:Shutdown()if not self.active then return end;self:Reset('unload');hud:Shutdown();earlyAcquisitions={};save();self.active=false end
 local function odPressed(p)
  if context.OdPressed then return context.OdPressed(p)end
  return input:IsODModifierPressed(p)
 end
 function api:Execute(p,move,command,owner)
  owner=owner or {}
  if not self.active or not live(p)or owner.id and not p:HasCollectible(owner.id)then return {ok=false,reason='ownership'}end
  if self:IsBusy(p)then return {ok=false,reason='recovery'}end
  local requested=command.odRequested
  if requested==nil then requested=odPressed(p)end
  local variant=(move=='dp'or move=='circle_360')and requested and 'od'or 'normal'
  local def=C.Definition(move,variant);local dir=directions[command.facing]
  if not def or not dir then return {ok=false,reason='command'}end
  local r=self:GetRecord(p)
  if move=='wave'and not waveRegistered()then return notify(p,'Wave registration missing')end
  if variant=='od'and r.od>0 then return notify(p,'OD cooldown')end
  if move=='circle_720'and r.energy<90 then return notify(p,'Need 3 SA bars')end
  for _,other in pairs(self.sessions)do if move=='circle_720'or other.move=='circle_720'then return notify(p,'Cinematic busy')end end
  local s={player=p,move=move,variant=variant,def=def,forward=Vector(dir[1],dir[2]),command=command,id=owner.id,
   owner=owner.owner,tick=0,hits={},damage=p.Damage,origin=Vector(p.Position.X,p.Position.Y)}
  if move=='circle_360'or move=='circle_720'then
   s.target=choose(s);if not s.target then return missingTarget(s,'No grabbable target')end
   faceTarget(s,s.target)
  end
  if move=='circle_720'and not grab(s,s.target)then return notify(p,'No grabbable target')end
  local shown=presentation:Play(p,move,{variant=variant,facing=s.facing or command.facing,target=s.grabbed and s.target or nil,
   combat=true,sourceOwner=owner.owner})
  if not shown.ok then release(s,true);return shown end
  self.sessions[key(p)]=s
  inRun=true
  if move=='circle_720'then r.energy=0;s.spent=true;dirty=true end
  if variant=='od'and move=='dp'then r.od=C.OD_COOLDOWN;dirty=true end
  notify(p,'Command OK',true)
  return {ok=true,presentation=false}
 end
 local function hitFeedback(s,n)
  if exists(n)then n:SetColor(Color(1,1,1,1,.8,.8,.8),3,100,false,false)end
  s.hitUntil=api.clock+3
  if s.move~='dp'then s.hitstop=2 end
  if SoundEffect and SoundEffect.SOUND_MEAT_IMPACTS then SFXManager():Play(SoundEffect.SOUND_MEAT_IMPACTS,.7,0,false,1)end
 end
 local function receiptFor(n)
  local k=entityKey(n)
  if not receipts[k]then receipts[k]={entity=n,before=math.max(0,n.HitPoints),frame=game:GetFrameCount(),hits={}}end
  return receipts[k]
 end
 local function settleReceipts()
  for k,r in pairs(receipts)do
   local remaining=exists(r.entity)and math.max(0,r.before-math.max(0,r.entity:ToNPC().HitPoints))or 0
   if remaining>0 then
    -- One actual HP budget shared by all accepted hits in native order. This
    -- prevents co-op/foreign damage and overkill from being credited twice.
    for _,h in ipairs(r.hits)do
     local actual=math.min(remaining,h.amount);remaining=remaining-actual
     if actual>0 and h.session then
      local s=h.session
      if s.move~='circle_720'then C.Gain(api:GetRecord(s.player),actual);dirty=true end
      hitFeedback(s,r.entity)
     end
    end
    receipts[k]=nil
   elseif #r.hits==0 or game:GetFrameCount()>r.frame+2 or not exists(r.entity)then receipts[k]=nil end
  end
 end
 local function hit(s,n,amount,stage)
  n=n and n.ToNPC and n:ToNPC();if not n then return false end
  local lease=s.lease;local heldTarget=lease and entityKey(lease.entity)==entityKey(n)
  if heldTarget then n.EntityCollisionClass=lease.collision end
  if not eligible(n)then
   if heldTarget then n.EntityCollisionClass=EntityCollisionClass.ENTCOLL_NONE end
   return false
  end
  local hitKey=tostring(stage)..':'..entityKey(n)
  if s.hits[hitKey]then
   if heldTarget then n.EntityCollisionClass=EntityCollisionClass.ENTCOLL_NONE end
   return false
  end
  s.hits[hitKey]=true
  receiptFor(n)
  local previous=currentHit;currentHit={session=s,target=n}
  local worked,err=pcall(input.WithCommand,input,s.player,s.command,function()n:TakeDamage(amount,0,EntityRef(s.player),0)end)
  currentHit=previous
  if heldTarget and exists(n)then n.EntityCollisionClass=EntityCollisionClass.ENTCOLL_NONE end
  if not worked then error(err,0)end
  return true
 end
 local function spawnWave(s)
  local pos=s.player.Position+s.forward*((s.player.Size or 10)+s.def.radius)
  local e=input:WithCommand(s.player,s.command,function()
   return Isaac.Spawn(EntityType.ENTITY_EFFECT,waveVariant,0,pos,Vector(0,0),s.player):ToEffect()
  end)
  e.Visible=false;e.EntityCollisionClass=EntityCollisionClass.ENTCOLL_NONE;e.GridCollisionClass=EntityGridCollisionClass.GRIDCOLL_NONE
  input:MarkAttack(s.player,e,s.command.serial)
  api.shots[#api.shots+1]={entity=e,player=s.player,command=s.command,forward=s.forward,def=s.def,damage=s.damage,hits={},distance=0,age=0,move='wave',facing=s.command.facing}
 end
 local function updateShots()
  local kept={}
  for _,s in ipairs(api.shots)do
   if exists(s.entity)and live(s.player)then
    local a=s.entity.Position;local b=a+s.forward*s.def.speed;local wall=1
    for step=1,s.def.speed do local point=a+s.forward*step
     if game:GetRoom():GetGridCollisionAtPos(point)>=GridCollisionClass.COLLISION_OBJECT then wall=(step-1)/s.def.speed;break end
    end
    b=a+(b-a)*wall;local nearest,nearT
    for _,n in ipairs(Isaac.GetRoomEntities())do if eligible(n)then
     local d,t=C.SegmentDistance(n.Position.X,n.Position.Y,a.X,a.Y,b.X,b.Y)
     if d<=s.def.radius+(n.Size or 0)and(not nearT or t<nearT)then nearest,nearT=n,t end
    end end
    s.entity.Position=b;s.distance=s.distance+s.def.speed*wall;s.age=s.age+1
    if nearest then hit(s,nearest,s.damage*s.def.damage,'projectile')end
    if nearest or wall<1 or s.distance>=s.def.range then s.entity:Remove()else kept[#kept+1]=s end
   end
  end
  api.shots=kept
 end
 local function protect(s)
  return s and(s.move=='circle_720'or s.grabbed or s.move=='dp'and s.variant=='od'and s.tick<=32)
 end
 local function lockMovement(s)return s and(s.move=='dp'and not s.landed or s.move=='circle_720'or s.grabbed)end
 local function advanceUppercut(s)
  local p=s.player;local room=game:GetRoom();local from=s.controlPosition or s.origin
  s.sweepFrom=from
  local travel=presentation:GetHorizontalTravel(p,C.SourceFrame(s.move,s.variant,s.tick))
  local delta=travel-(s.controlTravel or 0);s.controlTravel=travel
  local next=Vector(from.X+delta*s.forward.X,s.origin.Y)
  local clamped=room:GetClampedPosition(next,p.Size or 10);next.X=clamped.X
  local edge=next+Vector((p.Size or 10)*s.forward.X,0);local collision=room:GetGridCollisionAtPos(edge)
  if collision>=GridCollisionClass.COLLISION_OBJECT or collision==(GridCollisionClass.COLLISION_PIT or 1)and not p.CanFly then next=from end
  s.controlPosition=next;p.Position=next;p.Velocity=Vector(0,0)
 end
 local function enemySource(source)
  local e=source and source.Entity;local seen={};local projectile=false
  for _=1,12 do
   if not exists(e)or seen[entityKey(e)]then break end;seen[entityKey(e)]=true
   if e.ToPlayer and e:ToPlayer()then return false end
   if flag(e,EntityFlag.FLAG_FRIENDLY)or flag(e,EntityFlag.FLAG_CHARM)then return false end
   local n=e.ToNPC and e:ToNPC();if n and n:IsActiveEnemy(false)then return true end
   if EntityType.ENTITY_PROJECTILE and e.Type==EntityType.ENTITY_PROJECTILE then projectile=true end
   e=e.SpawnerEntity or e.Parent
  end
  return projectile
 end
 local function updateSession(s)
  if not live(s.player)or s.id and not s.player:HasCollectible(s.id)then finish(s,true);return end
  local art=presentation:GetState(s.player)
  if not art or not art.combat or art.sourceOwner~=s.owner then finish(s,true);return end
  if s.target and not live(s.target)and not s.settled and(s.grabbed or s.move=='circle_720')then finish(s,true);notify(s.player,'Target lost');return end
  if s.hitstop and s.hitstop>0 then
   if s.move=='dp'then s.player.Position=s.controlPosition or s.origin;s.player.Velocity=Vector(0,0)end
   s.hitstop=s.hitstop-1;return
  end
  s.tick=s.tick+1
  if s.tick>=s.def.duration then finish(s,false);return end
  if s.move=='dp'and not s.landed then
   advanceUppercut(s)
   local source=C.SourceFrame(s.move,s.variant,s.tick)
   if s.tick>s.def.windows[#s.def.windows][2]and presentation:GetVerticalHeight(s.player,source)>=-.001 then
    s.landed=true;presentation:ReleasePlayerPose(s.player)
   end
  end
  if s.move=='wave'and s.tick==s.def.spawn then spawnWave(s)end
  if s.move=='dp'then
   for stage,w in ipairs(s.def.windows)do if s.tick>=w[1]and s.tick<=w[2]then
    local a=s.sweepFrom or s.player.Position;local b=s.player.Position+s.forward*s.def.length
    for _,n in ipairs(Isaac.GetRoomEntities())do if eligible(n)then
     if C.SegmentDistance(n.Position.X,n.Position.Y,a.X,a.Y,b.X,b.Y)<=s.def.radius+(n.Size or 0)then
      hit(s,n,s.damage*(type(s.def.damage)=='table'and s.def.damage[stage]or s.def.damage),stage)
     end
    end end
   end end
  elseif s.move=='circle_360'or s.move=='circle_720'then
   if s.move=='circle_360'and s.tick==s.def.grab then
    -- Range was confirmed by the recognized command. Preserve that hit
    -- through the authored startup; reselect only if the target is invalid.
    local candidate=canGrab(s.target)and s.target or choose(s)
    if not candidate or not grab(s,candidate)then finish(s,true);missingTarget(s,'Grab missed');return end
    faceTarget(s,s.target)
    if not presentation:SetTarget(s.player,s.target,s.facing)then finish(s,true);return end
    if s.variant=='od'then api:GetRecord(s.player).od=C.OD_COOLDOWN;dirty=true end
   end
   if s.tick==s.def.slam then
    local splashPosition
    if s.def.splashRadius then
     -- Resolve this tick's authored landing before a lethal hit can remove
     -- the target. Bosses keep their real world position during the scene.
     presentation:SetCombatFrame(s.player,C.SourceFrame(s.move,s.variant,s.tick),false)
     local pos=s.lease and s.lease.boss and s.lease.position or presentation:GetTargetPosition(s.player)or s.target.Position
     splashPosition=Vector(pos.X,pos.Y)
    end
    -- Mark owned settlement before lethal callbacks; own kill must finish V9.
    s.settled=true;hit(s,s.target,s.damage*s.def.damage,'slam')
    if s.def.splash then for _,n in ipairs(Isaac.GetRoomEntities())do
     if entityKey(n)~=s.targetKey and(not s.def.splashRadius or(n.Position-splashPosition):Length()<=s.def.splashRadius)then
      hit(s,n,s.damage*s.def.splash,s.move=='circle_720'and 'room'or 'splash')
     end
    end end
    presentation:FinishTarget(s.player,true)
   end
   if s.tick==s.def.release then
    release(s,false);presentation:FinishTarget(s.player,false)
    if s.move == 'circle_720' then
     presentation:SetCombatFrame(s.player,C.SourceFrame(s.move,s.variant,s.tick),false)
     finish(s,false,true);return
    end
   end
  end
  local source=C.SourceFrame(s.move,s.variant,s.tick)
  presentation:SetCombatFrame(s.player,source,(s.hitUntil or 0)>=api.clock)
  if s.lease and exists(s.target)then
   local lease=s.lease;s.target.Velocity=Vector(0,0)
   if lease.boss then s.target.Position=lease.position
   elseif presentation:GetTargetPosition(s.player)then s.target.Position=presentation:GetTargetPosition(s.player)end
  end
  if lockMovement(s)and s.move~='dp'then s.player.Position=s.origin;s.player.Velocity=Vector(0,0)end
 end
 local function add(name,priority,fn)if ModCallbacks[name]then mod:AddPriorityCallback(ModCallbacks[name],priority,fn)end end
 add('MC_POST_UPDATE',100,function()
  if not api.active then return end
  if not next(api.sessions)and #api.shots==0 and not root().motionCombat then return end
  if game:IsPaused()or lastFrame==game:GetFrameCount()then return end;lastFrame=game:GetFrameCount();api.clock=api.clock+1
  local saved=root().motionCombat;if saved then for _,r in pairs(saved.players)do if r.od>0 then r.od=r.od-1;dirty=true end end end
  updateShots();local pending={};for _,s in pairs(api.sessions)do pending[#pending+1]=s end
  for _,s in ipairs(pending)do
   local good,err=pcall(updateSession,s)
   if not good then finish(s,true);notify(s.player,'Attack cancelled');if context.DebugLog then context.DebugLog('[Motion Combat] '..tostring(err))end end
  end
  if api.clock%30==0 then save()end
 end)
 add('MC_ENTITY_TAKE_DMG',-28000,function(_,e)
  if not api.active or not inRun then return end
  local n=e.ToNPC and e:ToNPC();if n and live(n)then receiptFor(n)end
 end)
 add('MC_POST_ENTITY_TAKE_DMG',28000,function(_,e,amount,_,source)
  if not api.active or not inRun then return end
  local n=e.ToNPC and e:ToNPC();if not n then return end
  local r=receiptFor(n);local owned=currentHit and same(currentHit.target,n)and source and same(source.Entity,currentHit.session.player)
  r.hits[#r.hits+1]={amount=math.max(0,amount),session=owned and currentHit.session or nil}
 end)
 add('MC_POST_UPDATE',200,function()if api.active and inRun and not game:IsPaused()then settleReceipts()end end)
 add('MC_POST_UPDATE',300,function()
  if not api.active or not inRun or game:IsPaused()then return end
  local seen={}
  for _,p in ipairs(players())do
   if live(p)and input:IsRestricted(p)then
    seen[key(p)]=true
    local r=root().motionCombat and root().motionCombat.players[key(p)]
    hud:Update(p,r and r.energy or 0)
   end
  end
  hud:Prune(seen)
 end)
 add('MC_PRE_NPC_UPDATE',-29000,function(_,n)
  if not api.active or not inRun then return end
  local s=api.grabs[entityKey(n)]
  if s and s.lease then n.Velocity=Vector(0,0);return true end
 end)
 add('MC_INPUT_ACTION',-29000,function(_,e,hook,action)
  if not api.active or not e or action<ButtonAction.ACTION_LEFT or action>ButtonAction.ACTION_DOWN then return end
  local s=api.sessions[key(e)]
  if lockMovement(s)then return hook==InputHook.GET_ACTION_VALUE and 0 or false end
 end)
 add('MC_PRE_PLAYER_TAKE_DMG',-29000,function(_,p,_,flags,source)
  local s=api.sessions[key(p)]
  if not api.active or not protect(s)then return end
  if not D.Payment(p,flags,source,game:GetRoom(),false)and not D.Flag(flags,'DAMAGE_FAKE')
   and(s.move=='dp'and s.variant=='od'or enemySource(source))then return false end
 end)
 add('MC_POST_RENDER',100,function()
  if not api.active or not inRun then return end
  for _,shot in ipairs(api.shots)do if exists(shot.entity)then presentation:RenderProjectile(shot)end end
  if context.RenderHUD then context.RenderHUD(api)return end
  for index,p in ipairs(players())do
   local r=root().motionCombat and root().motionCombat.players[key(p)];local f=api.feedback[key(p)]
   if input:IsRestricted(p)then hud:Render(p,index-1)end
   if r and input:IsRestricted(p)and Isaac.RenderText then
    local pos=Isaac.WorldToScreen(p.Position)
    local view=input:GetState(p)
    if view.profile=='dp'or view.profile=='circle_360'then
     local text='OD '..(r.od==0 and(view.odRequested and 'armed'or 'LShift')or string.format('%.1fs',r.od/30))
     Isaac.RenderText(text,pos.X-55,pos.Y-53,1,.85,.25,1)
    end
    if view.activeHeld then
     local progress=view.pending and 'queued' or tostring(view.count or 0)
     Isaac.RenderText('INPUT '..table.concat(view.history or {},' ')..' '..progress,pos.X-55,pos.Y-40,.8,.9,1,1)
    end
    if f and f.untilTick>=api.clock then Isaac.RenderText(f.text,pos.X-45,pos.Y-66,f.success and .2 or 1,f.success and 1 or .4,.2,1)end
   end
  end
 end)
 for _,name in ipairs({'MC_POST_NEW_ROOM','MC_POST_NEW_LEVEL'})do add(name,100,function()if api.active then api:Reset(name);save()end end)end
 add('MC_POST_GAME_STARTED',100,function(_,continued)
  local acquired=earlyAcquisitions;earlyAcquisitions={}
  if not api.active then return end;api:Reset('start');lastFrame=-1;runSeed=nil;inRun=true
  if not continued then root().motionCombat=nil;root().motionCombatHourglass=nil end
  snapshots=C.Clone(root().motionCombatHourglass or {})
  if not continued then for _,p in pairs(acquired)do api:OnAcquire(p,'circle_720')end end
 end)
 add('MC_PRE_GAME_EXIT',100,function()if api.active then api:Reset('exit');save();inRun=false end end)
 add('MC_POST_GLOWING_HOURGLASS_SAVE',100,function(_,slot)
  if not api.active then return end;snapshots[tostring(slot)]=api:Capture();root().motionCombatHourglass=C.Clone(snapshots);dirty=true;save()
 end)
 add('MC_POST_GLOWING_HOURGLASS_LOAD',100,function(_,slot)
  if not api.active then return end;api:Reset('hourglass');api:Restore(snapshots[tostring(slot)]);save()
 end)
 add('MC_PRE_MOD_UNLOAD',100,function(_,unloaded)if unloaded==mod then api:Shutdown()end end)
 mod.MotionCombat=api;return api
end
