-- Renders current extra lives without updating the acquisition ledger.
return function(dependencies)
    local function RenderLife(player, index, playerCount)
        local lives = dependencies.GetLifeCount(player)
        if lives > 0 then
            local label = (playerCount > 1 and ("P" .. index .. " ") or "") .. "+" .. tostring(lives)
            local originX, originY = dependencies.GetOrigin()
            local x = originX + (index - 1) * 60
            local y = originY
            dependencies.RenderText("", label, x + 1, y + 1, 0, 0, 0, 0.75)
            dependencies.RenderText("", label, x, y, 1, 0.8, 0.85, 1)
        end
    end

    return { RenderLife = RenderLife }
end
