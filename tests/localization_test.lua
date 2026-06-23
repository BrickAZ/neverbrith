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

local function containsHan(text)
    return text ~= nil and text:match("[\228-\233][\128-\191][\128-\191]") ~= nil
end

local function loadNeverbirthWithEID()
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
    local eidCalls = {}

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
    }

    CollectibleType = { COLLECTIBLE_NULL = 0, COLLECTIBLE_PLAN_C = 475 }
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
    RoomType = { ROOM_DEVIL = 14, ROOM_ANGEL = 15 }
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

    function Game()
        return {
            GetSeeds = function()
                return { GetStartSeedString = function() return "TEST RUN" end }
            end,
        }
    end

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
            return {}
        end,
        FindByType = function()
            return {}
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

        function mod:HasData()
            return false
        end

        function mod:LoadData()
            return "{}"
        end

        function mod:SaveData() end

        return mod
    end

    EID = {
        _currentMod = "previous-mod",
        ModIndicator = {},
        addCollectible = function(_, id, description, itemName, language)
            eidCalls[#eidCalls + 1] = {
                id = id,
                description = description,
                itemName = itemName,
                language = language,
            }
        end,
    }

    dofile("main.lua")

    return {
        eidCalls = eidCalls,
        itemIds = itemIds,
    }
end

local expectedEID = {
    EssentialBalm = {
        en_us = {
            name = "Essential Balm",
            description = "{{Damage}} +1 damage#{{Shotspeed}} -0.2 shot speed",
        },
        zh_cn = {
            name = "风油精",
            description = "↑ +1攻击力#↓ -0.2弹速",
        },
    },
    Wuhu = {
        en_us = {
            name = "Wuhu!",
            description = "{{Speed}} +1 speed#{{Tears}} Max fire rate#{{Damage}} +40 damage#{{Shotspeed}} -1 shot speed",
        },
        zh_cn = {
            name = "芜湖！~",
            description = "↑ +1移速#↑ 攻速上限达到30#↑ +40攻击力#↓ -1弹速",
        },
    },
    Aphrodisiac = {
        en_us = {
            name = "Aphrodisiac",
            description = "Spend 1 full heart without dying#{{Damage}} +0.5 damage#{{Tears}} +0.5 fire rate#Charm effect and homing tears for 3 seconds",
        },
        zh_cn = {
            name = "春药",
            description = "使用后扣除1滴完整的血#{{Warning}} 优先扣红心 #{{Warning}} 不致死#↑ +0.5攻击力#↑ +0.5攻速#角色进入魅惑状态#眼泪获得追踪效果#持续3秒",
        },
    },
    Musicbox = {
        en_us = {
            name = "Music Box",
            description = "20 seconds of invincibility and red tears#{{Warning}} Death when the timer ends#Reuse does not extend time#When uncharged, blocks one lethal hit and triggers itself#Extra lives can save you",
        },
        zh_cn = {
            name = "八音盒",
            description = "使用后进入20秒无敌状态，眼泪变红并播放八音盒音乐#{{Warning}} 倒计时结束时强制死亡#第二次使用不会延长倒计时#未充能且受到致死伤害时，失去八音盒并自动触发一次#八音盒期间压制计划C的自杀死亡，但保留杀敌伤害#只有额外生命可以继续游戏",
        },
    },
    Angelbox = {
        en_us = {
            name = "Angel Box",
            description = "First use converts red heart containers into full soul hearts#Overflow soul hearts recharge it#At full charge, forces an angel room this floor and adds 1 quality 4 angel item on first entry#Favors angel rooms while held",
        },
        zh_cn = {
            name = "天使盒",
            description = "每名玩家首次使用：每个红心容器生成1个完整魂心#之后只吸收装不下的魂心充能，满12格可再次使用#非首次使用：本层尽力必定开启天使房#若使用前本层未进入过天使房，该玩家使首次进入本层天使房时额外生成1个4级天使房道具#持有时一半恶魔房概率转为天使房概率",
        },
    },
    Devilbox = {
        en_us = {
            name = "Devil Box",
            description = "First use converts red heart containers into full black hearts#Overflow black hearts recharge it#At full charge, forces a devil room this floor and adds 1 quality 3 devil item on first entry#Favors devil rooms while held",
        },
        zh_cn = {
            name = "恶魔盒",
            description = "每名玩家首次使用：每个红心容器生成1个完整黑心#之后只吸收装不下的黑心充能，满12格可再次使用#非首次使用：本层尽力必定开启恶魔房#若使用前本层未进入过恶魔房，该玩家使首次进入本层恶魔房时额外生成1个3级恶魔房道具#持有时一半交易房方向转为恶魔房概率",
        },
    },
    ds4 = {
        en_us = {
            name = "ds4",
            description = "{{Warning}} Effect not implemented yet",
        },
        zh_cn = {
            name = "ds4",
            description = "{{Warning}} 效果尚未实现",
        },
    },
}

