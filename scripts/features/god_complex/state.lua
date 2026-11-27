-- Private state responsibilities for god_complex; created once by its entry.
return function(mod, context, deps)
    local callbackInstallers = {}
    local data = {active={}, lastUses={}, collisions={}, before={}, pending={}, settled={}, shootRestore={}, ready=false, badVisuals={}}
    local ID = context.ItemId
    local Shooting = deps.Shooting
    local CACHE = deps.Config.CACHE

    local function log(message) if context.DebugLog then context.DebugLog('[God Complex] '..message) end end

    local function key(e) return tostring(GetPtrHash(e))..':'..tostring(e.InitSeed) end

    local function same(a,b) return a and b and key(a)==key(b) end

    local function saveKey(p) return tostring(p.InitSeed)..':'..tostring(p.ControllerIndex) end

    local function exists(e) return e and e:Exists() end

    local function alive(p) return exists(p) and not p:IsDead() and not p:IsCoopGhost() and not p:HasMortalDamage() end

    local function frame() return Game():GetFrameCount() end

    local function location()
        local l=Game():GetLevel();local d=l:GetCurrentRoomDesc()
        return table.concat({tostring(context.GetCurrentRunSeed()),l:GetStage(),l:GetStageType(),
            l:GetDungeonPlacementSeed(),l:GetDimension(),d.ListIndex,d.SafeGridIndex,d.SpawnSeed},':')
    end

    local function saved()
        local root=context.GetSaveRoot();local run=tostring(context.GetCurrentRunSeed())
        if type(root.godComplex)~='table' or root.godComplex.run~=run then
            root.godComplex={version=1,run=run,players={}}
        end
        if type(root.godComplex.players)~='table' then root.godComplex.players={} end
        return root.godComplex
    end

    local function refresh(p) if exists(p) then p:AddCacheFlags(CACHE);p:EvaluateItems() end end

    local function state(p)
        local s=p and data.active[key(p)]
        if data.ready and s and alive(p) and p:HasCollectible(ID) and s.room==location() and s.age<240 then return s end
    end

    local function restoreShoot(k)
        Shooting.Restore(data.shootRestore, k, exists)
    end

    local function stop(k)
        local s=data.active[k];data.active[k]=nil;restoreShoot(k)
        if not s then return end
        for _,t in pairs(s.tears) do
            if exists(t.entity) then t.entity:ClearTearFlags(t.bits) end
        end
        for _,projectile in ipairs(s.projectiles or {}) do if exists(projectile) then projectile:Remove() end end
        for id,r in pairs(data.pending) do if r.state==s then data.pending[id]=nil end end
        s.target=nil;s.cooldown=nil;s.visuals={};s.strikes={};s.tears={}
        refresh(s.player)
    end

    local function clear()
        local keys={};for k in pairs(data.active) do keys[#keys+1]=k end
        for _,k in ipairs(keys) do stop(k) end
        for k in pairs(data.shootRestore) do restoreShoot(k) end
        data.collisions={};data.before={};data.pending={};data.settled={}
    end
    function callbackInstallers.clear()
        return mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,clear)
    end
    function callbackInstallers.clear2()
        return mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,clear)
    end

    return {
        Data = data,
        Installers = callbackInstallers,
        log = log,
        key = key,
        same = same,
        saveKey = saveKey,
        exists = exists,
        alive = alive,
        frame = frame,
        location = location,
        saved = saved,
        refresh = refresh,
        state = state,
        restoreShoot = restoreShoot,
        stop = stop,
        clear = clear,
    }
end
