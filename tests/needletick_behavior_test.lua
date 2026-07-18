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
    CacheFlag = { CACHE_DAMAGE = 1, CACHE_SHOTSPEED = 2, CACHE_TEARCOLOR = 4, CACHE_SPEED = 8, CACHE_FIREDELAY = 16, CACHE_TEARFLAG = 32, CACHE_LUCK = 1024 }
    DamageFlag = { DAMAGE_INVINCIBLE = 4, DAMAGE_CLONES = 8, DAMAGE_IGNORE_ARMOR = 16 }
    EntityFlag = { FLAG_CHARM = 1, FLAG_FRIENDLY = 2 }
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
            if name == "Needletick" or name == "虚空针尖" then return itemIds.Needletick end
            return -1
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
            collectibles = opts.collectibles or {},
            rngSequence = opts.rngSequence or { 0 },
            rngIndex = 0,
        }
        function player:ToPlayer() return self end
        function player:GetCollectibleNum(itemId) return self.collectibles[itemId] or 0 end
        function player:HasCollectible(itemId) return (self.collectibles[itemId] or 0) > 0 end
        function player:GetCollectibleRNG()
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
            died = false,
            damageCalls = {},
        }
        function enemy:ToPlayer() return nil end
        function enemy:ToNPC() return self end
        function enemy:IsVulnerableEnemy() return self.vulnerable and not self.died end
        function enemy:IsBoss() return self.boss end
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

local function test_xml_registers_needletick_item_text_and_devil_pool()
    local items = readFile("content/items.xml")
    local zhItems = readFile("content/items.zh_cn.xml")
    local enItems = readFile("content/items.en_us.xml")
    local pools = readFile("content/itempools.xml")
    local zhPools = readFile("content/itempools.zh_cn.xml")

    assertTruthy(items:find('<passive%s+name="Needletick".-quality="3".-tags="offensive summonable"', 1), "Needletick should be a quality 3 offensive passive")
    assertTruthy(enItems:find('name="Needletick"', 1), "en item xml should register Needletick")
    assertTruthy(zhItems:find('name="虚空针尖"', 1), "zh item xml should register Needletick")
    assertTruthy(enItems:find('description="vomit in buckets"', 1, true), "en pickup text should match design")
    assertTruthy(zhItems:find('description="下次请吐在垃圾桶里……"', 1, true), "zh pickup text should match design")
    assertTruthy(pools:find('<Pool Name="devil".-<Item Name="Needletick" Weight="1"', 1), "Needletick should be in devil pool")
    assertTruthy(zhPools:find('<Pool Name="devil".-<Item Name="虚空针尖" Weight="1"', 1), "Needletick zh pool should be in devil pool")
end

