-- Owns the complete UncutCord feature; installed at its original callback position.
return function(Neverbirth, dependencies)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local Rolls = include("scripts.systems.collectible_rng")
local WorldQueries = include("scripts.runtime.world_queries")
    local Items = { UncutCord = assert(dependencies.ItemId) }
    local GetPlayers = assert(dependencies.GetPlayers)
    local IsBloodSkullBacklashActive = assert(dependencies.IsBloodSkullBacklashActive)

local UNCUT_CORD_TRIGGER_CHANCE = 0.5
local UNCUT_CORD_ROOMS_REQUIRED = 2
local UNCUT_CORD_MIN_SETTLED_DAMAGE = 1
local UNCUT_CORD_SETTLE_FLAGS = DamageFlag.DAMAGE_INVINCIBLE
local UNCUT_CORD_POPUP_DURATION = 45
local UNCUT_CORD_DEBT_OFFSET = Vector(0, -44)
local UNCUT_CORD_POPUP_OFFSET = Vector(0, -58)

local uncutCordDebts = {}
local uncutCordSettling = {}
local uncutCordFeedbacks = {}
local running, disposed = true, false

local function GetUncutCordPlayerKey(player)
    return tostring(player and player.InitSeed or "")
end

local function PlayerHasUncutCord(player)
    return player and player.GetCollectibleNum and player:GetCollectibleNum(Items.UncutCord) > 0
end

local function GetUncutCordRandomFloat(player)
    local rng = Rolls.Get(player, Items.UncutCord, "RandomFloat")
    if rng then
        local ok, value = pcall(function() return rng:RandomFloat() end)
        if ok and type(value) == "number" then return value end
    end
    return math.random()
end

local function IsUncutCordCombatEnemy(entity)
    if not entity or not entity.IsVulnerableEnemy then
        return false
    end

    local ok, isEnemy = pcall(function()
        return entity:IsVulnerableEnemy()
    end)
    return ok and isEnemy == true
end

local function UncutCordRoomHasEnemies()
    if not Isaac.GetRoomEntities then
        return false
    end

    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if IsUncutCordCombatEnemy(entity) then
            return true
        end
    end

    return false
end

local function GetUncutCordGame()
    return WorldQueries.TryGame()
end

local function GetUncutCordRoom()
    local game = GetUncutCordGame()
    if game and game.GetRoom then
        return game:GetRoom()
    end

    return nil
end

local function GetUncutCordRoomKey()
    return WorldQueries.RoomIndexOrSeed(function()
        local game = GetUncutCordGame()
        if game and game.GetLevel then return game:GetLevel() end
    end, GetUncutCordRoom)
end

local function IsUncutCordRoomClear()
    if UncutCordRoomHasEnemies() then
        return false
    end

    local room = GetUncutCordRoom()
    if room and room.IsClear then
        local ok, isClear = pcall(function()
            return room:IsClear()
        end)
        if ok then
            return isClear == true
        end
    end

    return true
end

local function AttachUncutCordRoomState(record)
    record.currentRoomKey = GetUncutCordRoomKey()
    record.currentRoomHadEnemies = UncutCordRoomHasEnemies()
    record.currentRoomCounted = false
end

local function FindUncutCordPlayerByKey(playerKey)
    for _, player in ipairs(GetPlayers()) do
        if GetUncutCordPlayerKey(player) == playerKey then
            return player
        end
    end

    return nil
end

local function FormatUncutCordHeartAmount(amount)
    return string.format("%.1f", (tonumber(amount) or 0) / 2)
end

local function SetUncutCordFeedback(playerKey, textKey, suffix, r, g, b)
    if playerKey == nil or playerKey == "" then
        return
    end

    uncutCordFeedbacks[playerKey] = {
        textKey = textKey,
        suffix = suffix or "",
        timer = UNCUT_CORD_POPUP_DURATION,
        r = r or 1,
        g = g or 1,
        b = b or 1,
    }
end

local function SetUncutCordPlayerFeedback(player, textKey, suffix, r, g, b)
    SetUncutCordFeedback(GetUncutCordPlayerKey(player), textKey, suffix, r, g, b)
