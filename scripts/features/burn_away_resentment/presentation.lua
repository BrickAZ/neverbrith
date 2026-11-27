-- Private presentation ownership for Burn Away the Resentment.
return function(Neverbirth, deps)
    local Installers = {}
    local Config = deps.Config
    local GetFolkRoomKey = deps.World.GetFolkRoomKey
    local GetFolkPlayerKey = deps.World.GetFolkPlayerKey
    local Queries = deps.Queries
    local bursts = {}

    local function EnsureStatusSprite(state)
        if type(state) ~= "table" or state.statusSprite or not Sprite then
            return state and state.statusSprite or nil
        end
        local sprite = Sprite()
        if sprite.Load then
            pcall(function()
                sprite:Load(Config.StatusPath, true)
            end)
        end
        state.statusSprite = sprite
        return sprite
    end

    local function UpdateStatusSprite(state)
        if type(state) ~= "table" then
            return
        end
        local layers = tonumber(state.currentLayers) or 0
        local clarity = tonumber(state.currentFloorClarity) or 0
        local animation = nil
        local frame = nil
        if layers >= Config.MaxLayers then
            animation = "Ready"
        elseif layers > 0 then
            animation = "Resentment"
            frame = math.max(0, math.min(4, layers - 1))
        elseif clarity > 0 then
            animation = "Clarity"
            frame = math.max(0, math.min(5, clarity - 1))
        end
        if not animation then
            state.statusSprite = nil
            state.statusAnimation = nil
            state.statusFrame = nil
            return
        end
        local sprite = EnsureStatusSprite(state)
        if not sprite then
            return
        end
        if state.statusAnimation ~= animation and sprite.Play then
            pcall(function()
                sprite:Play(animation, true)
            end)
            state.statusAnimation = animation
            state.statusFrame = nil
        end
        if frame ~= nil and state.statusFrame ~= frame and sprite.SetFrame then
            pcall(function()
                sprite:SetFrame(animation, frame)
            end)
            state.statusFrame = frame
        end
        if sprite.Update then
            pcall(function()
                sprite:Update()
            end)
        end
    end

    local function SpawnBurst(player, spentLayers)
        if not Sprite or not player then
            return
        end
        local sprite = Sprite()
        if sprite.Load then
            pcall(function()
                sprite:Load(Config.BurstPath, true)
            end)
        end
        if sprite.Play then
            pcall(function()
                sprite:Play("Burst", true)
            end)
        end
        local scale = 0.75 + math.max(0, tonumber(spentLayers) or 0) * 0.1
        sprite.Scale = Vector(scale, scale)
        bursts[#bursts + 1] = {
            sprite = sprite,
            position = player.Position or Vector(320, 280),
            ownerKey = GetFolkPlayerKey(player),
            roomKey = GetFolkRoomKey(),
            age = 0,
        }
    end

    local function UpdateVisuals()
        for _, state in pairs(Neverbirth.BurnAwayResentment.states) do
            if state.player and Queries.PlayerHas(state.player) then
                UpdateStatusSprite(state)
            end
        end
        for index = #bursts, 1, -1 do
            local burst = bursts[index]
            burst.age = (tonumber(burst.age) or 0) + 1
            if burst.sprite and burst.sprite.Update then
                pcall(function()
                    burst.sprite:Update()
                end)
            end
            local finished = false
            if burst.sprite and burst.sprite.IsFinished then
                local ok, result = pcall(function()
                    return burst.sprite:IsFinished("Burst")
                end)
                finished = ok and result == true
            end
            if burst.roomKey ~= GetFolkRoomKey() or finished or burst.age >= Config.BurstTimeout then
                table.remove(bursts, index)
            end
        end
    end

    local function RenderVisuals()
        for _, state in pairs(Neverbirth.BurnAwayResentment.states) do
            if state.player and state.statusSprite and Queries.PlayerHas(state.player) and state.statusSprite.Render then
                local position = Neverbirth.BurnAwayResentment.GetPlayerHeadWorldPosition(state.player)
                if Isaac and Isaac.WorldToScreen then
                    local ok, screenPosition = pcall(function()
                        return Isaac.WorldToScreen(position)
                    end)
                    if ok and screenPosition then
                        position = screenPosition
                    end
                end
                pcall(function()
                    state.statusSprite:Render(position)
                end)
            end
        end
        for _, burst in ipairs(bursts) do
            if burst.sprite and burst.sprite.Render then
                local position = burst.position or Vector(320, 280)
                if Isaac and Isaac.WorldToScreen then
                    local ok, screenPosition = pcall(function()
                        return Isaac.WorldToScreen(position)
                    end)
                    if ok and screenPosition then
                        position = screenPosition
                    end
                end
                pcall(function()
                    burst.sprite:Render(position)
                end)
            end
        end
    end

    local function ClearOwnerBursts(key)
        for index = #bursts, 1, -1 do
            if bursts[index].ownerKey == key then
                table.remove(bursts, index)
            end
        end
    end

    local function ClearBursts()
        bursts = {}
    end

    function Installers.Render()
        Neverbirth:AddCallback(ModCallbacks.MC_POST_RENDER, function()
            RenderVisuals()
        end)
    end

    return {
        EnsureStatusSprite = EnsureStatusSprite,
        UpdateStatusSprite = UpdateStatusSprite,
        SpawnBurst = SpawnBurst,
        UpdateVisuals = UpdateVisuals,
        RenderVisuals = RenderVisuals,
        ClearOwnerBursts = ClearOwnerBursts,
        ClearBursts = ClearBursts,
        Installers = Installers,
    }
end
