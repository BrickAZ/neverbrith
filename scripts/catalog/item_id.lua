local function IsValidItemId(id)
    if id == nil then
        return false
    end

    if type(id) == "number" then
        return id > 0
    end

    return true
end

return IsValidItemId
