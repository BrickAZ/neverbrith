-- Owns this feature's rules, state and callbacks. Dependencies are provided by main.lua.
return function(Neverbirth, dependencies)
local GetPlayers = assert(dependencies.GetPlayers)
function Neverbirth:GetItemConfigObject()
    if Isaac.GetItemConfig then
        return Isaac.GetItemConfig()
    end

    return nil
end

function Neverbirth:GetCollectibleConfig(itemId)
    local config = self:GetItemConfigObject()
    if config and config.GetCollectible then
        return config:GetCollectible(itemId)
    end

    return nil
end

function Neverbirth:IsBabyTaggedCollectible(itemId)
    local config = self:GetCollectibleConfig(itemId)
    local babyTag = ItemConfig and ItemConfig.TAG_BABY
    if config and babyTag and type(config.Tags) == "number" then
        return (config.Tags & babyTag) ~= 0
    end

    return false
end

function Neverbirth:CollectBabyTaggedItems()
    local ids = {}
    local config = self:GetItemConfigObject()
    if not config or not config.GetCollectibles then
        return ids
    end

    -- GetCollectibles returns native userdata, not an iterable Lua table.
    -- Use Size + GetCollectible; GetTaggedItems can crash in REPENTOGON 1.0.12a.
    local collectibles = config:GetCollectibles()
    local size = collectibles and tonumber(collectibles.Size) or 0
    for itemId = 1, (size or 0) - 1 do
        if self:IsBabyTaggedCollectible(itemId) then
            ids[#ids + 1] = itemId
        end
    end

    return ids
end

function Neverbirth:AnyPlayerOwnsCollectible(itemId)
    for _, player in ipairs(GetPlayers()) do
        if player.GetCollectibleNum and player:GetCollectibleNum(itemId) > 0 then
            return true
        end
    end

    return false
end


end
