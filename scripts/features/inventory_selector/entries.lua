return function(itemName, getTemporaryCount)
    return function(player)
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
                            temporaryCount=getTemporaryCount(player,id)}
                    end
                end
            end
            return entries
    end
end
