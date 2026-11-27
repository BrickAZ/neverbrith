local fixture=dofile('tests/support/neverbirth_fixture.lua')
local env=fixture();local mod=Neverbirth
local api=assert(mod.DogFoodSeriesTestAPI)
local p={InitSeed=991,counts={}}
function p:ToPlayer()return self end
function p:GetCollectibleNum(id)return self.counts[id] or 0 end
local item=env.itemIds.ProteinStrip
local pickup={Type=EntityType.ENTITY_PICKUP,Variant=PickupVariant.PICKUP_COLLECTIBLE,SubType=item,InitSeed=997}
local function event(id,...)
    local n=0
    for _,record in ipairs(env.callbacks[id] or {})do
        if debug.getinfo(record.fn,'S').source:find('scripts/systems/dog_food_acquisition.lua',1,true)then
            record.fn(mod,...);n=n+1
        end
    end
    assert(n==1,'missing/duplicate food lifecycle event '..tostring(id))
end
api.Callbacks.TrackPickupCollision(mod,pickup,p)
assert(next(api.Runtime.pending),'real collision must retain a pending player')
event(ModCallbacks.MC_PRE_GAME_EXIT,true)
event(ModCallbacks.MC_PRE_GAME_EXIT,true)
assert(next(api.Runtime.pending)==nil,'exit retained player reference')
local oldFrame=api.Runtime.frame
api.Callbacks.TrackPickupCollision(mod,pickup,p);api.Callbacks.Update(mod)
assert(next(api.Runtime.pending)==nil and api.Runtime.frame==oldFrame,'stopped food instance advanced')
event(ModCallbacks.MC_POST_GAME_STARTED,true)
api.Callbacks.TrackPickupCollision(mod,pickup,p)
assert(next(api.Runtime.pending),'continue failed to resume tracking')
event(ModCallbacks.MC_PRE_MOD_UNLOAD,{})
assert(next(api.Runtime.pending),'another mod unload cleared pending')
event(ModCallbacks.MC_PRE_MOD_UNLOAD,mod);event(ModCallbacks.MC_PRE_MOD_UNLOAD,mod)
assert(next(api.Runtime.pending)==nil,'unload retained player reference')
event(ModCallbacks.MC_POST_GAME_STARTED,false)
api.Callbacks.TrackPickupCollision(mod,pickup,p)
assert(next(api.Runtime.pending)==nil,'disposed instance resumed')
print('Food lifecycle: exit/continue/unload reference release and stopped updates passed')
