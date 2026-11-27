-- Low Grade. REPENTOGON 1.0.12a: damage callback 1006 runs only on successful
-- native damage (ASMCallbacks.cpp); trinket events are 1096/1097. Swallowed
-- amounts come from GetSmeltedTrinkets()[id], never from the stat multiplier.
return function(mod, context)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local id = assert(context.TrinketId, "Low Grade requires its registered trinket ID")
    local state = assert(context.State, "Low Grade requires pending-content state")
    local golden = TrinketType.TRINKET_GOLDEN_FLAG
    local data, ready, reconciling, removing = nil, false, false, false
    local lastUpdateFrame, needsGroundScan = nil, false
    local pending, confirmed = {}, {}
    local recentGround, removalFrames = {}, {}
    local rangeMultipliers = {}
    local api = {}

    local clone = include("scripts.runtime.plain_data").CopyTree
    local function log(message)
        if context.DebugLog then context.DebugLog("Low Grade: " .. message) end
    end
    local function save()
        if data then context.GetSaveRoot().lowGrade = data end
        if context.Save then context.Save() end
    end
    local function players() return context.GetPlayers() or {} end
    local function playerKey(player) return state.PlayerKey(player) end
    -- Progress uses the normalized owner. Actual held/smelted topology belongs
    -- to one native form; an inactive Lazarus inventory must not erase it.
    local function holderKey(player)
        if state.InventoryPlayerKey then return state.InventoryPlayerKey(player) end
        local owner = playerKey(player)
        if not owner or player.InitSeed == nil then return nil end
        return owner .. ":form:" .. tostring(player.InitSeed)
    end
    local function isOurs(raw) return type(raw) == "number" and (raw & ~golden) == id end
    local function rawCount(player, raw, kind)
        if kind == "smelted" then
            local desc = (player:GetSmeltedTrinkets() or {})[id] or {}
            return desc[(raw & golden) ~= 0 and "goldenTrinketAmount" or "trinketAmount"] or 0
        end
        local n = 0
        for slot = 0, 1 do if player:GetTrinket(slot) == raw then n = n + 1 end end
        return n
    end
    local function refresh(player)
        local holder = holderKey(player)
        if holder then rangeMultipliers[holder] = player:GetTrinketMultiplier(id) end
        player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_RANGE)
        player:EvaluateItems()
    end
    local function newCopy(raw, token)
        data.nextCopy = data.nextCopy + 1
        local key = tostring(data.nextCopy)
        data.copies[key] = { raw = raw, remaining = 5, token = token }
        return key, data.copies[key]
    end
    local function inventory(player)
        local list = {}
        for slot = 0, 1 do
            local raw = player:GetTrinket(slot)
            if isOurs(raw) then list[#list + 1] = { raw = raw, kind = "held" } end
        end
        local desc = (player:GetSmeltedTrinkets() or {})[id] or {}
        for _, info in ipairs({ { id, desc.trinketAmount or 0 }, { id | golden, desc.goldenTrinketAmount or 0 } }) do
            for _ = 1, info[2] do list[#list + 1] = { raw = info[1], kind = "smelted" } end
        end
        return list
    end
    local function distance(a, b)
        return (a.X - b.X)^2 + (a.Y - b.Y)^2
    end
    local function trackGround(pickup)
        if not ready or pickup.Variant ~= PickupVariant.PICKUP_TRINKET or not isOurs(pickup.SubType) then return end
        local token = state.PickupToken(pickup)
        if not token then log("unresolved physical pickup token; durability is not reset") return end
        if data.ground[token] then return end
        local matches = {}
        for key, copy in pairs(data.copies) do
            if copy.kind == "detached" and copy.raw == pickup.SubType
                and copy.dropRoom == state.RoomKey() and copy.dropPosition
                and recentGround[token] and recentGround[token].frame == copy.dropFrame
                and distance(copy.dropPosition, pickup.Position) <= 80^2 then
                local source = pickup.SpawnerEntity and pickup.SpawnerEntity:ToPlayer()
                if not source or playerKey(source) == copy.dropOwner then matches[#matches + 1] = key end
            end
        end
        if #matches == 1 then
            local key = matches[1]
            data.copies[key].kind, data.copies[key].token = "ground", token
            data.ground[token] = key
            save()
        elseif #matches > 1 then
            log("ambiguous simultaneous trinket drops; physical identity cannot be inferred from ID")
        end
    end
    local function ownedCopies(key, holder)
        local list = {}
        for copyKey, copy in pairs(data.copies) do
            if copy.owner == key and copy.holder == holder then list[#list + 1] = { key = copyKey, copy = copy } end
        end
        table.sort(list, function(a,b) return tonumber(a.key) < tonumber(b.key) end)
        return list
    end
    -- Reconcile real held/smelted topology before claiming a receipt. This
    -- preserves the exact old durability when smelting changes its category.
    local function reconcilePlayer(player, initial)
        local key = playerKey(player)
        local holder = holderKey(player)
        if not key or not holder then log("unresolved player/form identity") return end
        local available = inventory(player)
        local owned = ownedCopies(key, holder)
        local used, matched = {}, {}
        for _, entry in ipairs(owned) do
            for i, native in ipairs(available) do
                if not used[i] and native.raw == entry.copy.raw and native.kind == entry.copy.kind then
                    used[i], matched[entry.key] = true, true
                    break
                end
            end
        end
        for _, entry in ipairs(owned) do
            local copy = entry.copy
            if not matched[entry.key] then
                local changedKind
                if copy.kind == "held" then
                    for i, native in ipairs(available) do
                        if not used[i] and native.raw == copy.raw and native.kind == "smelted" then
                            used[i], copy.kind, changedKind = true, "smelted", true
                            break
                        end
                    end
                end
                if not changedKind then
                    copy.owner, copy.holder, copy.kind, copy.dropOwner = nil, nil, "detached", key
                    copy.dropRoom = state.RoomKey()
                    copy.dropFrame = removalFrames[holder] and removalFrames[holder][copy.raw] or Game():GetFrameCount()
                    copy.dropPosition = { X = player.Position.X, Y = player.Position.Y }
                    needsGroundScan = true
                end
            end
        end
        for i, native in ipairs(available) do
            if not used[i] then
                local receipts = confirmed[holder] or {}
                local receipt, receiptIndex
                for index, candidate in ipairs(receipts) do
                    if candidate.raw == native.raw then receipt, receiptIndex = candidate, index; break end
                end
                local copyKey, copy
                if receipt and receipt.token then
                    copyKey = data.ground[receipt.token]
                    if copyKey then copy = data.copies[copyKey] end
                    if not copy then copyKey, copy = newCopy(native.raw, receipt.token) end
                    data.ground[receipt.token] = nil
                elseif initial or receipt then
                    copyKey, copy = newCopy(native.raw)
                else
                    log("native inventory addition lacked a confirmed acquisition; no durability reset")
                end
                if copy then
                    copy.owner, copy.holder, copy.kind = key, holder, native.kind
                    copy.dropOwner, copy.dropPosition, copy.dropRoom = nil, nil, nil
                end
                if receiptIndex then table.remove(receipts, receiptIndex) end
            end
        end
        confirmed[holder] = nil
    end
    local function reconcile(initial)
        if not ready or reconciling or removing then return end
        reconciling = true
        for _, player in ipairs(players()) do reconcilePlayer(player, initial) end
        if needsGroundScan then
            needsGroundScan = false
            for _, candidate in pairs(recentGround) do
                local pickup = candidate.pickup
                if not pickup.Exists or pickup:Exists() then trackGround(pickup) end
            end
        end
        -- A disappearance is not proof of a drop. Only a pickup initialized in
        -- the native removal frame can keep this physical record alive. Direct
        -- destruction must terminate it before a future same-ID spawn exists.
        for copyKey, copy in pairs(data.copies) do
            if copy.kind == "detached" then data.copies[copyKey] = nil end
        end
        for token, candidate in pairs(recentGround) do
            if candidate.frame < Game():GetFrameCount() then recentGround[token] = nil end
        end
        removalFrames = {}
        reconciling = false
    end
    local function ensureFloor()
        if not ready then return end
        local floor = state.FloorKey()
        if data.floor ~= floor then
            data.floor = floor
            data.floors[#data.floors + 1] = floor
            if #data.floors > 3 then
                local old = table.remove(data.floors, 1)
                for _, progress in pairs(data.players) do progress.damaged[old], progress.judged[old] = nil, nil end
            end
        end
    end
    local function progressFor(player)
        local key = playerKey(player)
        if not key then return end
        data.players[key] = data.players[key] or { damaged = {}, judged = {} }
        return data.players[key]
    end
    local function emptyState()
        return { runSeed = tostring(context.GetCurrentRunSeed()), floor = nil,
            floors = {}, players = {}, copies = {}, ground = {}, nextCopy = 0 }
    end
    local function start(_, continued)
        local root = context.GetSaveRoot()
        local seed = tostring(context.GetCurrentRunSeed())
        if continued and root.lowGrade and root.lowGrade.runSeed == seed then data = root.lowGrade
        else data = emptyState() end
        ready, pending, confirmed, lastUpdateFrame = true, {}, {}, nil
        recentGround, removalFrames, rangeMultipliers = {}, {}, {}
        ensureFloor()
        reconcile(true)
        save()
    end
    function callbackInstallers.start()
        return mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, start)
    end
    local function eligibleDamage(amount, flags)
        -- Perfection exceptions: fake/no-penalty damage, donation/payment,
        -- cursed doors, spiked chests, and sacrifice-room spikes. Regular room
        -- spikes remain valid. The native post callback excludes rejected hits.
        local excluded = DamageFlag.DAMAGE_FAKE | DamageFlag.DAMAGE_NO_PENALTIES
            | DamageFlag.DAMAGE_IV_BAG | DamageFlag.DAMAGE_DEVIL
            | DamageFlag.DAMAGE_CURSED_DOOR | DamageFlag.DAMAGE_CHEST
        if amount <= 0 or (flags & excluded) ~= 0 then return false end
        return not ((flags & DamageFlag.DAMAGE_SPIKES) ~= 0 and Game():GetRoom():GetType() == RoomType.ROOM_SACRIFICE)
    end
    local function expire(player, copyKey, copy)
        local before = rawCount(player, copy.raw, copy.kind)
        removing = true
        if copy.kind == "held" then player:TryRemoveTrinket(copy.raw)
        elseif copy.kind == "smelted" then player:TryRemoveSmeltedTrinket(copy.raw) end
        removing = false
        local after = rawCount(player, copy.raw, copy.kind)
        if before - after == 1 then data.copies[copyKey] = nil
        else log("expired copy removal did not remove exactly one native " .. copy.kind .. " copy") end
    end
    local function damage(_, entity, amount, flags)
        if not ready then return end
        local player = entity:ToPlayer()
        if not player or not eligibleDamage(amount, flags) then return end
        ensureFloor()
        reconcile()
        local progress = progressFor(player)
        if not progress then return end
        progress.damaged[data.floor] = true
        local expired = false
        for _, entry in ipairs(ownedCopies(playerKey(player), holderKey(player))) do
            local copy = entry.copy
            copy.remaining = math.max(0, copy.remaining - 1)
            if copy.remaining == 0 then expire(player, entry.key, copy); expired = true end
        end
        if expired then refresh(player) end
        save()
    end
    function callbackInstallers.damage()
        return mod:AddCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG, damage, EntityType.ENTITY_PLAYER)
    end
    local function boss(_, _rng, position)
        if not ready or Game():GetRoom():GetType() ~= RoomType.ROOM_BOSS then return end
        -- Native floor settlement belongs to the last boss-room descriptor,
        -- not an earlier XL boss or a mirror-dimension copy of its grid index.
        local level = Game():GetLevel()
        if level:GetCurrentRoomDesc().ListIndex ~= level:GetLastBossRoomListIndex() then return end
        ensureFloor()
        for _, player in ipairs(players()) do
            local progress = progressFor(player)
            if progress and not progress.judged[data.floor] then
                progress.judged[data.floor] = true
                local qualified = #data.floors == 3
                for _, floor in ipairs(data.floors) do if not progress.damaged[floor] then qualified = false end end
                if qualified then
                    local spawnPosition = Game():GetRoom():FindFreePickupSpawnPosition(position, 40, true)
                    local entity = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_TRINKET, id,
                        spawnPosition, Vector(0, 0), player)
                    if not entity then log("qualified boss reward spawn failed") end
                end
            end
        end
        save()
    end
    function callbackInstallers.boss()
        return mod:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, boss)
    end
    local function cache(_, player, flag)
        local multiplier = player:GetTrinketMultiplier(id)
        if multiplier <= 0 then return end
        if flag == CacheFlag.CACHE_DAMAGE then player.Damage = player.Damage + 5 * multiplier
        elseif flag == CacheFlag.CACHE_FIREDELAY then
            local tears = 30 / math.max(0.00001, player.MaxFireDelay + 1)
            player.MaxFireDelay = 30 / (tears + 5 * multiplier) - 1
        elseif flag == CacheFlag.CACHE_RANGE then player.TearRange = player.TearRange + 5 * 40 * multiplier end
    end
    function callbackInstallers.cache()
        return mod:AddPriorityCallback(ModCallbacks.MC_EVALUATE_CACHE, CallbackPriority.LATE, cache)
    end
    function callbackInstallers.cache2()
        return mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, cache)
    end
    local function queuedItem(player)
        return player.QueuedItem and player.QueuedItem.Item
    end
    local function collision(_, pickup, collider)
        if not ready or not isOurs(pickup.SubType) then return end
        local player = collider:ToPlayer()
        if not player then return end
        local key = holderKey(player)
        if key and pending[key] and pending[key].lastQueuedFrame then return end
        reconcile()
        trackGround(pickup)
        local token = state.PickupToken(pickup)
        if token and key then pending[key] = { raw = pickup.SubType, token = token,
            frame = Game():GetFrameCount(), wasQueued = queuedItem(player) ~= nil } end
        -- Observation only: leave native trinket collection/cancellation intact.
    end
    function callbackInstallers.collision()
        return mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, collision, PickupVariant.PICKUP_TRINKET)
    end
    local function added(_, player, raw)
        if not ready or not isOurs(raw) or removing then return end
        local key = holderKey(player)
        if key then
            local frame = Game():GetFrameCount()
            local candidate = pending[key]
            local token
            if candidate and candidate.raw == raw and candidate.lastQueuedFrame
                and candidate.lastQueuedFrame >= frame - 1 and not queuedItem(player) then
                token = candidate.token
                pending[key], recentGround[token] = nil, nil
            end
            confirmed[key] = confirmed[key] or {}
            confirmed[key][#confirmed[key] + 1] = { raw = raw, frame = frame, token = token }
        end
    end
    function callbackInstallers.added()
        return mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_TRINKET_ADDED, added)
    end
    local function postCollision(_, pickup, collider)
        if not ready then return end
        local player = collider:ToPlayer()
        if not player then return end
        local key = holderKey(player)
        local receipt = key and pending[key]
        if not receipt or receipt.frame ~= Game():GetFrameCount() or receipt.token ~= state.PickupToken(pickup) then return end
        -- 1.0.12a callback 1239 fires only when native collision code ran.
        -- POST1096 alone is not enough: another mod could cancel the collision
        -- and independently grant the same trinket later in this same frame.
        local receipts = confirmed[key] or {}
        local queued = queuedItem(player)
        if not receipt.wasQueued and queued and isOurs(queued.ID) then
            -- Native pickup first consumes the ground entity, then adds the
            -- trinket when the pickup animation flushes QueuedItem.
            receipt.lastQueuedFrame = receipt.frame
            return
        end
        for index = #receipts, 1, -1 do
            local candidate = receipts[index]
            if candidate.frame == receipt.frame and candidate.raw == receipt.raw and not candidate.token then
                candidate.token = receipt.token
                break
            end
        end
        pending[key] = nil
        recentGround[receipt.token] = nil
        reconcile()
        save()
    end
    function callbackInstallers.postCollision()
        return mod:AddCallback(ModCallbacks.MC_POST_PICKUP_COLLISION, postCollision, PickupVariant.PICKUP_TRINKET)
    end
    local function removed(_, player, raw)
        -- TriggerTrinketRemoved can run before a smelt operation has finished
        -- updating both inventories. Reconcile after the native operation, not
        -- in its intermediate topology, or the old durability would be lost.
        if ready and isOurs(raw) and not removing then
            lastUpdateFrame = nil
            local holder = holderKey(player)
            if holder then
                removalFrames[holder] = removalFrames[holder] or {}
                removalFrames[holder][raw] = Game():GetFrameCount()
            end
        end
    end
    function callbackInstallers.removed()
        return mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_TRINKET_REMOVED, removed)
    end
    local function update()
        if not ready then return end
        local frame = Game():GetFrameCount()
        if lastUpdateFrame == frame then return end
        lastUpdateFrame = frame
        reconcile()
        -- The native trinket pickup applies damage and tears on this build but
        -- can leave range stale. Refresh once when the effective amount changes.
        for _, player in ipairs(players()) do
            local holder = holderKey(player)
            local candidate = holder and pending[holder]
            if candidate then
                local queued = queuedItem(player)
                if candidate.lastQueuedFrame and queued and isOurs(queued.ID) then
                    candidate.lastQueuedFrame = frame
                elseif frame > candidate.frame then pending[holder] = nil end
            end
            local multiplier = player:GetTrinketMultiplier(id)
            if holder and (rangeMultipliers[holder] or 0) ~= multiplier then
                rangeMultipliers[holder] = multiplier
                player:AddCacheFlags(CacheFlag.CACHE_RANGE)
                player:EvaluateItems()
            end
        end
    end
    function callbackInstallers.update()
        return mod:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, update)
    end
    state.RegisterParticipant("lowGrade", function() return clone(data) end, function(snapshot)
        -- A native save can precede MC_POST_GAME_STARTED. Its empty module
        -- snapshot is still a real rollback boundary, not permission to retain
        -- damage or copies acquired after that initial room.
        data, ready, pending, confirmed, lastUpdateFrame = snapshot and clone(snapshot) or emptyState(), true, {}, {}, nil
        recentGround, removalFrames, rangeMultipliers = {}, {}, {}
        ensureFloor()
        if not snapshot then reconcile(true) end
        save()
        for _, player in ipairs(players()) do refresh(player) end
    end)
    callbackInstallers.start()
    mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function() ensureFloor(); save() end)
    callbackInstallers.boss()
    callbackInstallers.damage()
    if mod.AddPriorityCallback and CallbackPriority then
        callbackInstallers.cache()
    else callbackInstallers.cache2() end
    callbackInstallers.collision()
    callbackInstallers.postCollision()
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, function(_, pickup)
        if not ready or not isOurs(pickup.SubType) then return end
        local token = state.PickupToken(pickup)
        if token then recentGround[token] = { pickup = pickup, frame = Game():GetFrameCount() } end
        reconcile(); trackGround(pickup)
    end, PickupVariant.PICKUP_TRINKET)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, function(_, pickup) trackGround(pickup) end, PickupVariant.PICKUP_TRINKET)
    callbackInstallers.update()
    -- Register without an optional ID filter: the native callback parameter can
    -- include GOLDEN_FLAG, whereas the registered base ID does not.
    callbackInstallers.added()
    callbackInstallers.removed()
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function(_, shouldSave)
        if shouldSave then reconcile(); save() end
        ready = false
        pending, confirmed, recentGround, removalFrames = {}, {}, {}, {}
    end)
    api.GetDurability = function(token)
        if not data then return nil end
        for _, copy in pairs(data.copies) do if copy.token == token then return copy.remaining end end
    end
    mod.LowGrade = api
    return api
end
