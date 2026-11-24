-- Bomb Suit / 炸弹套装. Runtime-only owner state and a normal bomb carrier.
-- FireBomb creates a fetus (35 damage), not an ordinary placed bomb (100).
return function(mod, context)
    local ID = context.ItemId
    if not ID or ID <= 0 then return end
    local required = {"MC_PRE_PLAYER_TAKE_DMG", "MC_POST_ENTITY_TAKE_DMG",
        "MC_PRE_PLAYER_UPDATE", "MC_POST_PLAYER_UPDATE", "MC_PRE_TRIGGER_PLAYER_DEATH",
        "MC_POST_TRIGGER_COLLECTIBLE_REMOVED", "MC_PRE_BOMB_UPDATE",
        "MC_POST_BOMB_UPDATE", "MC_PRE_ENTITY_SPAWN"}
    for _, name in ipairs(required) do
        if not ModCallbacks[name] then
            if context.DebugLog then context.DebugLog("[Bomb Suit] Missing callback: " .. name) end
            return
        end
    end
    local DURATION, BONUS = 90, 0.5
    -- Native entities2.xml: 6.2 is the blood donation machine; 6.5 is the devil beggar.
    -- IV Bag has its dedicated damage flag. Do not classify Razor, Blood Rights,
    -- Sharp Plug, sacrifice spikes or all NO_PENALTIES hits as blood payment.
    local BLOOD_SLOT, DEVIL_BEGGAR = 2, 5
    local active, before, shootScopes = {}, {}, {}
    local bombScopes, pendingScatter, scopeFrame = {}, {}, -1
    local ready = false
    local OWNER_MARKER = "NeverbirthBombSuitOwner"
    local beepAt = {[0]=true,[30]=true,[50]=true,[65]=true,[75]=true,[81]=true,[86]=true,[89]=true}

    local function key(entity)
        if not entity then return nil end
        if GetPtrHash then return tostring(GetPtrHash(entity)) end
        return tostring(entity.InitSeed)
    end
    local function exists(entity) return entity and (not entity.Exists or entity:Exists()) end
    local function alive(player)
        return exists(player) and not player:IsDead() and not player:HasMortalDamage()
    end
    local function held(player) return alive(player) and player:HasCollectible(ID) end
    local function refresh(player)
        if exists(player) then player:AddCacheFlags(CacheFlag.CACHE_SPEED); player:EvaluateItems() end
    end
    local function restoreShoot(k)
        local scope = shootScopes[k]; shootScopes[k] = nil
        if scope and exists(scope.player) then scope.player:SetCanShoot(scope.value) end
    end
    local function stop(k)
        local state = active[k]; active[k], before[k] = nil, nil
        restoreShoot(k)
        if state then refresh(state.player) end
    end
    local function clear()
        local keys = {}; for k in pairs(active) do keys[#keys+1] = k end
        for _, k in ipairs(keys) do stop(k) end
        for k in pairs(shootScopes) do restoreShoot(k) end
        before = {}
        bombScopes, pendingScatter, scopeFrame = {}, {}, -1
    end
    local function stateFor(player)
        local k = key(player); local state = k and active[k]
        if state and not held(player) then stop(k); return nil end
        return ready and state or nil
    end
    local function isBloodPayment(flags, source)
        if (flags & DamageFlag.DAMAGE_IV_BAG) ~= 0 then return true end
        local entity = source and source.Entity
        local kind = entity and entity.Type or (source and source.Type)
        local variant = entity and entity.Variant or (source and source.Variant)
        return kind == EntityType.ENTITY_SLOT and (variant == BLOOD_SLOT or variant == DEVIL_BEGGAR)
    end
    local function health(player)
        return {player:GetHearts(), player:GetSoulHearts(), player:GetBoneHearts()}
    end
    local function lostHealth(player, old)
        if not old then return false end
        local current = health(player)
        -- A shield's loss is not heart loss. Bone-container loss is real damage
        -- even when the red-heart counter remains unchanged.
        for i = 1, 3 do if current[i] < old[i] then return true end end
        return false
    end
    local function sourceKey(source)
        local entity = source and source.Entity
        if entity then return "entity:" .. key(entity) end
        return "ref:" .. tostring(source and source.Type or 0) .. ":" .. tostring(source and source.Variant or 0)
    end
    local function sourceOwner(entity, seen, depth)
        if not entity or (depth or 0) > 8 then return nil end
        seen = seen or {}; local k = key(entity)
        if seen[k] then return nil end; seen[k] = true
        local data = entity.GetData and entity:GetData()
        if data and data[OWNER_MARKER] then return data[OWNER_MARKER] end
        return sourceOwner(entity.Parent, seen, (depth or 0)+1)
            or sourceOwner(entity.SpawnerEntity, seen, (depth or 0)+1)
    end
    local function initOwned(_, entity)
        local owner = sourceOwner(entity)
        if owner and entity.GetData then entity:GetData()[OWNER_MARKER] = owner end
    end
    local function sweepBombScopes()
        local frame = Game():GetFrameCount()
        if scopeFrame ~= frame then
            -- A cancelled/removed bomb may not have a matching POST update.
            -- Never carry an open native-AI scope into another frame.
            bombScopes, scopeFrame = {}, frame
            for seed, candidate in pairs(pendingScatter) do
                if frame > candidate.frame + 2 then pendingScatter[seed] = nil end
            end
        end
    end
    local function preBomb(_, bomb)
        if not ready then return end
        sweepBombScopes()
        local candidate = pendingScatter[bomb.InitSeed]
        if candidate then
            pendingScatter[bomb.InitSeed] = nil
            -- Native Scatter children deliberately have no Parent and point
            -- straight to the player. Spawn identity alone is insufficient:
            -- confirm the native mini-bomb size and half-parent damage before
            -- adopting it. Hot Bombs flags are retained; Mega children do 92.5.
            if bomb.FrameCount <= 1 and bomb.Variant == BombVariant.BOMB_NORMAL
                and bomb.SubType == 0 and not bomb.IsFetus and bomb:GetScale() == 0.5
                and math.abs(bomb.ExplosionDamage - candidate.damage) < 0.001
                and key(bomb.SpawnerEntity) == candidate.owner
                and not bomb:HasTearFlags(TearFlags.TEAR_SCATTER_BOMB) then
                bomb:GetData()[OWNER_MARKER] = candidate.owner
            end
        end
        local owner = sourceOwner(bomb)
        -- Every bomb contributes a stack entry: unrelated nested Bomb:Update()
        -- calls are barriers and cannot borrow the enclosing owned root.
        bombScopes[#bombScopes+1] = {bomb=bomb, key=key(bomb),
            owner=owner and bomb:HasTearFlags(TearFlags.TEAR_SCATTER_BOMB) and owner or nil,
            damage=bomb.ExplosionDamage}
    end
    local function postBomb(_, bomb)
        for i=#bombScopes,1,-1 do
            if bombScopes[i].key == key(bomb) then
                for j=#bombScopes,i,-1 do bombScopes[j] = nil end
                return
            end
        end
    end
    local function preSpawn(_, kind, variant, subtype, position, velocity, spawner, seed)
        if not ready or kind ~= EntityType.ENTITY_BOMBDROP then return end
        sweepBombScopes()
        local scope = bombScopes[#bombScopes]
        if scope and scope.owner and scope.bomb:GetExplosionCountdown() <= 0
            and variant == BombVariant.BOMB_NORMAL and subtype == 0
            and key(spawner) == scope.owner then
            pendingScatter[seed] = {owner=scope.owner, damage=scope.damage/2, frame=scopeFrame}
        end
    end
    local function beep(state)
        if SoundEffect and SoundEffect.SOUND_BEEP and SFXManager then
            SFXManager():Play(SoundEffect.SOUND_BEEP, 0.55, 0, false, 0.9 + state.age / DURATION * 0.65)
        end
    end
    local function preDamage(_, player, amount, flags, source, countdown, extraSource)
        if not ready then return end
        flags = flags or 0
        local k = key(player)
        local state = stateFor(player)
        local payment = isBloodPayment(flags, source)
        -- nil preserves the original native hit. false cancels before native
        -- shields/health; do not spend a mantle merely to ignore an armed hit.
        if state and not payment then return false end
        local owner = sourceOwner(source and source.Entity) or sourceOwner(extraSource and extraSource.Entity)
        if owner == k and not payment then return false end
        if not state and held(player) and amount > 0 and (flags & DamageFlag.DAMAGE_FAKE) == 0 then
            local frame = Game():GetFrameCount()
            local receipts = before[k]
            if not receipts or receipts.frame ~= frame then receipts={frame=frame}; before[k]=receipts end
            -- Cancellation has no POST callback. Bound candidates to one frame
            -- and match by source; do not let fake/payment nested hits erase a
            -- real outer candidate or assume every PRE has a paired POST.
            receipts[#receipts+1] = {health=health(player),source=sourceKey(source),payment=payment}
            if #receipts > 16 then table.remove(receipts,1) end
        end
    end
    local function postDamage(_, entity, amount, flags, source)
        if not ready then return end
        local player = entity:ToPlayer(); if not player then return end
        local k = key(player)
        if stateFor(player) or not held(player) or amount <= 0 or (flags & DamageFlag.DAMAGE_FAKE) ~= 0 then return end
        local receipts = before[k]
        if not receipts or receipts.frame ~= Game():GetFrameCount() then return end
        local receipt
        local payment = isBloodPayment(flags, source)
        for i=#receipts,1,-1 do
            local candidate = receipts[i]
            if candidate.source==sourceKey(source) and candidate.payment==payment
                and (payment or lostHealth(player,candidate.health)) then
                receipt=table.remove(receipts,i)
                if payment then
                    -- Only older snapshots precede this payment. Newer nested
                    -- candidates already contain its loss and must not be adjusted.
                    local current=health(player)
                    for j=1,i-1 do for h=1,3 do
                        receipts[j].health[h]=receipts[j].health[h]-math.max(0,receipt.health[h]-current[h])
                    end end
                end
                break
            end
        end
        if payment or not receipt then return end
        before[k]=nil
        active[k] = {player=player, age=0, lastFrame=Game():GetFrameCount()}
        refresh(player); beep(active[k])
        if Sprite then
            local ok, sprite = pcall(function()
                local s = Sprite(); s:Load("gfx/Effects/BombSuit/fuse.anm2", true); s:Play("Fuse", true); return s
            end)
            if ok then active[k].fuse = sprite end
        end
    end
    local function evaluate(_, player, flag)
        if flag == CacheFlag.CACHE_SPEED and ready and active[key(player)] and held(player) then
            player.MoveSpeed = player.MoveSpeed + BONUS
        end
    end
    local function prePlayer(_, player)
        if not stateFor(player) then return end
        local k = key(player)
        if not shootScopes[k] then shootScopes[k] = {player=player, value=player:CanShoot()} end
        player:SetCanShoot(false)
    end
    local function postPlayer(_, player) restoreShoot(key(player)) end
    local function input(_, entity, hook, action)
        local player = entity and entity:ToPlayer()
        if not player or not stateFor(player) then return end
        if action == ButtonAction.ACTION_SHOOTLEFT or action == ButtonAction.ACTION_SHOOTRIGHT
            or action == ButtonAction.ACTION_SHOOTUP or action == ButtonAction.ACTION_SHOOTDOWN then
            if hook == InputHook.GET_ACTION_VALUE then return 0 end
            return false
        end
    end
    local function detonate(k, state)
        -- Keep the armed damage guard until native Update returns. Descendants
        -- get narrow ownership marks, so late cluster/tear/effect damage remains
        -- self-safe without adding general invulnerability after the three seconds.
        local ok, err = pcall(function()
            local player = state.player
            local entity = Isaac.Spawn(EntityType.ENTITY_BOMBDROP, BombVariant.BOMB_NORMAL,
                0, player.Position, Vector(0, 0), player)
            local bomb = entity and entity:ToBomb()
            if not bomb then error("normal bomb spawn returned no bomb") end
            bomb:GetData()[OWNER_MARKER] = k
            -- GetBombFlags(false) supplies guaranteed ordinary bomb upgrades,
            -- rather than the random fetus subset. Do not convert BitSet128
            -- to a Lua integer. The engine executes the bomb's special effects.
            bomb:AddTearFlags(player:GetBombFlags(false))
            local mega = player:HasCollectible(CollectibleType.COLLECTIBLE_MR_MEGA)
                or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_MR_MEGA)
            bomb.ExplosionDamage = mega and 185 or 100
            -- Native bombs decrement a positive countdown to trigger explosion;
            -- setting zero alone leaves the normal carrier unexploded.
            bomb:SetExplosionCountdown(1)
            bomb:Update()
        end)
        stop(k)
        if not ok and context.DebugLog then context.DebugLog("[Bomb Suit] " .. tostring(err)) end
    end
    local function update()
        if not ready or Game():IsPaused() then return end
        local frame = Game():GetFrameCount()
        local keys = {}; for k in pairs(active) do keys[#keys+1] = k end
        for _, k in ipairs(keys) do
            local state = active[k]
            if not held(state.player) then stop(k)
            elseif state.lastFrame ~= frame then
                state.lastFrame = frame; state.age = state.age + 1
                if state.age >= DURATION then detonate(k, state)
                else
                    if beepAt[state.age] then beep(state) end
                    local period = state.age >= 75 and 4 or (state.age >= 60 and 8 or 16)
                    if state.player.SetColor and state.age % period < period / 2 then
                        state.player:SetColor(Color(1, 0.65, 0.55, 1, 0.12, 0, 0), 2, 30, false, false)
                    end
                    if state.fuse then
                        local phase = state.age >= 75 and (4 + math.floor(state.age / 2) % 2)
                            or math.min(4, math.floor(state.age / 15))
                        state.fuse:SetFrame("Fuse", phase)
                    end
                end
            end
        end
    end
    local function render(_, player)
        local state = stateFor(player)
        if not state or not state.fuse or not Isaac.WorldToScreen then return end
        if RenderMode then
            local mode = Game():GetRoom():GetRenderMode()
            if mode ~= RenderMode.RENDER_NORMAL and mode ~= RenderMode.RENDER_NULL then return end
        end
        -- Same world->screen adapter as Burn Away Resentment; callback render
        -- offset is not added again. One presentation-only sprite per holder.
        local world = context.GetPlayerHeadWorldPosition and context.GetPlayerHeadWorldPosition(player)
            or player.Position + Vector(0, -35)
        state.fuse:Render(Isaac.WorldToScreen(world) + Vector(0, -10), Vector(0, 0), Vector(0, 0))
    end
    local function start() clear(); ready = true end
    local function exit() clear(); ready = false end
    local function death(_, player) stop(key(player)) end
    local function removed(_, player, item)
        if item == ID and not player:HasCollectible(ID) then stop(key(player)) end
    end
    mod.BombSuit = {IsActive=function(player) return stateFor(player) ~= nil end,
        GetAge=function(player) local s=stateFor(player); return s and s.age or nil end,
        IsBloodPayment=isBloodPayment, ItemId=ID}
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG, -20000, preDamage)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG, -20000, postDamage, EntityType.ENTITY_PLAYER)
    mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, evaluate)
    -- Nested around existing modules' priority-0 shooting scopes.
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE, -20000, prePlayer)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, 20000, postPlayer)
    mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, input)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, update)
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, start)
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, exit)
    mod:AddCallback(ModCallbacks.MC_PRE_TRIGGER_PLAYER_DEATH, death)
    mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED, removed, ID)
    -- Open after ordinary PRE callbacks, close before ordinary POST callbacks.
    -- Only the native Bomb AI segment can propose Scatter ownership candidates.
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_BOMB_UPDATE, 20000, preBomb)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_BOMB_UPDATE, -20000, postBomb)
    mod:AddCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, preSpawn)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE, -20000, function() bombScopes = {} end)
    for _, name in ipairs({"MC_POST_BOMB_INIT", "MC_POST_EFFECT_INIT", "MC_POST_TEAR_INIT"}) do
        if ModCallbacks[name] then mod:AddCallback(ModCallbacks[name], initOwned) end
    end
    if ModCallbacks.MC_POST_PLAYER_RENDER then mod:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, render) end
    if ModCallbacks.MC_POST_GLOWING_HOURGLASS_LOAD then
        mod:AddCallback(ModCallbacks.MC_POST_GLOWING_HOURGLASS_LOAD, clear)
    end
    if ModCallbacks.MC_PRE_MOD_UNLOAD then
        mod:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, function(_, unloaded) if unloaded == mod then exit() end end)
    end
end
