-- Private presentation ownership for Cleaver.
return function(Neverbirth, deps)
    local Installers = {}
    local lifetime = deps.Lifetime
    local Queries = deps.Queries
    local Geometry = deps.Geometry

    local function CaptureShadowSprite(target)
        if not target or not target.GetSprite or not Sprite then
            return nil
        end
        local ok, source = pcall(function()
            return target:GetSprite()
        end)
        if not ok or not source or not source.GetFilename or not source.GetAnimation or not source.GetFrame then
            return nil
        end
        local filename, animation, frame = nil, nil, nil
        ok = pcall(function()
            filename = source:GetFilename()
            animation = source:GetAnimation()
            frame = source:GetFrame()
        end)
        if not ok or type(filename) ~= "string" or filename == "" or type(animation) ~= "string" or animation == "" then
            return nil
        end
        local snapshot = Sprite()
        ok = pcall(function()
            snapshot:Load(filename, true)
            snapshot:SetFrame(animation, tonumber(frame) or 0)
            snapshot.Color = Color(0, 0, 0, Neverbirth.Cleaver.Config.ShadowAlpha, 0, 0, 0)
        end)
        return ok and snapshot or nil
    end

    local function GetSwingAnimation(direction, variant)
        local base = nil
        if math.abs(direction.X) >= math.abs(direction.Y) then
            base = direction.X >= 0 and "SwingRight" or "SwingLeft"
        else
            base = direction.Y >= 0 and "SwingDown" or "SwingUp"
        end
        return base .. "_" .. (variant == "B" and "B" or "A")
    end

    local function GetHoldAnimation(direction, variant)
        local suffix = variant == "B" and "B" or "A"
        if not direction or not direction.Length or direction:Length() <= 0 then
            return "IdleDown_" .. suffix
        end
        if math.abs(direction.X) >= math.abs(direction.Y) then
            return (direction.X >= 0 and "IdleRight_" or "IdleLeft_") .. suffix
        end
        return (direction.Y >= 0 and "IdleDown_" or "IdleUp_") .. suffix
    end

    local function EnsureHoldVisual(state)
        if not state or state.holdVisual then return state and state.holdVisual or nil end
        if not Sprite then return nil end
        local sprite = Sprite()
        local animation = GetHoldAnimation(state.holdDirection, state.lastSwingVariant)
        local loaded = false
        local ok = pcall(function()
            local result = sprite:Load(Neverbirth.Cleaver.Config.HoldVisualPath, true)
            if result ~= false then
                sprite:Play(animation, true)
                loaded = true
            end
        end)
        if not ok or not loaded then return nil end
        local scale = tonumber(Neverbirth.Cleaver.Config.HoldScale) or 0.65
        if sprite.Scale ~= nil and Vector then sprite.Scale = Vector(scale, scale) end
        state.holdVisual = { sprite = sprite, animation = animation }
        return state.holdVisual
    end

    local function UpdateHoldVisual(state, direction)
        if not state then return end
        if direction and direction.Length and direction:Length() > 0 then
            state.holdDirection = direction:Normalized()
        elseif not state.holdDirection then
            state.holdDirection = Vector(0, 1)
        end
        local hold = EnsureHoldVisual(state)
        if not hold or not hold.sprite then return end
        local animation = GetHoldAnimation(state.holdDirection, state.lastSwingVariant)
        if hold.animation ~= animation then
            hold.animation = animation
            if hold.sprite.Play then pcall(function() hold.sprite:Play(animation, true) end) end
        end
        if hold.sprite.Update then pcall(function() hold.sprite:Update() end) end
    end

    local function GetHoldWorldPosition(player, direction, variant)
        local animation = GetHoldAnimation(direction, variant)
        local offsets = Neverbirth.Cleaver.Config.HoldOffsets or {}
        local offset = offsets[animation] or { x = 0, y = 0 }
        return Geometry.GetPlayerBodyWorldPosition(player) + Vector(tonumber(offset.x) or 0, tonumber(offset.y) or 0)
    end

    local function CreateSwingVisual(player, direction, variant)
        if not Sprite then return nil end
        local sprite = Sprite()
        local animation = GetSwingAnimation(direction, variant)
        local ok = pcall(function()
            sprite:Load(Neverbirth.Cleaver.Config.CleaverVisualPath, true)
            sprite:Play(animation, true)
        end)
        if not ok then return nil end
        -- Idle and swing share the same authored actor, so they must share the same scale.
        local scale = tonumber(Neverbirth.Cleaver.Config.HoldScale) or 0.5
        if sprite.Scale ~= nil and Vector then sprite.Scale = Vector(scale, scale) end
        return { sprite = sprite, animation = animation, age = 0, player = player, animationUpdates = 0 }
    end

    function Neverbirth:RenderCleaverShadows()
        if not lifetime.runtimeActive then return end
        if not (Isaac and Isaac.WorldToScreen and Color) then
            return
        end
        for _, shadow in pairs(Neverbirth.Cleaver.shadows) do
            if Queries.IsTargetAlive(shadow.target) and shadow.sprite and shadow.sprite.Render then
                local screen = Isaac.WorldToScreen(shadow.position + (shadow.renderOffset or Vector(0, 0)))
                pcall(function()
                    shadow.sprite:Render(screen)
                end)
            end
        end
        for _, state in pairs(Neverbirth.Cleaver.states) do
            local swing = state.swing
            local hold = state.holdVisual
            if hold and hold.sprite and hold.sprite.Render and state.player and not swing then
                local screen = Isaac.WorldToScreen(GetHoldWorldPosition(state.player, state.holdDirection, state.lastSwingVariant))
                pcall(function() hold.sprite:Render(screen) end)
            end        local visual = swing and swing.visual
            if visual and visual.sprite and visual.sprite.Render and state.player then
                local screen = Isaac.WorldToScreen(Geometry.GetPlayerBodyWorldPosition(state.player))
                pcall(function() visual.sprite:Render(screen) end)
            end
        end
    end
    function Installers.Render()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_RENDER, Neverbirth.RenderCleaverShadows)
    end

    return {
        CaptureShadowSprite = CaptureShadowSprite,
        GetSwingAnimation = GetSwingAnimation,
        GetHoldAnimation = GetHoldAnimation,
        EnsureHoldVisual = EnsureHoldVisual,
        UpdateHoldVisual = UpdateHoldVisual,
        GetHoldWorldPosition = GetHoldWorldPosition,
        CreateSwingVisual = CreateSwingVisual,
        RenderCleaverShadows = Neverbirth.RenderCleaverShadows,
        Installers = Installers,
    }
end
