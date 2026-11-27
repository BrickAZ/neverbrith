-- Private audio responsibility for the Big Dog family.
return function(Neverbirth, deps)
    local soundIds = {}
    local soundManager = nil
    local Constants = deps.Constants
    local SOUND_NAMES = deps.SOUND_NAMES
    local runtime = deps.State.Runtime

    local function resolveSoundId(cue)
        if soundIds[cue] then
            return soundIds[cue]
        end
        local name = SOUND_NAMES[cue]
        if not name or not Isaac or type(Isaac.GetSoundIdByName) ~= "function" then
            return nil
        end
        local ok, soundId = pcall(Isaac.GetSoundIdByName, name)
        soundId = ok and tonumber(soundId) or nil
        if not soundId or soundId <= 0 then
            return nil
        end
        soundIds[cue] = soundId
        return soundId
    end

    local function playSoundCue(cue, pitch)
        local soundId = resolveSoundId(cue)
        if not soundId or type(SFXManager) ~= "function" then
            return false
        end
        if not soundManager then
            local ok, manager = pcall(SFXManager)
            if ok then
                soundManager = manager
            end
        end
        if not soundManager or type(soundManager.Play) ~= "function" then
            return false
        end
        local ok = pcall(soundManager.Play, soundManager, soundId, 1, 0, false, tonumber(pitch) or 1)
        return ok
    end

    local function chargeSoundIntervalFrames(pitch)
        local safePitch = math.max(0.01, tonumber(pitch) or Constants.CHARGE_SOUND_START_PITCH)
        local frames = Constants.CHARGE_SOUND_DURATION_SECONDS
            * Constants.CHARGE_SOUND_FRAMES_PER_SECOND / safePitch
        return math.max(1, math.floor(frames + 0.5))
    end

    local function clearChargeSoundSchedule(state)
        if type(state) ~= "table" then
            return
        end
        state.chargeSoundPitch = nil
        state.chargeSoundNextFrame = nil
    end

    local function scheduleChargeSound(state, pitch)
        if type(state) ~= "table" then
            return false
        end
        local resolvedPitch = math.max(0.01, tonumber(pitch) or Constants.CHARGE_SOUND_START_PITCH)
        state.chargeSoundPitch = resolvedPitch
        state.chargeSoundNextFrame = nil
        if not playSoundCue("Charge", resolvedPitch) then
            return false
        end
        state.chargeSoundNextFrame = runtime.frame + chargeSoundIntervalFrames(resolvedPitch)
        return true
    end

    local function beginChargeSoundSchedule(state)
        clearChargeSoundSchedule(state)
        return scheduleChargeSound(state, Constants.CHARGE_SOUND_START_PITCH)
    end

    local function updateChargeSoundSchedule(state)
        if type(state) ~= "table" or state.chargeSoundNextFrame == nil then
            return false
        end
        if runtime.frame < state.chargeSoundNextFrame then
            return false
        end
        local nextPitch = math.min(
            Constants.CHARGE_SOUND_MAX_PITCH,
            (tonumber(state.chargeSoundPitch) or Constants.CHARGE_SOUND_START_PITCH)
                + Constants.CHARGE_SOUND_PITCH_STEP
        )
        return scheduleChargeSound(state, nextPitch)
    end

    return {
        resolveSoundId = resolveSoundId,
        playSoundCue = playSoundCue,
        chargeSoundIntervalFrames = chargeSoundIntervalFrames,
        clearChargeSoundSchedule = clearChargeSoundSchedule,
        scheduleChargeSound = scheduleChargeSound,
        beginChargeSoundSchedule = beginChargeSoundSchedule,
        updateChargeSoundSchedule = updateChargeSoundSchedule,
    }
end
