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

local function assertGreaterThan(actual, expected, message)
    if not (actual > expected) then
        error((message or "expected greater value") .. ": expected > " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function readFile(path)
    local file = assert(io.open(path, "r"), path .. " should exist")
    local text = file:read("*a")
    file:close()
    return text
end

local function readBinaryFile(path)
    local file = assert(io.open(path, "rb"), path .. " should exist")
    local text = file:read("*a")
    file:close()
    return text
end

local function readPngInfo(path)
    local data = readBinaryFile(path)
    local signature = string.char(137) .. "PNG\r\n" .. string.char(26) .. "\n"
    assertEquals(data:sub(1, 8), signature, path .. " should be a PNG")

    local function readBigEndian32(offset)
        local b1, b2, b3, b4 = data:byte(offset, offset + 3)
        return ((b1 * 256 + b2) * 256 + b3) * 256 + b4
    end

    return {
        width = readBigEndian32(17),
        height = readBigEndian32(21),
        colorType = data:byte(26),
    }
end

local function loadNeverbirth(options)
    options = options or {}
    local callbacks = {}
    local players = {}
    local roomEntities = {}
    local spawns = {}
    local debugStrings = {}
    local renderTexts = {}
    local hudTexts = {}
    local renderedSprites = {}
    local loadedSprites = {}
    local costumeIds = {
        ["gfx/characters/neverbirth_coin_faced_mask.anm2"] = 9103,
        ["gfx/characters/neverbirth_coin_faced_mask_broken.anm2"] = 9104,
        ["gfx/characters/costume_coin_faced_mask.anm2"] = 9101,
        ["gfx/characters/costume_coin_faced_mask_broken.anm2"] = 9102,
    }
    local itemIds = {
        CoinSewnSword = 748,
        CoinFacedMask = 749,
        BlackTaisui = 750,
        MeatLump = 751,
        CleansedWavyCap = 752,
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
        MC_POST_CURSE_EVAL = 16,
        MC_POST_PICKUP_UPDATE = 17,
    }
    CollectibleType = { COLLECTIBLE_NULL = 0, COLLECTIBLE_SPOON_BENDER = 3, COLLECTIBLE_1UP = 11, COLLECTIBLE_LOST_CONTACT = 213, COLLECTIBLE_PLAN_C = 475, COLLECTIBLE_WAVY_CAP = 582, COLLECTIBLE_DEATH_CERTIFICATE = 628 }
    CacheFlag = { CACHE_DAMAGE = 1, CACHE_SHOTSPEED = 2, CACHE_TEARCOLOR = 4, CACHE_SPEED = 8, CACHE_FIREDELAY = 16, CACHE_TEARFLAG = 32, CACHE_RANGE = 64, CACHE_LUCK = 1024 }
    DamageFlag = { DAMAGE_RED_HEARTS = 1, DAMAGE_NOKILL = 2, DAMAGE_INVINCIBLE = 4, DAMAGE_FAKE = 8, DAMAGE_IV_BAG = 16, DAMAGE_DEVIL = 32, DAMAGE_CURSED_DOOR = 64 }
    EntityFlag = { FLAG_CHARM = 1, FLAG_FRIENDLY = 2 }
    TearFlags = { TEAR_HOMING = 1, TEAR_PIERCING = 2, TEAR_SPECTRAL = 4 }
    EntityType = { ENTITY_PLAYER = 1, ENTITY_TEAR = 2, ENTITY_PICKUP = 5, ENTITY_SLOT = 6, ENTITY_PROJECTILE = 9, ENTITY_EFFECT = 1000 }
    PickupVariant = { PICKUP_HEART = 10, PICKUP_COIN = 20, PICKUP_KEY = 30, PICKUP_BOMB = 40, PICKUP_COLLECTIBLE = 100, PICKUP_TAROTCARD = 300 }
    HeartSubType = { HEART_HALF = 1, HEART_FULL = 2, HEART_SOUL = 3, HEART_HALF_SOUL = 8, HEART_BLACK = 6, HEART_HALF_BLACK = 10 }
    CoinSubType = { COIN_PENNY = 1 }
    KeySubType = { KEY_NORMAL = 1 }
    BombSubType = { BOMB_NORMAL = 1 }
    ItemPoolType = { POOL_TREASURE = 0, POOL_DEVIL = 3, POOL_ANGEL = 4 }
    RoomType = { ROOM_DEFAULT = 1, ROOM_BOSS = 5, ROOM_DEVIL = 14, ROOM_ANGEL = 15, ROOM_SACRIFICE = 17 }
    LevelCurse = { CURSE_OF_UNKNOWN = 4, CURSE_OF_LOST = 16, CURSE_OF_BLIND = 64 }
    GameStateFlag = { STATE_DEVILROOM_SPAWNED = 5, STATE_DEVILROOM_VISITED = 6 }
    GridRooms = { ROOM_DEVIL_IDX = -1 }
    ActiveSlot = { SLOT_PRIMARY = 0, SLOT_SECONDARY = 1, SLOT_POCKET = 2, SLOT_POCKET2 = 3 }
    ItemConfig = { TAG_BABY = 1 }
    Card = { RUNE_HAGALAZ = 32, RUNE_BLACK = 41, RUNE_SHARD = 55, CARD_SOUL_ISAAC = 81, CARD_SOUL_JACOB = 97 }
    EffectVariant = { POOF01 = 1, BLOOD_EXPLOSION = 2, PLAYER_CREEP_BLACK = 3, CREEP_RED = 4 }
    local coinSwordQiVariant = options.coinSwordQiVariant
    if coinSwordQiVariant == nil then
        coinSwordQiVariant = 3001
    end

    local roomClear = options.roomClear == true
    local roomType = options.roomType or RoomType.ROOM_DEFAULT
    local roomIndex = options.roomIndex or 1
    local stage = options.stage or 1
    local levelCurses = options.levelCurses or 0

    function MusicManager()
        return { GetCurrentMusicID = function() return 1 end, Play = function() end, Fadeout = function() end }
    end

    function Game()
        return {
            GetSeeds = function()
                return { GetStartSeedString = function() return "TEST RUN" end }
            end,
            GetNumPlayers = function() return #players end,
            GetItemPool = function()
                return { GetCollectible = function() return 1 end }
            end,
            GetHUD = function()
                return { ShowItemText = function(_, title, subtitle) hudTexts[#hudTexts + 1] = { title = title, subtitle = subtitle } end }
            end,
        GetRoom = function()
                return {
                    GetSpawnSeed = function() return 5000 end,
                    GetCenterPos = function() return Vector(320, 280) end,
                    GetType = function() return roomType end,
                    IsClear = function() return roomClear end,
                    FindFreePickupSpawnPosition = function(_, pos) return pos end,
                    IsPositionInRoom = function(_, pos) return pos.X >= 0 and pos.X <= 640 and pos.Y >= 0 and pos.Y <= 560 end,
                }
            end,
            GetLevel = function()
                return {
                    GetStage = function() return stage end,
                    GetStageType = function() return 0 end,
                    GetCurrentRoomIndex = function() return roomIndex end,
                    GetCurses = function() return levelCurses end,
                    SetCurses = function(_, curses) levelCurses = curses or 0 end,
                    RemoveCurses = function(_, mask) levelCurses = levelCurses & (~(mask or 0)) end,
                    RemoveCurse = function(_, curse) levelCurses = levelCurses & (~(curse or 0)) end,
                    AddAngelRoomChance = function() end,
                    InitializeDevilAngelRoom = function() end,
                }
            end,
            Spawn = function(_, entityType, variant, position, velocity, spawner, subtype, seed)
                spawns[#spawns + 1] = { entityType = entityType, variant = variant, subtype = subtype, position = position, velocity = velocity, spawner = spawner, seed = seed, viaGame = true }
                return spawns[#spawns]
            end,
            GetStateFlag = function() return false end,
            SetStateFlag = function() end,
        }
    end

    Isaac = {
        GetItemIdByName = function(name)
            if name == "Coin-Sewn Sword" or name == "铜钱剑" then return itemIds.CoinSewnSword end
            if name == "Coin-Faced Mask" or name == "铜钱面具" then return itemIds.CoinFacedMask end
            if name == "Black Taisui" or name == "黑太岁" then return itemIds.BlackTaisui end
            if name == "Meat Lump" or name == "肉块" then return itemIds.MeatLump end
            if name == "Cleansed Wavy Cap" or name == "净化迷幻菇" then return itemIds.CleansedWavyCap end
            return -1
        end,
        GetMusicIdByName = function() return -1 end,
        GetPlayer = function(index) return players[(index or 0) + 1] end,
        FindByType = function(entityType)
            if entityType == EntityType.ENTITY_PLAYER then return players end
            return {}
        end,
        GetRoomEntities = function() return roomEntities end,
        DebugString = function(message) debugStrings[#debugStrings + 1] = tostring(message) end,
        WorldToScreen = function(position) return position end,
        RenderText = function(text, x, y, r, g, b, a)
            renderTexts[#renderTexts + 1] = { text = text, x = x, y = y, r = r, g = g, b = b, a = a }
        end,
        GetEntityVariantByName = function(name)
            local variants = {
                ["Coin Sword Qi"] = coinSwordQiVariant,
                ["Black Taisui Spore"] = 3007,
                ["Black Taisui Pulse"] = 3008,
                ["Black Taisui Curse Devour"] = 3009,
                ["Black Taisui Reveal"] = 3010,
                ["Black Taisui Fear Pulse"] = 3011,
                ["Black Taisui Death Deny"] = 3012,
                ["Black Taisui Mature Core"] = 3013,
                ["Black Taisui Hallucination Eat"] = 3014,
            }
            return variants[name] or -1
        end,
        GetCostumeIdByPath = function(path)
            if options.missingCoinMaskCostumes then
                return -1
            end
            return costumeIds[path] or -1
        end,
        Spawn = function(entityType, variant, subtype, position, velocity, spawner)
            local entity = {
                Type = entityType,
                Variant = variant,
                SubType = subtype,
                Position = position,
                Velocity = velocity,
                SpawnerEntity = spawner,
                removed = false,
                SpriteRotation = 0,
                SpriteScale = Vector(1, 1),
                sprite = {
                    animations = {},
                    Rotation = 0,
                    Scale = Vector(1, 1),
                    Play = function(self, name) self.animations[#self.animations + 1] = name; self.current = name end,
                    IsFinished = function() return false end,
                    GetAnimation = function(self) return self.current end,
                    IsPlaying = function(self, name) return self.current == name end,
                },
                data = {},
            }
            function entity:GetData() return self.data end
            function entity:GetSprite() return self.sprite end
            function entity:ToEffect() return self end
            function entity:Remove() self.removed = true end
            function entity:SetColor(color) self.color = color end
            spawns[#spawns + 1] = entity
            if entityType == EntityType.ENTITY_EFFECT then
                roomEntities[#roomEntities + 1] = entity
            end
            return entity
        end,
        GetItemConfig = function()
            return {
                GetCollectible = function(_, subtype) return { Tags = 0, Type = 3, MaxCharges = 3, Name = "Mock", GfxFileName = "gfx/items/collectibles/mock_" .. tostring(subtype or 0) .. ".png" } end,
                GetCollectibles = function() return {} end,
            }
        end,
    }

    Color = setmetatable({}, { __call = function(_, r, g, b, a, ro, go, bo) return { R = r, G = g, B = b, A = a, RO = ro, GO = go, BO = bo } end })
    Color.Default = Color(1, 1, 1, 1, 0, 0, 0)
    function Sprite()
        local sprite = {
            loads = {},
            plays = {},
            renders = {},
            current = nil,
        }
        function sprite:Load(path, loadGraphics)
            self.loads[#self.loads + 1] = { path = path, loadGraphics = loadGraphics }
            loadedSprites[#loadedSprites + 1] = self
        end
        function sprite:Play(animation, force)
            self.plays[#self.plays + 1] = { animation = animation, force = force }
            self.current = animation
        end
        function sprite:Render(position)
            self.renders[#self.renders + 1] = { position = position }
            renderedSprites[#renderedSprites + 1] = { sprite = self, position = position }
        end
        return sprite
    end
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
            Normalized = function(self)
                local length = self:Length()
                if length <= 0 then return Vector(1, 0) end
                return Vector(self.X / length, self.Y / length)
            end,
            Resized = function(self, length)
                return self:Normalized() * length
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

    local function runUse(itemId, player, activeSlot)
        local callback = getCallbacks(ModCallbacks.MC_USE_ITEM, itemId)[1]
        assertTruthy(callback, "use callback should be registered for item " .. tostring(itemId))
        return callback(mod, itemId, nil, player, 0, activeSlot or ActiveSlot.SLOT_PRIMARY, 0)
    end

    local function runPostUpdate()
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_UPDATE)) do callback(mod) end
    end

    local function runDamage(player, amount, flags, sourceEntity)
        local result
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_ENTITY_TAKE_DMG, EntityType.ENTITY_PLAYER)) do
            local value = callback(mod, player, amount or 1, flags or 0, EntityRef(sourceEntity or player), 0)
            if value == false then result = false end
        end
        return result
    end

    local function runNewRoom()
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_NEW_ROOM)) do callback(mod) end
    end

    local function runNewLevel()
        stage = stage + 1
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_NEW_LEVEL)) do callback(mod) end
    end

    local function runEvaluate(player, cacheFlag)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_EVALUATE_CACHE)) do callback(mod, player, cacheFlag) end
    end

    local function runCurseEval(curses)
        local result = curses or 0
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_CURSE_EVAL)) do
            local value = callback(mod, result)
            if type(value) == "number" then
                result = value
            end
        end
        return result
    end

    local function runHeartCollision(pickup, player)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_PRE_PICKUP_COLLISION, PickupVariant.PICKUP_HEART)) do
            callback(mod, pickup, player, false)
        end
    end

    local function runPostFireTear(tear)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_FIRE_TEAR)) do
            callback(mod, tear)
        end
    end

    local function runPostRender()
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_RENDER)) do callback(mod) end
    end

    local function runPostPickupInit(pickup)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_PICKUP_INIT, pickup and pickup.Variant)) do
            callback(mod, pickup)
        end
    end

    local function runPostPickupUpdate(pickup)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_PICKUP_UPDATE, pickup and pickup.Variant)) do
            callback(mod, pickup)
        end
    end

    local function runPostAddCollectible(itemId, player)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_ADD_COLLECTIBLE, itemId)) do
            callback(mod, itemId, 0, true, 0, 0, player)
        end
    end

    local function newPlayer(opts)
        opts = opts or {}
        local player = {
            Type = EntityType.ENTITY_PLAYER,
            InitSeed = opts.initSeed or (#players + 100),
            Position = opts.position or Vector(100, 100),
            Damage = opts.damage or 3.5,
            MoveSpeed = opts.moveSpeed or 1,
            MaxFireDelay = opts.maxFireDelay or 10,
            TearRange = opts.tearRange or 260,
            Luck = opts.luck or 0,
            hearts = opts.hearts or opts.maxHearts or 6,
            maxHearts = opts.maxHearts or 6,
            soulHearts = opts.soulHearts or 0,
            blackHearts = opts.blackHearts or 0,
            coins = opts.coins or 0,
            collectibles = opts.collectibles or {},
            damageCalls = {},
            removedCollectibles = {},
            dead = opts.dead == true,
            addedNullCostumes = {},
            removedNullCostumes = {},
            nullCostumes = {},
            tears = {},
            cacheFlags = {},
            activeItems = opts.activeItems or { [ActiveSlot.SLOT_PRIMARY] = itemIds.CoinSewnSword },
            activeCharges = opts.activeCharges or {},
            dischargedSlots = {},
            rngSequence = opts.rngSequence or { 0, 0, 0, 0, 0, 0 },
            rngIndex = 0,
            testOptions = opts,
        }
        if not opts.noEffects then
            player.effects = {
                counts = {},
                addCalls = {},
                removeCalls = {},
                AddCollectibleEffect = function(self, itemId, addCostume, num)
                    self.addCalls[#self.addCalls + 1] = { itemId = itemId, addCostume = addCostume, num = num }
                    self.counts[itemId] = (self.counts[itemId] or 0) + (num or 1)
                end,
                RemoveCollectibleEffect = function(self, itemId, num)
                    self.removeCalls[#self.removeCalls + 1] = { itemId = itemId, num = num }
                    self.counts[itemId] = math.max(0, (self.counts[itemId] or 0) - (num or 1))
                end,
                GetCollectibleEffectNum = function(self, itemId)
                    return self.counts[itemId] or 0
                end,
                HasCollectibleEffect = function(self, itemId)
                    return (self.counts[itemId] or 0) > 0
                end,
            }
        end
        function player:ToPlayer() return self end
        function player:GetCollectibleNum(itemId) return self.collectibles[itemId] or 0 end
        function player:HasCollectible(itemId) return (self.collectibles[itemId] or 0) > 0 end
        function player:GetHearts() return self.hearts end
        function player:GetMaxHearts() return self.maxHearts end
        function player:GetSoulHearts() return self.soulHearts end
        function player:GetBlackHearts() return self.blackHearts end
        function player:AddHearts(amount) self.hearts = math.max(0, self.hearts + amount) end
        function player:AddMaxHearts(amount) self.maxHearts = math.max(0, self.maxHearts + amount) end
        function player:AddSoulHearts(amount) self.soulHearts = math.max(0, self.soulHearts + amount) end
        function player:AddBlackHearts(amount) self.blackHearts = math.max(0, self.blackHearts + amount); self.soulHearts = math.max(0, self.soulHearts + amount) end
        function player:AddCollectible(itemId, charge, firstTime)
            self.addedCollectibles = self.addedCollectibles or {}
            self.addedCollectibles[#self.addedCollectibles + 1] = { itemId = itemId, charge = charge, firstTime = firstTime }
            self.collectibles[itemId] = (self.collectibles[itemId] or 0) + 1
        end
        function player:RemoveCollectible(itemId)
            self.removedCollectibles[#self.removedCollectibles + 1] = itemId
            self.collectibles[itemId] = math.max(0, (self.collectibles[itemId] or 0) - 1)
        end
        function player:GetNumCoins() return self.coins end
        function player:AddCoins(amount) self.coins = self.coins + amount end
        function player:TakeDamage(amount, flags, source, countdown)
            self.damageCalls[#self.damageCalls + 1] = { amount = amount, flags = flags, source = source, countdown = countdown }
        end
        function player:AddNullCostume(costumeId)
            self.addedNullCostumes[#self.addedNullCostumes + 1] = costumeId
            self.nullCostumes[costumeId] = true
        end
        function player:TryRemoveNullCostume(costumeId)
            self.removedNullCostumes[#self.removedNullCostumes + 1] = costumeId
            self.nullCostumes[costumeId] = nil
        end
        function player:GetShootingInput() return self.testOptions.shootingInput end
        function player:GetMovementInput() return self.testOptions.movementInput end
        function player:GetFireDirection() return self.testOptions.fireDirection or Vector(1, 0) end
        function player:GetMovementDirection() return self.testOptions.moveDirection or Vector(1, 0) end
        function player:GetActiveItem(slot) return self.activeItems[slot or ActiveSlot.SLOT_PRIMARY] or 0 end
        function player:GetActiveCharge(slot) return self.activeCharges[slot or ActiveSlot.SLOT_PRIMARY] or 0 end
        function player:SetActiveCharge(charge, slot)
            self.activeCharges[slot or ActiveSlot.SLOT_PRIMARY] = charge
        end
        function player:DischargeActiveItem(slot) self.dischargedSlots[#self.dischargedSlots + 1] = slot or ActiveSlot.SLOT_PRIMARY end
        function player:GetCollectibleRNG()
            return {
                RandomInt = function(_, max)
                    player.rngIndex = player.rngIndex + 1
                    return (player.rngSequence[player.rngIndex] or 0) % max
                end,
            }
        end
        function player:AddCacheFlags(flag) self.cacheFlags[#self.cacheFlags + 1] = flag end
        function player:EvaluateItems() end
        function player:SetColor(color) self.lastColor = color end
        function player:IsDead() return self.dead == true end
        function player:Revive() self.revived = (self.revived or 0) + 1; self.dead = false end
        function player:GetEffects() return self.effects end
        function player:HasMortalDamage() return self.testOptions.hasMortalDamage == true end
        players[#players + 1] = player
        return player
    end

    local function newCollectiblePickup(subtype, opts)
        opts = opts or {}
        local pickup = {
            Type = EntityType.ENTITY_PICKUP,
            Variant = PickupVariant.PICKUP_COLLECTIBLE,
            SubType = subtype or 1,
            Position = opts.position or Vector(160, 100),
            OptionsPickupIndex = opts.optionsPickupIndex or 0,
            Price = opts.price or 0,
            ShopItemId = opts.shopItemId or 0,
            hidden = opts.hidden == true,
            morphCalls = {},
            updateAppearanceCalls = 0,
        }
        pickup.sprite = {
            animation = opts.animation or "Idle",
            replacedSpritesheets = {},
            loadGraphicsCalls = 0,
            playCalls = {},
            setFrames = {},
            GetAnimation = function(self) return self.animation end,
            ReplaceSpritesheet = function(self, layer, path)
                self.replacedSpritesheets[#self.replacedSpritesheets + 1] = { layer = layer, path = path }
            end,
            LoadGraphics = function(self) self.loadGraphicsCalls = self.loadGraphicsCalls + 1 end,
            Play = function(self, animation, force)
                self.playCalls[#self.playCalls + 1] = { animation = animation, force = force }
                self.animation = animation
            end,
            SetFrame = function(self, animation, frame)
                self.setFrames[#self.setFrames + 1] = { animation = animation, frame = frame }
                self.animation = animation
            end,
        }
        function pickup:ToPickup() return self end
        function pickup:GetData() self.data = self.data or {}; return self.data end
        function pickup:GetSprite() return self.sprite end
        function pickup:Morph(entityType, variant, newSubtype, keepPrice, keepSeed, ignoreModifiers)
            self.morphCalls[#self.morphCalls + 1] = {
                entityType = entityType,
                variant = variant,
                subtype = newSubtype,
                keepPrice = keepPrice,
                keepSeed = keepSeed,
                ignoreModifiers = ignoreModifiers,
                optionsPickupIndex = self.OptionsPickupIndex,
                price = self.Price,
                shopItemId = self.ShopItemId,
            }
            self.Type = entityType
            self.Variant = variant
            self.SubType = newSubtype
            self.hidden = false
        end
        function pickup:UpdateAppearance()
            self.updateAppearanceCalls = self.updateAppearanceCalls + 1
            self.hidden = false
        end
        roomEntities[#roomEntities + 1] = pickup
        return pickup
    end

    local function newEnemy(x, y)
        local enemy = { Type = 10, Position = Vector(x or 200, y or 100), confused = 0, feared = 0, data = {}, damageTaken = 0, removed = false }
        function enemy:IsVulnerableEnemy() return true end
        function enemy:ToNPC() return self end
        function enemy:GetData() return self.data end
        function enemy:AddConfusion(_, duration) self.confused = self.confused + (duration or 0) end
        function enemy:AddFear(_, duration) self.feared = self.feared + (duration or 0) end
        function enemy:TakeDamage(amount) self.damageTaken = self.damageTaken + amount end
        roomEntities[#roomEntities + 1] = enemy
        return enemy
    end

    local function newProjectile(x, y)
        local projectile = { Type = EntityType.ENTITY_PROJECTILE, Position = Vector(x or 155, y or 100), removed = false, died = false }
        function projectile:Remove() self.removed = true end
        function projectile:Die() self.died = true; self.removed = true end
        roomEntities[#roomEntities + 1] = projectile
        return projectile
    end

    local function newRoomEntity(entityType, x, y)
        local entity = { Type = entityType, Position = Vector(x or 155, y or 100), removed = false }
        function entity:Remove() self.removed = true end
        roomEntities[#roomEntities + 1] = entity
        return entity
    end

    local function newHeart(subtype)
        return { Type = EntityType.ENTITY_PICKUP, Variant = PickupVariant.PICKUP_HEART, SubType = subtype or HeartSubType.HEART_HALF, Position = Vector(120, 100) }
    end

    return {
        items = itemIds,
        spawns = spawns,
        roomEntities = roomEntities,
        newPlayer = newPlayer,
        newEnemy = newEnemy,
        newProjectile = newProjectile,
        newRoomEntity = newRoomEntity,
        newCollectiblePickup = newCollectiblePickup,
        newHeart = newHeart,
        runUse = runUse,
        runPostUpdate = runPostUpdate,
        runDamage = runDamage,
        runNewRoom = runNewRoom,
        runNewLevel = runNewLevel,
        runEvaluate = runEvaluate,
        runCurseEval = runCurseEval,
        runHeartCollision = runHeartCollision,
        runPostFireTear = runPostFireTear,
        runPostRender = runPostRender,
        runPostPickupInit = runPostPickupInit,
        runPostPickupUpdate = runPostPickupUpdate,
        runPostAddCollectible = runPostAddCollectible,
        getLevelCurses = function() return levelCurses end,
        setLevelCurses = function(curses) levelCurses = curses or 0 end,
        runEffectUpdate = function(effect)
            local variant = effect and effect.Variant or coinSwordQiVariant
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_EFFECT_UPDATE, variant)) do
                callback(mod, effect)
            end
        end,
        setRoomClear = function(value) roomClear = value end,
        setRoomIndex = function(value) roomIndex = value or roomIndex end,
        coinSwordQiVariant = coinSwordQiVariant,
        costumes = {
            active = costumeIds["gfx/characters/costume_coin_faced_mask.anm2"],
            broken = costumeIds["gfx/characters/costume_coin_faced_mask_broken.anm2"],
            fallbackActive = costumeIds["gfx/characters/neverbirth_coin_faced_mask.anm2"],
            fallbackBroken = costumeIds["gfx/characters/neverbirth_coin_faced_mask_broken.anm2"],
        },
        debugStrings = debugStrings,
        renderTexts = renderTexts,
        hudTexts = hudTexts,
        renderedSprites = renderedSprites,
        loadedSprites = loadedSprites,
        mod = mod,
    }
end

local function countSpawns(env, variant, subtype)
    local count = 0
    for _, spawn in ipairs(env.spawns) do
        local spawnVariant = spawn.variant or spawn.Variant
        local spawnSubtype = spawn.subtype or spawn.SubType
        if spawnVariant == variant and (subtype == nil or spawnSubtype == subtype) then
            count = count + 1
        end
    end
    return count
end

local function coinSwordEffects(env)
    local effects = {}
    for _, spawn in ipairs(env.spawns) do
        if spawn.Type == EntityType.ENTITY_EFFECT and spawn.Variant == env.coinSwordQiVariant then
            effects[#effects + 1] = spawn
        end
    end
    return effects
end

local function coinSwordDataEffects(env)
    local effects = {}
    for _, spawn in ipairs(env.spawns) do
        if spawn.Type == EntityType.ENTITY_EFFECT and spawn.GetData and spawn:GetData().NeverbirthCoinSwordQi then
            effects[#effects + 1] = spawn
        end
    end
    return effects
end

local function effectSpawns(env, variant)
    local effects = {}
    for _, spawn in ipairs(env.spawns) do
        if spawn.Type == EntityType.ENTITY_EFFECT and spawn.Variant == variant then
            effects[#effects + 1] = spawn
        end
    end
    return effects
end

local function countEffectSpawns(env, variant)
    return #effectSpawns(env, variant)
end

local function assertNoDischargeResult(result, message)
    assertTruthy(type(result) == "table", message or "initial Coin-Sewn Sword use should return a use-result table")
    assertEquals(result.Discharge, false, message or "initial Coin-Sewn Sword use should not discharge")
end

local function beginAndFireCoinSword(env, player, direction)
    local result = env.runUse(env.items.CoinSewnSword, player)
    assertNoDischargeResult(result, "Coin-Sewn Sword should only enter holding state on first use")
    player.testOptions.shootingInput = direction or player.testOptions.shootingInput or Vector(1, 0)
    env.runPostUpdate()
end

local function itemPoolBlock(pools, name)
    return pools:match('<Pool Name="' .. name .. '".-</Pool>') or ""
end

local function test_xml_registers_folk_horror_items_and_pools()
    local items = readFile("content/items.xml")
    local pools = readFile("content/itempools.xml")
    local entities = readFile("content/entities2.xml")

    assertTruthy(items:find('<active%s+name="Coin%-Sewn Sword".-maxcharges="3".-description="Coin and blade share the same edge%.". -', 1) or items:find('<active%s+name="Coin%-Sewn Sword".-maxcharges="3".-description="Coin and blade share the same edge%."', 1), "Coin-Sewn Sword should be a 3-charge active")
    assertTruthy(items:find('<passive%s+name="Coin%-Faced Mask".-description="Buy yourself another face%."', 1), "Coin-Faced Mask should be registered as passive")
    assertTruthy(items:find('<passive%s+name="Black Taisui".-cache="all".-description="Feeds on blood and lets you see clearly%."', 1), "Black Taisui should be registered as passive")
    assertTruthy(items:find('<passive%s+name="Black Taisui".-gfx="BlackTaisui%.png"', 1), "Black Taisui should keep its own collectible icon")
    assertTruthy(items:find('<passive%s+name="Meat Lump".-cache="all".-description="One more bite"', 1), "Meat Lump should be registered as passive")
    assertTruthy(items:find('<active%s+name="Cleansed Wavy Cap".-maxcharges="900".-chargetype="timed".-description="Placeholder logic for a purified mushroom%."', 1), "Cleansed Wavy Cap should use Wavy Cap timed charge mode")
    assertTruthy(items:find('<active%s+name="Cleansed Wavy Cap".-gfx="PurifiedMushroom%.png"', 1), "Cleansed Wavy Cap should use the Purified Mushroom collectible icon")
    assertTruthy(not items:find('<active%s+name="Cleansed Wavy Cap".-gfx="PurifiedMushroom_64%.png"', 1), "Cleansed Wavy Cap should not use the 64px preview icon")

    assertTruthy(itemPoolBlock(pools, "shop"):find('<Item Name="Coin%-Sewn Sword" Weight="1"', 1), "Coin-Sewn Sword should be in shop")
    assertTruthy(itemPoolBlock(pools, "treasure"):find('<Item Name="Coin%-Sewn Sword" Weight="1"', 1), "Coin-Sewn Sword should be in treasure")
    assertTruthy(itemPoolBlock(pools, "curse"):find('<Item Name="Coin%-Sewn Sword" Weight="1"', 1), "Coin-Sewn Sword should be in curse")
    assertTruthy(itemPoolBlock(pools, "devil"):find('<Item Name="Coin%-Faced Mask" Weight="1"', 1), "Coin-Faced Mask should be in devil")
    assertTruthy(itemPoolBlock(pools, "secret"):find('<Item Name="Black Taisui" Weight="0.2"', 1), "Black Taisui should be in secret at low weight")
    assertTruthy(itemPoolBlock(pools, "curse"):find('<Item Name="Black Taisui" Weight="0.2"', 1), "Black Taisui should be in curse at low weight")
    assertTruthy(not itemPoolBlock(pools, "devil"):find('<Item Name="Black Taisui"', 1), "Black Taisui should not remain in devil pool")
    assertTruthy(not pools:find('<Item Name="Meat Lump"', 1, true), "Meat Lump should not appear in natural item pools")
    assertTruthy(not pools:find('<Item Name="Cleansed Wavy Cap"', 1, true), "Cleansed Wavy Cap should not appear in natural item pools")
    assertTruthy(entities:find('name="Coin Sword Qi"', 1, true), "entities2.xml should register Coin Sword Qi")
    assertTruthy(entities:find('anm2path="Effects/CoinSwordQi/CoinSwordQi.anm2"', 1, true), "Coin Sword Qi should use an anm2 path relative to gfx/")
    assertTruthy(not entities:find('anm2path="gfx/Effects/CoinSwordQi/CoinSwordQi.anm2"', 1, true), "Coin Sword Qi should not double-prefix gfx in entities2.xml")

    local anm2 = readFile("resources/gfx/Effects/CoinSwordQi/CoinSwordQi.anm2")
    assertTruthy(anm2:find('<Spritesheet Path="CoinSwordQi.png"', 1, true), "Coin Sword Qi anm2 should resolve the png from its own folder")
    assertTruthy(anm2:find('Animation Name="Slash"', 1, true), "Coin Sword Qi anm2 should contain Slash")
    assertTruthy(anm2:find('Animation Name="BloodSlash"', 1, true), "Coin Sword Qi anm2 should contain BloodSlash")
    assertTruthy(anm2:find('Animation Name="EmpoweredSlash"', 1, true), "Coin Sword Qi anm2 should contain EmpoweredSlash")
end

local function test_purified_mushroom_icon_resource_is_collectible_ready()
    local icon = readPngInfo("resources/gfx/Items/Collectibles/PurifiedMushroom.png")
    assertEquals(icon.width, 32, "PurifiedMushroom.png should be 32px wide")
    assertEquals(icon.height, 32, "PurifiedMushroom.png should be 32px tall")
    assertEquals(icon.colorType, 6, "PurifiedMushroom.png should be RGBA")

    local preview = readPngInfo("resources/gfx/Items/Collectibles/PurifiedMushroom_64.png")
    assertEquals(preview.width, 64, "PurifiedMushroom_64.png should be 64px wide")
    assertEquals(preview.height, 64, "PurifiedMushroom_64.png should be 64px tall")

    for _, path in ipairs({ "content/items.xml", "content/items.zh_cn.xml", "content/items.en_us.xml" }) do
        local xml = readFile(path)
        assertTruthy(xml:find('gfx="PurifiedMushroom%.png"', 1), path .. " should reference the 32px Purified Mushroom icon")
        assertTruthy(not xml:find('gfx="PurifiedMushroom_64%.png"', 1), path .. " should not reference the 64px preview icon")
    end
end

local function test_coin_sewn_sword_spends_six_coins_for_six_slashes_and_empowered_slash()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 8, damage = 5 })
    env.newEnemy(200, 100)

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effects = coinSwordEffects(env)

    assertEquals(player.coins, 2, "Coin-Sewn Sword should spend at most six coins")
    assertEquals(#player.dischargedSlots, 1, "Coin-Sewn Sword should discharge only when qi is fired")
    assertEquals(#effects, 7, "six coins should create six sword qi effects plus one empowered qi effect")
    assertEquals(effects[1]:GetData().Mode, "normal", "coin-spent qi should use normal mode")
    assertEquals(effects[1]:GetData().Damage, 10, "normal sword qi should deal player damage x2.0")
    assertEquals(effects[1].Variant, env.coinSwordQiVariant, "Coin-Sewn Sword should spawn the custom Coin Sword Qi variant")
    assertEquals(effects[1]:GetSprite().current, "Slash", "normal sword qi should play Slash")
    assertEquals(effects[7]:GetData().Mode, "empowered", "full spend should create empowered qi")
    assertEquals(effects[7]:GetData().Damage, 30, "empowered qi should deal player damage x6.0")
    assertEquals(effects[7]:GetData().Piercing, true, "empowered qi should be piercing")
    assertEquals(effects[7]:GetSprite().current, "EmpoweredSlash", "empowered sword qi should play EmpoweredSlash")
    assertGreaterThan(effects[7].SpriteScale.X, 1.4, "empowered sword qi should be visually larger than normal qi")
    assertTruthy(effects[7]:GetData().Length > effects[1]:GetData().Length, "empowered qi should have a larger hitbox than normal qi")
    assertEquals(#player.tears or 0, 0, "Coin-Sewn Sword should not use player tears as its primary qi")
end

local function test_coin_sewn_sword_spreads_six_qi_visibly()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 6, damage = 5 })

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effects = coinSwordEffects(env)

    assertGreaterThan(math.abs(effects[1].Velocity.Y), 11, "first qi should reach the edge of the 150-degree forward fan")
    assertGreaterThan(math.abs(effects[6].Velocity.Y), 11, "last qi should reach the other edge of the 150-degree forward fan")
    assertGreaterThan(math.abs(effects[6].Velocity.Y - effects[1].Velocity.Y), 22, "six qi should be spread across a wide 150-degree fan")
    assertGreaterThan(math.abs(effects[2].Position.X - effects[1].Position.X) + math.abs(effects[2].Position.Y - effects[1].Position.Y), 1, "adjacent qi should not spawn on the exact same point")
end

local function test_coin_sewn_sword_holds_without_spending_until_direction_input()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 6, damage = 5, shootingInput = Vector(0, 0), fireDirection = -1, moveDirection = -1 })

    local result = env.runUse(env.items.CoinSewnSword, player)
    env.runPostUpdate()

    assertNoDischargeResult(result, "Coin-Sewn Sword should not discharge when only raised")
    assertEquals(player.coins, 6, "Coin-Sewn Sword should not spend coins before direction input")
    assertEquals(#coinSwordEffects(env), 0, "Coin-Sewn Sword should not fire before direction input")
    assertEquals(#player.dischargedSlots, 0, "Coin-Sewn Sword should not discharge before direction input")

    player.testOptions.shootingInput = Vector(0, -1)
    env.runPostUpdate()

    assertEquals(player.coins, 0, "Coin-Sewn Sword should spend coins after direction input")
    assertEquals(#coinSwordEffects(env), 7, "Coin-Sewn Sword should fire after direction input")
    assertEquals(#player.dischargedSlots, 1, "Coin-Sewn Sword should discharge after direction input")
end

local function test_coin_sewn_sword_second_use_cancels_holding_without_spending()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 6, damage = 5, shootingInput = Vector(0, 0), fireDirection = -1, moveDirection = -1 })

    env.runUse(env.items.CoinSewnSword, player)
    local cancelResult = env.runUse(env.items.CoinSewnSword, player)
    env.runPostUpdate()

    assertNoDischargeResult(cancelResult, "Coin-Sewn Sword cancel should not discharge")
    assertEquals(player.coins, 6, "cancelling Coin-Sewn Sword should not spend coins")
    assertEquals(#coinSwordEffects(env), 0, "cancelling Coin-Sewn Sword should not fire qi")
    assertEquals(#player.dischargedSlots, 0, "cancelling Coin-Sewn Sword should not discharge")
end

local function test_coin_sewn_sword_spends_available_coins_only()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 3, damage = 5 })
    env.newEnemy(200, 100)

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effects = coinSwordEffects(env)

    assertEquals(player.coins, 0, "Coin-Sewn Sword should spend all three available coins")
    assertEquals(#effects, 3, "three coins should create three sword qi effects")
end

local function test_coin_sewn_sword_no_coins_backlashes_and_fires_blood_qi()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 0, damage = 5 })

    beginAndFireCoinSword(env, player, Vector(1, 0))

    assertEquals(#player.damageCalls, 1, "no coins should cause half-heart backlash")
    assertEquals(player.damageCalls[1].amount, 1, "backlash should be half a heart")
    local effects = coinSwordEffects(env)
    assertEquals(#effects, 1, "no coins should fire one blood sword qi effect")
    assertEquals(effects[1]:GetData().Mode, "blood", "no-coin qi should use blood mode")
    assertEquals(effects[1]:GetData().Damage, 20, "blood sword qi should deal player damage x4.0")
    assertEquals(effects[1]:GetSprite().current, "BloodSlash", "blood sword qi should play BloodSlash")
    assertEquals(effects[1].color, nil, "blood sword qi should not rely on code-side tinting")
    assertEquals(math.floor(effects[1].Velocity.Y + 0.5), 0, "single blood qi should fire along the input direction")
    assertGreaterThan(effects[1]:GetData().Width, effects[1]:GetData().Length * 0.75, "blood qi should use its own wide hitbox")
end

local function test_coin_sword_qi_effect_hits_enemy_and_normal_qi_disappears()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 1, damage = 5 })
    local enemy = env.newEnemy(155, 100)

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effect = coinSwordEffects(env)[1]
    env.runEffectUpdate(effect)
    env.runEffectUpdate(effect)

    assertEquals(enemy.damageTaken, 10, "normal Coin Sword Qi should damage enemies in its hitbox once")
    assertEquals(effect.removed, false, "normal Coin Sword Qi should play its disappear animation before being removed")
    assertEquals(effect:GetSprite().current, "Disappear", "normal Coin Sword Qi should switch to Disappear after hitting")
    for _ = 1, 4 do
        env.runEffectUpdate(effect)
    end
    assertEquals(effect.removed, true, "normal Coin Sword Qi should remove itself after its disappear animation window")
end

local function test_coin_sword_qi_hitbox_matches_visual_center_but_not_far_outside()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 1, damage = 5 })
    local nearEdge = env.newEnemy(155, 131)

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effect = coinSwordEffects(env)[1]
    env.runEffectUpdate(effect)

    assertEquals(nearEdge.damageTaken, 10, "normal qi should hit enemies near the visible 96x96 slash edge")

    local envMiss = loadNeverbirth()
    local playerMiss = envMiss.newPlayer({ coins = 1, damage = 5 })
    local outside = envMiss.newEnemy(155, 150)
    beginAndFireCoinSword(envMiss, playerMiss, Vector(1, 0))
    local missEffect = coinSwordEffects(envMiss)[1]
    envMiss.runEffectUpdate(missEffect)

    assertEquals(outside.damageTaken, 0, "normal qi should not hit enemies clearly outside the slash visual")
end

local function test_blood_coin_sword_qi_damages_enemy_in_its_hitbox()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 0, damage = 5 })
    local enemy = env.newEnemy(150, 100)

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effects = coinSwordEffects(env)
    env.runEffectUpdate(effects[1])

    assertEquals(enemy.damageTaken, 20, "blood qi should deal player damage x4.0 to enemies in its hitbox")
end

local function test_coin_sword_debug_hitbox_renders_only_when_enabled()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 1, damage = 5 })

    beginAndFireCoinSword(env, player, Vector(1, 0))
    env.runPostRender()
    assertEquals(#env.renderTexts, 0, "Coin Sword Qi hitbox debug should be silent by default")

    env.mod.DebugCoinSwordHitbox = true
    env.runPostRender()
    assertTruthy(#env.renderTexts > 0, "debug hitbox mode should render hitbox markers")
    assertTruthy(tostring(env.renderTexts[1].text):find("CSQ", 1, true), "debug hitbox markers should be identifiable")
end

local function test_coin_sword_qi_fallback_effect_still_updates_when_variant_lookup_fails()
    local env = loadNeverbirth({ coinSwordQiVariant = -1 })
    local player = env.newPlayer({ coins = 1, damage = 5 })
    local enemy = env.newEnemy(155, 100)

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effect = coinSwordDataEffects(env)[1]
    assertTruthy(effect, "fallback Coin Sword Qi should still spawn an effect with qi data")
    env.runEffectUpdate(effect)
    env.runEffectUpdate(effect)

    assertEquals(enemy.damageTaken, 10, "fallback Coin Sword Qi should still run hitbox damage")
    assertEquals(effect:GetSprite().current, "Disappear", "fallback normal Coin Sword Qi should still play disappear before removal")
end

local function test_coin_sword_qi_uses_player_shooting_direction_and_entity_rotation()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 1, damage = 5, position = Vector(100, 100), shootingInput = Vector(0, -1) })
    env.newEnemy(250, 100)

    beginAndFireCoinSword(env, player, Vector(0, -1))
    local effect = coinSwordEffects(env)[1]

    assertEquals(math.floor(effect.Velocity.X + 0.5), 0, "Coin Sword Qi should not aim at enemies before player shooting input")
    assertEquals(math.floor(effect.Velocity.Y + 0.5), -12, "Coin Sword Qi should follow the player's shooting direction")
    assertEquals(math.floor(effect.SpriteRotation + 0.5), -90, "Coin Sword Qi should rotate the entity sprite toward velocity")
end

local function test_coin_sword_qi_does_not_write_effect_rotation()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 1, damage = 5 })

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effect = coinSwordEffects(env)[1]

    assertEquals(effect.Rotation, nil, "Coin Sword Qi should not write effect.Rotation because it is not writable in-game")
    assertEquals(effect:GetSprite().Rotation, 0, "Coin Sword Qi should rotate the sprite object instead")
end

local function test_coin_sewn_sword_removes_tears_while_held_and_release_shot_only()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 6, damage = 5, shootingInput = Vector(0, 0), fireDirection = -1, moveDirection = -1 })

    env.runUse(env.items.CoinSewnSword, player)
    local heldTear = { Type = EntityType.ENTITY_TEAR, SpawnerEntity = player, removed = false }
    function heldTear:Remove() self.removed = true end
    env.runPostFireTear(heldTear)
    assertEquals(heldTear.removed, true, "Coin-Sewn Sword should remove normal tears while raised")

    player.testOptions.shootingInput = Vector(1, 0)
    env.runPostUpdate()
    local releaseTear = { Type = EntityType.ENTITY_TEAR, SpawnerEntity = player, removed = false }
    function releaseTear:Remove() self.removed = true end
    env.runPostFireTear(releaseTear)
    assertEquals(releaseTear.removed, true, "Coin-Sewn Sword should remove the normal tear from the release input")

    local laterTear = { Type = EntityType.ENTITY_TEAR, SpawnerEntity = player, removed = false }
    function laterTear:Remove() self.removed = true end
    env.runPostFireTear(laterTear)
    assertEquals(laterTear.removed, false, "Coin-Sewn Sword should allow normal tears after the qi release shot is consumed")
end

local function test_coin_sewn_sword_cancel_allows_tears_again()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 6, damage = 5, shootingInput = Vector(0, 0), fireDirection = -1, moveDirection = -1 })

    env.runUse(env.items.CoinSewnSword, player)
    env.runUse(env.items.CoinSewnSword, player)

    local tear = { Type = EntityType.ENTITY_TEAR, SpawnerEntity = player, removed = false }
    function tear:Remove() self.removed = true end
    env.runPostFireTear(tear)

    assertEquals(tear.removed, false, "cancelling Coin-Sewn Sword should restore normal tear firing")
end

local function test_empowered_coin_sword_qi_pierces_multiple_enemies()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 6, damage = 5 })
    local enemyA = env.newEnemy(155, 100)
    local enemyB = env.newEnemy(180, 100)

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effect = coinSwordEffects(env)[7]
    env.runEffectUpdate(effect)

    assertEquals(enemyA.damageTaken, 30, "empowered qi should hit the first enemy")
    assertEquals(enemyB.damageTaken, 30, "empowered qi should pierce into the second enemy")
    assertEquals(effect.removed, false, "empowered qi should not disappear after the first hit")
end

local function test_coin_sword_qi_inherits_spoon_bender_homing()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 1, damage = 5, collectibles = { [3] = 1 } })
    env.newEnemy(190, 40)

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effect = coinSwordEffects(env)[1]
    local originalY = effect.Velocity.Y
    env.runEffectUpdate(effect)

    assertEquals(effect:GetData().Homing, true, "Spoon Bender should mark Coin Sword Qi as homing")
    assertTruthy(effect.Velocity.Y < originalY, "homing Coin Sword Qi should bend toward the nearest enemy")
end

local function test_coin_sword_qi_without_spoon_bender_does_not_home()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 1, damage = 5 })
    env.newEnemy(190, 40)

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effect = coinSwordEffects(env)[1]
    env.runEffectUpdate(effect)

    assertEquals(effect:GetData().Homing, false, "Coin Sword Qi should not be homing without Spoon Bender")
    assertEquals(math.floor(effect.Velocity.Y + 0.5), 0, "non-homing Coin Sword Qi should keep the input direction")
