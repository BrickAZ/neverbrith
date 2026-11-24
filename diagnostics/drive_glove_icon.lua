-- Opt-in resource probe; never included by the normal loader.
return function(mod)
    local started,age=false,0
    local function log(text) Isaac.DebugString('[Drive Glove runtime] '..text) end
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if started then return end
        started=true
        Isaac.StartNewGame(0,0,0,123456789)
    end)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE,function()
        age=age+1
        local player=Isaac.GetPlayer(0)
        if age==30 then
            local id=mod.DriveGlove.ItemId
            local config=Isaac.GetItemConfig():GetCollectible(id)
            log('ICON config id='..id..' gfx='..config.GfxFileName)
            local expected='gfx/items/collectibles/drive_glove_v1.png'
            log((config.GfxFileName:lower()==expected and 'PASS ' or 'FAIL ')..'resolved icon path')
            local other=Isaac.GetItemConfig():GetCollectible(Isaac.GetItemIdByName('Blinky'))
            log('ICON comparison gfx='..other.GfxFileName)
            player.Position=Game():GetRoom():GetCenterPos()+Vector(100,50)
            player.ControlsEnabled=false
            player:AddCollectible(id,0,true,0)
            local pickup=Isaac.Spawn(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_COLLECTIBLE,id,
                Game():GetRoom():GetCenterPos()+Vector(-100,50),Vector.Zero,nil)
            for _,layer in ipairs(pickup:GetSprite():GetAllLayers()) do
                log('ICON pedestal layer='..layer:GetLayerID()..' path='..layer:GetSpritesheetPath())
            end
            log((pickup:GetSprite():GetLayer(1):GetSpritesheetPath():lower()==expected and 'PASS ' or 'FAIL ')..'native pedestal icon path')
            log((player:GetActiveItem(0)==id and 'PASS ' or 'FAIL ')..'active slot item identity')
            log('ICON ready for visual inspection')
        end
        if age==1350 then log('DONE icon observation') end
    end)
end
