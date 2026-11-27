-- Shared existing lethal-hit query used by Musicbox, Black Taisui and Meat Lump.
local function IsIncomingDamageLethal(player, amount)
    if player.HasMortalDamage and player:HasMortalDamage() then
        return true
    end

    local totalHealth = 0
    if player.GetHearts then
        totalHealth = totalHealth + player:GetHearts()
    end
    if player.GetSoulHearts then
        totalHealth = totalHealth + player:GetSoulHearts()
    end
    if player.GetBoneHearts then
        totalHealth = totalHealth + player:GetBoneHearts() * 2
    end

    return totalHealth > 0 and amount ~= nil and amount >= totalHealth
end

return IsIncomingDamageLethal
