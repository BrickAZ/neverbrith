-- Owns music, sprites and countdown drawing. Never advances gameplay debt.
return function(Neverbirth, dependencies)
-- Native bindings are declared here; the entry chooses their installation phase.
local callbackInstallers = {}
local GetPlayers = assert(dependencies.GetPlayers)
local musicboxEffects = assert(dependencies.Effects)
local DebugLog = dependencies.Log
local Core = assert(dependencies.Core)
local IsEnabled = dependencies.IsEnabled or function() return true end
local MUSICBOX_THEME_NAME = "MusicboxTheme"
local MUSICBOX_COUNTDOWN_OFFSET = Vector(0, -45)
local Musicbox = {}
Musicbox.VisualOffset = Vector(0, 0)
Musicbox.FinalWindupFrames = 5 * 30
Musicbox.FinalBeatFrames = 2 * 30
Musicbox.VisualSpecs = {
    Contract = {
        path = "gfx/Effects/musicbox_active_contract.anm2",
        animation = "ContractIdle",
    },
    Windup = {
        path = "gfx/Effects/musicbox_warning_windup.anm2",
        animation = "FinalWindup",
    },
    Beat = {
        path = "gfx/Effects/musicbox_warning_beat.anm2",
        animation = "FinalBeat",
    },
    Panic = {
        path = "gfx/Effects/musicbox_activation_panic.anm2",
        animation = "PanicActivate",
    },
    ShadowGuardian = {
        path = "gfx/Effects/musicbox_shadow_guardian.anm2",
        animation = "Activate",
    },
}

Musicbox.Visuals = {}
Musicbox.PanicVisuals = {}
Musicbox.ShadowGuardianVisuals = {}
-- Existing lifecycle tests inspect these live maps; presentation helpers/config stay local.
Neverbirth.Musicbox = {
    Visuals = Musicbox.Visuals, PanicVisuals = Musicbox.PanicVisuals,
    ShadowGuardianVisuals = Musicbox.ShadowGuardianVisuals,
}
local musicboxThemeId = nil
local musicboxPreviousMusicId = nil
local musicboxMusicStarted = false
local musicboxMissingThemeLogged = false

local function IsValidMusicId(musicId)
    return type(musicId) == "number" and musicId > 0
end

local function GetMusicboxThemeId()
    if musicboxThemeId == nil then
        musicboxThemeId = Isaac.GetMusicIdByName(MUSICBOX_THEME_NAME)
    end

    if IsValidMusicId(musicboxThemeId) then
        return musicboxThemeId
    end

    if not musicboxMissingThemeLogged then
        DebugLog("[neverbirth] MusicboxTheme music id not found")
        musicboxMissingThemeLogged = true
    end

    return nil
end

local function StartMusicboxMusic()
    local themeId = GetMusicboxThemeId()
    if not themeId then
        return
    end

    local music = MusicManager()
    if musicboxPreviousMusicId == nil and music.GetCurrentMusicID then
        local currentMusicId = music:GetCurrentMusicID()
        if currentMusicId ~= themeId then
            musicboxPreviousMusicId = currentMusicId
        end
    end

    music:Play(themeId, 1)
    musicboxMusicStarted = true
end

local function KeepMusicboxMusic()
    local themeId = GetMusicboxThemeId()
    if not themeId then
        return
    end

    local music = MusicManager()
    if not music.GetCurrentMusicID or music:GetCurrentMusicID() ~= themeId then
        music:Play(themeId, 1)
        musicboxMusicStarted = true
    end
end

local function StopMusicboxMusic(onlyIfOwned)
    if not musicboxMusicStarted then
        return
    end

    local music = MusicManager()
    local themeId = GetMusicboxThemeId()

    if onlyIfOwned and music.GetCurrentMusicID and music:GetCurrentMusicID() ~= themeId then
        -- The menu/new room already selected its music; release our bookkeeping only.
    elseif IsValidMusicId(musicboxPreviousMusicId) and musicboxPreviousMusicId ~= themeId then
        music:Play(musicboxPreviousMusicId, 1)
    elseif music.Fadeout then
        music:Fadeout(0.08)
    end

    musicboxPreviousMusicId = nil
    musicboxMusicStarted = false
end

function Musicbox.GetVisualKind(timer)
    return Core.GetVisualKind(timer, Musicbox.FinalWindupFrames, Musicbox.FinalBeatFrames)
end

function Musicbox.CreateSprite(kind)
    local spec = Musicbox.VisualSpecs[kind]
    if not spec or not Sprite then
        return nil
    end

    local ok, sprite = pcall(function()
        return Sprite()
    end)
    if not ok or not sprite then
        return nil
    end

    if sprite.Load then
        pcall(function()
            sprite:Load(spec.path, true)
        end)
    end
    if sprite.Play then
        pcall(function()
            sprite:Play(spec.animation, true)
        end)
    end
    return sprite
end

function Musicbox.GetVisualPosition(player)
    local position = (player and player.Position) or Vector(320, 280)
    if player and player.PositionOffset then
        position = position + player.PositionOffset
    end
    if player and player.GetFlyingOffset then
        local ok, flyingOffset = pcall(function()
            return player:GetFlyingOffset()
        end)
        if ok and flyingOffset then
            position = position + flyingOffset
        end
    end
    return position + Musicbox.VisualOffset
end

