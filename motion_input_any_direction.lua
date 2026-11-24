-- Independent DP item: horizontal mirroring only, preserving the proven
-- matcher/window/buffer. Up/down never become forward; only one side commits.
return function(C)
 local A={};local bases={{'right',1,0,1},{'left',-1,0,-1}}
 local keys={{1,-1,0},{2,1,0},{4,0,-1},{8,0,1}}
 local function sample(input,c)
  local s={};for k,v in pairs(input)do s[k]=v end
  local mask=0
  for _,key in ipairs(keys)do if (input.moveMask or 0)&key[1]~=0 then
   local x=key[2]*c.x+key[3]*c.y;local y=(-key[2]*c.y+key[3]*c.x)*c.hand
   mask=mask|(x<0 and 1 or x>0 and 2 or y<0 and 4 or 8)
  end end
  s.moveMask=mask;s.shootMask=0;s.headFacing='right';s.lastShotFacing='right';return s
 end
 local function sync(s,input,winner)
  for _,c in ipairs(s.candidates)do if c~=winner then
   C.Reset(c.core,sample(input,c),'direction_commit');c.core.serial=s.serial
   c.core.needsNeutral=winner.core.needsNeutral;c.core.rearmAt=winner.core.rearmAt;c.core.waitChange=winner.core.waitChange
  end end
  s.pending=winner.core.pending;s.leader=winner;s.pendingOwner=s.pending and winner or nil
 end
 local function events(s,c,output)
  for _,e in ipairs(output)do e.facing=c.facing end
  s.serial=c.core.serial;s.lastShotFacing=c.facing;s.leader=c;s.pending=c.core.pending
  return output
 end
 function A.New(input)
  local s={serial=0,sequence=input.sequence or 0,time=input.time or 0,candidates={},lastShotFacing=input.lastShotFacing=='left'and 'left'or 'right'}
  for _,b in ipairs(bases)do
   local c={facing=b[1],x=b[2],y=b[3],hand=b[4]};c.core=C.New(sample(input,c));s.candidates[#s.candidates+1]=c
  end
  s.leader=s.candidates[1];return s
 end
 function A.Step(s,input)
  if type(input.time)~='number'or type(input.sequence)~='number'or input.sequence<=s.sequence then return {}end
  if input.time<s.time then
   local serial=s.serial;local fresh=A.New(input);for k in pairs(s)do s[k]=nil end;for k,v in pairs(fresh)do s[k]=v end;s.serial=serial;return {}
  end
  s.sequence=input.sequence;s.time=input.time
  if s.pendingOwner then
   local c=s.pendingOwner;local out=events(s,c,C.Step(c.core,sample(input,c)))
   s.pending=c.core.pending;if not s.pending then sync(s,input,c)end
   return out
  end
  local best,bestCount,out=s.leader,-1,{}
  for _,c in ipairs(s.candidates)do
   c.core.serial=s.serial
   local output=C.Step(c.core,sample(input,c))
   for _,e in ipairs(output)do if e.kind~='progress'then
    events(s,c,output);sync(s,input,c);return output
   end end
   local count=C.View(c.core).count
   if count>bestCount then best,bestCount,out=c,count,output end
  end
  s.leader=best;for _,e in ipairs(out)do e.facing=best.facing end;return out
 end
 function A.View(s)
  local v=C.View(s.leader.core);v.facing=s.leader.core.attempt and s.leader.facing or s.lastShotFacing;v.serial=s.serial;return v
 end
 return A
end
