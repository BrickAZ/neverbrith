return function(Neverbirth, dependencies)
    local Runtime = { running = true, disposed = false }
    local rules = include("scripts.features.coin_sewn_sword.rules")

    local aiming = include("scripts.features.coin_sewn_sword.aiming")(Neverbirth, {
        IsVulnerableEnemy = dependencies.World.IsVulnerableEnemy,
    })
    local presentation = include("scripts.features.coin_sewn_sword.presentation")(Neverbirth, { Rules = rules, Runtime = Runtime })
    local qi = include("scripts.features.coin_sewn_sword.qi")(Neverbirth, {
        World = dependencies.World, Log = dependencies.Log, Rules = rules,
        Aiming = aiming, Presentation = presentation,
        Runtime = Runtime,
    })
    -- Preserve the original effect -> debug -> later hold registration order.
    presentation.InstallDebugCallback()
    local attack = include("scripts.features.coin_sewn_sword.attack")(Neverbirth, {
        World = dependencies.World, Rules = rules, Aiming = aiming, SpawnQi = qi.Spawn,
    })
    return include("scripts.features.coin_sewn_sword.input")(Neverbirth, {
        CoinSewnSwordId = dependencies.CoinSewnSwordId, Rules = rules,
        Fire = attack.Fire, VectorFromInput = aiming.VectorFromInput,
        Runtime = Runtime, ReleaseEffects = qi.ReleaseAll,
    })
end
