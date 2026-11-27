-- Private registry ownership for Everchanging.
return function(Neverbirth, deps)
    local DebugLog = deps.DebugLog

    local ALLOWED_SLOTS = {
        full = true,
        head = true,
        face = true,
        body = true,
        legs = true,
        accessory = true,
    }

    local STYLE_SPECS = {
        {
            id = "blue_banana_peel",
            slots = { "head" },
            resources = {
                head = { costume = "gfx/characters/costume_blue_banana_peel.anm2" },
            },
            full = false,
            metadata = { source = "existing_blue_banana_peel_costume" },
        },
        {
            id = "tokarev_cloak",
            slots = { "accessory", "face" },
            resources = {
                accessory = { costume = "gfx/characters/costume_tokarev_cloak.anm2" },
                face = { costume = "gfx/characters/costume_tokarev_face.anm2" },
            },
            full = false,
            metadata = { source = "tokarev_cloak_with_independent_head2_face" },
        },
        {
            id = "ringotsuga_apple_storyteller",
            slots = { "head" },
            resources = {
                head = { costume = "gfx/characters/costume_ringotsuga_headgear.anm2" },
            },
            full = false,
            metadata = { source = "ringotsuga_headgear_only" },
        },
        {
            id = "tantan_daodao_twins",
            eligibility = "normal_jacob_esau_pair",
            pairRoles = {
                jacob = {
                    slots = { "head" },
                    resources = {
                        head = { costume = "gfx/characters/costume_daodao_hair.anm2" },
                    },
                },
                esau = {
                    slots = { "head", "face" },
                    resources = {
                        head = { costume = "gfx/characters/costume_tantan_hair.anm2" },
                        face = { costume = "gfx/characters/costume_tantan_glasses.anm2" },
                    },
                },
            },
            full = false,
            metadata = { source = "tantan_daodao_normal_twins_accessories" },
        },
        {
            id = "yoontoons_storyteller",
            slots = { "head", "face" },
            resources = {
                head = { costume = "gfx/characters/costume_yoontoons_hair.anm2" },
                face = { costume = "gfx/characters/costume_yoontoons_glasses.anm2" },
            },
            full = false,
            metadata = { source = "yoontoons_hair_glasses_accessories" },
        },
    }

    local function LogInvalidStyle(index, reason)
        DebugLog("[neverbirth] Everchanging ignored style #" .. tostring(index) .. ": " .. tostring(reason))
    end

    local function NormalizeStyleResourceSet(slots, resources, allowFull)
        if type(slots) ~= "table" or #slots == 0 then return nil, "missing slots" end
        if type(resources) ~= "table" then return nil, "missing resources" end
        local normalized = { slots = {}, resources = {} }
        local seen = {}
        for _, rawSlot in ipairs(slots) do
            local slot = tostring(rawSlot or "")
            local resource = resources[slot]
            if not ALLOWED_SLOTS[slot] then return nil, "unsupported slot " .. slot end
            if seen[slot] then return nil, "duplicate slot " .. slot end
            if type(resource) ~= "table" then return nil, "missing resource for slot " .. slot end
            if slot == "full" then
                if not allowFull then return nil, "paired roles cannot use the full slot" end
                if type(resource.anm2) ~= "string" or resource.anm2 == "" then
                    return nil, "missing ANM2 resource for full slot"
                end
                normalized.resources[slot] = { anm2 = resource.anm2 }
            else
                if type(resource.costume) ~= "string" or resource.costume == "" then
                    return nil, "missing costume resource for slot " .. slot
                end
                normalized.resources[slot] = { costume = resource.costume }
            end
            seen[slot] = true
            normalized.slots[#normalized.slots + 1] = slot
        end
        normalized.hasFull = seen.full == true
        return normalized
    end

    local function BuildStyleRegistry(specs)
        local registry = { byId = {} }
        if type(specs) ~= "table" then return registry end

        for index, spec in ipairs(specs) do
            local valid = type(spec) == "table"
            local styleId = valid and tostring(spec.id or "") or ""
            local reason = nil
            local style = nil

            if not valid then
                reason = "entry is not a table"
            elseif styleId == "" then
                reason = "missing stable id"
            elseif registry.byId[styleId] then
                reason = "duplicate id " .. styleId
            elseif spec.pairRoles ~= nil then
                if type(spec.pairRoles) ~= "table" then
                    reason = "paired roles are not a table"
                else
                    local jacob, jacobReason = NormalizeStyleResourceSet(
                        spec.pairRoles.jacob and spec.pairRoles.jacob.slots,
                        spec.pairRoles.jacob and spec.pairRoles.jacob.resources,
                        false
                    )
                    local esau, esauReason = NormalizeStyleResourceSet(
                        spec.pairRoles.esau and spec.pairRoles.esau.slots,
                        spec.pairRoles.esau and spec.pairRoles.esau.resources,
                        false
                    )
                    if not jacob then
                        reason = "invalid Jacob role: " .. tostring(jacobReason)
                    elseif not esau then
                        reason = "invalid Esau role: " .. tostring(esauReason)
                    else
                        jacob.hasFull = nil
                        esau.hasFull = nil
                        style = {
                            id = styleId,
                            pairRoles = { jacob = jacob, esau = esau },
                            eligibility = spec.eligibility,
                            full = false,
                            metadata = spec.metadata,
                        }
                    end
                end
            else
                local normalized, normalizeReason = NormalizeStyleResourceSet(spec.slots, spec.resources, true)
                if not normalized then
                    reason = normalizeReason
                else
                    local isFull = spec.full == true
                    local hasFull = normalized.hasFull
                    normalized.hasFull = nil
                    if isFull or hasFull then
                        if not isFull or #normalized.slots ~= 1 or normalized.slots[1] ~= "full" then
                            reason = "full styles must declare only the full slot"
                        end
                    end
                    if not reason then
                        style = {
                            id = styleId,
                            slots = normalized.slots,
                            resources = normalized.resources,
                            full = isFull,
                            metadata = spec.metadata,
                        }
                    end
                end
            end

            if reason then
                LogInvalidStyle(index, reason)
            elseif style then
                registry[#registry + 1] = style
                registry.byId[styleId] = style
            end
        end
        return registry
    end

    local STYLE_REGISTRY = BuildStyleRegistry(STYLE_SPECS)

    return {
        LogInvalidStyle = LogInvalidStyle,
        NormalizeStyleResourceSet = NormalizeStyleResourceSet,
        BuildStyleRegistry = BuildStyleRegistry,
        StyleSpecs = STYLE_SPECS,
        StyleRegistry = STYLE_REGISTRY,
    }
end
