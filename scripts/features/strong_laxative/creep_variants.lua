return {
    EffectVariant.PLAYER_CREEP_HOLYWATER_TRAIL,
    (EffectVariant and (EffectVariant.PLAYER_CREEP_GREEN or EffectVariant.CREEP_GREEN or EffectVariant.PLAYER_CREEP_BLACK or EffectVariant.CREEP_RED or EffectVariant.POOF01)) or 1,
    EffectVariant and EffectVariant.PLAYER_CREEP_GREEN,
    EffectVariant and EffectVariant.CREEP_GREEN,
    EffectVariant and EffectVariant.PLAYER_CREEP_BLACK,
    EffectVariant and EffectVariant.CREEP_RED,
}
