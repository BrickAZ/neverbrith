-- Coordinates item owners and preserves the original installation phases.
return function(Neverbirth, dependencies)
    local Runtime = { running = true, disposed = false }
    local childDependencies = {}
    for key, value in pairs(dependencies) do childDependencies[key] = value end
    childDependencies.Runtime = Runtime
    local VisualEffects = assert(dependencies.VisualEffects)
    local GetFolkRoom = dependencies.World.GetFolkRoom
    local GetFolkPlayerKey = dependencies.World.GetFolkPlayerKey
    local GetFolkRandomInt = dependencies.World.GetFolkRandomInt
    local GoodGirlOfBabylonId = dependencies.GoodGirlOfBabylonId
    local GetPlayers = dependencies.GetPlayers
    local PublishGlobal = dependencies.PublishGlobal
    local GOOD_GIRL_REWARD_CHANCE = 33

    Neverbirth.GoodGirl = Neverbirth.GoodGirl or {
        CostumePath = "gfx/characters/costume_good_girl_of_babylon.anm2",
        CardPickRetries = 16,
        MaxReasonableCardSubtype = 10000,
        states = {},
        costumeStates = {},
        costumeId = nil,
    }

    local Presentation = include('scripts.features.good_girl_of_babylon.presentation')(Neverbirth, childDependencies)
    Runtime.RemoveFollowEffect = Presentation.RemoveFollowEffect
    local State = include('scripts.features.good_girl_of_babylon.state')(Neverbirth, childDependencies)
    local Combat = include('scripts.features.good_girl_of_babylon.combat')(Neverbirth, {
        World = dependencies.World, GoodGirlOfBabylonId = dependencies.GoodGirlOfBabylonId,
        VisualEffects = VisualEffects, State = State, Presentation = Presentation,
        Runtime = Runtime,
    })
    local Rewards = include('scripts.features.good_girl_of_babylon.rewards')(Neverbirth, {
        World = dependencies.World, GoodGirlOfBabylonId = dependencies.GoodGirlOfBabylonId,
        VisualEffects = VisualEffects, Cards = include('scripts.systems.card_rewards'),
    })
    local GetGoodGirlState = State.GetGoodGirlState
    local PlayerHasGoodGirl = State.PlayerHasGoodGirl
    local GoodGirlHasFullRedHearts = State.GoodGirlHasFullRedHearts
    local IsGoodGirlPresentable = State.IsGoodGirlPresentable
    local GetGoodGirlCostumeId = Presentation.GetGoodGirlCostumeId
    local RemoveGoodGirlCostume = Presentation.RemoveGoodGirlCostume
    local AddGoodGirlCostume = Presentation.AddGoodGirlCostume
    local ApplyGoodGirlCostume = Presentation.ApplyGoodGirlCostume
    local RefreshGoodGirlCache = Combat.RefreshGoodGirlCache
    local IsGoodGirlRedHeartDamage = Combat.IsGoodGirlRedHeartDamage
    local FearGoodGirlEnemies = Combat.FearGoodGirlEnemies
    local CharmGoodGirlRoomEnemies = Combat.CharmGoodGirlRoomEnemies
    local GetGoodGirlItemPool = Rewards.GetGoodGirlItemPool
    local GetGoodGirlItemConfig = Rewards.GetGoodGirlItemConfig
    local GetGoodGirlRewardSeed = Rewards.GetGoodGirlRewardSeed
    local IsGoodGirlKnownCardSubtype = Rewards.IsGoodGirlKnownCardSubtype
    local AddGoodGirlCardCandidate = Rewards.AddGoodGirlCardCandidate
    local CollectGoodGirlCardCandidates = Rewards.CollectGoodGirlCardCandidates
    local GetGoodGirlRewardCardSubtype = Rewards.GetGoodGirlRewardCardSubtype
    local SpawnGoodGirlReward = Rewards.SpawnGoodGirlReward

    Combat.InstallEvaluate()
    Combat.InstallDamage()

    function Neverbirth:RefreshGoodGirlOfBabylonRoom()
        if not Runtime.running or Runtime.disposed then return end
        for _, player in ipairs(GetPlayers()) do
            if PlayerHasGoodGirl(player) then
                local key = GetFolkPlayerKey(player)
                local previousState = Neverbirth.GoodGirl.states[key]
                Presentation.RemoveFollowEffect(previousState, "haloEffect")
                Presentation.RemoveFollowEffect(previousState, "echoEffect")
                State.ReplaceRoomState(key)
                ApplyGoodGirlCostume(player, IsGoodGirlPresentable(player, Neverbirth.GoodGirl.states[key]))
                CharmGoodGirlRoomEnemies(player)
                RefreshGoodGirlCache(player)
            end
        end
    end

    if ModCallbacks.MC_POST_NEW_ROOM then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.RefreshGoodGirlOfBabylonRoom)
    end

    function Neverbirth:UpdateGoodGirlOfBabylon()
        if not Runtime.running or Runtime.disposed then return end
        local room = GetFolkRoom()
        local isClear = room and room.IsClear and room:IsClear()

        for _, player in ipairs(GetPlayers()) do
            if PlayerHasGoodGirl(player) then
                local state = GetGoodGirlState(player)
                local presentable = IsGoodGirlPresentable(player, state)
                local refreshCache = State.ObservePresentable(state, presentable)
                local echoFrames = State.TickEcho(state)
                if echoFrames > 0 then
                    if state.echoFrames > 0 then
                        Neverbirth:EnsureGoodGirlFollowEffect(state, "echoEffect", "GoodGirlEcho", player)
                    else
                        Presentation.RemoveFollowEffect(state, "echoEffect")
                        refreshCache = true
                    end
                else
                    Presentation.RemoveFollowEffect(state, "echoEffect")
                end

                if presentable then
                    ApplyGoodGirlCostume(player, true)
                    Neverbirth:EnsureGoodGirlFollowEffect(state, "haloEffect", "GoodGirlHalo", player)
                else
                    ApplyGoodGirlCostume(player, false)
                    Presentation.RemoveFollowEffect(state, "haloEffect")
                end

                if refreshCache then RefreshGoodGirlCache(player) end

                if isClear and State.ClaimReward(state) then
                    if IsGoodGirlPresentable(player, state) and not state.redDamaged and GetFolkRandomInt(player, GoodGirlOfBabylonId, 100) < GOOD_GIRL_REWARD_CHANCE then
                        SpawnGoodGirlReward(player)
                    end
                end
            else
                ApplyGoodGirlCostume(player, false)
                local state = State.Find(player)
                if state then
                    local refreshCache = State.Release(state)
                    Presentation.RemoveFollowEffect(state, "haloEffect")
                    Presentation.RemoveFollowEffect(state, "echoEffect")
                    if refreshCache then RefreshGoodGirlCache(player) end
                end
            end
        end
    end

    Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateGoodGirlOfBabylon)

    local function ClearPlayerCostume(player)
        ApplyGoodGirlCostume(player, false)
    end

    local function ResetRuntime()
        local previous = Neverbirth.GoodGirl.states
        for _, state in pairs(Neverbirth.GoodGirl.states) do
            Presentation.RemoveFollowEffect(state, "haloEffect")
            Presentation.RemoveFollowEffect(state, "echoEffect")
        end
        State.ResetRuntime()
        Neverbirth.GoodGirl.costumeStates = {}
        for _, player in ipairs(GetPlayers()) do
            if previous[GetFolkPlayerKey(player)] then RefreshGoodGirlCache(player) end
        end
    end

    local function Pause()
        Runtime.running = false
        for _, state in pairs(Neverbirth.GoodGirl.states) do
            Presentation.RemoveFollowEffect(state, "haloEffect")
            Presentation.RemoveFollowEffect(state, "echoEffect")
        end
        Neverbirth.GoodGirl.costumeStates = {}
    end
    local function Resume(refresh)
        if Runtime.disposed then return end
        Runtime.running = true
        if refresh == false then return end
        for _, player in ipairs(GetPlayers()) do
            if State.Find(player) or PlayerHasGoodGirl(player) then RefreshGoodGirlCache(player) end
        end
    end
    local function Dispose()
        if Runtime.disposed then return end
        Pause()
        Runtime.disposed = true
        State.ResetRuntime()
    end

    -- Compatibility names formerly defined by main.lua.
    PublishGlobal("GetGoodGirlState", GetGoodGirlState)
    PublishGlobal("PlayerHasGoodGirl", PlayerHasGoodGirl)
    PublishGlobal("GoodGirlHasFullRedHearts", GoodGirlHasFullRedHearts)
    PublishGlobal("IsGoodGirlPresentable", IsGoodGirlPresentable)
    PublishGlobal("GetGoodGirlCostumeId", GetGoodGirlCostumeId)
    PublishGlobal("RemoveGoodGirlCostume", RemoveGoodGirlCostume)
    PublishGlobal("AddGoodGirlCostume", AddGoodGirlCostume)
    PublishGlobal("ApplyGoodGirlCostume", ApplyGoodGirlCostume)
    PublishGlobal("GetGoodGirlItemPool", GetGoodGirlItemPool)
    PublishGlobal("GetGoodGirlItemConfig", GetGoodGirlItemConfig)
    PublishGlobal("GetGoodGirlRewardSeed", GetGoodGirlRewardSeed)
    PublishGlobal("IsGoodGirlKnownCardSubtype", IsGoodGirlKnownCardSubtype)
    PublishGlobal("AddGoodGirlCardCandidate", AddGoodGirlCardCandidate)
    PublishGlobal("CollectGoodGirlCardCandidates", CollectGoodGirlCardCandidates)
    PublishGlobal("GetGoodGirlRewardCardSubtype", GetGoodGirlRewardCardSubtype)
    PublishGlobal("RefreshGoodGirlCache", RefreshGoodGirlCache)
    PublishGlobal("IsGoodGirlRedHeartDamage", IsGoodGirlRedHeartDamage)
    PublishGlobal("FearGoodGirlEnemies", FearGoodGirlEnemies)
    PublishGlobal("CharmGoodGirlRoomEnemies", CharmGoodGirlRoomEnemies)
    PublishGlobal("SpawnGoodGirlReward", SpawnGoodGirlReward)

    return { ClearPlayerCostume = ClearPlayerCostume, ResetRuntime = ResetRuntime,
        Pause = Pause, Resume = Resume, Dispose = Dispose }
end
