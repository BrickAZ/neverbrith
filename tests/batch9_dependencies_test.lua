function include(name)return dofile(name:gsub('%.','/')..'.lua')end
EntityType={ENTITY_PICKUP=5};PickupVariant={PICKUP_COLLECTIBLE=100}
CacheFlag={CACHE_DAMAGE=1,CACHE_LUCK=2}
CollectibleType={};TrinketType={}
ModCallbacks={MC_USE_ITEM=1,MC_POST_PICKUP_INIT=2,MC_POST_PICKUP_MORPH=3,
    MC_EVALUATE_CACHE=4,MC_POST_UPDATE=5,MC_PRE_PICKUP_COLLISION=6}
local function build(seed)
    local root,mod,players,saves={unrelated={value=17}}, {}, {}, 0
    -- Keep the save root separate from the feature's replaceable section.
    local function section(name)
        return {Get=function()return root[name]end,Replace=function(v)root[name]=v end,Save=function()saves=saves+1 end}
    end
    mod={registered=0}
    function mod:AddCallback()self.registered=self.registered+1 end
    local deps={Store=section('crazyCoconut'),Items={CrazyCoconut=1,Condom=2,FortuneRivallingHeavenGu=3},
        GetCurrentRunSeed=function()return seed end,GetPlayers=function()return players end,
        IsValidItemId=function(id)return type(id)=='number' and id>0 end,Log=function()end,
        GetNeedletickLuckCap=function()return 10 end}
    local coconut=dofile('scripts/features/crazy_coconut.lua')(mod,deps)
    local condom=dofile('scripts/features/condom.lua')(mod,{Store=section('condom'),Items=deps.Items,GetCurrentRunSeed=deps.GetCurrentRunSeed})
    local fortune=dofile('scripts/features/fortune_rivalling_heaven_gu.lua')(mod,deps)
    assert(mod.registered==0,'constructing implementations must not register before the original install points')
    return {mod=mod,root=root,players=players,saveCount=function()return saves end,
        setSeed=function(v)seed=v end,coconut=coconut,condom=condom,fortune=fortune}
end
local a,b=build('run-a'),build('run-b')
local function player(env)
    local p={InitSeed=101,Damage=3.5,copies=1}
    function p:GetCollectibleNum(id)return id==1 and self.copies or 0 end
    function p:AddCacheFlags()end
    function p:EvaluateItems()end
    env.players[1]=p
    return p
end
local pa,pb=player(a),player(b)
a.mod:TrackCrazyCoconutCopies();b.mod:TrackCrazyCoconutCopies()
assert(a.root.crazyCoconut~=b.root.crazyCoconut and a.root.crazyCoconut.players['101']==1)
local replacement={runSeed='run-a',players={['101']=7},playerCounts={['101']=1},pending={},naturalDamage={},extension='preserve'}
a.root.crazyCoconut=replacement
local oldSaves=a.saveCount()
a.mod:TrackCrazyCoconutCopies()
assert(a.mod:GetCrazyCoconutData()==replacement and replacement.players['101']==7 and a.saveCount()==oldSaves)
assert(b.root.crazyCoconut.players['101']==1,'identical player seeds in distinct installations stay isolated')
local bans=a.mod:GetCondomData();bans.banned['77']=true
assert(not b.mod:IsCondomBanned(77))
a.setSeed('next-run')
a.mod:TrackCrazyCoconutCopies()
assert(a.root.crazyCoconut~=replacement and replacement.players['101']==7 and replacement.extension=='preserve')
assert(a.root.crazyCoconut.players['101']==1 and a.root.unrelated.value==17)
assert(not a.mod:IsCondomBanned(77) and bans.banned['77']==true,'new seed replaces the region without mutating its old view')
assert(a.mod:RegisterLuckCap(90,12) and a.mod:RegisterLuckCap(90,7))
assert(#a.mod.FortuneRivallingHeavenGu.luckCaps.collectible[90]==2)
assert(b.mod.FortuneRivallingHeavenGu.luckCaps.collectible[90]==nil)
a.coconut.InstallEvaluateCrazyCoconut();a.coconut.InstallTrackCrazyCoconutCopies();a.coconut.InstallHandleCrazyCoconutCollectiblePickup()
a.condom.InstallPickupInit();a.condom.InstallPickupMorph();a.condom.InstallUseCondom()
assert(a.mod.registered==6 and b.mod.registered==0)
print('batch9 dependencies: isolated factories, deferred callbacks, live Store replacement, old-view preservation, new seed and independent append-only luck registry passed')
