-- Stateless card algorithms. Item owners supply validity and fallback policies.
local Cards = {}
local WorldQueries = include("scripts.runtime.world_queries")

function Cards.GetItemPool()
    return WorldQueries.TryMethod(Game and Game() or nil, "GetItemPool")
end

function Cards.GetItemConfig()
    return WorldQueries.TryItemConfig()
end

function Cards.HasDisplayData(itemConfig, subtype)
    if itemConfig and itemConfig.GetCard then
        local ok, cardConfig = pcall(function()
            return itemConfig:GetCard(subtype)
        end)
        if not ok or cardConfig == nil then
            return false
        end

        local hasDisplayData = false
        for _, field in ipairs({ "Name", "Description", "GfxFileName", "HudAnim" }) do
            local fieldOk, value = pcall(function()
                return cardConfig[field]
            end)
            if fieldOk and value ~= nil and tostring(value) ~= "" then
                hasDisplayData = true
                break
            end
        end
        if not hasDisplayData then
            return false
        end
    end
    return true
end

function Cards.AddCandidate(candidates, seen, subtype, isKnown)
    subtype = math.floor(tonumber(subtype) or 0)
    if subtype >= 1 and not seen[subtype] and isKnown(subtype) then
        seen[subtype] = true
        candidates[#candidates + 1] = subtype
    end
end

function Cards.CollectCandidates(addCandidate, first, last)
    local candidates = {}
    local seen = {}
    local maxVanilla = last or ((Card and type(Card.RUNE_HAGALAZ) == "number" and Card.RUNE_HAGALAZ > 1) and (Card.RUNE_HAGALAZ - 1) or 31)
    for subtype = first or 1, maxVanilla do
        addCandidate(candidates, seen, subtype)
    end
    if type(Card) == "table" then
        for _, subtype in pairs(Card) do
            addCandidate(candidates, seen, subtype)
        end
    end
    table.sort(candidates)
    return candidates
end

function Cards.RewardSeed(player, attempt, getRoom, salt)
    local seed = tonumber(player and player.InitSeed) or 0
    local room = getRoom()
    if room and room.GetSpawnSeed then
        local ok, roomSeed = pcall(function() return room:GetSpawnSeed() end)
        if ok and type(roomSeed) == "number" then seed = seed + roomSeed end
    end
    return math.abs(math.floor(seed + (attempt or 0) * 101 + salt))
end

-- The name-only fallback is an explicit per-item policy. getVariant preserves
-- Good Girl's live enum lookup and the other callers' captured values.
function Cards.HasEIDDescription(entityType, getVariant, subtype, allowObjectName)
    if not EID then return true end
    local checked, description = false, nil
    local calls = {
        function() return EID.getDescriptionObjByID and EID:getDescriptionObjByID(entityType, getVariant(), subtype) end,
        function() return EID.getDescriptionObj and EID:getDescriptionObj(entityType, getVariant(), subtype) end,
    }
    for _, call in ipairs(calls) do
        local ok, result = pcall(call)
        if ok and result ~= nil then checked, description = true, result; break
        elseif ok then checked = true end
    end
    if allowObjectName and description == nil and EID.getObjectName then
        local ok, name = pcall(function() return EID:getObjectName(entityType, getVariant(), subtype) end)
        if ok then
            checked = true
            if name ~= nil then description = { Name = name } end
        end
    end
    if not checked then return true end
    if type(description) ~= "table" then return false end
    local name = tostring(description.Name or description.ObjName or "")
    local combined = string.lower(name .. " " .. tostring(description.Description or ""))
    if combined == " " or combined:find("no description available", 1, true) then return false end
    if combined:find(tostring(entityType) .. "." .. tostring(getVariant()) .. ".", 1, true) then return false end
    return true
end

function Cards.RollPool(itemPool, seed, isKnown)
    local rolls = {
        function() return itemPool:GetCard(seed, true, true, false) end,
        function() return itemPool:GetCard(seed, true, false, false) end,
    }
    for _, roll in ipairs(rolls) do
        local ok, subtype = pcall(roll)
        if ok and isKnown(subtype) then
            return math.floor(subtype)
        end
    end
    return nil
end

return Cards
