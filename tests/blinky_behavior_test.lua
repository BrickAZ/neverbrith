-- Callback-level fixture: native calls are recorded, never treated as game acceptance.
local function fixture()
    local V={};V.__index=V
    function Vector(x,y)return setmetatable({X=x,Y=y},V)end
    function V.__add(a,b)return Vector(a.X+b.X,a.Y+b.Y)end
    function V.__sub(a,b)return Vector(a.X-b.X,a.Y-b.Y)end
    function V.__mul(a,b)if type(a)=='number'then a,b=b,a end;return Vector(a.X*b,a.Y*b)end
    function V:Length()return math.sqrt(self.X*self.X+self.Y*self.Y)end
    function V:Resized(n)local l=self:Length();return l==0 and Vector(0,0)or self*(n/l)end
    function V:Rotated(a)a=math.rad(a);return Vector(self.X*math.cos(a)-self.Y*math.sin(a),self.X*math.sin(a)+self.Y*math.cos(a))end
    function V:GetAngleDegrees()return math.deg(math.atan(self.Y,self.X))end
    Vector= setmetatable({}, {__call=function(_,x,y)return setmetatable({X=x,Y=y},V)end});Vector.Zero=Vector(0,0)
    ModCallbacks={MC_USE_ITEM=1,MC_POST_UPDATE=2,MC_POST_NEW_ROOM=3,MC_POST_GAME_STARTED=4,
        MC_PRE_GAME_EXIT=5,MC_ENTITY_TAKE_DMG=6,MC_POST_NPC_DEATH=7,MC_POST_RENDER=8,
        MC_INPUT_ACTION=9,MC_PRE_PICKUP_COLLISION=10,MC_PRE_USE_ITEM=11,MC_POST_GLOWING_HOURGLASS_LOAD=12}
    ButtonAction={ACTION_ITEM=9,ACTION_PILLCARD=10,ACTION_DROP=11};InputHook={IS_ACTION_PRESSED=0,IS_ACTION_TRIGGERED=1,GET_ACTION_VALUE=2}
    EntityType={ENTITY_PICKUP=5,ENTITY_EFFECT=1000,ENTITY_FIREPLACE=33,ENTITY_SHOPKEEPER=17,ENTITY_TEAR=2,
        ENTITY_MOVABLE_TNT=292,ENTITY_POOP=245}
    GridEntityType={GRID_ROCK=2,GRID_ROCKB=3,GRID_ROCKT=4,GRID_ROCK_BOMB=5,GRID_ROCK_ALT=6,
        GRID_PIT=7,GRID_SPIKES=8,GRID_SPIKES_ONOFF=9,GRID_ROCK_SS=22,GRID_POOP=14,GRID_TNT=12}
    TearVariant={BLUE=0,NAIL=13};TearFlags={TEAR_NORMAL=0,TEAR_KNOCKBACK=1<<24};EffectVariant={RED_CANDLE_FLAME=52}
    EntityFlag={FLAG_FRIENDLY=1};DamageFlag={DAMAGE_EXPLOSION=4};Direction={LEFT=0,UP=1,RIGHT=2,DOWN=3}
    UseFlag={USE_CARBATTERY=1};Color=setmetatable({Default={}}, {__call=function()return{}end})
    PickupVariant={PICKUP_ETERNALCHEST=53,PICKUP_BED=380,PICKUP_TROPHY=370,PICKUP_BIGCHEST=340}
    ChestSubType={CHEST_OPENED=0,CHEST_CLOSED=1}
    function EntityRef(e)return{Entity=e}end
    function Sprite()return{Load=function()end,Play=function()end,SetFrame=function()end,
        ReplaceSpritesheet=function()end,LoadGraphics=function()end,
        RenderLayer=function()end,
        Update=function()end,Render=function()end,GetFilename=function()return'gfx/005.010_heart.anm2'end,
        GetAnimation=function()return'Idle'end,GetFrame=function()return 0 end}end
    local f={root={},entities={},grids={},pressed={},frame=0,roomKey='room1',spawned={},saves=0,callbacks={}}
    function f:call(id,... )local result;for _,c in ipairs(self.callbacks[id]or{})do result=c.fn(nil,...)or result end;return result end
    local room={GetGridSize=function()return 12 end,GetGridEntity=function(_,i)return f.grids[i]end,
        RemoveGridEntity=function(_,i)f.grids[i]=nil end,GetGridPosition=function(_,i)return Vector(i*20,0)end,
        GetGridCollisionAtPos=function()return 0 end,IsPositionInRoom=function()return true end,
        FindFreePickupSpawnPosition=function(_,p)return p end}
    local game={GetRoom=function()return room end,GetFrameCount=function()return f.frame end,IsPaused=function()return false end,
        BombExplosionEffects=function(_,_,damage)f.bombDamage=damage end}
    function Game()return game end
    function f:entity(t,v,s,x)
        local e={Type=t,Variant=v,SubType=s,InitSeed=100+#self.entities,Position=Vector(x or 60,0),Velocity=Vector(0,0),
            Price=0,Charge=0,ShopItemId=-1,OptionsPickupIndex=0,State=0,Size=10,HitPoints=40,MaxHitPoints=40,data={}}
        function e:GetData()return self.data end;function e:GetSprite()return Sprite()end
        function e:Exists()return not self.removed end;function e:IsDead()return self.HitPoints<=0 end
        function e:Remove()self.removed=true end;function e:ToPickup()return self.Type==5 and self or nil end
        function e:ToNPC()return self.Type>=10 and self.Type<1000 and self or nil end
        function e:ToEffect()return self.Type==1000 and self or nil end
        function e:ToTear()return self.Type==2 and self or nil end
        function e:IsVulnerableEnemy()return self.Type==10 end;function e:IsActiveEnemy()return self.Type==10 end
        function e:HasEntityFlags()return false end
        function e:TakeDamage(d,flags,source)
            f:call(ModCallbacks.MC_ENTITY_TAKE_DMG,self,d,flags,source,0)
            if self.cancel then return false end;self.HitPoints=self.HitPoints-d
            if self:IsDead()then f:call(ModCallbacks.MC_POST_NPC_DEATH,self)end;return true
        end
        function e:TryOpenChest()self.opens=(self.opens or 0)+1;self.State=1;self.SubType=0;return true end
        if self.nativeThrow then
            function e:TryThrow()self.pendingThrow=true;return true end
        end
        function e:ChangeVariant(vv)self.Variant=vv end;function e:AddTearFlags(flags)self.TearFlags=flags end
        function e:Morph(t,v,s,price,seed,ignore)
            self.Type=t;self.Variant=v;self.SubType=s;self.ignoreModifiers=ignore
        end
        self.entities[#self.entities+1]=e;return e
    end
    function game:Spawn(t,v,p,vel,owner,s,seed)
        assert(getmetatable(p)==V and getmetatable(vel)==V,'engine vectors must come from Vector constructor')
        if f.failSpawn then return nil end
        local e=f:entity(t,v,s,p.X);e.Position=p;e.Velocity=vel;e.SpawnerEntity=owner;e.InitSeed=seed
        f.spawned[#f.spawned+1]=e;return e
    end
    Isaac={GetRoomEntities=function()local out={};for _,e in ipairs(f.entities)do if e:Exists()then out[#out+1]=e end end;return out end,
        Spawn=function(t,v,s,p,vel,o)return game:Spawn(t,v,p,vel,o,s,900+#f.spawned)end,
        GetEntityVariantByName=function()return 3025 end,WorldToScreen=function(p)return p end,
        GetItemConfig=function()return{GetCollectible=function()return{Name='Item',GfxFileName='item.png'}end}end}
    Input={IsActionPressed=function(a)return f.pressed[a]or false end,GetActionValue=function(a)return f.pressed[a]and 1 or 0 end}
    local p=f:entity(1,0,0,0);p.InitSeed=1;p.ControllerIndex=0;p.Damage=10;p.TearRange=260;p.ShotSpeed=1
    function p:GetHeadDirection()return 2 end;function p:GetActiveItem()return 99 end
    function p:IsDead()return false end;function p:GetCollectibleRNG()return{RandomFloat=function()return .5 end}end
    function p:FireTear(pos,vel)return game:Spawn(2,0,pos,vel,self,0,990+#f.spawned)end
    local mod={AddCallback=function(_,id,fn,param)f.callbacks[id]=f.callbacks[id]or{};f.callbacks[id][#f.callbacks[id]+1]={fn=fn,param=param}end,
        GetRuntimeLocale=function()return'en_us'end}
    mod.PendingContentState={InventoryPlayerKey=function()return'player'end,RoomKey=function()return f.roomKey end}
    mod.InventorySelector={IsBlocking=function()return f.blocking or false end,
        Open=function(_,request)f.request=request;f.blocking=true;return true end}
    function include(name)return assert(loadfile(name..'.lua'))()end
    f.api=assert(loadfile('blinky.lua'))()(mod,{ItemId=99,GetSaveRoot=function()return f.root end,
        GetCurrentRunSeed=function()return 123 end,GetPlayers=function()return{p}end,Save=function()f.saves=f.saves+1 end})
    f.p=p;f.mod=mod;f.room=room
    function f:tick(n)for _=1,n or 1 do
        self.frame=self.frame+1
        for _,e in ipairs(self.entities)do if e.pendingThrow then e.pendingThrow=nil;e.SubType=0;e.opens=(e.opens or 0)+1 end end
        self:call(2)
    end end
    function f:use(ctrl)self.pressed[9]=true;self.pressed[11]=ctrl;return self:call(1,99,{},p,0,0,0)end
    function f:list()return f.api.GetEntries(p)end
    function f:grid(i,t,v)local g={State=0,Position=Vector(i*20,0),desc={Type=t,Variant=v or 0,SpawnSeed=i},sprite=Sprite()}
        function g:GetType()return self.desc.Type end;function g:GetVariant()return self.desc.Variant end
        function g:GetSprite()return self.sprite end;function g:Destroy()self.destroyed=true;self.State=2 end
        self.grids[i]=g;return g
    end
    return f
end
local function eq(a,b,m)assert(a==b,(m or'')..' expected '..tostring(b)..', got '..tostring(a))end
local tests={}
function tests.absorb_instances_price_options_and_grid_exclusions()
    local f=fixture();local a=f:entity(5,100,25,80);a.Price=-2;a.Charge=4;a.OptionsPickupIndex=7
    local b=f:entity(5,100,26,100);b.Price=15;b.OptionsPickupIndex=7
    local rock=f:grid(2,2);local x=f:grid(3,4);local giant=f:grid(4,14,7)
    f:use();f:tick();eq(#f:list(),3);eq(a.removed,true);eq(b.removed,true);eq(rock==f.grids[2],false)
    eq(x.destroyed,true);eq(giant==f.grids[4],true)
    local seen={};for _,e in ipairs(f:list())do if e.kind=='pickup'then seen[e.subtype]=e end end
    eq(seen[25].price,-2);eq(seen[25].charge,4);eq(seen[26].price,15)
end
function tests.melee_once_then_suction_only_kill_reward()
    local f=fixture();local e=f:entity(10,0,0,25);e.HitPoints=8
    f:use();eq(e.HitPoints,6);f:tick(14);eq(e.HitPoints,6);f:tick();eq(e.HitPoints,1)
    f:tick(15);eq(#f:list(),1);eq(f:list()[1].variant,10);eq(f:list()[1].subtype,1)
    f:call(7,e);eq(#f:list(),1,'reward deduplicated')
end
function tests.other_kill_and_canceled_damage_never_reward()
    local f=fixture();local e=f:entity(10,0,0,25);f:use();f:tick(15);e:TakeDamage(100,0,EntityRef(f.p));eq(#f:list(),0)
    local g=fixture();local n=g:entity(10,0,0,25);n.cancel=true;g:use();g:tick(30);eq(#g:list(),0);eq(n.HitPoints,40)
end
function tests.selector_confirm_and_failed_spawn_keep_inventory()
    local f=fixture();f:entity(5,100,25);f:use();f:tick();f.pressed={};f:tick();f:use(true)
    eq(type(f.request),'table');eq(f.request.confirmAction,9)
    local row=f.request.getEntries(f.p)[1];f.failSpawn=true
    eq(f.request.execute(f.p,row),false);eq(#f:list(),1)
    f.failSpawn=false;eq(f.request.execute(f.p,row),true);eq(#f:list(),0)
    f:tick(40);local pickup=f.spawned[#f.spawned];eq(pickup.Type,5);eq(pickup.OptionsPickupIndex,0)
end
function tests.boundaries_continue_hourglass_and_new_run()
    local f=fixture();f:entity(5,20,1);f:use();f:tick();f.pressed={};f:tick()
    local uid=f:list()[1].uid;eq(f.api.Spit(f.p,uid),true);eq(#f:list(),0)
    f.roomKey='room2';f:call(3);eq(#f:list(),1,'in-flight object returned before crossing boundary')
    f:call(4,true);eq(#f:list(),1,'continue');f.root.pendingContent={};eq(#f:list(),1,'hourglass independent')
    f:call(4,false);eq(#f:list(),0,'new run resets even repeated seed')
end
function tests.open_chest_shopkeeper_and_flame()
    local f=fixture();local c=f:entity(5,50,0);c.State=1;local corpse=f:entity(17,0,0,80)
    f:entity(33,2,0,100);f:use();f:tick();eq(corpse.removed,true);eq(#f:list(),2)
    local types={};for _,e in ipairs(f:list())do types[e.kind]=true end;eq(types.spentChest,true);eq(types.flame,true)
end
function tests.returned_pickups_can_be_absorbed_again_without_reroll()
    local f=fixture();local a=f:entity(5,100,25);a.Price=-2;a.Charge=4
    f:entity(5,100,0,90);f:use();f:tick();eq(#f:list(),1,'empty pedestal excluded')
    f.pressed={};f:tick();eq(f.api.Spit(f.p,f:list()[1].uid),true);f:tick(40)
    local result=f.spawned[#f.spawned];eq(result.SubType,25);eq(result.Price,-2);eq(result.Charge,4)
    eq(result.AutoUpdatePrice,false);eq(result.ignoreModifiers,true)
    f:use();f:tick();eq(result.removed,true,'released source token must be absorbable');eq(#f:list(),1)
end
function tests.holy_chest_opens_once_and_returns_as_spent_ammo()
    local f=fixture();f:entity(5,53,1);f:use();f:tick();eq(f:list()[1].kind,'chest')
    f.pressed={};f:tick();f.api.Spit(f.p,f:list()[1].uid);f:tick(40)
    local chest=f.spawned[#f.spawned];eq(chest.opens,1)
    eq(f:call(10,chest,f.p,false),true,'further player collision cannot open again')
    f:use();f:tick();eq(f:list()[1].kind,'spentChest')
    f.pressed={};f:tick();local n=#f.spawned;f.api.Spit(f.p,f:list()[1].uid);f:tick(40)
    eq(#f.spawned,n+1,'spent chest has only its flight, no reward chest');eq(#f:list(),0)
end
function tests.thrown_damage_poop_split_and_misses_consume()
    for _,kind in ipairs({'rock','poop','chest','spentChest'})do
        local f=fixture();local Core=include('blinky_core');local entry={kind=kind,variant=50,subtype=1,seed=15,
            spritePath='gfx/005.050_chest.anm2',animation='Idle'}
        local uid=Core.Add(f.root.blinky or Core.Ensure(f.root,123),'player',entry)
        local npc=f:entity(10,0,0,30)
        f.api.Spit(f.p,uid);f:tick()
        local expected=kind=='rock'and 7 or kind=='poop'and 5 or 20
        eq(npc.HitPoints,40-expected,kind..' damage')
        if kind=='poop'then
            local count=0;for _,e in ipairs(f.spawned)do if e.Type==2 then count=count+1;eq(e.CollisionDamage,2.5)end end
            eq(count,4,'four half-damage droplets')
        end
        eq(#f:list(),0)
        local miss=fixture();uid=Core.Add(Core.Ensure(miss.root,123),'player',entry)
        miss.api.Spit(miss.p,uid);miss:tick(40);eq(#miss:list(),0,kind..' misses consume')
    end
end
function tests.spikes_flame_tnt_use_native_carriers()
    local Core=include('blinky_core')
    local f=fixture();local s=Core.Ensure(f.root,123)
    f.api.Spit(f.p,Core.Add(s,'player',{kind='spikes'}));eq(#f.spawned,3)
    for _,tear in ipairs(f.spawned)do eq(tear.Variant,13);eq(tear.CollisionDamage,10);eq(tear.TearFlags,1<<24)end
    f.api.Spit(f.p,Core.Add(s,'player',{kind='flame'}));local flame=f.spawned[#f.spawned]
    eq(flame.Variant,52);eq(flame.CollisionDamage,30)
    f.api.Spit(f.p,Core.Add(s,'player',{kind='tnt',spritePath='grid_tnt.anm2'}))
    f:tick(40);eq(f.bombDamage,40)
end
function tests.transport_landing_failure_recovers_and_melee_has_one_swing()
    local f=fixture();f:entity(5,20,1);f:use();f:tick();f.pressed={};f:tick()
    f.api.Spit(f.p,f:list()[1].uid);f.failSpawn=true;f:tick(40);eq(#f:list(),1,'failed landing returns object')
    local g=fixture();g:entity(10,0,0,25);local pickup=g:entity(5,20,1)
    g:use();g:tick(9);eq(pickup.removed,nil,'swing finishes before suction')
    g:use();g:tick();eq(pickup.removed,true);eq(g.entities[2].HitPoints,38,'held active callback cannot repeat melee')
end
function tests.schoolbag_ctrl_swap_does_not_activate_the_other_item()
    local f=fixture();local Core=include('blinky_core')
    Core.Add(Core.Ensure(f.root,123),'player',{kind='rock'})
    function f.p:GetActiveItem(slot)return slot==1 and 99 or 55 end
    f.pressed[11]=true;f.pressed[9]=true
    eq(f:call(11,55,{},f.p,0,0,0),true,'intercept primary after native Ctrl swap')
    eq(type(f.request),'table');eq(f.request.valid(f.p),true)
end
function tests.melee_matches_native_swing_side_arc()
    local f=fixture();local side=f:entity(10,0,0,0);side.Position=Vector(0,25)
    f:use();eq(side.HitPoints,38,'native jawbone swing side arc')
    f:use();eq(side.HitPoints,38,'one hit per held swing')
end
function tests.deferred_native_holy_open_survives_changed_subtype_and_continue()
    local f=fixture();f.nativeThrow=true;f:entity(5,53,1);f:use();f:tick();f.pressed={};f:tick()
    f.api.Spit(f.p,f:list()[1].uid);f:tick(40)
    local chest=f.spawned[#f.spawned];eq(chest.SubType,0);eq(chest.opens,1)
    chest.data={};f:call(4,true)
    eq(f:call(10,chest,f.p,false),true,'persistent identity excludes mutable chest subtype')
end
function tests.hourglass_restores_no_bag_and_reconciles_late_native_sources()
    local f=fixture();local original=f:entity(5,20,1);f:use();f:tick();f.pressed={};f:tick()
    f:call(12,0);original.removed=nil;f:tick()
    eq(original.removed,true,'native source replay removed after hourglass load');eq(#f:list(),1)
    f:call(8);eq(#f:list(),1,'render is read-only')
end
local names={};for n in pairs(tests)do names[#names+1]=n end;table.sort(names)
for _,name in ipairs(names)do tests[name]();print('PASS '..name)end
print('blinky_behavior_test: '..#names..' cases passed')
