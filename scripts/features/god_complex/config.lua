-- Item policy constants; no callbacks or runtime state.
    local CACHE=CacheFlag.CACHE_DAMAGE|CacheFlag.CACHE_FIREDELAY|CacheFlag.CACHE_SPEED|CacheFlag.CACHE_TEARFLAG
    local INDIRECT=DamageFlag.DAMAGE_POISON_BURN|DamageFlag.DAMAGE_FIRE|DamageFlag.DAMAGE_ACID|DamageFlag.DAMAGE_FAKE
        |DamageFlag.DAMAGE_BOOGER|DamageFlag.DAMAGE_CLONES
    local NO_USE={Discharge=false,Remove=false,ShowAnim=false}
    local FORMS={'Solar','War','Eye'}
    local ROOT='gfx/Effects/GodComplex/'
    local SOLAR_DAMAGE_RADIUS=95
    -- Alpha bounds in each 64x64 SolarHalo crop; right/bottom are exclusive.
    -- The PNG/ANM2 resource test verifies these and the 3-tick frame duration.
    local SOLAR_HALO_BOUNDS={
        {6,14,57,51},{5,13,58,52},{3,12,60,53},{2,11,61,54},
        {3,12,60,53},{4,13,59,52},{6,14,57,51},{7,15,56,50},
    }

return {
    CACHE = CACHE,
    INDIRECT = INDIRECT,
    NO_USE = NO_USE,
    FORMS = FORMS,
    ROOT = ROOT,
    SOLAR_DAMAGE_RADIUS = SOLAR_DAMAGE_RADIUS,
    SOLAR_HALO_BOUNDS = SOLAR_HALO_BOUNDS,
}
