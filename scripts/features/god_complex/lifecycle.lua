-- Private lifecycle responsibilities for god_complex; created once by its entry.
return function(mod, context, deps)
    local callbackInstallers = {}
    local data = deps.State.Data
    local ID = context.ItemId
    local Shooting = deps.Shooting
    local NO_USE = deps.Config.NO_USE
    local FORMS = deps.Config.FORMS
    local log = deps.State.log
    local key = deps.State.key
    local saveKey = deps.State.saveKey
    local alive = deps.State.alive
    local location = deps.State.location
    local saved = deps.State.saved
    local refresh = deps.State.refresh
    local state = deps.State.state
    local restoreShoot = deps.State.restoreShoot
    local stop = deps.State.stop
    local clear = deps.State.clear
    local combat = deps.Targeting.combat
    local chooseTarget = deps.Targeting.chooseTarget
    local startVisuals = deps.Presentation.startVisuals
    local solar = deps.Combat.solar
    local eye = deps.Combat.eye
    local frame = deps.State.frame

    local function use(_,id,rng,p,flags,slot)
        if not data.ready or not alive(p) or not p:HasCollectible(ID) or state(p) or data.active[key(p)]
            or data.lastUses[key(p)]==frame() or (flags & UseFlag.USE_CARBATTERY)~=0
            or Game():IsPaused() or p.ControlsEnabled==false or not p:AreControlsEnabled()
            or Game():GetRoom():GetFrameCount()<=0 or Game():GetRoom():IsClear() or not combat() then return NO_USE end
        if not p.SetCanShoot then log('SetCanShoot unavailable; use refused');return NO_USE end
        local old=saved().players[saveKey(p)];local choices={}
        for _,form in ipairs(FORMS) do if form~=old then choices[#choices+1]=form end end
        local form=choices[p:GetCollectibleRNG(ID):RandomInt(#choices)+1]
        local s={player=p,form=form,slot=slot,room=location(),age=0,lastFrame=frame(),tears={},visuals={},strikes={},strikeIndex=0,nextHit=6}
        data.active[key(p)]=s;data.lastUses[key(p)]=frame();saved().players[saveKey(p)]=form
        if form=='Eye' then s.target=chooseTarget(p) end
        refresh(p);startVisuals(s);context.Save()
        -- XML maxcharges=2 is the only charge authority, for the supplied slot.
        return {Discharge=true,Remove=false,ShowAnim=true}
    end
    function callbackInstallers.use()
        return mod:AddCallback(ModCallbacks.MC_USE_ITEM,use,ID)
    end

    local function evaluate(_,p,flag)
        local s=state(p);if not s then return end
        if s.form=='Solar' and flag==CacheFlag.CACHE_SPEED then p.MoveSpeed=p.MoveSpeed*0.55
        elseif s.form=='War' then
            if flag==CacheFlag.CACHE_DAMAGE then p.Damage=p.Damage*2
            elseif flag==CacheFlag.CACHE_FIREDELAY then p.MaxFireDelay=p.MaxFireDelay*0.60
            elseif flag==CacheFlag.CACHE_TEARFLAG then
                s.addedPiercing=TearFlags.TEAR_PIERCING & ~p.TearFlags
                p.TearFlags=p.TearFlags|TearFlags.TEAR_PIERCING
            end
        end
    end
    function callbackInstallers.evaluate()
        return mod:AddPriorityCallback(ModCallbacks.MC_EVALUATE_CACHE,20000,evaluate)
    end

    local function prePlayer(_,p)
        local s=state(p)
        if s and s.form=='Solar' then
            local k=key(p)
            Shooting.Block(data.shootRestore, k, p)
        end
    end
    function callbackInstallers.prePlayer()
        return mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,10000,prePlayer)
    end

    local function postPlayer(_,p) restoreShoot(key(p)) end
    function callbackInstallers.postPlayer()
        return mod:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,-10000,postPlayer)
    end

    local function update()
        if not data.ready or Game():IsPaused() then return end
        local entities=next(data.active) and Isaac.GetRoomEntities() or {}
        local now=frame()
        for k,s in pairs(data.active) do
            if not state(s.player) then stop(k)
            elseif s.lastFrame~=now then
                s.lastFrame=now;s.age=s.age+1
                if s.age>=240 then stop(k)
                else
                    for _,sprite in pairs(s.visuals) do sprite:Update() end
                    for i,b in pairs(s.strikes) do b.age=b.age+1;if b.age>=12 or b.sprite:IsFinished('Judgment') then s.strikes[i]=nil end end
                    if s.form=='Solar' then solar(s,entities) elseif s.form=='Eye' then eye(s) end
                end
            end
        end
        for k,c in pairs(data.collisions) do if c.frame<now then data.collisions[k]=nil end end
        for k,r in pairs(data.before) do if r.frame<now then data.before[k]=nil end end
    end
    function callbackInstallers.update()
        return mod:AddCallback(ModCallbacks.MC_POST_UPDATE,update)
    end

    local function started(_,continued)
        clear();data.ready=true;data.lastUses={};data.badVisuals={}
        if not continued then context.GetSaveRoot().godComplex=nil end
        saved()
    end
    function callbackInstallers.started()
        return mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,started)
    end

    local function exitGame() clear();if data.ready then context.Save() end;data.ready=false;data.lastUses={} end
    function callbackInstallers.exitGame()
        return mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT,exitGame)
    end
    function callbackInstallers.exitGame2()
        return mod:AddCallback(ModCallbacks.MC_POST_GAME_END,exitGame)
    end

    local function died(_,p) if p then stop(key(p)) end end
    function callbackInstallers.died()
        return mod:AddCallback(ModCallbacks.MC_PRE_TRIGGER_PLAYER_DEATH,died)
    end

    local function lost(_,p,id) if id==ID and not p:HasCollectible(ID) then stop(key(p)) end end
    function callbackInstallers.lost()
        return mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED,lost)
    end

    function callbackInstallers.unload()
        mod:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD,function(_,unloaded) if unloaded==mod then exitGame() end end)
    end

    return {
        Installers = callbackInstallers,
        use = use,
        evaluate = evaluate,
        prePlayer = prePlayer,
        postPlayer = postPlayer,
        update = update,
        started = started,
        exitGame = exitGame,
        died = died,
        lost = lost,
    }
end
