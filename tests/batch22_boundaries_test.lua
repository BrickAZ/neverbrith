local factory = dofile('scripts/features/debug_controller.lua')
local ids = {MC_USE_ITEM=1,MC_POST_UPDATE=2,MC_POST_RENDER=3,MC_POST_FIRE_TEAR=4,
    MC_POST_NEW_LEVEL=5,MC_POST_GAME_STARTED=6,MC_PRE_GAME_EXIT=7,MC_PRE_MOD_UNLOAD=8}
ModCallbacks=ids
Vector=function(x,y) return {X=x,Y=y} end
local function create()
    local mod, callbacks = {}, {}
    function mod:AddCallback(id,fn,filter) callbacks[#callbacks+1]={id=id,fn=fn,filter=filter} end
    local api=factory(mod,{Items={DebugController=17},IsValidItemId=function(id) return id and id>0 end})
    assert(#callbacks==0, 'construction must not register outside explicit phases')
    for _,phase in ipairs({'Use','Update','Render','Tear','Level','GameStarted'}) do api['Install'..phase]() end
    assert(#callbacks==8 and callbacks[1].filter==17, 'six phases plus optional exit/unload bindings')
    for i,row in ipairs(callbacks) do assert(row.id==i,'native binding order changed') end
    local function call(id,...)
        for _,row in ipairs(callbacks) do if row.id==id then row.fn(mod,...) end end
    end
    return mod,call
end
local function player(seed)
    return {InitSeed=seed,owned=true,HasCollectible=function(self)return self.owned end,
        IsDead=function(self)return self.dead==true end}
end
local function removed(mod,p)
    local tear={SpawnerEntity=p,Remove=function(self) self.removed=true end}
    mod:SuppressDebugControllerTear(tear)
    return tear.removed==true
end
local a,call=create()
local p,q=player(1),player(2)
a:UseDebugController(nil,nil,p)
assert(removed(a,p) and not removed(a,q), 'menus and suppression belong to one player')
p.owned=false;call(ids.MC_POST_UPDATE)
assert(not removed(a,p),'loss of the controller must close its menu')
p.owned=true;a:UseDebugController(nil,nil,p);p.dead=true;call(ids.MC_POST_UPDATE)
assert(not removed(a,p),'death must close its menu')
p.dead=false;a:UseDebugController(nil,nil,p);call(ids.MC_POST_NEW_LEVEL)
assert(not removed(a,p),'level boundary must clear menus')
for _,continued in ipairs({false,true}) do
    a:UseDebugController(nil,nil,p);call(ids.MC_POST_GAME_STARTED,continued)
    assert(not removed(a,p),'new/continued runs must not retain transient UI')
end
a:UseDebugController(nil,nil,p);call(ids.MC_PRE_GAME_EXIT,true)
a:UseDebugController(nil,nil,p)
assert(not removed(a,p),'exit must disable retained callbacks')
call(ids.MC_POST_GAME_STARTED,true);a:UseDebugController(nil,nil,p)
assert(removed(a,p),'new run callback must reactivate the same non-disposed instance')
call(ids.MC_PRE_MOD_UNLOAD,{})
assert(removed(a,p),'unloading another mod must not close this instance')
call(ids.MC_PRE_MOD_UNLOAD,a);call(ids.MC_PRE_MOD_UNLOAD,a)
call(ids.MC_POST_GAME_STARTED,false);a:UseDebugController(nil,nil,p)
assert(not removed(a,p),'disposed instance cannot reactivate')
local b=create();b:UseDebugController(nil,nil,p)
assert(removed(b,p) and not removed(a,p),'new installation owns independent UI state')
for _,deps in ipairs({{IsValidItemId=function()end},{Items={}}}) do
    local n=0
    local ok=pcall(factory,{AddCallback=function()n=n+1 end},deps)
    assert(not ok and n==0,'missing required dependencies fail before registration')
end
print('batch22 boundaries: phase order, owner isolation, loss/death/level/run/continue/exit/unload and missing dependencies passed')
