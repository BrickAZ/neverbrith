local Controls = dofile('scripts/systems/control_ownership.lua')
local Scope = dofile('scripts/systems/shooting_scope.lua')
local function key(p) return p.ptr..':'..p.InitSeed end
local function player(value, ptr, seed)
    local p={canShoot=value,ptr=ptr or 'p',InitSeed=seed or 1,live=true,writes={},reads=0}
    function p:CanShoot() self.reads=self.reads+1;return self.canShoot end
    function p:SetCanShoot(v) self.canShoot=v;self.writes[#self.writes+1]=v end
    return p
end
local function exists(p) return p.live end
local function trace(shared, initial)
    local service=Controls.Create(key)
    local a=shared and Scope.ForOwner(service,'drive') or Scope
    local b=shared and Scope.ForOwner(service,'bomb') or Scope
    local c=shared and Scope.ForOwner(service,'god') or Scope
    local p=player(initial);local x,y,z={},{},{}
    a.Block(x,'x',p);b.Block(y,'y',p);c.Block(z,'z',p)
    c.Block(z,'z',p)
    c.Restore(z,'z',exists);b.Restore(y,'y',exists);a.Restore(x,'x',exists)
    assert(p.canShoot==initial)
    return p
end
for _,initial in ipairs({true,false}) do
    local old,new=trace(false,initial),trace(true,initial)
    assert(old.reads==new.reads and #old.writes==#new.writes)
    for i,v in ipairs(old.writes) do assert(new.writes[i]==v,'normal order setter drift') end
    local service=Controls.Create(key);local a,b=Scope.ForOwner(service,'a'),Scope.ForOwner(service,'b')
    local p=player(initial);local x,y={},{}
    a.Block(x,'x',p);b.Block(y,'y',p)
    a.Restore(x,'x',exists);assert(p.canShoot==false,'early owner unlocked remaining owner')
    a.Restore(x,'x',exists);assert(p.canShoot==false)
    b.Restore(y,'y',exists);assert(p.canShoot==initial)
end

do -- Physical entities stay separate even when their logical seed is identical.
    local service=Controls.Create(key);local a,b=Scope.ForOwner(service,'a'),Scope.ForOwner(service,'b')
    local p,q=player(true,'old',7),player(false,'new',7);local x,y={},{}
    a.Block(x,'x',p);b.Block(y,'y',q)
    p.live=false;local writes=#p.writes
    a.Restore(x,'x',exists);assert(#p.writes==writes and q.canShoot==false)
    b.Restore(y,'y',exists);assert(q.canShoot==false)
    local replacement=player(true,'old',8)
    a.Block(x,'x',replacement);a.Restore(x,'x',exists);assert(replacement.canShoot==true)
end

do -- A handle cannot release another owner's claim; release is idempotent.
    local service=Controls.Create(key);local a,b=service.Owner('a'),service.Owner('b')
    local p=player(true);local handle=a.Capture(p);a.Block(handle)
    assert(not pcall(b.Release,handle,exists))
    assert(not pcall(service.Owner,'a'))
    assert(p.canShoot==false and a.Release(handle,exists)==true)
    assert(a.Release(handle,exists)==false and p.canShoot==true)
end

do -- A removed body can be replaced even if a provider recycles its entire key.
    local service=Controls.Create(key,exists)
    local a,b=Scope.ForOwner(service,'old'),Scope.ForOwner(service,'new')
    local old,new=player(true,'same',9),player(false,'same',9);local x,y={},{}
    a.Block(x,'x',old);old.live=false
    b.Block(y,'y',new)
    a.Restore(x,'x',exists);assert(new.canShoot==false)
    b.Restore(y,'y',exists);assert(new.canShoot==false,'old body baseline leaked to replacement')
end

do -- Capture is retained before a failed native block; restore detaches first.
    local service=Controls.Create(key);local a=Scope.ForOwner(service,'a')
    local p=player(true);local x={};local setter=p.SetCanShoot
    function p:SetCanShoot() error('block failed') end
    assert(not pcall(a.Block,x,'x',p) and x.x)
    function p:SetCanShoot() assert(x.x==nil);error('restore failed') end
    local ok,err=pcall(a.Restore,x,'x',exists)
    assert(not ok and tostring(err):find('restore failed',1,true) and x.x==nil)
    p.SetCanShoot=setter
    a.Block(x,'x',p);a.Restore(x,'x',exists);assert(p.canShoot==true)
end

do -- A reentrant validity query cannot lose the original true baseline.
    local service=Controls.Create(key);local a,b=Scope.ForOwner(service,'a'),Scope.ForOwner(service,'b')
    local p=player(true);local x,y={},{}
    a.Block(x,'x',p)
    a.Restore(x,'x',function(who) b.Block(y,'y',who);return true end)
    assert(p.canShoot==false)
    b.Restore(y,'y',exists);assert(p.canShoot==true)
end

for _,fail in ipairs({false,true}) do -- Setter reentry, including an error after B claims.
    local service=Controls.Create(key);local a,b=Scope.ForOwner(service,'a'),Scope.ForOwner(service,'b')
    local p=player(true);local x,y={},{};local setter=p.SetCanShoot;local once=true
    a.Block(x,'x',p)
    function p:SetCanShoot(value)
        if value and once then
            once=false;assert(x.x==nil);b.Block(y,'y',self)
            if fail then error('reentrant setter failed') end
        end
        setter(self,value)
    end
    local ok,err=pcall(a.Restore,x,'x',exists)
    assert(ok==not fail)
    if fail then assert(tostring(err):find('reentrant setter failed',1,true)) end
    assert(x.x==nil and p.canShoot==false,'restore overrode a reentrant owner')
    p.SetCanShoot=setter;b.Restore(y,'y',exists);assert(p.canShoot==true)
end

for _,secondary in ipairs({false,true}) do
    -- A setter can apply true and then throw after B already acquired its block.
    local service=Controls.Create(key);local a,b=Scope.ForOwner(service,'a'),Scope.ForOwner(service,'b')
    local p=player(true);local x,y={},{};local setter=p.SetCanShoot;local once=true;local faulted=false;local repairs=0
    a.Block(x,'x',p)
    function p:SetCanShoot(value)
        if value and once then
            once=false;b.Block(y,'y',self);setter(self,value);faulted=true
            error('first error after native write')
        end
        setter(self,value)
        if faulted then
            repairs=repairs+1
            if secondary then error('secondary repair failure') end
        end
    end
    local ok,err=pcall(a.Restore,x,'x',exists)
    assert(not ok and tostring(err):find('first error after native write',1,true))
    assert(not tostring(err):find('secondary repair failure',1,true))
    assert(p.canShoot==false and x.x==nil and repairs==1,'failed restore did not preserve remaining owner')
    p.SetCanShoot=setter;b.Restore(y,'y',exists);assert(p.canShoot==true)
end

do -- The repair validity query can itself release the last remaining owner.
    local service=Controls.Create(key);local a,b=Scope.ForOwner(service,'a'),Scope.ForOwner(service,'b')
    local p=player(true);local x,y={},{};local setter=p.SetCanShoot;local once=true;local queries=0
    a.Block(x,'x',p)
    function p:SetCanShoot(value)
        if value and once then
            once=false;b.Block(y,'y',self);setter(self,value)
            error('original restoration failed')
        end
        setter(self,value)
    end
    local ok,err=pcall(a.Restore,x,'x',function(who)
        queries=queries+1
        if queries==2 then b.Restore(y,'y',exists) end
        return true
    end)
    assert(not ok and tostring(err):find('original restoration failed',1,true))
    assert(queries==2 and p.canShoot==true and x.x==nil and y.y==nil,'repair re-locked an unowned player')
end

for _,repair in ipairs({false,true}) do
    -- A successful false setter may release the last owner, whose true write
    -- happens before this outer false write. Recalculate in both paths.
    local service=Controls.Create(key);local a,b=Scope.ForOwner(service,'a'),Scope.ForOwner(service,'b')
    local p=player(true);local x,y={},{};local setter=p.SetCanShoot;local releaseInside=false;local begin=true
    a.Block(x,'x',p)
    if not repair then b.Block(y,'y',p);releaseInside=true end
    function p:SetCanShoot(value)
        if repair and value and begin then
            begin=false;b.Block(y,'y',self);setter(self,value);releaseInside=true
            error('first setter failure')
        end
        if not value and releaseInside then
            releaseInside=false;b.Restore(y,'y',exists)
        end
        setter(self,value)
    end
    local ok,err=pcall(a.Restore,x,'x',exists)
    assert(ok==not repair)
    if repair then assert(tostring(err):find('first setter failure',1,true)) end
    assert(p.canShoot==true and x.x==nil and y.y==nil,'successful false write overrode final owner release')
end

do -- A setter repeatedly changing owners is bounded and explicitly fails.
    local service=Controls.Create(key);local a,b=Scope.ForOwner(service,'a'),Scope.ForOwner(service,'b')
    local p=player(true);local x,y={},{};local setter=p.SetCanShoot;local nested=false;local calls=0
    a.Block(x,'x',p)
    function p:SetCanShoot(value)
        calls=calls+1;assert(calls<10,'unbounded reentrant reconciliation')
        if not nested then
            nested=true
            if y.y then b.Restore(y,'y',exists) else b.Block(y,'y',self) end
            nested=false
        end
        setter(self,value)
    end
    local ok,err=pcall(a.Restore,x,'x',exists)
    assert(not ok and tostring(err):find('control owners kept changing',1,true))
    assert(x.x==nil and calls<=6)
end

for _,fail in ipairs({false,true}) do
    -- Replacement during the setter must not inherit the old generation or be
    -- touched by either the successful correction or exception repair branch.
    local service=Controls.Create(key,exists);local a,b=Scope.ForOwner(service,'a'),Scope.ForOwner(service,'b')
    local old,new=player(true,'reuse',11),player(true,'reuse',11);local x,y={},{};local setter=old.SetCanShoot
    a.Block(x,'x',old)
    function old:SetCanShoot(value)
        self.live=false;b.Block(y,'y',new);setter(self,value)
        if fail then error('old generation setter failed') end
    end
    local ok,err=pcall(a.Restore,x,'x',exists)
    assert(ok==not fail)
    if fail then assert(tostring(err):find('old generation setter failed',1,true)) end
    assert(new.canShoot==false and #new.writes==1,'old restoration touched the new generation')
    b.Restore(y,'y',exists);assert(new.canShoot==true)
end

do -- Existence failures propagate after detachment, without retaining an entity.
    local a=Scope.ForOwner(Controls.Create(key),'a');local p=player(false);local x={}
    a.Block(x,'x',p)
    local ok,err=pcall(a.Restore,x,'x',function()error('exists failed')end)
    assert(not ok and tostring(err):find('exists failed',1,true) and x.x==nil)
    a.Block(x,'x',p);a.Restore(x,'x',exists);assert(p.canShoot==false)
end
print('control ownership: normal setter parity, arbitrary release, physical identities, owner isolation and failure/reentry passed')
