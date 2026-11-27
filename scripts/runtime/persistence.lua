-- One instance per mod installation. This service knows no item rules or IDs.
local Persistence = {}

function Persistence.Create(mod, dependencies)
    local json = assert(dependencies.Json, 'persistence requires JSON')
    local initialize = dependencies.Initialize or function() end
    local log = dependencies.Log or function() end
    local root, loadError
    local state = 'unloaded'
    local service = {}

    function service.GetRoot()
        if state == 'ready' then return root end
        if state == 'failed' then error(loadError, 0) end
        if state == 'loading' then error('persistence: reentrant load before initialization completed', 0) end
        state = 'loading'
        local ok, candidate = pcall(function()
            local data = {}
            if mod.HasData and mod:HasData() then
                data = json.decode(mod:LoadData())
                assert(type(data) == 'table', 'saved root must be a table')
            end
            initialize(data)
            return data
        end)
        if not ok then
            -- Fail closed for this instance. Only a new instance may retry loading;
            -- callers must never receive a writable fallback for unreadable data.
            state = 'failed'
            loadError = '[neverbirth] Failed to load mod data; saving disabled until reload: ' .. tostring(candidate)
            log(loadError)
            error(loadError, 0)
        end
        root, state = candidate, 'ready'
        return root
    end

    function service.Save()
        local loaded, data = pcall(service.GetRoot)
        if not loaded then return false end -- GetRoot owns the one-time load diagnostic.
        if not mod.SaveData then return false end
        local ok, encoded = pcall(function()
            local value = json.encode(data)
            assert(type(value) == 'string', 'JSON encoder must return a string')
            return value
        end)
        if not ok then
            log('[neverbirth] Failed to save mod data: ' .. tostring(encoded))
            return false
        end
        local written, result = pcall(mod.SaveData, mod, encoded)
        if not written or result == false then
            log('[neverbirth] Failed to write mod data: ' .. tostring(result))
            return false
        end
        return true
    end

    function service.Section(name, initializeSection)
        assert(type(name) == 'string' and name ~= '', 'save region requires a name')
        local section = {}
        function section.Get()
            local data = service.GetRoot()
            if type(data[name]) ~= 'table' then data[name] = {} end
            if initializeSection then initializeSection(data[name]) end
            return data[name]
        end
        function section.Replace(value)
            assert(type(value) == 'table', 'save region requires plain table data')
            service.GetRoot()[name] = value
            return value
        end
        section.Save = service.Save
        return section
    end

    -- A compatibility view over explicitly owned legacy root fields. Reading a
    -- missing field does not create it; assigning nil still removes it. The view
    -- always resolves the current root/region rather than retaining old tables.
    -- Never serialize this view: Save writes the real root, including unknown fields.
    function service.Scope(names)
        if type(names) == 'string' then names = { names } end
        assert(type(names) == 'table' and #names > 0, 'save scope requires owned fields')
        local allowed, ordered = {}, {}
        for _, name in ipairs(names) do
            assert(type(name) == 'string' and name ~= '' and not allowed[name],
                'save scope requires unique nonempty field names')
            allowed[name], ordered[#ordered + 1] = true, name
        end
        local function check(name)
            assert(allowed[name], 'save scope does not own field: ' .. tostring(name))
        end
        local view = setmetatable({}, {
            __index = function(_, name)
                check(name)
                return service.GetRoot()[name]
            end,
            __newindex = function(_, name, value)
                check(name)
                service.GetRoot()[name] = value
            end,
            __pairs = function()
                local index = 0
                return function()
                    while index < #ordered do
                        index = index + 1
                        local name = ordered[index]
                        local value = service.GetRoot()[name]
                        if value ~= nil then return name, value end
                    end
                end
            end,
            __metatable = 'owned save fields',
        })
        return {
            GetRoot = function()
                service.GetRoot() -- Preserve eager load/error at the legacy getter boundary.
                return view
            end,
            Save = service.Save,
        }
    end

    return service
end

return Persistence
