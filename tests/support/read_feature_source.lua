-- Source-contract checks follow the feature's literal includes after extraction.
-- Actual registration and import lifetime are checked by the real-entry fixture.
return function(entry)
    local seen, parts = {}, {}
    local function visit(file)
        if seen[file] then return end
        seen[file] = true
        local handle = assert(io.open(file, "rb"), "missing feature source: " .. file)
        local body = handle:read("*a")
        handle:close()
        parts[#parts + 1] = body
        for module in body:gmatch('include%("([%w_%.]+)"%)') do
            if module:match("^scripts%.") then visit(module:gsub("%.", "/") .. ".lua") end
        end
    end
    visit(entry)
    return table.concat(parts, "\n")
end
