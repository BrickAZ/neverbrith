-- Engine doubles exercise the module's ownership and event contracts, not native AI.
local function equal(got, want, message)
    if got ~= want then error((message or "mismatch") .. ": expected " .. tostring(want) .. ", got " .. tostring(got), 2) end
end
local function near(got, want, message)
    if math.abs(got - want) > 0.00001 then error((message or "mismatch") .. ": expected " .. want .. ", got " .. got, 2) end
end
local function copy(value)
    if type(value) ~= "table" then return value end
    local result = {}; for k, v in pairs(value) do result[k] = copy(v) end; return result
end

ModCallbacks = { MC_PRE_ADD_COLLECTIBLE = 1004, MC_EVALUATE_CACHE = 8, MC_FAMILIAR_INIT = 6,
    MC_FAMILIAR_UPDATE = 7, MC_POST_FAMILIAR_FIRE_PROJECTILE = 1252, MC_POST_PEFFECT_UPDATE = 4,
    MC_POST_GAME_STARTED = 15, MC_POST_NEW_ROOM = 19, MC_PRE_GAME_EXIT = 17,
    MC_POST_ADD_COLLECTIBLE = 1005, MC_PRE_PICKUP_COLLISION = 38, MC_POST_UPDATE = 1, MC_POST_PICKUP_COLLISION = 1239,
    MC_POST_PICKUP_INIT = 34, MC_POST_TRIGGER_COLLECTIBLE_REMOVED = 1095,
    MC_POST_NEW_LEVEL = 18, MC_PRE_SPAWN_CLEAN_AWARD = 70, MC_POST_ENTITY_TAKE_DMG = 1006,
    MC_POST_PICKUP_UPDATE = 35, MC_POST_PLAYER_UPDATE = 31,
    MC_POST_TRIGGER_TRINKET_ADDED = 1096, MC_POST_TRIGGER_TRINKET_REMOVED = 1097,
    MC_POST_GLOWING_HOURGLASS_SAVE = 1300, MC_POST_GLOWING_HOURGLASS_LOAD = 1301 }
PickupVariant = { PICKUP_COLLECTIBLE = 100 }
CacheFlag = { CACHE_DAMAGE = 1, CACHE_FIREDELAY = 2, CACHE_FAMILIARS = 4, CACHE_RANGE = 8 }
CallbackPriority = { DEFAULT = 0, LATE = 100 }
TrinketType = { TRINKET_GOLDEN_FLAG = 32768 }
EntityType = { ENTITY_FAMILIAR = 3 }
PlayerForm = { PLAYERFORM_BABY = 7 }
ItemConfig = { TAG_BABY = 1 }
TearFlags = { TEAR_SPECTRAL = 1 << 4 }
local vectorMeta = {}
Vector = setmetatable({}, { __call = function(_, x, y) return setmetatable({ X = x, Y = y }, vectorMeta) end })

