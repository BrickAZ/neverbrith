-- Engine surfaces are doubles. These tests exercise the real module callbacks,
-- not native collision cadence, shield behavior, health topology or rendering.
local function eq(a, b, why)
    assert(a == b, (why or "mismatch") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
local function fixture(saved)
    local f = { callbacks={}, frame=10, floor=1, dimension=0, index=10, seed=900,
        clear=false, enemies={}, pickups={}, players={}, spawned={}, sprites={}, sounds={}, soundLookups=0,
        saved=saved or {}, saves=0, scans=0 }
    ModCallbacks = {}
    for _, n in ipairs({"MC_USE_ITEM", "MC_POST_UPDATE", "MC_EVALUATE_CACHE", "MC_ENTITY_TAKE_DMG",
        "MC_PRE_PLAYER_TAKE_DMG", "MC_POST_ENTITY_TAKE_DMG", "MC_PRE_PLAYER_ADD_HEARTS", "MC_POST_PLAYER_ADD_HEARTS",
        "MC_PRE_PLAYER_UPDATE", "MC_POST_PLAYER_UPDATE", "MC_POST_PEFFECT_UPDATE", "MC_POST_PLAYER_INIT",
        "MC_PRE_TRIGGER_PLAYER_DEATH", "MC_POST_PICKUP_INIT", "MC_POST_PICKUP_UPDATE", "MC_PRE_PICKUP_COLLISION",
        "MC_POST_GAME_STARTED", "MC_POST_NEW_ROOM", "MC_POST_NEW_LEVEL", "MC_PRE_GAME_EXIT", "MC_POST_GAME_END",
        "MC_PRE_MOD_UNLOAD", "MC_POST_TRIGGER_COLLECTIBLE_REMOVED", "MC_POST_PLAYER_RENDER", "MC_POST_RENDER",
        "MC_POST_GRID_ENTITY_DOOR_UPDATE", "MC_POST_FIRE_TEAR"}) do ModCallbacks[n] = n end
    CallbackPriority = {IMPORTANT=-200, EARLY=-100, DEFAULT=0, LATE=100}
    EntityType = {ENTITY_PLAYER=1, ENTITY_TEAR=2, ENTITY_PICKUP=5}
    PickupVariant = {PICKUP_HEART=10, PICKUP_LOCKEDCHEST=60, PICKUP_CHEST=50, PICKUP_COIN=20}
    CacheFlag = {CACHE_DAMAGE=1, CACHE_SPEED=2, CACHE_RANGE=4, CACHE_SHOTSPEED=8, CACHE_TEARFLAG=16}
    TearFlags = {TEAR_PIERCING=2, TEAR_SPECTRAL=4}
    EntityFlag = {FLAG_FRIENDLY=1, FLAG_CHARM=2}
    AddHealthType = {RED=1, MAX=2, SOUL=4, BLACK=8, ETERNAL=16, GOLDEN=32, BONE=64, ROTTEN=128, BROKEN=256}
    DamageFlag = {DAMAGE_FAKE=1<<21, DAMAGE_RED_HEARTS=1<<5, DAMAGE_NO_MODIFIERS=1<<25, DAMAGE_INVINCIBLE=1<<13,
        DAMAGE_COUNTDOWN=1<<6, DAMAGE_FIRE=2, DAMAGE_EXPLOSION=4, DAMAGE_CURSED_DOOR=1<<16, DAMAGE_NOKILL=1}
    RoomType = {ROOM_DEFAULT=1, ROOM_BOSS=5, ROOM_SECRET=7, ROOM_DEVIL=14, ROOM_ANGEL=15}
    DoorVariant = {DOOR_UNSPECIFIED=0, DOOR_LOCKED=1, DOOR_UNLOCKED=8}
    UseFlag = {USE_CARBATTERY=1<<5}
    -- Match the installed enums.lua: POST_RENDER is outside room entity
    -- passes (NULL), not the entity NORMAL pass. The previous fake enum hid
    -- a production guard that suppressed every crown/verdict draw.
    RenderMode = {RENDER_NULL=0,RENDER_NORMAL=1,RENDER_SKIP=2,RENDER_WATER_ABOVE=3,
        RENDER_WATER_REFRACT=4,RENDER_WATER_REFLECT=5}
    local vmt = {__add=function(a,b) return Vector(a.X+b.X,a.Y+b.Y) end,
        __sub=function(a,b) return Vector(a.X-b.X,a.Y-b.Y) end}
    Vector = setmetatable({Zero=setmetatable({X=0,Y=0},vmt)}, {__call=function(_,x,y) return setmetatable({X=x,Y=y},vmt) end})
    EntityRef = function(p) return {Entity=p} end
    GetPtrHash = function(p) return p.InitSeed end
    local room = {IsClear=function() return f.clear end, GetFrameCount=function() return f.frame end,
        GetType=function() return f.roomType or 1 end, GetAliveEnemiesCount=function() return #f.enemies end,
        GetCenterPos=function() return Vector(320,280) end, FindFreePickupSpawnPosition=function(_,p) return p end,
        GetDoor=function(_,slot) return f.doors[slot] end,
        GetRenderMode=function() f.renderModeReads=(f.renderModeReads or 0)+1;return f.renderMode or RenderMode.RENDER_NULL end}
    local level = {GetStage=function() return f.floor end, GetStageType=function() return 0 end,
        GetDungeonPlacementSeed=function() return f.seed end, GetDimension=function() return f.dimension end,
        GetCurrentRoomIndex=function() return f.index end,
        GetCurrentRoomDesc=function() return {ListIndex=f.index, SafeGridIndex=f.index, SpawnSeed=f.index+100} end}
    local game = {GetFrameCount=function() return f.frame end, GetRoom=function() return room end,
        GetLevel=function() return level end, IsPaused=function() return f.paused or false end}
    Game = function() return game end
    Isaac = {GetRoomEntities=function() f.scans=f.scans+1; return f.enemies end,
        FindByType=function(_,variant) local r={} for _,p in ipairs(f.pickups) do if p.Variant==variant and not p.removed then r[#r+1]=p end end return r end,
        Spawn=function(kind,variant,subtype,position,velocity,owner)
            local p=f:pickup(variant,subtype); f.spawned[#f.spawned+1]=p; f:call("MC_POST_PICKUP_INIT",p); return p end,
        WorldToScreen=function(p) return Vector(p.X*2+7,p.Y*2+11) end,
        GetSoundIdByName=function(name)
            eq(name,"I Am a God Declaration");f.soundLookups=f.soundLookups+1
            return f.missingSound and 0 or 1771
        end}
    SFXManager=function()
        return {Play=function(_,id,volume,delay,loop,pitch)
            if f.brokenAudio then error("audio unavailable") end
            f.sounds[#f.sounds+1]={id=id,volume=volume,delay=delay,loop=loop,pitch=pitch}
        end}
    end
    Sprite = function()
        if f.brokenVisual then error("missing visual") end
        local s={age=0}
        function s:Load(path) self.path=path end
        -- HasAnimation is NOT an available native Sprite API in this build.
        function s:Play(a) self.animation=a; self.age=0 end
        function s:GetAnimation() return self.animation end
        function s:Update() self.age=self.age+1 end
        function s:IsFinished(a) return self.animation==a and self.age>=20 end
        function s:Render(position) self.rendered=position;self.draws=(self.draws or 0)+1 end
        f.sprites[#f.sprites+1]=s
        return s
    end
    function f:call(name,...)
        local result
        for _,r in ipairs(self.callbacks[name] or {}) do
            local actor=select(1,...)
            if not r.filter or (name=="MC_USE_ITEM" and r.filter==actor)
                or (type(actor)=="table" and (r.filter==actor.Type or r.filter==actor.Variant))
                or name=="MC_POST_TRIGGER_COLLECTIBLE_REMOVED" then
                local value=r.fn(self.mod,...)
                if value~=nil then result=value end
            end
        end
        return result
    end
    function f:damage(p,amount,flags)
        flags=flags or 0
        local source=EntityRef(p)
        if self:call("MC_PRE_PLAYER_TAKE_DMG",p,amount,flags,source,30)==false then return false end
        local countdown=30
        for _,r in ipairs(self.callbacks.MC_ENTITY_TAKE_DMG or {}) do
            local v=r.fn(self.mod,p,amount,flags,source,countdown)
            if v==false then return false end
            if type(v)=="table" then amount=v.Damage or amount; flags=v.DamageFlags or flags; countdown=v.DamageCountdown or countdown end
        end
        self.lastDamage={p=p,amount=amount,flags=flags,countdown=countdown}
        p.red=math.max(0,p.red-amount); p.cooldown=60
        self:call("MC_POST_ENTITY_TAKE_DMG",p,amount,flags,source,countdown)
        return true
    end
    function f:player(seed)
        local p={Type=1,Variant=0,InitSeed=seed,Position=Vector(100,100),Size=12,held=true,red=12,max=12,
            soul=0,eternal=0,bone=0,rotten=0,golden=0,cooldown=0,baseDamage=3.5,evals=0,ControlsEnabled=true}
        function p:ToPlayer() return self end
        function p:Exists() return not self.removed end
        function p:IsDead() return self.dead or false end
        function p:IsCoopGhost() return self.ghost or false end
        function p:HasMortalDamage() return self.mortal or false end
        function p:AreControlsEnabled() return self.ControlsEnabled and not self.cutscene end
        function p:HasCollectible(id) return id==991 and self.held end
        function p:ResetDamageCooldown() self.cooldown=0 end
        function p:SetMinDamageCooldown(n) self.cooldown=math.max(self.cooldown,n) end
        function p:SetDamageCountdown(n) self.countdown=n end
        function p:SetFireDamageCooldown(n) self.fireCooldown=n end
        function p:GetPlayerType() return 0 end
        function p:GetSubPlayer() return self.sub end
        function p:AddCacheFlags(flags) self.cache=flags end
        function p:EvaluateItems()
            self.evals=self.evals+1
            self.Damage,self.MoveSpeed,self.TearRange,self.ShotSpeed,self.TearFlags=self.baseDamage,1,260,1,8
            for _,flag in pairs(CacheFlag) do f:call("MC_EVALUATE_CACHE",self,flag) end
        end
        function p:TakeDamage(a,flags) return f:damage(self,a,flags) end
        for _,entry in ipairs({{"Hearts","red",1},{"MaxHearts","max",2},{"SoulHearts","soul",4},
            {"BlackHearts","soul",8},{"EternalHearts","eternal",16},{"BoneHearts","bone",64},
            {"RottenHearts","rotten",128},{"GoldenHearts","golden",32}}) do
            local suffix,key,kind=table.unpack(entry)
            p["Get"..suffix]=function(self) return self[key] end
            p["Add"..suffix]=function(self,n)
                local override=f:call("MC_PRE_PLAYER_ADD_HEARTS",self,n,kind,false)
                n=override~=nil and override or n; self[key]=math.max(0,self[key]+n)
                f:call("MC_POST_PLAYER_ADD_HEARTS",self,n,kind,false)
            end
        end
        self.players[#self.players+1]=p
        return p
    end
    function f:pickup(variant,subtype)
        local p={Type=5,Variant=variant,SubType=subtype or 1}
        function p:Remove() self.removed=true end
        function p:Exists() return not self.removed end
        self.pickups[#self.pickups+1]=p; return p
    end
    function f:enemy(friendly,invincible)
        local e={Type=10}
        function e:Exists() return true end
        function e:IsDead() return false end
        function e:IsActiveEnemy() return true end
        function e:IsVulnerableEnemy() return not invincible end
        function e:HasEntityFlags() return friendly or false end
        self.enemies[#self.enemies+1]=e; return e
    end
    function f:door(slot,targetType,open)
        local d={Slot=slot,TargetRoomIndex=20+slot,TargetRoomType=targetType,CurrentRoomType=1,open=open,State=open and 1 or 0}
        function d:GetVariant() return 0 end
        function d:IsOpen() return self.open end
        function d:IsLocked() return false end
        function d:IsBusted() return false end
        function d:Close() self.open=false end
        function d:Open() self.open=true end
        self.doors[slot]=d;return d
    end
    function f:tick(n)
        for _=1,n do
            self.frame=self.frame+1
            for _,p in ipairs(self.players) do self:call("MC_PRE_PLAYER_UPDATE",p); self:call("MC_POST_PLAYER_UPDATE",p) end
            self:call("MC_POST_UPDATE")
        end
    end
    function f:use(p) return self:call("MC_USE_ITEM",991,{},p,0,0,0) end
    f.mod={}
    function f.mod:AddPriorityCallback(id,priority,fn,filter)
        f.callbacks[id]=f.callbacks[id] or {};table.insert(f.callbacks[id],{fn=fn,priority=priority,filter=filter})
        table.sort(f.callbacks[id],function(a,b) return a.priority<b.priority end)
    end
    function f.mod:AddCallback(id,fn,filter) self:AddPriorityCallback(id,0,fn,filter) end
    f.doors={}; f:door(0,1,true); f:door(1,14,true)
    f:player(101);f:player(102);f:enemy()
    local path="i_am_a_god.lua"
    local file=io.open(path,"r"); assert(file,"I Am a God runtime module has not been implemented");file:close()
    dofile(path)(f.mod,{ItemId=991,GetPlayers=function() return f.players end,
        GetSaveRoot=function() return f.saved end,GetCurrentRunSeed=function() return 5000 end,
        Save=function() f.saves=f.saves+1 end,DebugLog=function() end})
    f:call("MC_POST_GAME_STARTED",saved~=nil)
    return f
end

local tests={}
function tests.declaration_voice_plays_once_only_on_accepted_use()
    local f=fixture();local p=f.players[1]
    f.clear=true;eq(f:use(p).Discharge,false);eq(#f.sounds,0);eq(f.soundLookups,0)
    f.clear=false
    eq(f:call("MC_USE_ITEM",991,{},p,UseFlag.USE_CARBATTERY,0,0).Discharge,false)
    eq(#f.sounds,0)
    eq(f:use(p).Discharge,true);eq(#f.sounds,1)
    local sound=f.sounds[1]
    eq(sound.id,1771);eq(sound.volume,1);eq(sound.delay,0);eq(sound.loop,false);eq(sound.pitch,1)
    eq(f:use(f.players[2]).Discharge,false);eq(#f.sounds,1)
    f:tick(180);eq(#f.sounds,1,"updates and failure verdict must not replay the voice")
    eq(f:use(p).Discharge,true);eq(#f.sounds,2);eq(f.soundLookups,1,"cache the resolved sound id")
end
function tests.missing_or_broken_voice_does_not_abort_the_item()
    for _,mode in ipairs({"missingSound","brokenAudio"}) do
        local f=fixture();f[mode]=true
        eq(f:use(f.players[1]).Discharge,true);eq(f.players[1].Damage,10.5)
        eq(#f.sounds,0)
        f.enemies={};f.clear=true;f:tick(180)
        eq(#f.spawned,1,"reward still resolves when audio is unavailable")
    end
end
function tests.invalid_use_and_duplicate_do_not_discharge()
    local f=fixture(); local p=f.players[1]
    f.clear=true;eq(f:use(p).Discharge,false)
    f.clear=false;f.enemies={};eq(f:use(p).Discharge,false)
    f:enemy(true);eq(f:use(p).Discharge,false,"friendly is not combat")
    f.enemies={};f:enemy(false,true);eq(f:use(p).Discharge,true,"invincible phase is still an enemy")
    eq(f:use(f.players[2]).Discharge,false,"team cannot overlap declarations")
end
function tests.exact_expiry_realtime_cache_and_success_once()
    local f=fixture();local p,q=table.unpack(f.players)
    eq(f:use(p).Discharge,true);eq(p.Damage,10.5);eq(p.MoveSpeed,1.3);eq(p.TearRange,420);eq(p.ShotSpeed,1.25)
    q:EvaluateItems();eq(q.Damage,3.5,"buff only owner")
    p.baseDamage=6;p:EvaluateItems();eq(p.Damage,18,"other cache contributions are live")
    f.enemies={};f.clear=true;f:tick(179);eq(#f.spawned,0);eq(p.Damage,18)
    f:tick(1);eq(#f.spawned,1);eq(f.spawned[1].Variant,60);eq(p.Damage,6)
    f:tick(30);eq(#f.spawned,1);eq(f.doors[0].open,true)
end
function tests.all_damage_sources_all_players_no_recursive_hit()
    local f=fixture();f:use(f.players[1])
    for _,p in ipairs(f.players) do
        for _,flag in ipairs({0,2,4,1<<16,1<<6}) do
            p.red=100;p.cooldown=60;f:damage(p,1,flag)
            eq(f.lastDamage.amount,2);eq(f.lastDamage.flags,flag);eq(f.lastDamage.countdown,0);eq(p.cooldown,0)
        end
    end
end
function tests.failure_hits_owner_for_four_half_hearts_and_keeps_mark()
    local f=fixture();local p,q=table.unpack(f.players);f:use(p);f:tick(180)
    eq(f.lastDamage.p,p);eq(f.lastDamage.amount,4);eq(p.red,8);eq(q.red,12);eq(p.Damage,3.5)
    eq(#f.spawned,0);p:AddHearts(2);eq(p.red,8)
end
function tests.heart_removal_and_healing_ceiling_survive_clear_reentry_and_removal()
    local f=fixture();local p,q=table.unpack(f.players)
    local h=f:pickup(10,12);local c=f:pickup(50);f:use(p);eq(h.removed,true);eq(c.removed,nil)
    for _,player in ipairs({p,q}) do
        player:AddHearts(-4);player:AddHearts(4);eq(player.red,8)
        player:AddMaxHearts(2);eq(player.max,14,"empty containers allowed")
        player:AddSoulHearts(2);eq(player.soul,0)
        player:AddBlackHearts(2);eq(player.soul,0)
        player:AddBoneHearts(1);eq(player.bone,0)
        player:AddRottenHearts(1);eq(player.rotten,0)
        player:AddEternalHearts(1);eq(player.eternal,0)
        player.red=12;f:tick(1);eq(player.red,8,"direct full-heal rolled back")
    end
    p.held=false;f:tick(1);eq(p.Damage,3.5)
    f.clear=true;f.enemies={};f:tick(1);p:AddHearts(2);eq(p.red,8)
    local h2=f:pickup(10);eq(f:call("MC_PRE_PICKUP_COLLISION",h2,p,false),true);eq(h2.removed,true)
    f.index=11;f:call("MC_POST_NEW_ROOM");p:AddHearts(2);eq(p.red,10)
    f.index=10;f:call("MC_POST_NEW_ROOM");p:AddHearts(2);eq(p.red,10)
end
function tests.dimension_floor_new_run_and_continue_isolation()
    local f=fixture();local p=f.players[1];f:use(p)
    f.dimension=1;f:call("MC_POST_NEW_ROOM");p:AddHearts(2);eq(p.red,14)
    f.dimension=0;f:call("MC_POST_NEW_ROOM");p:AddHearts(2);eq(p.red,14)
    local continued=fixture(f.saved);continued.players[1]:AddHearts(2);eq(continued.players[1].red,12)
    continued.floor=2;continued:call("MC_POST_NEW_LEVEL");continued.players[1]:AddHearts(2);eq(continued.players[1].red,14)
    f:call("MC_POST_GAME_STARTED",false);p:AddHearts(2);eq(p.red,16)
end
function tests.death_revive_exit_and_missing_visual_are_safe()
    local f=fixture();local p=f.players[1];f.brokenVisual=true;eq(f:use(p).Discharge,true)
    p.dead=true;f:tick(1);eq(p.Damage,3.5);eq(#f.spawned,0)
    p:AddHearts(2);p.dead=false;f:tick(1);local hp=p.red;p:AddHearts(2);eq(p.red,hp)
    f:call("MC_PRE_GAME_EXIT",true);p:AddHearts(2);eq(p.red,hp+2)
end
function tests.boss_phase_gap_cannot_award_a_chest()
    local f=fixture();f:use(f.players[1]);f.enemies={};f.clear=false;f:tick(180)
    eq(#f.spawned,0);eq(f.lastDamage.amount,4)
end
function tests.special_doors_are_untouched_and_cache_does_not_churn()
    local f=fixture();local p=f.players[1];f:use(p)
    eq(f.doors[0].open,false);eq(f.doors[1].open,true,"devil door is untouched")
    local scans,evals=f.scans,p.evals;f:tick(100)
    eq(f.scans,scans,"no entity scan in each update");eq(p.evals,evals,"no cache churn")
end
function tests.visuals_use_native_sprite_api_and_121_frame_overload()
    local f=fixture();local p=f.players[1];f:use(p)
    eq(#f.sprites,1);eq(f.sprites[1].animation,"Declare")
    f:tick(21);eq(f.sprites[1].animation,"Idle")
    f:tick(99);eq(f.sprites[1].animation,"Idle")
    f:tick(1);eq(f.sprites[1].animation,"Overload")
    f:call("MC_POST_RENDER");assert(f.sprites[1].rendered,"crown must actually be rendered")
    eq(f.sprites[1].rendered.X,207,"one camera conversion")
    eq(f.sprites[1].rendered.Y,175,"head anchor then camera conversion")
    f:tick(59);eq(#f.sprites,3);eq(f.sprites[2].animation,"Fail");eq(f.sprites[3].animation,"FailShatter")
end
function tests.post_render_draws_crown_and_both_verdicts_outside_entity_passes()
    for _,success in ipairs({false,true}) do
        local f=fixture();f:use(f.players[1])
        eq(RenderMode.RENDER_NULL,0);eq(RenderMode.RENDER_NORMAL,1)
        for _=1,3 do f:call("MC_POST_RENDER") end
        eq(f.sprites[1].draws,3,"global post-render draws once per invocation in RENDER_NULL")
        f:tick(121);f:call("MC_POST_RENDER")
        eq(f.sprites[1].animation,"Overload");eq(f.sprites[1].draws,4)
        if success then f.clear=true;f.enemies={} end
        f:tick(59);f:call("MC_POST_RENDER")
        eq(f.sprites[1].draws,4,"finished declaration no longer draws its crown")
        eq(f.sprites[2].draws,1,"verdict sprite reaches the actual render callback")
        if not success then eq(f.sprites[3].draws,1,"failure shatter also draws") end
        eq(f.renderModeReads,nil,"global POST_RENDER must not use entity-pass filtering")
        f:tick(31);f:call("MC_POST_RENDER")
        eq(f.sprites[2].draws,1,"expired verdict no longer draws")
    end
end
function tests.pause_duplicate_updates_and_owner_removal()
    local f=fixture();local p=f.players[1];f:use(p)
    f:tick(100);f.paused=true;f:tick(500);eq(p.Damage,10.5)
    f.paused=false;f:tick(79);eq(f.lastDamage,nil)
    f:call("MC_POST_UPDATE");eq(f.lastDamage,nil,"same frame cannot advance twice")
    p.held=false;f:call("MC_POST_TRIGGER_COLLECTIBLE_REMOVED",p,991);eq(p.Damage,3.5)
    f:tick(50);eq(f.lastDamage,nil,"cancelled declaration never settles")
end
function tests.reviving_player_rebases_then_cannot_heal_again()
    local f=fixture();local p=f.players[2];f:use(f.players[1])
    p.dead=true;p.red=0;eq(f:call("MC_PRE_TRIGGER_PLAYER_DEATH",p),nil)
    p.dead=false;p:AddHearts(6);eq(p.red,6,"native revival health survives")
    f:call("MC_POST_PLAYER_UPDATE",p);p:AddHearts(6);eq(p.red,6,"revival does not disable later prohibition")
end
function tests.coop_join_and_forgotten_inactive_body_are_protected()
    local f=fixture();f:use(f.players[1]);local p=f:player(103)
    p:AddHearts(2);eq(p.red,12);p.cooldown=60;f:damage(p,1);eq(f.lastDamage.amount,2)
    local sub=f:player(104);table.remove(f.players);f.players[2].sub=sub
    f:tick(1);sub.red=16;f:tick(1);eq(sub.red,12,"inactive health body is also reconciled")
end
function tests.pickup_init_and_health_before_new_room_cannot_use_stale_mark()
    local f=fixture();local p=f.players[1];f:use(p)
    f.index=11
    local safe=f:pickup(10);f:call("MC_POST_PICKUP_INIT",safe)
    eq(safe.removed,nil,"destination pickup init precedes new room callback")
    p:AddHearts(2);eq(p.red,14,"unmarked destination allows healing before new room")
    f:call("MC_POST_NEW_ROOM")
    f.index=10
    local banned=f:pickup(10);f:call("MC_POST_PICKUP_INIT",banned)
    eq(banned.removed,true,"marked destination blocks pickup init before new room")
    p:AddHearts(2);eq(p.red,14)
end
function tests.separate_userdata_wrappers_share_player_identity()
    local f=fixture();local p=f.players[1];f:use(p)
    local wrapper=setmetatable({}, {__index=p,__newindex=function(_,k,v) p[k]=v end})
    p.Damage=3.5;f:call("MC_EVALUATE_CACHE",wrapper,CacheFlag.CACHE_DAMAGE)
    eq(p.Damage,10.5,"cache callback receives a new wrapper for the same native player")
    p.red=16;f:call("MC_POST_PLAYER_UPDATE",wrapper);eq(p.red,12,"wrapper must not reset healing ceiling")
    p.held=false;f:call("MC_POST_TRIGGER_COLLECTIBLE_REMOVED",wrapper,991)
    eq(p.Damage,3.5,"inventory event identifies same owner by pointer and seed")
end
function tests.unsafe_states_never_discharge_or_mark_a_room()
    local f=fixture();local p=f.players[1]
    p.ControlsEnabled=false;eq(f:use(p).Discharge,false)
    p.ControlsEnabled=true;p.cutscene=true;eq(f:use(p).Discharge,false)
    p.cutscene=false;p.dead=true;eq(f:use(p).Discharge,false)
    p.dead=false;p.mortal=true;eq(f:use(p).Discharge,false)
    p.mortal=false;p.ghost=true;eq(f:use(p).Discharge,false)
    p.ghost=false;f.paused=true;eq(f:use(p).Discharge,false)
    f.paused=false;eq(f:call("MC_USE_ITEM",991,{},p,UseFlag.USE_CARBATTERY,0,0).Discharge,false)
    f:call("MC_POST_GAME_END");eq(f:use(p).Discharge,false)
    eq(f.saved.iAmAGod.rooms[next(f.saved.iAmAGod.rooms)],nil,"no permanent penalty from an invalid use")
end
function tests.temporary_tears_and_buffs_clean_up_at_lifecycle_boundaries()
    for _,event in ipairs({"success","failure","MC_PRE_TRIGGER_PLAYER_DEATH","MC_POST_NEW_ROOM",
        "MC_POST_NEW_LEVEL","MC_POST_GAME_STARTED","MC_PRE_GAME_EXIT","MC_POST_GAME_END","MC_PRE_MOD_UNLOAD"}) do
        local f=fixture();local p=f.players[1];f:use(p)
        local wrapper=setmetatable({}, {__index=p,__newindex=function(_,k,v) p[k]=v end})
        local tear={SpawnerEntity=wrapper,TearFlags=p.TearFlags}
        function tear:Exists() return true end
        function tear:AddTearFlags(bits) self.TearFlags=self.TearFlags|bits end
        function tear:ClearTearFlags(bits) self.TearFlags=self.TearFlags & ~bits end
        f:call("MC_POST_FIRE_TEAR",tear);eq(tear.TearFlags,14)
        if event=="success" then f.clear=true;f.enemies={};f:tick(180)
        elseif event=="failure" then f:tick(180)
        elseif event=="MC_PRE_TRIGGER_PLAYER_DEATH" then f:call(event,wrapper)
        elseif event=="MC_PRE_MOD_UNLOAD" then f:call(event,f.mod)
        elseif event=="MC_POST_GAME_STARTED" then f:call(event,false)
        elseif event=="MC_POST_NEW_ROOM" then f.index=11;f:call(event)
        elseif event=="MC_POST_NEW_LEVEL" then f.floor=2;f:call(event)
        else f:call(event) end
        eq(p.Damage,3.5,event.." removes owner buff");eq(p.TearFlags,8,event.." removes cached flags")
        eq(tear.TearFlags,8,event.." removes temporary flags from surviving tears")
    end
end
function tests.installed_repentogon_dispatcher_preserves_damage_chain_and_cancellation()
    local file=io.open("../../resources/scripts/main_ex.lua","r")
    if not file then print("SKIP installed REPENTOGON dispatcher unavailable");return end
    local source=file:read("*a");file:close()
    local begin=assert(source:find("function _RunEntityTakeDmgCallback",1,true))
    local finish=assert(source:find("-- Custom handling for MC_PRE_TRIGGER_PLAYER_DEATH",begin,true))
    local f=fixture();local p=f.players[1];f:use(p)
    local env=setmetatable({GetCallbackIterator=function(id)
        local i=0;return function() i=i+1;return (f.callbacks[id] or {})[i] end
    end,RunCallbackInternal=function(_,record,...) return record.fn(f.mod,...) end},{__index=_G})
    assert(load(source:sub(begin,finish-1),"installed REPENTOGON damage dispatcher","t",env))()
    local function dispatch(player,amount,flags)
        return env._RunEntityTakeDmgCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,1,player,amount,flags,
            EntityRef(setmetatable({}, {__index=p})),30)
    end
    -- Existing ACE/ring-style early modifiers precede our multiplier, while
    -- later lethal guards see the doubled amount through the real dispatcher.
    f.mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,-100,function(_,_,amount) return {Damage=amount*3} end)
    local observed
    f.mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,0,function(_,_,amount) observed=amount end)
    local ret=dispatch(p,1,DamageFlag.DAMAGE_EXPLOSION)
    eq(ret.Damage,6);eq(observed,6);eq(ret.DamageCountdown,0)
    function p:TakeDamage(amount,flags)
        local wrapper=setmetatable({}, {__index=self})
        local verdict=dispatch(wrapper,amount,flags)
        f.verdict=verdict;return verdict~=false
    end
    f:tick(180);eq(f.verdict.Damage,4,"judgment stays four half-hearts after early modifiers and wrapper changes")
    f.mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,-200,function() return false end)
    observed=nil;eq(dispatch(p,2,0),false);eq(observed,nil,"native cancellation is retained")
end
local count=0
for name,test in pairs(tests) do test();count=count+1;print("PASS "..name) end
print("I Am a God behavior tests passed: "..count)
