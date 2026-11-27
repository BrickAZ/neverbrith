local function GetPlayers()
    local players = {}

    if Game and Isaac.GetPlayer then
        local gameOk, game = pcall(Game)
        if gameOk and game and game.GetNumPlayers then
            local countOk, playerCount = pcall(function()
                return game:GetNumPlayers()
            end)
            playerCount = countOk and tonumber(playerCount) or 0

            for index = 0, playerCount - 1 do
                local playerOk, player = pcall(function()
                    return Isaac.GetPlayer(index)
                end)
                if playerOk and player then
                    if player.ToPlayer then
                        local toPlayerOk, convertedPlayer = pcall(function()
                            return player:ToPlayer()
                        end)
                        player = toPlayerOk and convertedPlayer or player
                    end

                    if player then
                        players[#players + 1] = player
                    end
                end
            end

            if #players > 0 then
                return players
            end
        end
    end

    if Isaac.FindByType then
        for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PLAYER, -1, -1, false, false)) do
            local player = entity and entity.ToPlayer and entity:ToPlayer()
            if player then
                players[#players + 1] = player
            end
        end
    end

    return players
end

return GetPlayers
