local Shooting = dofile('scripts/systems/shooting_scope.lua')
local outer, inner = {}, {}
local p = {canShoot=true, live=true, writes={}}
function p:CanShoot() return self.canShoot end
function p:SetCanShoot(value) self.canShoot=value;self.writes[#self.writes+1]=value end
local function exists(player) return player.live end
for _, initial in ipairs({true,false}) do
    p.canShoot=initial
    Shooting.Block(outer,'owner',p) -- Bomb Suit: PRE -20000 / POST +20000
    Shooting.Block(inner,'owner',p) -- God Complex: PRE +10000 / POST -10000
    Shooting.Block(outer,'owner',p) -- repeated PRE never replaces first snapshot
    assert(not p.canShoot)
    Shooting.Restore(inner,'owner',exists)
    assert(not p.canShoot and inner.owner==nil)
    Shooting.Restore(outer,'owner',exists)
    assert(p.canShoot==initial and outer.owner==nil)
end
local writes=#p.writes
Shooting.Restore(outer,'missing',exists)
assert(#p.writes==writes)
Shooting.Block(outer,'owner',p);p.live=false;writes=#p.writes
Shooting.Restore(outer,'owner',exists)
assert(outer.owner==nil and #p.writes==writes)
p.live=true;p.canShoot=true
Shooting.Block(outer,'owner',p)
local oldSet=p.SetCanShoot
function p:SetCanShoot() assert(outer.owner==nil);error('native restore failure') end
local ok,err=pcall(Shooting.Restore,outer,'owner',exists)
assert(not ok and tostring(err):find('native restore failure',1,true) and outer.owner==nil)
p.SetCanShoot=oldSet
print('shooting_scope: nested scopes, initial false, repeated PRE, missing/dead owner and error detachment passed')
