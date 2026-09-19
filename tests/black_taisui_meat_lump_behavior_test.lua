-- Full main.lua load, actual registered handlers and installed 1.0.12a dispatcher.
-- HP, cooldown and HUD are explicit test doubles, not in-game evidence.
local function read(path)
    local f = assert(io.open(path, "r")); local s = f:read("*a"); f:close(); return s
end
local oldArg = arg
arg = { "--fixture" }
local loadFixture = dofile("tests/folk_horror_items_behavior_test.lua")
arg = oldArg
local native = read("E:/Isaac - Repentance/resources/scripts/main_ex.lua")
assert(native:find('["Version"] = "1.0.12a"', 1, true))
local first = assert(native:find("function _RunEntityTakeDmgCallback(", 1, true))
local last = assert(native:find("-- Custom handling for MC_PRE_TRIGGER_PLAYER_DEATH", first, true))
local dispatchSource = native:sub(first, last - 1)
local function eq(a, b, label)
    assert(a == b, (label or "value") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
local function setup(options)
    local env = loadFixture(options)
    DamageFlag = { DAMAGE_NOKILL = 1, DAMAGE_FIRE = 2, DAMAGE_RED_HEARTS = 32,
        DAMAGE_DEVIL = 1024, DAMAGE_INVINCIBLE = 8192, DAMAGE_CURSED_DOOR = 65536,
        DAMAGE_IV_BAG = 262144, DAMAGE_FAKE = 2097152 }
    local dispatcher = setmetatable({
        GetCallbackIterator = function()
            local callbacks = env.getCallbacks(ModCallbacks.MC_ENTITY_TAKE_DMG, EntityType.ENTITY_PLAYER)
            local i = 0; return function() i = i + 1; return callbacks[i] end
        end,
        RunCallbackInternal = function(_, callback, ...) return callback(env.mod, ...) end,
    }, { __index = _G })
    assert(load(dispatchSource, "@installed-1.0.12a-damage-dispatch", "t", dispatcher))()
    function env.hit(player, flags, amount)
        flags, amount = flags or 0, amount or 1
        -- Model native damage immunity before MC_ENTITY_TAKE_DMG for ordinary contact.
        if player:GetDamageCooldown() > 0 and flags & DamageFlag.DAMAGE_INVINCIBLE == 0 then return false end
        local result = dispatcher._RunEntityTakeDmgCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,
            EntityType.ENTITY_PLAYER, player, amount, flags, EntityRef(env.newEnemy(100, 100)), 30)
        if result ~= false and flags & (DamageFlag.DAMAGE_FAKE | DamageFlag.DAMAGE_NOKILL) == 0 then
            player.hearts = math.max(0, player.hearts - amount)
            player.dead = player.hearts + player.soulHearts <= 0
        end
        return result
    end
    function env.pickup(player)
        player.collectibles[env.items.MeatLump] = (player.collectibles[env.items.MeatLump] or 0) + 1
        env.runPostAddCollectible(env.items.MeatLump, player)
        env.runPostUpdate()
    end
    function env.texts()
        for i = #env.renderTexts, 1, -1 do env.renderTexts[i] = nil end
        env.runPostRender()
        local seen = {}; for _, record in ipairs(env.renderTexts) do seen[record.text] = true end
        return seen
    end
    return env
