-- Deterministic two-item integration surface. Real factories and registered
-- callbacks run here; native entities, room transitions and persistence are fake.
return function()
    local e = { seed = 'ARCHIVE-SEED', frame = 1, roomIndex = 10, dimension = 2,
        rooms = {}, entities = {}, players = {}, transitions = {}, logs = {}, saves = {},
        root = { unrelated = { keep = 17 } }, nextEntity = 100, failTransition = false }
    function include(name) return dofile(name:gsub('%.', '/') .. '.lua') end
    ModCallbacks = { MC_USE_ITEM=1, MC_POST_NEW_ROOM=2, MC_PRE_PICKUP_COLLISION=3,
        MC_POST_UPDATE=4, MC_POST_GAME_STARTED=5, MC_PRE_GAME_EXIT=6,
        MC_PRE_MOD_UNLOAD=7, MC_POST_PICKUP_UPDATE=8 }
    EntityType={ENTITY_PICKUP=5,ENTITY_EFFECT=1000}; PickupVariant={PICKUP_COLLECTIBLE=100}
    CollectibleType={COLLECTIBLE_BREAKFAST=25}; ItemType={ITEM_ACTIVE=3}
    EntityCollisionClass={ENTCOLL_NONE=0}; GridCollisionClass={COLLISION_NONE=0}
    GridRooms={ROOM_DEBUG_IDX=-3}; Direction={NO_DIRECTION=-1}; RoomTransitionAnim={TELEPORT=3}
    local function vector(x,y) return {X=x or 0,Y=y or 0,nativeVector=true} end
    local function clone(value)
        if type(value)~='table' then
            assert(type(value)=='nil' or type(value)=='number' or type(value)=='string' or type(value)=='boolean','non-serializable save value')
            return value
        end
        local result={}; for k,v in pairs(value)do result[k]=clone(v)end; return result
    end
    e.clone=clone
    e.mod={callbacks={}}
    function e.mod:AddCallback(event,fn,filter)
        self.callbacks[#self.callbacks+1]={event=event,fn=fn,filter=filter}
    end
    local ids={}
    for _,row in ipairs(dofile('generated/neverbirth_collectibles.lua'))do
        for _,name in ipairs(row.names or {row.englishName})do ids[name]=1000+row.localId end
    end
    e.ids={CertificateOfNeverbirth=ids['Certificate of Neverbirth'],HouseVsElephant=ids['House VS Elephant']}
    local descriptors={}
    local function descriptor(index,dimension)
        local key=index..':'..dimension
        descriptors[key]=descriptors[key] or {SafeGridIndex=index,GridIndex=index,identity=key}
        return descriptors[key]
    end
    e.level={GetCurrentRoomIndex=function()return e.roomIndex end,
        GetCurrentRoomDesc=function()return descriptor(e.roomIndex,e.dimension)end,
        GetRoomByIdx=function(_,index,dimension)return descriptor(index,dimension)end,
        GetStage=function()return 1 end,GetStageType=function()return 0 end}
    e.room={GetTopLeftPos=function()return vector(40,120)end,
        GetBottomRightPos=function()return vector(600,440)end,
        IsPositionInRoom=function(_,position)return not e.rejectPositions and position.nativeVector==true end,
        SetClear=function(_,v)e.clear=v end}
    e.game={GetLevel=function()return e.level end,GetRoom=function()return e.room end,
        GetFrameCount=function()return e.frame end,
        StartRoomTransition=function(_,index,_,_,player,dimension)
            e.transitions[#e.transitions+1]={index=index,dimension=dimension,player=player.InitSeed}
            if e.failTransition then return false end
        end}
    function e:spawn(kind,variant,subtype,position)
        assert(position.nativeVector,'engine API must receive a Vector')
        self.nextEntity=self.nextEntity+1
        local entity={Type=kind,Variant=variant,SubType=subtype,InitSeed=self.nextEntity,
            Position=position,exists=true,data={},sprite={}}
        function entity:GetData()return self.data end
        function entity:Exists()return self.exists end
        function entity:Remove()self.exists=false end
        function entity:GetSprite()return self.sprite end
        function entity.sprite:HasAnimation()return not e.missingAnimation end
        function entity.sprite:Play(name) if e.failPlay then error('play failed')end; self.animation=name end
        self.entities[#self.entities+1]=entity
        return entity
    end
    local isaac={GetItemIdByName=function(name)return ids[name] or -1 end,
        GetEntityVariantByName=function()return e.variant or 3016 end,
        GetRoomEntities=function()local r={};for _,v in ipairs(e.entities)do if v.exists then r[#r+1]=v end end;return r end,
        GetItemConfig=function()return {GetCollectible=function(_,id)return {Type=id==402 and 3 or 1}end}end,
        Spawn=function(kind,variant,subtype,position,velocity)
            assert(velocity.nativeVector,'velocity must be Vector')
            if e.failSpawn and kind==1000 then error('spawn failed')end
            return e:spawn(kind,variant,subtype,position)
        end,
        ExecuteCommand=function(command)
            assert(command=='goto s.default.2')
            if e.failCommand then error('goto failed')end
            e:arrive(-3,0,true)
        end}
    function e:activate()
        Vector=vector; Game=function()return self.game end; Isaac=isaac
        GetPtrHash=function(value)return value and value.identity end
    end
    function e:emit(event,...)
        self:activate()
        for _,r in ipairs(self.mod.callbacks)do if r.event==event then r.fn(self.mod,...)end end
    end
    function e:arrive(index,dimension,fresh)
        self.rooms[self.roomIndex..':'..self.dimension]=self.entities
        self.roomIndex,self.dimension=index,dimension
        self.entities=not fresh and self.rooms[index..':'..dimension] or {}
        if not self.entities then self.entities={}end
        self:emit(ModCallbacks.MC_POST_NEW_ROOM)
    end
    function e:advance(frames)
        for _=1,frames do self.frame=self.frame+1;self:emit(ModCallbacks.MC_POST_UPDATE)end
    end
    function e:park()
        for i,p in ipairs(self.players)do p.Position=vector(120+i*30,180)end
    end
    function e:controls(owner,role)
        local r={};local marker=owner=='certificate' and 'NeverbirthCertificateGalleryPortal' or 'NeverbirthHouseGalleryControl'
        local roleKey=owner=='certificate' and 'NeverbirthCertificatePortalRole' or 'NeverbirthHouseControlRole'
        for _,entity in ipairs(self.entities)do
            if entity.exists and entity.data[marker] and (not role or entity.data[roleKey]==role)then r[#r+1]=entity end
        end
        return r
    end
    function e:pedestals(owner)
        local r={};local marker=owner=='certificate' and 'NeverbirthCertificateSessionToken' or 'NeverbirthHouseSessionToken'
        for _,entity in ipairs(self.entities)do
            if entity.exists and entity.Type==5 and entity.Variant==100 and entity.data[marker] then r[#r+1]=entity end
        end
        return r
    end
    function e:press(owner,role)
        self:park();self:advance(11)
        local control=assert(self:controls(owner,role)[1],'missing control '..owner..':'..role)
        self.players[1].Position=control.Position
        self:advance(1);self:park();self:advance(role=='return' and 13 or 10)
    end
    function e:use(owner)
        self:activate()
        local api=owner=='certificate' and self.cert or self.house
        return api.Callbacks.UseItem(self.mod,api.GetItemId(),nil,self.players[1],0,0,0)
    end
    function e:section(name)
        return {Get=function()return self.root[name]end,Replace=function(v)self.root[name]=v end,
            Save=function()self.saves[#self.saves+1]=clone(self.root)end}
    end
    for i=1,3 do
        local p={InitSeed=i,Position=vector(120+i*30,180),counts={}}
        function p:ToPlayer()return self end
        function p:GetCollectibleNum(id)return self.counts[id] or 0 end
        function p:HasCollectible(id)return self:GetCollectibleNum(id)>0 end
        e.players[i]=p
    end
    e:activate()
    e.carriers = {}
    for _,item in ipairs({'certificate_of_neverbirth','house_vs_elephant'})do
        local section=item=='certificate_of_neverbirth' and 'certificateOfNeverbirth' or 'houseVsElephant'
        local owner=item=='certificate_of_neverbirth' and 'certificate' or 'house'
        e.carriers[owner]=include('scripts.features.'..item)(e.mod,{Store=e:section(section),Items=e.ids,
            GetPlayers=function()return e.players end,GetCurrentRunSeed=function()return e.seed end,
            GetHouseCarrier=function()return e.carriers.house end,
            GetCertificateCarrier=function()return e.carriers.certificate end,
            Log=function(message)e.logs[#e.logs+1]=message end})
    end
    e.cert=e.mod.CertificateOfNeverbirthTestAPI;e.house=e.mod.HouseVsElephantTestAPI
    e:emit(ModCallbacks.MC_POST_GAME_STARTED,false)
    return e
end
