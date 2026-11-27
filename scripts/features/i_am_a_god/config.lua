-- Item policy constants; no callbacks or runtime state.
    local DURATION, OVERLOAD = 180, 121
    local CACHE = CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SPEED | CacheFlag.CACHE_RANGE
        | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_TEARFLAG
    local TEARS = TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL
    local NO_USE = { Discharge=false, Remove=false, ShowAnim=false }
    local VISUALS = {
        Crown = "gfx/Effects/IAmAGod/IAmAGodCrown.anm2",
        Success = "gfx/Effects/IAmAGod/IAmAGodSuccessBurst.anm2",
        Fail = "gfx/Effects/IAmAGod/IAmAGodFailShatter.anm2",
    }

    local HEALTH = {
        {key="bone",get="GetBoneHearts",add="AddBoneHearts"},
        {key="rotten",get="GetRottenHearts",add="AddRottenHearts"},
        {key="red",get="GetHearts",add="AddHearts"},
        -- GetSoulHearts includes black hearts; do not count/subtract them twice.
        {key="soul",get="GetSoulHearts",add="AddSoulHearts"},
        {key="eternal",get="GetEternalHearts",add="AddEternalHearts"},
    }
    local BLOCK_HEALTH = AddHealthType.RED | AddHealthType.SOUL | AddHealthType.BLACK
        | AddHealthType.ETERNAL | AddHealthType.BONE | AddHealthType.ROTTEN

return {
    DURATION = DURATION,
    OVERLOAD = OVERLOAD,
    CACHE = CACHE,
    TEARS = TEARS,
    NO_USE = NO_USE,
    VISUALS = VISUALS,
    HEALTH = HEALTH,
    BLOCK_HEALTH = BLOCK_HEALTH,
}