end

local function test_lost_contact_coin_sword_qi_blocks_projectiles()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 1, damage = 5, collectibles = { [213] = 1 } })
    local projectile = env.newProjectile(155, 100)

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effect = coinSwordEffects(env)[1]
    env.runEffectUpdate(effect)

    assertEquals(effect:GetData().Shielded, true, "Lost Contact should mark Coin Sword Qi as shielded")
    assertEquals(projectile.removed, true, "shielded Coin Sword Qi should remove enemy projectiles in its hitbox")
    assertEquals(effect:GetSprite().current, "Disappear", "normal shielded Coin Sword Qi should disappear after blocking a projectile")
end

local function test_empowered_lost_contact_coin_sword_qi_blocks_without_disappearing()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 6, damage = 5, collectibles = { [213] = 1 } })
    local projectileA = env.newProjectile(170, 100)
    local projectileB = env.newProjectile(195, 100)

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effect = coinSwordEffects(env)[7]
    env.runEffectUpdate(effect)

    assertEquals(projectileA.removed, true, "empowered shielded qi should remove the first projectile")
    assertEquals(projectileB.removed, true, "empowered shielded qi should remove the second projectile")
    assertEquals(effect:GetSprite().current, "EmpoweredSlash", "empowered shielded qi should keep flying after blocking")
    assertEquals(effect.removed, false, "empowered shielded qi should not be removed after blocking projectiles")
