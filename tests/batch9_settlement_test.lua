local savedArg=arg;arg={'--fixture'}
local loadMod=dofile('tests/condom_utility_knife_behavior_test.lua');arg=savedArg
local env=loadMod()
local mod=env.mod
local first=env.newPlayer({initSeed=101,damage=3.5,collectibles={[env.items.CrazyCoconut]=1}})
local second=env.newPlayer({initSeed=202,damage=3.5,collectibles={[env.items.CrazyCoconut]=2}})
-- Legacy fixture may use its own seed option; the public player identity is explicit.
first.InitSeed=101;second.InitSeed=202
env.runPostUpdate()
local data=mod:GetCrazyCoconutData()
assert(data.players['101']==1 and data.players['202']==2)
first.Damage=6.5;second.Damage=9.5
local a,b=env.newPickup(env.items.NonBaby),env.newPickup(env.items.DamageDeclaredNonDamage)
env.runCollectiblePickup(a,first);env.runCollectiblePickup(a,first)
env.runCollectiblePickup(b,first)
assert(#data.pending['101']==2,'repeat collision only updates one candidate')
local beforeA,beforeB=data.pending['101'][1],data.pending['101'][2]
a:Remove();b:Remove()
first.collectibles[env.items.NonBaby]=1;first.collectibles[env.items.DamageDeclaredNonDamage]=1
env.runPostUpdate()
assert(beforeA.remainingUpdates==2 and beforeB.remainingUpdates==2 and data.players['101']==1)
env.runPostUpdate()
assert(beforeA.remainingUpdates==1 and data.players['101']==1)
local samples=0
local natural=mod.GetCrazyCoconutNaturalDamage
mod.GetCrazyCoconutNaturalDamage=function(self,p,...)
    if p==first then samples=samples+1 end
    return natural(self,p,...)
end
env.runPostUpdate()
assert(data.players['101']==3 and #data.pending['101']==0,'two due candidates settle once each')
assert(samples==2,'one settlement sample shared by the batch, then one stored natural-damage sample')
assert(data.players['202']==2,'other player layers stay isolated')
env.runPostUpdate();assert(data.players['101']==3)
mod.GetCrazyCoconutNaturalDamage=natural
local rejected=env.newPickup(env.items.DamageItem)
env.runCollectiblePickup(rejected,second)
second.QueuedItem={Item={ID=env.items.DamageItem}}
env.runPostUpdate()
second.QueuedItem={Item=nil}
for _=1,3 do env.runPostUpdate() end
assert(#data.pending['202']==0 and data.players['202']==2,'unconfirmed item queue is discarded')
local pending=env.newPickup(env.items.DamageItem)
env.runCollectiblePickup(pending,second)
second.collectibles[env.items.CrazyCoconut]=0
env.runPostUpdate()
assert(#data.pending['202']==0 and data.naturalDamage['202']==nil and data.players['202']==2,
    'item loss clears pending observation while retaining old earned layers')

-- Replacement exhaustion and reentrant morph preserve the existing policy.
local bans=mod:GetCondomData();bans.banned[tostring(env.items.NonBaby)]=true
local originalGame=Game
local calls=0
local game=originalGame()
game.GetItemPool=function()return {GetCollectible=function(_,pool,decrease,seed,fallback)
    calls=calls+1;assert(decrease==true and seed==0 and fallback==0)
    return env.items.NonBaby
end}end
Game=function()return game end
local doomed=env.newPickup(env.items.NonBaby)
mod:ReplaceCondomBannedPickup(doomed)
assert(calls==20 and not doomed:Exists(),'20 failed replacements remove the banned pedestal')
Game=originalGame
local pedestal=env.newPickup(env.items.NonBaby)
local rolls=0
mod.RollCondomReplacement=function()rolls=rolls+1;return env.items.DamageItem end
function pedestal:Morph(kind,variant,id,keepPrice,keepSeed,ignore)
    assert(keepPrice==true and keepSeed==true and ignore==false)
    mod:ReplaceCondomBannedPickup(self)
    self.SubType=id
end
mod:ReplaceCondomBannedPickup(pedestal)
assert(rolls==1 and pedestal.SubType==env.items.DamageItem)
assert(pedestal:GetData().neverbirthCondomReplacing==nil,'reentry guard released after morph')
print('batch9 settlement: same-batch damage sample, delayed confirmation, rejected queue, item loss, two players, 20-roll exhaustion and morph reentry passed')
