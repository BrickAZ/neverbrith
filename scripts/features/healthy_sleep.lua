-- Repentance 1.7.9b / REPENTOGON 1.0.12a adapter. No custom bed or ANM2.
-- Native collision chooses bed.Target. Transfer only that bed's pending effect;
-- vanilla red full-heal bypasses AddHearts. See reports/healthy-sleep/2026-09-18-runtime-repair.md.
return function(mod, context)
    if not context.ItemId or context.ItemId <= 0 then return end
    local required = { 'MC_POST_PICKUP_COLLISION', 'MC_PRE_PLAYER_UPDATE',
        'MC_PRE_ITEM_OVERLAY_SHOW', 'MC_POST_ITEM_OVERLAY_SHOW', 'MC_POST_ITEM_OVERLAY_UPDATE' }
    for _, name in ipairs(required) do
        if not ModCallbacks[name] then
            if context.DebugLog then context.DebugLog('[健康睡眠] 缺少原版睡眠接入能力，已停止此道具初始化。') end
            return
        end
    end
    if not ItemOverlay or not ItemOverlay.GetSprite or not ItemOverlay.GetOverlayID then return end

    local TOTAL = 28800
    local State = include("scripts.features.healthy_sleep.state")(context)
    local Presentation = include("scripts.features.healthy_sleep.presentation")(mod, State)
    local Input = include("scripts.features.healthy_sleep.input")(mod, context, State)
    local Runtime = include("scripts.features.healthy_sleep.runtime")(mod, context, State, Presentation, Input, TOTAL)
    local Lifecycle = include("scripts.features.healthy_sleep.lifecycle")(mod, context, State, Runtime, TOTAL)

    Lifecycle.gameStarted()
    Lifecycle.newRoom()
    Lifecycle.newLevel()
    Runtime.Installers.update()
    Lifecycle.exitGame()
    Lifecycle.gameEnded()
    Lifecycle.unload()
    Runtime.Installers.beforeCollision()
    Runtime.Installers.afterCollision()
    Runtime.Installers.beforeOverlayShow()
    Runtime.Installers.afterOverlayShow()
    Runtime.Installers.update2()
    Input.Installers.beforePlayerUpdate()
    Input.Installers.inputAction()
    Presentation.Installers.render()
end