end

local function test_lost_contact_coin_sword_qi_does_not_remove_player_tears_or_pickups()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 1, damage = 5, collectibles = { [213] = 1 } })
    local tear = env.newRoomEntity(EntityType.ENTITY_TEAR, 155, 100)
    local pickup = env.newRoomEntity(EntityType.ENTITY_PICKUP, 155, 100)

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effect = coinSwordEffects(env)[1]
    env.runEffectUpdate(effect)

    assertEquals(tear.removed, false, "shielded Coin Sword Qi should not remove player tears")
    assertEquals(pickup.removed, false, "shielded Coin Sword Qi should not remove pickups")
end

local function test_coin_sword_qi_can_home_and_block_projectiles_together()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 1, damage = 5, collectibles = { [3] = 1, [213] = 1 } })
    env.newEnemy(190, 40)
    local projectile = env.newProjectile(155, 100)

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effect = coinSwordEffects(env)[1]
    env.runEffectUpdate(effect)

    assertEquals(effect:GetData().Homing, true, "Spoon Bender compatibility should still be active")
    assertEquals(effect:GetData().Shielded, true, "Lost Contact compatibility should still be active")
    assertTruthy(effect:GetData().Direction.Y < 0, "homing should still adjust direction while shielded")
    assertEquals(projectile.removed, true, "shielded homing qi should still block projectiles")
