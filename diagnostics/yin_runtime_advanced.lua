-- Explicit seeded acceptance tests; loaded only by launch-yin-runtime-test.ps1.
return function(mod)
    local function log(s) Isaac.DebugString("[Yin runtime advanced] "..s) end
    log("YIN_RUNTIME_STAGE="..tostring(NEVERBIRTH_YIN_TEST_STAGE))
    if Isaac.GetPlayerExplosionImmunityAPIVersion()~=1 then log("ABORT api unavailable");return end
    local cases={"zero-listeners","mantle","invincible-frames","old-parameter-modify","snapshots","ipecac-knife","ipecac-bomb","baby-skin-20","nested-coop","coop-current-candle"}
    local index,frame,phase,events,posts,passed=0,0,"idle",{},{},0
    local p,other,baby,before,mode,cleanup,specialOkay
    local function health(player) return player:GetHearts()+player:GetSoulHearts() end
    local function setup(player,pyro,host,candle)
        for _,id in ipairs({223,375,260,313,149,52,114}) do while player:HasCollectible(id) do player:RemoveCollectible(id) end end
        if pyro then player:AddCollectible(223,0,true) end
        if host then player:AddCollectible(375,0,true) end
        if candle then player:AddCollectible(260,0,true) end
        player:AddSoulHearts(-99);player:AddHearts(99);player.ControlsEnabled=false
    end
    local observe=function(_,target,h,i)
        if phase=="attack" or phase=="shoot" then
            events[#events+1]={call=h.callId,target=target.InitSeed,damage=h.damage,flags=h.flags,countdown=h.countdown,site=i.siteKey,source=i.sourceKey}
            log("EVENT case="..cases[index].." call="..h.callId.." player="..target.InitSeed.." variant="..target.Variant.." site="..i.siteKey.." damage="..h.damage.." flags="..h.flags.." countdown="..h.countdown)
        end
    end
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_EXPLOSION_IMMUNITY,999999,observe)
    mod:AddCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,function(_,e,d,f,s,c)
        if (phase=="attack" or phase=="shoot") and e:ToPlayer() then posts[#posts+1]={target=e.InitSeed,damage=d,flags=f,countdown=c} end
    end)
    local started=false
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if started then return end;started=true;Isaac.StartNewGame(0,0,0,123456789)
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_GAME_STARTED,999999,function()
        p=Isaac.GetPlayer(0);p:AddCollectible(mod.YinsCurseTestAPI.ItemId,0,true)
        mode=mod.YinsCurseTestAPI.GetSavedState().q4Mode
        NEVERBIRTH_YIN_EXPLOSION_DIAGNOSTICS=true;include("diagnostics/yin_explosion_immunity_acceptance")(mod)
        log("GAME seed="..Game():GetSeeds():GetStartSeed().." player="..p.InitSeed.." lockedMode="..tostring(mode))
        phase="wait";frame=0
    end)
    local function attack(target,source,damage,flags,countdown)
        return target:TakeDamage(damage or 1,flags or DamageFlag.DAMAGE_EXPLOSION,EntityRef(source or target),countdown or 0)
    end
    local function finish(okay,details)
        if cleanup then cleanup();cleanup=nil end
        if okay then passed=passed+1 end
        log("RESULT "..cases[index].." "..(okay and "PASS" or "FAIL").." "..details.." events="..#events.." post="..#posts)
        phase="wait";frame=0
    end
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,999999,function()
        if phase=="idle" or phase=="done" then return end
        frame=frame+1
        if phase=="wait" and frame>=110 then
            index=index+1
            if not cases[index] then mod.YinExplosionDiagnostics.Disable();phase="done";log("DONE passed="..passed.." total="..#cases);return end
            setup(p,true,false,false)
            if other then setup(other,false,false,false) end
            if cases[index]=="mantle" then p:AddCollectible(313,0,true) end
            if cases[index]=="ipecac-knife" then setup(p,false,false,false);p:AddCollectible(149,0,true);p:AddCollectible(114,0,true) end
            if cases[index]=="ipecac-bomb" then setup(p,false,false,false);p:AddCollectible(149,0,true);p:AddCollectible(52,0,true) end
            if cases[index]=="baby-skin-20" then setup(p,false,false,false);PlayerManager.SpawnSelectedBaby(20,1) end
            if cases[index]=="nested-coop" then
                other=PlayerManager.SpawnCoPlayer2(0);setup(other,true,false,true);setup(p,true,true,false)
            end
            if cases[index]=="coop-current-candle" then setup(p,true,false,true);setup(other,true,false,false) end
            phase="setup";frame=0
        elseif phase=="setup" and frame>=30 then
            local name=cases[index];events={};posts={};specialOkay=nil;before=health(p);phase="attack";frame=0
            log("CASE "..name.." before="..before.." mode="..tostring(mod.YinsCurseTestAPI.GetSavedState().q4Mode))
            if name=="zero-listeners" then
                local listeners={};for _,c in ipairs(Isaac.GetCallbacks(1485)) do listeners[#listeners+1]={mod=c.Mod,fn=c.Function,priority=c.Priority} end
                for _,c in ipairs(listeners) do c.mod:RemoveCallback(1485,c.fn) end
                local count=#Isaac.GetCallbacks(1485);attack(p)
                specialOkay=count==0 and health(p)==before
                for _,c in ipairs(listeners) do c.mod:AddPriorityCallback(1485,c.priority,c.fn) end
                log("ZERO count="..count.." api="..Isaac.GetPlayerExplosionImmunityAPIVersion())
            elseif name=="mantle" then
                local prior=p:GetEffects():GetCollectibleEffectNum(313);attack(p)
                local after=p:GetEffects():GetCollectibleEffectNum(313)
                specialOkay=health(p)==before and prior>0 and after==prior-1
                log("MANTLE prior="..prior.." after="..after)
            elseif name=="invincible-frames" then
                attack(p);local first=health(p);attack(p)
                -- The second hit retains Pyromaniac's one-half-heart heal,
                -- then native invincibility blocks its damage.
                specialOkay=first==before-1 and health(p)==first+1 and #posts==1
            elseif name=="old-parameter-modify" then
                local fn=function()return {Damage=2,DamageFlags=DamageFlag.DAMAGE_EXPLOSION|DamageFlag.DAMAGE_NO_PENALTIES,DamageCountdown=7}end
                mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,-999999,fn,1);attack(p);mod:RemoveCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,fn)
                specialOkay=health(p)==before-2 and #posts==1 and posts[1].damage==2 and posts[1].countdown==7 and posts[1].flags==(DamageFlag.DAMAGE_EXPLOSION|DamageFlag.DAMAGE_NO_PENALTIES)
            elseif name=="snapshots" then
                local fn=function(_,target,h,i)h.damage=999;h.flags=2;h.countdown=99;h.source=EntityRef(nil);i.siteKey="tampered";i.sourceKey="tampered";return true end
                mod:AddPriorityCallback(1485,20,fn);attack(p);mod:RemoveCallback(1485,fn)
                specialOkay=health(p)==before-1 and #events==1 and events[1].damage==1 and events[1].flags==4 and events[1].countdown==0 and events[1].site=="pyromaniac.full-health"
            elseif name=="ipecac-knife" or name=="ipecac-bomb" then
                local shoot=function(_,e,hook,action)
                    if e and e:ToPlayer() and e.InitSeed==p.InitSeed and action==ButtonAction.ACTION_SHOOTRIGHT then
                        if hook==InputHook.GET_ACTION_VALUE then return 1 else return true end
                    end
                end
                mod:AddCallback(ModCallbacks.MC_INPUT_ACTION,shoot);cleanup=function()mod:RemoveCallback(ModCallbacks.MC_INPUT_ACTION,shoot);p.ControlsEnabled=false end
                p.ControlsEnabled=true;phase="shoot"
            elseif name=="baby-skin-20" then
                for _,entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PLAYER,-1,-1,false,false)) do
                    local v=entity:ToPlayer()
                    if v and v.Variant==1 then baby=v;break end
                end
                if baby then
                    log("BABY nativeSpawnSkin="..baby.BabySkin.." subtype="..baby.SubType)
                    baby.BabySkin=20 -- Supported REPENTOGON skin-selection property on a real native baby.
                    log("BABY target="..baby.InitSeed.." variant="..baby.Variant.." skin="..baby.BabySkin)
                    attack(baby);specialOkay=#events==1 and events[1].site=="coop-baby.skin-20" and events[1].target==baby.InitSeed
                else specialOkay=false;log("QUALIFICATION skin-20 baby not spawned") end
            elseif name=="nested-coop" then
                local otherBefore=health(other);local nested=false
                local fn=function(_,target,h,i)
                    if target.InitSeed==p.InitSeed and not nested then nested=true;attack(other) end
                end
                mod:AddPriorityCallback(1485,20,fn);attack(p);mod:RemoveCallback(1485,fn)
                specialOkay=health(p)==before-1 and health(other)==otherBefore and #events==3
                    and events[1].target==other.InitSeed and events[2].target==p.InitSeed and events[3].target==p.InitSeed
                    and events[1].call~=events[2].call and events[2].call==events[3].call
            elseif name=="coop-current-candle" then
                local otherBefore=health(other);attack(other);attack(p)
                specialOkay=health(other)==otherBefore-1 and health(p)==before and #events==2
                    and events[1].target==other.InitSeed and events[2].target==p.InitSeed
            end
        elseif phase=="shoot" then
            local knife=cases[index]=="ipecac-knife"
            local entities=Isaac.FindByType(knife and EntityType.ENTITY_KNIFE or EntityType.ENTITY_BOMB,-1,-1,false,false)
            if entities[1] then
                if cleanup then cleanup();cleanup=nil end
                phase="attack";frame=0
                if knife then
                    log("FACTORY knife="..entities[1].InitSeed.." spawner="..tostring(entities[1].SpawnerType))
                    attack(p,entities[1]);specialOkay=health(p)==before-1 and #events==1 and events[1].site=="ipecac.qualified-knife"
                else
                    local b=entities[1]:ToBomb();b.Position=p.Position;b.Velocity=Vector.Zero;b:SetExplosionCountdown(1)
                    log("FACTORY bomb="..b.InitSeed.." variant="..b.Variant.." spawner="..tostring(b.SpawnerType))
                end
            elseif frame>150 then finish(false,"native firing produced no source entity; qualification not observed") end
        elseif phase=="attack" and frame>=15 then
            if cases[index]=="ipecac-bomb" then specialOkay=health(p)==before-1 and #events==1 and events[1].site=="ipecac.qualified-bomb" end
            local locked=mod.YinsCurseTestAPI.GetSavedState().q4Mode==mode
            finish(specialOkay==true and locked,"loss="..(before-health(p)).." locked="..tostring(locked))
            if baby then PlayerManager.RemoveCoPlayer(baby);baby=nil end
        end
    end)
end