end
local tests = {}
local function test(name, fn) tests[#tests + 1] = { name, fn } end
local function oneHeart(env, withTaisui)
    local p = env.newPlayer({ hearts = 1, maxHearts = 2,
        collectibles = withTaisui and { [env.items.BlackTaisui] = 1 } or {} })
    if withTaisui then env.mod:SetBlackTaisuiParasiteValue(p, 16) end
    return p
end

test("meat survives consecutive enemy contact and immunity expires", function()
    local e = setup(); local p = oneHeart(e); e.pickup(p)
    eq(e.hit(p), false, "first lethal hit"); eq(e.mod:GetMeatLumpLifeCount(p), 0)
    assert(p:GetDamageCooldown() > 0, "blocked lethal hit must grant native invincibility")
    for _ = 1, 8 do eq(e.hit(p), false); eq(p.dead, false); eq(p.hearts, 1) end
    p.damageCooldown = 0; eq(e.hit(p), nil); eq(p.dead, true, "spent charge must not become permanent immunity")
end)
test("body ward preserves meat until a later unprotected hit", function()
    local e = setup(); local p = oneHeart(e, true); e.pickup(p)
    eq(e.hit(p), false); eq(e.mod:GetMeatLumpLifeCount(p), 1)
    eq(e.hit(p), false); eq(e.mod:GetMeatLumpLifeCount(p), 1, "same-contact follow-up must not spend meat")
    p.damageCooldown = 0; eq(e.hit(p), false); eq(e.mod:GetMeatLumpLifeCount(p), 0)
    eq(p.dead, false); assert(p:GetDamageCooldown() > 0)
end)
test("fire contact receives the same survival protection", function()
    local e = setup(); local p = oneHeart(e); e.pickup(p)
    eq(e.hit(p, DamageFlag.DAMAGE_FIRE), false)
    eq(e.hit(p, DamageFlag.DAMAGE_FIRE), false); eq(p.dead, false)
end)
test("new meat never borrows hidden c11", function()
    local e = setup(); local p = oneHeart(e); e.pickup(p)
    for _, call in ipairs(p.effects.addCalls) do assert(call.itemId ~= 11, "must not add then hide a c11 effect") end
    eq(p.effects.counts[11] or 0, 0, "no fake native 1UP entitlement")
    eq(e.mod:GetMeatLumpLifeCount(p), 1)
end)
test("foreign c11 effects and real collectible survive updates and both saves", function()
    local e = setup(); local p = oneHeart(e, true)
    p.effects.counts[11] = 2; p.collectibles[11] = 1
    e.pickup(p); e.runPostUpdate(); eq(p.effects.counts[11], 2, "update must not remove foreign effects")
    eq(e.hit(p), false); p.damageCooldown = 0; eq(e.hit(p), false)
    eq(p.effects.counts[11], 2); eq(p.collectibles[11], 1)
end)
test("pickup observer and held-copy polling grant exactly once", function()
    local e = setup(); local p = oneHeart(e); e.pickup(p)
    e.runPostAddCollectible(e.items.MeatLump, p); e.runPostUpdate()
    eq(e.mod:GetMeatLumpLifeCount(p), 1, "reobserving the same held copy")
    e.pickup(p); eq(e.mod:GetMeatLumpLifeCount(p), 2)
end)
test("held copy fallback remains available", function()
    local e = setup(); local p = oneHeart(e)
    p.collectibles[e.items.MeatLump] = 1; e.runPostUpdate(); e.runPostUpdate()
    eq(e.mod:GetMeatLumpLifeCount(p), 1)
end)
test("removing and reacquiring a copy between updates grants the new copy", function()
    local e = setup(); local p = oneHeart(e); e.pickup(p)
    p:RemoveCollectible(e.items.MeatLump)
    for _, callback in ipairs(e.getCallbacks(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED, e.items.MeatLump)) do
        callback(e.mod, p, e.items.MeatLump, false, false)
    end
    e.pickup(p); eq(e.mod:GetMeatLumpLifeCount(p), 2, "each newly obtained copy grants one charge")
end)
test("HUD shows meat +1 then +2 then decrements and disappears", function()
    local e = setup(); local p = oneHeart(e)
    eq(e.texts()["+1"], nil); e.pickup(p); eq(e.texts()["+1"], true)
    e.pickup(p); eq(e.texts()["+2"], true)
    eq(e.hit(p), false); eq(e.texts()["+1"], true)
    p.damageCooldown = 0; eq(e.hit(p), false); eq(e.texts()["+1"], nil); eq(e.texts()["+0"], nil)
end)
for _, language in ipairs({ "en", "zh" }) do
    test("stage three alone has no WARD or fake +1 in " .. language, function()
        local e = setup({ language = language }); oneHeart(e, true)
        local text = e.texts(); eq(text.WARD, nil); eq(text["护命"], nil); eq(text["+1"], nil)
    end)
end
test("HUD respects native visibility", function()
    local e = setup(); local p = oneHeart(e); e.pickup(p)
    local originalGame = Game
    Game = function() local g = originalGame(); g.GetHUD = function() return { IsVisible = function() return false end } end; return g end
    eq(e.texts()["+1"], nil, "hidden native HUD")
    Game = originalGame; eq(e.texts()["+1"], true)
end)
test("two players keep separate counts and labelled HUD entries", function()
    local e = setup(); local a = oneHeart(e); local b = oneHeart(e)
    e.pickup(a); e.pickup(b); e.pickup(b)
    local text = e.texts(); eq(text["P1 +1"], true); eq(text["P2 +2"], true)
    eq(e.hit(a), false); eq(e.mod:GetMeatLumpLifeCount(b), 2); eq(b:GetDamageCooldown(), 0)
end)
test("fake and nonlethal requests do not consume meat", function()
    local e = setup(); local p = oneHeart(e); e.pickup(p)
    eq(e.hit(p, DamageFlag.DAMAGE_FAKE), nil); eq(e.mod:GetMeatLumpLifeCount(p), 1)
    eq(e.hit(p, DamageFlag.DAMAGE_NOKILL), nil); eq(e.mod:GetMeatLumpLifeCount(p), 1)
    p.hearts = 3; eq(e.hit(p), nil); eq(e.mod:GetMeatLumpLifeCount(p), 1)
end)
test("spent copy stays spent across room floor and continuation", function()
    local e = setup(); local p = oneHeart(e); e.pickup(p); eq(e.hit(p), false)
    e.runNewRoom(); e.runNewLevel(); e.mod:ResetFolkHorrorItemState(true); e.runPostUpdate()
    eq(e.mod:GetMeatLumpLifeCount(p), 0); eq(e.texts()["+1"], nil)
    e.pickup(p); eq(e.mod:GetMeatLumpLifeCount(p), 1, "newly obtained copy still grants another charge")
end)
test("new run seed clears previous meat charges", function()
    local e = setup(); local p = oneHeart(e); e.pickup(p)
    local originalGame = Game
    Game = function() local g = originalGame(); g.GetSeeds = function() return { GetStartSeedString = function() return "NEXT RUN" end } end; return g end
    eq(e.mod:GetMeatLumpLifeCount(p), 0)
end)
test("forced Avada failure cannot spend or activate either protection", function()
    local e = setup(); local p = oneHeart(e, true); e.pickup(p)
    e.mod.AvadaKedavra = { IsFailureDeath = function() return true end }
    eq(e.hit(p), nil); eq(e.mod:GetMeatLumpLifeCount(p), 1); eq(p:GetDamageCooldown(), 0)
end)
test("failed recovery does not consume meat", function()
    local e = setup(); local p = oneHeart(e); e.pickup(p); p.dead = true
    function p:Revive() error("engine recovery rejected") end
    eq(e.mod:ApplyMeatLumpLife(p, true), false); eq(e.mod:GetMeatLumpLifeCount(p), 1)
end)
test("failed recovery does not consume body ward", function()
    local e = setup(); local p = oneHeart(e, true); p.dead = true
    function p:Revive() end
    eq(e.mod:ApplyBlackTaisuiDeathSave(p, true), false); eq(e.mod:BlackTaisuiDeathSaveAvailable(p), true)
end)
test("soul-heart character receives immunity after meat save", function()
    local e = setup(); local p = e.newPlayer({ hearts = 0, maxHearts = 0, soulHearts = 1 }); e.pickup(p)
    eq(e.hit(p), false); assert(p.soulHearts >= 2); assert(p:GetDamageCooldown() > 0)
end)

local failures = 0
for _, t in ipairs(tests) do
    local ok, err = pcall(t[2]); if ok then print("PASS " .. t[1]) else failures = failures + 1; print("FAIL " .. t[1] .. ": " .. tostring(err)) end
end
print(string.format("Black Taisui / Meat Lump: %d passed, %d failed", #tests - failures, failures))
assert(failures == 0, "death-save/HUD regression failures")
