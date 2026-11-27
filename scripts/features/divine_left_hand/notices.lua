-- Temporary copy feedback owns its runtime state and cleanup, never saved.
return function(mod, state, itemName, renderText)
    local notices = {}
    local api = {}
    function api.OnTemporaryCopy(player,id,name)
        notices[state.InventoryPlayerKey(player)]={player=player,name=itemName(id,name),
            expires=Game():GetFrameCount()+90}
    end
    function api.InstallCallbacks()
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
    return api
end
