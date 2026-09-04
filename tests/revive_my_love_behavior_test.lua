local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, message)
    if not value then
        error(message or "expected a truthy value", 2)
    end
end

ModCallbacks = {
    MC_ENTITY_TAKE_DMG = 1,
    MC_POST_GAME_STARTED = 2,
    MC_PRE_GAME_EXIT = 3,
    MC_POST_EFFECT_UPDATE = 4,
    MC_POST_PLAYER_UPDATE = 5,
}
EntityType = { ENTITY_PLAYER = 1, ENTITY_EFFECT = 1000 }
DamageFlag = { DAMAGE_FAKE = 1, DAMAGE_NOKILL = 2 }

local function makeEngineVector(x, y)
    return { X = x, Y = y, __engineVector = true }
end

Vector = setmetatable({ Zero = makeEngineVector(0, 0) }, {
    __call = function(_, x, y)
        return makeEngineVector(x, y)
    end,
})

Color = setmetatable({}, {
    __call = function(_, ...)
        return { __engineColor = true, values = { ... } }
    end,
})

local function makePlayer(options)
    options = options or {}
    local player = {
        Type = EntityType.ENTITY_PLAYER,
        InitSeed = options.seed or 100,
        collectibleCount = options.collectibleCount or 1,
        hearts = options.hearts == nil and 2 or options.hearts,
        maxHearts = options.maxHearts == nil and 6 or options.maxHearts,
        soulHearts = options.soulHearts or 0,
        boneHearts = options.boneHearts or 0,
        mortal = options.mortal == true,
        otherRevive = options.otherRevive == true,
        dead = options.dead == true,
        removeCalls = 0,
        reviveCalls = 0,
        cooldown = 0,
        Position = makeEngineVector(options.x or 120, options.y or 160),
        colorCalls = 0,
        sprite = {
            animation = options.deathAnimation or "Death",
            finished = options.deathAnimationFinished == true,
        },
    }

    function player:ToPlayer() return self end
    function player:HasCollectible() return self.collectibleCount > 0 end
    function player:GetCollectibleNum() return self.collectibleCount end
    function player:RemoveCollectible()
        self.removeCalls = self.removeCalls + 1
        self.collectibleCount = math.max(0, self.collectibleCount - 1)
    end
    function player:HasMortalDamage() return self.mortal end
    function player:WillPlayerRevive() return self.otherRevive end
    function player:IsDead() return self.dead end
    function player:GetSprite() return self.sprite end
    function player.sprite:GetAnimation() return self.animation end
    function player.sprite:IsFinished(animation)
        return animation == self.animation and self.finished
    end
    function player:Revive()
        self.reviveCalls = self.reviveCalls + 1
        self.dead = false
    end
    function player:GetHearts() return self.hearts end
    function player:GetMaxHearts() return self.maxHearts end
    function player:GetSoulHearts() return self.soulHearts end
    function player:GetBoneHearts() return self.boneHearts end
    function player:AddHearts(amount) self.hearts = self.hearts + amount end
    function player:AddSoulHearts(amount) self.soulHearts = self.soulHearts + amount end
    function player:SetMinDamageCooldown(frames) self.cooldown = frames end
    function player:SetColor(color)
        assertTruthy(color and color.__engineColor, "player SetColor requires an engine Color")
        self.colorCalls = self.colorCalls + 1
    end
    return player
end

