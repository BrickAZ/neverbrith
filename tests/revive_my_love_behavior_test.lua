-- Engine boundary fixture: death resolution happens after the native animation,
-- and returning false revives immediately (it does not postpone Game Over).
local function eq(a, b, why)
    assert(a == b, (why or "mismatch") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
ModCallbacks = { MC_ENTITY_TAKE_DMG=1, MC_POST_GAME_STARTED=2, MC_PRE_GAME_EXIT=3,
    MC_POST_EFFECT_UPDATE=4, MC_POST_PLAYER_UPDATE=5, MC_TRIGGER_PLAYER_DEATH_POST_CHECK_REVIVES=1051,
    MC_PRE_PLAYER_UPDATE=1160, MC_PRE_PLAYER_TAKE_DMG=1008, MC_POST_NEW_ROOM=19,
    MC_POST_ADD_COLLECTIBLE=1005, MC_POST_TRIGGER_COLLECTIBLE_REMOVED=1095, MC_POST_UPDATE=6 }
EntityType = { ENTITY_PLAYER=1, ENTITY_EFFECT=1000 }
EntityCollisionClass = { ENTCOLL_NONE=0, ENTCOLL_ALL=4 }
DamageFlag = { DAMAGE_FAKE=1, DAMAGE_NOKILL=2 }
Vector = setmetatable({Zero={X=0,Y=0}}, {__call=function(_,x,y) return {X=x,Y=y} end})
Color = setmetatable({}, {__call=function(_,...) return {...} end})
REPENTOGON = {Version="1.0.12a", MeetsVersion=function(v) return v == "1.0.12a" end}

local function environment(options)
    options = options or {}
    local callbacks, players, effects, root = {}, {}, {}, {}
    local soundCount, seed = 0, 12345
    local mod = {}
    function mod:AddCallback(id, fn, filter) callbacks[id]={fn=fn,filter=filter} end
    Game = function() return {GetNumPlayers=function() return #players end} end
    Isaac = {GetPlayer=function(i) return players[i+1] end}
    function Isaac.Spawn(t,v,s,pos,vel,owner)
        if options.noEffect then return nil end
        local e={Type=t,Variant=v,SubType=s,Position=pos,SpawnerEntity=owner,
            InitSeed=1000+#effects,removed=false,sprite={finished=false,plays=0}}
        function e:GetSprite() return self.sprite end
        function e.sprite:Play(name) self.animation=name; self.plays=self.plays+1 end
        function e.sprite:IsFinished(name) return self.animation==name and self.finished end
        function e:Exists() return not self.removed end
        function e:Remove() self.removed=true end
        function e:SetColor() end
        effects[#effects+1]=e
        return e
    end
    local api = dofile("revive_my_love.lua")(mod, {ItemId=9001,EffectVariant=3020,
        GetSaveRoot=function() return root end, Save=function() end,
        GetCurrentRunSeed=function() return seed end,
        PlaySound=function() soundCount=soundCount+1 end})
    local function call(id,...)
        local c=callbacks[id]
        if c then return c.fn(mod,...) end
    end
    local function player(count)
        local p={Type=1,InitSeed=10+#players,held=count or 1,dead=false,hearts=2,maxHearts=6,soul=0,
            ControlsEnabled=true,Visible=true,EntityCollisionClass=4,Position=Vector(100,120),
            Velocity=Vector(0,0),FrameCount=0,revives=0,removed=0,effectCount=0}
        function p:ToPlayer() return self end
        function p:GetCollectibleNum(id) eq(id,9001); return self.held end
        function p:IsDead() return self.dead end
        function p:Exists() return true end
        function p:WillPlayerRevive() return self.effectCount>0 or self.otherRevive==true end
        function p:RemoveCollectible(id)
            eq(id,9001); self.held=self.held-1; self.removed=self.removed+1
            call(1095,self,id) -- Synchronous removal callback must not re-arm the revive.
        end
        function p:Revive()
            if self.vetoRevive then return end
            self.revives=self.revives+1; self.dead=false; self.hearts=1
            if options.deathPresentation then
                self.Visible=false; self.ControlsEnabled=false; self.EntityCollisionClass=0
            end
        end
        function p:GetHearts() return self.hearts end
        function p:GetMaxHearts() return self.maxHearts end
        function p:GetSoulHearts() return self.soul end
        function p:AddHearts(n) self.hearts=self.hearts+n end
        function p:AddSoulHearts(n) self.soul=self.soul+n end
        function p:SetMinDamageCooldown(n) self.cooldown=n end
        function p:SetColor() end
        local fx={}
        function fx:GetCollectibleEffectNum(id) eq(id,9001); return p.effectCount end
        function fx:AddCollectibleEffect(id,costume,n)
            eq(id,9001); eq(costume,false); p.effectCount=p.effectCount+n
        end
        function fx:RemoveCollectibleEffect(id,n) eq(id,9001); p.effectCount=math.max(0,p.effectCount-n) end
        function p:GetEffects() return fx end
        players[#players+1]=p
        return p
    end
    return {api=api,call=call,player=player,effects=effects,root=root,callbacks=callbacks,
        sounds=function() return soundCount end,
        newSeed=function() seed=seed+1 end}
end

local tests={}
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
