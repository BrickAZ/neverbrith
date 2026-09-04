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
    local file = assert(io.open(path, "rb"), path .. " should exist")
    local value = file:read("*a")
    file:close()
    return value
end

local function assertVectorNear(actual, x, y, epsilon, message)
    assertTruthy(actual, (message or "vector") .. " should exist")
    assertNear(actual.X, x, epsilon, (message or "vector") .. " X")
    assertNear(actual.Y, y, epsilon, (message or "vector") .. " Y")
end

-- localization_test owns the project's complete ordinary-Repentance stub and
-- loads main.lua.  Keeping this behavior test on that entrypoint prevents the
-- production module from accidentally depending on REPENTOGON or StageAPI.
dofile("tests/localization_test.lua")

local api = assert(Neverbirth and Neverbirth.BigDogBarkTestAPI,
    "Big Dog Bark runtime API should load through main.lua")
local constants = assert(api.Constants, "Big Dog Bark constants should be exposed")
local runtime = assert(api.Runtime, "Big Dog Bark runtime should be exposed")
local function callbackRegistered(callbackId, callbackFn)
    for _, entry in ipairs(NeverbirthLocalizationTestCallbacks[callbackId] or {}) do
        if entry.fn == callbackFn then
            return true
        end
    end
    return false
end
assertTruthy(callbackRegistered(ModCallbacks.MC_POST_PEFFECT_UPDATE, api.Callbacks.PostPlayerUpdate),
    "Big Dog Bark must use ordinary Repentance MC_POST_PEFFECT_UPDATE for its gameplay update")
assertTruthy(NeverbirthLocalizationTestCallbacks[ModCallbacks.MC_POST_ENTITY_REMOVE],
    "Big Dog Bark must register MC_POST_ENTITY_REMOVE in ordinary Repentance")
assertTruthy(NeverbirthLocalizationTestCallbacks[ModCallbacks.MC_POST_PLAYER_RENDER],
    "Big Dog Bark must register MC_POST_PLAYER_RENDER in ordinary Repentance")

local vectorMeta = {
    __add = function(left, right) return Vector(left.X + right.X, left.Y + right.Y) end,
    __sub = function(left, right) return Vector(left.X - right.X, left.Y - right.Y) end,
    __unm = function(value) return Vector(-value.X, -value.Y) end,
    __mul = function(left, right)
        if type(left) == "number" then return Vector(right.X * left, right.Y * left) end
        return Vector(left.X * right, left.Y * right)
    end,
}

function Vector(x, y)
    return setmetatable({
        X = x or 0,
        Y = y or 0,
        Length = function(self)
            return math.sqrt(self.X * self.X + self.Y * self.Y)
        end,
        LengthSquared = function(self)
            return self.X * self.X + self.Y * self.Y
        end,
        Normalized = function(self)
            local length = self:Length()
            if length <= 0 then return Vector(0, 0) end
            return Vector(self.X / length, self.Y / length)
        end,
        Distance = function(self, other)
            return (self - other):Length()
        end,
    }, vectorMeta)
end

local function makePlayer(seed, options)
    options = options or {}
    local player = {
        InitSeed = seed,
        Position = options.position or Vector(100, 100),
        Damage = options.damage or 3.5,
        MaxFireDelay = options.maxFireDelay or 9,
        movement = options.movement or Vector(0, 0),
        collectibles = options.collectibles or {},
        activeItems = options.activeItems or {},
        queuedItemId = nil,
    }
    function player:ToPlayer() return self end
    function player:Exists() return true end
    function player:IsDead() return false end
    function player:GetCollectibleNum(itemId) return self.collectibles[itemId] or 0 end
    function player:HasCollectible(itemId) return (self.collectibles[itemId] or 0) > 0 end
    function player:GetActiveItem(slot) return self.activeItems[slot] or 0 end
    function player:GetMovementInput() return self.movement end
    function player:GetQueuedItem()
        if not self.queuedItemId then return nil end
        return { Item = { ID = self.queuedItemId } }
    end
    return player
end

local createdChargeSprites = {}

