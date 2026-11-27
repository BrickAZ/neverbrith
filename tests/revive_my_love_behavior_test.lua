-- Engine boundary fixture: death resolution happens after the native animation,
-- and returning false revives immediately (it does not postpone Game Over).
local function eq(a, b, why)
    assert(a == b, (why or "mismatch") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
local environment = dofile('tests/support/revive_my_love_fixture.lua')

local tests={}
tests[#tests+1]=function()
    local e=environment(); local p=e.player(); local other=e.player(); e.call(2,false)
    e.call(5,p) -- Preserve living presentation before native death resolution.
    p.dead=true; e.call(1051,p)
    -- The native death path overwrites Revive() flags and omits POST_PLAYER_UPDATE.
    -- POST_UPDATE is the observed boundary before the very first render.
    p.ControlsEnabled=true; p.Visible=true; p.EntityCollisionClass=4
    p.Velocity=Vector(4,5)
    e.call(6)
    eq(p.ControlsEnabled,false,"post-death handoff must lock controls before render")
    eq(p.Visible,false,"post-death handoff must hide the live player before render")
    eq(p.EntityCollisionClass,0,"post-death handoff must restore no collision")
    eq(p.Velocity.X,0); eq(p.Velocity.Y,0)
    e.call(5,other)
    eq(other.ControlsEnabled,true); eq(other.Visible,true); eq(other.EntityCollisionClass,4)
    e.effects[1].sprite.finished=true; e.call(4,e.effects[1]); e.call(6)
    eq(p.ControlsEnabled,true); eq(p.Visible,true); eq(p.EntityCollisionClass,4)
end
tests[#tests+1]=function()
    local e=environment(); local p=e.player(); e.call(2,false)
    p.dead=true; e.call(1051,p)
    for frame=1,3 do
        p.EntityCollisionClass=4
        eq(e.call(1160,p),true)
        eq(p.EntityCollisionClass,0,"every suspended player update must maintain no collision")
    end
end
tests[#tests+1]=function()
    local e=environment(); local p=e.player(3)
    e.call(2,false); e.call(5,p); e.call(5,p)
    eq(p.effectCount,1,"three copies must advertise only one usable extra life")
    p.held=0; e.call(1095,p,9001)
    eq(p.effectCount,0,"removal must immediately remove the HUD/save-protection entitlement")
    p.held=1; e.call(1005,9001,0,true,0,0,p)
    eq(p.effectCount,1,"adding the item must register the extra life before the next damage")
end
tests[#tests+1]=function()
    local e=environment(); local p=e.player(2); e.call(2,false)
    e.call(5,p) -- No death: ordinary updates must not consume or lock anything.
    eq(p.removed,0); eq(p.ControlsEnabled,true); eq(#e.effects,0)
    p.dead=true; p.hearts=0
    e.call(5,p) -- During the native death animation, do not consume the reserve.
    eq(p.effectCount,1); eq(p.revives,0); eq(#e.effects,0)
    e.call(1051,p) -- Engine's authoritative post-animation/post-vanilla-revive boundary.
    eq(p.revives,1,"must rescue from Game Over at the real-death callback")
    eq(p.removed,1); eq(p.held,1); eq(p.effectCount,0)
    eq(p.ControlsEnabled,false); eq(p.Visible,false); eq(p.EntityCollisionClass,0)
    eq(e.call(1160,p),true,"native player update/shooting must be suspended during the visual")
    eq(e.call(1008,p,1,0,nil,0),false,"animation lock must protect without spending a shield")
    eq(#e.effects,1); eq(e.sounds(),1); eq(e.effects[1].sprite.animation,"Revive")
    e.call(1051,p); eq(p.revives,1,"duplicate death delivery must not double revive")
    e.call(4,e.effects[1]); eq(p.ControlsEnabled,false)
    e.effects[1].sprite.finished=true; e.call(4,e.effects[1])
    eq(p.ControlsEnabled,true); eq(p.Visible,true); eq(p.EntityCollisionClass,4)
    eq(p.hearts,2); eq(p.cooldown,60); eq(e.effects[1].removed,true)
    eq(e.call(1008,p,1,0,nil,0),nil); eq(e.call(1160,p),nil)
    e.call(5,p); eq(p.effectCount,0,"spare copy must not falsely advertise another revival")
    p.dead=true; e.call(1051,p); eq(p.revives,1)
end
tests[#tests+1]=function()
    local e=environment(); local a=e.player(); local b=e.player(); e.call(2,false)
    a.dead=true; e.call(1051,a)
    eq(b.effectCount,1); eq(b.removed,0); eq(b.ControlsEnabled,true)
    b.dead=true; e.call(1051,b); eq(#e.effects,2)
    e.effects[1].sprite.finished=true; e.call(4,e.effects[1])
    eq(a.ControlsEnabled,true); eq(b.ControlsEnabled,false)
    e.call(19); eq(b.ControlsEnabled,true); eq(e.effects[2].removed,true)
end
tests[#tests+1]=function()
    local e=environment(); local p=e.player(2); e.call(2,false)
    p.dead=true; e.call(1051,p); e.call(3,true)
    eq(p.ControlsEnabled,true,"exit must not save a hidden/locked player")
    eq(p.hearts,2); e.call(2,true); eq(p.effectCount,0)
    e.newSeed(); e.call(2,false); eq(p.effectCount,1)
end
tests[#tests+1]=function()
    local e=environment({noEffect=true}); local p=e.player(); e.call(2,false)
    p.dead=true; e.call(1051,p)
    eq(p.dead,false); eq(p.ControlsEnabled,true); eq(p.hearts,2)
end
tests[#tests+1]=function()
    local e=environment(); local p=e.player(); e.call(2,false)
    p.dead=true; e.call(1051,p); e.effects[1]:Remove(); e.call(1160,p)
    eq(p.ControlsEnabled,true,"removed visual must not strand the owner")
    eq(p.hearts,2)
end
tests[#tests+1]=function()
    local e=environment(); local p=e.player(); e.call(2,false)
    p.dead=true; p.vetoRevive=true; e.call(1051,p)
    eq(p.removed,0,"foreign veto must not consume the item or fake success")
    eq(p.ControlsEnabled,true); eq(#e.effects,0)
end
tests[#tests+1]=function()
    local e=environment(); local p=e.player(); e.call(2,false)
    p.maxHearts=0; p.hearts=0; p.dead=true; e.call(1051,p)
    e.effects[1].sprite.finished=true; e.call(4,e.effects[1]); eq(p.soul,2)
end
tests[#tests+1]=function()
    local e=environment(); local p=e.player(); e.call(2,false)
    eq(e.callbacks[ModCallbacks.MC_ENTITY_TAKE_DMG],nil,
        "ordinary damage must not be used as a speculative death trigger")
    -- A native/earlier revival already won. Even an unexpected late delivery
    -- must not consume this item, hide the player, or start a second sequence.
    e.call(1051,p)
    eq(p.removed,0); eq(#e.effects,0); eq(p.effectCount,1)
end
tests[#tests+1]=function()
    local e=environment(); local p=e.player(); e.call(2,false)
    p.dead=true; e.call(1051,p)
    for i=1,90 do
        eq(e.call(1160,p),true); eq(e.call(1160,p),true)
        e.call(6) -- 30 Hz logic, 60 Hz player updates.
    end
    e.call(6)
    eq(e.call(1160,p),nil,"stalled animation must release the player via recovery watchdog")
    eq(p.ControlsEnabled,true); eq(p.Visible,true); eq(p.hearts,2)
end
tests[#tests+1]=function()
    local e=environment({deathPresentation=true}); local p=e.player(); e.call(2,false)
    e.call(5,p) -- Save a living player's presentation, not the death callback's values.
    p.dead=true; p.Visible=false; p.ControlsEnabled=false; p.EntityCollisionClass=0
    e.call(5,p); e.call(1051,p)
    e.effects[1].sprite.finished=true; e.call(4,e.effects[1])
    eq(p.Visible,true,"death-time invisibility must not be restored after the cocoon")
    eq(p.ControlsEnabled,true,"death-time control lock must not survive the cocoon")
    eq(p.EntityCollisionClass,4,"restore living collision, not death collision")
end
tests[#tests+1]=function()
    local e=environment(); local p=e.player(); e.call(2,false)
    p.dead=true; e.call(1051,p)
    for frame=1,48 do
        eq(e.call(1160,p),true); eq(e.call(1160,p),true)
        eq(e.effects[1].removed,false,"48-frame visual must survive all 96 player updates")
        e.effects[1].sprite.finished=frame==48
        e.call(4,e.effects[1]); e.call(6)
    end
    eq(p.Visible,true); eq(p.ControlsEnabled,true); eq(e.effects[1].removed,true)
end
tests[#tests+1]=function()
    local e=environment({deathPresentation=true}); local p=e.player(); e.call(2,false)
    p.Visible=false; p.ControlsEnabled=false; p.EntityCollisionClass=2
    e.call(5,p) -- A foreign living state must not be replaced with blanket true/ALL.
    p.dead=true; e.call(1051,p)
    e.effects[1].sprite.finished=true; e.call(4,e.effects[1])
    eq(p.Visible,false); eq(p.ControlsEnabled,false); eq(p.EntityCollisionClass,2)
end
tests[#tests+1]=function()
    local rg=REPENTOGON; REPENTOGON=nil
    local e=environment(); eq(next(e.callbacks),nil,"missing required extension must not partially register")
    REPENTOGON={MeetsVersion=function() return false end}
    e=environment(); eq(next(e.callbacks),nil,"unsupported build must not register")
    REPENTOGON=rg
end
local failures=0
for index,test in ipairs(tests) do
    local ok,err=pcall(test)
    if not ok then failures=failures+1; print("FAIL " .. index .. ": " .. tostring(err)) end
end
assert(failures==0, tostring(failures) .. " revive regressions failed")
print("revive_my_love_behavior_test: " .. #tests .. " passed")
