local sharedCalls={}
function include(name)
    local api=dofile(name:gsub('%.','/')..'.lua')
    if name=='scripts.systems.null_costumes' then
        for method,implementation in pairs(api) do
            api[method]=function(...)
                sharedCalls[method]=(sharedCalls[method] or 0)+1
                return implementation(...)
            end
        end
    end
    return api
end
local calls,lookups={},{}
Isaac={GetCostumeIdByPath=function(path)lookups[path]=(lookups[path] or 0)+1;return path:find('broken',1,true) and 102 or 101 end}
local p={InitSeed=7,TryRemoveNullCostume=function(_,id)calls[#calls+1]='remove:'..id end,
    AddNullCostume=function(_,id)calls[#calls+1]='add:'..id end}
local function key(player)return tostring(player.InitSeed)end
local mask=include('scripts.features.coin_faced_mask.presentation')({}, {GetPlayerKey=key})
local good={GoodGirl={costumeStates={},CostumePath='good'}}
local girl=include('scripts.features.good_girl_of_babylon.presentation')(good,{World={GetFolkPlayerKey=key},VisualEffects={}})
local strong={StrongLaxative={}}
include('scripts.features.strong_laxative.presentation')(strong,{Config={CostumePath='strong'},GetPlayerKey=key,ItemId=1})
mask.Apply(p,'active');girl.ApplyGoodGirlCostume(p,true);strong.StrongLaxative.ApplyCostume(p,true)
local first=#calls
for _=1,10 do mask.Apply(p,'active');girl.ApplyGoodGirlCostume(p,true);strong.StrongLaxative.ApplyCostume(p,true)end
assert(#calls==first and lookups.good==1 and lookups.strong==1, 'all three actual consumers skip unchanged state')
assert(sharedCalls.Transition==33 and sharedCalls.GetCachedId==4 and sharedCalls.Add==3, 'all consumers execute the common operations')
mask.Apply(p,'broken');assert(calls[#calls]=='add:102')
mask.ClearPlayerCostume(p);mask.ResetRuntime();mask.Apply(p,'active')
assert(lookups['gfx/characters/costume_coin_faced_mask.anm2']==1, 'mask runtime reset keeps resource cache')
good.GoodGirl.costumeStates={};girl.ApplyGoodGirlCostume(p,true)
assert(lookups.good==1, 'GoodGirl reads the replacement state table')
local oldRemove=strong.StrongLaxative.RemoveCostume
local dynamicCalls=0
strong.StrongLaxative.RemoveCostume=function(...)dynamicCalls=dynamicCalls+1;oldRemove(...)end
strong.StrongLaxative.ApplyCostume(p,false);assert(dynamicCalls==1, 'public dynamic dispatch remains live')

-- Rebinding during the native operation must update the new state table.
local previous=good.GoodGirl.costumeStates
p.AddNullCostume=function()good.GoodGirl.costumeStates={}end
girl.ApplyGoodGirlCostume(p,false);girl.ApplyGoodGirlCostume(p,true)
assert(good.GoodGirl.costumeStates~=previous and good.GoodGirl.costumeStates['7']=='presentable')

-- Missing API is retryable for the mask but negatively cached by GoodGirl/Laxative.
Isaac={};p.AddNullCostume=function()end
local mask2=include('scripts.features.coin_faced_mask.presentation')({}, {GetPlayerKey=key})
local missing={GoodGirl={costumeStates={},CostumePath='missing'}}
local girl2=include('scripts.features.good_girl_of_babylon.presentation')(missing,{World={GetFolkPlayerKey=key},VisualEffects={}})
local strong2={StrongLaxative={}}
include('scripts.features.strong_laxative.presentation')(strong2,{Config={CostumePath='missing-strong'},GetPlayerKey=key,ItemId=1})
mask2.Apply(p,'active');assert(girl2.GetGoodGirlCostumeId()==nil and strong2.StrongLaxative.GetCostumeId()==nil)
local retries=0;Isaac.GetCostumeIdByPath=function()retries=retries+1;return 200 end
mask2.ClearPlayerCostume(p);assert(retries==2)
assert(girl2.GetGoodGirlCostumeId()==nil and strong2.StrongLaxative.GetCostumeId()==nil and retries==2)
missing.GoodGirl.costumeId=nil;assert(girl2.GetGoodGirlCostumeId()==200 and retries==3)
Isaac.GetCostumeIdByPath=function()error('bad resource')end
missing.GoodGirl.costumeId=nil;assert(girl2.GetGoodGirlCostumeId()==nil and missing.GoodGirl.costumeId==false)
p.TryRemoveNullCostume=function()error('removed native entity')end
assert(pcall(girl2.ApplyGoodGirlCostume,p,false), 'native costume operation failure remains contained')
local Costumes=include('scripts.systems.null_costumes')
local cache={}
Isaac.GetCostumeIdByPath=function()assert(cache.id==nil);return -1 end
assert(Costumes.GetCachedId(cache,'id','mask',true)==nil and cache.id==false)
cache={};Isaac.GetCostumeIdByPath=function()assert(cache.id==false);return -1 end
assert(Costumes.GetCachedId(cache,'id','single')==nil and cache.id==false)
print('shared costume consumers: three consumers, idle calls, failure cache policy, runtime reset, rebind and dynamic methods passed')
