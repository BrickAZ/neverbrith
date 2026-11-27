local fixture=dofile('tests/support/big_dog_fixture.lua')
local f=fixture();local a=f.api
local p=f.player(13);local other=f.player(14);f.players={p,other}
p.slots[0]=a.ItemId;other.slots[0]=a.ItemId
a.Callbacks.GameStarted(nil,false)
assert(#f.saves==1 and f.root.bigDogBark.runSeed=='DOG-13')
local record=a.GetPlayerRecord(p);record.foodPickups=4;record.chewUnlocked=true
assert(a.UseWindPill(p) and not a.UseWindPill(p))
assert(#f.saves==2 and not a.GetPlayerRecord(other).potionArmed)
local saved=f.copy(f.root);local oldRuntime=a.Runtime.players['13']
a.Callbacks.GameStarted(nil,true)
assert(#f.saves==2 and a.Runtime.players['13']==nil)
record=a.GetPlayerRecord(p)
assert(record.foodPickups==4 and record.chewUnlocked and record.potionArmed)
assert(a.Runtime.players['13']~=oldRuntime,'Continue reconstructs transient state')
-- Same logical seed with a new body must replace the runtime player reference.
local replacement=f.player(13);replacement.slots[0]=a.ItemId;f.players={replacement,other}
assert(a.GetPlayerRecord(replacement)==record)
assert(a.Runtime.players['13'].player==replacement)
-- Both replacing the provider result and replacing the provider function stay live.
f.root={bigDogBark={runSeed='DOG-13',players={['13']={foodPickups=2,potionArmed=false}}},unrelated={keep=42}}
assert(a.GetPlayerRecord(replacement).foodPickups==2)
local alternative={bigDogBark={runSeed='DOG-13',players={['13']={foodPickups=7,potionArmed=true}}},unrelated={keep=99}}
f.context.GetSaveRoot=function()return alternative end
assert(a.GetPlayerRecord(replacement).foodPickups==7,'provider replacement remains visible')
local saveCalls=0;f.context.Save=function()saveCalls=saveCalls+1 end
a.Callbacks.PreGameExit();assert(saveCalls==1 and a.Runtime.savedAtExit)
f.context.GetCurrentRunSeed=function()return 1234 end
assert(a.GetPlayerRecord(replacement).foodPickups==0 and alternative.bigDogBark.runSeed=='1234')
assert(alternative.unrelated.keep==99)
-- Invalid data normalization and save exceptions match legacy behavior.
alternative.bigDogBark.players['13']={foodPickups='4.9',potionArmed=1}
record=a.GetPlayerRecord(replacement);assert(record.foodPickups==4 and record.chewUnlocked and not record.potionArmed)
f.context.Save=function()error('save fails')end
assert(a.UseWindPill(replacement));a.Callbacks.PreGameExit()
-- New room cancels charge/dash/echo/trails without erasing food or the armed potion.
replacement.collectibles[a.EchoItemId]=1
a.Callbacks.PostPlayerUpdate(nil,replacement)
local state=a.Runtime.players['13'];state.mode='charging';state.chargeBarVisible=true
local trail=a.SpawnOrRefreshTrail(replacement,Vector(100,100),40,0)
local trailEntity=trail.nodes[1].entity;local dog=state.dog
a.Callbacks.NewRoom()
assert(dog.removed and trailEntity.removed and #a.Runtime.trails==0)
assert(state.mode=='follow' and not state.chargeBarVisible and next(state.roomChewed)==nil)
assert(a.GetPlayerRecord(replacement).foodPickups==4 and a.GetPlayerRecord(replacement).potionArmed)
-- Successful launch alone consumes the potion; denied launch keeps it.
f.mod.AvadaKedavra={OwnsAttack=function()return true end}
assert(a.Launch(replacement,Vector(1,0))==nil and record.potionArmed)
f.mod.AvadaKedavra=nil
local dash=a.Launch(replacement,Vector(1,0))
assert(dash.distance==480 and dash.damageMultiplier==1.5 and not record.potionArmed)
-- Losing the active cleans owned entities, retaining persistent progression.
a.Callbacks.PostPlayerUpdate(nil,replacement);local freshDog=state.dog
replacement.slots={};a.Callbacks.PostPlayerUpdate(nil,replacement)
assert(freshDog.removed and state.dog==nil and state.dash==nil and state.mode=='follow')
assert(a.GetPlayerRecord(replacement).foodPickups==4)
-- Fresh run explicitly resets the persisted area; unrelated data remains.
f.context.Save=function()end;a.Callbacks.GameStarted(nil,false)
assert(next(alternative.bigDogBark.players)==nil and alternative.unrelated.keep==99)
print('batch13 boundaries: saved schema, live providers, Continue, body replacement, errors, room reset, launch payment, item loss, fresh run passed')
