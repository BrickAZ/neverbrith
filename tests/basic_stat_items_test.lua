-- Real entry registrations, ordinary-data players. Engine clamping is native-only.
local loadMod = dofile('tests/support/neverbirth_fixture.lua')
local env = loadMod({ Root = arg and arg[1] })
local mod, ids = Neverbirth, env.itemIds
local food = assert(mod.DogFoodSeriesTestAPI).Callbacks.Evaluate
local selected = { [assert(mod.EvaluateEssentialBalm)] = true, [assert(mod.EvaluateWuhu)] = true, [food] = true }
local ordered = {}
for _,entry in ipairs(env.callbacks[ModCallbacks.MC_EVALUATE_CACHE]) do
    if selected[entry.fn] then ordered[#ordered+1] = entry.fn end
end
assert(#ordered==3, 'all three actual feature cache handlers must be installed exactly once')
assert(ordered[1]==mod.EvaluateEssentialBalm and ordered[2]==mod.EvaluateWuhu and ordered[3]==food,
    'preserve additive/override/tears conversion registration order')
local function near(a,b) assert(math.abs(a-b)<1e-9, tostring(a)..' ~= '..tostring(b)) end
local counts={}
local function evaluate(flag)
    local p={Damage=3.5,ShotSpeed=1,MoveSpeed=1,MaxFireDelay=9,TearRange=260,Luck=0,
        GetCollectibleNum=function(_,id) return counts[id] or 0 end}
    for _,fn in ipairs(ordered) do fn(mod,p,flag) end
    return p
end
counts[ids.EssentialBalm]=2
near(evaluate(CacheFlag.CACHE_DAMAGE).Damage,5.5)
near(evaluate(CacheFlag.CACHE_SHOTSPEED).ShotSpeed,0.6)
local color=evaluate(CacheFlag.CACHE_TEARCOLOR).TearColor
assert(color and color.G==1 and color.R==0.2)
counts[ids.Wuhu]=1
counts[ids.ProteinStrip]=2;counts[ids.EnergyKibble]=2;counts[ids.LeanCan]=2
counts[ids.DHAFishOil]=2;counts[ids.LuckyLiverBites]=2
for _=1,3 do
    near(evaluate(CacheFlag.CACHE_DAMAGE).Damage,45.8)
    near(evaluate(CacheFlag.CACHE_SHOTSPEED).ShotSpeed,-0.4)
    near(evaluate(CacheFlag.CACHE_SPEED).MoveSpeed,2.2)
    near(evaluate(CacheFlag.CACHE_RANGE or 64).TearRange,292)
    near(evaluate(CacheFlag.CACHE_LUCK or 1024).Luck,0.5)
    near(evaluate(CacheFlag.CACHE_FIREDELAY).MaxFireDelay,30/30.3-1)
    near(evaluate(CacheFlag.CACHE_DAMAGE).MaxFireDelay,0)
end
counts={}
near(evaluate(CacheFlag.CACHE_DAMAGE).Damage,3.5)
near(evaluate(CacheFlag.CACHE_SHOTSPEED).ShotSpeed,1)
near(evaluate(CacheFlag.CACHE_FIREDELAY).MaxFireDelay,9)
print('basic stat items passed: real registration, stacking, combinations, refresh, removal')