end

local function test_coin_sword_qi_expires()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 1, damage = 5 })

    beginAndFireCoinSword(env, player, Vector(1, 0))
    local effect = coinSwordEffects(env)[1]
    effect:GetData().Life = 1
    env.runEffectUpdate(effect)

    assertEquals(effect.removed, true, "Coin Sword Qi should remove itself when its life expires")
end

local function test_coin_faced_mask_enters_room_with_mask_and_confuses_enemies()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 5, collectibles = { [env.items.CoinFacedMask] = 1 } })
    local enemy = env.newEnemy(130, 100)

    env.runNewRoom()

    assertTruthy(enemy.confused > 0, "Coin-Faced Mask should disturb enemies when entering with enough coins")
end

local function test_coin_faced_mask_active_costume_appears_when_room_mask_is_active()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 5, collectibles = { [env.items.CoinFacedMask] = 1 } })

    env.runNewRoom()

    assertTruthy(player.nullCostumes[env.costumes.active], "active mask costume should be worn after entering with enough coins")
    assertEquals(player.nullCostumes[env.costumes.fallbackActive], nil, "stable 32px head costume should be preferred over the oversized fallback")
    assertEquals(player.nullCostumes[env.costumes.broken], nil, "broken mask costume should not be worn while the mask is intact")
