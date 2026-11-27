-- Blinky's bag belongs to the run, outside the shared Hourglass snapshots.
return function(mod, context)
    local Core=include('blinky_core')
    local game=Game()
    local id=context.ItemId
    if not id or id<=0 then return end
    local api,holds,flights,swings={},{},{},{}
    local stateService=context.State or mod.PendingContentState
    local selector
    if context.GetSelector then selector=assert(context.GetSelector(), 'Blinky requires inventory selector')
    else selector=context.Selector or mod.InventorySelector end
    local flightVariant=Isaac.GetEntityVariantByName('Blinky Thrown Object')
    local activeDamage,readingInput,reconcileAt=nil,0,nil
    local G=GridEntityType
    local chestVariants={ [50]=true,[51]=true,[52]=true,[53]=true,[54]=true,[55]=true,
        [56]=true,[57]=true,[58]=true,[60]=true,[360]=true,[390]=true }
    local holyChestVariant=PickupVariant.PICKUP_ETERNALCHEST
    local rocks={}
    for _,name in ipairs({'GRID_ROCK','GRID_ROCKB','GRID_ROCK_BOMB','GRID_ROCK_ALT',
        'GRID_ROCK_GOLD','GRID_ROCK_SPIKED','GRID_ROCK_ALT2'})do
        if G[name] then rocks[G[name]]=true end
    end
    local function data()
        local s=Core.Ensure(context.GetSaveRoot(),context.GetCurrentRunSeed())
        s.released=s.released or {};return s
    end
    local function save()if context.Save then context.Save()end end
    local function key(p)return stateService.InventoryPlayerKey(p)end
    local function roomKey()return stateService.RoomKey()end
    local function zero()return Vector(0,0)end
    local function exists(e)return e and e:Exists()end
    local function enemy(e)
        return exists(e) and e:ToNPC() and e:IsActiveEnemy(false) and e:IsVulnerableEnemy()
            and not e:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) and not e:IsDead()
    end
    local function facing(p)
        local dirs={[Direction.LEFT]=Vector(-1,0),[Direction.UP]=Vector(0,-1),
            [Direction.RIGHT]=Vector(1,0),[Direction.DOWN]=Vector(0,1)}
        return dirs[p:GetHeadDirection()] or Vector(0,1)
    end
    local function entityToken(e)return table.concat({'e',e.InitSeed,e.Type,e.Variant,e.SubType},':')end
    local function chestIdentity(e)return roomKey()..':chest:'..e.InitSeed..':'..e.Variant end
    local function gridToken(g,i)return table.concat({'g',i,g:GetType(),g:GetVariant()},':')end
    local function enemyToken(e)return roomKey()..':'..entityToken(e)end
    local function input(action,p)
        if not action then return false end
        readingInput=readingInput+1
        local value=Input.IsActionPressed(action,p.ControllerIndex)
        readingInput=readingInput-1
        return value
    end
    -- Keep the precedence explicit: pocket slots use the pocket binding.
    local function actionForSlot(slot)
        if slot==2 or slot==3 then return ButtonAction.ACTION_PILLCARD end
        return ButtonAction.ACTION_ITEM
    end
    local function spriteRecord(sprite)
        return {spritePath=sprite:GetFilename(),animation=sprite:GetAnimation(),frame=sprite:GetFrame()}
    end
    local function copySprite(record,sprite)
        local r=spriteRecord(sprite);for k,v in pairs(r)do record[k]=v end
    end
    local function label(entry)
        local zh=mod:GetRuntimeLocale()=='zh_cn'
        if entry.kind=='pickup' and entry.variant==100 then
            local config=Isaac.GetItemConfig():GetCollectible(entry.subtype)
            local name=config and config.Name or tostring(entry.subtype)
            if mod.GetLocalizedItemName then name=mod:GetLocalizedItemName(entry.subtype,name)end
            return name
        end
        local names={rock={'Rock','石头'},poop={'Poop','大便'},spikes={'Spikes','尖刺'},
            tnt={'TNT','TNT'},flame={'Fire','火焰'},chest={'Chest','箱子'},spentChest={'Opened chest','已开箱子'},
            pickup={'Pickup','掉落物'}}
        local pair=names[entry.kind] or names.pickup
        local name=pair[zh and 2 or 1]
        if entry.kind=='pickup'then name=name..' '..entry.variant..':'..entry.subtype end
        if entry.price and entry.price~=0 then name=name..' ['..tostring(entry.price)..']'end
        return name
    end
    local function pickupRecord(pickup)
        local kind='pickup'
        if chestVariants[pickup.Variant] then
            local animation=pickup:GetSprite():GetAnimation()
            local opened=pickup.SubType==ChestSubType.CHEST_OPENED or animation=='Open' or animation=='Opened'
                or pickup:GetData().NeverbirthBlinkyHolyOpened
                or (data().holyOpened or{})[chestIdentity(pickup)]
            kind=opened and 'spentChest' or 'chest'
        end
        local e={kind=kind,variant=pickup.Variant,subtype=pickup.SubType,seed=pickup.InitSeed,
            price=pickup.Price,charge=pickup.Charge,shopItemId=pickup.ShopItemId,state=pickup.State,
            touched=pickup.Touched,timeout=pickup.Timeout}
        copySprite(e,pickup:GetSprite())
        if pickup.GetVarData then e.varData=pickup:GetVarData()end
        if pickup.GetFlipCollectible then
            local flip=pickup:GetFlipCollectible()
            if type(flip)=='number'then e.flip=flip elseif flip and flip.ID then e.flip=flip.ID end
        end
        if pickup.GetCollectibleCycle then
            local cycle=pickup:GetCollectibleCycle();e.cycle={}
            for _,value in ipairs(cycle or{})do
                if type(value)=='number'then e.cycle[#e.cycle+1]=value end
            end
        end
        if pickup.Variant==100 then
            local config=Isaac.GetItemConfig():GetCollectible(pickup.SubType)
            e.gfx=config and config.GfxFileName
        end
        return e
    end
    local function remember(p,e,source)
        local uid=Core.Add(data(),key(p),e,source);save();return uid
    end
    local function removeGrid(room,index)
        if room.RemoveGridEntityImmediate then room:RemoveGridEntityImmediate(index,0,false)
        else room:RemoveGridEntity(index,0,false)end
    end
    local function absorb(p)
        local room=game:GetRoom();local s=data();local rk=roomKey();local direction=facing(p)
        local range=math.max(0,p.TearRange)
        for i=0,room:GetGridSize()-1 do
            local g=room:GetGridEntity(i)
            if g and Core.InCone(p.Position,direction,g.Position,range)
                and not Core.IsConsumed(s,rk,gridToken(g,i)) then
                local t,v=g:GetType(),g:GetVariant();local kind
                if t==G.GRID_ROCKT or t==G.GRID_ROCK_SS then
                    -- Tinted rocks retain the native destruction reward, never enter the bag.
                    if g.State~=2 then g:Destroy(false)end
                elseif rocks[t] and g.State~=2 then kind='rock'
                elseif t==G.GRID_POOP and g.State<1000 and not(v>=7 and v<=10)then kind='poop'
                elseif t==G.GRID_SPIKES or t==G.GRID_SPIKES_ONOFF then kind='spikes'
                elseif t==G.GRID_TNT and g.State~=2 then kind='tnt' end
                if kind then
                    local e={kind=kind,gridType=t,gridVariant=v};copySprite(e,g:GetSprite())
                    remember(p,e,{room=rk,token=gridToken(g,i),grid=i,gridType=t,gridVariant=v})
                    removeGrid(room,i)
                end
            end
        end
        for _,entity in ipairs(Isaac.GetRoomEntities())do
            local released=entity:GetData().NeverbirthBlinkyReleased or(s.released[rk]or{})[entityToken(entity)]
            if exists(entity) and Core.InCone(p.Position,direction,entity.Position,range)
                and (released or not Core.IsConsumed(s,rk,entityToken(entity))) then
                local pickup=entity:ToPickup()
                if pickup and pickup.Variant~=PickupVariant.PICKUP_BED
                    and pickup.Variant~=PickupVariant.PICKUP_TROPHY and pickup.Variant~=PickupVariant.PICKUP_BIGCHEST
                    and not(pickup.Variant==100 and pickup.SubType<=0)then
                    -- Clear the mutual-exclusion group before removing this physical instance.
                    local e=pickupRecord(pickup)
                    remember(p,e,{room=rk,token=entityToken(pickup)})
                    pickup.OptionsPickupIndex=0;pickup:Remove()
                elseif entity.Type==EntityType.ENTITY_FIREPLACE and not entity:IsDead()then
                    local e={kind='flame'};copySprite(e,entity:GetSprite())
                    remember(p,e,{room=rk,token=entityToken(entity)});entity:Remove()
                elseif entity.Type==EntityType.ENTITY_SHOPKEEPER then
                    -- Remove, rather than Kill, suppresses coin/spider/Steam Sale death drops.
                    remember(p,{kind='discard'}, {room=rk,token=entityToken(entity)})
                    local list=Core.Entries(s,key(p));table.remove(list,#list);entity:Remove();save()
                elseif entity.Type==EntityType.ENTITY_MOVABLE_TNT or entity.Type==EntityType.ENTITY_POOP then
                    local e={kind=entity.Type==EntityType.ENTITY_MOVABLE_TNT and 'tnt' or 'poop'}
                    copySprite(e,entity:GetSprite());remember(p,e,{room=rk,token=entityToken(entity)});entity:Remove()
                end
            end
        end
    end
    local function mark(npc)
        local s=data();local rk=roomKey();s.wounds[rk]=s.wounds[rk]or{}
        s.wounds[rk][entityToken(npc)]=true
        npc:GetData().NeverbirthBlinkyWounded=true
    end
    local function wounded(npc)
        return npc:GetData().NeverbirthBlinkyWounded or
            (data().wounds[roomKey()] or{})[entityToken(npc)]
    end
    local function melee(p)
        local hits={};local angle=facing(p):GetAngleDegrees()-90
        -- Sweep the native Swing null trajectory, once per physical target.
        local points={Vector(-20,0),Vector(-14,14),Vector(0,20),Vector(14,14),Vector(20,0)}
        for i,point in ipairs(points)do points[i]=p.Position+point:Rotated(angle)end
        for _,e in ipairs(Isaac.GetRoomEntities())do
            if enemy(e)then
                for i=2,#points do
                    if Core.DistanceToSegment(points[i-1],points[i],e.Position)<=16+e.Size then
                        hits[#hits+1]=e;break
                    end
                end
            end
        end
        if #hits==0 then return false end
        local sprite=Sprite();sprite:Load('gfx/008.003_donkey jawbone.anm2',true);sprite:Play('Swing',true)
        sprite.Rotation=facing(p):GetAngleDegrees()-90
        swings[key(p)]={sprite=sprite,player=p,expires=game:GetFrameCount()+10}
        for _,npc in ipairs(hits)do
            if npc:TakeDamage(Core.Damage('melee',p.Damage),0,EntityRef(p),0)~=false and exists(npc)then mark(npc)end
        end
        save();return true
    end
    local function reward(npc)
        local d=npc:GetData();local credit=d.NeverbirthBlinkySuction
        if credit and Core.Reward(data(),credit.key,credit.death)then save()end
    end
    local function suctionDamage(p)
        for _,npc in ipairs(Isaac.GetRoomEntities())do
            if enemy(npc) and wounded(npc) and Core.InCone(p.Position,facing(p),npc.Position,p.TearRange)then
                local d=npc:GetData();local credit={key=key(p),death=enemyToken(npc)}
                activeDamage=npc;d.NeverbirthBlinkySuction=credit
                local accepted=npc:TakeDamage(Core.Damage('suction',p.Damage),0,EntityRef(p),0)
                activeDamage=nil
                if accepted==false then d.NeverbirthBlinkySuction=nil
                elseif npc:IsDead() or npc.HitPoints<=0 then reward(npc)end
            end
        end
    end
    local function makeSprite(e)
        local sprite=Sprite();sprite:Load(e.spritePath or'gfx/005.011_heart.anm2',true)
        if e.gfx then sprite:ReplaceSpritesheet(1,e.gfx);sprite:LoadGraphics()end
        sprite:SetFrame(e.animation or'Idle',e.frame or 0);return sprite
    end
    local function nativePickup(e,pos,p)
        if e.variant==100 and not Isaac.GetItemConfig():GetCollectible(e.subtype)then return nil end
        local free=game:GetRoom():FindFreePickupSpawnPosition(pos,0,true)
        local entity=game:Spawn(EntityType.ENTITY_PICKUP,e.variant,free,zero(),p,e.subtype,e.seed~=0 and e.seed or 1)
        local pickup=entity and entity:ToPickup()
        if not pickup then if entity then entity:Remove()end;return nil end
        -- Spawn may apply item/pickup replacement modifiers. This is transportation
        -- of an existing physical object, not another item-pool roll.
        pickup:Morph(EntityType.ENTITY_PICKUP,e.variant,e.subtype,true,true,true)
        pickup.Price=e.price or 0;pickup.AutoUpdatePrice=false;pickup.ShopItemId=e.shopItemId or-1
        pickup.Charge=e.charge or 0;pickup.OptionsPickupIndex=0;pickup.State=e.state or 0
        pickup.Touched=e.touched or false;pickup.Wait=10
        if e.timeout and e.timeout>=0 then pickup.Timeout=e.timeout end
        if e.varData and pickup.SetVarData then pickup:SetVarData(e.varData)end
        if e.flip and e.flip>0 and pickup.InitFlipState then pickup:InitFlipState(e.flip)end
        if e.cycle and pickup.AddCollectibleCycle then
            if pickup.RemoveCollectibleCycle then pickup:RemoveCollectibleCycle()end
            for _,cid in ipairs(e.cycle)do pickup:AddCollectibleCycle(cid)end
        end
        local rk=roomKey();local s=data();s.released[rk]=s.released[rk]or{}
        s.released[rk][entityToken(pickup)]=true
        pickup:GetData().NeverbirthBlinkyReleased=true
        save();return pickup
    end
    local function fireTear(p,pos,velocity,damage,nail)
        -- Native tears, with explicit damage: player passives cannot change the approved base.
        local entity=Isaac.Spawn(EntityType.ENTITY_TEAR,nail and TearVariant.NAIL or TearVariant.BLUE,
            0,pos,velocity,p)
        local tear=entity and entity:ToTear()
        if not tear then return nil end
        tear.CollisionDamage=damage;tear.Height=-10;tear.FallingSpeed=-2;tear.FallingAcceleration=.3
        if nail then tear:AddTearFlags(TearFlags.TEAR_KNOCKBACK)
        else tear.Color=Color(.55,.32,.16,1,0,0,0);tear.Scale=.65 end
        return tear
    end
    local function specialShot(p,e,direction)
        if e.kind=='spikes'then
            local created={}
            for _,angle in ipairs({-10,0,10})do
                local tear=fireTear(p,p.Position,direction:Rotated(angle)*10,p.Damage,true)
                if not tear then for _,t in ipairs(created)do t:Remove()end;return false end
                created[#created+1]=tear
            end
            return true
        elseif e.kind=='flame'then
            local entity=Isaac.Spawn(EntityType.ENTITY_EFFECT,EffectVariant.RED_CANDLE_FLAME,0,
                p.Position+direction*16,direction*10,p)
            local fire=entity and entity:ToEffect()
            if not fire then return false end
            fire.Parent=p;fire.CollisionDamage=p.Damage*3
            return true
        end
    end
    function api.GetEntries(p)return Core.Entries(data(),key(p))end
    function api.Spit(p,uid)
        local ok=Core.Take(data(),key(p),uid,function(e)
            local direction=facing(p)
            if e.kind=='spikes' or e.kind=='flame'then
                return specialShot(p,e,direction)
            end
            if not flightVariant or flightVariant<=0 then return false end
            local rng=p:GetCollectibleRNG(id)
            direction=direction:Rotated((rng:RandomFloat()-.5)*30)
            local entity=Isaac.Spawn(EntityType.ENTITY_EFFECT,flightVariant,0,p.Position,zero(),p)
            local effect=entity and entity:ToEffect()
            if not effect then return false end
            effect.Visible=false
            effect.Timeout=120
            local flight={entity=effect,entry=e,player=p,key=key(p),room=roomKey(),age=0,
                pos=p.Position,velocity=direction*(8+rng:RandomFloat()*4),duration=18+rng:RandomFloat()*12,
                sprite=makeSprite(e),damage=Core.Damage(e.kind,p.Damage)}
            flights[#flights+1]=flight
            data().inflight=data().inflight or{};data().inflight[tostring(e.uid)]={key=flight.key,entry=e}
            return true
        end)
        if ok then save()end
        return ok
    end
    local function menu(p,slot)
        holds[key(p)]=nil
        return selector.Open(p,{title=mod:GetRuntimeLocale()=='zh_cn'and'凸眼鱼 · 储物清单'or'Blinky · Stored objects',
            controls=mod:GetRuntimeLocale()=='zh_cn'and'方向键选择  主动键吐出  返回取消'or'Arrows: select  Active: spit  Back: cancel',
            confirmAction=actionForSlot(slot),
            getEntries=function(owner)
                local result={}
                for index,e in ipairs(api.GetEntries(owner))do
                    result[#result+1]={id=e.uid,count=1,name=label(e),order=index,payload=e,
                        spritePath=e.spritePath,animation=e.animation,frame=e.frame,gfx=e.gfx}
                end
                return result
            end,
            valid=function(owner)return owner:GetActiveItem(slot)==id end,
            execute=function(owner,e)local ok=api.Spit(owner,e.id);if ok then save()end;return ok end})
    end
    local function finishFlight(f,hit)
        local e,p=f.entry,f.player;local pos=f.pos
        if e.kind=='pickup'then
            if not nativePickup(e,pos,p)then Core.Return(data(),f.key,e)end
        elseif e.kind=='chest'then
            local chest=nativePickup(e,pos,p)
            if chest then
                local opened
                if chest.TryThrow then opened=chest:TryThrow(EntityRef(p),zero(),0)end
                if not opened then opened=chest:TryOpenChest()end
                if not opened then
                    chest:Remove();Core.Return(data(),f.key,e)
                end
                if opened and e.variant==holyChestVariant then
                    chest:GetData().NeverbirthBlinkyHolyOpened=true
                    local s=data();s.holyOpened=s.holyOpened or{};s.holyOpened[chestIdentity(chest)]=true
                end
            else Core.Return(data(),f.key,e)end
        elseif e.kind=='poop' and hit then
            for i=0,3 do fireTear(p,pos,Vector(1,0):Rotated(i*90)*7,f.damage/2,false)end
        elseif e.kind=='tnt'then
            game:BombExplosionEffects(pos,40,TearFlags.TEAR_NORMAL,Color.Default,p,1,true,false,DamageFlag.DAMAGE_EXPLOSION)
        end
        if exists(f.entity)then f.entity:Remove()end
        if data().inflight then data().inflight[tostring(e.uid)]=nil end
        save()
    end
    local function stepFlights()
        local room=game:GetRoom()
        for i=#flights,1,-1 do
            local f=flights[i];f.age=f.age+1
            if not exists(f.player) or f.player:IsDead()then
                Core.Return(data(),f.key,f.entry)
                if exists(f.entity)then f.entity:Remove()end
                data().inflight[tostring(f.entry.uid)]=nil;table.remove(flights,i);save()
                goto nextFlight
            end
            local nextPos=f.pos+f.velocity
            local blocked=not room:IsPositionInRoom(nextPos,12) or room:GetGridCollisionAtPos(nextPos)~=0
            if not blocked then f.pos=nextPos end
            local hit
            if f.damage>0 and f.entry.kind~='tnt'then
                for _,npc in ipairs(Isaac.GetRoomEntities())do
                    if enemy(npc) and (npc.Position-f.pos):Length()<=npc.Size+12 then
                        npc:TakeDamage(f.damage,0,EntityRef(f.player),0);hit=npc;break
                    end
                end
            end
            if hit or blocked or f.age>=f.duration or not exists(f.entity)then
                finishFlight(f,hit);table.remove(flights,i)
            else f.entity.Position=f.pos end
            ::nextFlight::
        end
    end
    local function returnFlights()
        local s=data()
        for _,f in ipairs(flights)do
            Core.Return(s,f.key,f.entry);if exists(f.entity)then f.entity:Remove()end
        end
        -- A saved, interrupted flight is recovered exactly once after Continue.
        for _,f in pairs(s.inflight or{})do Core.Return(s,f.key,f.entry)end
        s.inflight={};flights={};holds={};swings={};save()
    end
    local function enforceConsumed()
        local s=data();local rk=roomKey();local ledger=s.consumed[rk]or{};local room=game:GetRoom()
        if next(ledger)==nil then return end
        for _,record in pairs(ledger)do
            if record.grid then
                local g=room:GetGridEntity(record.grid)
                if g and gridToken(g,record.grid)==record.token then removeGrid(room,record.grid)end
            end
        end
        for _,e in ipairs(Isaac.GetRoomEntities())do
            local token=entityToken(e)
            if ledger[token] and not(s.released[rk]or{})[token]then e:Remove()end
        end
        -- Same-seed released pickups are deliberately exempt. If Hourglass recreates
        -- one too, the user-approved duplication fallback wins over losing the bag.
    end
    mod:AddCallback(ModCallbacks.MC_USE_ITEM,function(_,_,_,p,flags,slot)
        if UseFlag and UseFlag.USE_CARBATTERY and flags & UseFlag.USE_CARBATTERY~=0 then
            return {Discharge=false,Remove=false,ShowAnim=false}
        end
        if selector.IsBlocking(p)then return{Discharge=false,Remove=false,ShowAnim=false}end
        if input(ButtonAction.ACTION_DROP,p)then menu(p,slot or 0)
        elseif not holds[key(p)]then
            local swung=melee(p)
            holds[key(p)]={player=p,slot=slot or 0,start=game:GetFrameCount(),last=game:GetFrameCount(),melee=swung}
            local config=Isaac.GetItemConfig():GetCollectible(id)
            if config then
                holds[key(p)].sprite=makeSprite({spritePath='gfx/005.100_collectible.anm2',animation='Idle',gfx=config.GfxFileName})
            end
        end
        return{Discharge=false,Remove=false,ShowAnim=false}
    end,id)
    -- Schoolbag's native Ctrl action may swap Blinky into the secondary slot
    -- before the Active press. Keep that chord assigned to Blinky's storage.
    mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM,function(_,used,_,p)
        if used~=id and p:GetActiveItem(1)==id and input(ButtonAction.ACTION_DROP,p)then
            if not selector.IsBlocking(p)then menu(p,1)end
            return true
        end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE,function()
        if game:IsPaused()then return end
        local now=game:GetFrameCount()
        if reconcileAt and now>=reconcileAt then reconcileAt=nil;enforceConsumed()end
        for k,h in pairs(holds)do
            local p=h.player
            if not exists(p) or p:IsDead() or p:GetActiveItem(h.slot)~=id or selector.IsBlocking(p)
                or not input(actionForSlot(h.slot),p)then holds[k]=nil
            else
                if not h.melee or now-h.start>=10 then absorb(p)end
                if now-h.last>=15 then h.last=now;suctionDamage(p)end
            end
        end
        for k,swing in pairs(swings)do
            if now>=swing.expires or not exists(swing.player)then swings[k]=nil else swing.sprite:Update()end
        end
        stepFlights()
    end)
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,function(_,entity)
        if entity:GetData().NeverbirthBlinkySuction and entity~=activeDamage then
            entity:GetData().NeverbirthBlinkySuction=nil
        end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH,function(_,npc)reward(npc)end)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,function()
        returnFlights();enforceConsumed();reconcileAt=game:GetFrameCount()+1
    end)
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,function(_,continued)
        flights={};holds={};swings={};activeDamage=nil
        if not continued then context.GetSaveRoot().blinky=nil end
        returnFlights();enforceConsumed();reconcileAt=game:GetFrameCount()+1
    end)
    if ModCallbacks.MC_POST_GLOWING_HOURGLASS_LOAD then
        mod:AddCallback(ModCallbacks.MC_POST_GLOWING_HOURGLASS_LOAD,function()
            returnFlights();reconcileAt=game:GetFrameCount()+1
        end)
    end
    if ModCallbacks.MC_EXECUTE_CMD then
        mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD,function(_,command,parameters)
            if command~='blinky'then return end
            local mode,index=(parameters or''):match('^(%a+)%s*(%d*)$')
            index=tonumber(index)or 0
            local p=(context.GetPlayers()or{})[index+1]
            local message
            if not p then message='Blinky: player unavailable\n'
            elseif mode=='give'then
                p:AddCollectible(id,0,true,0);message='Blinky: given to P'..(index+1)..'\n'
            elseif mode=='status'then
                message='Blinky: P'..(index+1)..' stores '..#api.GetEntries(p)..' objects; runtime collectible '..id..'\n'
            else message='blinky give [player index] / blinky status [player index]\n'end
            if Isaac.ConsoleOutput then Isaac.ConsoleOutput(message)elseif context.DebugLog then context.DebugLog(message)end
        end)
    end
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT,function()returnFlights()end)
    mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION,function(_,pickup)
        if pickup.Variant==holyChestVariant and (pickup:GetData().NeverbirthBlinkyHolyOpened
            or (data().holyOpened or{})[chestIdentity(pickup)])then return true end
    end)
    mod:AddCallback(ModCallbacks.MC_INPUT_ACTION,function(_,entity,hook,action)
        if readingInput>0 or action~=ButtonAction.ACTION_DROP or not entity then return end
        local p=entity:ToPlayer()
        if p and holds[key(p)]then return hook==InputHook.GET_ACTION_VALUE and 0 or false end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER,function()
        for _,f in ipairs(flights)do
            local height=math.sin(math.pi*math.min(1,f.age/f.duration))*24
            f.sprite:Render(Isaac.WorldToScreen(f.pos)+Vector(0,-height),zero(),zero())
        end
        for _,swing in pairs(swings)do
            swing.sprite:Render(Isaac.WorldToScreen(swing.player.Position),zero(),zero())
        end
        for _,hold in pairs(holds)do
            if hold.sprite and exists(hold.player)then
                hold.sprite:RenderLayer(1,Isaac.WorldToScreen(hold.player.Position)+facing(hold.player)*20+Vector(0,8))
            end
        end
        if next(data().wounds[roomKey()]or{})==nil then return end
        for _,npc in ipairs(Isaac.GetRoomEntities())do
            if enemy(npc) and wounded(npc)then
                local font=mod.GetRuntimeTextFont and mod:GetRuntimeTextFont(mod:GetRuntimeLocale())
                if font and KColor then
                    local pos=Isaac.WorldToScreen(npc.Position)
                    font:DrawStringUTF8(mod:GetRuntimeLocale()=='zh_cn'and'受创'or'Wounded',pos.X-12,pos.Y-32,KColor(1,.3,.3,1),0,false)
                end
            end
        end
    end)
    mod.Blinky=api;return api
end
