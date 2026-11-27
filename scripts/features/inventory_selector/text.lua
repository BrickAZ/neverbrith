return function(mod, context)
    local function itemName(id, fallback)
        local localized = context.EIDDescriptions[id] and context.EIDDescriptions[id][mod:GetRuntimeLocale()]
        if localized and localized.name then return localized.name end
        local config = Isaac.GetItemConfig():GetCollectible(id)
        local name = config and config.Name or fallback
        if type(name) == "string" and name ~= "" then
            if name:sub(1, 1) ~= "#" then return name end
            if Isaac.GetString then
                local translated = Isaac.GetString("Items", name:sub(2))
                if type(translated) == "string" and translated ~= "" and translated ~= name
                    and translated ~= name:sub(2) then return translated end
            end
        end
        return mod:GetRuntimeLocale() == "zh_cn" and "未知道具" or "Unknown item"
    end
    local function renderText(text,x,y,r,g,b,a)
        local locale=mod:GetRuntimeLocale()
        local font=mod:GetRuntimeTextFont(locale)
        if font and font.DrawStringUTF8 and type(KColor)=="function" then
            font:DrawStringUTF8(tostring(text),x,y,KColor(r or 1,g or 1,b or 1,a or 1),0,false)
        elseif Isaac.RenderText then Isaac.RenderText(tostring(text),x,y,r or 1,g or 1,b or 1,a or 1) end
    end
    local function getText(key)
        local text=Options.Language=="zh" and {
            temporary="本层临时",controls="方向选择  菜单确认 / 返回取消",debugTitle="背包选择器 · 调试目标",
        } or {temporary="Temporary",controls="Move: select  Menu: confirm / back",debugTitle="Inventory target debug"}
        return text[key]
    end
    return { ItemName=itemName, RenderText=renderText, GetText=getText }
end
