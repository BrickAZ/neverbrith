return function(Neverbirth, dependencies)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local COIN_SWORD_MODE_CONFIGS = dependencies.Rules.COIN_SWORD_MODE_CONFIGS
    local function AngleFromVector(vector)
        return math.atan(vector.Y, vector.X) * 180 / math.pi
    end

    local function GetCoinSwordAnimationName(mode)
        if mode == "blood" then
            return "BloodSlash"
        elseif mode == "empowered" then
            return "EmpoweredSlash"
        end

        return "Slash"
    end

    local function SafeSetCoinSwordField(target, field, value)
        if not target then
            return false
        end

        local ok = pcall(function()
            target[field] = value
        end)
        return ok == true
    end

    local function PlayCoinSwordAnimation(effect, mode, direction)
        if not effect or not effect.GetSprite then
            return
        end

        local sprite = effect:GetSprite()
        if not sprite then
            return
        end

        local animation = GetCoinSwordAnimationName(mode)

        if sprite.Play then
            pcall(function()
                sprite:Play(animation, true)
            end)
        end
        local angle = AngleFromVector(direction or Vector(1, 0))
        local config = COIN_SWORD_MODE_CONFIGS[mode or "normal"] or COIN_SWORD_MODE_CONFIGS.normal
        local scaleValue = config.scale or 1
        local scale = Vector(scaleValue, scaleValue)
        SafeSetCoinSwordField(sprite, "Rotation", angle)
        SafeSetCoinSwordField(effect, "SpriteRotation", angle)
        SafeSetCoinSwordField(sprite, "Scale", scale)
        SafeSetCoinSwordField(effect, "SpriteScale", scale)
    end

    local function UpdateCoinSwordVisualDirection(effect, direction)
        if not effect or not direction then
            return
        end

        local angle = AngleFromVector(direction)
        if effect.GetSprite then
            local sprite = effect:GetSprite()
            SafeSetCoinSwordField(sprite, "Rotation", angle)
        end
        SafeSetCoinSwordField(effect, "SpriteRotation", angle)
    end

    local function PlayDisappear(effect)
        if effect.GetSprite then
            local sprite = effect:GetSprite()
            if sprite and sprite.Play then
                pcall(function()
                    sprite:Play("Disappear", true)
                end)
            end
        end
    end

    local function RenderCoinSwordQiDebugText(text, position, red, green, blue, alpha)
        if not position or not Isaac.WorldToScreen or not Isaac.RenderText then
            return
        end

        local ok, screen = pcall(function()
            return Isaac.WorldToScreen(position)
        end)
        if not ok or not screen then
            return
        end

        pcall(function()
            Isaac.RenderText(text, screen.X, screen.Y, red, green, blue, alpha)
        end)
    end

    function Neverbirth:RenderCoinSwordQiDebug()
        if not dependencies.Runtime.running or dependencies.Runtime.disposed then return end
        if not self.DebugCoinSwordHitbox then
            return
        end
        if not Isaac.GetRoomEntities then
            return
        end

        for _, effect in ipairs(Isaac.GetRoomEntities()) do
            local data = effect and effect.GetData and effect:GetData() or nil
            if type(data) == "table" and data.NeverbirthCoinSwordQi and effect.Position and data.Direction then
                local direction = data.Direction
                if not direction.Length or direction:Length() <= 0 then
                    direction = Vector(1, 0)
                else
                    direction = direction:Normalized()
                end

                local length = tonumber(data.Length) or COIN_SWORD_MODE_CONFIGS.normal.length
                local width = tonumber(data.Width) or COIN_SWORD_MODE_CONFIGS.normal.width
                local backLength = tonumber(data.BackLength) or COIN_SWORD_MODE_CONFIGS.normal.back
                local radius = width / 2
                local side = Vector(-direction.Y, direction.X)
                local red, green, blue = 0.2, 1, 0.2
                if data.Mode == "blood" then
                    red, green, blue = 1, 0.15, 0.15
                elseif data.Mode == "empowered" then
                    red, green, blue = 1, 0.85, 0.15
                end

                RenderCoinSwordQiDebugText("CSQ " .. tostring(data.Mode or "normal"), effect.Position, red, green, blue, 1)
                for index = 0, 4 do
                    local forward = -backLength + ((length + backLength) * index / 4)
                    local center = effect.Position + direction * forward
                    RenderCoinSwordQiDebugText(".", center, red, green, blue, 0.9)
                    RenderCoinSwordQiDebugText(".", center + side * radius, red, green, blue, 0.9)
                    RenderCoinSwordQiDebugText(".", center - side * radius, red, green, blue, 0.9)
                end
                RenderCoinSwordQiDebugText("o", effect.Position + direction * length, red, green, blue, 0.9)
                RenderCoinSwordQiDebugText("o", effect.Position - direction * backLength, red, green, blue, 0.9)
            end
        end
    end
    function callbackInstallers.Neverbirth_RenderCoinSwordQiDebug()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_RENDER, Neverbirth.RenderCoinSwordQiDebug)
    end

    local function InstallDebugCallback()
        if ModCallbacks.MC_POST_RENDER then
            callbackInstallers.Neverbirth_RenderCoinSwordQiDebug()
        end
    end

    return { SetField = SafeSetCoinSwordField, UpdateDirection = UpdateCoinSwordVisualDirection, Play = PlayCoinSwordAnimation, AnimationName = GetCoinSwordAnimationName,
        PlayDisappear = PlayDisappear, InstallDebugCallback = InstallDebugCallback }
end
