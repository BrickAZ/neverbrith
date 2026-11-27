local loadMod = dofile('tests/support/neverbirth_fixture.lua')
local imports = {}
local env = loadMod({ OnInclude = function(name) imports[name] = (imports[name] or 0) + 1 end })
for _, item in ipairs({'good_girl_of_babylon', 'the_moon_is_beautiful'}) do
    for _, part in ipairs(item == 'good_girl_of_babylon' and {'state','combat','rewards','presentation'} or {'room','combat','rewards','presentation'}) do
        assert(imports['scripts.features.'..item..'.'..part] == 1, item..'.'..part)
    end
end
assert(imports['scripts.systems.card_rewards'] == 3, 'stateless helper used by GoodGirl, Moon and BossOrder')
for _, name in ipairs({'EvaluateGoodGirlOfBabylon','HandleGoodGirlOfBabylonDamage','UpdateGoodGirlOfBabylon',
    'UpdateMoonIsBeautiful','EvaluateMoonIsBeautiful','HandleMoonIsBeautifulDamage'}) do
    local count = 0
    for _, records in pairs(env.callbacks) do for _, r in ipairs(records) do if r.fn == Neverbirth[name] then count=count+1 end end end
    assert(count == 1, name..' callback once')
    local previous, partial, callbacks = Neverbirth
    local ok, err = pcall(loadMod, {
        OnModCreated = function(m,c) partial,callbacks=m,c end,
        AfterRegister = function(m,_,fn) if m[name] == fn then error('batch8 failure '..name) end end,
    })
    assert(not ok and tostring(err):find('batch8 failure '..name,1,true))
    assert(Neverbirth == previous and partial.GoodGirl == nil and partial.Moon == nil)
    for _, records in pairs(callbacks) do assert(#records == 0) end
end
loadMod()
print('batch8 loading: eight item modules, stateless helper, six registration rollback boundaries and fresh load passed')
