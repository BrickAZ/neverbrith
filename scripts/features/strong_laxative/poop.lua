-- Owns RNG, grid placement and the shared per-room allowance. Only successful spawns count.
return function(Neverbirth, dependencies)
    local private = dependencies.Private or {}
    local Rolls = include("scripts.systems.collectible_rng")
    local StrongLaxativeConfig = dependencies.Config
    local StrongLaxativeId = dependencies.ItemId
    local IsValidItemId = dependencies.IsValidItemId
    local GetFolkRoom = dependencies.GetRoom
    local GetFolkRoomKey = dependencies.GetRoomKey
    local strongLaxativeRoomPoopCounts = {}

    function private.GetRng(player)
        if player and player.GetCollectibleRNG and IsValidItemId(StrongLaxativeId) then
            return Rolls.Get(player, StrongLaxativeId, "RandomInt")
        end
        return nil
    end

    function private.RandomInt(player, max)
        if max <= 0 then return 0 end
        return Rolls.IntOrRoomSeed(private.GetRng(player), max, GetFolkRoom)
    end

    function Neverbirth.StrongLaxative.GetPoopRoomCount(roomKey)
        return math.max(0, tonumber(strongLaxativeRoomPoopCounts[roomKey]) or 0)
    end

    function private.GetPoopSpawnPosition(player)
        if not player or not player.Position then
            return nil
        end

        local room = GetFolkRoom()
        local angleIndex = private.RandomInt(player, 8)
        local angle = (angleIndex / 8) * math.pi * 2
        local offset = Vector(math.cos(angle), math.sin(angle)) * StrongLaxativeConfig.PoopDistance
        local position = player.Position + offset

        if room and room.FindFreePickupSpawnPosition then
            local ok, freePosition = pcall(function()
                return room:FindFreePickupSpawnPosition(position, 24, true, false)
            end)
            if ok and freePosition then
                position = freePosition
            end
        end

        if room and room.IsPositionInRoom then
            local ok, inRoom = pcall(function()
                return room:IsPositionInRoom(position, 16)
            end)
            if ok and not inRoom then
                return nil
            end
        end

        return position
    end

    function private.SpawnPoop(player)
        local room = GetFolkRoom()
        if not room then
            return false
        end

        local position = private.GetPoopSpawnPosition(player)
        if not position then
            return false
        end

        local variants = private.PoopVariants or {}
        if #variants <= 0 then
            return false
        end

        local variant = variants[private.RandomInt(player, #variants) + 1] or 0
        local seed = room.GetSpawnSeed and room:GetSpawnSeed() or 0

        if room.SpawnGridEntity and room.GetGridIndex then
            local ok, result = pcall(function()
                return room:SpawnGridEntity(room:GetGridIndex(position), StrongLaxativeConfig.GridPoop, variant, seed, 0)
            end)
            return ok and result ~= false
        end

        return false
    end

    function Neverbirth.StrongLaxative.TryPoopRoll(player, copies)
        local roomKey = GetFolkRoomKey()
        if Neverbirth.StrongLaxative.GetPoopRoomCount(roomKey) >= StrongLaxativeConfig.RoomPoopCap then
            return
        end

        local chance = math.min(100, math.max(0, (tonumber(copies) or 0) * StrongLaxativeConfig.PoopChancePerCopy))
        if chance <= 0 then
            return
        end

        if private.RandomInt(player, 100) < chance and private.SpawnPoop(player) then
            strongLaxativeRoomPoopCounts[roomKey] = Neverbirth.StrongLaxative.GetPoopRoomCount(roomKey) + 1
        end
    end

    local function ResetRoom()
        strongLaxativeRoomPoopCounts[GetFolkRoomKey()] = 0
    end
    local function ResetRuntime()
        strongLaxativeRoomPoopCounts = {}
    end
    return { ResetRoom = ResetRoom, ResetRuntime = ResetRuntime }
end
