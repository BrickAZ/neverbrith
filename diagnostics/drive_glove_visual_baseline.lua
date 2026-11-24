-- Reproduce the reported render defect using the preserved pre-fix module.
-- No gameplay item is granted: only the old presentation callbacks run on p0.
return function(mod,useFixed)
    local started,active,age=false,false,0
    local preCount,postCount,lowest=0,0,1
    local t={mode='blue',blueAt=0,events={}}
    local s={gauge=6,burnout=false}
    local function log(x) Isaac.DebugString('[Drive Glove runtime] '..x) end
    local old=include(useFixed and 'drive_glove_visuals' or 'reports/drive-rush/2026-10-14/visual-contact-fix/before/drive_glove_visuals')(mod,{
        Key=function(p) return tostring(p.InitSeed) end,GetPlayers=function() return {Isaac.GetPlayer(0)} end,
        GetState=function() if active then return s,t end end,IsReady=function() return active end,IsHeld=function() return true end})
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_RENDER,900000,function(_,p)
        if active then preCount=preCount+1;lowest=math.min(lowest,p.SpriteScale.Y) end
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_RENDER,900000,function()
        if active then postCount=postCount+1 end
    end)
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if started then return end;started=true
        log('START '..(useFixed and 'fixed' or 'old')..' render baseline');Isaac.StartNewGame(0,0,0,123456789)
    end)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE,function()
        age=age+1
        local p=Isaac.GetPlayer(0)
        if age==80 then active=true;t.blueAt=Game():GetFrameCount() end
        if age>=120 and age<210 then p:SetMinDamageCooldown(60) end
        if active then old.Update() end
        if age==120 or age==210 then log('BASELINE age='..age..' pre='..preCount..' post='..postCount..' min='..lowest..' current='..p.SpriteScale.Y) end
        if age==210 then
            local passed=useFixed and math.abs(lowest-.96)<.001 and math.abs(p.SpriteScale.Y-1)<.001 and preCount>postCount
                or not useFixed and lowest<.5
            log((passed and 'PASS ' or 'FAIL ')..(useFixed and 'fixed scale with missing POST' or 'old shrinking reproduced'))
            active=false;old.ClearRoom();p.SpriteScale=Vector.One;p.Color=Color.Default
            log('DONE checks=1 failures='..(passed and 0 or 1))
        end
    end)
end
