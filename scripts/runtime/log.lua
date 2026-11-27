local function DebugLog(message)
    if Isaac.DebugString then
        Isaac.DebugString(message)
    elseif print then
        print(message)
    end
end

return DebugLog
