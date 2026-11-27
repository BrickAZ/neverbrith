-- Exercise actual feature lifecycle/state/weapon release functions together.
local Controls=dofile('scripts/systems/control_ownership.lua')
local Scope=dofile('scripts/systems/shooting_scope.lua')
GetPtrHash=function(p)return p.ptr end
CacheFlag={CACHE_SPEED=4}
local function exists(p)return p:Exists()end
for _,initial in ipairs({true,false}) do
    for _,early in ipairs({true,false}) do
        local p={ptr=7,InitSeed=3,canShoot=initial}
        function p:CanShoot()return self.canShoot end
        function p:SetCanShoot(value)self.canShoot=value end
        function p:Exists()return true end
        function p:IsDead()return false end
        function p:HasMortalDamage()return false end
        function p:HasCollectible()return true end
        function p:AddCacheFlags()end
        function p:EvaluateItems()end
        local service=Controls.Create(function(who)return who.ptr..':'..who.InitSeed end,exists)
        local god=Scope.ForOwner(service,'god_complex')
        local bomb=Scope.ForOwner(service,'bomb_suit')
        local drive=Scope.ForOwner(service,'drive_glove')
        local gs=dofile('scripts/features/god_complex/state.lua')({}, {ItemId=1}, {Shooting=god,Config={CACHE=4}})
        gs.Data.ready=true
        gs.Data.active[gs.key(p)]={player=p,form='Solar',tears={}}
        -- The fixture selects the live form; the actual callbacks and state
        -- owners below perform every acquisition, stop and restoration.
        gs.state=function(who)return gs.Data.active[gs.key(who)]end
        local gl=dofile('scripts/features/god_complex/lifecycle.lua')({}, {ItemId=1},
            {State=gs,Shooting=god,Config={},Targeting={},Presentation={},Combat={}})
        local bs=dofile('scripts/features/bomb_suit/state.lua')({}, {ItemId=2}, {Shooting=bomb})
        bs.Data.ready=true;bs.Data.active[bs.key(p)]={player=p}
        local bl=dofile('scripts/features/bomb_suit/lifecycle.lua')({}, {ItemId=2},
            {State=bs,Shooting=bomb,Config={},Bombs={},Presentation={}})
        local weapons=dofile('scripts/features/drive_glove/weapons.lua')({},
            {Core={},State={},Rules={},Input={},Shooting=drive,Exists=exists})
        local t={}
        drive.Block(t,'shootScope',p)
        bl.prePlayer(nil,p);gl.prePlayer(nil,p)
        assert(p.canShoot==false)
        if early then
            weapons.RestoreShoot(p,t);assert(p.canShoot==false,'Drive cleanup released another owner')
            bs.stop(bs.key(p));assert(p.canShoot==false,'Bomb stop released God Complex')
            gs.stop(gs.key(p))
        else
            gl.postPlayer(nil,p);assert(p.canShoot==false)
            bl.postPlayer(nil,p);assert(p.canShoot==false)
            weapons.RestoreShoot(p,t)
        end
        assert(p.canShoot==initial and t.shootScope==nil)
        gs.clear();bs.clear();weapons.RestoreShoot(p,t)
        assert(p.canShoot==initial,'repeated actual cleanup changed permission')
    end
end
print('control release order: actual God/Bomb state and lifecycle, Drive weapon restore, early stop and original false passed')
