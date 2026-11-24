-- Audited official 1.0.12a sections from the verified pre-install main_ex.lua.
-- Source SHA256: 2C05C2B9C838FE801A1399229F3620E56148EDDD29E5A412B7AE1C5874B1E6E7
return {
 comparator=[====[
local function CallbackComparator(a, b)
	if not a or not b then
		return a ~= nil
	elseif a.Priority == b.Priority then
		return a.AddOrder < b.AddOrder
	else
		return a.Priority < b.Priority
	end
end

]====],
 dispatcher=[====[
function _RunEntityTakeDmgCallback(callbackID, param, entity, damage, damageFlags, source, damageCountdown)
	local combinedRet

	for callback in GetCallbackIterator(callbackID, param) do
		local ret = RunCallbackInternal(callbackID, callback, entity, damage, damageFlags, source, damageCountdown)
		if ret ~= nil then
			if type(ret) == "boolean" and ret == false then
				-- Only terminate the callback early if someone returns FALSE.
				-- RIP to returning true stopping the callback.
				return false
			elseif type(ret) == "table" then
				-- Set / update overrides to damage etc so that they are visible to later callbacks.
				if ret.Damage and type(ret.Damage) == "number" then
					damage = ret.Damage
				end
				if ret.DamageFlags and type(ret.DamageFlags) == "number" and ret.DamageFlags == math.floor(ret.DamageFlags) then
					damageFlags = ret.DamageFlags
				end
				if ret.DamageCountdown and type(ret.DamageCountdown) == "number" then
					damageCountdown = ret.DamageCountdown
				end
				if combinedRet then
					for k, v in pairs(ret) do
						combinedRet[k] = v
					end
				else
					combinedRet = ret
				end
			end
		end
	end

	return combinedRet
end

]====],
}
