local fixture = assert(loadfile("tests/memory_disorder_behavior_test.lua"))("fixture")
local function eq(a, b, label) assert(a == b, label .. ": expected " .. tostring(b) .. ", got " .. tostring(a)) end
local function setup(kind, red, soul)
    local env = fixture.makeEnvironment()
    local p = env.players[1]
    p.playerType = kind
    p.health.maxHearts, p.health.hearts, p.health.soulHearts = red, red, soul
    p.soulCharge, p.bloodCharge = 7, 9
    function p:GetHealthType()
        local t = self.playerType
        if t == 10 or t == 31 then return 2 end
        if t == 14 or t == 33 then return 3 end
        if t == 16 then return 4 end
        if t == 4 or t == 12 or t == 17 or t == 24 or t == 25 or t == 35 or t == 36 or t == 40 then return 1 end
        return 0
    end
    function p:GetHeartLimit() return self:GetHealthType() == 3 and (self.playerType == 33 and 4 or 6) or 24 end
    function p:AddMaxHearts(n)
        local mode = self:GetHealthType()
        if mode == 1 or mode == 2 then return end
        if mode == 4 then self:AddBoneHearts(math.floor(n / 2)); return end
        self.health.maxHearts = math.max(0, math.min(self:GetHeartLimit(), self.health.maxHearts + n))
        self.health.hearts = math.min(self.health.hearts, self.health.maxHearts + self.health.boneHearts * 2)
    end
    function p:AddHearts(n)
        if self.playerType == 36 and n > 0 then self.bloodCharge = self.bloodCharge + n; return end
        self.health.hearts = math.max(0, math.min(self.health.maxHearts + self.health.boneHearts * 2, self.health.hearts + n))
    end
    function p:AddSoulHearts(n)
        if n > 0 and self.playerType == 18 then self.soulCharge = self.soulCharge + n; return end
        if n > 0 and self:GetHealthType() == 3 then return end
        self.health.soulHearts = math.max(0, self.health.soulHearts + n)
        self.health.blackHearts = self.health.blackHearts % (2 ^ math.ceil(self.health.soulHearts / 2))
    end
    function p:AddBlackHearts(n)
        local before = self.health.soulHearts
        self:AddSoulHearts(n)
        for i = before, self.health.soulHearts - 1 do
            self.health.blackHearts = self.health.blackHearts | (1 << math.floor(i / 2))
        end
    end
    function p:GetSoulCharge() return self.soulCharge end
    function p:SetSoulCharge(n) self.soulCharge = n end
    function p:GetBloodCharge() return self.bloodCharge end
    function p:SetBloodCharge(n) self.bloodCharge = n end
    local change = p.ChangePlayerType
    function p:ChangePlayerType(t)
        change(self, t)
        if self:GetHealthType() == 2 then self.health.maxHearts, self.health.hearts, self.health.soulHearts = 0, 0, 1 end
    end
    p.collectibleCounts[9000] = 1
    env.api.OnOwnershipUpdate(p)
    return env, p
end
local function switch(env, p, target) assert(env.api.ResolveIdentitySwitch(p, assert(env.api.FindProfile(target)))) end
local tests = {}
tests.conversion_matrix = function()
    for _, c in ipairs({
        {0,6,0,"blue_baby",0,6}, {0,6,0,"blue_baby_b",0,6},
        {0,6,2,"blue_baby",0,8}, {4,0,6,"bethany",6,0},
        {4,0,6,"keeper",6,0}, {4,0,4,"keeper_b",4,0},
        {4,0,6,"isaac",0,6}, {0,6,0,"bethany_b",0,6},
        {0,6,0,"judas_b",0,6}, {10,0,1,"isaac",0,1},
    }) do
        local env,p=setup(c[1],c[2],c[3]); switch(env,p,c[4])
        eq(p:GetHearts(),c[5],c[4] .. " red HP"); eq(p:GetSoulHearts(),c[6],c[4] .. " soul HP")
    end
end
tests.damage_survives_continue = function()
    local env,p=setup(0,6,2); switch(env,p,"blue_baby"); p:AddSoulHearts(-4)
    env.api.OnPreGameExit(); env.api.OnGameStarted(true); switch(env,p,"isaac")
    eq(p:GetMaxHearts(),6,"latent capacity"); eq(p:GetHearts()+p:GetSoulHearts(),4,"damage survives continue")
end
tests.resources_and_latent_health = function()
    local env,p=setup(0,6,2); switch(env,p,"bethany")
    eq(p:GetSoulCharge(),7,"no fabricated soul charge"); p.soulCharge=5
    switch(env,p,"isaac"); eq(p:GetHearts(),6,"red survives"); eq(p:GetSoulHearts(),2,"soul survives")
    switch(env,p,"bethany"); eq(p:GetSoulCharge(),5,"spent charge stays spent")
    switch(env,p,"bethany_b"); eq(p:GetBloodCharge(),9,"no fabricated blood charge")
