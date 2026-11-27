-- Private lifecycle responsibilities for bomb_suit; created once by its entry.
return function(mod, context, deps)
    local callbackInstallers = {}
    local data = deps.State.Data
    local ID = context.ItemId
    local Shooting = deps.Shooting
    local DURATION = deps.Config.DURATION
    local beepAt = deps.Config.beepAt
    local key = deps.State.key
    local held = deps.State.held
    local restoreShoot = deps.State.restoreShoot
    local stop = deps.State.stop
    local clear = deps.State.clear
    local stateFor = deps.State.stateFor
    local detonate = deps.Bombs.detonate
    local beep = deps.Presentation.beep

    local function prePlayer(_, player)
        if not stateFor(player) then return end
        local k = key(player)
        Shooting.Block(data.shootScopes, k, player)
    end
    function callbackInstallers.prePlayer()
        return mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE, -20000, prePlayer)
    end

    local function postPlayer(_, player) restoreShoot(key(player)) end
    function callbackInstallers.postPlayer()
        return mod:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, 20000, postPlayer)
    end

    local function input(_, entity, hook, action)
        local player = entity and entity:ToPlayer()
        if not player or not stateFor(player) then return end
        if action == ButtonAction.ACTION_SHOOTLEFT or action == ButtonAction.ACTION_SHOOTRIGHT
            or action == ButtonAction.ACTION_SHOOTUP or action == ButtonAction.ACTION_SHOOTDOWN then
            if hook == InputHook.GET_ACTION_VALUE then return 0 end
            return false
        end
    end
    function callbackInstallers.input()
        return mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, input)
    end

    local function update()
        if not data.ready or Game():IsPaused() then return end
        local frame = Game():GetFrameCount()
        local keys = {}; for k in pairs(data.active) do keys[#keys+1] = k end
        for _, k in ipairs(keys) do
            local state = data.active[k]
            if not held(state.player) then stop(k)
            elseif state.lastFrame ~= frame then
                state.lastFrame = frame; state.age = state.age + 1
                if state.age >= DURATION then detonate(k, state)
                else
                    if beepAt[state.age] then beep(state) end
                    local period = state.age >= 75 and 4 or (state.age >= 60 and 8 or 16)
                    if state.player.SetColor and state.age % period < period / 2 then
                        state.player:SetColor(Color(1, 0.65, 0.55, 1, 0.12, 0, 0), 2, 30, false, false)
                    end
                    if state.fuse then
                        local phase = state.age >= 75 and (4 + math.floor(state.age / 2) % 2)
                            or math.min(4, math.floor(state.age / 15))
                        state.fuse:SetFrame("Fuse", phase)
                    end
                end
            end
        end
    end
    function callbackInstallers.update()
        return mod:AddCallback(ModCallbacks.MC_POST_UPDATE, update)
    end

    local function start() clear(); data.ready = true end
    function callbackInstallers.start()
        return mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, start)
    end

    local function exit() clear(); data.ready = false end
    function callbackInstallers.exit()
        return mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, exit)
    end

    local function death(_, player) stop(key(player)) end
    function callbackInstallers.death()
        return mod:AddCallback(ModCallbacks.MC_PRE_TRIGGER_PLAYER_DEATH, death)
    end

    local function removed(_, player, item)
        if item == ID and not player:HasCollectible(ID) then stop(key(player)) end
    end
    function callbackInstallers.removed()
        return mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED, removed, ID)
    end

    function callbackInstallers.unload()
        mod:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD,function(_,unloaded) if unloaded==mod then exit() end end)
    end

    return {
        Installers = callbackInstallers,
        prePlayer = prePlayer,
        postPlayer = postPlayer,
        input = input,
        update = update,
        start = start,
        exit = exit,
        death = death,
        removed = removed,
    }
end