end

local function test_coin_faced_mask_active_costume_appears_when_picked_up_mid_room()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 5 })

    env.runPostUpdate()
    assertEquals(player.nullCostumes[env.costumes.active], nil, "mask should not appear before the item is held")

    player.collectibles[env.items.CoinFacedMask] = 1
    env.runPostUpdate()

    assertTruthy(player.nullCostumes[env.costumes.active], "active mask costume should appear immediately when picked up mid-room")
end

local function test_coin_faced_mask_does_not_fake_an_overlay_when_null_costume_is_unavailable()
    local env = loadNeverbirth({ missingCoinMaskCostumes = true })
    local player = env.newPlayer({ coins = 5, collectibles = { [env.items.CoinFacedMask] = 1 } })

    env.runPostUpdate()
    env.runPostRender()

    assertEquals(#player.addedNullCostumes, 0, "missing costume ids should not try to add an invalid null costume")
    assertEquals(#env.renderedSprites, 0, "coin-faced mask should not fake a player costume with a loose overlay")
    assertEquals(#env.loadedSprites, 0, "coin-faced mask should not load the costume anm2 as a normal render sprite")
end

local function test_coin_faced_mask_spends_coins_and_blocks_one_monster_hit()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 5, collectibles = { [env.items.CoinFacedMask] = 1 } })
    local enemy = env.newEnemy(130, 100)

    env.runNewRoom()
    local result = env.runDamage(player, 2, 0, enemy)

    assertEquals(result, false, "mask protection should cancel the original hit")
    assertEquals(player.coins, 0, "mask protection should spend five coins")
    assertEquals(#player.damageCalls, 0, "mask protection should fully block the monster hit")
end

local function test_coin_faced_mask_does_not_spend_on_non_monster_cost_damage()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 5, collectibles = { [env.items.CoinFacedMask] = 1 } })

    env.runNewRoom()
    local result = env.runDamage(player, 2, DamageFlag.DAMAGE_DEVIL, player)

    assertEquals(result, nil, "mask should not cancel non-monster cost damage")
    assertEquals(player.coins, 5, "mask should not spend coins on non-monster cost damage")
    assertTruthy(player.nullCostumes[env.costumes.active], "mask should remain active after ignored cost damage")
end

local function test_coin_faced_mask_spent_mask_removes_costumes()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 5, collectibles = { [env.items.CoinFacedMask] = 1 } })
    local enemy = env.newEnemy(130, 100)

    env.runNewRoom()
    env.runDamage(player, 2, 0, enemy)

    assertEquals(player.nullCostumes[env.costumes.active], nil, "spent mask should remove the active costume")
    assertEquals(player.nullCostumes[env.costumes.broken], nil, "spent mask should not leave a broken costume")
end

local function test_coin_faced_mask_breaks_without_coins_and_applies_room_luck_penalty()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 5, luck = 1, collectibles = { [env.items.CoinFacedMask] = 1 } })
    local enemy = env.newEnemy(130, 100)

    env.runNewRoom()
    player.coins = 0
    env.runDamage(player, 2, 0, enemy)
    env.runEvaluate(player, CacheFlag.CACHE_LUCK)

    assertEquals(player.Luck, -1, "broken mask should apply -2 luck for this room")
end

local function test_coin_faced_mask_breaks_to_broken_costume_until_next_room()
    local env = loadNeverbirth()
    local player = env.newPlayer({ coins = 5, collectibles = { [env.items.CoinFacedMask] = 1 } })
    local enemy = env.newEnemy(130, 100)

    env.runNewRoom()
    player.coins = 0
    env.runDamage(player, 2, 0, enemy)

    assertEquals(player.nullCostumes[env.costumes.active], nil, "broken mask should remove the active costume")
    assertTruthy(player.nullCostumes[env.costumes.broken], "broken mask costume should remain after the mask breaks")

    player.coins = 5
    env.runNewRoom()

    assertTruthy(player.nullCostumes[env.costumes.active], "new room with enough coins should restore the active mask costume")
    assertEquals(player.nullCostumes[env.costumes.broken], nil, "new room should clear the broken mask costume")
end

local function test_coin_faced_mask_costumes_are_independent_for_multiple_players()
    local env = loadNeverbirth()
    local playerA = env.newPlayer({ initSeed = 1, coins = 5, collectibles = { [env.items.CoinFacedMask] = 1 } })
    local playerB = env.newPlayer({ initSeed = 2, coins = 5, collectibles = { [env.items.CoinFacedMask] = 1 } })
    local enemy = env.newEnemy(130, 100)

    env.runNewRoom()
    playerB.coins = 0
    env.runDamage(playerB, 2, 0, enemy)

    assertTruthy(playerA.nullCostumes[env.costumes.active], "player A should keep the intact mask costume")
    assertEquals(playerA.nullCostumes[env.costumes.broken], nil, "player A should not receive player B's broken costume")
    assertEquals(playerB.nullCostumes[env.costumes.active], nil, "player B should lose the intact mask costume")
    assertTruthy(playerB.nullCostumes[env.costumes.broken], "player B should receive the broken costume")
end

local function anm2HasAnimation(text, animationName)
    return text:find('<Animation[^>]-Name="' .. animationName .. '"', 1) ~= nil
end

local function assertBlackTaisuiEffectResource(entities, spec)
    local basePath = "Effects/BlackTaisui/" .. spec.file
    local anm2Path = "resources/gfx/" .. basePath .. ".anm2"
    local pngPath = "resources/gfx/" .. basePath .. ".png"
    local spritePath = "gfx/" .. basePath .. ".png"
    local relativeEntityPath = basePath .. ".anm2"

    assertTruthy(entities:find('variant="' .. spec.variant .. '"', 1, true), spec.name .. " should reserve its entity variant")
    assertTruthy(entities:find('name="' .. spec.name .. '"', 1, true), spec.name .. " should be registered in entities2.xml")
    assertTruthy(entities:find('anm2path="' .. relativeEntityPath .. '"', 1, true), spec.name .. " should use an anm2 path relative to gfx/")
    assertTruthy(not entities:find('anm2path="gfx/' .. relativeEntityPath .. '"', 1, true), spec.name .. " should not double-prefix gfx in entities2.xml")

    local png = readPngInfo(pngPath)
    assertEquals(png.width, spec.width * spec.frames, spec.name .. " PNG width should match its frame strip")
    assertEquals(png.height, spec.height, spec.name .. " PNG height should match its frame height")
    assertEquals(png.colorType, 6, spec.name .. " PNG should be RGBA")

    local anm2 = readFile(anm2Path)
    assertTruthy(anm2:find('<Spritesheet Id="0" Path="' .. spec.file .. '.png"', 1, true), spec.name .. " anm2 should reference the effect PNG relative to its own folder")
    assertTruthy(not anm2:find('Path="gfx/Effects/BlackTaisui/', 1, true), spec.name .. " anm2 should not duplicate the gfx/Effects/BlackTaisui path inside the effect folder")
    assertTruthy(anm2:find('<Layer Name="body" Id="0" SpritesheetId="0"', 1, true), spec.name .. " anm2 should have a visible body layer")
    assertTruthy(anm2:find('<Animations DefaultAnimation="' .. spec.animation .. '"', 1, true), spec.name .. " anm2 should default to its playback animation")
    assertTruthy(anm2:find('<Animation Name="' .. spec.animation .. '" FrameNum="' .. spec.frames .. '" Loop="' .. spec.loop .. '"', 1, true), spec.name .. " animation should use the expected frame count and loop flag")
    assertTruthy(anm2:find('<LayerAnimation LayerId="0" Visible="true"', 1, true), spec.name .. " animation should contain a visible LayerAnimation")
    assertTruthy(anm2:find('AlphaTint="255"', 1, true), spec.name .. " frames should render at full alpha")
    assertTruthy(not anm2:find('AlphaTint="0"', 1, true), spec.name .. " should not contain invisible alpha-zero frames")
    assertTruthy(anm2:find('Visible="true"', 1, true), spec.name .. " should contain visible frames")

    local firstFrame = 'XPivot="' .. spec.pivot .. '" YPivot="' .. spec.pivot .. '" XCrop="0" YCrop="0" Width="' .. spec.width .. '" Height="' .. spec.height .. '"'
    local lastCrop = (spec.frames - 1) * spec.width
    local lastFrame = 'XPivot="' .. spec.pivot .. '" YPivot="' .. spec.pivot .. '" XCrop="' .. lastCrop .. '" YCrop="0" Width="' .. spec.width .. '" Height="' .. spec.height .. '"'
    assertTruthy(anm2:find(firstFrame, 1, true), spec.name .. " first frame crop should start at the left edge")
    assertTruthy(anm2:find(lastFrame, 1, true), spec.name .. " last frame crop should match the final strip frame")
end