local function makeEnvironment()
    local callbacks = {}
    local saveRoot = {}
    local saved = 0
    local sounds = 0
    local spawns = {}
    local runSeed = 12345
    local mod = {}

    Isaac = {
        Spawn = function(entityType, variant, subtype, position, velocity, spawner)
            assertTruthy(position and position.__engineVector,
                "Isaac.Spawn position must be an engine Vector, not a Lua-table lookalike")
            assertTruthy(velocity and velocity.__engineVector,
                "Isaac.Spawn velocity must be an engine Vector, not a Lua-table lookalike")

            local sprite = {
                playCalls = 0,
                animation = nil,
                force = nil,
                finished = false,
            }
            function sprite:Play(animation, force)
                self.playCalls = self.playCalls + 1
                self.animation = animation
                self.force = force
            end
            function sprite:IsFinished(animation)
                return animation == self.animation and self.finished
            end

            local effect = {
                Type = entityType,
                Variant = variant,
                SubType = subtype,
                Position = position,
                SpawnerEntity = spawner,
                sprite = sprite,
                removeCalls = 0,
                colorCalls = 0,
            }
            function effect:GetSprite() return self.sprite end
            function effect:SetColor(color)
                assertTruthy(color and color.__engineColor, "effect SetColor requires an engine Color")
                self.colorCalls = self.colorCalls + 1
            end
            function effect:Remove() self.removeCalls = self.removeCalls + 1 end

            spawns[#spawns + 1] = effect
            return effect
        end,
    }

    function mod:AddCallback(callbackId, fn, variant)
        callbacks[#callbacks + 1] = { id = callbackId, fn = fn, variant = variant }
    end

    local initialize = assert(dofile("revive_my_love.lua"))
    local api = initialize(mod, {
        ItemId = 9001,
        EffectVariant = 3020,
        GetSaveRoot = function() return saveRoot end,
        Save = function() saved = saved + 1 end,
        GetCurrentRunSeed = function() return runSeed end,
        IsIncomingDamageLethal = function(player, amount)
            if player:HasMortalDamage() then return true end
            local total = player:GetHearts() + player:GetSoulHearts() + player:GetBoneHearts() * 2
            return total > 0 and amount >= total
        end,
        PlaySound = function() sounds = sounds + 1 end,
    })

    local function findCallback(callbackId)
        for _, callback in ipairs(callbacks) do
            if callback.id == callbackId then return callback.fn, callback.variant end
        end
        error("missing callback " .. tostring(callbackId), 2)
    end

    return {
        api = api,
        callbacks = callbacks,
        saveRoot = saveRoot,
        getSavedCount = function() return saved end,
        getSoundCount = function() return sounds end,
        getEffectCount = function() return #spawns end,
        getEffect = function(index) return spawns[index] end,
        setRunSeed = function(value) runSeed = value end,
        damage = function(player, amount, flags)
            local callback, variant = findCallback(ModCallbacks.MC_ENTITY_TAKE_DMG)
            assertEquals(variant, EntityType.ENTITY_PLAYER, "damage callback should be filtered to players")
            return callback(mod, player, amount, flags or 0, nil, 0)
        end,
        updatePlayer = function(player)
            local callback = findCallback(ModCallbacks.MC_POST_PLAYER_UPDATE)
            return callback(mod, player)
        end,
        gameStarted = function(continued)
            local callback = findCallback(ModCallbacks.MC_POST_GAME_STARTED)
            return callback(mod, continued == true)
        end,
        updateEffect = function(effect)
            local callback, variant = findCallback(ModCallbacks.MC_POST_EFFECT_UPDATE)
            assertEquals(variant, 3020, "effect callback should be filtered to the registered revive variant")
            return callback(mod, effect)
        end,
    }
end

local function confirmDeath(env, player, animation)
    player.dead = true
    player.hearts = 0
    player.soulHearts = 0
    player.sprite.animation = animation or "Death"
    player.sprite.finished = false
    env.updatePlayer(player)
end

local function finishDeathAnimation(env, player)
    player.sprite.finished = true
    env.updatePlayer(player)
    return env.getEffect(env.getEffectCount())
end

local function test_nonlethal_damage_is_untouched()
    local env = makeEnvironment()
    env.gameStarted(false)
    local player = makePlayer({ hearts = 4 })
    assertEquals(env.damage(player, 1), nil, "ordinary damage must not be cancelled")
    assertEquals(player.removeCalls, 0, "ordinary damage must not consume the item")
    assertEquals(env.getSoundCount(), 0, "ordinary damage must not play revive audio")
end

local function test_lethal_damage_is_allowed_and_only_confirmed_death_consumes_the_item()
    local env = makeEnvironment()
    env.gameStarted(false)
    local player = makePlayer({ hearts = 6, soulHearts = 2, collectibleCount = 2 })

    assertEquals(env.damage(player, 8), nil, "lethal damage must be allowed to kill the player")
    assertEquals(player.removeCalls, 0, "a merely predicted death must not consume the item")
    assertEquals(player.hearts, 6, "the damage callback must not restore or rewrite health")
    assertEquals(env.getSoundCount(), 0, "audio must wait until after the real death animation")
    assertEquals(env.getEffectCount(), 0, "the custom animation must wait until real death finishes")

    confirmDeath(env, player, "Death")
    assertEquals(player.removeCalls, 1, "a confirmed real death should consume exactly one copy")
    assertEquals(player.collectibleCount, 1, "one duplicate should remain")
    assertEquals(player.reviveCalls, 0, "the player must remain truly dead during the death animation")
    assertEquals(player.hearts, 0, "health must not return during the death animation")
    assertEquals(env.getEffectCount(), 0, "the custom animation must not overlap the death animation")

    local effect = finishDeathAnimation(env, player)
    assertEquals(env.getSoundCount(), 1, "revive audio should start with the custom animation")
    assertEquals(env.getEffectCount(), 1, "the custom revive effect should spawn after death finishes")
    assertEquals(player.reviveCalls, 0, "the player must remain dead while the custom animation plays")

    assertEquals(effect.Type, EntityType.ENTITY_EFFECT, "revive visual should be an Effect entity")
    assertEquals(effect.Variant, 3020, "revive visual should use the registered cocoon variant")
    assertEquals(effect.SubType, 0, "revive visual should use subtype zero")
    assertEquals(effect.SpawnerEntity, player, "revive visual should be attributed to the revived player")
    assertEquals(effect.sprite.playCalls, 1, "the registered animation should be started exactly once")
    assertEquals(effect.sprite.animation, "Revive", "the registered Revive animation should play")
    assertEquals(effect.sprite.force, true, "the one-shot animation should restart at frame zero")
    assertEquals(effect.colorCalls, 1, "the world effect should receive the approved pink tint")
    assertEquals(player.colorCalls, 0, "the player flash must wait until the actual revival")

    env.updateEffect(effect)
    assertEquals(player.reviveCalls, 0, "an unfinished custom animation must not revive the player")
    effect.sprite.finished = true
    env.updateEffect(effect)
    assertEquals(player.reviveCalls, 1, "finishing the custom animation should perform one engine revive")
    assertEquals(player.hearts, 2, "the revived player should have one full red heart")
    assertEquals(player.soulHearts, 0, "red-heart revival should not retain a lethal soul-heart layer")
    assertTruthy(player.cooldown >= 1, "the revived player should receive brief invincibility")
    assertEquals(player.colorCalls, 1, "the revived player should receive the approved pink flash")

    assertEquals(env.damage(player, 2), nil, "a second lethal hit in the same run must not be cancelled")
    assertEquals(player.removeCalls, 1, "remaining duplicates must not grant a second revive")
end

local function test_cancelled_lethal_prediction_does_not_consume_or_lock_the_item()
    local env = makeEnvironment()
    env.gameStarted(false)
    local player = makePlayer({ hearts = 2 })
    assertEquals(env.damage(player, 2), nil, "the predicted lethal hit should remain uncancelled")
    env.updatePlayer(player)
    assertEquals(player.removeCalls, 0, "a hit cancelled later in the callback chain must not consume the item")
    assertEquals(env.getEffectCount(), 0, "a surviving player must not start the revive sequence")

    assertEquals(env.damage(player, 2), nil, "the item should be able to arm again on a later real death")
    confirmDeath(env, player, "LostDeath")
    assertEquals(player.removeCalls, 1, "death animations ending in Death should be accepted")
    assertEquals(env.getEffectCount(), 0, "LostDeath must finish before the custom visual starts")
    finishDeathAnimation(env, player)
    assertEquals(env.getEffectCount(), 1, "LostDeath completion should start the custom visual")
end

local function test_other_revive_sources_are_not_consumed_or_blocked()
    local env = makeEnvironment()
    env.gameStarted(false)
    local player = makePlayer({ hearts = 2, otherRevive = true })
    assertEquals(env.damage(player, 2), nil, "an already pending engine revive should keep control")
    assertEquals(player.removeCalls, 0, "this item should remain when another revive source handles death")
    assertEquals(env.getSoundCount(), 0, "the custom revive should not falsely announce a trigger")
end

local function test_coop_players_have_independent_once_per_run_state()
    local env = makeEnvironment()
    env.gameStarted(false)
    local first = makePlayer({ seed = 101, hearts = 2 })
    local second = makePlayer({ seed = 202, hearts = 2 })

    assertEquals(env.damage(first, 2), nil, "first player's death must be allowed")
    assertEquals(env.damage(second, 2), nil, "second player's death must be allowed independently")
    confirmDeath(env, first)
    confirmDeath(env, second)
    assertEquals(first.removeCalls, 1, "first player should consume only their own item")
    assertEquals(second.removeCalls, 1, "second player should consume only their own item")
end

local function test_no_red_heart_character_has_a_survivable_fallback()
    local env = makeEnvironment()
    env.gameStarted(false)
    local player = makePlayer({ hearts = 0, maxHearts = 0, soulHearts = 0, boneHearts = 0 })

    assertEquals(env.damage(player, 1), nil, "zero-heart characters must still pass through a real death")
    confirmDeath(env, player)
    local effect = finishDeathAnimation(env, player)
    effect.sprite.finished = true
    env.updateEffect(effect)
    assertTruthy(player.soulHearts >= 2 or player.cooldown > 0,
        "zero-heart characters should receive fallback health or invincibility")
end

local function test_continue_keeps_state_but_new_run_resets_it()
    local env = makeEnvironment()
    env.gameStarted(false)
    local player = makePlayer({ seed = 303, hearts = 2, collectibleCount = 2 })
    assertEquals(env.damage(player, 2), nil, "first run death should be allowed")
    confirmDeath(env, player)

    env.gameStarted(true)
    assertEquals(env.damage(player, 2), nil, "continued run should remember that the player already revived")

    env.setRunSeed(54321)
    env.gameStarted(false)
    player.dead = false
    player.hearts = 2
    assertEquals(env.damage(player, 2), nil, "a new run should reset and allow the next real death")
    confirmDeath(env, player)
    assertEquals(player.removeCalls, 2, "the new run should consume a new copy after death is confirmed")
end

local function test_fake_and_nokill_damage_are_ignored()
    local env = makeEnvironment()
    env.gameStarted(false)
    local player = makePlayer({ hearts = 2 })
    assertEquals(env.damage(player, 2, DamageFlag.DAMAGE_FAKE), nil, "fake damage must not revive")
    assertEquals(env.damage(player, 2, DamageFlag.DAMAGE_NOKILL), nil, "nonlethal damage flags must not revive")
    assertEquals(player.removeCalls, 0, "ignored damage must not consume the item")
end

local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local function test_registration_audio_and_room_safety_contract()
    local items = readFile("content/items.xml")
    local pools = readFile("content/itempools.xml")
    local sounds = readFile("content/sounds.xml")
    local source = readFile("revive_my_love.lua")
    local main = readFile("main.lua")
    local entities = readFile("content/entities2.xml")
    local anm2 = readFile("resources/gfx/Effects/ReviveMyLove/revive_my_love_cocoon.anm2")
    local wav = io.open("resources/sfx/revive_my_love/revive_my_love.wav", "rb")

    assertTruthy(items:find('<passive name="Revive My Love"', 1, true), "item should be registered as a passive")
    assertTruthy(items:find('gfx="revive_my_beloved.png" id="51" quality="3"', 1, true), "item should use local id 51 and quality 3")
    assertEquals(pools:find('Revive My Love', 1, true), nil, "pool metadata must remain TBD")
    assertTruthy(sounds:find('name="Revive My Love"', 1, true), "custom sound should be registered")
    assertTruthy(sounds:find('revive_my_love/revive_my_love.wav', 1, true), "registered sound should use the converted WAV")
    assertTruthy(wav ~= nil, "converted full-length WAV should exist")
    if wav then wav:close() end
    for _, forbidden in ipairs({ "StartRoomTransition", "ChangeRoom", "ExecuteCommand" }) do
        assertEquals(source:find(forbidden, 1, true), nil, "revive logic must not alter rooms: " .. forbidden)
    end
    assertTruthy(source:find("player:Revive()", 1, true), "the final stage must use the engine revive path")
    assertTruthy(source:find("MC_POST_PLAYER_UPDATE", 1, true), "the module must observe the native death animation")
    assertTruthy(main:find("first true death", 1, true), "English EID should describe a true death, not cancelled damage")
    assertTruthy(main:find("首次真正死亡", 1, true), "Chinese EID should describe a true death, not cancelled damage")
    assertTruthy(source:find("Color(1.0, 0.55, 0.78", 1, true), "player revival flash should use the approved pink tint")
    assertTruthy(source:find("Color(1.0, 0.32, 0.68", 1, true), "world revival effect should use the approved pink tint")
    assertEquals(source:find("Color(0.30, 0.68, 1.0", 1, true), nil, "the previous blue-silver poof tint must be removed")
    assertEquals(source:find("POOF_EFFECT", 1, true), nil, "the native poof must not replace the custom ANM2")
    assertTruthy(main:find("EffectVariant = 3020", 1, true), "main should inject the registered revive effect variant")
    assertTruthy(entities:find('variant="3020"', 1, true), "the revive effect variant should be registered")
    assertTruthy(entities:find('anm2path="Effects/ReviveMyLove/revive_my_love_cocoon.anm2"', 1, true),
        "the entity registration should point at the real cocoon ANM2")
    assertTruthy(anm2:find('DefaultAnimation="Revive"', 1, true), "the cocoon ANM2 should default to Revive")
    assertTruthy(anm2:find('<Animation Name="Revive" FrameNum="48" Loop="false">', 1, true),
        "Revive should remain a 48-frame one-shot animation")
end

local tests = {
    test_nonlethal_damage_is_untouched,
    test_lethal_damage_is_allowed_and_only_confirmed_death_consumes_the_item,
    test_cancelled_lethal_prediction_does_not_consume_or_lock_the_item,
    test_other_revive_sources_are_not_consumed_or_blocked,
    test_coop_players_have_independent_once_per_run_state,
    test_no_red_heart_character_has_a_survivable_fallback,
    test_continue_keeps_state_but_new_run_resets_it,
    test_fake_and_nokill_damage_are_ignored,
    test_registration_audio_and_room_safety_contract,
}

for _, test in ipairs(tests) do test() end
print("revive_my_love_behavior_test: ok")
