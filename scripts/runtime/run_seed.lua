local function GetCurrentRunSeed()
    if not Game then
        return "unknown"
    end

    local ok, game = pcall(Game)
    if not ok or not game or not game.GetSeeds then
        return "unknown"
    end

    local seeds = game:GetSeeds()
    if not seeds then
        return "unknown"
    end

    if seeds.GetStartSeedString then
        return seeds:GetStartSeedString()
    end

    if seeds.GetStartSeed then
        return tostring(seeds:GetStartSeed())
    end

    return "unknown"
end

return GetCurrentRunSeed
