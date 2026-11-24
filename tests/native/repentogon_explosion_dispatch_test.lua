-- Real checkout callback core. Engine display is substituted; not Isaac proof.
local native=assert(arg[1],'native source root required')
local function read(p) local f=assert(io.open(p,'rb')); local s=f:read('*a'); f:close(); return s end
local enums={MC_ENTITY_TAKE_DMG=11}
for name,id in read(native..'/repentogon/resources/scripts/enums_ex.lua'):gmatch('ModCallbacks%.([%w_]+)%s*=%s*(%d+)') do enums[name]=tonumber(id) end
local cb=assert(enums.MC_PRE_PLAYER_EXPLOSION_IMMUNITY,'new explosion immunity callback is missing from the production enum')
local unused=-100
setmetatable(enums,{__index=function(t,k) unused=unused-1; rawset(t,k,unused); return unused end})
local text=read(native..'/repentogon/resources/scripts/main_ex.lua')
local function section(a,b)
    local first=assert(text:find(a,1,true),a); local last=assert(text:find(b,first+1,true),b)
    return text:sub(first,last-1)
end
local diagnostics,states={},{}
local env=setmetatable({ModCallbacks=enums,CallbackPriority={DEFAULT=0},Isaac={
    SetBuiltInCallbackState=function(id,on) states[id]=on end,
    _CopyExplosionImmunityEntityRef=function(ref)
        local copy={}; for k,v in pairs(ref) do copy[k]=v end; return copy
    end,
},debug_getinfo=debug.getinfo},{__index=_G})
env.logError=function(id,mod,msg) diagnostics[#diagnostics+1]={id,mod,msg} end
env.logWarning=env.logError; env.cleanTraceback=function() return 'test traceback' end
-- Keep real locals in the same lexical chunk: type rules, iterator, register,
-- unload, return checker, dispatcher. Never copy the implementation.
assert(load(section('local function GetMetatableType','---- ERROR LOGGING / DISPLAY')
    ..section('local function typeCheckCallback','---- MISC STUFF'),
    '@native-callback-core','t',env))()
local Isaac=env.Isaac; local actor={}; local count=0
local function hit() return {callId=7,damage=1,flags=4,source={},countdown=17} end
local function immune() return {reason='EXPLOSION_IMMUNITY',sourceKey='COLLECTIBLE_PYROMANIAC',siteKey='pyromaniac.full-health',collectibleId=223} end
local function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
local function test(name,fn) fn(); count=count+1; print('PASS '..name) end
local function unload(mod) Isaac.RunCallback(enums.MC_PRE_MOD_UNLOAD,mod) end
test('all_listeners_and_priority_order',function()
    local mod={Name='order'}; local seen={}
    for _,entry in ipairs({{'late',20,true},{'first',-20,false},{'middle',0,nil},{'same',0,true}}) do
        Isaac.AddPriorityCallback(mod,cb,entry[2],function(self,p,h,i)
            eq(self,mod); eq(p,actor); eq(h.callId,7); eq(i.reason,'EXPLOSION_IMMUNITY')
            seen[#seen+1]=entry[1]; return entry[3]
        end)
    end
    eq(Isaac.RunCallback(cb,actor,hit(),immune()),false)
    eq(table.concat(seen,','),'first,middle,same,late'); unload(mod)
end)
test('false_then_true_error_invalid_and_mutation',function()
    local mod={Name='veto'}; local seen=0; local h,i=hit(),immune(); local observations={}
    local returns={false,true,'error',42,{}}
    for n=1,#returns do
        Isaac.AddCallback(mod,cb,function(_,_,snapshot,identity)
            seen=seen+1
            observations[n]={damage=snapshot.damage,id=identity.collectibleId,sourceType=snapshot.source.Type}
            snapshot.damage=999; identity.collectibleId=999; snapshot.source.Type=999
            if returns[n]=='error' then error('listener failed') end
            return returns[n]
        end)
    end
    eq(Isaac.RunCallback(cb,actor,h,i),false); eq(seen,5)
    for _,seen in ipairs(observations) do eq(seen.damage,1); eq(seen.id,223); eq(seen.sourceType,nil) end
    eq(h.source.Type,nil)
    eq(h.damage,1); eq(i.collectibleId,223)
    assert(#diagnostics>=3,'invalid returns and errors need diagnostics'); unload(mod)
end)
test('no_false_returns_nil',function()
    local mod={Name='allow'}
    Isaac.AddCallback(mod,cb,function() return true end)
    Isaac.AddCallback(mod,cb,function() return nil end)
    eq(Isaac.RunCallback(cb,actor,hit(),immune()),nil); unload(mod)
    eq(Isaac.RunCallback(cb,actor,hit(),immune()),nil); eq(states[cb],false)
end)
test('unload_removes_only_its_mod',function()
    local a,b={Name='a'},{Name='b'}; local seen={0,0}
    Isaac.AddCallback(a,cb,function() seen[1]=seen[1]+1; return false end)
    Isaac.AddCallback(b,cb,function() seen[2]=seen[2]+1 end)
    unload(a); eq(Isaac.RunCallback(cb,actor,hit(),immune()),nil)
    eq(seen[1],0); eq(seen[2],1); unload(b)
end)
test('default_dispatch_still_short_circuits',function()
    local mod={Name='legacy'}; local seen=0; local custom='legacy-test'
    Isaac.AddCallback(mod,custom,function() seen=seen+1; return true end)
    Isaac.AddCallback(mod,custom,function() seen=seen+1; return false end)
    eq(Isaac.RunCallback(custom),true); eq(seen,1); unload(mod)
end)
test('ordinary_damage_chain_keeps_cancellation',function()
    local mod={Name='damage'}; local seen=0
    Isaac.AddCallback(mod,11,function() return {Damage=2} end)
    Isaac.AddCallback(mod,11,function(_,_,damage) eq(damage,2); seen=seen+1; return false end)
    eq(Isaac.RunCallback(11,actor,1,4,{},17),false); eq(seen,1); unload(mod)
end)
test('filtered_registration_is_rejected',function()
    eq(pcall(Isaac.AddCallback,{Name='filtered'},cb,function() end,223),false)
end)
print('NATIVE_DISPATCH_TESTS '..count)
