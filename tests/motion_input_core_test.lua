local C = dofile('motion_input_core.lua')
local passed = 0
local failures = {}
local function check(v, label) assert(v, label); passed = passed + 1 end
local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then failures[#failures+1]=name .. ': ' .. tostring(err) end
end
local directions = {[1]=9,[2]=8,[3]=10,[4]=1,[6]=2,[7]=5,[8]=4,[9]=6,[5]=0}
local function rig(profile, facing)
    local sample = {time=0,sequence=0,activeHeld=false,moveMask=0,shootMask=0,headFacing=facing or 'right',profile=profile,availability='ready'}
    local state = C.New(sample)
    local all = {}
    local function step(t, move, shoot, active, availability)
        sample.time=t; sample.sequence=sample.sequence+1
        if move~=nil then sample.moveMask=directions[move] end
        if shoot~=nil then sample.shootMask=shoot end
        if active~=nil then sample.activeHeld=active end
        sample.availability=availability or 'ready'
        local events=C.Step(state,sample)
        for _,e in ipairs(events) do all[#all+1]=e end
        return events
    end
    local function count(kind, reason)
        local n=0; for _,e in ipairs(all) do if e.kind==kind and (not reason or e.reason==reason) then n=n+1 end end; return n
    end
    local function run(sequence, duration)
        for i,d in ipairs(sequence) do step((i-1)*duration/(#sequence-1),d,0,true) end
    end
    return {step=step,count=count,run=run,state=state,sample=sample,events=all}
end
test('single tap and fresh edges',function()
    local r=rig('wave_tap'); r.step(0,5,0,true); r.step(.1,nil,2); r.step(.2,nil,2); r.step(.3,nil,0)
    check(r.count('execute')==1,'hold/release do not repeat')
    r.step(.4,nil,2); check(r.count('execute')==2,'fresh press repeats without WASD neutral')
    local seq=r.sample.sequence; C.Step(r.state,r.sample); check(r.count('execute')==2 and r.sample.sequence==seq,'same sample is idempotent')
end)
test('pre-held arrow is not a click',function()
    local r=rig('wave_tap'); r.step(.1,5,2,false); r.step(.2,5,2,true)
    check(r.count('execute')==0,'pre-active held ignored'); r.step(.3,nil,0);r.step(.4,nil,2)
    check(r.count('execute')==1,'release then fresh press accepted')
end)
for _,gap in ipairs({1.2,1.201}) do test('double tap boundary '..gap,function()
    local r=rig('double_wave_tap'); r.step(0,5,2,true); r.step(.1,nil,0); r.step(gap,nil,2)
    check(r.count('execute')==(gap<=1.2 and 1 or 0),'double tap exact window')
end) end
test('double tap direction and long hold',function()
    local r=rig('double_wave_tap');r.step(0,5,2,true);r.step(.2,nil,2);check(r.count('execute')==0,'hold not second tap')
    r.step(.3,nil,0);r.step(.4,nil,4);check(r.count('execute')==0,'different direction restarts')
    r.step(.5,nil,0);r.step(.6,nil,4);check(r.count('execute')==1,'new same direction pair')
    check(r.events[#r.events].facing=='up','tap direction is attack direction')
end)
for _,case in ipairs({{'reverse_qcf',{2,1,4}},{'reverse_qcf',{2,4}},{'reverse_qcf',{1,4}},
 {'dp',{6,2,3}},{'dp',{6,2,6}},{'dp',{3,2,3}}}) do
    test('motion '..case[1]..table.concat(case[2]),function()
        local r=rig(case[1]);r.run(case[2],.6);check(r.count('execute')==1,'0.6 boundary accepted')
        local late=rig(case[1]);late.run(case[2],.601);check(late.count('execute')==0,'over window rejected')
    end)
end
test('insufficient dragon steps and diagonal hold',function()
    local r=rig('dp');r.run({6,2},.1);check(r.count('execute')==0,'dragon needs three stages')
    local b=rig('reverse_qcf');b.step(0,1,0,true);b.step(.1,1);check(b.count('execute')==0,'one diagonal cannot supply several stages')
end)
for _,n in ipairs({4,8}) do
    for _,seq in ipairs({{6,2,4,8,6,2,4,8},{8,4,2,6,8,4,2,6},{4,8,6,2,4,8,6,2}}) do
        test('circle '..n..'/'..seq[1],function()
            local a={};for i=1,n do a[i]=seq[i] end
            local window=n==4 and .8 or 1.5
            local r=rig(n==4 and 'circle_360' or 'circle_720');r.run(a,window)
            check(r.count('execute')==1,'circle boundary')
            local late=rig(n==4 and 'circle_360' or 'circle_720');late.run(a,window+.001)
            check(late.count('execute')==0,'late circle')
        end)
    end
end
test('circle diagonals, order and first lap',function()
    local r=rig('circle_360');r.run({6,3,2,1,4,7,8},.5);check(r.count('execute')==1,'natural roll')
    local bad=rig('circle_360');bad.run({6,4,2,8},.3);check(bad.count('execute')==0,'unordered directions rejected')
    local two=rig('circle_720');two.run({6,2,4,8},.4);check(two.count('execute')==0,'first lap only progress')
end)

test('circle only tolerates adjacent diagonal bridges',function()
    local r=rig('circle_360');r.run({6,7,2,9,4,3,8},.3)
    check(r.count('execute')==0,'unrelated diagonals cannot be erased to assemble a circle')
    local b=rig('circle_360');b.run({6,2,9,4,8},.3)
    check(b.count('execute')==0,'diagonal against established rotation rejected')
    local c=rig('circle_360');c.run({6,9,2,4,8},.3)
    check(c.count('execute')==0,'diagonal transition cannot point toward the opposite next cardinal')
    local e=rig('circle_360');e.run({6,9,3,2,4,8},.3)
    check(e.count('execute')==0,'opposite diagonal cannot overwrite an in-progress bridge')
end)
test('neutral limit does not extend clock',function()
    local r=rig('reverse_qcf');r.step(0,2,0,true);r.step(.1,5);r.step(.3,4);check(r.count('execute')==1,'0.2 neutral accepted')
    local b=rig('reverse_qcf');b.step(0,2,0,true);b.step(.1,5);b.step(.301,4);check(b.count('execute')==0,'long neutral rejected')
    local c=rig('circle_360');c.step(0,6,0,true);c.step(.3,2);c.step(.5,4);c.step(.6,5);c.step(.801,8)
    check(c.count('execute')==0,'neutral cannot extend total window')
end)
test('brief backwards bounce',function()
    local r=rig('circle_360');r.step(0,6,0,true);r.step(.1,2);r.step(.2,6);r.step(.2+2/30,4);r.step(.4,8)
    check(r.count('execute')==1,'2 frame bounce ignored')
    local b=rig('circle_360');b.step(0,6,0,true);b.step(.1,2);b.step(.2,6);b.step(.27,4);b.step(.4,8)
    check(b.count('execute')==0,'long reverse not ignored')
end)
test('new facing after a rejected reverse has no phantom cardinal',function()
    local r=rig('circle_360');r.step(0,6,0,true);r.step(.1,2);r.step(.15,2,4)
    r.step(.2,6,4);r.step(.27,6,4)
    local view=C.View(r.state)
    check(view.facing=='up' and view.count==1,'new attempt translates the reversed world input in its new facing')
    r.step(.35,8,4);r.step(.4,4,4);r.step(.45,2,4)
    check(r.count('execute')==1,'new four real cardinals complete once')
end)
test('hard wrong-direction retry uses new world basis',function()
    local r=rig('circle_360');r.step(0,6,2,true);r.step(.1,2,2);r.step(.2,8,4);r.step(.23,8,4)
    check(C.View(r.state).count==1,'held world direction cannot become a second relative cardinal')
    r.step(.3,6,4);r.step(.4,2,4);check(r.count('execute')==0,'three real cardinals do not complete')
    r.step(.5,4,4);check(r.count('execute')==1,'four real cardinals complete')
end)

test('neutral timeout retry uses new world basis',function()
    local r=rig('circle_360');r.step(0,6,2,true);r.step(.1,5,2);r.step(.301,8,4);r.step(.33,8,4)
    check(C.View(r.state).count==1,'neutral timeout restart cannot count held key twice')
    r.step(.4,6,4);r.step(.5,2,4);check(r.count('execute')==0,'neutral timeout still needs four real cardinals')
end)

test('explicit shot memory and current head fallback',function()
    local r=rig('reverse_qcf');r.sample.headFacing='up';r.step(.1,5,0,false)
    check(C.View(r.state).facing=='up','before any shot use current head, not initial head')
    r.step(.2,5,1,false);r.step(.3,5,0,false);r.sample.headFacing='right'
    C.Reset(r.state,r.sample,'room')
    check(C.View(r.state).facing=='left','room reset preserves last explicit shooting direction')
end)
test('facing lock and no-shot fallback',function()
    local r=rig('reverse_qcf','up');r.step(0,6,0,true);r.step(.1,3,2);r.step(.2,2)
    check(r.count('execute')==1,'relative directions use locked up facing')
    check(r.events[#r.events].facing=='up','mid-motion shooting does not rotate basis')
    local b=rig('reverse_qcf');b.step(0,5,4,false);b.step(.1,5,0);b.step(.2,6,0,true);b.step(.3,2)
    check(b.count('execute')==1,'last shooting direction used after release')
end)
test('SOCD last pressed and simultaneous conflict',function()
    local r=rig('reverse_qcf');r.step(0,2,0,true);r.sample.moveMask=0
    -- move input D then A while D is still held: last pressed A must win.
    r.step(.1,6);r.sample.moveMask=3;r.sample.sequence=r.sample.sequence+1;r.sample.time=.2
    C.Step(r.state,r.sample) -- the prior wrong direction must not complete a motion
    check(r.count('execute')==0,'arbitrary order does not become motion')
    local b=rig('reverse_qcf');b.step(0,2,0,true);b.sample.moveMask=3;b.sample.sequence=2;b.sample.time=.1
    local es=C.Step(b.state,b.sample);local n=0;for _,e in ipairs(es)do if e.kind=='execute'then n=n+1 end end
    check(n==0,'simultaneous opposite directions do not invent last press')
    local c=rig('circle_360');c.step(0,6,0,true)
    -- D remains held when A is newly added; normalization must select the newer A.
    c.sample.moveMask=3;c.sample.sequence=c.sample.sequence+1;c.sample.time=.2
    C.Step(c.state,c.sample)
    check(c.state.lastWorld==4,'last-down A wins over already-held D')
end)
test('charge directions and grace',function()
    for _,back in ipairs({1,4,7}) do for _,forward in ipairs({3,6,9}) do
        local r=rig('charge_back_forward');r.step(0,back,0,true);r.step(.5,back);r.step(.55,5);r.step(.75,forward)
        check(r.count('execute')==1,'charge and 0.2 release window')
    end end
    local short=rig('charge_back_forward');short.step(0,4,0,true);short.step(.499,6);check(short.count('execute')==0,'not charged')
    local g=rig('charge_back_forward');g.step(0,4,0,true);g.step(.2,5);g.step(.3,4);g.step(.6,6)
    check(g.count('execute')==1,'0.1 neutral preserved but did not grow')
    local b=rig('charge_back_forward');b.step(0,4,0,true);b.step(.2,5);b.step(.301,4);b.step(.6,6)
    check(b.count('execute')==0,'long charge gap resets')
    local idle=rig('charge_back_forward');idle.step(0,4,0,false);idle.step(1,4,0,false);idle.step(1.01,6,0,true)
    check(idle.count('execute')==0,'holding rear without active never stores charge')
end)

test('charge timeout restarts in latest world basis',function()
    local r=rig('charge_back_forward');r.step(0,4,2,true)
    for frame=1,4 do r.step(frame/30,5,1) end
    for frame=5,21 do r.step(frame/30,6,1) end
    r.step(22/30,4,1)
    check(r.count('execute')==1,'new rear edge after expired neutral starts charge in new facing')
    local b=rig('charge_back_forward');b.step(0,4,2,true);b.step(.5,4,2);b.step(.51,5,1)
    b.step(.75,6,1);b.step(1.3,6,1);b.step(1.31,4,1)
    check(b.count('execute')==1,'expired charged release can start a fresh rear charge in new facing')
end)
test('ordinary rearm and held completion',function()
    local r=rig('reverse_qcf');r.run({2,4},.1);r.step(.2,4);r.step(.3,2);r.step(.4,4)
    check(r.count('execute')==1,'cannot rearm without neutral')
    r.step(.5,5);r.step(.6,5);r.step(.7,2);r.step(.8,4)
    check(r.count('execute')==2,'0.1 neutral rearms')
end)
test('rearm counts neutral interval ending on a new key edge',function()
    local r=rig('reverse_qcf');r.run({2,4},.1);r.step(.2,5);r.step(.3,2);r.step(.4,4)
    check(r.count('execute')==2,'neutral end does not need an extra empty sample')
end)
test('pending ready, expiry, resource and cancel',function()
    local r=rig('wave_tap');r.step(0,5,2,true,'recovery');check(r.count('pending')==1 and r.count('execute')==0,'queue only')
    r.step(.2,nil,2,true,'ready');r.step(.21,nil,2,true,'ready');check(r.count('execute')==1,'queue boundary and dedup')
    local b=rig('wave_tap');b.step(0,5,2,true,'recovery');b.step(.201,nil,2,true,'ready');check(b.count('execute')==0,'expired queue')
    for _,reason in ipairs({'resource','target'}) do local c=rig('wave_tap');c.step(0,5,2,true,reason);c.step(.1,nil,2,true,'ready')
        check(c.count('execute')==0 and c.count('failure',reason)==1,'conditions do not queue') end
    local c=rig('wave_tap');c.step(0,5,2,true,'recovery');c.step(.1,nil,2,false);c.step(.15,nil,2,true)
    check(c.count('execute')==0,'active release clears queue and old held edge')
end)
test('reset and profile change baseline',function()
    local r=rig('double_wave_tap');r.step(0,5,2,true);r.step(.1,nil,0);C.Reset(r.state,r.sample,'room');r.step(.2,nil,2)
    check(r.count('execute')==0,'room reset clears first click')
    r.sample.profile='wave_tap';r.step(.3,nil,2);check(r.count('execute')==0,'switch while held is not a new press')
end)
test('720 up-down shortcut is single-use and needs active',function()
    local r=rig('circle_720');r.sample.moveMask=12;r.step(0,nil,0,false)
    check(r.count('execute')==0,'chord without active does nothing')
    r.step(.01,nil,0,true);check(r.count('execute')==1,'active plus held opposite arrows completes 720')
    for i=1,80 do r.step(.01+i/30,nil,0,true)end
    check(r.count('execute')==1 and r.state.serial==1,'holding chord never repeats after neutral timer')
    r.step(3,5,0,true);r.step(3.11,5,0,true);r.sample.moveMask=12;r.step(3.12,nil,0,true)
    check(r.count('execute')==2,'release and new chord rearms')
    C.Reset(r.state,r.sample,'room');r.step(3.2,nil,0,true)
    check(r.count('execute')==2,'room reset does not fire already held chord')
end)
test('720 shortcut shares failure consumption and recovery buffer',function()
    local r=rig('circle_720');r.step(0,5,0,true);r.sample.moveMask=12;r.step(.01,nil,0,true,'resource')
    r.step(.02,nil,0,true,'ready');check(r.count('failure','resource')==1 and r.count('execute')==0,'failed chord does not wait for resources')
    local b=rig('circle_720');b.step(0,5,0,true);b.sample.moveMask=12;b.step(.01,nil,0,true,'recovery')
    check(b.count('pending')==1,'shortcut uses the same recovery queue')
    b.step(.1,nil,0,true,'ready');b.step(.15,nil,0,true,'ready')
    check(b.count('execute')==1 and b.state.serial==1,'buffer releases once without duplicate serial')
    local e=rig('circle_720');e.step(0,5,0,true);e.sample.moveMask=12;e.step(.01,nil,0,true,'recovery');e.step(.22,nil,0,true,'ready')
    check(e.count('execute')==0 and e.count('failure','buffer_expired')==1,'shortcut buffer expires normally')
end)
test('720 shortcut does not leak to other profiles or duplicate partial circles',function()
    for _,profile in ipairs({'dp','circle_360'})do local r=rig(profile);r.step(0,5,0,true);r.sample.moveMask=12;r.step(.1,nil,0,true)
        check(r.count('execute')==0,'up-down shortcut belongs only to 720')end
    local r=rig('circle_720');r.run({6,2,4,8,6,2,4},.5);r.sample.moveMask=12;r.step(.55,nil,0,true)
    check(r.count('execute')==1 and r.state.serial==1,'chord consumes the partial circle once')
end)
assert(#failures==0,table.concat(failures,'\n'))
print('motion_input_core: '..passed..' assertions passed')
