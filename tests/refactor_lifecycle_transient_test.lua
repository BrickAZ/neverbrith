-- Isolated feature factories: no shared fixture edits and no native engine required.
local env = dofile('tests/support/neverbirth_fixture.lua')()
local items = env.itemIds
local failures, checks = {}, 0
local function check(label, fn)
    local ok, err = pcall(fn)
    if ok then checks = checks + 1; print('PASS ' .. label)
    else failures[#failures + 1] = label .. ': ' .. tostring(err); print('FAIL ' .. failures[#failures]) end
end
local function eq(actual, expected, label)
    assert(actual == expected, label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end

local function setup(feature)
    local players, entities, callbacks = {}, {}, {}
    local worldAvailable = true
    local mod = {}
    function mod:AddCallback(id, fn, filter)
        callbacks[id] = callbacks[id] or {}
        callbacks[id][#callbacks[id] + 1] = { fn = fn, filter = filter }
    end
    local function event(id, ...)
        for _, row in ipairs(callbacks[id] or {}) do row.fn(mod, ...) end
    end
    local world = {
        GetFolkRoom = function() return { IsClear = function() return false end } end,
        GetFolkRoomKey = function() return 'same-seed:1:1' end,
        GetFolkFloorKey = function() return 'same-seed:1' end,
        GetFolkPlayerKey = function(p) return tostring(p.InitSeed) end,
        PlayerHasCollectible = function(p, id) return p and p:HasCollectible(id) end,
        IsVulnerableEnemy = function() return false end,
    }
    Isaac.GetRoomEntities = function() assert(worldAvailable, 'room query after world release'); return entities end
    Isaac.GetCostumeIdByPath = function() return 321 end
    Sprite = function()
        return { Load = function() end, Play = function() end, Update = function() end }
    end
    local function player()
        local p = { InitSeed = 101, Position = Vector(100, 100), Velocity = Vector(0, 0),
            Damage = 3.5, Luck = 1, MoveSpeed = 1, MaxFireDelay = 10, TearRange = 260, ShotSpeed = 1,
            inventory = {}, data = {}, values = {}, flags = 0, evaluations = 0, added = 0, removed = 0 }
        for _, id in pairs(items) do p.inventory[id] = 1 end
        function p:GetData() return self.data end
        function p:Exists() return not self.gone end
        function p:IsDead() return false end
        function p:HasCollectible(id) return (self.inventory[id] or 0) > 0 end
        function p:GetCollectibleNum(id) return self.inventory[id] or 0 end
        function p:GetPlayerType() return 42 end
        function p:ToPlayer() return self end
        function p:AddNullCostume() self.added = self.added + 1 end
        function p:TryRemoveNullCostume() self.removed = self.removed + 1 end
        function p:AddCacheFlags(flags) self.flags = self.flags | flags end
        function p:GetCustomCacheValue(tag) return self.values[tag] or 0 end
        function p:AddCustomCacheTag(tag)
            local value = 0
            for _, row in ipairs(callbacks[ModCallbacks.MC_EVALUATE_CUSTOM_CACHE] or {}) do
                if row.filter == tag then value = row.fn(mod, self, tag, value) or value end
            end
            self.values[tag] = value
        end
        function p:EvaluateItems()
            self.evaluations = self.evaluations + 1
            local flags = self.flags; self.flags = 0
            for _, entry in ipairs({ {CacheFlag.CACHE_DAMAGE,'Damage',3.5},
                {CacheFlag.CACHE_LUCK,'Luck',1}, {CacheFlag.CACHE_SPEED,'MoveSpeed',1},
                {CacheFlag.CACHE_FIREDELAY,'MaxFireDelay',10}, {CacheFlag.CACHE_RANGE,'TearRange',260},
                {CacheFlag.CACHE_SHOTSPEED,'ShotSpeed',1} }) do
                if entry[1] and flags & entry[1] ~= 0 then
                    self[entry[2]] = entry[3]
                    event(ModCallbacks.MC_EVALUATE_CACHE, self, entry[1])
                end
            end
        end
        players[#players + 1] = p
        return p
    end
    local deps = { World = world, Items = items, GetPlayers = function()
            assert(worldAvailable, 'player query after world release'); return players
        end,
        IsValidItemId = function(id) return type(id) == 'number' and id > 0 end,
        GetNeedletickLuckCap = function() return 10 end,
        Log = function() end, GetPlayerHeadWorldPosition = function(p) return p.Position end,
        BurnAwayResentmentId = items.BurnAwayResentment, CleaverId = items.Cleaver,
        TheMoonIsBeautifulId = items.TheMoonIsBeautiful, StrongLaxativeId = items.StrongLaxative,
        CreepVariants = {}, RemoveCreepIfActive = function() end }
    local api = dofile('scripts/features/' .. feature .. '.lua')(mod, deps)
    if api then
        local keys = {}; for name in pairs(api) do if name:match('^Install') then keys[#keys+1] = name end end
        table.sort(keys); for _, name in ipairs(keys) do api[name]() end
    end
    -- Inspect private lifetime without publishing a new runtime TestAPI.
    local private, burnParts = {}, {}
    for _, rows in pairs(callbacks) do
        for _, row in ipairs(rows) do
            for i = 1, 50 do
                local name, value = debug.getupvalue(row.fn, i)
                if not name then break end
                if name == 'private' then private = value end
                if feature == 'burn_away_resentment' and (name == 'Presentation' or name == 'Attributes') then
                    burnParts[name] = value
                end
            end
        end
    end
    if feature == 'burn_away_resentment' then
        local visited = {}
        local function inspect(fn)
            if visited[fn] then return end
            visited[fn] = true
            for i = 1, 50 do
                local name, value = debug.getupvalue(fn, i)
                if not name then break end
                if name == 'Presentation' or name == 'Attributes' then burnParts[name] = value end
                if type(value) == 'function' then inspect(value) end
            end
        end
        for _, rows in pairs(callbacks) do for _, row in ipairs(rows) do inspect(row.fn) end end
    end
    local names = { burn_away_resentment='BurnAwayResentment', cleaver='Cleaver',
        debug_controller='DebugController', the_moon_is_beautiful='Moon',
        fortune_rivalling_heaven_gu='FortuneRivallingHeavenGu', strong_laxative='StrongLaxative' }
    local public = mod[names[feature]]
    local view = setmetatable({}, { __index=function(_, key)
        if public[key] ~= nil then return public[key] end
        if feature == 'burn_away_resentment' then
            for _, part in pairs(burnParts) do
                if part[key] ~= nil then return part[key] end
            end
            if key == 'bursts' and burnParts.Presentation then
                -- Read the current private collection; cleanup replaces its table.
                for i = 1, 50 do
                    local name, value = debug.getupvalue(burnParts.Presentation.SpawnBurst, i)
                    if not name then break end
                    if name == 'bursts' then return value end
                end
            end
        end
        return private[key]
    end })
    return { mod = mod, view = view, player = player, players = players, entities = entities, event = event, callbacks = callbacks,
        releaseWorld = function() worldAvailable = false end }
end

for _, boundary in ipairs({'exit', 'unload'}) do
    local function finish(e)
        local id = boundary == 'exit' and ModCallbacks.MC_PRE_GAME_EXIT or ModCallbacks.MC_PRE_MOD_UNLOAD
        assert(#(e.callbacks[id] or {}) > 0, boundary .. ' callback installed')
        if boundary == 'unload' then e.event(id, {}) end
        return function() e.event(id, boundary == 'unload' and e.mod or true) end
    end
    check('burn ' .. boundary .. ' releases references and restores cache', function()
        local e = setup('burn_away_resentment'); local p = e.player(); local burn = e.view
        local s = burn.GetState(p); s.currentLayers = 4; s.currentFloorClarity = 3
        s.pendingHurtBurst = {frames = 3}; s.statusSprite = {}; burn.SpawnBurst(p, 4); burn.RefreshCache(p)
        assert(p.MoveSpeed < 1 and p.Damage > 3.5)
        local close = finish(e); eq(burn.GetState(p), s, 'foreign unload preserves state'); close(); close()
        eq(next(burn.states), nil, 'states cleared'); eq(next(burn.bursts), nil, 'bursts cleared')
        eq(s.player, nil, 'old state releases player'); eq(s.statusSprite, nil, 'old state releases Sprite')
        eq(s.pendingHurtBurst, nil, 'pending damage cancelled'); eq(p.MoveSpeed, 1, 'speed restored'); eq(p.Damage, 3.5, 'damage restored')
    end)
    check('cleaver ' .. boundary .. ' removes native carrier once and restores cache', function()
        local e = setup('cleaver'); local p = e.player(); local c = e.mod.Cleaver
        c.Config.Registered = true; c.Config.PlayerType = 42
        local s = c.GetState(p); local count = 0
        s.swing = { nativeKnife = { Exists = function() return true end, Remove = function() count=count+1 end }, visual = {sprite={}} }
        s.holdVisual = {sprite={}}; c.shadows.test = {target=p,sprite={}}
        p:AddCacheFlags(CacheFlag.CACHE_DAMAGE); p:EvaluateItems(); assert(p.Damage ~= 3.5)
        local close = finish(e); eq(c.GetState(p), s, 'foreign unload preserves state'); close(); close()
        eq(count, 1, 'carrier removed once'); eq(next(c.states), nil, 'states cleared')
        eq(s.player, nil, 'player reference cleared'); eq(s.holdVisual, nil, 'idle Sprite cleared')
        eq(next(c.shadows), nil, 'target references cleared'); eq(p.Damage, 3.5, 'raw damage restored')
    end)
    check('debug controller ' .. boundary .. ' releases players and Sprite cache', function()
        local e = setup('debug_controller'); local p = e.player(); local d = e.view
        d.Open(p); d.GetSprite('Root'); local close = finish(e)
        assert(d.IsOpen(p), 'foreign unload preserves menu'); close(); close()
        assert(not d.IsOpen(p), 'menu closed'); eq(next(d.sprites), nil, 'Sprite cache cleared')
    end)
    check('moon ' .. boundary .. ' clears bonus and runtime without recreation', function()
        local e = setup('the_moon_is_beautiful'); local p = e.player(); local m = e.view
        local s = m.GetRoomState(); m.Trigger(p, s); assert(p.Damage > 3.5)
        local close = finish(e); eq(m.roomState, s, 'foreign unload preserves room'); close(); close()
        eq(m.roomState, nil, 'cache restoration must not recreate room'); eq(next(m.visuals), nil, 'visual references cleared')
        eq(p.Damage, 3.5, 'room damage restored'); eq(p.Luck, 1, 'room luck restored')
    end)
    check('fortune ' .. boundary .. ' clears owner references and luck contribution', function()
        local e = setup('fortune_rivalling_heaven_gu'); local p = e.player()
        e.mod:RegisterLuckCap(987, 12); p.inventory[987] = 1; e.mod:TrackFortuneRivallingHeavenGuLuckSources()
        eq(p.Luck, 12, 'luck applied'); local old = e.mod.FortuneRivallingHeavenGu.players[p:GetData()]
        local close = finish(e); eq(e.mod.FortuneRivallingHeavenGu.players[p:GetData()], old, 'foreign unload preserves owner'); close(); close()
        eq(next(e.mod.FortuneRivallingHeavenGu.players), nil, 'runtime cleared'); eq(old.owner, nil, 'old owner released')
        eq(p.Luck, 1, 'luck restored')
    end)
    check('strong laxative ' .. boundary .. ' clears clocks costume and creep owners', function()
        local e = setup('strong_laxative'); local p = e.player(); local s = e.mod.StrongLaxative.GetState(p)
        s.poopTimer = 59; e.mod.StrongLaxative.ApplyCostume(p, true)
        local data = {NeverbirthStrongLaxativeCreep=true,Owner=p,Life=120,Age=30,Synergy={}}
        local effect = { GetData=function() return data end, Exists=function(self) return not self.removed end,
            Remove=function(self) self.removed=true; self.removals=(self.removals or 0)+1 end }
        e.entities[1] = effect
        e.mod:UpdateStrongLaxativeCreep(effect)
        local close = finish(e); eq(e.mod.StrongLaxative.GetState(p), s, 'foreign unload preserves clock'); close(); close()
        eq(data.Owner, nil, 'creep owner released'); eq(effect.removals, 1, 'effect removed once')
        local fresh = e.mod.StrongLaxative.GetState(p); assert(fresh ~= s, 'runtime replaced'); eq(fresh.poopTimer, 0, 'clock cleared')
        local before = p.added; e.mod.StrongLaxative.ApplyCostume(p, true); eq(p.added, before+1, 'costume cache invalidated')
    end)
end

for _, continued in ipairs({false, true}) do
    check('same seed start transient reset continued=' .. tostring(continued), function()
        for _, feature in ipairs({'burn_away_resentment','cleaver','debug_controller','the_moon_is_beautiful','fortune_rivalling_heaven_gu','strong_laxative'}) do
            local e = setup(feature); local p = e.player()
            if feature == 'burn_away_resentment' then
                local s=e.mod.BurnAwayResentment.GetState(p); s.currentLayers=5
                e.event(ModCallbacks.MC_POST_GAME_STARTED, continued); eq(next(e.mod.BurnAwayResentment.states),nil,feature)
            elseif feature == 'cleaver' then
                local s=e.mod.Cleaver.GetState(p); s.cooldown=10
                e.event(ModCallbacks.MC_POST_GAME_STARTED, continued); eq(next(e.mod.Cleaver.states),nil,feature)
            elseif feature == 'debug_controller' then
                e.view.Open(p); e.view.GetSprite('Root')
                e.event(ModCallbacks.MC_POST_GAME_STARTED, continued); assert(not e.view.IsOpen(p)); eq(next(e.view.sprites),nil,feature)
            elseif feature == 'the_moon_is_beautiful' then
                e.mod.Moon.GetRoomState().failed=true
                e.event(ModCallbacks.MC_POST_GAME_STARTED, continued); assert(not e.mod.Moon.GetRoomState().failed,feature)
            elseif feature == 'fortune_rivalling_heaven_gu' then
                e.mod:InvalidateFortuneLuck(p); local old=e.mod.FortuneRivallingHeavenGu.players[p:GetData()]
                e.event(ModCallbacks.MC_POST_GAME_STARTED, continued); assert(e.mod.FortuneRivallingHeavenGu.players[p:GetData()] ~= old,feature)
            else
                local old=e.mod.StrongLaxative.GetState(p); old.poopTimer=59; e.mod.StrongLaxative.ApplyCostume(p,true)
                e.event(ModCallbacks.MC_POST_GAME_STARTED, continued); local s=e.mod.StrongLaxative.GetState(p)
                assert(s ~= old,feature .. ' same seed must replace clock'); eq(s.poopTimer,0,feature)
                local before=p.added; e.mod.StrongLaxative.ApplyCostume(p,true); eq(p.added,before+1,'same seed costume rebind')
            end
        end
    end)
end
check('unload before a run never queries missing world', function()
    for _, feature in ipairs({'burn_away_resentment','cleaver','debug_controller','the_moon_is_beautiful','fortune_rivalling_heaven_gu','strong_laxative'}) do
        local e = setup(feature); e.releaseWorld()
        e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod)
    end
end)
check('exit then unload and late updates never query released world', function()
    for _, feature in ipairs({'burn_away_resentment','cleaver','debug_controller','the_moon_is_beautiful','fortune_rivalling_heaven_gu','strong_laxative'}) do
        local e = setup(feature); e.event(ModCallbacks.MC_PRE_GAME_EXIT, true); e.releaseWorld()
        e.event(ModCallbacks.MC_PRE_GAME_EXIT, true); e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod)
        e.event(ModCallbacks.MC_POST_UPDATE)
    end
end)
check('unloaded instance cannot restart through old started or update callbacks', function()
    for _, feature in ipairs({'burn_away_resentment','cleaver','debug_controller','the_moon_is_beautiful','fortune_rivalling_heaven_gu','strong_laxative'}) do
        local e = setup(feature); e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod); e.releaseWorld()
        e.event(ModCallbacks.MC_POST_GAME_STARTED, false); e.event(ModCallbacks.MC_POST_GAME_STARTED, true)
        e.event(ModCallbacks.MC_POST_UPDATE); e.event(ModCallbacks.MC_POST_NEW_ROOM); e.event(ModCallbacks.MC_POST_NEW_LEVEL)
    end
end)
check('unload releases invalid player references without native cache access', function()
    for _, feature in ipairs({'burn_away_resentment','cleaver','the_moon_is_beautiful','fortune_rivalling_heaven_gu','strong_laxative'}) do
        local e = setup(feature); local p = e.player()
        if feature == 'burn_away_resentment' or feature == 'cleaver' then e.view.GetState(p)
        elseif feature == 'the_moon_is_beautiful' then e.view.Trigger(p, e.view.GetRoomState())
        elseif feature == 'fortune_rivalling_heaven_gu' then e.mod:InvalidateFortuneLuck(p)
        else e.view.ApplyCostume(p, true) end
        p.Exists = function() error('expired native owner') end
        local nativeCacheCalls = 0
        p.EvaluateItems = function() nativeCacheCalls = nativeCacheCalls + 1 end
        p.AddCacheFlags = function() nativeCacheCalls = nativeCacheCalls + 1 end
        p.AddCustomCacheTag = function() nativeCacheCalls = nativeCacheCalls + 1 end
        e.releaseWorld(); e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod); e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod)
        eq(nativeCacheCalls, 0, feature .. ' skips invalid native cache calls')
    end
end)
check('cleaver start retains already evaluated character attributes', function()
    for _, continued in ipairs({false, true}) do
        local e = setup('cleaver'); local p = e.player()
        e.mod.Cleaver.Config.Registered = true; e.mod.Cleaver.Config.PlayerType = 42
        p:AddCacheFlags(CacheFlag.CACHE_DAMAGE); p:EvaluateItems()
        local before = p.Damage
        e.event(ModCallbacks.MC_POST_GAME_STARTED, continued)
        eq(p.Damage, before, 'start keeps character cache'); eq(next(e.mod.Cleaver.states), nil, 'raw snapshots reset')
    end
end)
assert(#failures == 0, table.concat(failures, '\n'))
print('transient lifecycle: ' .. checks .. ' scenarios passed')
