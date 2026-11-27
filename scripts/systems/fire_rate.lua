-- Add shots per second, preserving the legacy lower bounds. Direct fire-delay
-- subtraction (Chunyao, Wavy Cap, Good Girl) is a different mechanic.
return function(maxFireDelay, amount)
    local delay = tonumber(maxFireDelay) or 0
    local bonus = math.max(0, tonumber(amount) or 0)
    if bonus <= 0 then return delay end
    local tears = 30 / math.max(0.0001, delay + 1)
    return 30 / math.max(0.0001, tears + bonus) - 1
end
