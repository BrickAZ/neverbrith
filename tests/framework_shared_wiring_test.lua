local realDofile=dofile
local loadMod=realDofile('tests/support/neverbirth_fixture.lua')
local captured, instances={},{}
local scopes={yins_curse='yinCurse',big_dog_bark='bigDogBark',revive_my_love='reviveMyLove',
    night_of_the_cowards='nightOfTheCowards',memory_disorder='memoryDisorder',
    ring_of_the_seven_curses='ringOfSevenCurses',healthy_sleep='healthySleep',
    i_am_a_god='iAmAGod',god_complex='godComplex',blinky='blinky',drive_glove='driveGlove',
    motion_combat='motionCombat',divine_left_hand='divineLeftHand',echo_baby='echoBaby',low_grade='lowGrade'}
local targets={['scripts/systems/acquisition_state']=true,pending_content_integration=true,motion_items=true}
for name in pairs(scopes) do targets[name]=true end
_G.dofile=function(path)
    local result=realDofile(path)
    local name=path:gsub('\\','/'):gsub('%.lua$','')
    if name=='scripts/runtime/persistence' then
        return {Create=function(...)
            local api=result.Create(...)
            -- The real service still owns its root internally. The bootstrap is
            -- deliberately denied an unscoped getter in this integration test.
            return {Section=api.Section,Scope=api.Scope,Save=api.Save}
        end}
    end
    if targets[name] then return function(mod, context)
        captured[name]=context
        if name=='pending_content_integration' then
            -- The base fixture omits optional trinket registration. Exercise its
            -- real path here using the same ID/enum contracts as its behavior test.
            TrinketType={TRINKET_GOLDEN_FLAG=32768}
            PickupVariant.PICKUP_TRINKET=350
            ModCallbacks.MC_POST_TRIGGER_TRINKET_ADDED=1096
            ModCallbacks.MC_POST_TRIGGER_TRINKET_REMOVED=1097
            ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD=5099 -- unique fixture event
            Isaac.GetTrinketIdByName=function(value) return value=='Low Grade' and 201 or -1 end
        end
        if scopes[name] then
            local view=assert(context.GetSaveRoot)()
            local _=view[scopes[name]]
            assert(not pcall(function() return view.unrelatedOwner end),name..' receives unrestricted data')
        end
        -- Formal dependencies must survive removal of the legacy service locator.
        local oldInput,oldPresentation,oldCombat=mod.MotionInput,mod.MotionPresentation,mod.MotionCombat
        if name=='motion_combat' or name=='motion_items' then
            mod.MotionInput,mod.MotionPresentation=nil,nil
            if name=='motion_items' then mod.MotionCombat=nil end
        end
        local instance=result(mod,context)
        if name=='motion_combat' or name=='motion_items' then
            mod.MotionInput,mod.MotionPresentation=oldInput,oldPresentation
            if name=='motion_items' then mod.MotionCombat=oldCombat end
        end
        instances[name]=instance
        return instance
    end end
    return result
end
local ok,err=pcall(loadMod)
_G.dofile=realDofile
assert(ok,err)
for name in pairs(scopes) do assert(captured[name], 'missing real consumer '..name) end
local state=instances['scripts/systems/acquisition_state']
assert(state==Neverbirth.PendingContentState and state==captured.pending_content_integration.State)
assert(captured.blinky.State==state and captured.blinky.GetSelector()==Neverbirth.InventorySelector)
assert(captured.divine_left_hand.State==state and captured.echo_baby.State==state and captured.low_grade.State==state)
assert(captured.drive_glove.Key==captured.motion_combat.Key)
assert(captured.drive_glove.Key==captured['scripts/systems/acquisition_state'].Identity.InventoryPlayerKey)
assert(type(captured.drive_glove.IsInventoryBlocking)=='function')
local oldBlocking=Neverbirth.InventorySelector.IsBlocking
local queried
Neverbirth.InventorySelector.IsBlocking=function(player)queried=player;return 'blocking-sentinel'end
local player={}
assert(captured.drive_glove.IsInventoryBlocking(player)=='blocking-sentinel' and queried==player)
Neverbirth.InventorySelector.IsBlocking=oldBlocking
assert(captured.motion_combat.Input==Neverbirth.MotionInput and captured.motion_items.Combat==Neverbirth.MotionCombat)
assert(captured.motion_items.Presentation==Neverbirth.MotionPresentation)
local sharedView=captured['scripts/systems/acquisition_state'].GetSaveRoot()
local _=sharedView.pendingContent
_=sharedView.pendingContentHourglass
assert(not pcall(function() return sharedView.echoBaby end))
local motionView=captured.motion_combat.GetSaveRoot()
motionView.motionCombatHourglass={['1']={players={}}}
assert(motionView.motionCombatHourglass['1'].players)
local modules={'scripts.runtime.player_identity','scripts.runtime.snapshot_participants',
    'scripts.systems.acquisition_state','scripts.features.inventory_selector.text',
    'scripts.features.inventory_selector.entries','scripts.features.divine_left_hand.notices',
    'scripts.integrations.low_grade_eid'}
local previous=Neverbirth
for _,name in ipairs(modules) do
    local callbacks
    local success,message=pcall(loadMod,{
        OnInclude=function(path)if path==name then error('missing shared module '..name)end end,
        OnModCreated=function(_,rows)callbacks=rows end,
    })
    assert(not success and tostring(message):find('missing shared module',1,true),name)
    assert(Neverbirth==previous,'failed bootstrap replaced the working public instance')
    for _,rows in pairs(callbacks)do assert(#rows==0,'partial callbacks after '..name)end
end
print('framework wiring: 15 scoped consumers, shared instances, explicit dependencies and 7 installation rollback cases passed')
