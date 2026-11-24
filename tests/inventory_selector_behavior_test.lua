-- Engine globals are boundary doubles; all selection/input/lifecycle logic runs the real module.
local function eq(a,b,m) assert(a==b,(m or 'mismatch')..': expected '..tostring(b)..', got '..tostring(a)) end
ModCallbacks={MC_POST_PLAYER_UPDATE=1,MC_INPUT_ACTION=2,MC_POST_RENDER=3,MC_POST_NEW_ROOM=4,MC_POST_NEW_LEVEL=5,MC_PRE_GAME_EXIT=6,MC_POST_GAME_END=7,MC_POST_GAME_STARTED=8,MC_EXECUTE_CMD=9,MC_POST_UPDATE=10,MC_PRE_MOD_UNLOAD=11}
InputHook={IS_ACTION_PRESSED=0,IS_ACTION_TRIGGERED=1,GET_ACTION_VALUE=2}
ButtonAction={ACTION_LEFT=0,ACTION_RIGHT=1,ACTION_UP=2,ACTION_DOWN=3,ACTION_SHOOTLEFT=4,ACTION_SHOOTRIGHT=5,ACTION_SHOOTUP=6,ACTION_SHOOTDOWN=7,ACTION_BOMB=8,ACTION_ITEM=9,ACTION_PILLCARD=10,ACTION_DROP=11,ACTION_PAUSE=12,ACTION_MAP=13,ACTION_MENUCONFIRM=14,ACTION_MENUBACK=15,ACTION_MENULEFT=20,ACTION_MENURIGHT=21,ACTION_MENUUP=22,ACTION_MENUDOWN=23}
local factory=assert(loadfile('inventory_selector.lua'),'inventory selector module must exist')()
local function fixture(noState)
    local f={callbacks={},pressed={},triggered={},draws={},sprites={},logs={},players={},room='r1',floor='f1'}
    local game={IsPaused=function() return f.paused==true end,GetLevel=function() return {GetStage=function() return 1 end,GetStageType=function() return 0 end,GetCurrentRoomIndex=function() return 1 end} end}
    Game=function() return game end
    Vector=function(x,y) return {X=x,Y=y} end
    Sprite=function()
        local s={}
        function s:Load(path) self.path=path end
        function s:ReplaceSpritesheet(layer,path) self.gfx=path end
        function s:LoadGraphics() end
        function s:SetFrame(name,frame) end
        function s:Render(pos) f.sprites[#f.sprites+1]={sprite=self,pos=pos} end
        function s:RenderLayer(layer,pos) f.sprites[#f.sprites+1]={sprite=self,pos=pos,layer=layer} end
        return s
    end
    Isaac={GetScreenWidth=function() return 480 end,GetScreenHeight=function() return 300 end}
    local function read(action,controller,hook)
        -- Deliberately model recursive engine input calls: self-interception must be bypassed.
        local override=f:call(ModCallbacks.MC_INPUT_ACTION,f.players[controller+1],hook,action)
        if override~=nil then return override end
        if hook==InputHook.GET_ACTION_VALUE then return (f.pressed[controller] or {})[action] and 1 or 0 end
        return ((hook==InputHook.IS_ACTION_TRIGGERED and f.triggered or f.pressed)[controller] or {})[action]==true
    end
    Input={IsActionPressed=function(a,c) return read(a,c,0) end,IsActionTriggered=function(a,c) return read(a,c,1) end,GetActionValue=function(a,c) return read(a,c,2) end}
    local mod={}
    function mod:AddCallback(id,fn) f.callbacks[id]=fn end
    function f:call(id,...) if self.callbacks[id] then return self.callbacks[id](mod,...) end end
    function f:player(index,entries)
        local p={ControllerIndex=index,InitSeed=index+100,entries=entries or {},alive=true,exists=true,ControlsEnabled=true}
        function p:ToPlayer() return self end
        function p:IsDead() return not self.alive end
        function p:Exists() return self.exists end
        self.players[index+1]=p; return p
    end
    local context={State={PlayerKey=function(p) return tostring(p.InitSeed) end,RoomKey=function() return f.room end,FloorKey=function() return f.floor end},GetPlayers=function() return f.players end,GetEntries=function(p) if f.entriesError then error('entry fault') end return p.entries end,DebugLog=function(s) f.logs[#f.logs+1]=s end,RenderText=function(s,x,y) if f.renderError then error('render fault') end f.draws[#f.draws+1]={text=s,x=x,y=y} end}
    f.state=context.State
    if noState then context.State=nil end
    factory(mod,context); f.api=mod.InventorySelector
    function f:tick(p,action)
        self.triggered[p.ControllerIndex]=action and {[action]=true} or {}
        self:call(ModCallbacks.MC_POST_PLAYER_UPDATE,p)
        self.triggered[p.ControllerIndex]={}
    end
    return f
end
local function entry(id,count,temp,order) return {id=id,count=count or 1,temporaryCount=temp or 0,name='Item '..id,gfx='item'..id..'.png',type=1,order=order or id} end
local tests={}
function tests.merge_order_and_operation()
    local f=fixture(); local p=f:player(0,{entry(2,1,0,5),entry(1,2,1,3),entry(1,1,1,4)})
    eq(f.api.Open(p,{title='Inspect',execute=function() return true end}),true)
    local s=f.api.GetSession(p);eq(#s.entries,2);eq(s.entries[1].id,1);eq(s.entries[1].count,3);eq(s.entries[1].temporaryCount,2)
    f:call(ModCallbacks.MC_POST_RENDER); local all='';for _,d in ipairs(f.draws) do all=all..d.text end
    assert(all:find('Inspect',1,true));assert(all:find('Item 1',1,true));assert(all:find('3',1,true));assert(#f.sprites>0,'icons and selected frame render')
    eq(p.ControlsEnabled,true,'no blanket player controls mutation')
end
function tests.owner_inputs_and_release()
    local f=fixture();local a=f:player(0,{entry(1),entry(2)});local b=f:player(1,{entry(3),entry(4)})
    local picked={};local request={title='Inspect',execute=function(p,e) picked[p.ControllerIndex]=e.id return true end}
    f.api.Open(a,request);f.api.Open(b,request);f:tick(a,21)
    eq(f.api.GetSession(a).selected,2);eq(f.api.GetSession(b).selected,1)
    eq(f:call(2,a,2,4),0);eq(f:call(2,b,0,4),false);eq(f:call(2,a,0,13),nil,'map unaffected')
    local outsider=f:player(2,{entry(9)});eq(f:call(2,outsider,0,4),nil)
    f.pressed[0]={[14]=true,[4]=true};f:tick(a,14);eq(picked[0],2);eq(picked[1],nil);eq(f.api.GetSession(a),nil)
    eq(f:call(2,a,0,4),false,'closing key does not leak attack');f:tick(a);eq(f:call(2,a,0,4),false)
    f.pressed[0]={};f:tick(a);eq(f:call(2,a,0,4),nil,'released owner restored');eq(f:call(2,b,0,4),false,'other owner still selecting')
end
function tests.confirm_revalidates_target_and_counts()
    local f=fixture();local p=f:player(0,{entry(1,3,2)});local result
    f.api.Open(p,{execute=function(_,e) result=e return true end});p.entries={entry(1,2,1)};f:tick(p,14)
    eq(result.count,2);eq(result.temporaryCount,1)
    f:tick(p);local called=0;local reason
    f.api.Open(p,{execute=function() called=called+1 return true end,onCancel=function(r) reason=r end});p.entries={};f:tick(p,14)
    eq(called,0);eq(reason,'target_invalid');eq(f.api.GetSession(p),nil)
end
function tests.caller_and_eligibility_revalidated()
    for _,field in ipairs({'valid','eligible'}) do
        local f=fixture();local p=f:player(0,{entry(1)});local allowed=true;local calls=0;local why
        local request={execute=function() calls=calls+1 return true end,onCancel=function(r) why=r end};request[field]=function() return allowed end
        f.api.Open(p,request);allowed=false;f:tick(p,14);eq(calls,0);eq(why,field=='valid' and 'caller_invalid' or 'target_invalid')
    end
end
function tests.failure_and_callback_error_cleanup()
    for _,mode in ipairs({'false','execute','eligible','valid','entries','render','cancel'}) do
        local f=fixture();local p=f:player(0,{entry(1)});local cancellations=0;local broken=false
        local request={execute=function() if mode=='execute' then error('execute fault') end return false end,onCancel=function() cancellations=cancellations+1 if mode=='cancel' then error('cancel fault') end end}
        if mode=='valid' or mode=='eligible' then request[mode]=function() if broken then error('predicate fault') end return true end end
        f.api.Open(p,request);broken=true
        if mode=='entries' then f.entriesError=true end
        if mode=='render' then f.renderError=true;f:call(3) elseif mode=='cancel' then f.api.Close(p,'cancel') else f:tick(p,14) end
        eq(f.api.GetSession(p),nil,mode..' cleaned');eq(cancellations,1,mode..' notified once');f:tick(p);eq(f:call(2,p,0,4),nil,mode..' released')
    end
end
function tests.lifecycle_cancellation()
    for _,mode in ipairs({'back','room','floor','death','removed','exit','end','reload','unload','roomkey','floorkey'}) do
        local f=fixture();local p=f:player(0,{entry(1)});local cancelled=0;local calls=0
        f.api.Open(p,{execute=function() calls=calls+1 return true end,onCancel=function() cancelled=cancelled+1 end})
        if mode=='back' then f:tick(p,15)
        elseif mode=='death' then p.alive=false;f:tick(p)
        elseif mode=='removed' then p.exists=false;f:call(10)
        elseif mode=='roomkey' then f.room='r2';f:tick(p)
        elseif mode=='floorkey' then f.floor='f2';f:tick(p)
        else f:call(({room=4,floor=5,exit=6,['end']=7,reload=8,unload=11})[mode]) end
        eq(f.api.GetSession(p),nil,mode);eq(cancelled,1,mode);eq(calls,0,mode);f:tick(p);eq(f:call(2,p,0,4),nil,mode..' cleanup')
    end
end
function tests.pagination_and_pause()
    local f=fixture();local entries={};for i=1,30 do entries[i]=entry(i) end;local p=f:player(0,entries)
    local selected;f.api.Open(p,{execute=function(_,e) selected=e.id return true end})
    for i=1,12 do f:tick(p,21) end
    local s=f.api.GetSession(p);eq(s.selected,13);eq(s.page,2)
    f.paused=true;f:tick(p,14);eq(selected,nil);eq(f.api.GetSession(p),s)
    f.paused=false;f:tick(p,14);eq(selected,13)
end
function tests.no_implicit_operation_and_debug()
    local f=fixture();local p=f:player(0,{entry(42)});eq(f.api.Open(p,{}),false);eq(f:call(2,p,0,4),nil)
    eq(f.api.Open(p,{execute=function() return true end,eligible=function() return false end}),false)
    f:call(9,'inventory_selector','0');assert(f.api.GetSession(p));f:tick(p,14)
    eq(p.entries[1].count,1);local all=table.concat(f.logs,'\n');assert(all:find('42',1,true),'debug logs selected ID')
end
function tests.opening_held_input_requires_a_new_press()
    local f=fixture();local p=f:player(0,{entry(1),entry(2)});local calls=0
    f.pressed[0]={[14]=true,[21]=true};f.api.Open(p,{execute=function() calls=calls+1 return true end})
    f:tick(p,14);eq(calls,0);eq(f.api.GetSession(p).selected,1)
    f:tick(p,21);eq(f.api.GetSession(p).selected,1)
    f.pressed[0]={};f:tick(p);f:tick(p,21);eq(f.api.GetSession(p).selected,2)
    f:tick(p,14);eq(calls,1)
end
function tests.four_player_panels_keep_text_on_screen()
    local f=fixture()
    for i=0,3 do local p=f:player(i,{entry(i+1)});f.api.Open(p,{title='Inspect',execute=function() return true end}) end
    f:call(3)
    for _,d in ipairs(f.draws) do assert(d.y>=0 and d.y<300,'four player text remains in viewport: '..d.y) end
end
function tests.native_boundary_without_shared_state()
    local f=fixture(true);local p=f:player(0,{entry(1)})
    eq(f.api.Open(p,{execute=function() return true end}),true,'verified native room boundary needs no unknown dimension method')
    f:call(4);eq(f.api.GetSession(p),nil)
end
function tests.shared_controller_cannot_advance_two_owners()
    local f=fixture();local a=f:player(0,{entry(1)});local b=f:player(1,{entry(2)});b.ControllerIndex=0
    local request={execute=function() return true end};eq(f.api.Open(a,request),true)
    eq(f.api.Open(b,request),false,'one controller has one input owner')
end
function tests.shared_canonical_identity_does_not_mix_physical_selection_owners()
    local f=fixture();local a=f:player(0,{entry(1)});local b=f:player(1,{entry(2)})
    f.state.PlayerKey=function() return 'canonical' end
    f.state.InventoryPlayerKey=function(p) return tostring(p.InitSeed) end
    local request={execute=function() return true end}
    eq(f.api.Open(a,request),true);eq(f.api.Open(b,request),true,'physical selectors are independent')
    eq(f.api.GetSession(a).entries[1].id,1);eq(f.api.GetSession(b).entries[1].id,2)
end
function tests.caller_storage_and_active_confirmation()
    local f=fixture();local p=f:player(0,{entry(999)});local received
    local stored={{id=71,count=1,name='Rock',spritePath='gfx/grid/grid_rock.anm2',animation='Idle',payload={kind='rock'}},
        {id=72,count=1,name='Priced item',payload={price=-2}}}
    f.pressed[0]={[9]=true}
    eq(f.api.Open(p,{getEntries=function()return stored end,confirmAction=9,
        execute=function(_,e)received=e return true end}),true)
    eq(f.api.GetSession(p).entries[1].id,71,'caller entries replace held inventory')
    f:tick(p,9);eq(received,nil,'opening active key cannot confirm')
    f.pressed[0]={};f:tick(p);f:tick(p,21);f:tick(p,9)
    eq(received.id,72);eq(received.payload.price,-2)
    eq(f.api.IsBlocking(p),true,'release guard remains after closing')
    f:tick(p);eq(f.api.IsBlocking(p),false)
end
local names={};for n in pairs(tests) do names[#names+1]=n end;table.sort(names)
for _,n in ipairs(names) do tests[n]();print('PASS '..n) end
print('inventory_selector_behavior_test: '..#names..' cases passed')
