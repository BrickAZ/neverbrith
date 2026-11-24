-- Explicit temporary menu-only native asset probe. Never starts or changes a run.
return function(mod)
    local assets=include('generated/motion_presentation')
    local pending,cache={},{};local native=Sprite();native:Load('gfx/001.000_player.anm2',true)
    local frameCount,layerCount,errors=0,0,0;local active=true
    for _,name in ipairs({'wave','dp','circle_360','circle_720'}) do
        local asset=assets[name];local s=Sprite();s:Load(asset.native_path or asset.path,true);cache[name]=s
        for _,variant in ipairs({'normal','od'}) do
            if asset.variants[variant] then
                assert(s:GetAnimationData(asset.variants[variant].animation),'missing animation '..name..' '..variant)
                for i,data in ipairs(asset[variant..'_frames']) do
                    pending[#pending+1]={key=name,variant=variant,tick=i-1,data=data}
                end
            end
        end
        for _,event in ipairs(asset.audio) do
            assert(Isaac.GetSoundIdByName('Zangief V2 '..event.key)>0,'unregistered sound '..event.key)
            assert(not event.key:find('_eng',1,true),'English voice not selected')
        end
    end
    Isaac.DebugString('[Motion native probe] BEGIN expected='..#pending)
    local cursor=1
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if not active then return end
        local good,err=pcall(function()
            for _=1,16 do
                local job=pending[cursor]
                if not job then
                    active=false
                    Isaac.DebugString('[Motion native probe] PASS frames='..frameCount..' layers='..layerCount..' errors='..errors..' no_run_started=true')
                    return
                end
                local asset=assets[job.key];local s=cache[job.key];local data=job.data
                s:SetFrame(asset.variants[job.variant].animation,job.tick)
                assert(s:GetFrame()==job.tick,'native animation did not accept frame')
                for _,layer in ipairs(asset.layers) do
                    if layer[2]=='native_body' or layer[2]=='native_head' then
                        local pose=layer[2]=='native_body' and data.body or data.head
                        local id=asset.native_layer_map and asset.native_layer_map[tostring(layer[1])] or layer[1]
                        local f=s:GetLayerFrameData(id);local pos=f:GetPos();local scale=f:GetScale()
                        assert(math.abs(pos.X-pose[1])<.015 and math.abs(pos.Y-pose[2])<.015,'native position differs from ledger '..job.key..' '..job.tick)
                        assert(math.abs(scale.X-pose[3]/100)<.015 and math.abs(scale.Y-pose[4]/100)<.015,'native scale differs from ledger')
                    end
                end
                for _,entry in ipairs(data.visible) do
                    s.Scale=Vector(.5,.5);s.Rotation=0
                    local id=asset.native_layer_map and asset.native_layer_map[tostring(entry[1])] or entry[1]
                    s:RenderLayer(id,Vector(150,150));layerCount=layerCount+1
                end
                native:SetFrame('Walk'..data.face,data.body_tick);native:RenderLayer(1,Vector(110,110))
                native:SetFrame('Head'..data.face,0);native:RenderLayer(4,Vector(110,110))
                frameCount=frameCount+1;cursor=cursor+1
            end
        end)
        if not good then active=false;errors=errors+1;Isaac.DebugString('[Motion native probe] FAIL '..tostring(err)) end
    end)
end
