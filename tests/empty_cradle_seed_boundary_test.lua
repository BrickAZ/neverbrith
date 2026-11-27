-- A wrong global lookup (rather than the injected run seed) leaks floor rewards across runs.
local env=dofile('tests/support/neverbirth_fixture.lua')({Root=arg and arg[1]})
local mod,ids=Neverbirth,env.itemIds
local seed='AAAA';local originalGame=Game
Game=function()
    local g=originalGame()
    g.GetSeeds=function()return {GetStartSeedString=function()return seed end}end
    g.GetLevel=function()return {GetStage=function()return 1 end,GetStageType=function()return 0 end,GetCurrentRoomIndex=function()return 2 end}end
    g.GetRoom=function()return {IsClear=function()return true end,GetType=function()return 1 end,GetSpawnSeed=function()return 2 end}end
    return g
end
local p={InitSeed=500,Damage=3.5,Position=Vector(10,10)}
function p:ToPlayer()return self end
function p:GetCollectibleNum(id)return id==ids.EmptyCradle and 1 or 0 end
function p:GetSoulHearts()return 2 end
function p:GetBlackHearts()return 1 end
function p:AddCacheFlags()end
local evaluate,damage,update
for _,entry in ipairs(env.callbacks[ModCallbacks.MC_EVALUATE_CACHE])do if entry.fn==mod.EvaluateEmptyCradle then evaluate=entry.fn end end
for _,entry in ipairs(env.callbacks[ModCallbacks.MC_ENTITY_TAKE_DMG])do if entry.fn==mod.HandleEmptyCradleDamage then damage=entry.fn end end
for _,entry in ipairs(env.callbacks[ModCallbacks.MC_POST_UPDATE])do if entry.fn==mod.UpdateEmptyCradleRewards then update=entry.fn end end
assert(evaluate and damage and update,'must exercise registered callbacks')
function p:EvaluateItems()self.Damage=3.5;evaluate(mod,self,CacheFlag.CACHE_DAMAGE)end
Isaac.FindByType=function(kind)return kind==EntityType.ENTITY_PLAYER and {p} or {}end
local previousGlobal=GetCurrentRunSeed
GetCurrentRunSeed=function()return 'UNRELATED GLOBAL' end
damage(mod,p,1,0,EntityRef(p));update(mod)
assert(p.Damage==4.5,'first run upgraded black-heart reward')
seed='BBBB' -- Same body, floor and room; intentionally no reset callback.
p:EvaluateItems()
assert(p.Damage==3.5,'changed run seed must invalidate old floor damage bonus')
damage(mod,p,1,0,EntityRef(p));update(mod)
assert(p.Damage==4.5,'changed run seed must reset reward eligibility too')
GetCurrentRunSeed=previousGlobal
print('empty cradle seed boundary passed: same player/stage, new run, unrelated global excluded')
