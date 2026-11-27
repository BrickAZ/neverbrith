-- Private lifecycle responsibilities for i_am_a_god; created once by its entry.
return function(mod, context, deps)
    local callbackInstallers = {}
    local data = deps.State.Data
    local ITEM_ID = context.ItemId
    local DURATION = deps.Config.DURATION
    local OVERLOAD = deps.Config.OVERLOAD
    local playerKey = deps.State.playerKey
    local samePlayer = deps.State.samePlayer
    local players = deps.State.players
    local location = deps.State.location
    local saved = deps.State.saved
    local stop = deps.State.stop
    local validActive = deps.State.validActive
    local clearCooldown = deps.Health.clearCooldown
    local purgeHearts = deps.Health.purgeHearts
    local capture = deps.Health.capture
    local reconcile = deps.Health.reconcile
    local settle = deps.Combat.settle

    local function update()
        if not data.ready or Game():IsPaused() then return end
        if validActive() then
            local frame=Game():GetFrameCount()
            if data.active.lastFrame~=frame then
                data.active.lastFrame=frame;data.active.age=data.active.age+1
                if data.active.age>=DURATION then settle()
                elseif data.active.crown then
                    local s=data.active.crown
                    if data.active.age>=OVERLOAD and s:GetAnimation()~="Overload" then s:Play("Overload",true)
                    elseif s:IsFinished("Declare") then s:Play("Idle",true) end
                    s:Update()
                end
            end
        end
        if data.marked or data.active then
            for _,p in ipairs(players()) do
                if data.active then clearCooldown(p) end
                reconcile(p)
            end
        end
        for i=#data.bursts,1,-1 do
            local b=data.bursts[i];b.age=b.age+1;b.sprite:Update()
            if b.room~=data.currentKey or b.age>=b.timeout or b.sprite:IsFinished(b.animation) then table.remove(data.bursts,i) end
        end
    end
    function callbackInstallers.update()
        return mod:AddCallback(ModCallbacks.MC_POST_UPDATE,update)
    end

    local function enterRoom()
        if not data.ready then return end
        -- Never release old-room handles against a newly loaded room.
        local floor,key=location()
        if key~=data.currentKey then data.currentKey=nil end
        stop();data.bursts={};data.snapshots={};data.reviving={}
        data.currentFloor,data.currentKey=floor,key
        data.marked=saved().rooms[key]==true
        if data.marked then
            for _,p in ipairs(players()) do capture(p) end
            purgeHearts()
        end
    end
    function callbackInstallers.enterRoom()
        return mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,enterRoom)
    end

    local function newLevel()
        if not data.ready then return end
        data.currentKey=nil;stop();data.bursts={};data.snapshots={};data.reviving={}
        data.currentFloor,data.currentKey=location()
        local s=saved();s.rooms={};data.marked=false;context.Save()
    end
    function callbackInstallers.newLevel()
        return mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,newLevel)
    end

    local function started(_,continued)
        stop();data.ready=true;data.bursts={};data.snapshots={};data.reviving={}
        if not continued then context.GetSaveRoot().iAmAGod=nil end
        enterRoom()
    end
    function callbackInstallers.started()
        return mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,started)
    end

    local function exitGame()
        stop();data.bursts={};data.snapshots={};data.reviving={}
        if data.ready then context.Save() end
        data.ready=false;data.marked=false
    end
    function callbackInstallers.exitGame()
        return mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT,exitGame)
    end
    function callbackInstallers.exitGame2()
        return mod:AddCallback(ModCallbacks.MC_POST_GAME_END,exitGame)
    end

    local function death(_,p)
        if not data.ready then return end
        if data.active and samePlayer(data.active.player,p) then stop() end
        data.reviving[playerKey(p)]=true;data.snapshots[playerKey(p)]=nil
        -- nil: preserve every native death/revival decision.
    end
    function callbackInstallers.death()
        return mod:AddCallback(ModCallbacks.MC_PRE_TRIGGER_PLAYER_DEATH,death)
    end

    local function removed(_,p,id)
        if id==ITEM_ID and data.active and samePlayer(data.active.player,p) and not p:HasCollectible(ITEM_ID) then stop() end
    end
    function callbackInstallers.removed()
        return mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED,removed,ITEM_ID)
    end

    function callbackInstallers.unload()
        mod:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD,function(_,unloaded) if unloaded==mod then exitGame() end end)
    end

    return {
        Installers = callbackInstallers,
        update = update,
        enterRoom = enterRoom,
        newLevel = newLevel,
        started = started,
        exitGame = exitGame,
        death = death,
        removed = removed,
    }
end
