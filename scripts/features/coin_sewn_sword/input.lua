-- Owns holding and the one-update release input lock.
return function(Neverbirth, dependencies)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local CoinSewnSwordId = dependencies.CoinSewnSwordId
    local FireCoinSewnSword = dependencies.Fire
    local VectorFromInput = dependencies.VectorFromInput
    local coinSwordHoldStates = {}
    local coinSwordInputBlocks = {}
    local Runtime = dependencies.Runtime or { running = true, disposed = false }
    Neverbirth.__coinSwordReadingInput = false
    local COIN_SWORD_NO_DISCHARGE_RESULT = dependencies.Rules.COIN_SWORD_NO_DISCHARGE_RESULT
    local function GetCoinSwordReleaseDirection(player)
        if not player or not Input or not Input.GetActionValue or not ButtonAction then return nil end
        Neverbirth.__coinSwordReadingInput = true
        local ok, x, y = pcall(function()
            local controller = player.ControllerIndex
            return Input.GetActionValue(ButtonAction.ACTION_SHOOTRIGHT, controller)
                    - Input.GetActionValue(ButtonAction.ACTION_SHOOTLEFT, controller),
                Input.GetActionValue(ButtonAction.ACTION_SHOOTDOWN, controller)
                    - Input.GetActionValue(ButtonAction.ACTION_SHOOTUP, controller)
        end)
        Neverbirth.__coinSwordReadingInput = false
        if not ok then return nil end
        return VectorFromInput(Vector(x, y))
    end

    local function GetCoinSwordActiveItem(player, slot)
        if not player or not player.GetActiveItem then
            return CoinSewnSwordId
        end

        local ok, itemId = pcall(function()
            return player:GetActiveItem(slot or (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0)
        end)
        if ok then
            return itemId
        end

        return CoinSewnSwordId
    end

    local function GetCoinSwordHoldKey(player)
        return tostring((player and player.InitSeed) or "")
    end

    local function CoinSwordYieldsAttack(player)
        return Neverbirth.AvadaKedavra and Neverbirth.AvadaKedavra.OwnsAttack(player)
    end

    local function CoinSwordPlayerAvailable(player, slot)
        return player and (not player.Exists or player:Exists())
            and (not player.IsDead or not player:IsDead())
            and player.ControlsEnabled ~= false and not CoinSwordYieldsAttack(player)
            and GetCoinSwordActiveItem(player, slot) == CoinSewnSwordId
    end

    function Neverbirth:CoinSwordInputAction(entity, hook, action)
        if not Runtime.running or Runtime.disposed or Neverbirth.__coinSwordReadingInput or not entity or not entity.ToPlayer or not ButtonAction then return nil end
        if action ~= ButtonAction.ACTION_SHOOTLEFT and action ~= ButtonAction.ACTION_SHOOTRIGHT
            and action ~= ButtonAction.ACTION_SHOOTUP and action ~= ButtonAction.ACTION_SHOOTDOWN then return nil end
        local player = entity:ToPlayer()
        if not player then return nil end
        local key = GetCoinSwordHoldKey(player)
        local state = coinSwordHoldStates[key] or coinSwordInputBlocks[key]
        if not state or not CoinSwordPlayerAvailable(player, state.slot) then return nil end
        if hook == InputHook.GET_ACTION_VALUE then return 0 end
        if hook == InputHook.IS_ACTION_PRESSED or hook == InputHook.IS_ACTION_TRIGGERED then return false end
    end
    function callbackInstallers.Neverbirth_CoinSwordInputAction()
        return Neverbirth:AddCallback(ModCallbacks.MC_INPUT_ACTION, Neverbirth.CoinSwordInputAction)
    end

    local function StartCoinSewnSwordHold(player, slot)
        coinSwordHoldStates[GetCoinSwordHoldKey(player)] = {
            slot = slot or (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0,
        }
    end

    function Neverbirth:UseCoinSewnSword(_, _, player, _, activeSlot)
        if not Runtime.running or Runtime.disposed or not player or CoinSwordYieldsAttack(player) then
            return false
        end

        local key = GetCoinSwordHoldKey(player)
        if coinSwordHoldStates[key] then
            local direction = GetCoinSwordReleaseDirection(player)
            if direction then
                local state = coinSwordHoldStates[key]
                coinSwordHoldStates[key] = nil
                coinSwordInputBlocks[key] = state
                FireCoinSewnSword(player, direction, state.slot or activeSlot)
            else
                coinSwordHoldStates[key] = nil
                coinSwordInputBlocks[key] = nil
            end
            return COIN_SWORD_NO_DISCHARGE_RESULT
        end

        StartCoinSewnSwordHold(player, activeSlot)
        return COIN_SWORD_NO_DISCHARGE_RESULT
    end
    function callbackInstallers.Neverbirth_UseCoinSewnSword()
        return Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseCoinSewnSword, CoinSewnSwordId)
    end

    function Neverbirth:UpdateCoinSewnSwordHold(player)
        if not Runtime.running or Runtime.disposed then return end
        local key = GetCoinSwordHoldKey(player)
        -- Keep the release input blocked throughout the complete native weapon pass.
        -- Release this one-update lease only when the owner's next update starts.
        coinSwordInputBlocks[key] = nil
        local state = coinSwordHoldStates[key]
        if not state then return end
        if not CoinSwordPlayerAvailable(player, state.slot) then
            coinSwordHoldStates[key] = nil
            return
        end
        local direction = GetCoinSwordReleaseDirection(player)
        if direction then
            coinSwordHoldStates[key] = nil
            coinSwordInputBlocks[key] = state
            FireCoinSewnSword(player, direction, state.slot)
        end
    end
    function callbackInstallers.Neverbirth_UpdateCoinSewnSwordHold()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE, Neverbirth.UpdateCoinSewnSwordHold)
    end

    function Neverbirth:CancelCoinSewnSwordHolds()
        coinSwordHoldStates = {}
        coinSwordInputBlocks = {}
        Neverbirth.__coinSwordReadingInput = false
    end
    function callbackInstallers.Neverbirth_CancelCoinSewnSwordHolds(callbackId)
        return Neverbirth:AddCallback(callbackId, Neverbirth.CancelCoinSewnSwordHolds)
    end

    function Neverbirth:UnloadCoinSewnSword(unloaded)
        if unloaded ~= Neverbirth or Runtime.disposed then return end
        Runtime.running, Runtime.disposed = false, true
        Neverbirth:CancelCoinSewnSwordHolds()
        if dependencies.ReleaseEffects then dependencies.ReleaseEffects() end
    end
    function callbackInstallers.InstallUnload()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, Neverbirth.UnloadCoinSewnSword)
    end

    function Neverbirth:ExitCoinSewnSword()
        Runtime.running = false
        Neverbirth:CancelCoinSewnSwordHolds()
        if dependencies.ReleaseEffects then dependencies.ReleaseEffects() end
    end
    function callbackInstallers.InstallExit()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, Neverbirth.ExitCoinSewnSword)
    end

    function Neverbirth:ResumeCoinSewnSword()
        if Runtime.disposed then return end
        if dependencies.ReleaseEffects then dependencies.ReleaseEffects() end
        Runtime.running = true
    end
    function callbackInstallers.InstallResume()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResumeCoinSewnSword)
    end

    local function InstallHoldCallbacks()
        callbackInstallers.Neverbirth_UseCoinSewnSword()

        if ModCallbacks.MC_PRE_PLAYER_UPDATE then
            callbackInstallers.Neverbirth_UpdateCoinSewnSwordHold()
        end
        if ModCallbacks.MC_INPUT_ACTION then
            callbackInstallers.Neverbirth_CoinSwordInputAction()
        end

        for _, callbackId in ipairs({
            ModCallbacks.MC_POST_NEW_ROOM, ModCallbacks.MC_POST_NEW_LEVEL,
            ModCallbacks.MC_POST_GAME_STARTED, ModCallbacks.MC_PRE_GAME_EXIT,
        }) do
            callbackInstallers.Neverbirth_CancelCoinSewnSwordHolds(callbackId)
        end
        if ModCallbacks.MC_POST_ENTITY_REMOVE then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, function(_, entity)
                local key = GetCoinSwordHoldKey(entity)
                coinSwordHoldStates[key], coinSwordInputBlocks[key] = nil, nil
            end, EntityType.ENTITY_PLAYER)
        end
        if ModCallbacks.MC_PRE_MOD_UNLOAD then callbackInstallers.InstallUnload() end
        if ModCallbacks.MC_PRE_GAME_EXIT then callbackInstallers.InstallExit() end
        if ModCallbacks.MC_POST_GAME_STARTED then callbackInstallers.InstallResume() end
    end

    return { InstallHoldCallbacks = InstallHoldCallbacks }
end
