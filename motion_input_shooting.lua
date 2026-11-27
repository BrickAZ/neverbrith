-- Owns attack provenance and restriction state, never the player's CanShoot flag.
local S={}
local pointerSeed=include('scripts/systems/entity_identity')
local attackTypes={[2]=true,[4]=true,[7]=true,[8]=true,[9]=true}
local TAG='NeverbirthMotionAttackV1'
local function player(e) return e and e.ToPlayer and e:ToPlayer() end
local function data(e) return e and e.GetData and e:GetData() end
function S.New(context)
    context=context or {}
    local gate={players={},owned={},issued={},stack={},statuses={}}
    local issuer={}
    local function key(p)
        if context.Key then return context.Key(p) end
        return pointerSeed(p)
    end
    local function entityKey(e)
        if context.EntityKey then return context.EntityKey(e) end
        return pointerSeed(e)
    end
    function gate:Update(p,owners)
        local k=key(p);self.players[k]=p;self.owned[k]=type(owners)=='table' and next(owners)~=nil or owners==true
    end
    function gate:IsRestricted(p)
        if not p then return false end
        if context.IsOwned then return not not context.IsOwned(p) end
        return self.owned[key(p)]==true
    end
    function gate:ReleasePlayer(p) self.owned[key(p)]=nil end
    function gate:Resolve(source)
        local e=source and (source.Entity or source)
        local queue,seen={e},{};local at=1;local candidate
        while at<=#queue and at<=64 do
            local node=queue[at];at=at+1
            if node and not seen[node] then
                seen[node]=true
                local d=data(node);local tag=d and d[TAG]
                if tag and tag.issuer==issuer and self.players[tag.owner] then
                    if tag.token then return self.players[tag.owner],tag.token end
                    candidate=candidate or self.players[tag.owner]
                end
                local p=player(node)
                if p then candidate=candidate or p end
                if node.SpawnerEntity then queue[#queue+1]=node.SpawnerEntity end
                if node.Parent then queue[#queue+1]=node.Parent end
                local f=node.ToFamiliar and node:ToFamiliar()
                if f and f.Player then queue[#queue+1]=f.Player end
            end
        end
        return candidate
    end
    local function tokenFor(p,command)
        local k=key(p);gate.players[k]=p;gate.issued[k]=gate.issued[k] or {}
        local serial=command and command.serial
        assert(type(serial)=='number' and serial>0 and serial%1==0,'command needs a positive completion serial')
        local token=gate.issued[k][serial]
        if not token then token={owner=k,serial=serial};gate.issued[k][serial]=token end
        return token
    end
    local function scoped(p)
        local scope=gate.stack[#gate.stack]
        return scope and scope.owner==key(p) and scope or nil
    end
    function gate:MarkAttack(p,e,serial)
        local k=key(p);local token=self.issued[k] and self.issued[k][serial]
        if not token or player(e) then return false end
        local owner=self:Resolve(e)
        if owner and key(owner)~=k then return false end
        local d=data(e);if not d then return false end
        d[TAG]={issuer=issuer,owner=k,token=token};return true
    end
    function gate:WithCommand(p,command,fn,...)
        local token=tokenFor(p,command);self.stack[#self.stack+1]=token
        local result=table.pack(pcall(fn,...));self.stack[#self.stack]=nil
        if not result[1] then error(result[2],0) end
        return table.unpack(result,2,result.n)
    end
    function gate:ObserveEntity(e)
        if not e or player(e) then return false end
        local p,token=self:Resolve(e)
        local scope=self.stack[#self.stack]
        -- Only attack/effect creations inherit the synchronous execution scope;
        -- room/NPC/pickup side effects must not become command attacks.
        if not p and scope and (attackTypes[e.Type] or e.Type==1000) then p=self.players[scope.owner] end
        if not p then return false end
        token=token or scoped(p)
        local d=data(e)
        if d then d[TAG]={issuer=issuer,owner=key(p),token=token} end
        if self:IsRestricted(p) and not token and attackTypes[e.Type] then
            if e.Remove then e:Remove() end
            return true
        end
        return false
    end
    function gate:ShouldBlockDamage(target,source,kind)
        -- Do not turn a shooting restriction into cancelled self-health payments.
        if player(target) then return false end
        local p,token
        if kind and kind>=1 and kind<=3 then
            local record=self.statuses[entityKey(target)];local status=record and record[kind]
            if status then p=self.players[status.owner];token=status.token end
        else p,token=self:Resolve(source) end
        if not p then return false end
        token=token or scoped(p)
        return self:IsRestricted(p) and token==nil
    end
    function gate:StatusApplied(target,source,kind)
        if not (kind and kind>=1 and kind<=3) then return end
        local p,token=self:Resolve(source)
        local k=entityKey(target);self.statuses[k]=self.statuses[k] or {}
        self.statuses[k][kind]=p and {owner=key(p),token=token or scoped(p)} or false
    end
    function gate:CopyStatus(from,to,overwrite)
        local record=self.statuses[entityKey(from)] or {};local k=entityKey(to);self.statuses[k]=self.statuses[k] or {}
        for kind,method in ipairs({'GetPoisonDamage','GetBurnDamage','GetBleedingCountdown'}) do
            if overwrite or from[method] and from[method](from)~=0 then self.statuses[k][kind]=record[kind] or false end
        end
    end
    function gate:ForgetEntity(e) self.statuses[entityKey(e)]=nil end
    function gate:Reset()
        self.players={};self.owned={};self.issued={};self.stack={};self.statuses={}
    end
    return gate
end
return S