end
tests.lost_and_no_resurrection = function()
    local env,p=setup(0,6,2); switch(env,p,"the_lost")
    eq(p:GetSoulHearts(),1,"native Lost life"); switch(env,p,"isaac")
    eq(p:GetHearts()+p:GetSoulHearts(),8,"Lost transition preserves ledger")
    p.dead=true
    eq(env.api.ResolveIdentitySwitch(p,env.api.FindProfile("blue_baby")),false,"dead player is not switched")
end
tests.failed_health_write_rolls_back = function()
    local env,p=setup(0,6,0)
    local add=p.AddSoulHearts
    function p:AddSoulHearts(n) if self.playerType==4 and n>0 then return end; return add(self,n) end
    eq(env.api.ResolveIdentitySwitch(p,env.api.FindProfile("blue_baby")),false,"failed health write is not success")
    eq(p:GetPlayerType(),0,"restore original type after refused health")
    eq(p:GetHearts(),6,"restore live HP after refused health")
end
tests.legacy_zero_lost_ledger = function()
    local env,p=setup(10,0,1)
    env.api.GetRuntimeState(p).healthLedger.soulHearts=0
    switch(env,p,"isaac")
    eq(p:GetSoulHearts(),1,"legacy Lost state retains native half-heart")
end
tests.forgotten_soul_is_included_in_health = function()
    local env,p=setup(16,0,0)
    p.health.boneHearts,p.health.hearts=2,2
    local soul=fixture.makePlayer(909,17)
    soul.ControllerIndex=p.ControllerIndex
    soul.health.maxHearts,soul.health.hearts,soul.health.soulHearts=0,0,4
    function p:GetSubPlayer() return soul end
    function soul:GetSubPlayer() return p end
    -- Refresh the initial snapshot after supplying the engine's subplayer.
    env.api.GetSavedState().players={}; env.api.Runtime.states={}
    env.api.OnOwnershipUpdate(p)
    switch(env,p,"isaac")
    eq(p:GetSoulHearts(),4,"Forgotten's Soul HP must not disappear")
end
tests.black_hearts_survive_conversion_and_damage = function()
    local env,p=setup(0,6,2)
    p.health.blackHearts=1; env.api.GetRuntimeState(p).healthLedger.blackMask=1
    switch(env,p,"blue_baby"); p:AddSoulHearts(-2); switch(env,p,"isaac")
    eq(p:GetHearts(),4,"converted outer red health takes damage first")
    eq(p:GetSoulHearts(),2,"original soul health survives outer damage")
    eq(p:GetBlackHearts(),1,"original black heart remains black")
    switch(env,p,"blue_baby"); p:AddBlackHearts(2); switch(env,p,"isaac")
    eq(p:GetSoulHearts(),4,"new black health retained")
    eq(p:GetBlackHearts(),3,"new black heart remapped past converted red health")
    switch(env,p,"blue_baby"); p:AddBlackHearts(2)
    env.api.OnPreGameExit(); env.api.OnGameStarted(true)
    p:AddSoulHearts(-2); switch(env,p,"isaac")
    eq(p:GetHearts(),4,"new outer heart is consumed before converted health")
    eq(p:GetSoulHearts(),4,"continued pickup damage keeps original soul amount")
    eq(p:GetBlackHearts(),3,"continued pickup damage preserves remaining colors")
end
tests.failed_loss_restore_keeps_recoverable_state = function()
    local env,p=setup(0,6,0); switch(env,p,"blue_baby")
    local change=p.ChangePlayerType
    function p:ChangePlayerType(t) if t==0 then return end; change(self,t) end
    p.collectibleCounts[9000]=0
    eq(env.api.OnOwnershipUpdate(p),false,"refused original identity is not settled")
    assert(env.api.GetRuntimeState(p),"failed restoration keeps original identity ledger")
    eq(p:GetPlayerType(),4,"valid current identity retained")
    p.ChangePlayerType=change
    assert(env.api.OnOwnershipUpdate(p))
    eq(p:GetPlayerType(),0,"next update can finish restoration")
    eq(p:GetHearts(),6,"health recovered without a starting-health reset")
end
local failed=0
for name,test in pairs(tests) do
    local ok,err=pcall(test)
    print((ok and "PASS " or "FAIL ") .. name .. (ok and "" or ": " .. tostring(err)))
    if not ok then failed=failed+1 end
end
assert(failed==0,tostring(failed) .. " health regressions failed")
