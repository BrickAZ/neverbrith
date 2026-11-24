-- Real Yin module and registration, simulated API. Not evidence of Isaac play.
ModCallbacks={MC_PRE_PLAYER_EXPLOSION_IMMUNITY=1485,MC_POST_UPDATE=1}
CollectibleType={COLLECTIBLE_BLACK_CANDLE=260}
local function setup(version,callbackId)
    ModCallbacks.MC_PRE_PLAYER_EXPLOSION_IMMUNITY=callbackId
    local logs,callbacks,root={},{},{}
    Isaac={DebugString=function(s) logs[#logs+1]=s end,GetRoomEntities=function() return {} end}
    if version~=nil then Isaac.GetPlayerExplosionImmunityAPIVersion=function()
        if version=='throws' then error('capability query failed') end
        return version
    end end
    local mod={};function mod:AddCallback(id,fn,filter) callbacks[id]={fn=fn,filter=filter} end
    dofile('yins_curse.lua')(mod,{ItemId=9000,GetSaveRoot=function()return root end,
        GetPlayers=function()return {} end,GetCurrentRunSeed=function()return 'test' end})
    return mod.YinsCurseTestAPI,callbacks,logs,root
end
local function player(candle)
    return {candle=candle,HasCollectible=function(self,id)return id==260 and self.candle end}
end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local count=0
local function test(name,fn) fn();count=count+1;print('PASS '..name) end
test('register_only_complete_capability',function()
    local api,cb=setup(1,1485);assert(cb[1485],'complete native API must register Yin');eq(cb[1485].filter,nil)
    for _,version in ipairs({0,2,'1',false,'throws'}) do
        local _,missing,logs=setup(version,1485);eq(missing[1485],nil);assert(missing[1]);eq(#logs,1)
    end
    local _,cb2,logs=setup(nil,1485);eq(cb2[1485],nil);eq(#logs,1)
    local _,cb3=setup(1,nil);eq(cb3[1485],nil)
end)
test('four_candle_source_combinations_and_inactive',function()
    local api,cb=setup(1,1485);local handler=assert(cb[1485]).fn
    local h={callId=1,damage=2,flags=4,source={Type=1},countdown=12}
    local immunity={reason='EXPLOSION_IMMUNITY',sourceKey='any-native-source'}
    api.ResetForTest('test');eq(handler(nil,player(false),h,immunity),nil)
    api.RecordFirstAcquisition(player(false));eq(handler(nil,player(false),h,immunity),false)
    eq(handler(nil,player(true),h,immunity),nil)
    local function nativeDecision(candle,eligible)
        if not eligible then return 'continue_original_damage' end
        return handler(nil,player(candle),h,immunity)==false and 'continue_original_damage' or 'original_immunity'
    end
    eq(nativeDecision(false,false),'continue_original_damage')
    eq(nativeDecision(true,false),'continue_original_damage')
    eq(nativeDecision(false,true),'continue_original_damage')
    eq(nativeDecision(true,true),'original_immunity')
    -- Source absence means native never invokes the interface. The handler also
    -- ignores unknown reasons, without granting immunity or touching hit values.
    eq(handler(nil,player(true),h,{reason='FIRE_IMMUNITY'}),nil)
    eq(handler(nil,player(false),h,{reason='FIRE_IMMUNITY'}),nil)
    eq(h.damage,2);eq(h.flags,4);eq(h.source.Type,1);eq(h.countdown,12)
end)
test('eid_reports_the_loaded_capability_in_both_languages',function()
    local f=assert(io.open('main.lua','rb'));local text=f:read('*a');f:close()
    local first=assert(text:find('local yinExplosionApiReady = false',1,true))
    local last=assert(text:find('local EID_DESCRIPTIONS = {',first,true))
    local begin=assert(text:find('[Items.YinsCurse] = {',last,true))
    local finish=assert(text:find('[Items.ACEAntiCheatSystem] = {',begin,true))
    for _,v in ipairs({0,1}) do
        local env={pcall=pcall,type=type,Items={YinsCurse=1},Isaac={GetPlayerExplosionImmunityAPIVersion=function()return v end}}
        local entries=assert(load(text:sub(first,last-1)..'return {'..text:sub(begin,finish-1)..'}','@actual-yin-eid','t',env))()
        local en,zh=entries[1].en_us.eidDescription,entries[1].zh_cn.eidDescription
        if v==1 then assert(en:find('Blocks explosion immunity',1,true));assert(zh:find('封锁爆炸免疫',1,true))
        else assert(en:find('Existing explosion immunity still works',1,true));assert(zh:find('已有防爆效果目前仍会生效',1,true)) end
    end
end)
test('coop_candle_is_target_local_and_live',function()
    local api,cb=setup(1,1485);local handler=cb[1485].fn
    local a,b=player(true),player(false);api.ResetForTest('test');api.RecordFirstAcquisition(a)
    local i={reason='EXPLOSION_IMMUNITY',sourceKey='PLAYER_BABY_SKIN_20'}
    eq(handler(nil,b,{},i),false);eq(handler(nil,a,{},i),nil)
    a.candle=false;b.candle=true
    eq(handler(nil,b,{},i),nil);eq(handler(nil,a,{},i),false)
    eq(api.GetSavedState().q4Mode,'bonus_root')
end)
test('saved_activation_survives_runtime_reset_and_root_reload',function()
    local api,cb,_,root=setup(1,1485);api.ResetForTest('test');api.RecordFirstAcquisition(player(false))
    root.yinCurse.firstQ4Resolved=true;api.ResetRuntimeOnly()
    eq(cb[1485].fn(nil,player(false),{},{reason='EXPLOSION_IMMUNITY'}),false)
    eq(root.yinCurse.q4Mode,'replace_root');eq(root.yinCurse.firstQ4Resolved,true)
end)
print('YIN_EXPLOSION_TESTS '..count)
