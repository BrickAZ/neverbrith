-- Actual feature factories; only the native player surfaces are simulated.
function include(name) return dofile(name:gsub('%.', '/') .. '.lua') end
ModCallbacks = { MC_POST_UPDATE=1, MC_POST_GAME_STARTED=2, MC_PRE_GAME_EXIT=3,
    MC_PRE_MOD_UNLOAD=4, MC_POST_NEW_ROOM=5 }
CollectibleType, TrinketType, CacheFlag = {}, {}, { CACHE_LUCK=1024 }
Isaac = { GetCostumeIdByPath=function() return 101 end }
local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed=passed+1; print('PASS '..name)
    else failed=failed+1; print('FAIL '..name..': '..tostring(err)) end
end
local function valid(id) return type(id)=='number' and id>0 end
local function fortune(mod, provider)
    return include('scripts.features.fortune_rivalling_heaven_gu')(mod, {
        Items={Needletick=777, FortuneRivallingHeavenGu=778},
        GetPlayers=function() return {} end, IsValidItemId=valid,
        Log=function() end, GetNeedletickLuckCap=provider,
    })
end
local function registeredCap(mod)
    return mod.FortuneRivallingHeavenGu.luckCaps.collectible[777][1].fixedCap
end
test('fortune consumes the explicit provider, never a peer public field', function()
    local mod, cap, reads = {NeedletickLuckCap=999}, 23, 0
    fortune(mod, function() reads=reads+1; return cap end)
    assert(registeredCap(mod)==23 and reads==1)
    mod.NeedletickLuckCap=nil; cap=17
    mod:RegisterVerifiedFortuneLuckCaps()
    assert(registeredCap(mod)==17 and reads==2, 're-registration must query the current provider')
end)
test('missing or non-callable fortune dependency fails before publication', function()
    for _, value in ipairs({false, 10}) do
        local mod={sentinel={}}
        local ok=pcall(fortune, mod, value or nil)
        assert(not ok and mod.FortuneRivallingHeavenGu==nil and mod.RegisterLuckCap==nil)
    end
end)
test('needletick returns an instance query and retains its chance/compatibility contract', function()
    local function create()
        local mod={}; function mod:AddCallback() error('no tear callbacks enabled in this fixture') end
        local api=include('scripts.features.needletick')(mod,{ItemId=777,IsValidItemId=valid})
        return mod,api
    end
    local a,aa=create(); local b,bb=create()
    assert(type(aa)=='table' and type(aa.GetLuckCap)=='function')
    assert(aa.GetLuckCap()==10 and bb.GetLuckCap()==10)
    assert(a.GetNeedletickChance(-3)==0.05 and a.GetNeedletickChance(10)==0.15)
    a.NeedletickLuckCap=23
    assert(aa.GetLuckCap()==23 and bb.GetLuckCap()==10 and a.GetNeedletickChance(23)==0.15)
    local consumer={NeedletickLuckCap=999}; fortune(consumer,aa.GetLuckCap)
    assert(registeredCap(consumer)==23)
end)

local function createLaxative()
    local env={players={}, callbacks={}, mod={StrongLaxative={}}}
    function env.mod:AddCallback(id, fn) env.callbacks[id]=fn end
    local private={}
    local config={CostumePath='diagnostic',PoopRollInterval=60,CreepInterval=4}
    local function key(p) return tostring(p.InitSeed) end -- existing folk_world contract
    local appearance=include('scripts.features.strong_laxative.presentation')(env.mod, {
        Private=private,Config=config,GetPlayerKey=key,ItemId=1,
    })
    local runtime=include('scripts.features.strong_laxative.players')(env.mod, {
        Private=private,Config=config,ItemId=1,GetPlayerKey=key,
        IsValidItemId=valid,PlayerHasCollectible=function(p) return p.copies>0 end,
        GetPlayers=function() return env.players end,
        ResetPoopRoom=function() end,ResetPoopRuntime=function() end,
        ResetPresentation=appearance.ResetRuntime,ResetCreep=function() end,
    })
    runtime.InstallUpdateCallback();runtime.InstallRoomCallback();runtime.InstallLifecycle()
    function env.update() env.callbacks[ModCallbacks.MC_POST_UPDATE](env.mod) end
    function env.event(id, ...) env.callbacks[id](env.mod, ...) end
    return env
end
local function player(seed, body)
    body=body or {adds=0,removes=0,exists=true}
    local p={InitSeed=seed,copies=1,body=body}
    function p:GetData() return self.body end
    function p:GetCollectibleNum() return self.copies end
    function p:Exists() return self.body.exists end
    function p:AddNullCostume() self.body.adds=self.body.adds+1 end
    function p:TryRemoveNullCostume() self.body.removes=self.body.removes+1 end
    return p
