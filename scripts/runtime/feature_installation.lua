-- Entry-owned installation scope. No gameplay dispatch, registry globals or save state.
local Installation = {}

function Installation.Create(mod)
    local history, failed, active = {}, false, false
    local publishedGlobals
    local function snapshot()
        local values = {}
        for key, value in pairs(mod) do values[key] = value end
        return values
    end
    local function changes(before)
        local result, seen = {}, {}
        for key, value in pairs(mod) do
            seen[key] = true
            if before[key] ~= value then result[#result + 1] = { key = key, before = before[key], after = value } end
        end
        for key, value in pairs(before) do
            if not seen[key] then result[#result + 1] = { key = key, before = value } end
        end
        return result
    end
    local function rollback()
        local errors = {}
        for i = #history, 1, -1 do
            local entry = history[i]
            for j = #entry.callbacks, 1, -1 do
                local callback = entry.callbacks[j]
                local ok, err = pcall(function() mod:RemoveCallback(callback.event, callback.fn) end)
                if not ok then errors[#errors + 1] = tostring(err) end
            end
            for _, change in ipairs(entry.exports) do
                -- Do not overwrite an unrelated later replacement of an exported field.
                if rawget(mod, change.key) == change.after then rawset(mod, change.key, change.before) end
            end
            for j = #(entry.globals or {}), 1, -1 do
                local change = entry.globals[j]
                if rawget(_G, change.key) == change.after then rawset(_G, change.key, change.before) end
            end
        end
        history = {}
        return errors
    end
    local service = {}
    function service.PublishGlobal(name, value)
        assert(active, 'global compatibility exports require an active installation scope')
        publishedGlobals[#publishedGlobals + 1] = { key = name, before = rawget(_G, name), after = value }
        rawset(_G, name, value)
    end
    function service.Run(name, install)
        assert(not failed, 'feature installation batch failed; start a fresh bootstrap')
        assert(type(install) == 'function', 'feature installer must be a function')
        -- Child phases share the enclosing transaction's callback/export ledger.
        -- A child failure propagates to the outer owner, which performs one rollback.
        if active then
            local result = table.pack(pcall(install))
            if not result[1] then error('[neverbirth] Failed to install ' .. tostring(name) .. ': ' .. tostring(result[2]), 0) end
            return table.unpack(result, 2, result.n)
        end
        active = true
        publishedGlobals = {}
        local before, callbacks = snapshot(), {}
        local rawAdd, rawPriority = rawget(mod, 'AddCallback'), rawget(mod, 'AddPriorityCallback')
        local add, priority = mod.AddCallback, mod.AddPriorityCallback
        local forwarding = false
        mod.AddCallback = function(self, event, fn, param)
            if self ~= mod then return add(self, event, fn, param) end
            if not forwarding then callbacks[#callbacks + 1] = { event = event, fn = fn } end
            -- Native/test AddCallback may delegate to AddPriorityCallback; record once.
            local previous = forwarding
            forwarding = true
            local value = add(self, event, fn, param)
            forwarding = previous
            return value
        end
        mod.AddPriorityCallback = function(self, event, order, fn, param)
            if self == mod and not forwarding then callbacks[#callbacks + 1] = { event = event, fn = fn } end
            return priority(self, event, order, fn, param)
        end
        local outcome = table.pack(pcall(install))
        rawset(mod, 'AddCallback', rawAdd)
        rawset(mod, 'AddPriorityCallback', rawPriority)
        active = false
        history[#history + 1] = { callbacks = callbacks, exports = changes(before), globals = publishedGlobals }
        publishedGlobals = nil
        if not outcome[1] then
            failed = true
            local cleanupErrors = rollback()
            local message = '[neverbirth] Failed to install ' .. tostring(name) .. ': ' .. tostring(outcome[2])
            if #cleanupErrors > 0 then message = message .. '; callback cleanup failed: ' .. table.concat(cleanupErrors, '; ') end
            error(message, 0)
        end
        return table.unpack(outcome, 2, outcome.n)
    end
    return service
end

return Installation
