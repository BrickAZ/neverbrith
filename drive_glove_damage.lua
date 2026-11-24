-- Early cancellation avoids the native hurt path, including Mantle and hurt procs.
-- Keep classification separate from callback wiring so exclusions can be tested.
local D={}
function D.Flag(flags,name)
    local bit=DamageFlag[name]; return bit and flags & bit~=0 or false
end
function D.Payment(player,flags,source,room,activePayment)
    for _,name in ipairs({'DAMAGE_IV_BAG','DAMAGE_CHEST','DAMAGE_DEVIL'}) do
        if D.Flag(flags,name) then return true end
    end
    local e=source and source.Entity
    if e and e.Type==EntityType.ENTITY_SLOT then
        return e.Variant==SlotVariant.BLOOD_DONATION_MACHINE or e.Variant==SlotVariant.DEVIL_BEGGAR
    end
    if D.Flag(flags,'DAMAGE_SPIKES') and room:GetType()==RoomType.ROOM_SACRIFICE then return true end
    if activePayment and (not e or e.Type==EntityType.ENTITY_PLAYER) then return true end
    -- Razor and Sharp Plug use forced red-heart/self damage. Do not generalize
    -- DAMAGE_NO_PENALTIES (ordinary enemies/mods may use it) into a payment flag.
    return D.Flag(flags,'DAMAGE_INVINCIBLE') and (D.Flag(flags,'DAMAGE_RED_HEARTS')
        or D.Flag(flags,'DAMAGE_NO_PENALTIES')) and (not e or e.Type==EntityType.ENTITY_PLAYER)
end
function D.Bomb(flags,source)
    local e=source and source.Entity
    return (e and e.Type==EntityType.ENTITY_BOMBDROP) or (source and source.Type==EntityType.ENTITY_BOMBDROP) or false
end
function D.NormalDirection(player,flags,source)
    local e=source and source.Entity
    if not e then return end
    for _,name in ipairs({'DAMAGE_LASER','DAMAGE_SPIKES','DAMAGE_POOP','DAMAGE_ACID',
        'DAMAGE_CURSED_DOOR','DAMAGE_PITFALL'}) do
        if D.Flag(flags,name) then return end
    end
    if e.Type==EntityType.ENTITY_LASER then return end
    if e.Type==EntityType.ENTITY_PROJECTILE or e.Type==EntityType.ENTITY_TEAR then
        if e.Velocity:LengthSquared()>.001 then return e.Velocity end
        return
    end
    -- A live enemy's ordinary collision is contact. Its sourced explosion is not.
    if e:ToNPC() and not D.Flag(flags,'DAMAGE_EXPLOSION') and not D.Flag(flags,'DAMAGE_CRUSH') then return end
    if e.Type==EntityType.ENTITY_EFFECT and not D.Flag(flags,'DAMAGE_EXPLOSION') then return end
    local direction=player.Position-e.Position
    if direction:LengthSquared()>.001 then return direction end
end
function D.NormalAmount(player,amount,flags,game)
    amount=math.max(1,math.ceil(amount))
    -- These modifiers are normally applied after PRE_PLAYER_TAKE_DMG.
    if not D.Flag(flags,'DAMAGE_NO_MODIFIERS') then
        if player:HasCollectible(CollectibleType.COLLECTIBLE_WAFER) then amount=1
        elseif game:GetLevel():GetStage()>=LevelStage.STAGE4_1 then amount=math.max(2,amount) end
    end
    local kind=player:GetPlayerType()
    if kind==PlayerType.PLAYER_KEEPER or kind==PlayerType.PLAYER_KEEPER_B then amount=math.ceil(amount/2)*2 end
    -- Glass Cannon's break damage is a later, separate hurt consequence. A
    -- successful guard prevents that path, so it is not charged in advance.
    return amount
end
function D.Impact(player,flags,source)
    for _,name in ipairs({'DAMAGE_SPIKES','DAMAGE_POOP','DAMAGE_ACID','DAMAGE_PITFALL'}) do
        if D.Flag(flags,name) then return 'Floor',0 end
    end
    local e=source and source.Entity
    if not e then return 'Center',0 end
    if e.Type==EntityType.ENTITY_PROJECTILE or e.Type==EntityType.ENTITY_TEAR then
        if e.Velocity:LengthSquared()>.001 then return '',e.Velocity:GetAngleDegrees()+180 end
    end
    local direction=e.Position-player.Position
    if direction:LengthSquared()>.001 then return '',direction:GetAngleDegrees() end
    return 'Center',0
end
function D.Invulnerable(player,flags)
    if D.Flag(flags,'DAMAGE_FAKE') then return true end
    if player:GetDamageCooldown()>0 then return true end
    if D.Flag(flags,'DAMAGE_COUNTDOWN') and player:GetDamageCountdown()>0 then return true end
    if D.Flag(flags,'DAMAGE_FIRE') and player:GetFireDamageCooldown()>0 then return true end
    return false
end
function D.Cooldown(player,amount,flags,countdown)
    -- Native GetDamageCooldown / SetMinDamageCooldown use 60 Hz units, whereas
    -- the action state machine uses 30 Hz ticks. Half/full-heart hits: 60/120.
    local cooldown=amount>1 and 120 or 60
    local blind=player:GetTrinketMultiplier(TrinketType.TRINKET_BLIND_RAGE)
    -- GetTrinketMultiplier already includes Mom's Box.
    if blind>0 then cooldown=cooldown*2*blind end
    player:SetMinDamageCooldown(cooldown)
    if D.Flag(flags,'DAMAGE_COUNTDOWN') then player:SetDamageCountdown(countdown) end
    if D.Flag(flags,'DAMAGE_FIRE') then player:SetFireDamageCooldown(10) end
end
function D.Health(player)
    return {player:GetHearts(),player:GetSoulHearts(),player:GetBoneHearts()}
end
function D.LostHealth(before,player)
    local after=D.Health(player)
    return after[1]<before[1] or after[2]<before[2] or after[3]<before[3]
end
return D
