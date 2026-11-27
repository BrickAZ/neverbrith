-- Assemble one Drive Glove instance. Each owner keeps handlers beside bindings.
return function(mod, context)
    local C=include('drive_glove_core')
    local D=include('drive_glove_damage')
    local W=include('drive_glove_weapon')
    local game,ID=Game(),context.ItemId
    if not ID or ID<=0 then return end
    local audio=include('drive_glove_audio')()
    local shooting = context.ShootingControls and include('scripts/systems/shooting_scope').ForOwner(context.ShootingControls, 'drive_glove')
    -- The main entry supplies this provider. Preserve the legacy standalone factory.
    local stateContext={Key=context.Key or function(p)return mod.PendingContentState.InventoryPlayerKey(p)end,
        GetPlayers=function()return context.GetPlayers()end,
        GetSaveRoot=function()return context.GetSaveRoot()end,
        GetCurrentRunSeed=function()return context.GetCurrentRunSeed()end,
        Save=function()if context.Save then context.Save()end end}
    local records=include('scripts/features/drive_glove/state')(stateContext,C,ID)
    local function now()return game:GetFrameCount()end
    local function exists(e)return e and e:Exists()end
    local nativeAttribution=Isaac.GetStatusAttributionAPIVersion and Isaac.GetStatusAttributionAPIVersion()==1
    local freeze=include('scripts/features/drive_glove/freeze')(mod,{Game=game,Now=now,Exists=exists,State=records})
    local visuals,weapon
    -- Input can request an effect only after all owners have been constructed.
    local function flush(p,s,t)
        weapon.Charge(p,s,t); weapon.Refresh(p,t)
        if visuals then visuals.Events(p,s,t) end
        audio.Events(t)
        t.events={}
    end
    local controls=include('scripts/features/drive_glove/input')(mod,{
        Core=C,State=records,Now=now,ItemId=ID,Freeze=freeze,Flush=flush,
        IsInventoryBlocking=context.IsInventoryBlocking or function(p)
            return mod.InventorySelector and mod.InventorySelector.IsBlocking(p)
        end})
    weapon=include('scripts/features/drive_glove/weapons')(mod,{
        Core=C,Rules=W,State=records,Now=now,Input=controls,Flush=flush,Shooting=shooting,Exists=exists})
    local players=include('scripts/features/drive_glove/players')(mod,{
        Core=C,State=records,Now=now,Freeze=freeze,Flush=flush,WeaponRules=W,
        Input=controls,Weapons=weapon,Game=game,Shooting=shooting})
    local damage=include('scripts/features/drive_glove/damage')(mod,{
        Core=C,Rules=D,State=records,Now=now,Game=game,Context=context,Input=controls,Freeze=freeze,Flush=flush})
    local attribution=include('scripts/features/drive_glove/attribution')(mod,{
        Core=C,Rules=D,State=records,Now=now,Exists=exists,Flush=flush,NativeAttribution=nativeAttribution})
    local api={ItemId=ID,GetState=function(p)return records.Data(p),records.Get(p)end,
        IsActive=function(p)return controls.Busy(records.Peek(p))end,Core=C,Damage=D}
    mod.DriveGlove=api
    visuals=include('drive_glove_visuals')(mod,{GetState=records.PeekVisual,GetPlayers=records.Players,
        IsHeld=records.IsHeld,IsReady=records.IsReady,Key=records.Key})
    local lifecycle=include('scripts/features/drive_glove/lifecycle')(mod,{
        Core=C,State=records,Now=now,Freeze=freeze,Attribution=attribution,Visuals=visuals,
        Weapons=weapon,Input=controls,Game=game,Exists=exists,ItemId=ID,Flush=flush,Shooting=shooting})
    players.Install.prePlayer()
    players.Install.postPlayer()
    damage.Install.earlyDamage()
    damage.Install.lateDamage()
    damage.Install.postDamage()
    -- PRE captures live sources; accepted POST damage owns the eventual kill.
    attribution.Install.npcAttackSource()
    attribution.Install.npcDamage()
    attribution.Install.died()
    if nativeAttribution then
        attribution.Install.statusApplied()
        attribution.Install.statusCopied()
        attribution.Install.sources()
    else
        Isaac.DebugString('[Drive Glove] Status attribution API unavailable; sourceless DOT kills are not guessed.')
    end
    controls.Install.input()
    controls.Install.preUse()
    controls.Install.use()
    controls.Install.cards()
    controls.Install.pickup()
    weapon.Install.weaponFired()
    weapon.Install.postWeaponFire()
    weapon.Install.evaluate()
    lifecycle.Install.postUpdate()
    lifecycle.Install.started()
    lifecycle.Install.exit()
    lifecycle.Install.newRoom()
    lifecycle.Install.cancelRoom()
    lifecycle.Install.acquire()
    freeze.InstallUpdates()
    lifecycle.Install.unload()
    lifecycle.Install.command()
    return api
end
