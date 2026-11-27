-- Ordinary-data rules only; the adapter owns engine actions and persistence.
local Core = { Duration = 20 * 30, PlanCDelay = 3 * 30 }

function Core.MatchesRun(debt, runSeed)
    return type(debt) == 'table' and debt.runSeed == runSeed
end

function Core.NextTimer(timer, hasPlayer)
    timer = tonumber(timer) or 0
    if hasPlayer and timer > 0 then return timer - 1 end
    return timer
end

function Core.GetVisualKind(timer, windupFrames, beatFrames)
    timer = math.max(tonumber(timer) or 0, 0)
    if timer <= beatFrames then return 'Beat' end
    if timer <= windupFrames then return 'Windup' end
    return 'Contract'
end

return Core
