-- Per-installation runtime references and the unchanged reviveMyLove save region.
return function(context, ITEM_ID, debugLog)
    local runtime = { sequencesByPlayer = {}, livingStateByPlayer = {} }
    local function currentRunSeed()
        return tostring(context.GetCurrentRunSeed and context.GetCurrentRunSeed() or "")
    end
    local function save()
        if context.Save then context.Save() end
    end
    local function getSaveRoot()
        return context.GetSaveRoot and context.GetSaveRoot() or nil
    end
    local function resetState(root)
        root.reviveMyLove = {runSeed = currentRunSeed(), triggeredByPlayer = {}}
        return root.reviveMyLove
    end
    local function getState()
        local root = getSaveRoot()
        if not root then return nil end
        local state = root.reviveMyLove
        if type(state) ~= "table" or tostring(state.runSeed or "") ~= currentRunSeed() then
            state = resetState(root)
        end
        if type(state.triggeredByPlayer) ~= "table" then state.triggeredByPlayer = {} end
        return state
    end
    local function playerKey(player)
        return tostring(player and player.InitSeed or "")
    end
    local function hasItem(player)
        return ITEM_ID > 0 and player and player:GetCollectibleNum(ITEM_ID, true) > 0
    end

    local function syncExtraLife(player)
        if not player then return end
        local state = getState()
        if not state then return end
        local key = playerKey(player)
        local wanted = hasItem(player) and not state.triggeredByPlayer[key]
            and not runtime.sequencesByPlayer[key] and 1 or 0
        if wanted == 1 and not player:IsDead() then
            runtime.livingStateByPlayer[key] = {
                controlsEnabled = player.ControlsEnabled, visible = player.Visible,
                collisionClass = player.EntityCollisionClass,
            }
        elseif wanted == 0 then
            runtime.livingStateByPlayer[key] = nil
        end
        local effects = player:GetEffects()
        local count = effects:GetCollectibleEffectNum(ITEM_ID)
        -- Own only this collectible's effect. One effect advertises x1 even
        -- with duplicate copies; it adds no costume or stats.
        if count < wanted then
            effects:AddCollectibleEffect(ITEM_ID, false, wanted - count)
        elseif count > wanted then
            effects:RemoveCollectibleEffect(ITEM_ID, count - wanted)
        end
        if count ~= wanted then
            debugLog("extra life entitlement for player " .. key .. ": " .. count .. " -> " .. wanted)
        end
    end

    return { runtime = runtime, save = save, getSaveRoot = getSaveRoot, resetState = resetState, getState = getState, playerKey = playerKey, hasItem = hasItem, syncExtraLife = syncExtraLife }
end
