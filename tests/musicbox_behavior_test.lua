local function deepcopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[deepcopy(key)] = deepcopy(child)
    end
    return copy
end

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

local function loadNeverbirth(savedStore)
    savedStore = savedStore or { text = nil, snapshot = nil }

    local callbacks = {}
    local itemIds = {
        EssentialBalm = 733,
        Wuhu = 734,
        Aphrodisiac = 735,
        Musicbox = 736,
        Angelbox = 737,
        Devilbox = 738,
        ds4 = 739,
    }

    package.loaded.json = nil
    package.preload.json = function()
        return {
            encode = function(value)
                savedStore.snapshot = deepcopy(value)
                return "<json>"
            end,
            decode = function()
                return deepcopy(savedStore.snapshot or {})
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
    }

    CollectibleType = {
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
    EntityType = { ENTITY_PLAYER = 1 }
    ActiveSlot = {
        SLOT_PRIMARY = 0,
        SLOT_SECONDARY = 1,
        SLOT_POCKET = 2,
        SLOT_POCKET2 = 3,
    }

    local musicState = {
        current = 1,
        plays = {},
        fadeouts = 0,
    }

    function MusicManager()
        return {
            GetCurrentMusicID = function()
                return musicState.current
            end,
            Play = function(_, musicId)
                musicState.current = musicId
                musicState.plays[#musicState.plays + 1] = musicId
            end,
            Fadeout = function()
                musicState.fadeouts = musicState.fadeouts + 1
            end,
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
        }
    end

    local players = {}
    local roomEntities = {}

    Isaac = {
        GetItemIdByName = function(name)
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
            for _, player in ipairs(players) do
                entities[#entities + 1] = player
            end
            return entities
        end,
        WorldToScreen = function(position)
            return position
        end,
        RenderText = function() end,
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

        function mod:SaveData(text)
            savedStore.text = text
        end

        function mod:LoadData()
            return savedStore.text
        end

        function mod:HasData()
            return savedStore.text ~= nil
        end

        return mod
    end

    dofile("main.lua")

    local function getCallback(callbackId, param)
        for _, registration in ipairs(callbacks[callbackId] or {}) do
            if param == nil or registration.param == param then
                return registration.fn
            end
        end

        error("callback not found: " .. tostring(callbackId) .. " param=" .. tostring(param), 2)
    end

    local function getCallbackOrNil(callbackId, param)
        for _, registration in ipairs(callbacks[callbackId] or {}) do
            if param == nil or registration.param == param then
                return registration.fn
            end
        end

        return nil
    end

    local function getCallbacks(callbackId, param)
        local found = {}
        for _, registration in ipairs(callbacks[callbackId] or {}) do
            if param == nil or registration.param == param then
                found[#found + 1] = registration.fn
            end
        end

        return found
    end

    local function newPlayer(options)
        options = options or {}
        local player = {
            InitSeed = options.initSeed or 1234,
            Position = Vector(0, 0),
            TearFlags = 0,
            killCount = 0,
            removeCalls = {},
            cacheFlags = {},
            activeItems = options.activeItems or { [ActiveSlot.SLOT_PRIMARY] = itemIds.Musicbox },
            activeCharges = options.activeCharges or { [ActiveSlot.SLOT_PRIMARY] = 12 },
            needsCharge = options.needsCharge,
            mortalDamage = options.mortalDamage,
            hearts = options.hearts or 2,
            soulHearts = options.soulHearts or 0,
            boneHearts = options.boneHearts or 0,
            willRevive = options.willRevive or false,
            removeCollectibleThrows = options.removeCollectibleThrows or false,
        }

        function player:ToPlayer()
            return self
        end

        function player:AddCacheFlags(flags)
            self.cacheFlags[#self.cacheFlags + 1] = flags
        end

        function player:EvaluateItems()
            self.evaluated = (self.evaluated or 0) + 1
        end

        function player:GetCollectibleNum()
            return 0
        end

        function player:GetActiveItem(slot)
            return self.activeItems[slot or ActiveSlot.SLOT_PRIMARY] or 0
        end

        function player:GetActiveCharge(slot)
            return self.activeCharges[slot or ActiveSlot.SLOT_PRIMARY] or 0
        end

        function player:NeedsCharge(slot)
            if type(self.needsCharge) == "table" then
                return self.needsCharge[slot or ActiveSlot.SLOT_PRIMARY]
            end
            return self.needsCharge
        end

        function player:RemoveCollectible(itemId, ignoreModifiers, slot, removeFromPlayerForm)
            if self.removeCollectibleThrows then
                error("RemoveCollectible failed")
            end

            self.removeCalls[#self.removeCalls + 1] = {
                itemId = itemId,
                ignoreModifiers = ignoreModifiers,
                slot = slot,
                removeFromPlayerForm = removeFromPlayerForm,
            }
            self.activeItems[slot or ActiveSlot.SLOT_PRIMARY] = 0
        end

        function player:HasMortalDamage()
            return self.mortalDamage
        end

        function player:Kill()
            self.killCount = self.killCount + 1
        end

        function player:WillPlayerRevive()
            return self.willRevive
        end

        function player:GetHearts()
            return self.hearts
        end

        function player:GetSoulHearts()
            return self.soulHearts
        end

        function player:GetBoneHearts()
            return self.boneHearts
        end

        function player:AddHearts(amount)
            self.addedHearts = (self.addedHearts or 0) + amount
        end

        players[#players + 1] = player
        return player
    end

    local function newEnemy(options)
        options = options or {}
        local enemy = {
            damageTaken = 0,
            vulnerable = options.vulnerable ~= false,
        }

        function enemy:IsVulnerableEnemy()
            return self.vulnerable
        end

        function enemy:ToPlayer()
            return nil
        end

        function enemy:TakeDamage(amount, flags, source, countdown)
            self.damageTaken = self.damageTaken + amount
            self.lastDamageFlags = flags
            self.lastDamageSource = source
            self.lastDamageCountdown = countdown
            return true
        end

        roomEntities[#roomEntities + 1] = enemy
        return enemy
    end

    return {
        mod = mod,
        items = itemIds,
        savedStore = savedStore,
        callbacks = callbacks,
        musicState = musicState,
        getCallback = getCallback,
        getCallbackOrNil = getCallbackOrNil,
        getCallbacks = getCallbacks,
        newPlayer = newPlayer,
        newEnemy = newEnemy,
    }
end

local function tick(env, frames)
    local updates = env.getCallbacks(ModCallbacks.MC_POST_UPDATE)
    for _ = 1, frames do
        for _, update in ipairs(updates) do
            update(env.mod)
        end
    end
end

local function test_second_use_does_not_extend_death_timer()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    local use = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Musicbox)

    use(env.mod, env.items.Musicbox, nil, player)
    tick(env, 300)
    use(env.mod, env.items.Musicbox, nil, player)
    tick(env, 300)

    assertEquals(player.killCount, 1, "second Musicbox use must not postpone the 20 second death")
end

local function test_uncharged_musicbox_auto_triggers_on_lethal_damage()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 0 },
        needsCharge = true,
        mortalDamage = true,
    })
    local damage = env.getCallback(ModCallbacks.MC_ENTITY_TAKE_DMG)

    local result = damage(env.mod, player, 1, 0, nil, 0)

    assertEquals(result, false, "lethal damage should be cancelled by panic Musicbox trigger")
    assertEquals(#player.removeCalls, 1, "panic trigger should remove the uncharged Musicbox")
    assertEquals(player.removeCalls[1].itemId, env.items.Musicbox, "panic trigger should remove Musicbox")
    assertTruthy(env.savedStore.snapshot and env.savedStore.snapshot.musicboxDeathDebt, "panic trigger should save death debt")

    tick(env, 600)
    assertEquals(player.killCount, 1, "panic-triggered Musicbox should still kill after 20 seconds")
end

local function test_uncharged_musicbox_auto_triggers_on_real_half_heart_lethal_damage()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        hearts = 1,
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 0 },
    })
    local damage = env.getCallback(ModCallbacks.MC_ENTITY_TAKE_DMG)

    local result = damage(env.mod, player, 1, 0, nil, 0)

    assertEquals(result, false, "real half-heart lethal damage should be cancelled by panic Musicbox trigger")
    assertEquals(#player.removeCalls, 1, "panic trigger should remove Musicbox without relying on HasMortalDamage")
    assertTruthy(env.savedStore.snapshot and env.savedStore.snapshot.musicboxDeathDebt, "real damage panic trigger should save death debt")
end

local function test_full_charge_musicbox_does_not_auto_trigger_on_lethal_damage()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        hearts = 1,
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 12 },
    })
    local damage = env.getCallback(ModCallbacks.MC_ENTITY_TAKE_DMG)

    local result = damage(env.mod, player, 1, 0, nil, 0)

    assertEquals(result, nil, "full-charge Musicbox should not auto trigger on lethal damage")
    assertEquals(#player.removeCalls, 0, "full-charge Musicbox should not be removed by panic trigger")
    assertEquals(env.savedStore.snapshot == nil, true, "full-charge Musicbox should not save a panic death debt")
end

local function test_full_main_charge_ignores_needs_charge_from_secondary_battery()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        hearts = 1,
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 12 },
        needsCharge = true,
    })
    local damage = env.getCallback(ModCallbacks.MC_ENTITY_TAKE_DMG)

    local result = damage(env.mod, player, 1, 0, nil, 0)

    assertEquals(result, nil, "main charge at 12 should not auto trigger even if NeedsCharge reports true")
    assertEquals(#player.removeCalls, 0, "NeedsCharge true should not remove a usable Musicbox")
end

local function test_uncharged_musicbox_in_secondary_slot_auto_triggers()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        hearts = 1,
        activeItems = {
            [ActiveSlot.SLOT_PRIMARY] = 0,
            [ActiveSlot.SLOT_SECONDARY] = env.items.Musicbox,
        },
        activeCharges = { [ActiveSlot.SLOT_SECONDARY] = 0 },
    })
    local damage = env.getCallback(ModCallbacks.MC_ENTITY_TAKE_DMG)

    local result = damage(env.mod, player, 1, 0, nil, 0)

    assertEquals(result, false, "uncharged Musicbox in secondary slot should auto trigger on lethal damage")
    assertEquals(#player.removeCalls, 1, "secondary-slot panic trigger should remove Musicbox")
    assertEquals(player.removeCalls[1].slot, ActiveSlot.SLOT_SECONDARY, "panic trigger should remove Musicbox from the matching active slot")
end

local function test_panic_musicbox_still_triggers_if_remove_collectible_errors()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        hearts = 1,
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 0 },
        removeCollectibleThrows = true,
    })
    local damage = env.getCallback(ModCallbacks.MC_ENTITY_TAKE_DMG)

    local ok, result = pcall(function()
        return damage(env.mod, player, 1, 0, nil, 0)
    end)

    assertEquals(ok, true, "panic Musicbox should not crash if removal fails")
    assertEquals(result, false, "panic Musicbox should still cancel lethal damage if removal fails")
    assertTruthy(env.savedStore.snapshot and env.savedStore.snapshot.musicboxDeathDebt, "panic trigger should save death debt even if removal fails")
