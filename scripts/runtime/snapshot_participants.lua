-- One registry per acquisition service. The owner controls validation, shared
-- state replacement, transient cleanup and Save; this registry owns participants.
return function(clone)
    local participants = {}
    local api = {}
    function api.Register(name, capture, restore)
        assert(not participants[name], 'duplicate snapshot participant '..name)
        participants[name] = { capture=capture, restore=restore }
    end
    function api.Capture()
        local values = {}
        for name, p in pairs(participants) do values[name] = clone(p.capture()) end
        return values
    end
    function api.Restore(values)
        for name, p in pairs(participants) do p.restore(clone(values[name])) end
    end
    return api
end
