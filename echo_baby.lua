-- Echo Baby: physical acquisitions own reward records; native species own their AI.
-- REPENTOGON 1.0.12a: EntityFamiliar:GetItemConfig is the exact granting source.
-- Copies deliberately have no ItemConfig source: they are not normal collectibles.
return function(mod, context)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local itemId, variant, state = context.ItemId, context.FamiliarVariant, context.State
    local SAVE_KEY = "echoBaby"
    local COPY_KEY = "NeverbirthEchoCopy"
    local BODY_KEY = "NeverbirthEchoBody"
    local beforeAdd, activeOwners, lastCounts = {}, {}, {}
    local inCache = false
    local saved

    local function log(message)
        if context.DebugLog then context.DebugLog("[neverbirth] Echo Baby: " .. message) end
    end
    if not itemId or itemId <= 0 or not variant or variant <= 0 or not state then
        log("invalid item/familiar registration or missing acquisition state; module disabled")
        return
    end

    local plainCopy = include("scripts.runtime.plain_data").CopyTree
    local function runSeed() return tostring(context.GetCurrentRunSeed()) end
    local function loadState(reset)
        local root = context.GetSaveRoot()
        local existing = root[SAVE_KEY]
        if reset or type(existing) ~= "table" or existing.version ~= 1 or existing.seed ~= runSeed() then
            existing = { version = 1, seed = runSeed(), players = {} }
            root[SAVE_KEY] = existing
        end
        existing.players = existing.players or {}
        saved = existing
    end
    local function ensureState()
        if not saved or saved.seed ~= runSeed() then loadState(false) end
    end
    local function save()
        context.GetSaveRoot()[SAVE_KEY] = saved
        if context.Save then context.Save() end
    end
    local function keyFor(player) return tostring(state.PlayerKey(player)) end
    local function inventoryKey(player)
        if not player then return nil end
        if state.InventoryPlayerKey then return state.InventoryPlayerKey(player) end
        return keyFor(player) .. ":form:" .. tostring(player.InitSeed)
    end
    local function rewards(player, create)
        ensureState()
        local key = keyFor(player)
        local record = saved.players[key]
        if not record and create then
            record = { seen = {}, damage = 0, tears = 0, groups = {}, pending = {} }
            saved.players[key] = record
        end
        return record, key
    end
    local function itemCount(player, id)
        if not player or not player.GetCollectibleNum then return 0 end
        return math.max(0, tonumber(player:GetCollectibleNum(id)) or 0)
    end
    local function active(player)
        return player and not (player.IsHologram and player:IsHologram())
            and not (player.IsDead and player:IsDead())
    end
    local function configFor(id)
        local ok, config = pcall(function() return Isaac.GetItemConfig():GetCollectible(id) end)
        return ok and config or nil
    end
    local function eligible(id)
        if id == itemId then return false end
        local config = configFor(id)
        local tag = ItemConfig and ItemConfig.TAG_BABY
        return config ~= nil and tag ~= nil and ((config.Tags or 0) & tag) ~= 0
    end
    local function listFamiliars()
        local result = {}
        for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR, -1, -1, false, false)) do
            local familiar = entity:ToFamiliar()
            if familiar and (not familiar.Exists or familiar:Exists()) then result[#result + 1] = familiar end
        end
        return result
    end
    local function sourceId(familiar)
        local ok, config = pcall(function() return familiar:GetItemConfig() end)
        return ok and config and config.ID or nil, ok
    end
    local function hasNoItemSource(familiar)
        local id, verified = sourceId(familiar)
        return verified and id == nil
    end
    local function speciesKey(familiar) return tostring(familiar.Variant) .. ":" .. tostring(familiar.SubType) end
    local function nativeGroup(player, id)
        local result = {}
        local owner = inventoryKey(player)
        for _, familiar in ipairs(listFamiliars()) do
            if inventoryKey(familiar.Player) == owner and not familiar:GetData()[COPY_KEY] and sourceId(familiar) == id then
                local key = speciesKey(familiar)
                local row = result[key] or { variant = familiar.Variant, subtype = familiar.SubType, count = 0 }
                row.count = row.count + 1
                result[key] = row
            end
        end
        return result
    end
    local function refresh(player)
        if not player or inCache then return end
        player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_FAMILIARS)
        player:EvaluateItems()
    end
    local function hashSeed(text)
        local hash = 2166136261
        for i = 1, #text do hash = ((hash ~ text:byte(i)) * 16777619) & 0x7fffffff end
        return math.max(1, hash)
    end
    local function identitySeed(playerKey, token, suffix)
        return hashSeed(saved.seed .. "|" .. playerKey .. "|" .. token .. "|" .. suffix)
    end
    local function roll(playerKey, token)
        -- The token determines this mutually exclusive draw, so rewind/retry does
        -- not drift a live player's collectible RNG or produce a second reward.
        local ok, result = pcall(function()
            local rng = RNG()
            rng:SetSeed(identitySeed(playerKey, token, "reward"), 35)
            return rng:RandomInt(2)
        end)
        if not ok then log("seeded reward RNG unavailable: " .. tostring(result)); return nil end
        return result
    end
    local function ensureConjoined(player)
        if itemCount(player, itemId) <= 0 or not active(player) then return end
        if player:HasPlayerForm(PlayerForm.PLAYERFORM_BABY) then return end
        -- This changes the native transformation counter, not collectible inventory.
        local current = player:GetPlayerFormCounter(PlayerForm.PLAYERFORM_BABY)
        local missing = math.max(0, 3 - current)
        if missing > 0 then player:IncrementPlayerFormCounter(PlayerForm.PLAYERFORM_BABY, missing) end
    end

    function mod:EchoBabyPreAdd(id, _, _, _, _, player)
        if not player or not eligible(id) then return end
        local owner = inventoryKey(player)
        local existing = beforeAdd[owner] and beforeAdd[owner][id]
        if existing then
            for _, observation in ipairs(existing) do
                if observation.receipt and observation.receipt.completed and not observation.after then
                    -- A native grant may wait until POST_PICKUP_COLLISION to be
                    -- confirmed. Freeze it before the next same-ID grant changes
                    -- its source group; a completed receipt is not an outer call.
                    player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
                    player:EvaluateItems()
                    observation.after = nativeGroup(player, id)
                end
            end
        end
        local echoCount = itemCount(player, itemId)
        if echoCount <= 0 then return end
        local receipt = state.GetPendingReceipt and state.GetPendingReceipt(player)
        beforeAdd[owner] = beforeAdd[owner] or {}
        -- Receipts identify both synchronous POST_ADD delivery and delivery after
        -- native POST_PICKUP_COLLISION. Rejected/nonphysical grants consume their
        -- own observation rather than a later real pickup's source group.
        beforeAdd[owner][id] = beforeAdd[owner][id] or {}
        table.insert(beforeAdd[owner][id], { group = nativeGroup(player, id), owner = owner,
            room = state.RoomKey(), beforeCount = receipt and receipt.count or player:GetCollectibleNum(id, true, true),
            echoCount = echoCount, receipt = receipt })
    end
    function callbackInstallers.mod_EchoBabyPreAdd()
        return mod:AddCallback(ModCallbacks.MC_PRE_ADD_COLLECTIBLE, mod.EchoBabyPreAdd)
    end

    local function settleAcquisition(player, id, token, physical, temporary, observation, playerKey)
        if id == itemId then ensureConjoined(player); refresh(player); return end
        if not physical or temporary or not eligible(id) then return end
        if type(token) ~= "string" or token == "" then log("physical baby acquisition has no stable token; skipped"); return end
        local record = rewards(player, false)
        if record and record.seen[token] then return end
        -- Ownership is sampled before the actual grant. A delayed confirmation
        -- cannot make an older baby retroactively eligible after Echo arrives.
        if not observation or (observation.echoCount or 0) <= 0 then return end
        record = rewards(player, true)
        local choice = roll(playerKey, token)
        if choice == nil then return end
        record.seen[token] = true
        if choice == 0 then record.damage = (record.damage or 0) + 1
        else record.tears = (record.tears or 0) + 0.5 end
        if observation.owner == inventoryKey(player) and observation.room == state.RoomKey()
            and (observation.receipt and observation.receipt.postCount or player:GetCollectibleNum(id, true, true)) > observation.beforeCount then
            record.pending[#record.pending + 1] = { id = id, token = token,
                before = observation.group, after = observation.after, room = observation.room, attempts = 0 }
        else
            log("source group for item " .. tostring(id) .. " cannot be attributed to pickup " .. token
                .. "; stat draw saved, familiar copy skipped")
        end
        save()
        refresh(player)
    end

    local function acquired(player, id, token, physical, temporary, receipt)
        if not player then return end
        local playerKey = keyFor(player)
        local owner = inventoryKey(player)
        local stack = beforeAdd[owner] and beforeAdd[owner][id]
        local observation
        if stack then
            if receipt then
                for index, pending in ipairs(stack) do
                    if pending.receipt == receipt or (pending.receipt and pending.receipt.serial == receipt.serial) then
                        observation = table.remove(stack, index); break
                    end
                end
            else observation = table.remove(stack) end
        end
        settleAcquisition(player, id, token, physical, temporary, observation, playerKey)
        if stack and #stack > 0 and not (stack[#stack].receipt and stack[#stack].receipt.completed) then
            -- A nested same-ID addition has completed before the outer one is
            -- applied. Rebase the outer observation after native initialization;
            -- it must not copy that nested scripted/temporary contribution.
            player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
            player:EvaluateItems()
            local outer = stack[#stack]
            outer.group, outer.beforeCount = nativeGroup(player, id), itemCount(player, id)
        end
    end

    local function resolveGroups(player, record, playerKey)
        local remaining = {}
        for _, pending in ipairs(record.pending) do
            local current = pending.after or nativeGroup(player, pending.id)
            local rows, decreased = {}, false
            for key, old in pairs(pending.before) do
                if (current[key] and current[key].count or 0) < old.count then decreased = true end
            end
            for key, row in pairs(current) do
                local count = row.count - (pending.before[key] and pending.before[key].count or 0)
                if count > 0 then rows[#rows + 1] = { variant = row.variant, subtype = row.subtype, count = count } end
            end
            table.sort(rows, function(a, b)
                return a.variant == b.variant and a.subtype < b.subtype or a.variant < b.variant
            end)
            if not decreased and #rows > 0 then
                for _, row in ipairs(rows) do
                    row.seeds = {}
                    for slot = 1, row.count do
                        row.seeds[slot] = identitySeed(playerKey, pending.token,
                            tostring(row.variant) .. ":" .. tostring(row.subtype) .. ":" .. slot)
                    end
                end
                record.groups[#record.groups + 1] = { id = pending.id, token = pending.token, species = rows }
                save()
            else
                pending.attempts = (pending.attempts or 0) + 1
                if pending.attempts == 1 then
                    log("item " .. tostring(pending.id) .. " has no unambiguous new native source group; "
                        .. "no variant guess made (pickup " .. pending.token .. ")")
                end
                -- A bounded retry permits native familiar initialization after the
                -- add callback. A room change or nonlinear replacement is unsafe.
                if not decreased and pending.room == state.RoomKey() and pending.attempts < 2 then
                    remaining[#remaining + 1] = pending
                end
            end
        end
        if #remaining ~= #record.pending then record.pending = remaining; save() end
    end

    local function desiredCopies(record, playerKey)
        local desired = {}
        if not record then return desired end
        for _, group in ipairs(record.groups) do
            for _, row in ipairs(group.species) do
                for slot, seed in ipairs(row.seeds) do
                    desired[tostring(seed)] = { playerKey = playerKey, token = group.token, sourceId = group.id,
                        variant = row.variant, subtype = row.subtype, slot = slot, seed = seed }
                end
            end
        end
        return desired
    end
    local function reconcileCopies(player, record, playerKey)
        local owner = inventoryKey(player)
        local desired = desiredCopies(record, playerKey)
        local found = {}
        for _, familiar in ipairs(listFamiliars()) do
            local marker = familiar:GetData()[COPY_KEY]
            local row = desired[tostring(familiar.InitSeed)]
            if marker and marker.playerKey == playerKey then
                if row and inventoryKey(familiar.Player) == owner and familiar.Variant == row.variant and familiar.SubType == row.subtype
                    and hasNoItemSource(familiar)
                    and not found[tostring(row.seed)] then
                    found[tostring(row.seed)] = true
                else
                    -- An undone Hourglass reward, old Lazarus form, or redundant
                    -- owned copy is the only kind this reconciliation removes.
                    familiar:Remove()
                end
            elseif row and inventoryKey(familiar.Player) == owner and familiar.Variant == row.variant and familiar.SubType == row.subtype
                and hasNoItemSource(familiar) and not marker and not found[tostring(row.seed)] then
                -- Save/continue does not persist GetData. Rebind only our exact
                -- saved seed and species with no normal collectible source.
                familiar:GetData()[COPY_KEY] = plainCopy(row)
                found[tostring(row.seed)] = true
            end
        end
        local okVector, zero = pcall(function() return Vector(0, 0) end)
        if not okVector or not zero then log("native Vector unavailable; only owned familiar reconstruction skipped"); return end
        for seed, row in pairs(desired) do
            if not found[seed] then
                -- CACHE_FAMILIARS owns reconstruction. Game:Spawn fixes the saved
                -- identity and leaves ItemConfig nil; native variant/subtype init
                -- and update continue to own this species' AI and native buffs.
                local ok, entity = pcall(function()
                    return Game():Spawn(EntityType.ENTITY_FAMILIAR, row.variant, player.Position, zero,
                        player, row.subtype, row.seed)
                end)
                local familiar = ok and entity and entity:ToFamiliar() or nil
                if familiar and hasNoItemSource(familiar) then
                    familiar.Player = player
                    familiar:GetData()[COPY_KEY] = plainCopy(row)
                elseif familiar then
                    -- Abort only the entity this operation just created. A source
                    -- pointer would let native sacrifice code remove a real item.
                    familiar:Remove()
                    log("copy unexpectedly has an item source or unreadable provenance; owned spawn aborted")
                else
                    log("native familiar reconstruction failed for source " .. tostring(row.sourceId)
                        .. " species " .. row.variant .. ":" .. row.subtype)
                end
            end
        end
    end

    function mod:EchoBabyEvaluateCache(player, flag)
        local record, playerKey = rewards(player, false)
        if flag == CacheFlag.CACHE_DAMAGE then
            if record then player.Damage = player.Damage + (record.damage or 0) end
        elseif flag == CacheFlag.CACHE_FIREDELAY then
            if record and (record.tears or 0) > 0 and player.MaxFireDelay > -1 then
                local rate = 30 / (player.MaxFireDelay + 1)
                local contribution = math.min(record.tears, math.max(0, 5 - rate))
                if contribution > 0 then player.MaxFireDelay = 30 / (rate + contribution) - 1 end
            end
        elseif flag == CacheFlag.CACHE_FAMILIARS and active(player) then
            inCache = true
            ensureConjoined(player)
            local count = itemCount(player, itemId)
            if player.GetEffects then count = count + player:GetEffects():GetCollectibleEffectNum(itemId) end
            player:CheckFamiliar(variant, count, player:GetCollectibleRNG(itemId), configFor(itemId), -1)
            if record then resolveGroups(player, record, playerKey) end
            reconcileCopies(player, record, playerKey)
            inCache = false
        end
    end

    function mod:EchoBabyFamiliarInit(familiar)
        familiar:GetData()[BODY_KEY] = true
        familiar:GetData().NeverbirthEchoCooldown = 0
        familiar:AddToFollowers()
    end
    function callbackInstallers.mod_EchoBabyFamiliarInit()
        return mod:AddCallback(ModCallbacks.MC_FAMILIAR_INIT, mod.EchoBabyFamiliarInit, variant)
    end
    function mod:EchoBabyFamiliarUpdate(familiar)
        if not familiar:GetData()[BODY_KEY] then return end
        familiar:FollowParent()
        local data = familiar:GetData()
        data.NeverbirthEchoFired = false
        data.NeverbirthEchoCooldown = math.max(0, (data.NeverbirthEchoCooldown or 0) - 1)
        -- Own the cadence independently of whether native Shoot decrements before
        -- or after its readiness test. A positive native sentinel prevents early
        -- shots while retaining its native direction/animation processing.
        familiar.FireCooldown = data.NeverbirthEchoCooldown > 0 and data.NeverbirthEchoCooldown + 1 or 0
        -- Native common-shooter handling owns direction, range, animations and
        -- familiar synergies; no player stats or foreign tear effects are copied.
        familiar:Shoot()
        if data.NeverbirthEchoFired then
            data.NeverbirthEchoCooldown = 28
            familiar.FireCooldown = 28
        end
    end
    function callbackInstallers.mod_EchoBabyFamiliarUpdate()
        return mod:AddCallback(ModCallbacks.MC_FAMILIAR_UPDATE, mod.EchoBabyFamiliarUpdate, variant)
    end
    function mod:EchoBabyFiredTear(tear)
        local source = tear.SpawnerEntity
        local familiar = source and source:ToFamiliar()
        if not familiar or familiar.Variant ~= variant or not familiar:GetData()[BODY_KEY] then return end
        tear.CollisionDamage = 3 * familiar:GetMultiplier()
        tear.TearFlags = tear.TearFlags | TearFlags.TEAR_SPECTRAL
        tear:GetData().NeverbirthEchoTear = true
        familiar:GetData().NeverbirthEchoFired = true
    end
    function callbackInstallers.mod_EchoBabyFiredTear()
        return mod:AddCallback(ModCallbacks.MC_POST_FAMILIAR_FIRE_PROJECTILE, mod.EchoBabyFiredTear, variant)
    end
    function mod:EchoBabyPlayerUpdate(player)
        if not active(player) then return end
        local record, playerKey = rewards(player, false)
        local count = itemCount(player, itemId)
        ensureConjoined(player)
        local owner = inventoryKey(player)
        if activeOwners[playerKey] ~= owner or lastCounts[playerKey] ~= count or (record and #record.pending > 0) then
            activeOwners[playerKey], lastCounts[playerKey] = owner, count
            refresh(player)
        end
    end
    function callbackInstallers.mod_EchoBabyPlayerUpdate()
        return mod:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, mod.EchoBabyPlayerUpdate)
    end
    function mod:EchoBabyNewRoom()
        beforeAdd = {}
        for _, player in ipairs(context.GetPlayers()) do if active(player) then refresh(player) end end
    end
    function callbackInstallers.mod_EchoBabyNewRoom()
        return mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, mod.EchoBabyNewRoom)
    end
    function mod:EchoBabyGameStarted(continued)
        beforeAdd, activeOwners, lastCounts = {}, {}, {}
        loadState(not continued)
        if not continued then
            for _, familiar in ipairs(listFamiliars()) do if familiar:GetData()[COPY_KEY] then familiar:Remove() end end
        end
        -- The first player update refreshes caches after the main save loader.
    end
    function callbackInstallers.mod_EchoBabyGameStarted()
        return mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.EchoBabyGameStarted)
    end
    function mod:EchoBabyGameExit(shouldSave)
        if shouldSave then ensureState(); save() end
        beforeAdd, activeOwners, lastCounts = {}, {}, {}
    end
    function callbackInstallers.mod_EchoBabyGameExit()
        return mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.EchoBabyGameExit)
    end

    state.SubscribeAcquisition(acquired)
    state.RegisterParticipant("echo_baby", function()
        ensureState(); return plainCopy(saved)
    end, function(snapshot)
        if type(snapshot) == "table" and snapshot.seed == runSeed() then
            saved = plainCopy(snapshot)
        else
            saved = { version = 1, seed = runSeed(), players = {} }
        end
        context.GetSaveRoot()[SAVE_KEY] = saved
        beforeAdd, activeOwners, lastCounts = {}, {}, {}
        -- Actual cache refresh follows native room restoration; removing entities
        -- now would race the Hourglass's own familiar state reconstruction.
    end)

    callbackInstallers.mod_EchoBabyPreAdd()
    -- Observe native and earlier cap-breaking contributions before deciding
    -- how much of Echo's recorded reward still fits under 5 tears/second.
    mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(self, player, flag)
        if flag ~= CacheFlag.CACHE_FIREDELAY then self:EchoBabyEvaluateCache(player, flag) end
    end)
    local tearsCache = function(self, player, flag)
        if flag == CacheFlag.CACHE_FIREDELAY then self:EchoBabyEvaluateCache(player, flag) end
    end
    if mod.AddPriorityCallback and CallbackPriority then
        mod:AddPriorityCallback(ModCallbacks.MC_EVALUATE_CACHE, CallbackPriority.LATE + 1, tearsCache)
    else mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, tearsCache) end
    callbackInstallers.mod_EchoBabyFamiliarInit()
    callbackInstallers.mod_EchoBabyFamiliarUpdate()
    callbackInstallers.mod_EchoBabyFiredTear()
    callbackInstallers.mod_EchoBabyPlayerUpdate()
    callbackInstallers.mod_EchoBabyNewRoom()
    callbackInstallers.mod_EchoBabyGameStarted()
    callbackInstallers.mod_EchoBabyGameExit()

    local api = { GetRewards = function(player)
        local record = rewards(player, false)
        return record and { damage = record.damage, tears = record.tears } or { damage = 0, tears = 0 }
    end, IsCopy = function(familiar) return familiar and familiar:GetData()[COPY_KEY] ~= nil end }
    mod.EchoBaby = api
    return api
end
