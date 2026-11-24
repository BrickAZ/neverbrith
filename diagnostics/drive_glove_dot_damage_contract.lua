-- Same native status damage probes for the original DLL and attribution DLL.
return function(mod)
    local started,age,index,active=false,0,0,nil
    local cases={'poison','burn','both','poison-first','burn-first','bleed','weaker','immune'}
    local function log(s)Isaac.DebugString('[Drive Glove runtime] '..s)end
    mod:AddCallback(ModCallbacks.MC_NPC_UPDATE,function(_,e)
        if cases[index]=='bleed' then e.Velocity=Vector(8,0);e.State=4;e:ClearEntityFlags(EntityFlag.FLAG_APPEAR) end
    end)
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if started then return end;started=true;Isaac.StartNewGame(0,0,0,123456789)
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,999999,function()
        age=age+1;if age<100 or age%10~=0 then return end
        local p=Isaac.GetPlayer(0);p.ControlsEnabled=false;p.Position=Vector(80,80)
        if active then
            log('MEASURE '..cases[index]..' hp='..active.HitPoints..' poison='..active:GetPoisonCountdown()..' burn='..active:GetBurnCountdown()..' bleed='..active:GetBleedingCountdown())
        end
        index=index+1
        if not cases[index] then log('DONE native damage comparison');age=-100000;return end
        for _,e in ipairs(Isaac.GetRoomEntities()) do if not e:ToPlayer() then e:Remove() end end
        if mod.RingOfSevenCursesTestAPI then mod.RingOfSevenCursesTestAPI.ResetForTest();p:RemoveCollectible(mod.RingOfSevenCursesTestAPI.ItemId) end
        active=Isaac.Spawn(EntityType.ENTITY_ATTACKFLY,0,0,Vector(400,300),Vector(0,0),nil):ToNPC()
        active.HitPoints=100;active.MaxHitPoints=100
        local c=cases[index]
        if c=='immune' then active:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS) end
        if c~='burn' and c~='bleed' then active:AddPoison(EntityRef(p),60,3.5) end
        if c=='burn' or c=='both' or c=='poison-first' or c=='burn-first' then active:AddBurn(EntityRef(p),60,3.5) end
        if c=='poison-first' then active:SetBurnDamageTimer(10) end
        if c=='burn-first' then active:SetPoisonDamageTimer(10) end
        if c=='bleed' then active:AddBleeding(EntityRef(p),60);active.Velocity=Vector(8,0) end
        if c=='weaker' then active:AddPoison(EntityRef(nil),60,2) end
    end)
end
