-- Assembles Black Taisui owners and preserves the original interleaved registration order.
return function(Neverbirth, dependencies)
    local Runtime = { running = true, disposed = false }
    local World = dependencies.World
    local PlayerHasCollectible = World.PlayerHasCollectible
    local BlackTaisuiId = dependencies.BlackTaisuiId
    local CleansedWavyCap = dependencies.CleansedWavyCap
    Runtime.BlackTaisuiStageTwoThreshold = 8
    Runtime.BlackTaisuiStageThreeThreshold = 16
    Runtime.BlackTaisuiStageOneDamagePenalty = 0.5
    Runtime.BlackTaisuiStageOneSpeedPenalty = 0.2
    Runtime.BlackTaisuiStageOneLuckPenalty = 3
    Runtime.BlackTaisuiStageTwoDamagePenalty = 0.5
    Runtime.BlackTaisuiStageThreeDamageBonus = 1.5
    Runtime.BlackTaisuiDamageFloor = 1
    Runtime.BlackTaisuiSpeedFloor = 0.5
    Runtime.BlackTaisuiFearDuration = 90
    Runtime.BlackTaisuiFearRadius = 180
    Runtime.BlackTaisuiWavyCap = (CollectibleType and CollectibleType.COLLECTIBLE_WAVY_CAP) or 582
    Runtime.BlackTaisuiWavyCapTearsBonus = 0.75
    Runtime.BlackTaisuiWavyCapRangeBonus = 20


    local presentation = include("scripts.features.black_taisui.presentation")(Neverbirth, { Runtime = Runtime,
        VisualEffects = dependencies.VisualEffects, GetFolkGame = World.GetFolkGame,
        GetPlayers = dependencies.GetPlayers, MeatLump = dependencies.MeatLump,
    })
    local growth = include("scripts.features.black_taisui.growth")(Neverbirth, { Runtime = Runtime,
        VisualEffects = dependencies.VisualEffects, GetFolkGame = World.GetFolkGame,
        GetFolkPlayerKey = World.GetFolkPlayerKey, PlayerHasCollectible = PlayerHasCollectible,
        BlackTaisuiId = BlackTaisuiId, MeatLumpId = dependencies.MeatLumpId,
        CleansedWavyCap = CleansedWavyCap, IsValidItemId = dependencies.IsValidItemId, ParasiteState = dependencies.ParasiteState, Store = dependencies.Store,
    })
    include("scripts.features.black_taisui.survival")(Neverbirth, { Runtime = Runtime,
        Presentation = presentation, VisualEffects = dependencies.VisualEffects, GetSurvivalCooldown = assert(dependencies.GetSurvivalCooldown),
        GetFolkRoomKey = World.GetFolkRoomKey, GetFolkFloorKey = World.GetFolkFloorKey,
        BlackTaisuiId = BlackTaisuiId, PlayerHasCollectible = PlayerHasCollectible,
        IsIncomingDamageLethal = dependencies.IsIncomingDamageLethal,
        IsVulnerableEnemy = World.IsVulnerableEnemy, SpawnFolkEffect = World.SpawnFolkEffect,
    })
    growth.InstallCacheCallback()

    include("scripts.features.black_taisui.purification")(Neverbirth, { Runtime = Runtime,
        VisualEffects = assert(dependencies.VisualEffects), GetFolkGame = World.GetFolkGame,
        GetFolkRoomKey = World.GetFolkRoomKey, GetFolkFloorKey = World.GetFolkFloorKey,
        GetFolkPlayerKey = World.GetFolkPlayerKey, GetPlayers = dependencies.GetPlayers,
        BlackTaisuiId = BlackTaisuiId, CleansedWavyCapId = dependencies.CleansedWavyCapId,
        IsValidItemId = dependencies.IsValidItemId, PlayerHasCollectible = PlayerHasCollectible, DebugLog = dependencies.Log,
    })
    return include("scripts.features.black_taisui.lifecycle")(Neverbirth, { Runtime = Runtime,
        Presentation = presentation, MeatLump = dependencies.MeatLump,
        GetPlayers = dependencies.GetPlayers, GetFolkFloorKey = World.GetFolkFloorKey,
        GetFolkRoomKey = World.GetFolkRoomKey, GetFolkPlayerKey = World.GetFolkPlayerKey,
        PlayerHasCollectible = PlayerHasCollectible, BlackTaisuiId = BlackTaisuiId,
        CleansedWavyCap = CleansedWavyCap, VisualEffects = dependencies.VisualEffects, ParasiteState = dependencies.ParasiteState,
    })
end
