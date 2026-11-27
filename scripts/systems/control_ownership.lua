-- Runtime CanShoot ownership only. No callbacks, saved keys or gameplay policy.
local Controls = {}

function Controls.Create(entityKey, exists)
    assert(type(entityKey) == 'function', 'control ownership requires a runtime entity key')
    assert(exists == nil or type(exists) == 'function', 'control validity query must be a function')
    local subjects, restoring, repairing, names = {}, {}, {}, {}
    local service = {}

    function service.Owner(name)
        assert(type(name) == 'string' and name ~= '' and not names[name], 'control owner must be unique')
        names[name] = true
        local claims = {}
        local issued = setmetatable({}, {__mode='k'})
        local owner = {}

        -- Capture before applying so the caller can retain the handle even when
        -- the engine setter fails. Repeated suppression reuses this same handle.
        function owner.Capture(player)
            local key, observed = entityKey(player), player:CanShoot()
            local subject = subjects[key]
            if subject and subject.player ~= player and exists and not exists(subject.player) then
                -- A recycled identity after removal is a new native body. Old
                -- handles remain releasable, but cannot own the new body.
                subjects[key], subject = nil, nil
            end
            if not subject then
                local pending = restoring[key]
                local original
                local generation
                if pending and (not exists or exists(pending.player)) then
                    original, generation = pending.original, pending.generation
                end
                if original == nil then original = observed end
                subject = {original=original, player=player, generation=generation or {}, handles={}}
                subjects[key] = subject
            end
            local handle = {}
            local claim = {key=key, player=player, subject=subject}
            claims[handle], issued[handle], subject.handles[handle] = claim, true, true
            return handle
        end

        function owner.Block(handle)
            local claim = assert(claims[handle], 'control handle is not active for this owner')
            claim.player:SetCanShoot(false)
        end

        function owner.Release(handle, exists)
            assert(issued[handle], 'control handle belongs to another owner')
            local claim = claims[handle]
            if not claim then return false end
            claims[handle], claim.subject.handles[handle] = nil, nil
            if not next(claim.subject.handles) and subjects[claim.key] == claim.subject then
                subjects[claim.key] = nil
            end
            -- Detach the claim before validity checks or setters can reenter.
            -- Retain the generation only during restoration, so a reentrant
            -- claimant does not mistake our not-yet-restored false for baseline.
            local previous = restoring[claim.key]
            restoring[claim.key] = {original=claim.subject.original, player=claim.player, generation=claim.subject.generation}
            local function desired()
                local remaining = subjects[claim.key]
                if remaining and remaining.generation ~= claim.subject.generation then return nil end
                local value = claim.subject.original
                local active = remaining and next(remaining.handles) ~= nil
                if active then value = false end
                return value, active
            end
            local function writeCurrent(repair)
                local previousValue
                for attempt = 1, 2 do
                    if not exists(claim.player) then return end
                    -- Both validity and setters can synchronously change owners.
                    local value, active = desired()
                    if value == nil or (repair and attempt == 1 and not active) then return end
                    if value == previousValue then return end
                    claim.player:SetCanShoot(value)
                    local after = desired()
                    if after == nil or after == value then return end
                    previousValue = value
                end
                -- Do not silently succeed or spin if a setter repeatedly flips
                -- ownership. Native failures retain the same bounded cleanup.
                error('control owners kept changing during restoration', 0)
            end
            local ok, err = pcall(writeCurrent, false)
            if not ok and not repairing[claim.key] then
                local remaining = subjects[claim.key]
                if remaining and remaining.generation == claim.subject.generation and next(remaining.handles) then
                    -- The setter may have applied true before throwing, after
                    -- a reentrant owner already blocked. Repair at most once;
                    -- a secondary native failure must not replace the first.
                    repairing[claim.key] = true
                    pcall(writeCurrent, true)
                    repairing[claim.key] = nil
                end
            end
            restoring[claim.key] = previous
            if not ok then error(err, 0) end
            return true
        end

        return owner
    end

    return service
end

return Controls
