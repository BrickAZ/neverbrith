-- Owns handlers and native bindings; the entry schedules installation.
return function(Neverbirth, dependencies)
-- Native bindings are declared here; the entry chooses their installation phase.
local callbackInstallers = {}
local BAN_COUNT = 2
local ShowFeedback = assert(dependencies.ShowFeedback)
local Store = assert(dependencies.Store)
local Items = assert(dependencies.Items)
local GetCurrentRunSeed = assert(dependencies.GetCurrentRunSeed)

local getRunData = include("scripts.runtime.run_section")(Store, GetCurrentRunSeed,
    function() return { runSeed = GetCurrentRunSeed(), banned = {} } end, { "banned" })
function Neverbirth:GetCondomData()
    return getRunData()
end

local function ResetRun()
    -- A new run may reuse the seed; preserve fields owned by extensions.
    local data = Store.Get()
    data.runSeed = GetCurrentRunSeed()
    data.banned = {}
    Store.Save()
end

local function GetCondomEligibleItems(self)
    local data = self:GetCondomData()
    local eligible = {}
    local game = Game()
    local itemPool = game and game:GetItemPool()

    for _, itemId in ipairs(self:CollectBabyTaggedItems()) do
        if not data.banned[tostring(itemId)] and not self:AnyPlayerOwnsCollectible(itemId)
            and (not itemPool or not itemPool.CanSpawnCollectible or itemPool:CanSpawnCollectible(itemId, false)) then
            eligible[#eligible + 1] = itemId
        end
    end

    return eligible
end

local function PickCondomTarget(self, eligible, rng)
    if #eligible <= 0 then
        return nil
    end

    local index = 1
    if rng and rng.RandomInt then
        index = rng:RandomInt(#eligible) + 1
    end

    local itemId = eligible[index]
    table.remove(eligible, index)
    return itemId
end

function Neverbirth:UseCondom(itemId, rng, player)
    local data = self:GetCondomData()
    local eligible = GetCondomEligibleItems(self)
    local playerRng = rng
    if (not playerRng or not playerRng.RandomInt) and player and player.GetCollectibleRNG then
        playerRng = player:GetCollectibleRNG(Items.Condom)
    end

    local bannedItems = {}
    for _ = 1, BAN_COUNT do
        local target = PickCondomTarget(self, eligible, playerRng)
        if not target then
            break
        end

        data.banned[tostring(target)] = true
        bannedItems[#bannedItems + 1] = target
    end

    ShowFeedback(bannedItems)
    if #bannedItems > 0 then
        Store.Save()
    end

    return true
end
function callbackInstallers.InstallUseCondom()
    return Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseCondom, Items.Condom)
end

function Neverbirth:IsCondomBanned(itemId)
    local data = self:GetCondomData()
    return data.banned[tostring(itemId)] == true
end

local function IsCondomBannedCollectible(self, itemId)
    return itemId and self:IsCondomBanned(itemId)
end

return { ResetRun = ResetRun, IsBannedCollectible = function(id) return IsCondomBannedCollectible(Neverbirth, id) end,
    InstallUseCondom = callbackInstallers.InstallUseCondom,
}
end
