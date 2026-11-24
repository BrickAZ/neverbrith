local fixture = assert(loadfile("tests/memory_disorder_behavior_test.lua"))("fixture")
local function eq(a, b, message)
    assert(a == b, message .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
local function config(id, kind, hidden, gfx)
    return { ID = id, Type = kind or 1, Hidden = hidden, GfxFileName = gfx or ("icon-" .. id .. ".png") }
end
local function setup(configs)
    local env = fixture.makeEnvironment()
    env.setIconConfigs(configs or { config(12), config(13), config(25) })
    env.api.InvalidateIconCache()
    return env, env.players[1], env.players[2]
end
local function sprite()
    local s = { sheets = {}, loads = 0, animation = "ShopIdle", frame = 9 }
    function s:GetLayer(layer)
        return { GetSpritesheetPath = function() return self.sheets[layer] or "original.png" end }
    end
    function s:ReplaceSpritesheet(layer, gfx) self.sheets[layer] = gfx end
    function s:LoadGraphics() self.loads = self.loads + 1 end
    return s
end
local function pickup(seed)
    local p = { Type = 5, Variant = 100, SubType = 9000, InitSeed = seed or 900, data = {}, sprite = sprite(), blind = false }
    function p:GetData() return self.data end
    function p:GetSprite() return self.sprite end
    function p:IsBlind() return self.blind end
    return p
end
local function history(player, ids, trinket)
    function player:GetHistory()
        return { GetCollectiblesHistory = function()
            local entries = {}
            for _, id in ipairs(ids) do
                entries[#entries + 1] = { GetItemID = function() return id end, IsTrinket = function() return trinket == id end }
            end
            return entries
        end }
    end
end

local tests = {}
function tests.filters_and_no_grants()
    local env, p, peer = setup({ config(9000), config(0), config(12), config(13, 2), config(14, 3), config(15, 1, true), config(16, 1, false, ""), config(17), config(18), config(19) })
    p.collectibleCounts[17] = 1
    peer.collectibleCounts[18] = 1
    history(peer, { 19 })
    eq(env.api.ChooseIcon(p), 12, "only an unseen passive is eligible")
    eq(#p.addedCollectibles, 0, "disguise never grants the displayed collectible")
    peer.collectibleCounts[18] = nil
    p.collectibleCounts[17] = nil
    env.dispatch(ModCallbacks.MC_POST_ADD_COLLECTIBLE, 12, 0, true, 0, 0, peer)
    eq(env.api.ChooseIcon(p), 0, "removed and newly acquired items remain excluded")
end
function tests.history_trinkets_are_not_collectibles()
    local env, p = setup({ config(12) })
    history(p, { 12 }, 12)
    eq(env.api.ChooseIcon(p), 12, "smelted trinket id does not exclude a collectible")
end
function tests.engine_userdata_config_list()
    local oldIsaac = Isaac
    local proxies = {}
    local function userdata(fields)
        local value = assert(io.tmpfile())
        proxies[#proxies + 1] = { value = value, metatable = getmetatable(value) }
        debug.setmetatable(value, fields and { __index = fields } or nil)
        return value
    end
    -- ItemConfigList:Get returns opaque userdata; only GetCollectible exposes fields.
    local opaque = userdata()
    local items = {
        [12] = userdata(config(12)),
        [13] = userdata(config(13, 2)),
        [14] = userdata(config(14, 3)),
        [15] = userdata(config(15, 1, true)),
        [16] = userdata(config(16, 1, false, "")),
        [9000] = userdata(config(9000)),
        [9100] = userdata(config(9100)),
    }
    local listReads = 0
    local list = userdata({ Size = 9101, Get = function()
        listReads = listReads + 1
        return opaque
    end })
    local itemConfig = userdata({ GetCollectible = function(_, id) return items[id] end })
    Isaac = { GetItemConfig = function() return itemConfig end }
    local ok, err = xpcall(function()
        for _, entry in ipairs({
            { id = ModCallbacks.MC_POST_GAME_STARTED, continued = false },
            { id = ModCallbacks.MC_POST_GAME_STARTED, continued = true },
            { id = ModCallbacks.MC_POST_NEW_ROOM },
            { id = ModCallbacks.MC_POST_UPDATE },
        }) do
            local env, p = setup(list)
            p.collectibleCounts[12] = 1
            env.dispatch(entry.id, entry.continued)
            eq(env.api.ChooseIcon(p), 9100, "callbacks select an unseen modded passive across sparse IDs")
            eq(env.saveRoot.memoryDisorder.pickedIconItems["12"], true, "starting inventory remains excluded")
            local pedestal = pickup()
            env.dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, pedestal)
            env.dispatch(ModCallbacks.MC_PRE_PICKUP_RENDER, pedestal)
            eq(pedestal.sprite.sheets[1], "icon-9100.png", "typed config reaches pedestal rendering")
            env.dispatch(ModCallbacks.MC_POST_ADD_COLLECTIBLE, 9100, 0, true, 0, 0, p)
            eq(env.api.ChooseIcon(p), 0, "all eligible icons acquired falls back to question mark")
        end
        eq(listReads, 0, "opaque list entries are never used")
    end, debug.traceback)
    Isaac = oldIsaac
    for _, proxy in ipairs(proxies) do
        debug.setmetatable(proxy.value, proxy.metatable)
        proxy.value:close()
    end
    assert(ok, err)
end
function tests.no_repeat_and_room_switch()
    local env, p = setup({ config(12), config(13) })
    p.collectibleCounts[9000] = 1
    env.api.OnOwnershipUpdate(p)
    local first = env.api.GetRuntimeState(p).currentIconId
    env.api.BeginRoomTransitions("next-room")
    for _ = 1, 15 do env.api.AdvanceFrame() end
    local nextId = env.api.GetRuntimeState(p).currentIconId
    assert(nextId ~= first, "two eligible icons alternate at identity switch")
    assert(nextId == 12 or nextId == 13, "transition uses passive pool")
end
function tests.pedestal_eid_held_and_blind()
    local env, p = setup({ config(12), config(13), config(14, 2) })
    local modifiers = {}
    EID = { InlineIcons = { QuestionMark = "question-icon" } }
    function EID:addDescriptionModifier(name, condition, callback)
        modifiers[#modifiers + 1] = { condition = condition, callback = callback }
    end
    function EID:createItemIconObject(markup) return markup end
    env.runPostUpdate()
    env.runPostUpdate()
    eq(#modifiers, 1, "EID modifier registered only once")
    local pedestal = pickup()
    env.dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, pedestal)
    env.dispatch(ModCallbacks.MC_PRE_PICKUP_RENDER, pedestal)
    local id = pedestal.data.NeverbirthMemoryDisorderIcon.id
    eq(pedestal.sprite.sheets[1], "icon-" .. id .. ".png", "actual pedestal spritesheet is replaced")
    eq(pedestal.sprite.animation, "ShopIdle", "native shop animation preserved")
    eq(pedestal.sprite.frame, 9, "native animation frame preserved")
    local desc = { ObjType = 5, ObjVariant = 100, ObjSubType = 9000, Entity = pedestal, Name = "Memory Disorder", Description = "real mechanics" }
    assert(modifiers[1].condition(desc))
    modifiers[1].callback(desc)
    eq(desc.Icon, "Collectible" .. id, "EID icon agrees with pedestal")
    eq(desc.Name, "Memory Disorder", "name remains real item name")
    eq(desc.Description, "real mechanics", "disguise never substitutes effect description")
    assert(not modifiers[1].condition({ ObjType = 5, ObjVariant = 350, ObjSubType = 9000 }), "trinkets not modified")
    local loads = pedestal.sprite.loads
    for _ = 1, 5 do env.dispatch(ModCallbacks.MC_PRE_PICKUP_RENDER, pedestal) end
    eq(pedestal.sprite.loads, loads, "no graphic reload on unchanged render frames")
    pedestal.sprite.sheets[1] = "engine-reloaded.png"
    env.dispatch(ModCallbacks.MC_PRE_PICKUP_RENDER, pedestal)
    eq(pedestal.sprite.sheets[1], "icon-" .. id .. ".png", "engine reload is repaired")

    p.data, p.held = {}, sprite()
    function p:GetData() return self.data end
    function p:GetHeldSprite() return self.held end
    function p:ToPlayer() return self end
    p.QueuedItem = { Item = { ID = 9000 } }
    env.dispatch(ModCallbacks.MC_PRE_PICKUP_COLLISION, pedestal, p)
    env.dispatch(ModCallbacks.MC_PRE_PLAYER_RENDER, p)
    eq(p.held.sheets[0], "icon-" .. id .. ".png", "held icon agrees with touched pedestal")
    p.QueuedItem.Item.ID = 12
    p.held.sheets[0] = "real-other-item.png"
    env.dispatch(ModCallbacks.MC_PRE_PLAYER_RENDER, p)
    eq(p.held.sheets[0], "real-other-item.png", "other held items are untouched")

    pedestal.blind = true
    env.dispatch(ModCallbacks.MC_PRE_PICKUP_RENDER, pedestal)
    eq(pedestal.sprite.sheets[1], "gfx/items/collectibles/questionmark.png", "blind pedestal stays hidden")
    modifiers[1].callback(desc)
    eq(desc.Icon, "question-icon", "EID does not expose blind disguise")
    pedestal.blind = false
    env.dispatch(ModCallbacks.MC_PRE_PICKUP_RENDER, pedestal)
    eq(pedestal.sprite.sheets[1], "icon-" .. id .. ".png", "disguise restored after blind state")
    pedestal.SubType = 14
    env.dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, pedestal)
    eq(pedestal.sprite.sheets[1], "icon-14.png", "reroll restores native item graphics with 1.0.12a APIs")
    eq(pedestal.data.NeverbirthMemoryDisorderIcon, nil, "reroll clears disguise record")
    EID = nil
end
function tests.acquisition_refreshes_existing_pedestal()
    local env, _, peer = setup({ config(12), config(13) })
    local pedestal = pickup()
    env.dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, pedestal)
    local id = pedestal.data.NeverbirthMemoryDisorderIcon.id
    env.dispatch(ModCallbacks.MC_POST_ADD_COLLECTIBLE, id, 0, true, 0, 0, peer)
    env.dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, pedestal)
    local replacement = pedestal.data.NeverbirthMemoryDisorderIcon.id
    assert(replacement ~= id and replacement > 0, "teammate acquisition refreshes existing disguise")
    env.dispatch(ModCallbacks.MC_PRE_PICKUP_RENDER, pedestal)
    eq(pedestal.sprite.sheets[1], "icon-" .. replacement .. ".png", "new choice reaches renderer")
end
function tests.save_continue_and_new_run()
    local env, p = setup({ config(12), config(13) })
    env.dispatch(ModCallbacks.MC_POST_ADD_COLLECTIBLE, 12, 0, true, 0, 0, p)
    p.collectibleCounts[9000] = 1
    env.api.OnOwnershipUpdate(p)
    local pedestal = pickup()
    env.dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, pedestal)
    env.api.OnPreGameExit()
    env.api.OnGameStarted(true)
    eq(env.api.GetRuntimeState(p).currentIconId, 13, "valid saved holder disguise survives continue")
    eq(env.saveRoot.memoryDisorder.pickedIconItems["12"], true, "acquisition history survives continue")
    local reloaded = pickup()
    env.dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, reloaded)
    eq(reloaded.data.NeverbirthMemoryDisorderIcon.id, pedestal.data.NeverbirthMemoryDisorderIcon.id, "pedestal disguise survives fresh entity on continue")
    env.api.OnGameStarted(false)
    eq(env.saveRoot.memoryDisorder.pickedIconItems["12"], nil, "new run clears prior acquisition history")
