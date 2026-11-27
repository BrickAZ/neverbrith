-- Copies values in an acyclic data tree; keys and non-table leaves are retained.
-- No state, registration, validation, RNG or persistence side effects.
local function copyTree(value)
    if type(value) ~= 'table' then return value end
    local result = {}
    for key, child in pairs(value) do result[key] = copyTree(child) end
    return result
end

return { CopyTree = copyTree }
