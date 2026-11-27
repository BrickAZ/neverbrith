-- Private Drive Glove lifecycle; instantiated once by init.lua.
return function(mod, deps)
    local callbackInstallers = {}
    local C,records,now=deps.Core,deps.State,deps.Now
    local data,state,key,held=records.Data,records.Get,records.Key,records.IsHeld
    local freeze,attribution,visuals=deps.Freeze,deps.Attribution,deps.Visuals
    local restoreShoot,refresh=deps.Weapons.RestoreShoot,deps.Weapons.Refresh
    local busy,canControl=deps.Input.Busy,deps.Input.CanControl
    local game,exists,players,ID=deps.Game,deps.Exists,records.Players,deps.ItemId
    local flush,save=deps.Flush,records.Save
    local function restoreAll()
        freeze.Stop()
        for _,t in pairs(records.All()) do
            if deps.Shooting or exists(t.player) then restoreShoot(t.player,t) end
        end
    end
    local function cancelRoom()
        restoreAll()
        attribution.Reset()
        for _,t in pairs(records.All()) do
            if busy(t) then C.End(t,'room') end
            t.planned=nil; t.walkOrigin=nil; t.damageReceipts={}; t.rushShot=nil
        end
        if visuals then visuals.ClearRoom() end
    end
    function callbackInstallers.cancelRoom()
        return mod:AddCallback(ModCallbacks.MC_POST_GLOWING_HOURGLASS_LOAD,cancelRoom)
    end
    local function postUpdate()
        if not records.IsReady() or game:IsPaused() then return end
        freeze.ThawExpired()
        freeze.HoldPositions()
        attribution.Update()
        for _,t in pairs(records.All()) do
            if exists(t.player) then
                restoreShoot(t.player,t)
                if t.rushShot and t.rushShot.finishing and t.rushShot.emittedAt<now() then t.rushShot=nil end
                t.damageReceipts={}
                local s=data(t.player)
                if s then
                    if held(t.player) and canControl(t.player) and not freeze.IsActive() then C.Regen(s,t,t.walking) end
                    flush(t.player,s,t)
                end
            elseif deps.Shooting then
                restoreShoot(t.player,t)
            end
        end
        if visuals then visuals.Update() end
        if now()%30==0 then
            for _,t in pairs(records.All()) do if t.saveDirty then save(); break end end
        end
    end
    function callbackInstallers.postUpdate()
        return mod:AddCallback(ModCallbacks.MC_POST_UPDATE,postUpdate)
    end
    local function started(_,continued)
        restoreAll(); records.Reset(true); attribution.Reset()
        if not continued then records.ClearSaved() end
        for _,p in ipairs(players()) do
            local s=data(p)
            if s then local t=state(p); t.cacheDirty=true; refresh(p,t) end
        end
        if visuals then visuals.ClearRoom() end
    end
    function callbackInstallers.started()
        return mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,started)
    end
    local function exit()
        restoreAll(); if records.IsReady() then save() end; records.Reset(false); attribution.Reset()
        if visuals then visuals.ClearRoom() end
    end
    function callbackInstallers.exit()
        return mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT,exit)
    end
    function callbackInstallers.newRoom()
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,function() if records.IsReady() then cancelRoom(); save() end end)
    end
    function callbackInstallers.acquire()
    mod:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE,function(_,item,_,_,_,_,p)
        if item==ID and records.IsReady() then data(p); save() end
    end,ID)
    end
    function callbackInstallers.unload()
    mod:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD,function(_,unloaded) if unloaded==mod then exit() end end)
    end
    function callbackInstallers.command()
    mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD,function(_,command,args)
        if command~='driveglove' then return end
        local mode,arg=(args or ''):match('^(%S+)%s*(.*)$')
        local p=players()[1]; if not p then return end
        if mode=='give' then p:AddCollectible(ID,0,true,0); data(p); save() end
        local s,t=data(p),state(p)
        if mode=='meter' and tonumber(arg) and s then C.SetGauge(s,t,tonumber(arg),'Gain'); flush(p,s,t); save() end
        if s and (mode=='status' or mode=='give' or mode=='meter') then
            Isaac.ConsoleOutput(string.format('Drive Glove v1: id=%d meter=%.4f burnout=%s mode=%s moves=%d remaining=%.3f reward=%s\n',
                ID,s.gauge,tostring(s.burnout),t.mode,t.moveFrames,t.remaining or 0,t.reward and (t.reward.started and 'active' or 'pending') or 'none'))
        else Isaac.ConsoleOutput('driveglove give / status / meter 0..6 (debug meter only)\n') end
    end)
    end

    return {
        Install = callbackInstallers,

    }
end
