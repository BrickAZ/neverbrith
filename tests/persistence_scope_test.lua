local Persistence = dofile('scripts/runtime/persistence.lua')
local root = {a={run='same',value=9}, b={untouched=true}, future={version=99}}
local loads, writes, initialized, encoded = 0, 0, 0
local store = Persistence.Create({
    HasData=function() return true end,
    LoadData=function() loads=loads+1; return 'old bytes' end,
    SaveData=function(_, bytes) assert(bytes=='saved'); writes=writes+1 end,
}, {
    Json={decode=function() return root end, encode=function(data) encoded=data; return 'saved' end},
    Initialize=function(data) initialized=initialized+1; data.legacy={} end,
})
local names={'a','missing'}
local scope=store.Scope(names)
names[1]='future' -- caller mutation must not expand permissions
assert(loads==0 and initialized==0, 'wiring must not load or create fields')
local view=scope.GetRoot()
assert(loads==1 and initialized==1 and view.a==root.a and view.missing==nil)
assert(root.missing==nil, 'a missing read must not change save shape')
assert(not pcall(function() return view.b end), 'cross-feature read must fail')
assert(not pcall(function() view.future={} end), 'cross-feature write must fail')
local replacement={run='same',value=4}
view.a=replacement
assert(root.a==replacement and store.Section('a').Get()==replacement)
store.Section('a').Replace({value=7})
assert(view.a.value==7 and scope.GetRoot()==view, 'replacement must not leave stale view')
view.a=nil
assert(root.a==nil and view.a==nil, 'new-run clear must retain nil, not insert an empty table')
view.missing=false
assert(root.missing==false, 'raw legacy values are preserved until their owner validates')
local fields={}; for k,v in pairs(view) do fields[k]=v end
assert(fields.missing==false and fields.b==nil and fields.future==nil)
assert(scope.Save() and encoded==root and root.future.version==99 and root.b.untouched)
assert(writes==1, 'scope changes do not add save points')
for _, nameset in ipairs({{}, {'a','a'}, {''}}) do assert(not pcall(store.Scope,nameset)) end
local failures,writesOnFailure=0,0
local bad=Persistence.Create({HasData=function()return true end,LoadData=function()return 'bad'end,
    SaveData=function()writesOnFailure=writesOnFailure+1 end}, {
    Json={decode=function()failures=failures+1;error('corrupt')end,encode=function()error('must not write')end},
})
local region=bad.Scope('a')
assert(not pcall(region.GetRoot) and not pcall(region.GetRoot))
assert(region.Save()==false and failures==1 and writesOnFailure==0)
print('save scopes: lazy reads, exact nil/false, ownership, replacement, full save and failure protection passed')