end
function tests.empty_pool_is_question_mark()
    local env = setup({ config(13, 2), config(14, 3) })
    local pedestal = pickup()
    env.dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, pedestal)
    env.dispatch(ModCallbacks.MC_PRE_PICKUP_RENDER, pedestal)
    eq(pedestal.sprite.sheets[1], "gfx/items/collectibles/questionmark.png", "empty pool never impersonates an acquired Breakfast")
    env.runPostUpdate() -- EID absent is supported.
end

function tests.holder_eid_follows_identity_switch()
    local env, p, peer = setup({ config(12), config(13) })
    p.collectibleCounts[9000] = 1
    env.api.OnOwnershipUpdate(p)
    local first = env.api.GetRuntimeState(p).currentIconId
    local modifier
    EID = { player = p, InlineIcons = { QuestionMark = "question-icon" } }
    function EID:addDescriptionModifier(_, _, callback) modifier = callback end
    function EID:createItemIconObject(markup) return markup end
    env.runPostUpdate()
    local desc = { ObjType = 5, ObjVariant = 100, ObjSubType = 9000 }
    modifier(desc)
    eq(desc.Icon, "Collectible" .. first, "inventory description starts with holder's current icon")
    env.api.BeginRoomTransitions("next-room")
    for _ = 1, 15 do env.api.AdvanceFrame() end
    local nextId = env.api.GetRuntimeState(p).currentIconId
    modifier(desc)
    eq(desc.Icon, "Collectible" .. nextId, "new room selection reaches EID display")
    assert(first ~= nextId, "room switch visibly changes holder icon")
    env.dispatch(ModCallbacks.MC_POST_ADD_COLLECTIBLE, nextId, 0, true, 0, 0, peer)
    env.runPostUpdate()
    modifier(desc)
    eq(desc.Icon, "Collectible" .. first, "teammate acquisition refreshes holder's displayed icon")
    EID = nil
end

function tests.blind_curse_and_seed_determinism()
    local env = setup()
    local pedestal = pickup(700)
    env.dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, pedestal)
    local id = pedestal.data.NeverbirthMemoryDisorderIcon.id
    local env2 = setup()
    local same = pickup(700)
    env2.dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, same)
    eq(same.data.NeverbirthMemoryDisorderIcon.id, id, "same run and pedestal seed gives same initial disguise")
    local oldGame, oldCurse = Game, LevelCurse
    LevelCurse = { CURSE_OF_BLIND = 64 }
    Game = function() return { GetLevel = function() return { GetCurses = function() return 64 end } end } end
    env.dispatch(ModCallbacks.MC_PRE_PICKUP_RENDER, pedestal)
    eq(pedestal.sprite.sheets[1], "gfx/items/collectibles/questionmark.png", "floor curse independently hides the disguise")
    Game, LevelCurse = oldGame, oldCurse
end

local count = 0
for _, test in pairs(tests) do test(); count = count + 1 end
print("memory_disorder_icons_test: " .. count .. " cases passed")
