-- Isolated evidence collector for the ordinary placed-bomb route.
return function(mod)
    local phase,index,ticks='menu',0,0
    local forceBomb=false
    local targets={}
    local function prepareTargets(p)
        for _,target in ipairs(targets)do if target:Exists()then target:Remove()end end;targets={}
        for _,distance in ipairs({30,100,140})do
            local target=Isaac.Spawn(EntityType.ENTITY_GAPER,0,0,p.Position+Vector(distance,0),Vector.Zero,nil):ToNPC()
            target.MaxHitPoints=10000;target.HitPoints=10000
            target:AddEntityFlags(EntityFlag.FLAG_FREEZE|EntityFlag.FLAG_NO_KNOCKBACK|EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
            target:GetData().distance=distance;targets[#targets+1]=target
        end
    end
    local cases={{name='ordinary'},{name='mega',id=CollectibleType.COLLECTIBLE_MR_MEGA},
        {name='sad-hot',id=CollectibleType.COLLECTIBLE_SAD_BOMBS,second=CollectibleType.COLLECTIBLE_HOT_BOMBS},
        {name='scatter',id=CollectibleType.COLLECTIBLE_SCATTER_BOMBS},
        {name='remote',id=CollectibleType.COLLECTIBLE_REMOTE_DETONATOR},
        {name='brimstone',id=CollectibleType.COLLECTIBLE_BRIMSTONE_BOMBS},
        {name='bomber',id=CollectibleType.COLLECTIBLE_BOMBER_BOY},
        {name='blood',id=CollectibleType.COLLECTIBLE_BLOOD_BOMBS},
        {name='ghost',id=CollectibleType.COLLECTIBLE_GHOST_BOMBS},
        {name='rocket',id=CollectibleType.COLLECTIBLE_ROCKET_IN_A_JAR},
        {name='bobby-bob',id=CollectibleType.COLLECTIBLE_BOBBY_BOMB,second=CollectibleType.COLLECTIBLE_BOBS_CURSE},
        {name='sticky-glitter',id=CollectibleType.COLLECTIBLE_STICKY_BOMBS,second=CollectibleType.COLLECTIBLE_GLITTER_BOMBS}}
    local function log(s)Isaac.DebugString('[Bomb Suit discovery] '..s)end
    local function inspect(label,b)
        log(label..' damage='..b.ExplosionDamage..' flags='..tostring(b.Flags)..' radius='..b.RadiusMultiplier
            ..' variant='..b.Variant..' fetus='..tostring(b.IsFetus)..' scale='..b:GetScale())
    end
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if phase=='menu'then phase='starting';Isaac.StartNewGame(0,0,0,31415926)end
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_GAME_STARTED,999999,function()phase='wait';ticks=0 end)
    mod:AddPriorityCallback(ModCallbacks.MC_INPUT_ACTION,-999999,function(_,entity,hook,action)
        if forceBomb and entity and entity:ToPlayer() and action==ButtonAction.ACTION_BOMB then
            return hook==InputHook.GET_ACTION_VALUE and 1 or true
        end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_USE_BOMB,function(_,p,b)
        prepareTargets(p);inspect(cases[index].name..': placed',b);b:GetData().discovery='placed';b:SetExplosionCountdown(1);forceBomb=false
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,-999999,function()return false end)
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,function(_,target,damage,flags,ref)
        if phase=='done'or not cases[index]then return end
        local source=ref and ref.Entity
        if target:GetData().distance then
            log(cases[index].name..': damage amount='..damage..' distance='..target:GetData().distance
                ..' sourceType='..tostring(source and source.Type)..' sourceTag='..tostring(source and source:GetData().discovery))
        end
    end,EntityType.ENTITY_GAPER)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,999999,function()
        if phase=='menu'or phase=='starting'or phase=='done'then return end
        ticks=ticks+1;local p=Isaac.GetPlayer(0)
        if phase=='wait'and ticks>=110 then
            index=index+1;local c=cases[index]
            if not c then phase='done';Isaac.DebugString('[Bomb Suit native] DONE passed=1 total=1');return end
            for _,other in ipairs(cases)do for _,id in ipairs({other.id,other.second})do
                while p:HasCollectible(id)do p:RemoveCollectible(id)end
            end end
            for _,id in ipairs({c.id,c.second})do p:AddCollectible(id,0,true)end
            p.Position=Game():GetRoom():GetCenterPos();p.Velocity=Vector.Zero;prepareTargets(p)
            log(c.name..' GetBombFlags(false)='..tostring(p:GetBombFlags(false)))
            local b=p:FireBomb(p.Position,Vector.Zero);inspect(c.name..': FireBomb nil',b);b:Remove()
            b=p:FireBomb(p.Position,Vector.Zero,p);inspect(c.name..': FireBomb player',b);b:Remove()
            b=Isaac.Spawn(EntityType.ENTITY_BOMBDROP,BombVariant.BOMB_NORMAL,0,p.Position,Vector.Zero,p):ToBomb()
            b.Flags=p:GetBombFlags(false);b.ExplosionDamage=p:HasCollectible(CollectibleType.COLLECTIBLE_MR_MEGA)and 185 or 100
            inspect(c.name..': configured spawn',b);b:GetData().discovery='spawn';b:SetExplosionCountdown(1);b:Update()
            p:AddBombs(1);p:SetBombPlaceDelay(0);p.ControlsEnabled=true;forceBomb=true
            phase='placed';ticks=0
        elseif phase=='placed'and ticks>=30 then forceBomb=false;phase='wait';ticks=100 end
    end)
end
