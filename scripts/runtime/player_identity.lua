-- Existing persistent identity contract. Do not substitute a runtime pointer key.
local Identity = {}

function Identity.PlayerKey(player)
    if not player then return 'missing' end
    local t=player.GetPlayerType and player:GetPlayerType()
    local types=PlayerType or {}
    if t and (t==types.PLAYER_LAZARUS_B or t==types.PLAYER_LAZARUS2_B) then
        -- Only Lazarus forms share this key. Jacob and Esau are independent.
        local partner=player.GetOtherTwin and player:GetOtherTwin()
        if not partner and player.GetSubPlayer then partner=player:GetSubPlayer() end
        local pt=partner and partner.GetPlayerType and partner:GetPlayerType()
        local identity=player.InitSeed or 0
        if partner and pt and (pt==types.PLAYER_LAZARUS_B or pt==types.PLAYER_LAZARUS2_B) then
            identity=math.min(identity,partner.InitSeed or identity)
        end
        return 'lazarus:'..tostring(identity)..':'..tostring(player.ControllerIndex or 0)
    end
    return tostring(player.InitSeed or 0)..':'..tostring(player.ControllerIndex or 0)
end

function Identity.InventoryPlayerKey(player)
    return Identity.PlayerKey(player)..':form:'..tostring(player.InitSeed or 0)
end

return Identity
