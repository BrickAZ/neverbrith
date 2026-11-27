-- Installed once at the old Musicbox callback position by main.lua.
return function(Neverbirth, dependencies)
-- Keep native bindings beside handlers; invoke at their original installation phase.
local callbackInstallers = {}
local Items = { Musicbox = assert(dependencies.ItemId) }
local GetPlayers = assert(dependencies.GetPlayers)
local GetCurrentRunSeed = assert(dependencies.GetCurrentRunSeed)
local Store = assert(dependencies.Store)
local IsIncomingDamageLethal = assert(dependencies.IsIncomingDamageLethal)
local Core = include("scripts.features.musicbox.core")
local MUSICBOX_DURATION, MUSICBOX_PLAN_C_DELAY = Core.Duration, Core.PlanCDelay
local MUSICBOX_MAX_CHARGE = 12
local PLAN_C_ID = (CollectibleType and CollectibleType.COLLECTIBLE_PLAN_C) or 475
local MUSICBOX_PLAN_C_DAMAGE = 9999999
local MUSICBOX_TEAR_COLOR = Color(1, 0, 0, 1, 0, 0, 0)
local MUSICBOX_ACTIVE_SLOTS = { ActiveSlot.SLOT_PRIMARY, ActiveSlot.SLOT_SECONDARY }
local musicboxEffects, musicboxPlanCDeaths = {}, {}
-- Hot reload can install this module inside a run. Exit suspends it; unload is final.
local running, disposed = true, false
local presentation = include("scripts.features.musicbox.presentation")(Neverbirth, {
    GetPlayers = GetPlayers, Effects = musicboxEffects, Log = dependencies.Log, Core = Core,
    IsEnabled = function() return running and not disposed end,
})
local StartMusicboxMusic, KeepMusicboxMusic, StopMusicboxMusic =
    presentation.StartMusic, presentation.KeepMusic, presentation.StopMusic
local function GetMusicboxDebtTable()
    local data = Store.Get()
    if type(data.debts) ~= "table" then data.debts = {} end
    return data.debts
end
local SaveMusicboxData = Store.Save
local function HasActiveMusicboxEffect()
    for _, effect in pairs(musicboxEffects) do
        if effect.timer > 0 then
            return true
        end
    end

    return false
end


local function GetPlayerMusicboxKey(player)
    return tostring(player and player.InitSeed or "")
end

local function FindPlayerByMusicboxDebt(debt)
    if not debt then
        return nil
    end

    local debtSeed = tostring(debt.playerInitSeed or "")
    for _, player in ipairs(GetPlayers()) do
        if tostring(player.InitSeed or "") == debtSeed then
            return player
        end
    end

    return nil
end

local function GetCurrentMusicboxDebt(player)
    local debt = GetMusicboxDebtTable()[GetPlayerMusicboxKey(player)]
    if not debt or not Core.MatchesRun(debt, GetCurrentRunSeed()) then
        return nil
    end

    return debt
end

local function IsMusicboxActiveForPlayer(player)
    if not running or disposed or not player then
        return false
    end

    local effect = musicboxEffects[player.InitSeed]
    if effect and (tonumber(effect.timer) or 0) > 0 then
        return true
    end

    local debt = GetCurrentMusicboxDebt(player)
    return debt and (tonumber(debt.timer) or 0) > 0
end

local function PlayerHasMusicbox(player)
    if not player then
        return false
    end

    if IsMusicboxActiveForPlayer(player) then
        return true
    end

    if player.GetActiveItem then
        for _, slot in ipairs(MUSICBOX_ACTIVE_SLOTS) do
            if player:GetActiveItem(slot) == Items.Musicbox then
                return true
            end
        end
    end

    return player.GetCollectibleNum and player:GetCollectibleNum(Items.Musicbox) > 0
end

local function RefreshMusicboxPlayerCache(player)
    player:AddCacheFlags(CacheFlag.CACHE_TEARCOLOR)
    player:EvaluateItems()
end

local function SyncMusicboxEffectFromDebt(player, debt)
    if not player or not debt then
        return
    end

    musicboxEffects[player.InitSeed] = {
        timer = math.max(tonumber(debt.timer) or 0, 0),
        player = player,
    }
end

local function ClearMusicboxDebt(key)
    GetMusicboxDebtTable()[key] = nil
end

local function ForceMusicboxDeath(key, debt, player)
    if not player then
        return
    end

    local willRevive = player.WillPlayerRevive and player:WillPlayerRevive()
    musicboxEffects[player.InitSeed] = nil
    presentation.ClearVisuals(player.InitSeed)
    RefreshMusicboxPlayerCache(player)

    if willRevive then
        ClearMusicboxDebt(key)
    else
        debt.timer = 0
        debt.expired = true
    end
    SaveMusicboxData()

    if player.Kill then
        player:Kill()
    elseif player.Die then
        player:Die()
    elseif player.TakeDamage then
        player:TakeDamage(999, DamageFlag.DAMAGE_INVINCIBLE, EntityRef(player), 0)
    end
end

