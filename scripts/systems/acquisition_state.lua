-- Confirmed acquisition identities and native Glowing Hourglass slot snapshots.
-- Collision only stages a candidate; an actual inventory increase settles it.
return function(mod, context)
    local game = Game()
    local subscribers, pending, preAdds, temporary, awaiting = {}, {}, {}, {}, {}
    local detached, newGround = {}, {}
    local service = {}
    local clone = include("scripts.runtime.plain_data").CopyTree
    local function log(message)
        if context.DebugLog then context.DebugLog('[pending_content] '..tostring(message)) end
    end
    local function data()
        local root=context.GetSaveRoot(); local seed=tostring(context.GetCurrentRunSeed())
        if type(root.pendingContent)~='table' or root.pendingContent.seed~=seed then
            root.pendingContent={seed=seed,serial=0,players={},pickups={}}
            root.pendingContentHourglass={seed=seed,slots={}}
        end
        root.pendingContent.inventory=root.pendingContent.inventory or {}
        return root.pendingContent
    end
    local function save() if context.Save then context.Save() end end
    local function frame() return game:GetFrameCount() end
    local function count(player,id) return player:GetCollectibleNum(id,true,true) end
    local identity = context.Identity or include("scripts.runtime.player_identity")
    service.PlayerKey = identity.PlayerKey
    service.InventoryPlayerKey = identity.InventoryPlayerKey
    function service.FloorKey()
        local l=game:GetLevel()
        return table.concat({l:GetStage(),l:GetStageType(),
            l.GetDungeonPlacementSeed and l:GetDungeonPlacementSeed() or 0},':')
    end
    function service.RoomKey()
        local l=game:GetLevel(); local d=l:GetCurrentRoomDesc()
        -- ListIndex distinguishes native mirror/alternate descriptors without
        -- requiring a newer GetDimension API.
        return service.FloorKey()..':'..tostring(d and d.ListIndex or l:GetCurrentRoomIndex())
            ..':'..tostring(d and d.SafeGridIndex or l:GetCurrentRoomIndex())
    end
    local function pickupIdentity(pickup)
        return service.RoomKey()..':'..tostring(pickup.InitSeed)
    end
    function service.PickupToken(pickup)
        local d=pickup:GetData()
        if d.NeverbirthPhysicalToken then return d.NeverbirthPhysicalToken end
        local identity=pickupIdentity(pickup)
        local root=data()
        if not root.pickups[identity] then
            root.serial=root.serial+1
            root.pickups[identity]='physical:'..root.seed..':'..root.serial
        end
        d.NeverbirthPhysicalToken=root.pickups[identity]
        return d.NeverbirthPhysicalToken
    end
    local function historyRows(player)
        if not player.GetHistory then return nil end
        local history=player:GetHistory()
        if not history or not history.GetCollectiblesHistory then return nil end
        local rows={}
        for _,item in ipairs(history:GetCollectiblesHistory()) do
            local values={item:GetItemID(),item:GetTime(),item:GetLevelStage(),item:GetStageType(),
                item:GetRoomType(),item:GetItemPoolType(),tostring(item:IsTrinket())}
            for i,value in ipairs(values)do values[i]=tostring(value)end
            rows[#rows+1]={id=item:GetItemID(),signature=table.concat(values,':'),trinket=item:IsTrinket()}
        end
        return rows
    end
    local function bindGround(pickup)
        if pickup.Variant~=PickupVariant.PICKUP_COLLECTIBLE or pickup.SubType<=0 then return end
        local matches={};local spawn=pickup.SpawnerEntity
        local owner=spawn and spawn.ToPlayer and spawn:ToPlayer() or spawn
        for _,row in ipairs(detached)do
            if row.id==pickup.SubType and row.frame==frame() and row.room==service.RoomKey()
                and (not owner or service.InventoryPlayerKey(owner)==service.InventoryPlayerKey(row.player)) then
                local a,b=pickup.Position,row.player.Position
                if a and b and (a.X-b.X)^2+(a.Y-b.Y)^2<=80^2 then matches[#matches+1]=row end
            end
        end
        if #matches==1 and not matches[1].unresolved then
            local row=matches[1];local d=pickup:GetData()
            d.NeverbirthPhysicalToken=row.token;d.NeverbirthPhysicalTemporary=row.temporary
            data().pickups[pickupIdentity(pickup)]=row.token
            for i=#detached,1,-1 do if detached[i]==row then table.remove(detached,i) end end
            save()
        elseif #matches>0 then
            pickup:GetData().NeverbirthPhysicalUnresolved=true
            log('ambiguous native collectible drop; physical rewards suppressed')
        end
    end
    local function synchronizeInventory(player)
        local rows=historyRows(player);if not rows then return nil end
        local root=data();local key=service.InventoryPlayerKey(player);local previous=root.inventory[key] or {}
        local unchanged=#rows==#previous
        if unchanged then for i,row in ipairs(rows)do if row.signature~=previous[i].signature then unchanged=false;break end end end
        if unchanged then return previous end
        -- A proven append keeps every earlier physical row even if the native
        -- metadata of the newly appended row is identical to an older one.
        if #rows > #previous then
            local prefix=true
            for i,row in ipairs(previous)do if rows[i].signature~=row.signature then prefix=false;break end end
            if prefix then for i,row in ipairs(previous)do
                rows[i].token,row.temporary,row.unresolved= row.token,row.temporary,row.unresolved
            end end
        end
        local oldBy,newBy={},{}
        for _,row in ipairs(previous)do local group=oldBy[row.signature]or{};oldBy[row.signature]=group;group[#group+1]=row end
        for _,row in ipairs(rows)do local group=newBy[row.signature]or{};newBy[row.signature]=group;group[#group+1]=row end
        for signature,old in pairs(oldBy)do
            local now=newBy[signature]or{}
            if #old==#now then
                for i,row in ipairs(now)do
                    row.token,row.temporary,row.unresolved=old[i].token,old[i].temporary,old[i].unresolved
                end
            elseif #old==1 and #now==0 and (old[1].token or old[1].unresolved) and not old[1].trinket then
                detached[#detached+1]={id=old[1].id,token=old[1].token,temporary=old[1].temporary,
                    unresolved=old[1].unresolved,room=service.RoomKey(),frame=frame(),player=player}
            elseif #old>#now then
                -- Identical native receipts cannot prove which physical object left.
                for _,row in ipairs(now)do row.unresolved=true end
                for _,row in ipairs(old)do if (row.token or row.unresolved) and not row.trinket then
                    detached[#detached+1]={id=row.id,unresolved=true,
                        room=service.RoomKey(),frame=frame(),player=player}
                    log('indistinguishable native collectible histories; drop identity unavailable')
                    break
                end end
            end
        end
        root.inventory[key]=rows
        for _,pickup in ipairs(newGround)do if not pickup.Exists or pickup:Exists()then bindGround(pickup)end end
        return rows
    end
    function service.SubscribeAcquisition(fn) subscribers[#subscribers+1]=fn end
    function service.IsTemporary(player) return (temporary[service.PlayerKey(player)] or 0)>0 end
    function service.WithTemporary(player,fn)
        local k=service.PlayerKey(player);temporary[k]=(temporary[k]or 0)+1
        local result=table.pack(pcall(fn));temporary[k]=temporary[k]-1
        if not result[1] then log(result[2]);return false,result[2] end
        return table.unpack(result,2,result.n)
    end
    function service.GetAcquisitions(player)
        return clone(data().players[service.PlayerKey(player)] or {})
    end
    function service.GetPendingReceipt(player)
        local stack=preAdds[service.InventoryPlayerKey(player)]
        return stack and stack[#stack] or nil
    end
    local snapshots = include("scripts.runtime.snapshot_participants")(clone)
    service.RegisterParticipant = snapshots.Register
    function service.Snapshot()
        -- Preserve the original shared-before-participants capture sequence.
        local snapshot={shared=clone(data()),participants={}}
        snapshot.participants = snapshots.Capture()
        return snapshot
    end
    function service.Restore(snapshot)
        if not snapshot or not snapshot.shared or snapshot.shared.seed~=tostring(context.GetCurrentRunSeed()) then return false end
        context.GetSaveRoot().pendingContent=clone(snapshot.shared)
        pending,preAdds,temporary,awaiting,detached,newGround={},{},{},{},{},{}
        snapshots.Restore(snapshot.participants)
        save();return true
    end
    mod.PendingContentState=service
    mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION,function(_,pickup,collider)
        local player=collider and collider.ToPlayer and collider:ToPlayer()
        if not player or pickup.SubType<=0 then return end
        local k=service.InventoryPlayerKey(player)
        local current=pending[k]
        if current and current.lastQueuedFrame then return end
        synchronizeInventory(player);bindGround(pickup)
        pending[k]={id=pickup.SubType,token=service.PickupToken(pickup),frame=frame(),
            room=service.RoomKey(),pickup=pickup}
    end,PickupVariant.PICKUP_COLLECTIBLE)
    mod:AddCallback(ModCallbacks.MC_PRE_ADD_COLLECTIBLE,function(_,id,charge,firstTime,slot,varData,player)
        local k=service.InventoryPlayerKey(player);local candidate=pending[k]
        local beforeHistory=synchronizeInventory(player)
        local queued=player.QueuedItem and player.QueuedItem.Item
        local sameFrame=candidate and not candidate.lastQueuedFrame and candidate.frame==frame() and firstTime==true
        -- The engine clears QueuedItem before AddCollectible. A previous-frame
        -- observation of this confirmed pedestal's queue proves the native flush,
        -- including re-pickups where the engine passes FirstTime=false.
        local queueFlush=candidate and not queued and candidate.lastQueuedFrame
            and candidate.lastQueuedFrame>=frame()-1
        local matches=candidate and candidate.id==id and candidate.room==service.RoomKey() and (sameFrame or queueFlush)
        local physical=not service.IsTemporary(player) and matches
            and not candidate.pickup:GetData().NeverbirthPhysicalUnresolved
        preAdds[k]=preAdds[k]or{}
        local root=data();root.serial=root.serial+1
        preAdds[k][#preAdds[k]+1]={id=id,count=count(player,id),temporary=service.IsTemporary(player)
                or (matches and candidate.pickup:GetData().NeverbirthPhysicalTemporary) or false,
            physical=physical and true or false,token=physical and candidate.token or nil,
                unresolved=matches and candidate.pickup:GetData().NeverbirthPhysicalUnresolved or false,
            confirmed=physical and candidate.nativeConfirmed or false,candidate=physical and candidate or nil,
            serial=root.serial,completed=false,beforeHistory=beforeHistory and clone(beforeHistory)}
    end)
    local function deliver(player,id,receipt)
        local k=service.PlayerKey(player)
        local root=data();root.serial=root.serial+1
        local token=receipt.token or ('grant:'..root.seed..':'..root.serial)
        local events=root.players[k]or{};root.players[k]=events
        events[#events+1]={id=id,token=token,order=root.serial,temporary=receipt.temporary,physical=receipt.physical}
        if receipt.physical then pending[service.InventoryPlayerKey(player)]=nil end
        for _,fn in ipairs(subscribers) do
            local ok,err=pcall(fn,player,id,token,receipt.physical,receipt.temporary,receipt)
            if not ok then log('acquisition subscriber: '..tostring(err)) end
        end
        save()
    end
    mod:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE,function(_,id,charge,firstTime,slot,varData,player)
        local k=service.InventoryPlayerKey(player);local stack=preAdds[k];local receipt=stack and table.remove(stack)
        if not receipt or receipt.id~=id or count(player,id)<=receipt.count then return end
        receipt.completed=true;receipt.postCount=count(player,id)
        local after=synchronizeInventory(player);local before=receipt.beforeHistory
        if after and before and #after==#before+1 then
            local prefix=true
            for i,row in ipairs(before)do if after[i].signature~=row.signature then prefix=false;break end end
            local added=after[#after]
            if prefix and added.id==id and not added.trinket then
                added.token=receipt.token or ('grant:'..data().seed..':'..receipt.serial)
                added.temporary=receipt.temporary
                added.unresolved=receipt.unresolved
                -- A nonphysical grant acquires identity before it is ever dropped.
                if not receipt.token then receipt.token=added.token end
            end
        end
        if receipt.physical and not receipt.confirmed then
            awaiting[#awaiting+1]={player=player,id=id,receipt=receipt}
        else deliver(player,id,receipt) end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_COLLISION,function(_,pickup,collider)
        local player=collider and collider.ToPlayer and collider:ToPlayer()
        if not player then return end
        local k=service.InventoryPlayerKey(player);local candidate=pending[k]
        if not candidate or candidate.frame~=frame() or candidate.token~=service.PickupToken(pickup) then return end
        candidate.nativeConfirmed=true
        local queued=player.QueuedItem and player.QueuedItem.Item
        if queued and queued.ID==candidate.id and pickup.SubType~=candidate.id then
            candidate.lastQueuedFrame=frame()
        end
        for i=#awaiting,1,-1 do
            local event=awaiting[i]
            if event.receipt.candidate==candidate then
                table.remove(awaiting,i);deliver(player,event.id,event.receipt)
            end
        end
    end,PickupVariant.PICKUP_COLLECTIBLE)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE,function()
        local incomplete=awaiting;awaiting={}
        for _,event in ipairs(incomplete) do
            event.receipt.physical=false;event.receipt.token=nil
            deliver(event.player,event.id,event.receipt)
        end
        for k,v in pairs(pending) do
            -- A cancelled contact cannot later claim an unrelated scripted grant.
            local p;for _,candidate in ipairs(context.GetPlayers())do if service.InventoryPlayerKey(candidate)==k then p=candidate;break end end
            local q=p and p.QueuedItem and p.QueuedItem.Item
            if v.room~=service.RoomKey() then pending[k]=nil
            elseif v.lastQueuedFrame and q and q.ID==v.id then v.lastQueuedFrame=frame()
            elseif frame()>v.frame then pending[k]=nil end
        end
        if #newGround>0 or #detached>0 then
            for _,player in ipairs(context.GetPlayers())do synchronizeInventory(player)end
            for _,pickup in ipairs(newGround)do if not pickup.Exists or pickup:Exists()then bindGround(pickup)end end
            detached,newGround={},{}
        end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,function()pending,preAdds,detached,newGround={},{},{},{} end)
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,function(_,continued)
        pending,preAdds,temporary,awaiting,detached,newGround={},{},{},{},{},{}
        if not continued then
            local root=context.GetSaveRoot();root.pendingContent=nil;root.pendingContentHourglass=nil
        end
        data()
    end)
    mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED,function(_,player)
        synchronizeInventory(player)
    end)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT,function(_,pickup)
        newGround[#newGround+1]=pickup
        for _,player in ipairs(context.GetPlayers())do synchronizeInventory(player)end
        bindGround(pickup)
    end,PickupVariant.PICKUP_COLLECTIBLE)
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT,function(_,shouldSave)
        if shouldSave then save() end
        pending,preAdds,temporary,awaiting,detached,newGround={},{},{},{},{},{}
    end)
    mod:AddCallback(ModCallbacks.MC_POST_GLOWING_HOURGLASS_SAVE,function(_,slot)
        local root=context.GetSaveRoot();data()
        root.pendingContentHourglass=root.pendingContentHourglass or {seed=tostring(context.GetCurrentRunSeed()),slots={}}
        root.pendingContentHourglass.slots[tostring(slot)]=service.Snapshot();save()
    end)
    mod:AddCallback(ModCallbacks.MC_POST_GLOWING_HOURGLASS_LOAD,function(_,slot)
        local snapshots=context.GetSaveRoot().pendingContentHourglass
        if snapshots and snapshots.seed==tostring(context.GetCurrentRunSeed()) then
            service.Restore(snapshots.slots[tostring(slot)])
        end
    end)
    return service
end
