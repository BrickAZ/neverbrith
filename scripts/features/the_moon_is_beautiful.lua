-- Coordinates item owners and preserves the original installation phases.
return function(Neverbirth, dependencies)
    -- Private implementation state stays inside this installed feature instance.
    local private = {}
    local provided = dependencies
    dependencies = {}
    for key, value in pairs(provided) do dependencies[key] = value end
    dependencies.Private = private
    Neverbirth.Moon = Neverbirth.Moon or {}
    private.Config = {
        WindowFrames = 120,
        SilenceFrames = 60,
        DamageBonus = 1.0,
        LuckBonus = 1,
        WaveDamageMultiplier = 0.3,
        WaveRadius = 80,
        RewardChance = 10,
        CardPickRetries = 8,
        MaxReasonableCardSubtype = 10000,
        -- The prompt ANM2 uses a bottom pivot, so the player-head anchor supplies
        -- the vertical placement instead of applying a second large fixed lift.
        PromptOffset = Vector(0, 0),
        SuccessOffset = Vector(0, -42),
    }

    private.roomState = nil
    private.visuals = private.visuals or {}
    private.nextVisualId = private.nextVisualId or 0
    Neverbirth.Moon.waveDamageDepth = Neverbirth.Moon.waveDamageDepth or 0
    Neverbirth.Moon.bossBonusDepth = Neverbirth.Moon.bossBonusDepth or 0

    include('scripts.features.the_moon_is_beautiful.presentation')(Neverbirth, dependencies)
    local Room = include('scripts.features.the_moon_is_beautiful.room')(Neverbirth, dependencies)
    local Combat = include('scripts.features.the_moon_is_beautiful.combat')(Neverbirth, dependencies)
    include('scripts.features.the_moon_is_beautiful.rewards')(Neverbirth, {
        Private = private, World = dependencies.World, TheMoonIsBeautifulId = dependencies.TheMoonIsBeautifulId,
        GetPlayers = dependencies.GetPlayers, Cards = include('scripts.systems.card_rewards'),
    })

    Room.InstallUpdate()

    if ModCallbacks.MC_POST_RENDER then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_RENDER, function()
            private.RenderVisuals()
        end)
    end

    if ModCallbacks.MC_POST_NEW_ROOM then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
            private.ResetRoom()
        end)
    end

    if ModCallbacks.MC_POST_NEW_LEVEL then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function()
            private.ResetRoom()
        end)
    end

    if ModCallbacks.MC_POST_GAME_STARTED then
        Room.InstallGameStarted()
    end

    Room.InstallEvaluate()

    Combat.InstallDamage()

    if ModCallbacks.MC_POST_NPC_DEATH then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, function(_, entity)
            private.HandleMarkedDeath(entity)
        end)
    end

    if ModCallbacks.MC_POST_ENTITY_KILL then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, function(_, entity)
            private.HandleMarkedDeath(entity)
        end)
    end
    Room.InstallTeardown()
end
