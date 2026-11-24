-- Explicit temporary acceptance loader; not included during normal play.
return function(mod)
    local function log(s) Isaac.DebugString("[Yin runtime probe] "..s) end
    log("YIN_RUNTIME_STAGE="..tostring(NEVERBIRTH_YIN_TEST_STAGE))
    local ok, version = pcall(Isaac.GetPlayerExplosionImmunityAPIVersion)
    log("version="..tostring(REPENTOGON and REPENTOGON.Version).." api="..tostring(ok and version or "error")
        .." callback="..tostring(ModCallbacks.MC_PRE_PLAYER_EXPLOSION_IMMUNITY)
        .." yin="..tostring(Isaac.GetItemIdByName("Yin's Curse")).." mod="..tostring(mod ~= nil))
    local seen=false
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if seen then return end
        seen=true
        log("main-menu-render; api="..tostring(Isaac.GetPlayerExplosionImmunityAPIVersion())
            .." menu="..tostring(MenuManager.GetActiveMenu()))
    end)
end