local expectedXmlDescriptions = {
    EssentialBalm = "Handle with care",
    Wuhu = "Dark wind, wild flight",
    Aphrodisiac = "Heat of the moment",
    Musicbox = "Your life, on a timer",
    Angelbox = "Full hearts, heavenbound",
    Devilbox = "Black hearts, below",
    ds4 = "",
}

local function findEIDCall(calls, id, language)
    local found = nil
    for _, call in ipairs(calls) do
        if call.id == id and call.language == language then
            assertEquals(found, nil, "EID should register only one " .. language .. " description for item " .. tostring(id))
            found = call
        end
    end
    return found
end

local function test_eid_registers_explicit_english_and_chinese_descriptions()
    local env = loadNeverbirthWithEID()

    for itemName, languageExpectations in pairs(expectedEID) do
        local itemId = env.itemIds[itemName]
        for language, expectation in pairs(languageExpectations) do
            local call = findEIDCall(env.eidCalls, itemId, language)
            assertTruthy(call, "missing EID " .. language .. " registration for " .. itemName)
            assertEquals(call.itemName, expectation.name, itemName .. " " .. language .. " EID name")
            assertEquals(call.description, expectation.description, itemName .. " " .. language .. " EID description")
        end
    end

    assertEquals(#env.eidCalls, 14, "EID should register exactly two languages for each item")
    for _, call in ipairs(env.eidCalls) do
        assertTruthy(call.language == "en_us" or call.language == "zh_cn", "EID language should be explicit for every registration")
        if call.language == "en_us" then
            assertEquals(containsHan(call.itemName), false, "English EID name should not contain Chinese")
            assertEquals(containsHan(call.description), false, "English EID description should not contain Chinese")
        elseif call.language == "zh_cn" and call.itemName ~= "ds4" then
            assertTruthy(containsHan(call.itemName), "Chinese EID name should contain Chinese for " .. tostring(call.id))
            assertTruthy(containsHan(call.description), "Chinese EID description should contain Chinese for " .. tostring(call.id))
        end
    end
end

local function getItemXmlDescription(itemName)
    local file = assert(io.open("content/items.xml", "r"))
    local text = file:read("*a")
    file:close()

    local block = text:match('<[pa][ac][st][si][iv][vee]*%s+name="' .. itemName .. '"(.-)/>')
        or text:match('<active%s+name="' .. itemName .. '"(.-)/>')
        or text:match('<passive%s+name="' .. itemName .. '"(.-)/>')
    assertTruthy(block, "items.xml should contain item " .. itemName)
    return block:match('description="(.-)"')
end

local function test_items_xml_uses_english_fallback_descriptions()
    for itemName, expectedDescription in pairs(expectedXmlDescriptions) do
        local description = getItemXmlDescription(itemName)
        assertEquals(description, expectedDescription, itemName .. " XML description")
        assertEquals(containsHan(description), false, itemName .. " XML description should not contain Chinese")
    end
end

test_eid_registers_explicit_english_and_chinese_descriptions()
test_items_xml_uses_english_fallback_descriptions()

print("localization tests passed")
