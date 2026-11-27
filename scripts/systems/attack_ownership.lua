-- Existing attack priority only; damage attribution and cleanup stay with each item.
local Ownership = {}

-- Resolve the current compatibility table/method on every call. This preserves
-- replacement, short-circuit and error behavior; no truth-value normalization.
function Ownership.AvadaOwnsAttack(mod, player)
    return mod.AvadaKedavra and mod.AvadaKedavra.OwnsAttack(player)
end

return Ownership