end
test('same-key replacement receives its costume without resetting gameplay clocks', function()
    local env=createLaxative(); local old,fresh=player(7),player(7)
    env.players={old};env.update()
    local state=env.mod.StrongLaxative.GetState(old);state.creepCooldown=3;state.poopTimer=19
    env.players={fresh};env.update()
    assert(old.body.adds==1 and fresh.body.adds==1, 'fresh body must receive costume')
    assert(env.mod.StrongLaxative.GetState(fresh)==state and state.creepCooldown==2 and state.poopTimer==20)
end)
test('different wrappers for one body do not repeatedly remove and add costume', function()
    local env=createLaxative(); local a=player(7)
    env.players={a};env.update()
    for _=1,12 do env.players={player(7,a.body)};env.update() end
    assert(a.body.adds==1 and a.body.removes==1)
end)
test('appearance is body-owned even when player keys collide or one body returns', function()
    local env=createLaxative();local a,b=player(7),player(7)
    env.mod.StrongLaxative.ApplyCostume(a,true);env.mod.StrongLaxative.ApplyCostume(b,true)
    env.mod.StrongLaxative.ApplyCostume(a,true)
    assert(a.body.adds==1 and b.body.adds==1)
    env.mod.StrongLaxative.ApplyCostume(b,false)
    assert(b.body.removes==2 and a.body.removes==1)
    env.mod.StrongLaxative.ApplyCostume(b,false);env.mod.StrongLaxative.ApplyCostume(b,true)
    assert(b.body.removes==3 and b.body.adds==2)
end)
test('new game, continue and room reset preserve their existing clock and costume policies', function()
    local env=createLaxative();local a,b=player(7),player(7)
    env.players={a};env.update();env.players={b};env.update()
    env.event(ModCallbacks.MC_POST_NEW_ROOM);env.update()
    assert(b.body.adds==1 and env.mod.StrongLaxative.GetState(b).poopTimer==1)
    env.event(ModCallbacks.MC_POST_GAME_STARTED,false)
    assert(a.body.removes==2 and b.body.removes==2, 'all still-live owned bodies are cleaned')
    env.update();assert(b.body.adds==2 and env.mod.StrongLaxative.GetState(b).poopTimer==1)
    env.event(ModCallbacks.MC_POST_GAME_STARTED,true);env.update();assert(b.body.adds==3)
end)
test('exit and unload clean live owners, tolerate removed owners and stop updates', function()
    local env=createLaxative();local a,b=player(7),player(7)
    env.players={a};env.update();a.body.exists=false
    env.players={b};env.update();env.event(ModCallbacks.MC_PRE_GAME_EXIT,true)
    assert(a.body.removes==1 and b.body.removes==2)
    env.update();assert(b.body.adds==1)
    env.event(ModCallbacks.MC_POST_GAME_STARTED,false);env.update()
    env.event(ModCallbacks.MC_PRE_MOD_UNLOAD,{}) -- another mod cannot dispose this instance
    env.update();assert(b.body.adds==2)
    env.event(ModCallbacks.MC_PRE_MOD_UNLOAD,env.mod);env.update()
    env.event(ModCallbacks.MC_POST_GAME_STARTED,false);env.update()
    assert(b.body.adds==2 and b.body.removes==4)
end)
test('real main injects the one installed needletick query into fortune', function()
    local original=dofile
    local provided,owned,installs=nil,nil,0
    function dofile(path)
        local loaded=original(path)
        if path=='scripts/features/needletick.lua' then
            return function(...)
                installs=installs+1;local api=loaded(...);owned=api.GetLuckCap;return api
            end
        elseif path=='scripts/features/fortune_rivalling_heaven_gu.lua' then
            return function(mod,deps) provided=deps.GetNeedletickLuckCap;return loaded(mod,deps) end
        end
        return loaded
    end
    local ok,env=pcall(function() return dofile('tests/support/neverbirth_fixture.lua')() end)
    dofile=original
    assert(ok,env)
    assert(installs==1 and type(owned)=='function' and provided==owned and provided()==10)
    local mod=Neverbirth
    mod.NeedletickLuckCap=23;mod:RegisterVerifiedFortuneLuckCaps()
    assert(provided()==23 and mod.FortuneRivallingHeavenGu.luckCaps.collectible[env.itemIds.Needletick][1].fixedCap==23)
end)
print(string.format('fortune/laxative boundaries: %d passed, %d failed',passed,failed))
assert(failed==0)
