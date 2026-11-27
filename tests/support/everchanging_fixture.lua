-- Isolated feature instance with observable persistence, RNG and cosmetic calls.
return function(options)
    options = options or {}
    local e = { players = {}, calls = {}, logs = {}, saves = {}, lookups = {}, seed = '12', callbacks = {} }
    local function clone(v)
        if type(v) ~= 'table' then return v end
        local out = {}; for k, value in pairs(v) do out[k] = clone(value) end; return out
    end
    e.clone = clone
    e.saved = options.Saved or { runSeed = '12', players = {} }
    local store = {
        Get = function() return e.saved end,
        Replace = function(v) e.saved = v; e.calls[#e.calls + 1] = { 'replace', clone(v) } end,
        Save = function() e.saves[#e.saves + 1] = clone(e.saved); e.calls[#e.calls + 1] = { 'save', clone(e.saved) } end,
    }
    ModCallbacks = {}
    for _, name in ipairs({'MC_POST_PLAYER_UPDATE','MC_POST_PLAYER_INIT','MC_POST_NEW_ROOM',
        'MC_POST_NEW_LEVEL','MC_POST_GAME_STARTED','MC_EXECUTE_CMD','MC_PRE_GAME_EXIT','MC_PRE_MOD_UNLOAD'}) do
        ModCallbacks[name] = name
    end
    PlayerType = { PLAYER_JACOB = 19, PLAYER_ESAU = 20, PLAYER_JACOB_B = 39 }
    Isaac = {
        GetCostumeIdByPath = function(path)
            e.lookups[path] = (e.lookups[path] or 0) + 1
            if e.lookup then return e.lookup(path) end
            local id = 100; for i = 1, #path do id = id + path:byte(i) end; return id
        end,
        GetPlayerTypeByName = function() return 9001 end,
    }
    function include(name) return dofile((options.Root or '') .. name:gsub('%.', '/') .. '.lua') end
    e.mod = {}
    function e.mod:AddCallback(event, fn) e.callbacks[event] = fn end
    include('scripts.features.everchanging')(e.mod, {
        Store = store, Items = { Everchanging = 770 }, GetPlayers = function() return e.players end,
        GetCurrentRunSeed = function() return e.seed end,
        IsValidItemId = function(id) return type(id) == 'number' and id > 0 end,
        Log = function(s) e.logs[#e.logs + 1] = s end,
    })
    e.api = e.mod.EverchangingTestAPI
    function e.event(name, ...) return assert(e.callbacks[name])(e.mod, ...) end
    function e.player(seed, playerType)
        local p = { InitSeed = seed, data = {}, count = 0, playerType = playerType or 0, draws = {}, costumes = {} }
        local sprite = { filename = 'gfx/001.000_player.anm2', animation = 'WalkDown', frame = 7, overlay = 'HeadDown', overlayFrame = 2 }
        function sprite:GetFilename() return self.filename end
        function sprite:GetAnimation() return self.animation end
        function sprite:GetFrame() return self.frame end
        function sprite:GetOverlayAnimation() return self.overlay end
        function sprite:GetOverlayFrame() return self.overlayFrame end
        function sprite:Load(path, graphics)
            e.calls[#e.calls + 1] = { 'load', seed, path, graphics }
            if p.failLoad then error('injected ANM2 load', 0) end
            self.filename, self.frame, self.overlay, self.overlayFrame = path, 0, '', 0
        end
        function sprite:SetFrame(animation, frame) self.animation, self.frame = animation, frame end
        function sprite:SetOverlayFrame(animation, frame) self.overlay, self.overlayFrame = animation, frame end
        function p:GetData() return self.data end
        function p:GetSprite() return sprite end
        function p:GetPlayerType() return self.playerType end
        function p:GetOtherTwin() return self.twin end
        function p:GetCollectibleNum() return self.count end
        function p:GetCollectibleRNG()
            return { RandomInt = function(_, n)
                self.draws[#self.draws + 1] = n; e.calls[#e.calls + 1] = { 'draw', seed, n }
                if self.failRng then error('injected RNG failure', 0) end
                return self.roll or (#self.draws - 1)
            end }
        end
        function p:AddNullCostume(id)
            e.calls[#e.calls + 1] = { 'add', seed, id }
            if id == self.failCostume then error('injected costume failure', 0) end
            self.costumes[id] = true
        end
        function p:TryRemoveNullCostume(id)
            e.calls[#e.calls + 1] = { 'remove', seed, id }
            if self.failRemove then error('injected costume removal', 0) end
            self.costumes[id] = nil
        end
        e.players[#e.players + 1] = p; return p
    end
    function e.fullStyle()
        local r = e.api.BuildStyleRegistry({{ id = 'test_full', slots = {'full'}, full = true,
            resources = { full = { anm2 = 'gfx/test_full.anm2' } } }})
        e.api.StyleRegistry[#e.api.StyleRegistry + 1] = r[1]; e.api.StyleRegistry.byId.test_full = r[1]
    end
    function e.snapshot()
        local players = {}
        for _, p in ipairs(e.players) do players[#players + 1] = { seed = p.InitSeed, count = p.count,
            data = clone(p.data), costumes = clone(p.costumes), sprite = clone(p:GetSprite()), draws = clone(p.draws) } end
        return { saved = clone(e.saved), saves = clone(e.saves), calls = clone(e.calls), logs = clone(e.logs), players = players }
    end
    return e
end
