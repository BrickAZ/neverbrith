-- Deterministic providers around the real factory, usable with frozen old/new roots.
return function()
    dofile('tests/support/neverbirth_fixture.lua')()
    local f = { root = {}, seed = 'DOG-13', players = {}, saves = {}, effects = {}, enemies = {}, sounds = {}, registrations = {} }
    local function copy(value)
        if type(value) ~= 'table' then return value end
        local out = {}; for k,v in pairs(value) do out[k] = copy(v) end; return out
    end
    f.copy = copy
    Vector = function(x,y) return {X=x or 0,Y=y or 0} end
    EntityRef = function(entity) return {Entity=entity} end
    function f.player(seed)
        local p={InitSeed=seed,Position=Vector(100,100),Damage=10,MaxFireDelay=9,collectibles={},slots={},movement=Vector(1,0)}
        function p:Exists() return not self.removed end
        function p:IsDead() return self.dead == true end
        function p:HasCollectible(id) return (self.collectibles[id] or 0)>0 end
        function p:GetCollectibleNum(id) return self.collectibles[id] or 0 end
        function p:GetActiveItem(slot) return self.slots[slot] or 0 end
        function p:GetMovementInput() return self.movement end
        function p:GetQueuedItem() return self.queued and {Item={ID=self.queued}} end
        function p:ToPlayer() return self end
        return p
    end
    function f.entity(seed,position)
        local e={InitSeed=seed,Type=10,Variant=0,SubType=0,Position=position or Vector(140,100),Velocity=Vector(0,0),MaxHitPoints=1000,HitPoints=1000,Size=0,data={},hits={}}
        local s={animation='FollowHorizontal',events={}}
        function s:IsPlaying(name) return self.animation==name end
        function s:Play(name) self.animation=name end
        function s:IsEventTriggered(name) return self.events[name]==true end
        function e:Exists() return not self.removed end
        function e:IsDead() return self.dead==true end
        function e:GetData() return self.data end
        function e:GetSprite() return s end
        function e:Remove() self.removed=true end
        function e:ToEffect() return self end
        function e:ToNPC() return self end
        function e:IsVulnerableEnemy() return not self.removed and self.vulnerable~=false end
        function e:IsActiveEnemy() return not self.removed end
        function e:HasEntityFlags() return false end
        function e:TakeDamage(amount,flags,source)
            if self.reject then return false end
            self.HitPoints=self.HitPoints-amount;self.hits[#self.hits+1]={amount=amount,owner=source.Entity.InitSeed};return true
        end
        function e:AddSlowing(_,duration,amount) self.slow={duration,amount} end
        return e
    end
    Isaac.GetSoundIdByName=function(name) return name:find('Charge',1,true) and 91 or 92 end
    SFXManager=function()return {Play=function(_,id,volume,delay,loop,pitch)f.sounds[#f.sounds+1]={id=id,pitch=pitch}end}end
    Isaac.Spawn=function(kind,variant,subtype,position,velocity,owner)
        local e=f.entity(1000+#f.effects,Vector(position.X,position.Y));e.Type=kind;e.Variant=variant;e.SubType=subtype
        e.Velocity=velocity;e.SpawnerEntity=owner;f.effects[#f.effects+1]=e;return e
    end
    Isaac.FindInRadius=function(position,radius)
        local out={};for _,e in ipairs(f.enemies)do
            if not e.removed and (e.Position.X-position.X)^2+(e.Position.Y-position.Y)^2<=radius^2 then out[#out+1]=e end
        end;return out
    end
    Isaac.GetRoomEntities=function()return f.enemies end
    ItemConfig.TAG_FOOD=8
    local mod={}
    function mod:AddCallback(event,fn,filter)f.registrations[#f.registrations+1]={event=event,fn=fn,filter=filter}end
    f.context={ItemIds={BigDogBark=780,WindChargeRod=781,EchoShard=782},
        GetPlayers=function()return f.players end,GetSaveRoot=function()return f.root end,
        GetCurrentRunSeed=function()return f.seed end,Save=function()f.saves[#f.saves+1]=copy(f.root)end,
        GetCollectibleConfig=function(id)return {ID=id,Tags=8}end}
    f.mod=mod;f.api=dofile('big_dog_bark.lua')(mod,f.context)
    function f.step(count)
        for _=1,count do
            for _,p in ipairs(f.players)do f.api.Callbacks.PostPlayerUpdate(nil,p)end
            local limit=#f.effects
            for i=1,limit do local e=f.effects[i]
                if not e.removed then
                    if e.Variant==3017 then f.api.Callbacks.UpdateDog(nil,e)
                    elseif e.Variant==3018 then f.api.Callbacks.UpdateEcho(nil,e)
                    elseif e.Variant==3019 then f.api.Callbacks.UpdateTrail(nil,e)end
                end
            end
            f.api.Callbacks.PostUpdate()
        end
    end
    return f
end
