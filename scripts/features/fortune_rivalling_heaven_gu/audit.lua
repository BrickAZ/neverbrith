-- Item-owned implementation; the entry owns callback installation.
return function(Neverbirth, dependencies)
local private = assert(dependencies.Private)
local Items = assert(dependencies.Items)
local GetNeedletickLuckCap = assert(dependencies.GetNeedletickLuckCap)

function private.BuildFortuneLuckAuditRows(self)
    local rows = {}
    local function row(section, line, zh, en, kind, enum, condition, direction, cap, maxProbability, runtime, registration, version, runtimeItemId)
        rows[#rows + 1] = {
            screenshotSection = section,
            screenshotLine = line,
            zh = zh,
            en = en,
            kind = kind,
            id = runtimeItemId or enum, -- 原版枚举名或 Neverbirth 已解析的本地数值 ID.
            enum = enum,
            runtimeItemId = runtimeItemId,
            condition = condition or "无",
            luckDirection = direction,
            cap = cap,
            maxProbability = maxProbability,
            includeFortune = direction == "positive" and runtime == true and cap ~= nil,
            registration = registration,
            verification = "verified",
            version = version or "Repentance",
            runtime = runtime == true,
        }
    end

    local S = "泪弹效果"
    row(S, 1, "亚巴顿", "Abaddon", "collectible", "COLLECTIBLE_ABADDON", nil, "positive", 85, "100%", true, "fixed")
    row(S, 2, "苹果！", "Apple!", "collectible", "COLLECTIBLE_APPLE", nil, "positive", 14, "100%", true, "fixed")
    row(S, 3, "焦油球", "Ball of Tar", "collectible", "COLLECTIBLE_BALL_OF_TAR", nil, "positive", 18, "100%", true, "fixed")
    row(S, 4, "鸟眼", "Bird's Eye", "collectible", "COLLECTIBLE_BIRDS_EYE", nil, "positive", 10, "50%", true, "fixed")
    row(S, 5, "感冒", "The Common Cold", "collectible", "COLLECTIBLE_COMMON_COLD", nil, "positive", 12, "100%", true, "fixed")
    row(S, 6, "黑暗物质", "Dark Matter", "collectible", "COLLECTIBLE_DARK_MATTER", nil, "positive", 20, "100%", true, "fixed")
    row(S, 7, "硫磺火炸弹 + 胎儿博士", "Brimstone Bombs + Dr. Fetus", "synergy", "COLLECTIBLE_DR_FETUS", "COLLECTIBLE_BRIMSTONE_BOMBS", "positive", 29.67, "100%", true, "dynamic")
    row(S, 8, "屁屁炸弹 + 胎儿博士", "Butt Bombs + Dr. Fetus", "synergy", "COLLECTIBLE_DR_FETUS", "COLLECTIBLE_BUTT_BOMBS", "positive", 27, "100%", true, "dynamic")
    row(S, 9, "火焰炸弹 + 胎儿博士", "Hot Bombs + Dr. Fetus", "synergy", "COLLECTIBLE_DR_FETUS", "COLLECTIBLE_HOT_BOMBS", "positive", 12.34, "100%", true, "dynamic")
    row(S, 10, "幽灵炸弹 + 胎儿博士", "Ghost Bombs + Dr. Fetus", "synergy", "COLLECTIBLE_DR_FETUS", "COLLECTIBLE_GHOST_BOMBS", "positive", 8.25, "100%", true, "dynamic")
    row(S, 11, "悲伤炸弹 + 胎儿博士", "Sad Bombs + Dr. Fetus", "synergy", "COLLECTIBLE_DR_FETUS", "COLLECTIBLE_SAD_BOMBS", "positive", 29.67, "100%", true, "dynamic")
    row(S, 12, "散射炸弹 + 胎儿博士", "Scatter Bombs + Dr. Fetus", "synergy", "COLLECTIBLE_DR_FETUS", "COLLECTIBLE_SCATTER_BOMBS", "positive", 8.25, "100%", true, "dynamic")
    row(S, 13, "安乐死", "Euthanasia", "collectible", "COLLECTIBLE_EUTHANASIA", nil, "positive", 14.5, "100%", false, "fixed", "Afterbirth+（截图旧版）")
    row(S, 14, "安乐死", "Euthanasia", "collectible", "COLLECTIBLE_EUTHANASIA", nil, "positive", 13, "25%", true, "fixed")
    row(S, 15, "邪眼", "Evil Eye", "collectible", "COLLECTIBLE_EVIL_EYE", nil, "positive", 20, "10%", true, "fixed")
    row(S, 16, "火焰意志", "Fire Mind", "collectible", "COLLECTIBLE_FIRE_MIND", nil, "positive", 13, "100%", true, "fixed")
    row(S, 17, "幽灵辣椒", "Ghost Pepper", "collectible", "COLLECTIBLE_GHOST_PEPPER", nil, "positive", 10, "50%", true, "fixed")
    row(S, 18, "神圣之光", "Holy Light", "collectible", "COLLECTIBLE_HOLY_LIGHT", nil, "positive", 8.89, "50%", true, "fixed")
    row(S, 19, "铁块", "Iron Bar", "collectible", "COLLECTIBLE_IRON_BAR", nil, "positive", 26.95, "100%", true, "fixed")
    row(S, 20, "击退泪滴", "Knockout Drops", "collectible", "COLLECTIBLE_KNOCKOUT_DROPS", nil, "positive", 8.01, "100%", true, "fixed")
    row(S, 21, "小魔角", "Little Horn", "collectible", "COLLECTIBLE_LITTLE_HORN", nil, "positive", 15, "20%", true, "fixed")
    row(S, 22, "磁石", "Lodestone", "collectible", "COLLECTIBLE_LODESTONE", nil, "positive", 5, "100%", true, "fixed")
    row(S, 23, "洛基的角", "Loki's Horns", "collectible", "COLLECTIBLE_LOKIS_HORNS", nil, "positive", 7, "100%", false, "fixed", "Afterbirth+（截图旧版）")
    row(S, 24, "洛基的角", "Loki's Horns", "collectible", "COLLECTIBLE_LOKIS_HORNS", nil, "positive", 15, "100%", true, "fixed")
    row(S, 25, "洛基的角 + 鲁多维科科技", "Loki's Horns + The Ludovico Technique", "synergy", "COLLECTIBLE_LOKIS_HORNS", "COLLECTIBLE_LUDOVICO_TECHNIQUE", "positive", 20, "100%", true, "dynamic")
    row(S, 26, "妈妈的美瞳", "Mom's Contacts", "collectible", "COLLECTIBLE_MOMS_CONTACTS", nil, "positive", 20, "50%", true, "fixed")
    row(S, 27, "妈妈的眼睛", "Mom's Eye", "collectible", "COLLECTIBLE_MOMS_EYE", nil, "positive", 2, "100%", false, "fixed", "Afterbirth+（截图旧版）")
    row(S, 28, "妈妈的眼睛", "Mom's Eye", "collectible", "COLLECTIBLE_MOMS_EYE", nil, "positive", 5, "100%", true, "fixed")
    row(S, 29, "妈妈的眼睛 + 鲁多维科科技", "Mom's Eye + The Ludovico Technique", "synergy", "COLLECTIBLE_MOMS_EYE", "COLLECTIBLE_LUDOVICO_TECHNIQUE", "positive", 10, "100%", true, "dynamic")
    row(S, 30, "妈妈的眼影", "Mom's Eyeshadow", "collectible", "COLLECTIBLE_MOMS_EYESHADOW", nil, "positive", 26.95, "100%", true, "fixed")
    row(S, 31, "妈妈的香水", "Mom's Perfume", "collectible", "COLLECTIBLE_MOMS_PERFUME", nil, "positive", 85, "100%", true, "fixed")
    row(S, 32, "妈妈的假发", "Mom's Wig", "collectible", "COLLECTIBLE_MOMS_WIG", nil, "positive", 9.50, "100%", true, "fixed")
    row(S, 33, "眼球裂缝", "Ocular Rift", "collectible", "COLLECTIBLE_OCULAR_RIFT", nil, "positive", 15, "20%", true, "fixed")
    row(S, 34, "寄生虫", "Parasitoid", "collectible", "COLLECTIBLE_PARASITOID", nil, "positive", 5, "50%", true, "fixed")
    row(S, 35, "烂番茄", "Rotten Tomato", "collectible", "COLLECTIBLE_ROTTEN_TOMATO", nil, "positive", 4.01, "100%", true, "fixed")
    row(S, 36, "蜘蛛之咬", "Spider Bite", "collectible", "COLLECTIBLE_SPIDER_BITE", nil, "positive", 15, "100%", true, "fixed")
    row(S, 37, "坚韧之爱", "Tough Love", "collectible", "COLLECTIBLE_TOUGH_LOVE", nil, "positive", 9, "100%", true, "fixed")

    S = "随机触发：饰品"
    row(S, 1, "黑牙", "Black Tooth", "trinket", "TRINKET_BLACK_TOOTH", nil, "positive", 32, "100%", true, "fixed")
    row(S, 2, "该隐的眼睛", "Cain's Eye", "trinket", "TRINKET_CAINS_EYE", nil, "positive", 3, "100%", true, "fixed")
    row(S, 3, "游戏卡带", "Cartridge", "trinket", "TRINKET_CARTRIDGE", nil, "positive", 38, "100%", true, "fixed")
    row(S, 4, "咀嚼过的笔", "Chewed Pen", "trinket", "TRINKET_CHEWED_PEN", nil, "positive", 18, "100%", true, "fixed")
    row(S, 5, "夏娃的鸟足", "Eve's Bird Foot", "trinket", "TRINKET_EVES_BIRD_FOOT", nil, "positive", 7.6, "100%", true, "fixed")
    row(S, 6, "冰块", "Ice Cube", "trinket", "TRINKET_ICE_CUBE", nil, "positive", 40, "100%", true, "fixed")
    row(S, 7, "以撒的叉子", "Isaac's Fork", "trinket", "TRINKET_ISAACS_FORK", nil, "positive", 18, "100%", true, "fixed")
    row(S, 8, "颚破", "Jawbreaker", "trinket", "TRINKET_JAWBREAKER", nil, "positive", 9, "100%", true, "fixed")
    row(S, 9, "打火机", "A Lighter", "trinket", "TRINKET_LIGHTER", nil, "positive", 40, "100%", true, "fixed")
    row(S, 10, "遗失的书页", "A Missing Page", "trinket", "TRINKET_MISSING_PAGE", nil, "positive", 60, "50%", true, "fixed")
    row(S, 11, "老旧电容", "Old Capacitor", "trinket", "TRINKET_OLD_CAPACITOR", nil, "positive", 4.34, "33%", true, "fixed")
    row(S, 12, "衔尾蛇虫", "Ouroboros Worm", "trinket", "TRINKET_OUROBOROS_WORM", nil, "positive", 9, "100%", true, "fixed")
    row(S, 13, "粉红眼", "Pinky Eye", "trinket", "TRINKET_PINKY_EYE", nil, "positive", 18, "100%", true, "fixed")
    row(S, 14, "图钉", "Push Pin", "trinket", "TRINKET_PUSH_PIN", nil, "positive", 18, "100%", true, "fixed")
    row(S, 15, "红色补丁", "Red Patch", "trinket", "TRINKET_RED_PATCH", nil, "positive", 8, "100%", true, "fixed")
    row(S, 16, "参孙的锁链", "Samson's Lock", "trinket", "TRINKET_SAMSONS_LOCK", nil, "positive", 9.34, "100%", true, "fixed")

    S = "随机触发：收藏品与组合"
    row(S, 1, "黑曜石剑", "Athame", "collectible", "COLLECTIBLE_ATHAME", nil, "positive", 30, "100%", true, "fixed")
    row(S, 2, "破损的调制解调器", "Broken Modem", "collectible", "COLLECTIBLE_BROKEN_MODEM", "截图仅说明随幸运提高；未给出满概率阈值", "positive", nil, "未列出", false, "none")
    row(S, 3, "凯尔特十字", "Celtic Cross", "collectible", "COLLECTIBLE_CELTIC_CROSS", nil, "positive", 26.67, "100%", true, "fixed")
    row(S, 4, "嗝屁猫", "Gimpy", "collectible", "COLLECTIBLE_GIMPY", nil, "positive", 20, "50%", false, "fixed", "Afterbirth+（截图旧版）")
    row(S, 5, "嗝屁猫", "Gimpy", "collectible", "COLLECTIBLE_GIMPY", nil, "positive", 46, "100%", true, "fixed")
    row(S, 6, "弥达斯之触 + 反人类卡", "Midas' Touch + A Card Against Humanity", "synergy", "COLLECTIBLE_MIDAS_TOUCH", "CARD_AGAINST_HUMANITY", "positive", 18, "100%", true, "dynamic")
    row(S, 7, "弥达斯之触 + 大便", "Midas' Touch + The Poop", "synergy", "COLLECTIBLE_MIDAS_TOUCH", "COLLECTIBLE_POOP", "positive", 5, "100%", false, "dynamic", "Afterbirth+（截图旧版）")
    row(S, 8, "弥达斯之触 + 大便", "Midas' Touch + The Poop", "synergy", "COLLECTIBLE_MIDAS_TOUCH", "COLLECTIBLE_POOP", "positive", 6.56, "100%", true, "dynamic")
    row(S, 9, "弥达斯之触 + 放松胶囊", "Midas' Touch + Re-Lax", "synergy", "COLLECTIBLE_MIDAS_TOUCH", "PILL_RELAX", "positive", 7.50, "100%", true, "dynamic")
    row(S, 10, "神秘礼物", "Mystery Gift", "collectible", "COLLECTIBLE_MYSTERY_GIFT", "幸运越高，煤块/大便失败概率越低；无有限正向满概率", "reverse", -10, "反向：-10 时失败概率 100%", false, "none")
    row(S, 11, "老旧绷带", "Old Bandage", "collectible", "COLLECTIBLE_OLD_BANDAGE", nil, "positive", 26.67, "50%", false, "fixed", "Afterbirth+（截图旧版）")
    row(S, 12, "老旧绷带", "Old Bandage", "collectible", "COLLECTIBLE_OLD_BANDAGE", nil, "positive", 80, "100%", true, "fixed")
    row(S, 13, "室女座", "Virgo", "collectible", "COLLECTIBLE_VIRGO", nil, "positive", 10, "100%", true, "fixed")
    row(S, 14, "肮脏的心灵", "Dirty Mind", "collectible", "COLLECTIBLE_DIRTY_MIND", nil, "positive", 7.50, "10%", true, "fixed")

    S = "Neverbirth 幸运道具"
    row(S, 1, "虚空针尖", "Needletick", "collectible", "NEVERBIRTH_NEEDLETICK", nil, "positive",
        GetNeedletickLuckCap(), "15%", true, "fixed", "Repentance", Items.Needletick)

    return rows
end

end