function Musicbox.ClearVisuals(playerSeed)
    Musicbox.Visuals[playerSeed] = nil
    Musicbox.PanicVisuals[playerSeed] = nil
    Musicbox.ShadowGuardianVisuals[playerSeed] = nil
end

function Musicbox.EnsureVisual(player, timer)
    if not player then
        return
    end

    local seed = player.InitSeed
    local kind = Musicbox.GetVisualKind(timer)
    local visual = Musicbox.Visuals[seed]
    if visual and visual.kind == kind then
        visual.player = player
        return
    end

    local sprite = Musicbox.CreateSprite(kind)
    if not sprite then
        return
    end

    Musicbox.Visuals[seed] = {
        kind = kind,
        player = player,
        sprite = sprite,
    }
end

function Musicbox.SpawnPanicVisual(player)
    if not player then
        return
    end

    local sprite = Musicbox.CreateSprite("Panic")
    if not sprite then
        return
    end

    Musicbox.PanicVisuals[player.InitSeed] = {
        player = player,
        sprite = sprite,
        timer = 6,
    }
end

function Musicbox.SpawnShadowGuardianVisual(player)
    if not player then
        return
    end

    local sprite = Musicbox.CreateSprite("ShadowGuardian")
    if not sprite then
        return
    end

    Musicbox.ShadowGuardianVisuals[player.InitSeed] = {
        player = player,
        sprite = sprite,
        timer = 6,
    }
end
function Musicbox.UpdateVisuals()
    local activeSeeds = {}
    for _, player in ipairs(GetPlayers()) do
        local effect = player and musicboxEffects[player.InitSeed]
        if effect and (tonumber(effect.timer) or 0) > 0 then
            activeSeeds[player.InitSeed] = true
            Musicbox.EnsureVisual(player, effect.timer)
        end
    end

    for seed in pairs(Musicbox.Visuals) do
        if not activeSeeds[seed] then
            Musicbox.Visuals[seed] = nil
        end
    end

    for _, visual in pairs(Musicbox.Visuals) do
        if visual.sprite and visual.sprite.Update then
            pcall(function()
                visual.sprite:Update()
            end)
        end
    end

    for seed, visual in pairs(Musicbox.PanicVisuals) do
        if visual.sprite and visual.sprite.Update then
            pcall(function()
                visual.sprite:Update()
            end)
        end
        visual.timer = (tonumber(visual.timer) or 0) - 1
        if visual.timer <= 0 then
            Musicbox.PanicVisuals[seed] = nil
        end
    end
    for seed, visual in pairs(Musicbox.ShadowGuardianVisuals) do
        if visual.sprite and visual.sprite.Update then
            pcall(function()
                visual.sprite:Update()
            end)
        end
        visual.timer = (tonumber(visual.timer) or 0) - 1
        if visual.timer <= 0 then
            Musicbox.ShadowGuardianVisuals[seed] = nil
        end
    end
end

function Musicbox.RenderVisual(visual)
    if not visual or not visual.player or not visual.sprite or not visual.sprite.Render then
        return
    end

    local position = Musicbox.GetVisualPosition(visual.player)
    if Isaac.WorldToScreen then
        local ok, screenPosition = pcall(function()
            return Isaac.WorldToScreen(position)
        end)
        if ok and screenPosition then
            position = screenPosition
        end
    end
    pcall(function()
        visual.sprite:Render(position)
    end)
end

function Musicbox.RenderVisuals()
    for _, visual in pairs(Musicbox.Visuals) do
        Musicbox.RenderVisual(visual)
    end
    for _, visual in pairs(Musicbox.PanicVisuals) do
        Musicbox.RenderVisual(visual)
    end
    for _, visual in pairs(Musicbox.ShadowGuardianVisuals) do
        Musicbox.RenderVisual(visual)
    end
end

function Neverbirth:RenderMusicboxCountdown()
    if not IsEnabled() then return end
    Musicbox.RenderVisuals()
    for _, player in ipairs(GetPlayers()) do
        local effect = musicboxEffects[player.InitSeed]
        if effect and effect.timer > 0 then
            local secondsLeft = math.ceil(effect.timer / 30)
            local screenPosition = Isaac.WorldToScreen(player.Position + MUSICBOX_COUNTDOWN_OFFSET)
            Isaac.RenderText(tostring(secondsLeft), screenPosition.X - 4, screenPosition.Y, 1, 0.1, 0.1, 1)
        end
    end
end
function callbackInstallers.InstallRender()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_RENDER, Neverbirth.RenderMusicboxCountdown)
end


local function Reset()
    for _, visuals in ipairs({ Musicbox.Visuals, Musicbox.PanicVisuals,
        Musicbox.ShadowGuardianVisuals }) do
        for key in pairs(visuals) do visuals[key] = nil end
    end
    StopMusicboxMusic(true)
end

return { StartMusic = StartMusicboxMusic, KeepMusic = KeepMusicboxMusic,
    StopMusic = StopMusicboxMusic, RenderCountdown = Neverbirth.RenderMusicboxCountdown, Reset = Reset,
    InstallRender = callbackInstallers.InstallRender,
    ClearVisuals = Musicbox.ClearVisuals, EnsureVisual = Musicbox.EnsureVisual,
    SpawnShadowGuardianVisual = Musicbox.SpawnShadowGuardianVisual,
    SpawnPanicVisual = Musicbox.SpawnPanicVisual, UpdateVisuals = Musicbox.UpdateVisuals,
}
end
