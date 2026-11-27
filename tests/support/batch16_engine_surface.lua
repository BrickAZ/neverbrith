-- Extra constants required to actually install all three items in the full-main fixture.
-- Only registration is modeled here; behavior remains in the dedicated engine doubles.
return function()
    local names={'MC_PRE_PLAYER_ADD_HEARTS','MC_POST_PLAYER_ADD_HEARTS',
        'MC_POST_GRID_ENTITY_DOOR_UPDATE','MC_PRE_LASER_COLLISION','MC_POST_LASER_COLLISION',
        'MC_PRE_KNIFE_COLLISION','MC_POST_KNIFE_COLLISION','MC_POST_FIRE_TEAR','MC_POST_GAME_END'}
    local used={};for _,v in pairs(ModCallbacks)do used[v]=true end
    local id=16000
    for _,name in ipairs(names) do
        if ModCallbacks[name]==nil then
            while used[id]do id=id+1 end
            ModCallbacks[name]=id;used[id]=true
        end
    end
    CacheFlag.CACHE_RANGE=CacheFlag.CACHE_RANGE or 2048
    TearFlags.TEAR_PIERCING=TearFlags.TEAR_PIERCING or 2
    TearFlags.TEAR_SPECTRAL=TearFlags.TEAR_SPECTRAL or 4
    AddHealthType={RED=1,SOUL=2,BLACK=4,ETERNAL=8,BONE=16,ROTTEN=32}
    for i,name in ipairs({'DAMAGE_POISON_BURN','DAMAGE_FIRE','DAMAGE_ACID','DAMAGE_FAKE','DAMAGE_BOOGER','DAMAGE_CLONES'}) do
        DamageFlag[name]=DamageFlag[name] or (1 << (i+8))
    end
    for i,name in ipairs({'ENTITY_SLOTH','ENTITY_LUST','ENTITY_WRATH','ENTITY_GLUTTONY','ENTITY_GREED','ENTITY_ENVY','ENTITY_PRIDE'})do
        EntityType[name]=EntityType[name] or (45+i)
    end
end
