-- Source contracts follow the real static include chain after a module split.
-- This does not execute code or prove that a conditional include runs.
return function(path)
    local seen, chunks = {}, {}
    local function visit(file)
        if seen[file] then return end
        seen[file] = true
        local handle = assert(io.open(file, 'rb'), file)
        local source = handle:read('*a'); handle:close()
        chunks[#chunks + 1] = source
        for name in source:gmatch('include%s*%(%s*"([%w_%.]+)"%s*%)') do
            visit(name:gsub('%.', '/') .. '.lua')
        end
    end
    visit(path)
    return table.concat(chunks, '\n')
end