local function test_black_taisui_effect_resources_exist()
    local entities = readFile("content/entities2.xml")
    assertTruthy(entities:find('<entities%s+anm2root="gfx/"', 1), "entities2.xml should resolve effect anm2 paths from gfx/")

    local effects = {
        { variant = 3007, name = "Black Taisui Spore", file = "BlackTaisuiSpore", animation = "Spore", frames = 6, width = 32, height = 32, pivot = 16, loop = "true" },
        { variant = 3008, name = "Black Taisui Pulse", file = "BlackTaisuiPulse", animation = "Pulse", frames = 8, width = 64, height = 64, pivot = 32, loop = "true" },
        { variant = 3009, name = "Black Taisui Curse Devour", file = "BlackTaisuiCurseDevour", animation = "Devour", frames = 10, width = 64, height = 64, pivot = 32, loop = "false" },
        { variant = 3010, name = "Black Taisui Reveal", file = "BlackTaisuiReveal", animation = "Reveal", frames = 8, width = 64, height = 64, pivot = 32, loop = "false" },
        { variant = 3011, name = "Black Taisui Fear Pulse", file = "BlackTaisuiFearPulse", animation = "FearPulse", frames = 10, width = 96, height = 96, pivot = 48, loop = "false" },
        { variant = 3012, name = "Black Taisui Death Deny", file = "BlackTaisuiDeathDeny", animation = "DeathDeny", frames = 16, width = 128, height = 128, pivot = 64, loop = "false" },
        { variant = 3013, name = "Black Taisui Mature Core", file = "BlackTaisuiMatureCore", animation = "MatureCore", frames = 8, width = 64, height = 64, pivot = 32, loop = "true" },
        { variant = 3014, name = "Black Taisui Hallucination Eat", file = "BlackTaisuiHallucinationEat", animation = "HallucinationEat", frames = 12, width = 96, height = 96, pivot = 48, loop = "false" },
    }

    for _, spec in ipairs(effects) do
        assertBlackTaisuiEffectResource(entities, spec)
    end
end

local function test_coin_faced_mask_costume_resources_exist()
    local costumes2 = readFile("content/costumes2.xml")
    local activeAnm2 = readFile("resources/gfx/characters/costume_coin_faced_mask.anm2")
    local brokenAnm2 = readFile("resources/gfx/characters/costume_coin_faced_mask_broken.anm2")

    assertTruthy(costumes2:find('<costumes%s+anm2root="gfx/characters/"', 1), "costumes2.xml should register character costumes from gfx/characters")
    assertTruthy(costumes2:find('anm2path="costume_coin_faced_mask%.anm2"', 1), "stable active mask costume should be registered in costumes2.xml")
    assertTruthy(costumes2:find('anm2path="costume_coin_faced_mask_broken%.anm2"', 1), "stable broken mask costume should be registered in costumes2.xml")
    assertTruthy(costumes2:find('anm2path="costume_coin_faced_mask%.anm2"%s+type="none"', 1), "active mask costume should be registered as a null costume for AddNullCostume")
    assertTruthy(costumes2:find('anm2path="costume_coin_faced_mask_broken%.anm2"%s+type="none"', 1), "broken mask costume should be registered as a null costume for AddNullCostume")
    assertTruthy(not costumes2:find("neverbirth_coin_faced_mask", 1, true), "oversized 64px mask art must not be registered as a live costume")
    assertTruthy(activeAnm2:find('costume_coin_faced_mask%.png', 1), "active mask anm2 should reference the stable costume PNG")
    assertTruthy(activeAnm2:find('Layer Name="head2"', 1), "active mask anm2 should use an overlay head layer")
    assertTruthy(anm2HasAnimation(activeAnm2, "HeadDown"), "active mask should define HeadDown")
    assertTruthy(anm2HasAnimation(activeAnm2, "HeadRight"), "active mask should define HeadRight")
    assertTruthy(anm2HasAnimation(activeAnm2, "HeadUp"), "active mask should define HeadUp")
    assertTruthy(anm2HasAnimation(activeAnm2, "HeadLeft"), "active mask should define HeadLeft")
    assertTruthy(activeAnm2:find('Width="32"', 1), "stable active mask should use 32px head crops")
    assertTruthy(activeAnm2:find('Height="32"', 1), "stable active mask should use 32px head crops")
    assertTruthy(activeAnm2:find('XPivot="16"', 1), "stable active mask should use the Isaac head pivot")
    assertTruthy(brokenAnm2:find('costume_coin_faced_mask_broken%.png', 1), "broken mask anm2 should reference the stable broken mask PNG")
    assertTruthy(brokenAnm2:find('Layer Name="head2"', 1), "broken mask anm2 should use an overlay head layer")

    local activePng = readPngInfo("resources/gfx/characters/costumes/costume_coin_faced_mask.png")
    local brokenPng = readPngInfo("resources/gfx/characters/costumes/costume_coin_faced_mask_broken.png")
    assertEquals(activePng.width, 256, "active mask PNG should be an 8-frame 32px costume strip")
    assertEquals(activePng.height, 32, "active mask PNG should use 32px head frames")
    assertEquals(activePng.colorType, 6, "active mask PNG should have an alpha channel")
    assertEquals(brokenPng.width, 256, "broken mask PNG should be an 8-frame 32px costume strip")
    assertEquals(brokenPng.height, 32, "broken mask PNG should use 32px head frames")
    assertEquals(brokenPng.colorType, 6, "broken mask PNG should have an alpha channel")
end

local function setBlackTaisuiParasite(env, player, value)
    assertTruthy(env.mod.SetBlackTaisuiParasiteValue, "Black Taisui should expose a testable parasite setter")
    env.mod:SetBlackTaisuiParasiteValue(player, value)
end

local function getBlackTaisuiParasite(env, player)
    assertTruthy(env.mod.GetBlackTaisuiParasiteValue, "Black Taisui should expose a testable parasite getter")
    return env.mod:GetBlackTaisuiParasiteValue(player)
end

local function isMeatLumpSpawn(env, spawn)
    return (spawn.entityType or spawn.Type) == EntityType.ENTITY_PICKUP
        and (spawn.variant or spawn.Variant) == PickupVariant.PICKUP_COLLECTIBLE
        and (spawn.subtype or spawn.SubType) == env.items.MeatLump
end

local function test_black_taisui_stage_one_penalties_stack_and_respect_floors()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 4, moveSpeed = 1, luck = 0, collectibles = { [env.items.BlackTaisui] = 1 } })

    setBlackTaisuiParasite(env, player, 0)
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    env.runEvaluate(player, CacheFlag.CACHE_SPEED)
    env.runEvaluate(player, CacheFlag.CACHE_LUCK)

    assertEquals(player.Damage, 3.5, "stage one should apply -0.5 damage per Black Taisui")
    assertEquals(player.MoveSpeed, 0.8, "stage one should apply -0.2 speed per Black Taisui")
    assertEquals(player.Luck, -3, "stage one should apply -3 luck per Black Taisui")

    local twoCopies = env.newPlayer({ damage = 4, moveSpeed = 1, luck = 0, collectibles = { [env.items.BlackTaisui] = 2 } })
    setBlackTaisuiParasite(env, twoCopies, 0)
    env.runEvaluate(twoCopies, CacheFlag.CACHE_DAMAGE)
    env.runEvaluate(twoCopies, CacheFlag.CACHE_SPEED)
    env.runEvaluate(twoCopies, CacheFlag.CACHE_LUCK)
    assertEquals(twoCopies.Damage, 3, "stage one damage penalty should stack with copies")
    assertEquals(twoCopies.MoveSpeed, 0.6, "stage one speed penalty should stack with copies")
    assertEquals(twoCopies.Luck, -6, "stage one luck penalty should stack with copies")

    local floored = env.newPlayer({ damage = 1.2, moveSpeed = 0.6, collectibles = { [env.items.BlackTaisui] = 2 } })
    setBlackTaisuiParasite(env, floored, 0)
    env.runEvaluate(floored, CacheFlag.CACHE_DAMAGE)
    env.runEvaluate(floored, CacheFlag.CACHE_SPEED)
    assertEquals(floored.Damage, 1, "Black Taisui should not reduce damage below 1")
    assertEquals(floored.MoveSpeed, 0.5, "Black Taisui should not reduce speed below 0.5")

    local alreadyLow = env.newPlayer({ damage = 0.8, moveSpeed = 0.4, collectibles = { [env.items.BlackTaisui] = 2 } })
    setBlackTaisuiParasite(env, alreadyLow, 0)
    env.runEvaluate(alreadyLow, CacheFlag.CACHE_DAMAGE)
    env.runEvaluate(alreadyLow, CacheFlag.CACHE_SPEED)
    assertEquals(alreadyLow.Damage, 0.8, "Black Taisui should not raise already-low damage")
    assertEquals(alreadyLow.MoveSpeed, 0.4, "Black Taisui should not raise already-low speed")
end

local function test_black_taisui_stage_two_softens_penalty_and_filters_curses()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 4, moveSpeed = 1, luck = 0, collectibles = { [env.items.BlackTaisui] = 2 } })
    local enemy = env.newEnemy(140, 100)

    setBlackTaisuiParasite(env, player, 8)
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    env.runEvaluate(player, CacheFlag.CACHE_SPEED)
    env.runEvaluate(player, CacheFlag.CACHE_LUCK)

    assertEquals(player.Damage, 3.5, "stage two should cap all Black Taisui damage penalty at -0.5")
    assertEquals(player.MoveSpeed, 1, "stage two should no longer penalize speed")
    assertEquals(player.Luck, 0, "stage two should no longer penalize luck")

    local curses = LevelCurse.CURSE_OF_BLIND | LevelCurse.CURSE_OF_LOST | LevelCurse.CURSE_OF_UNKNOWN
    assertEquals(env.runCurseEval(curses), 0, "stage two should suppress Blind/Lost/Unknown curse displays")
    assertTruthy(enemy.feared > 0, "suppressing curses should trigger black spore fear feedback once")
end

local function test_black_taisui_spawns_effects_for_growth_curse_and_fear()
    local env = loadNeverbirth()
    local player = env.newPlayer({ collectibles = { [env.items.BlackTaisui] = 1 } })

    setBlackTaisuiParasite(env, player, 8)
    assertGreaterThan(countEffectSpawns(env, 3008), 0, "parasite growth should spawn Black Taisui Pulse")
    assertGreaterThan(countEffectSpawns(env, 3011), 0, "strong spore triggers should spawn Black Taisui Fear Pulse")

    env.runCurseEval(LevelCurse.CURSE_OF_BLIND)
    assertGreaterThan(countEffectSpawns(env, 3007), 0, "ordinary spore triggers should spawn Black Taisui Spore")
    assertGreaterThan(countEffectSpawns(env, 3009), 0, "curse suppression should spawn Black Taisui Curse Devour")
end

local function test_black_taisui_stage_two_removes_existing_level_curses_after_activation()
    local env = loadNeverbirth({
        levelCurses = LevelCurse.CURSE_OF_BLIND | LevelCurse.CURSE_OF_LOST | LevelCurse.CURSE_OF_UNKNOWN,
    })
    local player = env.newPlayer({ collectibles = { [env.items.BlackTaisui] = 1 } })

    setBlackTaisuiParasite(env, player, 8)
    env.runPostUpdate()

    assertEquals(env.getLevelCurses(), 0, "stage two should actively remove existing Blind/Lost/Unknown curses from the current level")
end

