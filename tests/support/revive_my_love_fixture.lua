include = function(name) return dofile((name:gsub('%.', '/')) .. '.lua') end
-- Engine boundary fixture: death resolution happens after the native animation,
-- and returning false revives immediately (it does not postpone Game Over).
local function eq(a, b, why)
    assert(a == b, (why or "mismatch") .. ": expected " .. tostring(b) .. ", got " .. tostring(a))
end
ModCallbacks = { MC_ENTITY_TAKE_DMG=1, MC_POST_GAME_STARTED=2, MC_PRE_GAME_EXIT=3,
    MC_POST_EFFECT_UPDATE=4, MC_POST_PLAYER_UPDATE=5, MC_TRIGGER_PLAYER_DEATH_POST_CHECK_REVIVES=1051,
    MC_PRE_PLAYER_UPDATE=1160, MC_PRE_PLAYER_TAKE_DMG=1008, MC_POST_NEW_ROOM=19,
    MC_POST_ADD_COLLECTIBLE=1005, MC_POST_TRIGGER_COLLECTIBLE_REMOVED=1095, MC_POST_UPDATE=6 }
EntityType = { ENTITY_PLAYER=1, ENTITY_EFFECT=1000 }
EntityCollisionClass = { ENTCOLL_NONE=0, ENTCOLL_ALL=4 }
DamageFlag = { DAMAGE_FAKE=1, DAMAGE_NOKILL=2 }
Vector = setmetatable({Zero={X=0,Y=0}}, {__call=function(_,x,y) return {X=x,Y=y} end})
Color = setmetatable({}, {__call=function(_,...) return {...} end})
REPENTOGON = {Version="1.0.12a", MeetsVersion=function(v) return v == "1.0.12a" end}

local function environment(options)
    options = options or {}
    local callbacks, players, effects, root = {}, {}, {}, {}
    local soundCount, seed = 0, 12345
    local saves = {}
    local mod = {}
    function mod:AddCallback(id, fn, filter) callbacks[id]={fn=fn,filter=filter} end
    Game = function() return {GetNumPlayers=function() return #players end} end
    Isaac = {GetPlayer=function(i) return players[i+1] end}
    function Isaac.Spawn(t,v,s,pos,vel,owner)
        if options.noEffect then return nil end
        local e={Type=t,Variant=v,SubType=s,Position=pos,SpawnerEntity=owner,
            InitSeed=1000+#effects,removed=false,sprite={finished=false,plays=0}}
        function e:GetSprite() return self.sprite end
        function e.sprite:Play(name) self.animation=name; self.plays=self.plays+1 end
        function e.sprite:IsFinished(name) return self.animation==name and self.finished end
        function e:Exists() return not self.removed end
        function e:Remove() self.removed=true end
        function e:SetColor() end
        effects[#effects+1]=e
        return e
    end
    local api = dofile(options.ModulePath or "revive_my_love.lua")(mod, {ItemId=9001,EffectVariant=3020,
        GetSaveRoot=function() return root end, Save=function()
            local function copy(t) if type(t)~='table' then return t end local out={} for k,v in pairs(t)do out[k]=copy(v)end return out end
            saves[#saves+1]=copy(root)
        end,
        GetCurrentRunSeed=function() return seed end,
        PlaySound=function() soundCount=soundCount+1 end})
    local function call(id,...)
        local c=callbacks[id]
        if c then return c.fn(mod,...) end
    end
    local function player(count)
        local p={Type=1,InitSeed=10+#players,held=count or 1,dead=false,hearts=2,maxHearts=6,soul=0,
            ControlsEnabled=true,Visible=true,EntityCollisionClass=4,Position=Vector(100,120),
            Velocity=Vector(0,0),FrameCount=0,revives=0,removed=0,effectCount=0}
        function p:ToPlayer() return self end
        function p:GetCollectibleNum(id) eq(id,9001); return self.held end
        function p:IsDead() return self.dead end
        function p:Exists() return true end
        function p:WillPlayerRevive() return self.effectCount>0 or self.otherRevive==true end
        function p:RemoveCollectible(id)
            eq(id,9001); self.held=self.held-1; self.removed=self.removed+1
            call(1095,self,id) -- Synchronous removal callback must not re-arm the revive.
        end
        function p:Revive()
            if self.vetoRevive then return end
            self.revives=self.revives+1; self.dead=false; self.hearts=1
            if options.deathPresentation then
                self.Visible=false; self.ControlsEnabled=false; self.EntityCollisionClass=0
            end
        end
        function p:GetHearts() return self.hearts end
        function p:GetMaxHearts() return self.maxHearts end
        function p:GetSoulHearts() return self.soul end
        function p:AddHearts(n) self.hearts=self.hearts+n end
        function p:AddSoulHearts(n) self.soul=self.soul+n end
        function p:SetMinDamageCooldown(n) self.cooldown=n end
        function p:SetColor() end
        local fx={}
        function fx:GetCollectibleEffectNum(id) eq(id,9001); return p.effectCount end
        function fx:AddCollectibleEffect(id,costume,n)
            eq(id,9001); eq(costume,false); p.effectCount=p.effectCount+n
        end
        function fx:RemoveCollectibleEffect(id,n) eq(id,9001); p.effectCount=math.max(0,p.effectCount-n) end
        function p:GetEffects() return fx end
        players[#players+1]=p
        return p
    end
    return {mod=mod,saves=saves,players=players,api=api,call=call,player=player,effects=effects,root=root,callbacks=callbacks,
        sounds=function() return soundCount end,
        newSeed=function() seed=seed+1 end}
end

return environment
