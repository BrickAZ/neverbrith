local build=dofile('tests/support/archive_pair_fixture.lua')
local cases=0
local function case(name,run)
    run();cases=cases+1;print('PASS archive pair: '..name)
end
case('nested Certificate, House takeover and restoration preserve parent and origin',function()
    local e=build();local origin=e.clone(e.players[1].Position)
    assert(e:use('certificate').Remove==false)
    local stack=e.cert.GetPersistentData().stack;local parent=stack[1]
    assert(#stack==1 and #e:controls('certificate')==3)
    e:press('certificate','next');assert(parent.galleryPageIndex==2)
    assert(e:use('certificate').ShowAnim);local child=stack[2]
    assert(#stack==2 and child~=parent)
    local positions=e.clone(child.originPlayerPositions)
    assert(e:use('house').Remove==true)
    local house=e.house.GetPersistentData().session
    assert(house.parentCertificateToken==child.token and #e:controls('certificate')==0)
    assert(e:use('certificate').ShowAnim==false and #stack==2,'carrier exclusion')
    e:press('house','return')
    assert(e.house.GetPersistentData().session==nil and stack[2]==child and #e:controls('certificate')==3)
    assert(e.players[1].Position.X==house.originPlayerPositions[1].x)
    e:press('certificate','return')
    assert(#stack==1 and stack[1]==parent and parent.galleryPageIndex==2)
    assert(e.players[1].Position.X==positions[1].x)
    e:press('certificate','return')
    assert(#e.transitions==1 and e.transitions[1].index==10 and e.transitions[1].dimension==2)
    e:arrive(10,2)
    assert(#stack==0 and e.players[1].Position.X==origin.X and e.players[1].Position.Y==origin.Y)
    assert(e.root.unrelated.keep==17)
end)
case('failed return rebuilds its own room and can retry',function()
    for _,owner in ipairs({'certificate','house'})do
        local e=build();e:use(owner);e.failTransition=true;e:press(owner,'return')
        local session=owner=='certificate' and e.cert.GetPersistentData().stack[1] or e.house.GetPersistentData().session
        assert(session.phase=='active' and #e:controls(owner)==3)
        e.failTransition=false;e:press(owner,'return');assert(#e.transitions==2)
        e:arrive(10,2)
        assert(owner=='certificate' and #e.cert.GetPersistentData().stack==0 or owner=='house' and e.house.GetPersistentData().session==nil)
    end
end)
case('continued House aborts selection while Certificate stack survives',function()
    local e=build();e:use('certificate');local parent=e.cert.GetPersistentData().stack[1]
    e:use('house');local stale=e.house.GetPersistentData().session
    local pickup=e:pedestals('house')[1]
    e.house.Callbacks.PickupCollision(e.mod,pickup,e.players[1])
    e.players[1].QueuedItem={Item={ID=pickup.SubType}}
    e:emit(ModCallbacks.MC_PRE_GAME_EXIT,true)
    local saves=#e.saves;e:advance(2);assert(#e.saves==saves)
    e:emit(ModCallbacks.MC_POST_GAME_STARTED,true)
    assert(e.house.GetPersistentData().session==nil and e.cert.GetPersistentData().stack[1]==parent)
    assert(e.transitions[#e.transitions].index==stale.originRoomIndex)
    e:arrive(-3,0);assert(#e:controls('certificate')==3)
    e:emit(ModCallbacks.MC_POST_GAME_STARTED,false)
    assert(#e.cert.GetPersistentData().stack==0 and #e.house.GetPersistentData().encounters==0)
end)
case('three simultaneous reservations settle only after grants and return once',function()
    local e=build();e:use('house');local session=e.house.GetPersistentData().session
    local pickups=e:pedestals('house')
    for i=1,3 do
        assert(e.house.Callbacks.PickupCollision(e.mod,pickups[i],e.players[i])==nil)
        e.players[i].QueuedItem={Item={ID=pickups[i].SubType}}
    end
    e:advance(6);assert(session.selectedCount==0 and #e.transitions==0)
    for i=1,3 do
        local id=pickups[i].SubType;pickups[i].SubType=0
        e.players[i].counts[id]=(e.players[i].counts[id] or 0)+1;e.players[i].QueuedItem=nil
    end
    e:advance(1);assert(session.selectedCount==3 and #e.transitions==1)
    e:advance(8);assert(#e.transitions==1)
end)
case('position validation remains Certificate-only',function()
    local e=build();e.rejectPositions=true
    assert(e:use('certificate').ShowAnim)
    assert(e.cert.GetPersistentData().stack[1].phase=='capacity_failure' and #e:controls('certificate')==0)
    local h=build();h.rejectPositions=true;assert(h:use('house').Remove)
    assert(#h:controls('house')==3 and #h:pedestals('house')==3)
end)
case('independent stores, live replacement, old-view retention and unload gating',function()
    local a,b=build(),build()
    local av,bv=a.cert.GetPersistentData(),b.cert.GetPersistentData()
    assert(av~=bv and av.stack~=bv.stack)
    local replacement={runSeed=a.seed,nextToken=19,stack={},extension='keep'}
    a.root.certificateOfNeverbirth=replacement
    assert(a.cert.GetPersistentData()==replacement and b.cert.GetPersistentData()==bv)
    a.seed='NEXT';assert(a.cert.GetPersistentData()~=replacement and replacement.nextToken==19 and replacement.extension=='keep')
    b:use('house');b:emit(ModCallbacks.MC_PRE_MOD_UNLOAD,{})
    assert(b.mod.HouseVsElephantCarrierAPI.IsActive())
    b:emit(ModCallbacks.MC_PRE_MOD_UNLOAD,b.mod);b:emit(ModCallbacks.MC_PRE_MOD_UNLOAD,b.mod)
    local saves=#b.saves;b:emit(ModCallbacks.MC_POST_GAME_STARTED,true);b:advance(4)
    assert(not b.mod.HouseVsElephantCarrierAPI.IsActive() and #b.saves==saves)
    assert(b:use('certificate').ShowAnim==false and b:use('house').ShowAnim==false)
end)
case('variant failure cache and zero-variant policy stay item-specific',function()
    local e=build();e.variant=-1
    assert(e:use('certificate').ShowAnim==false)
    e.variant=3016;assert(e:use('certificate').ShowAnim==false,'Certificate retains failed variant cache')
    local h=build();h.variant=-1;assert(h:use('house').ShowAnim==false)
    h.variant=0;assert(h:use('house').Remove==true,'House retries and accepts zero variant as before')
    assert(#h:controls('house')==3)
end)
case('entry command failure rolls back sessions without rewriting token policy',function()
    for _,owner in ipairs({'certificate','house'})do
        local e=build();e.failCommand=true;local result=e:use(owner)
        assert(result.Remove==false and result.ShowAnim==false and e.roomIndex==10)
        assert(#e.cert.GetPersistentData().stack==0 and e.house.GetPersistentData().session==nil)
        local data=owner=='certificate' and e.cert.GetPersistentData() or e.house.GetPersistentData()
        assert((data.nextToken or data.nextSessionToken)==2,'failed entry retains original token increment')
    end
end)
case('control spawn errors keep each original protection boundary',function()
    local e=build();e.failSpawn=true
    assert(e:use('certificate').ShowAnim==true)
    assert(e.cert.GetPersistentData().stack[1].phase=='active' and #e:controls('certificate')==0)
    local h=build();h.failSpawn=true
    assert(h:use('house').ShowAnim==false and h.house.GetPersistentData().session==nil)
end)
case('Certificate animation markers retain attempted-versus-missing distinction',function()
    local e=build();e:use('certificate');local control=e:controls('certificate','next')[1]
    assert(control.data.NeverbirthCertificatePlayedAnimation=='NextIdle')
    e.missingAnimation=true;e:park();e:advance(11)
    e.players[1].Position=control.Position;e:advance(1)
    assert(control.data.NeverbirthCertificateRequestedAnimation=='NextPress')
    assert(control.data.NeverbirthCertificatePlayedAnimation=='NextIdle','missing animation does not erase old played marker')
    local h=build();h:use('certificate');control=h:controls('certificate','next')[1]
    h.failPlay=true;h:park();h:advance(11);h.players[1].Position=control.Position;h:advance(1)
    assert(control.data.NeverbirthCertificateRequestedAnimation=='NextPress' and control.data.NeverbirthCertificatePlayedAnimation==nil)
end)
print('archive pair lifecycle: '..cases..' cases passed')