function Sprite()
    local sprite = {
        animation = nil,
        frame = 0,
        loadCalls = 0,
        playCalls = {},
        renderCalls = {},
        finished = {},
        triggered = {},
    }
    function sprite:Load(path, loadGraphics)
        self.loadCalls = self.loadCalls + 1
        self.loadedPath = path
        self.loadedGraphics = loadGraphics
    end
    function sprite:Play(animation, force)
        self.animation = animation
        self.frame = 0
        self.playCalls[#self.playCalls + 1] = animation
    end
    function sprite:IsPlaying(animation)
        return self.animation == animation and self.finished[animation] ~= true
    end
    function sprite:IsFinished(animation)
        return self.animation == animation and self.finished[animation] == true
    end
    function sprite:TriggerEvent(eventName)
        self.triggered[eventName] = true
    end
    function sprite:IsEventTriggered(eventName)
        local value = self.triggered[eventName] == true
        self.triggered[eventName] = nil
        return value
    end

    function sprite:GetAnimation() return self.animation end
    function sprite:SetFrame(animation, frame)
        self.animation = animation
        self.frame = frame
    end
    function sprite:Update() self.frame = self.frame + 1 end
    function sprite:Render(position, topLeftClamp, bottomRightClamp)
        self.renderCalls[#self.renderCalls + 1] = position
        self.renderArguments = self.renderArguments or {}
        self.renderArguments[#self.renderArguments + 1] = {
            position = position,
            topLeftClamp = topLeftClamp,
            bottomRightClamp = bottomRightClamp,
        }
    end
    createdChargeSprites[#createdChargeSprites + 1] = sprite
    return sprite
end

local function makePickup(seed, itemId)
    local data = {}
    local pickup = {
        Type = EntityType.ENTITY_PICKUP,
        Variant = PickupVariant.PICKUP_COLLECTIBLE,
        SubType = itemId,
        InitSeed = seed,
        Position = Vector(120, 100),
        removed = false,
    }
    function pickup:GetData() return data end
    function pickup:Exists() return not self.removed end
    return pickup
end

local function makeEnemy(seed, position, maxHp)
    local enemy = {
        InitSeed = seed,
        Position = position or Vector(120, 100),
        Velocity = Vector(0, 0),
        HitPoints = maxHp or 100,
        MaxHitPoints = maxHp or 100,
        damageCalls = {},
        damageSources = {},
        slowCalls = 0,
        dead = false,
    }
    function enemy:Exists() return not self.dead end
    function enemy:IsDead() return self.dead end
    function enemy:IsVulnerableEnemy() return not self.dead end
    function enemy:IsActiveEnemy() return not self.dead end
    function enemy:ToNPC() return self end
    function enemy:IsBoss() return false end
    function enemy:TakeDamage(amount, flags, source, countdown)
        self.damageCalls[#self.damageCalls + 1] = amount
        self.damageSources[#self.damageSources + 1] = source
        self.HitPoints = self.HitPoints - amount
    end
    function enemy:AddSlowing()
        self.slowCalls = self.slowCalls + 1
    end
    return enemy
end

local function makeDogEffect(seed, position)
    local data = { NeverbirthBigDogDog = true }
    local sprite = Sprite()
    local effect = {
        InitSeed = seed,
        Position = position or Vector(0, 0),
        Velocity = Vector(0, 0),
        removed = false,
    }
    function effect:Exists() return not self.removed end
    function effect:GetData() return data end
    function effect:GetSprite() return sprite end
    function effect:Remove() self.removed = true end
    return effect, sprite, data
end

local function test_registration()
    for _, path in ipairs({ "content/items.xml", "content/items.en_us.xml" }) do
        local text = readFile(path)
        local dog = text:match('<active[^>]-name="Big Dog Bark"[^>]*/>')
        assertTruthy(dog, path .. " should register Big Dog Bark")
        assertEquals(dog:match('id="(.-)"'), "48", path .. " Big Dog Bark local id")
        assertEquals(dog:match('quality="(.-)"'), "3", path .. " Big Dog Bark quality")
        assertEquals(dog:match('maxcharges="(.-)"'), "0", path .. " Big Dog Bark charge")
        assertEquals(dog:match('gfx="(.-)"'), "big_dog_bark.png", path .. " Big Dog Bark icon")

        local rod = text:match('<passive[^>]-name="Wind Charge Rod"[^>]*/>')
        local shard = text:match('<passive[^>]-name="Echo Shard"[^>]*/>')
        assertTruthy(rod, path .. " should register Wind Charge Rod")
        assertTruthy(shard, path .. " should register Echo Shard")
        assertEquals(rod:match('id="(.-)"'), "49", path .. " Wind Charge Rod local id")
        assertEquals(shard:match('id="(.-)"'), "50", path .. " Echo Shard local id")
        assertEquals(rod:match('quality="(.-)"'), nil, "Wind Charge Rod quality stays TBD")
        assertEquals(shard:match('quality="(.-)"'), nil, "Echo Shard quality stays TBD")
    end

    local zh = readFile("content/items.zh_cn.xml")
    assertTruthy(zh:find('name="大狗叫"', 1, true), "Chinese items XML should register 大狗叫")
    assertTruthy(zh:find('name="蓄风棒"', 1, true), "Chinese items XML should register 蓄风棒")
    assertTruthy(zh:find('name="回响碎片"', 1, true), "Chinese items XML should register 回响碎片")

    for _, path in ipairs({ "content/itempools.xml", "content/itempools.en_us.xml" }) do
        local pools = readFile(path)
        local dogPool = pools:match('<Pool Name="treasure">.-</Pool>')
        assertTruthy(dogPool and dogPool:find('<Item Name="Big Dog Bark" Weight="1" DecreaseBy="1" RemoveOn="1"/>', 1, true),
            path .. " should add Big Dog Bark only to treasure at the locked weight")
        assertEquals(pools:find('Name="Wind Charge Rod"', 1, true), nil, "Wind Charge Rod pool stays TBD")
        assertEquals(pools:find('Name="Echo Shard"', 1, true), nil, "Echo Shard pool stays TBD")
    end
    local zhPools = readFile("content/itempools.zh_cn.xml")
    local zhTreasure = zhPools:match('<Pool Name="treasure">.-</Pool>')
    assertTruthy(zhTreasure and zhTreasure:find('<Item Name="大狗叫" Weight="1" DecreaseBy="1" RemoveOn="1"/>', 1, true),
        "Chinese treasure pool should use the translated item name")

    local sounds = readFile("content/sounds.xml")
    assertTruthy(sounds:find('<sounds root="sfx/">', 1, true),
        "custom Big Dog Bark sounds should use the engine SFX resource root")
    assertTruthy(sounds:find('name="Big Dog Bark Charge"', 1, true),
        "charge cue should be registered by its stable sound name")
    assertTruthy(sounds:find('path="big_dog_bark/big_dog_charge.wav"', 1, true),
        "charge cue should point to the PCM WAV used by the custom SFX loader")
    assertTruthy(sounds:find('name="Big Dog Bark Release"', 1, true),
        "release cue should be registered by its stable sound name")
    assertTruthy(sounds:find('path="big_dog_bark/big_dog_release.wav"', 1, true),
        "release cue should point to the PCM WAV used by the custom SFX loader")

    for _, path in ipairs({
        "resources/sfx/big_dog_bark/big_dog_charge.wav",
        "resources/sfx/big_dog_bark/big_dog_release.wav",
    }) do
        local wav = readFile(path)
        assertEquals(wav:sub(1, 4), "RIFF", path .. " should use the RIFF container")
        assertEquals(wav:sub(9, 12), "WAVE", path .. " should be a WAVE file")
        assertEquals(wav:sub(13, 16), "fmt ", path .. " should begin with a fmt chunk")
        local formatCode = (wav:byte(21) or 0) + (wav:byte(22) or 0) * 256
        assertEquals(formatCode, 1, path .. " should contain uncompressed PCM audio")
    end

    for _, path in ipairs({ "content/pocketitems.xml", "content/pocketitems.en_us.xml" }) do
        assertTruthy(readFile(path):find('name="Wind Charge Potion"', 1, true), path .. " should register the custom pill")
    end
    assertTruthy(readFile("content/pocketitems.zh_cn.xml"):find('name="蓄风药剂"', 1, true),
        "Chinese pocketitems XML should register 蓄风药剂")

    local entities = readFile("content/entities2.xml")
    assertTruthy(entities:find('variant="3017"', 1, true) and entities:find('name="Big Dog Bark Dog"', 1, true),
        "Big Dog Bark dog effect should use variant 3017")
    assertTruthy(entities:find('variant="3018"', 1, true) and entities:find('name="Big Dog Bark Echo"', 1, true),
        "Big Dog Bark echo effect should use variant 3018")
    assertTruthy(entities:find('variant="3019"', 1, true) and entities:find('name="Big Dog Bark Pollution"', 1, true),
        "Big Dog Bark pollution effect should use variant 3019")

    local dogAnm2 = readFile("resources/gfx/Effects/BigDogBark/big_dog_entity.anm2")
    for _, animation in ipairs({
        "FollowDown", "FollowUp", "FollowHorizontal",
        "ChewDown", "ChewUp", "ChewHorizontal",
        "RunDown", "RunUp", "RunHorizontal",
        "BiteDown", "BiteUp", "BiteHorizontal",
        "DashDown", "DashUp", "DashHorizontal",
        "ChargeDown", "ChargeUp", "ChargeHorizontal",
    }) do
        assertTruthy(dogAnm2:find('Name="' .. animation .. '"', 1, true), "dog ANM2 missing " .. animation)
    end
    for _, animation in ipairs({ "FollowDown", "FollowUp", "FollowHorizontal" }) do
        local block = assert(dogAnm2:match('<Animation Name="' .. animation .. '".-</Animation>'),
            "dog ANM2 should expose " .. animation .. " for baseline validation")
        assertTruthy(block:find('FrameNum="16"', 1, true),
            animation .. " should use a slower sixteen-frame breathing loop")
        assertTruthy(block:find('YPosition="0" XScale="100" YScale="100" Delay="16"', 1, true),
            animation .. " root timing should cover the full breathing loop")
        local expected = { 0, 1, 0, -1 }
        local index = 0
        for yPosition, delay in block:gmatch('<Frame XPosition="0" YPosition="([%-0-9]+)" XPivot=.-Delay="([0-9]+)"') do
            index = index + 1
            assertEquals(tonumber(yPosition), expected[index], animation .. " light breathing offset " .. index)
            assertEquals(tonumber(delay), 4, animation .. " breathing keyframe duration " .. index)
        end
        assertEquals(index, 4, animation .. " should have four slow breathing keyframes")
    end
    local echoAnm2 = readFile("resources/gfx/Effects/BigDogBark/big_dog_echo.anm2")
    for _, eventName in ipairs({ "BiteLungeStart", "BiteHit", "BiteEnd" }) do
        assertTruthy(dogAnm2:find('Name="' .. eventName .. '"', 1, true),
            "dog ANM2 missing event " .. eventName)
    end
    for _, animation in ipairs({ "BiteDown", "BiteUp", "BiteHorizontal" }) do
        local block = assert(dogAnm2:match('<Animation Name="' .. animation .. '".-</Animation>'),
            "dog ANM2 should expose " .. animation .. " event timing")
        assertTruthy(block:find('EventId="0"', 1, true), animation .. " should expose lunge event")
        assertTruthy(block:find('EventId="1"', 1, true), animation .. " should expose hit event")
        assertTruthy(block:find('EventId="2"', 1, true), animation .. " should expose end event")
    end
    for _, animation in ipairs({ "EchoDown", "EchoUp", "EchoHorizontal" }) do
        assertTruthy(echoAnm2:find('Name="' .. animation .. '"', 1, true), "echo ANM2 missing " .. animation)
    end
    local creepAnm2 = readFile("resources/gfx/Effects/BigDogBark/big_dog_creep.anm2")
    assertTruthy(creepAnm2:find('Name="Appear"', 1, true), "pollution ANM2 missing Appear")
end

local function test_constants_charge_direction_and_busy()
    assertEquals(constants.DASH_DISTANCE, 320, "base dash distance")
    assertEquals(constants.DASH_SPEED, 20, "dash speed")
    assertEquals(constants.HIT_RADIUS, 30, "dash collision radius")
    assertEquals(constants.ECHO_DELAY_FRAMES, 12, "echo delay")
    assertEquals(constants.TRAIL_RADIUS, 40, "base trail radius")
    assertEquals(constants.TRAIL_INTERVAL_FRAMES, 4, "trail interval")
    assertEquals(constants.TRAIL_LIFETIME_FRAMES, 150, "five-second trail lifetime")
    assertEquals(constants.WIND_IMPULSE, 8, "wind impulse")
    assertEquals(constants.WIND_SPEED_CAP, 12, "wind speed cap")
    assertEquals(constants.CHEW_APPROACH_RADIUS, 80, "chew windup radius")
    assertEquals(constants.CHEW_LUNGE_DISTANCE, 72, "chew lunge distance")
    assertEquals(constants.CHEW_LUNGE_SPEED, 12, "chew lunge speed")
    assertEquals(constants.CHEW_HIT_RADIUS, 24, "chew capsule radius")
    assertEquals(constants.CHEW_PATH_REFRESH_FRAMES, 12, "chew path refresh interval")
    assertEquals(constants.CHEW_PAUSE_FRAMES, 20, "chew pause")
    assertNear(constants.DOG_VISUAL_SCALE, 0.5, 0.000001, "dog visual scale")
    assertNear(constants.ECHO_VISUAL_SCALE, 0.5, 0.000001, "echo visual scale")
    assertNear(constants.TRAIL_VISUAL_SCALE, 0.5, 0.000001, "trail visual scale")
    assertEquals(constants.CHARGE_BAR_HEAD_OFFSET_X, -8, "chargebar horizontal offset")

    assertNear(api.GetChargeSeconds(2.73), 0.5, 0.000001, "2.73 tears gives half a second")
    assertEquals(api.GetChargeFrames(2.73), 15, "half a second is fifteen 30 Hz update frames")
    assertNear(api.GetChargeSeconds(27.3), 0.1, 0.000001, "charge duration is clamped to 0.1 seconds")
    assertEquals(api.GetChargeFrames(27.3), 3, "minimum charge is three update frames")
    assertEquals(api.GetChargeFrames(1), 41, "charge frames round upward")

    local direction, remembered = api.ResolveDirection(Vector(0, -3), Vector(1, 0), false)
    assertVectorNear(direction, 0, -1, 0.000001, "current movement direction")
    assertVectorNear(remembered, 0, -1, 0.000001, "current movement updates history")
    direction, remembered = api.ResolveDirection(Vector(0, 0), Vector(0, -1), false)
    assertVectorNear(direction, 0, -1, 0.000001, "stationary player uses last movement")
    direction = api.ResolveDirection(Vector(0, 0), nil, false)
    assertVectorNear(direction, 1, 0, 0.000001, "no movement history falls back right")
    direction = api.ResolveDirection(Vector(1, 0), Vector(0, 1), true)
    assertVectorNear(direction, -1, 0, 0.000001, "Wind Charge Rod reverses the resolved direction")

    for _, state in ipairs({
        "charging", "dash", "echo_wait", "echo", "chew",
        "bite_windup", "bite_lunge", "bite_recover", "chew_pause"
    }) do
        assertEquals(api.IsBusy(state), true, state .. " should block another launch")
    end
    assertEquals(api.IsBusy("follow"), false, "follow state permits a launch")
    assertEquals(api.IsBusy("chew_seek"), false, "chase yields to a successful explicit launch")
end

local function test_custom_chargebar_and_active_slot_state_machine()
    local previousSpawn = Isaac.Spawn
    local previousGetPtrHash = GetPtrHash
    local previousActionPressed = Input.IsActionPressed
    local previousVectorConstructor = Vector
    local previousGetSoundIdByName = Isaac.GetSoundIdByName
    local previousSFXManager = SFXManager
    local playedSounds = {}
    local soundIds = {
        [api.SoundNames.Charge] = 9101,
        [api.SoundNames.Release] = 9102,
    }
    Isaac.GetSoundIdByName = function(name)
        return soundIds[name] or -1
    end
    local manager = {}
    function manager:Play(soundId, volume, frameDelay, loop, pitch)
        playedSounds[#playedSounds + 1] = {
            id = soundId,
            volume = volume,
            frameDelay = frameDelay,
            loop = loop,
            pitch = pitch,
        }
    end
    SFXManager = function() return manager end
    local function soundCount(soundId)
        local count = 0
        for _, call in ipairs(playedSounds) do
            if call.id == soundId then count = count + 1 end
        end
        return count
    end
    local function soundCalls(soundId)
        local calls = {}
        for _, call in ipairs(playedSounds) do
            if call.id == soundId then
                calls[#calls + 1] = call
            end
        end
        return calls
    end
    local spawnSerial = 0
    local spawnVelocityWasNative = nil
    createdChargeSprites = {}
    Vector = setmetatable({}, {
        __call = function(_, x, y)
            local value = previousVectorConstructor(x, y)
            value._nativeVector = true
            return value
        end,
    })
    GetPtrHash = function(entity)
        return entity and entity._ptrHash or tostring(entity)
    end
    Isaac.Spawn = function(entityType, variant, subType, position, velocity, spawner)
        spawnVelocityWasNative = velocity and velocity._nativeVector == true
        spawnSerial = spawnSerial + 1
        local data = {}
        local entitySprite = {
            FlipX = false,
            IsPlaying = function() return false end,
            Play = function() end,
        }
        local effect = {
            Type = entityType,
            Variant = variant,
            SubType = subType,
            Position = position,
            Velocity = velocity,
            SpawnerEntity = spawner,
            removed = false,
            _ptrHash = "charge-effect:" .. tostring(spawnSerial),
        }
        function effect:Exists() return not self.removed end
        function effect:GetData() return data end
        function effect:GetSprite() return entitySprite end
        function effect:ToEffect() return self end
        function effect:Remove() self.removed = true end
        return effect
    end

    api.ResetForTest("custom-chargebar")
    local passiveOnly = makePlayer(3100, {
        collectibles = { [api.ItemId] = 1 },
    })
    assertEquals(api.HasBigDogActive(passiveOnly), false,
        "inventory ownership without an active-slot copy must not enable Big Dog Bark")
    api.Callbacks.PlayerUpdate(nil, passiveOnly)
    assertEquals(runtime.players[tostring(passiveOnly.InitSeed)].dog, nil,
        "inventory ownership without an active-slot copy must not spawn the dog")

    local player = makePlayer(3101, {
        position = Vector(140, 120),
        movement = Vector(1, 0),
        maxFireDelay = 9,
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = api.ItemId },
    })
    assertEquals(api.HasBigDogActive(player), true,
        "Big Dog Bark in any active slot enables the dog system")
    api.Callbacks.PlayerUpdate(nil, player)
    assertEquals(spawnVelocityWasNative, true,
        "Isaac.Spawn velocity must come from the callable engine Vector constructor")
    local state = runtime.players[tostring(player.InitSeed)]
    assertTruthy(state.dog, "active-slot ownership alone spawns the following dog")

    Input.IsActionPressed = function() return true end
    api.Callbacks.UseItem(nil, api.ItemId, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    assertEquals(state.mode, "charging", "pressing the held active begins manual charge")
    assertEquals(soundCount(soundIds[api.SoundNames.Charge]), 1,
        "entering the charging phase plays the charge cue exactly once")
    assertNear(soundCalls(soundIds[api.SoundNames.Charge])[1].pitch, 1, 0.000001,
        "the first charge cue uses normal playback speed")
    assertEquals(soundCount(soundIds[api.SoundNames.Release]), 0,
        "starting charge must not play the release cue")
    assertEquals(state.chargeReady, false, "new charge starts below the threshold")
    local previousWorldToScreen = Isaac.WorldToScreen
    Isaac.WorldToScreen = function(position)
        return Vector(position.X + 500, position.Y + 300)
    end
    player.PositionOffset = Vector(37, -19)
    api.Callbacks.PlayerRender(nil, player, Vector(200, -100))
    Isaac.WorldToScreen = previousWorldToScreen
    local chargeSprite = assert(state.chargeBarSprite, "first render should lazily cache a chargebar Sprite")
    assertEquals(chargeSprite.loadedPath, "gfx/chargebar.anm2", "chargebar loads the original ANM2")
    assertEquals(chargeSprite.loadCalls, 1, "chargebar ANM2 loads exactly once for this player")
    assertEquals(chargeSprite.animation, "Charging", "incomplete charge renders Charging")
    assertEquals(chargeSprite.frame, 0, "new charge begins at Charging frame zero")
    assertTruthy(#chargeSprite.renderCalls > 0, "chargebar renders while charging")
    local firstRenderPosition = chargeSprite.renderCalls[#chargeSprite.renderCalls]
    local firstRenderArguments = chargeSprite.renderArguments[#chargeSprite.renderArguments]
    assertNear(firstRenderPosition.X,
        player.Position.X + constants.CHARGE_BAR_HEAD_OFFSET_X + 500,
        0.000001,
        "chargebar converts its player-relative world anchor exactly once")
    assertNear(firstRenderPosition.Y,
        player.Position.Y + constants.CHARGE_BAR_HEAD_OFFSET_Y + 300,
        0.000001,
        "chargebar ignores player render offsets after converting the world anchor")
    assertVectorNear(firstRenderArguments.topLeftClamp, 0, 0, 0.000001, "chargebar top-left clamp")
    assertVectorNear(firstRenderArguments.bottomRightClamp, 0, 0, 0.000001, "chargebar bottom-right clamp")

    local previousGame = Game
    local previousRenderMode = RenderMode
    RenderMode = {
        RENDER_WATER_REFRACT = 9101,
        RENDER_WATER_REFLECT = 9102,
    }
    Game = function()
        return {
            GetRoom = function()
                return {
                    GetRenderMode = function()
                        return RenderMode.RENDER_WATER_REFRACT
                    end,
                }
            end,
        }
    end
    local renderCountBeforeRefraction = #chargeSprite.renderCalls
    api.Callbacks.PlayerRender(nil, player, Vector(0, 0))
    assertEquals(#chargeSprite.renderCalls, renderCountBeforeRefraction,
        "chargebar must not render in the water refraction pass")
    Game = previousGame
    RenderMode = previousRenderMode

    local previousProjection = Isaac.WorldToScreen
    Isaac.WorldToScreen = function()
        error("projection failed")
    end
    local renderCountBeforeProjectionFailure = #chargeSprite.renderCalls
    api.Callbacks.PlayerRender(nil, player, Vector(0, 0))
    assertEquals(#chargeSprite.renderCalls, renderCountBeforeProjectionFailure,
        "chargebar must not render when WorldToScreen fails")
    Isaac.WorldToScreen = previousProjection

    api.Callbacks.PlayerRender(nil, player, Vector(0, 0))
    assertEquals(chargeSprite.loadCalls, 1, "render callback must not reload the ANM2")

    local required = state.chargeFrames
    for _ = 1, math.max(1, math.floor(required / 2)) do
        api.Callbacks.PostUpdate()
        api.Callbacks.PlayerUpdate(nil, player)
    end
    api.Callbacks.PlayerRender(nil, player, Vector(0, 0))
    assertEquals(chargeSprite.animation, "Charging", "partial hold remains in Charging")
    assertTruthy(chargeSprite.frame > 0 and chargeSprite.frame < 100,
        "partial hold maps progress into Charging frames 1 through 99")

    while runtime.frame - state.chargeStartFrame < required do
        api.Callbacks.PostUpdate()
        api.Callbacks.PlayerUpdate(nil, player)
    end
    assertEquals(state.mode, "charging", "full charge waits for release instead of auto-firing")
    assertEquals(state.chargeReady, true, "threshold marks the charge ready while held")
    api.Callbacks.PlayerRender(nil, player, Vector(0, 0))
    assertEquals(chargeSprite.animation, "StartCharged", "first full render plays StartCharged")
    chargeSprite.finished.StartCharged = true
    api.Callbacks.PlayerRender(nil, player, Vector(0, 0))
    assertEquals(chargeSprite.animation, "Charged", "completed StartCharged loops Charged")

    api.GetPlayerRecord(player).potionArmed = true
    for _ = 1, 5 do
        api.Callbacks.PostUpdate()
        api.Callbacks.PlayerUpdate(nil, player)
    end
    assertEquals(state.mode, "charging", "holding after full charge still does not auto-fire")
    assertEquals(api.GetPlayerRecord(player).potionArmed, true,
        "holding a full charge does not consume Wind Charge Potion")
    local guard = 0
    while soundCount(soundIds[api.SoundNames.Charge]) < 7 and guard < 120 do
        guard = guard + 1
        api.Callbacks.PostUpdate()
        api.Callbacks.PlayerUpdate(nil, player)
    end
    local acceleratingCalls = soundCalls(soundIds[api.SoundNames.Charge])
    assertEquals(#acceleratingCalls, 7,
        "holding charge continuously replays the charge cue through the capped sequence")
    for index, expectedPitch in ipairs({ 1, 1.2, 1.4, 1.6, 1.8, 2, 2 }) do
        assertNear(acceleratingCalls[index].pitch, expectedPitch, 0.000001,
            "charge cue pitch sequence should accelerate and remain capped")
    end
    player.movement = Vector(-1, 0)
    Input.IsActionPressed = function() return false end
    api.Callbacks.PlayerUpdate(nil, player)
    assertEquals(state.mode, "dash", "releasing a full charge launches the dog")
    assertEquals(soundCount(soundIds[api.SoundNames.Release]), 1,
        "a successful charged launch plays the release cue exactly once")
    assertNear(soundCalls(soundIds[api.SoundNames.Release])[1].pitch, 0.5, 0.000001,
        "a release after the capped 2.0 charge cue plays at reciprocal 0.5 speed")
    assertVectorNear(state.dash.direction, -1, 0, 0.000001,
        "successful release resolves direction from release-time movement")
    assertEquals(api.GetPlayerRecord(player).potionArmed, false,
        "only the successful release consumes Wind Charge Potion")
    local chargeCountAfterLaunch = soundCount(soundIds[api.SoundNames.Charge])
    for _ = 1, 30 do
        api.Callbacks.PostUpdate()
        api.Callbacks.PlayerUpdate(nil, player)
    end
    assertEquals(soundCount(soundIds[api.SoundNames.Charge]), chargeCountAfterLaunch,
        "successful launch stops scheduling charge cue replays")
    api.Callbacks.PlayerRender(nil, player, Vector(0, 0))
    assertEquals(chargeSprite.animation, "Disappear", "successful release dismisses the chargebar")

    local cancelled = makePlayer(3102, {
        movement = Vector(0, 1),
        collectibles = { [api.ItemId] = 1 },
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = api.ItemId },
    })
    api.GetPlayerRecord(cancelled).potionArmed = true
    Input.IsActionPressed = function() return true end
    local chargeCountBeforeCancel = soundCount(soundIds[api.SoundNames.Charge])
    api.Callbacks.UseItem(nil, api.ItemId, nil, cancelled, 0, ActiveSlot.SLOT_PRIMARY, 0)
    assertEquals(soundCount(soundIds[api.SoundNames.Charge]), chargeCountBeforeCancel + 1,
        "each new charge attempt starts its own normal-speed charge cue")
    local cancelledState = runtime.players[tostring(cancelled.InitSeed)]
    api.Callbacks.PlayerRender(nil, cancelled, Vector(0, 0))
    api.Callbacks.PostUpdate()
    api.Callbacks.PlayerUpdate(nil, cancelled)
    Input.IsActionPressed = function() return false end
    api.Callbacks.PlayerUpdate(nil, cancelled)
    assertEquals(cancelledState.mode, "follow", "early release cancels without firing")
    assertEquals(cancelledState.dash, nil, "early release creates no dash")
    assertEquals(soundCount(soundIds[api.SoundNames.Release]), 1,
        "early cancellation must not play another release cue")
    assertEquals(api.GetPlayerRecord(cancelled).potionArmed, true,
        "early release does not consume Wind Charge Potion")
    local chargeCountAfterCancel = soundCount(soundIds[api.SoundNames.Charge])
    for _ = 1, 30 do
        api.Callbacks.PostUpdate()
        api.Callbacks.PlayerUpdate(nil, cancelled)
    end
    assertEquals(soundCount(soundIds[api.SoundNames.Charge]), chargeCountAfterCancel,
        "early cancellation stops scheduling charge cue replays")
    api.Callbacks.PlayerRender(nil, cancelled, Vector(0, 0))
    assertEquals(cancelledState.chargeBarSprite.animation, "Disappear",
        "early release plays Disappear")

    local coop = makePlayer(3103, {
        movement = Vector(0, -1),
        collectibles = { [api.ItemId] = 1 },
        activeItems = { [ActiveSlot.SLOT_SECONDARY] = api.ItemId },
    })
    Input.IsActionPressed = function() return true end
    local chargeCountBeforeCoop = soundCount(soundIds[api.SoundNames.Charge])
    api.Callbacks.UseItem(nil, api.ItemId, nil, coop, 0, ActiveSlot.SLOT_SECONDARY, 0)
    assertEquals(soundCount(soundIds[api.SoundNames.Charge]), chargeCountBeforeCoop + 1,
        "a co-op player starts an independent normal-speed charge sequence")
    api.Callbacks.PlayerRender(nil, coop, Vector(0, 0))
    local coopState = runtime.players[tostring(coop.InitSeed)]
    assertTruthy(coopState.chargeBarSprite ~= chargeSprite,
        "co-op players own independent chargebar Sprite instances")

    coop.activeItems[ActiveSlot.SLOT_SECONDARY] = 0
    api.Callbacks.PlayerUpdate(nil, coop)
    assertEquals(coopState.mode, "follow", "losing the active-slot item cancels unfinished charge")
    assertEquals(coopState.chargeStartFrame, nil, "active-slot loss clears charge timing")

    local rod = makePlayer(3104, {
        movement = Vector(1, 0),
        collectibles = { [api.RodItemId] = 1 },
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = api.ItemId },
    })
    local chargeCountBeforeRod = soundCount(soundIds[api.SoundNames.Charge])
    api.Callbacks.UseItem(nil, api.ItemId, nil, rod, 0, ActiveSlot.SLOT_PRIMARY, 0)
    local rodState = runtime.players[tostring(rod.InitSeed)]
    assertEquals(rodState.mode, "dash", "Wind Charge Rod still launches instantly")
    assertEquals(soundCount(soundIds[api.SoundNames.Charge]), chargeCountBeforeRod,
        "Wind Charge Rod instant launch never starts the charge cue sequence")
    assertEquals(soundCount(soundIds[api.SoundNames.Release]), 2,
        "Wind Charge Rod successful instant launch plays the release cue")
    api.Callbacks.PlayerRender(nil, rod, Vector(0, 0))
    assertEquals(rodState.chargeBarSprite, nil, "Wind Charge Rod instant launch never creates a chargebar")

    Input.IsActionPressed = previousActionPressed
    Isaac.Spawn = previousSpawn
    GetPtrHash = previousGetPtrHash
    Vector = previousVectorConstructor
    Isaac.GetSoundIdByName = previousGetSoundIdByName
    SFXManager = previousSFXManager
end
local function test_active_and_pill_callback_contracts()
    local previousSpawn = Isaac.Spawn
    local previousGetPtrHash = GetPtrHash
    local spawnSerial = 0
    GetPtrHash = function(entity)
        if entity and entity._ptrHash then return entity._ptrHash end
        if type(previousGetPtrHash) == "function" then return previousGetPtrHash(entity) end
        return tostring(entity)
    end
    Isaac.Spawn = function(entityType, variant, subType, position, velocity, spawner)
        spawnSerial = spawnSerial + 1
        local data = {}
        local sprite = {
            FlipX = false,
            IsPlaying = function() return false end,
            Play = function() end,
        }
        local effect = {
            Type = entityType,
            Variant = variant,
            SubType = subType,
            Position = position,
            Velocity = velocity,
            SpawnerEntity = spawner,
            removed = false,
            _ptrHash = "effect:" .. tostring(spawnSerial),
        }
        function effect:Exists() return not self.removed end
        function effect:GetData() return data end
        function effect:GetSprite() return sprite end
        function effect:ToEffect() return self end
        function effect:Remove() self.removed = true end
        return effect
    end
    api.ResetForTest("active-input")
    local player = makePlayer(3001, {
        movement = Vector(0, 1),
        collectibles = { [api.ItemId] = 1 },
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = api.ItemId },
    })
    local result = api.Callbacks.UseItem(nil, api.ItemId, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    assertEquals(type(result), "table", "zero-charge active returns a callback options table")
    assertEquals(result.Discharge, false, "Big Dog Bark never discharges")
    assertEquals(result.Remove, false, "using Big Dog Bark does not remove it")
    assertEquals(result.ShowAnim, false, "charge latch suppresses the vanilla use animation")
    local state = runtime.players[tostring(player.InitSeed)]
    assertEquals(state.mode, "charging", "normal use enters charging")
    local originalDog = state.dog
    local dogWrapper = {
        Position = originalDog.Position,
        Velocity = originalDog.Velocity,
        _ptrHash = originalDog._ptrHash,
    }
    function dogWrapper:Exists() return true end
    function dogWrapper:GetData() return originalDog:GetData() end
    function dogWrapper:GetSprite() return originalDog:GetSprite() end
    function dogWrapper:ToEffect() return self end
    function dogWrapper:Remove() self.removed = true end
    api.Callbacks.UpdateDog(nil, dogWrapper)
    assertEquals(dogWrapper.removed, nil,
        "a second Lua wrapper for the same dog entity must not be removed")
    assertEquals(state.dog, dogWrapper,
        "the current dog wrapper refreshes after pointer-key validation")
    assertEquals(state.mode, "charging", "charging survives the dog effect update")
    api.Callbacks.UseItem(nil, api.ItemId, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    assertEquals(state.mode, "charging", "same-frame repeat callback cannot launch twice")

    api.Callbacks.PlayerUpdate(nil, player)
    assertEquals(state.mode, "follow", "release before charge threshold cancels without firing")

    api.ResetForTest("active-after-chew-unlock")
    local unlockedPlayer = makePlayer(3005, {
        movement = Vector(1, 0),
        collectibles = { [api.ItemId] = 1 },
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = api.ItemId },
    })
    api.GetPlayerRecord(unlockedPlayer).chewUnlocked = true
    local alreadyChewed = makeEnemy(3006, Vector(180, 100), 100)
    api.RegisterRoomTarget(alreadyChewed)
    local unlockedResult = api.Callbacks.UseItem(
        nil, api.ItemId, nil, unlockedPlayer, 0, ActiveSlot.SLOT_PRIMARY, 0
    )
    local unlockedState = runtime.players[tostring(unlockedPlayer.InitSeed)]
    assertEquals(unlockedResult.Discharge, false,
        "chew unlock does not change the zero-charge callback contract")
    assertEquals(unlockedState.mode, "charging",
        "an available chew target must not steal an explicit active use")
    api.Callbacks.UpdateDog(nil, unlockedState.dog)
    assertEquals(unlockedState.mode, "charging",
        "dog update must keep explicit charging ahead of autonomous chew")

    unlockedState.mode = "follow"
    unlockedState.roomChewed[api.EntityKey(alreadyChewed)] = true
    unlockedState.chewSearchPending = true
    local searchesBefore = runtime.chewSearchCount
    api.Callbacks.UpdateDog(nil, unlockedState.dog)
    assertEquals(runtime.chewSearchCount, searchesBefore + 1,
        "no-target autonomous chew searches once when marked dirty")
    for _ = 1, 10 do
        api.Callbacks.UpdateDog(nil, unlockedState.dog)
    end
    assertEquals(runtime.chewSearchCount, searchesBefore + 1,
        "no-target autonomous chew must not rescan the cached room table every frame")

    local newlySpawned = makeEnemy(3007, Vector(200, 100), 100)
    assertEquals(api.RegisterRoomTarget(newlySpawned), true,
        "a newly initialized enemy advances the room target version")
    api.Callbacks.UpdateDog(nil, unlockedState.dog)
    assertEquals(runtime.chewSearchCount, searchesBefore + 2,
        "new enemy initialization permits exactly one new target search")
    assertEquals(api.ResolveEntityReference(unlockedState.chewTarget), newlySpawned,
        "the event-gated search can acquire the newly initialized enemy")

    local removedKey = api.EntityKey(newlySpawned)
    local versionBeforeRemove = runtime.roomTargetVersion
    api.Callbacks.EntityRemove(nil, newlySpawned)
    assertEquals(runtime.roomTargetKeys[removedKey], nil,
        "entity removal releases the cached room key")
    assertEquals(api.ResolveEntityReference(unlockedState.chewTarget), nil,
        "entity removal clears the active chew target reference")
    assertEquals(unlockedState.chewSearchPending, true,
        "entity removal marks autonomous target selection dirty")
    assertEquals(runtime.roomTargetVersion, versionBeforeRemove + 1,
        "entity removal advances the cached target version")

    api.ResetForTest("delayed-eligibility")
    local delayedPlayer = makePlayer(3008, {
        collectibles = { [api.ItemId] = 1 },
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = api.ItemId },
    })
    api.GetPlayerRecord(delayedPlayer).chewUnlocked = true
    api.Callbacks.UseItem(nil, api.ItemId, nil, delayedPlayer, 0, ActiveSlot.SLOT_PRIMARY, 0)
    local delayedState = runtime.players[tostring(delayedPlayer.InitSeed)]
    delayedState.mode = "follow"
    local dormant = makeEnemy(3009, Vector(220, 100), 100)
    dormant.active = false
    function dormant:IsVulnerableEnemy() return self.active and not self.dead end
    function dormant:IsActiveEnemy() return self.active and not self.dead end
    assertEquals(api.RegisterRoomTarget(dormant), true,
        "temporarily inactive NPCs remain cached for later eligibility")
    local delayedSearches = runtime.chewSearchCount
    api.Callbacks.UpdateDog(nil, delayedState.dog)
    assertEquals(runtime.chewSearchCount, delayedSearches + 1,
        "the dirty target cache is searched once")
    for _ = 1, constants.CHEW_SEARCH_RETRY_FRAMES - 1 do
        api.Callbacks.PostUpdate()
        api.Callbacks.UpdateDog(nil, delayedState.dog)
    end
    assertEquals(runtime.chewSearchCount, delayedSearches + 1,
        "an inactive target does not cause per-frame rescans")
    dormant.active = true
    api.Callbacks.PostUpdate()
    api.Callbacks.UpdateDog(nil, delayedState.dog)
    assertEquals(runtime.chewSearchCount, delayedSearches + 2,
        "the low-frequency retry acquires enemies that become active later")
    assertEquals(api.ResolveEntityReference(delayedState.chewTarget), dormant,
        "the fifteenth-frame retry stores the newly eligible target")

    local chargedPlayer = makePlayer(3004, {
        movement = Vector(0, -1),
        maxFireDelay = 9,
        collectibles = { [api.ItemId] = 1 },
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = api.ItemId },
    })
    api.Callbacks.UseItem(nil, api.ItemId, nil, chargedPlayer, 0, ActiveSlot.SLOT_PRIMARY, 0)
    local chargedState = runtime.players[tostring(chargedPlayer.InitSeed)]
    local previousActionPressed = Input.IsActionPressed
    Input.IsActionPressed = function() return true end
    for _ = 1, chargedState.chargeFrames do
        api.Callbacks.PlayerUpdate(nil, chargedPlayer)
        api.Callbacks.PostUpdate()
    end
    Input.IsActionPressed = function() return false end
    api.Callbacks.PlayerUpdate(nil, chargedPlayer)
    Input.IsActionPressed = previousActionPressed
    assertEquals(chargedState.mode, "dash", "release at the charge threshold launches the dog")
    assertVectorNear(chargedState.dash.direction, 0, -1, 0.000001,
        "charged launch freezes the current movement direction")

    local rodPlayer = makePlayer(3002, {
        movement = Vector(1, 0),
        collectibles = { [api.RodItemId] = 1 },
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = api.ItemId },
    })
    result = api.Callbacks.UseItem(nil, api.ItemId, nil, rodPlayer, 0, ActiveSlot.SLOT_PRIMARY, 0)
    assertEquals(result.Discharge, false, "Wind Charge Rod instant use still does not discharge")
    local rodState = runtime.players[tostring(rodPlayer.InitSeed)]
    assertEquals(rodState.mode, "dash", "Wind Charge Rod launches immediately")
    assertVectorNear(rodState.dash.direction, -1, 0, 0.000001, "Wind Charge Rod launch is reversed")

    local pillPlayer = makePlayer(3003)
    assertEquals(api.Callbacks.UsePill(nil, api.PillEffectId, pillPlayer, 0), nil,
        "pill callback follows the void MC_USE_PILL contract")
    assertEquals(api.GetPlayerRecord(pillPlayer).potionArmed, true, "custom pill arms only its user")
    Isaac.Spawn = previousSpawn
    GetPtrHash = previousGetPtrHash
end

local function test_damage_hits_wind_and_echo()
    assertNear(api.ComputeDashDamage(100, 10, 1), 12, 0.000001, "body damage formula")
    assertNear(api.ComputeEchoDamage(100, 10, 1), 6, 0.000001, "echo damage is half body formula")
    assertNear(api.ComputeChewDamage(100), 10, 0.000001, "chew deals ten percent max HP")
    assertNear(api.ComputeDashDamage(100, 10, 1.5), 18, 0.000001, "potion multiplies final body damage")
    assertNear(api.ComputeEchoDamage(100, 10, 1.5), 9, 0.000001, "potion multiplies final echo damage")

    local hitMap = {}
    local enemy = makeEnemy(4001, Vector(100, 100), 100)
    assertEquals(api.RegisterHit(hitMap, enemy), true, "first body contact should settle")
    assertEquals(api.RegisterHit(hitMap, enemy), false, "same dash cannot hit one entity twice")
    assertEquals(api.RegisterHit({}, enemy), true, "echo has an independent hit map")

    local previousEntityRef = EntityRef
    EntityRef = setmetatable({}, {
        __call = function(_, entity)
            return { Entity = entity, nativeEntityRef = true }
        end,
    })
    local owner = makePlayer(4002)
    local retryEnemy = makeEnemy(4003, Vector(100, 100), 100)
    local attempts = 0
    local originalTakeDamage = retryEnemy.TakeDamage
    function retryEnemy:TakeDamage(amount, flags, source, countdown)
        attempts = attempts + 1
        if attempts == 1 then
            error("simulated engine rejection")
        end
        return originalTakeDamage(self, amount, flags, source, countdown)
    end
    local retryMap = {}
    assertEquals(api.DamageOnce(retryMap, retryEnemy, 5, owner), false,
        "a rejected engine damage call must not consume the one-hit slot")
    assertEquals(next(retryMap), nil, "failed damage must leave the hit map untouched")
    assertEquals(api.DamageOnce(retryMap, retryEnemy, 5, owner), true,
        "the same target can be retried after a failed engine damage call")
    assertEquals(retryEnemy.damageSources[1].nativeEntityRef, true,
        "damage must use callable native EntityRef constructors")

    api.ResetForTest("dash-damage-callback")
    local dashPlayer = makePlayer(4004, {
        damage = 10,
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = api.ItemId },
    })
    local dash = assert(api.Launch(dashPlayer, Vector(1, 0), { startPosition = Vector(0, 0) }))
    dash.traveled = 1
    local dogData = {
        NeverbirthBigDogDog = true,
        NeverbirthBigDogOwnerKey = tostring(dashPlayer.InitSeed),
    }
    local dogSprite = {
        IsPlaying = function() return false end,
        Play = function() end,
    }
    local dog = {
        Position = Vector(1, 0),
        Velocity = Vector(0, 0),
        InitSeed = 4005,
    }
    function dog:Exists() return true end
    function dog:GetData() return dogData end
    function dog:GetSprite() return dogSprite end
    local dashState = runtime.players[tostring(dashPlayer.InitSeed)]
    dashState.dog = dog
    local dashEnemy = makeEnemy(4006, Vector(12, 0), 100)
    local previousFindInRadius = Isaac.FindInRadius
    Isaac.FindInRadius = function() return { dashEnemy } end
    api.Callbacks.UpdateDog(nil, dog)
    Isaac.FindInRadius = previousFindInRadius
    assertNear(dashEnemy.damageCalls[1], api.ComputeDashDamage(100, 10, 1), 0.000001,
        "the registered dog effect update must inflict dash damage")
    assertEquals(dashEnemy.damageSources[1].nativeEntityRef, true,
        "the registered dog effect update must pass a native EntityRef")
    EntityRef = previousEntityRef

    assertNear(api.PointSegmentDistanceSquared(Vector(50, 10), Vector(0, 0), Vector(100, 0)), 100, 0.000001,
        "dash collision measures distance to the swept segment")

    local velocity = api.ApplyVelocityImpulse(Vector(10, 0), Vector(1, 0), 8, 12)
    assertVectorNear(velocity, 12, 0, 0.000001, "wind impulse is capped")
    velocity = api.ApplyVelocityImpulse(Vector(0, 0), Vector(0, -1), 8, 12)
    assertVectorNear(velocity, 0, -8, 0.000001, "wind follows the frozen dash direction")

    api.ResetForTest("echo-path")
    local player = makePlayer(5001, { damage = 10 })
    local dash = assert(api.Launch(player, Vector(1, 0), {
        startPosition = Vector(40, 60),
        potionMultiplier = 1,
        hasEchoShard = true,
    }), "idle dog should launch")
    assertVectorNear(dash.startPosition, 40, 60, 0.000001, "dash freezes its start")
    assertVectorNear(dash.endPosition, 360, 60, 0.000001, "dash freezes its 320-pixel endpoint")
    local echo = assert(api.CreateEchoFromDash(dash), "Echo Shard should create replay data")
    assertVectorNear(echo.startPosition, 40, 60, 0.000001, "echo starts at original start")
    assertVectorNear(echo.endPosition, 360, 60, 0.000001, "echo replays original endpoint")
    assertEquals(echo.readyFrame - echo.createdFrame, 12, "echo waits twelve update frames")
end
local function test_pollution_trails_require_echo_shard()
    api.ResetForTest("trail-requires-echo-shard")
    local plainPlayer = makePlayer(5101, {
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = api.ItemId },
    })
    local plainDash = assert(api.Launch(plainPlayer, Vector(1, 0), {
        startPosition = Vector(0, 0),
    }), "base Big Dog Bark should launch")
    assertEquals(plainDash.hasEchoShard, false,
        "a launch without Echo Shard freezes the shard state as disabled")
    assertEquals(plainDash.trailEnabled, false,
        "base Big Dog Bark must not enable pollution trails")
    local plainDog, _, plainData = makeDogEffect(5102, Vector(0, 0))
    plainData.NeverbirthBigDogOwnerKey = tostring(plainPlayer.InitSeed)
    runtime.players[tostring(plainPlayer.InitSeed)].dog = plainDog
    api.Callbacks.UpdateDog(nil, plainDog)
    assertEquals(#runtime.trails, 0,
        "a base dash without Echo Shard must leave no pollution trail")
    plainPlayer.collectibles[api.EchoItemId] = 1
    for _ = 1, 20 do
        api.Callbacks.UpdateDog(nil, plainDog)
    end
    assertEquals(plainDash.hasEchoShard, false,
        "acquiring Echo Shard during a dash must not change the launch snapshot")
    assertEquals(#runtime.trails, 0, "a launch without Echo Shard stays trail-free until it ends")

    api.ResetForTest("trail-enabled-by-echo-shard")
    local echoPlayer = makePlayer(5111, {
        collectibles = { [api.EchoItemId] = 1 },
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = api.ItemId },
    })
    local echoDash = assert(api.Launch(echoPlayer, Vector(1, 0), {
        startPosition = Vector(0, 0),
    }), "Echo Shard Big Dog Bark should launch")
    assertEquals(echoDash.hasEchoShard, true,
        "a launch with Echo Shard freezes the shard state as enabled")
    assertEquals(echoDash.trailEnabled, true,
        "Echo Shard enables pollution trails for the body dash")
    local echoDog, _, echoData = makeDogEffect(5112, Vector(0, 0))
    echoData.NeverbirthBigDogOwnerKey = tostring(echoPlayer.InitSeed)
    runtime.players[tostring(echoPlayer.InitSeed)].dog = echoDog
    api.Callbacks.UpdateDog(nil, echoDog)
    assertEquals(#runtime.trails, 1,
        "a body dash with Echo Shard leaves pollution trail")
    echoPlayer.collectibles[api.EchoItemId] = nil
    for _ = 1, 20 do
        api.Callbacks.UpdateDog(nil, echoDog)
    end
    assertEquals(echoDash.hasEchoShard, true,
        "losing Echo Shard during a dash must not revoke the launch snapshot")
    assertTruthy(#runtime.trails >= 1, "a launch with Echo Shard keeps its trails until it ends")
end


local function test_potion_consumes_only_on_successful_launch_and_isolated_per_player()
    api.ResetForTest("potion")
    local first = makePlayer(6001)
    local second = makePlayer(6002)
    assertEquals(api.UseWindPill(first), true, "first pill arms the next successful launch")
    assertEquals(api.UseWindPill(first), false, "repeat pill is a no-op")
    assertEquals(api.GetPlayerRecord(first).potionArmed, true, "first player is armed")
    assertEquals(api.GetPlayerRecord(second).potionArmed, false, "co-op player is not armed")

    local rejected = api.Launch(first, Vector(1, 0), { busy = true, startPosition = Vector(0, 0) })
    assertEquals(rejected, nil, "busy dog refuses launch")
    assertEquals(api.GetPlayerRecord(first).potionArmed, true, "rejected launch must not consume potion")

    local dash = assert(api.Launch(first, Vector(1, 0), { startPosition = Vector(0, 0) }),
        "valid launch should succeed")
    assertEquals(api.GetPlayerRecord(first).potionArmed, false, "successful launch consumes potion")
    assertEquals(dash.damageMultiplier, 1.5, "potion freezes a 1.5 damage multiplier")
    assertEquals(dash.distance, 480, "potion freezes a 1.5 distance multiplier")
    assertEquals(dash.trailRadius, 60, "potion freezes a 1.5 trail radius")
    assertEquals(dash.windImpulse, 8, "potion adds strong wind")
end

local function test_cross_owner_trails_deal_one_highest_hit_per_enemy_per_frame()
    api.ResetForTest("trail")
    local weak = makePlayer(7001, { damage = 4 })
    local strong = makePlayer(7002, { damage = 10 })
    local weakTrail = api.SpawnOrRefreshTrail(weak, Vector(100, 100), 40, 50)
    local sameTrail = api.SpawnOrRefreshTrail(strong, Vector(180, 100), 60, 70)
    assertEquals(sameTrail, weakTrail, "overlapping trails merge even across owners")
    assertEquals(sameTrail.radius, 60, "merged trail keeps the largest radius")
    assertEquals(sameTrail.expiresFrame, 220, "overlap refreshes the full 150-frame lifetime")
    assertEquals(#sameTrail.nodes, 2, "overlap extends one logical trail with a second visual node")
    assertVectorNear(sameTrail.nodes[1].position, 100, 100, 0.000001, "first visual node keeps its coverage")
    assertVectorNear(sameTrail.nodes[2].position, 180, 100, 0.000001, "new visual node preserves extended coverage")
    assertEquals(#runtime.trails, 1, "overlap remains one logical damage source")

    local enemy = makeEnemy(7003, Vector(110, 100), 100)
    api.SubmitTrailCandidates(sameTrail, 80, { enemy })
    api.SubmitTrailCandidates(sameTrail, 80, { enemy })
    assertEquals(api.ApplyTrailCandidates(80), 1, "one enemy settles once for the frame")
    assertEquals(#enemy.damageCalls, 1, "overlap must create only one damage event")
    assertNear(enemy.damageCalls[1], 0.10, 0.000001, "highest current owner damage wins")
    assertEquals(enemy.slowCalls, 1, "overlap applies native slowing only once")
    assertEquals(api.ApplyTrailCandidates(80), 0, "same frame cannot settle twice")
end

local function test_real_food_pickups_unlock_chew_and_ignore_inventory_reconciliation()
    api.ResetForTest("food")
    ItemConfig = ItemConfig or {}
    ItemConfig.TAG_FOOD = ItemConfig.TAG_FOOD or 1
    local originalGetItemConfig = Isaac.GetItemConfig
    Isaac.GetItemConfig = function()
        return {
            GetCollectible = function(_, itemId)
                return {
                    ID = itemId,
                    HasTags = function(_, tag) return tag == ItemConfig.TAG_FOOD end,
                }
            end,
        }
    end

    local first = makePlayer(8001)
    local second = makePlayer(8002)
    first.collectibles[900] = 3
    api.SettleFoodPickups(1)
    assertEquals(api.GetPlayerRecord(first).foodPickups, 0,
        "initial inventory and sourceless reconciliation do not count")

    local queuedPlayer = makePlayer(8003)
    local queuedPickup = makePickup(8050, 900)
    api.Callbacks.PrePickupCollision(nil, queuedPickup, queuedPlayer, false)
    queuedPlayer.queuedItemId = 900
    assertEquals(api.SettleFoodPickups(constants.FOOD_SETTLE_TIMEOUT_FRAMES + 5), 0,
        "a real queued pickup must survive beyond the false-collision timeout")
    assertTruthy(next(runtime.pendingFood),
        "queued food remains pending while the pickup animation still owns the item")
    queuedPickup.removed = true
    queuedPlayer.queuedItemId = nil
    assertEquals(api.SettleFoodPickups(constants.FOOD_SETTLE_TIMEOUT_FRAMES + 6), 1,
        "queued food settles once after the queue flushes and its pedestal is gone")
    assertEquals(api.GetPlayerRecord(queuedPlayer).foodPickups, 1,
        "long queued pickup contributes exactly one food event")
    assertEquals(api.SettleFoodPickups(constants.FOOD_SETTLE_TIMEOUT_FRAMES + 7), 0,
        "a settled queued pickup cannot be counted twice")

    local cancelledPlayer = makePlayer(8004)
    local cancelledPickup = makePickup(8051, 900)
    api.Callbacks.PrePickupCollision(nil, cancelledPickup, cancelledPlayer, false)
    cancelledPlayer.queuedItemId = 900
    assertEquals(api.SettleFoodPickups(2), 0,
        "seeing the queued item alone does not count before pickup completion")
    cancelledPlayer.queuedItemId = nil
    assertEquals(api.SettleFoodPickups(3), 0,
        "a cancelled queue whose pedestal remains does not count")
    assertEquals(api.GetPlayerRecord(cancelledPlayer).foodPickups, 0,
        "cancelled queue leaves food progress unchanged")
    assertEquals(next(runtime.pendingFood), nil,
        "cancelled queue is removed instead of lingering indefinitely")

    for index = 1, 4 do
        local pickup = makePickup(8100 + index, 900)
        assertEquals(api.Callbacks.PrePickupCollision(nil, pickup, first, false), nil,
            "food pedestal collision must never cancel the pickup")
        first.collectibles[900] = first.collectibles[900] + 1
        pickup.removed = true
        assertEquals(api.SettleFoodPickups(index * 3), 1, "confirmed pedestal pickup settles once")
        assertEquals(api.CaptureFoodPickup(pickup, first, index * 3), false,
            "same pedestal instance cannot be captured twice")
    end
    assertEquals(api.GetPlayerRecord(first).foodPickups, 4, "four distinct real pickups are counted")
    assertEquals(api.GetPlayerRecord(first).chewUnlocked, true, "four food pickups permanently unlock chew")
    assertEquals(api.GetPlayerRecord(second).foodPickups, 0, "co-op food progress is isolated")
    assertEquals(api.GetPlayerRecord(second).chewUnlocked, false, "co-op unlock is isolated")
    Isaac.GetItemConfig = originalGetItemConfig
end

local function test_chew_selection_pause_and_room_lifecycle()
    api.ResetForTest("chew")
    local player = makePlayer(9001, { position = Vector(0, 0) })
    local nearest = makeEnemy(9002, Vector(20, 0), 100)
    local farther = makeEnemy(9003, Vector(80, 0), 200)
    local selected = api.SelectChewTarget(player, { farther, nearest })
    assertEquals(selected, nearest, "chew selects the nearest eligible unchewed target")

    local friendly = makeEnemy(9004, Vector(5, 0), 100)
    function friendly:HasEntityFlags(flag)
        return flag == EntityFlag.FLAG_FRIENDLY
    end
    assertEquals(api.SelectChewTarget(player, { friendly }), nil,
        "an enemy with only the friendly flag is excluded")

    local charmed = makeEnemy(9005, Vector(5, 0), 100)
    function charmed:HasEntityFlags(flag)
        return flag == EntityFlag.FLAG_CHARM
    end
    assertEquals(api.SelectChewTarget(player, { charmed }), nil,
        "an enemy with only the charm flag is excluded")

    local changingAllegiance = makeEnemy(9006, Vector(10, 0), 100)
    changingAllegiance.friendly = true
    function changingAllegiance:HasEntityFlags(flag)
        return self.friendly and flag == EntityFlag.FLAG_FRIENDLY
    end
    assertEquals(api.RegisterRoomTarget(changingAllegiance), true,
        "a friendly NPC is cached without becoming an eligible chew target")
    assertEquals(api.SelectChewTarget(player, { changingAllegiance }), nil,
        "the current friendly flag blocks selection")
    changingAllegiance.friendly = false
    assertEquals(api.SelectChewTarget(player, { changingAllegiance }), changingAllegiance,
        "a cached NPC can become eligible after losing the friendly flag")

    local state = { mode = "chew" }
    api.BeginChewPause(state, 100)
    assertEquals(state.mode, "chew_pause", "completed chew enters pause")
    assertEquals(api.IsChewPauseComplete(state, 119), false, "pause lasts all twenty frames")
    assertEquals(api.IsChewPauseComplete(state, 120), true, "pause ends on the twentieth frame")

    local record = api.GetPlayerRecord(player)
    record.foodPickups = 4
    record.chewUnlocked = true
    record.potionArmed = true
    local playerState = runtime.players[tostring(player.InitSeed)]
    playerState.roomChewed = { [nearest.InitSeed] = true }
    playerState.mode = "dash"
    playerState.chewPath = { Vector(20, 20) }
    playerState.chewLungeDirection = Vector(1, 0)
    playerState.chewLungeStart = Vector(0, 0)
    playerState.chewHitConsumed = true
    playerState.chewSafePosition = Vector(10, 10)
    playerState.nextChewSafeFrame = 50
    api.Callbacks.NewRoom()
    assertEquals(next(runtime.players[tostring(player.InitSeed)].roomChewed), nil,
        "new room clears only per-room chew marks")
    assertEquals(runtime.players[tostring(player.InitSeed)].mode, "follow",
        "new room clears transient dog activity")
    assertEquals(playerState.chewPath, nil, "new room clears cached chew paths")
    assertEquals(playerState.chewLungeDirection, nil, "new room clears a locked lunge direction")
    assertEquals(playerState.chewLungeStart, nil, "new room clears a locked lunge origin")
    assertEquals(playerState.chewHitConsumed, false, "new room clears BiteHit consumption")
    assertEquals(playerState.chewSafePosition, nil, "new room clears the previous room safe point")
    assertEquals(playerState.nextChewSafeFrame, 0, "new room resets safe-point timing")

    assertEquals(record.foodPickups, 4, "new room preserves run food progress")
    assertEquals(record.chewUnlocked, true, "new room preserves chew unlock")
    assertEquals(record.potionArmed, true, "new room preserves armed potion")

    api.Callbacks.NewLevel()
    assertEquals(record.chewUnlocked, true, "new floor preserves run chew unlock")
    assertEquals(record.potionArmed, true, "new floor preserves armed potion")
    api.Callbacks.PreGameExit()
    assertEquals(runtime.savedAtExit, true, "exit callback saves run-owned state")
end


local function test_mature_chew_events_pathing_and_retry_contract()
    api.ResetForTest("mature-chew")
    local player = makePlayer(9101, {
        position = Vector(0, 0),
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = api.ItemId },
    })
    api.GetPlayerRecord(player).chewUnlocked = true
    local target = makeEnemy(9102, Vector(70, 0), 100)
    assertEquals(api.RegisterRoomTarget(target), true, "mature chew target should enter the room cache")
    api.SelectChewTarget(player, { target })
    local state = runtime.players[tostring(player.InitSeed)]
    local dog, sprite = makeDogEffect(9103, Vector(0, 0))
    state.dog = dog
    state.chewSearchPending = true

    api.UpdateChew(state, dog, player)
    assertEquals(state.mode, "bite_windup", "approach radius begins event-driven bite windup")
    assertEquals(sprite.animation, "BiteHorizontal", "windup chooses a directional Bite animation")
    assertEquals(#target.damageCalls, 0, "windup must not deal contact damage")

    target.Position = Vector(0, 60)
    api.UpdateChew(state, dog, player)
    assertEquals(state.mode, "bite_windup", "target movement does not skip the bite telegraph")
    assertEquals(sprite.animation, "BiteHorizontal",
        "bite windup keeps its entry direction instead of restarting another directional animation")
    assertVectorNear(state.chewWindupDirection, 1, 0, 0.000001,
        "bite windup direction is locked when the telegraph begins")
    sprite:TriggerEvent("BiteLungeStart")
    api.UpdateChew(state, dog, player)
    assertEquals(state.mode, "bite_lunge", "BiteLungeStart locks the lunge state")
    assertVectorNear(state.chewLungeDirection, 1, 0, 0.000001,
        "the lunge follows the telegraphed direction even if the target moves")
    target.Position = Vector(60, 0)
    for _ = 1, 5 do api.UpdateChew(state, dog, player) end
    assertVectorNear(state.chewLungeDirection, 1, 0, 0.000001,
        "target movement after lunge start cannot rotate the locked path")
    assertEquals(#target.damageCalls, 0, "movement alone cannot replace the BiteHit event")

    target.Position = Vector(60, 0)
    sprite:TriggerEvent("BiteHit")
    api.UpdateChew(state, dog, player)
    assertEquals(state.mode, "bite_recover", "BiteHit enters recovery")
    assertNear(target.damageCalls[1], 10, 0.000001, "accepted bite deals ten percent maximum HP")
    assertEquals(state.roomChewed[api.EntityKey(target)], true,
        "only an accepted non-zero bite marks the target chewed")
    sprite:TriggerEvent("BiteHit")
    api.UpdateChew(state, dog, player)
    assertEquals(#target.damageCalls, 1, "one bite cannot consume BiteHit twice")

    target.dead = true
    sprite:TriggerEvent("BiteEnd")
    api.UpdateChew(state, dog, player)
    assertEquals(state.mode, "chew_pause", "BiteEnd completes recovery even after the target disappears")
    assertEquals(state.chewPauseUntil - runtime.frame, constants.CHEW_PAUSE_FRAMES,
        "successful bite enforces the full twenty-frame pause")

    api.ResetForTest("no-frame-fallback")
    local fallbackPlayer = makePlayer(9110)
    api.GetPlayerRecord(fallbackPlayer).chewUnlocked = true
    local fallbackTarget = makeEnemy(9111, Vector(60, 0), 100)
    api.RegisterRoomTarget(fallbackTarget)
    api.SelectChewTarget(fallbackPlayer, { fallbackTarget })
    local fallbackState = runtime.players[tostring(fallbackPlayer.InitSeed)]
    local fallbackDog, fallbackSprite = makeDogEffect(9112, Vector(0, 0))
    fallbackState.dog = fallbackDog
    fallbackState.chewSearchPending = true
    api.UpdateChew(fallbackState, fallbackDog, fallbackPlayer)
    fallbackSprite.frame = 17
    api.UpdateChew(fallbackState, fallbackDog, fallbackPlayer)
    assertEquals(fallbackState.mode, "bite_windup",
        "animation frame numbers must not silently replace missing ANM2 events")
    assertEquals(#fallbackTarget.damageCalls, 0, "missing BiteHit event never deals damage")

    api.ResetForTest("rejected-bite")
    local rejectedPlayer = makePlayer(9120)
    api.GetPlayerRecord(rejectedPlayer).chewUnlocked = true
    local rejectedTarget = makeEnemy(9121, Vector(60, 0), 100)
    local rejectedAttempts = 0
    function rejectedTarget:TakeDamage()
        rejectedAttempts = rejectedAttempts + 1
        return false
    end
    api.RegisterRoomTarget(rejectedTarget)
    api.SelectChewTarget(rejectedPlayer, { rejectedTarget })
    local rejectedState = runtime.players[tostring(rejectedPlayer.InitSeed)]
    local rejectedDog, rejectedSprite = makeDogEffect(9122, Vector(0, 0))
    rejectedState.dog = rejectedDog
    rejectedState.chewSearchPending = true
    api.UpdateChew(rejectedState, rejectedDog, rejectedPlayer)
    rejectedSprite:TriggerEvent("BiteLungeStart")
    api.UpdateChew(rejectedState, rejectedDog, rejectedPlayer)
    for _ = 1, 3 do api.UpdateChew(rejectedState, rejectedDog, rejectedPlayer) end
    rejectedSprite:TriggerEvent("BiteHit")
    api.UpdateChew(rejectedState, rejectedDog, rejectedPlayer)
    assertEquals(rejectedAttempts, 1,
        "BiteHit should attempt one positive damage event against the locked target")
    assertEquals(rejectedState.roomChewed[api.EntityKey(rejectedTarget)], nil,
        "an engine-rejected bite must remain eligible for a later retry")

    api.ResetForTest("chase-inertia")
    local chasePlayer = makePlayer(9130, { position = Vector(0, 0) })
    api.GetPlayerRecord(chasePlayer).chewUnlocked = true
    local chaseTarget = makeEnemy(9131, Vector(200, 0), 100)
    api.RegisterRoomTarget(chaseTarget)
    local chaseState = runtime.players[tostring(chasePlayer.InitSeed)]
    local chaseDog = makeDogEffect(9132, Vector(0, 0))
    chaseState.dog = chaseDog
    chaseState.chewSearchPending = true
    api.UpdateChew(chaseState, chaseDog, chasePlayer)
    local firstStep = chaseDog.Position.X
    api.UpdateChew(chaseState, chaseDog, chasePlayer)
    local secondStep = chaseDog.Position.X - firstStep
    assertTruthy(secondStep > firstStep,
        "direct pursuit keeps its smoothed velocity instead of restarting acceleration every frame")

    local room = { blocked = { [12] = true } }
    function room:GetGridWidth() return 5 end
    function room:GetGridSize() return 25 end
    function room:GetGridIndex(position)
        return math.floor(position.Y / 40) * 5 + math.floor(position.X / 40)
    end
    function room:GetGridPosition(index)
        return Vector((index % 5) * 40, math.floor(index / 5) * 40)
    end
    function room:GetGridCollision(index)
        return self.blocked[index] and 3 or 0
    end
    local path = api.BuildChewGridPath(room, Vector(0, 80), Vector(160, 80))
    assertTruthy(path and #path >= 3, "blocked direct route should produce a cached grid detour")
    for _, node in ipairs(path) do
        assertEquals(node.X == 80 and node.Y == 80, false, "grid path must not enter a blocked cell")
    end

    local previousGame = Game
    local sealedRoom = {}
    function sealedRoom:CheckLine() return false end
    function sealedRoom:GetGridWidth() return 3 end
    function sealedRoom:GetGridSize() return 3 end
    function sealedRoom:GetGridIndex(position) return position.X < 100 and 0 or 2 end
    function sealedRoom:GetGridPosition(index) return Vector(index * 40, 0) end
    function sealedRoom:GetGridCollision(index) return index == 1 and 3 or (index == 0 and 3 or 0) end
    Game = function() return { GetRoom = function() return sealedRoom end } end
    api.ResetForTest("chew-rescue")
    local rescuePlayer = makePlayer(9140, { position = Vector(300, 0) })
    api.GetPlayerRecord(rescuePlayer).chewUnlocked = true
    local rescueTarget = makeEnemy(9141, Vector(200, 0), 100)
    api.RegisterRoomTarget(rescueTarget)
    local rescueState = runtime.players[tostring(rescuePlayer.InitSeed)]
    local rescueDog = makeDogEffect(9142, Vector(0, 0))
    rescueState.dog = rescueDog
    rescueState.chewSafePosition = Vector(10, 10)
    rescueState.nextChewSafeFrame = 999
    rescueState.chewSearchPending = true
    for attempt = 1, constants.CHEW_PATH_FAILURE_LIMIT do
        api.UpdateChew(rescueState, rescueDog, rescuePlayer)
        if attempt < constants.CHEW_PATH_FAILURE_LIMIT then
            for _ = 1, constants.CHEW_PATH_REFRESH_FRAMES do api.Callbacks.PostUpdate() end
        end
    end
    assertVectorNear(rescueDog.Position, 10, 10, 0.000001,
        "repeated path failures rescue the dog to its last saved safe position")
    Game = previousGame

    local pathState = {}
    assertEquals(api.ShouldRefreshChewPath(pathState, "target", 0, false), true,
        "missing path refreshes immediately")
    pathState.chewPath = path
    pathState.chewPathTargetKey = "target"
    pathState.nextChewPathFrame = 12
    assertEquals(api.ShouldRefreshChewPath(pathState, "target", 11, false), false,
        "cached path is reused before twelve frames")
    assertEquals(api.ShouldRefreshChewPath(pathState, "target", 12, false), true,
        "cached path refreshes on the twelfth frame")
    assertEquals(api.ShouldRefreshChewPath(pathState, "other", 1, false), true,
        "target change invalidates the cached path")
    assertEquals(api.ShouldRefreshChewPath(pathState, "target", 1, true), true,
        "a newly blocked route invalidates the cached path")
end
local function test_source_has_no_hot_global_scans()
    local module = readFile("big_dog_bark.lua")
    assertEquals(module:find("GetCollectibles", 1, true), nil,
        "food pickup tracking must not enumerate global ItemConfig")
    assertEquals(module:find("MC_POST_ADD_COLLECTIBLE", 1, true), nil,
        "ordinary Repentance implementation must not depend on an extension callback")
    assertTruthy(module:find("FindInRadius", 1, true),
        "dash and trail collision should use local radius queries")

    local effectUpdateStart = assert(module:find("local function updateDog", 1, true),
        "dog effect update should exist")
    local effectUpdateEnd = assert(module:find("local function movementInput", effectUpdateStart, true),
        "effect hot-update block should have a stable end marker")
    local effectUpdate = module:sub(effectUpdateStart, effectUpdateEnd - 1)
    assertEquals(effectUpdate:find("GetRoomEntities", 1, true), nil,
        "per-effect hot update must not scan the whole room")
end

test_registration()
test_constants_charge_direction_and_busy()
test_custom_chargebar_and_active_slot_state_machine()
test_active_and_pill_callback_contracts()
test_damage_hits_wind_and_echo()
test_pollution_trails_require_echo_shard()
test_potion_consumes_only_on_successful_launch_and_isolated_per_player()
test_cross_owner_trails_deal_one_highest_hit_per_enemy_per_frame()
test_real_food_pickups_unlock_chew_and_ignore_inventory_reconciliation()
test_chew_selection_pause_and_room_lifecycle()
test_mature_chew_events_pathing_and_retry_contract()
test_source_has_no_hot_global_scans()

print("Big Dog Bark behavior tests passed.")
