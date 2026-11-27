return function(Neverbirth)
Neverbirth.RuntimeLocalization = Neverbirth.RuntimeLocalization or {
    defaultLocale = "en_us",
    localeByGameLanguage = {
        zh = "zh_cn",
    },
    fontPaths = {
        zh_cn = "resources-dlc3.zh/font/teammeatfontextended10.fnt",
    },
    texts = {
        en_us = {
            uncutCordDelay = "DELAY",
            uncutCordDebt = "DEBT",
            uncutCordHalfPaid = "HALF PAID",
            uncutCordFullPaid = "FULL PAID",
            blackTaisuiTitle = "Black Taisui",
            blackTaisuiBlock = "TAISUI BLOCK",
            blackTaisuiDeathSaveSubtitle = "Lethal damage blocked",
            condomTitle = "Condom",
            condomBanned = "Banned {items}",
            condomNameSeparator = " and ",
            condomUnknownItem = "Unknown item",
            condomEmpty = "No baby items left",
        },
        zh_cn = {
            uncutCordDelay = "延迟伤害",
            uncutCordDebt = "延迟伤害",
            uncutCordHalfPaid = "一半延迟伤害",
            uncutCordFullPaid = "全部延迟伤害",
            blackTaisuiTitle = "黑太岁",
            blackTaisuiBlock = "挡下致命伤害",
            blackTaisuiDeathSaveSubtitle = "挡下致命伤害",
            condomTitle = "避孕套",
            condomBanned = "禁用了{items}",
            condomNameSeparator = "和",
            condomUnknownItem = "未知道具",
            condomEmpty = "没有剩余宝宝道具",
        },
    },
    fontCache = {},
}

function Neverbirth:GetRuntimeLocale()
    local language = Options and Options.Language
    return self.RuntimeLocalization.localeByGameLanguage[language]
        or self.RuntimeLocalization.defaultLocale
end

function Neverbirth:GetRuntimeText(key, locale)
    locale = locale or self:GetRuntimeLocale()
    local texts = self.RuntimeLocalization.texts
    local localized = texts[locale]
    if localized and localized[key] ~= nil then
        return localized[key]
    end
    local fallback = texts[self.RuntimeLocalization.defaultLocale]
    return (fallback and fallback[key]) or tostring(key or "")
end

function Neverbirth:FormatRuntimeText(key, values, locale)
    local text = self:GetRuntimeText(key, locale)
    return (text:gsub("{([%w_]+)}", function(name)
        local value = values and values[name]
        return value ~= nil and tostring(value) or ("{" .. name .. "}")
    end))
end

function Neverbirth:GetRuntimeTextFont(locale)
    local localization = self.RuntimeLocalization
    local cached = localization.fontCache[locale]
    if cached ~= nil then
        return cached or nil
    end

    localization.fontCache[locale] = false
    local path = localization.fontPaths[locale]
    if not path or type(Font) ~= "function" then
        return nil
    end

    local okFont, font = pcall(Font)
    if not okFont or not font or type(font.Load) ~= "function" then
        return nil
    end
    local okLoad, loaded = pcall(function()
        return font:Load(path)
    end)
    if not okLoad or loaded == false then
        return nil
    end

    localization.fontCache[locale] = font
    return font
end

function Neverbirth:RenderRuntimeText(key, suffix, x, y, r, g, b, a)
    local locale = self:GetRuntimeLocale()
    suffix = suffix or ""
    local text = self:GetRuntimeText(key, locale) .. suffix

    if locale ~= self.RuntimeLocalization.defaultLocale then
        local font = self:GetRuntimeTextFont(locale)
        if font and type(KColor) == "function" then
            local okColor, color = pcall(KColor, r or 1, g or 1, b or 1, a or 1)
            local method = font.DrawStringUTF8 or font.DrawString
            if okColor and color and type(method) == "function" then
                local drawn = pcall(method, font, text, x, y, color, 0, false)
                if drawn then
                    return true
                end
            end
        end
        text = self:GetRuntimeText(key, self.RuntimeLocalization.defaultLocale) .. suffix
    end

    if Isaac and Isaac.RenderText then
        return pcall(Isaac.RenderText, text, x, y, r or 1, g or 1, b or 1, a or 1)
    end
    return false
end

end