end

local function ApplyUncutCordDamage(player, amount)
    local playerKey = GetUncutCordPlayerKey(player)
    local previous = uncutCordSettling[playerKey]
    uncutCordSettling[playerKey] = true

    local ok, err = pcall(function()
        if player and player.TakeDamage then
            player:TakeDamage(amount, UNCUT_CORD_SETTLE_FLAGS, EntityRef(player), 0)
        end
    end)

    uncutCordSettling[playerKey] = previous
    if not ok then error(err, 0) end -- Release the guard without retrying possibly applied damage.
end

local function SettleUncutCordDebt(player, playerKey, record, amount, feedbackKey)
    local settledAmount = math.max(UNCUT_CORD_MIN_SETTLED_DAMAGE, tonumber(amount) or 0)
    uncutCordDebts[playerKey] = nil
    if feedbackKey then
        SetUncutCordFeedback(
            playerKey,
            feedbackKey,
            " " .. FormatUncutCordHeartAmount(settledAmount),
            1,
            feedbackKey == "uncutCordHalfPaid" and 0.85 or 0.35,
            feedbackKey == "uncutCordHalfPaid" and 0.25 or 0.2
        )
    end
    ApplyUncutCordDamage(player, settledAmount)
end

local function SettleUncutCordDebtHalf(player, playerKey, record)
    SettleUncutCordDebt(player, playerKey, record, (tonumber(record.amount) or 0) / 2, "uncutCordHalfPaid")
end

local function SettleUncutCordDebtFull(player, playerKey, record)
    SettleUncutCordDebt(player, playerKey, record, tonumber(record.amount) or 0, "uncutCordFullPaid")
end

local function StoreUncutCordDebt(player, amount)
    local playerKey = GetUncutCordPlayerKey(player)
    local record = {
        amount = tonumber(amount) or 0,
        roomsCleared = 0,
    }
    AttachUncutCordRoomState(record)
    uncutCordDebts[playerKey] = record
    SetUncutCordPlayerFeedback(player, "uncutCordDelay", " " .. FormatUncutCordHeartAmount(record.amount), 0.55, 0.9, 1)
end

function Neverbirth:HandleUncutCordDamage(entity, amount)
    if not running or disposed then return nil end
    local player = entity and entity.ToPlayer and entity:ToPlayer()
    if not player then
        return nil
    end

    local playerKey = GetUncutCordPlayerKey(player)
    if uncutCordSettling[playerKey] then
        return nil
    end

    if IsBloodSkullBacklashActive() then
        return nil
    end

    local record = uncutCordDebts[playerKey]
    if record then
        SettleUncutCordDebtFull(player, playerKey, record)
        return nil
    end

    local damageAmount = tonumber(amount) or 0
    if damageAmount <= 0 or not PlayerHasUncutCord(player) then
        return nil
    end

    if GetUncutCordRandomFloat(player) >= UNCUT_CORD_TRIGGER_CHANCE then
        return nil
    end

    StoreUncutCordDebt(player, damageAmount)
    return false
end

Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.HandleUncutCordDamage)

function Neverbirth:TrackUncutCordNewRoom()
    if not running or disposed then return end
    for _, record in pairs(uncutCordDebts) do
        AttachUncutCordRoomState(record)
    end
end

if ModCallbacks.MC_POST_NEW_ROOM then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.TrackUncutCordNewRoom)
end

function Neverbirth:UpdateUncutCordRooms()
    if not running or disposed then return end
    if next(uncutCordDebts) == nil or not IsUncutCordRoomClear() then
        return
    end

    local currentRoomKey = GetUncutCordRoomKey()
    for playerKey, record in pairs(uncutCordDebts) do
        if record.currentRoomKey ~= currentRoomKey then
            AttachUncutCordRoomState(record)
        end

        if record.currentRoomHadEnemies and not record.currentRoomCounted then
            record.currentRoomCounted = true
            record.roomsCleared = (tonumber(record.roomsCleared) or 0) + 1

        end
        if record.roomsCleared >= UNCUT_CORD_ROOMS_REQUIRED then
            local player = FindUncutCordPlayerByKey(playerKey)
            -- A temporarily absent owner keeps plain debt until a current entity is available.
            if player then SettleUncutCordDebtHalf(player, playerKey, record) end
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateUncutCordRooms)

