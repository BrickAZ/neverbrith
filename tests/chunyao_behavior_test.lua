-- Complete entry, actual registered item/cache/update handlers. No new lifecycle policy.
local env = dofile('tests/support/neverbirth_fixture.lua')({Root=arg and arg[1]})
local mod, ids = Neverbirth, env.itemIds
local function registered(event, fn, filter)
    local found=0
    for _, entry in ipairs(env.callbacks[event] or {}) do
        if entry.fn==fn then assert(entry.param==filter);found=found+1 end
    end
    assert(found==1,'expected one real registered handler')
    return fn
end
local use=registered(ModCallbacks.MC_USE_ITEM,mod.UseChunyao,ids.Aphrodisiac)
local update=registered(ModCallbacks.MC_POST_UPDATE,mod.UpdateChunyaoEffects)
registered(ModCallbacks.MC_EVALUATE_CACHE,mod.EvaluateChunyao)
local selected={[mod.EvaluateEssentialBalm]=true,[mod.EvaluateWuhu]=true,[mod.EvaluateChunyao]=true}
local players={}
Isaac.FindByType=function(kind) return kind==EntityType.ENTITY_PLAYER and players or {} end
local function player(seed)
    local p={InitSeed=seed,charge=0,counts={},damageCalls={},entityFlags=0}
    function p:ToPlayer() return self end
    function p:GetCollectibleNum(id) return self.counts[id] or 0 end
    function p:GetActiveCharge() return self.charge end
    function p:DischargeActiveItem() self.charge=0 end
    function p:TakeDamage(amount,flags) self.damageCalls[#self.damageCalls+1]={amount,flags} end
    function p:AddEntityFlags(flags) self.entityFlags=self.entityFlags|flags end
    function p:ClearEntityFlags(flags) self.entityFlags=self.entityFlags&~flags end
    function p:AddCacheFlags() end
    function p:EvaluateItems()
        self.Damage,self.MaxFireDelay,self.TearFlags,self.TearColor=3.5,9,0,Color.Default
        for _,flag in ipairs({CacheFlag.CACHE_DAMAGE,CacheFlag.CACHE_FIREDELAY,CacheFlag.CACHE_TEARCOLOR,CacheFlag.CACHE_TEARFLAG}) do
            for _,entry in ipairs(env.callbacks[ModCallbacks.MC_EVALUATE_CACHE]) do
                if selected[entry.fn] then entry.fn(mod,self,flag) end
            end
        end
    end
    p:EvaluateItems();players[#players+1]=p;return p
end
local function ticks(n) for _=1,n do update(mod) end end
local a,b=player(11),player(22)
assert(use(mod,ids.Aphrodisiac,nil,a)==false and #a.damageCalls==0,'empty charge must do nothing')
a.charge=1
assert(use(mod,ids.Aphrodisiac,nil,a)==true and a.charge==0)
assert(a.damageCalls[1][1]==1 and a.damageCalls[1][2]==(DamageFlag.DAMAGE_RED_HEARTS|DamageFlag.DAMAGE_NOKILL|DamageFlag.DAMAGE_INVINCIBLE))
assert(a.Damage==4 and a.MaxFireDelay==8.5 and a.TearFlags&TearFlags.TEAR_HOMING~=0)
ticks(30);a.charge=1;use(mod,ids.Aphrodisiac,nil,a)
assert(a.Damage==4.5 and a.MaxFireDelay==8)
assert(b.Damage==3.5 and b.TearFlags==0,'effects isolated by player')
ticks(59);assert(a.Damage==4.5,'first effect remains through frame 89')
ticks(1);assert(a.Damage==4 and a.MaxFireDelay==8.5,'only first effect expires at 90')
ticks(29);assert(a.Damage==4)
ticks(1);assert(a.Damage==3.5 and a.MaxFireDelay==9 and a.entityFlags==0 and a.TearFlags==0)
-- Preserve the current cache order, including Wuhu overriding delay on every cache event.
a.counts[ids.EssentialBalm]=1;a.counts[ids.Wuhu]=1;a.charge=1
use(mod,ids.Aphrodisiac,nil,a)
assert(a.Damage==45 and a.MaxFireDelay==0 and a.TearColor.R==1 and a.TearColor.G==0)
ticks(90);assert(a.Damage==44.5 and a.MaxFireDelay==0 and a.TearColor.R==Color().R,'Wuhu color override remains after Chunyao expires')
-- Current cleanup clears its homing flag before the engine cache evaluation.
b.charge=1;use(mod,ids.Aphrodisiac,nil,b);ticks(90)
assert(b.Damage==3.5 and a.Damage==44.5)
print('chunyao passed: registered handlers, charge/cost, staggered 90-frame stacks, players and cache ordering')
