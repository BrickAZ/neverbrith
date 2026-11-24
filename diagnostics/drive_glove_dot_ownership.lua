-- Opt-in real-engine, two-player source attribution probe. The runner restores
-- all saves/options; this file is never included by the regular mod loader.
return function(mod)
    local started,age,index,checks,failures=false,0,0,0,0
    local players,states,current,applied,ticks={},{},nil,0,{}
    local function log(s)Isaac.DebugString('[Drive Glove runtime] '..s)end
    local function check(name,value,detail)
        checks=checks+1;if not value then failures=failures+1 end
        log((value and 'PASS ' or 'FAIL ')..name..' '..tostring(detail or ''))
    end
    mod:AddCallback('REPENTOGON_POST_DOT_APPLIED',function(_,e,ref,kind)
        applied=applied+1
        log('APPLY case='..index..' kind='..kind..' target='..e.InitSeed..' source='..tostring(ref.Entity and ref.Entity.InitSeed))
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,999999,function(_,e,d,f,ref)
        if current and e:ToNPC() then
            local kind=Isaac.GetCurrentDotDamageKind(e,ref)
            ticks[#ticks+1]=kind
            log('HIT case='..index..' kind='..kind..' amount='..d..' hp='..e.HitPoints)
        end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,function(_,e,d,f,ref)
        if current and e:ToNPC() then
            log('SETTLED case='..index..' kind='..Isaac.GetCurrentDotDamageKind(e,ref)..' hp='..e.HitPoints)
        end
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,900000,function(_,e,d,f,ref)
        if current and current.cancelSecond and ref.Entity and GetPtrHash(ref.Entity)==GetPtrHash(players[2]) then return false end
    end)
    local function enemy()
        local e=Isaac.Spawn(EntityType.ENTITY_ATTACKFLY,0,0,Game():GetRoom():GetCenterPos()+Vector(80,0),Vector(0,0),nil):ToNPC()
        e.HitPoints=1;e.MaxHitPoints=1
        return e
    end
    mod:AddCallback(ModCallbacks.MC_NPC_UPDATE,function(_,e)
        if current and (index==22 or index==23) then
            e.Velocity=Vector(8,0);e.State=4;e:ClearEntityFlags(EntityFlag.FLAG_APPEAR)
        end
    end)
    local function apply(e,p,kind,damage)
        if kind==1 then e:AddPoison(EntityRef(p),60,damage or 3.5)
        else e:AddBurn(EntityRef(p),60,damage or 3.5) end
    end
    local cases={
        {name='script player poison',owner=1,run=function(e)apply(e,players[1],1)end},
        {name='script second player burn',owner=2,run=function(e)apply(e,players[2],2)end},
        {name='poison wins simultaneous statuses',owner=1,run=function(e)apply(e,players[1],1);apply(e,players[2],2);e:SetBurnDamageTimer(10)end},
        {name='burn wins simultaneous statuses',owner=2,run=function(e)apply(e,players[1],1);apply(e,players[2],2);e:SetPoisonDamageTimer(10)end},
        {name='opposite owners poison wins',owner=2,run=function(e)apply(e,players[2],1);apply(e,players[1],2);e:SetBurnDamageTimer(10)end},
        {name='opposite owners burn wins',owner=1,run=function(e)apply(e,players[2],1);apply(e,players[1],2);e:SetPoisonDamageTimer(10)end},
        {name='familiar script poison source removed',owner=2,run=function(e)
            local f=Isaac.Spawn(EntityType.ENTITY_FAMILIAR,FamiliarVariant.BROTHER_BOBBY,0,Vector(80,80),Vector(0,0),players[2]):ToFamiliar()
            f.Player=players[2];apply(e,f,1);f:Remove()
        end},
        {name='familiar script burn source removed',owner=1,run=function(e)
            local f=Isaac.Spawn(EntityType.ENTITY_FAMILIAR,FamiliarVariant.BROTHER_BOBBY,0,Vector(80,80),Vector(0,0),players[1]):ToFamiliar()
            f.Player=players[1];apply(e,f,2);f:Remove()
        end},
        {name='plain hit cannot steal poison',owner=1,run=function(e)
            apply(e,players[1],1);e:TakeDamage(.1,0,EntityRef(players[2]),0)
        end},
        {name='weaker poison extends without replacing payload',owner=1,run=function(e)
            apply(e,players[1],1,5);apply(e,players[2],1,3)
            check('native poison damage retains maximum',e:GetPoisonDamage()==5,e:GetPoisonDamage())
        end},
        {name='stronger poison replaces payload',owner=2,run=function(e)apply(e,players[1],1,3);apply(e,players[2],1,5)end},
        {name='equal poison native replacement',owner=2,run=function(e)apply(e,players[1],1,4);apply(e,players[2],1,4)end},
        {name='weaker burn extends without replacing payload',owner=2,run=function(e)apply(e,players[2],2,5);apply(e,players[1],2,3)end},
        {name='unowned stronger payload clears owner',owner=0,run=function(e)apply(e,players[1],1,3);apply(e,nil,1,6)end},
        {name='immune application cannot replace owner',owner=1,run=function(e)
            apply(e,players[1],1,4);local n=applied;e:AddEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS)
            apply(e,players[2],1,6);e:ClearEntityFlags(EntityFlag.FLAG_NO_STATUS_EFFECTS)
            check('immune application has no observer',applied==n,applied..'/'..n)
        end},
        {name='environment final hit clears status credit',owner=0,run=function(e)
            apply(e,players[1],1);e:TakeDamage(100,0,EntityRef(nil),0)
        end},
        {name='direct second player hit keeps credit',owner=2,run=function(e)
            apply(e,players[1],1);e:TakeDamage(100,0,EntityRef(players[2]),0)
        end},
        {name='native poison tear collision',owner=2,run=function(e)
            local t=players[2]:FireTear(e.Position,Vector(0,0),false,false,false)
            t.CollisionDamage=.1;t.TearFlags=t.TearFlags|TearFlags.TEAR_POISON
        end},
        {name='native familiar burn tear collision',owner=1,run=function(e)
            players[1]:AddCollectible(CollectibleType.COLLECTIBLE_BROTHER_BOBBY)
            local f=Isaac.Spawn(EntityType.ENTITY_FAMILIAR,FamiliarVariant.BROTHER_BOBBY,0,Vector(80,80),Vector(0,0),players[1]):ToFamiliar()
            f.Player=players[1]
            local t=Isaac.Spawn(EntityType.ENTITY_TEAR,0,0,e.Position,Vector(0,0),f):ToTear()
            t.CollisionDamage=.1;t.TearFlags=t.TearFlags|TearFlags.TEAR_BURN
            log('FAMILIAR fixture player='..tostring(f.Player and f.Player.InitSeed)..' tearSpawner='..tostring(t.SpawnerEntity and t.SpawnerEntity.InitSeed))
        end},
        {name='explicit copied status keeps source',owner=2,run=function(e)
            local from=enemy();from.HitPoints=100;apply(from,players[2],1)
            from:CopyStatusEffects(e,true);from:Remove()
        end},
        {name='expired source not reused',owner=0,run=function(e)
            apply(e,players[1],1,5);e:ClearEntityFlags(EntityFlag.FLAG_POISON);e:SetPoisonCountdown(0)
            apply(e,nil,1,3)
        end},
        {name='script player bleeding',owner=1,run=function(e)
            e:AddBleeding(EntityRef(players[1]),60);e.Velocity=Vector(8,0)
        end},
        {name='familiar bleeding source removed',owner=2,run=function(e)
            local f=Isaac.Spawn(EntityType.ENTITY_FAMILIAR,FamiliarVariant.BROTHER_BOBBY,0,Vector(80,80),Vector(0,0),players[2]):ToFamiliar()
            f.Player=players[2];e:AddBleeding(EntityRef(f),60);f:Remove();e.Velocity=Vector(8,0)
        end},
        {name='same frame native poison and burn',owner=2,run=function(e)
            apply(e,players[1],1);apply(e,players[2],2)
        end},
        {name='cancelled followup cannot steal queued death',owner=1,cancelSecond=true,run=function(e)
            e:TakeDamage(100,0,EntityRef(players[1]),0);e:TakeDamage(100,0,EntityRef(players[2]),0)
        end},
        {name='removed glove receives no status credit',owner=0,run=function(e)
            apply(e,players[1],1);players[1]:RemoveCollectible(mod.DriveGlove.ItemId)
        end},
    }
    local function cleanup()
        for _,e in ipairs(Isaac.GetRoomEntities()) do
            if not e:ToPlayer() then e:Remove() end
        end
    end
    local function reset()
        cleanup();ticks={};applied=0
        for i,p in ipairs(players) do
            p:RemoveCollectible(CollectibleType.COLLECTIBLE_BROTHER_BOBBY)
            p.ControlsEnabled=false;p.Position=Vector(100,100+i*40);p.Velocity=Vector(0,0)
            if not p:HasCollectible(mod.DriveGlove.ItemId) then p:AddCollectible(mod.DriveGlove.ItemId,0,true,0) end
            local s,t=mod.DriveGlove.GetState(p);mod.DriveGlove.Core.End(t,'probe')
            s.gauge=2;s.burnout=false;states[i]=s
        end
    end
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if started then return end;started=true;Isaac.StartNewGame(0,0,0,123456789)
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,900000,function()
        age=age+1;if age<100 or age%20~=0 then return end
        if index==0 then
            check('native API is installed',Isaac.GetStatusAttributionAPIVersion and Isaac.GetStatusAttributionAPIVersion()==1)
            check('Yin API remains installed',Isaac.GetPlayerExplosionImmunityAPIVersion()==1)
            players={Isaac.GetPlayer(0),PlayerManager.SpawnCoPlayer2(0)}
            if mod.RingOfSevenCursesTestAPI then mod.RingOfSevenCursesTestAPI.ResetForTest() end
            for _,p in ipairs(players) do
                if mod.RingOfSevenCursesTestAPI then p:RemoveCollectible(mod.RingOfSevenCursesTestAPI.ItemId) end
            end
            check('player ownership keys differ',mod.PendingContentState.InventoryPlayerKey(players[1])~=mod.PendingContentState.InventoryPlayerKey(players[2]))
        elseif current then
            for i=1,2 do
                local expected=2+(current.owner==i and 1 or 0)
                check(current.name..' player '..i,math.abs(states[i].gauge-expected)<.0001,states[i].gauge..' expected '..expected)
            end
            check(current.name..' native death',not current.enemy:Exists() or current.enemy:IsDead(),
                'type='..current.enemy.Type..' hp='..current.enemy.HitPoints..' state='..current.enemy.State)
        end
        index=index+1;current=cases[index]
        if not current then log('DONE checks='..checks..' failures='..failures);age=-100000;return end
        reset();current.enemy=enemy();log('CASE '..index..' '..current.name)
        local ok,err=pcall(current.run,current.enemy);if not ok then check('case exception',false,err) end
    end)
end
