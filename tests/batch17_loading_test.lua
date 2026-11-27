local loadMod = dofile('tests/support/neverbirth_fixture.lua')
local rawLoadMod=loadMod
loadMod=function(options) options=options or {};options.Root=os.getenv('BATCH17_TEST_ROOT');return rawLoadMod(options)end
local parts = {
    revive_my_love = {'state','presentation','runtime'},
    healthy_sleep = {'state','presentation','input','runtime','lifecycle'},
}
local function enable(name)
    if name ~= 'revive_my_love' then return end
    REPENTOGON.MeetsVersion = function() return true end
    local id=8500
    for _,n in ipairs({'MC_TRIGGER_PLAYER_DEATH_POST_CHECK_REVIVES','MC_PRE_PLAYER_TAKE_DMG',
        'MC_POST_TRIGGER_COLLECTIBLE_REMOVED','MC_POST_PICKUP_COLLISION',
        'MC_PRE_ITEM_OVERLAY_SHOW','MC_POST_ITEM_OVERLAY_SHOW','MC_POST_ITEM_OVERLAY_UPDATE','MC_POST_GAME_END'}) do
        id=id+1;ModCallbacks[n]=ModCallbacks[n] or id
    end
    ItemOverlay={GetSprite=function()return {}end,GetOverlayID=function()return 0 end}
    Giantbook={SLEEP=33};PickupVariant.PICKUP_BED=380
end
local function owner(fn)
    return debug.getinfo(fn,'S').source:match('scripts/features/([^/]+)/')
end
local imports,rows={},{}
loadMod({OnInclude=function(n)enable(n);imports[n]=(imports[n]or 0)+1 end,
    AfterRegister=function(_,event,fn,param)
        local item=owner(fn)
        if parts[item]then rows[item]=rows[item]or {};table.insert(rows[item],{event,fn,param})end
    end})
for item,list in pairs(parts)do
    assert(imports['scripts.features.'..item]==1,item..' entry loaded once')
    for _,part in ipairs(list)do assert(imports['scripts.features.'..item..'.'..part]==1,part)end
end
assert(#rows.revive_my_love==11 and #rows.healthy_sleep==15,'all native bindings installed')
local order={revive_my_love={'MC_TRIGGER_PLAYER_DEATH_POST_CHECK_REVIVES','MC_PRE_PLAYER_TAKE_DMG',
    'MC_PRE_PLAYER_UPDATE','MC_POST_UPDATE','MC_POST_ADD_COLLECTIBLE','MC_POST_TRIGGER_COLLECTIBLE_REMOVED',
    'MC_POST_NEW_ROOM','MC_POST_GAME_STARTED','MC_PRE_GAME_EXIT','MC_POST_PLAYER_UPDATE','MC_POST_EFFECT_UPDATE'},
    healthy_sleep={'MC_POST_GAME_STARTED','MC_POST_NEW_ROOM','MC_POST_NEW_LEVEL','MC_POST_UPDATE',
    'MC_PRE_GAME_EXIT','MC_POST_GAME_END','MC_PRE_MOD_UNLOAD','MC_PRE_PICKUP_COLLISION','MC_POST_PICKUP_COLLISION',
    'MC_PRE_ITEM_OVERLAY_SHOW','MC_POST_ITEM_OVERLAY_SHOW','MC_POST_ITEM_OVERLAY_UPDATE',
    'MC_PRE_PLAYER_UPDATE','MC_INPUT_ACTION','MC_POST_RENDER'}}
for item,list in pairs(order)do for i,name in ipairs(list)do assert(rows[item][i][1]==ModCallbacks[name],item..':'..i)end end
assert(rows.revive_my_love[5][3]==Neverbirth.ReviveMyLoveTestAPI.ItemId)
assert(rows.revive_my_love[11][3]==3020)
assert(rows.healthy_sleep[8][3]==380 and rows.healthy_sleep[9][3]==380 and rows.healthy_sleep[11][3]==33)
for stage=1,26 do
    local before=Neverbirth;local partial,callbacks;local count=0
    local ok,err=pcall(loadMod,{OnInclude=enable,
        OnModCreated=function(m,c)partial,callbacks=m,c end,
        AfterRegister=function(_,_,fn)
            if parts[owner(fn)]then count=count+1;if count==stage then error('batch17 rollback injection')end end
        end})
    assert(not ok and tostring(err):find('batch17 rollback injection',1,true), 'stage '..stage..': '..tostring(err))
    assert(Neverbirth==before and partial.ReviveMyLoveTestAPI==nil,'rollback preserves previous export')
    for _,list in pairs(callbacks)do assert(#list==0,'failed installation retains callbacks')end
end
loadMod({OnInclude=enable})
print('batch17 loading: eight private modules, 26 ordered bindings/rollback stages, filters and fresh load passed')
