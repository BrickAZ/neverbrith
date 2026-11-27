local loadMod = dofile('tests/support/neverbirth_fixture.lua')
-- No descriptions may be published until all gameplay installers have succeeded.
local calls, eid = 0
local ok, err = pcall(loadMod, { OnModCreated = function()
    eid = EID
    eid.addCollectible = function() calls = calls + 1 end
end, OnInclude = function(name)
    if name == 'scripts.features.debug_controller' then error('late gameplay failure') end
end })
assert(not ok and tostring(err):find('late gameplay failure', 1, true))
assert(calls == 0 and eid.ModIndicator.neverbirth == nil, 'failed gameplay bootstrap leaked external EID publication')

-- This matches the installed EID addCollectible storage contract: language.custom[5.100.id].
local function createEID(owner, priorIndicator)
    local old = { 11, 'prior name', 'prior description', 'other-mod' }
    local service = { _currentMod = owner, ModIndicator = { neverbirth = priorIndicator },
        descriptions = { en_us = { custom = { ['5.100.11'] = old, unrelated = 'keep' } } } }
    service.calls = 0
    function service:addCollectible(id, description, name, language)
        self.calls = self.calls + 1
        self.descriptions[language] = self.descriptions[language] or {}
        self.descriptions[language].custom = self.descriptions[language].custom or {}
        self.descriptions[language].custom['5.100.' .. id] = { id, name, description, self._currentMod }
        if self.calls == 2 then error('EID rejected the second write') end
    end
    return service, old
end
local factory = dofile('scripts/integrations/eid.lua')
for _, ownerCase in ipairs({ 'other-mod', false }) do
    for _, indicatorCase in ipairs({ { Name = 'previous indicator' }, false }) do
        local previousOwner = ownerCase or nil
        local previousIndicator = indicatorCase or nil
        local service, old = createEID(previousOwner, previousIndicator)
        EID = service
        local mod, logs = {}, {}
        function mod:AddCallback() end
        local integration = factory(mod, { Descriptions = { [11] = {
            en_us = { name = 'new', eidDescription = 'new description' },
            zh_cn = { name = '新', eidDescription = '新描述' },
        } }, LanguageOrder = { 'en_us', 'zh_cn' }, IsValidItemId = function() return true end,
            Log = function(message) logs[#logs + 1] = message end })
        assert(service.calls == 0, 'constructing the adapter must not publish descriptions')
        assert(integration.Publish() == false, 'optional EID failure must be reported without aborting gameplay')
        assert(service._currentMod == previousOwner, 'EID attribution was not restored')
        assert(service.ModIndicator.neverbirth == previousIndicator, 'EID indicator was not restored')
        assert(service.descriptions.en_us.custom['5.100.11'] == old, 'overwritten EID entry was not restored')
        assert(service.descriptions.en_us.custom.unrelated == 'keep', 'unrelated EID entry was changed')
        assert(service.descriptions.zh_cn == nil, 'failed EID publication left a newly created language table')
        for _ = 1, 3 do mod:TryRegisterEIDDescriptions() end
        assert(service.calls == 2 and #logs == 1, 'broken API must not be retried and logged every frame')
        -- A replacement API (late load/reload) gets one new attempt; success remains idempotent.
        function service:addCollectible(id, description, name, language)
            self.calls = self.calls + 1
            self.descriptions[language] = self.descriptions[language] or { custom = {} }
            self.descriptions[language].custom['5.100.' .. id] = { id, name, description, self._currentMod }
        end
        mod:TryRegisterEIDDescriptions()
        assert(service.calls == 4 and service.descriptions.zh_cn.custom['5.100.11'][2] == '新')
        assert(service._currentMod == previousOwner)
        mod:TryRegisterEIDDescriptions()
        assert(service.calls == 4, 'successful EID publication must run once')
    end
end
local loaded = loadMod()
assert(#loaded.eidCalls == 138, 'successful complete entry must retain all localized descriptions')
print('EID lifecycle: deferred publication, partial-write rollback, attribution, bounded failure and recovery passed')
