-- Native charge units, reconstructed from the installed game's GetMaxCharge
-- methods and checked by native weapon probes (native-charge-contract.txt).
local W={}
function W.ReleaseBurst(w)
    local kind=w:GetWeaponType()
    return (kind==WeaponType.WEAPON_TEARS or kind==WeaponType.WEAPON_LASER)
        and w:GetModifiers() & WeaponModifier.CURSED_EYE~=0
end
function W.Release(w)
    local kind,mods=w:GetWeaponType(),w:GetModifiers()
    if W.Full(w)<=0 then return false end
    if kind==WeaponType.WEAPON_SPIRIT_SWORD then return false end
    if WeaponModifier.SOY_MILK and mods & WeaponModifier.SOY_MILK~=0 then return false end
    return not (kind==WeaponType.WEAPON_TEARS and mods & WeaponModifier.NEPTUNUS~=0)
end
function W.Full(w)
    local kind,mods,delay=w:GetWeaponType(),w:GetModifiers(),w:GetMaxFireDelay()
    local chocolate=mods & WeaponModifier.CHOCOLATE_MILK~=0
    local cursed=mods & WeaponModifier.CURSED_EYE~=0
    local remote=WeaponModifier.LUDOVICO_TECHNIQUE and mods & WeaponModifier.LUDOVICO_TECHNIQUE~=0
    if kind==WeaponType.WEAPON_BRIMSTONE then
        return remote and 0 or math.max(.001,delay)*(chocolate and 2.5 or 1)
    elseif kind==WeaponType.WEAPON_MONSTROS_LUNGS then
        return math.max(.001,delay)*(chocolate and 2.5 or 1)
    elseif kind==WeaponType.WEAPON_KNIFE or kind==WeaponType.WEAPON_BONE then
        return remote and 0 or math.max(.001,delay)*4
    elseif kind==WeaponType.WEAPON_SPIRIT_SWORD then return math.max(0,delay*4)
    elseif kind==WeaponType.WEAPON_TECH_X then return math.max(0,delay*3)
    elseif kind==WeaponType.WEAPON_FETUS then return math.max(.001,delay*3)
    elseif kind==WeaponType.WEAPON_TEARS or kind==WeaponType.WEAPON_LASER then
        local factor=1
        if kind==WeaponType.WEAPON_TEARS and mods & WeaponModifier.NEPTUNUS~=0 then factor=12
        else
            if kind==WeaponType.WEAPON_LASER and mods & WeaponModifier.MONSTROS_LUNG~=0 then factor=4.3 end
            if chocolate then factor=factor*2.5 end
            if cursed then factor=factor*2 end
        end
        return factor>1 and math.max(0,(delay+1)*factor-1) or 0
    end
    return 0
end
return W