local function test_needletick_tear_resource_is_registered()
    local entities = readFile("content/entities2.xml")
    local anm2 = readFile("resources/gfx/Effects/NeedletickTear/NeedletickTear.anm2")
    local png = readPngInfo("resources/gfx/Effects/NeedletickTear/NeedletickTear_large.png")

    assertTruthy(entities:find('<entities%s+anm2root="gfx/"', 1), "entities2.xml should resolve entity anm2 paths from gfx/")
    assertTruthy(entities:find('id="2"', 1, true), "Needletick Tear should be registered as EntityType.ENTITY_TEAR")
    assertTruthy(entities:find('variant="3015"', 1, true), "Needletick Tear should use the reserved custom tear variant")
    assertTruthy(entities:find('name="Needletick Tear"', 1, true), "Needletick Tear entity name should match Lua lookup")
    assertTruthy(entities:find('anm2path="Effects/NeedletickTear/NeedletickTear.anm2"', 1, true), "Needletick Tear anm2 path should be relative to gfx/")
    assertTruthy(entities:find('baseHP="0"', 1, true), "Needletick Tear should include Isaac tear entity baseHP")
    assertTruthy(entities:find('boss="0"', 1, true), "Needletick Tear should include Isaac tear entity boss flag")
    assertTruthy(entities:find('champion="0"', 1, true), "Needletick Tear should include Isaac tear entity champion flag")
    assertTruthy(entities:find('collisionDamage="0"', 1, true), "Needletick Tear should include Isaac tear entity collision damage")
    assertTruthy(entities:find('collisionMass="3"', 1, true), "Needletick Tear should include Isaac tear entity collision mass")
    assertTruthy(entities:find('collisionRadius="8"', 1, true), "Needletick Tear should include Isaac tear entity collision radius")
    assertTruthy(entities:find('friction="1"', 1, true), "Needletick Tear should include Isaac tear entity friction")
    assertTruthy(entities:find('numGridCollisionPoints="12"', 1, true), "Needletick Tear should include Isaac tear entity grid collision points")
    assertTruthy(entities:find('shadowSize="12"', 1, true), "Needletick Tear should include Isaac tear entity shadow size")
    assertTruthy(entities:find('stageHP="0"', 1, true), "Needletick Tear should include Isaac tear entity stageHP")
    assertTruthy(not entities:find('anm2path="gfx/Effects/NeedletickTear/NeedletickTear.anm2"', 1, true), "Needletick Tear should not double-prefix gfx in entities2.xml")

    assertEquals(png.width, 192, "Needletick Tear PNG should be an 8-frame 24px strip")
    assertEquals(png.height, 24, "Needletick Tear PNG should use visible 24px tear frames")
    assertEquals(png.colorType, 6, "Needletick Tear PNG should be RGBA")
    assertTruthy(png.fileSize > 100, "Needletick Tear PNG should not be an empty placeholder")

    assertTruthy(anm2:find('<Spritesheet Id="0" Path="NeedletickTear_large.png"', 1, true), "Needletick Tear anm2 should reference its spritesheet relative to the anm2 file")
    assertTruthy(not anm2:find('Path="gfx/Effects/NeedletickTear/NeedletickTear.png"', 1, true), "Needletick Tear anm2 should not use a gfx-prefixed internal spritesheet path")
    assertTruthy(anm2:find('<Layer Name="body" Id="0" SpritesheetId="0"', 1, true), "Needletick Tear anm2 should contain a body layer")
    assertTruthy(anm2:find('<Animations DefaultAnimation="RegularTear6"', 1, true), "Needletick Tear anm2 should use an Isaac tear animation as default")
    assertTruthy(anm2:find('<Animation Name="RegularTear6" FrameNum="8" Loop="true"', 1, true), "Needletick Tear should provide a regular tear animation")
    assertTruthy(not anm2:find('<Animation Name="Idle"', 1, true), "Needletick Tear should not rely on effect-style Idle animation")
    assertTruthy(anm2:find('<LayerAnimation LayerId="0" Visible="true"', 1, true), "Needletick Tear animation should have a visible LayerAnimation")
    assertTruthy(anm2:find('XPivot="12" YPivot="12" XCrop="0" YCrop="0" Width="24" Height="24"', 1, true), "Needletick Tear first frame crop should match the strip")
    assertTruthy(anm2:find('XPivot="12" YPivot="12" XCrop="168" YCrop="0" Width="24" Height="24"', 1, true), "Needletick Tear last frame crop should match the strip")
    assertTruthy(anm2:find('AlphaTint="255"', 1, true), "Needletick Tear frames should render at full alpha")
    assertTruthy(not anm2:find('AlphaTint="0"', 1, true), "Needletick Tear should not contain invisible alpha-zero frames")
    assertTruthy(anm2:find('Visible="true"', 1, true), "Needletick Tear frames should be visible")
end

local function test_needletick_chance_scales_with_luck_and_clamps()
    local env = loadNeverbirth()

    assertNear(env.mod.GetNeedletickChance(0), 0.05, 0.0001, "base chance should be 5 percent")
    assertNear(env.mod.GetNeedletickChance(5), 0.10, 0.0001, "5 luck should be 10 percent")
    assertNear(env.mod.GetNeedletickChance(10), 0.15, 0.0001, "10 luck should be 15 percent")
    assertNear(env.mod.GetNeedletickChance(20), 0.15, 0.0001, "chance should clamp at 15 percent")
    assertNear(env.mod.GetNeedletickChance(-5), 0.05, 0.0001, "chance should not drop below base chance")
