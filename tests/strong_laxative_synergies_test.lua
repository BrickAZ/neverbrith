-- Native parameter generation is an external engine boundary, not emulated AI.
local function eq(a,b) assert(a==b, "expected "..tostring(b)..", got "..tostring(a)) end
local function near(a,b) assert(math.abs(a-b)<0.00001, tostring(a).." ~= "..tostring(b)) end
local mt={}
local function bits(lo,hi) return setmetatable({lo=lo or 0,hi=hi or 0},mt) end
mt.__band=function(a,b) return bits(a.lo & b.lo,a.hi & b.hi) end
mt.__bor=function(a,b) return bits(a.lo | b.lo,a.hi | b.hi) end
mt.__eq=function(a,b) return a.lo==b.lo and a.hi==b.hi end
TearFlags={TEAR_NORMAL=bits(),TEAR_HOMING=bits(4),TEAR_POISON=bits(16),TEAR_FREEZE=bits(32),
    TEAR_CHARM=bits(64),TEAR_FEAR=bits(128),TEAR_SHRINK=bits(256),TEAR_BURN=bits(512),
    TEAR_GLOW=bits(1024),TEAR_EXPLOSIVE=bits(2048),TEAR_GROW=bits(4096),TEAR_ACID=bits(8192),
    TEAR_SLOW=bits(16384),TEAR_ICE=bits(0,2),TEAR_BAIT=bits(0,8),TEAR_TURN_HORIZONTAL=bits(0,128)}
EntityFlag={FLAG_FRIENDLY=2,FLAG_CHARM=4}
WeaponType={WEAPON_TEARS=1}
CollectibleType={COLLECTIBLE_IPECAC=149,COLLECTIBLE_PROPTOSIS=261,
    COLLECTIBLE_FIRE_MIND=257,COLLECTIBLE_LUMP_OF_COAL=132,COLLECTIBLE_PLAYDOUGH_COOKIE=570}
EntityGridCollisionClass={GRIDCOLL_NONE=0}
function Color(r,g,b,a,ro,go,bo) return {R=r,G=g,B=b,A=a,RO=ro,GO=go,BO=bo} end
function Vector(x,y) return {X=x,Y=y} end
function EntityRef(e) return {Entity=e} end
local factory=assert(loadfile("strong_laxative_synergies.lua"))()
local function env(o)
    o=o or {}
    local p={Damage=o.damage or 20,Position=Vector(0,0),InitSeed=12,flags=o.flags or TearFlags.TEAR_NORMAL,
        calls=0,items=o.items or {},alive=true}
    function p:HasCollectible(id) return self.items[id]==true end
    function p:Exists() return self.alive end
    function p:IsDead() return not self.alive end
    function p:GetTearPoisonDamage() return o.poisonDamage or self.Damage end
    function p:GetTearHitParams(weapon,scale,eye,source)
        eq(weapon,1); eq(source,nil); eq(eye,1)
        self.calls=self.calls+1
        near(scale,self.Damage>0 and self:GetTearPoisonDamage()*.666/self.Damage or 0)
        return {TearFlags=self.flags,TearDamage=o.sampleDamage or self.Damage*scale,
            TearColor=o.color or Color(.8,.2,.9,1,0,0,0)}
    end
    return factory({SlowDuration=30,CreepDamageInterval=10,CreepRadius=44},
        function(e) return e.vulnerable==true end),p
