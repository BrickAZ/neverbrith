-- Private state ownership; constructed once by the item entry.
return function(Neverbirth, deps)
    local context = deps.context

    local ITEM_ID = tonumber(context.ItemId) or -1
    local BLACK_CANDLE_ID = (CollectibleType and CollectibleType.COLLECTIBLE_BLACK_CANDLE) or 260
    local IPECAC_ID = (CollectibleType and CollectibleType.COLLECTIBLE_IPECAC) or 149
    local PICKUP_ENTITY = (EntityType and EntityType.ENTITY_PICKUP) or 5
    local COLLECTIBLE_PICKUP = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
    local NO_ENTITY_COLLISION = (EntityCollisionClass and EntityCollisionClass.ENTCOLL_NONE) or 0
    local NO_GRID_COLLISION = (GridCollisionClass and GridCollisionClass.COLLISION_NONE) or 0
    local PENDING_PICKUP_TIMEOUT = 8

    local runtime = {
        frame = 0,
        serial = 0,
        playerCounts = {},
        pending = {},
        failedBonusCandidates = {},
        resolvingQ4 = false,
        testRunSeed = nil,
    }


    local function debugLog(message)
        if type(context.DebugLog) == "function" then
            context.DebugLog("[neverbirth][Yin's Curse] " .. tostring(message))
        elseif Isaac and Isaac.DebugString then
            Isaac.DebugString("[neverbirth][Yin's Curse] " .. tostring(message))
        end
    end

    local function getSaveRoot()
        if type(context.GetSaveRoot) ~= "function" then
            return nil
        end
        local ok, root = pcall(context.GetSaveRoot)
        if not ok or type(root) ~= "table" then
            return nil
        end
        if type(root.yinCurse) ~= "table" then
            root.yinCurse = {}
        end
        return root
    end

    local function currentRunSeed()
        if runtime.testRunSeed ~= nil then
            return tostring(runtime.testRunSeed)
        end
        if type(context.GetCurrentRunSeed) == "function" then
            local ok, seed = pcall(context.GetCurrentRunSeed)
            if ok and seed ~= nil then
                return tostring(seed)
            end
        end
        return "unknown"
    end

    local function save()
        if type(context.Save) == "function" then
            pcall(context.Save)
        end
    end

    local function resetSavedState(runSeed)
        local root = getSaveRoot()
        if not root then
            return nil
        end
        root.yinCurse = {
            runSeed = tostring(runSeed or currentRunSeed()),
            yinCurseActive = false,
            q4Mode = nil,
            firstQ4Resolved = false,
        }
        return root.yinCurse
    end

    local function getSavedState()
        local root = getSaveRoot()
        if not root then
            return nil
        end
        local state = root.yinCurse
        local runSeed = currentRunSeed()
        if tostring(state.runSeed or "") ~= runSeed then
            state = resetSavedState(runSeed)
        end
        state.yinCurseActive = state.yinCurseActive == true
        state.firstQ4Resolved = state.firstQ4Resolved == true
        if state.q4Mode ~= "bonus_root" and state.q4Mode ~= "replace_root" then
            state.q4Mode = nil
        end
        return state
    end

    local function resetRuntimeOnly()
        runtime.frame = 0
        runtime.serial = 0
        runtime.playerCounts = {}
        runtime.pending = {}
        runtime.failedBonusCandidates = {}
        runtime.resolvingQ4 = false
    end

    local function resetForTest(runSeed)
        resetRuntimeOnly()
        runtime.testRunSeed = tostring(runSeed or "test")
        resetSavedState(runtime.testRunSeed)
        return getSavedState()
    end

    return {
        debugLog = debugLog,
        getSaveRoot = getSaveRoot,
        currentRunSeed = currentRunSeed,
        save = save,
        resetSavedState = resetSavedState,
        getSavedState = getSavedState,
        resetRuntimeOnly = resetRuntimeOnly,
        resetForTest = resetForTest,
        ITEM_ID = ITEM_ID,
        BLACK_CANDLE_ID = BLACK_CANDLE_ID,
        IPECAC_ID = IPECAC_ID,
        PICKUP_ENTITY = PICKUP_ENTITY,
        COLLECTIBLE_PICKUP = COLLECTIBLE_PICKUP,
        NO_ENTITY_COLLISION = NO_ENTITY_COLLISION,
        NO_GRID_COLLISION = NO_GRID_COLLISION,
        PENDING_PICKUP_TIMEOUT = PENDING_PICKUP_TIMEOUT,
        runtime = runtime,
    }
end
