-- Focused engine double, loaded through the complete production entry.
return function(options)
    options = options or {}
    local function copy(value)
        if type(value) ~= 'table' then return value end
        local result = {}; for key, child in pairs(value) do result[key] = copy(child) end; return result
    end
    local saved = copy(options.Saved or {})
    local env = { players = {}, spawned = {}, renders = 0, saves = 0 }
    local loaded = dofile('tests/support/neverbirth_fixture.lua')({ Root = options.Root,
        OnModCreated = function(mod)
            local game = Game()
            Game = function() return game end
            ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD = 9001
            package.loaded.json = nil
            package.preload.json = function() return {
                encode = function(root) saved = copy(root); return '<traffic-save>' end,
                decode = function() return copy(saved) end,
            } end
            function mod:HasData() return options.Saved ~= nil end
            function mod:LoadData() return '<traffic-save>' end
            function mod:SaveData() env.saves = env.saves + 1 end
        end,
    })
    env.api, env.state, env.items, env.callbacks = Neverbirth.LittleLeatherShoesTestAPI, Neverbirth.LittleLeatherShoesState, loaded.itemIds, loaded.callbacks
    local game = Game()
    env.level = { stage = 1, index = 0 }
    function env.level:GetStage() return self.stage end
    function env.level:GetStageType() return 0 end
    function env.level:GetDimension() return 0 end
    function env.level:GetCurrentRoomIndex() return self.index end
    function env.level:GetCurrentRoomDesc() return { ListIndex=self.index, SafeGridIndex=self.index } end
    env.room = { kind = 1 }
    function env.room:GetType() return self.kind end
    function env.room:GetSpawnSeed() return 100 end
    function env.room:GetCenterPos() return Vector(320, 280) end
    function env.room:IsClear() return true end
    function env.room:GetAliveEnemiesCount() return 0 end
    env.pool = { draws = 0 }
    function env.pool:GetPoolForRoom(kind) return kind end
    function env.pool:GetCollectible(pool) self.draws = self.draws + 1; return 800 + pool end
    function game:GetRoom() return env.room end
    function game:GetLevel() return env.level end
    function game:GetNumPlayers() return #env.players end
    function game:GetItemPool() return env.pool end
    function game:GetFrameCount() return env.frame or 0 end
    Game = function() return game end
    Isaac.GetPlayer = function(index) return env.players[index + 1] end
    Isaac.GetRoomEntities = function() return {} end
    Isaac.RenderText = function() env.renders = env.renders + 1 end
    local nextSeed = 8000
    Isaac.Spawn = function(kind, variant, subtype, position)
        nextSeed = nextSeed + 1
        local entity = { Type = kind, Variant = variant, SubType = subtype, Position = position, InitSeed = nextSeed, data = {} }
        function entity:GetData() return self.data end
        function entity:Remove() self.removed = true end
        function entity:Exists() return not self.removed end
        env.spawned[#env.spawned + 1] = entity
        return entity
    end
    Sprite = function()
        return {
            updates = 0, Load = function() end, Play = function() end,
            Update = function(self) self.updates = self.updates + 1 end,
            IsFinished = function(self) return env.finishAfter and self.updates >= env.finishAfter or false end,
            Render = function() env.renders = env.renders + 1 end,
        }
    end
    function env.player(seed, inventory)
        local player = { InitSeed = seed, inventory = inventory or {}, Position = Vector(seed, 200), MaxFireDelay = 9, evaluations = 0 }
        function player:ToPlayer() return self end
        function player:Exists() return not self.gone end
        function player:HasCollectible(id) return (self.inventory[id] or 0) > 0 end
        function player:GetCollectibleNum(id) return self.inventory[id] or 0 end
        function player:RemoveCollectible(id) self.inventory[id] = math.max(0, (self.inventory[id] or 0) - 1) end
        function player:AddCacheFlags() end
        function player:EvaluateItems()
            self.evaluations = self.evaluations + 1; self.MaxFireDelay = 9
            env.api.Callbacks.EvaluateHeat(Neverbirth, self, CacheFlag.CACHE_FIREDELAY)
        end
        env.players[#env.players + 1] = player; return player
    end
    function env.event(event, ...)
        local count = 0
        for _, entry in ipairs(env.callbacks[event] or {}) do
            local source = debug.getinfo(entry.fn, 'S').source:gsub('\\', '/')
            if source:find('scripts/features/little_leather_shoes/', 1, true) or source:find('scripts/features/traffic_heat.lua', 1, true) then
                count = count + 1; entry.fn(Neverbirth, ...)
            end
        end
        assert(count > 0, 'missing real traffic event ' .. tostring(event))
    end
    function env.update(count) for _ = 1, count or 1 do env.event(ModCallbacks.MC_POST_UPDATE) end end
    -- Exercise the existing shared provenance service, not a fabricated receipt.
    function env.acquisitionEvent(event, ...)
        local found=0
        for _,entry in ipairs(env.callbacks[event] or {}) do
            if debug.getinfo(entry.fn,'S').source:gsub('\\','/'):match('scripts/systems/acquisition_state%.lua$') then
                found=found+1;entry.fn(Neverbirth,...)
            end
        end
        assert(found>0,'missing acquisition callback')
    end
    function env.grant(player, id)
        env.acquisitionEvent(ModCallbacks.MC_PRE_ADD_COLLECTIBLE,id,0,true,0,0,player)
        player.inventory[id]=(player.inventory[id] or 0)+1
        env.acquisitionEvent(ModCallbacks.MC_POST_ADD_COLLECTIBLE,id,0,true,0,0,player)
    end
    function env.queuePickup(player, pickup)
        env.event(ModCallbacks.MC_POST_PICKUP_UPDATE,pickup)
        env.acquisitionEvent(ModCallbacks.MC_PRE_PICKUP_COLLISION,pickup,player,false)
        player.QueuedItem={Item={ID=pickup.SubType}}
        pickup.SubType=0
        env.acquisitionEvent(ModCallbacks.MC_POST_PICKUP_COLLISION,pickup,player,false)
    end
    function env.flushPickup(player)
        local id=player.QueuedItem.Item.ID
        env.acquisitionEvent(ModCallbacks.MC_POST_UPDATE)
        env.frame=(env.frame or 0)+1
        player.QueuedItem.Item=nil
        env.grant(player,id)
    end
    function env.count(variant)
        local count = 0; for _, entity in ipairs(env.spawned) do if entity.Variant == variant then count = count + 1 end end; return count
    end
    function env.saved() return copy(saved) end
    env.api.ResetTransientState(false)
    return env
end
