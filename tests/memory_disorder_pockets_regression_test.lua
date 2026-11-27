local fixture = assert(loadfile('tests/memory_disorder_behavior_test.lua'))('fixture')
local function eq(actual, expected, label)
    assert(actual == expected, label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local function checkPockets(player, expected, label)
    for slot = 0, 1 do
        eq(player:GetCard(slot), expected[slot][1], label .. ' card ' .. slot)
        eq(player:GetPill(slot), expected[slot][2], label .. ' pill ' .. slot)
    end
end
local combinations = {
    {[0]={18,0}, [1]={0,0}},
    {[0]={0,5}, [1]={19,0}},
    {[0]={18,0}, [1]={0,2053}}, -- Preserve the complete pill color/horse bit value.
    {[0]={0,0}, [1]={0,6}},
    {[0]={0,0}, [1]={0,0}},
}
for index, original in ipairs(combinations) do
    local e = fixture.makeEnvironment()
    local p = e.players[1]
    for slot=0,1 do
        if original[slot][1] ~= 0 then p:SetCard(slot, original[slot][1])
        else p:SetPill(slot, original[slot][2]) end
    end
    p.collectibleCounts[9000]=1; e.api.OnOwnershipUpdate(p)
    local isaac = assert(e.api.FindProfile('isaac'))
    local temporary = {id='pocket_regression', playerType=PlayerType.PLAYER_ISAAC,
        pocketCards={[0]=13,[1]=14}}
    for cycle=1,2 do
        assert(e.api.ResolveIdentitySwitch(p, temporary))
        checkPockets(p, {[0]={13,0},[1]={14,0}}, 'temporary')
        e.api.OnOwnershipUpdate(p)
        assert(e.api.ResolveIdentitySwitch(p, isaac))
        e.api.OnOwnershipUpdate(p)
        checkPockets(p, original, 'restore ' .. index .. '/' .. cycle)
        local state=e.api.GetRuntimeState(p)
        for slot=0,1 do
            eq(state.permanentPockets.cards[slot],original[slot][1],'permanent card ledger')
            eq(state.permanentPockets.pills[slot],original[slot][2],'permanent pill ledger')
        end
    end
    p.collectibleCounts[9000]=0; e.api.OnOwnershipUpdate(p)
    checkPockets(p, original, 'item loss')
end

-- Actual replacement/consumption remains permanent; do not resurrect old cards.
local e=fixture.makeEnvironment(); local p=e.players[1]
p.collectibleCounts[9000]=1; e.api.OnOwnershipUpdate(p)
assert(e.api.ResolveIdentitySwitch(p, {id='pocket_replaced',playerType=PlayerType.PLAYER_ISAAC,
    pocketCards={[0]=13,[1]=14}}))
p:SetPill(0,6); p:SetCard(1,0); e.api.OnOwnershipUpdate(p)
p.collectibleCounts[9000]=0; e.api.OnOwnershipUpdate(p)
checkPockets(p, {[0]={0,6},[1]={0,0}}, 'actual replacement/consumption')
print('memory_disorder_pockets_regression_test: 5 slot combinations, repeated switches, loss and replacement passed')
