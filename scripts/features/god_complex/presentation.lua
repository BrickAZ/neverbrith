-- Private presentation responsibilities for god_complex; created once by its entry.
return function(mod, context, deps)
    local callbackInstallers = {}
    local data = deps.State.Data
    local ROOT = deps.Config.ROOT
    local SOLAR_DAMAGE_RADIUS = deps.Config.SOLAR_DAMAGE_RADIUS
    local SOLAR_HALO_BOUNDS = deps.Config.SOLAR_HALO_BOUNDS
    local log = deps.State.log
    local enemy = deps.Targeting.enemy
    local state = deps.State.state

    local function visual(file,animation)
        local path=ROOT..file..'.anm2'
        if data.badVisuals[path] then return nil end
        local ok,s=pcall(function()
            local sprite=Sprite();sprite:Load(path,true);sprite:Play(animation,true)
            if sprite:GetAnimation()~=animation then error('animation missing: '..animation) end
            return sprite
        end)
        if ok then return s end
        data.badVisuals[path]=true;log('Visual unavailable; gameplay remains active: '..path..' ('..tostring(s)..')')
    end

    local function startVisuals(s)
        s.visuals.state=visual('GodComplexState',s.form)
        -- A small floating status badge, not a full-size mask over Isaac's face.
        if s.visuals.state then s.visuals.state.Scale=Vector(0.5,0.5) end
        if s.form=='Solar' then s.visuals.halo=visual('GodComplexSolarHalo','SolarHalo')
        elseif s.form=='Eye' then
            s.visuals.mark=visual('GodComplexEyeMark','EyeMark')
            -- Two 12-frame strikes can overlap at the six-frame damage cadence.
            s.visuals.strike1=visual('GodComplexJudgment','Judgment')
            s.visuals.strike2=visual('GodComplexJudgment','Judgment')
        end
    end

    local function draw(sprite,world,screenOffset,fitSolarHalo)
        if not sprite then return end
        local ok,err=pcall(function()
            if not Isaac.WorldToScreen then error('WorldToScreen unavailable') end
            local screen=Isaac.WorldToScreen(world)
            if fitSolarHalo then
                local b=SOLAR_HALO_BOUNDS[math.floor(sprite:GetFrame()/3)+1]
                -- Project the actual damage boundary, not the transparent
                -- 64px canvas. Fit each animated ellipse to that same range.
                local r=SOLAR_DAMAGE_RADIUS
                local left=Isaac.WorldToScreen(world+Vector(-r,0)).X
                local right=Isaac.WorldToScreen(world+Vector(r,0)).X
                local top=Isaac.WorldToScreen(world+Vector(0,-r)).Y
                local bottom=Isaac.WorldToScreen(world+Vector(0,r)).Y
                local sx,sy=(right-left)/(b[3]-b[1]),(bottom-top)/(b[4]-b[2])
                sprite.Scale=Vector(sx,sy)
                -- The visible ring is slightly off the ANM2 pivot (32,32).
                screen=Vector(left+(32-b[1])*sx,top+(32-b[2])*sy)
            end
            if screenOffset then screen=screen+screenOffset end
            sprite:Render(screen,Vector.Zero,Vector.Zero)
        end)
        if not ok and not data.badVisuals.render then data.badVisuals.render=true;log('Owned render skipped: '..tostring(err)) end
    end

    local function head(e) return e.Position+Vector(0,-math.max(18,(e.Size or 12)+4)) end

    local function mainRenderPass()
        if not data.ready then return false end
        local mode=Game():GetRoom():GetRenderMode()
        return mode==RenderMode.RENDER_NULL or mode==RenderMode.RENDER_NORMAL
    end

    local function renderUnderPlayer(_,p)
        if not mainRenderPass() then return end
        local s=state(p)
        -- PRE_PLAYER_RENDER places the halo behind its owner. Position is the
        -- logical ground anchor; body/flying/callback offsets do not move it.
        -- Return nil so the engine still renders Isaac normally afterwards.
        if s then draw(s.visuals.halo,p.Position,nil,true) end
    end
    function callbackInstallers.renderUnderPlayer()
        return mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_RENDER,renderUnderPlayer)
    end

    local function render()
        if not mainRenderPass() then return end
        for _,s in pairs(data.active) do
            if state(s.player) then
                -- Clearance is in screen pixels after one camera conversion.
                -- The ANM2 pivot is near the badge bottom; 40px clears a normal
                -- head, and SpriteScale keeps enlarged players clear as well.
                local height=40*math.max(1,s.player.SpriteScale and s.player.SpriteScale.Y or 1)
                draw(s.visuals.state,s.player.Position,Vector(0,-height))
                if s.target and enemy(s.target,true) then draw(s.visuals.mark,head(s.target)) end
                for _,b in pairs(s.strikes) do draw(b.sprite,b.position) end
            end
        end
    end
    function callbackInstallers.render()
        return mod:AddCallback(ModCallbacks.MC_POST_RENDER,render)
    end

    return {
        Installers = callbackInstallers,
        visual = visual,
        startVisuals = startVisuals,
        draw = draw,
        head = head,
        mainRenderPass = mainRenderPass,
        renderUnderPlayer = renderUnderPlayer,
        render = render,
    }
end
