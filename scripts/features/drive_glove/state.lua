-- Owns saved-record lookup and this installation's transient player records.
return function(context, C, ID)
    local runtime, ready = {}, false
    local key = assert(context.Key, 'Drive Glove requires an inventory player key')
    local api = {Key=key, Players=context.GetPlayers}
    function api.IsHeld(p) return p:HasCollectible(ID) end
    function api.Data(p)
        return C.Record(context.GetSaveRoot(),context.GetCurrentRunSeed(),key(p),api.IsHeld(p))
    end
    function api.Get(p)
        local k=key(p)
        if not runtime[k] then runtime[k]=C.Runtime(); runtime[k].player=p end
        return runtime[k]
    end
    function api.Peek(p) return runtime[key(p)] end
    function api.All() return runtime end
    function api.IsReady() return ready end
    function api.Reset(active) runtime={}; ready=active end
    function api.Save()
        if context.Save then context.Save() end
        for _,t in pairs(runtime) do t.saveDirty=false end
    end
    function api.PeekVisual(p)
        local saved=context.GetSaveRoot().driveGlove
        local k=key(p)
        return saved and saved.players[k],runtime[k]
    end
    function api.ClearSaved() context.GetSaveRoot().driveGlove=nil end
    return api
end
