-- Explicit assembly only; legacy callers may still supply an unrestricted getter.
return function(mod, context)
    local state = context.State or include("pending_content_state")(mod, context)
    local function withContext(fields, scopeName)
        local child = {State=state, GetSaveRoot=context.GetSaveRoot, Save=context.Save,
            GetCurrentRunSeed=context.GetCurrentRunSeed, GetPlayers=context.GetPlayers,
            DebugLog=context.DebugLog}
        if context.SaveScopes and scopeName then
            child.GetSaveRoot=assert(context.SaveScopes[scopeName], "missing save scope: "..scopeName).GetRoot
        end
        for key,value in pairs(fields) do child[key]=value end
        return child
    end
    local text = include("scripts.features.inventory_selector.text")(mod, context)
    local notices = include("scripts.features.divine_left_hand.notices")(mod, state, text.ItemName, text.RenderText)
    local divineLeftHand = include("divine_left_hand")(mod,withContext({ItemId=context.Items.DivineLeftHand,
        OnTemporaryCopy=notices.OnTemporaryCopy,
    }, "DivineLeftHand"))
    local lowGradeId=-1
    if Isaac.GetTrinketIdByName then
        for _,name in ipairs({"Low Grade","零分考卷"})do
            local candidate=Isaac.GetTrinketIdByName(name)
            if candidate and candidate>0 then lowGradeId=candidate;break end
        end
    end
    if lowGradeId>0 then include("low_grade")(mod,withContext({TrinketId=lowGradeId}, "LowGrade")) end
    local familiarVariant=Isaac.GetEntityVariantByName and Isaac.GetEntityVariantByName("Echo Baby Familiar") or -1
    include("echo_baby")(mod,withContext({ItemId=context.Items.EchoBaby,FamiliarVariant=familiarVariant}, "EchoBaby"))
    local selector = include("inventory_selector")(mod,withContext({
        GetEntries=include("scripts.features.inventory_selector.entries")(text.ItemName, function(player,id)
            return divineLeftHand and divineLeftHand.GetTemporaryCount(player,id) or 0
        end),
        RenderText=text.RenderText,
        GetText=text.GetText,
    }))
    include("scripts.integrations.low_grade_eid")(mod, lowGradeId)
    notices.InstallCallbacks()
    return { State=state, Selector=selector, DivineLeftHand=divineLeftHand }
end
