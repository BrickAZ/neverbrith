-- Native-selected sleeper control and logical-action acceleration.
return function(mod, context, State)
    local callbackInstallers = {}
    local runtime = State.runtime
    local HOLD_FRAMES = 15
    local inOrigin = State.inOrigin
    local bedRecord = State.bedRecord
    local sleepState = State.sleepState
    local playerKey = State.playerKey
    local actions, actionSet = {}, {}
    for _, name in ipairs({ 'ACTION_LEFT', 'ACTION_RIGHT', 'ACTION_UP', 'ACTION_DOWN',
        'ACTION_SHOOTLEFT', 'ACTION_SHOOTRIGHT', 'ACTION_SHOOTUP', 'ACTION_SHOOTDOWN',
        'ACTION_BOMB', 'ACTION_ITEM', 'ACTION_PILLCARD', 'ACTION_DROP' }) do
        local id = ButtonAction[name]
        if id ~= nil and not actionSet[id] then actions[#actions+1], actionSet[id] = id, true end
    end
    local function sleeper(player)
        if not runtime.ready or not player or not inOrigin() then return nil end
        local bed, sleep = bedRecord(), sleepState()
        if not bed or bed.phase ~= 'sleeping' or not sleep or sleep.settled then return nil end
        if player:IsDead() then return nil end
        return sleep.recipients[playerKey(player)]
    end
    local function beforePlayerUpdate(_, player)
        local recipient = sleeper(player)
        if not recipient then return end
        player.Velocity = Vector.Zero
        player.Position = Vector(recipient.position.x, recipient.position.y)
        player:GetSprite():SetFrame(recipient.animation, recipient.frame)
        return true -- skip native player AI only for the native-selected sleepers
    end
    function callbackInstallers.beforePlayerUpdate()
        return mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE, beforePlayerUpdate)
    end
    local function inputAction(_, entity, hook, action)
        if runtime.sampling or not actionSet[action] or not entity then return end
        local player = entity:ToPlayer()
        if not sleeper(player) then return end
        if hook == InputHook.GET_ACTION_VALUE then return 0 end
        if hook == InputHook.IS_ACTION_PRESSED or hook == InputHook.IS_ACTION_TRIGGERED then return false end
    end
    function callbackInstallers.inputAction()
        return mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, inputAction)
    end
    local function sampleActions(sleep, collecting)
        local matureByPlayer = {}
        runtime.sampling = true
        for _, p in ipairs(context.GetPlayers()) do
            local key = playerKey(p)
            if (collecting or sleep.recipients[key]) and not p:IsDead() then
                runtime.held[key] = runtime.held[key] or {}
                matureByPlayer[key] = {}
                for _, action in ipairs(actions) do
                    -- Engine logical action API merges keyboard/controller/multiple bindings.
                    local down = Input.IsActionPressed(action, p.ControllerIndex)
                    runtime.held[key][action] = down and ((runtime.held[key][action] or 0) + 1) or 0
                    if runtime.held[key][action] >= HOLD_FRAMES then matureByPlayer[key][tostring(action)] = true end
                end
            end
        end
        runtime.sampling = false
        return matureByPlayer
    end
    local function multiplier(matureByPlayer, recipients)
        local mature = {}
        for key, values in pairs(matureByPlayer) do
            if recipients[key] then
                for action in pairs(values) do mature[action] = true end
            end
        end
        local n = 0
        for _ in pairs(mature) do n=n+1 end
        return 1 + 3599 * math.sqrt(n)
    end
    return { Installers=callbackInstallers, sampleActions=sampleActions, multiplier=multiplier }
end