local function test_black_taisui_stage_two_removes_wavy_cap_effects_and_keeps_positive_stats()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        maxFireDelay = 10,
        tearRange = 260,
        collectibles = {
            [env.items.BlackTaisui] = 1,
            [582] = 1,
        },
    })

    setBlackTaisuiParasite(env, player, 8)
    player.effects.counts[582] = 2
    env.runPostUpdate()

    assertEquals(player.effects.counts[582], 0, "stage two should remove active Wavy Cap temporary effects that drive distortion")
    assertEquals(player.effects.removeCalls[#player.effects.removeCalls].itemId, 582, "stage two should remove Wavy Cap effect specifically")

    env.runEvaluate(player, CacheFlag.CACHE_FIREDELAY)
    env.runEvaluate(player, CacheFlag.CACHE_RANGE)
    assertEquals(player.MaxFireDelay, 8.5, "stage two should compensate Wavy Cap tears benefit after suppressing its side effects")
    assertEquals(player.TearRange, 300, "stage two should compensate Wavy Cap range benefit after suppressing its side effects")
end

local function test_black_taisui_stage_two_replaces_wavy_cap_with_cleansed_cap()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        collectibles = {
            [env.items.BlackTaisui] = 1,
            [CollectibleType.COLLECTIBLE_WAVY_CAP] = 1,
        },
    })

    setBlackTaisuiParasite(env, player, 8)
    env.runPostUpdate()

    assertEquals(player.collectibles[CollectibleType.COLLECTIBLE_WAVY_CAP], 0, "stage two should remove the original Wavy Cap before it can keep distorting the room")
    assertEquals(player.collectibles[env.items.CleansedWavyCap], 1, "stage two should grant the controlled Wavy Cap replacement")
    assertEquals(player.removedCollectibles[#player.removedCollectibles], CollectibleType.COLLECTIBLE_WAVY_CAP, "replacement should explicitly remove Wavy Cap")
    assertEquals(player.addedCollectibles[#player.addedCollectibles].itemId, env.items.CleansedWavyCap, "replacement should explicitly add Cleansed Wavy Cap")
    assertGreaterThan(countEffectSpawns(env, 3014), 0, "replacing Wavy Cap should spawn Black Taisui Hallucination Eat")
end

local function test_cleansed_wavy_cap_applies_controlled_stats()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        moveSpeed = 1,
        maxFireDelay = 10,
        collectibles = {
            [env.items.BlackTaisui] = 1,
            [env.items.CleansedWavyCap] = 1,
        },
    })

    setBlackTaisuiParasite(env, player, 8)
    env.runUse(env.items.CleansedWavyCap, player)
    env.runEvaluate(player, CacheFlag.CACHE_SPEED)
    env.runEvaluate(player, CacheFlag.CACHE_FIREDELAY)

    assertEquals(player.MoveSpeed, 0.97, "Cleansed Wavy Cap use should apply -0.03 speed")
    assertEquals(player.MaxFireDelay, 9.25, "Cleansed Wavy Cap use should apply +0.75 tears correction")
end

local function test_cleansed_wavy_cap_uses_wavy_cap_timed_charge_curve()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        collectibles = {
            [env.items.BlackTaisui] = 1,
            [env.items.CleansedWavyCap] = 1,
        },
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = env.items.CleansedWavyCap },
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 900 },
    })

    setBlackTaisuiParasite(env, player, 8)
    env.runUse(env.items.CleansedWavyCap, player)
    env.runPostUpdate()

    assertEquals(player.activeCharges[ActiveSlot.SLOT_PRIMARY], 800, "first Cleansed Wavy Cap use should leave a short timed recharge instead of fully emptying")
end

local function test_cleansed_wavy_cap_room_transition_and_clear_decay()
    local env = loadNeverbirth({ roomClear = false, roomIndex = 1 })
    local player = env.newPlayer({
        moveSpeed = 1,
        maxFireDelay = 10,
        collectibles = {
            [env.items.BlackTaisui] = 1,
            [env.items.CleansedWavyCap] = 1,
        },
    })

    setBlackTaisuiParasite(env, player, 8)
    env.runUse(env.items.CleansedWavyCap, player)
    env.setRoomIndex(2)
    env.runNewRoom()
    env.runEvaluate(player, CacheFlag.CACHE_SPEED)
    env.runEvaluate(player, CacheFlag.CACHE_FIREDELAY)

    assertEquals(player.MoveSpeed, 0.94, "leaving the room should convert -0.03 speed into -0.06 lingering speed")
    assertEquals(player.MaxFireDelay, 9.7, "leaving the room should convert +0.75 tears into +0.30 lingering tears")

    env.setRoomClear(true)
    env.runPostUpdate()
    player.MoveSpeed = 1
    player.MaxFireDelay = 10
    env.runEvaluate(player, CacheFlag.CACHE_SPEED)
    env.runEvaluate(player, CacheFlag.CACHE_FIREDELAY)

    assertEquals(player.MoveSpeed, 1, "clearing a room should remove one lingering Wavy Cap speed stack")
    assertEquals(player.MaxFireDelay, 10, "clearing a room should remove one lingering Wavy Cap tears stack")
end

