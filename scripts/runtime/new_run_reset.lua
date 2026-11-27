-- Creates an owner-local native callback; it neither registers callbacks nor
-- dispatches engine events. Cleanup all players before replacing shared state.
return function(steps)
    return function(_, isContinued)
        if isContinued then return end
        if steps.Players then
            for _, player in ipairs(steps.GetPlayers()) do
                for _, clear in ipairs(steps.Players) do clear(player) end
            end
        end
        for _, reset in ipairs(steps.Reset) do reset() end
    end
end
