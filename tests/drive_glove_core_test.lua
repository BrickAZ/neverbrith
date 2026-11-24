local C = dofile('drive_glove_core.lua')
local n = 0
local function ok(v, label) assert(v, label); n = n + 1 end
local function near(a,b,label) ok(math.abs(a-b)<1e-7,label) end
local function pair(g) return {gauge=g or 6,burnout=false},C.Runtime() end
local function step(s,t,f,held,x,y) C.Tick(s,t,f,{held=held,x=x or 0,y=y or 0},true) end
do
 local s,t=pair(.5); ok(not C.StartBlue(s,t,10),'exact .5 cannot parry'); ok(s.burnout and t.mode=='idle','no recovery for failed start')
 s,t=pair(.51); ok(C.StartBlue(s,t,10),'above .5 starts'); step(s,t,11,true); ok(s.burnout and t.mode=='recovery','drain forces recovery')
end
do
 local s,t=pair(); C.StartBlue(s,t,0)
 ok(C.Parry(s,t,2)=='PerfectParry','third frame perfect'); near(s.gauge,6,'perfect refills')
 step(s,t,7,false); ok(t.mode=='idle','S+5 release free')
 s,t=pair(); C.StartBlue(s,t,0); C.Parry(s,t,2); step(s,t,8,false)
 ok(t.mode=='recovery','S+6 expired'); step(s,t,19,false); ok(t.mode=='recovery','12f last locked'); step(s,t,20,false); ok(t.mode=='idle','12f complete')
 s,t=pair(); C.StartBlue(s,t,0); C.Parry(s,t,0); step(s,t,1,false); ok(t.mode=='idle','success bypasses min hold')
 s,t=pair(); C.StartBlue(s,t,0); step(s,t,1,false); ok(t.mode=='blue','whiff early release waits'); step(s,t,6,false); ok(t.mode=='recovery','whiff minimum 6')
 s,t=pair(); C.StartBlue(s,t,0); ok(C.Parry(s,t,3)=='Parry','fourth frame ordinary')
 C.Parry(s,t,8); step(s,t,13,false); ok(t.mode=='idle','later parry refreshes exit')
end
do
 local s,t=pair(.5); C.Guard(s,t,2); ok(s.burnout and s.gauge==0,'last guard can overdraw')
 s,t=pair(); C.StartBlue(s,t,0); s.gauge=.5; ok(C.StartRush(s,t,1,1,0),'exact rush payment allowed')
 ok(s.burnout and t.mode=='startup' and not t.reward,'paid rush survives burnout')
 for f=1,5 do step(s,t,f,true,-1,0); ok(t.mode=='startup','five startup ticks') end
 step(s,t,6,true,-1,0); ok(t.mode=='rush' and t.moveFrames==0,'movement starts after stop')
 for f=6,9 do local d=C.RushStep(t,-1,0); near(d,260/18,'early reverse keeps speed'); C.CommitMove(t,d) end
 near(t.heading,0,'early reverse cannot turn'); ok(C.RushStep(t,-1,0)==nil and t.mode=='idle','brake before fifth move')
end
do
 local s,t=pair(); C.StartBlue(s,t,0); C.StartRush(s,t,1,1,0); step(s,t,6,true)
 for i=1,6 do local d=C.RushStep(t,0,1); C.CommitMove(t,d) end
 near(t.heading,90,'90 degree turn in six'); near(t.remaining,260-6*260/18,'curved path spends same budget')
 while t.mode=='rush' do local d=C.RushStep(t,0,0); C.CommitMove(t,d) end
 ok(t.moveFrames==18,'horizontal curved budget 18 steps')
 near(C.Budget(0,1),140,'vertical'); near(C.Budget(1,1),140*math.sqrt(2),'diagonal')
 s,t=pair(); C.StartBlue(s,t,0); s.gauge=.49; ok(not C.StartRush(s,t,1,1,0),'failed rush'); ok(s.burnout and t.mode=='recovery','failed rush recovery')
