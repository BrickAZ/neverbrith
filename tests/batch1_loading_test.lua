-- Exercise real entry imports, not just individually loadable extracted files.
local loadMod = dofile('tests/support/neverbirth_fixture.lua')
local expected = {
    'scripts.features.essential_balm', 'scripts.features.wuhu',
    'scripts.runtime.persistence', 'scripts.runtime.legacy_save_schema',
    'scripts.systems.incoming_damage', 'scripts.features.musicbox.init',
    'scripts.features.musicbox.core', 'scripts.features.musicbox.presentation',
    'scripts.features.dog_food_series',
}
local function bindings(env)
    local mod=Neverbirth
    local handlers={
        {ModCallbacks.MC_EVALUATE_CACHE, mod.EvaluateEssentialBalm},
        {ModCallbacks.MC_EVALUATE_CACHE, mod.EvaluateWuhu},
        {ModCallbacks.MC_USE_ITEM, mod.UseMusicbox, env.itemIds.Musicbox},
        {ModCallbacks.MC_PRE_USE_ITEM, mod.InterceptPlanC, 475},
        {ModCallbacks.MC_POST_UPDATE, mod.UpdateMusicbox},
        {ModCallbacks.MC_POST_RENDER, mod.RenderMusicboxCountdown},
        {ModCallbacks.MC_PRE_PLAYER_TAKE_DMG, mod.PreventActiveMusicboxDamage},
        {ModCallbacks.MC_ENTITY_TAKE_DMG, mod.PreventMusicboxDamage},
        {ModCallbacks.MC_EVALUATE_CACHE, mod.EvaluateMusicbox},
        {ModCallbacks.MC_POST_GAME_STARTED, mod.StartMusicboxRun},
        {ModCallbacks.MC_PRE_GAME_EXIT, mod.ExitMusicbox},
        {ModCallbacks.MC_PRE_MOD_UNLOAD, mod.UnloadMusicbox},
        {ModCallbacks.MC_EVALUATE_CACHE, assert(mod.DogFoodSeriesTestAPI).Callbacks.Evaluate},
        {ModCallbacks.MC_POST_UPDATE, mod.DogFoodSeriesTestAPI.Callbacks.Update},
        {ModCallbacks.MC_PRE_PICKUP_COLLISION, mod.DogFoodSeriesTestAPI.Callbacks.TrackPickupCollision, 100},
        {ModCallbacks.MC_POST_FIRE_TEAR, mod.DogFoodSeriesTestAPI.Callbacks.MarkDentalTear},
        {ModCallbacks.MC_PRE_TEAR_COLLISION, mod.DogFoodSeriesTestAPI.Callbacks.DentalCollision},
        {ModCallbacks.MC_POST_GAME_STARTED, mod.DogFoodSeriesTestAPI.Callbacks.GameStarted},
    }
    for _,spec in ipairs(handlers) do
        assert(spec[1]~=nil,'missing callback enum in complete entry fixture')
        assert(type(spec[2])=='function','missing feature handler')
        local count=0
        for _,entry in ipairs(env.callbacks[spec[1]] or {}) do
            if entry.fn==spec[2] then
                count=count+1
                assert(entry.param==spec[3], 'callback filter changed')
                assert(entry.Priority==0, 'callback priority changed')
            end
        end
        assert(count==1,'handler must be installed exactly once')
    end
end
for _=1,2 do
    local includes={}
    local env=loadMod({OnInclude=function(name) includes[name]=(includes[name] or 0)+1 end})
    bindings(env)
    for _,name in ipairs(expected) do assert(includes[name]==1,name..' must load once per instance') end
    local callback=env.callbacks[ModCallbacks.MC_USE_ITEM]
    callback[#callback+1]={fn=Neverbirth.UseMusicbox,param=env.itemIds.Musicbox,Priority=0}
    assert(not pcall(bindings,env),'duplicate installation counterexample must fail')
end
local missingCollision=loadMod()
for i,entry in ipairs(missingCollision.callbacks[ModCallbacks.MC_PRE_TEAR_COLLISION]) do
    if entry.fn==Neverbirth.DogFoodSeriesTestAPI.Callbacks.DentalCollision then
        table.remove(missingCollision.callbacks[ModCallbacks.MC_PRE_TEAR_COLLISION],i); break
    end
end
assert(not pcall(bindings,missingCollision),'missing real collision registration must fail')
local omitted=loadMod({OmitModule='scripts.features.essential_balm'})
assert(not pcall(bindings,omitted),'missing module counterexample must fail')
print('batch1 loading passed: real imports, repeated instances, signatures, omitted/duplicate counterexamples')