end
local function enemy(x,y,o)
    o=o or {}
    local e={Position=Vector(x,y),vulnerable=true,calls={}}
    function e:Exists() return not o.removed end
    function e:IsDead() return o.dead==true end
    function e:IsFlying() return o.flying==true end
    function e:HasEntityFlags(f) return (o.friendly and f==2) or (o.charmed and f==4) or false end
    for _,name in ipairs({"AddPoison","AddBurn","AddFreeze","AddCharmed","AddFear","AddIce","AddBaited"}) do
        e[name]=function(self,source,duration,damage)
            self.calls[#self.calls+1]={name=name,source=source.Entity,duration=duration,damage=damage}
        end
    end
    return e
end
local tests={}
function tests.base_damage_and_snapshot()
    local api,p=env(); local s=api.Snapshot(p)
    near(s.Damage,2); p.Damage=99; near(s.Damage,2); eq(p.calls,1)
end
function tests.base_damage_does_not_depend_on_unrelated_poison_cache()
    local api,p=env({damage=20,poisonDamage=10})
    near(api.Snapshot(p).Damage,2)
end
function tests.ipecac_excludes_explosive_bonus_and_only_poisons()
    local api,p=env({damage=60,poisonDamage=20,flags=TearFlags.TEAR_POISON | TearFlags.TEAR_EXPLOSIVE,items={[149]=true}})
    local s=api.Snapshot(p); near(s.Damage,2)
    local e=enemy(0,0); api.ApplyStatuses(s,e,EntityRef(p))
    eq(#e.calls,1); eq(e.calls[1].name,"AddPoison"); eq(e.calls[1].source,p)
end
function tests.proptosis_has_constant_threefold_damage()
    -- TearHitParams may already include a weapon modifier: direct damage must
    -- remain our 10% base with exactly one explicit Proptosis multiplier.
    for _,nativeMultiplier in ipairs({1,3}) do
        local api,p=env({flags=TearFlags.TEAR_SHRINK,items={[261]=true},sampleDamage=13.32*nativeMultiplier})
        local s=api.Snapshot(p); near(s.Damage,6)
        p.Position=Vector(1000,1000); near(s.Damage,6)
    end
end
function tests.unrelated_native_damage_modifiers_do_not_change_locked_base()
    local api,p=env({sampleDamage=133.2})
    near(api.Snapshot(p).Damage,2)
end
function tests.coal_acid_godhead_brainworm_do_not_add_unrequested_effects()
    for _,flag in ipairs({TearFlags.TEAR_GROW,TearFlags.TEAR_ACID,TearFlags.TEAR_GLOW,TearFlags.TEAR_TURN_HORIZONTAL}) do
        local api,p=env({flags=flag}); local s=api.Snapshot(p); near(s.Damage,2)
        local e=enemy(0,0); api.ApplyStatuses(s,e,EntityRef(p)); eq(#e.calls,0)
    end
end
function tests.cookie_statuses_include_high_word_ice_and_bait()
    local cases={{TearFlags.TEAR_POISON,"AddPoison"},{TearFlags.TEAR_BURN,"AddBurn"},
        {TearFlags.TEAR_FREEZE,"AddFreeze"},{TearFlags.TEAR_CHARM,"AddCharmed"},
        {TearFlags.TEAR_FEAR,"AddFear"},{TearFlags.TEAR_ICE,"AddIce"},{TearFlags.TEAR_BAIT,"AddBaited"}}
    for _,c in ipairs(cases) do
        local api,p=env({flags=c[1],items={[570]=true}})
        local s=api.Snapshot(p); local e=enemy(0,0); api.ApplyStatuses(s,e,EntityRef(p))
        eq(#e.calls,1); eq(e.calls[1].name,c[2]); eq(e.calls[1].source,p); eq(p.calls,1)
    end
end
function tests.cookie_native_damage_modifier_and_color_survive()
    local tint=Color(.9,.1,.2,1,0,0,0)
    local api,p=env({sampleDamage=26.64,color=tint,items={[570]=true}})
    local s=api.Snapshot(p); near(s.Damage,4); eq(s.Color,tint)
end
function tests.homing_retargets_ground_enemies_and_ignores_grid()
    local api,p=env({flags=TearFlags.TEAR_HOMING})
    local s=api.Snapshot(p); local effect={Position=Vector(0,0),Velocity=Vector(0,0)}
    api.Move(effect,s,{enemy(1,0,{flying=true}),enemy(2,0,{friendly=true}),enemy(3,0,{dead=true}),enemy(100,0)})
    assert(effect.Velocity.X>0); near(effect.Velocity.Y,0); eq(effect.GridCollisionClass,0)
    api.Move(effect,s,{enemy(0,100)}); assert(effect.Velocity.Y>0)
    api.Move(effect,s,{}); near(effect.Velocity.X,0); near(effect.Velocity.Y,0)
end
function tests.brainworm_does_not_become_homing()
    local api,p=env({flags=TearFlags.TEAR_TURN_HORIZONTAL})
    local effect={Position=Vector(0,0),Velocity=Vector(0,0)}
    api.Move(effect,api.Snapshot(p),{enemy(50,0)}); near(effect.Velocity.X,0)
end
function tests.ground_eligibility_excludes_friends_charmed_flying_dead_removed()
    local api=env(); eq(api.IsGroundEnemy(enemy(0,0)),true)
    for _,o in ipairs({{friendly=true},{charmed=true},{flying=true},{dead=true},{removed=true}}) do
        eq(api.IsGroundEnemy(enemy(0,0,o)),false)
    end
end
function tests.coop_and_zero_damage_are_isolated()
    local api,a=env({flags=TearFlags.TEAR_BURN}); local _,b=env({damage=0})
    local sa,sb=api.Snapshot(a),api.Snapshot(b); near(sb.Damage,0)
    local e=enemy(0,0); api.ApplyStatuses(sb,e,EntityRef(b)); eq(#e.calls,0)
    api.ApplyStatuses(sa,e,EntityRef(a)); eq(e.calls[1].source,a)
end
local count=0
for name,test in pairs(tests) do test(); count=count+1; print("PASS "..name) end
print("strong laxative synergy tests passed: "..count)
