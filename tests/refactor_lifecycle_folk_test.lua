-- Boundary regressions use the real owners, never copied implementation bodies.
local savedArg = arg; arg = { '--fixture' }
local folkFixture = dofile('tests/folk_horror_items_behavior_test.lua')
local girlFixture = dofile('tests/good_girl_of_babylon_behavior_test.lua')
arg = savedArg
local checks, failures = 0, {}
local function check(name, fn)
    checks = checks + 1
    local ok, err = pcall(fn)
    if ok then print('PASS ' .. name) else failures[#failures + 1] = name .. ': ' .. tostring(err) end
end
local function cache(e, p)
    p.evaluations = 0
    function p:EvaluateItems()
        self.evaluations = self.evaluations + 1
        self.Damage, self.MoveSpeed, self.MaxFireDelay, self.TearRange, self.Luck = 3.5, 1, 10, 260, 0
        for _, flag in ipairs({ CacheFlag.CACHE_DAMAGE, CacheFlag.CACHE_SPEED, CacheFlag.CACHE_FIREDELAY, CacheFlag.CACHE_RANGE, CacheFlag.CACHE_LUCK }) do
            e.runEvaluate(self, flag)
        end
    end
end
local function brokenMask()
    local e = folkFixture()
    local p = e.newPlayer({ coins = 5, collectibles = { [e.items.CoinFacedMask] = 1 } })
    cache(e, p); e.runNewRoom(); p.coins = 0; e.runDamage(p, 1, 0, e.newEnemy())
    assert(p.Luck == -2)
    return e, p
end
check('mask floor reset refreshes previous penalty exactly once', function()
    local e, p = brokenMask(); local before = p.evaluations
    e.mod:ClearCoinFacedMaskCostumes()
    assert(p.Luck == 0 and p.evaluations == before + 1, 'floor reset left old luck cache')
    e.mod:ClearCoinFacedMaskCostumes(); assert(p.evaluations == before + 1)
end)
check('mask same-seed new run resets cache while Continue preserves penalty', function()
    local e, p = brokenMask()
    e.mod:ResetFolkHorrorItemState(true); assert(p.Luck == -2)
    e.mod:ResetFolkHorrorItemState(false)
    assert(p.Luck == 0, 'new run left old mask luck cache')
end)
check('Black Taisui does not count healing while absent on reacquisition', function()
    local e = folkFixture()
    local p = e.newPlayer({ hearts = 2, maxHearts = 6, collectibles = { [e.items.BlackTaisui] = 1 } })
    e.mod:UpdateBlackTaisui(); p.collectibles[e.items.BlackTaisui] = nil
    e.mod:UpdateBlackTaisui(); p.hearts = 6
    p.collectibles[e.items.BlackTaisui] = 1; e.mod:UpdateBlackTaisui()
    assert(e.mod:GetBlackTaisuiParasiteValue(p) == 0, 'absent-item healing was counted after reacquisition')
end)
check('cleansed cap queued correction cannot write a replacement active item', function()
    local e = folkFixture()
    local p = e.newPlayer({ collectibles = { [e.items.CleansedWavyCap] = 1 },
        activeItems = { [0] = e.items.CleansedWavyCap }, activeCharges = { [0] = 900 } })
    e.runUse(e.items.CleansedWavyCap, p, 0)
    p.activeItems[0] = 999; p.activeItems[1] = e.items.CleansedWavyCap; p.activeCharges[0] = 17
    e.mod:UpdateBlackTaisui()
    assert(p.activeCharges[0] == 17, 'deferred correction overwrote another active item')
    local s = e.mod:GetCleansedWavyCapState(p)
    assert(s.cleansedWavyChargeDelay == nil and s.cleansedWavyChargeRepeats == nil, 'invalid charge lease remained queued')
end)
check('Good Girl new run refreshes old echo and broken luck', function()
    local e = girlFixture(); local p = e.newPlayer(); cache(e, p)
    e.runDamage(p, 1, DamageFlag.DAMAGE_RED_HEARTS); e.runPostUpdate()
    assert(p.Damage == 4.7 and p.Luck == -2)
    Neverbirth:ResetFolkHorrorItemState(false)
    assert(p.Damage == 3.5 and p.Luck == 2, 'new run retained old echo or broken cache')
end)

local function isolated()
    folkFixture() -- establishes native constants and vectors only
    ModCallbacks.MC_PRE_MOD_UNLOAD = 91001
    local mod = { callbacks = {} }
    function mod:AddCallback(event, fn, filter)
        self.callbacks[event] = self.callbacks[event] or {}
        table.insert(self.callbacks[event], { fn = fn, filter = filter })
    end
    local function fire(event, ...)
        for _, entry in ipairs(mod.callbacks[event] or {}) do entry.fn(mod, ...) end
    end
    local players, entities = {}, {}
    local roomIndex, floor = 1, 1
    local room = { IsClear = function() return true end, GetType = function() return 1 end, GetSpawnSeed = function() return roomIndex end }
    local level = { GetStage = function() return floor end, GetStageType = function() return 0 end, GetCurrentRoomIndex = function() return roomIndex end }
    Game = function() return { GetRoom = function() return room end, GetLevel = function() return level end } end
    Isaac.GetRoomEntities = function() return entities end
    local function player(seed, item)
        local p = { InitSeed = seed, item = item, Damage = 3.5, Luck = 0, Position = Vector(100, 100), evaluations = 0 }
        function p:GetCollectibleNum(id) return id == self.item and 1 or 0 end
        function p:HasCollectible(id) return self:GetCollectibleNum(id) > 0 end
        function p:GetActiveItem() return self.item end
        function p:ToPlayer() return self end
        function p:AddCacheFlags() end
        function p:GetSoulHearts() return 2 end
        function p:GetBlackHearts() return 1 end
        function p:EvaluateItems()
            self.Damage, self.Luck = 3.5, 0; self.evaluations = self.evaluations + 1
            fire(ModCallbacks.MC_EVALUATE_CACHE, self, CacheFlag.CACHE_DAMAGE)
            fire(ModCallbacks.MC_EVALUATE_CACHE, self, CacheFlag.CACHE_LUCK)
        end
        players[#players + 1] = p; return p
    end
    return { mod = mod, fire = fire, player = player, players = players, entities = entities,
        getPlayers = function() return players end }
end
check('empty cradle new run invalidates already-evaluated black-heart reward', function()
    local e = isolated(); local p = e.player(101, 737)
    dofile('scripts/features/empty_cradle.lua')(e.mod, { ItemId = 737, GetPlayers = e.getPlayers,
        GetCurrentRunSeed = function() return 'SAME' end, IsBloodSkullBacklashActive = function() return false end })
    e.mod:HandleEmptyCradleDamage(p, 1, 0, EntityRef(p)); e.mod:UpdateEmptyCradleRewards()
    assert(p.Damage == 4.5)
    e.fire(ModCallbacks.MC_POST_GAME_STARTED, true); assert(p.Damage == 4.5)
    e.fire(ModCallbacks.MC_POST_GAME_STARTED, false)
    assert(p.Damage == 3.5, 'new run cleared state but not damage cache')
end)
check('shredded tarot loss clears its luck once without native cache notification', function()
    local e = isolated(); local p = e.player(102, 738)
    dofile('scripts/features/shredded_tarot.lua')(e.mod, { ItemId = 738, GetPlayers = e.getPlayers })
    e.mod:TrackShreddedTarotHolders(); p:EvaluateItems(); assert(p.Luck == 3)
    local before = p.evaluations; p.item = nil; e.mod:TrackShreddedTarotHolders()
    assert(p.Luck == 0 and p.evaluations == before + 1, 'lost tarot left luck cache')
    e.mod:TrackShreddedTarotHolders(); assert(p.evaluations == before + 1)
end)
check('sword unload releases hold and ignores a different mod unload', function()
    local e = isolated(); local p = e.player(103, 748)
    local input = dofile('scripts/features/coin_sewn_sword/input.lua')(e.mod, { CoinSewnSwordId = 748,
        Fire = function() error('stale hold fired') end, VectorFromInput = function() return nil end,
        Rules = { COIN_SWORD_NO_DISCHARGE_RESULT = {} } })
    input.InstallHoldCallbacks(); e.mod:UseCoinSewnSword(nil, nil, p, nil, 0)
    assert(e.mod:CoinSwordInputAction(p, InputHook.GET_ACTION_VALUE, ButtonAction.ACTION_SHOOTLEFT) == 0)
    e.fire(ModCallbacks.MC_PRE_MOD_UNLOAD, {})
    assert(e.mod:CoinSwordInputAction(p, InputHook.GET_ACTION_VALUE, ButtonAction.ACTION_SHOOTLEFT) == 0)
    e.fire(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod); e.fire(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod)
    assert(e.mod:CoinSwordInputAction(p, InputHook.GET_ACTION_VALUE, ButtonAction.ACTION_SHOOTLEFT) == nil, 'unload left input held')
    e.mod:UseCoinSewnSword(nil, nil, p, nil, 0)
    assert(e.mod:CoinSwordInputAction(p, InputHook.GET_ACTION_VALUE, ButtonAction.ACTION_SHOOTLEFT) == nil, 'disposed owner accepted a hold')
end)
check('sterilization exit releases cached NPC and old update cannot reacquire it', function()
    local e = isolated(); e.player(104, 736)
    dofile('scripts/features/sterilization_certificate.lua')(e.mod, { ItemId = 736, GetPlayers = e.getPlayers })
    local weak = setmetatable({}, { __mode = 'v' })
    do
        local npc = { InitSeed = 7, Type = 16, IsVulnerableEnemy = function() return true end }
        weak[1], e.entities[1] = npc, npc
        e.mod:TrackSterilizationNewRoom()
    end
    e.entities[1] = nil; e.fire(ModCallbacks.MC_PRE_GAME_EXIT)
    collectgarbage('collect'); collectgarbage('collect')
    assert(weak[1] == nil, 'module retained spawner entity after exit')
    Isaac.GetRoomEntities = function() error('world queried after exit') end
    e.mod:UpdateSterilizationCertificate(); e.mod:TrackSterilizationNewRoom()
end)
check('private sword helpers are not exported on the mod instance', function()
    local e = folkFixture()
    for _, name in ipairs({ '__coinSwordInputBlocks', 'CoinSwordYieldsAttack', 'CoinSwordPlayerAvailable',
        'GetNearestEnemyDirectionFromPosition', 'SafeSetCoinSwordField', 'UpdateCoinSwordVisualDirection',
        'IsCoinSwordEnemyProjectile', 'RemoveCoinSwordBlockedProjectile' }) do
        assert(e.mod[name] == nil, name .. ' still published')
    end
end)
check('shared folk exit pauses all old callbacks and Continue preserves plain echo state', function()
    local e = girlFixture(); local p = e.newPlayer(); local mod = Neverbirth
    cache(e, p); e.runDamage(p, 1, DamageFlag.DAMAGE_RED_HEARTS); e.runPostUpdate()
    local state = GetGoodGirlState(p); local echo = state.echoEffect; local frames = state.echoFrames
    mod:ExitFolkHorrorItemState(); mod:ExitFolkHorrorItemState()
    assert(state.echoEffect == nil and state.haloEffect == nil and echo.removed)
    assert(state.echoFrames == frames and state.broken, 'exit erased Continue gameplay state')
    local oldGame, oldFind = Game, Isaac.FindByType
    Game = function() error('world after exit') end
    Isaac.FindByType = function() error('players after exit') end
    mod:UpdateGoodGirlOfBabylon(); mod:RefreshGoodGirlOfBabylonRoom()
    mod:UpdateBlackTaisui(); mod:RenderBlackTaisuiLifeHud(); mod:ResetBlackTaisuiOnNewLevel()
    mod:RecoverMeatLumpDeadPlayers(); mod:TrackMeatLumpOneUpCopies()
    mod:UpdateCoinFacedMaskCostumes(); mod:RefreshCoinFacedMaskRoom(); mod:AdvanceCleansedWavyCapRooms()
    assert(state.echoFrames == frames)
    Game, Isaac.FindByType = oldGame, oldFind
    mod:ResetFolkHorrorItemState(true)
    assert(GetGoodGirlState(p) == state and p.Damage == 4.7 and p.Luck == -2)
    e.runPostUpdate(); assert(state.echoFrames == frames - 1 and state.echoEffect)
    mod:UnloadFolkHorrorItemState({}); assert(next(mod.GoodGirl.states))
    Game = function() error('world during unload') end
    mod:UnloadFolkHorrorItemState(mod); mod:UnloadFolkHorrorItemState(mod)
    mod:ResetFolkHorrorItemState(false); mod:UpdateGoodGirlOfBabylon()
    assert(next(mod.GoodGirl.states) == nil)
    Game = oldGame
end)
for _, spec in ipairs({
    { file = 'blood_skull_gu', exit = 'ExitBloodSkullGu', start = 'ResetBloodSkullGuState', unload = 'UnloadBloodSkullGu', call = 'UseBloodSkullGu' },
    { file = 'empty_cradle', exit = 'ExitEmptyCradle', start = 'ResetEmptyCradleState', unload = 'UnloadEmptyCradle', call = 'UpdateEmptyCradleRewards' },
    { file = 'shredded_tarot', exit = 'ExitShreddedTarot', start = 'ResetShreddedTarotState', unload = 'UnloadShreddedTarot', call = 'TrackShreddedTarotHolders' },
    { file = 'between_death_and_life', exit = 'ExitBetweenDeathLife', start = 'ResetBetweenDeathLifeState', unload = 'UnloadBetweenDeathLife', call = 'UpdateBetweenDeathLifeBossReward' },
}) do
    check(spec.file .. ' exit and unload prevent stale world/player access', function()
        local e = isolated(); local forbidden = false
        local data = { runSeed = 'SAME', spawnedByFloor = {}, preActivationBossClearedFloors = {} }
        local deps = { ItemId = 777, Items = { BetweenDeathAndLife = 777 },
            GetPlayers = function() assert(not forbidden, 'players accessed while stopped'); return e.players end,
            GetCurrentRunSeed = function() return 'SAME' end, IsValidItemId = function(id) return type(id) == 'number' and id > 0 end,
            IsBloodSkullBacklashActive = function() return false end, Log = function() end,
            Store = { Get = function() assert(not forbidden, 'save queried while stopped'); return data end,
                Replace = function(value) data = value end, Save = function() end } }
        dofile('scripts/features/' .. spec.file .. '.lua')(e.mod, deps)
        assert(e.mod[spec.exit] and e.mod[spec.unload], 'missing owner lifecycle handlers')
        e.fire(ModCallbacks.MC_PRE_GAME_EXIT); e.fire(ModCallbacks.MC_PRE_GAME_EXIT); forbidden = true
        local function call()
            if spec.file == 'blood_skull_gu' then
                local poison = setmetatable({}, { __index = function() error('old player accessed') end })
                e.mod[spec.call](e.mod, nil, nil, poison)
            else e.mod[spec.call](e.mod) end
        end
        call(); e.fire(ModCallbacks.MC_PRE_MOD_UNLOAD, {})
        forbidden = false; e.fire(ModCallbacks.MC_POST_GAME_STARTED, true)
        e.fire(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod); e.fire(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod)
        forbidden = true; e.fire(ModCallbacks.MC_POST_GAME_STARTED, false); call()
    end)
end
check('death trial same-seed reset preserves unowned section extensions', function()
    local e = isolated()
    local data = { runSeed = 'SAME', active = true, extension = { keep = 7 }, spawnedByFloor = { old = true } }
    dofile('scripts/features/between_death_and_life.lua')(e.mod, {
        Items = { BetweenDeathAndLife = 777 }, GetCurrentRunSeed = function() return 'SAME' end,
        IsValidItemId = function(id) return type(id) == 'number' and id > 0 end, Log = function() end,
        Store = { Get = function() return data end, Replace = function(value) data = value end, Save = function() end },
    })
    e.fire(ModCallbacks.MC_POST_GAME_STARTED, true)
    assert(data.active == true and data.spawnedByFloor.old)
    e.fire(ModCallbacks.MC_POST_GAME_STARTED, false)
    assert(data.active == false and next(data.spawnedByFloor) == nil)
    assert(data.extension and data.extension.keep == 7, 'new run erased an unowned extension')
end)
check('sword exit releases projectile owners and rejects stale input until Continue', function()
    local e = folkFixture()
    local p = e.newPlayer({ coins = 1, shootingInput = Vector(1, 0) })
    e.runUse(e.items.CoinSewnSword, p); e.runPrePlayer(p)
    local effect
    for _, spawn in ipairs(e.spawns) do
        if spawn.GetData and spawn:GetData().NeverbirthCoinSwordQi then effect = spawn; break end
    end
    assert(effect and effect:GetData().Owner == p)
    for _, callback in ipairs(e.getCallbacks(ModCallbacks.MC_PRE_GAME_EXIT)) do callback(e.mod, true) end
    assert(effect:GetData().Owner == nil and effect.removed, 'exit retained sword projectile owner')
    e.mod:UseCoinSewnSword(nil, nil, p, nil, 0)
    assert(e.mod:CoinSwordInputAction(p, InputHook.GET_ACTION_VALUE, ButtonAction.ACTION_SHOOTLEFT) == nil)
    local oldEntities = Isaac.GetRoomEntities
    Isaac.GetRoomEntities = function() error('stale projectile queried room') end
    e.mod:UpdateCoinSwordQi(effect)
    Isaac.GetRoomEntities = oldEntities
    for _, callback in ipairs(e.getCallbacks(ModCallbacks.MC_POST_GAME_STARTED)) do callback(e.mod, true) end
    p.shootingInput = Vector(0, 0); e.runUse(e.items.CoinSewnSword, p)
    assert(e.mod:CoinSwordInputAction(p, InputHook.GET_ACTION_VALUE, ButtonAction.ACTION_SHOOTLEFT) == 0)
end)
local function capCache()
    local e = folkFixture({ roomClear = false })
    local p = e.newPlayer({ collectibles = { [e.items.BlackTaisui] = 1, [e.items.CleansedWavyCap] = 1 },
        activeItems = { [0] = e.items.CleansedWavyCap }, activeCharges = { [0] = 900 } })
    cache(e, p); e.mod:SetBlackTaisuiParasiteValue(p, 8)
    e.runUse(e.items.CleansedWavyCap, p, 0)
    assert(p.MoveSpeed == 0.97 and p.MaxFireDelay == 9.25, 'must create actual cap cache through use')
    return e, p
end
check('cap cache is restored on new run after losing only Black Taisui', function()
    local e, p = capCache(); p.collectibles[e.items.BlackTaisui] = nil
    e.mod:ResetFolkHorrorItemState(false)
    assert(p.MoveSpeed == 1 and p.MaxFireDelay == 10, 'cap-only owner retained pre-reset cache')
    assert(e.mod:GetCleansedWavyCapState(p).cleansedWavyCurrentTears == 0)
end)
check('cap Continue keeps floor state but reconciles a lost Black Taisui gate', function()
    local e, p = capCache(); local state = e.mod:GetCleansedWavyCapState(p)
    p.collectibles[e.items.BlackTaisui] = nil
    e.mod:ExitFolkHorrorItemState(); e.mod:ResetFolkHorrorItemState(true)
    assert(e.mod:GetCleansedWavyCapState(p) == state and state.cleansedWavyCurrentTears == 0.75)
    assert(p.MoveSpeed == 1 and p.MaxFireDelay == 10, 'Continue retained cache while its ownership gate is false')
end)
check('Black Taisui item loss and reacquisition reconcile cache once', function()
    local e = folkFixture(); local p = e.newPlayer({ collectibles = { [e.items.BlackTaisui] = 1 } })
    cache(e, p); e.mod:SetBlackTaisuiParasiteValue(p, 16); e.mod:UpdateBlackTaisui()
    assert(p.Damage == 5); local before = p.evaluations
    p.collectibles[e.items.BlackTaisui] = nil; e.mod:UpdateBlackTaisui()
    assert(p.Damage == 3.5 and p.evaluations == before + 1, 'loss left mature damage cached')
    e.mod:UpdateBlackTaisui(); assert(p.evaluations == before + 1)
    p.collectibles[e.items.BlackTaisui] = 1; e.mod:UpdateBlackTaisui()
    assert(p.Damage == 5 and p.evaluations == before + 2, 'reacquisition did not restore saved stage cache')
end)
check('tarot new run invalidates pre-start luck from an absent old holder', function()
    local e = isolated(); local p = e.player(105, 738)
    dofile('scripts/features/shredded_tarot.lua')(e.mod, { ItemId = 738, GetPlayers = e.getPlayers })
    e.mod:TrackShreddedTarotHolders(); p:EvaluateItems(); assert(p.Luck == 3)
    p.item = nil; e.fire(ModCallbacks.MC_POST_GAME_STARTED, false)
    assert(p.Luck == 0, 'new run left old tarot luck')
end)
check('fresh loader Continue consumes the restored Taisui state in initial native cache', function()
    local store = { snapshot = { blackTaisui = { runSeed = 'TEST RUN', players = { ['106'] = { parasite = 16, meatLumpSpawned = true } }, meatLumpCounts = {}, meatLumpLives = {} } } }
    local e = folkFixture({ savedStore = store })
    local p = e.newPlayer({ initSeed = 106, collectibles = { [e.items.BlackTaisui] = 1 } }); cache(e, p)
    p:EvaluateItems(); assert(p.Damage == 5)
    e.mod:ResetFolkHorrorItemState(true); e.mod:UpdateBlackTaisui()
    assert(p.Damage == 5 and e.mod:GetBlackTaisuiParasiteValue(p) == 16)
end)
check('fresh Good Girl Continue closes its first update cache without old runtime state', function()
    local e = girlFixture(); local p = e.newPlayer(); cache(e, p)
    Neverbirth:ResetFolkHorrorItemState(true); Neverbirth:UpdateGoodGirlOfBabylon()
    assert(p.Luck == 2 and p.MaxFireDelay == 9.4 and p.evaluations == 1)
end)
check('death trial defers frame-zero NPC init until new-run versus Continue is known', function()
    local fixture = assert(loadfile('tests/between_death_and_life_behavior_test.lua'))('--fixture')
    for _, paused in ipairs({ false, true }) do
    for _, continued in ipairs({ false, true }) do
        local e = fixture({ hasData = true, savedRoot = { deathTrial = { active = true, runSeed = 'TEST RUN',
            activatedRoomKey = 'old-room', activatedFloorKey = 'old-floor', spawnedByFloor = {}, preActivationBossClearedFloors = {} } } })
        local nativeGame = Game
        Game = function() local g = nativeGame(); g.GetFrameCount = function() return 0 end; return g end
        e.level.currentRoomIndex = 2
        local npc = e.newNpc({ type = EntityType.ENTITY_FLY })
        Isaac.GetRoomEntities = function() return { npc } end
        if paused then e.mod:ExitBetweenDeathLife() end
        e.runPostNpcInit(npc)
        assert(not npc.champion, 'NPC init used the previous same-seed run before GAME_STARTED')
        for _, record in ipairs(e.callbacks[ModCallbacks.MC_POST_GAME_STARTED]) do
            if record.fn == e.mod.ResetBetweenDeathLifeState then record.fn(e.mod, continued) end
        end
        assert((npc.champion == true) == continued, 'Continue must reconcile deferred NPCs; new run must leave them unchanged')
    end
    end
end)
check('meat removal callback cannot write its ledger after pause or disposal', function()
    local e = isolated(); ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED = 91002
    local p = e.player(107, 751); local forbidden = false
    local data = { meatLumpLives = {}, meatLumpCounts = {} }
    local owner = dofile('scripts/features/meat_lump.lua')(e.mod, {
        MeatLumpId = 751, IsValidItemId = function(id) return id == 751 end, GetPlayers = e.getPlayers,
        GetSurvivalCooldown = function() return 60 end, IsIncomingDamageLethal = function() return false end,
        GetSaveData = function() assert(not forbidden, 'stopped removal callback accessed save ledger'); return data end,
        Store = { Save = function() assert(not forbidden, 'stopped removal callback saved ledger') end },
    })
    owner.InstallCollectibleCallbacks(); e.mod:TrackMeatLumpPlayerCopies(p)
    assert(data.meatLumpLives['107'] == 1)
    owner.Pause(); forbidden = true; p.item = nil
    e.fire(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED, p)
    owner.Resume(); forbidden = false
    e.fire(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED, p)
    assert(data.meatLumpCounts['107'] == 0 and data.meatLumpLives['107'] == 1)
    owner.Dispose(); forbidden = true; e.fire(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED, p)
end)
for _, failure in ipairs(failures) do print('FAIL ' .. failure) end
assert(#failures == 0, #failures .. '/' .. checks .. ' folk boundaries failed')
print('refactor lifecycle folk: ' .. checks .. ' scenarios passed')
