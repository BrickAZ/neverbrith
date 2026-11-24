-- Isolated bootstrap: main.lua is close to Lua's 200-local limit.
return function(mod, context)
    local shared = context
    local state = include("pending_content_state")(mod, shared)
    local function withContext(fields)
        local context = {}; for key,value in pairs(shared) do context[key]=value end
        context.State=state
        for key,value in pairs(fields) do context[key]=value end
        return context
    end
    local notices = {}
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
    include("divine_left_hand")(mod,withContext({ItemId=context.Items.DivineLeftHand,
        OnTemporaryCopy=function(player,id,name)
            notices[state.InventoryPlayerKey(player)]={player=player,name=itemName(id,name),
                expires=Game():GetFrameCount()+90}
        end,
    }))
    local lowGradeId=-1
    if Isaac.GetTrinketIdByName then
        for _,name in ipairs({"Low Grade","零分考卷"})do
            local candidate=Isaac.GetTrinketIdByName(name)
            if candidate and candidate>0 then lowGradeId=candidate;break end
        end
    end
    if lowGradeId>0 then include("low_grade")(mod,withContext({TrinketId=lowGradeId})) end
    local familiarVariant=Isaac.GetEntityVariantByName and Isaac.GetEntityVariantByName("Echo Baby Familiar") or -1
    include("echo_baby")(mod,withContext({ItemId=context.Items.EchoBaby,FamiliarVariant=familiarVariant}))
    include("inventory_selector")(mod,withContext({
        GetEntries=function(player)
            local entries,order={},{}
            local history=player:GetHistory():GetCollectiblesHistory()
            for index,receipt in ipairs(history) do
                if not receipt:IsTrinket() and not order[receipt:GetItemID()] then order[receipt:GetItemID()]=index end
            end
            for id,count in pairs(player:GetCollectiblesList()) do
                if count>0 then
                    local config=Isaac.GetItemConfig():GetCollectible(id)
                    if config then
                        entries[#entries+1]={id=id,count=count,type=config.Type,name=itemName(id),
                            gfx=config.GfxFileName,order=order[id] or (#history+id),
                            temporaryCount=mod.DivineLeftHand and mod.DivineLeftHand.GetTemporaryCount(player,id) or 0}
                    end
                end
            end
            return entries
        end,
        RenderText=renderText,
        GetText=function(key)
            local text=Options.Language=="zh" and {
                temporary="本层临时",controls="方向选择  菜单确认 / 返回取消",debugTitle="背包选择器 · 调试目标",
            } or {temporary="Temporary",controls="Move: select  Menu: confirm / back",debugTitle="Inventory target debug"}
            return text[key]
        end,
    }))
    local eidRegistered=false
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE,function()
        if not eidRegistered and lowGradeId>0 and EID and type(EID.addTrinket)=="function" then
            EID:addTrinket(lowGradeId,"{{Damage}} +5 damage#{{Tears}} +5 tears beyond the normal cap#{{Range}} +5 range#Three consecutive floors with Perfection-valid damage: the third floor's final boss drops one copy#Each physical copy expires after 5 valid hits; dropped, golden and swallowed copies keep durability","Low Grade","en_us")
            EID:addTrinket(lowGradeId,"{{Damage}} +5攻击力#{{Tears}} +5射速，可突破常规上限#{{Range}} +5射程#连续三层各受到满分考卷判定的有效伤害：第三层最终头目结算掉落一份#每份实物承受5次有效伤害后移除；丢下、金色、吞下保留该份耐久","零分考卷","zh_cn")
            eidRegistered=true
        end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER,function()
        for key,notice in pairs(notices) do
            local player=notice.player
            if Game():GetFrameCount()>notice.expires or not player or (player.Exists and not player:Exists()) then notices[key]=nil
            else
                local p=Isaac.WorldToScreen(player.Position)
                renderText(notice.name,p.X-50,p.Y-64,0.8,0.85,1,1)
                renderText(Options.Language=="zh" and "本层临时" or "Temporary this floor",p.X-36,p.Y-52,0.8,0.85,1,1)
            end
        end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,function()notices={} end)
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT,function()notices={} end)
end
