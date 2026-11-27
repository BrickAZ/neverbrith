local Installation=dofile('scripts/runtime/feature_installation.lua')
local callbacks={}
local mod={existing='keep',replaced='original'}
function mod:AddCallback(event,fn,param)return self:AddPriorityCallback(event,0,fn,param)end
function mod:AddPriorityCallback(event,priority,fn,param)
    callbacks[#callbacks+1]={event=event,fn=fn,param=param,priority=priority}
    if self.throwAfterRegister then error('registration failed after mutation')end
end
function mod:RemoveCallback(event,fn)
    for i=#callbacks,1,-1 do if callbacks[i].event==event and callbacks[i].fn==fn then table.remove(callbacks,i)end end
end
local originalAdd,originalPriority=mod.AddCallback,mod.AddPriorityCallback
local unrelated=function()end
mod:AddCallback(1,unrelated,2)
local install=Installation.Create(mod)
local first=function()end
local result=install.Run('first',function()
    mod.replaced='first';mod.owned=function()end
    mod:AddCallback(2,first,3)
    return {query=function()return true end}
end)
assert(result.query() and #callbacks==2 and callbacks[2].fn==first)
assert(mod.AddCallback==originalAdd and mod.AddPriorityCallback==originalPriority,'registration methods restored after success')
-- Unrelated work between feature installations must survive a later abort.
local between=function()end;mod:AddCallback(3,between);mod.unrelatedField='later'
mod.throwAfterRegister=true
local ok,err=pcall(install.Run,'second',function()
    mod.replaced='second';mod.partial=true
    mod:AddPriorityCallback(4,-100,function()end,5)
end)
mod.throwAfterRegister=nil
assert(not ok and tostring(err):find('second',1,true) and tostring(err):find('registration failed',1,true))
assert(#callbacks==2 and callbacks[1].fn==unrelated and callbacks[2].fn==between,'rollback only owned callbacks, including failed add')
assert(mod.replaced=='original' and mod.owned==nil and mod.partial==nil and mod.unrelatedField=='later')
assert(mod.AddCallback==originalAdd and mod.AddPriorityCallback==originalPriority)
assert(not pcall(install.Run,'unsafe retry',function()end),'failed batch cannot resume partly')
local retry=Installation.Create(mod)
retry.Run('fresh install',function()mod:AddCallback(2,first,3)end)
assert(#callbacks==3,'fresh batch can install after successful rollback')
local failInclude=Installation.Create(mod)
failInclude.Run('earlier',function()mod:AddCallback(9,function()end)end)
assert(not pcall(failInclude.Run,'missing module',function()error('include missing')end))
assert(#callbacks==3,'load failure also rolls back earlier batch callbacks')
print('feature installation passed: identity/order, grouped rollback, mutated failure, exports, unrelated callbacks, fresh retry')
