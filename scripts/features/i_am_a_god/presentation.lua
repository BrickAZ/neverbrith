-- Private presentation responsibilities for i_am_a_god; created once by its entry.
return function(mod, context, deps)
    local callbackInstallers = {}
    local data = deps.State.Data
    local alive = deps.State.alive

    local function visual(path,animation)
        if data.badVisuals[path] then return nil end
        local ok,sprite=pcall(function()
            local s=Sprite();s:Load(path,true)
            s:Play(animation,true)
            if s:GetAnimation()~=animation then error("animation missing") end
            return s
        end)
        if ok then return sprite end
        data.badVisuals[path]=true
        if context.DebugLog then context.DebugLog("[我即神明] 特效资源不可用，机制继续运行："..path) end
    end

    local function playDeclarationSound()
        local ok,err=pcall(function()
            if not data.declarationSoundId then
                local id=Isaac.GetSoundIdByName("I Am a God Declaration")
                if not id or id<=0 then error("I Am a God Declaration is not registered") end
                data.declarationSoundId=id
            end
            SFXManager():Play(data.declarationSoundId,1,0,false,1)
        end)
        if not ok and not data.soundWarning then
            data.soundWarning=true
            if context.DebugLog then context.DebugLog("[我即神明] 宣言语音不可用，机制继续运行："..tostring(err)) end
        end
    end

    local function headPosition(p)
        -- Same world-anchor adapter as the existing BurnAway overhead sprite.
        if context.GetPlayerHeadWorldPosition then return context.GetPlayerHeadWorldPosition(p) end
        return p.Position+Vector(0,-math.max(18,(p.Size or 20)+4))
    end

    local function addBurst(path,animation,p,timeout)
        local s=visual(path,animation)
        if s then data.bursts[#data.bursts+1]={sprite=s,animation=animation,player=p,position=headPosition(p),
            room=data.currentKey,age=0,timeout=timeout} end
    end

    local function render()
        if not data.ready or not Isaac.WorldToScreen then return end
        -- MC_POST_RENDER runs once after room/entity passes. GetRenderMode is
        -- RENDER_NULL here; requiring RENDER_NORMAL hides every owned sprite.
        -- Reflection/refraction filtering belongs in entity-render callbacks.
        if data.active and data.active.crown and alive(data.active.player) then data.active.crown:Render(Isaac.WorldToScreen(headPosition(data.active.player))) end
        for _,b in ipairs(data.bursts) do
            local position=alive(b.player) and headPosition(b.player) or b.position
            b.sprite:Render(Isaac.WorldToScreen(position))
        end
    end
    function callbackInstallers.render()
        return mod:AddCallback(ModCallbacks.MC_POST_RENDER,render)
    end

    return {
        Installers = callbackInstallers,
        visual = visual,
        playDeclarationSound = playDeclarationSound,
        headPosition = headPosition,
        addBurst = addBurst,
        render = render,
    }
end
