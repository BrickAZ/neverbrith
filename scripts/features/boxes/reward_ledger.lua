-- One implementation, one isolated live Store per box. No cached save tables.
return function(dependencies)
    local GetData, GetRunSeed = dependencies.GetData, dependencies.GetRunSeed
    local GetFloorKey = dependencies.GetFloorKey
    local Ledger = {}

    function Ledger.PlayerRecord(player)
        local data = GetData()
        local key = tostring(player and player.InitSeed or "")
        local runSeed = GetRunSeed()
        local record = data.players[key]
        if type(record) ~= "table" or record.runSeed ~= runSeed then
            record = { runSeed = runSeed, firstUseDone = false }
            data.players[key] = record
        end
        return record, key
    end

    function Ledger.Pending()
        local data = GetData()
        local floorKey = GetFloorKey()
        local pending = data.pendingRewards[floorKey]
        if type(pending) == "table" then return pending end
        local legacyCount = tonumber(pending) or 0
        pending = {}
        for index = 1, legacyCount do pending["legacy" .. tostring(index)] = true end
        data.pendingRewards[floorKey] = pending
        return pending
    end

    function Ledger.Count()
        local count = 0
        for _, pending in pairs(Ledger.Pending()) do
            if pending then count = count + 1 end
        end
        return count
    end

    function Ledger.HasPending() return Ledger.Count() > 0 end

    function Ledger.IsCurrentRoom()
        local room = dependencies.GetRoom()
        return room and room.GetType and room:GetType() == dependencies.RoomType
    end

    function Ledger.HasEntered()
        return GetData()[dependencies.EnteredField][GetFloorKey()] == true or Ledger.IsCurrentRoom()
    end

    function Ledger.MarkEntered()
        local data = GetData()
        local floorKey = GetFloorKey()
        if data[dependencies.EnteredField][floorKey] then return false end
        data[dependencies.EnteredField][floorKey] = true
        return true
    end

    function Ledger.MarkPending(player)
        if Ledger.HasEntered() then return false end
        local pending = Ledger.Pending()
        pending[tostring(player and player.InitSeed or "")] = true
        return true
    end

    function Ledger.ClearPending() GetData().pendingRewards[GetFloorKey()] = nil end

    function Ledger.AppliedChance(data, floorKey)
        local applied = data.appliedChanceFloors[floorKey]
        if applied == true then return dependencies.LegacyChance end
        if type(applied) == "number" then return applied end
        return 0
    end

    function Ledger.SetChance(target)
        local level = dependencies.GetLevel()
        if not level or not level.AddAngelRoomChance then return false end
        local data = GetData()
        local floorKey = GetFloorKey()
        local delta = target - Ledger.AppliedChance(data, floorKey)
        if math.abs(delta) <= 0.0001 then return false end
        level:AddAngelRoomChance(delta)
        if dependencies.ClearChance(target) then
            data.appliedChanceFloors[floorKey] = nil
        else
            data.appliedChanceFloors[floorKey] = target
        end
        return true
    end
    return Ledger
end
