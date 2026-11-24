local count=0
local function check(v,m)assert(v,m);count=count+1 end
local exists=io.open('motion_combat_core.lua','r');check(exists~=nil,'real combat core is missing');exists:close()
local C=dofile('motion_combat_core.lua')
check(C.Definition('wave','normal').damage==1,'wave confirmed damage')
check(C.Definition('dp','od').damage[2]==3,'OD second stage damage')
check(C.Definition('circle_360','normal').damage==3,'ordinary 360 now deals three times panel damage')
check(C.Definition('circle_360','od').damage==6,'OD360 keeps six times primary damage')
for _,variant in ipairs({'normal','od'})do
 local d=C.Definition('circle_360',variant)
 check(d.splash==3 and d.splashRadius==80,'both 360 variants have confirmed 80-unit three-times landing splash')
end
check(C.Definition('circle_720','normal').damage==15 and C.Definition('circle_720','normal').splash==10,'latest 720 correction is fifteen primary and ten room damage')
check(C.Definition('circle_360','normal').duration==54,'user confirmed slower 1.8s 360')
check(C.Definition('circle_360','normal').grab==6 and C.Definition('circle_360','normal').slam==42,'360 keeps startup and delays real slam with picture')
check(C.SourceFrame('circle_360','normal',42)==73 and C.SourceFrame('circle_360','od',34)==73,'both real slam ticks match authored contact frame')
check(C.Definition('circle_720','od')==nil,'720 has one version only')
check(C.Definition('circle_720','normal').duration==394,'V9 full length')
check(C.Definition('wave','od')==nil,'only one wave')
check(C.SegmentDistance(5,2,0,0,10,0)==2,'swept projectile distance')
check(C.SegmentDistance(12,0,0,0,10,0)==2,'endpoint distance')
check(C.InCone(10,0,1,0,30) and not C.InCone(-10,0,1,0,30),'front cone excludes rear')
for _,move in ipairs({'wave','dp','circle_360','circle_720'}) do
 for _,variant in ipairs({'normal','od'}) do
  local d=C.Definition(move,variant)
  if d then
   local previous=-1
   for t=0,d.duration-1 do local f=C.SourceFrame(move,variant,t);check(f>=previous and f>=0 and f<d.sourceFrames,'combat animation monotonic and bounded');previous=f end
   check(previous==d.sourceFrames-1,'combat reaches source final frame')
  end
 end
end
local root={};local a=C.Record(root,42,'one');local b=C.Record(root,42,'two')
C.Gain(a,95);check(a.energy==90 and b.energy==0,'per-player capped energy')
a.od=130;local copy=C.Clone(root.motionCombat);a.energy=0
check(copy.players.one.energy==90 and copy.players.one.od==130,'snapshot is plain deep copy')
check(C.Record(root,43,'one').energy==0,'new run resets meter')
print('motion_combat_core: '..count..' assertions passed')
