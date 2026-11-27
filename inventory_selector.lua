-- Transient, owner-scoped inventory chooser. The caller owns eligibility, effects and costs.
-- Native carriers verified in the installed game's unpacked resources; no entity is spawned.
return function(mod, context)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    context = context or {}
    local api, sessions, releases = {}, {}, {}
    local game = Game()
    local readingInput = 0
    local columns, pageSize = 4, 12
    local actions = ButtonAction or {}
    local hooks = InputHook or {}
    local blocked, releaseActions = {}, {}
    for _, name in ipairs({"ACTION_LEFT", "ACTION_RIGHT", "ACTION_UP", "ACTION_DOWN",
        "ACTION_SHOOTLEFT", "ACTION_SHOOTRIGHT", "ACTION_SHOOTUP", "ACTION_SHOOTDOWN",
        "ACTION_BOMB", "ACTION_ITEM", "ACTION_PILLCARD", "ACTION_DROP",
        "ACTION_MENUCONFIRM", "ACTION_MENUBACK", "ACTION_MENULEFT", "ACTION_MENURIGHT",
        "ACTION_MENUUP", "ACTION_MENUDOWN"}) do
        local action = actions[name]
        if action ~= nil then blocked[action] = true; releaseActions[#releaseActions + 1] = action end
    end

    local function log(message)
        if context.DebugLog then pcall(context.DebugLog, "InventorySelector: " .. tostring(message)) end
    end

    local function playerKey(player)
        if not player then return nil end
        if context.State and context.State.InventoryPlayerKey then
            local key = context.State.InventoryPlayerKey(player)
            if key ~= nil then return tostring(key) end
        end
        if context.State and context.State.PlayerKey then
            local key = context.State.PlayerKey(player)
            if key ~= nil then return tostring(key) end
        end
        return tostring(player.InitSeed or player) .. ":" .. tostring(player.ControllerIndex)
    end

    local function boundary(name)
        if context.State and context.State[name] then return context.State[name]() end
        local level = game:GetLevel()
        local floor = tostring(level:GetStage()) .. ":" .. tostring(level:GetStageType())
        if name == "FloorKey" then return floor end
        -- MC_POST_NEW_ROOM also cancels dimension changes; the shared service supplies a
        -- richer dimension-aware key when present. This fallback only uses vanilla methods.
        return floor .. ":" .. tostring(level:GetCurrentRoomIndex())
    end

    local function alive(player)
        return player and (not player.Exists or player:Exists()) and (not player.IsDead or not player:IsDead())
    end

    local function rawInput(method, action, controller)
        if action == nil or not Input or not Input[method] then return false end
        readingInput = readingInput + 1
        local ok, value = pcall(Input[method], action, controller)
        readingInput = readingInput - 1
        if not ok then error(value) end
        return value
    end

    local function held(action, controller)
        return rawInput("IsActionPressed", action, controller) == true
            or (tonumber(rawInput("GetActionValue", action, controller)) or 0) > 0.2
    end

    local function notify(request, reason)
        if request.onCancel then
            local ok, err = pcall(request.onCancel, reason)
            if not ok then log("onCancel error: " .. tostring(err)) end
        end
    end

    local function finish(key, reason, success)
        local session = sessions[key]
        if not session then return end
        -- Remove before running foreign callbacks. Cleanup is idempotent and cannot be interrupted.
        sessions[key] = nil
        releases[key] = {player = session.player, controller = session.controller}
        if not success then notify(session.request, reason) end
    end

    local function safely(key, fn)
        local ok, err = pcall(fn)
        if not ok then
            log(err)
            if key then finish(key, "callback_error") end
        end
        return ok
    end

    local function entries(player, request)
        local provider = request.getEntries or context.GetEntries
        if type(provider) ~= "function" then error("GetEntries adapter unavailable") end
        local result, byId = {}, {}
        for i, source in ipairs(provider(player) or {}) do
            local id, count = tonumber(source.id), tonumber(source.count)
            if id and id > 0 and count and count > 0 then
                local temporary = math.max(0, math.min(count, tonumber(source.temporaryCount) or 0))
                local entry = byId[id]
                if entry then
                    entry.count = entry.count + count
                    entry.temporaryCount = entry.temporaryCount + temporary
                    entry.order = math.min(entry.order, tonumber(source.order) or i)
                else
                    entry = {id = id, count = count, temporaryCount = temporary,
                        name = source.name or tostring(id), gfx = source.gfx, type = source.type,
                        order = tonumber(source.order) or i, payload = source.payload,
                        spritePath = source.spritePath, animation = source.animation,
                        layer = source.layer, frame = source.frame}
                    byId[id] = entry; result[#result + 1] = entry
                end
            end
        end
        table.sort(result, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.id < b.id end)
        local eligible = {}
        for _, entry in ipairs(result) do
            -- Evaluate after merging, so the predicate sees the actual normal/temporary quantities.
            if not request.eligible or request.eligible(player, entry) == true then eligible[#eligible + 1] = entry end
        end
        return eligible
    end

    function api.Open(player, request)
        if type(request) ~= "table" or type(request.execute) ~= "function" or not alive(player) then return false end
        if actions.ACTION_MENUCONFIRM == nil or actions.ACTION_MENUBACK == nil then
            log("native menu actions unavailable"); return false
        end
        local key = playerKey(player)
        if sessions[key] or releases[key] then return false end
        for _, session in pairs(sessions) do
            if session.controller == player.ControllerIndex then return false end
        end
        for _, release in pairs(releases) do
            if release.controller == player.ControllerIndex then return false end
        end
        local opened = false
        local ok = safely(nil, function()
            if request.valid and request.valid(player) ~= true then notify(request, "caller_invalid"); return end
            local targets = entries(player, request)
            if #targets == 0 then notify(request, "no_targets"); return end
            local controller = player.ControllerIndex
            if controller == nil then error("owner controller unavailable") end
            local initialHeld = {}
            for _, action in ipairs(releaseActions) do initialHeld[action] = held(action, controller) end
            -- Opening while a trigger key is down never confirms or navigates immediately.
            sessions[key] = {player = player, controller = controller, request = request,
                title = request.title or "", entries = targets, selected = 1, page = 1,
                room = boundary("RoomKey"), floor = boundary("FloorKey"),
                initialHeld = initialHeld, repeats = {}, icons = {}}
            opened = true
        end)
        if not ok then notify(request, "callback_error") end
        return opened
    end

    function api.Close(player, reason)
        finish(playerKey(player), reason or "cancelled")
    end

    function api.GetSession(player)
        return sessions[playerKey(player)]
    end

    function api.IsBlocking(player)
        local key = playerKey(player)
        return sessions[key] ~= nil or releases[key] ~= nil
    end

    local function closeAll(reason, dropRelease)
        local keys = {}; for key in pairs(sessions) do keys[#keys + 1] = key end
        for _, key in ipairs(keys) do finish(key, reason) end
        if dropRelease then releases = {} end
    end

    local function invalidReason(session)
        if not alive(session.player) then return "owner_invalid" end
        if session.player.ControllerIndex ~= session.controller then return "controller_changed" end
        if boundary("FloorKey") ~= session.floor then return "floor_changed" end
        if boundary("RoomKey") ~= session.room then return "room_changed" end
        if session.request.valid and session.request.valid(session.player) ~= true then return "caller_invalid" end
    end

    local function edge(session, action)
        if action == nil then return false end
        if session.initialHeld[action] then
            if not held(action, session.controller) then session.initialHeld[action] = nil end
            return false
        end
        return rawInput("IsActionTriggered", action, session.controller) == true
    end

    local function direction(session, menuAction, moveAction)
        local triggered = edge(session, menuAction) or edge(session, moveAction)
        local down = (not session.initialHeld[menuAction] and held(menuAction, session.controller))
            or (not session.initialHeld[moveAction] and held(moveAction, session.controller))
        if not down then session.repeats[menuAction] = 0; return triggered end
        local ticks = (session.repeats[menuAction] or 0) + 1
        session.repeats[menuAction] = ticks
        return triggered or ticks == 1 or (ticks >= 12 and ticks % 4 == 0)
    end

    local function confirm(key, session)
        -- Re-read the inventory and caller immediately before executing. A disappearing ID
        -- never redirects confirmation to the next entry that happens to occupy its slot.
        local reason = invalidReason(session)
        if reason then finish(key, reason); return end
        local selected = session.entries[session.selected]
        local current
        for _, entry in ipairs(entries(session.player, session.request)) do
            if selected and entry.id == selected.id then current = entry; break end
        end
        if not current then finish(key, "target_invalid"); return end
        session.executing = true
        local succeeded = session.request.execute(session.player, current) == true
        finish(key, succeeded and "success" or "execute_failed", succeeded)
    end

    local function updatePlayer(_, player)
        local key = playerKey(player)
        if releases[key] then
            local release = releases[key]
            local ok, down = pcall(function()
                for _, action in ipairs(releaseActions) do if held(action, release.controller) then return true end end
                return false
            end)
            if not ok then log(down) end
            if not ok or not down or not alive(player) then releases[key] = nil end
            return
        end
        local session = sessions[key]
        if not session or session.executing then return end
        safely(key, function()
            local reason = invalidReason(session)
            if reason then finish(key, reason); return end
            if game:IsPaused() then return end
            if edge(session, actions.ACTION_MENUBACK) then finish(key, "cancelled"); return end
            if edge(session, session.request.confirmAction or actions.ACTION_MENUCONFIRM) then confirm(key, session); return end
            local delta = 0
            if direction(session, actions.ACTION_MENULEFT, actions.ACTION_LEFT) then delta = -1
            elseif direction(session, actions.ACTION_MENURIGHT, actions.ACTION_RIGHT) then delta = 1
            elseif direction(session, actions.ACTION_MENUUP, actions.ACTION_UP) then delta = -columns
            elseif direction(session, actions.ACTION_MENUDOWN, actions.ACTION_DOWN) then delta = columns end
            session.selected = math.max(1, math.min(#session.entries, session.selected + delta))
            session.page = math.floor((session.selected - 1) / pageSize) + 1
        end)
    end
    function callbackInstallers.updatePlayer(add)
        return add("MC_POST_PLAYER_UPDATE", updatePlayer)
    end

    local function inputAction(_, entity, hook, action)
        if readingInput > 0 or not entity or not blocked[action] then return end
        local player = entity.ToPlayer and entity:ToPlayer()
        if not player then return end
        local key = playerKey(player)
        if not sessions[key] and not releases[key] then return end
        if hook == hooks.GET_ACTION_VALUE then return 0 end
        if hook == hooks.IS_ACTION_PRESSED or hook == hooks.IS_ACTION_TRIGGERED then return false end
    end
    function callbackInstallers.inputAction(add)
        return add("MC_INPUT_ACTION", inputAction)
    end

    local function text(value, x, y, r, g, b)
        if context.RenderText then return context.RenderText(tostring(value), x, y, r or 1, g or 1, b or 1, 1) end
        if Isaac.RenderText then return Isaac.RenderText(tostring(value), x, y, r or 1, g or 1, b or 1, 1) end
    end

    local function label(key, fallback)
        return context.GetText and context.GetText(key) or fallback
    end

    local function renderSession(session, index, total)
        -- Fixed HUD screen coordinates, never world/camera coordinates. Slots are sorted by controller.
        local width, height = Isaac.GetScreenWidth(), Isaac.GetScreenHeight()
        local x = total == 1 and (width / 2 - 72) or (index % 2 == 1 and 34 or width / 2 + 14)
        local y = total <= 2 and 68 or (index <= 2 and 42 or height / 2 + 38)
        local spacing = total > 2 and 25 or 34
        text("P" .. (session.controller + 1) .. " " .. session.title, x - 10, y - 30)
        local first = (session.page - 1) * pageSize + 1
        if not session.frame and type(Sprite) == "function" then
            session.frame = Sprite(); session.frame:Load("gfx/ui/ui_inventory.anm2", true)
            session.frame:SetFrame("Idle", 0); session.frame.Scale = Vector(spacing / 16, spacing / 16)
        end
        for i = first, math.min(#session.entries, first + pageSize - 1) do
            local entry, slot = session.entries[i], i - first
            local px, py = x + (slot % columns) * spacing, y + math.floor(slot / columns) * spacing
            if i == session.selected and session.frame then session.frame:Render(Vector(px, py)) end
            if (entry.gfx or entry.spritePath) and type(Sprite) == "function" then
                local icon = session.icons[entry.id]
                if not icon then
                    icon = Sprite(); icon:Load(entry.spritePath or "gfx/005.100_collectible.anm2", true)
                    if entry.gfx then icon:ReplaceSpritesheet(1, entry.gfx); icon:LoadGraphics() end
                    icon:SetFrame(entry.animation or "Idle", entry.frame or 0)
                    if total > 2 then icon.Scale = Vector(0.7, 0.7) end
                    session.icons[entry.id] = icon
                end
                -- Render only the collectible head layer, excluding pedestal, sparkle and shadow.
                if entry.spritePath then
                    if entry.layer ~= nil then icon:RenderLayer(entry.layer, Vector(px, py))
                    else icon:Render(Vector(px, py)) end
                else icon:RenderLayer(1, Vector(px, py + (total > 2 and 15 or 22))) end
            end
            text("x" .. entry.count, px + 7, py + 8, 1, 1, 0.6)
        end
        local selected = session.entries[session.selected]
        local footer = y + spacing * 2 + 20
        text(selected.name .. " x" .. selected.count, x - 10, footer)
        if selected.temporaryCount > 0 then
            text(label("temporary", "Temporary") .. " x" .. selected.temporaryCount, x - 10, footer + 12, 0.6, 0.8, 1)
        end
        text(session.page .. "/" .. math.ceil(#session.entries / pageSize), x + spacing * 3 - 8, y - 16)
        if total <= 2 then text(session.request.controls or label("controls", "Move: select  Confirm / Back"), x - 16, footer + 26) end
    end

    local function render()
        if game:IsPaused() then return end
        local list = {}; for key, session in pairs(sessions) do list[#list + 1] = {key = key, session = session} end
        table.sort(list, function(a, b) return a.session.controller < b.session.controller end)
        for index, item in ipairs(list) do
            safely(item.key, function() renderSession(item.session, index, #list) end)
        end
    end
    function callbackInstallers.render(add)
        return add("MC_POST_RENDER", render)
    end

    local function sweep()
        local present
        if context.GetPlayers then
            present = {}; for _, player in ipairs(context.GetPlayers()) do present[playerKey(player)] = true end
        end
        local keys = {}; for key in pairs(sessions) do keys[#keys + 1] = key end
        for _, key in ipairs(keys) do
            safely(key, function()
                if not alive(sessions[key].player) or (present and not present[key]) then finish(key, "owner_invalid") end
            end)
        end
        for key, release in pairs(releases) do
            if not alive(release.player) or (present and not present[key]) then releases[key] = nil end
        end
    end
    function callbackInstallers.sweep(add)
        return add("MC_POST_UPDATE", sweep)
    end

    local function debugCommand(_, command, parameters)
        if command ~= "inventory_selector" then return end
        local index = tonumber(parameters == "" and "0" or parameters) or 0
        local players = context.GetPlayers and context.GetPlayers() or {}
        local player = players[index + 1]
        if not player then log("player index unavailable: " .. tostring(index)); return end
        local opened = api.Open(player, {title = label("debugTitle", "Inspect inventory"),
            execute = function(owner, entry)
                log("selected controller=" .. owner.ControllerIndex .. " id=" .. entry.id
                    .. " count=" .. entry.count .. " temporary=" .. entry.temporaryCount)
                return true -- Diagnostic only: no collectible grant/removal, charge or persistent effect.
            end})
        log(opened and "debug opened" or "debug not opened")
    end
    function callbackInstallers.debugCommand(add)
        return add("MC_EXECUTE_CMD", debugCommand)
    end

    local function add(name, callback)
        if ModCallbacks[name] then mod:AddCallback(ModCallbacks[name], callback) end
    end
    mod.InventorySelector = api
    callbackInstallers.updatePlayer(add)
    callbackInstallers.inputAction(add)
    callbackInstallers.render(add)
    callbackInstallers.sweep(add)
    add("MC_POST_NEW_ROOM", function() closeAll("room_changed") end)
    add("MC_POST_NEW_LEVEL", function() closeAll("floor_changed") end)
    add("MC_PRE_GAME_EXIT", function() closeAll("game_exit", true) end)
    add("MC_POST_GAME_END", function() closeAll("game_end", true) end)
    add("MC_POST_GAME_STARTED", function() closeAll("game_started", true) end)
    add("MC_PRE_MOD_UNLOAD", function() closeAll("mod_unload", true) end)
    callbackInstallers.debugCommand(add)
    return api
end
