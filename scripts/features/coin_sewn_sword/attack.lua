-- Settlement happens once, at release, using the current wallet and original slot.
return function(Neverbirth, dependencies)
    local GetPlayerCoins = dependencies.World.GetPlayerCoins
    local AddPlayerCoins = dependencies.World.AddPlayerCoins
    local SpawnFolkEffect = dependencies.World.SpawnFolkEffect
    local GetCoinSwordBaseDirection = dependencies.Aiming.GetBaseDirection
    local SpawnCoinSwordQi = dependencies.SpawnQi
    local FOLK_RED_CREEP = (EffectVariant and (EffectVariant.CREEP_RED or EffectVariant.POOF01)) or 1
    local COIN_SWORD_MAX_SPEND = dependencies.Rules.COIN_SWORD_MAX_SPEND
    local COIN_SWORD_NORMAL_DAMAGE_MULT = dependencies.Rules.COIN_SWORD_NORMAL_DAMAGE_MULT
    local COIN_SWORD_EMPOWERED_DAMAGE_MULT = dependencies.Rules.COIN_SWORD_EMPOWERED_DAMAGE_MULT
    local COIN_SWORD_BLOOD_DAMAGE_MULT = dependencies.Rules.COIN_SWORD_BLOOD_DAMAGE_MULT
    local COIN_SWORD_BACKLASH_FLAGS = dependencies.Rules.COIN_SWORD_BACKLASH_FLAGS
    local COIN_SWORD_MODE_CONFIGS = dependencies.Rules.COIN_SWORD_MODE_CONFIGS
    local function RotateVector(vector, degrees)
        local radians = (degrees or 0) * math.pi / 180
        local cosValue = math.cos(radians)
        local sinValue = math.sin(radians)
        return Vector(vector.X * cosValue - vector.Y * sinValue, vector.X * sinValue + vector.Y * cosValue)
    end

    local function DischargeCoinSewnSword(player, slot)
        if player and player.DischargeActiveItem then
            pcall(function()
                player:DischargeActiveItem(slot or (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0)
            end)
        end
    end

    local function FireCoinSewnSword(player, direction, slot)
        if Neverbirth.AvadaKedavra and Neverbirth.AvadaKedavra.OwnsAttack(player) then return false end
        if not player then
            return false
        end

        local baseDirection = (direction and direction:Length() > 0) and direction:Normalized() or GetCoinSwordBaseDirection(player)
        local coins = GetPlayerCoins(player)
        if coins <= 0 then
            if player.TakeDamage then
                player:TakeDamage(1, COIN_SWORD_BACKLASH_FLAGS, EntityRef(player), 0)
            end
            SpawnFolkEffect(FOLK_RED_CREEP, player.Position, player)
            SpawnCoinSwordQi(player, COIN_SWORD_BLOOD_DAMAGE_MULT, "blood", baseDirection)
            DischargeCoinSewnSword(player, slot)
            return true
        end

        local spent = math.min(coins, COIN_SWORD_MAX_SPEND)
        AddPlayerCoins(player, -spent)
        for index = 1, spent do
            local angle = 0
            if spent > 1 then
                angle = -COIN_SWORD_MODE_CONFIGS.normal.scatter + ((index - 1) * COIN_SWORD_MODE_CONFIGS.normal.scatter * 2 / (spent - 1))
            end
            local forwardOffset = (index - 1) * 3
            SpawnCoinSwordQi(player, COIN_SWORD_NORMAL_DAMAGE_MULT, "normal", RotateVector(baseDirection, angle), forwardOffset)
        end
        if spent >= COIN_SWORD_MAX_SPEND then
            SpawnCoinSwordQi(player, COIN_SWORD_EMPOWERED_DAMAGE_MULT, "empowered", baseDirection)
        end

        DischargeCoinSewnSword(player, slot)
        return true
    end

    return { Fire = FireCoinSewnSword }
end
