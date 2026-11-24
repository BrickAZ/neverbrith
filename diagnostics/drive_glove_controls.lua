-- Isolated native operation regression; loaded only by the acceptance runner.
return function(mod)
 local started,age,checks,failures=false,0,0,0
 local inputs,warp,warped={},false,nil
 local baselineRelease,baselineEmit,baselineArmed
 local silentShots,measureSilent=0,false
 local function log(s)Isaac.DebugString('[Drive Glove runtime] '..s)end
 local function check(name,ok,detail)
  checks=checks+1;if not ok then failures=failures+1 end
  log((ok and 'PASS ' or 'FAIL ')..name..' '..tostring(detail or ''))
 end
 local raw=Input.GetActionValue
 Input.GetActionValue=function(a,c)
  if started and c==Isaac.GetPlayer(0).ControllerIndex then return inputs[a] or 0 end
  return raw(a,c)
 end
 mod:AddPriorityCallback(ModCallbacks.MC_INPUT_ACTION,900000,function(_,_,hook,a)
  if started then return hook==InputHook.GET_ACTION_VALUE and (inputs[a] or 0) or (inputs[a] or 0)>0 end
 end)
 local function reset()
  local p=Isaac.GetPlayer(0)
  if mod.RingOfSevenCursesTestAPI then
   mod.RingOfSevenCursesTestAPI.ResetForTest();p:RemoveCollectible(mod.RingOfSevenCursesTestAPI.ItemId)
  end
  if not p:HasCollectible(mod.DriveGlove.ItemId) then p:AddCollectible(mod.DriveGlove.ItemId,0,true,0) end
  local s,t=mod.DriveGlove.GetState(p);mod.DriveGlove.Core.End(t,'probe')
  s.gauge=6;s.burnout=false;t.reward=nil;t.gift=nil;t.grantCharge=nil;t.events={};t.cacheDirty=true
  t.needsRelease=false;t.lastTick=nil;t.pressedActions={};t.lastPressed=false;t.inputHeld=false
  t.action=ButtonAction.ACTION_ITEM;t.rushShot=nil;inputs={}
  p.Position=Game():GetRoom():GetCenterPos()+Vector(-120,0);p.Velocity=Vector(0,0)
  p:ResetDamageCooldown();p:SetDamageCountdown(0)
  return p,s,t
 end
 mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,0,function(_,p)
  if not warp then return end
  local _,t=mod.DriveGlove.GetState(p)
  if t.mode=='rush' and t.planned then
   warped=p.Position+Vector(0,20);p.Position=warped;warp=false
  end
 end)
 mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_WEAPON_FIRED,function(_,_,n,e)
  if measureSilent and n>0 and e and e:ToPlayer() then silentShots=silentShots+n end
  if baselineArmed and n>0 and e and e:ToPlayer() and not baselineEmit then baselineEmit=Game():GetFrameCount() end
 end)
 mod:AddCallback(ModCallbacks.MC_POST_WEAPON_FIRE,function(_,w,_,fire,interp)
  if baselineArmed and not fire and not interp and not baselineRelease then baselineRelease=Game():GetFrameCount() end
 end)
 mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
  if not started then started=true;log('START controls');Isaac.StartNewGame(0,0,0,123456789) end
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,900000,function()
  age=age+1;local p=Isaac.GetPlayer(0);local s,t=mod.DriveGlove.GetState(p)
  if age==100 then reset();inputs={[ButtonAction.ACTION_ITEM]=1}
  elseif age==101 then
   check('active starts immobile blue',t.mode=='blue' and p.Velocity:Length()==0)
   local hearts=p:GetHearts();p:TakeDamage(1,DamageFlag.DAMAGE_NO_MODIFIERS,EntityRef(nil),0)
   check('sourceless perfect keeps health and center effect',p:GetHearts()==hearts and t.successAt==Game():GetFrameCount() and t.impactKind=='Center')
   inputs={}
  elseif age==102 then check('success release exits immediately',t.mode=='idle');inputs={[ButtonAction.ACTION_ITEM]=1}
  elseif age==103 then check('next-frame fresh active reenters blue',t.mode=='blue');inputs={}
  elseif age==125 then reset();inputs={[ButtonAction.ACTION_ITEM]=1}
  elseif age==126 then inputs={}
  elseif age==132 then check('whiff enters recovery',t.mode=='recovery')
  elseif age==144 then check('12f recovery ended',t.mode=='idle');inputs={[ButtonAction.ACTION_ITEM]=1}
  elseif age==145 then check('fresh active immediately after recovery works',t.mode=='blue');inputs={}
  elseif age==165 then reset();inputs={[ButtonAction.ACTION_ITEM]=1,[ButtonAction.ACTION_RIGHT]=1}
  elseif age==166 then check('single direction starts rush',t.mode=='startup')
  elseif age==173 then warp=true
  elseif age==174 then
   check('short external displacement ends rush',t.mode=='idle' and t.reason=='takeover')
   check('external 20-unit position survives',warped and (p.Position-warped):Length()<.01)
   inputs={}
  elseif age==190 then
   reset();inputs={[ButtonAction.ACTION_ITEM]=1}
  elseif age==191 then
   p:TakeDamage(1,DamageFlag.DAMAGE_SPIKES,EntityRef(nil),0)
   check('floor blue feedback selected',t.impactKind=='Floor');inputs={}
  elseif age==215 then
   reset();p:RemoveCollectible(mod.DriveGlove.ItemId);p:AddCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE)
  elseif age==220 then
   local w=p:GetWeapon(1);w:SetCharge(include('drive_glove_weapon').Full(w));w:SetFireDelay(0)
   inputs={[ButtonAction.ACTION_SHOOTUP]=1}
  elseif age==222 then baselineArmed=true;inputs={}
  elseif age==235 then
   local delay=baselineEmit and baselineRelease and baselineEmit-baselineRelease
   log('NATIVE_BRIMSTONE release='..tostring(baselineRelease)..' emission='..tostring(baselineEmit)..' windup='..tostring(delay))
   check('native full brimstone has 4f launch windup',delay==4)
   baselineArmed=false
   for _,path in ipairs({'gfx/Effects/DriveDefense/v1/drive_defense_back.anm2','gfx/Effects/DriveDefense/v1/drive_defense_front.anm2'}) do
    local sprite=Sprite();sprite:Load(path,true)
    for _,anim in ipairs({'Guard','Parry','ParryFloor','ParryCenter','PerfectParry','PerfectParryFloor','PerfectParryCenter'}) do
     local data=sprite:GetAnimationData(anim)
     check(path..' '..anim,data~=nil and data:GetName()==anim)
    end
   end
  elseif age==240 then
   reset();p:RemoveCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE);p:AddCollectible(CollectibleType.COLLECTIBLE_CURSED_EYE)
  elseif age==245 then
   measureSilent=true;inputs={[ButtonAction.ACTION_ITEM]=1,[ButtonAction.ACTION_RIGHT]=1}
  elseif age==273 then
   check('full charge gift alone never fires',silentShots==0,silentShots)
   check('no fire leaves shooting reward pending',t.reward and t.reward.started==nil)
   check('no fire permits full rush distance',t.reason=='distance' and t.moveFrames==18)
   measureSilent=false;inputs={};log('DONE checks='..checks..' failures='..failures)
  end
 end)
end