local function ForcePlanCDeath(player)
    if not player then
        return
    end

    if player.Kill then
        player:Kill()
    elseif player.Die then
        player:Die()
    elseif player.TakeDamage then
        player:TakeDamage(999, DamageFlag.DAMAGE_INVINCIBLE, EntityRef(player), 0)
    end
end

local function StartMusicboxEffect(player, source)
    local wasActive = HasActiveMusicboxEffect()
    local key = GetPlayerMusicboxKey(player)
    local debts = GetMusicboxDebtTable()
    local debt = debts[key]
    local runSeed = GetCurrentRunSeed()
    musicboxPlanCDeaths[player.InitSeed] = nil

    if Core.MatchesRun(debt, runSeed) then
        SyncMusicboxEffectFromDebt(player, debt)
        RefreshMusicboxPlayerCache(player)

        if wasActive then
            KeepMusicboxMusic()
        else
            StartMusicboxMusic()
        end

        if (tonumber(debt.timer) or 0) <= 0 then
            ForceMusicboxDeath(key, debt, player)
        end

        return true
    end

    debt = {
        runSeed = runSeed,
        playerInitSeed = player.InitSeed,
        timer = MUSICBOX_DURATION,
        source = source or "use",
        expired = false,
    }
    debts[key] = debt
    SyncMusicboxEffectFromDebt(player, debt)
    presentation.EnsureVisual(player, debt.timer)
    if source == "use" then
        presentation.SpawnShadowGuardianVisual(player)
    end
    SaveMusicboxData()

    RefreshMusicboxPlayerCache(player)

    if not wasActive then
        StartMusicboxMusic()
    else
        KeepMusicboxMusic()
    end

    if source == "panic" then
        presentation.SpawnPanicVisual(player)
    end

    return true
end

function Neverbirth:UseMusicbox(_, _, player)
    if not running or disposed or not player then
        return false
    end

    return StartMusicboxEffect(player, "use")
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseMusicbox, Items.Musicbox)

local function DamageEnemiesWithPlanC(player)
    local source = EntityRef(player)
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if entity and entity.IsVulnerableEnemy and entity:IsVulnerableEnemy() and entity.TakeDamage then
            entity:TakeDamage(MUSICBOX_PLAN_C_DAMAGE, 0, source, 0)
        end
    end
end

local function RemoveInterceptedPlanC(player, activeSlot)
    if player and player.RemoveCollectible then
        player:RemoveCollectible(PLAN_C_ID, false, activeSlot or ActiveSlot.SLOT_PRIMARY, true)
    end
end

function Neverbirth:InterceptPlanC(collectibleId, _, player, _, activeSlot)
    if not running or disposed or collectibleId ~= PLAN_C_ID or not PlayerHasMusicbox(player) then
        return nil
    end

    DamageEnemiesWithPlanC(player)
    RemoveInterceptedPlanC(player, activeSlot)

    if not IsMusicboxActiveForPlayer(player) then
        musicboxPlanCDeaths[player.InitSeed] = {
            timer = MUSICBOX_PLAN_C_DELAY,
            player = player,
        }
    end

    return true
end

Neverbirth:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, Neverbirth.InterceptPlanC, PLAN_C_ID)

local function UpdateMusicboxPlanCDeaths()
    for seed, effect in pairs(musicboxPlanCDeaths) do
        local player = effect.player
        if player and IsMusicboxActiveForPlayer(player) then
            musicboxPlanCDeaths[seed] = nil
        elseif player then
            effect.timer = effect.timer - 1
            if effect.timer <= 0 then
                musicboxPlanCDeaths[seed] = nil
                ForcePlanCDeath(player)
            end
        end
    end
end

function Neverbirth:UpdateMusicbox()
    if not running or disposed then return end
    UpdateMusicboxPlanCDeaths()

    local hasActiveAfterUpdate = false
    local changed = false
    local debts = GetMusicboxDebtTable()
    local runSeed = GetCurrentRunSeed()

    for key, debt in pairs(debts) do
        if not Core.MatchesRun(debt, runSeed) then
            debts[key] = nil
            changed = true
        else
            local player = FindPlayerByMusicboxDebt(debt)
            local timer = tonumber(debt.timer) or 0

            if player then
                if timer > 0 then
                    timer = Core.NextTimer(timer, true)
                    debt.timer = timer
                    changed = true
                end

                if timer <= 0 then
                    ForceMusicboxDeath(key, debt, player)
                    changed = true
                else
                    SyncMusicboxEffectFromDebt(player, debt)
                    hasActiveAfterUpdate = true
                end
            elseif timer <= 0 and debt.expired then
                changed = true
            end
        end
    end

    if changed then
        SaveMusicboxData()
    end

    if hasActiveAfterUpdate then
        KeepMusicboxMusic()
    else
        StopMusicboxMusic()
    end

    presentation.UpdateVisuals()
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateMusicbox)

presentation.InstallRender()

