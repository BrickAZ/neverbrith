-- Owned hidden diagnostic only: normal Haunt room and normal enemy AI.
return function(mod,options)
 local game=Game();local phase='menu';local boot,passed,failed=0,0,0;local at=0;local sa,spd;local victim,beforeHP;local original=Input.GetActionValue
 local function log(s)Isaac.DebugString('[Motion runtime probe] '..s)end
 local function check(name,ok)if ok then passed=passed+1 else failed=failed+1 end;log((ok and 'PASS 'or 'FAIL ')..name)end
 Input.GetActionValue=function(a,c)if phase~='menu'and phase~='done'then return 0 end;return original(a,c)end
 mod:AddPriorityCallback(ModCallbacks.MC_INPUT_ACTION,-9999999,function(_,_,hook)
  if phase~='menu'and phase~='done'then return hook==InputHook.GET_ACTION_VALUE and 0 or false end
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,-9999999,function()if phase~='menu'and phase~='done'then return false end end)
 mod:AddCallback(ModCallbacks.MC_PRE_RENDER,function()
  if phase~='menu'then return end;boot=boot+1;if boot<5 then return end
  phase='starting';log('START attempt='..options.Attempt..' natural-AI-probe=true');Isaac.StartNewGame(0,0,0,31415926)
 end)
 mod:AddPriorityCallback(ModCallbacks.MC_POST_GAME_STARTED,9999999,function()
  local p=Isaac.GetPlayer(0);sa=Isaac.GetItemIdByName('720');spd=Isaac.GetItemIdByName('360')
  for _,e in ipairs(Isaac.GetRoomEntities())do if e.Type==EntityType.ENTITY_PICKUP then e:Remove()end end
  p:AddCollectible(sa,0,false);phase='enter';at=game:GetFrameCount()+20
 end)
 local function dump(label)
  local p=Isaac.GetPlayer(0);local count=0
  for _,e in ipairs(Isaac.GetRoomEntities())do local n=e:ToNPC();if n then
   count=count+1;log('NATURAL '..label..' type='..n.Type..'.'..n.Variant..' state='..n.State..' hp='..n.HitPoints
    ..' enemy='..tostring(n:IsEnemy())..' active='..tostring(n:IsActiveEnemy(false))..' vulnerable='..tostring(n:IsVulnerableEnemy())
    ..' boss='..tostring(n:IsBoss())..' collision='..n.EntityCollisionClass..' flags='..tostring(n:GetEntityFlags())..' distance='..(n.Position-p.Position):Length()
    ..' size='..n.Size..' playerSize='..p.Size)
  end end
  return count
 end
 local function cast(move,id)
  local p=Isaac.GetPlayer(0);local result=mod.MotionCombat:Execute(p,move,{serial=game:GetFrameCount()+1,facing='right'},{id=id,owner='natural-probe'})
  local s=mod.MotionCombat:GetState(p)
  if move=='circle_360'and result.ok then victim=s.target;beforeHP=victim.HitPoints end
  log('NATURAL_CAST '..move..' ok='..tostring(result.ok)..' reason='..tostring(result.reason)..' target='..tostring(s.target and s.target.Type)..' grabbed='..tostring(s.grabbed))
 end
 mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,9999999,function()
  local now=game:GetFrameCount();if phase=='menu'or phase=='starting'or phase=='done'or now<at then return end
  local p=Isaac.GetPlayer(0)
  if phase=='enter'then
   Isaac.ExecuteCommand('goto s.boss.5012');phase='observe';at=now+90
  elseif phase=='observe'then
   check('real-room-enemies-observed',dump('phase1')>0);cast('circle_720',sa);phase='cancel1';at=now+10
  elseif phase=='cancel1'then
   mod.MotionCombat:Reset('natural probe phase')
   for _,e in ipairs(Isaac.GetRoomEntities())do local n=e:ToNPC();if n and not n:IsBoss()and n:IsEnemy()then n:Kill()end end
   phase='phase2';at=now+120
  elseif phase=='phase2'then
   dump('phase2');mod.MotionCombat:GetRecord(p).energy=90;cast('circle_720',sa);phase='cancel2';at=now+10
  elseif phase=='cancel2'then
   mod.MotionCombat:Reset('natural probe close');p:RemoveCollectible(sa);p:AddCollectible(spd,0,false)
   for _,e in ipairs(Isaac.GetRoomEntities())do local n=e:ToNPC();if n and n:IsVulnerableEnemy()and n:IsActiveEnemy(false)then
    p.Position=n.Position+Vector(-28,0);break
   end end
   dump('close');cast('circle_360',spd);phase='grabcheck';at=now+8
  elseif phase=='grabcheck'then
   local s=mod.MotionCombat:GetState(p);log('NATURAL_360_CONTACT grabbed='..tostring(s.grabbed)..' feedback='..tostring(s.feedback and s.feedback.text))
   dump('aftercontact');check('normal-AI-startup-target-kept',s.grabbed);phase='slamcheck';at=now+36
  elseif phase=='slamcheck'then
   check('normal-AI-real-slam-damage',victim and victim:Exists()and victim.HitPoints<beforeHP)
   log('NATURAL_DAMAGE before='..tostring(beforeHP)..' after='..tostring(victim and victim:Exists()and victim.HitPoints))
   mod.MotionCombat:Reset('natural probe done');phase='done';Input.GetActionValue=original
   check('natural-AI-probe-completed',true);log('SUMMARY checks='..passed..' passed fail='..failed..' cases=1')
   for _=1,48 do log('DONE '..string.rep('.',1024))end
  end
 end)
end
