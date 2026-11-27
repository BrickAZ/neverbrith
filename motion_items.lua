-- Formal actives delegate recognized commands to the real combat executor.
return function(mod,context)
    context=context or {}
    if mod.MotionItems then mod.MotionItems:Shutdown() end
    local input=assert(context.Input or mod.MotionInput,'motion input must load first')
    local presentation=assert(context.Presentation or mod.MotionPresentation,'motion presentation must load first')
    local combat=assert(context.Combat or mod.MotionCombat,'motion combat must load before formal bindings')
    local specs=assert(combat.Specifications,'motion combat must supply the item specifications')
    local entityKey=include('scripts/systems/entity_identity')
    local api={active=true,registered={},playbacks={}}
    local function key(p)
        return context.Key and context.Key(p) or entityKey(p)
    end
    local function owned(p,id)return p and p:Exists() and p:HasCollectible(id) end
    local function stop(record)
        local current=presentation:GetState(record.player)
        if current and current.sourceOwner==record.owner then presentation:Stop(record.player,true) end
    end
    function api:Reset()
        for _,record in pairs(self.playbacks) do stop(record) end
        self.playbacks={}
    end
    function api:Shutdown()
        if not self.active then return end
        self:Reset();self.active=false
        for _,owner in ipairs(self.registered) do input:UnregisterOwner(owner) end
        self.registered={}
    end
    for _,spec in ipairs(specs) do
        local id=context.Items and context.Items[spec.field]
        if type(id)=='number' and id>0 and id%1==0 then
            local owner='motion_item:'..spec.key
            input:RegisterOwner(owner,{collectibleId=id,profile=spec.profile,anyDirection=spec.anyDirection,has=function(p)return api.active and owned(p,id) end,
                availability=function(p)return combat:IsBusy(p) and 'recovery' or 'ready' end,
                execute=function(p,command)
                    if not api.active or not owned(p,id) then return {ok=false,reason='ownership'} end
                    local result=combat:Execute(p,spec.key,command,{id=id,owner=owner})
                    if not result.ok then return result end
                    api.playbacks[key(p)]={player=p,id=id,owner=owner}
                    -- We already invoked the player-owned presentation; avoid a
                    -- second automatic Play through the generic success sink.
                    return {ok=true,presentation=false}
                end})
            api.registered[#api.registered+1]=owner
        elseif context.DebugLog then context.DebugLog('[Motion Items] Missing registered runtime ID: '..spec.field) end
    end
    local function add(name,fn)
        if ModCallbacks[name] then mod:AddCallback(ModCallbacks[name],fn) end
    end
    add('MC_POST_ADD_COLLECTIBLE',function(_,id,_,_,_,_,p)
        local saId=context.Items and context.Items.Ultimate720
        if api.active and id==saId and owned(p,id) then combat:OnAcquire(p,'circle_720') end
    end)
    add('MC_POST_UPDATE',function()
        if not api.active then return end
        for k,record in pairs(api.playbacks) do
            if not owned(record.player,record.id) or record.player:IsDead() then stop(record);api.playbacks[k]=nil
            else
                local current=presentation:GetState(record.player)
                if not current or current.sourceOwner~=record.owner then api.playbacks[k]=nil end
            end
        end
    end)
    for _,name in ipairs({'MC_POST_NEW_ROOM','MC_POST_NEW_LEVEL','MC_POST_GAME_STARTED','MC_PRE_GAME_EXIT','MC_POST_GLOWING_HOURGLASS_LOAD'}) do
        add(name,function()if api.active then api:Reset() end end)
    end
    add('MC_PRE_MOD_UNLOAD',function(_,unloaded)if unloaded==mod then api:Shutdown() end end)
    mod.MotionItems=api
    return api
end
