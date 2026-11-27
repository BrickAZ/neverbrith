-- Save schema and runtime clocks remain local to this installation.
return function(context)
    local runtime = { ready=false, sampling=false, held={}, saveAt=0, ownedOverlay=false }
    local function save() context.Save() end
    local function playerKey(player) return tostring(player.InitSeed) end
    local function floorKey()
        local level = Game():GetLevel()
        return table.concat({ level:GetStage(), level:GetStageType(), level:GetDungeonPlacementSeed() }, ':')
    end
    local function data()
        local root, run = context.GetSaveRoot(), context.GetCurrentRunSeed()
        if type(root.healthySleep) ~= 'table' or root.healthySleep.run ~= run then
            root.healthySleep = { version=1, run=run }
        end
        return root.healthySleep
    end
    local function currentFloor()
        local d = data()
        if type(d.floor) ~= 'table' or d.floor.key ~= floorKey() then return nil end
        return d.floor
    end
    local function bedRecord()
        local floor = currentFloor()
        return floor and floor.bed
    end
    local function sleepState()
        local bed = bedRecord()
        return bed and bed.sleep
    end
    local function hasOwner()
        for _, p in ipairs(context.GetPlayers()) do
            if p:HasCollectible(context.ItemId) then return true end
        end
        return false
    end
    local function inOrigin()
        local floor, level = currentFloor(), Game():GetLevel()
        return floor and level:GetDimension() == 0 and level:GetCurrentRoomIndex() == floor.room
    end
    local function isOwned(pickup)
        local bed = bedRecord()
        return pickup and pickup.Variant == PickupVariant.PICKUP_BED and pickup.SubType == 0
            and bed and bed.seed == pickup.InitSeed and inOrigin()
    end
    return { runtime=runtime, save = save, playerKey = playerKey, floorKey = floorKey, data = data, currentFloor = currentFloor, bedRecord = bedRecord, sleepState = sleepState, hasOwner = hasOwner, inOrigin = inOrigin, isOwned = isOwned }
end
