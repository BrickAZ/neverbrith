-- Owns dental tear tagging, legal targets, knockback, cooldown and combat registration.
return function(dependencies)
local CombatSource = include("scripts.systems.combat_source")
local ItemId = dependencies.ItemId
local PLAYER_ENTITY = (EntityType and EntityType.ENTITY_PLAYER) or 1
return { key = "DentalChew", itemId = ItemId, cache = nil, CreateCombat = function(Neverbirth, context)
-- Keep native bindings beside handlers; invoke at their original installation phase.
local callbackInstallers = {}
local itemCount, playerKey, GetFrame = context.ItemCount, context.PlayerKey, context.GetFrame
    local DENTAL_PUSH_PER_COPY = 1.25
    local DENTAL_SPEED_CAP = 4.5
    local DENTAL_COOLDOWN_FRAMES = 8
    local DENTAL_TEAR_KEY = "NeverbirthDentalChewPlayerTear"
    local DENTAL_SOURCE_KEY = "NeverbirthDentalChewSourcePlayer"
    local DENTAL_COOLDOWN_KEY = "NeverbirthDentalChewLastPushByPlayer"

    local function directPlayerTearOwner(tear)
        return CombatSource.TryPlayer(tear and tear.SpawnerEntity)
    end

    local function markDentalTear(_, tear)
        local player = directPlayerTearOwner(tear)
        if not player or itemCount(player, ItemId) <= 0 or not tear.GetData then return nil end
        local data = tear:GetData()
        data[DENTAL_TEAR_KEY] = true
        data[DENTAL_SOURCE_KEY] = playerKey(player)
        return nil
    end
    function callbackInstallers.markDentalTear()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, markDentalTear)
    end

    local function hasFlag(entity, flag)
        if not entity or not flag or flag == 0 or not entity.HasEntityFlags then return false end
        local ok, result = pcall(function() return entity:HasEntityFlags(flag) end)
        return ok and result == true
    end

    local function eligibleDentalTarget(collider)
        if not collider or collider.Type == PLAYER_ENTITY or not collider.ToNPC then return nil end
        local ok, npc = pcall(function() return collider:ToNPC() end)
        if not ok or not npc then return nil end
        if npc.IsBoss then
            local bossOk, boss = pcall(function() return npc:IsBoss() end)
            if bossOk and boss then return nil end
        end
        if npc.IsVulnerableEnemy then
            local vulnerableOk, vulnerable = pcall(function() return npc:IsVulnerableEnemy() end)
            if vulnerableOk and vulnerable ~= true then return nil end
        end
        if npc.IsActiveEnemy then
            local activeOk, active = pcall(function() return npc:IsActiveEnemy(false) end)
            if activeOk and active ~= true then return nil end
        end
        if EntityFlag then
            if hasFlag(npc, EntityFlag.FLAG_BOSS)
                or hasFlag(npc, EntityFlag.FLAG_FRIENDLY)
                or hasFlag(npc, EntityFlag.FLAG_NO_KNOCKBACK)
                or hasFlag(npc, EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK) then
                return nil
            end
        end
        -- A segmented main body owns a child segment but has no parent segment.
        -- Reject only that body shape; ordinary summoned enemies remain eligible.
        if npc.ChildNPC and not npc.ParentNPC then return nil end
        return npc
    end

    local function vectorLength(vector)
        local x, y = vector and tonumber(vector.X) or 0, vector and tonumber(vector.Y) or 0
        return math.sqrt(x * x + y * y)
    end

    local function applyDentalPush(npc, direction, amount)
        local length = vectorLength(direction)
        if length <= 0 then return false end
        local velocity = npc.Velocity or Vector(0, 0)
        local x = (tonumber(velocity.X) or 0) + (tonumber(direction.X) or 0) / length * amount
        local y = (tonumber(velocity.Y) or 0) + (tonumber(direction.Y) or 0) / length * amount
        local resultLength = math.sqrt(x * x + y * y)
        if resultLength > DENTAL_SPEED_CAP then
            x = x / resultLength * DENTAL_SPEED_CAP
            y = y / resultLength * DENTAL_SPEED_CAP
        end
        npc.Velocity = Vector(x, y)
        return true
    end

    local function dentalCollision(_, tear, collider)
        if not tear or not tear.GetData then return nil end
        local tearData = tear:GetData()
        if not tearData or tearData[DENTAL_TEAR_KEY] ~= true then return nil end
        local player = directPlayerTearOwner(tear)
        local key = playerKey(player)
        if not player or key == "" or tearData[DENTAL_SOURCE_KEY] ~= key then return nil end
        local copies = itemCount(player, ItemId)
        if copies <= 0 then return nil end
        local npc = eligibleDentalTarget(collider)
        if not npc or not npc.GetData then return nil end
        local npcData = npc:GetData()
        if type(npcData[DENTAL_COOLDOWN_KEY]) ~= "table" then npcData[DENTAL_COOLDOWN_KEY] = {} end
        local lastFrame = tonumber(npcData[DENTAL_COOLDOWN_KEY][key])
        if lastFrame and GetFrame() - lastFrame < DENTAL_COOLDOWN_FRAMES then return nil end
        if applyDentalPush(npc, tear.Velocity, DENTAL_PUSH_PER_COPY * copies) then
            npcData[DENTAL_COOLDOWN_KEY][key] = GetFrame()
        end
        return nil
    end
    function callbackInstallers.dentalCollision()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, dentalCollision)
    end

return { MarkTear = markDentalTear, Collision = dentalCollision, EligibleTarget = eligibleDentalTarget, ApplyPush = applyDentalPush, InstallCallbacks = function()
if ModCallbacks.MC_POST_FIRE_TEAR then callbackInstallers.markDentalTear() end
if ModCallbacks.MC_PRE_TEAR_COLLISION then callbackInstallers.dentalCollision() end
end }
end }
end
