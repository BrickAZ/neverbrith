local CopyTree = dofile('scripts/runtime/plain_data.lua').CopyTree
local function same(a, b)
    assert(type(a) == type(b))
    if type(a) ~= 'table' then assert(a == b); return end
    for key, value in pairs(a) do same(value, b[key]) end
    for key in pairs(b) do assert(a[key] ~= nil) end
end
assert(CopyTree(nil) == nil and CopyTree(false) == false and CopyTree(0) == 0)
local shared = {value = 3}
local source = {rows = {{id = 5, temporary = true}, {id = 6, data = {n = 0}}}, a = shared, b = shared}
local result = CopyTree(source)
same(source, result)
assert(result ~= source and result.rows ~= source.rows and result.rows[1] ~= source.rows[1])
assert(result.a ~= shared and result.b ~= shared and result.a ~= result.b, 'legacy trees do not preserve aliasing')
result.rows[2].data.n = 7
assert(source.rows[2].data.n == 0, 'nested results must be independently writable')
local key, marker = {}, function() end
local unusual = setmetatable({[key] = marker}, {__index = {inherited = true}})
local copied = CopyTree(unusual)
assert(copied[key] == marker and getmetatable(copied) == nil and copied.inherited == nil)
local visited = 0
local custom = setmetatable({}, {__pairs = function()
    visited = visited + 1
    return next, {fromPairs = {ok = true}}, nil
end})
assert(CopyTree(custom).fromPairs.ok and visited == 1, 'preserve pairs traversal rather than raw traversal')
local broken = setmetatable({}, {__pairs = function() error('copy traversal failed') end})
local ok, err = pcall(CopyTree, broken)
assert(not ok and tostring(err):find('copy traversal failed', 1, true), 'errors must propagate')
-- The public copier deliberately does not replace Blinky's stricter serializer.
local Core = dofile('blinky_core.lua')
assert(not pcall(Core.Clone, {leaf = marker}), 'Blinky must retain its nonserializable-leaf rejection')
print('plain data: independent nested values, alias/key/leaf/metatable/pairs/error contracts and Blinky policy passed')