local function test_black_taisui_stage_two_refreshes_hidden_collectible_pedestals()
    local env = loadNeverbirth()
    local player = env.newPlayer({ collectibles = { [env.items.BlackTaisui] = 1 } })
    local pickup = env.newCollectiblePickup(302, { hidden = true, optionsPickupIndex = 7, price = 15, shopItemId = 2 })

    setBlackTaisuiParasite(env, player, 8)
    env.runPostUpdate()

    assertEquals(pickup.hidden, false, "stage two should refresh hidden collectible pedestal visuals")
    assertEquals(pickup.sprite.replacedSpritesheets[#pickup.sprite.replacedSpritesheets].path, "gfx/items/collectibles/mock_302.png", "stage two should replace question-mark collectible spritesheet with the real item gfx")
    assertEquals(pickup.sprite.loadGraphicsCalls > 0, true, "stage two should reload collectible graphics after replacing the spritesheet")
    assertEquals(#pickup.sprite.setFrames, 0, "stage two reveal should not freeze the pedestal animation on frame 0")
    assertEquals(#pickup.sprite.playCalls, 0, "stage two reveal should not restart pedestal animation and risk restoring the question mark")
    assertEquals(pickup.SubType, 302, "stage two reveal should keep the real collectible subtype")
    assertEquals(pickup.OptionsPickupIndex, 7, "stage two reveal should keep option pickup index")
    assertEquals(pickup.Price, 15, "stage two reveal should keep shop price")
    assertEquals(pickup.ShopItemId, 2, "stage two reveal should keep shop item id")
    assertEquals(#pickup.morphCalls, 0, "stage two reveal should not morph collectible pedestals because Morph retriggers pickup init")
    assertEquals(pickup.updateAppearanceCalls, 0, "stage two reveal should not call UpdateAppearance because it can retrigger question-mark refresh paths")
    assertGreaterThan(countEffectSpawns(env, 3010), 0, "revealing a hidden collectible should spawn Black Taisui Reveal")
end

local function test_black_taisui_stage_two_refreshes_shop_hidden_collectible_sprite_without_breaking_shop_data()
    local env = loadNeverbirth()
    local player = env.newPlayer({ collectibles = { [env.items.BlackTaisui] = 1 } })
    local pickup = env.newCollectiblePickup(455, { hidden = true, animation = "ShopIdle", price = 30, shopItemId = 4 })

    setBlackTaisuiParasite(env, player, 8)
    env.runPostUpdate()

    assertEquals(pickup.sprite.replacedSpritesheets[#pickup.sprite.replacedSpritesheets].path, "gfx/items/collectibles/mock_455.png", "stage two should reveal shop collectible sprite using real item gfx")
    assertEquals(#pickup.sprite.setFrames, 0, "stage two shop reveal should not freeze the shop pedestal animation on frame 0")
    assertEquals(#pickup.sprite.playCalls, 0, "stage two shop reveal should not restart shop pedestal animation and risk restoring the question mark")
    assertEquals(pickup.Price, 30, "stage two shop reveal should keep price")
    assertEquals(pickup.ShopItemId, 4, "stage two shop reveal should keep shop item id")
    assertEquals(#pickup.morphCalls, 0, "stage two shop reveal should not morph shop pedestals")
end

local function test_black_taisui_stage_two_reveals_rerolled_collectible_without_room_reload()
    local env = loadNeverbirth()
    local player = env.newPlayer({ collectibles = { [env.items.BlackTaisui] = 1 } })
    local pickup = env.newCollectiblePickup(302, { hidden = true })

    setBlackTaisuiParasite(env, player, 8)
    env.runPostUpdate()
    assertEquals(pickup.sprite.replacedSpritesheets[#pickup.sprite.replacedSpritesheets].path, "gfx/items/collectibles/mock_302.png", "stage two should reveal the first item")

    pickup.SubType = 455
    for _ = 1, 10 do
        env.runPostUpdate()
    end

    assertEquals(pickup.sprite.replacedSpritesheets[#pickup.sprite.replacedSpritesheets].path, "gfx/items/collectibles/mock_455.png", "stage two should reveal rerolled item without leaving the room")
    assertEquals(#pickup.morphCalls, 0, "reroll reveal should still avoid Morph")
    assertEquals(pickup.updateAppearanceCalls, 0, "reroll reveal should still avoid UpdateAppearance")
end

local function test_black_taisui_stage_two_reapplies_sprite_if_game_restores_question_mark()
    local env = loadNeverbirth()
    local player = env.newPlayer({ collectibles = { [env.items.BlackTaisui] = 1 } })
    local pickup = env.newCollectiblePickup(302, { hidden = true })

    setBlackTaisuiParasite(env, player, 8)
    env.runPostUpdate()
    assertTruthy(#pickup.sprite.replacedSpritesheets > 0, "stage two should reveal the pedestal")

    pickup.hidden = true
    pickup.sprite.replacedSpritesheets = {}
    for _ = 1, 10 do
        env.runPostUpdate()
    end

    assertEquals(pickup.hidden, false, "stage two should re-reveal when the game restores the question mark visual")
    assertEquals(pickup.sprite.replacedSpritesheets[#pickup.sprite.replacedSpritesheets].path, "gfx/items/collectibles/mock_302.png", "stage two should reapply the real item gfx even when subtype did not change")
end

local function test_black_taisui_stage_two_does_not_guess_unknown_collectibles()
    local env = loadNeverbirth()
    local player = env.newPlayer({ collectibles = { [env.items.BlackTaisui] = 1 } })
    local pickup = env.newCollectiblePickup(0, { hidden = true })

    setBlackTaisuiParasite(env, player, 8)
    env.runPostUpdate()

    assertEquals(#pickup.morphCalls, 0, "stage two reveal should not morph collectible pedestals without a real subtype")
    assertEquals(pickup.hidden, true, "stage two reveal should leave truly unknown collectible pedestals alone")
end

local function test_black_taisui_stage_three_damage_and_spawns_meat_lump_once()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 4, hearts = 1, maxHearts = 2, collectibles = { [env.items.BlackTaisui] = 2 } })

    setBlackTaisuiParasite(env, player, 16)
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertEquals(player.Damage, 7, "stage three should grant +1.5 fixed damage per Black Taisui")

    env.runPostUpdate()
    local meatLumps = 0
    for _, spawn in ipairs(env.spawns) do
        if isMeatLumpSpawn(env, spawn) then
            meatLumps = meatLumps + 1
        end
    end
    assertEquals(meatLumps, 1, "stage three should spawn one Meat Lump reward")

    env.runPostUpdate()
    env.runNewLevel()
    env.runPostUpdate()
    meatLumps = 0
    for _, spawn in ipairs(env.spawns) do
        if isMeatLumpSpawn(env, spawn) then
            meatLumps = meatLumps + 1
        end
    end
    assertEquals(meatLumps, 1, "stage three Meat Lump reward should be once per player per run")

    player.hearts = 1
    local hit = env.runDamage(player, 2, DamageFlag.DAMAGE_RED_HEARTS)
    assertEquals(hit, false, "Black Taisui stage three should block the first lethal damage each floor")
    assertEquals(player.hearts, 1, "Black Taisui death save should leave half a red heart")
    assertGreaterThan(countEffectSpawns(env, 3012), 0, "death save should spawn Black Taisui Death Deny")
    assertGreaterThan(countEffectSpawns(env, 3013), 0, "stage three should periodically show Black Taisui Mature Core")

    local deathDeny = effectSpawns(env, 3012)[1]
    deathDeny.sprite.IsFinished = function() return true end
    env.runEffectUpdate(deathDeny)
    assertTruthy(deathDeny.removed, "finished non-loop Black Taisui effect should be removed")

    player.hearts = 1
    hit = env.runDamage(player, 2, DamageFlag.DAMAGE_RED_HEARTS)
    assertEquals(hit, nil, "Black Taisui death save should only trigger once per floor")

    env.runNewLevel()
    player.hearts = 1
    hit = env.runDamage(player, 2, DamageFlag.DAMAGE_RED_HEARTS)
    assertEquals(hit, false, "Black Taisui death save should refresh on the next floor")
end

local function test_black_taisui_stage_three_spawns_meat_lump_when_crossing_threshold()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 2, maxHearts = 4, collectibles = { [env.items.BlackTaisui] = 1 } })

    setBlackTaisuiParasite(env, player, 15)
    env.runPostUpdate()
    for _, spawn in ipairs(env.spawns) do
        assertTruthy(not isMeatLumpSpawn(env, spawn), "stage two should not spawn Meat Lump")
    end

    env.runDamage(player, 1, DamageFlag.DAMAGE_RED_HEARTS)
    env.runPostUpdate()
    local found = false
    for _, spawn in ipairs(env.spawns) do
        if isMeatLumpSpawn(env, spawn) then
            found = true
        end
    end
    assertTruthy(found, "crossing into stage three should spawn Meat Lump")
end

local function test_meat_lump_grants_custom_life_without_visible_c11_on_pickup()
    local env = loadNeverbirth()
    local player = env.newPlayer({})

    env.runPostAddCollectible(env.items.MeatLump, player)

    assertEquals(#(player.addedCollectibles or {}), 0, "Meat Lump should not add visible c11 to the item list")
    assertEquals(#player.removedCollectibles, 0, "Meat Lump should not add and then remove visible c11")
    assertEquals(player.effects.counts[CollectibleType.COLLECTIBLE_1UP] or 0, 1, "Meat Lump should add a hidden c11 backup effect")

    player.hearts = 1
    local result = env.runDamage(player, 2, 0)
    assertEquals(result, false, "Meat Lump custom life should block lethal damage")
    assertEquals(player.hearts, 1, "Meat Lump custom life should leave the player at half a red heart")
    assertEquals(player.effects.counts[CollectibleType.COLLECTIBLE_1UP] or 0, 0, "custom Meat Lump save should consume the hidden c11 backup effect")
end

local function test_meat_lump_grants_custom_life_from_held_copy_even_if_pickup_callback_missed()
    local env = loadNeverbirth()
    local player = env.newPlayer({ collectibles = { [env.items.MeatLump] = 1 } })

    env.runPostUpdate()

    assertEquals(player.collectibles[CollectibleType.COLLECTIBLE_1UP] or 0, 0, "held-copy tracking should not leave c11 in the visible item list")
    assertEquals(#(player.addedCollectibles or {}), 0, "held Meat Lump should not call AddCollectible for visible c11")
    assertEquals(player.effects.counts[CollectibleType.COLLECTIBLE_1UP] or 0, 1, "held Meat Lump should grant a hidden c11 backup effect")

    env.runPostUpdate()
    player.hearts = 1
    local result = env.runDamage(player, 2, 0)
    assertEquals(result, false, "held Meat Lump should grant one custom revive charge")

    player.hearts = 1
    result = env.runDamage(player, 2, 0)
    assertEquals(result, nil, "custom revive charge should not repeat without gaining another Meat Lump")

    player.collectibles[env.items.MeatLump] = 2
    env.runPostUpdate()
    player.hearts = 1
    result = env.runDamage(player, 2, 0)
    assertEquals(result, false, "a second Meat Lump copy should grant one more custom revive charge")
end

local function test_black_taisui_stage_three_renders_custom_life_marker_until_used()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 2, maxHearts = 4, collectibles = { [env.items.BlackTaisui] = 1 } })

    setBlackTaisuiParasite(env, player, 16)
    env.runPostUpdate()
    env.runPostRender()

    local sawWard = false
    for _, rendered in ipairs(env.renderTexts) do
        if rendered.text == "WARD" then
            sawWard = true
        end
    end
    assertTruthy(sawWard, "stage three should render a Black Taisui ward marker")
    assertEquals(player.effects.counts[CollectibleType.COLLECTIBLE_1UP] or 0, 0, "Black Taisui ward should not fake a c11 temp effect")

    player.hearts = 1
    env.runDamage(player, 2, DamageFlag.DAMAGE_RED_HEARTS)
    assertGreaterThan(#env.hudTexts, 0, "Black Taisui should show feedback when blocking lethal damage")
    assertTruthy(player.lastColor, "Black Taisui should flash the player when blocking lethal damage")
    for index = #env.renderTexts, 1, -1 do
        env.renderTexts[index] = nil
    end
    env.runPostRender()

    sawWard = false
    local sawFeedback = false
    for _, rendered in ipairs(env.renderTexts) do
        if rendered.text == "WARD" then
            sawWard = true
        elseif rendered.text == "TAISUI BLOCK" then
            sawFeedback = true
        end
    end
    assertTruthy(not sawWard, "Black Taisui ward marker should disappear after the floor save is used")
    assertTruthy(sawFeedback, "Black Taisui should briefly render a block feedback label")
end

local function test_black_taisui_stage_three_does_not_block_cost_damage()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 1, maxHearts = 2, collectibles = { [env.items.BlackTaisui] = 1 } })

    setBlackTaisuiParasite(env, player, 16)

    local result = env.runDamage(player, 2, DamageFlag.DAMAGE_IV_BAG)
    assertEquals(result, nil, "Black Taisui should not block IV Bag style cost damage")

    result = env.runDamage(player, 2, DamageFlag.DAMAGE_DEVIL)
    assertEquals(result, nil, "Black Taisui should not block devil deal style cost damage")

    result = env.runDamage(player, 2, DamageFlag.DAMAGE_CURSED_DOOR)
    assertEquals(result, nil, "Black Taisui should not block curse door style cost damage")
end

local function test_black_taisui_parasite_value_grows_from_red_healing_container_and_damage()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 2, maxHearts = 4, soulHearts = 0, collectibles = { [env.items.BlackTaisui] = 1 } })

    env.runPostUpdate()
    player.hearts = 4
    env.runPostUpdate()
    assertEquals(getBlackTaisuiParasite(env, player), 2, "actual red heart healing should add one parasite per half heart")

    player.maxHearts = 6
    env.runPostUpdate()
    assertEquals(getBlackTaisuiParasite(env, player), 6, "gaining one red heart container should add four parasite")

    env.runDamage(player, 1, DamageFlag.DAMAGE_RED_HEARTS)
    assertEquals(getBlackTaisuiParasite(env, player), 8, "red heart damage should add two parasite per half heart")
end

local function test_black_taisui_no_red_container_uses_soul_black_at_half_efficiency()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 0, maxHearts = 0, soulHearts = 0, blackHearts = 0, collectibles = { [env.items.BlackTaisui] = 1 } })

    env.runPostUpdate()
    player.soulHearts = 2
    env.runPostUpdate()
    assertEquals(getBlackTaisuiParasite(env, player), 1, "soul healing without red containers should feed at half efficiency")

    env.runDamage(player, 1, 0)
    assertEquals(getBlackTaisuiParasite(env, player), 2, "soul or black damage without red containers should feed at half efficiency")
end

local function test_black_taisui_multiple_players_are_independent()
    local env = loadNeverbirth()
    local playerA = env.newPlayer({ initSeed = 1, collectibles = { [env.items.BlackTaisui] = 1 } })
    local playerB = env.newPlayer({ initSeed = 2, collectibles = { [env.items.BlackTaisui] = 1 } })

    setBlackTaisuiParasite(env, playerA, 16)
    setBlackTaisuiParasite(env, playerB, 8)

    assertEquals(getBlackTaisuiParasite(env, playerA), 16, "player A should keep separate parasite value")
    assertEquals(getBlackTaisuiParasite(env, playerB), 8, "player B should keep separate parasite value")
end

test_xml_registers_folk_horror_items_and_pools()
test_purified_mushroom_icon_resource_is_collectible_ready()
test_coin_sewn_sword_spends_six_coins_for_six_slashes_and_empowered_slash()
test_coin_sewn_sword_spreads_six_qi_visibly()
test_coin_sewn_sword_holds_without_spending_until_direction_input()
test_coin_sewn_sword_second_use_cancels_holding_without_spending()
test_coin_sewn_sword_spends_available_coins_only()
test_coin_sewn_sword_no_coins_backlashes_and_fires_blood_qi()
test_coin_sword_qi_effect_hits_enemy_and_normal_qi_disappears()
test_coin_sword_qi_hitbox_matches_visual_center_but_not_far_outside()
test_blood_coin_sword_qi_damages_enemy_in_its_hitbox()
test_coin_sword_debug_hitbox_renders_only_when_enabled()
test_coin_sword_qi_fallback_effect_still_updates_when_variant_lookup_fails()
test_coin_sword_qi_uses_player_shooting_direction_and_entity_rotation()
test_coin_sword_qi_does_not_write_effect_rotation()
test_coin_sewn_sword_removes_tears_while_held_and_release_shot_only()
test_coin_sewn_sword_cancel_allows_tears_again()
test_empowered_coin_sword_qi_pierces_multiple_enemies()
test_coin_sword_qi_inherits_spoon_bender_homing()
test_coin_sword_qi_without_spoon_bender_does_not_home()
test_lost_contact_coin_sword_qi_blocks_projectiles()
test_empowered_lost_contact_coin_sword_qi_blocks_without_disappearing()
test_lost_contact_coin_sword_qi_does_not_remove_player_tears_or_pickups()
test_coin_sword_qi_can_home_and_block_projectiles_together()
test_coin_sword_qi_expires()
test_coin_faced_mask_enters_room_with_mask_and_confuses_enemies()
test_coin_faced_mask_active_costume_appears_when_room_mask_is_active()
test_coin_faced_mask_active_costume_appears_when_picked_up_mid_room()
test_coin_faced_mask_does_not_fake_an_overlay_when_null_costume_is_unavailable()
test_coin_faced_mask_spends_coins_and_blocks_one_monster_hit()
test_coin_faced_mask_does_not_spend_on_non_monster_cost_damage()
test_coin_faced_mask_spent_mask_removes_costumes()
test_coin_faced_mask_breaks_without_coins_and_applies_room_luck_penalty()
test_coin_faced_mask_breaks_to_broken_costume_until_next_room()
test_coin_faced_mask_costumes_are_independent_for_multiple_players()
test_coin_faced_mask_costume_resources_exist()
test_black_taisui_effect_resources_exist()
test_black_taisui_stage_one_penalties_stack_and_respect_floors()
test_black_taisui_stage_two_softens_penalty_and_filters_curses()
test_black_taisui_spawns_effects_for_growth_curse_and_fear()
test_black_taisui_stage_two_removes_existing_level_curses_after_activation()
test_black_taisui_stage_two_removes_wavy_cap_effects_and_keeps_positive_stats()
test_black_taisui_stage_two_replaces_wavy_cap_with_cleansed_cap()
test_cleansed_wavy_cap_applies_controlled_stats()
test_cleansed_wavy_cap_uses_wavy_cap_timed_charge_curve()
test_cleansed_wavy_cap_room_transition_and_clear_decay()
test_black_taisui_stage_two_refreshes_hidden_collectible_pedestals()
test_black_taisui_stage_two_refreshes_shop_hidden_collectible_sprite_without_breaking_shop_data()
test_black_taisui_stage_two_reveals_rerolled_collectible_without_room_reload()
test_black_taisui_stage_two_reapplies_sprite_if_game_restores_question_mark()
test_black_taisui_stage_two_does_not_guess_unknown_collectibles()
test_black_taisui_stage_three_damage_and_spawns_meat_lump_once()
test_black_taisui_stage_three_spawns_meat_lump_when_crossing_threshold()
test_meat_lump_grants_custom_life_without_visible_c11_on_pickup()
test_meat_lump_grants_custom_life_from_held_copy_even_if_pickup_callback_missed()
test_black_taisui_stage_three_renders_custom_life_marker_until_used()
test_black_taisui_stage_three_does_not_block_cost_damage()
test_black_taisui_parasite_value_grows_from_red_healing_container_and_damage()
test_black_taisui_no_red_container_uses_soul_black_at_half_efficiency()
test_black_taisui_multiple_players_are_independent()

print("folk horror item behavior tests passed")