end
do
 local s,t=pair(); C.StartBlue(s,t,10); step(s,t,10,true,1,0)
 ok(t.mode=='startup' and t.rushAt==10,'single direction enters rush on the same tick')
 near(s.gauge,5,'same-tick blue and rush charge exactly once')
 step(s,t,11,true,1,0);near(s.gauge,5,'holding direction cannot repay rush')
 s,t=pair();C.StartBlue(s,t,10);step(s,t,10,true,.1,.1)
 ok(t.mode=='blue','stick noise does not trigger rush')
 step(s,t,11,true,.3,.4)
 ok(t.mode=='startup','analog direction triggers without double tap')
 near(t.heading,math.deg(math.atan(.4,.3)),'analog initial heading is not quantized')
end
do
 local s,t=pair(); C.GrantReward(s,t,1); local r=t.reward; C.GrantReward(s,t,20); ok(t.reward==r,'oldest reward wins')
 C.Shot(s,t,100); ok(t.reward.started==100,'timer starts on shot'); C.Shot(s,t,120); ok(t.reward.started==100,'multi shot no restart')
 step(s,t,189,false); ok(t.reward~=nil,'90th reward tick'); step(s,t,190,false); ok(t.reward==nil,'reward expires')
 C.GrantReward(s,t,200); C.SetGauge(s,t,0,'Spend'); ok(not t.reward and s.burnout,'burnout cancels reward')
 for i=1,599 do C.Regen(s,t,false) end; ok(s.burnout,'burnout 599 ticks'); C.Regen(s,t,false); near(s.gauge,6,'20s full'); ok(not s.burnout,'burnout ends at full')
 s,t=pair(0); s.burnout=true; for i=1,400 do C.Regen(s,t,true) end; near(s.gauge,6,'walking 13.333s')
 s,t=pair(1); for i=1,300 do C.Regen(s,t,false) end; near(s.gauge,2,'normal 10s one bar')
 for i=1,200 do C.Regen(s,t,true) end; near(s.gauge,3,'walking 50 percent bonus')
end
ok(C.GuardDirection(1,0,1,1),'45 inclusive'); ok(not C.GuardDirection(1,0,0,1),'90 cannot guard')
ok(not C.GuardDirection(0,0,1,0),'no input cannot guard')
do
 local root={}; ok(C.Record(root,1,'a',false)==nil,'no acquisition no record')
 local s=C.Record(root,1,'a',true); near(s.gauge,6,'first pickup full')
 s.gauge=.75;s.burnout=true
 ok(C.Record(root,1,'a',false)==s,'removal retains record')
 near(C.Record(root,1,'a',true).gauge,.75,'same run reacquire preserves gauge')
 near(C.Record(root,1,'b',true).gauge,6,'second player separate')
 near(C.Record(root,2,'a',true).gauge,6,'new run new full record')
 local x,t=pair();C.StartBlue(x,t,0);step(x,t,0,true,0,0);step(x,t,1,true,1,1)
 ok(t.mode=='startup','one diagonal direction starts rush')
end
do
 local s,t=pair();C.SetGauge(s,t,0);C.SetGauge(s,t,0);C.SetGauge(s,t,3);C.SetGauge(s,t,6);C.SetGauge(s,t,6)
 local enter,exit=0,0
 for _,e in ipairs(t.events) do
  if e.kind=='BurnoutEnter' then enter=enter+1 elseif e.kind=='BurnoutExit' then exit=exit+1 end
 end
 ok(enter==1 and exit==1,'burnout audio events belong only to state transitions')
 s,t=pair();C.StartBlue(s,t,0);C.Parry(s,t,0);C.Parry(s,t,1)
 for _,e in ipairs(t.events) do ok(e.kind~='BurnoutExit','perfect refill is not burnout recovery') end
end
print('Drive Glove core: '..n..' assertions passed')