function Neverbirth:UpdateUncutCordFeedbacks()
    if not running or disposed then return end
    for playerKey, feedback in pairs(uncutCordFeedbacks) do
        feedback.timer = (tonumber(feedback.timer) or 0) - 1
        if feedback.timer <= 0 then
            uncutCordFeedbacks[playerKey] = nil
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateUncutCordFeedbacks)

local function AddUncutCordRenderPlayer(playersByKey, player)
    if not player or not player.Position then
        return
    end

    local playerKey = GetUncutCordPlayerKey(player)
    if playerKey ~= "" then
        playersByKey[playerKey] = player
    end
end

local function GetUncutCordRenderPlayers()
    local playersByKey = {}
    for _, player in ipairs(GetPlayers()) do
        AddUncutCordRenderPlayer(playersByKey, player)
    end

    return playersByKey
end

local function RenderUncutCordText(textKey, suffix, screenPosition, r, g, b)
    local x = screenPosition.X - 32
    local y = screenPosition.Y
    Neverbirth:RenderRuntimeText(textKey, suffix, x + 1, y + 1, 0, 0, 0, 0.75)
    Neverbirth:RenderRuntimeText(textKey, suffix, x, y, r, g, b, 1)
end

function Neverbirth:RenderUncutCordFeedbacks()
    if not running or disposed then return end
    for playerKey, player in pairs(GetUncutCordRenderPlayers()) do
        local record = uncutCordDebts[playerKey]
        if record then
            local roomsCleared = math.min(tonumber(record.roomsCleared) or 0, UNCUT_CORD_ROOMS_REQUIRED)
            local debtSuffix = " " .. FormatUncutCordHeartAmount(record.amount) ..
                " " ..
                tostring(roomsCleared) ..
                "/" ..
                tostring(UNCUT_CORD_ROOMS_REQUIRED)
            local debtPosition = Isaac.WorldToScreen(player.Position + UNCUT_CORD_DEBT_OFFSET)
            RenderUncutCordText("uncutCordDebt", debtSuffix, debtPosition, 1, 0.75, 0.2)
        end

        local feedback = uncutCordFeedbacks[playerKey]
        if feedback and (tonumber(feedback.timer) or 0) > 0 then
            local popupPosition = Isaac.WorldToScreen(player.Position + UNCUT_CORD_POPUP_OFFSET)
            RenderUncutCordText(feedback.textKey, feedback.suffix, popupPosition, feedback.r or 1, feedback.g or 1, feedback.b or 1)
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_RENDER, Neverbirth.RenderUncutCordFeedbacks)

local function ClearUncutCordState()
    uncutCordDebts = {}
    uncutCordSettling = {}
    uncutCordFeedbacks = {}
end

function Neverbirth:ResetUncutCordState(isContinued)
    if disposed then return end
    running = true
    uncutCordSettling = {}
    if isContinued then
        return
    end

    ClearUncutCordState()
end

if ModCallbacks.MC_POST_GAME_STARTED then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetUncutCordState)
end

function Neverbirth:ExitUncutCord()
    running = false
    uncutCordSettling = {}
end
function callbackInstallers.Neverbirth_ExitUncutCord()
    return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, Neverbirth.ExitUncutCord)
end

function Neverbirth:UnloadUncutCord(unloaded)
    if unloaded ~= Neverbirth or disposed then return end
    running, disposed = false, true
    ClearUncutCordState()
end
function callbackInstallers.Neverbirth_UnloadUncutCord()
    return Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, Neverbirth.UnloadUncutCord)
end

callbackInstallers.Neverbirth_ExitUncutCord()
callbackInstallers.Neverbirth_UnloadUncutCord()

end
