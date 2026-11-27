-- Facts about a source; no acceptance, health loss, attribution policy or damage.
local Source = {}
function Source.Entity(source)
    if source and source.Entity then return source.Entity end
    return source
end
function Source.TryPlayer(entity)
    if entity and entity.ToPlayer then
        local ok, player = pcall(function() return entity:ToPlayer() end)
        if ok and player then return player end
    end
    return nil
end
return Source
