-- Load explicitly from the console only; no normal-play loader/health changes.
return function(mod)
    if rawget(_G,"NEVERBIRTH_YIN_EXPLOSION_DIAGNOSTICS") ~= true then
        Isaac.DebugString("[Yin acceptance] Set NEVERBIRTH_YIN_EXPLOSION_DIAGNOSTICS=true before loading this diagnostic.")
        return
    end
    if mod.YinExplosionDiagnostics then mod.YinExplosionDiagnostics.Enable();return end
    local callback=ModCallbacks.MC_PRE_PLAYER_EXPLOSION_IMMUNITY
    if not callback or not Isaac.GetPlayerExplosionImmunityAPIVersion
        or Isaac.GetPlayerExplosionImmunityAPIVersion()~=1 then
        Isaac.DebugString("[Yin acceptance] Complete native API v1 is unavailable.");return
    end
    local registered={};local api={Enabled=false};mod.YinExplosionDiagnostics=api
    local function log(text) Isaac.DebugString("[Yin acceptance] "..text) end
    local function add(id,fn,priority)
        if not id then return end
        mod:AddPriorityCallback(id,priority or 0,fn)
        registered[#registered+1]={id,fn}
    end
    local function identity(p) return tostring(p.InitSeed).."/"..tostring(p:GetPlayerType()) end
    local function immunity(_,p,h,i)
        log("call="..tostring(h.callId).." player="..identity(p).." seed="..tostring(Game():GetSeeds():GetStartSeed())
            .." source="..tostring(i.sourceKey).." site="..tostring(i.siteKey)
            .." damage="..tostring(h.damage).." flags="..tostring(h.flags).." countdown="..tostring(h.countdown)
            .." candle="..tostring(p:HasCollectible(CollectibleType.COLLECTIBLE_BLACK_CANDLE)))
    end
    local function heal(_,p,amount,healthType)
        log("heal-attempt player="..identity(p).." amount="..tostring(amount).." type="..tostring(healthType))
    end
    local function healed(_,p,amount,healthType)
        log("heal-return player="..identity(p).." amount="..tostring(amount).." type="..tostring(healthType)
            .." red="..p:GetHearts().." soul="..p:GetSoulHearts())
    end
    local function postDamage(_,entity,amount,flags,source,countdown)
        local p=entity:ToPlayer();if not p then return end
        log("post-damage player="..identity(p).." amount="..tostring(amount).." flags="..tostring(flags)
            .." countdown="..tostring(countdown).." red="..p:GetHearts().." soul="..p:GetSoulHearts())
    end
    function api.Enable()
        if api.Enabled then return end
        api.Enabled=true;rawset(Isaac,"_PlayerExplosionImmunityDebug",true)
        add(callback,immunity,-1000)
        add(ModCallbacks.MC_PRE_PLAYER_ADD_HEARTS,heal,1000)
        add(ModCallbacks.MC_POST_PLAYER_ADD_HEARTS,healed,1000)
        add(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,postDamage,1000)
        log("enabled; seed="..tostring(Game():GetSeeds():GetStartSeed()).." immunity-listeners="..tostring(#Isaac.GetCallbacks(callback)))
    end
    function api.Disable()
        for _,r in ipairs(registered) do mod:RemoveCallback(r[1],r[2]) end
        registered={};api.Enabled=false;rawset(Isaac,"_PlayerExplosionImmunityDebug",false)
        NEVERBIRTH_YIN_EXPLOSION_DIAGNOSTICS=false;log("disabled")
    end
    api.Enable()
end
