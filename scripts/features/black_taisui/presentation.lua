-- Owns the family HUD and body-ward feedback; no life consumption or gameplay timers.
return function(Neverbirth, dependencies)
    local Runtime = assert(dependencies.Runtime)
    -- Native bindings are declared here; the entry chooses their installation phase.
    local callbackInstallers = {}
    local VisualEffects = dependencies.VisualEffects
    local GetFolkGame = dependencies.GetFolkGame
    local GetPlayers = dependencies.GetPlayers
    local MeatLump = dependencies.MeatLump
    local function DeathSaveFeedback(player)
        if player and player.SetColor and Color then
            pcall(function()
                player:SetColor(Color(0.35, 0.08, 0.45, 1, 0.12, 0, 0.2), 45, 1, true, false)
            end)
        end
        VisualEffects:Spawn("BlackTaisuiDeathDeny", player.Position or Vector(320, 280), player)
        local game = GetFolkGame()
        local hud = game and game.GetHUD and game:GetHUD()
        if hud and hud.ShowItemText then
            pcall(function()
                hud:ShowItemText(
                    Neverbirth:GetRuntimeText("blackTaisuiTitle"),
                    Neverbirth:GetRuntimeText("blackTaisuiDeathSaveSubtitle")
                )
            end)
        end
    end

    function Neverbirth:RenderBlackTaisuiLifeHud()
        if not Runtime.running or Runtime.disposed then return end
        if not Isaac then
            return
        end
        local game = GetFolkGame()
        local hud = game and game.GetHUD and game:GetHUD()
        if hud and hud.IsVisible and not hud:IsVisible() then return end
        local players = GetPlayers()
        for index, player in ipairs(players) do
            local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
            MeatLump.RenderLife(player, index, #players)
            if (tonumber(state.deathSaveFeedbackFrames) or 0) > 0 and player and player.Position and Isaac.WorldToScreen then
                local screen = Isaac.WorldToScreen(player.Position + Vector(0, -52))
                local textKey = state.deathSaveFeedbackKey or "blackTaisuiBlock"
                Neverbirth:RenderRuntimeText(textKey, "", screen.X - 34 + 1, screen.Y + 1, 0, 0, 0, 0.85)
                Neverbirth:RenderRuntimeText(textKey, "", screen.X - 34, screen.Y, 0.65, 0.22, 0.88, 1)
            end
        end
    end
    function callbackInstallers.InstallRender()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_RENDER, Neverbirth.RenderBlackTaisuiLifeHud)
    end



    return { DeathSaveFeedback = DeathSaveFeedback,
        InstallRender = callbackInstallers.InstallRender,
    }
end
