-- Preserve the public flat state while restricting each owner's field access.
-- These views are runtime-only; saved data stays in the original Store section.
return function(legacy)
    local function view(names)
        local fields = {}; for _, name in ipairs(names) do fields[name] = true end
        return setmetatable({}, {
            __index = function(_, key)
                assert(fields[key], 'traffic state read outside owner: ' .. tostring(key))
                return legacy[key]
            end,
            __newindex = function(_, key, value)
                assert(fields[key], 'traffic state write outside owner: ' .. tostring(key))
                legacy[key] = value
            end,
        })
    end
    return {
        Heat = view({ 'pendingHeatRefreshes' }),
        Rewards = view({ 'trafficInventorySeen', 'trafficAcquisitions', 'trafficPedestals', 'choiceGroups', 'nextChoiceId' }),
        Presentation = view({ 'visuals', 'choiceLinks', 'hudFonts', 'hudSprite', 'hudTier' }),
    }
end
