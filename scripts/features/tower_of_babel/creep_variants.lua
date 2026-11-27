-- Tower owns its broader removal policy; the injected list retains Laxative's separate scope.
return function(CreepVariants)
    local TowerOfBabelConfig = { CreepVariants = {} }
    local function AddTowerOfBabelCreepVariant(variant)
        if type(variant) ~= "number" then
            return
        end

        for _, existing in ipairs(TowerOfBabelConfig.CreepVariants) do
            if existing == variant then
                return
            end
        end

        TowerOfBabelConfig.CreepVariants[#TowerOfBabelConfig.CreepVariants + 1] = variant
    end

    for _, variant in ipairs(CreepVariants) do
        AddTowerOfBabelCreepVariant(variant)
    end

    if EffectVariant then
        for _, variant in ipairs({
            EffectVariant.CREEP_RED,
            EffectVariant.CREEP_GREEN,
            EffectVariant.CREEP_BLACK,
            EffectVariant.CREEP_WHITE,
            EffectVariant.CREEP_YELLOW,
            EffectVariant.PLAYER_CREEP_RED,
            EffectVariant.PLAYER_CREEP_GREEN,
            EffectVariant.PLAYER_CREEP_BLACK,
            EffectVariant.PLAYER_CREEP_WHITE,
            EffectVariant.PLAYER_CREEP_HOLYWATER,
            EffectVariant.PLAYER_CREEP_HOLYWATER_TRAIL,
            EffectVariant.PLAYER_CREEP_LEMON_MISHAP,
            EffectVariant.PLAYER_CREEP_LEMON_PARTY,
            EffectVariant.PLAYER_CREEP_PUDDLE_MILK,
            EffectVariant.CREEP_SLIPPERY_BROWN,
        }) do
            AddTowerOfBabelCreepVariant(variant)
        end
    end

    return TowerOfBabelConfig.CreepVariants
end
