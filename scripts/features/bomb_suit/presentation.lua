-- Private presentation responsibilities for bomb_suit; created once by its entry.
return function(mod, context, deps)
    local callbackInstallers = {}
    local data = deps.State.Data
    local DURATION = deps.Config.DURATION
    local stateFor = deps.State.stateFor

    local function beep(state)
        if SoundEffect and SoundEffect.SOUND_BEEP and SFXManager then
            SFXManager():Play(SoundEffect.SOUND_BEEP, 0.55, 0, false, 0.9 + state.age / DURATION * 0.65)
        end
    end

    local function render(_, player)
        local state = stateFor(player)
        if not state or not state.fuse or not Isaac.WorldToScreen then return end
        if RenderMode then
            local mode = Game():GetRoom():GetRenderMode()
            if mode ~= RenderMode.RENDER_NORMAL and mode ~= RenderMode.RENDER_NULL then return end
        end
        -- Same world->screen adapter as Burn Away Resentment; callback render
        -- offset is not added again. One presentation-only sprite per holder.
        local world = context.GetPlayerHeadWorldPosition and context.GetPlayerHeadWorldPosition(player)
            or player.Position + Vector(0, -35)
        state.fuse:Render(Isaac.WorldToScreen(world) + Vector(0, -10), Vector(0, 0), Vector(0, 0))
    end
    function callbackInstallers.render()
        return mod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, render)
    end

    return {
        Installers = callbackInstallers,
        beep = beep,
        render = render,
    }
end
