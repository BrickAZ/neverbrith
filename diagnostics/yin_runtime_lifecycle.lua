-- Explicit backed-up seeded runtime checks; no normal-play loader.
return function(mod)
    local function log(s) Isaac.DebugString("[Yin runtime lifecycle] "..s) end
    log("YIN_RUNTIME_STAGE="..tostring(NEVERBIRTH_YIN_TEST_STAGE))
    local p,other,baby,phase,frame,events,passed,mode,oldRoom,lives,deadSeen,deathPosts=nil,nil,nil,"idle",0,{},0,nil,nil,nil,false,0
    local function hp(v)return v:GetHearts()+v:GetSoulHearts()end
    local function hit(v,amount)return v:TakeDamage(amount or 1,DamageFlag.DAMAGE_EXPLOSION,EntityRef(v),0)end
    local function result(name,okay,details)if okay then passed=passed+1 end;log("RESULT "..name.." "..(okay and "PASS" or "FAIL").." "..details)end
    local started=false
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if started then return end;started=true;Isaac.StartNewGame(PlayerType.PLAYER_JACOB,0,0,123456789)
    end)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT,function(_,v)if v.Variant==1 then baby=v;log("INIT baby="..v.InitSeed.." subtype="..v.SubType)end end)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_EXPLOSION_IMMUNITY,999999,function(_,v,h,i)
        events[#events+1]={target=v.InitSeed,call=h.callId,site=i.siteKey}
        log("EVENT phase="..phase.." target="..v.InitSeed.." variant="..v.Variant.." call="..h.callId.." site="..i.siteKey)
    end)
    mod:AddCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,function(_,e)
        if phase=="revive" and e:ToPlayer() and e.InitSeed==p.InitSeed then deathPosts=deathPosts+1 end
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_GAME_STARTED,999999,function(_,continued)
        p=Isaac.GetPlayer(0);other=Isaac.GetPlayer(1)
        log("GAME seed="..Game():GetSeeds():GetStartSeed().." continued="..tostring(continued).." main="..p.InitSeed.." type="..p:GetPlayerType().." other="..other.InitSeed.." otherType="..other:GetPlayerType())
        for _,v in ipairs({p,other}) do v.ControlsEnabled=false;v:AddCollectible(223,0,true);v:AddSoulHearts(-99);v:AddHearts(99)end
        p:AddCollectible(mod.YinsCurseTestAPI.ItemId,0,true);other:AddCollectible(260,0,true)
        mode=mod.YinsCurseTestAPI.GetSavedState().q4Mode
        NEVERBIRTH_YIN_EXPLOSION_DIAGNOSTICS=true;include("diagnostics/yin_explosion_immunity_acceptance")(mod)
        phase="dual";frame=0
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,999999,function()
        if phase=="idle" or phase=="done" then return end
        frame=frame+1
        if phase=="dual" and frame>=110 then
            events={};local a,b=hp(p),hp(other);hit(p);hit(other)
            result("jacob-esau",hp(p)==a-1 and hp(other)==b and #events==2 and events[1].target==p.InitSeed and events[2].target==other.InitSeed,"mainLoss="..(a-hp(p)).." otherLoss="..(b-hp(other)))
            phase="baby";frame=0
        elseif phase=="baby" and frame>=110 then
            while p:HasCollectible(223)do p:RemoveCollectible(223)end
            while other:HasCollectible(223)do other:RemoveCollectible(223)end
            events={};baby=nil;PlayerManager.SpawnSelectedBaby(20,1)
            if baby then
                local originalSkin=baby.BabySkin;baby.BabySkin=20
                local before=hp(baby);hit(baby)
                result("native-baby-skin-20",#events==1 and events[1].target==baby.InitSeed and events[1].site=="coop-baby.skin-20" and hp(baby)==before-1,"originalSkin="..originalSkin.." selectedSkin="..baby.BabySkin.." targetLoss="..(before-hp(baby)))
                PlayerManager.RemoveCoPlayer(baby);baby=nil
            else result("native-baby-skin-20",false,"native init object unavailable")end
            phase="room";frame=0
        elseif phase=="room" and frame>=110 then
            oldRoom=Game():GetLevel():GetCurrentRoomDesc().ListIndex
            local target
            for slot=0,7 do local d=Game():GetRoom():GetDoor(slot);if d and d.TargetRoomIndex>=0 then target=d.TargetRoomIndex;break end end
            if target then log("MOVE from="..oldRoom.." targetGrid="..target);phase="hourglass";frame=0;Game():ChangeRoom(target)
            else result("glowing-hourglass",false,"no native door target");phase="prepare-revive";frame=0 end
        elseif phase=="hourglass" and frame>=50 then
            log("HOURGLASS beforeRoom="..Game():GetLevel():GetCurrentRoomDesc().ListIndex)
            p:UseActiveItem(CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS,UseFlag.USE_NOANIM)
            phase="hourglass-result";frame=0
        elseif phase=="hourglass-result" and frame>=50 then
            local state=mod.YinsCurseTestAPI.GetSavedState();local current=Game():GetLevel():GetCurrentRoomDesc().ListIndex
            result("glowing-hourglass",current==oldRoom and state.yinCurseActive and state.q4Mode==mode,"restoredRoom="..current.." originalRoom="..oldRoom.." active="..tostring(state.yinCurseActive).." mode="..tostring(state.q4Mode))
            phase="prepare-revive";frame=0
        elseif phase=="prepare-revive" and frame>=110 then
            p=Isaac.GetPlayer(0);p.ControlsEnabled=false
            while p:HasCollectible(260)do p:RemoveCollectible(260)end
            if not p:HasCollectible(223)then p:AddCollectible(223,0,true)end
            p:AddCollectible(CollectibleType.COLLECTIBLE_DEAD_CAT,0,true);p:AddHearts(99)
            phase="revive";frame=0;events={};deathPosts=0;lives=p:GetExtraLives();hit(p,100);deadSeen=p:IsDead()
            log("DEATH dead="..tostring(deadSeen).." beforeLives="..lives.." red="..p:GetHearts())
        elseif phase=="revive" then
            deadSeen=deadSeen or p:IsDead()
            if frame>=10 and not p:IsDead() then
                local state=mod.YinsCurseTestAPI.GetSavedState()
                result("dead-cat-revive",deadSeen and p:GetExtraLives()==lives-1 and #events==1 and deathPosts==1 and state.yinCurseActive and state.q4Mode==mode,"afterLives="..p:GetExtraLives().." deadSeen="..tostring(deadSeen).." damagePosts="..deathPosts.." active="..tostring(state.yinCurseActive))
                mod.YinExplosionDiagnostics.Disable();phase="done";log("DONE passed="..passed.." total=4")
            elseif frame>240 then result("dead-cat-revive",false,"revive timeout");phase="done";log("DONE passed="..passed.." total=4")end
        end
    end)
end
