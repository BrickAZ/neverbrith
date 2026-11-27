-- Owns this feature's rules, state and callbacks. Dependencies are provided by main.lua.
return function(Neverbirth, dependencies)
    -- Private implementation state stays inside this installed feature instance.
    local private = {}
-- Keep native bindings beside handlers; invoke at their original installation phase.
local callbackInstallers = {}
local Items = assert(dependencies.Items)
local IsValidItemId = assert(dependencies.IsValidItemId)
local disposed = false
local runtimeActive = true
-- Debug Controller

Neverbirth.DebugController = {}
private = {
    anm2 = "gfx/UI/DebugController/DebugControllerKeys.anm2",
    states = {},
    sprites = {},
    directions = { "left", "up", "right", "down" },
    offsets = {
        left = Vector(-24, 0),
        up = Vector(0, -24),
        right = Vector(24, 0),
        down = Vector(0, 24),
    },
    actions = {
        left = { "ACTION_SHOOTLEFT" },
        up = { "ACTION_SHOOTUP" },
        right = { "ACTION_SHOOTRIGHT" },
        down = { "ACTION_SHOOTDOWN" },
    },
    layouts = {
        root = {
            left = { page = "left", animation = "Left", label = "<" },
            up = { page = "up", animation = "Up", label = "^" },
            right = { page = "right", animation = "Right", label = ">" },
            down = { page = "down", animation = "Down", label = "v" },
        },
        left = {
            down = { command = 1, animation = "Num1", label = "1" },
            left = { command = 2, animation = "Num2", label = "2" },
            up = { command = 3, animation = "Num3", label = "3" },
            right = { page = "root", animation = "Back", label = "B" },
        },
        up = {
            down = { page = "root", animation = "Back", label = "B" },
            left = { command = 4, animation = "Num4", label = "4" },
            up = { command = 5, animation = "Num5", label = "5" },
            right = { command = 6, animation = "Num6", label = "6" },
        },
        right = {
            left = { page = "root", animation = "Back", label = "B" },
            up = { command = 7, animation = "Num7", label = "7" },
            right = { command = 8, animation = "Num8", label = "8" },
            down = { command = 9, animation = "Num9", label = "9" },
        },
        down = {
            up = { page = "root", animation = "Back", label = "B" },
            left = { command = 12, animation = "Num12", label = "12" },
            right = { command = 13, animation = "Num13", label = "13" },
            down = { command = 10, animation = "Num10", label = "10" },
        },
    },
}

function private.GetPlayerKey(player)
    return tostring((player and player.InitSeed) or "0")
end

function private.IsPlayerDead(player)
    if not player then
        return true
    end

    if player.IsDead then
        local ok, result = pcall(function()
            return player:IsDead()
        end)
        if ok then
            return result == true
        end
    end

    return player.dead == true or player.Dead == true
end

function private.PlayerHasItem(player)
    if not player or not IsValidItemId(Items.DebugController) then
        return false
    end

    if player.HasCollectible then
        local ok, hasItem = pcall(function()
            return player:HasCollectible(Items.DebugController)
        end)
        if ok and hasItem then
            return true
        end
    end

    if player.GetActiveItem then
        for slot = 0, 3 do
            local ok, activeItem = pcall(function()
                return player:GetActiveItem(slot)
            end)
            if ok and activeItem == Items.DebugController then
                return true
            end
        end
    end

    return false
end

function private.Close(player)
    private.states[private.GetPlayerKey(player)] = nil
end

function private.IsOpen(player)
    return private.states[private.GetPlayerKey(player)] ~= nil
end

function private.Open(player)
    private.states[private.GetPlayerKey(player)] = {
        player = player,
        page = "root",
        previous = {},
    }
end

function private.GetCommand(number)
    return "debug " .. tostring(number)
end

function private.ExecuteCommand(number)
    if Isaac and Isaac.ExecuteCommand then
        local command = private.GetCommand(number)
        pcall(function()
            Isaac.ExecuteCommand(command)
        end)
    end
end

function private.GetControllerIndex(player)
    if not player then return nil end
    return player.ControllerIndex or player.ControllerId or player.Controller
end

function Neverbirth.DebugController.IsDirectionPressed(player, direction)
    if not (Input and Input.IsActionPressed and ButtonAction) then
        return false
    end

    local controllerIndex = private.GetControllerIndex(player)
    if controllerIndex == nil then return false end
    for _, actionName in ipairs(private.actions[direction] or {}) do
        local action = ButtonAction[actionName]
        if action ~= nil then
            local ok, pressed = pcall(function()
                return Input.IsActionPressed(action, controllerIndex)
            end)
            if ok and pressed then
                return true
            end
        end
    end

    return false
end

function private.HandleDirection(player, state, direction)
    local page = state.page or "root"
    local entry = private.layouts[page] and private.layouts[page][direction]
    if not entry then
        return
    end

    if entry.page then
        state.page = entry.page
        return
    end

    if entry.command then
        private.ExecuteCommand(entry.command)
        private.Close(player)
    end
end

