-- Health ledger and target-capability projection; no independent persistence or callbacks.
return function(Neverbirth, context, deps)
    local safeCall = deps.safeCall
    local numberCall = deps.numberCall
    local copyTable = deps.copyTable
    local playerType = deps.playerType
    local getPlayerType = deps.getPlayerType
    local pairPartner = deps.pairPartner
    local profileForType = deps.profileForType

    local HEALTH_FIELDS = {
        { key = "maxHearts", getter = "GetMaxHearts", adder = "AddMaxHearts" },
        { key = "hearts", getter = "GetHearts", adder = "AddHearts" },
        { key = "soulHearts", getter = "GetSoulHearts", adder = "AddSoulHearts" },
        { key = "blackMask", getter = "GetBlackHearts" },
        { key = "boneHearts", getter = "GetBoneHearts", adder = "AddBoneHearts" },
        { key = "rottenHearts", getter = "GetRottenHearts", adder = "AddRottenHearts" },
        { key = "eternalHearts", getter = "GetEternalHearts", adder = "AddEternalHearts" },
        { key = "goldenHearts", getter = "GetGoldenHearts", adder = "AddGoldenHearts" },
        { key = "brokenHearts", getter = "GetBrokenHearts", adder = "AddBrokenHearts" },
        { key = "soulCharge", getter = "GetSoulCharge" },
        { key = "bloodCharge", getter = "GetBloodCharge" },
    }

    local function readHealth(player)
        local result = {}
        for _, field in ipairs(HEALTH_FIELDS) do
            result[field.key] = numberCall(player, field.getter)
        end
        if getPlayerType(player) == playerType("PLAYER_THEFORGOTTEN", 16) then
            local soul = pairPartner(player)
            if soul then
                result.soulHearts = numberCall(soul, "GetSoulHearts")
                result.blackMask = numberCall(soul, "GetBlackHearts")
            end
        end
        return result
    end

    local function adjustHealth(player, getter, adder, target)
        local current = numberCall(player, getter)
        local difference = (tonumber(target) or 0) - current
        if difference ~= 0 then safeCall(player, adder, difference) end
    end

    local function clearHealth(player)
        -- Clear secondary counters before their containers so no value is cloned.
        for _, field in ipairs({
            { "GetBrokenHearts", "AddBrokenHearts" },
            { "GetGoldenHearts", "AddGoldenHearts" },
            { "GetEternalHearts", "AddEternalHearts" },
            { "GetRottenHearts", "AddRottenHearts" },
            { "GetBoneHearts", "AddBoneHearts" },
            { "GetSoulHearts", "AddSoulHearts" },
            { "GetHearts", "AddHearts" },
            { "GetMaxHearts", "AddMaxHearts" },
        }) do
            local amount = numberCall(player, field[1])
            if amount ~= 0 then safeCall(player, field[2], -amount) end
        end
    end

    local function addSoulLedger(player, total, blackMask)
        total = math.max(0, tonumber(total) or 0)
        blackMask = math.max(0, tonumber(blackMask) or 0)
        for index = 0, total - 1 do
            local isBlack = math.floor(blackMask / (2 ^ math.floor(index / 2))) % 2 == 1
            if isBlack then
                safeCall(player, "AddBlackHearts", 1)
            else
                safeCall(player, "AddSoulHearts", 1)
            end
        end
    end

    local function healthMode(player, profile)
        local kind = getPlayerType(player)
        if kind == playerType("PLAYER_BETHANY", 18) then return "red_only" end
        local native = safeCall(player, "GetHealthType")
        if native == 1 then return "soul_only" end
        if native == 2 then return "lost" end
        if native == 3 then return "keeper" end
        if native == 4 then return "bone" end
        if kind == 12 or kind == 17 or kind == 24 or kind == 35 or kind == 36 or kind == 40 then return "soul_only" end
        if kind == 16 then return "bone" end
        return profile and profile.healthMode or "ordinary"
    end

    local function healthAmount(health)
        return (health.hearts or 0) + (health.soulHearts or 0) + (health.boneHearts or 0) * 2
    end

    local function restoreCharges(player, ledger)
        for _, entry in ipairs({ {"soulCharge", "SetSoulCharge", "GetSoulCharge", "AddSoulCharge"},
            {"bloodCharge", "SetBloodCharge", "GetBloodCharge", "AddBloodCharge"} }) do
            if ledger[entry[1]] ~= nil then
                local _, ok = safeCall(player, entry[2], ledger[entry[1]])
                if not ok then adjustHealth(player, entry[3], entry[4], ledger[entry[1]]) end
            end
        end
    end

    local function applyHealth(player, ledger, profile)
        ledger = ledger or readHealth(player)
        profile = profile or { healthMode = "ordinary" }
        local mode = healthMode(player, profile)
        -- Lost is alive through a native hidden half-heart. Never clear it.
        if mode == "lost" then
            if numberCall(player, "GetSoulHearts") < 1 then safeCall(player, "AddSoulHearts", 1) end
            restoreCharges(player, ledger)
            return mode
        end
        local projected = copyTable(ledger)
        local total = healthAmount(ledger)
        if mode == "soul_only" then
            projected.maxHearts, projected.hearts, projected.boneHearts = 0, 0, 0
            projected.soulHearts, projected.rottenHearts = total, 0
        elseif mode == "red_only" or mode == "keeper" then
            projected.soulHearts, projected.boneHearts = 0, 0
            projected.maxHearts = math.max(ledger.maxHearts or 0, math.ceil(total / 2) * 2)
            if mode == "keeper" then
                local limit = numberCall(player, "GetHeartLimit")
                if limit <= 0 then limit = profile.keeperHeartCap or 6 end
                projected.maxHearts = math.min(projected.maxHearts, limit, profile.keeperHeartCap or 6)
                projected.rottenHearts = 0
            end
            projected.hearts = math.min(total, projected.maxHearts)
        elseif mode == "bone" then
            projected.boneHearts = math.max(ledger.boneHearts or 0, math.ceil((ledger.maxHearts or 0) / 2))
            if projected.boneHearts == 0 and total > 0 then projected.boneHearts = 1 end
            projected.maxHearts = 0
        end
        local soulTarget = mode == "bone" and pairPartner(player) or player
        clearHealth(player)
        if soulTarget and soulTarget ~= player then clearHealth(soulTarget) end
        adjustHealth(player, "GetBrokenHearts", "AddBrokenHearts", projected.brokenHearts)
        adjustHealth(player, "GetMaxHearts", "AddMaxHearts", projected.maxHearts)
        adjustHealth(player, "GetBoneHearts", "AddBoneHearts", projected.boneHearts)
        adjustHealth(player, "GetHearts", "AddHearts", math.min(projected.hearts or 0,
            (projected.maxHearts or 0) + (projected.boneHearts or 0) * 2))
        addSoulLedger(soulTarget or player, projected.soulHearts, projected.blackMask)
        adjustHealth(player, "GetRottenHearts", "AddRottenHearts", projected.rottenHearts)
        adjustHealth(player, "GetEternalHearts", "AddEternalHearts", projected.eternalHearts)
        adjustHealth(player, "GetGoldenHearts", "AddGoldenHearts", projected.goldenHearts)
        restoreCharges(player, ledger)
        return mode
    end

    local function copySoulColors(mask, start, sourceMask, sourceStart, count)
        mask, sourceMask = mask or 0, sourceMask or 0
        for offset = 0, count - 1 do
            local bit = 2 ^ math.floor((start + offset) / 2)
            local sourceBit = 2 ^ math.floor((sourceStart + offset) / 2)
            local current = math.floor(mask / bit) % 2
            local desired = math.floor(sourceMask / sourceBit) % 2
            mask = mask + (desired - current) * bit
        end
        return mask
    end

    local function captureHealthLedger(player, state)
        local profile = state.currentProfile or profileForType(getPlayerType(player))
        if healthMode(player, profile) == "lost" then return end

        local current = readHealth(player)
        local applied = state.appliedHealth or current
        if state.healthProjection and state.healthProjection ~= "ordinary" and state.healthProjection ~= "jacob" then
            local ledger = state.healthLedger
            local delta = healthAmount(current) - healthAmount(applied)
            local preferred = state.healthProjection == "soul_only" and "soulHearts" or "hearts"
            local soulProjection = state.healthProjection == "soul_only"
            local tail = soulProjection and (state.projectedSoulTail or 0) or 0
            if delta >= 0 then
                ledger[preferred] = (ledger[preferred] or 0) + delta
                if soulProjection then tail = tail + delta end
            else
                local loss = -delta
                local tailLoss = math.min(tail, loss)
                ledger.soulHearts = math.max(0, (ledger.soulHearts or 0) - tailLoss)
                tail, loss = tail - tailLoss, loss - tailLoss
                local other = preferred == "hearts" and "soulHearts" or "hearts"
                -- Converted health was appended outside the native heart pool.
                local order = state.healthProjection == "soul_only"
                    and {"hearts", "boneHearts", "soulHearts"} or {preferred, other, "boneHearts"}
                for _, key in ipairs(order) do
                    local unit = key == "boneHearts" and 2 or 1
                    local available = (ledger[key] or 0) * unit
                    local removed = math.min(available, loss)
                    ledger[key] = math.max(0, (ledger[key] or 0) - math.ceil(removed / unit))
                    loss = loss - removed
                end
            end
            if soulProjection then
                local nativeSouls = math.max(0, math.min((ledger.soulHearts or 0) - tail, current.soulHearts - tail))
                ledger.blackMask = copySoulColors(ledger.blackMask, 0, current.blackMask, 0, nativeSouls)
                if tail > 0 then
                    ledger.blackMask = copySoulColors(ledger.blackMask, (ledger.soulHearts or 0) - tail,
                        current.blackMask, current.soulHearts - tail, tail)
                end
                state.projectedSoulTail = tail
                ledger.blackMask = (ledger.blackMask or 0) % (2 ^ math.ceil((ledger.soulHearts or 0) / 2))
            end
            if state.healthProjection == "red_only" or state.healthProjection == "keeper" then
                ledger.maxHearts = math.max(0, (ledger.maxHearts or 0) + current.maxHearts - (applied.maxHearts or 0))
            end
            for _, key in ipairs({"brokenHearts", "goldenHearts", "eternalHearts", "soulCharge", "bloodCharge"}) do
                ledger[key] = math.max(0, (ledger[key] or 0) + current[key] - (applied[key] or 0))
            end
            -- Advancing the baseline makes save + continue + next switch idempotent.
            state.appliedHealth = current
            return
        end
        if profile.healthMode == "soul_only" then
            state.healthLedger.soulHearts = math.max(0,
                (state.healthLedger.soulHearts or 0) + current.soulHearts - (applied.soulHearts or 0))
            state.healthLedger.blackMask = current.blackMask
            state.healthLedger.boneHearts = math.max(0,
                (state.healthLedger.boneHearts or 0) + current.boneHearts - (applied.boneHearts or 0))
            return
        end
        if profile.healthMode == "keeper" then
            state.healthLedger.maxHearts = math.max(0,
                (state.healthLedger.maxHearts or 0) + current.maxHearts - (applied.maxHearts or 0))
            state.healthLedger.hearts = math.max(0,
                (state.healthLedger.hearts or 0) + current.hearts - (applied.hearts or 0))
            state.healthLedger.brokenHearts = current.brokenHearts
            return
        end
        state.healthLedger = current
    end

    return {
        readHealth = readHealth,
        healthMode = healthMode,
        healthAmount = healthAmount,
        applyHealth = applyHealth,
        captureHealthLedger = captureHealthLedger,
    }
end
