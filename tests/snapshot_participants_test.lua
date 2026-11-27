local create=dofile('scripts/runtime/snapshot_participants.lua')
local function clone(v)
    if type(v)~='table'then return v end
    local r={};for k,x in pairs(v)do r[k]=clone(x)end;return r
end
local a,b=create(clone),create(clone)
local value={nested={count=3}}
a.Register('owner',function()return value end,function(v)value=v end)
assert(not pcall(a.Register,'owner',function()end,function()end))
local snapshot=a.Capture()
snapshot.owner.nested.count=8
assert(value.nested.count==3, 'capture must copy participant data')
a.Restore(snapshot)
assert(value.nested.count==8 and value~=snapshot.owner)
assert(next(b.Capture())==nil, 'separate installations cannot share participants')
a.Restore({})
assert(value==nil,'absent participant data must still call restore(nil)')
local bad=create(clone)
bad.Register('bad',function()error('capture failure')end,function()error('restore failure')end)
assert(not pcall(bad.Capture) and not pcall(bad.Restore,{}),'participant errors must propagate')
print('snapshot participants: capture/restore isolation, nil, duplicate names and errors passed')
