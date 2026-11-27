-- Private night_of_the_cowards responsibility: fear. No registration until an installer is called.
return function(Neverbirth, deps)
    local runtime = deps.Runtime
    local ENEMY_PARTITION = deps.Config.ENEMY_PARTITION
    local PLAYER_FEAR_ANM2 = deps.Config.PLAYER_FEAR_ANM2
    local PLAYER_FEAR_ANIMATION = deps.Config.PLAYER_FEAR_ANIMATION
    local AURA_RADIUS = deps.Config.AURA_RADIUS
    local AURA_RADIUS_SQUARED = deps.Config.AURA_RADIUS_SQUARED
    local PLAYER_BLOCK_DATA_KEY = deps.Config.PLAYER_BLOCK_DATA_KEY
    local zeroVector = deps.zeroVector
    local debugLog = deps.debugLog
    local makeVector = deps.makeVector
    local playerKey = deps.playerKey
    local toPlayer = deps.toPlayer
    local isAuraEnemy = deps.isAuraEnemy
    local getData = deps.getData
    local distanceSquared = deps.distanceSquared
    local callbackInstallers = {}
    local SHOOT_ACTIONS = {
        [ButtonAction and ButtonAction.ACTION_SHOOTLEFT or 4] = true,
        [ButtonAction and ButtonAction.ACTION_SHOOTRIGHT or 5] = true,
        [ButtonAction and ButtonAction.ACTION_SHOOTUP or 6] = true,
        [ButtonAction and ButtonAction.ACTION_SHOOTDOWN or 7] = true,
    }

    local function clearPlayerBlocks()
        for player in pairs(runtime.blockedPlayers) do
            local data = getData(player)
            if data then data[PLAYER_BLOCK_DATA_KEY] = nil end
        end
        runtime.blockedPlayers = {}
    end

    local function ensurePlayerFearSprite(player)
        local key = playerKey(player)
        local sprite = runtime.fearSprites[key]
        if sprite then return sprite end
        local ok, created = pcall(function()
            return Sprite()
        end)
        if not ok or not created or type(created.Load) ~= "function" then
            debugLog("player Fear Sprite constructor is unavailable")
            return nil
        end
        local loaded, err = pcall(created.Load, created, PLAYER_FEAR_ANM2, true)
        if not loaded then
            debugLog("player Fear sprite load failed: " .. tostring(err))
            return nil
        end
        runtime.fearSprites[key] = created
        return created
    end

    local function setPlayerBlocked(player, blocked)
        local wasBlocked = runtime.blockedPlayers[player] == true
        local data = getData(player)
        if data then data[PLAYER_BLOCK_DATA_KEY] = blocked == true or nil end
        if blocked then
            runtime.blockedPlayers[player] = true
            local sprite = ensurePlayerFearSprite(player)
            if sprite then
                if not wasBlocked and type(sprite.Play) == "function" then
                    pcall(sprite.Play, sprite, PLAYER_FEAR_ANIMATION, true)
                end
                if type(sprite.Update) == "function" then pcall(sprite.Update, sprite) end
            end
        else
            runtime.blockedPlayers[player] = nil
        end
    end

    local function isPlayerBlocked(player)
        if runtime.blockedPlayers[player] then return true end
        local data = getData(player)
        return data and data[PLAYER_BLOCK_DATA_KEY] == true or false
    end

    local function findAuraEnemy(player)
        if not player or not player.Position or not Isaac or type(Isaac.FindInRadius) ~= "function" then
            return nil
        end
        local ok, entities = pcall(Isaac.FindInRadius, player.Position, AURA_RADIUS, ENEMY_PARTITION)
        if not ok or type(entities) ~= "table" then return nil end
        for _, entity in ipairs(entities) do
            if isAuraEnemy(entity)
                and entity.Position
                and distanceSquared(player.Position, entity.Position) <= AURA_RADIUS_SQUARED
            then
                return entity
            end
        end
        return nil
    end

    local function applyPlayerAuraState(player)
        local enemy = findAuraEnemy(player)
        if not enemy then
            setPlayerBlocked(player, false)
            return false
        end
        setPlayerBlocked(player, true)
        return true
    end

    local function getPlayerFearWorldPosition(player)
        if not player or not player.Position then return nil end
        local size = math.max(0, tonumber(player.Size) or 20)
        local headOffset = math.max(18, size + 4)
        return makeVector(player.Position.X, player.Position.Y - headOffset)
    end

    local function postPlayerRender(_, player, _renderOffset)
        if not player or not player.Position or not isPlayerBlocked(player) then return nil end
        local sprite = runtime.fearSprites[playerKey(player)]
        if not sprite or type(sprite.Render) ~= "function" or not Isaac
            or type(Isaac.WorldToScreen) ~= "function"
        then
            return nil
        end

        local worldPosition = getPlayerFearWorldPosition(player)
        local ok, screenPosition = pcall(Isaac.WorldToScreen, worldPosition)
        if not ok or not screenPosition then return nil end
        local zero = zeroVector()
        pcall(sprite.Render, sprite, screenPosition, zero, zero)
        return nil
    end
    function callbackInstallers.postPlayerRender()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, postPlayerRender)
    end

    local function inputAction(_, entity, inputHook, buttonAction)
        local player = toPlayer(entity)
        if not player or not isPlayerBlocked(player) or not SHOOT_ACTIONS[buttonAction] then return nil end
        if InputHook and inputHook == InputHook.GET_ACTION_VALUE then return 0 end
        if not InputHook
            or inputHook == InputHook.IS_ACTION_PRESSED
            or inputHook == InputHook.IS_ACTION_TRIGGERED
        then
            return false
        end
        return nil
    end
    function callbackInstallers.inputAction()
        return Neverbirth:AddCallback(ModCallbacks.MC_INPUT_ACTION, inputAction, InputHook.IS_ACTION_PRESSED)
    end
    function callbackInstallers.inputAction2()
        return Neverbirth:AddCallback(ModCallbacks.MC_INPUT_ACTION, inputAction, InputHook.IS_ACTION_TRIGGERED)
    end
    function callbackInstallers.inputAction3()
        return Neverbirth:AddCallback(ModCallbacks.MC_INPUT_ACTION, inputAction, InputHook.GET_ACTION_VALUE)
    end
    function callbackInstallers.inputAction4()
        return Neverbirth:AddCallback(ModCallbacks.MC_INPUT_ACTION, inputAction)
    end

    return {
        clearPlayerBlocks = clearPlayerBlocks,
        ensurePlayerFearSprite = ensurePlayerFearSprite,
        setPlayerBlocked = setPlayerBlocked,
        isPlayerBlocked = isPlayerBlocked,
        findAuraEnemy = findAuraEnemy,
        applyPlayerAuraState = applyPlayerAuraState,
        getPlayerFearWorldPosition = getPlayerFearWorldPosition,
        postPlayerRender = postPlayerRender,
        inputAction = inputAction,
        Installers = callbackInstallers,
    }
end
