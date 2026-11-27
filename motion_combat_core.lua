-- Approved combat values and pure geometry; no native objects or callbacks.
local C={OD_COOLDOWN=180,ENERGY_PER_BAR=30,MAX_ENERGY=90,BOSS_ANTIGRAB=90}
-- Read-only specifications, loaded once with this core and passed to bindings
-- through the existing combat instance. Values and timing stay item-owned.
C.Specifications={
 include('scripts/features/motion_items/piledriver_360'),
 include('scripts/features/motion_items/ultimate_720'),
 include('scripts/features/motion_items/motion_wave'),
 include('scripts/features/motion_items/dragon_punch'),
}
local definitions,maps,directFrames={},{},{}
for _,spec in ipairs(C.Specifications)do
 definitions[spec.key]=spec.combat;maps[spec.key]=spec.frames;directFrames[spec.key]=spec.directFrames
end
function C.Definition(move,variant)return definitions[move] and definitions[move][variant]end
function C.Clone(v)if type(v)~='table'then return v end;local c={};for k,x in pairs(v)do c[k]=C.Clone(x)end;return c end
function C.Record(root,seed,key)
 if type(root.motionCombat)~='table' or root.motionCombat.seed~=tostring(seed) then root.motionCombat={seed=tostring(seed),players={}} end
 local records=root.motionCombat.players
 if not records[key]then records[key]={energy=0,od=0}end
 local r=records[key];r.energy=math.max(0,math.min(90,tonumber(r.energy)or 0));r.od=math.max(0,math.min(180,tonumber(r.od)or 0))
 return r
end
function C.Gain(record,damage)record.energy=math.min(90,record.energy+math.max(0,damage))end
function C.SegmentDistance(x,y,ax,ay,bx,by)
 local dx,dy=bx-ax,by-ay;local length=dx*dx+dy*dy
 local t=length>0 and math.max(0,math.min(1,((x-ax)*dx+(y-ay)*dy)/length))or 0
 return math.sqrt((x-ax-t*dx)^2+(y-ay-t*dy)^2),t
end
function C.InCone(x,y,fx,fy,reach)
 local distance=math.sqrt(x*x+y*y)
 return distance<=reach and (distance==0 or (x*fx+y*fy)/distance>=.5)
end
function C.SourceFrame(move,variant,t)
 local def=C.Definition(move,variant);t=math.max(0,math.min(def.duration-1,t))
 if directFrames[move]then return t end
 for _,s in ipairs(maps[move][variant])do
  if t<=s[2]then return math.floor(s[3]+(s[4]-s[3])*(t-s[1])/math.max(1,s[2]-s[1])+.5)end
 end
end
return C
