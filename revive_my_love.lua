-- Legacy factory path. Main passes the dynamic Avada query explicitly.
return function(mod, context)
    context = context or {}
    local dependencies = setmetatable({}, { __index = context })
    dependencies.IsFailureDeath = context.IsFailureDeath or function(player)
        return mod.AvadaKedavra and mod.AvadaKedavra.IsFailureDeath(player)
    end
    return include("scripts.features.revive_my_love")(mod, dependencies)
end
