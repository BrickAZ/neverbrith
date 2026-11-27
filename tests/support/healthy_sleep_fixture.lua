include = function(name) return dofile((name:gsub('%.', '/')) .. '.lua') end
-- Engine boundary doubles: these tests do not prove native bed/co-op behavior.
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function near(a,b,tolerance) assert(math.abs(a-b)<(tolerance or 0.000001),tostring(a)..' ~= '..tostring(b)) end
local names={'MC_POST_GAME_STARTED','MC_POST_NEW_ROOM','MC_POST_NEW_LEVEL','MC_POST_UPDATE','MC_PRE_GAME_EXIT','MC_POST_GAME_END','MC_PRE_MOD_UNLOAD','MC_PRE_PICKUP_COLLISION','MC_POST_PICKUP_COLLISION','MC_PRE_PLAYER_ADD_HEARTS','MC_PRE_PLAYER_UPDATE','MC_INPUT_ACTION','MC_POST_RENDER','MC_PRE_ITEM_OVERLAY_SHOW','MC_POST_ITEM_OVERLAY_SHOW','MC_POST_ITEM_OVERLAY_UPDATE'}
ModCallbacks={}; for i,n in ipairs(names) do ModCallbacks[n]=i end
PickupVariant={PICKUP_BED=380}; EntityType={ENTITY_PICKUP=5}; Giantbook={SLEEP=33}
AddHealthType={RED=1,SOUL=4}; InputHook={IS_ACTION_PRESSED=0,IS_ACTION_TRIGGERED=1,GET_ACTION_VALUE=2}
ButtonAction={ACTION_LEFT=0,ACTION_RIGHT=1,ACTION_UP=2,ACTION_DOWN=3,ACTION_SHOOTLEFT=4,ACTION_SHOOTRIGHT=5,ACTION_SHOOTUP=6,ACTION_SHOOTDOWN=7,ACTION_BOMB=8,ACTION_ITEM=9,ACTION_PILLCARD=10,ACTION_DROP=11,ACTION_PAUSE=12}
Vector=setmetatable({Zero={X=0,Y=0}}, {__call=function(_,x,y) return {X=x,Y=y} end})
Color=function(r,g,b,a,ro,go,bo) return {R=r,G=g,B=b,A=a,RO=ro or 0,GO=go or 0,BO=bo or 0} end
local function copy(t) if type(t)~='table' then return t end local o={} for k,v in pairs(t) do o[k]=copy(v) end return o end
local function fixture(saved, options)
    options = options or {}
    local f={root=saved or {},now=0,frame=0,floor=1,roomIndex=0,paused=false,hudVisible=true,spawnCount=0,entities={},players={},draws={}}
    local callbacks={}; local mod={}
    function mod:AddCallback(id,fn,filter) callbacks[id]=callbacks[id] or {}; table.insert(callbacks[id],{fn=fn,filter=filter}) end
    function mod:AddPriorityCallback(id,priority,fn,filter) self:AddCallback(id,fn,filter) end
    function f:call(name,...) local r; for _,cb in ipairs(callbacks[ModCallbacks[name]] or {}) do local v=cb.fn(mod,...) if v~=nil then r=v end end return r end
    local level={GetStage=function() return f.floor end,GetStageType=function() return 0 end,GetDungeonPlacementSeed=function() return 100+f.floor end,GetStartingRoomIndex=function() return 0 end,GetCurrentRoomIndex=function() return f.roomIndex end,GetDimension=function() return 0 end}
    local room={GetCenterPos=function() return Vector(320,280) end,FindFreePickupSpawnPosition=function(_,p) return p end,GetRenderMode=function() return 0 end}
    Game=function() return {GetLevel=function() return level end,GetRoom=function() return room end,GetFrameCount=function() return f.overlayPause and 0 or f.frame end,IsPaused=function() return f.paused or f.overlayPause end,IsPauseMenuOpen=function() return f.paused end,GetHUD=function() return {IsVisible=function() return f.hudVisible end} end} end
    local overlay={id=0,frame=0,event=false,playing=false,Color=Color(1,1,1,1)}
    function overlay:GetFrame() return self.frame end
    function overlay:IsPlaying() return self.playing end
    function overlay:IsEventTriggered(n) return self.event and n=='SleepFillHP' end
    function overlay:Render(p) eq(p.X,320);eq(p.Y,240);f.draws[#f.draws+1]={text='native-art',alpha=self.Color.A} end
    function overlay:SetLastFrame() self.frame=181;self.playing=false end
    ItemOverlay={GetOverlayID=function() return overlay.id end,GetSprite=function() return overlay end,GetPlayer=function() return f.players[1] end,
        GetDelay=function() return 0 end,
        Show=function(id) f:call('MC_PRE_ITEM_OVERLAY_SHOW',id,0,nil);overlay.id=id;overlay.playing=true;overlay.frame=0;f:call('MC_POST_ITEM_OVERLAY_SHOW',id,0,nil) end}; f.overlay=overlay
    Isaac={GetTime=function() return f.now end,GetFrameCount=function() return f.frame end,GetScreenWidth=function() return 640 end,GetScreenHeight=function() return 480 end,FindByType=function() local es={} for _,e in ipairs(f.entities) do if not e.removed then es[#es+1]=e end end return es end,
      Spawn=function(t,v,s,p,velocity,spawner) eq(t,5);eq(v,380);eq(s,0); f.spawnCount=f.spawnCount+1; local e={Type=t,Variant=v,SubType=s,Position=p,InitSeed=800+f.spawnCount,data={},State=0}
        function e:GetData() return self.data end; function e:ToPickup() return self end; function e:Exists() return not self.removed end;function e:Remove() self.removed=true end
        f.entities[#f.entities+1]=e;return e end}
    Input={IsActionPressed=function(a,c) local p=f.players[c+1];local binds=p.input[a] or {};return binds[1] or binds[2] or false end}
    function mod:RenderRuntimeText(_,text,x,y) f.draws[#f.draws+1]={text=text,x=x,y=y} end
    function f:addPlayer(seed,holds)
        local p={InitSeed=seed,ControllerIndex=#self.players,owned=holds,input={},Position=Vector(100,120),Velocity=Vector(0,0),hearts=2,maxHearts=6,soul=0,grants={}}
        function p:HasCollectible() return self.owned end;function p:ToPlayer() return self end;function p:IsDead() return false end
        function p:GetHearts() return self.hearts end;function p:GetEffectiveMaxHearts() return self.maxHearts end
        function p:AddHearts(n) self.grants[#self.grants+1]='red';self.hearts=math.min(self.maxHearts,self.hearts+n) end
        function p:AddSoulHearts(n) self.grants[#self.grants+1]='soul';self.soul=self.soul+n end
        local sprite={};function sprite:GetAnimation() return 'Sleep' end;function sprite:GetFrame() return 12 end;function sprite:SetFrame(a,n) self.held={a,n} end
        function p:GetSprite() return sprite end
        self.players[#self.players+1]=p;return p
    end
    local loader=loadfile(options.ModulePath or 'healthy_sleep.lua'); assert(loader,'健康睡眠生产模块尚未实现')
    f.saves={}
    loader()(mod,{ItemId=900,GetSaveRoot=function() return f.root end,Save=function() f.saved=copy(f.root);f.saves[#f.saves+1]=copy(f.root) end,GetCurrentRunSeed=function() return 'RUN' end,GetPlayers=function() return f.players end})
    f.mod=mod; f.callbacks=callbacks
    function f:tick(seconds) self.now=self.now+seconds*1000;self.frame=self.frame+1;self:call('MC_POST_UPDATE');self:call('MC_POST_ITEM_OVERLAY_UPDATE') end
    function f:contact(target)
        local bed=self.entities[#self.entities]
        eq(self:call('MC_PRE_PICKUP_COLLISION',bed,self.players[1],false),nil)
        bed.Touched=true;bed.Target=target or self.players[1]
        ItemOverlay.Show(33)
        self:call('MC_POST_PICKUP_COLLISION',bed,self.players[1],false)
    end
    function f:nativeEffect()
        self.overlay.event=true;self.overlay.frame=73
        for _,bed in ipairs(self.entities) do
            local target=bed.Target
            if target then
                if target.maxHearts>0 then target.hearts=target.maxHearts
                else target:AddSoulHearts(6) end
                bed.Target=nil
            end
        end
        self.overlay.event=false
    end
    function f:begin(recipients)
        local target=recipients and recipients[1] or self.players[1]
        local hp,soul=target.hearts,target.soul
        self:contact(target)
        -- 1.7.9b bed red-heal writes health directly; it never calls AddHearts.
        self:nativeEffect()
        eq(target.hearts,hp,'native direct full-heal must be deferred')
        eq(target.soul,soul,'native soul reward must be deferred')
        self.overlay.event=false;self.overlay.playing=false;self:tick(0)
    end
    return f
end

return fixture
