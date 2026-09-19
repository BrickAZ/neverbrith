-- Uses full main.lua, with native semantics at the changed boundaries.
local factory = assert(loadfile("tests/angelbox_behavior_test.lua"))("--fixture")
local passed, failures = 0, {}
local function eq(a,b,m) assert(a==b,(m or "value")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn)
    local ok,err=pcall(fn)
    if ok then passed=passed+1 else failures[#failures+1]=name..": "..tostring(err) end
end
local function useTwice(e,name)
    local id=e.items[name]
    local p=e.newPlayer({activeItems={[0]=id},activeCharges={[0]=4},maxHearts=6})
    local use=e.getCallback(ModCallbacks.MC_USE_ITEM,id)
    use(e.mod,id,nil,p,0,0,0); p:SetActiveCharge(4,0)
    return use(e.mod,id,nil,p,0,0,0),p
end
for _,name in ipairs({"Angelbox","Devilbox"}) do
    test(name.." opens the correct room",function()
        local e=factory(); local target=name=="Angelbox" and 15 or 14
        e.level.dealRoomDesc={Data={Type=target==15 and 14 or 15},VisitedCount=0}
        local result,p=useTwice(e,name)
        eq(result,true); eq(e.level.dealRoomDesc.Data.Type,target,"room type")
        eq(e.room.doorCalls,1,"door creation"); eq(p:GetActiveCharge(0),0)
    end)
    test(name.." failed door preserves charge and entitlement",function()
        local e=factory(); local old=e.level.dealRoomDesc.Data; e.room.doorSucceeds=false
        local result,p=useTwice(e,name)
        eq(type(result),"table"); eq(result.Discharge,false); eq(p:GetActiveCharge(0),4)
        eq(e.level.dealRoomDesc.Data,old,"room rollback")
        e.room.roomType=name=="Angelbox" and 15 or 14
        local reward=name=="Angelbox" and e.mod.SpawnAngelboxRewardOnNewRoom or e.mod.SpawnDevilboxRewardOnNewRoom
        reward(e.mod); eq(#e.spawned,0,"no reward entitlement after failed use")
    end)
    test(name.." preserves visited opposite room",function()
        local e=factory(); local old={Type=name=="Angelbox" and 14 or 15}
        e.level.dealRoomDesc={Data=old,VisitedCount=1}
        local result,p=useTwice(e,name)
        eq(type(result),"table"); eq(result.Discharge,false); eq(p:GetActiveCharge(0),4)
        eq(e.level.dealRoomDesc.Data,old)
    end)
    test(name.." converts exactly half of opposite outcomes once",function()
        local converted=0
        for roll=0,99 do
            local e=factory(); local target=name=="Angelbox" and 15 or 14
            local original=target==15 and 14 or 15
            e.level.dealRoomDesc={Data={Type=original},VisitedCount=0}
            local p=e.newPlayer({activeItems={[0]=e.items[name]}})
            local draws=0
            function p:GetCollectibleRNG()
                return {RandomFloat=function() draws=draws+1; return roll/100 end}
            end
            local door={TargetRoomIndex=-1,TargetRoomType=original}
            function door:SetRoomTypes(source,destination) self.TargetRoomType=destination end
            local cb=assert(e.getCallback(ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_UPDATE),"door callback missing")
            eq(cb(e.mod,door),nil)
            for _=1,3 do cb(e.mod,door) end
            eq(draws,1,"one draw per floor result")
            eq(door.TargetRoomType,e.level.dealRoomDesc.Data.Type,"door target matches room")
            if door.TargetRoomType==target then converted=converted+1 end
            eq(e.level.angelRoomChanceDelta,0,"no additive modifier")
        end
        eq(converted,50,"conditional conversion")
    end)
end
test("failed door retarget restores initialized room and does not reroll",function()
    local e=factory(); local old={Type=14}; e.level.dealRoomDesc={Data=old}
    local p=e.newPlayer(); local draws=0
    function p:GetCollectibleRNG() return {RandomFloat=function() draws=draws+1; return 0 end} end
    local door={TargetRoomIndex=-1,TargetRoomType=14}
    function door:SetRoomTypes(_,target) if target==15 then error("retarget failed") end; self.TargetRoomType=target end
    local cb=e.getCallback(ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_UPDATE)
    cb(e.mod,door); cb(e.mod,door)
    eq(e.level.dealRoomDesc.Data,old,"descriptor rollback"); eq(door.TargetRoomType,14); eq(draws,1)
end)
test("failed initializer preserves charge and room",function()
    local e=factory(); local old={Type=14}; e.level.dealRoomDesc={Data=old}
    function e.level:InitializeDevilAngelRoom() error("initialize failed") end
    local result,p=useTwice(e,"Angelbox")
    eq(result.Discharge,false); eq(p:GetActiveCharge(0),4); eq(e.level.dealRoomDesc.Data,old)
    eq(e.room.doorCalls,nil)
end)
test("existing opposite door is reused and retargeted",function()
    local e=factory(); e.level.dealRoomDesc={Data={Type=14}}
    local door={TargetRoomIndex=-1,TargetRoomType=14}
    function door:SetRoomTypes(_,target) self.TargetRoomType=target end
    function e.room:GetDoor(slot) if slot==0 then return door end end
    e.room.doorSucceeds=false
    local result,p=useTwice(e,"Angelbox")
    eq(result,true); eq(p:GetActiveCharge(0),0); eq(door.TargetRoomType,15)
    eq(e.room.doorCalls,nil,"reuse entrance without duplicate spawn")
end)
test("active retarget failure retains charge and original room",function()
    local e=factory(); local old={Type=14}; e.level.dealRoomDesc={Data=old}
    local door={TargetRoomIndex=-1,TargetRoomType=14}
    function door:SetRoomTypes(_,target) if target==15 then error("retarget failed") end end
    function e.room:GetDoor(slot) if slot==0 then return door end end
    local result,p=useTwice(e,"Angelbox")
    eq(result.Discharge,false); eq(p:GetActiveCharge(0),4); eq(e.level.dealRoomDesc.Data,old)
end)
test("irrelevant rooms and unowned conversions do not draw RNG",function()
    local e=factory(); local p=e.newPlayer(); local draws=0
    function p:GetCollectibleRNG() return {RandomFloat=function() draws=draws+1; return 0 end} end
    local cb=e.getCallback(ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_UPDATE)
    cb(e.mod,{TargetRoomIndex=1,TargetRoomType=14})
    cb(e.mod,{TargetRoomIndex=-1,TargetRoomType=15}) -- Already angel; no Devilbox owner.
    e.level.dealRoomDesc.Data.Type=14; function e.level:GetDimension() return 1 end
    cb(e.mod,{TargetRoomIndex=-1,TargetRoomType=14}); eq(draws,0)
end)
test("saved deal decisions survive reload without another draw",function()
    local e=factory(); e.level.dealRoomDesc.Data.Type=14
    local p=e.newPlayer()
    function p:GetCollectibleRNG() return {RandomFloat=function() return 0.8 end} end
    local door={TargetRoomIndex=-1,TargetRoomType=14,SetRoomTypes=function() end}
    e.getCallback(ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_UPDATE)(e.mod,door)
    local reloaded=factory(e.savedStore); reloaded.level.dealRoomDesc.Data.Type=14
    p=reloaded.newPlayer()
    function p:GetCollectibleRNG() error("saved outcome rerolled") end
    reloaded.getCallback(ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_UPDATE)(reloaded.mod,door)
    eq(reloaded.level.dealRoomDesc.Data.Type,14)
end)
test("legacy additive modifiers are removed exactly once",function()
    local e=factory(); e.level.dealRoomDesc.Data.Type=14
    local p=e.newPlayer()
    function p:GetCollectibleRNG() return {RandomFloat=function() return 0.8 end} end
    e.getCallback(ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_UPDATE)(e.mod,{TargetRoomIndex=-1,TargetRoomType=14})
    local snapshot=e.savedStore.snapshot
    local key=next(snapshot.angelbox.dealRoomConversions)
    snapshot.angelbox.appliedChanceFloors[key]=0.5
    local reloaded=factory(e.savedStore); reloaded.level.angelRoomChanceDelta=0.5
    reloaded.mod.UpdateAngelboxDealChance(); reloaded.mod.UpdateAngelboxDealChance()
    eq(reloaded.level.angelRoomChanceDelta,0)
end)
test("both boxes transfer each native direction only once",function()
    for _,original in ipairs({14,15}) do
        local e=factory(); e.level.dealRoomDesc.Data.Type=original
        local p=e.newPlayer({activeItems={[0]=e.items.Angelbox,[1]=e.items.Devilbox}}); local draws=0
        function p:GetCollectibleRNG() return {RandomFloat=function() draws=draws+1; return 0 end} end
        local door={TargetRoomIndex=-1,TargetRoomType=original}
        function door:SetRoomTypes(_,target) self.TargetRoomType=target end
        local cb=e.getCallback(ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_UPDATE)
        for _=1,4 do cb(e.mod,door) end
        eq(draws,1); eq(door.TargetRoomType,original==14 and 15 or 14)
    end
end)
test("heart logs distinguish a miss from actual spawn without duplicate events",function()
    local e=factory(); e.newPlayer(); local logs={}
    Isaac.DebugString=function(message) logs[#logs+1]=message end
    local hit=e.newHeartPickup(3,5); local miss=e.newHeartPickup(3,60)
    e.mod:HandleBoxHeartPickupInit(hit); e.mod:HandleBoxHeartPickupInit(miss)
    e.mod:HandleBoxHeartPickupInit(hit)
    eq(#logs,2); assert(logs[1]:find("hit=true spawned=true",1,true))
    assert(logs[2]:find("hit=false spawned=false",1,true)); eq(#e.spawned,1)
end)
test("failed bonus spawn cannot leave recursion suppression enabled",function()
    local e=factory(); e.newPlayer(); local originalGame=Game; local fail=true
    Game=function() local game=originalGame(); if fail then game.Spawn=function() error("spawn failed") end end; return game end
    e.mod:HandleBoxHeartPickupInit(e.newHeartPickup(3,5)); fail=false
    e.mod:HandleBoxHeartPickupInit(e.newHeartPickup(3,6)); eq(#e.spawned,1)
end)
test("late NPC handler is registered on the real callback table",function()
    local e=factory(); local expected=e.mod.LittleLeatherShoesTestAPI.Callbacks.NpcUpdate
    local found=false
    for _,fn in ipairs(e.getCallbacks(ModCallbacks.MC_NPC_UPDATE)) do if fn==expected then found=true end end
    assert(found,"NPC update handler was not registered")
end)
local shoes=assert(loadfile("tests/little_leather_shoes_behavior_test.lua"))("--fixture")
local a,s,room=shoes.api,shoes.state,shoes.room
shoes.players[1]={InitSeed=456,HasCollectible=function() return true end,GetCollectibleNum=function() return 0 end}
test("callable constructors preserve HUD and animation",function()
    a.ResetTransientState(true); s.floorTraffic=6; s.hudFonts={}
    local sprites,fonts,chests,text=0,0,0,nil
    Sprite=setmetatable({},{__call=function()
        sprites=sprites+1
        return {Load=function() end,Play=function() end,Render=function() end,Update=function() end,IsFinished=function() return false end}
    end})
    Font=setmetatable({},{__call=function()
        fonts=fonts+1; return {Load=function() return true end,DrawStringUTF8=function(_,value) text=value end}
    end})
    KColor=setmetatable({},{__call=function() return {} end})
    Options={Language="zh"}; Isaac.Spawn=function() chests=chests+1; return {} end
    a.Render(); eq(sprites,1,"meter"); eq(fonts,1,"font"); assert(text and text:find("流量",1,true))
    a.QueuePickupVisual(a.GetRewardItemsForTraffic(6)[1],Vector(100,100),true)
    eq(chests,0,"deferred chest")
    for _=1,8 do a.ProcessPickupVisuals() end
    eq(chests,1)
end)
test("ordinary clear does not wait for ambush flag",function()
    a.ResetTransientState(true); shoes.setRoomType(1)
    room.IsClear=function() return true end; room.IsAmbushDone=function() return false end
    room.IsAmbushActive=function() return false end
    local npc=shoes.newNpc({seed=7001})
    a.RegisterNpc(npc); a.Callbacks.EntityKill({},npc); eq(a.Callbacks.PreClearAward(),true)
    s.returnsEnabled=false; room.awards=0
    for _=1,10 do a.Update() end
    eq(s.floorTraffic,1,"traffic"); eq(room.awards,1,"one deferred award")
end)
test("late vulnerable NPC gets a death chain",function()
    a.ResetTransientState(true); room.IsClear=function() return false end
    local npc=shoes.newNpc({seed=7002}); npc.IsVulnerableEnemy=function() return false end
    a.Callbacks.NpcInit({},npc); npc.IsVulnerableEnemy=function() return true end
    assert(a.Callbacks.NpcUpdate,"NPC update missing")({},npc)
    assert(npc.data.NeverbirthLittleLeatherShoesChainId,"late NPC unregistered")
    a.Callbacks.EntityKill({},npc); eq(#s.splitWatch,1)
end)
test("wave rooms wait for completion and live returned enemies block settlement",function()
    a.ResetTransientState(true); shoes.setRoomType(11)
    room.IsClear=function() return true end; room.IsAmbushDone=function() return false end
    a.RegisterNpc(shoes.newNpc({seed=7003})); eq(a.Callbacks.PreClearAward(),true)
    room.awards=0; for _=1,3 do a.Update() end; eq(room.awards,0)
    room.IsAmbushDone=function() return true end
    room.GetAliveEnemiesCount=function() return 1 end
    for _=1,3 do a.Update() end; eq(room.awards,0)
    room.GetAliveEnemiesCount=function() return 0 end
    for _=1,3 do a.Update() end; eq(room.awards,1)
    room.GetAliveEnemiesCount=nil; shoes.setRoomType(1)
end)
test("shoes logs expose return decisions and one settlement",function()
    a.ResetTransientState(true); room.IsClear=function() return true end
    local logs={}; Isaac.DebugString=function(message) logs[#logs+1]=message end
    local npc=shoes.newNpc({seed=7004}); a.RegisterNpc(npc); a.Callbacks.EntityKill({},npc)
    s.returnsEnabled=false
    for _=1,10 do a.Update() end
    local decisions,settlements=0,0
    for _,line in ipairs(logs) do
        if line:find("return roll",1,true) then decisions=decisions+1; assert(line:find("threshold=33",1,true)); assert(line:find("queued=false",1,true)) end
        if line:find("settled room=",1,true) then settlements=settlements+1; assert(line:find("gained=1 total=1",1,true)) end
    end
    eq(decisions,1); eq(settlements,1)
end)
for _,message in ipairs(failures) do print("FAIL "..message) end
print("box/shoes regression: "..passed.." passed, "..#failures.." failed")
assert(#failures==0,"REPENTOGON regressions remain")
