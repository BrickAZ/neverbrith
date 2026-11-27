-- Private targeting responsibilities for god_complex; created once by its entry.
return function(mod, context, deps)
    local callbackInstallers = {}
    local data = deps.State.Data
    local exists = deps.State.exists

    local MINI={}
    for _,name in ipairs({'ENTITY_SLOTH','ENTITY_LUST','ENTITY_WRATH','ENTITY_GLUTTONY','ENTITY_GREED','ENTITY_ENVY','ENTITY_PRIDE'}) do
        MINI[EntityType[name]]=true
    end

    local function enemy(e,retained)
        if not exists(e) or not e:ToNPC() or e:IsDead() or e.HitPoints<=0 or not e:IsEnemy() then return false end
        -- Retain a locked target through charm, colour, burial and invulnerability.
        return retained or (e:IsActiveEnemy(false) and not e:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
            and not e:HasEntityFlags(EntityFlag.FLAG_CHARM))
    end

    local function combat()
        for _,e in ipairs(Isaac.GetRoomEntities()) do if enemy(e,false) then return true end end
        return false
    end

    local function mini(e)
        if not MINI[e.Type] then return false end
        if e.Type==EntityType.ENTITY_ENVY then
            return e.Variant==0 or e.Variant==1 or e.Variant==10 or e.Variant==11
                or e.Variant==20 or e.Variant==21 or e.Variant==30 or e.Variant==31
        end
        return e.Variant==0 or e.Variant==1 or (e.Type==EntityType.ENTITY_SLOTH and e.Variant==2)
    end

    local function trueBoss(e) return e:IsBoss() and not mini(e) end

    local function finalDeathType(e)
        -- Vanilla Envy's larger variants split instead of finally dying.
        return not trueBoss(e) and (e.Type~=EntityType.ENTITY_ENVY or e.Variant==30 or e.Variant==31)
    end

    local function distance(a,b) local x,y=a.Position.X-b.Position.X,a.Position.Y-b.Position.Y;return x*x+y*y end

    local function chooseTarget(p)
        local best,bestRank,bestHP,bestDistance
        local bossRoom=Game():GetRoom():GetType()==RoomType.ROOM_BOSS
        for _,e in ipairs(Isaac.GetRoomEntities()) do
            if enemy(e,false) then
                local rank=trueBoss(e) and (bossRoom and 0 or 2) or (mini(e) and 1 or (bossRoom and 2 or 0))
                local hp,dist=e.HitPoints,distance(e,p)
                if not best or rank<bestRank or (rank==bestRank and (hp>bestHP or (hp==bestHP and dist<bestDistance))) then
                    best,bestRank,bestHP,bestDistance=e,rank,hp,dist
                end
            end
        end
        return best
    end

    return {
        Installers = callbackInstallers,
        enemy = enemy,
        combat = combat,
        mini = mini,
        trueBoss = trueBoss,
        finalDeathType = finalDeathType,
        distance = distance,
        chooseTarget = chooseTarget,
    }
end
