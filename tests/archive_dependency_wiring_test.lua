local build = dofile('tests/support/archive_pair_fixture.lua')
local failures, passed = {}, 0
local function check(name, run)
    local ok, message = pcall(run)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failures[#failures + 1] = name .. ': ' .. tostring(message) end
end
local function poison()
    return setmetatable({}, { __index = function() error('public alias used as peer dependency') end })
end
local function upvalue(fn, wanted)
    for i = 1, 100 do
        local name, value = debug.getupvalue(fn, i)
        if name == wanted then return value end
        if not name then break end
    end
    error('missing explicit dependency ' .. wanted)
end

check('factories return the same carrier objects as the compatibility aliases', function()
    local e = build()
    assert(type(e.carriers.certificate) == 'table' and type(e.carriers.house) == 'table')
    assert(e.carriers.certificate == e.mod.CertificateOfNeverbirthCarrierAPI)
    assert(e.carriers.house == e.mod.HouseVsElephantCarrierAPI)
end)

check('nested takeover, exclusion, updates and restoration ignore replaced public aliases', function()
    local e = build()
    e.mod.CertificateOfNeverbirthCarrierAPI, e.mod.HouseVsElephantCarrierAPI = poison(), poison()
    assert(e:use('certificate').ShowAnim)
    e:press('certificate', 'next')
    assert(e:use('certificate').ShowAnim)
    local stack = e.cert.GetPersistentData().stack
    local child = stack[2]
    assert(e:use('house').Remove)
    assert(e.house.GetPersistentData().session.parentCertificateToken == child.token)
    assert(e:use('certificate').ShowAnim == false and #stack == 2)
    e:advance(3)
    e.cert.Callbacks.NewRoom(e.mod)
    assert(#e:controls('certificate') == 0, 'active peer keeps the certificate suspended')
    e:press('house', 'return')
    assert(e.house.GetPersistentData().session == nil and #e:controls('certificate') == 3)
    e:press('certificate', 'return'); e:press('certificate', 'return'); e:arrive(10, 2)
    assert(#stack == 0 and e.root.unrelated.keep == 17)
end)

check('peer providers are resolved at event time and allow an explicitly absent peer', function()
    local e = build()
    local certificate, house = e.carriers.certificate, e.carriers.house
    local calls = 0
    e.carriers.house = { IsActive = function() calls = calls + 1; return true end }
    assert(e:use('certificate').ShowAnim == false and calls == 1)
    e.carriers.house = nil
    assert(e:use('certificate').ShowAnim)
    e.carriers.certificate = nil
    assert(e:use('house').Remove == false, 'unowned special room must not consume House')
    assert(e.house.GetPersistentData().session == nil)
    e.carriers.certificate, e.carriers.house = certificate, house
    assert(e:use('house').Remove)
    e:press('house', 'return')
    assert(e.cert.GetPersistentData().stack[1].phase == 'active')
end)

check('separate installations cannot redirect one another through exported aliases', function()
    local a, b = build(), build()
    a.mod.CertificateOfNeverbirthCarrierAPI = b.carriers.certificate
    a.mod.HouseVsElephantCarrierAPI = b.carriers.house
    assert(a:use('certificate').ShowAnim and a:use('house').Remove)
    assert(#b.cert.GetPersistentData().stack == 0 and b.house.GetPersistentData().session == nil)
    a:emit(ModCallbacks.MC_PRE_MOD_UNLOAD, a.mod)
    assert(not a.carriers.house.IsActive() and not a.carriers.certificate.IsCurrent())
    assert(b:use('certificate').ShowAnim and b:use('house').Remove)
end)

check('missing provider fails before a standalone factory registers or publishes anything', function()
    for _, name in ipairs({ 'certificate_of_neverbirth', 'house_vs_elephant' }) do
        local e = build()
        local mod, registered = {}, 0
        function mod:AddCallback() registered = registered + 1 end
        local ok = pcall(dofile('scripts/features/' .. name .. '.lua'), mod, {
            Store=e:section('isolated'), Items=e.ids, GetPlayers=function() return e.players end,
            GetCurrentRunSeed=function() return e.seed end, Log=function() end,
        })
        assert(not ok and registered == 0 and mod.CertificateOfNeverbirthCarrierAPI == nil
            and mod.HouseVsElephantCarrierAPI == nil)
    end
end)

check('construction does not resolve a peer that has not been installed yet', function()
    for _, name in ipairs({ 'certificate_of_neverbirth', 'house_vs_elephant' }) do
        local e = build()
        local mod = { AddCallback = function() end }
        local function notReady() error('peer resolved during installation') end
        local carrier = dofile('scripts/features/' .. name .. '.lua')(mod, {
            Store=e:section('isolated'), Items=e.ids, GetPlayers=function() return e.players end,
            GetCurrentRunSeed=function() return e.seed end, Log=function() end,
            GetHouseCarrier=notReady, GetCertificateCarrier=notReady,
        })
        assert(type(carrier) == 'table')
    end
end)

check('real main connects one pair through installation-local providers', function()
    local loadMod = dofile('tests/support/neverbirth_fixture.lua')
    loadMod()
    local cert, house = Neverbirth.CertificateOfNeverbirthTestAPI, Neverbirth.HouseVsElephantTestAPI
    local getHouse = upvalue(cert.Callbacks.UseItem, 'GetHouseCarrier')
    local getCertificate = upvalue(house.Callbacks.UseItem, 'GetCertificateCarrier')
    assert(getHouse() == Neverbirth.HouseVsElephantCarrierAPI)
    assert(getCertificate() == Neverbirth.CertificateOfNeverbirthCarrierAPI)
    assert(upvalue(cert.Callbacks.Update, 'GetHouseCarrier') == getHouse)
    assert(upvalue(cert.Callbacks.NewRoom, 'GetHouseCarrier') == getHouse)
    local ownCertificate, ownHouse = getCertificate(), getHouse()
    Neverbirth.CertificateOfNeverbirthCarrierAPI, Neverbirth.HouseVsElephantCarrierAPI = poison(), poison()
    assert(getCertificate() == ownCertificate and getHouse() == ownHouse)
    loadMod()
    assert(getCertificate() == ownCertificate and getHouse() == ownHouse, 'old provider cannot capture the new installation')
    assert(Neverbirth.CertificateOfNeverbirthCarrierAPI ~= ownCertificate)
end)

if #failures > 0 then error(table.concat(failures, '\n')) end
print('archive dependency wiring cases passed: ' .. passed)
