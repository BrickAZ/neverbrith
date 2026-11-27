-- Compose owner declarations in the existing first-load initialization order.
-- No feature imports, game access, callbacks or saved format version are owned here.
-- compose({{Name=field, Initialize=function(region) ... end}, ...}) -> initialize(root)
return function(schemas)
    assert(type(schemas) == 'table', 'save schemas require an ordered array of owner declarations')
    local count = 0
    for index in pairs(schemas) do
        assert(type(index) == 'number' and index >= 1 and index % 1 == 0,
            'save schemas require an ordered array of owner declarations')
        count = count + 1
    end
    assert(count > 0, 'save schemas require at least one owner declaration')
    local ordered, names = {}, {}
    for index = 1, count do
        local schema = schemas[index]
        assert(type(schema) == 'table', 'save schema declaration is missing at index '..index)
        local name, initialize = schema.Name, schema.Initialize
        assert(type(name) == 'string' and name ~= '', 'save schema requires an owned region name')
        assert(not names[name], 'duplicate save schema region: '..name)
        assert(initialize == nil or type(initialize) == 'function',
            'save schema initializer must be a function: '..name)
        names[name] = true
        ordered[index] = { name=name, initialize=initialize }
    end
    return function(root)
        for _, schema in ipairs(ordered) do
            local region = root[schema.name]
            if type(region) ~= 'table' then
                region = {}
                root[schema.name] = region
            end
            if schema.initialize then schema.initialize(region) end
        end
    end
end
