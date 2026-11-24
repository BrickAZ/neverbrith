local fixture = assert(loadfile("tests/memory_disorder_behavior_test.lua"))("fixture")
local function eq(a,b,msg) assert(a==b,msg .. ": expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function setup(kind, holder)
    local env=fixture.makeEnvironment()
    local main,other=env.players[1],env.players[2]
    local peerType=kind==19 and 20 or 40
    main.playerType,other.playerType=kind,peerType
    other.ControllerIndex=main.ControllerIndex
    main.twin,other.twin=other,main
    local unrelated=fixture.makePlayer(303,0)
    local removals={}
    local function configure(p)
        function p:GetOtherTwin() return self.twin end
        function p:GetMainTwin() return (self.playerType==20 or self.playerType==40) and self.twin or self end
        function p:GetCollectiblesList()
            local result={}; for id,n in pairs(self.collectibleCounts) do result[id]=n end; return result
        end
        function p:GetTrinket() return 0 end
        p.smelted={}
        function p:GetSmeltedTrinkets() return self.smelted end
        function p:AddSmeltedTrinket(id)
            local base,field=id % 32768,id>=32768 and "goldenTrinketAmount" or "trinketAmount"
            self.smelted[base]=self.smelted[base] or {trinketAmount=0,goldenTrinketAmount=0}
            self.smelted[base][field]=self.smelted[base][field]+1
        end
    end
    configure(main); configure(other); configure(unrelated)
    function other:GetMainTwin() return main end
    main.collectibleCounts[9000]=(holder=="main" or holder=="both") and 1 or 0
    other.collectibleCounts[9000]=(holder=="other" or holder=="both") and 1 or 0
    other.collectibleCounts[182]=2
    other.health.maxHearts,other.health.hearts,other.health.soulHearts=kind==35 and 0 or 2,kind==35 and 0 or 2,2
    env.setPlayers({main,other,unrelated})
    PlayerManager={ RemoveCoPlayer=function(p)
        assert(p~=main and p~=unrelated,"must only remove proven former twin")
        removals[#removals+1]=p; p.exists=false
        if p.twin then p.twin.twin=nil end; p.twin=nil
        env.setPlayers({main,unrelated})
    end }
    local change=main.ChangePlayerType
    function main:ChangePlayerType(t)
        change(self,t)
        -- Deliberately model the reported engine boundary: an old twin may
        -- remain live. A new paired form creates a new native extra player.
        if (t==19 or t==35) and not self.twin then
            local peer=fixture.makePlayer(404,t==19 and 20 or 40)
            configure(peer); peer.ControllerIndex=self.ControllerIndex
            self.twin,peer.twin=peer,self
            function peer:GetMainTwin() return main end
            env.setPlayers({main,peer,unrelated})
        end
    end
    env.runPostUpdate()
    return env,main,other,unrelated,removals
end
local tests={}
tests.tainted_soul_cleanup_and_restore=function()
    local env,p,soul,unrelated,removed=setup(35,"main")
    assert(env.api.ResolveIdentitySwitch(p,env.api.FindProfile("eden")))
    eq(#removed,1,"exactly the old soul removed"); eq(soul.exists,false,"old soul gone")
    eq(unrelated.exists,true,"co-op player kept")
    p.collectibleCounts[9000]=0; env.api.OnOwnershipUpdate(p)
    eq(p:GetPlayerType(),35,"original body restored")
    assert(p.twin and p.twin~=soul,"new native partner restored")
    eq(p.twin:GetCollectibleNum(182),2,"partner permanent items restored")
    eq(p.twin:GetSoulHearts(),2,"partner HP restored")
end
tests.esau_holder_uses_main_and_restores_inventory=function()
    local env,p,esau,_,removed=setup(19,"other")
    assert(env.api.ResolveIdentitySwitch(esau,env.api.FindProfile("isaac")))
    eq(#esau.changeCalls,0,"no standalone Esau transformation")
    eq(p:GetPlayerType(),0,"canonical main transformed")
    eq(p:GetCollectibleNum(9000),1,"holder item survives parked partner")
    eq(#removed,1,"old Esau removed")
    p.collectibleCounts[9000]=0; env.api.OnOwnershipUpdate(p)
    eq(p:GetPlayerType(),19,"restores a real pair")
    eq(p.twin:GetCollectibleNum(182),2,"original Esau items kept")
    eq(p.twin:GetCollectibleNum(9000),0,"losing the item must not resurrect it")
end
tests.two_holders_switch_once=function()
    local env,p,other=setup(19,"both")
    env.dispatch(ModCallbacks.MC_POST_NEW_ROOM)
    for _=1,15 do env.runPostUpdate() end
    eq(#p.changeCalls,1,"one switch per pair")
    eq(#other.changeCalls,0,"secondary never switches separately")
end
tests.no_remove_api_preserves_pair=function()
    local env,p,other=setup(35,"main"); PlayerManager=nil
    eq(env.api.ResolveIdentitySwitch(p,env.api.FindProfile("isaac")),false,"no unsafe fallback removal")
    eq(#p.changeCalls,0,"capability failure occurs before mutation")
    eq(other.exists,true,"partner remains valid")
end
tests.parked_partner_survives_continue=function()
    local env,p,other=setup(19,"other")
    other:AddSmeltedTrinket(10); other:AddSmeltedTrinket(32778)
    assert(env.api.ResolveIdentitySwitch(other,env.api.FindProfile("isaac")))
    env.api.OnPreGameExit(); env.api.OnGameStarted(true)
    p.collectibleCounts[9000]=0; env.api.OnOwnershipUpdate(p)
    eq(p:GetPlayerType(),19,"continued original pair restored")
    eq(p.twin:GetCollectibleNum(182),2,"continued partner inventory restored")
    eq(p.twin:GetCollectibleNum(9000),0,"continued removal does not regrant item")
    eq(p.twin.smelted[10].trinketAmount,1,"smelted trinket restored")
    eq(p.twin.smelted[10].goldenTrinketAmount,1,"golden smelted trinket restored")
end
tests.cleanup_failure_rolls_back=function()
    local env,p,other=setup(35,"main")
    PlayerManager.RemoveCoPlayer=function() end
    eq(env.api.ResolveIdentitySwitch(p,env.api.FindProfile("isaac")),false,"no-op cleanup cannot succeed")
    eq(p:GetPlayerType(),35,"failed cleanup restores paired identity")
    eq(p.twin,other,"original valid twin kept")
end
tests.pair_to_pair_has_correct_partner=function()
    local env,p,old=setup(19,"main")
    assert(env.api.ResolveIdentitySwitch(p,env.api.FindProfile("the_forgotten_b")))
    eq(old.exists,false,"old Esau removed")
    assert(p.twin,"new native soul created after old twin cleanup")
    eq(p.twin:GetPlayerType(),40,"target pair has correct soul")
end
tests.same_pair_does_not_restore_stale_inventory=function()
    local env,p=setup(19,"main")
    assert(env.api.ResolveIdentitySwitch(p,env.api.FindProfile("isaac")))
    assert(env.api.ResolveIdentitySwitch(p,env.api.FindProfile("jacob")))
    p.twin.collectibleCounts[182]=1; p.twin.health.soulHearts=1
    assert(env.api.ResolveIdentitySwitch(p,env.api.FindProfile("jacob")))
    eq(p.twin:GetCollectibleNum(182),1,"same pair does not restore consumed item")
    eq(p.twin:GetSoulHearts(),1,"same pair does not heal partner")
end
local failed=0
for name,test in pairs(tests) do local ok,err=pcall(test); print((ok and "PASS " or "FAIL ")..name..(ok and "" or ": "..tostring(err))); if not ok then failed=failed+1 end end
PlayerManager=nil
assert(failed==0,tostring(failed).." pair regressions failed")
