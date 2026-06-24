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

local function loadNeverbirth()
    local callbacks = {}
    local itemIds = {
        EssentialBalm = 733,
        Wuhu = 734,
        Aphrodisiac = 735,
        Musicbox = 736,
        Angelbox = 737,
        Devilbox = 738,
        ds4 = 739,
        UncutCord = 740,
    }
    local players = {}
    local roomEntities = {}
    local renderedTexts = {}
    local findPlayersByType = true
    local currentRoomIndex = 1
    local damageCallbackRunner = nil

    package.loaded.json = nil
    package.preload.json = function()
        return {
            encode = function()
                return "{}"
            end,
            decode = function()
                return {}
            end,
        }
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
    }

    CollectibleType = {
        COLLECTIBLE_NULL = 0,
        COLLECTIBLE_PLAN_C = 475,
    }
    CacheFlag = {
        CACHE_DAMAGE = 1,
        CACHE_SHOTSPEED = 2,
        CACHE_TEARCOLOR = 4,
        CACHE_SPEED = 8,
        CACHE_FIREDELAY = 16,
        CACHE_TEARFLAG = 32,
    }
    DamageFlag = {
        DAMAGE_RED_HEARTS = 1,
        DAMAGE_NOKILL = 2,
        DAMAGE_INVINCIBLE = 4,
    }
    EntityFlag = { FLAG_CHARM = 1 }
    TearFlags = { TEAR_HOMING = 1 }
    EntityType = { ENTITY_PLAYER = 1, ENTITY_PICKUP = 5 }
    PickupVariant = { PICKUP_HEART = 10, PICKUP_COLLECTIBLE = 100 }
    HeartSubType = { HEART_SOUL = 3, HEART_BLACK = 6 }
    ItemPoolType = { POOL_DEVIL = 3, POOL_ANGEL = 4 }
    RoomType = { ROOM_DEFAULT = 1, ROOM_DEVIL = 14, ROOM_ANGEL = 15 }
    GameStateFlag = {
        STATE_DEVILROOM_SPAWNED = 5,
        STATE_DEVILROOM_VISITED = 6,
    }
    GridRooms = { ROOM_DEVIL_IDX = -1 }
    ActiveSlot = {
        SLOT_PRIMARY = 0,
        SLOT_SECONDARY = 1,
        SLOT_POCKET = 2,
        SLOT_POCKET2 = 3,
    }

    function MusicManager()
        return {
            GetCurrentMusicID = function()
                return 1
            end,
            Play = function() end,
            Fadeout = function() end,
        }
    end

    local room = {
        clear = false,
        spawnSeed = 100,
    }
    function room:IsClear()
        return self.clear
    end
    function room:GetSpawnSeed()
        return self.spawnSeed
    end
    function room:GetType()
        return RoomType.ROOM_DEFAULT
    end

    local level = {
        angelRoomChanceDelta = 0,
        initializeCalls = {},
    }
    function level:GetCurrentRoomIndex()
        return currentRoomIndex
    end
    function level:AddAngelRoomChance(delta)
        self.angelRoomChanceDelta = self.angelRoomChanceDelta + delta
    end
    function level:InitializeDevilAngelRoom(forceAngel, forceDevil)
        self.initializeCalls[#self.initializeCalls + 1] = {
            forceAngel = forceAngel,
            forceDevil = forceDevil,
        }
    end

    local seeds = {
        GetStartSeedString = function()
            return "TEST RUN"
        end,
    }
    function Game()
        return {
            GetSeeds = function()
                return seeds
            end,
            GetRoom = function()
                return room
            end,
            GetLevel = function()
                return level
            end,
            GetItemPool = function()
                return {
                    GetCollectible = function()
                        return CollectibleType.COLLECTIBLE_NULL
                    end,
                }
            end,
            Spawn = function() end,
            SetStateFlag = function() end,
        }
    end

    Isaac = {
        GetItemIdByName = function(name)
            if name == "Uncut Cord" or name == "未剪断的脐带" then
                return itemIds.UncutCord
            end
            return itemIds[name] or -1
        end,
        GetMusicIdByName = function(name)
            if name == "MusicboxTheme" then
                return 736
            end
            return -1
        end,
        DebugString = function() end,
        GetRoomEntities = function()
            local entities = {}
            for _, entity in ipairs(roomEntities) do
                entities[#entities + 1] = entity
            end
            return entities
        end,
        FindByType = function()
            local entities = {}
            if not findPlayersByType then
                return entities
            end
            for _, player in ipairs(players) do
                entities[#entities + 1] = player
            end
            return entities
        end,
        WorldToScreen = function(position)
            return position
        end,
        RenderText = function(text, x, y, r, g, b, a)
            renderedTexts[#renderedTexts + 1] = {
                text = text,
                x = x,
                y = y,
                r = r,
                g = g,
                b = b,
                a = a,
            }
        end,
        GetItemConfig = function()
            return {
                GetCollectible = function()
                    return { Quality = 4 }
                end,
            }
        end,
    }

    Color = setmetatable({}, {
        __call = function(_, r, g, b, a, ro, go, bo)
            return { R = r, G = g, B = b, A = a, RO = ro, GO = go, BO = bo }
        end,
    })
    Color.Default = Color(1, 1, 1, 1, 0, 0, 0)

    local vectorMeta = {
        __add = function(left, right)
            return Vector(left.X + right.X, left.Y + right.Y)
        end,
    }
    function Vector(x, y)
        return setmetatable({ X = x or 0, Y = y or 0 }, vectorMeta)
    end

    function EntityRef(entity)
        return { Entity = entity }
    end

    local mod
    function RegisterMod(name, version)
        mod = {
            Name = name,
            Version = version,
        }

        function mod:AddCallback(callbackId, fn, param)
            callbacks[callbackId] = callbacks[callbackId] or {}
            callbacks[callbackId][#callbacks[callbackId] + 1] = { fn = fn, param = param }
        end

        function mod:HasData()
            return false
        end

        function mod:LoadData()
            return "{}"
        end

        function mod:SaveData() end

        return mod
    end

    dofile("main.lua")

    local function getCallbacks(callbackId, param)
        local found = {}
        for _, registration in ipairs(callbacks[callbackId] or {}) do
            if param == nil or registration.param == param then
                found[#found + 1] = registration.fn
            end
        end

        return found
    end

    local function runDamageCallbacks(player, amount, flags)
        local result = nil
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_ENTITY_TAKE_DMG)) do
            local callbackResult = callback(mod, player, amount, flags or 0, EntityRef(player), 0)
            if callbackResult ~= nil then
                result = callbackResult
                if callbackResult == false then
                    return false
                end
            end
        end

        return result
    end
    damageCallbackRunner = runDamageCallbacks

    local function runPostUpdates(frames)
        for _ = 1, frames do
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_UPDATE)) do
                callback(mod)
            end
        end
    end

    local function runPostNewRoom()
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_NEW_ROOM)) do
            callback(mod)
        end
    end

    local function runPostRender()
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_RENDER)) do
            callback(mod)
        end
    end

    local function runPostGameStarted(isContinued)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_GAME_STARTED)) do
            callback(mod, isContinued == true)
        end
    end

    local function newPlayer(options)
        options = options or {}
        local player = {
            InitSeed = options.initSeed or 1234,
            Position = Vector(0, 0),
            TearFlags = 0,
            collectibles = options.collectibles or { [itemIds.UncutCord] = 1 },
            activeItems = options.activeItems or {},
            activeCharges = options.activeCharges or {},
            randomFloats = options.randomFloats or { 0.25 },
            randomIndex = 1,
            takeDamageCalls = {},
            reenteredResults = {},
            reenterOnTakeDamage = options.reenterOnTakeDamage or false,
        }

        function player:ToPlayer()
            return self
        end

        function player:GetCollectibleNum(itemId)
            return self.collectibles[itemId] or 0
        end

        function player:GetCollectibleRNG()
            local owner = self
            return {
                RandomFloat = function()
                    local value = owner.randomFloats[owner.randomIndex] or 1
                    owner.randomIndex = owner.randomIndex + 1
                    return value
                end,
            }
        end

        function player:GetActiveItem(slot)
            return self.activeItems[slot or ActiveSlot.SLOT_PRIMARY] or 0
        end

        function player:GetActiveCharge(slot)
            return self.activeCharges[slot or ActiveSlot.SLOT_PRIMARY] or 0
        end

        function player:GetHearts()
            return 12
        end

        function player:GetSoulHearts()
            return 0
        end

        function player:GetBoneHearts()
            return 0
        end

        function player:TakeDamage(amount, flags, source, countdown)
            self.takeDamageCalls[#self.takeDamageCalls + 1] = {
                amount = amount,
                flags = flags,
                source = source,
                countdown = countdown,
            }

            if self.reenterOnTakeDamage and damageCallbackRunner then
                self.reenteredResults[#self.reenteredResults + 1] = damageCallbackRunner(self, amount, flags)
            end
        end

        function player:AddCacheFlags() end
        function player:EvaluateItems() end

        players[#players + 1] = player
        return player
    end

    local function newEnemy()
        local enemy = {
            dead = false,
            vulnerable = true,
        }
        function enemy:ToPlayer()
            return nil
        end
        function enemy:IsVulnerableEnemy()
            return self.vulnerable and not self.dead
        end

        roomEntities[#roomEntities + 1] = enemy
        return enemy
    end

    local function enterRoom(index, enemyCount)
        currentRoomIndex = index
        room.spawnSeed = 100 + index
        room.clear = enemyCount == 0
        roomEntities = {}
        local enemies = {}
        for _ = 1, enemyCount do
            enemies[#enemies + 1] = newEnemy()
        end
        runPostNewRoom()
        return enemies
    end

    local function clearCurrentRoom()
        for _, entity in ipairs(roomEntities) do
            entity.dead = true
        end
        room.clear = true
        runPostUpdates(1)
    end

    return {
        items = itemIds,
        newPlayer = newPlayer,
        enterRoom = enterRoom,
        clearCurrentRoom = clearCurrentRoom,
        runDamageCallbacks = runDamageCallbacks,
        runPostUpdates = runPostUpdates,
        runPostRender = runPostRender,
        runPostGameStarted = runPostGameStarted,
        renderedTexts = renderedTexts,
        clearRenderedTexts = function()
            for i = #renderedTexts, 1, -1 do
                renderedTexts[i] = nil
            end
        end,
        setFindPlayersByType = function(enabled)
            findPlayersByType = enabled == true
        end,
        getCallbacks = getCallbacks,
    }
end

local function assertRenderedText(env, expected, message)
    for _, entry in ipairs(env.renderedTexts) do
        if entry.text == expected then
            return
        end
    end

    error(message or ("expected rendered text " .. expected), 2)
end

local function assertNoRenderedTextPrefix(env, prefix, message)
    for _, entry in ipairs(env.renderedTexts) do
        if string.sub(entry.text, 1, #prefix) == prefix then
            error(message or ("did not expect rendered text prefix " .. prefix), 2)
        end
    end
end

local function test_uncut_cord_delays_and_cancels_triggered_damage()
    local env = loadNeverbirth()
    local player = env.newPlayer({ randomFloats = { 0.25 } })

    local result = env.runDamageCallbacks(player, 2)

    assertEquals(result, false, "triggered Uncut Cord should cancel the incoming damage")
    assertEquals(#player.takeDamageCalls, 0, "delayed damage should not be applied immediately")
end

local function test_uncut_cord_renders_delay_popup_and_debt()
    local env = loadNeverbirth()
    local player = env.newPlayer({ randomFloats = { 0.25 } })

    env.runDamageCallbacks(player, 2)
    env.runPostRender()

    assertRenderedText(env, "DELAY 1.0", "delayed damage should show a short popup")
    assertRenderedText(env, "DEBT 1.0 0/2", "pending delayed damage should render debt status")
end

local function test_uncut_cord_renders_room_progress()
    local env = loadNeverbirth()
    local player = env.newPlayer({ randomFloats = { 0.25 } })

    env.runDamageCallbacks(player, 2)
    env.enterRoom(2, 1)
    env.clearCurrentRoom()
    env.clearRenderedTexts()
    env.runPostRender()

    assertRenderedText(env, "DEBT 1.0 1/2", "clearing one combat room should update debt progress")
end

local function test_uncut_cord_second_damage_settles_full_debt_and_allows_current_damage()
    local env = loadNeverbirth()
    local player = env.newPlayer({ randomFloats = { 0.25, 0.25 } })

    env.runDamageCallbacks(player, 2)
    local result = env.runDamageCallbacks(player, 1)

    assertEquals(result, nil, "second damage with pending debt should allow the current hit to proceed")
    assertEquals(#player.takeDamageCalls, 1, "second damage should immediately settle the delayed debt once")
    assertEquals(player.takeDamageCalls[1].amount, 2, "second damage should settle the full delayed amount")
end

local function test_uncut_cord_renders_full_paid_on_second_hit()
    local env = loadNeverbirth()
    local player = env.newPlayer({ randomFloats = { 0.25, 0.25 } })

    env.runDamageCallbacks(player, 2)
    env.clearRenderedTexts()
    env.runDamageCallbacks(player, 1)
    env.runPostRender()

    assertRenderedText(env, "FULL PAID 1.0", "second hit should show full debt settlement")
    assertNoRenderedTextPrefix(env, "DEBT", "full settlement should stop rendering debt")
end

local function test_uncut_cord_clears_two_combat_rooms_then_settles_half_debt()
    local env = loadNeverbirth()
    local player = env.newPlayer({ randomFloats = { 0.25 } })

    env.runDamageCallbacks(player, 4)

    env.enterRoom(2, 0)
    env.clearCurrentRoom()
    assertEquals(#player.takeDamageCalls, 0, "empty rooms should not count toward delayed damage settlement")

    env.enterRoom(3, 1)
    env.clearCurrentRoom()
    assertEquals(#player.takeDamageCalls, 0, "one cleared combat room should not settle yet")

    env.enterRoom(4, 1)
    env.clearCurrentRoom()
    assertEquals(#player.takeDamageCalls, 1, "two cleared combat rooms should settle delayed damage")
    assertEquals(player.takeDamageCalls[1].amount, 2, "successful settlement should apply half delayed damage")
end

local function test_uncut_cord_renders_half_paid_after_two_rooms()
    local env = loadNeverbirth()
    local player = env.newPlayer({ randomFloats = { 0.25 } })

    env.runDamageCallbacks(player, 2)
    env.enterRoom(2, 1)
    env.clearCurrentRoom()
    env.enterRoom(3, 1)
    env.clearCurrentRoom()
    env.clearRenderedTexts()
    env.runPostRender()

    assertRenderedText(env, "HALF PAID 0.5", "safe room clears should show half debt settlement")
    assertNoRenderedTextPrefix(env, "DEBT", "half settlement should stop rendering debt")
end

local function test_uncut_cord_half_settlement_is_at_least_half_a_heart()
    local env = loadNeverbirth()
    local player = env.newPlayer({ randomFloats = { 0.25 } })

    env.runDamageCallbacks(player, 1)
    env.enterRoom(2, 1)
    env.clearCurrentRoom()
    env.enterRoom(3, 1)
    env.clearCurrentRoom()

    assertEquals(player.takeDamageCalls[1].amount, 1, "half settlement should be at least half a heart")
end

local function test_uncut_cord_settlement_does_not_recurse_into_damage_intercept()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        randomFloats = { 0.25, 0.25, 0.25 },
        reenterOnTakeDamage = true,
    })

    env.runDamageCallbacks(player, 2)
    local result = env.runDamageCallbacks(player, 1)

    assertEquals(result, nil, "second damage should remain normal while settling")
    assertEquals(#player.takeDamageCalls, 1, "settlement should not recursively apply more delayed damage")
    assertEquals(player.reenteredResults[1], nil, "settling damage should bypass Uncut Cord interception")
end

local function test_uncut_cord_tracks_each_player_independently()
    local env = loadNeverbirth()
    local playerA = env.newPlayer({ initSeed = 111, randomFloats = { 0.25 } })
    local playerB = env.newPlayer({ initSeed = 222, randomFloats = { 0.25 } })

    env.runDamageCallbacks(playerA, 4)
    env.runDamageCallbacks(playerB, 2)
    env.runDamageCallbacks(playerA, 1)

    assertEquals(#playerA.takeDamageCalls, 1, "player A should settle their own delayed damage")
    assertEquals(playerA.takeDamageCalls[1].amount, 4, "player A should settle their own full debt on next hit")
    assertEquals(#playerB.takeDamageCalls, 0, "player B's delayed damage should remain pending")

    env.enterRoom(2, 1)
    env.clearCurrentRoom()
    env.enterRoom(3, 1)
    env.clearCurrentRoom()

    assertEquals(#playerB.takeDamageCalls, 1, "player B should later settle independently after rooms")
    assertEquals(playerB.takeDamageCalls[1].amount, 1, "player B should settle half of their own delayed damage")
end

local function test_uncut_cord_new_run_clears_runtime_debts()
    local env = loadNeverbirth()
    local player = env.newPlayer({ randomFloats = { 0.25, 0.75 } })

    env.runDamageCallbacks(player, 2)
    env.runPostGameStarted(false)
    local result = env.runDamageCallbacks(player, 1)

    assertEquals(result, nil, "new run should clear pending Uncut Cord debt before the next hit")
    assertEquals(#player.takeDamageCalls, 0, "after new-run cleanup there should be no old debt to settle")
end

local function test_uncut_cord_does_not_render_when_trigger_misses()
    local env = loadNeverbirth()
    local player = env.newPlayer({ randomFloats = { 0.75 } })

    env.runDamageCallbacks(player, 2)
    env.runPostRender()

    assertNoRenderedTextPrefix(env, "DELAY", "missed 50 percent trigger should not show feedback")
    assertNoRenderedTextPrefix(env, "DEBT", "missed 50 percent trigger should not create visible debt")
end

local function test_uncut_cord_renders_each_player_debt_independently()
    local env = loadNeverbirth()
    local playerA = env.newPlayer({ initSeed = 111, randomFloats = { 0.25 } })
    local playerB = env.newPlayer({ initSeed = 222, randomFloats = { 0.25 } })

    env.runDamageCallbacks(playerA, 2)
    env.runDamageCallbacks(playerB, 4)
    env.runPostRender()

    assertRenderedText(env, "DEBT 1.0 0/2", "player A should render their own debt")
    assertRenderedText(env, "DEBT 2.0 0/2", "player B should render their own debt")
end

local function test_uncut_cord_renders_from_stored_player_when_find_by_type_is_empty()
    local env = loadNeverbirth()
    local player = env.newPlayer({ randomFloats = { 0.25 } })

    env.runDamageCallbacks(player, 2)
    env.setFindPlayersByType(false)
    env.runPostRender()

    assertRenderedText(env, "DELAY 1.0", "delay popup should render from the stored player reference")
    assertRenderedText(env, "DEBT 1.0 0/2", "debt text should render from the stored player reference")
end

test_uncut_cord_delays_and_cancels_triggered_damage()
test_uncut_cord_renders_delay_popup_and_debt()
test_uncut_cord_renders_room_progress()
test_uncut_cord_second_damage_settles_full_debt_and_allows_current_damage()
test_uncut_cord_renders_full_paid_on_second_hit()
test_uncut_cord_clears_two_combat_rooms_then_settles_half_debt()
test_uncut_cord_renders_half_paid_after_two_rooms()
test_uncut_cord_half_settlement_is_at_least_half_a_heart()
test_uncut_cord_settlement_does_not_recurse_into_damage_intercept()
test_uncut_cord_tracks_each_player_independently()
test_uncut_cord_new_run_clears_runtime_debts()
test_uncut_cord_does_not_render_when_trigger_misses()
test_uncut_cord_renders_each_player_debt_independently()
test_uncut_cord_renders_from_stored_player_when_find_by_type_is_empty()

print("uncut cord behavior tests passed")
