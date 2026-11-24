-- Shared service only. Concrete items must explicitly register an approved binding.
return function(mod,context)
    context=context or {}
    if mod.MotionInput and mod.MotionInput.Shutdown then mod.MotionInput:Shutdown() end
    local C=include('motion_input_core')
    local S=include('motion_input_shooting')
    local service={active=true,bindings={},rehearsals={},states={},facings={},serials={},Capabilities={}}
    local rehearsalOwner={}
    local game=Game();local readDepth=0
    local function key(p)
        return context.Key and context.Key(p) or
            (GetPtrHash and tostring(GetPtrHash(p)) or tostring(p))..':'..tostring(p.InitSeed or 0)
    end
    local function log(message)
        if context.DebugLog then context.DebugLog('[Motion Input] '..message)
        elseif Isaac and Isaac.DebugString then Isaac.DebugString('[Motion Input] '..message) end
    end
    local function raw(p,action)
        readDepth=readDepth+1
        local ok,result=pcall(Input.GetActionValue,action,p.ControllerIndex)
        readDepth=readDepth-1
        if not ok then error(result,0) end
        return result or 0
    end
    local function masks(p,first)
        local value=0
        for i,bit in ipairs({1,2,4,8}) do if raw(p,first+i-1)>.2 then value=value|bit end end
        return value
    end
    local function has(binding,p)
        local ok,result=pcall(binding.has,p)
        if not ok then
            if not binding.hasError then log('ownership callback failed: '..tostring(result));binding.hasError=true end
            return false
        end
        return not not result
    end
    local function owned(p)
        local keys={}
        for name,b in pairs(service.bindings) do if has(b,p) then keys[name]=true end end
        if service.rehearsals[key(p)] then keys[rehearsalOwner]=true end
        return keys
    end
    local gate=S.New({Key=key,IsOwned=function(p)return service.active and next(owned(p))~=nil end})
    service.Gate=gate
    local function find(p,id)
        for name,b in pairs(service.bindings) do if b.collectibleId==id and has(b,p) then return name,b end end
    end
    local function selected(p)
        local rehearsal=service.rehearsals[key(p)]
        if rehearsal then return rehearsalOwner,rehearsal,raw(p,ButtonAction.ACTION_ITEM)>.2 end
        local mainName,main=find(p,p:GetActiveItem(0))
        local mainHeld=raw(p,ButtonAction.ACTION_ITEM)>.2
        local pocketHeld=raw(p,ButtonAction.ACTION_PILLCARD)>.2
        if mainHeld and pocketHeld then return nil,nil,false end
        if pocketHeld and p.GetPocketItem then
            local pocket=p:GetPocketItem(PillCardSlot.PRIMARY)
            if pocket and pocket:GetType()==PocketItemType.ACTIVE_ITEM then
                local slot=pocket:GetSlot()-1
                if slot>=2 and slot<=3 then local name,b=find(p,p:GetActiveItem(slot));return name,b,b~=nil end
            end
            return nil,nil,false
        end
        return mainName,main,main~=nil and mainHeld
    end
    function service:RegisterOwner(name,binding)
        assert(type(name)=='string' and name~='' and not self.bindings[name],'unique owner key required')
        assert(type(binding)=='table' and type(binding.collectibleId)=='number' and binding.collectibleId>0
            and binding.collectibleId%1==0,'positive runtime collectible ID required')
        assert(C.Profiles[binding.profile],'unknown input profile')
        assert(type(binding.has)=='function' and type(binding.execute)=='function','ownership and execution callbacks required')
        assert(binding.availability==nil or type(binding.availability)=='function','availability must be a function')
        for _,b in pairs(self.bindings) do assert(b.collectibleId~=binding.collectibleId,'one profile per collectible') end
        local copy={};for k,v in pairs(binding) do copy[k]=v end;self.bindings[name]=copy
        return true
    end
    function service:UnregisterOwner(name)
        self.bindings[name]=nil
        for _,record in pairs(self.states) do if record.owner==name then self.states[key(record.player)]=nil end end
        -- This gate resolves ownership live through IsOwned; removing the
        -- binding is sufficient. Never enumerate Game players here: mod unload
        -- also runs after the native Game has already been destroyed.
    end
    function service:IsRestricted(p) return self.active and gate:IsRestricted(p) or false end
    -- Explicit developer rehearsal only: no collectible IDs, inventory or save data.
    function service:SetRehearsal(p,binding)
        if binding then
            assert(C.Profiles[binding.profile] and type(binding.execute)=='function','valid rehearsal binding required')
            assert(binding.availability==nil or type(binding.availability)=='function','availability must be a function')
            local copy={};for k,v in pairs(binding) do copy[k]=v end
            local ownerKey=key(p);copy.has=function(who)return key(who)==ownerKey end
            self.rehearsals[key(p)]=copy
        else self.rehearsals[key(p)]=nil end
        self.states[key(p)]=nil;gate:Update(p,owned(p))
    end
    function service:SetPresentationSink(fn)
        assert(fn==nil or type(fn)=='function','presentation sink must be a function')
        self.presentationSink=fn
    end
    function service:MarkAttack(p,e,serial) return gate:MarkAttack(p,e,serial) end
    function service:WithCommand(p,command,fn,...) return gate:WithCommand(p,command,fn,...) end
    function service:Reset(reason)
        self.states={};self.rehearsals={};gate:Reset();self.lastReset=reason
        if reason=='MC_POST_GAME_STARTED' or reason=='MC_PRE_GAME_EXIT' or reason=='unload' then self.facings={} end
    end
    function service:Shutdown() self.active=false;self:Reset('unload');self.presentationSink=nil end
    function service:GetState(p)
        local r=self.states[key(p)];if not r then return {restricted=self:IsRestricted(p),count=0} end
        local view=C.View(r.core);view.owner=r.owner==rehearsalOwner and '__presentation_rehearsal' or r.owner;view.restricted=self:IsRestricted(p)
        view.lastEvent=r.lastEvent;view.executionError=r.executionError;view.activeHeld=r.activeHeld;view.directionMask=r.directionMask
        view.history={};for i,v in ipairs(r.history or {})do view.history[i]=v end;return view
    end
    function service:GetDiagnosticText(p)
        local v=self:GetState(p)
        local kind=v.lastEvent and v.lastEvent.kind
        local text=v.pending and '输入正确，暂存中' or (kind=='failure' and '输入正确，条件不足'
            or (kind=='execute' and '已释放' or '输入未完成'))
        return text..' | '..tostring(v.profile or '-')..' | '..tostring(v.facing or '-')..' | '..tostring(v.count or 0)
    end
    function service:SamplePlayer(p)
        if not self.active or next(self.bindings)==nil and next(self.rehearsals)==nil then return end
        if p.IsDead and p:IsDead() and self.rehearsals[key(p)] then self:SetRehearsal(p,nil) end
        gate:Update(p,owned(p))
        local owner,binding,activeHeld=selected(p)
        local record=self.states[key(p)]
        local seq=record and record.sequence+1 or 1
        local heads={[0]='left',[1]='up',[2]='right',[3]='down'}
        local directions=masks(p,ButtonAction.ACTION_SHOOTLEFT)
        local tap=binding and (binding.profile=='wave_tap' or binding.profile=='double_wave_tap')
        -- All motions now use shooting directions. For ordinary motions these
        -- same keys must not rotate the front reference while entering 623 or
        -- a circle. Keep the last explicit shot/head facing until release.
        local facingDirections=activeHeld and not tap and 0 or directions
        local sample={time=context.Now and context.Now() or game:GetFrameCount()/30,sequence=seq,
            moveMask=directions,shootMask=facingDirections,
            activeHeld=activeHeld,headFacing=heads[p:GetHeadDirection()] or 'down',profile=binding and binding.profile,
            lastShotFacing=self.facings[key(p)]}
        if game:IsPaused() or p.IsDead and p:IsDead() then sample.activeHeld=false end
        if binding and binding.availability then
            local ok,result=pcall(binding.availability,p);sample.availability=ok and result or 'unavailable'
        else sample.availability='ready' end
        if not record or record.owner~=owner then
            record={player=p,owner=owner,sequence=seq,core=C.New(sample)};self.states[key(p)]=record
            record.core.serial=self.serials[key(p)] or 0
            self.facings[key(p)]=record.core.lastShotFacing
            return
        end
        if not record.activeHeld then record.history={} end
        record.history=record.history or {}
        if sample.activeHeld and directions~=0 and directions~=record.directionMask then
            local label=(directions&1~=0 and '<' or '')..(directions&4~=0 and '^' or '')
                ..(directions&8~=0 and 'v' or '')..(directions&2~=0 and '>' or '')
            record.history[#record.history+1]=label;if #record.history>8 then table.remove(record.history,1)end
        end
        record.activeHeld=sample.activeHeld;record.directionMask=directions
        record.sequence=seq
        local events=C.Step(record.core,sample)
        self.facings[key(p)]=record.core.lastShotFacing
        self.serials[key(p)]=record.core.serial
        for _,event in ipairs(events) do
            record.lastEvent=event
            if event.kind=='execute' and binding and owner==record.owner and has(binding,p) then
                local valid,status=true,'ready'
                if binding.availability then valid,status=pcall(binding.availability,p) end
                if valid and status=='ready' then
                    local ok,result=pcall(function()
                        return gate:WithCommand(p,event,function()return binding.execute(p,event)end)
                    end)
                    if not ok or type(result)~='table' or result.ok~=true then
                        record.executionError=not ok and tostring(result) or (type(result)=='table' and result.reason or 'not_executed')
                        record.lastEvent={kind='failure',reason=record.executionError,profile=event.profile,serial=event.serial,facing=event.facing}
                        if not ok then log('execution callback failed: '..tostring(result)) end
                    else
                        record.executionError=nil
                        if self.presentationSink and owner~=rehearsalOwner then
                            local shown,err=pcall(self.presentationSink,p,event,result)
                            if not shown then log('presentation callback failed: '..tostring(err)) end
                        end
                    end
                else record.lastEvent={kind='failure',reason=status,profile=event.profile,serial=event.serial,facing=event.facing} end
            end
            if context.OnFeedback then context.OnFeedback(p,record.lastEvent,self:GetState(p)) end
        end
    end
    local function add(name,priority,fn)
        local id=ModCallbacks[name]
        if id then mod:AddPriorityCallback(id,priority,fn) end
    end
    local function enabled() return service.active and (next(service.bindings)~=nil or next(service.rehearsals)~=nil) end
    add('MC_PRE_PLAYER_UPDATE',-30000,function(_,p)service:SamplePlayer(p)end)
    add('MC_INPUT_ACTION',-30000,function(_,e,hook,action)
        if not enabled() or readDepth>0 or not e then return end
        local p=e.ToPlayer and e:ToPlayer()
        if p and gate:IsRestricted(p) and action>=ButtonAction.ACTION_SHOOTLEFT and action<=ButtonAction.ACTION_BOMB then
            return hook==InputHook.GET_ACTION_VALUE and 0 or false
        end
    end)
    add('MC_PRE_USE_ITEM',-30000,function(_,id,_,p)
        -- Installed 1.0.12a PRE_USE_ITEM is a boolean callback: only true cancels.
        if service.active and p and (service.rehearsals[key(p)] or find(p,id)) then return true end
    end)
    local dot=Isaac.GetStatusAttributionAPIVersion and Isaac.GetStatusAttributionAPIVersion()==1
        and type(Isaac.GetCurrentDotDamageKind)=='function'
    service.Capabilities.exactDot=not not dot
    add('MC_ENTITY_TAKE_DMG',-30000,function(_,target,_,_,source)
        if not enabled() then return end
        local kind=dot and Isaac.GetCurrentDotDamageKind(target,source) or 0
        if gate:ShouldBlockDamage(target,source,kind) then return false end
    end)
    for _,name in ipairs({'TEAR','LASER','KNIFE','BOMB','PROJECTILE'}) do
        add('MC_POST_'..name..'_INIT',-30000,function(_,e)if enabled() then gate:ObserveEntity(e) end end)
        add('MC_PRE_'..name..'_UPDATE',-30000,function(_,e)if enabled() and gate:ObserveEntity(e) then return true end end)
    end
    add('MC_POST_EFFECT_INIT',-30000,function(_,e)if enabled() then gate:ObserveEntity(e) end end)
    add('MC_POST_ENTITY_REMOVE',0,function(_,e)if service.active then gate:ForgetEntity(e) end end)
    if dot then
        mod:AddCallback('REPENTOGON_POST_DOT_APPLIED',function(_,e,source,kind)if service.active then gate:StatusApplied(e,source,kind) end end)
        mod:AddCallback('REPENTOGON_POST_DOT_COPY',function(_,a,b,overwrite)if service.active then gate:CopyStatus(a,b,overwrite) end end)
    end
    for _,name in ipairs({'MC_POST_NEW_ROOM','MC_POST_GAME_STARTED','MC_PRE_GAME_EXIT','MC_POST_GLOWING_HOURGLASS_LOAD'}) do
        add(name,0,function()if service.active then service:Reset(name) end end)
    end
    add('MC_PRE_MOD_UNLOAD',0,function(_,unloaded)if unloaded==mod then service:Shutdown() end end)
    mod.MotionInput=service
    return service
end
