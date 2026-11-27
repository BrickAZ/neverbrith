-- Item-owned visuals; the entry coordinates installation of the callback owners.
return function(Neverbirth, dependencies)
    local private = dependencies.Private or {}
    local Geometry = include("scripts.systems.player_geometry")
    local GetFolkRoomKey = dependencies.World.GetFolkRoomKey

    private.VisualSpecs = {
        Prompt = { path = "gfx/Effects/TheMoonIsBeautiful/moon_silence_prompt.anm2", animation = "Appear", nextAnimation = "Idle", nextAnimationFrames = 5, anchor = "playerHead", minHeadOffset = 18, headPadding = 4, followOffset = private.Config.PromptOffset },
        Fail = { path = "gfx/Effects/TheMoonIsBeautiful/moon_silence_prompt.anm2", animation = "Fail", anchor = "playerHead", minHeadOffset = 18, headPadding = 4, followOffset = private.Config.PromptOffset, timeout = 24 },
        Success = { path = "gfx/Effects/TheMoonIsBeautiful/moon_silence_success.anm2", animation = "Burst", anchor = "playerHead", followOffset = private.Config.SuccessOffset, timeout = 45 },
        Mark = { path = "gfx/Effects/TheMoonIsBeautiful/moon_mark.anm2", animation = "Idle", anchor = "enemyHead", minHeadOffset = 34, headPadding = 14 },
        BossMark = { path = "gfx/Effects/TheMoonIsBeautiful/moon_mark_boss.anm2", animation = "Idle", anchor = "enemyHead", minHeadOffset = 48, headPadding = 22 },
        Wave = { path = "gfx/Effects/TheMoonIsBeautiful/moon_mark_wave.anm2", animation = "Wave", timeout = 30 },
        Reward = { path = "gfx/Effects/TheMoonIsBeautiful/moon_reward_drop.anm2", animation = "Reward", timeout = 45 },
    }

    function private.SpawnVisual(key, owner, position)
        local spec = private.VisualSpecs[key]
        if type(spec) ~= "table" or not Sprite then
            return nil
        end

        local sprite = Sprite()
        if sprite.Load then
            pcall(function()
                sprite:Load(spec.path, true)
            end)
        end
        if sprite.Play then
            pcall(function()
                sprite:Play(spec.animation or "Idle", true)
            end)
        end

        private.nextVisualId = (tonumber(private.nextVisualId) or 0) + 1
        local id = private.nextVisualId
        private.visuals[id] = {
            id = id,
            key = key,
            sprite = sprite,
            animation = spec.animation or "Idle",
            owner = owner,
            position = position or (owner and owner.Position) or Vector(320, 280),
            roomKey = GetFolkRoomKey(),
            followOffset = spec.followOffset or Vector(0, 0),
            timeout = spec.timeout,
            nextAnimation = spec.nextAnimation,
            nextAnimationFrames = spec.nextAnimationFrames,
            age = 0,
        }
        return id
    end

    function private.RemoveVisual(id)
        if id then
            private.visuals[id] = nil
        end
    end

    function private.HasVisual(id)
        return id ~= nil and type(private.visuals) == "table" and private.visuals[id] ~= nil
    end

    function Neverbirth.Moon.ClearVisuals()
        for _, visual in pairs(private.visuals) do
            visual.owner, visual.sprite = nil, nil
        end
        private.visuals = {}
    end

    function private.IsOwnerValid(owner)
        if not owner or not owner.Position then
            return false
        end

        if owner.Exists then
            local ok, exists = pcall(function()
                return owner:Exists()
            end)
            if ok and exists == false then
                return false
            end
        end

        if owner.IsDead then
            local ok, dead = pcall(function()
                return owner:IsDead()
            end)
            if ok and dead == true then
                return false
            end
        end

        return true
    end

    function private.GetOwnerRenderOffset(owner)
        return Geometry.GetRenderOffset(owner)
    end

    function private.GetOwnerHeadOffset(owner, spec)
        local followOffset = (spec and spec.followOffset) or Vector(0, 0)
        if not spec then
            return followOffset
        end

        if spec.anchor == "playerHead" then
            local size = tonumber(owner and owner.Size) or 20
            local minOffset = tonumber(spec.minHeadOffset) or 18
            local padding = tonumber(spec.headPadding) or 4
            return followOffset + Vector(0, -math.max(minOffset, size + padding))
        end

        if spec.anchor == "enemyHead" then
            local size = tonumber(owner and owner.Size) or 20
            local minOffset = tonumber(spec.minHeadOffset) or 34
            local padding = tonumber(spec.headPadding) or 14
            return followOffset + Vector(0, -math.max(minOffset, size + padding))
        end

        return followOffset
    end

    function private.GetOwnerFootPosition(owner)
        if not owner or not owner.Position then
            return Vector(320, 280)
        end

        return owner.Position + private.GetOwnerRenderOffset(owner)
    end

    function private.GetVisualWorldPosition(visual)
        if type(visual) ~= "table" then
            return Vector(320, 280)
        end

        local spec = private.VisualSpecs and private.VisualSpecs[visual.key]
        if visual.owner and visual.owner.Position then
            return visual.owner.Position + private.GetOwnerRenderOffset(visual.owner) + private.GetOwnerHeadOffset(visual.owner, spec)
        end
        return visual.position or Vector(320, 280)
    end

    function private.GetVisualScreenPosition(visual)
        local worldPosition = private.GetVisualWorldPosition(visual)
        if Isaac and Isaac.WorldToScreen then
            local ok, screenPosition = pcall(function()
                return Isaac.WorldToScreen(worldPosition)
            end)
            if ok and screenPosition then
                return screenPosition
            end
        end
        return worldPosition
    end

    function private.UpdateVisuals()
        local currentRoomKey = GetFolkRoomKey()
        for id, visual in pairs(private.visuals or {}) do
            if (visual.roomKey and visual.roomKey ~= currentRoomKey) or (visual.owner and not private.IsOwnerValid(visual.owner)) then
                private.visuals[id] = nil
            else
                visual.position = private.GetVisualWorldPosition(visual)
                if visual.sprite and visual.sprite.Update then
                    pcall(function()
                        visual.sprite:Update()
                    end)
                end
                visual.age = (tonumber(visual.age) or 0) + 1
                if visual.nextAnimation and visual.nextAnimationFrames and visual.age >= visual.nextAnimationFrames then
                    if visual.sprite and visual.sprite.Play then
                        pcall(function()
                            visual.sprite:Play(visual.nextAnimation, true)
                        end)
                    end
                    visual.animation = visual.nextAnimation
                    visual.nextAnimation = nil
                    visual.nextAnimationFrames = nil
                end
                if visual.sprite and visual.sprite.IsFinished and not visual.nextAnimation then
                    local ok, finished = pcall(function()
                        return visual.sprite:IsFinished(visual.animation)
                    end)
                    if ok and finished == true and visual.timeout then
                        visual.timeout = 0
                    end
                end
                if visual.timeout then
                    visual.timeout = visual.timeout - 1
                    if visual.timeout <= 0 then
                        private.visuals[id] = nil
                    end
                end
            end
        end
    end

    function private.RenderVisuals()
        for _, visual in pairs(private.visuals) do
            if visual.sprite and visual.sprite.Render then
                local position = private.GetVisualScreenPosition(visual)
                pcall(function()
                    visual.sprite:Render(position)
                end)
            end
        end
    end

end