function private.GetSprite(animation)
    if not Sprite then
        return nil
    end

    local sprite = private.sprites[animation]
    if sprite then
        return sprite
    end

    local ok, newSprite = pcall(function()
        return Sprite()
    end)
    if not ok or not newSprite then
        return nil
    end

    if newSprite.Load then
        pcall(function()
            newSprite:Load(private.anm2, true)
        end)
    end
    if newSprite.Play then
        pcall(function()
            newSprite:Play(animation, true)
        end)
    end

    private.sprites[animation] = newSprite
    return newSprite
end

function private.RenderIcon(entry, position)
    local animation = entry.animation
    local sprite = animation and private.GetSprite(animation)
    if sprite and sprite.Render then
        pcall(function()
            if sprite.Play then
                sprite:Play(animation, true)
            end
            sprite:Render(position)
        end)
        return
    end

    if Isaac and Isaac.RenderText then
        Isaac.RenderText(entry.label or "?", position.X - 4, position.Y - 4, 1, 1, 1, 1)
    end
end

function Neverbirth:UseDebugController(_, _, player)
    if not runtimeActive then return { Discharge = false, Remove = false, ShowAnim = true } end
    if not player then
        return { Discharge = false, Remove = false, ShowAnim = true }
    end

    if private.IsOpen(player) then
        private.Close(player)
    else
        private.Open(player)
    end

    return { Discharge = false, Remove = false, ShowAnim = true }
end
function callbackInstallers.Neverbirth_UseDebugController()
    return Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseDebugController, Items.DebugController)
end

function Neverbirth:UpdateDebugControllerMenus()
    if not runtimeActive then return end
    for key, state in pairs(private.states) do
        local player = state.player
        if not player or private.IsPlayerDead(player) or not private.PlayerHasItem(player) then
            private.states[key] = nil
        else
            state.previous = state.previous or {}
            for _, direction in ipairs(private.directions) do
                local pressed = Neverbirth.DebugController.IsDirectionPressed(player, direction)
                if pressed and not state.previous[direction] then
                    private.HandleDirection(player, state, direction)
                    if not private.states[key] then
                        break
                    end
                end
                state.previous[direction] = pressed
            end
        end
    end
end
function callbackInstallers.Neverbirth_UpdateDebugControllerMenus()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateDebugControllerMenus)
end

function Neverbirth:RenderDebugControllerMenus()
    if not runtimeActive then return end
    if not (Isaac and Isaac.WorldToScreen) then
        return
    end

    for _, state in pairs(private.states) do
        local player = state.player
        if player and player.Position then
            local base = Isaac.WorldToScreen(player.Position + Vector(0, -54))
            local layout = private.layouts[state.page or "root"] or private.layouts.root
            for direction, entry in pairs(layout) do
                local offset = private.offsets[direction] or Vector(0, 0)
                private.RenderIcon(entry, base + offset)
            end
        end
    end
end
function callbackInstallers.Neverbirth_RenderDebugControllerMenus()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_RENDER, Neverbirth.RenderDebugControllerMenus)
end

function Neverbirth:SuppressDebugControllerTear(tear)
    if not runtimeActive then return end
    if not tear then
        return
    end

    local spawner = tear.SpawnerEntity or tear.Spawner or tear.Parent
    local player = spawner
    if player and player.ToPlayer then
        local ok, converted = pcall(function()
            return player:ToPlayer()
        end)
        player = ok and converted or player
    end

    if player and private.IsOpen(player) then
        if tear.Remove then
            pcall(function()
                tear:Remove()
            end)
        end
    end
end
function callbackInstallers.Neverbirth_SuppressDebugControllerTear()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, Neverbirth.SuppressDebugControllerTear)
end

function Neverbirth:CloseDebugControllerMenus()
    if not disposed then runtimeActive = true end
    private.states = {}
    private.sprites = {}
end
function callbackInstallers.Neverbirth_CloseDebugControllerMenus()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, Neverbirth.CloseDebugControllerMenus)
end
function callbackInstallers.Neverbirth_CloseDebugControllerMenus2()
    -- Menus and cached Sprites are transient, including Continue.
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.CloseDebugControllerMenus)
end

local function InstallTeardown()
    if ModCallbacks.MC_PRE_GAME_EXIT then
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
            Neverbirth:CloseDebugControllerMenus()
            runtimeActive = false
        end)
    end
    if ModCallbacks.MC_PRE_MOD_UNLOAD then
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, function(_, mod)
            if mod ~= Neverbirth then return end
            disposed = true
            runtimeActive = false
            Neverbirth:CloseDebugControllerMenus()
        end)
    end
end

return {
InstallUse = function() callbackInstallers.Neverbirth_UseDebugController() end,
InstallUpdate = function() callbackInstallers.Neverbirth_UpdateDebugControllerMenus() end,
InstallRender = function() callbackInstallers.Neverbirth_RenderDebugControllerMenus() end,
InstallTear = function() callbackInstallers.Neverbirth_SuppressDebugControllerTear() end,
InstallLevel = function() callbackInstallers.Neverbirth_CloseDebugControllerMenus() end,
InstallGameStarted = function() callbackInstallers.Neverbirth_CloseDebugControllerMenus2(); InstallTeardown() end,
}

end
