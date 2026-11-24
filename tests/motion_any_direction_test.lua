local count=0;local function check(v,m)assert(v,m);count=count+1 end
local C=dofile('motion_input_core.lua');local path='motion_input_any_direction.lua'
local file=io.open(path);check(file~=nil,'independent-item direction recognizer is missing');file:close()
local A=dofile(path)(C)
local function rig()
 local input={time=0,sequence=0,activeHeld=false,moveMask=0,shootMask=0,headFacing='right',lastShotFacing='right',profile='dp',availability='ready'}
 local state=A.New(input);local events={}
 local function step(mask,active,availability,od)
  input.time=input.time+1/30;input.sequence=input.sequence+1;input.moveMask=mask;input.activeHeld=active~=false
  input.availability=availability or 'ready';input.odRequested=not not od
  for _,e in ipairs(A.Step(state,input))do if e.kind=='execute'then events[#events+1]=e end end
 end
 return state,input,events,step
end
local cases={
 {'right',{2,8,10}},{'left',{1,8,9}},{'right',{2,8,2}},
 {'left',{1,8,1}},{'right',{10,8,10}},{'left',{9,8,9}},
}
for _,case in ipairs(cases)do
 local s,input,events,step=rig()
 for _,mask in ipairs(case[2])do step(mask)end
 check(#events==1 and events[1].facing==case[1],'input determines '..case[1]..' independently of the stale right-facing head')
 step(case[2][#case[2]]);check(#events==1,'held directions never double-execute')
 check(s.serial==1,'one global serial despite parallel direction candidates')
end
for _,sequence in ipairs({{4,2,6},{8,2,10},{4,1,5},{8,1,9},{2,4,6},{1,4,5},{6,4,6},{5,4,5}})do
 local s,input,events,step=rig()
 for _,mask in ipairs(sequence)do step(mask)end
 check(#events==0,'up/down cannot become forward or replace the downward DP component')
end
local s,input,events,step=rig();step(1,true,'recovery',true);step(8,true,'recovery',true);step(9,true,'recovery',true)
check(#events==0 and A.View(s).pending,'mirrored command uses the existing recovery buffer')
step(0,true,'ready',false);check(#events==1 and events[1].facing=='left'and events[1].odRequested,'pending keeps direction and OD together')
for _=1,5 do step(0)end
step(2);step(8);step(10)
check(#events==2 and events[2].facing=='right'and events[2].serial==2,'opposite next direction works after neutral with unique serial')
local a,b,expired,nextStep=rig();nextStep(1);b.time=b.time+.61;nextStep(8);nextStep(9)
check(#expired==0,'free direction does not extend the approved 0.6-second DP window')
print('motion_any_direction: '..count..' assertions passed')
