-- Owns the complete Chunyao feature; installed at its original callback position.
return function(Neverbirth, dependencies)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local Items = { Chunyao = assert(dependencies.ItemId) }
    local GetPlayers = assert(dependencies.GetPlayers)

local chunyaoEffects = {}
local running, disposed = true, false

function Neverbirth:UseChunyao(_, _, player, _, activeSlot)
    if not running or disposed or not player then return false end
    local slot = activeSlot or ((ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0)
    if slot < 0 then slot = (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0 end
    -- SLOT_POCKET2 is the engine's single-use pocket: it has no charge bar.
    -- Require the actual item there; a scripted empty-slot call is not a use.
    local singleUsePocket = slot == ((ActiveSlot and ActiveSlot.SLOT_POCKET2) or 3)
        and player.GetActiveItem and player:GetActiveItem(slot) == Items.Chunyao
    if not singleUsePocket and player:GetActiveCharge(slot) < 1 then
        return false
    end

    player:DischargeActiveItem(slot)
    player:TakeDamage(
        1,
        DamageFlag.DAMAGE_RED_HEARTS | DamageFlag.DAMAGE_NOKILL | DamageFlag.DAMAGE_INVINCIBLE,
        EntityRef(player),
        0
    )

    local effects = chunyaoEffects[player.InitSeed] or {}
    effects[#effects + 1] = {
        damageBonus = 0.5,
        fireRateBonus = 0.5,
        timer = 90,
    }
    chunyaoEffects[player.InitSeed] = effects

    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_TEARCOLOR | CacheFlag.CACHE_TEARFLAG)
    player:EvaluateItems()

    player:AddEntityFlags(EntityFlag.FLAG_CHARM)
    player.TearColor = Color(1, 0, 1, 1, 0, 0, 0)
    player.TearFlags = player.TearFlags | TearFlags.TEAR_HOMING

    return true
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseChunyao, Items.Chunyao)

function Neverbirth:UpdateChunyaoEffects()
    if not running or disposed then return end
    for _, player in ipairs(GetPlayers()) do
        if player then
            local effects = chunyaoEffects[player.InitSeed]

            if effects then
                local changed = false
                for i = #effects, 1, -1 do
                    effects[i].timer = effects[i].timer - 1

                    if effects[i].timer <= 0 then
                        table.remove(effects, i)
                        changed = true
                    end
                end

                if #effects == 0 then
                    chunyaoEffects[player.InitSeed] = nil
                    player:ClearEntityFlags(EntityFlag.FLAG_CHARM)
                    player.TearColor = Color.Default
                    player.TearFlags = player.TearFlags & ~TearFlags.TEAR_HOMING
                end

                if changed then
                    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_TEARCOLOR | CacheFlag.CACHE_TEARFLAG)
                    player:EvaluateItems()
                end
            end
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateChunyaoEffects)

function Neverbirth:EvaluateChunyao(player, cacheFlag)
    if not running or disposed then return end
    local effects = chunyaoEffects[player.InitSeed]
    if not effects then
        return
    end

    local totalDamageBonus = 0
    local totalFireRateBonus = 0

    for _, effect in ipairs(effects) do
        totalDamageBonus = totalDamageBonus + effect.damageBonus
        totalFireRateBonus = totalFireRateBonus + effect.fireRateBonus
    end

    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        player.Damage = player.Damage + totalDamageBonus
    elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
        player.MaxFireDelay = player.MaxFireDelay - totalFireRateBonus
    elseif cacheFlag == CacheFlag.CACHE_TEARCOLOR then
        player.TearColor = Color(1, 0, 1, 1, 0, 0, 0)
    elseif cacheFlag == CacheFlag.CACHE_TEARFLAG then
        player.TearFlags = player.TearFlags | TearFlags.TEAR_HOMING
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateChunyao)

function Neverbirth:ResetChunyaoState(isContinued)
    if disposed then return end
    local previous = chunyaoEffects
    if not isContinued then chunyaoEffects = {} end
    running = true
    for _, player in ipairs(GetPlayers()) do
        if previous[player.InitSeed] then
            if isContinued then
                player:AddEntityFlags(EntityFlag.FLAG_CHARM)
            else
                player:ClearEntityFlags(EntityFlag.FLAG_CHARM)
                player.TearFlags = player.TearFlags & ~TearFlags.TEAR_HOMING
            end
            player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_TEARCOLOR | CacheFlag.CACHE_TEARFLAG)
            player:EvaluateItems()
        end
    end
end
function callbackInstallers.Neverbirth_ResetChunyaoState()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetChunyaoState)
end

function Neverbirth:ExitChunyao()
    running = false -- Keep only plain timers for the existing same-instance continue policy.
end
function callbackInstallers.Neverbirth_ExitChunyao()
    return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, Neverbirth.ExitChunyao)
end

function Neverbirth:UnloadChunyao(unloaded)
    if unloaded ~= Neverbirth or disposed then return end
    running, disposed, chunyaoEffects = false, true, {}
end
function callbackInstallers.Neverbirth_UnloadChunyao()
    return Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, Neverbirth.UnloadChunyao)
end

callbackInstallers.Neverbirth_ResetChunyaoState()
callbackInstallers.Neverbirth_ExitChunyao()
callbackInstallers.Neverbirth_UnloadChunyao()

end
