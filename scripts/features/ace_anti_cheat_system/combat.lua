-- Private combat ownership; constructed once by the item entry.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local DATA_MONITORED = deps.State.DATA_MONITORED
    local DATA_DAMAGE_EVENTS = deps.State.DATA_DAMAGE_EVENTS
    local DATA_DEATH_PROCESSED = deps.State.DATA_DEATH_PROCESSED
    local runtime = deps.State.runtime
    local realTimeMs = deps.State.realTimeMs
    local safeCall = deps.Queries.safeCall
    local dataOf = deps.Queries.dataOf
    local toNpc = deps.Queries.toNpc
    local present = deps.Queries.present
    local hasFlag = deps.Queries.hasFlag
    local triggerOneHitAudit = deps.Audit.triggerOneHitAudit
    local recordOneHitDeath = deps.Audit.recordOneHitDeath

    local function bossOrMiniBoss(npc)
        local boss, bossOk = safeCall(npc, "IsBoss")
        if bossOk and boss == true then return true end
        local bossId, bossIdOk = safeCall(npc, "GetBossID")
        if bossIdOk and type(bossId) == "number" and bossId > 0 then return true end
        return EntityFlag and hasFlag(npc, EntityFlag.FLAG_BOSS) or false
    end

    local function segmentedMainBody(npc)
        local child = present(npc and npc.ChildNPC) or present(npc and npc.Child)
        local parent = present(npc and npc.ParentNPC) or present(npc and npc.Parent)
        return child and not parent
    end

    local function isEligibleNpc(entity)
        local npc = toNpc(entity)
        if not npc or bossOrMiniBoss(npc) or segmentedMainBody(npc) then return false end

        local enemy, enemyOk = safeCall(npc, "IsEnemy")
        if enemyOk and enemy ~= true then return false end
        local vulnerable, vulnerableOk = safeCall(npc, "IsVulnerableEnemy")
        if not vulnerableOk or vulnerable ~= true then return false end
        local active, activeOk = safeCall(npc, "IsActiveEnemy", false)
        if not activeOk or active ~= true then return false end
        local dead, deadOk = safeCall(npc, "IsDead")
        if deadOk and dead == true then return false end

        if EntityFlag then
            if hasFlag(npc, EntityFlag.FLAG_FRIENDLY)
                or hasFlag(npc, EntityFlag.FLAG_NO_KNOCKBACK)
                or hasFlag(npc, EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK) then
                return false
            end
        end

        -- SpawnerEntity is intentionally not inspected: summons and ordinary
        -- split children remain eligible. Only a segment-owning main body is
        -- rejected above.
        return true
    end

    local function monitorNpc(entity, reset)
        local npc = toNpc(entity)
        if not npc or not isEligibleNpc(npc) then return false end
        local data = dataOf(npc)
        if not data then return false end
        if reset or data[DATA_MONITORED] ~= true then
            data[DATA_DAMAGE_EVENTS] = 0
            data[DATA_DEATH_PROCESSED] = false
        end
        data[DATA_MONITORED] = true
        return true
    end

    local function monitorCurrentRoom(reset)
        if not Isaac or type(Isaac.GetRoomEntities) ~= "function" then return end
        for _, entity in ipairs(Isaac.GetRoomEntities() or {}) do
            monitorNpc(entity, reset)
        end
    end

    local function sameEntity(left, right)
        if left == right then return true end
        if not left or not right then return false end
        local leftSeed = tonumber(left.InitSeed)
        local rightSeed = tonumber(right.InitSeed)
        return leftSeed and rightSeed and leftSeed == rightSeed
    end

    local function entryAccepted(entry)
        local entity = entry and entry.entity
        if not entity then return false end
        local currentHp = tonumber(entity.HitPoints)
        if currentHp and entry.beforeHp and currentHp < entry.beforeHp then return true end
        local dead, deadOk = safeCall(entity, "IsDead")
        if deadOk and dead == true then return true end
        local mortal, mortalOk = safeCall(entity, "HasMortalDamage")
        return mortalOk and mortal == true
    end

    local function settleEntry(entry)
        if not entryAccepted(entry) then return false end
        local data = dataOf(entry.entity)
        if not data or data[DATA_MONITORED] ~= true then return false end
        data[DATA_DAMAGE_EVENTS] = math.max(0, tonumber(data[DATA_DAMAGE_EVENTS]) or 0) + 1
        return true
    end

    local function settlePendingForEntity(entity)
        local settled = 0
        for index = #runtime.pendingDamage, 1, -1 do
            local entry = runtime.pendingDamage[index]
            if sameEntity(entry.entity, entity) then
                if settleEntry(entry) then settled = settled + 1 end
                table.remove(runtime.pendingDamage, index)
            end
        end
        return settled
    end

    local function settleAllPending()
        for index = #runtime.pendingDamage, 1, -1 do
            settleEntry(runtime.pendingDamage[index])
            table.remove(runtime.pendingDamage, index)
        end
    end

    local function handleNpcDeath(entity, now)
        if not runtime.active or runtime.fatalTriggered then return false end
        local npc = toNpc(entity)
        if not npc then return false end
        local data = dataOf(npc)
        if not data then return false end
        if data[DATA_MONITORED] ~= true and not monitorNpc(npc, false) then return false end
        if data[DATA_DEATH_PROCESSED] == true then return false end

        settlePendingForEntity(npc)
        data[DATA_DEATH_PROCESSED] = true
        if tonumber(data[DATA_DAMAGE_EVENTS]) ~= 1 then return true end

        -- The room-owned third one-hit kill audit has priority over the
        -- unsupported target-FPS audit.
        if recordOneHitDeath() then return true end

        local timestamp = tonumber(now)
        if timestamp == nil then timestamp = realTimeMs() end
        if timestamp ~= nil then
            triggerOneHitAudit(timestamp)
        end
        return true
    end

    local function npcDamage(_, entity, amount)
        -- REPENTOGON 1.0.12a NPC POST runs after queue insertion, not HP commit.
        -- Only final positive, uncancelled requests may become candidates here.
        -- Settlement below is still a legacy HP observation, not per-entry proof
        -- when several accepted requests share one native damage queue.
        if not runtime.active or runtime.fatalTriggered or (tonumber(amount) or 0) <= 0 then return nil end
        local npc = toNpc(entity)
        if not npc then return nil end
        local data = dataOf(npc)
        if not data or data[DATA_MONITORED] ~= true then
            if not monitorNpc(npc, false) then return nil end
            data = dataOf(npc)
        end
        runtime.pendingDamage[#runtime.pendingDamage + 1] = {
            entity = npc,
            beforeHp = tonumber(npc.HitPoints),
        }
        return nil
    end
    function callbackInstallers.npcDamage()
        return Neverbirth:AddPriorityCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG, CallbackPriority.IMPORTANT, npcDamage)
    end

    local function npcInit(_, npc)
        if runtime.active then monitorNpc(npc, false) end
        return nil
    end
    function callbackInstallers.npcInit()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_INIT, npcInit)
    end

    local function npcDeath(_, npc)
        handleNpcDeath(npc)
        return nil
    end
    function callbackInstallers.npcDeath()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, npcDeath)
    end

    local function entityKill(_, entity)
        handleNpcDeath(entity)
        return nil
    end
    function callbackInstallers.entityKill()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, entityKill)
    end

    return {
        bossOrMiniBoss = bossOrMiniBoss,
        segmentedMainBody = segmentedMainBody,
        isEligibleNpc = isEligibleNpc,
        monitorNpc = monitorNpc,
        monitorCurrentRoom = monitorCurrentRoom,
        sameEntity = sameEntity,
        entryAccepted = entryAccepted,
        settleEntry = settleEntry,
        settlePendingForEntity = settlePendingForEntity,
        settleAllPending = settleAllPending,
        handleNpcDeath = handleNpcDeath,
        npcDamage = npcDamage,
        npcInit = npcInit,
        npcDeath = npcDeath,
        entityKill = entityKill,
        Installers = callbackInstallers,
    }
end
