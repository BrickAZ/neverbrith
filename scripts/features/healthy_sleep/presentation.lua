-- Native overlay ownership, pause observation and the sleep clock HUD.
return function(mod, State)
    local callbackInstallers = {}
    local runtime = State.runtime
    local sleepState = State.sleepState
    local inOrigin = State.inOrigin
    local bedRecord = State.bedRecord
    local function restoreOverlayColor()
        if runtime.overlayColor and ItemOverlay.GetOverlayID() == Giantbook.SLEEP then
            ItemOverlay.GetSprite().Color = runtime.overlayColor
        end
        runtime.overlayColor = nil
    end

    local function overlayActive()
        return ItemOverlay.GetOverlayID() == Giantbook.SLEEP and ItemOverlay.GetSprite():IsPlaying('Idle')
    end
    local function clockPaused()
        local game = Game()
        return game:IsPauseMenuOpen() or (game:IsPaused() and not (runtime.ownedOverlay and overlayActive()))
    end

    local function render()
        if not runtime.ready then return end
        local sleep = sleepState()
        if not sleep then return end
        local game = Game()
        -- Render observes pause to discard the interval even when updates stop.
        -- It does not advance progress or grant gameplay rewards.
        if clockPaused() then runtime.lastTime=nil end
        if not inOrigin() or bedRecord().phase == 'cancelled' then return end
        if sleep.settled and (not runtime.completedUntil or Isaac.GetTime() > runtime.completedUntil) then return end
        local nativeMovie = runtime.ownedOverlay and overlayActive()
        if nativeMovie then
            -- In this build vanilla draws ItemOverlay AFTER MC_POST_RENDER.
            -- Draw the same native sprite here, then make only its later copy
            -- transparent. This puts our clock above it without an ANM2 edit.
            local sprite = ItemOverlay.GetSprite()
            runtime.overlayColor = runtime.overlayColor or sprite.Color
            sprite.Color = runtime.overlayColor
            sprite:Render(Vector(Isaac.GetScreenWidth()/2, Isaac.GetScreenHeight()/2), Vector.Zero, Vector.Zero)
            local c = runtime.overlayColor
            sprite.Color = Color(c.R,c.G,c.B,0,c.RO,c.GO,c.BO)
        end
        local hud = game:GetHUD()
        if hud and not hud:IsVisible() and not nativeMovie then return end
        local minutes = math.min(480, math.floor((sleep.elapsed or 0)/60))
        local clock = string.format('%02d:%02d / 08:00', math.floor(minutes/60), minutes%60)
        local x, y = Isaac.GetScreenWidth()/2-47, Isaac.GetScreenHeight()-46
        mod:RenderRuntimeText('', clock, x+1, y+1, 0,0,0,0.85)
        mod:RenderRuntimeText('', clock, x, y, 0.75,0.85,1,1)
    end
    function callbackInstallers.render()
        return mod:AddCallback(ModCallbacks.MC_POST_RENDER, render)
    end
    return { Installers=callbackInstallers, restoreOverlayColor=restoreOverlayColor, overlayActive=overlayActive, clockPaused=clockPaused }
end