function Neverbirth:EvaluateMusicbox(player, cacheFlag)
    if not running or disposed then return end
    local debt = GetCurrentMusicboxDebt(player)
    local effect = musicboxEffects[player.InitSeed]

    if not effect and not (debt and (tonumber(debt.timer) or 0) > 0) then
        return
    end

    if cacheFlag == CacheFlag.CACHE_TEARCOLOR then
        player.TearColor = MUSICBOX_TEAR_COLOR
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateMusicbox)

local function IsMusicboxSlotUncharged(player, slot)
    if player.GetActiveCharge then
        local ok, charge = pcall(function()
            return player:GetActiveCharge(slot)
        end)
        if ok and charge ~= nil then
            return charge < MUSICBOX_MAX_CHARGE
        end
    end

    if player.NeedsCharge then
        local ok, needsCharge = pcall(function()
            return player:NeedsCharge(slot)
        end)
        if ok and needsCharge ~= nil then
            return needsCharge
        end
    end

    return false
end

local function FindUnchargedMusicboxSlot(player)
    if not player.GetActiveItem then
        return nil
    end

    for _, slot in ipairs(MUSICBOX_ACTIVE_SLOTS) do
        if player:GetActiveItem(slot) == Items.Musicbox and IsMusicboxSlotUncharged(player, slot) then
            return slot
        end
    end

    return nil
end

local function TryTriggerPanicMusicbox(player, amount)
    if GetCurrentMusicboxDebt(player) then
        return false
    end

    if not IsIncomingDamageLethal(player, amount) then
        return false
    end

    local slot = FindUnchargedMusicboxSlot(player)
    if slot == nil then
        return false
    end

    if player.RemoveCollectible then
        pcall(function()
            player:RemoveCollectible(Items.Musicbox, false, slot, true)
        end)
    end

    StartMusicboxEffect(player, "panic")
    return true
end

-- Already-active invulnerability must precede native Holy Mantle/other shields.
-- Do NOT start panic here: this early hook has not seen ACE/ring damage modifiers.
function Neverbirth:PreventActiveMusicboxDamage(player)
    if not running or disposed or not player then
        return nil
    end

    local debt = GetCurrentMusicboxDebt(player)
    if debt and (tonumber(debt.timer) or 0) > 0 then
        SyncMusicboxEffectFromDebt(player, debt)
        return false
    end

    if musicboxEffects[player.InitSeed] then
        return false
    end

    return nil
end

Neverbirth:AddCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG, Neverbirth.PreventActiveMusicboxDamage)

function Neverbirth:PreventMusicboxDamage(entity, amount)
    if not running or disposed then return nil end
    local player = entity and entity.ToPlayer and entity:ToPlayer()
    if not player then
        return nil
    end

    if self:PreventActiveMusicboxDamage(player) == false then
        return false
    end

    if TryTriggerPanicMusicbox(player, amount) then
        return false
    end

    return nil
end

Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.PreventMusicboxDamage)

local function ClearMusicboxRuntime()
    -- Presentation holds this map by reference: clear in place, never rebind it.
    for key in pairs(musicboxEffects) do musicboxEffects[key] = nil end
    for key in pairs(musicboxPlanCDeaths) do musicboxPlanCDeaths[key] = nil end
    presentation.Reset()
end

function Neverbirth:StartMusicboxRun(continued)
    if disposed then return end
    running = false
    ClearMusicboxRuntime()
    local debts = GetMusicboxDebtTable()
    if not continued then
        -- A new run is distinct even when its start seed and player seed repeat.
        for key in pairs(debts) do debts[key] = nil end
        SaveMusicboxData()
    end
    running = true
    local runSeed = continued and GetCurrentRunSeed()
    for _, player in ipairs(GetPlayers()) do
        if continued then
            local debt = debts[GetPlayerMusicboxKey(player)]
            if Core.MatchesRun(debt, runSeed) and (tonumber(debt.timer) or 0) > 0 then
                SyncMusicboxEffectFromDebt(player, debt)
                presentation.EnsureVisual(player, debt.timer)
            end
        end
        -- Player initialization may evaluate caches before GAME_STARTED clears old debt.
        RefreshMusicboxPlayerCache(player)
    end
    if HasActiveMusicboxEffect() then StartMusicboxMusic() end
end
function callbackInstallers.Neverbirth_StartMusicboxRun()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.StartMusicboxRun)
end

function Neverbirth:ExitMusicbox()
    if disposed then return end
    running = false
    -- Debt is already persisted on use/update; teardown must neither reload nor erase it.
    ClearMusicboxRuntime()
end
function callbackInstallers.Neverbirth_ExitMusicbox()
    return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, Neverbirth.ExitMusicbox)
end

function Neverbirth:UnloadMusicbox(unloaded)
    if unloaded ~= Neverbirth or disposed then return end
    running, disposed = false, true
    ClearMusicboxRuntime()
end
function callbackInstallers.Neverbirth_UnloadMusicbox()
    return Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, Neverbirth.UnloadMusicbox)
end

callbackInstallers.Neverbirth_StartMusicboxRun()
callbackInstallers.Neverbirth_ExitMusicbox()
callbackInstallers.Neverbirth_UnloadMusicbox()

return { IsActive = IsMusicboxActiveForPlayer }
end
