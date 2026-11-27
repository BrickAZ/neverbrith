-- Private player_anm2 ownership for Everchanging.
return function(Neverbirth, deps)
    local DebugLog = deps.DebugLog
    local STYLE_REGISTRY = deps.Registry.StyleRegistry
    local strangerPlayerType = nil
    local strangerPlayerTypeResolved = false

    local function ResolveStrangerPlayerType()
        if strangerPlayerTypeResolved then
            return strangerPlayerType
        end
        strangerPlayerTypeResolved = true
        if Isaac and Isaac.GetPlayerTypeByName then
            local ok, resolved = pcall(function()
                return Isaac.GetPlayerTypeByName("Stranger", false)
            end)
            if ok and type(resolved) == "number" and resolved >= 0 then
                strangerPlayerType = resolved
            end
        end
        return strangerPlayerType
    end

    local function IsCompatiblePlayer(player, runtime)
        if not player then
            return false
        end
        local strangerType = ResolveStrangerPlayerType()
        if strangerType ~= nil and player.GetPlayerType then
            local ok, playerType = pcall(function()
                return player:GetPlayerType()
            end)
            if ok and playerType == strangerType then
                return false
            end
        end
        if not player.GetSprite then
            return false
        end
        local ok, sprite = pcall(function()
            return player:GetSprite()
        end)
        if not ok or not sprite or not sprite.GetFilename then
            return false
        end
        local filenameOk, filename = pcall(function()
            return sprite:GetFilename()
        end)
        if not filenameOk then
            return false
        end
        filename = tostring(filename or ""):gsub("\\", "/"):lower()
        local applied = runtime and tostring(runtime.appliedPlayerAnm2 or ""):gsub("\\", "/"):lower() or ""
        if applied ~= "" and filename == applied then
            filename = tostring(runtime.originalSpriteFilename or ""):gsub("\\", "/"):lower()
        end
        return filename:match("001%.000_player%.anm2$") ~= nil
    end

    local function NormalizeAssetPath(path)
        return tostring(path or ""):gsub("\\", "/"):lower()
    end

    local function GetPlayerSprite(player)
        if not player or not player.GetSprite then
            return nil
        end
        local ok, sprite = pcall(function()
            return player:GetSprite()
        end)
        return ok and sprite or nil
    end

    local function GetSpriteFilename(sprite)
        if not sprite or not sprite.GetFilename then
            return nil
        end
        local ok, filename = pcall(function()
            return sprite:GetFilename()
        end)
        return ok and tostring(filename or "") or nil
    end

    local function IsManagedPlayerAnm2(path)
        local normalized = NormalizeAssetPath(path)
        if normalized == "" then
            return false
        end
        for _, style in ipairs(STYLE_REGISTRY) do
            local full = style.resources and style.resources.full
            if full and NormalizeAssetPath(full.anm2) == normalized then
                return true
            end
        end
        return false
    end

    local function CaptureOriginalPlayerAnm2(runtime, sprite)
        if runtime.originalSpriteFilename and runtime.originalSpriteFilename ~= "" then
            return runtime.originalSpriteFilename
        end
        local currentPath = GetSpriteFilename(sprite)
        if currentPath and currentPath ~= "" and not IsManagedPlayerAnm2(currentPath) then
            runtime.originalSpriteFilename = currentPath
        end
        return runtime.originalSpriteFilename
    end

    local function CaptureSpritePlayback(sprite)
        local playback = { animation = nil, frame = 0, overlayAnimation = nil, overlayFrame = 0 }
        pcall(function()
            if sprite.GetAnimation then playback.animation = sprite:GetAnimation() end
            if sprite.GetFrame then playback.frame = sprite:GetFrame() end
            if sprite.GetOverlayAnimation then playback.overlayAnimation = sprite:GetOverlayAnimation() end
            if sprite.GetOverlayFrame then playback.overlayFrame = sprite:GetOverlayFrame() end
        end)
        return playback
    end

    local function RestoreSpritePlayback(sprite, playback)
        if playback.animation and playback.animation ~= "" and sprite.SetFrame then
            sprite:SetFrame(playback.animation, playback.frame or 0)
        end
        if playback.overlayAnimation and playback.overlayAnimation ~= "" and sprite.SetOverlayFrame then
            sprite:SetOverlayFrame(playback.overlayAnimation, playback.overlayFrame or 0)
        end
    end

    local function LoadPlayerAnm2(sprite, anm2Path)
        if not sprite or not sprite.Load or type(anm2Path) ~= "string" or anm2Path == "" then
            return false
        end
        local playback = CaptureSpritePlayback(sprite)
        local ok, err = pcall(function()
            sprite:Load(anm2Path, true)
            RestoreSpritePlayback(sprite, playback)
        end)
        if not ok then
            DebugLog("[neverbirth] Everchanging failed to load player ANM2 "
                .. tostring(anm2Path) .. ": " .. tostring(err))
        end
        return ok
    end

    local function ApplyPlayerAnm2(player, runtime, anm2Path)
        local sprite = GetPlayerSprite(player)
        if not sprite or not sprite.Load then
            return false
        end
        if NormalizeAssetPath(GetSpriteFilename(sprite)) == NormalizeAssetPath(anm2Path) then
            runtime.appliedPlayerAnm2 = anm2Path
            return true
        end
        if not CaptureOriginalPlayerAnm2(runtime, sprite) then
            DebugLog("[neverbirth] Everchanging could not resolve the original player ANM2")
            return false
        end
        if not LoadPlayerAnm2(sprite, anm2Path) then
            return false
        end
        runtime.appliedPlayerAnm2 = anm2Path
        return true
    end

    local function RestorePlayerAnm2(player, runtime)
        local appliedPath = runtime.appliedPlayerAnm2
        if not appliedPath then
            return false
        end
        local sprite = GetPlayerSprite(player)
        local originalPath = runtime.originalSpriteFilename
        local currentPath = GetSpriteFilename(sprite)
        runtime.appliedPlayerAnm2 = nil
        if not sprite or not originalPath then
            return false
        end
        if NormalizeAssetPath(currentPath) == NormalizeAssetPath(originalPath) then
            return true
        end
        if NormalizeAssetPath(currentPath) ~= NormalizeAssetPath(appliedPath)
            and not IsManagedPlayerAnm2(currentPath) then
            return false
        end
        local ok = LoadPlayerAnm2(sprite, originalPath)
        if not ok then
            DebugLog("[neverbirth] Everchanging failed to restore player ANM2 "
                .. tostring(originalPath))
        end
        return ok
    end

    local function PlayerAnm2Matches(player, expectedPath)
        if not expectedPath then
            return true
        end
        local currentPath = GetSpriteFilename(GetPlayerSprite(player))
        if not currentPath then
            return nil
        end
        return NormalizeAssetPath(currentPath) == NormalizeAssetPath(expectedPath)
    end

    return {
        ResolveStrangerPlayerType = ResolveStrangerPlayerType,
        IsCompatiblePlayer = IsCompatiblePlayer,
        NormalizeAssetPath = NormalizeAssetPath,
        GetPlayerSprite = GetPlayerSprite,
        GetSpriteFilename = GetSpriteFilename,
        IsManagedPlayerAnm2 = IsManagedPlayerAnm2,
        CaptureOriginalPlayerAnm2 = CaptureOriginalPlayerAnm2,
        CaptureSpritePlayback = CaptureSpritePlayback,
        RestoreSpritePlayback = RestoreSpritePlayback,
        LoadPlayerAnm2 = LoadPlayerAnm2,
        ApplyPlayerAnm2 = ApplyPlayerAnm2,
        RestorePlayerAnm2 = RestorePlayerAnm2,
        PlayerAnm2Matches = PlayerAnm2Matches,
    }
end
