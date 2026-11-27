-- Strict legacy run-seed comparison and field repair, shared by compatible
-- saved ledgers. New-run policy and saving stay with the owner. Get() always
-- resolves the live section, including after Store.Replace or a continue load.
return function(store, getRunSeed, create, tableFields)
    return function()
        local data = store.Get()
        if type(data) ~= "table" or data.runSeed ~= getRunSeed() then
            data = create()
            store.Replace(data)
        end
        for _, field in ipairs(tableFields) do
            if type(data[field]) ~= "table" then data[field] = {} end
        end
        return data
    end
end
