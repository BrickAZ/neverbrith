-- Item-owned constants; consumers treat this table as read-only.
local Rules = {}
Rules.COIN_SWORD_MAX_SPEND = 6
Rules.COIN_SWORD_NORMAL_DAMAGE_MULT = 2.0
Rules.COIN_SWORD_EMPOWERED_DAMAGE_MULT = 6.0
Rules.COIN_SWORD_BLOOD_DAMAGE_MULT = 4.0
Rules.COIN_SWORD_SPEED = 12
Rules.COIN_SWORD_LIFE = 18
Rules.COIN_SWORD_MODE_CONFIGS = {
        normal = { length = 76, width = 64, back = 48, scatter = 75, scale = 1, spawnOffset = 28 },
        blood = { length = 84, width = 72, back = 52, scatter = 0, scale = 1, spawnOffset = 28 },
        empowered = { length = 144, width = 64, back = 56, scale = 1.45, spawnOffset = 54 },
    }
Rules.COIN_SWORD_DISAPPEAR_LIFE = 4
Rules.COIN_SWORD_BACKLASH_FLAGS = (DamageFlag and DamageFlag.DAMAGE_RED_HEARTS) or 0
Rules.COIN_SWORD_DAMAGE_FLAGS = (DamageFlag and DamageFlag.DAMAGE_NO_MODIFIERS) or 0
Rules.COIN_SWORD_ENTITY_EFFECT = (EntityType and EntityType.ENTITY_EFFECT) or 1000
Rules.COIN_SWORD_FALLBACK_EFFECT = (EffectVariant and EffectVariant.POOF01) or 1
Rules.COIN_SWORD_NO_DISCHARGE_RESULT = { Discharge = false, Remove = false, ShowAnim = true }

return Rules
