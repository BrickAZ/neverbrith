-- Shared Angel/Devil Box deal selection. REPENTOGON 1.0.12a door callback.
return function(mod, context)
    local ANGEL, DEVIL = RoomType.ROOM_ANGEL, RoomType.ROOM_DEVIL
    local INDEX = GridRooms and GridRooms.ROOM_DEVIL_IDX or -1
    local changing = false
    local function log(message)
        if Isaac and Isaac.DebugString then Isaac.DebugString("[neverbirth][Boxes] " .. message) end
    end
    local function state()
        local data = context.GetData()
        data.dealRoomConversions = data.dealRoomConversions or {}
        return data.dealRoomConversions
    end
    local function current()
        local game = Game()
        local level, room = game:GetLevel(), game:GetRoom()
        if level.GetDimension and level:GetDimension() ~= 0 then return nil end
        return level, room, level:GetRoomByIdx(INDEX, 0)
    end
    local function setType(level, desc, target)
        if desc.Data and desc.Data.Type == target then return true end
        if (tonumber(desc.VisitedCount) or 0) > 0 then return false end
        local old = desc.Data
        desc.Data = nil
        local ok = pcall(function() level:InitializeDevilAngelRoom(target == ANGEL, target == DEVIL) end)
        if not ok or not desc.Data or desc.Data.Type ~= target then desc.Data = old; return false end
        return true
    end
    local function syncDoor(door, source, target)
        if door and door.TargetRoomIndex == INDEX and door.TargetRoomType ~= target then
            door:SetRoomTypes(source, target)
        end
    end
    local function notifyFailure(target)
        log("open failed target=" .. target .. "; charge retained")
        local game = Game()
        local hud = game.GetHUD and game:GetHUD()
        if hud and hud.ShowItemText then
            local zh = Options and (Options.Language == "zh" or Options.Language == "zh_cn")
            local name = target == ANGEL and (zh and "天使盒" or "Angel Box") or (zh and "恶魔盒" or "Devil Box")
            hud:ShowItemText(name, zh and "这里无法开启交易房，已保留充能" or "Cannot open a deal room here; charge kept")
        end
        return false
    end
    local function open(target)
        local level, room, desc = current()
        if not level or not desc or not room then return notifyFailure(target) end
        local source = room:GetType()
        if source == target then return true end
        if source == ANGEL or source == DEVIL or not room.TrySpawnDevilRoomDoor then return notifyFailure(target) end
        local old, doors = desc.Data, {}
        if room.GetDoor then
            for slot = 0, 7 do
                local door = room:GetDoor(slot)
                if door and door.TargetRoomIndex == INDEX then
                    doors[#doors + 1] = { door = door, target = door.TargetRoomType }
                end
            end
        end
        changing = true
        local ok, opened = pcall(function()
            if not setType(level, desc, target) then return false end
            for _, entry in ipairs(doors) do syncDoor(entry.door, source, target) end
            if #doors > 0 then return true end
            return room:TrySpawnDevilRoomDoor(true, true) == true
        end)
        changing = false
        if not ok or not opened then
            desc.Data = old
            for _, entry in ipairs(doors) do pcall(syncDoor, entry.door, source, entry.target) end
            return notifyFailure(target)
        end
        local key = context.GetFloorKey()
        state()[key] = { target = target, forced = true }
        context.Save()
        log("open success target=" .. target)
        return true
    end
    local function convertDoor(_, door)
        if changing or not door or door.TargetRoomIndex ~= INDEX then return nil end
        local level, room, desc = current()
        if not level or not desc or not desc.Data then return nil end
        local source, original = room:GetType(), desc.Data.Type
        if source == ANGEL or source == DEVIL or (original ~= ANGEL and original ~= DEVIL) then return nil end
        local records, key = state(), context.GetFloorKey()
        if records[key] then pcall(syncDoor, door, source, original); return nil end
        if (tonumber(desc.VisitedCount) or 0) > 0 or context.WasEntered() then return nil end
        local item = original == DEVIL and context.AngelItem or context.DevilItem
        local owner
        for _, player in ipairs(context.GetPlayers()) do
            if context.HasItem(player, item) then owner = player; break end
        end
        if not owner then return nil end
        local rng = owner.GetCollectibleRNG and owner:GetCollectibleRNG(item)
        if not rng or not rng.RandomFloat then return nil end
        local roll = rng:RandomFloat()
        local target = original
        local converted = roll < 0.5
        if converted then target = original == DEVIL and ANGEL or DEVIL end
        local old, oldDoorTarget = desc.Data, door.TargetRoomType
        changing = true
        local ok, applied = pcall(function()
            if target ~= original and not setType(level, desc, target) then return false end
            syncDoor(door, source, target)
            return true
        end)
        changing = false
        if not ok or not applied then
            -- A failed conversion is recorded too: updates cannot turn one 50% draw into repeated attempts.
            desc.Data = old
            pcall(syncDoor, door, source, oldDoorTarget)
            target = original
        end
        records[key] = { source = original, target = target, roll = roll }
        context.Save()
        log(string.format("deal source=%d roll=%.6f threshold=0.5 target=%d applied=%s", original, roll, target, tostring(ok and applied)))
        return nil
    end
    mod.BoxDealRooms = { Open = open, Log = log }
    if ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_UPDATE then
        mod:AddCallback(ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_UPDATE, convertDoor)
    end
end