local function fixture(saved, useShared)
    local nativeVector = Vector -- native entity creation does not call the Lua constructor
    local env = { players = {}, entities = {}, callbacks = {}, logs = {}, root = saved or {}, seed = "run-1",
        rolls = {}, rollCalls = 0, rngSeeds = {}, spawnCalls = 0, frame = 0, saves = 0, participants = {} }
    local configs = { [900] = { ID = 900, Tags = 1 }, [8] = { ID = 8, Tags = 1 },
        [20] = { ID = 20, Tags = 1 }, [21] = { ID = 21, Tags = 0 }, [22] = { ID = 22, Tags = 1 } }
    function env:emit(id, filter, ...)
        table.sort(self.callbacks[id] or {}, function(a,b)
            if a.priority ~= b.priority then return a.priority < b.priority end
            return a.order < b.order
        end)
        for _, cb in ipairs(self.callbacks[id] or {}) do
            if cb.filter == nil or cb.filter == filter then cb.fn(self.mod, ...) end
        end
    end
    local function familiar(player, variant, subtype, source, seed)
        local f = { Type = 3, Variant = variant, SubType = subtype or 0, Player = player,
            Position = nativeVector(0, 0), Velocity = nativeVector(0, 0), InitSeed = seed or (#env.entities + 500),
            data = {}, source = source and configs[source], FireCooldown = 0 }
        function f:GetData() return self.data end
        function f:ToFamiliar() return self end
        function f:GetItemConfig() return self.source end
        function f:Exists() return not self.removed end
        function f:IsDead() return false end
        function f:Remove() self.removed = true end
        function f:AddToFollowers() self.followers = (self.followers or 0) + 1 end
        function f:FollowParent() self.followed = (self.followed or 0) + 1 end
        function f:GetMultiplier() return self.multiplier or 1 end
        function f:Shoot()
            self.shoots = (self.shoots or 0) + 1
            if self.Player.firing and self.FireCooldown <= 0 then
                local tear = { SpawnerEntity = self, TearFlags = 0, CollisionDamage = 3.5,
                    FallingSpeed = -3, FallingAcceleration = 0.1, Height = -23.75, data = {} }
                function tear:GetData() return self.data end
                env:emit(ModCallbacks.MC_POST_FAMILIAR_FIRE_PROJECTILE, self.Variant, tear)
                self.lastTear = tear
            elseif self.FireCooldown > 0 then self.FireCooldown = self.FireCooldown - 1 end
        end
        env.entities[#env.entities + 1] = f
        env:emit(ModCallbacks.MC_FAMILIAR_INIT, variant, f)
        return f
    end
    function env:native(player, variant, subtype, source, seed) return familiar(player, variant, subtype, source, seed) end
    function env:copies(player, variant)
        local result = {}
        for _, f in ipairs(self.entities) do
            if not f.removed and f.Player == player and f:GetData().NeverbirthEchoCopy and (not variant or f.Variant == variant) then
                result[#result + 1] = f
            end
        end
        return result
    end
    function env:player(key)
        local p = { key = key, items = {}, InitSeed = #self.players + 10, Index = #self.players,
            Damage = 3.5, MaxFireDelay = 9, Position = Vector(0, 0), flags = 0, formCounter = 0 }
        function p:GetCollectibleNum(id) return self.items[id] or 0 end
        function p:GetCollectibleRNG() return RNG() end
        function p:AddCacheFlags(flags) self.flags = self.flags | flags end
        function p:EvaluateItems()
            self.eval = (self.eval or 0) + 1
            local flags = self.flags; self.flags = 0
            if flags & CacheFlag.CACHE_DAMAGE ~= 0 then self.Damage = 3.5; env:emit(8, 1, self, 1) end
            if flags & CacheFlag.CACHE_FIREDELAY ~= 0 then self.MaxFireDelay = 9; env:emit(8, 2, self, 2) end
            if flags & CacheFlag.CACHE_FAMILIARS ~= 0 then env:emit(8, 4, self, 4) end
        end
        function p:CheckFamiliar(variant, target, rng, config, subtype)
            equal(variant, 1000, "only the owned custom variant uses CheckFamiliar")
            equal(config.ID, 900, "own body source")
            local found = {}
            for _, f in ipairs(env.entities) do if not f.removed and f.Player == self and f.Variant == variant then found[#found + 1] = f end end
            for i = target + 1, #found do found[i]:Remove() end
            for _ = #found + 1, target do familiar(self, variant, subtype == -1 and 0 or subtype, 900) end
        end
        function p:HasPlayerForm(form) equal(form, 7); return self.formCounter >= 3 end
        function p:GetPlayerFormCounter(form) equal(form, 7); return self.formCounter end
        function p:IncrementPlayerFormCounter(form, count) equal(form, 7); self.formCounter = self.formCounter + count end
        function p:IsHologram() return self.hologram == true end
        function p:IsDead() return self.dead == true end
        function p:ToPlayer() return self end
        function p:GetPlayerType() return 0 end
        self.players[#self.players + 1] = p
        return p
    end
    Isaac = { GetItemConfig = function() return { GetCollectible = function(_, id) return configs[id] end } end,
        FindByType = function(etype)
            equal(etype, 3); local result = {}
            for _, f in ipairs(env.entities) do if not f.removed then result[#result + 1] = f end end
            return result
        end }
    Game = function() return {
        GetFrameCount = function() return env.frame end,
        GetLevel = function() return { GetStage = function() return 1 end, GetStageType = function() return 0 end,
            GetDungeonPlacementSeed = function() return 99 end, GetCurrentRoomDesc = function() return { ListIndex = 1, SafeGridIndex = 1 } end } end,
        Spawn = function(_, etype, variant, position, velocity, spawner, subtype, seed)
            equal(etype, 3); equal(getmetatable(position), vectorMeta, "native position"); equal(getmetatable(velocity), vectorMeta, "native velocity")
            if not seed or seed <= 0 then error("native spawn requires positive seeded identity") end
            env.spawnCalls = env.spawnCalls + 1
            return familiar(spawner, variant, subtype, env.forceSpawnSourceId, seed)
        end } end
    RNG = setmetatable({}, { __call = function() return {
        SetSeed = function(_, seed, shift) env.rngSeeds[#env.rngSeeds + 1] = { seed, shift } end,
        RandomInt = function(_, max)
            equal(max, 2); env.rollCalls = env.rollCalls + 1; return table.remove(env.rolls, 1) or 0
        end } end })
    env.mod = { AddCallback = function(_, id, fn, filter)
        env.callbacks[id] = env.callbacks[id] or {}
        table.insert(env.callbacks[id], { fn = fn, filter = filter, priority = 0, order = #env.callbacks[id] + 1 })
    end }
    function env.mod:AddPriorityCallback(id, priority, fn, filter)
        self:AddCallback(id, fn, filter)
        env.callbacks[id][#env.callbacks[id]].priority = priority
    end
    local state = { PlayerKey = function(p) return p.key end, RoomKey = function() return "room" end,
        SubscribeAcquisition = function(fn) env.acquired = fn end,
        RegisterParticipant = function(name, capture, restore) env.participants[name] = { capture, restore } end }
    local context = { ItemId = 900, FamiliarVariant = 1000, State = state,
        GetSaveRoot = function() return env.root end, GetCurrentRunSeed = function() return env.seed end,
        GetPlayers = function() return env.players end, Save = function() env.saves = env.saves + 1 end,
        DebugLog = function(s) env.logs[#env.logs + 1] = s end }
    if useShared then context.State = dofile("pending_content_state.lua")(env.mod, context) end
    env.state = context.State
    env.context = context
    local loader, errorText = loadfile("echo_baby.lua")
    assert(loader, "Echo Baby module must exist: " .. tostring(errorText))
    env.api = loader()(env.mod, context)
    function env:acquire(player, id, token, species, physical, temporary)
        local pedestal
        if useShared and physical ~= false then
            pedestal = { InitSeed = 123, Variant = 100, SubType = id,
                GetData = function() return { NeverbirthPhysicalToken = token } end }
            self:emit(38, 100, pedestal, player)
            self:emit(1239, 100, pedestal, player)
        end
        self:emit(1004, id, id, 0, true, 0, 0, player)
        player.items[id] = (player.items[id] or 0) + 1
        for _, row in ipairs(species or {}) do self:native(player, row[1], row[2], id) end
        if useShared then self:emit(1005, id, id, 0, true, 0, 0, player)
        else self.acquired(player, id, token, physical ~= false, temporary == true) end
        self:emit(4, nil, player)
    end
    function env:cache(player, flag) self:emit(8, flag, player, flag) end
    return env
end

local tests = {}
tests["real Low Grade cap-breaking cache settles before Echo's capped contribution"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1
    e.rolls = {1}; e:acquire(p, 8, "tears-reward", {{1,0}})
    near(e.api.GetRewards(p).tears, 0.5)
    function p:GetTrinketMultiplier(id) equal(id, 201); return 1 end
    local lowContext = {}; for key,value in pairs(e.context) do lowContext[key] = value end
    lowContext.TrinketId = 201
    dofile("low_grade.lua")(e.mod, lowContext)
    p.MaxFireDelay = 9; e:cache(p, CacheFlag.CACHE_FIREDELAY)
    near(30 / (p.MaxFireDelay + 1), 8, "Echo must not add past 5 after Low Grade's +5")
    near(e.api.GetRewards(p).tears, 0.5, "blocked contribution remains recorded")
end
tests["existing babies are not rewarded when Echo arrives"] = function()
    local e = fixture(); local p = e:player("A"); p.items[8] = 1; e:native(p, 1, 0, 8)
    e:acquire(p, 900, "echo", {})
    equal(e.rollCalls, 0); equal(#e:copies(p), 0); equal(p.formCounter, 3)
    e:cache(p, 4); equal(#e:copies(p), 0)
end
tests["new physical instance copies all new species and rolls once"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 2; p.items[20] = 1
    e:native(p, 10, 1, 20); e:native(p, 11, 2, 20); e:native(p, 10, 1, nil)
    e:acquire(p, 20, "multi", { {10, 1}, {11, 2} })
    local copies = e:copies(p); equal(#copies, 2); equal(e.rollCalls, 1)
    equal(copies[1]:GetItemConfig(), nil, "copy does not own a normal collectible")
    equal(p.items[20], 2, "copy is not collectible inventory")
    p.Damage = 3.5; e:cache(p, 1); equal(p.Damage, 4.5)
    local own = 0; for _, f in ipairs(e.entities) do if not f.removed and f.Variant == 1000 then own = own + 1 end end
    equal(own, 2, "only Echo bodies scale with multiple Echo items")
end
tests["same token cannot reroll while another same-ID token qualifies"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1
    e:acquire(p, 8, "one", { {1, 0} }); e.acquired(p, 8, "one", true, false)
    equal(e.rollCalls, 1); equal(#e:copies(p), 1)
    e:acquire(p, 8, "two", { {1, 0} }); equal(e.rollCalls, 2); equal(#e:copies(p), 2)
end
tests["temporary nonphysical own and untagged grants never recurse"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1
    e:acquire(p, 8, "fake", {{1, 0}}, false, false)
    e:acquire(p, 8, "temporary", {{1, 0}}, true, true)
    e:acquire(p, 21, "not-baby", {{1, 0}})
    e:acquire(p, 900, "own", {})
    equal(e.rollCalls, 0); equal(#e:copies(p), 0)
end
tests["nested same-ID scripted grants do not steal the physical source group"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1
    e:emit(1004, 8, 8, 0, true, 0, 0, p) -- outer real pickup
    e:emit(1004, 8, 8, 0, false, 0, 0, p) -- nested scripted grant
    p.items[8] = 1; e:native(p, 1, 0, 8); e.acquired(p, 8, "script", false, false)
    p.items[8] = 2; e:native(p, 1, 0, 8); e.acquired(p, 8, "real", true, false)
    equal(#e:copies(p), 1, "only the new physical source group is copied")
    equal(e.rollCalls, 1)
end
tests["capped tears remain recorded and do not clamp cap breakers"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1; e.rolls = {1, 1}
    e:acquire(p, 8, "one", {{1,0}}); e:acquire(p, 8, "two", {{1,0}})
    p.MaxFireDelay = 30 / 4.8 - 1; e:cache(p, 2); near(30 / (p.MaxFireDelay + 1), 5)
    p.MaxFireDelay = 30 / 5 - 1; e:cache(p, 2); near(30 / (p.MaxFireDelay + 1), 5)
    p.MaxFireDelay = 30 / 7 - 1; e:cache(p, 2); near(30 / (p.MaxFireDelay + 1), 7)
    p.MaxFireDelay = 9; e:cache(p, 2); near(30 / (p.MaxFireDelay + 1), 4)
    p.Damage = 3.5; e:cache(p, 1); equal(p.Damage, 3.5, "mutually exclusive roll does not award damage")
    equal(e.rollCalls, 2)
end
tests["item and source loss preserve earned rewards but stop new rewards"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1
    e:acquire(p, 8, "one", {{1,0}}); p.items[900] = 0; p.items[8] = 0
    for _, f in ipairs(e.entities) do if f.source and f.source.ID == 8 then f:Remove() end end
    e:cache(p, 4); equal(#e:copies(p), 1); p.Damage = 3.5; e:cache(p, 1); equal(p.Damage, 4.5)
    e:acquire(p, 8, "lost-echo", {{1,0}}); equal(e.rollCalls, 1); equal(#e:copies(p), 1)
end
tests["cache replaces only missing marked copies and leaves native sources intact"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1
    e:acquire(p, 8, "one", {{1,0}}); local before = e.spawnCalls
    e:cache(p, 4); e:cache(p, 4); equal(e.spawnCalls, before, "idempotent cache")
    e:copies(p)[1]:Remove(); e:cache(p, 4); equal(#e:copies(p), 1); equal(e.spawnCalls, before + 1)
    local originals = 0; for _, f in ipairs(e.entities) do if not f.removed and f.source and f.source.ID == 8 then originals = originals + 1 end end
    equal(originals, 1, "native source remains exact")
end
tests["continue rebinds saved copy seeds and never recalculates acquisition rewards"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1; e:acquire(p, 8, "one", {{1,0}})
    local saved = copy(e.root); local seed = e:copies(p)[1].InitSeed
    local resumed = fixture(saved); local q = resumed:player("A"); q.items[900] = 1; q.items[8] = 1
    resumed:native(q, 1, 0, 8); resumed:native(q, 1, 0, nil, seed)
    resumed:emit(15, nil, true); resumed:emit(4, nil, q)
    equal(resumed.rollCalls, 0); equal(#resumed:copies(q), 1); equal(resumed.spawnCalls, 0, "rebind without duplicate")
    resumed.acquired(q, 8, "one", true, false); equal(resumed.rollCalls, 0)
    q.Damage = 3.5; resumed:cache(q, 1); equal(q.Damage, 4.5)
end
tests["Hourglass participant restores rewards and removes only undone owned copies"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1
    local part = e.participants.echo_baby; assert(part, "register Hourglass participant")
    local empty = part[1](); e:acquire(p, 8, "one", {{1,0}}); equal(#e:copies(p), 1)
    part[2](empty); e:cache(p, 4); equal(#e:copies(p), 0)
    p.Damage = 3.5; e:cache(p, 1); equal(p.Damage, 3.5)
    equal(p.items[8], 1, "restore never removes normal collectible")
end
tests["Lazarus records are shared while followers move to active form and co-op stays separate"] = function()
    local e = fixture(); local p = e:player("laz"); local b = e:player("B"); p.items[900] = 1; b.items[900] = 1
    e:acquire(p, 8, "one", {{1,0}})
    local q = e:player("laz"); q.items[900] = 1; p.hologram = true
    e:emit(4, nil, q); equal(#e:copies(p), 0); equal(#e:copies(q), 1); equal(#e:copies(b), 0)
    q.Damage = 3.5; e:cache(q, 1); equal(q.Damage, 4.5)
    b.Damage = 3.5; e:cache(b, 1); equal(b.Damage, 3.5)
    e.acquired(q, 8, "one", true, false); equal(e.rollCalls, 1)
end
tests["unattributable special baby diagnoses missing source instead of copying lookalike"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1
    e:emit(1004, 22, 22, 0, true, 0, 0, p); p.items[22] = 1; e:native(p, 1, 0, nil)
    e.acquired(p, 22, "unsupported", true, false); e:emit(4, nil, p)
    e:cache(p, 4); equal(#e:copies(p), 0); assert(#e.logs > 0, "diagnostic required for unsupported source")
end
tests["native Shoot follows and produces 28-frame 3-damage spectral tears with multiplier"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1; p.firing = true
    local own = e:native(p, 1000, 0, 900); equal(own.followers, 1)
    e:emit(7, 1000, own); equal(own.followed, 1); equal(own.shoots, 1)
    equal(own.FireCooldown, 28); equal(own.lastTear.CollisionDamage, 3)
    equal(own.lastTear.TearFlags & TearFlags.TEAR_SPECTRAL, TearFlags.TEAR_SPECTRAL)
    equal(own.lastTear.FallingSpeed, -3, "retain native range baseline")
    own.multiplier = 2; for _ = 1, 28 do e:emit(7, 1000, own) end; equal(own.lastTear.CollisionDamage, 6)
end
tests["consecutive shots are exactly 28 updates apart"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1; p.firing = true
    local own = e:native(p, 1000, 0, 900); e:emit(7, 1000, own)
    local first = own.lastTear
    for _ = 1, 27 do e:emit(7, 1000, own); equal(own.lastTear, first, "must not fire early") end
    e:emit(7, 1000, own); assert(own.lastTear ~= first, "the 28th update must fire again")
end
tests["new run clears rewards without touching other save roots"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1; e.root.other = { value = 7 }
    e:acquire(p, 8, "one", {{1,0}}); e.seed = "run-2"; e:emit(15, nil, false)
    p.Damage = 3.5; e:cache(p, 1); equal(p.Damage, 3.5); equal(e.root.other.value, 7)
end
tests["real shared receipt service settles the source group inside post-add"] = function()
    local e = fixture(nil, true); local p = e:player("A"); p.items[900] = 1
    e:acquire(p, 8, "shared-one", {{1,0}})
    equal(#e:copies(p), 1); equal(e.rollCalls, 1)
    equal(#e.logs, 0, "subscriber errors must not be hidden by the shared service")
    local snapshot = e.state.Snapshot()
    e:acquire(p, 8, "shared-two", {{1,0}}); equal(#e:copies(p), 2)
    assert(e.state.Restore(snapshot)); e:cache(p, 4); equal(#e:copies(p), 1)
    p.Damage = 3.5; e:cache(p, 1); equal(p.Damage, 4.5)
end
tests["failed Vector constructor cannot pass a table lookalike to native spawn"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1
    local originalVector = Vector
    Vector = setmetatable({}, { __call = function() error("typed constructor unavailable") end })
    e:emit(1004, 8, 8, 0, true, 0, 0, p); p.items[8] = 1
    -- Install the native source with the actual constructor before its callback.
    Vector = originalVector; e:native(p, 1, 0, 8)
    Vector = setmetatable({}, { __call = function() error("typed constructor unavailable") end })
    e.acquired(p, 8, "one", true, false)
    equal(e.spawnCalls, 0); equal(#e:copies(p), 0); assert(#e.logs > 0)
    Vector = originalVector; e:cache(p, 4); equal(#e:copies(p), 1, "earned entitlement survives failed reconstruction")
end
tests["source replacement is diagnosed rather than misattributed as a new group"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1; p.items[20] = 1
    local old = e:native(p, 10, 1, 20); e:emit(1004, 20, 20, 0, true, 0, 0, p)
    old:Remove(); p.items[20] = 2; e:native(p, 11, 2, 20)
    e.acquired(p, 20, "transformed", true, false)
    equal(#e:copies(p), 0); assert(#e.logs > 0, "nonlinear group needs explicit diagnosis")
end
tests["foreign familiar tears are never changed"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1
    local source = e:native(p, 1, 0, 8)
    local tear = { SpawnerEntity = source, CollisionDamage = 12, TearFlags = 256,
        GetData = function() error("foreign tear data should not be accessed") end }
    e.mod:EchoBabyFiredTear(tear)
    equal(tear.CollisionDamage, 12); equal(tear.TearFlags, 256)
end
tests["unsaved exit does not write the persistent save root"] = function()
    local e = fixture(); local before = e.saves
    e:emit(17, nil, false); equal(e.saves, before, "respect native ShouldSave argument")
    e:emit(17, nil, true); equal(e.saves, before + 1)
end
tests["delayed physical receipt freezes its group before a later same-ID scripted grant"] = function()
    local e = fixture(nil, true); local p = e:player("A"); p.items[900] = 1
    local pedestal = { InitSeed = 987, Variant = 100, SubType = 8,
        GetData = function() return { NeverbirthPhysicalToken = "deferred" } end }
    e:emit(38, 100, pedestal, p)
    e:emit(1004, 8, 8, 0, true, 0, 0, p); p.items[8] = 1; e:native(p, 1, 0, 8)
    e:emit(1005, 8, 8, 0, true, 0, 0, p)
    equal(e.rollCalls, 0, "native collision has not yet confirmed physical acquisition")
    e:emit(1004, 8, 8, 0, false, 0, 0, p); p.items[8] = 2; e:native(p, 1, 0, 8)
    e:emit(1005, 8, 8, 0, false, 0, 0, p)
    e:emit(1239, 100, pedestal, p)
    equal(e.rollCalls, 1); equal(#e:copies(p), 1, "only the physical receipt's frozen group is copied")
    equal(#e.logs, 0, "no acquisition subscriber error or unsafe attribution")
end
tests["a delayed receipt from before Echo ownership remains non-retroactive"] = function()
    local e = fixture(); local p = e:player("A")
    e:emit(1004, 8, 8, 0, true, 0, 0, p); p.items[8] = 1; e:native(p, 1, 0, 8)
    p.items[900] = 1; e.acquired(p, 8, "earlier", true, false)
    equal(e.rollCalls, 0, "ownership must be proved at actual acquisition, not delayed delivery")
    equal(#e:copies(p), 0)
end
tests["unexpected normal source attribution aborts only the newly created copy"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1; e.forceSpawnSourceId = 8
    e:acquire(p, 8, "one", {{1,0}})
    equal(#e:copies(p), 0, "an attributed copy must never become a normal-item sacrifice source")
    equal(p.items[8], 1)
    local normal = 0; for _, f in ipairs(e.entities) do if not f.removed and f.source and f.source.ID == 8 then normal = normal + 1 end end
    equal(normal, 1, "only the actual native original remains")
    assert(#e.logs > 0, "bad native source assignment is diagnosed")
end
tests["native grant and familiar may wrap the same player separately"] = function()
    local e = fixture(); local p = e:player("A"); p.items[900] = 1
    local pre = setmetatable({}, {__index=p})
    local familiarOwner = setmetatable({}, {__index=p})
    e:emit(1004, 8, 8, 0, true, 0, 0, pre)
    p.items[8] = 1
    e:native(familiarOwner, 1, 0, 8)
    e.acquired(p, 8, "wrapped", true, false)
    equal(e.rollCalls, 1, "the real owner is unchanged across native callback wrappers")
    equal(#e:copies(p), 1, "the wrapped native owner's familiar source is copied")
end

local names = {}; for name in pairs(tests) do names[#names + 1] = name end; table.sort(names)
for _, name in ipairs(names) do tests[name](); print("PASS " .. name) end
print("echo_baby_behavior_test: " .. #names .. " passed (engine doubles; native AI unverified)")
