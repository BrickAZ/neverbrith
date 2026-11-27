-- Item-owned implementation; the entry owns callback installation.
return function(Neverbirth, dependencies)
local Items = assert(dependencies.Items)

local function GetCondomCollectibleName(self, itemId)
    local translations = self.PickupBannerTexts[itemId]
    local translated = translations and (translations[self:GetRuntimeLocale()] or translations.en_us)
    if translated and translated.name then
        return translated.name
    end

    local config = self:GetCollectibleConfig(itemId)
    local name = config and config.Name
    if type(name) == "string" and name ~= "" then
        if name:sub(1, 1) ~= "#" then
            return name
        end
        if Isaac.GetString then
            local localized = Isaac.GetString("Items", name:sub(2))
            if type(localized) == "string" and localized ~= "" and localized ~= name
                and localized ~= name:sub(2) then
                return localized
            end
        end
    end
    return self:GetRuntimeText("condomUnknownItem")
end

local function ShowCondomFeedback(self, bannedItems)
    local game = Game()
    local hud = game and game.GetHUD and game:GetHUD()
    if not hud or not hud.ShowItemText then
        return
    end

    local title = self:GetRuntimeText("condomTitle")
    if #bannedItems > 0 then
        local names = {}
        for _, itemId in ipairs(bannedItems) do
            names[#names + 1] = GetCondomCollectibleName(self, itemId)
        end
        hud:ShowItemText(title, self:FormatRuntimeText("condomBanned", {
            items = table.concat(names, self:GetRuntimeText("condomNameSeparator")),
        }))
    else
        hud:ShowItemText(title, self:GetRuntimeText("condomEmpty"))
    end
end

return { ShowFeedback = function(items) return ShowCondomFeedback(Neverbirth, items) end }
end