end

local function test_musicbox_death_debt_survives_reload()
    local savedStore = { text = nil, snapshot = nil }
    local env = loadNeverbirth(savedStore)
    local player = env.newPlayer({ initSeed = 777 })
    local use = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Musicbox)

    use(env.mod, env.items.Musicbox, nil, player)
    tick(env, 100)

    local reloadedEnv = loadNeverbirth(savedStore)
    local reloadedPlayer = reloadedEnv.newPlayer({ initSeed = 777 })
    tick(reloadedEnv, 500)

    assertEquals(reloadedPlayer.killCount, 1, "saved Musicbox death debt should survive reload/rewind")
end

local function test_plan_c_during_musicbox_kills_enemies_without_plan_c_death()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        activeItems = {
            [ActiveSlot.SLOT_PRIMARY] = CollectibleType.COLLECTIBLE_PLAN_C,
            [ActiveSlot.SLOT_SECONDARY] = env.items.Musicbox,
        },
    })
    local enemy = env.newEnemy()
    local useMusicbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Musicbox)
    local usePlanC = env.getCallbackOrNil(ModCallbacks.MC_PRE_USE_ITEM, CollectibleType.COLLECTIBLE_PLAN_C)

    assertTruthy(usePlanC, "Plan C pre-use callback should be registered")

    useMusicbox(env.mod, env.items.Musicbox, nil, player)
    tick(env, 30)

    local result = usePlanC(env.mod, CollectibleType.COLLECTIBLE_PLAN_C, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)

    assertEquals(result, true, "Plan C should be intercepted while Musicbox is active")
    assertEquals(#player.removeCalls, 1, "intercepted Plan C should be removed after use")
    assertEquals(player.removeCalls[1].itemId, CollectibleType.COLLECTIBLE_PLAN_C, "intercepted Plan C should remove Plan C")
    assertEquals(enemy.damageTaken, 9999999, "intercepted Plan C should still damage enemies")

    tick(env, 90)
    assertEquals(player.killCount, 0, "intercepted Plan C should not kill before Musicbox expires")

    tick(env, 480)
    assertEquals(player.killCount, 1, "Musicbox death debt should still resolve after Plan C is blocked")
end

local function test_musicbox_cancels_pending_plan_c_death()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        activeItems = {
            [ActiveSlot.SLOT_PRIMARY] = CollectibleType.COLLECTIBLE_PLAN_C,
            [ActiveSlot.SLOT_SECONDARY] = env.items.Musicbox,
        },
    })
    local enemy = env.newEnemy()
    local useMusicbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Musicbox)
    local usePlanC = env.getCallbackOrNil(ModCallbacks.MC_PRE_USE_ITEM, CollectibleType.COLLECTIBLE_PLAN_C)

    assertTruthy(usePlanC, "Plan C pre-use callback should be registered")

    local result = usePlanC(env.mod, CollectibleType.COLLECTIBLE_PLAN_C, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    assertEquals(result, true, "Plan C should be intercepted when the player has Musicbox")
    assertEquals(#player.removeCalls, 1, "intercepted Plan C should be removed after use")
    assertEquals(player.removeCalls[1].itemId, CollectibleType.COLLECTIBLE_PLAN_C, "intercepted Plan C should remove Plan C")
    assertEquals(enemy.damageTaken, 9999999, "intercepted Plan C should still damage enemies")

    tick(env, 30)
    useMusicbox(env.mod, env.items.Musicbox, nil, player)
    tick(env, 90)
    assertEquals(player.killCount, 0, "Musicbox should cancel pending Plan C death")

    tick(env, 510)
    assertEquals(player.killCount, 1, "only Musicbox death should resolve after cancelling Plan C death")
end

local function test_plan_c_still_kills_when_musicbox_is_not_used()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        activeItems = {
            [ActiveSlot.SLOT_PRIMARY] = CollectibleType.COLLECTIBLE_PLAN_C,
            [ActiveSlot.SLOT_SECONDARY] = env.items.Musicbox,
        },
    })
    local enemy = env.newEnemy()
    local usePlanC = env.getCallbackOrNil(ModCallbacks.MC_PRE_USE_ITEM, CollectibleType.COLLECTIBLE_PLAN_C)

    assertTruthy(usePlanC, "Plan C pre-use callback should be registered")

    local result = usePlanC(env.mod, CollectibleType.COLLECTIBLE_PLAN_C, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)

    assertEquals(result, true, "Plan C should be intercepted when the player has unused Musicbox")
    assertEquals(#player.removeCalls, 1, "intercepted Plan C should be removed after use")
    assertEquals(player.removeCalls[1].itemId, CollectibleType.COLLECTIBLE_PLAN_C, "intercepted Plan C should remove Plan C")
    assertEquals(enemy.damageTaken, 9999999, "intercepted Plan C should still damage enemies")

    tick(env, 90)
    assertEquals(player.killCount, 1, "Plan C should kill if Musicbox is never activated")
end

local function test_plan_c_without_musicbox_uses_vanilla_behavior()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = CollectibleType.COLLECTIBLE_PLAN_C },
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 0 },
    })
    local usePlanC = env.getCallbackOrNil(ModCallbacks.MC_PRE_USE_ITEM, CollectibleType.COLLECTIBLE_PLAN_C)

    assertTruthy(usePlanC, "Plan C pre-use callback should be registered")

    local result = usePlanC(env.mod, CollectibleType.COLLECTIBLE_PLAN_C, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)

    assertEquals(result, nil, "Plan C should fall back to vanilla behavior without Musicbox involvement")
    assertEquals(#player.removeCalls, 0, "vanilla Plan C fallback should not be modified by neverbirth")
end

test_second_use_does_not_extend_death_timer()
test_uncharged_musicbox_auto_triggers_on_lethal_damage()
test_uncharged_musicbox_auto_triggers_on_real_half_heart_lethal_damage()
test_full_charge_musicbox_does_not_auto_trigger_on_lethal_damage()
test_full_main_charge_ignores_needs_charge_from_secondary_battery()
test_uncharged_musicbox_in_secondary_slot_auto_triggers()
test_panic_musicbox_still_triggers_if_remove_collectible_errors()
test_musicbox_death_debt_survives_reload()
test_plan_c_during_musicbox_kills_enemies_without_plan_c_death()
test_musicbox_cancels_pending_plan_c_death()
test_plan_c_still_kills_when_musicbox_is_not_used()
test_plan_c_without_musicbox_uses_vanilla_behavior()

print("musicbox behavior tests passed")
