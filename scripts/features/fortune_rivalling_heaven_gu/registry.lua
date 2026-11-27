-- Item-owned implementation; the entry owns callback installation.
-- Registrations append: one owner may have several conditional thresholds.
-- Collectibles and trinkets keep independent ID spaces; runtime owns invalidation.
return function(Neverbirth, dependencies)
local private = assert(dependencies.Private)
local Items = assert(dependencies.Items)
local IsValidItemId = assert(dependencies.IsValidItemId)

function private.RegisterFortuneLuckEntry(self, ownerKind, itemId, fixedCap, resolverFn, auditRow)
    itemId = tonumber(itemId) or 0
    if (ownerKind ~= "collectible" and ownerKind ~= "trinket") or itemId <= 0 then
        return false
    end
    fixedCap = tonumber(fixedCap)
    if not fixedCap and type(resolverFn) ~= "function" then
        return false
    end

    local buckets = self.FortuneRivallingHeavenGu.luckCaps[ownerKind]
    buckets[itemId] = buckets[itemId] or {}
    buckets[itemId][#buckets[itemId] + 1] = {
        fixedCap = fixedCap,
        resolverFn = resolverFn,
        auditRow = auditRow,
    }
    private.luckDependencies[ownerKind][itemId] = true
    self:InvalidateFortuneLuck()
    return true
end

function Neverbirth:RegisterLuckCap(itemId, fixedCap)
    return private.RegisterFortuneLuckEntry(self, "collectible", itemId, fixedCap, nil, nil)
end

function Neverbirth:RegisterLuckCapResolver(itemId, resolverFn)
    return private.RegisterFortuneLuckEntry(self, "collectible", itemId, nil, resolverFn, nil)
end

function Neverbirth:RegisterTrinketLuckCap(trinketId, fixedCap)
    return private.RegisterFortuneLuckEntry(self, "trinket", trinketId, fixedCap, nil, nil)
end

function Neverbirth:RegisterTrinketLuckCapResolver(trinketId, resolverFn)
    return private.RegisterFortuneLuckEntry(self, "trinket", trinketId, nil, resolverFn, nil)
end

function private.PlayerHasFortuneRivallingHeavenGu(self, player)
    return player and player.GetCollectibleNum and IsValidItemId(Items.FortuneRivallingHeavenGu)
        and (tonumber(player:GetCollectibleNum(Items.FortuneRivallingHeavenGu)) or 0) > 0
end

function private.GetFortuneTrinketMultiplier(self, player, trinketId)
    if not player then
        return 0
    end
    if player.GetTrinketMultiplier then
        local ok, multiplier = pcall(function()
            return player:GetTrinketMultiplier(trinketId)
        end)
        if ok and (tonumber(multiplier) or 0) > 0 then
            return math.max(0, tonumber(multiplier) or 0)
        end
    end
    if player.HasTrinket then
        local ok, hasTrinket = pcall(function()
            return player:HasTrinket(trinketId, true)
        end)
        if ok and hasTrinket then
            return 1
        end
    end
    return 0
end

function private.GetFortuneRivallingHeavenGuRequiredLuck(self, player)
    if not player or not player.GetCollectibleNum then
        return 0
    end

    local requiredLuck = 0
    for ownerKind, buckets in pairs(self.FortuneRivallingHeavenGu.luckCaps) do
        for itemId, entries in pairs(buckets) do
            local count = ownerKind == "collectible"
                and math.max(0, tonumber(player:GetCollectibleNum(itemId)) or 0)
                or private.GetFortuneTrinketMultiplier(self, player, itemId)
            if count > 0 then
                for _, entry in ipairs(entries) do
                    local cap = entry.fixedCap
                    if entry.resolverFn then
                        local ok, resolvedCap = pcall(entry.resolverFn, player, itemId, count)
                        cap = ok and tonumber(resolvedCap) or nil
                    end
                    if cap and cap >= 0 then
                        requiredLuck = math.max(requiredLuck, cap)
                    end
                end
            end
        end
    end
    return requiredLuck
end

function private.GetFortuneLuckAuditSignature(self, player)
    if not player then
        return ""
    end
    local parts = { private.PlayerHasFortuneRivallingHeavenGu(self, player) and "gu:1" or "gu:0" }
    for ownerKind, buckets in pairs(self.FortuneRivallingHeavenGu.luckCaps) do
        for itemId, _ in pairs(buckets) do
            local count = ownerKind == "collectible"
                and math.max(0, tonumber(player:GetCollectibleNum(itemId)) or 0)
                or private.GetFortuneTrinketMultiplier(self, player, itemId)
            parts[#parts + 1] = ownerKind .. ":" .. tostring(itemId) .. ":" .. tostring(count)
        end
    end
    table.sort(parts)
    return table.concat(parts, "|")
end

function private.FortuneAuditConditionMet(self, player, condition)
    if not condition or condition == "无" then
        return true
    end
    if condition == "CARD_AGAINST_HUMANITY" or condition == "PILL_RELAX" then
        -- 普通 Repentance 没有可安全盲扫的口袋槽位；这些一次性组合由其原生使用事件处理。
        return false
    end
    local conditionId = CollectibleType and CollectibleType[condition]
    return conditionId and player.GetCollectibleNum and (tonumber(player:GetCollectibleNum(conditionId)) or 0) > 0
end

function Neverbirth:RegisterVerifiedFortuneLuckCaps()
    local state = self.FortuneRivallingHeavenGu
    state.luckCaps = { collectible = {}, trinket = {} }
    private.luckDependencies = { collectible = {}, trinket = {} }
    if IsValidItemId(Items.FortuneRivallingHeavenGu) then
        private.luckDependencies.collectible[Items.FortuneRivallingHeavenGu] = true
    end
    state.auditRows = private.BuildFortuneLuckAuditRows(self)
    for _, auditRow in ipairs(state.auditRows) do
        if auditRow.includeFortune then
            local enumTable = auditRow.kind == "trinket" and TrinketType or CollectibleType
            local itemId = tonumber(auditRow.runtimeItemId) or (enumTable and enumTable[auditRow.enum])
            if itemId then
                local conditionId = CollectibleType and CollectibleType[auditRow.condition]
                if conditionId and conditionId > 0 then
                    private.luckDependencies.collectible[conditionId] = true
                end
                local function resolver(player)
                    if private.FortuneAuditConditionMet(self, player, auditRow.condition) then
                        return auditRow.cap
                    end
                    return nil
                end
                if auditRow.kind == "trinket" then
                    if auditRow.registration == "dynamic" then
                        self:RegisterTrinketLuckCapResolver(itemId, resolver)
                    else
                        self:RegisterTrinketLuckCap(itemId, auditRow.cap)
                    end
                elseif auditRow.registration == "dynamic" then
                    self:RegisterLuckCapResolver(itemId, resolver)
                else
                    self:RegisterLuckCap(itemId, auditRow.cap)
                end
            end
        end
    end
end

end
