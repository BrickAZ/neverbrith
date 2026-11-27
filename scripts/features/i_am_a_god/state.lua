-- Private state responsibilities for i_am_a_god; created once by its entry.
return function(mod, context, deps)
    local callbackInstallers = {}
    local data = {ready=false, marked=false, snapshots={}, reviving={}, bursts={}, badVisuals={}, reconciling=false}
    local ITEM_ID = context.ItemId
    local CACHE = deps.Config.CACHE

    local function alive(p)
        return p and p:Exists() and not p:IsDead() and not p:IsCoopGhost()
    end

    local function playerKey(p) return tostring(GetPtrHash(p)) .. ":" .. tostring(p.InitSeed) end

    local function samePlayer(a,b)
        -- Native callbacks may wrap the same entity in different Lua userdata.
        return a and b and playerKey(a)==playerKey(b)
    end

    local function players()
        -- GetPlayers owns ordinary co-op enumeration. Include the Forgotten's
        -- inactive health body as well; it is not always in Game:GetNumPlayers().
        local result, seen = {}, {}
        local function add(p)
            if p and p:Exists() then
                local key=playerKey(p)
                if not seen[key] then seen[key]=true;result[#result+1]=p end
            end
        end
        for _, p in ipairs(context.GetPlayers()) do
            add(p)
            if p.GetSubPlayer then add(p:GetSubPlayer()) end
        end
        return result
    end

    local function location()
        local level=Game():GetLevel()
        local floor=table.concat({tostring(context.GetCurrentRunSeed()),level:GetStage(),
            level:GetStageType(),level:GetDungeonPlacementSeed()}, ":")
        local desc=level:GetCurrentRoomDesc()
        -- Dimension + descriptor identity separates mirror/Death Certificate
        -- rooms, negative-grid rooms and distinct placements on the same floor.
        local key=table.concat({floor,level:GetDimension(),desc.ListIndex,
            desc.SafeGridIndex,desc.SpawnSeed}, ":")
        return floor,key
    end

    local function saved()
        local root=context.GetSaveRoot()
        local run=tostring(context.GetCurrentRunSeed())
        if type(root.iAmAGod)~="table" or root.iAmAGod.run~=run then
            root.iAmAGod={version=1,run=run,floor=data.currentFloor,rooms={}}
        end
        local s=root.iAmAGod
        if s.floor~=data.currentFloor or type(s.rooms)~="table" then s.floor=data.currentFloor;s.rooms={} end
        return s
    end

    local function roomMark()
        if not data.ready then return false, false end
        local floor,key=location()
        if floor==data.currentFloor and key==data.currentKey then return data.marked,true end
        -- Pickups and health callbacks can precede MC_POST_NEW_ROOM. Look up
        -- the destination without mutating cached room state or saved floors.
        local s=context.GetSaveRoot().iAmAGod
        return type(s)=="table" and s.run==tostring(context.GetCurrentRunSeed())
            and s.floor==floor and type(s.rooms)=="table" and s.rooms[key]==true, false
    end

    local function refresh(p)
        if p and p:Exists() then p:AddCacheFlags(CACHE);p:EvaluateItems() end
    end

    local function ordinaryDoor(d)
        if not d or d.TargetRoomIndex<0 or d.TargetRoomType~=RoomType.ROOM_DEFAULT
            or d:IsLocked() or d:IsBusted() then return false end
        local variant=d:GetVariant()
        return variant==DoorVariant.DOOR_UNSPECIFIED or variant==DoorVariant.DOOR_UNLOCKED
    end

    local function holdDoor(_,door)
        local a=data.active
        if not a or a.room~=data.currentKey or select(2,location())~=a.room then return end
        local record=a.doors[door.Slot]
        if record and record.target==door.TargetRoomIndex and ordinaryDoor(door) then door:Close(true) end
    end
    function callbackInstallers.holdDoor()
        return mod:AddCallback(ModCallbacks.MC_POST_GRID_ENTITY_DOOR_UPDATE,holdDoor)
    end

    local function releaseDoors(a)
        if not a or a.room~=data.currentKey or select(2,location())~=a.room then return end
        local room=Game():GetRoom()
        for slot,record in pairs(a.doors) do
            local door=room:GetDoor(slot)
            if door and door.TargetRoomIndex==record.target and ordinaryDoor(door)
                and (room:IsClear() or record.open) then door:Open() end
        end
        -- Closed native combat doors remain under the engine's control on
        -- failure. No lock bit, room clear bit, descriptor or door is replaced.
    end

    local function clearTears(a)
        for tear,bits in pairs(a.tears) do
            if tear:Exists() then tear:ClearTearFlags(bits) end
        end
    end

    local function stop()
        local a=data.active
        data.active=nil -- cache evaluation and damage must see the cleared state
        if a then releaseDoors(a);clearTears(a);refresh(a.player) end
        return a
    end

    local function validActive()
        if not data.active then return false end
        if select(2,location())~=data.currentKey then stop();return false end
        if data.active.room~=data.currentKey or not alive(data.active.player) or data.active.player:HasMortalDamage()
            or not data.active.player:HasCollectible(ITEM_ID) then stop();return false end
        return true
    end

    return {
        Data = data,
        Installers = callbackInstallers,
        alive = alive,
        playerKey = playerKey,
        samePlayer = samePlayer,
        players = players,
        location = location,
        saved = saved,
        roomMark = roomMark,
        refresh = refresh,
        ordinaryDoor = ordinaryDoor,
        holdDoor = holdDoor,
        releaseDoors = releaseDoors,
        clearTears = clearTears,
        stop = stop,
        validActive = validActive,
    }
end
