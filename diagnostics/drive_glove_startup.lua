-- Temporary startup smoke: deliberately never calls StartNewGame / Continue.
return function(mod)
    local done=false
    local function run()
        if done then return end; done=true
        local function log(s) Isaac.DebugString('[Drive Glove startup] '..s) end
        local id=mod.DriveGlove and mod.DriveGlove.ItemId
        log((id and id>0 and 'PASS ' or 'FAIL ')..'registration id='..tostring(id))
        for path,animation in pairs({
            ['gfx/Effects/DriveRush/v3/drive_parry_rush_v3.anm2']='Transition',
            ['gfx/Effects/DriveDefense/v1/drive_defense_front.anm2']='PerfectParry',
            ['gfx/Effects/DriveDefense/v1/drive_defense_back.anm2']='Guard',
            ['gfx/Effects/DriveRecovery/v1/drive_parry_release.anm2']='BurnoutFull',
            ['gfx/Effects/DriveRecovery/v1/drive_parry_recovery_floor.anm2']='Full',
            ['gfx/UI/DriveGauge/v2/drive_gauge.anm2']='BrownFill',
            ['gfx/UI/DriveGauge/v2/drive_gauge_feedback.anm2']='BurnoutEnter',
            ['gfx/UI/DriveGauge/v2/drive_gauge_icons.anm2']='BurnoutLabel',
        }) do
            local ok,err=pcall(function()
                local s,loaded=Sprite(path,true); assert(loaded,'native load failed'); assert(s:GetAnimationData(animation),'missing animation')
                s:SetFrame(animation,0)
            end)
            log((ok and 'PASS ' or 'FAIL ')..path..(ok and '' or ' '..tostring(err)))
        end
        log('DONE scope=startup-only; no run started')
    end
    run()
end
