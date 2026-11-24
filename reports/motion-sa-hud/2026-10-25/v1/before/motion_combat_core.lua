-- Approved combat values and pure geometry; no native objects or callbacks.
local C={OD_COOLDOWN=180,ENERGY_PER_BAR=30,MAX_ENERGY=90,BOSS_ANTIGRAB=90}
local definitions={
 wave={normal={damage=1,duration=14,sourceFrames=66,radius=10,speed=10,range=260,spawn=6}},
 dp={normal={damage=2,duration=30,sourceFrames=78,length=48,radius=18,windows={{6,15}}},
     od={damage={2,3},duration=50,sourceFrames=78,length=56,radius=20,windows={{6,12},{22,32}}}},
 circle_360={normal={damage=4,duration=36,sourceFrames=108,reach=16,grab=6,slam=24,release=26},
             od={damage=6,duration=48,sourceFrames=108,reach=24,grab=6,slam=34,release=36}},
 circle_720={normal={damage=30,splash=10,duration=394,sourceFrames=394,grab=0,slam=261,release=289}},
}
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
local maps={
 wave={normal={{0,5,0,16},{6,13,35,65}}},
 dp={normal={{0,5,0,17},{6,15,18,42},{16,29,43,77}},od={{0,5,0,17},{6,12,18,29},{13,21,30,37},{22,32,38,53},{33,49,54,77}}},
 circle_360={normal={{0,5,0,17},{6,21,18,65},{22,25,66,78},{26,35,79,107}},od={{0,5,0,17},{6,29,18,65},{30,35,66,78},{36,47,79,107}}},
}
function C.SourceFrame(move,variant,t)
 local def=C.Definition(move,variant);t=math.max(0,math.min(def.duration-1,t))
 if move=='circle_720'then return t end
 for _,s in ipairs(maps[move][variant])do
  if t<=s[2]then return math.floor(s[3]+(s[4]-s[3])*(t-s[1])/math.max(1,s[2]-s[1])+.5)end
 end
end
return C
