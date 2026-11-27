-- Exercise the three actual registered handlers together through synchronous TakeDamage reentry.
local loader=dofile('tests/support/neverbirth_fixture.lua')
local file=assert(io.open('E:/Isaac - Repentance/resources/scripts/main_ex.lua','r'))
local installed=file:read('*a');file:close()
dofile('tests/repentogon_installed_dispatch_contract.lua')(installed)
local contract=dofile('tests/fixtures/repentogon_1_0_12a_damage_contract.lua')
local comparator=assert(load(contract.comparator..'\nreturn CallbackComparator'))()
local function makeDispatch(env,mod,onCall)
    local records={}
    local selected={[mod.PreventMusicboxDamage]=true,[mod.HandleUncutCordDamage]=true,[mod.HandleEmptyCradleDamage]=true}
    for _,entry in ipairs(env.callbacks[ModCallbacks.MC_ENTITY_TAKE_DMG])do
        if selected[entry.fn]then records[#records+1]=entry end
    end
    assert(#records==3,'all three damage callbacks must come from the actual entry')
    table.sort(records,comparator)
    local scope=setmetatable({
        GetCallbackIterator=function(_,param)
            local i=0
            return function()
                repeat i=i+1 until not records[i] or records[i].param==nil or records[i].param==param
                return records[i]
            end
        end,
        RunCallbackInternal=function(_,record,...)
            if onCall then onCall(record.Function)end
            return record.Function(record.Mod,...)
        end,
    },{__index=_G})
    assert(load(contract.dispatcher,'@verified-installed-damage-dispatch','t',scope))()
    return function(p,amount,flags)
        return scope._RunEntityTakeDmgCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,EntityType.ENTITY_PLAYER,p,amount,flags or 0,EntityRef(p),0)
    end
end
local function scenario(failDamage,nested)
    local env=loader({Root=arg and arg[1]})
    local mod,ids=Neverbirth,env.itemIds
    local p={InitSeed=41,counts={[ids.BloodSkullGu]=1,[ids.UncutCord]=1,[ids.EmptyCradle]=1},charge=3,accepted={},Position=Vector(100,100)}
    local spawns,dispatches={},0
    local room={GetType=function()return 1 end,IsClear=function()return true end,GetSpawnSeed=function()return 3 end}
    local level={GetStage=function()return 1 end,GetStageType=function()return 0 end,GetCurrentRoomIndex=function()return 2 end}
    local originalGame=Game
    Game=function()local g=originalGame();g.GetRoom=function()return room end;g.GetLevel=function()return level end;return g end
    Isaac.FindByType=function(kind)return kind==EntityType.ENTITY_PLAYER and {p} or {} end
    Isaac.Spawn=function(...)spawns[#spawns+1]={...};return nil end
    function p:ToPlayer()return self end
    function p:GetCollectibleNum(id)return self.counts[id] or 0 end
    function p:GetActiveItem()return ids.BloodSkullGu end
    function p:GetActiveCharge()return self.charge end
    function p:DischargeActiveItem()self.charge=0 end
    function p:GetCollectibleRNG()return {RandomFloat=function()return 0 end,RandomInt=function()return 0 end} end
    function p:GetSoulHearts()return 0 end
    function p:AddCacheFlags()end
    function p:EvaluateItems()end
    local nativeDispatch=makeDispatch(env,mod)
    local function dispatch(amount,flags)return nativeDispatch(p,amount,flags)end
    local use
    for _,entry in ipairs(env.callbacks[ModCallbacks.MC_USE_ITEM]) do
        if entry.param==ids.BloodSkullGu and entry.fn==mod.UseBloodSkullGu then use=entry.fn end
    end
    assert(use,'blood skull use must be registered')
    function p:TakeDamage(amount,flags)
        dispatches=dispatches+1
        if nested and dispatches==1 then self.charge=3;use(mod,ids.BloodSkullGu,nil,self,0,0) end
        assert(dispatch(amount,flags)~=false,'backlash or debt repayment must not be delayed recursively')
        if failDamage then error('intentional engine damage failure') end
        self.accepted[#self.accepted+1]=amount
    end
    use(mod,ids.BloodSkullGu,nil,p,0,0)
    mod:UpdateEmptyCradleRewards()
    assert(#spawns==0,'backlash must not grant cradle reward')
    assert(dispatch(2,0)==false,'normal damage after normal/error/nested backlash must create cord debt')
    local before=dispatches
    p.charge=3;use(mod,ids.BloodSkullGu,nil,p,0,0)
    assert(dispatches==before+1,'backlash must not settle an existing cord debt')
    failDamage=false
    p.counts[ids.EmptyCradle]=0
    assert(dispatch(1,0)==nil,'next ordinary hit settles debt and continues')
    assert(p.accepted[#p.accepted]==2,'existing debt amount survives backlash')
    -- Fresh cradle state: cost exclusion must preserve this floor's first ordinary reward.
    mod:ResetEmptyCradleState(false);p.counts[ids.UncutCord]=0;p.counts[ids.EmptyCradle]=1
    p.charge=3;use(mod,ids.BloodSkullGu,nil,p,0,0);mod:UpdateEmptyCradleRewards()
    local count=#spawns
    dispatch(1,0);mod:UpdateEmptyCradleRewards()
    assert(#spawns==count+1,'ordinary damage after backlash must still earn the cradle reward')
    mod:UpdateEmptyCradleRewards();assert(#spawns==count+1,'reward settles once')
end
scenario(false,false);scenario(true,false);scenario(false,true)
local function protectionCancelsDownstream()
    local env=loader({Root=arg and arg[1]});local mod,ids=Neverbirth,env.itemIds
    local p={InitSeed=900,Position=Vector(10,10),cord=true,Type=EntityType.ENTITY_PLAYER}
    function p:ToPlayer()return self end
    function p:GetCollectibleNum(id)return (id==ids.EmptyCradle or id==ids.UncutCord and self.cord) and 1 or 0 end
    function p:GetCollectibleRNG()return {RandomFloat=function()return 0 end,RandomInt=function()return 0 end}end
    function p:GetActiveItem()return 0 end
    function p:GetSoulHearts()return 0 end
    function p:AddCacheFlags()end
    function p:EvaluateItems()end
    function p:TakeDamage()error('unexpected old cord debt during protected hit')end
    local room={IsClear=function()return true end,GetType=function()return 1 end,GetSpawnSeed=function()return 2 end}
    local previousGame=Game;Game=function()local g=previousGame();g.GetRoom=function()return room end;return g end
    Isaac.FindByType=function(kind)return kind==EntityType.ENTITY_PLAYER and {p} or {}end
    local rewards=0;Isaac.Spawn=function()rewards=rewards+1;return nil end
    assert(mod:UseMusicbox(nil,nil,p),'activate actual protection')
    local afterVisuals=rewards
    local visited={};local dispatch=makeDispatch(env,mod,function(fn)visited[#visited+1]=fn end)
    assert(dispatch(p,1)==false and #visited==1 and visited[1]==mod.PreventMusicboxDamage,'musicbox cancellation must stop the native chain before cord/cradle')
    mod:UpdateEmptyCradleRewards();assert(rewards==afterVisuals,'protected hit must not create cradle reward')
    mod:ExitMusicbox(true);visited={}
    assert(dispatch(p,1)==false,'first unprotected hit must create fresh cord debt, not repay an old one')
    assert(#visited==2 and visited[2]==mod.HandleUncutCordDamage,'cord cancellation must stop before cradle')
    mod:UpdateEmptyCradleRewards();assert(rewards==afterVisuals,'delayed hit must not create cradle reward')
    mod:ResetUncutCordState(false);p.cord=false
    dispatch(p,1);mod:UpdateEmptyCradleRewards()
    assert(rewards==afterVisuals+1,'first accepted ordinary hit retains cradle eligibility')
end
protectionCancelsDownstream()
print('batch2 damage synergy passed: installed dispatcher, musicbox/cord cancellation, backlash exclusion, debt preservation and error/nested unwind')
