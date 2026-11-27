-- Owns the legacy acquired-copy and extra-life fields; resolves the current save on every operation.
return function(dependencies)
    local MeatLumpId = dependencies.MeatLumpId
    local IsValidItemId = dependencies.IsValidItemId
    local GetSaveData = dependencies.GetSaveData
    local Store = dependencies.Store
    local function TrackCopies(player)
        if not player or not player.GetCollectibleNum or not IsValidItemId(MeatLumpId) then return end
        local data = GetSaveData()
        local key = tostring(player.InitSeed or "0")
        local current = math.max(0, tonumber(player:GetCollectibleNum(MeatLumpId)) or 0)
        local previous = tonumber(data.meatLumpCounts[key]) or 0
        if current == previous then return end
        -- POST_ADD and the polling fallback share one inventory snapshot authority.
        data.meatLumpCounts[key] = current
        if current > previous then
            data.meatLumpLives[key] = math.max(0, tonumber(data.meatLumpLives[key]) or 0) + current - previous
        end
        Store.Save()
    end

    local function GetCount(player)
        local data = GetSaveData()
        local key = tostring((player and player.InitSeed) or "0")
        return math.max(0, tonumber(data.meatLumpLives[key]) or 0)
    end

    local function Add(player, amount)
        local data = GetSaveData()
        local key = tostring((player and player.InitSeed) or "0")
        data.meatLumpLives[key] = math.max(0, (tonumber(data.meatLumpLives[key]) or 0) + (tonumber(amount) or 0))
        Store.Save()
    end

    local function Consume(player)
        local data = GetSaveData()
        local key = tostring((player and player.InitSeed) or "0")
        local count = math.max(0, tonumber(data.meatLumpLives[key]) or 0)
        if count <= 0 then
            return false
        end
        data.meatLumpLives[key] = count - 1
        Store.Save()
        return true
    end

    return { TrackCopies = TrackCopies, GetCount = GetCount, Add = Add, Consume = Consume }
end
