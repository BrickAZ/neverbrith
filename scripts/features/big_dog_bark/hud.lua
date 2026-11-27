-- Private hud responsibility for the Big Dog family.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local Constants = deps.Constants
    local runtime = deps.State.Runtime
    local debugLog = deps.Queries.debugLog
    local newVector = deps.Queries.newVector
    local vectorAdd = deps.Queries.vectorAdd
    local playerIsDead = deps.Queries.playerIsDead
    local hasBigDogActive = deps.Queries.hasBigDogActive
    local getPlayerRuntime = deps.State.getPlayerRuntime

    local function chargeProgress(state)
        if type(state) ~= "table" then
            return 0
        end
        local required = math.max(1, tonumber(state.chargeFrames) or 1)
        local elapsed = math.max(0, runtime.frame - (tonumber(state.chargeStartFrame) or runtime.frame))
        return math.max(0, math.min(1, elapsed / required))
    end

    local function setChargeBarPhase(state, phase)
        if type(state) ~= "table" then
            return
        end
        state.chargeBarPhase = phase
        state.chargeBarVisible = phase ~= nil
    end

    local function chargeBarAnimation(sprite)
        if sprite and type(sprite.GetAnimation) == "function" then
            local ok, animation = pcall(sprite.GetAnimation, sprite)
            if ok then
                return animation
            end
        end
        return nil
    end

    local function playChargeBarAnimation(sprite, animation)
        if not sprite or type(sprite.Play) ~= "function" then
            return false
        end
        if chargeBarAnimation(sprite) ~= animation then
            local ok = pcall(sprite.Play, sprite, animation, true)
            return ok
        end
        return true
    end

    local function ensureChargeBarSprite(state)
        if state.chargeBarSprite then
            return state.chargeBarSprite
        end
        if state.chargeBarLoadFailed then
            return nil
        end
        local okSprite, sprite = pcall(function()
            return Sprite()
        end)
        if not okSprite or not sprite or type(sprite.Load) ~= "function" then
            state.chargeBarLoadFailed = true
            debugLog("chargebar Sprite constructor is unavailable")
            return nil
        end
        local okLoad = pcall(sprite.Load, sprite, Constants.CHARGE_BAR_PATH, true)
        if not okLoad then
            state.chargeBarLoadFailed = true
            debugLog("failed to load " .. Constants.CHARGE_BAR_PATH)
            return nil
        end
        state.chargeBarSprite = sprite
        return sprite
    end

    local function chargeBarScreenPosition(player)
        local scaleY = tonumber(player and player.SpriteScale and player.SpriteScale.Y) or 1
        local anchor = vectorAdd(
            player.Position or newVector(0, 0),
            newVector(Constants.CHARGE_BAR_HEAD_OFFSET_X, Constants.CHARGE_BAR_HEAD_OFFSET_Y * scaleY)
        )
        if not Isaac or type(Isaac.WorldToScreen) ~= "function" then
            return nil, "Isaac.WorldToScreen is unavailable"
        end
        local ok, converted = pcall(Isaac.WorldToScreen, anchor)
        if not ok then
            return nil, tostring(converted)
        end
        if not converted then
            return nil, "Isaac.WorldToScreen returned no position"
        end
        return converted
    end

    local function canRenderChargeBarInCurrentPass()
        if not RenderMode or type(Game) ~= "function" then
            return true
        end
        local ok, renderMode = pcall(function()
            local game = Game()
            local room = game and type(game.GetRoom) == "function" and game:GetRoom() or nil
            if room and type(room.GetRenderMode) == "function" then
                return room:GetRenderMode()
            end
            return nil
        end)
        if not ok then
            return true
        end
        return renderMode ~= RenderMode.RENDER_WATER_REFRACT
            and renderMode ~= RenderMode.RENDER_WATER_REFLECT
    end

    local function postPlayerRender(_, player, _renderOffset)
        if not canRenderChargeBarInCurrentPass() then
            return nil
        end
        local state = getPlayerRuntime(player, false)
        if not state or state.chargeBarVisible ~= true then
            return nil
        end
        if playerIsDead(player) or not hasBigDogActive(player) then
            setChargeBarPhase(state, nil)
            return nil
        end
        local sprite = ensureChargeBarSprite(state)
        if not sprite then
            return nil
        end
        local phase = state.chargeBarPhase
        if phase == "charging" then
            local frame = math.floor(chargeProgress(state) * 100)
            if type(sprite.SetFrame) == "function" then
                pcall(sprite.SetFrame, sprite, "Charging", frame)
            end
        elseif phase == "start_charged" then
            if chargeBarAnimation(sprite) ~= "StartCharged" then
                playChargeBarAnimation(sprite, "StartCharged")
            elseif type(sprite.IsFinished) == "function" then
                local ok, finished = pcall(sprite.IsFinished, sprite, "StartCharged")
                if ok and finished == true then
                    setChargeBarPhase(state, "charged")
                    playChargeBarAnimation(sprite, "Charged")
                elseif type(sprite.Update) == "function" then
                    pcall(sprite.Update, sprite)
                end
            end
        elseif phase == "charged" then
            playChargeBarAnimation(sprite, "Charged")
            if type(sprite.Update) == "function" then
                pcall(sprite.Update, sprite)
            end
        elseif phase == "disappear" then
            if chargeBarAnimation(sprite) ~= "Disappear" then
                playChargeBarAnimation(sprite, "Disappear")
            elseif type(sprite.IsFinished) == "function" then
                local ok, finished = pcall(sprite.IsFinished, sprite, "Disappear")
                if ok and finished == true then
                    setChargeBarPhase(state, nil)
                    return nil
                elseif type(sprite.Update) == "function" then
                    pcall(sprite.Update, sprite)
                end
            end
        else
            return nil
        end
        local renderPosition, projectionError = chargeBarScreenPosition(player)
        if not renderPosition then
            local message = tostring(projectionError or "unknown projection failure")
            if state.chargeBarProjectionError ~= message then
                state.chargeBarProjectionError = message
                debugLog("chargebar WorldToScreen failed; skipping render: " .. message)
            end
            return nil
        end
        state.chargeBarProjectionError = nil
        if type(sprite.Render) == "function" then
            pcall(sprite.Render, sprite, renderPosition, newVector(0, 0), newVector(0, 0))
        end
        return nil
    end
    function callbackInstallers.postPlayerRender()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, postPlayerRender)
    end

    return {
        chargeProgress = chargeProgress,
        setChargeBarPhase = setChargeBarPhase,
        chargeBarAnimation = chargeBarAnimation,
        playChargeBarAnimation = playChargeBarAnimation,
        ensureChargeBarSprite = ensureChargeBarSprite,
        chargeBarScreenPosition = chargeBarScreenPosition,
        canRenderChargeBarInCurrentPass = canRenderChargeBarInCurrentPass,
        postPlayerRender = postPlayerRender,
        Installers = callbackInstallers,
    }
end
