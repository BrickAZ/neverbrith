-- Owned hidden-game test only. No OS input; never included by normal bootstrap.
return function(mod,options)
 local game=Game();local phase='menu';local boot,passed,failed=0,0,0
 local values={};local waveId,saId,target;local started,fullAt,castAt,hideAt,removedAt;local observed={};local marker
 local function log(s)Isaac.DebugString('[Motion runtime probe] '..s)end
 local function check(name,v,detail)
  if v then passed=passed+1 else failed=failed+1 end
  log((v and 'PASS 'or 'FAIL ')..name..' '..tostring(detail or ''))
 end
 local function signal(stage)
  if stage==marker then return end;marker=stage
  if io and io.open then
   local good,f=pcall(io.open,options.ReportPath..'/stage.txt','w')
   if good and f then f:write(stage);f:close()end
  end
  log('HUD_STAGE '..stage)
 end
 local native=Input.GetActionValue
 Input.GetActionValue=function(action,controller)if phase~='menu'and phase~='starting'and phase~='done'then return values[action]or 0 end;return native(action,controller)end
 mod:AddPriorityCallback(ModCallbacks.MC_INPUT_ACTION,-9999999,function(_,_,hook)
  if phase~='menu'and phase~='starting'and phase~='done'then return hook==InputHook.GET_ACTION_VALUE and 0 or false end
 end)
 mod:AddCallback(ModCallbacks.MC_PRE_RENDER,function()
  if phase~='menu'then return end;boot=boot+1;if boot<5 then return end
  phase='starting';log('START attempt='..options.Attempt..' version='..REPENTOGON.Version..' original-SA-HUD=true')
  Isaac.StartNewGame(0,0,0,31415926)
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_EVALUATE_CACHE,9999999,function(_,p,flag)if phase~='menu'and flag==CacheFlag.CACHE_DAMAGE then p.Damage=10 end end)
 mod:AddPriorityCallback(ModCallbacks.MC_POST_GAME_STARTED,9999999,function()
  for _,e in ipairs(Isaac.GetRoomEntities())do if e.Type==EntityType.ENTITY_PICKUP then e:Remove()end end
  local p=Isaac.GetPlayer(0)
  waveId=Isaac.GetItemIdByName('Wave');if waveId<0 then waveId=Isaac.GetItemIdByName('波动')end
  saId=Isaac.GetItemIdByName('720')
  p:AddCollectible(waveId,0,false);p:AddCacheFlags(CacheFlag.CACHE_DAMAGE);p:EvaluateItems()
  target=Isaac.Spawn(EntityType.ENTITY_GAPER,0,0,p.Position+Vector(70,0),Vector(0,0),nil):ToNPC()
  target.MaxHitPoints=2000;target.HitPoints=2000;target:GetData().NeverbirthSAProbe=true
  target:AddEntityFlags(EntityFlag.FLAG_NO_KNOCKBACK|EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
  phase='gain';started=game:GetFrameCount();check('formal-wave-held',p:GetActiveItem(0)==waveId)
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_PRE_NPC_UPDATE,-999999,function(_,n)
  if n:GetData().NeverbirthSAProbe and not mod.MotionCombat.grabs[tostring(GetPtrHash(n))..':'..tostring(n.InitSeed)]then n.Velocity=Vector(0,0);return true end
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,-9999999,function(_,p)
  values={};local now=game:GetFrameCount()
  if phase=='gain'then
   values[ButtonAction.ACTION_ITEM]=1
   local t=now-started
   if t>=20 and(t-20)%30<2 then values[ButtonAction.ACTION_SHOOTRIGHT]=1 end
  elseif phase=='full'and now-fullAt>=35 then
   check('ready-from-real-attacks',math.abs(target.HitPoints-1910)<.01,target.HitPoints)
   p:RemoveCollectible(waveId);p:AddCollectible(saId,0,false);started=now;phase='command'
  elseif phase=='command'then
   local t=now-started
   if t>=1 and t<=3 then values[ButtonAction.ACTION_SHOOTRIGHT]=1 end
   if t>=5 and t<35 then values[ButtonAction.ACTION_ITEM]=1 end
   local dirs={5,7,4,6,5,7,4,6};local step=math.floor((t-8)/2)+1
   if step>=1 and step<=8 then values[dirs[step]]=1 end
  end
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,9999999,function()
  if phase=='menu'or phase=='starting'or phase=='done'then return end
  local p=Isaac.GetPlayer(0);local combat=mod.MotionCombat;local now=game:GetFrameCount();local view=mod.MotionSAHUD:GetState(p)
  if view and view.error and not observed.error then observed.error=true;check('native-resource-load',false,view.error)end
  if phase=='gain'and view then
   for _,level in ipairs({0,1,2})do if view.level==level then observed['level'..level]=true end end
   if view.energy>0 and view.energy<30 then observed.partial=true end
   if view.energy==90 then
    fullAt=now;phase='full';check('actual-meter-full',combat:GetRecord(p).energy==90)
    check('actual-damage-to-meter',math.abs(target.HitPoints-1910)<.01,target.HitPoints)
    check('full-level-3-fill-1',view.level==3 and view.fill==1)
   end
  elseif phase=='command'and combat:IsBusy(p)then
   castAt=now;phase='spend';check('real-720-spends-now',combat:GetRecord(p).energy==0)
   local art=mod.MotionPresentation:GetState(p);check('V9-retained',art and art.version=='v9'and art.frames==394)
  elseif phase=='spend'and now-castAt>=15 then target:Remove();phase='refund'
  elseif phase=='refund'and not combat:IsBusy(p)and view and view.energy==90 then
   check('real-interruption-refund',combat:GetRecord(p).energy==90 and view.level==3 and view.fill==1)
   phase='refund_wait';hideAt=now+20
  elseif phase=='refund_wait'and now>=hideAt then
   observed.beforeHidden=view and view.renderedAt
   game:GetSeeds():AddSeedEffect(SeedEffect.SEED_NO_HUD);phase='hidden';hideAt=now
  elseif phase=='hidden'and now-hideAt>=6 then
   check('native-no-HUD-suppresses-SA',view and view.renderedAt==observed.beforeHidden)
   game:GetSeeds():RemoveSeedEffect(SeedEffect.SEED_NO_HUD);phase='unhidden';hideAt=now
  elseif phase=='unhidden'and now-hideAt>=6 then
   check('HUD-restores-without-resource-change',view and view.renderedAt>observed.beforeHidden and combat:GetRecord(p).energy==90)
   p:RemoveCollectible(saId);phase='removed';removedAt=now
  elseif phase=='removed'and now-removedAt>=3 then
   check('owner-loss-clears-HUD',mod.MotionSAHUD:GetState(p)==nil)
   check('HUD-did-not-change-meter',combat:GetRecord(p).energy==90)
   for _,name in ipairs({'empty','gain','full_enter','full_loop','spend','refund'})do check('rendered-'..name,observed[name])end
   for _,level in ipairs({0,1,2})do check('counter-level-'..level,observed['level'..level])end
   check('native-partial-progress',observed.partial)
   check('native-same-level-counter-steady',observed.sameLevelSteady)
   check('native-additive-animation-loaded',observed.resource)
   phase='done';Input.GetActionValue=native
   log('SUMMARY checks='..passed..' passed fail='..failed..' cases=1')
   for _=1,48 do log('DONE '..string.rep('.',1024))end
  end
  if now-(started or now)>650 and phase~='done'then
   check('test-completes',false,phase);phase='done';Input.GetActionValue=native
   log('SUMMARY checks='..passed..' passed fail='..failed..' cases=1')
   for _=1,48 do log('DONE '..string.rep('.',1024))end
  end
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_POST_RENDER,9999999,function()
  if phase=='menu'or phase=='starting'or phase=='done'then return end
  local p=Isaac.GetPlayer(0);local view=mod.MotionSAHUD:GetState(p)
  if not view or view.renderedAt~=game:GetFrameCount()then return end
  observed.resource=not view.error and view.resource=='gfx/UI/MotionSA/v1/sa_gauge.anm2'
  if phase=='gain'and observed.lastEnergy and view.energy>observed.lastEnergy and view.level>0
   and math.floor(observed.lastEnergy/30)==view.level then
   local name='Gain'..view.level
   observed.sameLevelSteady=(view.rendered[name]or 0)==(observed.lastDraws[name]or 0)
  end
  observed.lastEnergy=view.energy;observed.lastDraws=view.rendered
  if view.energy==0 and phase=='gain'then observed.empty=true;signal('empty')
  elseif phase=='gain'and view.energy>0 and view.energy<90 then observed.gain=true;signal('partial')
  elseif phase=='full'then observed[view.renderedPhase]=true;signal(view.renderedPhase)
  elseif phase=='spend'and view.renderedPhase=='spend'then observed.spend=true;signal('spend')
  elseif phase=='refund_wait'then observed.refund=true;signal('refund')end
  if not observed.position then
   observed.position=true;check('fixed-screen-position',view.position.X>10 and view.position.X<Isaac.GetScreenWidth()/2 and view.position.Y>Isaac.GetScreenHeight()/2)
  end
 end)
end
