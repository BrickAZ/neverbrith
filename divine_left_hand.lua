-- Physical temporary copies tracked by full native history receipts, never by same-ID count removal.
-- REPENTOGON 1.0.12a: Lua history arrays start at 1; native history removal uses vector indices.
return function(mod, context)
    local State, itemId = assert(context.State, "DivineLeftHand requires State"), assert(context.ItemId)
    local api, granting = {}, {}
    local fields = {"time", "stage", "stageType", "room", "pool", "trinket"}

    local function copy(value)
        if type(value) ~= "table" then return value end
        local result = {}; for key, child in pairs(value) do result[key] = copy(child) end; return result
    end

    local function log(message)
        if context.DebugLog then pcall(context.DebugLog, "DivineLeftHand: " .. tostring(message)) end
    end

    local function save()
        if context.Save then local ok, err = pcall(context.Save); if not ok then log(err) end end
    end

    local function data()
        local root, seed = context.GetSaveRoot(), tostring(context.GetCurrentRunSeed())
        local stored = root.divineLeftHand
        if type(stored) ~= "table" or stored.version ~= 1 or stored.runSeed ~= seed then
            stored = {version = 1, runSeed = seed, players = {}}; root.divineLeftHand = stored
        end
        return stored
    end

    local function key(player)
        if context.InventoryPlayerKey then return tostring(context.InventoryPlayerKey(player)) end
        if State.InventoryPlayerKey then return tostring(State.InventoryPlayerKey(player)) end
        return tostring(State.PlayerKey(player))
    end

    local function lineage(record)
        local values = {}; for _, name in ipairs(fields) do values[#values + 1] = tostring(record[name]) end
        return table.concat(values, ":")
    end

    local function signature(record) return tostring(record.id) .. ":" .. lineage(record) end

    local function readHistory(player)
        if type(player.GetHistory) ~= "function" then error("native history unavailable") end
        local native = player:GetHistory():GetCollectiblesHistory()
        if type(native) ~= "table" then error("native history list unavailable") end
        local records = {}
        for i, entry in ipairs(native) do
            records[i] = {id = entry:GetItemID(), time = entry:GetTime(), stage = entry:GetLevelStage(),
                stageType = entry:GetStageType(), room = entry:GetRoomType(), pool = entry:GetItemPoolType(),
                trinket = entry:IsTrinket()}
        end
        return records
    end

    local function equalLists(a, b, length)
        if not length and #a ~= #b then return false end
        for i = 1, length or #a do if not b[i] or signature(a[i]) ~= signature(b[i]) then return false end end
        return true
    end

    local function owner(player)
        local all, ownerKey = data().players, key(player)
        if not all[ownerKey] then all[ownerKey] = {records = {}, serial = 0, floor = State.FloorKey(), unresolved = {}} end
        return all[ownerKey]
    end

    local function fresh(stored, record)
        local result = copy(record); stored.serial = stored.serial + 1; result.serial = stored.serial; return result
    end

    local function inherit(old, current)
        local result = copy(current)
        result.serial, result.temporary, result.uncertain = old.serial, old.temporary, old.uncertain
        return result
    end

    local function groups(records, fingerprint)
        local result = {}
        for i, record in ipairs(records) do
            local group = fingerprint(record); result[group] = result[group] or {}; result[group][#result[group] + 1] = i
        end
        return result
    end

    local function reconcile(stored, current)
        local prior = stored.records
        if equalLists(prior, current) then return false end
        -- Native AddCollectible appends a receipt. Prefix-preserving appends keep known
        -- positions even when all exposed fields of adjacent copies happen to be identical.
        if #current > #prior and equalLists(prior, current, #prior) then
            local result = {}
            for i, record in ipairs(current) do result[i] = prior[i] and inherit(prior[i], record) or fresh(stored, record) end
            stored.records = result; return true
        end
        local result, usedOld, usedNew = {}, {}, {}
        local oldExact, newExact = groups(prior, signature), groups(current, signature)
        local oldLineage, newLineage = groups(prior, lineage), groups(current, lineage)
        local function match(oldIndex, newIndex)
            if usedOld[oldIndex] or usedNew[newIndex] then return end
            result[newIndex] = inherit(prior[oldIndex], current[newIndex])
            usedOld[oldIndex], usedNew[newIndex] = true, true
        end
        -- Exact unique records survive removals and index shifts.
        for fingerprint, oldIndices in pairs(oldExact) do
            local newIndices = newExact[fingerprint]
            if #oldIndices == 1 and newIndices and #newIndices == 1 then match(oldIndices[1], newIndices[1]) end
        end
        -- A reroll may change ID while retaining acquisition metadata. Only an exclusive
        -- one-to-one metadata correspondence carries temporary identity to its replacement.
        for fingerprint, oldIndices in pairs(oldLineage) do
            local newIndices = newLineage[fingerprint]
            if #oldIndices == 1 and newIndices and #newIndices == 1 then match(oldIndices[1], newIndices[1]) end
        end
        local unknownNew = {}
        for i in ipairs(current) do if not usedNew[i] then unknownNew[#unknownNew + 1] = i end end
        for i, old in ipairs(prior) do
            if not usedOld[i] and (old.temporary or old.uncertain) then
                local candidates = newLineage[lineage(old)] or {}
                if #candidates == 0 then candidates = unknownNew end
                if #candidates > 0 then
                    stored.unresolved[#stored.unresolved + 1] = copy(old)
                    for _, newIndex in ipairs(candidates) do
                        if not usedNew[newIndex] then
                            result[newIndex] = result[newIndex] or fresh(stored, current[newIndex])
                            result[newIndex].uncertain = true
                        end
                    end
                    log("ambiguous history owner; temporary receipt quarantined (id=" .. old.id .. ")")
                end
                -- No surviving candidate/addition: the owned receipt was removed, so it expires.
            end
        end
        for i, record in ipairs(current) do result[i] = result[i] or fresh(stored, record) end
        stored.records = result
        return true
    end

    local function sync(player)
        local stored = owner(player)
        local current = readHistory(player)
        if reconcile(stored, current) then save() end
        return stored
    end

    local function safeSync(player)
        local ok, result = pcall(sync, player)
        if not ok then log(result); return nil end
        return result
    end

    function api.GetTemporaryCount(player, id)
        local stored = safeSync(player)
        local count = 0
        for _, record in ipairs(stored and stored.records or {}) do
            if record.temporary and not record.uncertain and record.id == id and not record.trinket then count = count + 1 end
        end
        return count
    end

    local function cleanup(player)
        local stored = safeSync(player)
        if not stored or stored.floor == State.FloorKey() then return end
        if type(player.RemoveCollectibleByHistoryIndex) ~= "function" then log("precision removal unavailable; cleanup deferred"); return end
        -- Descend through the full history, including trinkets, so every removed index is
        -- a native vector index. Re-read after each removal; unexpected mutations stop cleanup.
        for i = #stored.records, 1, -1 do
            local record = stored.records[i]
            if record.temporary and not record.uncertain and not record.trinket then
                local before = readHistory(player)
                if not equalLists(stored.records, before) then
                    log("history changed during cleanup; stopped before deleting a foreign receipt"); return
                end
                player:RemoveCollectibleByHistoryIndex(i - 1)
                local after, expected = readHistory(player), copy(before)
                table.remove(expected, i)
                if not equalLists(expected, after) then
                    log("native history removal did not match the requested receipt; cleanup stopped")
                    reconcile(stored, after); save(); return
                end
                table.remove(stored.records, i)
                save()
            end
        end
        stored.floor = State.FloorKey(); save()
    end

    local function guardedCleanup(player)
        local ok, err = pcall(cleanup, player); if not ok then log(err) end
    end

    local function target(player, stored)
        if stored.blocked then return nil end
        local last
        for _, record in ipairs(stored.records) do
            if not record.trinket and not record.temporary
                and (not last or record.serial > last.serial) then last = record end
        end
        if not last or last.uncertain or last.id == itemId or player:GetCollectibleNum(last.id, true) <= 0 then return nil end
        local config = Isaac.GetItemConfig():GetCollectible(last.id)
        if not config or (config.Type ~= ItemType.ITEM_PASSIVE and config.Type ~= ItemType.ITEM_FAMILIAR) then return nil end
        return last, config
    end

    local function use(_, usedId, rng, player)
        local failed = {Discharge = false, ShowAnim = false, Remove = false}
        if usedId ~= itemId or granting[key(player)] then return failed end
        local succeeded = false
        local ok, err = pcall(function()
            if type(player.RemoveCollectibleByHistoryIndex) ~= "function" or type(State.WithTemporary) ~= "function" then
                log("physical receipt precision APIs unavailable; use rejected before granting"); return
            end
            cleanup(player)
            local stored = sync(player)
            local original, config = target(player, stored)
            if not original then return end
            local before = readHistory(player)
            local beforeCount = player:GetCollectibleNum(original.id, true)
            granting[key(player)] = true
            local wrapped, wrappedResult, wrapperError = pcall(State.WithTemporary, player, function()
                -- 1.0.12a LuaEntityPlayer.cpp calls this argument addConsumables.
                player:AddCollectible(original.id, 0, false)
            end)
            granting[key(player)] = nil
            local grantSucceeded = wrapped and wrappedResult ~= false
            if not grantSucceeded then log(wrapperError or wrappedResult) end
            local after = readHistory(player)
            if #after ~= #before + 1 or not equalLists(before, after, #before)
                or after[#after].id ~= original.id or after[#after].trinket
                or player:GetCollectibleNum(original.id, true) ~= beforeCount + 1 then
                log("grant failed or native physical receipt was not uniquely appended; no discharge")
                -- Preserve proof of old ownership. Never call RemoveCollectible(id) to guess a rollback.
                if player:GetCollectibleNum(original.id, true) ~= beforeCount or not equalLists(before, after) then
                    stored.blocked = true
                    stored.unresolved[#stored.unresolved + 1] = {id = original.id, temporary = true,
                        reason = "unproven_grant", floor = State.FloorKey()}
                    log("unproven physical grant; further uses blocked to prevent free permanent duplication")
                end
                reconcile(stored, after); save(); return
            end
            reconcile(stored, after)
            local receipt = stored.records[#stored.records]
            receipt.temporary = true; receipt.uncertain = nil
            succeeded = grantSucceeded
            if not grantSucceeded then stored.blocked = true end
            save()
            if succeeded and context.OnTemporaryCopy then
                local shown, showError = pcall(context.OnTemporaryCopy, player, original.id, config.Name)
                if not shown then log("copy notice failed: " .. tostring(showError)) end
            end
        end)
        granting[key(player)] = nil
        if not ok then log(err) end
        return succeeded and {Discharge = true, ShowAnim = true, Remove = false} or failed
    end

    State.SubscribeAcquisition(function(player)
        if not granting[key(player)] then safeSync(player) end
    end)
    State.RegisterParticipant("divine_left_hand", function() return copy(data()) end, function(snapshot)
        if type(snapshot) == "table" and snapshot.version == 1 then
            context.GetSaveRoot().divineLeftHand = copy(snapshot)
        else context.GetSaveRoot().divineLeftHand = nil end
        granting = {}
    end)
    mod.DivineLeftHand = api
    local function add(name, fn, filter) if ModCallbacks[name] then mod:AddCallback(ModCallbacks[name], fn, filter) end end
    add("MC_USE_ITEM", use, itemId)
    add("MC_POST_PLAYER_UPDATE", function(_, player) guardedCleanup(player) end)
    add("MC_POST_NEW_LEVEL", function() for _, player in ipairs(context.GetPlayers()) do guardedCleanup(player) end end)
    add("MC_POST_GAME_STARTED", function(_, continued)
        granting = {}
        if not continued then context.GetSaveRoot().divineLeftHand = nil end
        data()
    end)
    add("MC_PRE_GAME_EXIT", function(_, shouldSave)
        if shouldSave then
            for _, player in ipairs(context.GetPlayers()) do safeSync(player) end
            save()
        end
        granting = {}
    end)
    return api
end
