include = function(path) return dofile((path:gsub('%.', '/')) .. '.lua') end
local function eq(a,b,m) assert(a==b,(m or 'mismatch')..': expected '..tostring(b)..', got '..tostring(a)) end
local function clone(t) if type(t)~='table' then return t end local r={} for k,v in pairs(t) do r[k]=clone(v) end return r end
ModCallbacks={MC_USE_ITEM=1,MC_POST_PLAYER_UPDATE=2,MC_POST_NEW_LEVEL=3,MC_POST_GAME_STARTED=4,MC_PRE_GAME_EXIT=5}
ItemType={ITEM_PASSIVE=1,ITEM_ACTIVE=3,ITEM_FAMILIAR=4}
local factory=assert(loadfile('divine_left_hand.lua'),'temporary copy module must exist')()
local function fixture(saved)
    local f={root=saved or {},players={},callbacks={},floor='f1',seed='run1',clock=1,subscriptions={},participants={},temporaryDepth=0,logs={},notices={}}
    Isaac={GetItemConfig=function() return {GetCollectible=function(_,id) return {ID=id,Name='Item '..id,Type=(id==50 or id==900) and 3 or (id==7 and 4 or 1)} end} end}
    local state={PlayerKey=function(p) return p.canonical or p.key end,InventoryPlayerKey=function(p) return p.key end,FloorKey=function() return f.floor end,RoomKey=function() return 'r1' end,SubscribeAcquisition=function(fn) f.subscriptions[#f.subscriptions+1]=fn end,RegisterParticipant=function(name,capture,restore) f.participants[name]={capture=capture,restore=restore} end,WithTemporary=function(p,fn) f.temporaryDepth=f.temporaryDepth+1 local ok,err=pcall(fn) f.temporaryDepth=f.temporaryDepth-1 if not ok then if f.softTemporary then return false,err end error(err) end end}
    local mod={};function mod:AddCallback(id,fn,filter) f.callbacks[id]={fn=fn,filter=filter} end
    function f:call(id,...) local cb=self.callbacks[id] if cb then return cb.fn(mod,...) end end
    function f:player(key,history)
        local p={key=key,history=history or {},adds={},removes={},alive=true}
        for _,r in ipairs(p.history) do f.clock=math.max(f.clock,r.time or 0) end
        function p:Exists() return true end
        function p:IsDead() return not self.alive end
        function p:GetHistory()
            local records=clone(self.history)
            return {GetCollectiblesHistory=function()
                local result={};for i,r in ipairs(records) do
                    local h={};function h:GetItemID() return r.id end;function h:GetTime() return r.time end
                    function h:GetLevelStage() return r.stage or 1 end;function h:GetStageType() return 0 end
                    function h:GetRoomType() return 1 end;function h:GetItemPoolType() return 0 end
                    function h:IsTrinket() return r.trinket==true end;result[i]=h
                end;return result
            end}
        end
        function p:GetCollectibleNum(id) local n=(self.extra or {})[id] or 0;for _,r in ipairs(self.history) do if r.id==id and not r.trinket then n=n+1 end end return n end
        function p:AddCollectible(id,charge,firstTime)
            self.adds[#self.adds+1]={id=id,firstTime=firstTime,temporary=f.temporaryDepth>0}
            if f.grantFailure then return end
            if f.grantError then error('native grant error') end
            if f.noReceipt then self.extra=self.extra or {};self.extra[id]=(self.extra[id] or 0)+1;return end
            f.clock=f.clock+1;self.history[#self.history+1]={id=id,time=f.clock,label='temporary'}
            for _,fn in ipairs(f.subscriptions) do fn(self,id,'token'..f.clock,false,f.temporaryDepth>0) end
            if f.errorAfterGrant then error('error after native grant') end
        end
        function p:RemoveCollectibleByHistoryIndex(index)
            assert(index>=0 and index<#self.history,'native history index must be zero-based, including trinkets')
            self.removes[#self.removes+1]=clone(self.history[index+1]);table.remove(self.history,index+1)
        end
        f.players[#f.players+1]=p;return p
    end
    factory(mod,{ItemId=900,State=state,GetSaveRoot=function() return f.root end,GetCurrentRunSeed=function() return f.seed end,GetPlayers=function() return f.players end,Save=function() f.saved=clone(f.root) end,DebugLog=function(s) f.logs[#f.logs+1]=s end,OnTemporaryCopy=function(p,id,name) f.notices[#f.notices+1]={p=p,id=id,name=name} end})
    f.api=mod.DivineLeftHand
    function f:use(p) return self:call(1,900,nil,p,0,0,0) end
    function f:tick(p) return self:call(2,p) end
    function f:normal(p,id,time,trinket)
        self.clock=math.max(self.clock+1,time or 0);p.history[#p.history+1]={id=id,time=time or self.clock,label='normal',trinket=trinket}
        for _,fn in ipairs(self.subscriptions) do fn(p,id,'normal'..self.clock,true,false) end
    end
    return f
end
local tests={}
function tests.same_seed_new_run_resets_temporary_ownership_and_unsaved_exit_does_not_save()
    local f=fixture();local p=f:player('a',{{id=1,time=1,label='normal'}});f:use(p)
    eq(f.api.GetTemporaryCount(p,1),1)
    f.saved=nil;f:call(5,false);eq(f.saved,nil,'unsaved exit must not write continuation state')
    p.history={{id=1,time=1,label='normal'}};f:call(4,false)
    eq(f.api.GetTemporaryCount(p,1),0,'same seed is a new run when continued is false')
    eq(f:use(p).Discharge,true);eq(f.api.GetTemporaryCount(p,1),1)
    f.floor='f2';f:call(3);eq(p:GetCollectibleNum(1),1)
end
function tests.last_normal_active_and_self_do_not_fall_back()
    local f=fixture();local p=f:player('a',{{id=1,time=1},{id=50,time=2}})
    eq(f:use(p).Discharge,false);eq(#p.adds,0)
    p.history[2]={id=900,time=3};eq(f:use(p).Discharge,false);eq(#p.adds,0)
    table.remove(p.history,2);eq(f:use(p).Discharge,true);eq(p.adds[1].id,1)
end
function tests.real_temporary_repeated_and_no_pickup_resources()
    local f=fixture();local p=f:player('a',{{id=7,time=1}});eq(f:use(p).Discharge,true);eq(f:use(p).Discharge,true)
    eq(p:GetCollectibleNum(7),3);eq(f.api.GetTemporaryCount(p,7),2);eq(#f.notices,2)
    for _,add in ipairs(p.adds) do eq(add.firstTime,false);eq(add.temporary,true) end
    f.floor='f2';f:call(3);eq(p:GetCollectibleNum(7),1);eq(#p.removes,2)
    for _,r in ipairs(p.removes) do eq(r.label,'temporary','only owned history instances removed') end
    f:call(3);eq(#p.removes,2,'cleanup idempotent')
end
function tests.same_name_normal_acquired_later_is_preserved()
    local f=fixture();local p=f:player('a',{{id=1,time=1,label='normal'},{id=999,time=2,trinket=true,label='trinket'}})
    f:use(p);f:normal(p,1,30);f:use(p);eq(f.api.GetTemporaryCount(p,1),2)
    f.floor='f2';f:call(3);eq(p:GetCollectibleNum(1),2);eq(#p.history,3);eq(p.history[2].label,'trinket')
    for _,r in ipairs(p.removes) do eq(r.label,'temporary') end
end
function tests.owner_isolation_and_loss_death_do_not_clear_early()
    local f=fixture();local a=f:player('a',{{id=1,time=1},{id=900,time=2}});local b=f:player('b',{{id=2,time=1}})
    -- New target after owning active, then lose both normal and active, retaining only temporary.
    f:normal(a,1,10);f:use(a);f:use(b);table.remove(a.history,3);table.remove(a.history,2);table.remove(a.history,1)
    a.alive=false;f:tick(a);eq(f.api.GetTemporaryCount(a,1),1);eq(f.api.GetTemporaryCount(b,2),1)
    a.alive=true;eq(f:use(a).Discharge,false,'temporary-only inventory is not a source')
    f.floor='f2';f:call(3);eq(a:GetCollectibleNum(1),0);eq(b:GetCollectibleNum(2),1)
end
function tests.failed_grant_and_missing_precision_api_do_not_discharge()
    for _,mode in ipairs({'failure','error','history','remove'}) do
        local f=fixture();local p=f:player('a',{{id=1,time=1}})
        if mode=='failure' then f.grantFailure=true elseif mode=='error' then f.grantError=true elseif mode=='history' then p.GetHistory=false else p.RemoveCollectibleByHistoryIndex=false end
        eq(f:use(p).Discharge,false,mode);eq(f.api.GetTemporaryCount(p,1),0,mode);eq(f.temporaryDepth,0)
        if mode=='history' or mode=='remove' then eq(#p.adds,0,'precision preflight before native grant') end
    end
end
function tests.removal_shifts_indices_and_reroll_preserves_temporary_identity()
    local f=fixture();local p=f:player('a',{{id=1,time=1,label='normal'},{id=3,time=2,label='normal'}})
    f:use(p);table.remove(p.history,1);p.history[2].id=8;f:tick(p)
    eq(f.api.GetTemporaryCount(p,3),0);eq(f.api.GetTemporaryCount(p,8),1)
    f.floor='f2';f:call(3);eq(p:GetCollectibleNum(3),1);eq(p:GetCollectibleNum(8),0);eq(p.removes[1].label,'temporary')
end
function tests.removed_copy_record_does_not_delete_later_normal()
    local f=fixture();local p=f:player('a',{{id=1,time=1,label='normal'}});f:use(p);table.remove(p.history,2);f:tick(p);f:normal(p,1,40)
    eq(f.api.GetTemporaryCount(p,1),0);f.floor='f2';f:call(3);eq(p:GetCollectibleNum(1),2);eq(#p.removes,0)
end
function tests.save_continue_and_hourglass_restore_no_extra_grants()
    local f=fixture();local p=f:player('a',{{id=1,time=1,label='normal'}});f:use(p)
    local participant=f.participants.divine_left_hand;assert(participant,'snapshot participant registered')
    local snapshot=participant.capture();local native=clone(p.history);f:use(p);eq(f.api.GetTemporaryCount(p,1),2)
    p.history=native;participant.restore(snapshot);eq(f.api.GetTemporaryCount(p,1),1);eq(#p.adds,2,'restore grants no new native items')
    f:call(5,true);local continued=fixture(clone(f.root));local q=continued:player('a',clone(p.history));continued:call(4,true)
    eq(continued.api.GetTemporaryCount(q,1),1);eq(#q.adds,0);continued.floor='f2';continued:call(3);eq(q:GetCollectibleNum(1),1)
end
function tests.ambiguous_identical_history_does_not_guess_delete()
    local f=fixture();local p=f:player('a',{{id=1,time=2,label='normal'}});f.clock=1;f:use(p)
    -- Grant occurs at same time with identical available metadata. On contraction either
    -- normal or temporary might have gone; a plain count can never prove which survived.
    eq(p.history[2].time,2);table.remove(p.history,1);f:tick(p)
    f.floor='f2';f:call(3);eq(#p.removes,0,'ambiguous owner preserved');eq(p:GetCollectibleNum(1),1)
    assert(table.concat(f.logs,'\n'):find('ambiguous',1,true),'explicit diagnostic')
end
function tests.unproven_grant_does_not_allow_repeated_free_grants()
    local f=fixture();local p=f:player('a',{{id=1,time=1,label='normal'}});f.noReceipt=true
    eq(f:use(p).Discharge,false);eq(#p.adds,1);eq(f:use(p).Discharge,false)
    eq(#p.adds,1,'unproved history grant blocks further use rather than free permanent duplication')
end
function tests.soft_wrapper_error_does_not_charge_and_proven_copy_still_expires()
    local f=fixture();local p=f:player('a',{{id=1,time=1,label='normal'}});f.softTemporary=true;f.errorAfterGrant=true
    eq(f:use(p).Discharge,false,'shared wrapper false,error denotes failure')
    eq(f.api.GetTemporaryCount(p,1),1,'proven physical partial grant remains owned')
    f.floor='f2';f:call(3);eq(p:GetCollectibleNum(1),1);eq(f.temporaryDepth,0)
end
function tests.canonical_lazarus_identity_does_not_merge_physical_histories()
    local f=fixture();local a=f:player('a-alive',{{id=1,time=1,label='normal'}});local b=f:player('a-dead',{{id=2,time=1,label='normal'}})
    a.canonical='lazarus';b.canonical='lazarus';f:use(a);f:use(b)
    eq(f.api.GetTemporaryCount(a,1),1);eq(f.api.GetTemporaryCount(b,2),1)
    f.floor='f2';f:call(3);eq(a:GetCollectibleNum(1),1);eq(b:GetCollectibleNum(2),1)
end
local names={};for n in pairs(tests) do names[#names+1]=n end;table.sort(names)
for _,n in ipairs(names) do tests[n]();print('PASS '..n) end
print('divine_left_hand_behavior_test: '..#names..' cases passed')
