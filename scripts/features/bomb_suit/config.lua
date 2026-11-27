-- Item policy constants; no callbacks or runtime state.
    local DURATION, BONUS = 90, 0.5
    -- Native entities2.xml: 6.2 is the blood donation machine; 6.5 is the devil beggar.
    -- IV Bag has its dedicated damage flag. Do not classify Razor, Blood Rights,
    -- Sharp Plug, sacrifice spikes or all NO_PENALTIES hits as blood payment.
    local BLOOD_SLOT, DEVIL_BEGGAR = 2, 5

    local OWNER_MARKER = "NeverbirthBombSuitOwner"
    local beepAt = {[0]=true,[30]=true,[50]=true,[65]=true,[75]=true,[81]=true,[86]=true,[89]=true}


return {
    DURATION = DURATION,
    BONUS = BONUS,
    BLOOD_SLOT = BLOOD_SLOT,
    DEVIL_BEGGAR = DEVIL_BEGGAR,
    OWNER_MARKER = OWNER_MARKER,
    beepAt = beepAt,
}
