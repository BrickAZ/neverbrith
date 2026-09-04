local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, message)
    if not value then
        error(message or "expected truthy value", 2)
    end
end

local function assertNear(actual, expected, epsilon, message)
    if math.abs(actual - expected) > epsilon then
        error((message or "expected near value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function readFile(path)
    local file = assert(io.open(path, "r"), path .. " should exist")
    local text = file:read("*a")
    file:close()
    return text
end

local function readPngInfo(path)
    local file = assert(io.open(path, "rb"), path .. " should exist")
    local header = file:read(26)
    local fileSize = file:seek("end")
    file:close()
    assertTruthy(header and #header >= 26, path .. " should have a PNG header")

    local function readU32(offset)
        local a, b, c, d = string.byte(header, offset, offset + 3)
        return ((a * 256 + b) * 256 + c) * 256 + d
    end

    return {
        width = readU32(17),
        height = readU32(21),
        colorType = string.byte(header, 26),
        fileSize = fileSize,
    }
end

local function loadNeverbirth(options)
    options = options or {}
    local callbacks = {}
    local players = {}
    local roomEntities = {}
    local spawnedEntities = {}
    local itemIds = {
        Needletick = 760,
        ProteinStrip = 771,
        EnergyKibble = 772,
        LeanCan = 773,
        DHAFishOil = 774,
        DentalChew = 775,
        LuckyLiverBites = 776,
        GoatMilkPudding = 777,
    }

    package.loaded.json = nil
    package.preload.json = function()
        return { encode = function() return "{}" end, decode = function() return {} end }
    end

    ModCallbacks = {
        MC_POST_UPDATE = 1,
        MC_USE_ITEM = 2,
        MC_EVALUATE_CACHE = 3,
        MC_POST_RENDER = 4,
        MC_ENTITY_TAKE_DMG = 5,
        MC_PRE_USE_ITEM = 6,
        MC_PRE_PICKUP_COLLISION = 7,
        MC_POST_NEW_ROOM = 8,
        MC_POST_NEW_LEVEL = 9,
        MC_POST_GAME_STARTED = 10,
        MC_POST_PICKUP_INIT = 11,
        MC_POST_ADD_COLLECTIBLE = 13,
        MC_POST_EFFECT_UPDATE = 14,
        MC_POST_FIRE_TEAR = 15,
        MC_PRE_TEAR_COLLISION = 16,
        MC_POST_TEAR_UPDATE = 17,
    }
    EntityType = { ENTITY_PLAYER = 1, ENTITY_TEAR = 2, ENTITY_PICKUP = 5, ENTITY_FLY = 13, ENTITY_EFFECT = 1000 }
    CacheFlag = { CACHE_DAMAGE = 1, CACHE_SHOTSPEED = 2, CACHE_TEARCOLOR = 4, CACHE_SPEED = 8, CACHE_FIREDELAY = 16, CACHE_TEARFLAG = 32, CACHE_RANGE = 64, CACHE_LUCK = 1024 }
    DamageFlag = { DAMAGE_INVINCIBLE = 4, DAMAGE_CLONES = 8, DAMAGE_IGNORE_ARMOR = 16 }
    EntityFlag = { FLAG_CHARM = 1, FLAG_FRIENDLY = 2, FLAG_BOSS = 4, FLAG_NO_KNOCKBACK = 8, FLAG_NO_PHYSICS_KNOCKBACK = 16 }
    EffectVariant = { POOF01 = 1, BLOOD_EXPLOSION = 2 }
    TearFlags = { TEAR_HOMING = 1 }
    CollectibleType = { COLLECTIBLE_NULL = 0 }
    PickupVariant = { PICKUP_COLLECTIBLE = 100 }
    ItemPoolType = { POOL_TREASURE = 0, POOL_DEVIL = 3, POOL_ANGEL = 4 }
    RoomType = { ROOM_DEFAULT = 1 }
    ActiveSlot = { SLOT_PRIMARY = 0 }

    function MusicManager()
        return { GetCurrentMusicID = function() return 1 end, Play = function() end, Fadeout = function() end }
    end

    function Game()
        return {
            GetSeeds = function() return { GetStartSeedString = function() return "TEST RUN" end } end,
            GetNumPlayers = function() return #players end,
            GetPlayer = function(_, index) return players[(index or 0) + 1] end,
            GetRoom = function()
                return {
                    GetSpawnSeed = function() return 5000 end,
                    GetCenterPos = function() return Vector(320, 280) end,
                    GetType = function() return RoomType.ROOM_DEFAULT end,
                    IsClear = function() return false end,
                }
            end,
            GetLevel = function()
                return {
                    GetStage = function() return 1 end,
                    GetStageType = function() return 0 end,
                    GetCurrentRoomIndex = function() return 1 end,
                }
            end,
            GetItemPool = function() return { GetCollectible = function() return CollectibleType.COLLECTIBLE_NULL end } end,
            GetStateFlag = function() return false end,
            SetStateFlag = function() end,
        }
    end

    Isaac = {
        GetItemIdByName = function(name)
            local ids = {
                ["Needletick"] = itemIds.Needletick, ["虚空针尖"] = itemIds.Needletick,
                ["Protein Strip"] = itemIds.ProteinStrip, ["高蛋白肉条"] = itemIds.ProteinStrip,
                ["Energy Kibble"] = itemIds.EnergyKibble, ["活力狗饼干"] = itemIds.EnergyKibble,
                ["Lean Can"] = itemIds.LeanCan, ["轻盈低脂罐头"] = itemIds.LeanCan,
                ["DHA Fish Oil"] = itemIds.DHAFishOil, ["DHA 鱼油"] = itemIds.DHAFishOil,
                ["Dental Chew"] = itemIds.DentalChew, ["护齿磨牙骨"] = itemIds.DentalChew,
                ["Lucky Liver Bites"] = itemIds.LuckyLiverBites, ["幸运肝粒"] = itemIds.LuckyLiverBites,
                ["Goat Milk Pudding"] = itemIds.GoatMilkPudding, ["羊奶布丁"] = itemIds.GoatMilkPudding,
            }
            return ids[name] or -1
        end,
        GetEntityVariantByName = function(name)
            if name == "Needletick Tear" then
                return options.needletickTearVariant or -1
            end
            return -1
        end,
        Spawn = function(entityType, variant, subtype, position, velocity, spawner)
            local entity = {
                Type = entityType,
                Variant = variant,
                SubType = subtype,
                Position = position,
                Velocity = velocity,
                SpawnerEntity = spawner,
            }
            spawnedEntities[#spawnedEntities + 1] = entity
            return entity
        end,
        GetMusicIdByName = function() return -1 end,
        GetPlayer = function(index) return players[(index or 0) + 1] end,
        FindByType = function(entityType)
            if entityType == EntityType.ENTITY_PLAYER then return players end
            return {}
        end,
        GetRoomEntities = function() return roomEntities end,
        DebugString = function() end,
        GetItemConfig = function()
            return { GetCollectible = function() return { Tags = 0, Type = 3, MaxCharges = 0, Name = "Mock" } end, GetCollectibles = function() return {} end }
        end,
    }

    Color = setmetatable({}, { __call = function(_, r, g, b, a, ro, go, bo) return { R = r, G = g, B = b, A = a, RO = ro, GO = go, BO = bo } end })
    Color.Default = Color(1, 1, 1, 1, 0, 0, 0)
    local vectorMeta = {
        __add = function(left, right) return Vector(left.X + right.X, left.Y + right.Y) end,
        __sub = function(left, right) return Vector(left.X - right.X, left.Y - right.Y) end,
        __mul = function(left, scalar) return Vector(left.X * scalar, left.Y * scalar) end,
    }
    function Vector(x, y)
        return setmetatable({
            X = x or 0,
            Y = y or 0,
            Length = function(self) return math.sqrt(self.X * self.X + self.Y * self.Y) end,
            GetAngleDegrees = function(self) return math.deg(math.atan(self.Y, self.X)) end,
            Normalized = function(self)
                local length = self:Length()
                if length <= 0 then return Vector(1, 0) end
                return Vector(self.X / length, self.Y / length)
            end,
        }, vectorMeta)
    end
    function EntityRef(entity) return { Entity = entity } end

    local mod
    function RegisterMod(name, version)
        mod = { Name = name, Version = version }
        function mod:AddCallback(callbackId, fn, param)
            callbacks[callbackId] = callbacks[callbackId] or {}
            callbacks[callbackId][#callbacks[callbackId] + 1] = { fn = fn, param = param }
        end
        function mod:HasData() return false end
        function mod:LoadData() return "{}" end
        function mod:SaveData() end
        return mod
    end

    dofile("main.lua")

    local function getCallbacks(callbackId, param)
        local found = {}
        for _, registration in ipairs(callbacks[callbackId] or {}) do
            if param == nil or registration.param == nil or registration.param == param then
                found[#found + 1] = registration.fn
            end
        end
        return found
    end

    local function runPostFireTear(tear)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_FIRE_TEAR)) do
            callback(mod, tear)
        end
    end

    local function runTearCollision(tear, collider)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_PRE_TEAR_COLLISION)) do
            callback(mod, tear, collider, false)
        end
    end

    local function runPostTearUpdate(tear)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_TEAR_UPDATE)) do
            callback(mod, tear)
        end
    end

    local function newPlayer(opts)
        opts = opts or {}
        local player = {
            Type = EntityType.ENTITY_PLAYER,
            InitSeed = opts.initSeed or (#players + 100),
            Position = opts.position or Vector(100, 100),
            Luck = opts.luck or 0,
            Damage = opts.damage or 3.5,
            MaxFireDelay = opts.maxFireDelay or 9,
            MoveSpeed = opts.moveSpeed or 1,
            TearRange = opts.tearRange or 260,
            hearts = opts.hearts or 2,
            maxHearts = opts.maxHearts or 2,
            soulHearts = opts.soulHearts or 0,
            acceptsRedHearts = opts.acceptsRedHearts ~= false,
            collectibles = opts.collectibles or {},
            rngSequence = opts.rngSequence or { 0 },
            rngIndex = 0,
        }
        function player:ToPlayer() return self end
        function player:GetCollectibleNum(itemId) return self.collectibles[itemId] or 0 end
        function player:HasCollectible(itemId) return (self.collectibles[itemId] or 0) > 0 end
        function player:GetMaxHearts() return self.maxHearts end
        function player:GetHearts() return self.hearts end
        function player:AddMaxHearts(amount) if self.acceptsRedHearts then self.maxHearts = self.maxHearts + amount end end
        function player:AddHearts(amount) self.hearts = math.min(self.maxHearts, self.hearts + amount) end
        function player:AddSoulHearts(amount) self.soulHearts = self.soulHearts + amount end        function player:GetCollectibleRNG()
            return {
                RandomFloat = function()
                    self.rngIndex = self.rngIndex + 1
                    return self.rngSequence[self.rngIndex] or 1
                end,
            }
        end
        players[#players + 1] = player
        roomEntities[#roomEntities + 1] = player
        return player
    end

    local function newTear(player, pos, opts)
        local tear = {
            Type = EntityType.ENTITY_TEAR,
            Variant = opts and opts.variant or 0,
            Position = pos or Vector(120, 100),
            Velocity = opts and opts.velocity or Vector(6, 0),
            CollisionDamage = opts and opts.damage or 3.5,
            Scale = opts and opts.scale or 1,
            SpriteScale = opts and opts.spriteScale or Vector(1, 1),
            TearFlags = opts and opts.tearFlags or 0,
            SpawnerEntity = player,
            data = {},
            colors = {},
            changedVariants = {},
            sprite = {
                played = {},
                Play = function(self, animation, force)
                    self.played[#self.played + 1] = { animation = animation, force = force }
                end,
            },
        }
        function tear:GetData() return self.data end
        function tear:GetSprite() return self.sprite end
        function tear:ChangeVariant(variant)
            self.changedVariants[#self.changedVariants + 1] = variant
            self.Variant = variant
        end
        function tear:SetColor(color, duration, priority, fadeout, share)
            self.colors[#self.colors + 1] = { color = color, duration = duration, priority = priority, fadeout = fadeout, share = share }
        end
        return tear
    end

    local function newEnemy(opts)
        opts = opts or {}
        local enemy = {
            Type = opts.type or EntityType.ENTITY_FLY,
            Position = opts.position or Vector(120, 100),
            HitPoints = opts.hp or 10,
            MaxHitPoints = opts.maxHp or opts.hp or 10,
            flags = opts.flags or 0,
            boss = opts.boss == true,
            champion = opts.champion == true,
            vulnerable = opts.vulnerable ~= false,
            active = opts.active ~= false,
            Velocity = opts.velocity or Vector(0, 0),
            ChildNPC = opts.child and {} or nil,
            ParentNPC = opts.parent and {} or nil,
            data = {},
            died = false,
            damageCalls = {},
        }
        function enemy:ToPlayer() return nil end
        function enemy:ToNPC() return self end
        function enemy:IsVulnerableEnemy() return self.vulnerable and not self.died end
        function enemy:IsActiveEnemy() return self.active and not self.died end
        function enemy:GetData() return self.data end        function enemy:IsBoss() return self.boss end
        function enemy:IsChampion() return self.champion end
        function enemy:HasEntityFlags(flag) return (self.flags & flag) ~= 0 end
        function enemy:Die() self.died = true end
        function enemy:TakeDamage(amount, flags, source, countdown)
            self.damageCalls[#self.damageCalls + 1] = { amount = amount, flags = flags, source = source, countdown = countdown }
            self.HitPoints = self.HitPoints - amount
        end
        roomEntities[#roomEntities + 1] = enemy
        return enemy
    end

        return {
        mod = mod,
        items = itemIds,
        roomEntities = roomEntities,
        spawnedEntities = spawnedEntities,
        newPlayer = newPlayer,
        newTear = newTear,
        newEnemy = newEnemy,
        runPostFireTear = runPostFireTear,
        runTearCollision = runTearCollision,
        runPostTearUpdate = runPostTearUpdate,
    }
end

local function test_xml_and_pool_registration()
    local names = {
        { "Protein Strip", "高蛋白肉条", "protein_strip.png", "damage", "39" },
        { "Energy Kibble", "活力狗饼干", "energy_kibble.png", "firedelay", "40" },
        { "Lean Can", "轻盈低脂罐头", "lean_can.png", "speed", "41" },
        { "DHA Fish Oil", "DHA 鱼油", "dha_fish_oil.png", "range", "42" },
        { "Dental Chew", "护齿磨牙骨", "dental_chew.png", nil, "43" },
        { "Lucky Liver Bites", "幸运肝粒", "lucky_liver_bites.png", "luck", "44" },
        { "Goat Milk Pudding", "羊奶布丁", "goat_milk_pudding.png", nil, "45" },
    }
    for _, file in ipairs({ "content/items.xml", "content/items.en_us.xml", "content/items.zh_cn.xml" }) do
        local text = readFile(file)
        for _, spec in ipairs(names) do
            local name = file:find("zh_cn", 1, true) and spec[2] or spec[1]
            local escaped = name:gsub("([^%w])", "%%%1")
            local block = text:match('<passive%s+name="' .. escaped .. '".-/>')
            assertTruthy(block, file .. " missing " .. name)
            assertEquals(block:match('id="(.-)"'), spec[5], file .. " local id")
            assertEquals(block:match('quality="(.-)"'), "1", file .. " quality")
            assertEquals(block:match('gfx="(.-)"'), spec[3], file .. " icon")
            if spec[4] then assertEquals(block:match('cache="(.-)"'), spec[4], file .. " cache") end
        end
    end
    for _, file in ipairs({ "content/itempools.xml", "content/itempools.en_us.xml", "content/itempools.zh_cn.xml" }) do
        local text = readFile(file)
        for _, spec in ipairs(names) do
            local name = file:find("zh_cn", 1, true) and spec[2] or spec[1]
            local escaped = name:gsub("([^%w])", "%%%1")
            local count = 0
            for _ in text:gmatch('<Item Name="' .. escaped .. '" Weight="0%.1" DecreaseBy="1" RemoveOn="0%.1"/>') do count = count + 1 end
            assertEquals(count, 2, file .. " must place " .. name .. " only in boss and treasure")
        end
    end
end

local function test_pickup_benefits_and_reacquisition()
    local env = loadNeverbirth()
    local api = env.mod.DogFoodSeriesTestAPI
    local protein = env.newPlayer({ collectibles = { [env.items.ProteinStrip] = 1 }, hearts = 1, maxHearts = 2 })
    assertTruthy(api.ReconcilePlayerItem(protein, api.ItemById[env.items.ProteinStrip]))
    assertEquals(protein.maxHearts, 4, "first copy adds one red heart container")
    assertEquals(protein.hearts, 4, "first copy refills all red hearts")
    assertEquals(api.GetProcessedCount(protein, env.items.ProteinStrip), 1, "first copy is persisted")
    assertEquals(api.ReconcilePlayerItem(protein, api.ItemById[env.items.ProteinStrip]), false, "room/floor/cache reconciliation must not repeat")
    assertEquals(protein.maxHearts, 4, "reconciliation must not repeat health")
    protein.collectibles[env.items.ProteinStrip] = 0
    api.ReconcilePlayerItem(protein, api.ItemById[env.items.ProteinStrip])
    protein.collectibles[env.items.ProteinStrip] = 1
    api.ReconcilePlayerItem(protein, api.ItemById[env.items.ProteinStrip])
    assertEquals(protein.maxHearts, 6, "genuine reacquisition after removal grants once")

    local soulOnly = env.newPlayer({ acceptsRedHearts = false, collectibles = { [env.items.GoatMilkPudding] = 1 }, maxHearts = 0, hearts = 0 })
    api.ReconcilePlayerItem(soulOnly, api.ItemById[env.items.GoatMilkPudding])
    assertEquals(soulOnly.maxHearts, 0, "incompatible health model is not rewritten")
    assertEquals(soulOnly.soulHearts, 1, "Goat Milk Pudding adds exactly one soul-heart half unit")
    api.ReconcilePlayerItem(soulOnly, api.ItemById[env.items.GoatMilkPudding])
    assertEquals(soulOnly.soulHearts, 1, "Goat Milk Pudding one-time reward does not repeat")
end

local function test_continue_and_coop_independence()
    local env = loadNeverbirth()
    local api = env.mod.DogFoodSeriesTestAPI
    local first = env.newPlayer({
        initSeed = 301,
        collectibles = { [env.items.ProteinStrip] = 1 },
        hearts = 1,
        maxHearts = 2,
    })
    local second = env.newPlayer({
        initSeed = 302,
        collectibles = { [env.items.GoatMilkPudding] = 1 },
        hearts = 2,
        maxHearts = 2,
    })

    api.ReconcilePlayerItem(first, api.ItemById[env.items.ProteinStrip])
    api.ReconcilePlayerItem(second, api.ItemById[env.items.GoatMilkPudding])
    assertEquals(first.maxHearts, 4, "co-op player one receives only their own container")
    assertEquals(first.soulHearts, 0, "co-op player one does not receive player two's soul heart")
    assertEquals(second.maxHearts, 4, "co-op player two receives only their own container")
    assertEquals(second.soulHearts, 1, "co-op player two receives exactly their own half soul heart")
    assertEquals(api.GetProcessedCount(first, env.items.ProteinStrip), 1, "player one count is stored independently")
    assertEquals(api.GetProcessedCount(second, env.items.ProteinStrip), 0, "player two does not inherit player one's count")

    api.Callbacks.GameStarted(nil, true)
    api.ReconcilePlayerItem(first, api.ItemById[env.items.ProteinStrip])
    api.ReconcilePlayerItem(second, api.ItemById[env.items.GoatMilkPudding])
    assertEquals(first.maxHearts, 4, "continue does not repeat player one's red-heart reward")
    assertEquals(second.maxHearts, 4, "continue does not repeat player two's red-heart reward")
    assertEquals(second.soulHearts, 1, "continue does not repeat Goat Milk Pudding's soul heart")
end
local function test_stat_cache_stacks_and_retracts()
    local env = loadNeverbirth()
    local api = env.mod.DogFoodSeriesTestAPI
    local p = env.newPlayer({ collectibles = {
        [env.items.ProteinStrip] = 2, [env.items.EnergyKibble] = 2, [env.items.LeanCan] = 2,
        [env.items.DHAFishOil] = 2, [env.items.LuckyLiverBites] = 2,
    } })
    api.Callbacks.Evaluate(nil, p, CacheFlag.CACHE_DAMAGE)
    api.Callbacks.Evaluate(nil, p, CacheFlag.CACHE_FIREDELAY)
    api.Callbacks.Evaluate(nil, p, CacheFlag.CACHE_SPEED)
    api.Callbacks.Evaluate(nil, p, CacheFlag.CACHE_RANGE)
    api.Callbacks.Evaluate(nil, p, CacheFlag.CACHE_LUCK)
    assertNear(p.Damage, 3.8, 0.0001, "damage stacks per copy")
    assertNear(p.MaxFireDelay, 30 / (3 + 0.30) - 1, 0.0001, "tears use real conversion")
    assertNear(p.MoveSpeed, 1.2, 0.0001, "speed stacks per copy")
    assertNear(p.TearRange, 292, 0.0001, "+0.40 range equals +16 TearRange per copy")
    assertNear(p.Luck, 0.5, 0.0001, "luck stacks per copy")
    p.collectibles = {}
    p.Damage, p.MaxFireDelay, p.MoveSpeed, p.TearRange, p.Luck = 3.5, 9, 1, 260, 0
    api.Callbacks.Evaluate(nil, p, CacheFlag.CACHE_DAMAGE)
    api.Callbacks.Evaluate(nil, p, CacheFlag.CACHE_FIREDELAY)
    api.Callbacks.Evaluate(nil, p, CacheFlag.CACHE_SPEED)
    api.Callbacks.Evaluate(nil, p, CacheFlag.CACHE_RANGE)
    api.Callbacks.Evaluate(nil, p, CacheFlag.CACHE_LUCK)
    assertNear(p.Damage, 3.5, 0.0001, "removed items leave no stat bonus")
    assertNear(p.MaxFireDelay, 9, 0.0001, "removed tears item leaves no bonus")
end

local function test_dental_chew_direct_tear_cooldown_cap_and_filters()
    local env = loadNeverbirth()
    local api = env.mod.DogFoodSeriesTestAPI
    local holder = env.newPlayer({ initSeed = 101, collectibles = { [env.items.DentalChew] = 2 } })
    local tear = env.newTear(holder, Vector(100, 100), { velocity = Vector(3, 4) })
    local enemy = env.newEnemy({ velocity = Vector(4, 0) })
    api.Callbacks.MarkDentalTear(nil, tear)
    api.Callbacks.DentalCollision(nil, tear, enemy)
    assertNear(enemy.Velocity:Length(), 4.5, 0.0001, "combined push is capped at 4.5 speed")
    local firstX, firstY = enemy.Velocity.X, enemy.Velocity.Y
    api.Callbacks.DentalCollision(nil, tear, enemy)
    assertNear(enemy.Velocity.X, firstX, 0.0001, "same enemy/player is blocked inside 8 frames")
    assertNear(enemy.Velocity.Y, firstY, 0.0001, "cooldown preserves velocity")
    for _ = 1, 8 do api.Callbacks.Update() end
    api.Callbacks.DentalCollision(nil, tear, enemy)
    assertTruthy(enemy.Velocity.Y > firstY, "push is available again after 8 frames")

    local boss = env.newEnemy({ boss = true })
    api.Callbacks.DentalCollision(nil, tear, boss)
    assertNear(boss.Velocity:Length(), 0, 0.0001, "boss is never pushed")
    local fixed = env.newEnemy({ flags = EntityFlag.FLAG_NO_KNOCKBACK })
    api.Callbacks.DentalCollision(nil, tear, fixed)
    assertNear(fixed.Velocity:Length(), 0, 0.0001, "fixed no-knockback target is never pushed")
    local segmentedBody = env.newEnemy({ child = true })
    api.Callbacks.DentalCollision(nil, tear, segmentedBody)
    assertNear(segmentedBody.Velocity:Length(), 0, 0.0001, "segmented main body is never pushed")
    local familiarTear = env.newTear({ ToPlayer = function() return nil end }, Vector(100, 100), { velocity = Vector(5, 0) })
    api.Callbacks.MarkDentalTear(nil, familiarTear)
    local normal = env.newEnemy()
    api.Callbacks.DentalCollision(nil, familiarTear, normal)
    assertNear(normal.Velocity:Length(), 0, 0.0001, "non-player tear is not marked or pushed")

    local otherHolder = env.newPlayer({ initSeed = 202, collectibles = { [env.items.DentalChew] = 1 } })
    local firstSourceTear = env.newTear(holder, Vector(100, 100), { velocity = Vector(1, 0) })
    local secondSourceTear = env.newTear(otherHolder, Vector(100, 100), { velocity = Vector(0, 1) })
    local sharedEnemy = env.newEnemy()
    api.Callbacks.MarkDentalTear(nil, firstSourceTear)
    api.Callbacks.MarkDentalTear(nil, secondSourceTear)
    api.Callbacks.DentalCollision(nil, firstSourceTear, sharedEnemy)
    api.Callbacks.DentalCollision(nil, secondSourceTear, sharedEnemy)
    assertTruthy(sharedEnemy.Velocity.X > 0 and sharedEnemy.Velocity.Y > 0,
        "co-op tear owners have independent per-enemy cooldown keys")
end

test_xml_and_pool_registration()
test_pickup_benefits_and_reacquisition()
test_continue_and_coop_independence()
test_stat_cache_stacks_and_retracts()
test_dental_chew_direct_tear_cooldown_cap_and_filters()
print("dog food series behavior tests passed")