end

local function test_needletick_marks_proc_tears_only_for_holder_rolls()
    local env = loadNeverbirth()
    local holder = env.newPlayer({ luck = 0, collectibles = { [env.items.Needletick] = 1 }, rngSequence = { 0.049, 0.051 } })
    local procTear = env.newTear(holder)
    local normalTear = env.newTear(holder)

    env.runPostFireTear(procTear)
    env.runPostFireTear(normalTear)

    assertEquals(procTear:GetData().NeverbirthNeedletickTear, true, "successful roll should mark tear data")
    assertEquals(normalTear:GetData().NeverbirthNeedletickTear, nil, "failed roll should not mark tear")
end

local function test_needletick_proc_replaces_original_tear_variant_without_spawning_extra_entities()
    local env = loadNeverbirth({ needletickTearVariant = 3015 })
    local holder = env.newPlayer({ luck = 0, collectibles = { [env.items.Needletick] = 1 }, rngSequence = { 0 } })
    local tear = env.newTear(holder, Vector(100, 100), {
        variant = 0,
        velocity = Vector(9, -2),
        damage = 7.25,
        scale = 1.35,
        tearFlags = TearFlags.TEAR_HOMING,
    })

    env.runPostFireTear(tear)

    assertEquals(tear:GetData().NeverbirthNeedletickTear, true, "successful roll should mark original tear data")
    assertEquals(tear.Variant, 3015, "successful roll should ChangeVariant original tear into Needletick Tear")
    assertEquals(#tear.changedVariants, 1, "successful roll should call ChangeVariant exactly once")
    assertEquals(tear.sprite.played[1].animation, "RegularTear6", "successful roll should force a valid Isaac tear animation")
    assertNear(tear.SpriteScale.X, 1.6, 0.0001, "Needletick visual sprite should be scaled up so it is visible")
    assertNear(tear.SpriteScale.Y, 1.6, 0.0001, "Needletick visual sprite should be scaled up so it is visible")
    assertEquals(#tear.colors, 0, "Needletick should rely on its tear spritesheet instead of tinting the tear into a normal-looking blue/white projectile")
    assertEquals(tear.Velocity.X, 9, "ChangeVariant should preserve original tear velocity")
    assertEquals(tear.Velocity.Y, -2, "ChangeVariant should preserve original tear velocity")
    assertNear(tear.CollisionDamage, 7.25, 0.0001, "ChangeVariant should preserve original tear damage")
    assertNear(tear.Scale, 1.35, 0.0001, "ChangeVariant should preserve original tear scale")
    assertEquals(tear.TearFlags, TearFlags.TEAR_HOMING, "ChangeVariant should preserve original tear flags")
    assertEquals(#env.spawnedEntities, 0, "Needletick should not spawn an extra attack entity")
end

local function test_needletick_update_keeps_regular_tear_animation_visible()
    local env = loadNeverbirth({ needletickTearVariant = 3015 })
    local holder = env.newPlayer({ collectibles = { [env.items.Needletick] = 1 }, rngSequence = { 0 } })
    local tear = env.newTear(holder)

    env.runPostFireTear(tear)
    env.runPostTearUpdate(tear)

    assertEquals(tear.sprite.played[#tear.sprite.played].animation, "RegularTear6", "Needletick update should keep the tear on a valid visible animation")
    assertNear(tear.SpriteRotation, 0, 0.0001, "Needletick should point along horizontal tear velocity")

    tear.Velocity = Vector(0, -5)
    env.runPostTearUpdate(tear)

    assertNear(tear.SpriteRotation, -90, 0.0001, "Needletick should rotate with tear velocity like other custom tear sprites")
end

local function test_needletick_missing_resource_variant_marks_without_crashing()
    local env = loadNeverbirth({ needletickTearVariant = -1 })
    local holder = env.newPlayer({ luck = 0, collectibles = { [env.items.Needletick] = 1 }, rngSequence = { 0 } })
    local tear = env.newTear(holder, Vector(100, 100), { variant = 0 })

    env.runPostFireTear(tear)

    assertEquals(tear:GetData().NeverbirthNeedletickTear, true, "fallback should keep behavior mark when resource variant is missing")
    assertEquals(tear.Variant, 0, "fallback should not change to an invalid tear variant")
    assertEquals(#tear.changedVariants, 0, "fallback should not call ChangeVariant with an invalid variant")
end

local function test_needletick_kills_nearby_normal_enemies_on_collision()
    local env = loadNeverbirth()
    local holder = env.newPlayer({ collectibles = { [env.items.Needletick] = 1 }, rngSequence = { 0 } })
    local tear = env.newTear(holder, Vector(100, 100))
    local hit = env.newEnemy({ position = Vector(110, 100) })
    local nearby = env.newEnemy({ position = Vector(170, 100) })
    local far = env.newEnemy({ position = Vector(230, 100) })

    env.runPostFireTear(tear)
    env.runTearCollision(tear, hit)

    assertEquals(env.spawnedEntities[1].Type, EntityType.ENTITY_EFFECT, "Needletick impact should spawn visible feedback")
    assertEquals(env.spawnedEntities[1].Variant, EffectVariant.POOF01, "Needletick impact should use a visible poof placeholder")
    assertEquals(env.spawnedEntities[1].SpawnerEntity, tear, "Needletick impact effect source should be the tear")
    assertEquals(#hit.damageCalls, 1, "hit normal enemy should take lethal damage")
    assertEquals(hit.damageCalls[1].amount, hit.MaxHitPoints + 999, "hit normal enemy should be executed with damage")
    assertEquals(hit.damageCalls[1].flags, DamageFlag.DAMAGE_IGNORE_ARMOR, "execution damage should ignore armor")
    assertEquals(hit.damageCalls[1].source.Entity, tear, "execution source should be the special tear")
    assertEquals(#nearby.damageCalls, 1, "nearby normal enemy inside radius should take lethal damage")
    assertEquals(far.died, false, "enemy outside radius should survive")
end

local function test_needletick_does_not_kill_boss_champion_friendly_invulnerable_or_players()
    local env = loadNeverbirth()
    local holder = env.newPlayer({ collectibles = { [env.items.Needletick] = 1 }, rngSequence = { 0 } })
    local tear = env.newTear(holder, Vector(100, 100))
    local boss = env.newEnemy({ position = Vector(110, 100), boss = true })
    local champion = env.newEnemy({ position = Vector(120, 100), champion = true })
    local friendly = env.newEnemy({ position = Vector(130, 100), flags = EntityFlag.FLAG_FRIENDLY })
    local invulnerable = env.newEnemy({ position = Vector(140, 100), vulnerable = false })

    env.runPostFireTear(tear)
    env.runTearCollision(tear, boss)

    assertEquals(boss.died, false, "boss should be immune")
    assertEquals(champion.died, false, "champion should be immune")
    assertEquals(friendly.died, false, "friendly enemy should be immune")
    assertEquals(invulnerable.died, false, "invulnerable enemy should be immune")
    assertEquals(holder.died, nil, "player should not be killed")
end

test_xml_registers_needletick_item_text_and_devil_pool()
test_needletick_tear_resource_is_registered()
test_needletick_chance_scales_with_luck_and_clamps()
test_needletick_marks_proc_tears_only_for_holder_rolls()
test_needletick_proc_replaces_original_tear_variant_without_spawning_extra_entities()
test_needletick_update_keeps_regular_tear_animation_visible()
test_needletick_missing_resource_variant_marks_without_crashing()
test_needletick_kills_nearby_normal_enemies_on_collision()
test_needletick_does_not_kill_boss_champion_friendly_invulnerable_or_players()

print("needletick behavior tests passed")
