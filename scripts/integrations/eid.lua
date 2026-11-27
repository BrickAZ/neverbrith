return function(Neverbirth, dependencies)
local EID_DESCRIPTIONS, EID_LANGUAGE_ORDER = dependencies.Descriptions, dependencies.LanguageOrder
local IsValidItemId, DebugLog = dependencies.IsValidItemId, dependencies.Log
local eidDescriptionsRegistered = false
local failedEID, failedAddCollectible

-- EID:addCollectible replaces descriptions[language].custom["5.100." .. id].
-- Journal only our keys; retain other mods' entries and any pre-existing tables.
local function CaptureDescriptions(eid)
    local originalRoot, languages = eid.descriptions, {}
    for id, item in pairs(EID_DESCRIPTIONS) do
        if IsValidItemId(id) then
            for _, language in ipairs(EID_LANGUAGE_ORDER) do
                if item[language] or item.en_us then
                    local before = languages[language]
                    if not before then
                        local languageTable = originalRoot and originalRoot[language]
                        before = { language = languageTable, custom = languageTable and languageTable.custom, entries = {} }
                        languages[language] = before
                    end
                    local key = "5.100." .. id
                    before.entries[#before.entries + 1] = { key = key, value = before.custom and before.custom[key] }
                end
            end
        end
    end
    return function()
        local descriptions = eid.descriptions
        if not descriptions then return end
        for language, before in pairs(languages) do
            local languageTable = descriptions[language]
            local custom = languageTable and languageTable.custom
            if custom then
                for _, entry in ipairs(before.entries) do custom[entry.key] = entry.value end
                if not before.custom and next(custom) == nil then languageTable.custom = nil end
            end
            if languageTable and not before.language and next(languageTable) == nil then descriptions[language] = nil end
        end
        if not originalRoot and next(descriptions) == nil then eid.descriptions = nil end
    end
end

local function RegisterEIDDescriptions()
    if eidDescriptionsRegistered or not EID or type(EID.addCollectible) ~= "function" then
        return false
    end

    local eid = EID
    -- Missing EID remains retryable. A throwing API is retried only after replacement
    -- or a fresh bootstrap, rather than mutating external state every update.
    if failedEID == eid and failedAddCollectible == eid.addCollectible then return false end
    local restoreDescriptions = CaptureDescriptions(eid)
    local previousMod = eid._currentMod
    if previousMod ~= nil then
        eid._currentMod = "neverbirth"
    end
    local previousIndicator = eid.ModIndicator and eid.ModIndicator.neverbirth
    local installedIndicator
    if eid.ModIndicator and not previousIndicator then
        installedIndicator = { Name = "neverbirth", Icon = nil }
        eid.ModIndicator.neverbirth = installedIndicator
    end

    local ok, err = pcall(function()
        for id, item in pairs(EID_DESCRIPTIONS) do
            if IsValidItemId(id) then
                for _, language in ipairs(EID_LANGUAGE_ORDER) do
                    local localizedText = item[language] or item.en_us
                    if localizedText then
                        eid:addCollectible(id, localizedText.eidDescription, localizedText.name, language)
                    end
                end
            end
        end
    end)

    eid._currentMod = previousMod
    if not ok then
        restoreDescriptions()
        if installedIndicator and eid.ModIndicator.neverbirth == installedIndicator then
            eid.ModIndicator.neverbirth = previousIndicator
        end
        failedEID, failedAddCollectible = eid, eid.addCollectible
        DebugLog("[neverbirth] EID descriptions were not installed: " .. tostring(err))
        return false
    end

    eidDescriptionsRegistered = true
    return true
end

function Neverbirth:TryRegisterEIDDescriptions()
    if RegisterEIDDescriptions() then
        DebugLog("[neverbirth] EID descriptions registered")
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.TryRegisterEIDDescriptions)

return { Publish = RegisterEIDDescriptions }
end
