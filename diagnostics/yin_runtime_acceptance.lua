-- Explicit temporary test runner. Runs only in a backed-up, seeded test session.
-- Setup changes inventory/health; attacks call the real engine, never the Lua fixture.
return function(mod)
    local function log(s) Isaac.DebugString("[Yin runtime acceptance] "..s) end
    log("YIN_RUNTIME_STAGE="..tostring(NEVERBIRTH_YIN_TEST_STAGE))
    if Isaac.GetPlayerExplosionImmunityAPIVersion()~=1 then log("ABORT api unavailable");return end
    local started=false
    local cases={
        {name="inactive-no-source",loss=1,sites=0},
        {name="inactive-pyro-full",pyro=true,loss=0,sites=1},
        {name="inactive-pyro-low",pyro=true,low=true,loss=-1,sites=1,heals=1},
        {name="inactive-host",host=true,loss=0,sites=1},
        {name="active-no-source-no-candle",active=true,loss=1,sites=0},
        {name="active-no-source-candle",active=true,candle=true,loss=1,sites=0},
        {name="active-pyro-candle",active=true,pyro=true,candle=true,loss=0,sites=1},
        {name="active-pyro-no-candle",active=true,pyro=true,loss=1,sites=1},
        {name="active-pyro-low",active=true,pyro=true,low=true,loss=0,sites=1,heals=1},
        {name="active-host-candle",active=true,host=true,candle=true,loss=0,sites=1},
        {name="active-host-no-candle",active=true,host=true,loss=1,sites=1},
        {name="active-pyro-and-host",active=true,pyro=true,host=true,loss=1,sites=2},
        {name="active-pyro-fire",active=true,pyro=true,fire=true,loss=0,sites=0},
        {name="active-pyro-fire-explosion",active=true,pyro=true,mixed=true,loss=0,sites=0},
        {name="active-pyro-old-cancel",active=true,pyro=true,cancel=true,loss=0,sites=1},
        {name="active-pyro-pre-player-cancel",active=true,pyro=true,preCancel=true,loss=0,sites=0},
        {name="active-pyro-api-zero",active=true,pyro=true,apiZero=true,loss=0,sites=0},
        {name="active-pyro-return-chain",active=true,pyro=true,chain=true,loss=1,sites=1},
        {name="active-pyro-real-bomb",active=true,pyro=true,bomb=true,loss=2,sites=1},
    }
    local activeCase,observed,frame,index,phase,passed= nil,{},0,0,"idle",0
    local immunity=function(_,p,h,i)
        if activeCase and phase=="attack" then observed[#observed+1]={call=h.callId,source=i.sourceKey,site=i.siteKey,player=p.InitSeed,flags=h.flags} end
    end
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_EXPLOSION_IMMUNITY,999999,immunity)
    local heals=0
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_ADD_HEARTS,function(_,p,amount,kind)
        if activeCase and phase=="attack" and amount>0 and kind==AddHealthType.RED then heals=heals+1 end
    end)
    local post=0
    mod:AddCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,function(_,e)
        if activeCase and phase=="attack" and e:ToPlayer() then post=post+1 end
    end)
    local function inventory(p,id,want)
        while p:HasCollectible(id) do p:RemoveCollectible(id) end
        if want then p:AddCollectible(id,0,true) end
    end
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if started then return end
        started=true
        log("START seeded test from menu="..tostring(MenuManager.GetActiveMenu()))
        Isaac.StartNewGame(0,0,0,123456789)
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_GAME_STARTED,999999,function(_,continued)
        log("GAME seed="..Game():GetSeeds():GetStartSeed().." continued="..tostring(continued).." player="..Isaac.GetPlayer(0).InitSeed.." type="..Isaac.GetPlayer(0):GetPlayerType())
        NEVERBIRTH_YIN_EXPLOSION_DIAGNOSTICS=true
        include("diagnostics/yin_explosion_immunity_acceptance")(mod)
        phase="wait";frame=0
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,999999,function()
        if phase=="done" or phase=="idle" then return end
        frame=frame+1
        local p=Isaac.GetPlayer(0);p.ControlsEnabled=false
        if phase=="wait" and frame>=110 then
            index=index+1;activeCase=cases[index]
            if not activeCase then
                mod.YinExplosionDiagnostics.Disable()
                phase="done";log("DONE passed="..passed.." total="..#cases);return
            end
            local c=activeCase
            inventory(p,CollectibleType.COLLECTIBLE_PYROMANIAC,c.pyro)
            inventory(p,CollectibleType.COLLECTIBLE_HOST_HAT,c.host)
            inventory(p,CollectibleType.COLLECTIBLE_BLACK_CANDLE,c.candle)
            if c.active and not p:HasCollectible(mod.YinsCurseTestAPI.ItemId) then p:AddCollectible(mod.YinsCurseTestAPI.ItemId,0,true) end
            p:AddSoulHearts(-99);p:AddHearts(99)
            if c.low then p:AddHearts(-2) end
            frame=0;phase="setup"
        elseif phase=="setup" and frame>=20 then
            local c=activeCase
            c.before=p:GetHearts();observed={};heals=0;post=0;phase="attack";frame=0
            log("CASE "..c.name.." before="..c.before.." active="..tostring(mod.YinsCurseTestAPI.GetSavedState().yinCurseActive).." candle="..tostring(p:HasCollectible(260)))
            local flags=c.fire and DamageFlag.DAMAGE_FIRE or c.mixed and (DamageFlag.DAMAGE_FIRE|DamageFlag.DAMAGE_EXPLOSION) or DamageFlag.DAMAGE_EXPLOSION
            local cancel=function() return false end
            local chain={function() return true end,function() return nil end,function() error("intentional acceptance listener error") end,function() return "invalid acceptance return" end}
            if c.cancel then mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,-999999,cancel,EntityType.ENTITY_PLAYER) end
            if c.preCancel then mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,-999999,cancel) end
            if c.chain then for n,fn in ipairs(chain) do mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_EXPLOSION_IMMUNITY,100+n,fn) end end
            local previousVersion=Isaac._PlayerExplosionImmunityDispatchVersion
            if c.apiZero then Isaac._PlayerExplosionImmunityDispatchVersion=0;log("CAPABILITY during negative="..Isaac.GetPlayerExplosionImmunityAPIVersion()) end
            if c.bomb then
                local b=Isaac.Spawn(EntityType.ENTITY_BOMB,BombVariant.BOMB_NORMAL,0,p.Position,Vector.Zero,p):ToBomb()
                b:SetExplosionCountdown(1)
            else
                c.returned=p:TakeDamage(1,flags,EntityRef(p),0)
            end
            if c.apiZero then Isaac._PlayerExplosionImmunityDispatchVersion=previousVersion;log("CAPABILITY restored="..Isaac.GetPlayerExplosionImmunityAPIVersion()) end
            if c.cancel then mod:RemoveCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,cancel) end
            if c.preCancel then mod:RemoveCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,cancel) end
            if c.chain then for _,fn in ipairs(chain) do mod:RemoveCallback(ModCallbacks.MC_PRE_PLAYER_EXPLOSION_IMMUNITY,fn) end end
        elseif phase=="attack" and frame>=10 then
            local c=activeCase;local loss=c.before-p:GetHearts()
            local expectedPost=(c.bomb or c.loss>0 or (c.low and c.active)) and 1 or 0
            local okay=loss==c.loss and #observed==c.sites and heals==(c.heals or 0) and post==expectedPost
            if okay then passed=passed+1 end
            log("RESULT "..c.name.." "..(okay and "PASS" or "FAIL").." loss="..loss.." expected="..c.loss.." sites="..#observed.." expectedSites="..c.sites.." heals="..heals.." post="..post.." returned="..tostring(c.returned))
            for n,h in ipairs(observed) do log("OBS "..c.name.." n="..n.." call="..h.call.." site="..h.site.." source="..h.source.." flags="..h.flags.." player="..h.player) end
            activeCase=nil;phase="wait";frame=0
        end
    end)
end
