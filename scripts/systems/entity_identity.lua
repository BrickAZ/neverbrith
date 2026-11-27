-- Transient pointer + spawn-seed identity. No caching, callbacks or saved identity.
-- Accepts a live entity-like object; returns the legacy string key. Native errors propagate.
return function(entity)
    return (GetPtrHash and tostring(GetPtrHash(entity)) or tostring(entity))..':'..tostring(entity.InitSeed or 0)
end
